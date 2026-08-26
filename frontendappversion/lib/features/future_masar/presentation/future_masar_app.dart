import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import 'screens/splash_screen.dart';

// ==========================================
// 🌟 جذر ديمو "مسار المستقبل" (مستقل تماماً عن التطبيق الأصلي)
// ==========================================
class FutureMasarApp extends StatelessWidget {
  const FutureMasarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'مسار المستقبل — Demo',
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          theme: AppTheme.build(isDark: isDark),
          home: const SplashScreen(),
        );
      },
    );
  }
}
