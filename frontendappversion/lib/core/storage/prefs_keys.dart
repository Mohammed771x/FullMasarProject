// ==========================================
// 🗝️ مفاتيح SharedPreferences (مجمّعة لتفادي الأخطاء الإملائية)
// ==========================================
class PrefsKeys {
  PrefsKeys._();

  static const String isFirstRun = 'isFirstRun';
  static const String isDarkMode = 'isDarkMode';
  static const String deviceId = 'device_id'; // (قديم) للترحيل إلى التخزين الآمن
  /// مفتاح ظهور التعليمات — مرتبط بالصف والمسار أيضاً، لأن تعليمات
  /// "احياء الأول" غير تعليمات "احياء الثالث".
  static String instructionShown(int grade, String track, String subject) =>
      'instruction_shown_g${grade}_${track}_$subject';

  /// 👨‍🏫 تعليمات أداة المعلم — **بلا صف ولا مسار ولا مادة**: التعليمات هنا
  ///    تشرح الأداة نفسها، وهي واحدة في كل المواد (طلب المالك). فربطُها
  ///    بالصف كان سيعيد عرضها كلما بدّل المعلّم صفاً بلا جديد يقوله.
  static String teacherInstructionShown(String tool) =>
      'teacher_instruction_shown_$tool';
}
