import 'package:flutter/material.dart';

// 🌙 ريموت التحكم بالوضع الداكن (Global Notifier)
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);

// ==========================================
// 🎨 نظام الألوان الذكي (يدعم الفاتح والداكن)
// ==========================================
class AppColors {
  // الألوان الأساسية (لا تتغير)
  static const Color primary = Color(0xFF3B82F6);
  static const Color secondary = Color(0xFF8B5CF6);

  static const LinearGradient mainGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bubbleGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  // 🌙 الألوان المتغيرة بناءً على الوضع
  static Color get bgLight => isDarkModeNotifier.value ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  static Color get surfaceWhite => isDarkModeNotifier.value ? const Color(0xFF1E293B) : const Color(0xFFFFFFFF);
  static Color get softSurface => isDarkModeNotifier.value ? const Color(0xFF334155) : const Color(0xFFF1F5F9);

  static Color get textPrimary => isDarkModeNotifier.value ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  static Color get textSecondary => isDarkModeNotifier.value ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

  // الظلال
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: isDarkModeNotifier.value ? Colors.black.withValues(alpha: 0.3) : primary.withValues(alpha: 0.12),
      blurRadius: 30,
      offset: const Offset(0, 10),
    )
  ];

  static List<BoxShadow> get bubbleShadow => [
    BoxShadow(
      color: isDarkModeNotifier.value ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
      blurRadius: 15,
      offset: const Offset(0, 4),
    )
  ];
}
