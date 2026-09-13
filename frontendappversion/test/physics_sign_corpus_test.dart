// ➖ مسحٌ شامل: لا إشارةَ سالبٍ تبقى **يسارَ** عددها في الفيزياء.
//
// 🔴 **شكوى المالك الثالثة (2026-09-12):** «الفيزياء سالب في اليسار في
//    المقام، وشفت في بعض الأسس — في كل الأسس السالب في اليسار، خلوه في
//    اليمين. الفيزياء مش رياضيات».
//
// ⚖️ **ولماذا مسحٌ لا مثالان؟** أصلحتُ الأُسَّ والبسطَ بمثالَين فبقيت
//    صورٌ أخرى. والمقياسُ الآن على **كل سطرٍ في كتاب الفيزياء** يخرج من
//    الخادم وفيه إشارةٌ وعدد — ٣٢٥ سطراً، مولَّدةً بـ`_finish` نفسِها
//    (tools: scratchpad/fixture.py) لا مكتوبةً بيدي.
//
// 📐 **والمقياسُ بنيويّ لا بصريّ:** الإشارةُ حين تُفصل ذرّةً تقع يمينَ
//    عددها بحكم الصفّ RTL — فالعطلُ هو أن تبقى **ملتصقةً** في مقطعٍ
//    واحد يبدأ بها. فأيُّ `Text` نصُّه «-٥» أو «⁻¹٩» عطلٌ مباشر.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/math_text.dart';

/// إشارةٌ ملتصقةٌ بعددها من **يساره** — وهي عينُ ما يشكو منه المالك.
final _leftGlued = RegExp(r'^[-−⁻][0-9٠-٩⁰¹²³⁴⁵⁶⁷⁸⁹]');

void main() {
  final lines = (jsonDecode(
          File('test/fixtures/physics_sign_lines.json').readAsStringSync())
      as List)
      .cast<String>();

  _latinLines();

  test('الملفّ نفسُه موجودٌ وممتلئ', () {
    expect(lines.length, greaterThan(300));
  });

  testWidgets('⭐⭐ لا إشارةَ يسارَ عددها في ٣٢٥ سطراً من كتاب الفيزياء',
      (tester) async {
    // 🖥️ **سطحٌ عريض عن قصد**: الفحصُ هنا على **موضع الإشارة** لا على
    //    لفّ السطر، وبعضُ أسطر الكتاب أطولُ من الهاتف فيفيض الكسرُ
    //    داخله (وله اختبارُه: [render_overflow_test]) فيُغرق هذا بضجيج.
    tester.view
      ..physicalSize = const Size(2400 * 3, 1600 * 3)
      ..devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final bad = <String>[];
    for (final line in lines) {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(child: MathText(line))),
        ),
      ));
      await tester.pump();
      for (final w in tester.widgetList<Text>(find.byType(Text))) {
        final data = w.data ?? '';
        if (_leftGlued.hasMatch(data)) {
          bad.add('«$data» في: ${line.substring(0, line.length.clamp(0, 90))}');
          break;
        }
      }
    }
    expect(bad, isEmpty,
        reason: 'إشارةٌ بقيت يسارَ عددها في ${bad.length} سطراً:\n'
            '${bad.take(8).join("\n")}');
  });
}

// ══════════════════════════════════════════════════
// 🔤 سطرُ المعادلة اللاتينية يُقرأ من اليسار
// ══════════════════════════════════════════════════
// 🔴 **ما رآه المالك (2026-09-12):** «شوف الأجواء كيف مخربطة» — ومعادلةُ
//    سلاسل الطيف في ص ١٣٧ كانت تخرج: الأقواسُ منعكسة، و`R_H` بعد قوسها،
//    والأطرافُ مقلوبة.
//
// ⚖️ **ولم تكن علّةَ الرسّام وحده**: خطُّ الاتجاه الثنائي نفسُه يخرجها
//    كذلك (قِيس بـ`TextPainter`)، لأن السطر **لاتينيُّ البنية**: كلُّ
//    رموزه λ و R_H ولا كلمةَ عربيةً فيه. فلا ترتيبَ عربيٌّ يجعله يُقرأ،
//    والكتابُ نفسُه يطبعه من اليسار.

