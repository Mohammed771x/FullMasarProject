// 🎯 اختيار دروس من **وحدات مختلفة** في «اختبر نفسك».
//
// العلّة التي يغطّيها هذا الملف: أضعف دروس الطالب موزّعة على وحدات بطبيعتها،
// وشاشة الإعداد كانت تقيّد الاختيار بوحدة واحدة — فيصل «اختبار المراجعة»
// بثلاثة دروس ويُعلَّم على أوّلها فقط، والباقي يسقط بصمت.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/network/api_client.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/tutor_content_repository.dart';
import 'package:ye_student_tutor/features/quiz/presentation/quiz_setup_screen.dart';

const _caps = SubjectCapabilities(
  subject: 'كيمياء',
  lessonsAvailable: true,
  pagesAvailable: false,
  lessonsUnits: [
    LessonsUnit(unit: 'الكيمياء الحرارية', lessons: ['الطاقة', 'الإنثالبي']),
    LessonsUnit(
        unit: 'الطاقة والتفاعلات النووية',
        lessons: ['اكتشاف النظائر', 'استقرار النواة']),
  ],
  pagesUnits: [],
  examsAvailable: true,
  quizAvailable: true,
);

class _FakeRepo extends TutorContentRepository {
  _FakeRepo() : super(ApiClient());
  @override
  Future<SubjectCapabilities> getCapabilities(
          String subject, int grade, String track) async =>
      _caps;
}

Widget _screen({List<String>? preset, String? unit}) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: QuizSetupScreen(
          initialSubject: 'كيمياء',
          initialGrade: 3,
          initialTrack: 'علمي',
          presetUnit: unit,
          presetLessons: preset,
          repository: _FakeRepo(),
        ),
      ),
    );

void main() {
  testWidgets('⭐ دروس مقترحة من وحدتين ⇒ كلاهما يبقى مختاراً', (t) async {
    await t.pumpWidget(_screen(
      preset: const ['الإنثالبي', 'استقرار النواة'],
      unit: 'الكيمياء الحرارية',
    ));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    expect(find.text('المختارة (2/3)'), findsOneWidget,
        reason: 'سقط درسٌ لأنه من وحدة أخرى');
    // الدرس من وحدة غير المعروضة يُذكر باسم وحدته كي لا يبدو مفقوداً
    expect(find.textContaining('استقرار النواة'), findsWidgets);
    expect(find.textContaining('الإنثالبي'), findsWidgets);
  });

  testWidgets('تصفّح وحدة أخرى لا يمسح ما اخترته', (t) async {
    await t.pumpWidget(_screen(preset: const ['الإنثالبي']));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('المختارة (1/3)'), findsOneWidget);

    // نغيّر الوحدة من القائمة المنسدلة
    await t.tap(find.byType(DropdownButton<String>).first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('الطاقة والتفاعلات النووية').last);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('المختارة (1/3)'), findsOneWidget,
        reason: 'تغيير الوحدة مسح الاختيار');
  });

  testWidgets('بلا اقتراحات ⇒ لا شريط مختارة', (t) async {
    await t.pumpWidget(_screen());
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('المختارة'), findsNothing);
  });
}
