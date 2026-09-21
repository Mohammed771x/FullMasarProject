// 🪑 «لو نزلت من التعليم ورجعت، يرجّعني لآخر محادثة وآخر مكان كنت فيه.»
//
// 🔴 **عطلُ المالك (٢٠٢٦-٠٩-٢٢):** قسمُ التعليم شاشةٌ تُدفع وتُنزع، ومتحكّمُها
//    يموت معها — فكلُّ عودةٍ كانت بدايةً: أوّلُ مادةٍ في قائمة الصف
//    («العربي» في الأول الثانوي) ومحادثةٌ فارغة. ومعه كان زرُّ «أكمل من حيث
//    توقفت» يفتح القسمَ **فارغاً** وهو يَعِد بالمتابعة.
//
// ⚠️ وأخطرُ ما في الاستعادة أن تُستعاد **في غير موضعها**: فوق فتحةٍ موجَّهة
//    من نتيجة اختبار، أو بعد تبديل الصف، أو لحسابٍ آخر على الجوال نفسه.
//    ولذلك أكثرُ ما هنا حرّاسُ امتناعٍ لا حرّاسُ استعادة.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/config/curriculum.dart';
import 'package:ye_student_tutor/core/session/user_session.dart';
import 'package:ye_student_tutor/features/chat/data/edu_session.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/tutor_content_repository.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/teacher/data/teacher_tool.dart';

/// مستودع محتوى وهمي — لا شبكة في اختبار.
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

ChatController _controller() => ChatController(contentRepository: _FakeContent());

