import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;

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
}
