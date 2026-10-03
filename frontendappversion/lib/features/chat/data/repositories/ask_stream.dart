import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

// ==========================================
// 🌊 عميل بثّ الإجابة (SSE)
// ==========================================
// 🔴 **ما يعالجه:** الطالب كان يحدّق في مؤشّر تحميل حتى ٦٠ ثانية ثم يظهر
//    النص دفعةً واحدة. أول كلمةٍ الآن تصل خلال ثانيتين.
//
// 📡 **SSE لا WebSocket:** اتجاهٌ واحد يكفي، ويمرّ عبر أي بروكسي HTTP بلا
//    إعداد، ويُقرأ بـ`http.Client.send` **بلا أي حزمة جديدة**.
//
// ⚠️ **والتقطيع لا يقع على حدود الأحداث.** الشبكة تسلّم بايتاتٍ لا رسائل:
//    قد يصل نصف سطر `data:` في حزمة والنصف الآخر في التالية. ولذلك نُجمّع
//    في مخزنٍ ونقصّ على `\n\n` — وقراءةُ كل حزمة كحدثٍ كامل كانت ستُسقط
//    أجزاءً عشوائية من الشرح، وهو عطلٌ يظهر على الشبكات البطيئة وحدها
//    (أي عند طلابنا لا عندنا).

/// حدثٌ واحد من الخادم.
sealed class AskEvent {
  const AskEvent();
}

/// جزءٌ جديد يُلحق بالفقاعة فوراً.
class AskDelta extends AskEvent {
  const AskDelta(this.text);
  final String text;
}

/// النهاية: الرد **النهائي** بعد التنظيف + المراجع والأعلام.
///
/// ⚠️ يُستبدل به المبثوث ولا يُلحق: الخادم يُنقّي الناتج بعد التوليد وقد
///    يُلحق ملاحظة، فالمبثوث تقريبٌ والنهائيُّ هو الحقيقة.
class AskDone extends AskEvent {
  const AskDone(this.payload);
  final Map<String, dynamic> payload;
}

/// 🏷️ **نوعُ العطل** — منه وحده تُشتقّ رسالةُ الطالب وزرُّ إعادة المحاولة
/// وحركةُ الحصة ([ErrorMessages.forAskError]).
///
/// 🔴 **ما كان قبله:** كلُّ عطلٍ نصٌّ جاهز، وكلُّ ردٍّ غير ٢٠٠ فيه `answer`
///    يُعرض **جواباً عادياً** من الموديل — رفضُ ٤٠٣ وحصةُ ٤٢٩ و«ضغط مفاجئ»
///    ٥٠٠ بأزرار «حفظ» واقتراحات «بسّط لي»، ويُخصم من العدّاد. وما لا
///    `answer` فيه صار «حدث خطأ غير متوقع» بلا زرّ إعادة — حتى انقطاعُ النت.
enum AskErrorKind {
  /// لا شبكة / الخادم لا يُوصَل.
  offline,

  /// مهلةُ فتح الاتصال انقضت.
  timeout,

  /// البثّ فُتح ثم صمت أو انقطع.
  interrupted,

  /// 401 — التوكن منتهٍ أو مرفوض.
  unauthorized,

  /// 403 — محظور / قسمٌ مقفل / بريدٌ غير مفعّل.
  forbidden,

  /// 429 بعلَم `quota_exceeded` — نفدت الحصة.
  quota,

  /// 429 بلا علَم الحصة — طلباتٌ كثيرة في وقتٍ قصير.
  rateLimited,

  /// 413 / 422 — الرسالة أو الصورة أكبر من المسموح.
  tooLarge,

  /// 400 وما يشبهه — طلبٌ لا يقبله الخادم.
  badRequest,

  /// 404 — المسار غير موجود (خادمٌ قديم أو نسخةٌ قديمة).
  notFound,

  /// 5xx أو حدثُ `error` من الموديل أثناء التوليد.
  server,

  /// `done` وصل بنصٍّ فارغ — لا جوابَ يُعرض.
  empty,
}

/// انقطاعٌ برسالة عربية جاهزة — ما وصل قبله يبقى معروضاً.
///
/// [kind] يحدّد السلوك، و[serverMessage] نصُّ الخادم إن أرسل نصّاً عربياً
/// يُعرض كما هو (رسالةُ الحظر أو الحصة)، و[payload] جسمُ الردّ لمن يحتاج
/// أعلامه (`quota_exceeded` · `is_guest`).
class AskFailure extends AskEvent {
  const AskFailure(
    this.message, {
    this.kind = AskErrorKind.server,
    this.status,
    this.serverMessage = "",
    this.payload = const {},
  });
  final String message;
  final AskErrorKind kind;
  final int? status;
  final String serverMessage;
  final Map<String, dynamic> payload;
}

