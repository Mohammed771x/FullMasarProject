// ══════════════════════════════════════════════════
// ⚡ الشرحُ المخزون يصل **على طول** — بلا رحلةِ شبكةٍ عند الضغط
// ══════════════════════════════════════════════════
//
// 🔴 **علّةُ المالك (2026-09-16):** «لما أضغط شرح المفروض على طول يطلع لي
//    الشرح، ما ينتظر ثانيتين ولا ثلاثة — كما قسم الوزارة.»
//
// ⚖️ وقياسُ الخادم برّأ الجواب واتّهم الطريق: قراءةُ الشرح من القرص **مللي
//    ثانيةٌ واحدة**، بينما المسار رحلةُ شبكةٍ + حرّاسُ `/ask` + خصمُ الحصة
//    من Firestore **ثم ردُّها**. فصار يُسحب لحظةَ اختيار الدرس، وتصير
//    الضغطةُ عرضاً من الذاكرة.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/data/models/ask_response.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/chat_repository.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/tutor_content_repository.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

const String _stored = "### 🎯 الفكرة الكبرى\nشرحٌ مخزونٌ كاملٌ للدرس.";

/// مستودعُ محتوى يسلّم شرحاً مخزوناً — ويَعدّ كم مرّة سُئل.
class _FakeContent extends TutorContentRepository {
  final String answer = _stored;
  int pulls = 0;
  final List<String> asked = [];

  @override
  Future<String> getStoredExplanation(String subject, String unit,
      String lesson, int grade, String track) async {
    pulls++;
    asked.add("$grade|$track|$subject|$unit|$lesson");
    return answer;
  }
}

/// مستودعُ سؤالٍ يصرخ إن نُودي — فالمخزونُ يجب ألّا يمرّ به أصلاً.
class _ForbiddenChat extends ChatRepository {
  int calls = 0;

  @override
  Future<AskResponse> ask({
    required String userId,
    required String requestId,
    required String subject,
    required String mode,
    required String inputType,
    required int summaryLevel,
    required String lessonName,
    required String content,
    required String unitName,
    required List<Map<String, dynamic>> chatHistory,
    required int grade,
    required String track,
    String? contentMode,
    List<String> imagesBase64 = const [],
    String? idToken,
  }) async {
    calls++;
    return const AskResponse(
        answer: "من الموديل", references: [], sessionActive: false);
  }
}

SubjectCapabilities _caps() => SubjectCapabilities.fromJson({
      "subject": "احياء",
      "lessons": {
        "available": true,
        "units": [
          {"unit": "الجهاز العصبي", "lessons": ["الخلية العصبية", "السيال العصبي"]}
        ],
      },
      "pages": {"available": false, "units": [], "unit_pages": {}, "max_selectable": 3},
    });

ChatController _controller(_FakeContent content, {ChatRepository? chat}) {
  final c = ChatController(contentRepository: content, chatRepository: chat)
    ..selectedSubject = "احياء"
    ..selectedMode = "شرح"
    ..contentMode = "lessons"
    ..caps = _caps();
  return c;
}

