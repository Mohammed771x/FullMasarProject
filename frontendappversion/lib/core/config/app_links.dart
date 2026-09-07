// ==========================================
// 🔗 core/config/app_links.dart — روابط خارجية
// ==========================================
// مجمَّعة في مكان واحد كي لا تتناثر في الشاشات: تغيير رابط الخصوصية يوماً
// يجب أن يكون سطراً واحداً لا بحثاً في المشروع.
//
// ⚠️ الرابط الفارغ **لا يُعرض زرّه أصلاً** — زرٌّ لا يفتح شيئاً أسوأ من
//    غيابه: الطالب يظنّه عطلاً في التطبيق.
class AppLinks {
  AppLinks._();

  /// 📄 سياسة الخصوصية — ضع الرابط هنا ليظهر بندها في الإعدادات.
  static const String privacyPolicy = "";

  /// 📜 شروط الاستخدام.
  static const String terms = "";

  /// 💬 الدعم عبر واتساب.
  static const String supportWhatsapp = "https://wa.me/917736388574";

  /// 📧 بريد الدعم.
  static const String supportEmail = "bsak530156@gmail.com";

  static bool has(String url) => url.trim().isNotEmpty;
}
