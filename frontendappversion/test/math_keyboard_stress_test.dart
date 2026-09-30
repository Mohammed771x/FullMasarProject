import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/math_keyboard/math_editor.dart';
import 'package:ye_student_tutor/core/math_keyboard/math_input_field.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

// 🧪 **كلُّ ما يكتبه كيبورد الرياضيات — في الحقل وفي الفقاعة، بعرض جوال.**
//
// ⭐ طلبُ المالك (٢٠٢٦-٠٩-٣٠): «اخبط لق، جرّب كل شيء، شوف كيف يكبر
//    ويصغر» — والطالبُ يكتب المسألة ثم **كلاماً عادياً بعدها** في الرسالة
//    نفسها. فكلُّ سطرٍ هنا يُرسم في المكانين، ويُشترط:
//    ١) لا استثناء ولا فيضان (شريطُ «OVERFLOWED» الأصفر استثناءٌ في الاختبار).
//    ٢) **يبدأ من اليمين**: حافّةُ المحتوى اليمنى عند حافّة الحقل اليمنى.

const _cases = <String>[
  // مسألةُ المالك من صورته
  r'نها\sub{س←٠} \frac{جا ٣س\sup{٢}}{جا\sup{٢} س}',
  // مسألةٌ ثم كلامٌ عادي في الرسالة نفسها
  r'نها\sub{س←٠} \frac{١ - جتا\sup{٣} س}{جا س} وضّح لي الخطوات لو سمحت، وليش نضرب في المرافق؟',
  r'أوجد \frac{دص}{دس} إذا كانت ص = \sqrt{س\sup{٢} + ٩} + \sqrt[٣]{س - ١} ممكن تشرح لي قاعدة السلسلة بالتفصيل',
  r'∫\sub{٠}\sup{\frac{π}{٢}} جا س جتا\sup{٢} س د س',
  r'∫ (\frac{١}{س} + هـ\sup{٣س}) د س',
  r'حل المعادلة: لو\sub{٢} (س + ٣) + لو\sub{٢} (س - ١) = ٥',
  r'هـ\sup{٢س} - ٥ هـ\sup{س} + ٦ = ٠',
  r'\perm{ن}{٢} = ٣٠ ، \comb{ن}{٣} = ؟ ، \fact{٥}',
  r'ع = \frac{١ + ت}{١ - ت} أوجد |ع| و \ovl{ع}',
  r'جا ٢س\sup{٣} ، جا\sup{٣} ٢س ، (جا ٢س)\sup{٣}',
  // كسرٌ داخل كسرٍ داخل جذر — أعمقُ ما يمكن أن يُبنى
  r'\sqrt{\frac{\frac{س\sup{٢} + ١}{س - ١}}{\frac{٣}{س\sup{٢} - ٤}}}',
  // مسألةٌ طويلة جداً تلتفّ على أسطر
  r'نها\sub{س←∞} \frac{٣س\sup{٤} - ٥س\sup{٣} + ٧س\sup{٢} - ١١س + ١٣}{٢س\sup{٤} + ٩س\sup{٣} - ٤س\sup{٢} + س - ١٧} + \frac{جا س}{س} - \frac{١ - جتا س}{س\sup{٢}} + ظا\sup{٢} س - قا\sup{٢} س',
  // سطران (زر ↵)
  'د(س) = \\frac{س\\sup{٢} - ٤}{س - ٢}\nابحث عن اتصال الدالة عند س = ٢',
  // كلامٌ فقط
  'ممكن تفهمني الفرق بين النهاية من اليمين والنهاية من اليسار؟',
  // قوالبُ فارغة كما تظهر لحظةَ الإدراج
  r'\frac{}{} + \sqrt[]{} + س\sup{} + لو\sub{} + ∫\sub{}\sup{} + \fact{} + \perm{}{} + |ع|',
];

