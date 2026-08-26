import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/storage/chat_storage.dart';
import '../core/storage/prefs_keys.dart';
import '../core/theme/app_colors.dart';
import '../features/chat/presentation/screens/main_chat_screen.dart';
import '../features/onboarding/presentation/welcome_screen.dart';

// ==========================================
// 🚀 تهيئة التطبيق وتحديد الشاشة الأولى
// ==========================================
class AppBootstrap {
  AppBootstrap._();

  /// يهيّئ الخدمات ويعيد الشاشة المناسبة للإقلاع.
  static Future<Widget> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
    );

    await ChatStorage.init();

    final prefs = await SharedPreferences.getInstance();
    final bool isFirstRun = prefs.getBool(PrefsKeys.isFirstRun) ?? true;
    isDarkModeNotifier.value = prefs.getBool(PrefsKeys.isDarkMode) ?? false;

    // 🔻 حُذف نظام التفعيل بالكامل: لم نعد نتحقق من isActivated.
    // أول تشغيل → شاشة الترحيب، وبعدها → الشاشة الرئيسية مباشرة.
    return isFirstRun ? const AnimatedWelcomeScreen() : const MainChatScreen(showDrawerHelp: false);
  }
}
