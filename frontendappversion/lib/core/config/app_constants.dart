// ==========================================
// 📌 ثوابت التطبيق (المواد، الأوضاع، الفروع...)
// ==========================================
class AppConstants {
  AppConstants._();

  // المواد الدراسية
  static const List<String> subjects = [
    "احياء",
    "فيزياء",
    "كيمياء",
    "عربي",
    "انجليزي",
    "رياضيات",
  ];

  // أوضاع المواد العامة
  static const List<String> generalModes = ["شرح", "تلخيص", "سؤال", "وزاري"];

  // أوضاع الرياضيات
  static const List<String> mathModes = ["شرح", "سؤال", "وزاري"];

  // فروع الرياضيات
  static const List<String> mathBranches = [
    "تفاضل",
    "تكامل",
    "جبر",
    "هندسة",
    "احتمالات",
  ];

  // أقسام الوزاري للعربي
  static const List<String> arabicExamSections = [
    "أولاً: القراءة",
    "ثانياً: الأدب والنصوص والنقد",
    "ثالثاً: النحو والصرف",
    "رابعاً: التعبير",
  ];

  // أنواع أسئلة الوزاري للعربي
  static const List<String> arabicExamTypes = ["قطعة", "أسئلة عامة"];
}
