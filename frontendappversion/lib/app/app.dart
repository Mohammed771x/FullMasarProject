import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';

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
          title: 'منصة مسار',
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
          theme: AppTheme.build(isDark: isDark),
          home: home,
        );
      },
    );
  }
}
