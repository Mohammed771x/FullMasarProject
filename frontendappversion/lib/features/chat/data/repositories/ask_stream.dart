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
  }) async* {
    final client = _injected ?? http.Client();
    _active = client;

    final request = http.Request("POST", url)
      ..headers.addAll({...headers, "Accept": "text/event-stream"})
      ..body = jsonEncode(body);

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
      if (parsed != null && (parsed["answer"] ?? "").toString().isNotEmpty) {
        yield AskDone(parsed);
      } else {
        yield AskFailure("⚠️ تعذّر الوصول للخادم (${response.statusCode}).");
      }
      return;
    }

    var buffer = "";
    try {
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;

        // نقصّ على فاصل الأحداث فقط — راجع تحذير التقطيع في الأعلى.
        var sep = buffer.indexOf("\n\n");
        while (sep >= 0) {
          final block = buffer.substring(0, sep);
          buffer = buffer.substring(sep + 2);
          final event = _parseBlock(block);
          if (event != null) yield event;
          sep = buffer.indexOf("\n\n");
        }
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
  const StreamInterrupted(this.message);
  final String message;

  @override
  String toString() => message;
}
