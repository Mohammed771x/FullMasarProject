// ══════════════════════════════════════════════════
// 📊 الجدول على شاشة الجوال — لا كلمةَ تُكسر ولا سطرَ يفيض
// ══════════════════════════════════════════════════
//
// 🔴 **شكوى المالك (2026-09-13):** «الجدول لما يعرض في الجوال يطلع سيّئ
//    جداً — كلام متداخل مع بعضه، الحروف مقصّصة، مستحيل الطالب يفهمه.»
//
//    وكان محقّاً: **جدولُ المحتوى العاديّ لم يكن يمرّ بنا أصلاً.** كنّا
//    نعترض الجداولَ التي فيها كسرٌ أو معادلةُ تفاعل وحدها، والبقيّةُ
//    تذهب إلى `Table` الذي يرسمه الماركداون: أعمدةٌ متساوية بلا حدٍّ
//    أدنى. أربعةُ أعمدةٍ على شاشة ٤٠٢ نقطة = ٩٠ نقطةً للعمود، وكلمةُ
//    «الكهربائي» وحدها أعرضُ من ذلك — فتُكسر في وسطها حرفاً حرفاً.
//
// 🎯 والحراسةُ هنا على ثلاثة أشياء لا يُغني أحدها عن الآخر:
//    ① **لا كسرَ داخل كلمة**: يُقاس بعرضِ الخليّة مقابلَ أطولِ كلمةٍ فيها.
//    ② **لا فيضانَ أفقيّ**: ما من جدولٍ يتجاوز عرضَ الشاشة.
//    ③ **لا معنى يضيع**: كلُّ خليّةٍ تصل الطالبَ ولو تغيّر الشكل.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

const double _phone = 402;   // مقاس الجهاز الحقيقي ([masar-testing-traps])

const _fourColumns = r'''
| الخاصية | الفلزات | اللافلزات | أشباه الفلزات |
| :--- | :--- | :--- | :--- |
| التوصيل الكهربائي | موصلة جيدة للتيار الكهربائي | عازلة لا توصل التيار | موصلية متوسطة تزداد بالحرارة |
| البريق | لها بريق معدني لامع | باهتة بلا بريق | بريق شبه معدني |
''';

const _fiveColumns = r'''
| العنصر | الرمز | العدد الذري | الكتلة الذرية | التكافؤ |
| :--- | :--- | :--- | :--- | :--- |
| المغنيسيوم | Mg | 12 | 24.31 | 2 |
| الألومنيوم | Al | 13 | 26.98 | 3 |
''';

const _withMath = r'''
| الدالة | المشتقة | المقارب |
| :--- | :--- | :--- |
| د(س) = \frac{٢س + ٣}{س - ١} | \frac{-٥}{(س - ١)^٢} | ص = ٢ |
''';

const _withReaction = r'''
| التفاعل | المعادلة | النوع |
| :--- | :--- | :--- |
| احتراق الميثان | CH4 + 2O2 --> CO2 + 2H2O | تأكسد |
''';

Future<void> _pump(WidgetTester tester, String markdown,
    {double width = _phone, String subject = 'احياء'}) async {
  tester.view.physicalSize = Size(width, 874);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: MasarMarkdown(data: markdown, subject: subject),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

/// أعرضُ كلمةٍ في نصّ، بنفس النمط الذي رُسمت به.
double _widestWord(String text, TextStyle style) {
  final painter = TextPainter(textDirection: TextDirection.rtl);
  var widest = 0.0;
  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    painter.text = TextSpan(text: word, style: style);
    painter.layout();
    if (painter.width > widest) widest = painter.width;
  }
  painter.dispose();
  return widest;
}

/// 🔬 **الحكمُ الحقيقيّ على «الحروف مقصّصة»**: كلُّ نصٍّ مرسوم يجب أن
///    يتّسع صندوقُه لأطولِ كلمةٍ فيه. ما دون ذلك = كسرٌ في وسط الكلمة.
///
/// ⚠️ **والفحصُ على `RichText` لا على `Text`**: أولُ صيغةٍ لهذا الحارس
///    فحصت `Text` وحدها، فمرّ عليها **العطلُ نفسُه** — جداولُ الماركداون
///    تبني خلاياها بـ`Text.rich`/`RichText` فلا `data` فيها، فكان الحارسُ
///    يمرّ بجانب الكسر ولا يراه. وحارسٌ لا يُسقط العطلَ القديم ليس حارساً.
void _expectNoBrokenWords(WidgetTester tester) {
  final offenders = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final widget = element.widget as RichText;
    final text = widget.text.toPlainText();
    if (text.trim().isEmpty) continue;
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    final style = widget.text.style ?? DefaultTextStyle.of(element).style;
    final need = _widestWord(text, style);
    // هامشُ نقطةٍ واحدة: تقريبُ الأعداد لا كسرُ كلمة.
    if (need > box.size.width + 1) {
      offenders.add('«${text.replaceAll("\n", " ")}» يحتاج '
          '${need.toStringAsFixed(1)} وله ${box.size.width.toStringAsFixed(1)}');
    }
  }
  expect(offenders, isEmpty,
      reason: 'كلماتٌ ستُكسر في وسطها:\n${offenders.join("\n")}');
}

