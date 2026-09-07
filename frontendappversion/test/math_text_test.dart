// رسم الكسور: الترميز يصير بسطاً ومقاماً، وما لا كسر فيه لا يتغيّر سلوكه.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:ye_student_tutor/core/widgets/math_text.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('المحلِّل', () {
    test('يقرأ الكسر البسيط', () {
      final nodes = MathParser.parse(r'قيمة \frac{لو أ}{لو ب} ثابتة');
      expect(nodes.whereType<FracNode>().length, 1);
    });

    test('يقرأ الكسر المتداخل', () {
      final nodes = MathParser.parse(r'\frac{\frac{١}{س}}{٢}');
      final outer = nodes.whereType<FracNode>().single;
      expect(outer.numerator.whereType<FracNode>().length, 1);
    });

    test('لا ينهار على ترميز ناقص', () {
      expect(() => MathParser.parse(r'\frac{أ'), returnsNormally);
      expect(() => MathParser.parse(r'\frac'), returnsNormally);
      expect(() => MathParser.parse(''), returnsNormally);
    });

    test('يقرأ الجذر والأُسّ والعريض', () {
      expect(MathParser.parse(r'\sqrt{س}').whereType<SqrtNode>().length, 1);
      expect(MathParser.parse('س^٢').whereType<ScriptNode>().length, 1);
      expect(MathParser.parse('**مهم**').whereType<BoldNode>().length, 1);
    });
  });

  group('الرسم', () {
    testWidgets('البسط والمقام يظهران نصّاً منفصلين', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'الناتج \frac{لو أ}{لو ب} ثابت')));
      expect(find.text('لو'), findsWidgets);
      expect(find.text('أ'), findsOneWidget);
      expect(find.text('ب'), findsOneWidget);
    });

    testWidgets('الكسر يُرسم بخط فاصل (Container بارتفاع الخط)', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'\frac{١}{٢}')));
      final rules = t.widgetList<Container>(find.byType(Container)).where((c) {
        final box = c.constraints;
        return box != null && box.maxHeight == 1.6;
      });
      expect(rules.length, 1, reason: 'خط الكسر مفقود');
    });

    testWidgets('الأرقام السالبة لا تنقلب', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'د(-2) = \frac{١}{٢}')));
      // العدد وإشارته مقطع LTR واحد؛ لو انفصلا لظهر «2» وحده و«-» وحدها
      expect(find.text('-2'), findsOneWidget, reason: 'الإشارة انفصلت عن رقمها');
      expect(find.text('2'), findsNothing);
    });
  });

  _safetyNet();

  group('الجسر مع الماركداون', () {
    testWidgets('نصّ بلا كسور ⇒ MarkdownBody كما كان تماماً', (t) async {
      await t.pumpWidget(_wrap(const MasarMarkdown(data: '**عنوان**\n- نقطة')));
      expect(find.byType(MarkdownBody), findsOneWidget);
      expect(find.byType(MathText), findsNothing);
    });

    testWidgets('نصّ فيه كسر ⇒ سطر الكسر وحده للرسّام والباقي للماركداون',
        (t) async {
      await t.pumpWidget(_wrap(const MasarMarkdown(
          data: 'مقدمة عادية\n\nالقانون \\frac{ع}{ف} هنا\n\nخاتمة عادية')));
      expect(find.byType(MathText), findsOneWidget);
      expect(find.byType(MarkdownBody), findsWidgets);
    });

    testWidgets('MathOrText يبقى Text عادياً بلا كسور', (t) async {
      await t.pumpWidget(_wrap(const MathOrText('سؤال بسيط')));
      expect(find.byType(MathText), findsNothing);
      expect(find.text('سؤال بسيط'), findsOneWidget);
    });

    testWidgets('MathOrText يرسم عند وجود كسر', (t) async {
      await t.pumpWidget(_wrap(const MathOrText(r'ما قيمة \frac{١}{٢}؟')));
      expect(find.byType(MathText), findsOneWidget);
    });
  });
}

// ══════════ شبكة الأمان الرقمية + الحمولة الحيّة ══════════
void _safetyNet() {
  group('الكسر الرقمي البحت', () {
    test('يُرفع إلى \\frac', () {
      expect(liftNumericFractions('١/٥ جا⁵ س'), r'\frac{١}{٥} جا⁵ س');
      expect(liftNumericFractions('الناتج 3/4 فقط'), r'الناتج \frac{3}{4} فقط');
    });

    test('⚠️ وحدات القياس لا تُمسّ', () {
      for (final unit in ['20 م/ث', '72 كم/ساعة', 'كجم.م/ث', 'دص/دس']) {
        expect(liftNumericFractions(unit), unit, reason: 'تغيّرت: $unit');
      }
    });

    test('لا يلمس نصاً بلا شرطة', () {
      expect(liftNumericFractions('نص عادي تماماً'), 'نص عادي تماماً');
    });
  });
}
