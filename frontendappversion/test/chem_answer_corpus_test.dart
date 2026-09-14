// ⚗️ **معادلاتُ الكيمياء كما يكتبها الموديل فعلاً** — لا كما نتخيّله.
//
// 🔴 **علّةُ المالك (2026-09-12):** «ادخل على الكيمياء في المعادلات… ما طاع
//    يضبط». ولقطتُه أظهرت معادلتَي انشطارٍ نوويّ تصلان الطالبَ نصّاً خاماً:
//    «Al-27 + :قذيفة ألفا» و«3n <- (سريع)» — العنوانُ العربيّ مخلوطٌ
//    بالمعادلة اللاتينية، والسهمُ منقلب.
//
// 📊 **والمصدرُ محادثاتُ الجهاز نفسِها** (`conversations.hive` · ٦٢٤ ك.ب):
//    ثمانون سطراً من أجوبةٍ حقيقية — لا نصوصَ من تأليفي. ومسحُها كشف أن
//    الموديل يكتب `->` بشرطةٍ واحدة في ٣٠ موضعاً، والفحصُ كان يشترط
//    شرطتين فيسقطها كلَّها.
//
// 🔴 **والعرض ٤٠٢ نقطة لا ٨٠٠** — راجع [render_overflow_test].

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/chem_equation.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';
import 'package:ye_student_tutor/core/widgets/math_text.dart';

const _phone = Size(402, 874);

