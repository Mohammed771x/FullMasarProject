import 'package:flutter/material.dart';

import '../core/notifications/push_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';

// ==========================================
// 🌟 جذر التطبيق (MaterialApp + الثيم + RTL + الوضع الداكن)
// ==========================================
class MasarApp extends StatelessWidget {
  final Widget home;
  const MasarApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          // 🧭 لازمٌ لنقر الإشعار: الوجهة تُفتح بلا `context` شاشة، لأن
          //    النقرة قد تصل والتطبيق مغلقٌ تماماً أو على شاشةٍ عميقة.
          navigatorKey: masarNavigatorKey,
          title: 'منصة مسار',
          builder: (context, child) => _SystemBrightnessBridge(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          theme: AppTheme.build(isDark: isDark),
          home: home,
        );
      },
    );
  }
}

/// يوصّل إضاءة النظام إلى `ThemeController` ليعمل خيار «حسب النظام».
///
/// ⚠️ داخل `builder` لا فوق `MaterialApp`: هنا وحده يوجد `MediaQuery` يعيد
///    البناء عند تبديل الجهاز إلى الليل، فيتبعه التطبيق فوراً بلا إعادة فتح.
class _SystemBrightnessBridge extends StatelessWidget {
  const _SystemBrightnessBridge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ThemeController.I.setSystemBrightness(brightness),
    );
    return child;
  }
}
