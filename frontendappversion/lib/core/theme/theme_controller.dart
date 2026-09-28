import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// ثلاث حالات لا اثنتان: «اتبع النظام» خيارٌ متاحٌ لمن يريده.
/// ☀️ **قرار المالك (٢٠٢٦-٠٩-٢٧):** الافتراضيُّ **فاتح** لا «حسب النظام» —
///    جهازٌ داكن لا يجعل التطبيق داكناً في أول تشغيل؛ الطالبُ يغيّره بنفسه.
enum AppThemeMode { system, light, dark }

// ==========================================
// 🌗 core/theme/theme_controller.dart — مالك قرار الوضع
// ==========================================
// ⚠️ **علّة أُصلحت:** الوضع لم يكن يُحفظ إطلاقاً. `bootstrap` كان يقرأ
//    المفتاح `isDarkMode` من التخزين، لكن **لا أحد يكتبه** — فمفتاح
//    الإعدادات يبدّل الشاشة، ثم يعود التطبيق فاتحاً بعد أول إغلاق.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final ThemeController I = ThemeController._();

  static const _kMode = 'theme_mode';

  static const defaultMode = AppThemeMode.light;

  AppThemeMode _mode = defaultMode;
  Brightness _systemBrightness = Brightness.light;

  AppThemeMode get mode => _mode;

  bool get isDark => switch (_mode) {
        AppThemeMode.dark => true,
        AppThemeMode.light => false,
        AppThemeMode.system => _systemBrightness == Brightness.dark,
      };

  String get label => switch (_mode) {
        AppThemeMode.dark => 'داكن',
        AppThemeMode.light => 'فاتح',
        AppThemeMode.system => 'حسب النظام',
      };

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final saved = p.getString(_kMode);
    _mode = switch (saved) {
      'light' => AppThemeMode.light,
      'dark' => AppThemeMode.dark,
      'system' => AppThemeMode.system,
      // 🕰️ ترحيل المفتاح القديم (bool) — من فعّل الوضع سابقاً لا يفقده.
      //    ومن لم يختر شيئاً قطّ ⇒ الفاتح، ولو كان جهازه داكناً.
      _ => (p.getBool('isDarkMode') ?? false) ? AppThemeMode.dark : defaultMode,
    };
    _apply();
  }

  Future<void> setMode(AppThemeMode value) async {
    _mode = value;
    _apply();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kMode, value.name);
  }

  /// يصل من `MediaQuery.platformBrightnessOf` عند كل تغيّر في النظام.
  /// ⚠️ لا يُحفظ: هذه حالة الجهاز لا اختيار الطالب.
  void setSystemBrightness(Brightness value) {
    if (_systemBrightness == value) return;
    _systemBrightness = value;
    if (_mode == AppThemeMode.system) _apply();
  }

  void _apply() {
    final dark = isDark;
    if (isDarkModeNotifier.value != dark) isDarkModeNotifier.value = dark;
    notifyListeners();
  }
}
