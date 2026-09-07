import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_colors.dart';

/// ثلاث حالات لا اثنتان: «اتبع النظام» هو ما يتوقّعه مستخدم الهاتف اليوم،
/// وغيابه يجبره على تبديل التطبيق يدوياً كلما تبدّل جهازه ليلاً.
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

  AppThemeMode _mode = AppThemeMode.system;
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
      _ => (p.getBool('isDarkMode') ?? false)
          ? AppThemeMode.dark
          : AppThemeMode.system,
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
