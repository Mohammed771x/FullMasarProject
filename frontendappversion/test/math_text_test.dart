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
  _englishSentenceDirection();
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

    testWidgets('⭐ الإشارة يمين العدد العربي', (t) async {
      // 📌 عقدُ المالك 2026-09-11: الإشارةُ الأحادية تُفصل ذرّةً مستقلّة
      //    كي تقع **يمين** العدد بالعربية. والمهمّ أن العدد لا ينقلب.
      await t.pumpWidget(_wrap(const MathText(r'د(-٢) = \frac{١}{٢}')));
      expect(find.text('٢'), findsWidgets);
      expect(t.getCenter(find.textContaining('-')).dx,
          greaterThan(t.getCenter(find.text('٢').first).dx));
    });

    testWidgets('⭐⭐ ويسارَه إن كان لاتينياً — توضيحُ المالك 2026-09-12',
        (t) async {
      // 🔴 «الرقم إنجليزي، السالب المفروض على يساره» — **للكيمياء وحدها**،
      //    فتُطلب `latinSign` صراحةً والرياضياتُ على عقدها القديم.
      await t.pumpWidget(_wrap(
          const MathText(r'د(-2) = \frac{١}{٢}', latinSign: true)));
      // ⭐ مقطعٌ واحد يبدأ بالإشارة — لا ذرّتان تُرتَّبان عربياً.
      expect(find.text('-2'), findsOneWidget);
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

  // ══════════════════════════════════════════════════
  // 📐 ما يصل الشاشة فعلاً بعد مسح ٦٤ درساً (2026-09-09)
  // ══════════════════════════════════════════════════
  //
  // 🔴 صحّح المسحُ في الخادم أنماطاً لم تكن تُنتَج من قبل، أهمّها **الكسر
  //    داخل الكسر**: «\frac{جا س - جتا س}{س - \frac{ط}{٤}}». فلو عجز
  //    الرسّام عنها لظهر الترميز عارياً على الشاشة — أي لاستبدلنا عيباً
  //    بعيبٍ أسوأ. ولذلك تُختبر هنا **مخرجات الخادم نفسها**.
  group('مخرجات مسح الدروس', () {
    testWidgets('الكسر داخل المقام يُرسم ولا يظهر ترميزه', (t) async {
      await t.pumpWidget(_wrap(
          const MathText(r'\frac{جا س - جتا س}{س - \frac{ط}{٤}}')));
      expect(find.textContaining(r'\frac'), findsNothing);
      expect(find.text('ط'), findsOneWidget);
    });

    testWidgets('اسم الدالّة داخل البسط لا ينفصل عنه', (t) async {
      // 🔴 «جا \frac{س}{س}» كانت تعني جا(س/س)=جا(١) — قيمةٌ أخرى.
      await t.pumpWidget(_wrap(const MathText(r'نهـ \frac{جا س}{س} = ١')));
      final frac = MathParser.parse(r'\frac{جا س}{س}').whereType<FracNode>().single;
      expect((frac.numerator.first as TextNode).text.trim(), 'جا س');
      expect(find.textContaining(r'\frac'), findsNothing);
    });

    testWidgets('رموز الاتحاد والتركيب والتكامل تُعرض رموزاً لا حروفاً', (t) async {
      await t.pumpWidget(_wrap(
          const MathText('المجال ]-∞، ٢[ ∪ ]٢، ∞[ والتركيب (ق ∘ د) و ∫ د(س)')));
      expect(find.textContaining('U'), findsNothing);
      expect(find.textContaining(' o '), findsNothing);
      expect(find.textContaining('int'), findsNothing);
    });

    testWidgets('علامة المتمّمة تبقى مع قوسها داخل البسط', (t) async {
      const src = r'\frac{حـا(أ ∪ ب)َ}{١ - حـا(أ)}';
      await t.pumpWidget(_wrap(const MathText(src)));
      expect(find.textContaining(r'\frac'), findsNothing);
      final frac = MathParser.parse(src).whereType<FracNode>().single;
      expect((frac.numerator.first as TextNode).text, contains('حـا(أ ∪ ب)'));
    });
  });


  // ══════════════════════════════════════════════════
  // √ الجذر العربيّ — من اليمين
  // ══════════════════════════════════════════════════
  group('√ الجذر', () {
    testWidgets('يُرسم بعلامةٍ وسقفٍ لا بكلمة «جذر»', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'جـ = \sqrt{٧}')));
      expect(find.text('√'), findsOneWidget);
      expect(find.text('٧'), findsOneWidget);
      expect(find.textContaining(r'\sqrt'), findsNothing);
      expect(find.textContaining('جذر'), findsNothing);
    });

    testWidgets('⭐ واتجاهه من اليمين لليسار كالعربية', (t) async {
      // 🔴 قرار المالك: «جذر حق اللغة العربية، من اليمين لليسار».
      //    فالعلامة على يمين المقدار وسقفُها يمتدّ يساراً فوقه.
      await t.pumpWidget(_wrap(const MathText(r'\sqrt{٢}')));
      final row = t.widget<Row>(find
          .descendant(of: find.byType(MathText), matching: find.byType(Row))
          .last);
      expect(row.textDirection, TextDirection.rtl);
    });

    testWidgets('الجذر داخل كسرٍ يُرسم أيضاً', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'\frac{\sqrt{٦}}{٥}')));
      expect(find.text('√'), findsOneWidget);
      expect(find.textContaining(r'\sqrt'), findsNothing);
    });

    testWidgets('ومقدارٌ مركّب يبقى كاملاً تحت السقف', (t) async {
      await t.pumpWidget(
          _wrap(const MathText(r'\sqrt{(س-أ)² + ص²}')));
      expect(find.textContaining(r'\sqrt'), findsNothing);
      expect(find.text('√'), findsOneWidget);
    });
  });


  // ══════════════════════════════════════════════════
  // ⌋ المضروب بالرمز العربي
  // ══════════════════════════════════════════════════
  group('⌋ المضروب', () {
    testWidgets('يُرسم زاويةً حول العدد لا بعلامة !', (t) async {
      // 🔴 قرار المالك (2026-09-10): «المضروب في اللغة العربية على شكل حرف
      //    L بالمقلوب ويكون فوقه الرقم… إنت حاطه الآن بالإنجليزي».
      await t.pumpWidget(_wrap(const MathText(r'\fact{ن}')));
      expect(find.text('ن'), findsOneWidget);
      expect(find.textContaining('!'), findsNothing);
      expect(find.textContaining(r'\fact'), findsNothing);
    });

    testWidgets('⭐ والزاوية ضلعٌ عن يمينه وقاعدةٌ تحته', (t) async {
      // 🔴 قرار المالك المُصحَّح: «الـL بس مقلوب لليسار، مش لليمين… خط،
      //    بعدين خط إلى اليسار، والنون فوقه». أي القاعدة **أسفل** لا أعلى؛
      //    وكانت أوّلَ مرّةٍ مقلوبةً للأعلى: «أنت عكسته لفوق، لا».
      await t.pumpWidget(_wrap(const MathText(r'\fact{٥}')));
      final box = t.widget<Container>(find
          .descendant(of: find.byType(MathText), matching: find.byType(Container))
          .first);
      final border = (box.decoration as BoxDecoration).border as Border;
      expect(border.bottom.width, greaterThan(0), reason: 'القاعدة تحت العدد');
      expect(border.right.width, greaterThan(0), reason: 'الضلع الأيمن');
      expect(border.top.width, 0, reason: 'ولا سقف — الزاوية تفتح أعلى');
      expect(border.left.width, 0, reason: 'وتفتح يساراً');
    });

    testWidgets('⭐ والقاعدة تطول بطول المقدار', (t) async {
      // ⚖️ «ويكون طويل، يطول إذا كان في مضروب أشياء واجد» — فمضروبُ مقدارٍ
      //    مركّب يجرّ خطَّه فوق المقدار كلِّه، لا محرفاً ثابتَ العرض.
      double widthOf(WidgetTester t) => t
          .renderObject<RenderBox>(find
              .descendant(
                  of: find.byType(MathText), matching: find.byType(Container))
              .first)
          .size
          .width;

      await t.pumpWidget(_wrap(const MathText(r'\fact{٥}')));
      final short = widthOf(t);
      await t.pumpWidget(_wrap(const MathText(r'\fact{ن²-ن-٢}')));
      expect(widthOf(t), greaterThan(short * 2));
    });

    testWidgets('ومقدارٌ مركّب يقع كاملاً داخلها', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'\fact{ن-١}')));
      expect(find.textContaining(r'\fact'), findsNothing);
      expect(find.text('ن-'), findsOneWidget);
    });

    testWidgets('والمضروب داخل كسر — قانون التوافيق', (t) async {
      await t.pumpWidget(_wrap(
          const MathText(r'\frac{\fact{ن}}{\fact{ر} × \fact{ن-ر}}')));
      expect(find.textContaining(r'\fact'), findsNothing);
      expect(find.textContaining(r'\frac'), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════
  // ⁿلᵣ التباديل والتوافيق
  // ══════════════════════════════════════════════════
  group('ⁿلᵣ التباديل والتوافيق', () {
    testWidgets('يُرسم بحرف الكتاب لا بحرفٍ لاتيني', (t) async {
      // 🔴 قرار المالك (2026-09-10): «الـل والقاف… الـن فوق والراء تحت».
      await t.pumpWidget(_wrap(const MathText(r'\perm{ن}{ر}')));
      expect(find.text('ل'), findsOneWidget);
      expect(find.textContaining('P'), findsNothing);
      expect(find.textContaining(r'\perm'), findsNothing);
      expect(find.text('ن'), findsOneWidget);
      expect(find.text('ر'), findsOneWidget);
    });

    testWidgets('والتوافيق بالقاف', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'\comb{٩}{٣}')));
      expect(find.text('ق'), findsOneWidget);
      expect(find.textContaining('C'), findsNothing);
    });

    testWidgets('⭐ ن أعلى من الحرف وَر أسفل منه — بالبكسل', (t) async {
      // ⚖️ الاختبار على **المواضع** لا على وجود النصّ: «ن» و«ر» موجودتان
      //    مهما كان الترتيب، والخللُ يكون في مواضعهما ([math_visual_order]).
      await t.pumpWidget(_wrap(const MathText(r'\perm{ن}{ر}')));
      final letter = t.getCenter(find.text('ل'));
      final n = t.getCenter(find.text('ن'));
      final r = t.getCenter(find.text('ر'));
      expect(n.dy, lessThan(letter.dy), reason: 'ن فوق الحرف');
      expect(r.dy, greaterThan(letter.dy), reason: 'ر تحت الحرف');
    });

    testWidgets('⭐ وَن عن يمين الحرف وَر عن يساره — كالعربية', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'\perm{ن}{ر}')));
      final letter = t.getCenter(find.text('ل'));
      expect(t.getCenter(find.text('ن')).dx, greaterThan(letter.dx));
      expect(t.getCenter(find.text('ر')).dx, lessThan(letter.dx));
    });

    testWidgets('ومقدارٌ مركّب يبقى كاملاً', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'\comb{ن+٢}{ر-١}')));
      expect(find.textContaining(r'\comb'), findsNothing);
    });
  });

  // ⌋ الرمز مجرّداً في التعريف
  testWidgets('⌋ زاويةٌ فارغة ترسم الرمز وحده في التعريف', (t) async {
    // 📖 «مضروب العدد ( ⌋ ):» — تعريفٌ يُري العلامة نفسها.
    await t.pumpWidget(_wrap(const MathText(r'مضروب العدد \fact{}: تعريفه')));
    expect(find.textContaining(r'\fact'), findsNothing);
    expect(t.takeException(), isNull);
  });

  // ══════════════════════════════════════════════════
  // ₙ الدليلُ المنخفض — النصفُ الغائب من الأُسّ (2026-09-17)
  // ══════════════════════════════════════════════════
  //
  // 🔴 «_» تُرسم دليلاً منذ البداية، لكنها **لا تفتح بوّابةَ السطر**
  //    ([kMathTokens])، فسطرٌ كلُّ رياضياته «م_ط» كان يُطبع نصّاً عادياً
  //    بشرطةٍ عارية — **٣٩٠ موضعاً في المخزون** (٣٥٥ منها فيزياء).
  group('ₙ الدليل المنخفض', () {
    testWidgets(r'\sub يفتح بوّابةَ الرسّام', (t) async {
      expect(hasMathMarkup(r'م\sub{ط} = ٠٫٠٠٢'), isTrue);
      expect(hasMathMarkup('م_ط = ٠٫٠٠٢'), isFalse,
          reason: 'الشرطةُ وحدها لا تكفي — ولذلك لزم الأمرُ الصريح');
    });

    testWidgets('يُرسم منخفضاً لا يُطبع خاماً', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'م\sub{ط}')));
      expect(find.textContaining(r'\sub'), findsNothing);
      expect(find.text('ط'), findsOneWidget);
    });

    testWidgets('⭐ والدليلُ أخفضُ من الأساس — بالبكسل', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'م\sub{ط}')));
      expect(t.getCenter(find.text('ط')).dy,
          greaterThan(t.getCenter(find.text('م')).dy));
    });

    testWidgets('⚖️ وهو ضدُّ الأُسّ في الاتجاه لا في الرسم', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'س\sup{٢} و م\sub{ط}')));
      expect(t.getCenter(find.text('٢')).dy,
          lessThan(t.getCenter(find.text('س')).dy));
      expect(t.getCenter(find.text('ط')).dy,
          greaterThan(t.getCenter(find.text('م')).dy));
    });

    testWidgets('ودليلٌ مركّب يبقى كاملاً', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'ن\sub{i+1}')));
      expect(find.textContaining(r'\sub'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('ويتسلسل: «م_فراغ_وسط» دليلان لا واحد', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'م\sub{فراغ}\sub{وسط}')));
      expect(find.text('فراغ'), findsOneWidget);
      expect(find.text('وسط'), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  });

  // ══════════════════════════════════════════════════
  // ⁿ الأُسّ
  // ══════════════════════════════════════════════════
  group('ⁿ الأُسّ', () {
    testWidgets('يُرسم مرفوعاً لا يُطبع خاماً', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'س\sup{2}')));
      expect(find.textContaining(r'\sup'), findsNothing);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('⭐ والأُسّ أعلى من الأساس — بالبكسل', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'س\sup{2}')));
      expect(t.getCenter(find.text('2')).dy,
          lessThan(t.getCenter(find.text('س')).dy));
    });

    testWidgets('⭐ والأُسُّ السالب إشارتُه **يمينَ** عدده', (t) async {
      // 🔴 **طلبُ المالك (2026-09-12):** «الأس يطلع السالب في اليسار —
      //    خله في اليمين بدله». وكان الأُسُّ مستثنى بشرط «فردياً» لأن
      //    نصَّ صندوقه عددٌ سالبٌ وحده — وهو **جزءٌ من مقدار** لا مقدارٌ
      //    قائم، فلا ينطبق عليه الشرط أصلاً ([math_text._build]).
      await t.pumpWidget(_wrap(const MathText(r'س\sup{-١٢}')));
      expect(find.textContaining(r'\sup'), findsNothing);
      expect(t.getCenter(find.text('-')).dx,
          greaterThan(t.getCenter(find.text('١٢')).dx),
          reason: 'الإشارةُ يمينَ عددها في الأُسّ');
    });

    testWidgets('⚖️ وفي الكيمياء تبقى يساره — أرقامُها لاتينية', (t) async {
      // 🔒 عقدُ المالك للكيمياء: «كلها أرقام إنجليزية، والسالب يساره».
      await t.pumpWidget(
          _wrap(const MathText(r'ΔH\sup{-12}', latinSign: true)));
      expect(find.text('-12'), findsOneWidget);
    });

    testWidgets('ومقدارٌ متغيّر أو مركّب يبقى كاملاً', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'(س-أ)\sup{-(ن+1)}')));
      expect(find.textContaining(r'\sup'), findsNothing);
      expect(t.takeException(), isNull);
    });

    testWidgets('ولا يبتلع ما بعده', (t) async {
      // ⚖️ «١٠^٢٣ × ٥» — حدُّ الأُسّ صريحٌ فالخمسةُ خارجه.
      await t.pumpWidget(_wrap(const MathText(r'10\sup{23} × 5')));
      expect(find.textContaining('23'), findsOneWidget);
      expect(find.textContaining('5'), findsWidgets);
    });

    testWidgets('⭐ ورمزٌ داخل رمز — كسرٌ داخل أُسّ وأُسٌّ داخل جذر', (t) async {
      // ⚖️ المنهج فيه «س^(١/٣)» و«جذر(س²)» و«لو س²» — أي تعشيشٌ حقيقيّ،
      //    فمُحلّل الأقواس يجب أن يعدّ لا أن يقف عند أول «}».
      await t.pumpWidget(_wrap(const MathText(
          r'س\sup{\frac{1}{3}} + \sqrt{س\sup{2}} + \fact{ن}')));
      for (final tok in const [r'\sup', r'\frac', r'\sqrt', r'\fact']) {
        expect(find.textContaining(tok), findsNothing, reason: tok);
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('والأُسّ داخل كسر', (t) async {
      await t.pumpWidget(
          _wrap(const MathText(r'\frac{1}{س\sup{2}}')));
      expect(find.textContaining(r'\sup'), findsNothing);
      expect(find.textContaining(r'\frac'), findsNothing);
    });
  });

  // ══════════════════════════════════════════════════
  // ∛ دليلُ الجذر
  // ══════════════════════════════════════════════════
  group('∛ الجذر التكعيبي والرابع', () {
    testWidgets('يُرسم بدليله لا بترميزٍ مشوّه', (t) async {
      // 🔴 قرار المالك (2026-09-11): «جذر تكعيب ما يطلع… فيه تشويه».
      //    السبب: المُحلِّل يقفز `\sqrt` ثم ينتظر «{» فيجد «[».
      await t.pumpWidget(_wrap(const MathText(r'\sqrt[3]{٨} = ٢')));
      expect(find.textContaining(r'\sqrt'), findsNothing);
      expect(find.textContaining('['), findsNothing);
      expect(find.text('3'), findsOneWidget, reason: 'الدليل ظاهر');
      expect(find.text('٨'), findsOneWidget);
    });

    testWidgets('والدليلُ يعلو العلامة في حضنها', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'\sqrt[3]{٨}')));
      expect(t.getCenter(find.text('3')).dy,
          lessThan(t.getCenter(find.text('٨')).dy));
    });

    testWidgets('والجذر الرابع كذلك — أيُّ دليلٍ كان', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'\sqrt[4]{١٦}')));
      expect(find.text('4'), findsOneWidget);
      expect(t.takeException(), isNull);
    });

    testWidgets('والتربيعيُّ يبقى بلا دليل', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'\sqrt{٩}')));
      expect(find.text('2'), findsNothing);
      expect(find.text('٩'), findsOneWidget);
    });
  });

  // ══════════════════════════════════════════════════
  // ‾ الشرطة العلوية: المرافق والمتمّمة
  // ══════════════════════════════════════════════════
  group('‾ المرافق والمتمّمة', () {
    testWidgets('تُرسم حدّاً علوياً لا محرفاً مركّباً', (t) async {
      await t.pumpWidget(_wrap(const MathText(r'ع × \ovl{ع} = ر²')));
      expect(find.textContaining(r'\ovl'), findsNothing);
      expect(find.text('ع'), findsWidgets);
    });

    testWidgets('⭐ والشرطةُ تلامس الحرف لا تحلّق فوقه', (t) async {
      // 🔴 قرار المالك (2026-09-11): «الشرطة بعيدة من العين… خلّه
      //    بالمعقول». وكانت تُرسم حدّاً لصندوق النصّ، وصندوقُ «ع» بقياس
      //    ١٧ ارتفاعُه ٢٩ — فعلت الشرطةُ الحرفَ **١١ بكسلاً**.
      await t.pumpWidget(_wrap(const MathText(r'\ovl{ع}')));
      final bar = t.renderObject<RenderBox>(find
          .descendant(of: find.byType(MathText), matching: find.byType(Container))
          .first);
      final text = t.renderObject<RenderBox>(find.text('ع'));
      final barY = bar.localToGlobal(Offset.zero).dy;
      final textY = text.localToGlobal(Offset.zero).dy;
      expect(bar.size.height, lessThan(3), reason: 'خطٌّ رفيع لا صندوق');
      expect(bar.size.width, text.size.width, reason: 'بطول المقدار تماماً');
      // ⚖️ الفجوة تُقاس من **أعلى حيّز الحرف** لا من أعلى صندوق النصّ.
      final glyphTop = textY + (text.size.height - 17) / 2;
      expect(glyphTop - barY, lessThan(4), reason: 'قريبةٌ من الحرف');
      expect(barY, lessThan(glyphTop), reason: 'وفوقه لا عليه');
    });

    testWidgets('⭐⭐ والألفُ لا تُشبك همزتُها بالشرطة — علّةُ المالك',
        (t) async {
      // 🔴 «الألف الخط يشبك مع الهمزة ويطلع من… لكن الباء يجي فوقه ريض»
      //    (2026-09-12). وخلوصٌ ثابتٌ من سقف الصندوق يقع فوق «ب» مريحاً
      //    ويمرّ في **وسط الهمزة**، لأن حبر «أ» يعلو حبر «ب» بـ ٠٫٤٦ من
      //    قياس الخط — ٧٫٨ بكسل عند ١٧.
      //
      // ⚖️ والأرقام أدناه مقيسةٌ من ملفّ Cairo نفسِه بـ `fontTools`:
      //    صعودُ السطر = ١٫٣٠٣ ÷ (١٫٣٠٣ + ٠٫٥٧١) × ١٫٧ = ١٫١٨٢ من القياس.
      const size = 17.0, ascent = 1.1819;
      const inkOf = {'أ': 0.96, 'ع': 0.50};

      Future<({double gap, double height, bool above})> probe(String ch) async {
        await t.pumpWidget(_wrap(MathText('\\ovl{$ch}')));
        final bar = t.renderObject<RenderBox>(find
            .descendant(
                of: find.byType(MathText), matching: find.byType(Container))
            .first);
        final text = t.renderObject<RenderBox>(find.text(ch));
        final barBottom =
            bar.localToGlobal(Offset.zero).dy + bar.size.height;
        final boxTop = text.localToGlobal(Offset.zero).dy;
        final inkTop = boxTop + (ascent - inkOf[ch]!) * size;
        final stack = t.renderObject<RenderBox>(
            find.descendant(of: find.byType(MathText), matching: find.byType(Stack)).first);
        return (
          gap: inkTop - barBottom,
          height: stack.size.height,
          above: barBottom <= inkTop
        );
      }

      final alef = await probe('أ');
      final ain = await probe('ع');

      // ⭐ الفجوةُ **واحدة** فوق الحرفين — وهذا هو الإصلاح كلُّه.
      expect((alef.gap - ain.gap).abs(), lessThan(0.6),
          reason: 'الخلوصُ يجب أن يكون واحداً فوق «أ» وفوق «ع»');
      expect(alef.above, isTrue, reason: 'لا تمرّ الشرطةُ في الهمزة');
      expect(ain.gap, greaterThan(4), reason: 'ولا تلتصق بالحرف');

      // ⭐ والسطرُ يرتفع بدل أن تُقحم الشرطةُ في السطر الذي فوقه.
      expect(alef.height - ain.height, greaterThan(2.5),
          reason: 'يُزاد ارتفاعُ السطر ليتّسع للشرطة فوق الألف');
    });

    testWidgets('⭐ وفوق القوس يُقاس بأعلى ما فيه لا بالقوس', (t) async {
      // «(أ ∪ ب)» — القوسُ ٠٫٧٥ والألفُ ٠٫٩٦، فالعبرةُ بالألف.
      await t.pumpWidget(_wrap(const MathText(r'\ovl{(أ ∪ ب)}')));
      final bar = t.renderObject<RenderBox>(find
          .descendant(
              of: find.byType(MathText), matching: find.byType(Container))
          .first);
      final stack = t.renderObject<RenderBox>(find
          .descendant(of: find.byType(MathText), matching: find.byType(Stack))
          .first);
      expect(bar.localToGlobal(Offset.zero).dy,
          closeTo(stack.localToGlobal(Offset.zero).dy, 0.5),
          reason: 'الشرطةُ في سقف الحيّز لأن الألف تكاد تبلغه');
      expect(t.takeException(), isNull);
    });

    testWidgets('⭐⭐ ومرافقُ المرافق شرطتان بطولٍ واحد', (t) async {
      // «لما يكون مرافق المرافق يكون واحدة صغيرة واللي فوقها كبير» —
      //    لأن القوسين كانا داخل الصندوق الخارجي فاتّسع.
      await t.pumpWidget(_wrap(const MathText(r'\ovl{\ovl{ع}}')));
      final bars = find
          .descendant(of: find.byType(MathText), matching: find.byType(Container))
          .evaluate()
          .map((e) => e.renderObject as RenderBox)
          .toList();
      expect(bars.length, 2, reason: 'شرطتان');
      expect(bars[0].size.width, bars[1].size.width, reason: 'بطولٍ واحد');
      expect((bars[0].localToGlobal(Offset.zero).dy -
                  bars[1].localToGlobal(Offset.zero).dy)
              .abs(),
          lessThan(6),
          reason: 'متجاورتان لا متباعدتان');
    });

    testWidgets('⭐⭐ وتطول فوق القوس كلِّه — وهي علّةُ المالك', (t) async {
      // «لما تكون الشرطة على القوس كامل… ما تطلع».
      double width(WidgetTester t) => t
          .renderObject<RenderBox>(find
              .descendant(
                  of: find.byType(MathText), matching: find.byType(Container))
              .first)
          .size
          .width;
      await t.pumpWidget(_wrap(const MathText(r'\ovl{أ}')));
      final one = width(t);
      await t.pumpWidget(_wrap(const MathText(r'\ovl{(أ ∪ ب)}')));
      expect(width(t), greaterThan(one * 2));
    });

    testWidgets('وداخل دالّة الاحتمال', (t) async {
      await t.pumpWidget(
          _wrap(const MathText(r'حـا(\ovl{أ}) = ١ - حـا(أ)')));
      expect(find.textContaining(r'\ovl'), findsNothing);
      expect(t.takeException(), isNull);
    });
  });

}

