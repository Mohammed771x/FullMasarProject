// 🚫 رسّام الرياضيات لا يعمل خارج التعليم.
//
// 🔴 **العلّة التي يحرسها هذا الملف:** `liftNumericFractions` ترفع أي
//    «رقم/رقم» إلى `\frac{}{}`. هذا صحيح في درس فيزياء، وكارثة في شات
//    المنح: تاريخ «20/02/2026» ظهر **كسراً مرسوماً** على شاشة الطالب.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';
import 'package:ye_student_tutor/core/widgets/math_text.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  const date = "آخر موعد للتقديم 20/02/2026 فلا تتأخر.";

  test('الرافع نفسه يحوّل التاريخ إلى كسر — وهذا سبب العلّة', () {
    // ⚠️ ليس عيباً في الرافع: هو مصمَّم للرياضيات. العيب كان في تشغيله
    //    حيث لا رياضيات. نثبّته هنا كي يبقى سبب الإطفاء موثّقاً.
    expect(liftNumericFractions(date), contains(r'\frac'));
  });

  testWidgets('شات المنح: التاريخ يبقى نصاً ولا يصير كسراً', (tester) async {
    await tester.pumpWidget(_wrap(
      const MasarMarkdown(data: date, math: false),
    ));
    await tester.pump();

    expect(find.byType(MathText), findsNothing);   // لا رسّام إطلاقاً
    expect(tester.takeException(), isNull);
  });

  testWidgets('قسم التعليم: الكسر الحقيقي ما زال يُرسم', (tester) async {
    await tester.pumpWidget(_wrap(
      const MasarMarkdown(data: r"السرعة = \frac{المسافة}{الزمن}"),
    ));
    await tester.pump();

    expect(find.byType(MathText), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('نصّ بلا كسور لا يتأثر بالخيار', (tester) async {
    for (final math in [true, false]) {
      await tester.pumpWidget(_wrap(
        MasarMarkdown(data: "ما شروط التقديم؟", math: math),
      ));
      await tester.pump();
      expect(find.byType(MathText), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