void _latinLines() {
  group('🔤 اتجاهُ السطر من رموزه', () {
    test('سطرٌ رموزُه لاتينية', () {
      expect(isLatinMathLine(r'١/λ = R_H (١/١\sup{٢} - ١/٢\sup{٢})'), isTrue);
      expect(isLatinMathLine(r'∴ λ = ٤ / (٣ R_H)'), isTrue);
      expect(isLatinMathLine(r'E = \frac{1}{2} m v\sup{2}'), isTrue);
    });

    test('⚠️ وكلمةٌ عربيةٌ واحدة تكفي لإعادته عربياً', () {
      expect(isLatinMathLine(r'R_H = ١٠٩٦٧٧.٥٨ سم\sup{-١}'), isFalse);
      expect(isLatinMathLine(r'ط = ٦.٦٢٥ × ١٠\sup{-٣٤} جول'), isFalse);
      expect(isLatinMathLine('الطاقة = ٥ جول'), isFalse);
    });

    test('🛡️ وأسماءُ الترميز لا تُحسب لاتينيةً', () {
      // 🔴 لولا حجبُها لصار كلُّ سطرٍ فيه كسرٌ «لاتينياً» فانقلب.
      expect(isLatinMathLine(r'\frac{١}{٢} من الطاقة'), isFalse);
      expect(isLatinMathLine(r'\sqrt{٢ط} \sup{٢}'), isFalse);
    });
  });

  group('🔗 الأساسُ وأُسُّه لا يتفرّقان على سطرين', () {
    // 🔴 **رآه المالك (2026-09-12):** «… × ١٠» تنتهي السطر و«⁻⁵ سم» تبدأ
    //    الذي يليه، فيظهر الأُسُّ نشازاً بلا عدد. و`Wrap` يلفّ **بين
    //    ذرّتين**، فدُمج الأساسُ وأُسُّه في ذرّةٍ واحدة.
    testWidgets('⭐ على عرضٍ يضطرّ السطرَ إلى اللفّ', (tester) async {
      tester.view
        ..physicalSize = const Size(200 * 3, 600 * 3)
        ..devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              body: MathText(
                  r'الطول = ١.٢١٥٠٥ × ١٠\sup{-٥} سم = ١٢١٥.٠٥ أنجستروم')),
        ),
      ));
      await tester.pump();
      final base = tester.getCenter(find.text('١٠'));
      final exp = tester.getCenter(find.text('٥'));
      expect((base.dy - exp.dy).abs(), lessThan(20),
          reason: 'الأُسُّ يجب أن يبقى في سطر أساسه');
    });
  });

  group('🔤 ودليلُ الرمز اللاتينيّ يساره في كل موضع', () {
    testWidgets('⭐ «R_H» داخل مقام كسرٍ سطرُه عربيّ', (tester) async {
      // 🔴 «λ = ٤/(٣ R_H) سم» كانت تخرج «ᴴR» في المقام: الأساسُ وأُسُّه
      //    صارا ذرّةً واحدة، فأخذ صفُّها اتجاهَ **السطر** (عربيّ) لا
      //    اتجاهَ **الأساس** (لاتينيّ).
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: MathText(r'λ = \frac{٤}{٣ R_H} سم')),
        ),
      ));
      await tester.pump();
      expect(tester.getCenter(find.text('R')).dx,
          lessThan(tester.getCenter(find.text('H')).dx),
          reason: 'الدليلُ يسارَ رمزه اللاتينيّ');
    });

    testWidgets('⭐⭐ وأُسُّ الرقم يتبع **السطر** لا الرقم', (tester) async {
      // ⚖️ الرقمُ ليس رمزاً قوياً: «١٠⁻⁵» في سطرٍ عربيّ أُسُّها يسارها،
      //    وفي سطرٍ لاتينيّ يمينها — وكلاهما صحيحٌ في موضعه.
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
              body: MathText(r'λ = R_H × ٣\sup{٢}',
                  direction: TextDirection.ltr)),
        ),
      ));
      await tester.pump();
      // الأُسُّ «٢» يمينَ أساسه «٣» في السطر اللاتينيّ.
      expect(tester.getCenter(find.text('٢')).dx,
          greaterThan(tester.getCenter(find.text('٣')).dx));
    });

    testWidgets('⚖️ وفي سطرٍ عربيّ يقع يسارَه', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: MathText(r'الطاقة = ٣\sup{٢} جول')),
        ),
      ));
      await tester.pump();
      expect(tester.getCenter(find.text('٢')).dx,
          lessThan(tester.getCenter(find.text('٣')).dx));
    });

    testWidgets('⚖️ و«س²» أُسُّها يسارها كما في الكتاب العربي',
        (tester) async {
      await tester.pumpWidget(const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: MathText(r'ص = س\sup{٢} + ١')),
        ),
      ));
      await tester.pump();
      expect(tester.getCenter(find.text('٢')).dx,
          lessThan(tester.getCenter(find.text('س')).dx));
    });
  });

  group('🧮 والكسرُ الرقميّ لا يقطع عدداً عشرياً', () {
    test('🔴 «١ / ١٠٩٧٣٧.٣١» كانت تُقطع فيتشرّد «.٣١»', () {
      expect(liftNumericFractions('١ / ١٠٩٧٣٧.٣١'),
          r'\frac{١}{١٠٩٧٣٧.٣١}');
      expect(liftNumericFractions('٢.٥/٧.٥'), r'\frac{٢.٥}{٧.٥}');
      expect(liftNumericFractions('الناتج 3/4 فقط'), r'الناتج \frac{3}{4} فقط');
    });

    test('🔴 وأُسُّ المقام يُلتقط معه لا يُترك خارجه', () {
      // «١/١\sup{٢}» معناها ١/١² — فلو بقي الأُسُّ خارج الكسر لطفا
      // بجانبه بلا أساس، وهو ما ظهر على الشاشة.
      expect(liftNumericFractions(r'١/١\sup{٢} - ١/٢\sup{٢}'),
          r'\frac{١}{١\sup{٢}} - \frac{١}{٢\sup{٢}}');
      // ⚠️ وترميزٌ آخرُ بعد المقام يمنع الرفع أصلاً (لا نخمّن).
      expect(liftNumericFractions(r'١/١\frac{٢}{٣}'), r'١/١\frac{٢}{٣}');
    });

    test('⚠️ والوحداتُ تبقى كما هي', () {
      for (final unit in ['٢٠ م/ث', '٧٢ كم/ساعة', 'كجم.م/ث']) {
        expect(liftNumericFractions(unit), unit);
      }
    });
  });
}
