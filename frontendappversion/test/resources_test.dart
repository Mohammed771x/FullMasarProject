// مركز الموارد يتبع الصف والمسار: مواده = مواد الصف، وروابطه من resources.dart.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/config/curriculum.dart';
import 'package:ye_student_tutor/core/config/resources.dart';
import 'package:ye_student_tutor/features/chat/presentation/widgets/chat_dialogs.dart';

/// يفتح نافذة الموارد لصف/مسار معيّن ويعيد التحكّم بعد استقرار الأنيميشن.
Future<void> _openResources(WidgetTester tester, int grade, Track track) async {
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: Builder(
      builder: (context) => Scaffold(
        body: ElevatedButton(
          onPressed: () => ChatDialogs.showResources(context, grade: grade, track: track),
          child: const Text("افتح"),
        ),
      ),
    ),
  ));
  await tester.tap(find.text("افتح"));
  await tester.pumpAndSettle();
}

void main() {
  group('Resources — المصدر', () {
    test('الثالث العلمي وحده لديه روابط اليوم', () {
      expect(Resources.hasAny(3, Track.scientific), isTrue);
      expect(Resources.hasAny(3, Track.literary), isFalse);
      expect(Resources.hasAny(2, Track.scientific), isFalse);
      expect(Resources.hasAny(1, Track.none), isFalse);
    });

    test('كل مادة في الثالث العلمي لها روابط', () {
      for (final s in Curriculum.subjectsFor(3, Track.scientific)) {
        expect(Resources.forSubject(3, Track.scientific, s), isNotEmpty, reason: s);
      }
    });

    test('الصف الأول بلا مسار — normalizeTrack يمنع مفتاحاً خاطئاً', () {
      expect(Resources.scopeKey(1, Track.scientific), "g1|عام");
      expect(Resources.scopeKey(3, Track.none), "g3|علمي");
    });
  });

  group('مركز الموارد — النافذة', () {
    testWidgets('الثالث العلمي: مواد الصف الست بلا شارة «قريباً»', (tester) async {
      await _openResources(tester, 3, Track.scientific);

      expect(find.text("الثالث الثانوي · علمي"), findsOneWidget);
      for (final s in Curriculum.subjectsFor(3, Track.scientific)) {
        expect(find.text(Resources.displayName(s)), findsOneWidget, reason: s);
      }
      expect(find.text("قريباً"), findsNothing);
    });

    testWidgets('الثاني الأدبي: مواده هو، كلها «قريباً»', (tester) async {
      await _openResources(tester, 2, Track.literary);

      expect(find.text("الثاني الثانوي · أدبي"), findsOneWidget);
      final subjects = Curriculum.subjectsFor(2, Track.literary);
      for (final s in subjects) {
        expect(find.text(Resources.displayName(s)), findsOneWidget, reason: s);
      }
      // ولا مادة من الثالث العلمي الخاصة تظهر هنا
      expect(find.text(Resources.displayName("احياء")), findsNothing);
      expect(find.text("قريباً"), findsNWidgets(subjects.length));
    });

    testWidgets('الأول الثانوي: بلا مسار في الشارة', (tester) async {
      await _openResources(tester, 1, Track.scientific);
      expect(find.text("الأول الثانوي"), findsOneWidget);
    });
  });
}
