// ============================================================
// ⚗️ معادلات الكيمياء — كما رآها المالك مشوّهة على الشاشة
// ============================================================
// 🔴 لقطةُ المالك (2026-09-09) من درس «الألدهيدات والكيتونات»:
//    «CH3CH-2OH-» بدل «CH3-CH2-OH»، وأسهمٌ مقلوبة، وشرطُ التفاعل
//    «[Cu / 200-300 م]» مرسومٌ **كسراً**.
//
// ⚖️ والعلّة الاتجاهُ الثنائي: المعادلة سلسلةٌ لاتينية في فقرةٍ عربية،
//    وحروفُها المحايدة تُحسم إلى اتجاه الفقرة فتقفز أطرافها.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/chem_equation.dart';
import 'package:ye_student_tutor/core/widgets/chem_text.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

/// المعادلات كما هي **حرفياً** في ملفّ كيمياء الثاني العلمي.
const _real = [
  'CH3-CH2-OH --[Cu / 200-300 م]--> CH3-CHO + H2',
  'H-C≡C-H + H2O --[H2SO4]--> CH3-CHO',
  '(CH3COO)2Ca --[300 م]--> CH3-CO-CH3 + CaCO3',
  'CH4 + H2O --725م/Ni/Al2O3--> CO + 3H2↑',
  'R-CHO + [O] --استمرار أثر العامل المؤكسد--> R-COOH',
];

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

/// نصوصُ الصيغ كما وصلت الرسّام — [ChemLabel] تحتفظ بمصدرها كما هو.
///
/// ⚠️ **ولا تُجمع من `Text` الشجرة**: الدليلُ المنخفض `WidgetSpan`، فجمعُ
///    `Text.data` يعطي «CH￼-CH￼-OH» ثم «3» و«2» منفصلين بلا ترتيب.
///    والمقصودُ هنا **أن المحتوى وصل كما كُتب**، ومصدرُه هو الشاهد.
List<String> formulas(WidgetTester t) =>
    t.widgetList<ChemLabel>(find.byType(ChemLabel)).map((w) => w.text).toList();