/// أقصى يمينِ كلّ ما يُرسم داخل [root] — نصٌّ أو رسمٌ (علامةُ الجذر مرسومة).
double _rightmost(WidgetTester t, Finder root) {
  var r = double.negativeInfinity;
  final ink = find.descendant(
    of: root,
    matching: find.byWidgetPredicate((w) => w is Text || w is CustomPaint),
  );
  for (final e in ink.evaluate()) {
    final box = e.renderObject as RenderBox;
    if (!box.hasSize || box.size.width == 0) continue;
    // ↔️ علامةُ الجذر مقلوبةٌ أفقياً (تُرسم من اليمين) — فالطرفان يُقاسان.
    for (final x in [0.0, box.size.width]) {
      final dx = box.localToGlobal(Offset(x, 0)).dx;
      if (dx > r) r = dx;
    }
  }
  return r;
}

void main() {
  for (final phone in [const Size(375, 812), const Size(430, 932)]) {
    for (var i = 0; i < _cases.length; i++) {
      final src = _cases[i];
      testWidgets('حقل الكتابة ${phone.width.toInt()} · #$i', (t) async {
        t.view.physicalSize = phone * 3;
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        final c = TextEditingController(text: src);
        final focus = FocusNode();
        // عرضُ الحقل في شريط الكتابة: الشاشة − الهوامش − الأيقونات.
        final fieldWidth = phone.width - 32 - 14 - 36 * 3 - 42;
        await t.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: fieldWidth,
                    child: MathInputField(
                      key: const ValueKey('field'),
                      editor: MathEditor(c),
                      focusNode: focus,
                      hint: 'اكتب مسألتك هنا...',
                      style: const TextStyle(fontSize: 17, height: 1.5),
                      hintStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        focus.requestFocus(); // المؤشرُ الوامض والخاناتُ المنقّطة ظاهرة
        await t.pump();
        expect(t.takeException(), isNull);

        final field = find.byKey(const ValueKey('field'));
        final fieldRight = t.getTopRight(field).dx;
        // 10 حشوةُ الحقل الداخلية، و٤ هامشُ خطٍّ مسموح.
        expect(
          _rightmost(t, field),
          greaterThan(fieldRight - 10 - 14),
          reason: 'المسألة يجب أن تبدأ من اليمين',
        );
      });

      testWidgets('فقاعة الطالب ${phone.width.toInt()} · #$i', (t) async {
        t.view.physicalSize = phone * 3;
        t.view.devicePixelRatio = 3;
        addTearDown(t.view.reset);
        final bubbleWidth = phone.width * 0.78 - 40;
        await t.pumpWidget(
          MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: Center(
                  child: SizedBox(
                    key: const ValueKey('bubble'),
                    width: bubbleWidth,
                    child: MasarMarkdown(data: src, subject: 'رياضيات'),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pump();
        expect(t.takeException(), isNull);
        final bubble = find.byKey(const ValueKey('bubble'));
        expect(
          _rightmost(t, bubble),
          greaterThan(t.getTopRight(bubble).dx - 14),
          reason: 'الفقاعة تبدأ من اليمين',
        );
      });
    }
  }

  // 💬 رسالةٌ قصيرة فيها رياضيات تأخذ عرضَ كلامها كالرسالة النصّية — لا
  //    تمتدّ زرقاءَ حتى الحافّة اليسرى (المالك ٢٠٢٦-٠٩-٣٠).
  for (final src in [
    r'أوجد \frac{٥}{٠}',
    r'نها\sub{س←٠} \frac{جا س}{س}',
    r'س\sup{٢} + ١',
  ]) {
    testWidgets('الفقاعة بعرض محتواها: $src', (t) async {
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: MasarMarkdown(
                  key: const ValueKey('m'),
                  data: src,
                  subject: 'رياضيات',
                ),
              ),
            ),
          ),
        ),
      ));
      expect(t.takeException(), isNull);
      expect(t.getSize(find.byKey(const ValueKey('m'))).width, lessThan(200));
    });
  }
}
