// 🤖✨ الروبوت المتحرّك في شاشات الانتظار.
//
// 🎯 **طلبُ المالك (2026-09-20):** «لما جاهز تجهيز أسئلتك، خلّي الروبوت
//    يتحرّك». والانتظارُ في «اختبر نفسك» ثوانٍ يقضيها الطالب أمام صورة —
//    فإن سكنت ظنّ التطبيقَ متجمّداً.
//
// 🛡️ **ولماذا حارسٌ على الحركة؟** صورةٌ ساكنة وصورةٌ تطفو **تتطابقان في
//    لقطة**. سقوطُ الحركة لا يُرى في أي مراجعةٍ بصرية ولا في `analyze` —
//    يُرى في إطارين متتاليين وحدهما. وقد سقطت فعلاً أوّلَ مرّة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/masar_brand.dart';

Offset _offsetOf(WidgetTester t) {
  final transform = t.widget<Transform>(find.descendant(
      of: find.byType(MasarRobotAnimated), matching: find.byType(Transform)));
  final m = transform.transform;
  return Offset(m.storage[12], m.storage[13]);
}

void main() {
  testWidgets('⭐ الروبوت يطفو — الإطارُ الثاني غيرُ الأول', (t) async {
    await t.pumpWidget(const MaterialApp(
        home: Scaffold(body: Center(child: MasarRobotAnimated(size: 120)))));
    await t.pump();

    final a = _offsetOf(t);
    await t.pump(const Duration(milliseconds: 650));
    final b = _offsetOf(t);
    await t.pump(const Duration(milliseconds: 650));
    final c = _offsetOf(t);

    expect(a.dy == b.dy && b.dy == c.dy, isFalse,
        reason: 'الروبوت ساكنٌ — الحركة لم تعمل');
    // ⚠️ وحدُّ الإزاحة معقول: طفوٌ لا قفز.
    for (final o in [a, b, c]) {
      expect(o.dy.abs(), lessThanOrEqualTo(120 * 0.06));
    }

    // 🧹 نوقف المؤقّتات قبل نهاية الاختبار وإلا شكا `pumpAndSettle` من
    //    أنيميشنٍ لا ينتهي (وهو لا ينتهي عمداً — يدور ما دامت الشاشة).
    await t.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('♿ «تقليل الحركة» يُسكنه بلا كسر', (t) async {
    // ⚠️ `MaterialApp` يبني `MediaQuery` خاصّته من العرض، فأيُّ واحدةٍ
    //    فوقه تُطمس. الحقنُ يكون **داخله**.
    await t.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(disableAnimations: true),
          child: const Scaffold(
              body: Center(child: MasarRobotAnimated(size: 120))),
        ),
      ),
    ));
    await t.pump();

    expect(find.byType(MasarRobot), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(MasarRobotAnimated),
            matching: find.byType(Transform)),
        findsNothing,
        reason: 'لا ينبغي أن تُبنى الحركة أصلاً حين يطلب النظام تسكينها');
  });
}
