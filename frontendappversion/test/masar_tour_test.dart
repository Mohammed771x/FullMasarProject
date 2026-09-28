import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ye_student_tutor/core/tour/masar_tour.dart';
import 'package:ye_student_tutor/core/tour/tour_anchor.dart';

// 🤖 جولة الشرح: تمرّ بالخطوات بالترتيب، وتتخطّى عنصراً اختيارياً غائباً،
//    وتُغلق، ولا تظهر مرّةً ثانية إلا بعد التصفير.
//    ⚠️ لا `pumpAndSettle`: الروبوتُ يطفو ويرمش بلا توقّف ([masar-testing-traps]).
void main() {
  const steps = [
    TourStep(anchor: 'test.box', title: 'الخطوة الأولى', body: 'هذا مربع'),
    TourStep(
      anchor: 'test.missing',
      optional: true,
      title: 'خطوة غائبة',
      body: 'لا يجب أن تظهر',
    ),
    TourStep(title: 'الختام', body: 'انتهينا'),
  ];

  Future<void> pumpFor(WidgetTester t, int ms) async {
    for (var i = 0; i < ms ~/ 50; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  Widget app() => MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Builder(
          builder: (context) => Column(
            children: [
              const TourAnchor(
                id: 'test.box',
                child: SizedBox(width: 80, height: 80),
              ),
              TextButton(
                onPressed: () =>
                    MasarTour.maybeStart(context, id: 't', steps: steps),
                child: const Text('ابدأ'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('تمرّ بالخطوات وتتخطّى الغائب وتُغلق مرّةً واحدة', (t) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(app());
    await t.tap(find.text('ابدأ'));
    await pumpFor(t, 2500);

    expect(find.text('الخطوة الأولى'), findsOneWidget);
    expect(find.text('التالي'), findsOneWidget);

    await t.tap(find.text('التالي'));
    await pumpFor(t, 2500);
    expect(find.text('خطوة غائبة'), findsNothing);
    expect(find.text('الختام'), findsOneWidget);
    expect(find.text('لنبدأ'), findsOneWidget);

    await t.tap(find.text('لنبدأ'));
    await pumpFor(t, 1500);
    expect(find.text('الختام'), findsNothing);
    expect(await MasarTour.seen('t'), isTrue);

    // لا تظهر ثانيةً…
    await t.tap(find.text('ابدأ'));
    await pumpFor(t, 1500);
    expect(find.text('الخطوة الأولى'), findsNothing);

    // …إلا بعد «أعد جولة الشرح».
    await MasarTour.reset(['t']);
    await t.tap(find.text('ابدأ'));
    await pumpFor(t, 2500);
    expect(find.text('الخطوة الأولى'), findsOneWidget);
    await t.tap(find.text('إغلاق'));
    await pumpFor(t, 1500);
    expect(find.text('الخطوة الأولى'), findsNothing);
  });

  // 🎬 `before`: خطوةٌ تفتح ما تشرحه (القائمة الجانبية) — وما بعدها من
  //    الاختياريّ لا يُحكم عليه عند البدء بل حين يُفتح.
  testWidgets('before يُظهر المرساة قبل شرحها ويُفرز ما بعده عندها', (t) async {
    SharedPreferences.setMockInitialValues({});
    final open = ValueNotifier(false);
    var ran = 0;
    final steps = [
      const TourStep(title: 'البداية', body: 'أهلاً'),
      TourStep(
        anchor: 'test.drawer',
        title: 'داخل القائمة',
        body: 'فُتحت',
        before: () async {
          ran++;
          open.value = true;
        },
      ),
      const TourStep(
        anchor: 'test.inside',
        optional: true,
        title: 'عنصر داخلها',
        body: 'يظهر بعد الفتح',
      ),
      const TourStep(
        anchor: 'test.never',
        optional: true,
        title: 'غائب',
        body: 'لا يظهر',
      ),
      const TourStep(title: 'الختام', body: 'انتهينا'),
    ];
    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Builder(
              builder: (context) => Column(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: open,
                    builder: (_, v, _) => v
                        ? const Column(
                            children: [
                              TourAnchor(
                                id: 'test.drawer',
                                child: SizedBox(width: 80, height: 40),
                              ),
                              TourAnchor(
                                id: 'test.inside',
                                child: SizedBox(width: 80, height: 40),
                              ),
                            ],
                          )
                        : const SizedBox.shrink(),
                  ),
                  TextButton(
                    onPressed: () =>
                        MasarTour.maybeStart(context, id: 'b', steps: steps),
                    child: const Text('ابدأ'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('ابدأ'));
    await pumpFor(t, 2500);
    expect(find.text('البداية'), findsOneWidget);
    expect(ran, 0);

    await t.tap(find.text('التالي'));
    await pumpFor(t, 2500);
    expect(ran, 1);
    expect(find.text('داخل القائمة'), findsOneWidget);

    await t.tap(find.text('التالي'));
    await pumpFor(t, 2500);
    expect(find.text('عنصر داخلها'), findsOneWidget);

    await t.tap(find.text('التالي'));
    await pumpFor(t, 2500);
    expect(find.text('غائب'), findsNothing);
    expect(find.text('الختام'), findsOneWidget);
    await t.tap(find.text('لنبدأ'));
    await pumpFor(t, 1500);
    expect(ran, 1);
  });
}