EduPlace _place({
  String subject = "فيزياء",
  String mode = "تلخيص",
  int grade = 3,
  String track = "علمي",
  String uid = "",
  String? conversationId,
}) =>
    EduPlace(
      uid: uid,
      grade: grade,
      track: track,
      subject: subject,
      mode: mode,
      conversationId: conversationId,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    EduSession.I.clear();
    UserSession.I
      ..grade = 3
      ..track = "علمي";
  });

  tearDown(EduSession.I.clear);

  group('🪑 الاستعادة', () {
    test('يعود إلى المادة والوضع اللذين تركهما — لا إلى أوّل مادةٍ في القائمة', () async {
      EduSession.I.place = _place(subject: "فيزياء", mode: "تلخيص");
      final c = _controller();
      await c.init();

      expect(c.selectedSubject, "فيزياء");
      expect(c.selectedMode, "تلخيص");
      // 🧭 وأوّلُ مادةٍ في الثالث العلمي «احياء» — فلو لم تُستعد لظهرت هي.
      expect(Curriculum.defaultSubject(3, Track.scientific), "احياء");
    });

    test('والرياضيات بفرعها ووضعها — لها آلةُ حالةٍ مستقلّة', () async {
      EduSession.I.place = EduPlace(
        uid: "",
        grade: 3,
        track: "علمي",
        subject: "رياضيات",
        mode: "سؤال",
        mathBranch: "تكامل",
        mathMode: "سؤال",
      );
      final c = _controller();
      await c.init();

      expect(c.selectedSubject, "رياضيات");
      expect(c.selectedMathBranch, "تكامل");
      expect(c.mathMode, "سؤال");
      expect(c.selectedMode, "سؤال");
    });
  });

  group('🚧 ومتى لا تُستعاد', () {
    test('☢️ فتحةٌ موجَّهة (نتيجةُ اختبار) تسبق الجلسةَ ولا تنقضها', () async {
      EduSession.I.place = _place(subject: "فيزياء", mode: "تلخيص");
      final c = _controller();
      await c.init(openSubject: "كيمياء", openMode: "شرح");

      expect(c.selectedSubject, "كيمياء");
      expect(c.selectedMode, "شرح");
    });

    test('☢️ صفٌّ آخر: مكانُ «ثاني علمي» لا يُفتح لطالب «ثالث علمي»', () async {
      EduSession.I.place = _place(subject: "فيزياء", mode: "تلخيص", grade: 2);
      final c = _controller();
      await c.init();

      expect(c.selectedSubject, Curriculum.defaultSubject(3, Track.scientific));
    });

    test('☢️ مسارٌ آخر: «ثالث أدبي» لا يُفتح لطالب «ثالث علمي»', () async {
      EduSession.I.place = _place(subject: "عربي", mode: "شرح", track: "أدبي");
      final c = _controller();
      await c.init();

      expect(c.selectedSubject, "احياء");
    });

    test('☢️ حسابٌ آخر على الجوال نفسه لا يرث مكانَ من قبله', () async {
      EduSession.I.place = _place(uid: "uid-someone-else");
      final c = _controller();
      await c.init();

      expect(c.selectedSubject, "احياء");
    });

    test('☢️ مادةٌ ليست من مواد الصف تُهمَل بلا انهيار', () async {
      // «تاريخ» مادةُ الأدبي — ولو وصلت بطريقةٍ ما لصار الطالب في مادةٍ
      // لا قائمةَ لها ولا محتوى، وكلُّ طلبٍ بعدها يُرَدّ.
      EduSession.I.place = _place(subject: "تاريخ", mode: "شرح");
      final c = _controller();
      await c.init();

      expect(c.selectedSubject, "احياء");
    });

    // ☢️ **الحارسُ الذي يربط التعديلين معاً.** طالبٌ كان في الثالث ووضعِ
    //    «وزاري»، ثم بدّل صفَّه إلى الأول: شريحةُ الوزاري لم تعد مرسومةً
    //    أصلاً ([Curriculum.modesFor])، فاستعادةُ الوضع كانت ستضعه في وضعٍ
    //    لا زرَّ له على الشاشة — لا يخرج منه ولا يفهم أين هو.
    test('☢️ وضعٌ لم يعد لهذا الصف (وزاريٌّ في الأول) يسقط ويبقى «شرح»', () async {
      UserSession.I
        ..grade = 1
        ..track = "عام";
      EduSession.I.place =
          _place(subject: "فيزياء", mode: "وزاري", grade: 1, track: "عام");
      final c = _controller();
      await c.init();

      expect(c.selectedSubject, "فيزياء", reason: 'المادةُ تُستعاد');
      expect(c.selectedMode, "شرح", reason: 'والوضعُ المحذوف لا');
    });

    // ☢️ **العطلُ الذي رُصد في المحاكي (٢٠٢٦-٠٩-٢٢):** زرُّ «أكمل من حيث
    //    توقفت» التقط محادثةَ معلّمٍ فأخذ معها وضعَها `معلم:plan`. مُنقّى
    //    عند المصدر الآن، وهذا حارسٌ ثانٍ كي لا يعتمد الصحُّ على مصدرٍ بعينه.
    test('☢️ ومكانٌ يحمل وضعَ معلّمٍ لا يُفتح في قسم التعليم', () async {
      EduSession.I.place = _place(subject: "فيزياء", mode: "معلم:plan");
      final c = _controller();
      await c.init();

      expect(c.selectedSubject, "احياء", reason: 'لا يُستعاد شيءٌ منه');
      expect(c.selectedMode, "شرح");
    });

    test('👨‍🏫 وقسمُ المعلم لا يستعيد مكانَ الطالب', () async {
      EduSession.I.place = _place(subject: "فيزياء", mode: "تلخيص");
      final c = _controller();
      await c.init(teacher: TeacherTool.lessonPlan);

      expect(c.selectedMode, "معلم:plan");
    });
  });

  group('📸 الالتقاط', () {
    test('المكانُ يُلتقط بالمادة والوضع والوحدة والدرس', () {
      final c = _controller()
        ..grade = 3
        ..selectedSubject = "كيمياء"
        ..selectedMode = "شرح"
        ..contentMode = "lessons"
        ..selectedV3Unit = "الوحدة الأولى"
        ..selectedV3Lesson = "الروابط";
      c.rememberPlace();

      final p = EduSession.I.place!;
      expect(p.subject, "كيمياء");
      expect(p.contentMode, "lessons");
      expect(p.unit, "الوحدة الأولى");
      expect(p.lesson, "الروابط");
    });

    test('ومحادثةٌ بلا رسالةٍ واحدة لا تُطلب — فهي غير محفوظة أصلاً', () {
      final c = _controller()..selectedSubject = "احياء";
      c.createNewConversation();
      expect(c.currentConversationId, isNotNull);

      c.rememberPlace();
      expect(EduSession.I.place!.conversationId, isNull);
    });

    test('👨‍🏫 والمعلّمُ لا يكتب في جلسة قسم التعليم', () {
      final c = _controller()..teacherTool = TeacherTool.homework;
      c.rememberPlace();
      expect(EduSession.I.place, isNull);
    });
  });

  group('🔁 زرُّ «أكمل من حيث توقفت»', () {
    test('يكتب وجهتَه في الجلسة — وهي الآليّةُ نفسُها لا مسارٌ ثانٍ', () {
      final conv = ChatConversation(
        id: "conv-42",
        title: "شرح درس",
        subject: "انجليزي",
        mode: "تلخيص",
        grade: 3,
        track: "علمي",
      );
      EduSession.I.rememberConversation(conv, "uid-1");

      final p = EduSession.I.place!;
      expect(p.conversationId, "conv-42");
      expect(p.subject, "انجليزي");
      expect(p.mode, "تلخيص");
      expect(p.matches("uid-1", 3, "علمي"), isTrue);
      expect(p.matches("uid-2", 3, "علمي"), isFalse);
      expect(p.matches("uid-1", 2, "علمي"), isFalse);
    });

    test('ومحادثةُ رياضياتٍ تحمل فرعَها ووضعَها لا وضعَ الطالب العام', () {
      final conv = ChatConversation(
        id: "m-1",
        title: "وزاري",
        subject: "رياضيات",
        mode: "وزاري",
        branch: "جبر",
        grade: 3,
        track: "علمي",
      );
      EduSession.I.rememberConversation(conv, "uid-1");

      final p = EduSession.I.place!;
      expect(p.mathBranch, "جبر");
      expect(p.mathMode, "وزاري");
    });
  });
}