/// يصنّف ردّاً غير ٢٠٠ بحالته وأعلامه — لا بنصّه.
AskErrorKind askKindForStatus(int status, Map<String, dynamic>? body) {
  // 📱 **رفضُ App Check يصل 401 لكنه ليس جلسةً منتهية** (فحص أندرويد
  //    ٢٠٢٦-١٠-٠٣): كان يُجدَّد التوكن ويُعاد الطلب بلا فائدة، ثم يقرأ
  //    الطالب «انتهت جلستك… سجّل الدخول من جديد» — وتسجيلُ خروج الزائر
  //    يُضيّع بياناته ولا يُصلح شيئاً. فهو رفضٌ برسالة الخادم (حدّث التطبيق).
  if (body?["app_check_failed"] == true) return AskErrorKind.forbidden;
  if (status == 401) return AskErrorKind.unauthorized;
  if (status == 403) return AskErrorKind.forbidden;
  if (status == 429) {
    return body?["quota_exceeded"] == true
        ? AskErrorKind.quota
        : AskErrorKind.rateLimited;
  }
  if (status == 413 || status == 422) return AskErrorKind.tooLarge;
  if (status == 404) return AskErrorKind.notFound;
  if (status >= 500) return AskErrorKind.server;
  return AskErrorKind.badRequest;
}

/// المحاولة نفسها ما زالت تعمل في الخادم (HTTP 202).
///
/// ليست إجابةً للمستخدم ولا فشلاً: على المتحكّم أن يعيد الاستعلام بنفس
/// `request_id` ونفس الحمولة حتى تتحول المحاولة إلى `done`.
class AskPending extends AskEvent {
  const AskPending();
}

class AskStream {
  AskStream([http.Client? client]) : _injected = client;

  final http.Client? _injected;
  http.Client? _active;

  /// يفتح البثّ ويُنتج الأحداث تباعاً.
  ///
  /// 🛟 **لا يرمي عند انقطاع الشبكة** — يُنتج [AskFailure] كي يتصرّف
  ///    المتحكّم بنفس منطق بقية الأعطال بدل `try/catch` ثانٍ حوله.
  Stream<AskEvent> open({
    required Uri url,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
    Duration timeout = const Duration(seconds: 120),
    Duration idleTimeout = const Duration(seconds: 35),
  }) async* {
    // ☢️ **ومن فتحه يُغلقه** — وهذا ليس ترتيباً بل تسريبٌ حقيقيّ:
    //    إعادةُ الاستعلام على 202 تفتح `open()` من جديد كل مرة، وردُّ
    //    الخادم لا يأتي إلا بعد أن يفرغ من التوليد. فشرحٌ يستغرق ٤٠ ثانية
    //    كان يُخلّف **عشرات** عملاء `http` مفتوحين، كلٌّ منهم يحمل بركةَ
    //    اتصالاتٍ حيّة، بلا أن يُغلق واحدٌ منها أبداً.
    //
    // ⚖️ والمحقونُ في الاختبارات لا يُغلق: مالكُه من حَقَنه ([_injected])،
    //    وإغلاقُه هنا يقتل الطلب التالي في نفس الاختبار.
    final created = _injected == null ? http.Client() : null;
    final client = _injected ?? created!;
    _active = client;

    final request = http.Request("POST", url)
      ..headers.addAll({...headers, "Accept": "text/event-stream"})
      ..body = jsonEncode(body);

    try {
      yield* _events(client, request, timeout, idleTimeout);
    } finally {
      created?.close();
      if (identical(_active, client)) _active = null;
    }
  }

