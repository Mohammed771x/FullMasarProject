// اختبارات رسّام الصيغ البنائية والحلقات.
//
// الأسطر هنا **منقولة من نصّ الكتاب ومن ردود حقيقية** لا مخترعة — لأن
// العلّة الأصلية كانت أن الموديل يرسم ASCII خاطئاً كيميائياً، والهدف أن
// يصير الرسم من ترميزٍ لا من تخمين.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/chem_text.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';
import 'package:ye_student_tutor/core/widgets/math_text.dart';

void main() {
  group('تحليل السلسلة المكثّفة', () {
    test('سلسلة بسيطة بالشرطات', () {
      final c = parseChemChain('CH3-CH2-CH2-NH2');
      expect(c.groups.map((g) => g.label).toList(),
          ['CH3', 'CH2', 'CH2', 'NH2']);
      expect(c.groups.take(3).every((g) => g.bondAfter == ChemBond.single),
          isTrue);
      expect(c.groups.last.bondAfter, isNull);
    });

    test('الفراغ رابطةٌ أحادية — صيغة الكتاب حرفياً', () {
      // منقول من `كيمياء.json`: «CH3 CH2 CH2 NH2 : يسمى بروبيل أمين»
      final c = parseChemChain('CH3 CH2 CH2 NH2');
      expect(c.groups.length, 4);
      expect(c.groups.first.bondAfter, ChemBond.single);
    });

    test('الفرع بين قوسين يُرفع فوق المجموعة السابقة لا يصير مجموعة', () {
      final c = parseChemChain('CH3-CH(CH3)-CH3');
      expect(c.groups.map((g) => g.label).toList(), ['CH3', 'CH', 'CH3']);
      expect(c.groups[1].up.map((b) => b.label), ['CH3']);
      expect(c.groups[1].down, isEmpty);
    });

    test('فرعان على المجموعة نفسها: الثاني يتدلّى تحتها', () {
      final c = parseChemChain('CH3-C(CH3)(CH3)-CH3');
      expect(c.groups[1].up.map((b) => b.label), ['CH3']);
      expect(c.groups[1].down.map((b) => b.label), ['CH3']);
    });

    test('٢-أمينو بنتان — من نصّ الكتاب', () {
      // «CH3 CH2 CH2 CH (NH2) CH3 : يسمى 2-أمينو بنتان»
      final c = parseChemChain('CH3-CH2-CH2-CH(NH2)-CH3');
      expect(c.groups.length, 5);
      expect(c.groups[3].up.map((b) => b.label), ['NH2']);
    });

    test('الكربونيل: فرعٌ برابطة مزدوجة فوق الكربون', () {
      // ⚗️ هكذا يرسم الكتاب الأميد: أكسجينٌ فوق الكربون بخطّين.
      final c = parseChemChain('CH3-C(=O)-NH2');
      expect(c.groups.map((g) => g.label).toList(), ['CH3', 'C', 'NH2']);
      expect(c.groups[1].up.single.label, 'O');
      expect(c.groups[1].up.single.bond, ChemBond.double_);
    });

    test('N-بروبيل بيوتاناميد كاملاً', () {
      final c = parseChemChain('CH3-CH2-CH2-C(=O)-NH-CH2-CH2-CH3');
      expect(c.groups.map((g) => g.label).toList(),
          ['CH3', 'CH2', 'CH2', 'C', 'NH', 'CH2', 'CH2', 'CH3']);
      expect(c.groups[3].up.single.label, 'O');
      expect(c.groups[3].up.single.bond, ChemBond.double_);
    });

    test('الروابط الثنائية والثلاثية', () {
      expect(parseChemChain('CH3-C=O').groups[1].bondAfter, ChemBond.double_);
      expect(parseChemChain('CH3-C#N').groups[1].bondAfter, ChemBond.triple);
    });

    test('ثنائي ميثيل أمين — المركّب الذي رسمه الموديل خطأً', () {
      final c = parseChemChain('CH3-NH-CH3');
      expect(c.groups.map((g) => g.label).toList(), ['CH3', 'NH', 'CH3']);
      // ثلاث مجموعات لا أكثر: لا كربون معلّق ولا نيتروجين بثلاث هيدروجينات.
      expect(c.groups.every((g) => g.up.isEmpty && g.down.isEmpty), isTrue);
    });
  });

  group('تحليل الحلقة', () {
    test('العدد وحده', () {
      final r = parseChemRing('3');
      expect(r.size, 3);
      expect(r.aromatic, isFalse);
      expect(r.hetero, isNull);
    });

    test('البنزين: سداسي عطري', () {
      final r = parseChemRing('6|ar');
      expect(r.size, 6);
      expect(r.aromatic, isTrue);
    });

    test('البيريدين: سداسي عطري فيه نيتروجين', () {
      final r = parseChemRing('6|ar|N');
      expect(r.hetero, 'N');
      expect(r.aromatic, isTrue);
    });

    test('الأنيلين: بنزين عليه NH2', () {
      final r = parseChemRing('6|ar|+NH2');
      expect(r.substituent, 'NH2');
      expect(r.hetero, isNull);
    });

    test('ترتيب الأجزاء لا يهمّ', () {
      final a = parseChemRing('6|ar|N');
      final b = parseChemRing('N|6|ar');
      expect(b.size, a.size);
      expect(b.hetero, a.hetero);
      expect(b.aromatic, a.aromatic);
    });

    test('العدد خارج المدى يُقيَّد بلا انهيار', () {
      expect(parseChemRing('99').size, 8);
      expect(parseChemRing('1').size, 3);
    });
  });

  group('الجسر: متى يُستدعى الرسّام', () {
    test('سطر فيه \\chem يحتاج الرسّام', () {
      expect(containsMath(r'المركب \chem{CH3-NH-CH3} يسمى ثنائي ميثيل أمين'),
          isTrue);
    });

    test('سطر فيه \\ring يحتاج الرسّام', () {
      expect(containsMath(r'البنزين \ring{6|ar}'), isTrue);
    });

    test('🛡️ نصّ كيمياء بلا ترميز لا يتغيّر مساره', () {
      expect(containsMath('الأمينات مركبات تحتوي على مجموعة NH2'), isFalse);
    });
  });

  group('الرسم لا ينهار', () {
    Future<void> pump(WidgetTester tester, String source) async {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: SingleChildScrollView(child: MathText(source))),
        ),
      ));
    }

    testWidgets('سلسلة متفرّعة داخل جملة عربية', (tester) async {
      await pump(tester,
          r'المركب \chem{CH3-CH(CH3)-CH3} يسمى 2-ميثيل بروبان.');
      expect(tester.takeException(), isNull);
      expect(find.text('يسمى'), findsOneWidget);
    });

    testWidgets('حلقات: مثلث ومربع وبنزين وبيريدين', (tester) async {
      await pump(tester,
          r'\ring{3} و \ring{4} و \ring{6|ar} و \ring{6|ar|N} و \ring{6|ar|+NH2}');
      expect(tester.takeException(), isNull);
    });

    testWidgets('ترميز ناقص (قوس مفقود) لا يُسقط الشاشة', (tester) async {
      await pump(tester, r'\chem{CH3-CH(CH3 و \ring{');
      expect(tester.takeException(), isNull);
    });

    testWidgets('الكسر والكيمياء في سطر واحد', (tester) async {
      await pump(tester, r'\frac{1}{2} من \chem{CH3-CH3}');
      expect(tester.takeException(), isNull);
    });
  });

  group('الأرقام تنخفض دليلاً', () {
    testWidgets('CH3 يُرسم بحرفين ورقمٍ منخفض', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: ChemLabel('CH3',
                style: const TextStyle(fontSize: 16, color: Colors.black)),
          ),
        ),
      ));
      final rich = tester.widget<Text>(find.byType(Text).first);
      // النصّ مقسوم: «CH» عادي + «3» في WidgetSpan أصغر.
      expect(rich.textSpan!.toPlainText(includePlaceholders: false), 'CH');
    });

    testWidgets('رقم البداية معامل لا دليل', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.ltr,
          child: Scaffold(
            body: ChemLabel('2CH3',
                style: const TextStyle(fontSize: 16, color: Colors.black)),
          ),
        ),
      ));
      final rich = tester.widget<Text>(find.byType(Text).first);
      expect(rich.textSpan!.toPlainText(includePlaceholders: false), '2CH');
    });
  });
}