void main() {
  group('🔎 التمييز', () {
    test('كل معادلات الدرس تُعرف معادلاتٍ', () {
      for (final e in _real) {
        expect(looksLikeEquation(e), isTrue, reason: e);
      }
    });

    test('⚠️ والنثر العربي لا يُسحب إليها', () {
      // سهمٌ في جملةٍ عربية شائع: «← إذن»، ووصفُ خطوةٍ فيه سهم.
      for (final s in [
        'إذن الناتج هو الأسيتالدهيد ← وهذا ما نريده',
        'ننتقل الآن إلى الخطوة التالية وهي أكسدة الكحول الأولي بعامل مؤكسد',
        'تتميز الألدهيدات والكيتونات بأنها تملك درجات غليان عالية مقارنة بالهيدروكربونات',
        '',
      ]) {
        expect(looksLikeEquation(s), isFalse, reason: s);
      }
    });

    test('صيغةٌ بلا سهم ليست معادلة تفاعل', () {
      expect(looksLikeEquation('CH3-CO-CH3 | كيتون'), isFalse);
    });
  });

  group('🖼️ الرسم', () {
    testWidgets('⭐ المعادلة تُعزل إلى اليسار فلا يبعثرها الاتجاه', (t) async {
      await t.pumpWidget(_wrap(const ChemEquation(
          'CH3-CH2-OH --[Cu / 200-300 م]--> CH3-CHO + H2')));

      // 🧭 الشرطُ الحاسم: سياقُ الرسم `ltr` داخل صفحةٍ `rtl`.
      final dir = t.widget<Directionality>(find
          .descendant(
              of: find.byType(ChemEquation),
              matching: find.byType(Directionality))
          .first);
      expect(dir.textDirection, TextDirection.ltr);
    });

    testWidgets('الصيغ تصل كما كُتبت حرفاً بحرف', (t) async {
      // 🔒 شرطُ المالك: «المحتوى ضروري يكون نفسه، لا تعدل أي شيء».
      //
      // ⚠️ **والدليلُ صار سبَاناً منخفضاً** (طلب المالك 2026-09-12): «H2»
      //    تُرسم H₂، فلا يبقى للصيغة ودجت `Text` واحدة. والمقياسُ إذاً
      //    **النصُّ المرسوم كلُّه** لا ودجتٌ بعينها — والمحتوى هو المحتوى.
      await t.pumpWidget(_wrap(const ChemEquation(
          'CH3-CH2-OH --[Cu / 200-300 م]--> CH3-CHO + H2')));
      expect(formulas(t), contains('CH3-CH2-OH'));
      expect(formulas(t), contains('CH3-CHO + H2'));
    });

    testWidgets('شرطُ التفاعل يُرسم فوق السهم لا في وسط السطر', (t) async {
      await t.pumpWidget(_wrap(const ChemEquation(
          'CH3-CH2-OH --[Cu / 200-300 م]--> CH3-CHO + H2')));
      expect(find.text('Cu / 200-300 م'), findsOneWidget);
      expect(find.text('⟶'), findsOneWidget);
      // ولا يبقى الترميز الخام «-->» ظاهراً للطالب
      expect(find.textContaining('-->'), findsNothing);
    });

    testWidgets('السهم العكسي والاتزان لهما رمزاهما', (t) async {
      await t.pumpWidget(_wrap(const Column(children: [
        ChemEquation('N2 + 3H2 <=> 2NH3'),
        ChemEquation('CO2 + H2O <-- H2CO3'),
      ])));
      expect(find.text('⇌'), findsOneWidget);
      expect(find.text('⟵'), findsOneWidget);
    });
  });

  group('🔗 الوصل بالماركداون', () {
    testWidgets('⭐ نصٌّ فيه معادلة وحدها يمرّ بالرسّام لا بالماركداون', (t) async {
      // 🔴 الخروج المبكر كان يسلّم النصّ الخالي من `\frac` إلى `MarkdownBody`
      //    قبل التقسيم — فشرحُ الألدهيدات كلُّه معادلاتٌ بلا كسر، أي أن
      //    الإصلاح ما كان ليُنادى أصلاً.
      await t.pumpWidget(_wrap(const MasarMarkdown(
          data: 'تُحضّر الألدهيدات بأكسدة الكحولات:\n'
              'CH3-CH2-OH --[Cu / 200-300 م]--> CH3-CHO + H2\n'
              'وهذا تفاعلٌ مهم.')));
      expect(find.byType(ChemEquation), findsOneWidget);
      expect(find.text('Cu / 200-300 م'), findsOneWidget);
    });

    testWidgets('والنصّ الخالي منها لا يتغيّر سلوكه', (t) async {
      await t.pumpWidget(_wrap(const MasarMarkdown(
          data: 'الألدهيدات مركبات عضوية تحتوي مجموعة الكربونيل.')));
      expect(find.byType(ChemEquation), findsNothing);
    });
  });

  group('🧪 الترميز داخل المعادلة يبقى مرسوماً', () {
    testWidgets('⭐ حلقة البنزين تُرسم ولا تظهر ترميزاً عارياً', (t) async {
      // 🔴 كُشف في المحاكي: كتلةُ المعادلة سحبت السطر من `MathText`
      //    فخرجت «\ring{6|ar} + CH3Cl ⟶ تولوين» على شاشة الطالب.
      await t.pumpWidget(_wrap(const ChemEquation(
          r'\ring{6|ar} + CH3Cl --[AlCl3]--> تولوين + HCl')));
      expect(find.textContaining(r'\ring'), findsNothing);
      expect(formulas(t), contains('AlCl3'));
    });

    testWidgets('والكسر داخل المعادلة يُرسم بسطاً ومقاماً', (t) async {
      await t.pumpWidget(_wrap(const ChemEquation(
          r'A + B --> \frac{1}{2} C')));
      expect(find.textContaining(r'\frac'), findsNothing);
    });
  });

  testWidgets('وشرطُ التفاعل لا يعرض ترميزاً خاماً ولو جاء من محادثةٍ قديمة',
      (t) async {
    // 🔴 رُصد في المحاكي على محادثةٍ محفوظة قبل إصلاح الخادم.
    await t.pumpWidget(_wrap(const ChemEquation(
        r'CH3-CH2-OH --[\frac{Cu}{200}-300 م]--> CH3-CHO + H2')));
    expect(find.textContaining(r'\frac'), findsNothing);
  });

  // ══════════════════════════════════════════════════
  // 🔬 كشفُ المعادلة — وُسِّع 2026-09-12
  // ══════════════════════════════════════════════════
  group('🔬 كشفُ المعادلة', () {
    // 🔴 هذه الستّة كانت **تصل الطالبَ نصّاً خاماً**: لا رقمَ بعد الرمز
    //    («NaCl») ولا حرفين كبيرين متتاليين، أو حواشٍ عربية بين قوسين
    //    تُحسب كلاماً، أو تفاعلٌ عربيٌّ بلا رمزٍ لاتينيّ أصلاً.
    for (final src in const [
      'Cu(s) → Cu+2(aq) + 2e-',
      'NaCl → Na+ + Cl-',
      '2Na+ + 2e- → 2Na',
      'Zn(s) + Cu+2(aq) → Zn+2(aq) + Cu(s)',
      '2NaCl (مصهور) → 2Na(s) + Cl2(g) (تيار كهربي مستمر)',
      'فلز + ماء ← هيدروكسيد الفلز + غاز الهيدروجين',
    ]) {
      test('معادلة: $src', () => expect(looksLikeEquation(src), isTrue));
    }

    // ⛔ ونثرٌ يستعمل «←» بمعنى «يؤدّي إلى» — لا يُرسم معادلةً.
    for (final src in const [
      'أغلب التفاعلات الكيميائية تكون : إما طاردة للحرارة ← تنتقل الطاقة',
      'سالبية عالية ← عامل مؤكسد قوي',
      '3- الفلزات ← عوامل مختزلة قوية .',
      'البيانات المكتوبة على الرسم: المصعد (الأنود) (-)، المهبط (الكاثود) (+)',
      'نضع ف = س + ١ ⟵ د ف = د س',
      'انتقل الحكم من الدولة الأموية ← الدولة العباسية',
    ]) {
      test('نثر: $src', () => expect(looksLikeEquation(src), isFalse));
    }
  });

}
