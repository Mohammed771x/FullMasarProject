// 🎯 اختيار دروس من **وحدات مختلفة** في «اختبر نفسك».
//
// العلّة التي يغطّيها هذا الملف: أضعف دروس الطالب موزّعة على وحدات بطبيعتها،
// وشاشة الإعداد كانت تقيّد الاختيار بوحدة واحدة — فيصل «اختبار المراجعة»
// بثلاثة دروس ويُعلَّم على أوّلها فقط، والباقي يسقط بصمت.
import 'package:flutter/material.dart';
import 'dart:io';

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

const _capsOneUnit = SubjectCapabilities(
  subject: 'كيمياء',
  lessonsAvailable: true,
  pagesAvailable: false,
  lessonsUnits: [
    LessonsUnit(unit: 'الكيمياء الحرارية', lessons: ['الطاقة', 'الإنثالبي']),
  ],
  pagesUnits: [],
  examsAvailable: true,
  quizAvailable: true,
);

class _FakeRepoOneUnit extends TutorContentRepository {
  _FakeRepoOneUnit() : super(ApiClient());
  @override
  Future<SubjectCapabilities> getCapabilities(
          String subject, int grade, String track) async =>
      _capsOneUnit;
}

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

Widget _screenOneUnit() => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: QuizSetupScreen(
          initialSubject: 'كيمياء',
          initialGrade: 3,
          initialTrack: 'علمي',
          repository: _FakeRepoOneUnit(),
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

    // 🎨 بعد إعادة التصميم صار العدّاد **شارةً** في رأس بطاقة الدروس
    //    («تم اختيار ٢») بدل شريط «المختارة (٢/٣)». والسلوكُ المحروس هو
    //    هو: درسٌ من وحدةٍ أخرى لا يسقط.
    expect(find.text('تم اختيار 2'), findsOneWidget,
        reason: 'سقط درسٌ لأنه من وحدة أخرى');
    // الدرس من وحدة غير المعروضة يُذكر باسم وحدته كي لا يبدو مفقوداً
    expect(find.textContaining('استقرار النواة'), findsWidgets);
    expect(find.textContaining('الإنثالبي'), findsWidgets);
  });

  testWidgets('تصفّح وحدة أخرى لا يمسح ما اخترته', (t) async {
    await t.pumpWidget(_screen(preset: const ['الإنثالبي']));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('تم اختيار 1'), findsOneWidget);

    // نغيّر الوحدة من القائمة المنسدلة
    await t.tap(find.byType(DropdownButton<String>).first);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    await t.tap(find.text('الطاقة والتفاعلات النووية').last);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));

    expect(find.text('تم اختيار 1'), findsOneWidget,
        reason: 'تغيير الوحدة مسح الاختيار');
  });

  testWidgets('بلا اقتراحات ⇒ لا شريط مختارة', (t) async {
    await t.pumpWidget(_screen());
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('تم اختيار'), findsNothing);
  });

  // ══════════════════════════════════════════════════
  // 🪜 ترتيبُ خطوات بطاقة الدروس
  // ══════════════════════════════════════════════════
  //
  // 🎯 **نصُّ المالك (2026-09-20):** «ضروري تخلّي الطالب يختار الوحدة…
  //    عنده مكتوب اختر الوحدة وبعدين اختر الدروس، وفوق هالاثنتين موجودة
  //    الدروس اللي اختارها».
  //
  // 🛡️ وترتيبُ عناصرٍ في `Column` **لا يحرسه أي اختبارٍ وظيفي**: بدّلْ
  //    سطرين فتبقى الشاشة عاملةً تماماً وتخالف الطلب. فيُقاس الموضع.
  testWidgets('⭐ المختارة فوق، ثم «اختر الوحدة»، ثم «اختر الدروس»', (t) async {
    await t.pumpWidget(_screen(preset: const ['الإنثالبي']));
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));

    double yOf(Finder f) => t.getTopLeft(f).dy;

    final chip = find.textContaining('الإنثالبي').first;
    final unitStep = find.text('اختر الوحدة').first;
    final lessonsStep = find.text('اختر الدروس');
    final firstRow = find.text('الطاقة');

    expect(lessonsStep, findsOneWidget, reason: 'عنوانُ خطوة الدروس غائب');
    expect(yOf(chip), lessThan(yOf(unitStep)),
        reason: 'المختارة يجب أن تكون فوق منتقي الوحدة');
    expect(yOf(unitStep), lessThan(yOf(lessonsStep)),
        reason: 'الوحدة قبل الدروس');
    expect(yOf(lessonsStep), lessThan(yOf(firstRow)),
        reason: 'عنوانُ الدروس فوق صفوفها');
  });

  // 🔴 كانت القائمة تُخفى حين للمادة وحدةٌ واحدة — «إخفاءٌ ذكيّ» يحذف
  //    الخطوةَ الأولى من أمام الطالب. المالك: «أول مرة ضروري».
  testWidgets('منتقي الوحدة يظهر ولو كانت الوحدةُ واحدة', (t) async {
    await t.pumpWidget(_screenOneUnit());
    await t.pump();
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(DropdownButton<String>), findsOneWidget);
    expect(find.text('اختر الوحدة'), findsWidgets);
  });

  // ══════════════════════════════════════════════════
  // 🎯 لا صفَّ ولا مسار في «اختبر نفسك»
  // ══════════════════════════════════════════════════
  //
  // 🔴 **قرار المالك (2026-09-09):** «ماشي داعي موجود الصف الدراسي والمسار،
  //    خلاص تطلع المواد حق المادة اللي مختارة من قبل الطالب».
  //
  // ⚖️ وهي نفس القاعدة المطبّقة على القائمة الجانبية: الطالب حسم صفَّه في
  //    إعداداته مرّةً واحدة، وإعادةُ سؤاله تُقحم قراراً محسوماً — بل وتُغري
  //    بتغييره فيمتحن نفسه في منهجٍ ليس منهجه.
  //
  // 🛡️ والحارسُ **بنيويّ على الملف** لا اختبارُ ويدجت: بناءُ شاشة الإعداد
  //    يستدعي شبكةً وتخزيناً، وحارسٌ لا يعمل إلا بمحاكاةِ نصفِ التطبيق
  //    يُعطَّل عند أول تغيير فيصير أخضرَ على عيبٍ قائم.
  group('🎯 نطاق «اختبر نفسك»', () {
    final src = File('lib/features/quiz/presentation/quiz_setup_screen.dart')
        .readAsStringSync();

    test('لا شريحة صفٍّ ولا مسار في شاشة الإعداد', () {
      for (final gone in ['_gradeChips', '_trackChips', '_setGrade', '_setTrack',
                          '"الصف الدراسي"', '"المسار"']) {
        expect(src.contains(gone), isFalse, reason: 'ما زال موجوداً: $gone');
      }
    });

    test('والمواد تُبنى من صفّ الطالب نفسه', () {
      // ⚠️ الحذفُ وحده لا يكفي: لو بُنيت المواد من ثابتٍ لظهرت مواد صفٍّ آخر.
      expect(src.contains('Curriculum.subjectsFor(_grade, _track)'), isTrue);
      expect(src.contains('UserSession.I.grade'), isTrue);
    });
  });

}