void main() {
  final lines = (jsonDecode(
          File('test/fixtures/chem_answer_lines.json').readAsStringSync())
      as List).cast<String>();

  test('⭐ كلُّ سطرٍ من أجوبة الكيمياء الحقيقية يُعرف معادلةً', () {
    expect(lines.length, greaterThan(70));
    final missed = [for (final l in lines) if (readEquation(l) == null) l];
    expect(missed, isEmpty, reason: 'سطورٌ تصل الطالب نصّاً خاماً:\n${missed.join('\n')}');
  });

  test('🏷️ والعنوانُ العربيّ يُفصل عن المعادلة — علّةُ اللقطة', () {
    final eq = readEquation(
        '1. **تفاعل الألومنيوم مع قذيفة ألفا:** Al-27 + He-4 -> P-30 + n-1')!;
    expect(eq.label, '1. تفاعل الألومنيوم مع قذيفة ألفا:');
    // ⚖️ والمعادلةُ تُستكمل رمزَ نواة — راجع الاختبار التالي.
    expect(eq.equation,
        r'\nuc{27}{13}{Al} + \nuc{4}{2}{He} -> \nuc{30}{15}{P} + \nuc{1}{0}{n}');
    // ⚠️ ولا نجمةَ ماركداون تتسرّب إلى الصندوق.
    expect(eq.equation.contains('*'), isFalse);

    // ⚖️ ورأسٌ فيه متفاعل **ليس** عنواناً: «حمض قوي + قاعدة قوية» طرفُ
    //    المعادلة الأيمن، فقطعُه يُخرج معادلةً بلا متفاعلات.
    final both = readEquation('1. **حمض قوي + قاعدة قوية** -> ملح + ماء')!;
    expect(both.label, '1.');
    expect(both.equation, 'حمض قوي + قاعدة قوية -> ملح + ماء');

    // ⚖️ وترقيمُ التمارين بالحروف يُنتزع كذلك: «a)» داخل الصندوق تخرج
    //    «(a» لأن القوس محايدٌ في سياق الرسّام.
    final letter = readEquation(r'a) ^130_52Te + ^1_0n ⟶ ^130_52Te')!;
    expect(letter.label, 'a)');
    expect(letter.equation.startsWith('^130'), isTrue);

    // ⚖️ والنقطةُ المجرّدة تسقط، ويبقى العنوان.
    final bullet = readEquation('- مثال: HCl(aq) + NaOH(aq) -> NaCl(aq) + H2O(l)')!;
    expect(bullet.label, 'مثال:');
    expect(bullet.equation, 'HCl(aq) + NaOH(aq) -> NaCl(aq) + H2O(l)');
  });

  test('☢️ وصيغةُ الشرطة «Al-27» تُستكمل رمزَ نواة — سؤالُ المالك', () {
    // 🔴 «Al-27 + He-4 ⟶ P-30 + n-1» — سأل المالك: «هل هذه صيغة صحيحة؟»
    //    لا: تُسقط العددَ الذرّي فلا تتّزن المعادلة. والعددُ الذرّي **تعريفُ
    //    العنصر** لا معلومةٌ خارجية — الألمنيوم ١٣ دائماً.
    final eq = readEquation('Al-27 + He-4 -> P-30 + n-1')!;
    expect(eq.equation,
        r'\nuc{27}{13}{Al} + \nuc{4}{2}{He} -> \nuc{30}{15}{P} + \nuc{1}{0}{n}');

    final u = readEquation('U-235 + n (بطيء) -> Ba-141 + Kr-92 + 3n (سريع) + طاقة')!;
    expect(u.equation.contains(r'\nuc{235}{92}{U}'), isTrue);
    expect(u.equation.contains(r'\nuc{141}{56}{Ba}'), isTrue);
    expect(u.equation.contains(r'\nuc{92}{36}{Kr}'), isTrue);
    // ⚖️ و«3n» ليست رمزَ نواة — معاملٌ ونيوترون، فتبقى كما هي.
    expect(u.equation.contains('3n'), isTrue);

    // ⚠️ ولا يُمسّ ما ليس رمزَ عنصر: «R» مجموعةٌ ألكيلية لا عنصر.
    final r = readEquation('R-12 + NaOH -> R-OH + NaCl')!;
    expect(r.equation.contains('R-12'), isTrue);

    // ⚠️ ولا سلاسلُ الكربون: «CH3-CH2» شرطتُها رابطةٌ لا عددٌ كتليّ.
    final chain = readEquation('CH3-CH2-OH + HCl -> CH3-CH2-Cl + H2O')!;
    expect(chain.equation.contains(r'\nuc'), isFalse);

    // ⚠️ ولا مدى الحرارة في شرط التفاعل.
    final cond = readEquation('CH3-CH2-OH --[Cu / 200-300 م]--> CH3-CHO + H2')!;
    expect(cond.equation.contains(r'\nuc'), isFalse);
  });

  test('🛡️ وما ليس تفاعلاً يبقى نصّاً — والشرطةُ الواحدة وحدَها ليست قرينة',
      () {
    // 📊 مسحُ المنهج: `->` في الكيمياء ٢٩٨ موضعاً، أكثرُها ليس تفاعلاً.
    const prose = [
      // ترتيبُ مستويات الطاقة — لا تفاعل، وعربيتُه صفر.
      'أ - 4s -> 4p -> 4d -> 5s',
      // سلسلةٌ غذائية في الأحياء.
      'فتات كائنات ميتة -> ديدان أرض -> عصافير -> ثعابين -> صقور .',
      // مخطّطُ مفاهيم.
      'الخلية (مجموع الخلايا) -> نسيج (مجموع الأنسجة) -> عضو (مجموع الأعضاء)',
      // تحوّلُ طاقةٍ في الفيزياء.
      'المولد (طاقة حركية -> طاقة كهربائية)، الخلية الكهروضوئية (طاقة ضوئية -> طاقة كهربائية)',
    ];
    for (final p in prose) {
      expect(readEquation(p), isNull, reason: 'رُسم نثرٌ معادلةً: «$p»');
    }
  });

  testWidgets('⭐⭐ ولا سطرَ يفيض ولا يعرض سهماً خاماً على عرض الجهاز',
      (t) async {
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    for (final line in lines) {
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: MasarMarkdown(data: line, subject: 'كيمياء'),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull, reason: 'فاض أو انهار: $line');
      // ⚖️ السهمُ يُرسم رمزاً (⟶ · ⇌)، فبقاءُ `->` نصّاً يعني أن السطر
      //    لم يبلغ الرسّام أصلاً — وهو عين العطل.
      expect(find.textContaining('->'), findsNothing, reason: 'سهمٌ خام: $line');
      expect(find.textContaining('**'), findsNothing, reason: 'ماركداون خام: $line');
    }
  });

  testWidgets('🔴 ولا ترميزَ خام داخل صندوق المعادلة — لقطةُ المحاكي',
      (t) async {
    // 🔴 **ما ظهر على الشاشة (2026-09-12):**
    //    «d) \sup{235}_92U + \sup{1}_0n ⟶ \sup{141}_56Ba …»
    //    الصندوقُ رُسم والسهمُ صحّ، والمحتوى **ترميزٌ عارٍ**.
    //
    // ⚖️ والسببُ نسخةٌ محلية من قائمة الترميز في `chem_equation` تعرف
    //    أربعةً من تسعة — بلا `\sup`. فصارت [kMathTokens] وحدها المرجع.
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    const line =
        r'\sup{235}_92U + \sup{1}_0n ⟶ \sup{141}_56Ba + \sup{92}_36Kr';
    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: MasarMarkdown(data: line, subject: 'كيمياء')),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byType(ChemEquation), findsOneWidget, reason: 'تُرسم معادلةً');
    for (final token in kMathTokens) {
      expect(find.textContaining(token), findsNothing,
          reason: 'ترميزٌ خام داخل الصندوق: $token');
    }
    // ⭐ والعددُ الكتلي مرفوعٌ والذرّي منخفض — رمزُ النواة كما في الكتاب.
    expect(find.text('235'), findsOneWidget);
    expect(find.text('92'), findsWidgets);
  });

  testWidgets('☢️ ورمزُ النواة وحدةٌ واحدة: الكتلي فوق الذرّي ثم الرمز',
      (t) async {
    // 🔴 «Cl7₁³⁵» على الشاشة — الرمزُ سبق عددَيه وانقلب ترتيبُهما، لأن
    //    `^` و`_` قُرئا كلٌّ على حدة فرتّبهما الاتجاهُ الثنائي.
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: MasarMarkdown(
              data: r'\nuc{235}{92}{U} + \nuc{1}{0}{n} ⟶ \nuc{141}{56}{Ba}',
              subject: 'كيمياء'),
        ),
      ),
    ));
    await t.pumpAndSettle();

    Offset at(String s) =>
        t.getTopLeft(find.text(s).first) ;
    final mass = at('235');
    final atomic = at('92');
    final sym = at('U');
    // ⭐ الكتلي **فوق** الذرّي بالبكسل.
    expect(mass.dy, lessThan(atomic.dy), reason: '٢٣٥ فوق ٩٢');
    expect((mass.dx - atomic.dx).abs(), lessThan(14), reason: 'عمودٌ واحد');
    // ⭐ والعددان **قبل** الرمز — يساره في سياقٍ لاتينيّ.
    expect(mass.dx, lessThan(sym.dx), reason: 'العددان قبل الرمز');
  });

  testWidgets('🧭 وحاشيةُ التفاعل العربية تبقى في موضعها داخل الصندوق',
      (t) async {
    // 🔴 «(سريع ²⁷₁₃Al + ¹₀n rapid)» — الحاشيةُ قفزت إلى صدر المعادلة،
    //    لأن رسّام الرياضيات يرصّ ذرّاته **عربياً** بطبعه، والصندوقُ
    //    لاتينيّ. فصار اتجاهُ السطر يُصرَّح به.
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: MasarMarkdown(
              data: r'\\nuc{27}{13}{Al} + \\nuc{1}{0}{n} (سريع) ⟶ \\nuc{24}{11}{Na}',
              subject: 'كيمياء'),
        ),
      ),
    ));
    await t.pumpAndSettle();

    final al = t.getTopLeft(find.text('Al').first).dx;
    final note = t.getTopLeft(find.textContaining('سريع').first).dx;
    final na = t.getTopLeft(find.text('Na').first).dx;
    // ⭐ الترتيبُ كما كُتب: المتفاعل، ثم حاشيته، ثم الناتج — يساراً فيميناً.
    expect(al, lessThan(note), reason: 'الحاشيةُ بعد المتفاعل لا قبله');
    expect(note, lessThan(na), reason: 'والناتجُ بعد الحاشية');
  });

  testWidgets('⚗️ ودليلُ الصيغة يُرسم منخفضاً لا شرطةً وقوسين', (t) async {
    // 🔴 «C_{12}H_{22}O_{11}» كانت تصل الطالب بحروفها: الصندوقُ لا يعرف
    //    أن `_` دليلٌ ما لم يكن في السطر ترميزٌ صريح. وفي معادلةٍ كيميائية
    //    لا معنى آخر لـ`_` و`^`.
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: MasarMarkdown(
              data: 'C_{12}H_{22}O_{11} + H_2O --[بكتيريا]--> 4CH_3CHOHCOOH',
              subject: 'احياء'),
        ),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byType(ChemEquation), findsOneWidget);
    expect(find.textContaining('_{'), findsNothing, reason: 'دليلٌ خام');
    expect(find.textContaining('_'), findsNothing, reason: 'شرطةٌ سفلية خام');
    // ⭐ وشرطُ التفاعل يظهر فوق السهم لا وسط المتفاعلات.
    expect(find.text('بكتيريا'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('📊 وجدولُ المقارنة يبقى جدولاً — لا صندوقَ معادلةٍ بأعمدة',
      (t) async {
    // 🔴 **ما ظهر على الشاشة (2026-09-12):** «| ⁶⁰₂₇Co ⟶ … | +1 | 0 |»
    //    داخل صندوق معادلة، بأعمدة الجدول وشرطاته. والموديل يضع معادلة
    //    التحول النووي في عمودٍ من جدول مقارنة.
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    const table = '| نوع التحول | المعادلة | العدد الذري |\n'
        '|---|---|---|\n'
        r'| فقدان جسيم ألفا | \nuc{238}{92}{U} --> \nuc{234}{90}{Th} + \nuc{4}{2}{He} | -2 |'
        '\n'
        r'| انطلاق جاما | \nuc{60}{27}{Co} --> \nuc{60}{28}{Ni} + γ | 0 |';

    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: MasarMarkdown(data: table, subject: 'كيمياء'),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    expect(t.takeException(), isNull);
    // ⭐ جدولٌ لا صندوقُ معادلةٍ بأعمدة.
    expect(find.byType(MasarTable), findsOneWidget);
    // ⭐ والمعادلةُ تُرسم **داخل الخليّة** بلا إطارٍ ثانٍ — وإلا ظهر
    //    السهمُ نصّاً مقلوباً «<-».
    expect(
        find.descendant(
            of: find.byType(MasarTable), matching: find.byType(ChemEquation)),
        findsNWidgets(2));
    expect(find.textContaining('-->'), findsNothing);
    // ⭐ ولا عمودٌ «|» ولا سطرُ فصلٍ يظهر للطالب.
    expect(find.textContaining('|'), findsNothing);
    expect(find.textContaining('---'), findsNothing);
    // ⭐ والترويسةُ والخلايا كلُّها حاضرة، والنواةُ مرسومةٌ داخلها.
    //
    // 🔄 **`findsWidgets` لا `findsOneWidget` (2026-09-13):** عمودُ المعادلة
    //    هنا أعرضُ من أن يُقسَّم على شاشة جوال، فيختار الجدولُ **وضعَ
    //    البطاقات** — وفيه تتكرّر الترويسةُ مع كل صفّ لأن القيمة بلا
    //    اسمها لا معنى لها. الشكلُ تغيّر والمعنى كما هو، وهذا هو المقصود.
    expect(find.text('نوع التحول'), findsWidgets);
    expect(find.text('238'), findsOneWidget);
    expect(find.textContaining(r'\nuc'), findsNothing);
    // ولا تضيع خليّةٌ في التحوّل.
    expect(find.textContaining('فقدان جسيم ألفا'), findsWidgets);
    expect(find.textContaining('انطلاق جاما'), findsWidgets);
  });

  testWidgets('📊 وحتى الجدولُ الخالي من الترميز يمرّ بنا', (t) async {
    // 🔄 **انقلبت هذه القاعدة (2026-09-13)** وكانت: «جدولٌ بلا ترميز يبقى
    //    للماركداون». وسببُ الانقلاب شكوى المالك: «الجدول في الجوال متداخل
    //    والحروف مقصّصة» — و`Table` الذي يرسمه الماركداون يقسّم العرض
    //    بالتساوي بلا حدٍّ أدنى، فتُكسر الكلمةُ العربية في وسطها.
    //
    // ⚖️ ومسارانِ للجدول يعني شكلين لا يفهم الطالبُ لماذا اختلفا — فصار
    //    المسارُ واحداً ومسؤولاً. الحراسةُ الكاملة في [table_layout_test].
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    const plain = '| المادة | الحالة |\n|---|---|\n| الماء | سائل |';
    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: MasarMarkdown(data: plain, subject: 'كيمياء')),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.byType(MasarTable), findsOneWidget);
    expect(find.textContaining('|'), findsNothing);
    expect(find.text('الماء'), findsOneWidget);
  });

  testWidgets('➖ والسالبُ يسارَ الرقم اللاتيني في خلايا الجدول', (t) async {
    // 🔴 **ما رآه المالك (2026-09-12):** «1-» و«4-» في عمود «التغير في
    //    العدد الذري». والمصدر «-1» و«-4»: الإشارةُ محايدة ففي فقرةٍ
    //    عربية تقفز يمينَ الرقم.
    //
    // ⚖️ **وهذا صوابٌ مع الأرقام العربية وخطأٌ مع اللاتينية** — وأرقامُ
    //    الكيمياء والفيزياء والأحياء لاتينيةٌ كلُّها (`to_arabic` تُنادى
    //    في الرياضيات والمنطق وحدهما).
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    const table = '| التحول | المعادلة | العدد الذري |\n'
        '|---|---|---|\n'
        r'| ألفا | \nuc{238}{92}{U} --> \nuc{234}{90}{Th} | -2 |'
        '\n'
        r'| بيتا | \nuc{14}{6}{C} --> \nuc{14}{7}{N} | +1 |';

    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: MasarMarkdown(data: table, subject: 'كيمياء'),
          ),
        ),
      ),
    ));
    await t.pumpAndSettle();

    for (final value in ['-2', '+1']) {
      // ⚠️ النصُّ يصل معزولاً بمحارف الاتجاه، فالبحثُ بالاحتواء لا بالتطابق.
      final text = t.widget<Text>(find.textContaining(value).first);
      expect(text.textDirection, TextDirection.ltr,
          reason: 'الإشارةُ تقفز يمينَ الرقم بلا اتجاهٍ صريح: «$value»');
      expect(text.data!.contains(value), isTrue);
    }
  });

  test('➖ وحكمُ «لاتينيٌّ خالص» لا يخلط الرقمين', () {
    expect(isPureLatin('-1'), isTrue);
    expect(isPureLatin('ΔH = -286 kJ'), isTrue);
    // ⚖️ الرقمُ العربيُّ يُخرجه من الحكم — إشارتُه يمينَه بقرار المالك.
    expect(isPureLatin('-١'), isFalse);
    expect(isPureLatin('الكتلة -5'), isFalse);
  });

  test('➖ وعزلُ الإشارة في النثر العربي — بثلاثة حرّاس', () {
    // 🔴 «الطاقة -25.9 كيلوجول» كانت تُرسم «25.9-»: الإشارةُ محايدةٌ
    //    وجارُها العربيّ يجرّها يميناً. والقياسُ بـ`TextPainter` أثبته.
    String? iso(String s) {
      final out = isolateSignedNumbers(s);
      return out == s ? null : out;
    }

    expect(iso('الطاقة -25.9 كيلوجول'), isNotNull);
    expect(iso('العدد الذري -1 والكتلي 0'), isNotNull);
    expect(iso('قيمة ΔH = -286 كيلوجول'), isNotNull);

    // 🔒 ولا يُمسّ الطرحُ الثنائي ولا المدى ولا الترقيم ولا الرقم العربي.
    expect(iso('الفرق 90 - 30 = 60 متراً'), isNull, reason: 'طرحٌ ثنائي');
    expect(iso('ابن سيناء ( 370 - 428 هـ )'), isNull, reason: 'مدىً بفراغين');
    expect(iso('المدى 370-428 سنة'), isNull, reason: 'مدىً ملتصق');
    expect(iso('٢- اكتب البيانات'), isNull, reason: 'ترقيمُ سؤال');
    expect(iso('الناتج -٥ وحدة'), isNull, reason: 'رقمٌ عربيّ: إشارتُه يمينَه');
  });

  testWidgets('🔒 والرياضياتُ لا تتأثّر بشيءٍ من هذا — نصُّ المالك', (t) async {
    // 🔴 «التعديل للكيمياء فقط، لا للرياضيات — اترك الرياضيات كما هي».
    //    فالحدُّ **بالمادة** لا بشكل الرقم: أجوبةُ الرياضيات تحمل
    //    لاتينيةً أحياناً («المقام (س - 2) = 0»)، ولا يجوز أن تتغيّر.
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    Future<String?> render(String subject) async {
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: MasarMarkdown(
                data: 'الناتج -25.9 وحدة', subject: subject, math: true),
          ),
        ),
      ));
      await t.pumpAndSettle();
      final md = t.widgetList<MarkdownBody>(find.byType(MarkdownBody));
      return md.isEmpty ? null : md.first.data;
    }

    const isolate = '\u2066';
    expect((await render('رياضيات'))!.contains(isolate), isFalse,
        reason: 'الرياضياتُ يجب أن تمرّ كما كانت حرفاً بحرف');
    expect((await render('منطق'))!.contains(isolate), isFalse);
    expect((await render('كيمياء'))!.contains(isolate), isTrue,
        reason: 'والكيمياءُ وحدها تُعزل إشارتُها');
  });

  test('⚗️ الدليلُ ينخفض والمعاملُ لا — طلبُ المالك 2026-09-12', () {
    // 🔴 «H2SO4 — الاثنان بعد الـH صغيرة وتحته، والأربعة كذلك. ولا تخلط
    //    بينها وبين الأرقام التي قبل: في 2H2O الأولى كبيرة».
    expect(subscriptFormulas('H2SO4'), 'H_2SO_4');
    expect(subscriptFormulas('H2O'), 'H_2O');
    // ⭐ المعاملُ في أول الصيغة يبقى كبيراً.
    expect(subscriptFormulas('2H2O'), '2H_2O');
    expect(subscriptFormulas('2NaCl + MnO2'), '2NaCl + MnO_2');
    // ⭐ وبعد القوس المغلق دليلٌ: (CH3COO)₂Ca.
    expect(subscriptFormulas('(CH3COO)2Ca'), '(CH_3COO)_2Ca');
    expect(subscriptFormulas('Ca(OH)2'), 'Ca(OH)_2');

    // 🔒 وما ليس دليلاً لا يُمسّ:
    expect(subscriptFormulas('Cu+2'), 'Cu+2', reason: 'شحنةٌ لا دليل');
    expect(subscriptFormulas('200-300 م'), '200-300 م', reason: 'مدى حرارة');
    expect(subscriptFormulas('10^23'), '10^23', reason: 'أُسّ');
    expect(subscriptFormulas('U-235'), 'U-235', reason: 'شرطةٌ قبل الرقم');
    // 🔒 ولا ما بين قوسَي أمرٍ: أرقامُ النواة مرسومةٌ أصلاً.
    expect(subscriptFormulas(r'\nuc{235}{92}{U} + H2O'),
        r'\nuc{235}{92}{U} + H_2O');
    expect(subscriptFormulas(r'\frac{1}{2} O2'), r'\frac{1}{2} O_2');
  });

  test('🔒 ولا يضيع محرفٌ واحد من أي سطر — الفارقُ شرطةٌ سفلية فقط', () {
    // ⚠️ شرطُ المالك الدائم: «المحتوى ضروري يكون نفسه».
    for (final line in lines) {
      final eq = readEquation(line);
      if (eq == null) continue;
      final lifted = subscriptFormulas(eq.equation);
      expect(lifted.replaceAll('_', ''), eq.equation.replaceAll('_', ''),
          reason: 'تغيّر شيءٌ غير الدليل في: $line');
    }
  });

  testWidgets('⚗️ وحالةُ المادّة تنخفض كما في صفحة الكتاب', (t) async {
    // 📖 من صفحة الكتاب التي أرسلها المالك (2026-09-12):
    //    «Pb₍s₎ + SO₄²⁻₍aq₎ ⟶ PbSO₄₍s₎ + 2e⁻» — الحالةُ أصغرُ وأخفض.
    //
    // ⚠️ ولا يبلغها يونيكود: لا «q» ولا «g» منخفضةٌ فيه أصلاً، فلا سبيل
    //    إلا الرسم — ولذلك تبقى في النثر كما هي، وهو الصوابُ هناك:
    //    «عدد الكم الثانوي (l)» ليست حالةَ سائل.
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: MasarMarkdown(
              data: 'Pb(s) + SO4-2(aq) --> PbSO4(s) + 2e-',
              subject: 'كيمياء'),
        ),
      ),
    ));
    await t.pumpAndSettle();

    expect(find.byType(ChemEquation), findsOneWidget);
    // ⭐ الحالةُ ودجتٌ مستقلّة بقياسٍ أصغر — لا نصٌّ بحجم الصيغة.
    final states = t
        .widgetList<Text>(find.byType(Text))
        .where((w) => (w.data ?? '') == '(s)' || (w.data ?? '') == '(aq)')
        .toList();
    expect(states.length, 3, reason: 'حالتان (s) وواحدة (aq)');
    for (final state in states) {
      expect(state.style!.fontSize!, lessThan(16.0),
          reason: 'الحالةُ أصغرُ من الصيغة');
    }
  });

  test('🛡️ وقائمةُ الترميز واحدة لا نُسخ — وهي علّةٌ تكرّرت أربع مرات', () {
    // ⚠️ كلُّ رمزٍ يرسمه [MathText] يجب أن يبلغ الرسّام من **داخل**
    //    صندوق المعادلة أيضاً، وإلا طُبع للطالب حرفياً.
    for (final token in kMathTokens) {
      expect(hasMathMarkup('س $token{١} ص'), isTrue, reason: token);
    }
    expect(hasMathMarkup('نصٌّ عربيّ بلا ترميز'), isFalse);
    expect(kMathTokens.length, 10);
  });

  testWidgets('🧪 ورسّامُ المعادلات لا يعمل خارج الكيمياء والأحياء', (t) async {
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    const line = 'HCl(aq) + NaOH(aq) -> NaCl(aq) + H2O(l)';
    await t.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: MasarMarkdown(data: line, subject: 'رياضيات'),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.byType(ChemEquation), findsNothing);
  });
}
