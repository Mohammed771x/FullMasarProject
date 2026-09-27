import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/features/future_masar/presentation/widgets/everywhere_scene.dart';

// 📱 مشهد «أنا معك في كل شاشة»: تتقلّب الشاشاتُ بترتيبها، ويتوقّف التقليبُ
//    خارج صفحته، ولا يبقى مؤقّتٌ معلّق بعد النزع.
Widget _host(Widget child, {bool still = false}) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: still),
      child: Center(child: SizedBox(width: 340, height: 360, child: child)),
    ),
  ),
);

void main() {
  testWidgets('تتقلّب الشاشات: الرئيسية ← مسار ← اختبر نفسك ← المنح', (
    tester,
  ) async {
    await tester.pumpWidget(_host(const EverywhereScene()));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.text('الرئيسية'), findsOneWidget);

    for (final next in ['مسار', 'اختبر نفسك', 'المنح', 'الرئيسية']) {
      // دورةٌ واحدة بالضبط (٢٨٠٠) — مقسومةً كي تُرسم الإطاراتُ بينها:
      // المؤقّت ثم الاختباء (٢٦٠) ثم التبديل.
      await tester.pump(const Duration(milliseconds: 2400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text(next), findsOneWidget, reason: next);
    }

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('خارج صفحته لا يتقلّب', (tester) async {
    await tester.pumpWidget(_host(const EverywhereScene(active: false)));
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('الرئيسية'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('تقليل الحركة: الشاشة الأولى ثابتة', (tester) async {
    await tester.pumpWidget(_host(const EverywhereScene(), still: true));
    await tester.pump(const Duration(seconds: 7));
    expect(find.text('الرئيسية'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
