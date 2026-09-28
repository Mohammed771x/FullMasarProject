// 🎭 جولةُ «اختبر نفسك» على مادةٍ بلا دروس (أمرُ المالك ٢٠٢٦-٠٩-٢٧):
//    تُعرض دروسٌ «(مثال)» أثناء الشرح وحده، ثم تعود الشاشةُ إلى «لم تُضف بعد».
//    ⚠️ ملفٌّ وحده: `setMockInitialValues` يتسرّب إلى بقيّة الملف
//    ([robot-tour-guidance]). ولا `pumpAndSettle` — الروبوتُ يطفو بلا توقّف.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ye_student_tutor/core/network/api_client.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/tutor_content_repository.dart';
import 'package:ye_student_tutor/features/quiz/presentation/quiz_setup_screen.dart';

class _EmptyRepo extends TutorContentRepository {
  _EmptyRepo() : super(ApiClient());
  @override
  Future<SubjectCapabilities> getCapabilities(
    String subject,
    int grade,
    String track,
  ) async => SubjectCapabilities(
    subject: subject,
    lessonsAvailable: false,
    pagesAvailable: false,
    lessonsUnits: const [],
    pagesUnits: const [],
  );
}

void main() {
  Future<void> pumpFor(WidgetTester t, int ms) async {
    for (var i = 0; i < ms ~/ 50; i++) {
      await t.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets('مادةٌ بلا دروس ⇒ أمثلةٌ أثناء الجولة ثم تعود فارغة', (t) async {
    SharedPreferences.setMockInitialValues({});
    t.view.physicalSize = const Size(1206, 2622);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: QuizSetupScreen(
            initialSubject: 'عربي',
            initialGrade: 1,
            initialTrack: 'عام',
            repository: _EmptyRepo(),
          ),
        ),
      ),
    );
    await pumpFor(t, 3500);

    expect(find.text('هنا تختبر نفسك'), findsOneWidget);
    expect(find.text('الدرس الأول (مثال)'), findsWidgets);
    expect(find.textContaining('لم تُضف بعد'), findsNothing);

    await t.tap(find.text('إغلاق'));
    await pumpFor(t, 1500);
    expect(find.text('هنا تختبر نفسك'), findsNothing);
    expect(find.text('الدرس الأول (مثال)'), findsNothing);
    expect(find.textContaining('لم تُضف بعد'), findsOneWidget);
  });
}
