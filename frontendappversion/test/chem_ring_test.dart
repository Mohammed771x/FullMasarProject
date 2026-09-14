// ══════════════════════════════════════════════════
// ⚗️ رسّام الحلقات — لكلِّ مركّبٍ رسمُه هو
// ══════════════════════════════════════════════════
//
// 🔴 **ما رآه المالك (2026-09-13):** «الهكسان الحلقي والهكسين الحلقي — يقول
//    لي بدون رابطة ثنائية وبها رابطة ثنائية، **وطيب نفس الرسمة**؟»
//
//    وكان محقّاً: الرسّام لم يكن يعرف **الرابطة الثنائية داخل الحلقة**
//    أصلاً، فكلُّ حلقةٍ غير عطرية مضلّعٌ أصمّ — الهكسان والهكسين والبروبين
//    سواء. ولم يكن يعرف **موقع** المجموعة (أورثو · ميتا · بارا رسمةٌ
//    واحدة)، ولا **الحلقات الملتحمة** (النفثالين والأنثراسين حلقةٌ واحدة).
//
// 🎯 وهذا الملف يحرس الثلاثة: البنية المقروءة · الرسم المرسوم · وأن كلَّ
//    ترميزٍ يولّده المنهج يُرسم بلا انهيارٍ ولا فيضان.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/chem_text.dart';
import 'package:ye_student_tutor/core/widgets/math_text.dart';

ChemRing ring(String source) => parseChemRing(source);

Future<void> pumpRing(WidgetTester tester, String code,
    {Size screen = const Size(402, 874)}) async {
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Center(
          child: RepaintBoundary(
            key: const Key('ring'),
            child: MathText(code, style: const TextStyle(fontSize: 17)),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// بكسلاتُ الرسم — الحكمُ الوحيد على «هل اختلفت الرسمة فعلاً؟».
Future<List<int>> shoot(WidgetTester tester, String code) async {
  await pumpRing(tester, code);
  final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const Key('ring')));
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  });
  return bytes!;
}

