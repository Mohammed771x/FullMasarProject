// 🌗 الوضع الداكن في شاشتَي الترحيب والدخول.
//
// 🔴 **العلّة الجذرية التي أنتجت كل الأعطال:** لونٌ ثابتٌ مكتوبٌ في الشاشة
//    بدل أن يُقرأ من [AppColors]. فخلفيةٌ فاتحة ثابتة (`#F3F7FD`) مع بطاقاتٍ
//    تتبع الوضع = بطاقةٌ داكنة تطفو على صفحةٍ بيضاء. وحبرٌ داكن ثابت
//    (`kNavy`) على حقلٍ داكن = **نصٌّ لا يُرى أصلاً وأنت تكتبه**.
//
// ولذلك الاختبارات هنا تقيس **التباين** لا أسماء الألوان: القاعدة هي أن
// يُقرأ النصّ، لا أن يُسمّى اللون اسماً بعينه.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/theme/app_colors.dart';

/// نسبة التباين حسب WCAG — الأداة التي تحسم «هل يُقرأ؟» بلا ذوق.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double channel(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    // `r/g/b` كسورٌ من ٠ إلى ١ في فلاتر الحديثة.
    return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  }

  final l1 = lum(a), l2 = lum(b);
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  tearDown(() => isDarkModeNotifier.value = false);

  void dark() => isDarkModeNotifier.value = true;
  void light() => isDarkModeNotifier.value = false;

  group('🔴 الحبر يجب أن يُقرأ على سطحه في الوضعين', () {
    test('نصّ حقل الإدخال على أرضية الحقل', () {
      // ⚠️ الأسوأ على الإطلاق: كان `kNavy` داكناً على حقلٍ داكن، فيكتب
      //    الطالب بريده ولا يرى حرفاً. الحقل يستعمل `softSurface`.
      for (final isDark in [false, true]) {
        isDarkModeNotifier.value = isDark;
        final ratio = _contrast(AppColors.brandInk, AppColors.softSurface);
        expect(ratio, greaterThan(4.5),
            reason: 'حبر الحقل في وضع ${isDark ? "داكن" : "فاتح"}: $ratio');
      }
    });

    test('عنوان بطاقة الترحيب على سطح البطاقة', () {
      for (final isDark in [false, true]) {
        isDarkModeNotifier.value = isDark;
        expect(_contrast(AppColors.brandInk, AppColors.surfaceWhite),
            greaterThan(4.5));
      }
    });

    test('نصّ الصفحة العادي على خلفية الصفحة', () {
      for (final isDark in [false, true]) {
        isDarkModeNotifier.value = isDark;
        expect(_contrast(AppColors.textPrimary, AppColors.bgLight),
            greaterThan(4.5));
      }
    });

    test('النصّ الثانوي («تخطي») على خلفية الصفحة', () {
      for (final isDark in [false, true]) {
        isDarkModeNotifier.value = isDark;
        expect(_contrast(AppColors.textSecondary, AppColors.bgLight),
            greaterThan(3.0));
      }
    });
  });

  group('🎯 التعبئة التي تحمل نصّاً أبيض', () {
    test('الشارة المختارة (صف · مسار) يُقرأ نصُّها الأبيض', () {
      // 🔴 كانت تستعمل `primary`/`secondary` — وهما مُفتَّحان ليُقرآ **كنصّ**،
      //    فوضعُ أبيضَ فوقهما يعكس الدور ويهبط بالتباين إلى ٢٫٦:١.
      for (final isDark in [false, true]) {
        isDarkModeNotifier.value = isDark;
        expect(_contrast(Colors.white, AppColors.primaryFill), greaterThan(3.0),
            reason: 'شارة الصف في وضع ${isDark ? "داكن" : "فاتح"}');
        expect(_contrast(Colors.white, AppColors.secondaryFill), greaterThan(3.0),
            reason: 'شارة المسار في وضع ${isDark ? "داكن" : "فاتح"}');
      }
    });

    test('زرّ الدخول يُقرأ نصُّه الأبيض على طرفَي التدرّج', () {
      for (final isDark in [false, true]) {
        isDarkModeNotifier.value = isDark;
        for (final c in AppColors.primaryButton.colors) {
          expect(_contrast(Colors.white, c), greaterThan(3.0));
        }
      }
    });
  });

  group('🌗 كل رمزٍ بصريّ يتبدّل فعلاً بين الوضعين', () {
    test('لا لونَ ثابتاً تسلّل إلى الرموز المشتركة', () {
      // ⚠️ اختبارُ «هل تبدّل؟» يمسك اللونَ الثابت المنسيّ: قيمةٌ لا تتغيّر
      //    بين الوضعين هي بالضبط ما كان يُنتج نصفَ شاشةٍ فاتحة.
      light();
      final l = {
        'bgLight': AppColors.bgLight,
        'surfaceWhite': AppColors.surfaceWhite,
        'softSurface': AppColors.softSurface,
        'border': AppColors.border,
        'textPrimary': AppColors.textPrimary,
        'brandInk': AppColors.brandInk,
        'primaryFill': AppColors.primaryFill,
        'waveTint': AppColors.waveTint,
      };
      dark();
      final d = {
        'bgLight': AppColors.bgLight,
        'surfaceWhite': AppColors.surfaceWhite,
        'softSurface': AppColors.softSurface,
        'border': AppColors.border,
        'textPrimary': AppColors.textPrimary,
        'brandInk': AppColors.brandInk,
        'primaryFill': AppColors.primaryFill,
        'waveTint': AppColors.waveTint,
      };
      for (final key in l.keys) {
        expect(d[key], isNot(l[key]), reason: '«$key» لا يتبدّل بين الوضعين');
      }
    });

    test('سُلّم الأسطح يبقى صحيحاً في الداكن: الغائر أغمق والمرتفع أفتح', () {
      dark();
      double lum(Color c) => 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
      expect(lum(AppColors.softSurface), lessThan(lum(AppColors.surfaceWhite)));
      expect(lum(AppColors.elevatedSurface), greaterThan(lum(AppColors.surfaceWhite)));
    });
  });

  group('🌗 ThemeScope يُعيد البناء عند التبدّل', () {
    testWidgets('الخلفية تتبع الوضع بلا إعادة فتح الشاشة', (tester) async {
      light();
      await tester.pumpWidget(MaterialApp(
        home: ThemeScope(
          builder: (_) => Scaffold(backgroundColor: AppColors.bgLight),
        ),
      ));
      Color bg() => (tester.widget<Scaffold>(find.byType(Scaffold))).backgroundColor!;
      final before = bg();

      dark();
      await tester.pump();
      // ⭐ بلا هذا كانت الشاشة المدفوعة تبقى بلون الوضع السابق: تتغيّر
      //    حدود الحقول (من `Theme`) وتبقى الخلفية — نصفُ شاشةٍ داكنة.
      expect(bg(), isNot(before));
      expect(bg(), AppColors.bgLight);
    });
  });
}
