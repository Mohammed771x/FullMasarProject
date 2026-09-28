// 🎭 جولةُ «تحليل مستواي» على مثالٍ توضيحي — في ملفٍّ وحده لأن
//    `SharedPreferences.setMockInitialValues` يبقى لبقيّة اختبارات الملف، فيوقظ
//    تلميحاتِ شاشاتٍ أخرى (مؤقّتاتها تبقى معلّقة) في اختباراتٍ لا شأن لها به.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ye_student_tutor/features/future_masar/presentation/screens/analysis_screen.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_storage.dart';

const _owner = 'owner-1';

Widget _app(Widget child) => MaterialApp(
  home: Directionality(textDirection: TextDirection.rtl, child: child),
);

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('analysis_tour_demo');
    await QuizStorage.initForTests(dir.path);
  });

  tearDownAll(() async {
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  // 🎭 أمرُ المالك (٢٠٢٦-٠٩-٢٧): جولةُ الشرح لا تشرح شاشةً فارغة — تعرض
  //    مثالاً توضيحياً **في الذاكرة** ثم تعود الشاشةُ إلى حقيقتها بلا أثر.
  testWidgets('🎭 بلا نتائج ⇒ الجولةُ تشرح على مثالٍ ثم تعود الشاشةُ فارغة', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await t.pumpWidget(_app(const AnalysisScreen(ownerUid: _owner)));
    for (var i = 0; i < 60; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('ملخص أدائك العام'), findsOneWidget);
    expect(find.text('لا يوجد تحليل بعد'), findsNothing);
    expect(find.text('إغلاق'), findsOneWidget);

    await t.tap(find.text('إغلاق'));
    for (var i = 0; i < 40; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('ملخص أدائك العام'), findsNothing);
    expect(find.text('لا يوجد تحليل بعد'), findsOneWidget);
    expect(QuizStorage.all(_owner), isEmpty, reason: 'المثالُ لا يُحفظ');
  });
}
