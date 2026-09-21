// 🧪 قواعد اللوحة الداكنة.
//
// هذه ليست اختبارات تجميل: كل واحد منها يحرس علّةً وقعت فعلاً وقيل عنها
// «واضح إنه AI». اللون يُكسر بصمت — لا يرمي استثناءً ولا يُسقط اختباراً
// وظيفياً — فالحارس الوحيد أن تُقاس القاعدة رقمياً.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/theme/app_colors.dart';
import 'package:ye_student_tutor/features/future_masar/presentation/widgets/analysis_ui.dart';

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

  // ══════════════════════════════════════════════════
  // ⑦ لوحة «اختبر نفسك» — الوضع الداكن اشتُقّ ولم يُرسَم
  // ══════════════════════════════════════════════════
  //
  // 🎨 المصمّم رسم الفاتح وحده. فكلُّ قيمةٍ داكنةٍ هنا **استنتاجٌ منّي**،
  //    وأخطرُ ما في الاستنتاج أن يمرّ بلا قياس: لونٌ نُسخ من الفاتح إلى
  //    الداكن يبقى صحيحاً في `analyze` وفي كل اختبارٍ وظيفي — ولا يُرى
  //    إلا في يد الطالب.
  //
  // ⚠️ **والنصّ يُقاس، لا الزينة.** أرقامُ بطاقات الإحصاء في التصميم
  //    ملوّنةٌ على تعبئةٍ باهتة بنسبٍ منخفضة — وهذا اختيارُ المصمّم في
  //    عنصرٍ ضخمٍ زخرفي، فلا يُقاس بمقياس نصّ القراءة. المقيسُ هنا ما
  //    يُقرأ فعلاً: حبرُ الشرائح والشارات والعناوين.
  group('⑦ لوحة «اختبر نفسك»', () {
    test('حبرُ الشريحة والصفّ مقروءٌ على تعبئته في الوضعين', () {
      for (final dark in [false, true]) {
        withMode(dark, () {
          expect(contrast(AppColors.chipInk, AppColors.quizChipFill),
              greaterThanOrEqualTo(4.5));
          expect(contrast(AppColors.panelTitle, AppColors.surfaceWhite),
              greaterThanOrEqualTo(4.5));
          // الشريحةُ المختارة: حبرُ الهوية على سطحه الباهت.
          //
          // ⚠️ **عتبتان لا واحدة.** الفاتحُ زوجٌ **من التصميم نفسه**
          //    (`#0092FF` على `#E6F4FF` = 2.86) — لا أرفعه فأخالف ما
          //    قِسته، وأحرسُ ألّا يهبط. والداكنُ **من عندي**، فلا عذر
          //    له دون 4.5.
          expect(contrast(AppColors.primary, AppColors.quizTint),
              greaterThanOrEqualTo(dark ? 4.5 : 2.85));
        });
      }
    });

    test('شارةُ «تم اختيار ن» وشارةُ الموضوع تُقرآن', () {
      for (final dark in [false, true]) {
        withMode(dark, () {
          // ⚠️ الفاتحُ زوجُ التصميم (`#155DFC` على `#D4E4FE` = 4.08).
          expect(contrast(AppColors.quizBadgeInk, AppColors.quizBadgeFill),
              greaterThanOrEqualTo(dark ? 4.5 : 4.0));
          // 🏷️ وهذه بالذات: حبرُ التصدير `#FFD541` نسبتُه 1.5:1 — استُبدل
          //    بكهرمان المصمّم الغامق. الحارسُ يمنع عودتَه.
          expect(contrast(AppColors.quizTagInk, AppColors.quizTagFill),
              greaterThanOrEqualTo(4.5));
        });
      }
    });

    test('نصُّ الصندوق الملوّن كحليٌّ لا ملوّن — فيُقرأ على تعبئته', () {
      for (final dark in [false, true]) {
        withMode(dark, () {
          for (final fill in [
            AppColors.quizRightFill,
            AppColors.quizWrongFill,
          ]) {
            expect(contrast(AppColors.panelTitle, fill),
                greaterThanOrEqualTo(4.5));
            expect(contrast(AppColors.textPrimary, fill),
                greaterThanOrEqualTo(4.5));
          }
        });
      }
    });

    test('🌙 الأسطح الداكنة متدرّجة والحدود تُرى', () {
      withMode(true, () {
        // الغائرُ أغمقُ من البطاقة — نفسُ قاعدة المجموعة ①.
        expect(_lum(AppColors.quizChipFill),
            lessThan(_lum(AppColors.surfaceWhite)));
        expect(_lum(AppColors.quizOptionFill),
            lessThan(_lum(AppColors.surfaceWhite)));
        // والظلُّ لا يُرى على الأسود، فالحدُّ وحده يفصل.
        expect(contrast(AppColors.quizCardBorder, AppColors.surfaceWhite),
            greaterThan(1.2));
        expect(contrast(AppColors.quizChipBorder, AppColors.quizChipFill),
            greaterThan(1.1));
      });
    });

    test('ألوانُ الحالة تُفتَّح في الداكن ولا تبقى كما هي', () {
      for (final token in <Color Function()>[
        () => AppColors.quizWrong,
        () => AppColors.quizPink,
        () => AppColors.quizSky,
        () => AppColors.quizEmerald,
        () => AppColors.quizTagInk,
      ]) {
        late Color light, dark;
        withMode(false, () => light = token());
        withMode(true, () => dark = token());
        expect(_lum(dark), greaterThan(_lum(light)),
            reason: 'لونُ حالةٍ لم يُفتَّح للخلفية الداكنة');
      }
    });

    test('الزرُّ الأساسي — أبيضُه مقروءٌ ممتلئاً ومعطَّلاً', () {
      for (final dark in [false, true]) {
        withMode(dark, () {
          // ⚠️ **هذا بالضبط ما سقط في المحاكي**: الزرُّ كان يأخذ
          //    `primary` (الأزرقَ المفتَّح للقراءة) فصار أبيضُه 2.1:1.
          expect(contrast(Colors.white, AppColors.primaryFill),
              greaterThanOrEqualTo(3));
          // وفي الداكن وحده يفترقان: هناك يُفتَّح `primary` للقراءة
          // ويُعمَّق `primaryFill` ليَحمل. (في الفاتح هما لونٌ واحد.)
          if (dark) {
            expect(contrast(Colors.white, AppColors.primary),
                lessThan(contrast(Colors.white, AppColors.primaryFill)),
                reason: 'الأزرقُ المفتَّح لا يحمل نصّاً أبيض — '
                    'لا تستعمله تعبئةَ زرّ');
          }
          // ⚠️ المعطَّلُ في التصميم `#B0DDFF` بحبرٍ أبيض — نسبةٌ متعمَّدة
          //    منخفضة تقول «ينتظر منك شيئاً». نحرسُ ألّا تهبط أكثر.
          expect(contrast(Colors.white, AppColors.quizButtonIdle),
              greaterThanOrEqualTo(1.4));
        });
      }
    });
  });

  // ══════════════════════════════════════════════════
  // ⑨ «معلومات الطالب / تحليل مستواي» — من `03-home/22-معلومات`
  // ══════════════════════════════════════════════════
  //
  // 🎨 المصمّم رسم الفاتح وحده هنا أيضاً، وأكثرُ ألوانه من سلالم المشروع
  //    (`#3C65CA` = `secondary500` · الحلقةُ `success500`/`primary500`).
  //    فالحارسُ: هل يُقرأ ما كُتب على كلِّ سطح — في الوضعين.
  group('⑨ لوحة «معلومات الطالب»', () {
    test('نصُّ البطاقة الكحليّة أبيضُ مقروء', () {
      for (final dark in [false, true]) {
        withMode(dark, () {
          expect(contrast(Colors.white, AppColors.analysisNavy),
              greaterThanOrEqualTo(4.5));
        });
      }
    });

    test('شارةُ النسبة الحمراء تُقرأ على تعبئتها', () {
      for (final dark in [false, true]) {
        withMode(dark, () {
          // ⚠️ **التعبئةُ شفّافةٌ في الداكن** (`error500` بشفافية 0.16)،
          //    فقياسُها كما هي يعطي 1.0 كاذبة. تُركَّب على سطحها أولاً.
          expect(
              contrast(
                  AppColors.error500,
                  Color.alphaBlend(
                      AppColors.errorTint, AppColors.surfaceWhite)),
              greaterThanOrEqualTo(3.0));
          // «التفاصيل» على سطحه الرمادي.
          expect(contrast(AppColors.rowAction, AppColors.softSurface),
              greaterThanOrEqualTo(4.5));
          // وصفُ الدرس تحت عنوانه.
          expect(contrast(AppColors.rowHint, AppColors.surfaceWhite),
              greaterThanOrEqualTo(4.5));
        });
      }
    });

    test('حلقةُ المستوى تُرى على البطاقة ورقمُها يُقرأ', () {
      for (final dark in [false, true]) {
        withMode(dark, () {
          for (final p in [95, 70, 30]) {
            expect(contrast(analysisBand(p), AppColors.surfaceWhite),
                greaterThan(1.4),
                reason: 'حلقةُ $p% تذوب في البطاقة');
          }
          expect(contrast(AppColors.headingInk, AppColors.surfaceWhite),
              greaterThanOrEqualTo(4.5));
        });
      }
    });

    test('🌙 بطاقةُ الطالب وبطاقةُ المراجعة تحملان نصَّهما', () {
      for (final dark in [false, true]) {
        withMode(dark, () {
          // 👤 حبرُ بطاقة الطالب على **أغمقِ** طرفَي تدرّجها.
          final profile =
              AppColors.analysisProfileGradient.colors.last;
          expect(contrast(AppColors.analysisProfileInk, profile),
              greaterThanOrEqualTo(4.5));
          // 📅 وبطاقةُ المراجعة نصُّها أبيضُ على أفتحِ طرفَيها.
          final review = AppColors.analysisReviewGradient.colors.last;
          expect(contrast(Colors.white, review),
              greaterThanOrEqualTo(4.5));
        });
      }
    });
  });

  // ══════════════════════════════════════════════════
  // ⑧ لوحة «المنح» — الفاتحُ مقيسٌ والداكنُ مشتقّ
  // ══════════════════════════════════════════════════
  //
  // 🎨 المصمّم رسم الفاتح وحده هنا أيضاً. وأكثرُ ألوان القسم **درجاتٌ من
  //    سلالم المشروع** (تحقّقتُ منها بالبكسل)، فالحارسُ ليس «هل اللون
  //    صحيح» بل **هل يُقرأ ما كُتب عليه** — في الوضعين.
  group('⑧ لوحة «المنح»', () {
    test('حبرُ الوسوم الثلاثة مقروءٌ على تعبئته', () {
      for (final dark in [false, true]) {
        withMode(dark, () {
          // ⚠️ **عتبتان لا واحدة — كما في مجموعة ⑦.** الأخضرُ الفاتح زوجٌ
          //    **من التصدير نفسه** (`#18A342` على `#DEF9E6` = 2.96): لا
          //    أرفعه فأخالف ما قِسته، وأحرسُ ألّا يهبط. والداكنُ من عندي
          //    فلا عذرَ له دون 4.5.
          expect(contrast(AppColors.schGreenInk, AppColors.schGreenFill),
              greaterThanOrEqualTo(dark ? 4.5 : 2.9));
          expect(contrast(AppColors.schBlueInk, AppColors.schBlueFill),
              greaterThanOrEqualTo(4.5));
          expect(contrast(AppColors.schRedInk, AppColors.schRedFill),
              greaterThanOrEqualTo(4.5));
        });
      }
    });

    test('نصُّ السطح الباهت وحبرُ الدرج والتسمياتُ الثانوية تُقرأ', () {
      for (final dark in [false, true]) {
        withMode(dark, () {
          expect(contrast(AppColors.schTintInk, AppColors.schTint),
              greaterThanOrEqualTo(4.5));
          expect(contrast(AppColors.schDrawerInk, AppColors.surfaceWhite),
              greaterThanOrEqualTo(4.5));
          // «المعدل المطلوب:» و«قبل 10 س» — رماديٌّ صغير، وهو أكثرُ ما
          // يُنسى عند اشتقاق الداكن.
          expect(contrast(AppColors.schMutedInk, AppColors.surfaceWhite),
              greaterThanOrEqualTo(4.5));
          expect(contrast(AppColors.schMutedInk, AppColors.bgLight),
              greaterThanOrEqualTo(4.5));
        });
      }
    });

    // ✏️🗑️ زرّا بطاقة المحادثة — ألوانُهما الستّةُ مقيسةٌ من
    //    التصدير في الفاتح، ومشتقّةٌ في الداكن. والأيقونةُ **رسمٌ** لكنه
    //    رسمُ فعلٍ مدمِّر (حذف) وفعلٍ مُعدِّل، فيُحرَس كما يُحرَس النصّ.
    test('زرّا التعديل والحذف مقروءان في الوضعين', () {
      for (final dark in [false, true]) {
        withMode(dark, () {
          expect(contrast(AppColors.schEditInk, AppColors.schEditFill),
              greaterThanOrEqualTo(4.5));
          expect(contrast(AppColors.schDeleteInk, AppColors.schDeleteFill),
              greaterThanOrEqualTo(4.5));
          // والحدُّ يُرى على التعبئة، وإلا فالمربّعُ بلا إطار.
          expect(contrast(AppColors.schEditBorder, AppColors.schEditFill),
              greaterThan(1.1));
          expect(contrast(AppColors.schDeleteBorder, AppColors.schDeleteFill),
              greaterThan(1.1));
          // ⚠️ ولا يلتبس الزرّان: أحمرُ الحذف ≠ كحليُّ التعديل.
          expect(AppColors.schEditFill, isNot(AppColors.schDeleteFill));
        });
      }
    });

    test('🌙 السطحُ الباهت يُرى على الصفحة والحدُّ يُرى على البطاقة', () {
      withMode(true, () {
        // 🔴 أوّلُ اشتقاقٍ جرّبتُه (`#0E2233`) كانت نسبتُه على خلفية
        //    الصفحة 1.20:1 — لوحُ معلومةٍ يذوب فيها. فعُمّق.
        expect(contrast(AppColors.schTint, AppColors.bgLight),
            greaterThan(1.3));
        expect(contrast(AppColors.schSearchBorder, AppColors.surfaceWhite),
            greaterThan(1.2));
        // وفقاعةُ الطالب تختلف عن فقاعة المساعد — وإلا التبس المتكلّم.
        expect(AppColors.schBlueFill, isNot(AppColors.schTint));
      });
    });

    test('⭐ علامةُ المتابعة تُميَّز بالشكل لا بالحدّة — وهذا مقصود', () {
      // ⚠️ `#F3D31B` على `#FCF8DD` نسبتُه 1.39:1، وهي **من التصميم**.
      //    مقبولةٌ هنا وحدَها لأنها **رسمٌ لا نصّ**، وحالتاها تختلفان
      //    بالشكل (ممتلئة/مفرغة) لا باللون. والحارسُ يمنع أن يتسرّب هذا
      //    الاستثناء إلى نصّ.
      withMode(false, () {
        expect(contrast(AppColors.schSaveInk, AppColors.schSaveFill),
            lessThan(2.0));
        expect(contrast(AppColors.schSaveInk, AppColors.schSaveFill),
            greaterThan(1.2));
      });
      withMode(true, () {
        expect(contrast(AppColors.schSaveInk, AppColors.schSaveFill),
            greaterThanOrEqualTo(4.5));
      });
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

  group('⑩ شريطُ أدوات المعلم', () {
    // 🎨 مقيسٌ من `design/09-teacher` — وهذا الحارسُ يمنع أن يُخفَّض
    //    تباينُ الحبر صامتاً إلى ما كان في التصدير.
    for (final dark in [false, true]) {
      final mode = dark ? 'داكن' : 'فاتح';

      test('$mode: حبرُ الشريحة المختارة يُقرأ على تعبئتها', () {
        withMode(dark, () {
          for (var slot = 0; slot < 4; slot++) {
            final p = AppColors.toolPalette(slot);
            // ⚠️ تعبئةُ الداكن شفّافة، فتُركَّب على السطح قبل القياس —
            //    وإلا قست شفافيةً لا لوناً (علّةٌ وقعت في لوحة المنح).
            final fill = Color.alphaBlend(p.fill, AppColors.surfaceWhite);
            expect(contrast(p.ink, fill), greaterThanOrEqualTo(4.5),
                reason: 'حبرُ السلّم $slot لا يُقرأ على تعبئته');
          }
        });
      });

      test('$mode: الأيقونةُ تُرى داخل مربّعها', () {
        withMode(dark, () {
          for (var slot = 0; slot < 4; slot++) {
            final p = AppColors.toolPalette(slot);
            final box = Color.alphaBlend(p.box, AppColors.surfaceWhite);
            // 🖼️ الأيقونةُ رسمٌ لا نصّ: حدُّ WCAG لها ٣ لا ٤٫٥.
            expect(contrast(p.ink, box), greaterThanOrEqualTo(3),
                reason: 'أيقونةُ السلّم $slot تذوب في مربّعها');
          }
        });
      });
    }

    // 🔴 **ثلاثةُ أرقامٍ لا تبلغ 4.5 — وهي ألوانُ المصمّم بعينها.**
    //
    //    زرُّ التوليد في التصدير مصمتٌ بنصٍّ أبيض: الكحليّ `#2D4C98`
    //    يعطي 7.2، والأخضرُ `#18A342` يعطي 3.3، والذهبيّ `#B69E14`
    //    يعطي 2.7. ولو أُغمقت الدرجتان لاختلف **أبرزُ عنصرٍ في الشاشة**
    //    عن الملف الذي طلب المالكُ نقلَه حرفياً.
    //
    //    فالحدُّ هنا **٢٫٥ مكتوبةً صراحةً** لا 4.5 مموّهة: الرقمُ يقول
    //    ما هو، وأُبلغ المالكَ به ليقرّر. وما رُفع فعلاً هو **حبرُ
    //    الشريحة** (نصٌّ صغير على تعبئةٍ باهتة) — هناك كان النصُّ يختفي.
    test('زرُّ التوليد: لونُ التصدير مصمتٌ، والنصُّ أبيضُ فوقه', () {
      withMode(false, () {
        for (var slot = 0; slot < 4; slot++) {
          expect(contrast(Colors.white, AppColors.toolPalette(slot).cta),
              greaterThanOrEqualTo(2.5));
        }
      });
    });
  });
}
