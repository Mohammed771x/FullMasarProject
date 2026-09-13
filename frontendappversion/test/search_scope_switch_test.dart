// 🔎 فتح نتيجة بحثٍ من **نطاقٍ آخر** — أخطر جزء في ميزة البحث.
//
// 🔴 **العطل الذي يحرسه هذا الملف:** البحث يعرض محادثات كل المواد، لكن
//    `loadConversation` تستعيد الرسائل و`selectedMode` فقط وتترك المادة
//    والصف على ما كانت عليه الشاشة. فطالبٌ في «فيزياء» يفتح نتيجةً من
//    «انجليزي» فيرى رسائل الإنجليزي بينما البوصلة تقول «فيزياء» — وأول
//    رسالةٍ بعدها تُرسَل **بمادةٍ خاطئة** وتُحفظ في **نطاقٍ خاطئ**، فتختلط
//    المحادثتان بلا رجعة.
//
// ⚠️ ونثبت الوصل **بالحالة لا بالإحداثيات** ([masar-testing-traps]).
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/config/curriculum.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/tutor_content_repository.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

/// مستودع محتوى وهمي — لا شبكة في اختبار.
///
/// ⚠️ `extends` لا `implements`: الصنف الأصلي concrete، والتنفيذ الكامل
///    لواجهته هنا ضجيجٌ لا يفيد. نُبدّل الدالة الوحيدة التي تلمس الشبكة.
class _FakeContent extends TutorContentRepository {
  _FakeContent({this.lessonsUnits = const []});

  final List<LessonsUnit> lessonsUnits;
  final List<String> askedSubjects = [];

  @override
  Future<SubjectCapabilities> getCapabilities(
      String subject, int grade, String track) async {
    askedSubjects.add(subject);
    return SubjectCapabilities(
      subject: subject,
      lessonsAvailable: lessonsUnits.isNotEmpty,
      pagesAvailable: false,
      lessonsUnits: lessonsUnits,
      pagesUnits: const [],
      quizAvailable: false,
    );
  }
}

ChatConversation _englishConv() => ChatConversation(
      id: "en-1",
      title: "شرح درس: Reading",
      subject: "انجليزي",
      mode: "شرح",
      grade: 3,
      track: "علمي",
      messages: [
        ChatMessage(role: "user", text: "اشرح لي القطعة"),
        ChatMessage(role: "assistant", text: "Skimming is reading quickly."),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('🔎 فتح نتيجة بحثٍ من نطاقٍ آخر', () {
    test('🔴 المادة تنتقل مع المحادثة — لا تبقى مادة الشاشة السابقة', () async {
      final content = _FakeContent();
      final c = ChatController(contentRepository: content)
        ..grade = 3
        ..track = TrackLabel.fromKey("علمي")
        ..selectedSubject = "فيزياء";

      await c.openFromSearch(_englishConv());

      expect(c.selectedSubject, "انجليزي",
          reason: "بقيت مادة الشاشة السابقة — سيُرسل السؤال التالي خطأً");
      expect(c.grade, 3);
      expect(c.track.key, "علمي");
      c.dispose();
    });

    test('الرسائل تُستعاد فعلاً لا العنوان وحده', () async {
      final c = ChatController(contentRepository: _FakeContent());
      await c.openFromSearch(_englishConv());

      expect(c.messages.length, 2);
      expect(c.messages.last["text"], contains("Skimming"));
      c.dispose();
    });

    test('⚡ قوائم الوحدات تُعاد قراءتها للمادة الجديدة', () async {
      // بلا هذا تبقى وحدات المادة السابقة معروضةً تحت اسم المادة الجديدة.
      final content = _FakeContent();
      final c = ChatController(contentRepository: content)
        ..selectedSubject = "فيزياء";

      await c.openFromSearch(_englishConv());

      expect(content.askedSubjects, contains("انجليزي"));
      c.dispose();
    });

    test('🔴 وضع الدروس بلا درس ⇒ تُفتح لوحة الإعدادات لا شاشةٌ مكسورة',
        () async {
      // ⚠️ رُصد في المحاكي: المحادثة لا تحفظ الدرس، فيعود الطالب إلى وضع
      //    دروسٍ بلا درس — وأي رسالةٍ بعدها تذهب باسم درسٍ فارغ فيردّ
      //    الخادم «المحتوى قيد الإضافة» على مادةٍ محتواها موجود.
      final content = _FakeContent(lessonsUnits: [
        const LessonsUnit(unit: "القواعد", lessons: ["Reading"]),
      ]);
      final c = ChatController(contentRepository: content);

      await c.openFromSearch(_englishConv());

      expect(c.selectedV3Lesson, isEmpty, reason: "الدرس غير محفوظ أصلاً");
      expect(c.showSettingsPanel, isTrue,
          reason: "يجب أن يُطلب من الطالب اختيار درسه بدل إرسالٍ فاشل");
      c.dispose();
    });

    test('مادةٌ لا تحتاج درساً ⇒ لا لوحة إعدادات تعترض الطالب', () async {
      // اللوحة تُفتح للحاجة لا دائماً: فتحُها بلا سبب خطوةٌ زائدة في كل مرة.
      final c = ChatController(contentRepository: _FakeContent());
      await c.openFromSearch(_englishConv());

      expect(c.showSettingsPanel, isFalse);
      c.dispose();
    });

    test('🎓 مادةٌ غير مقررة على الصف لا تُضبط — الحارس يبقى قائماً', () async {
      final c = ChatController(contentRepository: _FakeContent())
        ..selectedSubject = "فيزياء";

      final alien = ChatConversation(
        id: "x", title: "t", subject: "مادة-وهمية", mode: "شرح",
        grade: 3, track: "علمي",
        messages: [ChatMessage(role: "user", text: "س")],
      );
      await c.openFromSearch(alien);

      expect(c.selectedSubject, "فيزياء",
          reason: "مادة خارج منهج الصف لا يجوز أن تُضبط من محادثة قديمة");
      c.dispose();
    });
  });
}
