// ============================================================
// 📏 صندوقٌ أعرضُ من السطر يُصغَّر ليسعه — والقصيرُ لا يُمسّ
// ============================================================
// 🔴 **ما رآه المالك (٢٠٢٦-٠٩-٣٠):** معامل الارتباط في «الارتباط وأشكال
//    الانتشار» (الثالث الأدبي) — مقامُه جذرٌ طويل فخرج «RIGHT OVERFLOWED BY
//    59 PIXELS». الكسرُ يقيس نفسَه سطراً واحداً والجذرُ صفٌّ لا يُلفّ.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

const Size _phone = Size(402, 874);

// نصُّ الكتاب حرفاً (grade3/أدبي/الإحصاء/2) — والجوابُ في اللقطة بنفس الشكل.
const _pearson = r'ر = \frac{ن مجـ س\sub{ر} ص\sub{ر} - مجـ س\sub{ر} × مجـ ص\sub{ر}}'
    r'{\sqrt{[ن مجـ س\sub{ر}\sup{٢} - (مجـ س\sub{ر})\sup{٢}][ن مجـ ص\sub{ر}\sup{٢} - (مجـ ص\sub{ر})\sup{٢}]}}';
const _pearsonNumbers = r'= \frac{٨ × ٣٦٤ - (٥٦ × ٤٠)}'
    r'{\sqrt{[٨ × ٥٢٤ - (٥٦)\sup{٢}][٨ × ٢٥٦ - (٤٠)\sup{٢}]}}';
const _pearsonDeviations = r'ر = \frac{مجـ (س\sub{ر} - \ovl{س})(ص\sub{ر} - \ovl{ص})}'
    r'{\sqrt{[مجـ (س\sub{ر} - \ovl{س})\sup{٢}][مجـ (ص\sub{ر} - \ovl{ص})\sup{٢}]}}';
// جذرٌ طويل **وحده** بلا كسر — الصندوقُ الآخر الذي لا يُلفّ.
const _longRoot = r'ع = \sqrt{\frac{(س\sub{١} - \ovl{س})\sup{٢} + (س\sub{٢} - \ovl{س})\sup{٢} + (س\sub{٣} - \ovl{س})\sup{٢} + (س\sub{٤} - \ovl{س})\sup{٢}}{ن}}';

Future<void> _pump(WidgetTester t, String text) async {
  t.view.physicalSize = _phone * 3;
  t.view.devicePixelRatio = 3;
  addTearDown(t.view.reset);
  await t.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            // حاشيةُ فقاعة المحادثة تقريباً — أضيقُ من الشاشة.
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            child: MasarMarkdown(data: text, subject: 'رياضيات'),
          ),
        ),
      ),
    ),
  ));
}

void main() {
  for (final (name, text) in [
    ('معامل بيرسون بالرموز', _pearson),
    ('معامل بيرسون بالأرقام', _pearsonNumbers),
    ('معامل بيرسون بالانحرافات', _pearsonDeviations),
    ('جذرٌ طويلٌ وحده', _longRoot),
  ]) {
    testWidgets('⭐ $name: لا فيضان على عرض الهاتف', (t) async {
      await _pump(t, text);
      final err = t.takeException();
      expect(err, isNull, reason: '$err');
      // والصندوقُ داخل الشاشة فعلاً — لا مقصوصٌ خارجها.
      for (final box in find.byType(FittedBox).evaluate()) {
        final r = t.getRect(find.byWidget(box.widget));
        expect(r.left, greaterThanOrEqualTo(0), reason: '$r');
        expect(r.right, lessThanOrEqualTo(_phone.width), reason: '$r');
      }
    });
  }

  testWidgets('🛡️ الكسرُ القصير بحجمه كما كان — لا يُصغَّر', (t) async {
    await _pump(t, r'ص = \frac{٢}{٣} س + \sqrt{٢٥}');
    expect(t.takeException(), isNull);
    final boxes = find.byType(FittedBox);
    expect(boxes, findsNWidgets(2));
    for (final e in boxes.evaluate()) {
      final fit = t.renderObject<RenderBox>(find.byWidget(e.widget));
      final child = (fit as RenderProxyBox).child!;
      // مقاسُ الصندوق = مقاسُ ما بداخله ⇒ نسبةُ التصغير ١ تماماً.
      expect(fit.size, child.size);
    }
  });

  testWidgets('📐 الطويلُ يُصغَّر بنسبةٍ واحدة لا يُقصّ', (t) async {
    await _pump(t, _pearson);
    final e = find.byType(FittedBox).evaluate().first;
    final fit = t.renderObject<RenderBox>(find.byWidget(e.widget));
    final child = (fit as RenderProxyBox).child!;
    expect(fit.size.width, lessThan(child.size.width));
    // النسبة واحدة في البعدين ⇒ لا تشويه.
    expect(fit.size.width / child.size.width,
        closeTo(fit.size.height / child.size.height, 0.01));
  });
}
