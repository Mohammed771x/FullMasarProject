import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// ==========================================
// 🎨 ثيم التطبيق (يبني ThemeData بناءً على الوضع)
// ==========================================
class AppTheme {
  static ThemeData build({required bool isDark}) {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bgLight,
      textTheme: GoogleFonts.cairoTextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.bgLight,
        brightness: isDark ? Brightness.dark : Brightness.light, // 👈 مهم جداً
      ),
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}
