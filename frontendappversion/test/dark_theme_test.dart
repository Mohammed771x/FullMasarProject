// 🧪 قواعد اللوحة الداكنة.
//
// هذه ليست اختبارات تجميل: كل واحد منها يحرس علّةً وقعت فعلاً وقيل عنها
// «واضح إنه AI». اللون يُكسر بصمت — لا يرمي استثناءً ولا يُسقط اختباراً
// وظيفياً — فالحارس الوحيد أن تُقاس القاعدة رقمياً.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/theme/app_colors.dart';

/// إضاءة نسبية (WCAG).
double _lum(Color c) {
  double ch(double v) => v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
}

double contrast(Color a, Color b) {
  final l1 = _lum(a), l2 = _lum(b);
  final hi = math.max(l1, l2), lo = math.min(l1, l2);
  return (hi + 0.05) / (lo + 0.05);
}

void withMode(bool dark, void Function() body) {
  final previous = isDarkModeNotifier.value;
  isDarkModeNotifier.value = dark;
  try {
    body();
  } finally {
    isDarkModeNotifier.value = previous;
  }
}

void main() {
  group('① سُلّم الأسطح — القاعدة نفسها في الوضعين', () {
    // 🔴 العلّة: في الداكن كان الغائر (#334155) **أفتح** من البطاقة
    //    (#1E293B)، فيبدو العنصر المنخفض مرتفعاً وينقلب منطق الواجهة.
    for (final dark in [false, true]) {
      test(dark ? 'الداكن' : 'الفاتح', () {
        withMode(dark, () {
          final sunken = _lum(AppColors.softSurface);
          final card = _lum(AppColors.surfaceWhite);
          final raised = _lum(AppColors.elevatedSurface);
          expect(sunken, lessThan(card), reason: 'الغائر يجب أن يكون أغمق من البطاقة');
          expect(raised, greaterThanOrEqualTo(card), reason: 'المرتفع لا يكون أغمق من البطاقة');
        });
      });
    }
  });

  group('② الفصل بين الأسطح مرئي', () {
    test('🌙 حدّ البطاقة يُرى على السطح الداكن', () {
      withMode(true, () {
        // الظلّ الأسود لا يعمل على خلفية داكنة، فالحدّ هو ما يحمل الفصل.
        expect(contrast(AppColors.border, AppColors.surfaceWhite),
            greaterThan(1.2));
        expect(contrast(AppColors.border, AppColors.bgLight), greaterThan(1.2));
      });
    });
  });

  group('③ لون الهوية يتغيّر بين الوضعين', () {
    test('🔴 العلّة: كان اللون نفسه في الوضعين', () {
      late Color light, dark;
      withMode(false, () => light = AppColors.primary);
      withMode(true, () => dark = AppColors.primary);
      expect(dark, isNot(light), reason: 'الأزرق المشبع يهتزّ على خلفية داكنة');
      expect(_lum(dark), greaterThan(_lum(light)), reason: 'الداكن يحتاج لوناً أفتح');
    });

    test('التدرّج يتغيّر أيضاً ويحمل نصّاً أبيض بتباين كافٍ', () {
      withMode(true, () {
        for (final c in AppColors.mainGradient.colors) {
          expect(contrast(Colors.white, c), greaterThanOrEqualTo(4.5),
              reason: 'النصّ فوق التدرّج أبيض دائماً');
        }
      });
    });
  });

  group('④ تباين النصّ في الوضع الداكن', () {
    test('الأساسي مقروء بلا هالة', () {
      withMode(true, () {
        final onCard = contrast(AppColors.textPrimary, AppColors.surfaceWhite);
        expect(onCard, greaterThanOrEqualTo(7));
        // ⚠️ سقفٌ مقصود: الأبيض الناصع على شبه الأسود يُتعب العين في
        //    القراءة الطويلة، وهذه شاشة درسٍ لا شاشة تنبيه.
        expect(contrast(AppColors.textPrimary, AppColors.bgLight), lessThan(16));
      });
    });

    test('الثانوي فوق كل سطح يتجاوز 4.5', () {
      withMode(true, () {
        for (final bg in [
          AppColors.bgLight,
          AppColors.surfaceWhite,
          AppColors.softSurface,
          AppColors.elevatedSurface,
        ]) {
          expect(contrast(AppColors.textSecondary, bg),
              greaterThanOrEqualTo(4.5));
        }
      });
    });

    test('لون الهوية مقروء نصّاً على كل سطح داكن', () {
      withMode(true, () {
        for (final bg in [AppColors.bgLight, AppColors.surfaceWhite]) {
          expect(contrast(AppColors.primary, bg), greaterThanOrEqualTo(4.5));
        }
      });
    });
  });

  group('⑤ الأقراص البيضاء فوق التدرّجات', () {
    test('🔴 نصُّها لا يتبع الوضع — القرص أبيضُ في الحالتين', () {
      // العلّة: كان يستعمل `primary`، فتباينه على الأبيض 3.7:1 في الفاتح،
      // وهبط إلى 2.7:1 بعد تفتيح اللون للوضع الداكن.
      for (final dark in [false, true]) {
        withMode(dark, () {
          expect(contrast(AppColors.onWhite, Colors.white),
              greaterThanOrEqualTo(4.5));
        });
      }
    });
  });

  group('⑥ اللوحة ليست مقياس Tailwind الجاهز', () {
    test('لا قيمة داكنة تطابق رمزاً افتراضياً', () {
      // 🔴 العلّة الأصلية: 9 من 9 قيم كانت رموز Tailwind بلا تعديل، وهي
      //    بصمة القوالب الجاهزة التي يلمحها المصمّم من أول نظرة.
      const tailwind = <int>[
        0xFF0F172A, 0xFF1E293B, 0xFF334155, 0xFF475569,
        0xFF94A3B8, 0xFF64748B, 0xFFF1F5F9, 0xFFF8FAFC,
        0xFF3B82F6, 0xFF8B5CF6,
      ];
      withMode(true, () {
        final palette = <Color>[
          AppColors.bgLight,
          AppColors.surfaceWhite,
          AppColors.softSurface,
          AppColors.elevatedSurface,
          AppColors.border,
          AppColors.textPrimary,
          AppColors.textSecondary,
          AppColors.primary,
          AppColors.secondary,
        ];
        for (final c in palette) {
          expect(tailwind.contains(c.toARGB32()), isFalse,
              reason: '${c.toARGB32().toRadixString(16)} رمزٌ جاهز بلا تعديل');
        }
      });
    });
  });
}
