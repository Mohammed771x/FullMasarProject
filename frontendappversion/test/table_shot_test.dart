// أداةُ معاينة: ترسم جداول حقيقية بمقاس الجوال وتحفظها PNG للفحص البصري.
// ليست اختبارَ حراسة — الحراسةُ في `table_layout_test.dart`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

const _out =
    '/private/tmp/claude-501/-Users-m-f-d-Documents-cuadeai-FullMasarProject/d8cff9c9-934c-47d8-88ce-a80a57566ee7/scratchpad';

const _dna = r'''
| وجه المقارنة | حمض DNA | حمض RNA |
| :--- | :--- | :--- |
| عدد الأشرطة | شريطين (مزدوج) | شريط واحد (مفرد) |
| نوع السكر | رايبوز منقوص الأكسجين C₅H₁₀O₄ | رايبوز كامل الأكسجين C₅H₁₀O₅ |
| القواعد النيتروجينية | A, G, C, T | A, G, C, U |
''';

const _four = r'''
| الخاصية | الفلزات | اللافلزات | أشباه الفلزات |
| :--- | :--- | :--- | :--- |
| التوصيل الكهربائي | موصلة جيدة للتيار الكهربائي | عازلة لا توصل التيار | موصلية متوسطة تزداد بالحرارة |
| البريق | لها بريق معدني لامع | باهتة بلا بريق | بريق شبه معدني |
| القابلية للطرق | قابلة للطرق والسحب | هشة تتكسر بسهولة | هشة نسبياً |
''';

const _five = r'''
| العنصر | الرمز | العدد الذري | الكتلة الذرية | التكافؤ |
| :--- | :--- | :--- | :--- | :--- |
| الصوديوم | Na | 11 | 22.99 | 1 |
| المغنيسيوم | Mg | 12 | 24.31 | 2 |
| الألومنيوم | Al | 13 | 26.98 | 3 |
''';

const _long = r'''
| المفهوم | التعريف العلمي الدقيق | مثال تطبيقي من الحياة |
| :--- | :--- | :--- |
| التناضح | انتقال جزيئات الماء من المحلول الأقل تركيزاً إلى الأعلى تركيزاً عبر غشاء شبه منفذ | انتفاخ الزبيب عند نقعه في الماء لفترة من الزمن |
| الانتشار | حركة الجزيئات من منطقة التركيز المرتفع إلى منطقة التركيز المنخفض | انتشار رائحة العطر في أرجاء الغرفة كلها |
''';

const _math = r'''
| الدالة | المشتقة الأولى | المقارب الأفقي |
| :--- | :--- | :--- |
| د(س) = \frac{٢س + ٣}{س - ١} | \frac{-٥}{(س - ١)^٢} | ص = ٢ |
| د(س) = \sqrt{س} | \frac{١}{٢\sqrt{س}} | لا يوجد |
''';

Future<void> _loadFont() async {
  final loader = FontLoader('Cairo');
  loader.addFont(Future.value(
      File('$_out/Cairo.ttf').readAsBytesSync().buffer.asByteData()));
  await loader.load();
}

Future<void> _shoot(WidgetTester tester, String name, String md,
    {String subject = 'احياء'}) async {
  await _loadFont();
  tester.view.physicalSize = const Size(402 * 3, 874 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SingleChildScrollView(
          child: RepaintBoundary(
            key: const Key('shot'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: DefaultTextStyle(
                style: const TextStyle(
                    fontFamily: 'Cairo',
                    fontSize: 16,
                    height: 1.6,
                    color: Colors.black),
                child: MasarMarkdown(data: md, subject: subject),
              ),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  final boundary =
      tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('shot')));
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$_out/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });
}

void main() {
  // 🧰 أداةُ معاينةٍ محليّة لا حارس: تحتاج مجلّدَ الجلسة وخطَّ Cairo منسوخاً
  //    إليه. على أي جهازٍ آخر تُتخطّى بصمت بدل أن تُسقط `flutter test`.
  if (!Directory(_out).existsSync() || !File('$_out/Cairo.ttf').existsSync()) {
    test('معاينةُ الجداول — متخطّاة (لا مجلّد معاينة على هذا الجهاز)', () {});
    return;
  }

  testWidgets('جدول DNA', (t) => _shoot(t, 'tbl_after_dna', _dna));
  testWidgets('أربعة أعمدة', (t) => _shoot(t, 'tbl_after_four', _four));
  testWidgets('خمسة أعمدة', (t) => _shoot(t, 'tbl_after_five', _five));
  testWidgets('محتوى طويل', (t) => _shoot(t, 'tbl_after_long', _long));
  testWidgets('جدول رياضيات',
      (t) => _shoot(t, 'tbl_after_math', _math, subject: 'رياضيات'));
}
