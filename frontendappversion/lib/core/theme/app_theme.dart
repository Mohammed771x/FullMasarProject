import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

// ==========================================
// 🎨 ثيم التطبيق
// ==========================================
// ⚠️ **لماذا كلّ هذه الأقسام بدل أربعة أسطر؟**
//    ما لا يُصرَّح به هنا ترسمه Material 3 بألوانها المشتقّة من البذرة — فتظهر
//    حوارات وقوائم وشرائح **بأرجوانٍ باهت لا علاقة له بهوية التطبيق**، وهو
//    أظهر ما يُقال عنه «واجهة قالبٍ جاهز». الوضع الداكن يفضح هذا أكثر لأن
//    أسطح M3 الافتراضية هناك أفتح من أسطحنا.
class AppTheme {
  static ThemeData build({required bool isDark}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: isDark ? Brightness.dark : Brightness.light,
    ).copyWith(
      // نفرض أسطحنا على المشتقّ من البذرة — سُلّمنا مقصود لا عشوائي.
      surface: AppColors.surfaceWhite,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.softSurface,
      surfaceContainer: AppColors.elevatedSurface,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    final text = GoogleFonts.cairoTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ).apply(bodyColor: AppColors.textPrimary, displayColor: AppColors.textPrimary);

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: AppColors.bgLight,
      canvasColor: AppColors.bgLight,
      colorScheme: scheme,
      textTheme: text,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),

      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceWhite,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent, // 🚫 صبغة M3 التي تُزرِقّ البار
        elevation: 0,
      ),

      // 🌙 الحوار سطحٌ **مرتفع** لا بطاقة: بلا ذلك يذوب في الخلفية الداكنة.
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.elevatedSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.elevatedSurface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.elevatedSurface,
        surfaceTintColor: Colors.transparent,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.bgLight,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.elevatedSurface,
        contentTextStyle: TextStyle(
            color: AppColors.textPrimary, fontWeight: FontWeight.bold),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // الحقل سطحٌ **غائر** — وهذا ما يجعله يُقرأ كمكان كتابة لا كبطاقة.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.softSurface,
        hintStyle: TextStyle(color: AppColors.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? AppColors.primary : null),
        trackColor: WidgetStateProperty.resolveWith((s) =>
            s.contains(WidgetState.selected)
                ? AppColors.primary.withValues(alpha: 0.35)
                : AppColors.softSurface),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: AppColors.primary,
        inactiveTrackColor: AppColors.softSurface,
        thumbColor: AppColors.primary,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceWhite,
        selectedColor: AppColors.primary,
        side: BorderSide(color: AppColors.border),
        labelStyle: TextStyle(color: AppColors.textSecondary),
      ),
      listTileTheme: ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.primary,
      ),
      iconTheme: IconThemeData(color: AppColors.textPrimary),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.softSurface,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primary.withValues(alpha: 0.28),
        selectionHandleColor: AppColors.primary,
      ),
    );
  }
}