// ───────────── الجملةُ الإنجليزية تُرسم من اليسار (2026-09-18) ─────────────
void _englishSentenceDirection() {
  test('جملةٌ إنجليزيةٌ كاملة تُعدّ لاتينيةَ الاتجاه، والرمزُ المفرد لا', () {
    expect(isLatinSentence("What is the passive form of 'Ali is washing'?"),
        isTrue);
    expect(isLatinSentence('Choose the correct form: He ____ (go) to school.'),
        isTrue);
    // 🔬 رمزٌ أو كلمتان داخل فقرةٍ عربية تبقى في مكانها
    expect(isLatinSentence('NaCl'), isFalse);
    expect(isLatinSentence('pH 7'), isFalse);
    expect(isLatinSentence('ما تعريف prefix and suffix now?'), isFalse);
  });

  test('المادّةُ بين نجمتين تُمال ولا تُعرض نجمتاها', () {
    const q = 'Change into the passive: *They built the school in 1990.*';
    expect(hasEmphasis(q), isTrue);
    final spans = emphasisSpans(q, const TextStyle());
    final shown = spans.map((s) => (s as TextSpan).text ?? '').join();
    expect(shown.contains('*'), isFalse);
    expect(shown, 'Change into the passive: They built the school in 1990.');
    expect(
        spans.any((s) =>
            (s as TextSpan).style?.fontStyle == FontStyle.italic &&
            s.text == 'They built the school in 1990.'),
        isTrue);
    // ✖️ والضربُ ليس إمالة
    expect(hasEmphasis('٣ * ٤ = ١٢'), isFalse);
    expect(hasEmphasis('نصٌّ بلا نجوم'), isFalse);
  });

  test('✏️ الكلمةُ بين شرطتين يُرسم تحتها خطّ — داخل المادّة وخارجَها', () {
    const q = 'Part of speech: *The __cut__ on his arm was bleeding.*';
    expect(hasEmphasis(q), isTrue);
    final spans = emphasisSpans(q, const TextStyle(fontSize: 14))
        .cast<TextSpan>();
    final shown = spans.map((s) => s.text ?? '').join();
    expect(shown.contains('*'), isFalse);
    expect(shown.contains('_'), isFalse);
    expect(shown, 'Part of speech: The cut on his arm was bleeding.');

    final word = spans.firstWhere((s) => s.text == 'cut');
    expect(word.style?.decoration, TextDecoration.underline);
    // 🎨 والمادّةُ أغمق: مائلةٌ وأثقلُ من النصّ العاديّ (طلبُ المالك).
    final material = spans.firstWhere((s) => (s.text ?? '').contains('on his'));
    expect(material.style?.fontStyle, FontStyle.italic);
    expect(material.style!.fontWeight!.value, greaterThanOrEqualTo(700));
    final lead = spans.first;
    expect(lead.style?.fontStyle, isNot(FontStyle.italic));

    // ␣ والفراغُ `____` يبقى فراغاً لا خطّاً
    expect(hasEmphasis('He ____ (go) to school.'), isFalse);
  });
}