void _expectNoOverflow(WidgetTester tester, {double width = _phone}) {
  expect(tester.takeException(), isNull);
  for (final element in find.byType(RichText).evaluate()) {
    final box = element.renderObject as RenderBox?;
    if (box == null || !box.hasSize) continue;
    expect(box.size.width, lessThanOrEqualTo(width),
        reason: 'صندوقٌ أعرضُ من الشاشة');
  }
}

void main() {
  group('📱 على شاشة الجوال', () {
    testWidgets('⭐ أربعةُ أعمدةٍ عربية — لا حرفَ مقصوص', (tester) async {
      await _pump(tester, _fourColumns);
      _expectNoBrokenWords(tester);
      _expectNoOverflow(tester);
    });

    testWidgets('⭐ خمسةُ أعمدةٍ كذلك', (tester) async {
      await _pump(tester, _fiveColumns);
      _expectNoBrokenWords(tester);
      _expectNoOverflow(tester);
    });

    testWidgets('وجدولُ الرياضيات بكسوره', (tester) async {
      await _pump(tester, _withMath, subject: 'رياضيات');
      _expectNoBrokenWords(tester);
      _expectNoOverflow(tester);
    });

    testWidgets('وجدولُ الكيمياء بمعادلته', (tester) async {
      await _pump(tester, _withReaction, subject: 'كيمياء');
      _expectNoBrokenWords(tester);
      _expectNoOverflow(tester);
    });

    testWidgets('🔍 وعلى أضيقِ شاشةٍ متداولة (٣٢٠)', (tester) async {
      // آيفون SE الأول وما شابهه — إن نجا الجدولُ هنا نجا في كل مكان.
      await _pump(tester, _fourColumns, width: 320);
      _expectNoBrokenWords(tester);
      _expectNoOverflow(tester, width: 320);
    });
  });

  group('📋 المعنى لا يضيع مهما تغيّر الشكل', () {
    testWidgets('كلُّ خليّةٍ تصل الطالب — شبكةً كانت أو بطاقات',
        (tester) async {
      await _pump(tester, _fiveColumns);
      for (final cell in [
        'المغنيسيوم', 'Mg', '12', '24.31', '2',
        'الألومنيوم', 'Al', '13', '26.98', '3',
      ]) {
        expect(find.textContaining(cell), findsWidgets,
            reason: 'ضاعت الخليّة «$cell»');
      }
    });

    testWidgets('والترويساتُ تبقى منسوبةً إلى قيمها في وضع البطاقات',
        (tester) async {
      await _pump(tester, _fiveColumns);
      for (final header in ['الرمز', 'العدد الذري', 'الكتلة الذرية']) {
        expect(find.textContaining(header), findsWidgets,
            reason: 'ترويسةٌ ضائعة: «$header» — قيمةٌ بلا اسمها لا معنى لها');
      }
    });

    testWidgets('ولا يبقى محرفُ «|» ولا سطرُ الفصل على الشاشة',
        (tester) async {
      await _pump(tester, _fourColumns);
      expect(find.textContaining('|'), findsNothing);
      expect(find.textContaining('---'), findsNothing);
    });
  });

  group('🛟 حالاتٌ حدّية لا تُسقط الشاشة', () {
    testWidgets('جدولٌ بلا ترويسةٍ حقيقية', (tester) async {
      await _pump(tester, '| أ | ب |\n| ج | د |\n');
      expect(tester.takeException(), isNull);
    });

    testWidgets('صفٌّ ناقصُ الخلايا', (tester) async {
      await _pump(tester,
          '| الاسم | القيمة | الوحدة |\n| :-- | :-- | :-- |\n| السرعة | ٥ |\n');
      expect(tester.takeException(), isNull);
      expect(find.textContaining('السرعة'), findsWidgets);
    });

    testWidgets('خليّةٌ فارغة', (tester) async {
      await _pump(tester,
          '| أ | ب |\n| :-- | :-- |\n| قيمة |  |\n');
      expect(tester.takeException(), isNull);
    });

    testWidgets('عمودٌ واحد لا يُعدّ جدولاً', (tester) async {
      await _pump(tester, '| سطر |\n| سطر آخر |\n');
      expect(tester.takeException(), isNull);
    });

    testWidgets('كلمةٌ واحدة أعرضُ من الشاشة لا تُسقط شيئاً', (tester) async {
      await _pump(tester,
          '| المصطلح | المعنى |\n| :-- | :-- |\n'
          '| Deoxyribonucleicacidpolymerase | إنزيم |\n');
      expect(tester.takeException(), isNull);
      expect(find.textContaining('إنزيم'), findsWidgets);
    });
  });

  group('🖥️ وعلى شاشةٍ عريضة يبقى جدولاً', () {
    testWidgets('الشبكةُ هي الأصل حين يتّسع العرض', (tester) async {
      await _pump(tester, _fourColumns, width: 900);
      _expectNoBrokenWords(tester);
      // ترويسةٌ واحدة فقط لكل عمود ⇒ شبكةٌ لا بطاقات (البطاقاتُ تكرّرها).
      expect(find.text('الفلزات'), findsOneWidget);
    });
  });
}
