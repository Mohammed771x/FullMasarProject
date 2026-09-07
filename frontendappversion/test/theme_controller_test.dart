// 🧪 حفظ الوضع و«اتبع النظام».
//
// 🔴 العلّة: `bootstrap` كان يقرأ مفتاح `isDarkMode` من التخزين، لكن **لا
//    أحد يكتبه** — فمفتاح الإعدادات يبدّل الشاشة، ثم يعود التطبيق فاتحاً
//    بعد أول إغلاق.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ye_student_tutor/core/theme/app_colors.dart';
import 'package:ye_student_tutor/core/theme/theme_controller.dart';

void main() {
  final c = ThemeController.I;

  test('🔴 العلّة: الاختيار ينجو من إعادة التشغيل', () async {
    SharedPreferences.setMockInitialValues({});
    await c.load();
    await c.setMode(AppThemeMode.dark);

    // إقلاع جديد يقرأ ما كُتب فعلاً.
    await c.load();
    expect(c.mode, AppThemeMode.dark);
    expect(isDarkModeNotifier.value, isTrue);
  });

  test('🕰️ ترحيل المفتاح القديم — من فعّل الوضع سابقاً لا يفقده', () async {
    SharedPreferences.setMockInitialValues({'isDarkMode': true});
    await c.load();
    expect(c.mode, AppThemeMode.dark);
  });

  test('بلا تخزين سابق ⇒ يتبع النظام لا يفرض الفاتح', () async {
    SharedPreferences.setMockInitialValues({});
    await c.load();
    expect(c.mode, AppThemeMode.system);
  });

  test('«حسب النظام» يتبدّل مع إضاءة الجهاز', () async {
    SharedPreferences.setMockInitialValues({});
    await c.load();
    await c.setMode(AppThemeMode.system);

    c.setSystemBrightness(Brightness.dark);
    expect(isDarkModeNotifier.value, isTrue);
    c.setSystemBrightness(Brightness.light);
    expect(isDarkModeNotifier.value, isFalse);
  });

  test('الاختيار الصريح لا يعبث به النظام', () async {
    SharedPreferences.setMockInitialValues({});
    await c.load();
    await c.setMode(AppThemeMode.light);

    c.setSystemBrightness(Brightness.dark);
    expect(isDarkModeNotifier.value, isFalse, reason: 'اختيار الطالب أعلى');
  });

  test('إضاءة النظام لا تُحفظ — حالة جهاز لا اختيار طالب', () async {
    SharedPreferences.setMockInitialValues({});
    await c.load();
    await c.setMode(AppThemeMode.system);
    c.setSystemBrightness(Brightness.dark);

    final p = await SharedPreferences.getInstance();
    expect(p.getString('theme_mode'), 'system');
  });
}
