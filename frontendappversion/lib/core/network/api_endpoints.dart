import '../config/app_config.dart';

// ==========================================
// 🔗 مسارات الـ Backend (نفس عقد السيرفر الأصلي حرفياً)
// ==========================================
class ApiEndpoints {
  ApiEndpoints._();

  static String get _base => AppConfig.baseUrl;

  // المحادثة الرئيسية
  static String ask() => "$_base/ask";

  /// 🌊 نفس `/ask` لكن يبثّ الجواب حرفاً حرفاً (SSE).
  /// نفس الحرّاس تماماً — البثّ طريقةُ تسليمٍ لا بابٌ جانبي.
  static String askStream() => "$_base/ask/stream";

  // 🎤 تنظيف نص التسجيل الصوتي
  static String voiceClean() => "$_base/voice/clean";

  /// 👤 صورة الحساب — رفعاً وحذفاً.
  static String avatar() => "$_base/me/avatar";

  /// 🎏 بانرات كل الأقسام في طلب واحد.
  ///
  /// 🎯 الصف والمسار **جزءٌ من الطلب** منذ صار البانر قابلاً للاستهداف:
  ///    بدونهما يعود كلُّ شيء (والتصفية تقع على التطبيق)، وبهما يصفّي
  ///    الخادمُ فلا تُنقل بانراتٌ لن تُعرض أصلاً.
  static String banners(int grade, String track) =>
      "$_base/banners?grade=$grade&track=${Uri.encodeComponent(track)}";

  /// 🔐 حالة أقسام التطبيق لهذا الصف والمسار — تُقرأ في كل إقلاع.
  static String appAccess(int grade, String track, [String role = "student"]) =>
      "$_base/app/access?grade=$grade&track=${Uri.encodeComponent(track)}"
      "&role=${Uri.encodeComponent(role)}";

  /// 📲 رمز جهاز الإشعارات — تسجيلاً (POST) وفصلاً (DELETE).
  static String device() => "$_base/me/device";

  /// 🔄 «تغيّر ملفي» — يُنادى بعد تبديل الدور أو الصف أو المسار.
  ///
  /// الخادم يكيّش `users/{uid}` دقيقتين لحارس الأقسام، فبلا هذا النداء
  /// يبقى يعامل من حوّل نفسه بدورِه القديم — فيظنّ التحويل لم يعمل.
  static String profileChanged() => "$_base/me/profile-changed";

  /// 📬 صندوق إشعارات الطالب.
  static String notificationsInbox() => "$_base/notifications/inbox";

  // 🎓 كل نقاط المحتوى محكومة بالصف والمسار — بلا ذلك يفترض الخادم
  //    «الثالث العلمي» فيتسرّب محتوى صفٍّ إلى صفٍّ آخر.
  static String _scope(int grade, String track) => "&grade=$grade&track=$track";

  // المحتوى العام
  static String units(String subject, int grade, String track) =>
      "$_base/subjects/units?subject=$subject${_scope(grade, track)}";

  static String lessons(String subject, String unit, int grade, String track) =>
      "$_base/subjects/lessons?subject=$subject&unit=$unit${_scope(grade, track)}";

  static String examYears(String subject, int grade, String track) =>
      "$_base/exams/years?subject=$subject${_scope(grade, track)}";

  static String examSections(String subject, String year, int grade, String track) =>
      "$_base/exams/sections?subject=$subject&year=$year${_scope(grade, track)}";

  // 🆕 قدرات المادة (الأوضاع + شجرة الوحدات/الدروس) — النسخة الثالثة
  static String capabilities(String subject, int grade, String track) =>
      "$_base/content/capabilities?subject=$subject&grade=$grade&track=$track";

  // 🎓 المنح — قائمة محكومة ببروتوكول النسخة ([32§4]).
  //    `version < 0` يعني «لا نسخة عندي، أرسل كل شيء».
  static String scholarships(int version) =>
      "$_base/scholarships${version >= 0 ? '?version=$version' : ''}";

  static String scholarship(String id) => "$_base/scholarships/$id";

  // 🖼️ الغلاف منفصل عن القائمة — يُجلب عند فتح شاشة المنحة وحدها.
  static String scholarshipCover(String id) => "$_base/scholarships/$id/cover";

  // 💬 مساعد المنحة
  static String scholarshipAskStream() =>
      "$_base/scholarship/ask/stream";

  static String scholarshipAsk() => "$_base/scholarship/ask";

  // 👨‍🏫 مساعد المعلم — أدوات المعلم ومحادثاتها.
  //    نقطة واحدة للتوليد والمتابعة معاً؛ الفرق حقلٌ في الجسم (`generate`)
  //    لا مسارٌ ثانٍ — فالمحادثة واحدة والسياق واحد.
  static String teacherAsk() => "$_base/teacher/ask";

  /// 🌊 نسخة البثّ — نفس الحرّاس، والشاشة واحدة فلا سبب لتجربتين.
  static String teacherAskStream() => "$_base/teacher/ask/stream";

  // الرياضيات
  static String mathLessons(String branch, int grade, String track) =>
      "$_base/math/lessons?branch=$branch${_scope(grade, track)}";

  static String mathExamYears(String branch, int grade, String track) =>
      "$_base/math/exams/years?branch=$branch${_scope(grade, track)}";

  static String mathExamLessons(String branch, String year, int grade, String track) =>
      "$_base/math/exams/lessons?branch=$branch&year=$year${_scope(grade, track)}";
}