void main() {
  group('⚡ السحبُ المسبق — يبدأ باختيار الدرس', () {
    test('اختيارُ الدرس يسحب شرحَه المخزون فوراً', () async {
      final content = _FakeContent();
      final c = _controller(content);
      addTearDown(c.dispose);

      c.setV3Unit("الجهاز العصبي");
      c.setV3Lesson("الخلية العصبية");
      await Future<void>.delayed(Duration.zero);

      expect(content.pulls, 1, reason: 'لم يُسحب الشرحُ عند الاختيار');
      expect(content.asked.single, "3|علمي|احياء|الجهاز العصبي|الخلية العصبية");
    });

    test('ولا يتكرّر النداءُ ما دام الدرسُ هو هو', () async {
      final content = _FakeContent();
      final c = _controller(content);
      addTearDown(c.dispose);

      c.setV3Unit("الجهاز العصبي");
      c.setV3Lesson("الخلية العصبية");
      await Future<void>.delayed(Duration.zero);
      for (var i = 0; i < 5; i++) {
        c.update(() {});
      }
      await Future<void>.delayed(Duration.zero);

      expect(content.pulls, 1, reason: 'نداءٌ مكرّرٌ بلا تغيّر درس');
    });

    test('وتبديلُ الدرس يسحب الجديد', () async {
      final content = _FakeContent();
      final c = _controller(content);
      addTearDown(c.dispose);

      c.setV3Unit("الجهاز العصبي");
      c.setV3Lesson("الخلية العصبية");
      await Future<void>.delayed(Duration.zero);
      c.setV3Lesson("السيال العصبي");
      await Future<void>.delayed(Duration.zero);

      expect(content.pulls, 2);
      expect(content.asked.last, endsWith("السيال العصبي"));
    });

    test('⛔ ولا سحبَ بلا درسٍ مختار — لا شيءَ ليُشرح', () async {
      final content = _FakeContent();
      final c = _controller(content);
      addTearDown(c.dispose);

      c.setV3Unit("الجهاز العصبي");
      await Future<void>.delayed(Duration.zero);

      expect(content.pulls, 0);
    });

    test('⛔ ولا في وضع الوحدات: مدخلُه صفحاتٌ لا درس', () async {
      final content = _FakeContent();
      final c = _controller(content)..contentMode = "pages";
      addTearDown(c.dispose);

      c.setV3Lesson("الخلية العصبية");
      await Future<void>.delayed(Duration.zero);

      expect(content.pulls, 0);
    });

    test('⛔ ولا في وضع التلخيص أو السؤال: المخزونُ شرحٌ ولا شيءَ غيره',
        () async {
      for (final mode in ["تلخيص", "سؤال"]) {
        final content = _FakeContent();
        final c = _controller(content)..selectedMode = mode;
        addTearDown(c.dispose);
        c.setV3Unit("الجهاز العصبي");
        c.setV3Lesson("الخلية العصبية");
        await Future<void>.delayed(Duration.zero);
        expect(content.pulls, 0, reason: 'سُحب مخزونٌ لوضع «$mode»');
      }
    });
  });

  group('⚡ الضغطةُ تعرض من الذاكرة', () {
    test('«اشرح لي» تعرض المخزونَ بلا نداءِ الخادم أصلاً', () async {
      final content = _FakeContent();
      final chat = _ForbiddenChat();
      final c = _controller(content, chat: chat);
      addTearDown(c.dispose);

      c.setV3Unit("الجهاز العصبي");
      c.setV3Lesson("الخلية العصبية");
      await Future<void>.delayed(Duration.zero);

      await c.processRequest(customText: ChatController.explainLessonText);

      expect(chat.calls, 0, reason: '☢️ ذهب إلى الخادم ومعه الجوابُ في يده');
      final last = c.messages.last;
      expect(last["role"], "ai");
      expect(last["text"], _stored);
      expect(last["cached"], isTrue);
    });

    test('⌨️ ويُكتب كغيره — الفرقُ أنه يبدأ من اللحظة الأولى', () async {
      // ⚖️ **تصحيحُ المالك (2026-09-16):** «خلّه يطلع يكتب مثل الدروس
      //    الباقية وكأنه بثّ، بس توّه على طول بسرعة يكتب — يا إما تطبّق
      //    الشيء كامل يا إما لا.»
      //
      // 🔴 وكنتُ أطفأتُ الطابعةَ للمخزون ظنّاً أنها هي البطء. وهي ليست
      //    إبطاءً بل **شكلَ الجواب في هذا التطبيق**: جوابٌ يهبط كتلةً
      //    واحدةً يبدو غريباً عمّا حوله. الذي كان يزعج المالكَ هو
      //    **الانتظارُ قبل أول حرف** — وذاك صار صفراً بالسحب المسبق.
      final content = _FakeContent();
      final c = _controller(content, chat: _ForbiddenChat());
      addTearDown(c.dispose);

      c.setV3Unit("الجهاز العصبي");
      c.setV3Lesson("الخلية العصبية");
      await Future<void>.delayed(Duration.zero);
      await c.processRequest(customText: ChatController.explainLessonText);

      expect(c.messages.last["animating"], isTrue,
          reason: '☢️ هبط الجوابُ كتلةً — لا يشبه بقيةَ المحادثة');
    });

    test('ورسالةُ الطالب تُحفظ قبله — فسؤالُه التالي يمضي ومعه الشرح',
        () async {
      final content = _FakeContent();
      final c = _controller(content, chat: _ForbiddenChat());
      addTearDown(c.dispose);

      c.setV3Unit("الجهاز العصبي");
      c.setV3Lesson("الخلية العصبية");
      await Future<void>.delayed(Duration.zero);
      await c.processRequest(customText: ChatController.explainLessonText);

      final history = c.buildChatHistory();
      expect(history.any((m) => m["role"] == "assistant"), isTrue,
          reason: 'الشرحُ لم يدخل سجلَّ المحادثة — فسؤالُه التالي بلا سياق');
    });

    test('⛔ وسؤالٌ حقيقيّ لا يُبتلع: يمضي إلى الموديل كما كان', () async {
      final content = _FakeContent();
      final chat = _ForbiddenChat();
      final c = _controller(content, chat: chat);
      addTearDown(c.dispose);

      c.setV3Unit("الجهاز العصبي");
      c.setV3Lesson("الخلية العصبية");
      await Future<void>.delayed(Duration.zero);

      await c.processRequest(customText: "بسّط لي الشرح");

      expect(c.messages.last["cached"], isNull,
          reason: '☢️ رُدّ على سؤالٍ خاصٍّ بشرحٍ مخزون');
    });

    test('⛔ وبعد أوّل جوابٍ لا مخزون: من شُرح له يريد متابعةً لا نسخة',
        () async {
      final content = _FakeContent();
      final c = _controller(content, chat: _ForbiddenChat());
      addTearDown(c.dispose);

      c.setV3Unit("الجهاز العصبي");
      c.setV3Lesson("الخلية العصبية");
      await Future<void>.delayed(Duration.zero);
      // ⚠️ المحادثةُ تُنشأ أولاً: `processRequest` تُنشئها إن غابت فتمسح
      //    ما وُضع فيها يدوياً ([createNewConversation]).
      c.createNewConversation();
      c.messages.add({"role": "ai", "text": "جوابٌ سابق", "refs": const []});

      await c.processRequest(customText: ChatController.explainLessonText);

      expect(c.messages.last["cached"], isNull);
    });
  });

  group('🧮 والرياضياتُ تدخل من الباب نفسه', () {
    test('اختيارُ درسِ رياضياتٍ يسحب شرحَه المخزون', () async {
      final content = _FakeContent();
      final c = ChatController(contentRepository: content)
        ..selectedSubject = "رياضيات"
        ..selectedMode = "شرح"
        ..mathMode = "شرح"
        ..selectedMathBranch = "هندسة";
      addTearDown(c.dispose);

      c.update(() => c.selectedLesson = "القطع المكافئ");
      await Future<void>.delayed(Duration.zero);

      expect(content.pulls, 1);
      expect(content.asked.single, "3|علمي|رياضيات|هندسة|القطع المكافئ");
    });
  });
}
