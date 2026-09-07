// تلميح الشاشة: يقفز الروبوت من الزاوية أولاً ثم تنفتح فقاعته.
// ⚠️ لا تستعمل pumpAndSettle هنا: RobotWidget فيه أنيميشن دائم فلا يستقر أبداً.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/robot_widget.dart';
import 'package:ye_student_tutor/core/widgets/screen_tip.dart';

Future<void> _pumpTip(WidgetTester tester, {required bool anchorTop}) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: Scaffold(
      body: Stack(children: [
        const SizedBox.expand(),
        ScreenTip(
          screenId: "test",
          text: "اختر المادة من القائمة الجانبية ثم اكتب سؤالك.",
          alwaysShow: true,
          anchorTop: anchorTop,
          topOffset: 100,
          delayBeforeShow: const Duration(milliseconds: 50),
        ),
      ]),
    ),
  ));
}

void main() {
  testWidgets('الروبوت يسبق الفقاعة (ظهور على مرحلتين)', (tester) async {
    await _pumpTip(tester, anchorTop: false);

    // قبل انقضاء مهلة الظهور: لا شيء بعد
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 200)); // منتصف قفزة الروبوت
    expect(tester.widget<RobotWidget>(find.byType(RobotWidget)).state, RobotState.wave);

    // بعد انفتاح الفقاعة: الروبوت يتكلّم
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<RobotWidget>(find.byType(RobotWidget)).state, RobotState.talk);
  });

  testWidgets('الافتراضي: الروبوت أسفل اليمين والفقاعة فوقه', (tester) async {
    await _pumpTip(tester, anchorTop: false);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500)); // لا pumpAndSettle: الروبوت يتحرّك دائماً

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final robot = tester.getRect(find.byType(RobotWidget));
    final bubble = tester.getRect(find.text("مساعد مسار"));

    expect(robot.center.dx, greaterThan(screen.width / 2)); // يمين
    expect(robot.bottom, greaterThan(screen.height - 100)); // أسفل
    expect(bubble.top, lessThan(robot.top)); // الفقاعة فوقه
  });

  testWidgets('anchorTop: الروبوت أعلى اليسار والفقاعة تحته', (tester) async {
    await _pumpTip(tester, anchorTop: true);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500)); // لا pumpAndSettle: الروبوت يتحرّك دائماً

    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    final robot = tester.getRect(find.byType(RobotWidget));
    final bubble = tester.getRect(find.text("مساعد مسار"));

    expect(robot.center.dx, lessThan(screen.width / 2)); // يسار
    expect(robot.top, lessThan(220)); // أعلى
    expect(bubble.top, greaterThan(robot.top)); // الفقاعة تحته
  });

  testWidgets('«فهمت 👍» يُخفي الفقاعة ثم الروبوت', (tester) async {
    await _pumpTip(tester, anchorTop: false);
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 500)); // لا pumpAndSettle: الروبوت يتحرّك دائماً

    await tester.tap(find.text("فهمت 👍"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final op = tester.widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity));
    expect(op.every((w) => w.opacity == 0), isTrue);
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale).last).scale, 0);
  });
}
