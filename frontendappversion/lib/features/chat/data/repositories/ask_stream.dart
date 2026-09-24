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

/// انقطاعٌ برسالة عربية جاهزة — ما وصل قبله يبقى معروضاً.
class AskFailure extends AskEvent {
  const AskFailure(this.message);
  final String message;
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
      yield AskFailure(_describe(e));
      return;
    }

    // ⚠️ **الرفض يصل كردٍّ عادي لا كتدفّق**: الخادم يفرض الحرّاس قبل بدء
    //    البثّ (401 · 429 · 403). فنقرأ الجسم كاملاً ونُخرجه كـ«نهاية»
    //    ليتعامل معه المتحكّم كردٍّ عادي — رسالة الحصة تُعرض كما هي.
    if (response.statusCode != 200) {
      final raw = await response.stream.bytesToString();
      Map<String, dynamic>? parsed;
      try {
        parsed = jsonDecode(raw) as Map<String, dynamic>;
      } catch (_) {}
      if (response.statusCode == 202 && parsed?["in_flight"] == true) {
        yield const AskPending();
      } else if (parsed != null &&
          (parsed["answer"] ?? "").toString().isNotEmpty) {
        yield AskDone(parsed);
      } else {
        yield AskFailure("⚠️ تعذّر الوصول للخادم (${response.statusCode}).");
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
        );
      }
    } catch (e) {
      yield AskFailure(_describe(e));
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
      "error" => AskFailure((json["v"] ?? "").toString()),
      _ => null,
    };
  }

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
  const StreamInterrupted(this.message, {this.hasPartial = false});
  final String message;
  final bool hasPartial;

  @override
  String toString() => message;
}

/// إلغاءٌ مقصود من المستخدم/تبديل السياق، لا عطلٌ يستحق فقاعة خطأ.
class RequestCancelled implements Exception {
  const RequestCancelled();
}
