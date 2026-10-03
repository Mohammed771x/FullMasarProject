import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../features/chat/data/repositories/ask_stream.dart';

// ==========================================
// 🛡️ تحويل الأخطاء إلى رسائل عربية مفهومة للطالب
// ==========================================
// نفس منطق _getDetailedErrorMessage الأصلي، مجمّع في مكان واحد.
class ErrorMessages {
  ErrorMessages._();

  static String fromException(Object error) {
    if (error is TimeoutException) {
      return "⏱️ انتهت مهلة الانتظار\nاستغرق الطلب وقتاً طويلاً جداً.\nقد يكون السيرفر مشغول. حاول مجدداً بعد دقيقة.";
    } else if (error is SocketException) {
      return "📡 خطأ في الاتصال\n• تأكد من وصول الإنترنت\n• السيرفر قد يكون مغلقاً حالياً";
    } else if (error is FormatException) {
      return "⚠️ خطأ في البيانات\nالبيانات المستقبلة من السيرفر غير مفهومة (ربما السيرفر يعاد تشغيله).";
    } else if (error is http.ClientException) {
      return "🔗 انقطع الاتصال\nلم نتمكن من إكمال التخاطب مع السيرفر.";
    } else {
      return "❌ خطأ غير معروف\nحاول مجدداً أو تواصل مع الدعم الفني.";
    }
  }

  // رسائل الفقاعة (تظهر داخل المحادثة عند الفشل) — نفس النصوص الأصلية
  static const String askTimeout =
      "⏱️ **عذراً، السيرفر مشغول جداً حالياً**\n\nاستغرق الطلب وقتاً أطول من اللازم.\nالرجاء المحاولة مرة أخرى أو طرح سؤال مختلف.";

  static const String askNoConnection =
      "📡 **تعذر الاتصال بالخادم**\n\nتأكد من اتصالك بالإنترنت وحاول مجدداً.";

  static const String askUnexpected =
      "⚠️ **حدث خطأ غير متوقع**\n\nيرجى المحاولة لاحقاً.";

  /// 🌊 التدفّق انتهى بلا `done` وبلا سببِ فشلٍ يُعرض — لا عطلَ شبكةٍ
  ///    صريح بل صمتٌ طال. تختلف عن [askTimeout] لأنها لا تقع على مهلة
  ///    الطلب بل على **خمول** البثّ بعد أن فُتح ([AskStream.idleTimeout]).
  static const String askStreamStalled =
      "⏱️ **تأخّر الرد أكثر من اللازم**\n\nحاول مرة أخرى.";

  // ══════════════════════════════════════════════════
  // 📡 تصنيف عطل الإرسال — مكانٌ واحد لا شرطٌ مكرّر
  // ══════════════════════════════════════════════════
  // 🔴 **العطل الذي أوجب هذه الدوال:** شاشة المحادثة كانت تمسك
  //    `SocketException` وحدها لرسالة «لا يوجد اتصال». وحزمة `http` على
  //    أندرويد ترمي `ClientException` في **معظم** أعطال الشبكة الحقيقية
  //    (انقطاع Wi-Fi · بيانات مغلقة · DNS فاشل)، فكان الطالب المنقطع نتُّه
  //    يرى «حدث خطأ غير متوقع» — رسالةٌ تُلقي اللومَ على التطبيق وتُخفي
  //    السببَ الوحيد الذي يستطيع الطالب إصلاحه بنفسه.
  //
  // ⚠️ وتُطابَق `ClientException` **بنوعها لا بنصّها**: نصوصها تختلف بين
  //    أندرويد وiOS والويب وتتغيّر بين إصدارات الحزمة.

  /// هل هذا العطل انقطاعُ اتصالٍ يستطيع الطالب إصلاحه؟
  static bool isConnectivity(Object error) =>
      error is SocketException || error is http.ClientException;

  /// هل تُجدي إعادةُ المحاولة؟ (مهلة أو شبكة — لا خطأ برمجي)
  static bool isRetryable(Object error) =>
      error is TimeoutException || isConnectivity(error);

  /// نصّ الفقاعة الذي يراه الطالب عند فشل الإرسال.
  static String forSendFailure(Object error) {
    if (error is StreamInterrupted) {
      return forAskError(error.kind, error.message);
    }
    if (error is TimeoutException) return askTimeout;
    if (isConnectivity(error)) return askNoConnection;
    return askUnexpected;
  }

  /// هل يُعرض زرّ «أعد المحاولة» على فقاعة هذا العطل؟
  static bool canRetrySend(Object error) {
    if (error is StreamInterrupted) return retryableKind(error.kind);
    return isRetryable(error);
  }

  // ══════════════════════════════════════════════════
  // 🏷️ عطلُ الإرسال بنوعه ([AskErrorKind]) — لا «غير متوقع» لعطلٍ معروف
  // ══════════════════════════════════════════════════
  // 🔴 **العطل الذي أوجب هذا الباب (فحص ٢٠٢٦-١٠-٠٢):** `AskStream` صار
  //    يحوّل كلَّ عطلٍ إلى `StreamInterrupted`، و[forSendFailure] لم تعرف
  //    هذا النوع — فانقطاعُ النت و٤٠١ و٥٠٠ كلُّها «حدث خطأ غير متوقع»
  //    بلا زرّ إعادة. أي أن العطلَ الذي يصفه رأسُ هذا الملف **عاد**.