  Stream<AskEvent> _events(
    http.Client client,
    http.Request request,
    Duration timeout,
    Duration idleTimeout,
  ) async* {
    final http.StreamedResponse response;
    try {
      response = await client.send(request).timeout(timeout);
    } catch (e) {
      yield _failureFor(e);
      return;
    }

    // ⚠️ **الرفض يصل كردٍّ عادي لا كتدفّق**: الخادم يفرض الحرّاس قبل بدء
    //    البثّ (401 · 403 · 429). وهو **فشلٌ لا جواب** وإن حمل `answer` —
    //    كان يُعرض فقاعةَ موديلٍ عادية تُحفظ وتُخصم وتُقترح متابعتُها.
    //    فيصير [AskFailure] بنوعه، ونصُّ الخادم يرافقه لمن يعرضه.
    if (response.statusCode != 200) {
      String raw = "";
      try {
        raw = await response.stream.bytesToString();
      } catch (_) {}
      Map<String, dynamic>? parsed;
      try {
        parsed = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
      if (response.statusCode == 202 && parsed?["in_flight"] == true) {
        yield const AskPending();
        return;
      }
      final kind = askKindForStatus(response.statusCode, parsed);
      yield AskFailure(
        "⚠️ تعذّر الوصول للخادم (${response.statusCode}).",
        kind: kind,
        status: response.statusCode,
        serverMessage: (parsed?["answer"] ?? "").toString(),
        payload: parsed ?? const {},
      );
      return;
    }

    // 📦 **٢٠٠ بلا بثّ = جوابٌ كامل** (فحص أندرويد ٢٠٢٦-١٠-٠٣): الخادمُ يردّ
    //    JSON عاديّاً على مسار البثّ في حالتين — إعادةُ نفس `request_id` بعد
    //    أن اكتمل (الجوابُ المحفوظ)، وصورةٌ رُفضت قبل التوليد (رسالةٌ عربية).
    //    كان يُقرأ «انقطاعاً» لغياب أحداث SSE: فيضيع الجوابُ المدفوع، وتُعاد
    //    الصورةُ تلقائياً فتُقرأ مرّتين وتُخصم مرّتين.
    if ((response.headers["content-type"] ?? "").contains("application/json")) {
      Map<String, dynamic>? parsed;
      try {
        parsed = jsonDecode(await response.stream.bytesToString())
            as Map<String, dynamic>;
      } catch (_) {}
      if (parsed != null && parsed["answer"] != null) {
        yield AskDone(parsed);
      } else {
        yield const AskFailure(
          "📡 **انقطع الاتصال**\n\nتأكد من الإنترنت وحاول مجدداً.",
          kind: AskErrorKind.interrupted,
        );
      }
      return;
    }

    var buffer = "";
    var terminal = false;
    try {
      // `timeout` أعلاه لفتح الاتصال فقط. هذه مهلة خمول متجددة مع كل chunk
      // (ومنها نبضات SSE)، كي لا يبقى `await for` معلقاً إلى الأبد.
      await for (final chunk
          in response.stream.transform(utf8.decoder).timeout(idleTimeout)) {
        buffer += chunk;

        // نقصّ على فاصل الأحداث فقط — راجع تحذير التقطيع في الأعلى.
        var sep = buffer.indexOf("\n\n");
        while (sep >= 0) {
          final block = buffer.substring(0, sep);
          buffer = buffer.substring(sep + 2);
          final event = _parseBlock(block);
          if (event != null) {
            if (event is AskDone || event is AskFailure) terminal = true;
            yield event;
          }
          sep = buffer.indexOf("\n\n");
        }
      }
      // إغلاق TCP بلا `done` انقطاعٌ، حتى لو وصل قبله جزء من النص.
      if (!terminal) {
        yield const AskFailure(
          "📡 **انقطع الاتصال**\n\nتأكد من الإنترنت وحاول مجدداً.",
          kind: AskErrorKind.interrupted,
        );
      }
    } catch (e) {
      // ⏱️ خمولٌ بعد الفتح أو سقوطُ الاتصال في منتصفه — انقطاعٌ لا مهلةُ فتح.
      yield AskFailure(
        _describe(e),
        kind: e is TimeoutException
            ? AskErrorKind.interrupted
            : AskErrorKind.offline,
      );
    }
  }

  /// يفكّ كتلة SSE واحدة. يعيد `null` للنبضات والأسطر التي لا تعنينا.
  AskEvent? _parseBlock(String block) {
    final line = block
        .split("\n")
        .firstWhere((l) => l.startsWith("data:"), orElse: () => "");
    if (line.isEmpty) return null; // نبضة `: keep-alive` أو سطر فارغ

    final raw = line.substring(5).trim();
    if (raw.isEmpty) return null;

    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // ⚠️ حدثٌ مشوّه يُتجاهل ولا يُسقط البثّ: بقيةُ الشرح أهمُّ من جزءٍ واحد.
      return null;
    }

    return switch (json["t"]) {
      "delta" => AskDelta((json["v"] ?? "").toString()),
      "done" => AskDone(json),
      "error" => AskFailure(
          (json["v"] ?? "").toString(),
          kind: AskErrorKind.server,
          serverMessage: (json["v"] ?? "").toString(),
        ),
      _ => null,
    };
  }

  static AskFailure _failureFor(Object e) => AskFailure(
        _describe(e),
        kind: e is TimeoutException ? AskErrorKind.timeout : AskErrorKind.offline,
      );

  static String _describe(Object e) {
    if (e is TimeoutException) {
      return "⏱️ **تأخّر الرد أكثر من اللازم**\n\nحاول مرة أخرى.";
    }
    return "📡 **انقطع الاتصال**\n\nتأكد من الإنترنت وحاول مجدداً.";
  }

  /// يقطع البثّ الجاري — يُنادى عند مغادرة الشاشة.
  void cancel() {
    try {
      _active?.close();
    } catch (_) {}
    _active = null;
  }
}

/// انقطاعٌ أثناء البثّ **قبل** وصول أي نص.
///
/// ⚠️ نوعٌ خاص لا `Exception` عامة: المتحكّم يعرض رسالته العربية كما هي بدل
///    أن يُترجم عطلاً مجهولاً إلى «حدث خطأ غير متوقع».
class StreamInterrupted implements Exception {
  const StreamInterrupted(
    this.message, {
    this.hasPartial = false,
    this.kind = AskErrorKind.interrupted,
    this.payload = const {},
  });
  final String message;
  final bool hasPartial;
  final AskErrorKind kind;
  final Map<String, dynamic> payload;

  @override
  String toString() => message;
}

/// إلغاءٌ مقصود من المستخدم/تبديل السياق، لا عطلٌ يستحق فقاعة خطأ.
class RequestCancelled implements Exception {
  const RequestCancelled();
}
