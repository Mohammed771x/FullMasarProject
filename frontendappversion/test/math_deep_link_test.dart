// 🧮 الفتح الموجَّه للرياضيات — «اشرح لي هذا الدرس» من شاشة التحليل.
//
// للرياضيات آلة حالة منفصلة (`selectedMathBranch` + `selectedLesson`)، ودروسها
// من `/math/lessons` لا من القدرات — و`loadCapabilities()` تضع `caps = null`
// لها. فأي منطقٍ يُعشَّش تحت `caps` لا يمسّ الرياضيات إطلاقاً (وهي العلّة التي
// أفلتت مرّتين: الشاشة تصل «وضع الشرح» وتقف بلا درس).
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/data/repositories/tutor_content_repository.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

class _FakeContent extends TutorContentRepository {
  _FakeContent(this.byBranch);
  final Map<String, List<String>> byBranch;
  final List<String> asked = [];

  @override
  Future<List<String>> getMathLessons(String branch, int grade, String track) async {
    asked.add(branch);
    return byBranch[branch] ?? const [];
  }
}

void main() {
  const lesson = "مشتقة الدالة اللوغاريتمية";
  final book = {
    "تفاضل": [lesson, "مبرهنة رول"],
    "تكامل": ["التكامل بالتجزئة"],
    "جبر": ["التباديل (ل)"],
  };

  test('الوحدة القادمة مع الدرس تُثبّت الفرع والدرس بنداءٍ واحد', () async {
    final fake = _FakeContent(book);
    final c = ChatController(contentRepository: fake);
    addTearDown(c.dispose);

    await c.applyMathDeepLink("تفاضل", lesson);

    expect(c.selectedMathBranch, "تفاضل");
    expect(c.selectedLesson, lesson);
    expect(c.mathMode, "شرح");
    expect(c.mathLessons, contains(lesson));
    expect(fake.asked, ["تفاضل"], reason: "لا يمسح الفروع بلا داعٍ");
  });

  test('وحدةٌ غائبة أو خاطئة ⇒ تُمسح الفروع حتى يُوجد الدرس', () async {
    final fake = _FakeContent(book);
    final c = ChatController(contentRepository: fake);
    addTearDown(c.dispose);

    await c.applyMathDeepLink("", lesson);

    expect(c.selectedMathBranch, "تفاضل");
    expect(c.selectedLesson, lesson);
    expect(fake.asked, isNotEmpty);
  });

  test('درسٌ لا وجود له لا يترك فرعاً مختاراً بلا درس', () async {
    final fake = _FakeContent(book);
    final c = ChatController(contentRepository: fake);
    addTearDown(c.dispose);

    await c.applyMathDeepLink("تفاضل", "درس غير موجود");

    expect(c.selectedMathBranch, isEmpty);
    expect(c.selectedLesson, isEmpty);
    expect(c.mathLessons, isEmpty);
  });

  test('درسٌ في فرعٍ آخر يُوجد ولو جاءت الوحدة خاطئة', () async {
    final fake = _FakeContent(book);
    final c = ChatController(contentRepository: fake);
    addTearDown(c.dispose);

    await c.applyMathDeepLink("تفاضل", "التكامل بالتجزئة");

    expect(c.selectedMathBranch, "تكامل");
    expect(c.selectedLesson, "التكامل بالتجزئة");
  });
}