  static const String askUnauthorized =
      "🔐 **انتهت جلستك**\n\nأغلق التطبيق وافتحه، وإن تكرّر فسجّل الدخول من جديد.";
  static const String askForbidden =
      "⛔ **لا يمكن إرسال هذا الطلب**\n\nهذا القسم غير متاح لحسابك حالياً.";
  static const String askQuota =
      "🎟️ **انتهت أسئلتك المتاحة**\n\nتتجدّد الحصة قريباً.";
  static const String askRateLimited =
      "⏳ **أرسلت أسئلةً كثيرة بسرعة**\n\nانتظر دقيقةً ثم حاول مجدداً.";
  static const String askTooLarge =
      "📦 **سؤالك أطول من المسموح**\n\nاختصر الرسالة أو صغّر الصورة وحاول مجدداً.";
  static const String askBadRequest =
      "⚠️ **تعذّر قبول الطلب**\n\nتأكد من اختيار الدرس وحاول مجدداً.";
  static const String askNotFound =
      "🛠️ **الخدمة غير متاحة الآن**\n\nقد يحتاج التطبيق إلى تحديث، أو أن الخادم في صيانة.";
  // ⚖️ **بلا «لم يُخصم سؤالك»** (فحص أندرويد ٢٠٢٦-١٠-٠٣): الخادمُ يثبّت
  //    الخصمَ متى نودي الموديل ولو فشل بعدها ([Backend/core/billing]) —
  //    فالتطبيقُ لا يعرف ذلك فلا يَعِد به.
  static const String askServer =
      "🛠️ **الخادم يواجه مشكلةً مؤقتة**\n\nحاول مجدداً بعد قليل.";
  static const String askEmpty =
      "🤔 **لم يصل ردٌّ هذه المرة**\n\nحاول مجدداً.";

  /// نصُّ فقاعة العطل حسب نوعه. [serverMessage] نصُّ الخادم — يُعرض في
  /// الحظر والحصة والإبطاء حيث يحمل سبباً لا يعرفه التطبيق (موعدُ التجدّد،
  /// سببُ الإقفال)، ويُتجاهل فيما سواها: رسائلُ التحقق تحمل أسماءَ حقولٍ
  /// إنجليزية («content») لا تعني الطالب شيئاً.
  static String forAskError(AskErrorKind kind, [String serverMessage = ""]) {
    final server = serverMessage.trim();
    final usable = server.isNotEmpty && !_looksTechnical(server);
    return switch (kind) {
      AskErrorKind.offline => askNoConnection,
      AskErrorKind.timeout => askTimeout,
      AskErrorKind.interrupted => askStreamStalled,
      AskErrorKind.unauthorized => askUnauthorized,
      AskErrorKind.forbidden => usable ? server : askForbidden,
      AskErrorKind.quota => usable ? server : askQuota,
      AskErrorKind.rateLimited => usable ? server : askRateLimited,
      AskErrorKind.tooLarge => askTooLarge,
      AskErrorKind.badRequest => askBadRequest,
      AskErrorKind.notFound => askNotFound,
      AskErrorKind.server => askServer,
      AskErrorKind.empty => askEmpty,
    };
  }

  /// هل تُجدي إعادةُ المحاولة لهذا النوع؟ الحظرُ والحصةُ والطولُ لا تتغيّر
  /// بضغطة — زرٌّ هناك وعدٌ كاذب.
  static bool retryableKind(AskErrorKind kind) => switch (kind) {
        AskErrorKind.offline ||
        AskErrorKind.timeout ||
        AskErrorKind.interrupted ||
        AskErrorKind.unauthorized ||
        AskErrorKind.rateLimited ||
        AskErrorKind.notFound ||
        AskErrorKind.server ||
        AskErrorKind.empty =>
          true,
        AskErrorKind.forbidden ||
        AskErrorKind.quota ||
        AskErrorKind.tooLarge ||
        AskErrorKind.badRequest =>
          false,
      };

  /// عطلٌ عابر يُعاد تلقائياً مرةً واحدة قبل أن يراه الطالب.
  static bool transientKind(AskErrorKind kind) => switch (kind) {
        AskErrorKind.offline ||
        AskErrorKind.timeout ||
        AskErrorKind.interrupted ||
        AskErrorKind.server =>
          true,
        _ => false,
      };

  /// نصٌّ تقنيّ لا يُعرض للطالب: لاتينيةٌ في رسالةٍ عربية أو بلا عربية.
  static bool _looksTechnical(String s) =>
      RegExp(r'[A-Za-z_]{3,}').hasMatch(s) ||
      !RegExp(r'[؀-ۿ]').hasMatch(s);
}
