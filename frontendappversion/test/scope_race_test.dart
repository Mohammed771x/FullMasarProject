// ══════════════════════════════════════════════════
// 🎫 تبديلٌ سريع بين المواد — أيُّ قائمةٍ تصل، لأيّ مادةٍ هي؟
// ══════════════════════════════════════════════════
//
// 🔴 **العطل الذي تحرسه هذه الاختبارات:** كلُّ محمّلٍ في [ChatController]
//    يطلب باسم `selectedSubject` **لحظةَ الطلب**، ويكتب في حقولٍ مشتركة
//    **لحظةَ الوصول**. وبينهما رحلةُ شبكة لا يضمن أحدٌ ترتيبَ عودتها.
//
//    فطالبٌ يتصفّح المواد بسرعة — فيزياء ← كيمياء — يُطلق طلبين. فإن
//    تأخّرت فيزياء وعادت أخيراً كتبت قدراتِها **على كيمياء**: شجرةُ دروسٍ
//    من مادةٍ أخرى أمام الطالب، و`contentMode` يُحسم بقدراتٍ ليست لها،
//    وسؤالُه يمضي بدرسٍ لا وجود له في مادّته.
//
// ☢️ وأخطرُ ما فيه أنه **لا يبدو عطلاً**: لا استثناء ولا رسالة، شاشةٌ
//    كاملةٌ سليمةُ المظهر ومحتواها لمادةٍ تركها الطالب.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ye_student_tutor/core/session/user_session.dart';
import 'package:ye_student_tutor/features/chat/data/edu_session.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/tutor_content_repository.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

/// مستودعٌ نتحكّم في لحظة ردّه لكل مادة على حدة.
class _GatedContent extends TutorContentRepository {
  final Map<String, Completer<void>> gates = {};
  final Map<String, Completer<void>> unitGates = {};
  final List<String> asked = [];

  /// يجعل ردَّ [subject] معلّقاً حتى `release(subject)`.
  void hold(String subject) => gates[subject] = Completer<void>();
  void holdUnits(String subject) => unitGates[subject] = Completer<void>();
  void release(String subject) {
    for (final g in [gates[subject], unitGates[subject]]) {
      if (g != null && !g.isCompleted) g.complete();
    }
  }

  @override
  Future<SubjectCapabilities> getCapabilities(
      String subject, int grade, String track) async {
    asked.add(subject);
    final gate = gates[subject];
    if (gate != null) await gate.future;
    return SubjectCapabilities(
      subject: subject,
      lessonsAvailable: subject == "فيزياء",
      pagesAvailable: subject != "فيزياء",
      lessonsUnits: subject == "فيزياء"
          ? const [LessonsUnit(unit: "الذرّة", lessons: ["بوهر"])]
          : const [],
      pagesUnits: subject == "فيزياء" ? const [] : const ["وحدةُ كيمياء"],
    );
  }

  @override
  Future<List<String>> getUnits(String subject, int grade, String track) async {
    asked.add("units:$subject");
    final gate = unitGates[subject] ?? gates[subject];
    if (gate != null) await gate.future;
    return ["وحدةُ $subject"];
  }
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
  tearDown(() => EduSession.I.clear());

  test('☢️ قدراتُ مادةٍ متأخّرة لا تُكتب فوق المادة الحالية', () async {
    final content = _GatedContent()..hold("فيزياء");
    final c = ChatController(contentRepository: content);
    await c.init();
    addTearDown(c.dispose);

    // 1️⃣ فيزياء تنطلق وتتعلّق في الطريق.
    final slow = c.setSubject("فيزياء");
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.selectedSubject, "فيزياء");

    // 2️⃣ الطالب لم ينتظر: كيمياء تنطلق وتصل أولاً.
    await c.setSubject("كيمياء");
    expect(c.selectedSubject, "كيمياء");
    expect(c.caps?.subject, "كيمياء");

    // 3️⃣ والآن تصل فيزياء **متأخّرة** — ولا يجوز أن تمسّ شيئاً.
    content.release("فيزياء");
    await slow;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(c.selectedSubject, "كيمياء");
    expect(c.caps?.subject, "كيمياء",
        reason: '🔴 قدراتُ فيزياء كُتبت فوق كيمياء');
    expect(c.contentMode, "pages",
        reason: 'وضعُ العرض حُسم بقدرات مادةٍ أخرى');
  });

  test('☢️ ولا تُطفئ انتظارَ المادة الحالية', () async {
    // 🔴 `capsLoading = false` من طلبٍ قديم يجعل الشاشة تبدو جاهزةً
    //    بينما قدراتُ المادة الحالية ما زالت في الطريق.
    final content = _GatedContent()
      ..hold("فيزياء")
      ..hold("كيمياء");
    final c = ChatController(contentRepository: content);
    await c.init();
    addTearDown(c.dispose);

    unawaited(c.setSubject("فيزياء"));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    unawaited(c.setSubject("كيمياء"));
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.capsLoading, isTrue, reason: 'التهيئة نفسها خاطئة');

    content.release("فيزياء");
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(c.capsLoading, isTrue,
        reason: '🔴 طلبٌ قديم أطفأ انتظارَ المادة الحالية');

    content.release("كيمياء");
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(c.capsLoading, isFalse);
  });

  test('☢️ ووحداتُ مادةٍ منصرفة لا تُعرض في قائمة الحالية', () async {
    // 📐 الرياضياتُ وحدها تترك `caps` فارغةً في قسم الطالب، فتمضي إلى
    //    `/subjects/units` — وهو المسار الذي نقيسه هنا.
    final content = _GatedContent()..holdUnits("رياضيات");
    final c = ChatController(contentRepository: content);
    await c.init();
    addTearDown(c.dispose);

    final slow = c.setSubject("رياضيات");
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(content.asked, contains("units:رياضيات"), reason: 'التهيئة خاطئة');

    await c.setSubject("كيمياء");
    final unitsOfChemistry = List<String>.of(c.availableUnits);

    content.release("رياضيات");
    await slow;
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(c.availableUnits, isNot(contains("وحدةُ رياضيات")),
        reason: '🔴 وحداتُ مادةٍ تركها الطالب بقيت في قائمته');
    expect(c.availableUnits, unitsOfChemistry,
        reason: '🔴 قائمةُ الوحدات تبدّلت تحت الطالب بعد استقرارها');
  });
}
