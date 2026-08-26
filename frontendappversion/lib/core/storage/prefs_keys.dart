// ==========================================
// 🗝️ مفاتيح SharedPreferences (مجمّعة لتفادي الأخطاء الإملائية)
// ==========================================
class PrefsKeys {
  PrefsKeys._();

  static const String isFirstRun = 'isFirstRun';
  static const String isDarkMode = 'isDarkMode';
  static const String deviceId = 'device_id'; // (قديم) للترحيل إلى التخزين الآمن
  static String instructionShown(String subject) => 'instruction_shown_$subject';
}