void main() {
  // ══════════════════ ① قراءة الترميز ══════════════════
  group('📖 قراءة الترميز', () {
    test('المقاس وحده', () {
      expect(ring('3').size, 3);
      expect(ring('6').size, 6);
      expect(ring('9').size, 8, reason: 'يُقصّ إلى المدى المدعوم');
    });

    test('⭐ الرابطة الثنائية — الفرق بين الهكسان والهكسين', () {
      expect(ring('6').doubleBonds, isEmpty);
      expect(ring('6|=1').doubleBonds, [1]);
      expect(ring('6|=1,3,5').doubleBonds, [1, 3, 5]);
    });

    test('العطرية والذرّة الغريبة', () {
      expect(ring('6|ar').aromatic, isTrue);
      expect(ring('6|ar|N').hetero, 'N');
      expect(ring('6|NH').hetero, 'NH');
      expect(ring('6|O@4').heteroAt, 4);
    });

    test('المجموعات ومواقعها', () {
      expect(ring('6|ar|+OH').substituents.single.label, 'OH');
      expect(ring('6|ar|+OH').substituents.single.at, isNull,
          reason: 'بلا موقع ⇒ الرأس الأعلى');

      final tnt = ring('6|ar|+CH3@1|+NO2@2|+NO2@4|+NO2@6');
      expect(tnt.substituents.map((s) => '${s.label}@${s.at}').toList(),
          ['CH3@1', 'NO2@2', 'NO2@4', 'NO2@6']);
    });

    test('الحلقات الملتحمة', () {
      expect(ring('6|ar').fused, 1);
      expect(ring('6|ar|fuse2').fused, 2);
      expect(ring('6|ar|fuse3').fused, 3);
    });

    test('🛟 الجزء المجهول يُهمل بصمت ولا يُفرغ الشاشة', () {
      final r = ring('6|ar|قادمٌ_من_نسخةٍ_أحدث|+OH');
      expect(r.size, 6);
      expect(r.aromatic, isTrue);
      expect(r.substituents.single.label, 'OH');
    });

    test('الترميز الفارغ يعطي حلقةً سداسية افتراضية', () {
      expect(ring('').size, 6);
    });
  });

  // ══════════════════ ② الرسم يختلف فعلاً ══════════════════
  group('🖌️ ثلاثة مركبات ⇐ ثلاث رسمات', () {
    testWidgets('⭐ هكسان · هكسين · بنزين — لا تتشابه صورُها', (tester) async {
      // نقارن **البكسل**: أن تختلف البنية المقروءة لا يكفي، فالعطل كان
      // في الرسم نفسه — ثلاثةُ ترميزاتٍ مختلفة تُرسم مضلّعاً واحداً.
      final hexane = await shoot(tester, r'\ring{6}');
      final hexene = await shoot(tester, r'\ring{6|=1}');
      final benzene = await shoot(tester, r'\ring{6|ar}');

      expect(_same(hexane, hexene), isFalse,
          reason: '🔴 الهكسان الحلقي والهكسين الحلقي كانا رسمةً واحدة');
      expect(_same(hexene, benzene), isFalse, reason: 'والهكسين ليس بنزيناً');
      expect(_same(hexane, benzene), isFalse);
    });

    testWidgets('أورثو · ميتا · بارا — ثلاثة مواضع لا موضعٌ واحد',
        (tester) async {
      final ortho = await shoot(tester, r'\ring{6|ar|+Br@1|+Br@2}');
      final meta = await shoot(tester, r'\ring{6|ar|+Br@1|+Br@3}');
      final para = await shoot(tester, r'\ring{6|ar|+Br@1|+Br@4}');
      expect(_same(ortho, meta), isFalse);
      expect(_same(meta, para), isFalse);
      expect(_same(ortho, para), isFalse);
    });

    testWidgets('نفثالين وأنثراسين أعرضُ من البنزين — حلقاتٌ ملتحمة',
        (tester) async {
      double widthOf(WidgetTester t) =>
          t.renderObject(find.byType(MathText)).paintBounds.width;
      await pumpRing(tester, r'\ring{6|ar}');
      final one = widthOf(tester);
      await pumpRing(tester, r'\ring{6|ar|fuse2}');
      final two = widthOf(tester);
      await pumpRing(tester, r'\ring{6|ar|fuse3}');
      final three = widthOf(tester);
      expect(two, greaterThan(one));
      expect(three, greaterThan(two));
    });
  });

  // ══════════════════ ③ كل ترميزات المنهج تُرسم ══════════════════
  group('📚 حمولة المنهج كاملةً', () {
    final codes = (jsonDecode(
            File('test/fixtures/ring_codes.json').readAsStringSync()) as List)
        .cast<String>();

    test('الحمولة موجودة وغير فارغة', () {
      expect(codes.length, greaterThan(40));
    });

    testWidgets('⭐ لا انهيارَ ولا فيضانَ على شاشة الجوال', (tester) async {
      // ⚠️ **بمقاس الجهاز لا بمقاس الاختبار الافتراضي (800×600)**: العطل
      //    الذي أفلت سابقاً كان يتّسع هناك ويفيض هنا ([render_overflow_test]).
      for (final code in codes) {
        await pumpRing(tester, code);
        expect(tester.takeException(), isNull, reason: 'انهيار عند $code');

        final box = tester.renderObject(find.byType(MathText)).paintBounds;
        expect(box.width, lessThanOrEqualTo(402),
            reason: 'فيضانٌ أفقيّ عند $code');
      }
    });

    testWidgets('ولا يبقى ترميزٌ خام على الشاشة', (tester) async {
      for (final code in codes.take(12)) {
        await pumpRing(tester, code);
        expect(find.textContaining(r'\ring'), findsNothing,
            reason: 'ترميزٌ خام ظاهر: $code');
      }
    });
  });

  // ══════════════════ ④ الحلقة داخل جملة عربية ══════════════════
  testWidgets('الحلقة تُرسم داخل نصّ الجواب لا وحدها', (tester) async {
    await pumpRing(tester,
        r'المركب الأول هو هكسين حلقي \ring{6|=1} والثاني بنزين \ring{6|ar}.');
    expect(tester.takeException(), isNull);
    expect(find.textContaining(r'\ring'), findsNothing);
    expect(find.byType(CustomPaint), findsWidgets);
  });
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
