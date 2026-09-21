// 🎓 «لما أحوّل الصف — كلّ شي يتحوّل معه.»
//
// 🔴 **ما كان ينقص (٢٠٢٦-٠٩-٢٢):** الفصلُ بالنطاق مُحكَمٌ في المخزن
//    ([grade_isolation_storage_test]) وفي هيكل التبويبات
//    ([shell_scope_invalidation_test]) — وبقيت **شاشةُ المحادثة خارجهما**:
//    هي تُدفع **فوق** الهيكل، فلا يُبطلها إبطالُه، و[ChatController] يقرأ
//    الصفَّ **مرّةً في `init`** ثم يعيش. فمن بدّل صفَّه من الإعدادات ثم عاد
//    إلى محادثةٍ ما زالت في المكدّس بقي أمامه موادُّ صفٍّ تركه، **وأوّلُ
//    رسالةٍ يرسلها تذهب بصفٍّ خاطئ وتُحفظ في نطاقٍ خاطئ** — وهو أسوأ
//    الأعطال: كلُّ شيءٍ يبدو سليماً والوجهةُ وحدها خاطئة.
//
// 🔑 **والبابان يجب أن يتطابقا:** الصفُّ يُبدَّل من مكانين — درجِ المحادثة
//    وشاشةِ الإعدادات. وكان الدرجُ ينادي `updateProfile` (تكتب الحقلين
//    وتُخطر) بينما الإعداداتُ تنادي `setGrade` (تُسقط كاشَ حارس الأقسام في
//    الخادم وتُعيد جلب البانرات وتصحّح المسار). فعلٌ واحدٌ وسلوكان.
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ye_student_tutor/core/config/curriculum.dart';
import 'package:ye_student_tutor/core/session/user_session.dart';
import 'package:ye_student_tutor/features/chat/data/edu_session.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/tutor_content_repository.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

class _FakeContent extends TutorContentRepository {
  @override
  Future<SubjectCapabilities> getCapabilities(
          String subject, int grade, String track) async =>
      SubjectCapabilities(
        subject: subject,
        lessonsAvailable: false,
        pagesAvailable: false,
        lessonsUnits: const [],
        pagesUnits: const [],
      );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    EduSession.I.clear();
    UserSession.I
      ..isGuest = true // ⛔ فلا يُكتب شيءٌ في السحابة من اختبار
      ..grade = 3
      ..track = "علمي";
  });

  tearDown(() async {
    EduSession.I.clear();
    UserSession.I
      ..grade = 3
      ..track = "علمي";
  });

  test('☢️ تبديلُ الصف من خارج الشاشة يصل إلى المحادثة المفتوحة', () async {
    final c = ChatController(contentRepository: _FakeContent());
    await c.init();
    expect(c.grade, 3);
    expect(c.selectedSubject, "احياء");

    // 🎓 كما لو بدّله الطالب من شاشة الإعدادات والمحادثةُ تحتها في المكدّس.
    await UserSession.I.setGrade(1);
    await Future<void>.delayed(Duration.zero);

    expect(c.grade, 1, reason: 'المتحكّم ما زال على صفٍّ تركه الطالب');
    expect(c.track, Track.none, reason: 'الأول الثانوي موحّدٌ بلا مسار');
    expect(Curriculum.subjectsFor(1, Track.none), contains(c.selectedSubject));
    c.dispose();
  });

  test('☢️ والوضعُ يُصحَّح معه: وزاريُّ الثالث لا يبقى في الأول', () async {
    final c = ChatController(contentRepository: _FakeContent());
    await c.init(openMode: "وزاري");
    expect(c.selectedMode, "وزاري");

    await UserSession.I.setGrade(2);
    await Future<void>.delayed(Duration.zero);

    expect(c.selectedMode, isNot("وزاري"));
    expect(Curriculum.modesFor(c.selectedSubject, grade: c.grade),
        contains(c.selectedMode));
    c.dispose();
  });

  test('🚪 والبابان يتطابقان: تبديلُه من الدرج يكتب جلسةَ المستخدم', () async {
    final c = ChatController(contentRepository: _FakeContent());
    await c.init();

    await c.setGrade(2); // ← زرُّ الدرج
    expect(c.grade, 2);
    // 🔑 وهذه هي النقطة: بلا كتابةِ الجلسة لا يُسقَط كاشُ حارس الأقسام في
    //    الخادم ولا تُعاد البانرات — فيبقى الطالب يرى أقسام صفٍّ تركه.
    expect(UserSession.I.grade, 2);
    c.dispose();
  });

  test('🚪 والمسارُ كذلك', () async {
    final c = ChatController(contentRepository: _FakeContent());
    await c.init();

    await c.setTrack(Track.literary);
    expect(c.track, Track.literary);
    expect(UserSession.I.track, "أدبي");
    // 📚 وموادُّ الأدبي غيرُ موادّ العلمي — فالمادةُ المختارة تتبع القائمة.
    expect(Curriculum.subjectsFor(3, Track.literary), contains(c.selectedSubject));
    c.dispose();
  });

  test('🔁 ولا حلقةَ لا نهائية بين المتحكّم والجلسة', () async {
    final c = ChatController(contentRepository: _FakeContent());
    await c.init();
    // لو نادى المستمعُ `_onScopeChanged` على تبديلٍ انتهى، لدار بلا توقّف.
    await c.setGrade(1);
    await Future<void>.delayed(Duration.zero);
    expect(c.grade, 1);
    expect(UserSession.I.grade, 1);
    c.dispose();
  });

  test('🧹 والمستمعُ يُنزع عند إغلاق الشاشة', () async {
    final c = ChatController(contentRepository: _FakeContent());
    await c.init();
    c.dispose();
    // ⚠️ بلا النزع يُنادى متحكّمٌ ميت فيرمي «used after being disposed».
    await UserSession.I.setGrade(2);
    await Future<void>.delayed(Duration.zero);
    expect(UserSession.I.grade, 2);
  });
}
