// 🔠 الرئيسيةُ والشريطُ السفليّ عند تكبير خطّ النظام.
//
// 🔴 **ما رُئي في المحاكي (فحص ٢٠٢٦-١٠-٠٢):**
//    • XXXL (حجمٌ عاديّ في إعدادات iOS): بطاقاتُ الإحصاء تفيض ٤px، وزرّا
//      «ابدأ التعلّم» و«فتح التحليل» مقصوصان، و«اختبر نفسك» صار «اختبر».
//    • أكبرُ أحجام الوصول: الزرّان **يختفيان**، والشريطُ يفيض ١٩px.
//
// ⚖️ `text_scale_test.dart` كان يغطّي شاشةَ التحديث وشارةَ الحصة وحدهما —
//    والرئيسيةُ التي انكسرت لم يكن لها اختبار.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ye_student_tutor/core/shell/masar_bottom_nav.dart';
import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/core/widgets/text_scale_clamp.dart';
import 'package:ye_student_tutor/features/future_masar/presentation/screens/home_tab.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_storage.dart';
import 'package:ye_student_tutor/features/saved/data/saved_storage.dart';

/// الرئيسيةُ كما تُعرض في القشرة: محتواها والشريطُ تحتها، بخطّ النظام [scale]
/// وخلف السقف نفسِه الذي يضعه جذرُ التطبيق ([TextScaleClamp]).
Widget _home(double scale) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: TextScaleClamp(
              child: Scaffold(
                body: HomeTab(onOpenTab: (_) {}),
                bottomNavigationBar: MasarBottomNav(
                  current: MasarTab.home,
                  onTap: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

/// زرّ البطاقة **داخلَ** بطاقته كاملاً — لا مقصوصاً بحافّتها.
void _expectInsideCard(WidgetTester tester, String label) {
  final text = find.text(label);
  expect(text, findsOneWidget, reason: "«$label» غير موجود");
  final card = find
      .ancestor(of: text, matching: find.byType(InkWell))
      .first;
  final t = tester.getRect(text);
  final c = tester.getRect(card);
  expect(
    t.top >= c.top - 0.5 && t.bottom <= c.bottom + 0.5,
    isTrue,
    reason: "«$label» مقصوصٌ بحافّة بطاقته: $t خارج $c",
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    // 🤖 الجولةُ أُكملت — وإلا غطّت الشاشة بطبقتها.
    SharedPreferences.setMockInitialValues({'tour_done_home': true});
    dir = await Directory.systemTemp.createTemp('home_scale');
    await ChatStorage.initForTests(dir.path);
    await QuizStorage.initForTests(dir.path);
    await SavedStorage.initForTests(dir.path);
  });

  tearDownAll(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  test('السقفُ ×١٫٣ — لا أقلّ فيُلغي التكبير ولا أكثر فيكسر الواجهة', () {
    expect(TextScaleClamp.maxScale, 1.3);
  });

  for (final size in const [Size(360, 640), Size(390, 844)]) {
    // 1.0 الافتراضي · 1.15 «كبير» · 1.35 XXXL · 2.0 و3.1 أحجامُ الوصول.
    for (final scale in const [1.0, 1.15, 1.35, 2.0, 3.1]) {
      testWidgets(
          '${size.width.toInt()}×${size.height.toInt()} عند ×$scale: '
          'لا فيض، والزرّان داخل بطاقتيهما', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_home(scale));
        await tester.pump(const Duration(milliseconds: 100));

        expect(tester.takeException(), isNull,
            reason: "فاضت الرئيسية أو الشريط عند ×$scale");
        _expectInsideCard(tester, "ابدأ التعلّم");
        _expectInsideCard(tester, "فتح التحليل");
        // 🔤 التبويبُ يُرى كاملاً لا «اختبر» وحدها.
        expect(find.text("اختبر نفسك"), findsOneWidget);

        // ⏱️ مؤقّتُ الجولة (٧٠٠ms) يُفرَّغ قبل نزع الشجرة.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
