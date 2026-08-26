// اختبار دخان بسيط: يتأكد أن جذر التطبيق يُبنى دون أخطاء.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/app/app.dart';

void main() {
  testWidgets('MasarApp builds without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MasarApp(home: Scaffold()));
    expect(find.byType(MasarApp), findsOneWidget);
  });
}
