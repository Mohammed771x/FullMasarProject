// ==========================================
// 💡 اقتراحاتُ الوضع — لكل وضعٍ ما يناسبه
// ==========================================
// ⚖️ **قرار المالك (2026-09-16):** «اقتراحات مناسبة لكل وضع. وركّز في زرّ
//    اشرح لي — خلّه باين أفضل، لما يضغط عليه يشرح له على طول من المخزون.»
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/data/models/ask_response.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/teacher/data/teacher_tool.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

SubjectCapabilities _caps() => SubjectCapabilities.fromJson({
      "subject": "احياء",
      "lessons": {
        "available": true,
        "units": [
          {"unit": "الجهاز العصبي", "lessons": ["الخلية العصبية"]}
        ],
      },
      "pages": {"available": true, "units": ["الجهاز العصبي"],
                "unit_pages": {"الجهاز العصبي": [9, 10]}, "max_selectable": 3},
    });

ChatController _withLesson({String mode = "شرح"}) {
  final c = ChatController()
    ..selectedSubject = "احياء"
    ..selectedMode = mode
    ..contentMode = "lessons"
    ..selectedV3Unit = "الجهاز العصبي"
    ..selectedV3Lesson = "الخلية العصبية"
    ..caps = _caps();
  return c;
}

void main() {
  group('📖 الزرُّ البارز — مفتاحُ المخزون', () {
    test('يظهر في وضع الشرح ودرسٌ مختار، وهو الوحيدُ البارز', () {
      final c = _withLesson();
      addTearDown(c.dispose);
      final primary = c.suggestions.where((s) => s.primary).toList();
      expect(primary.length, 1);
      expect(primary.single.label, "اشرح لي");
      expect(primary.single.send, isTrue);
    });

    test('☢️ ونصُّه حرفياً ما يقبله المخزون على الخادم', () {
      // 🔴 لو تغيّرت هذه الجملة بلا تغيير `is_full_lesson_request` معها،
      //    سقط الكاشُ **بصمت**: الزرُّ يعمل والشرحُ يُولَّد في كل مرة،
      //    فتضيع الميزةُ كلُّها ولا يشتكي أحد.
      expect(ChatController.explainLessonText, "اشرح لي هذا الدرس");
      final c = _withLesson();
      addTearDown(c.dispose);
      expect(c.suggestions.firstWhere((s) => s.primary).text,
          ChatController.explainLessonText);
    });

    test('ولا يظهر بلا درسٍ مختار — لا شيءَ ليُشرح', () {
      final c = _withLesson()..selectedV3Lesson = "";
      addTearDown(c.dispose);
      expect(c.suggestions.any((s) => s.primary), isFalse);
      expect(c.suggestions, isNotEmpty);      // وتبقى الشرائحُ العادية
    });
  });

  group('🎚️ لكل وضعٍ اقتراحُه', () {
    test('التلخيصُ يقترح تلخيصاً لا شرحاً', () {
      final c = _withLesson(mode: "تلخيص");
      addTearDown(c.dispose);
      final p = c.suggestions.firstWhere((s) => s.primary);
      expect(p.label, "لخّص لي");
      expect(p.text, isNot(contains('اشرح')));
    });

    test('⚠️ ووضعُ السؤال قوالبُ تُملأ ولا تُرسل', () {
      // وضعُ السؤال يشترط أن يكتب الطالبُ سؤاله ([questionNeedsTypedText]).
      // فقالبٌ ناقصٌ يُرسل يضيع من حصّته بلا فائدة.
      final c = _withLesson(mode: "سؤال");
      addTearDown(c.dispose);
      expect(c.suggestions, isNotEmpty);
      expect(c.suggestions.every((s) => !s.send), isTrue);
      expect(c.suggestions.any((s) => s.primary), isFalse);
    });

    test('والوزاريُّ بلا اقتراحات — له أزرارُه', () {
      final c = _withLesson(mode: "وزاري");
      addTearDown(c.dispose);
      expect(c.suggestions, isEmpty);
    });

    // 👨‍🏫 قرار المالك (٢٠٢٦-٠٩-٢٤): اقتراحاتُ المعلّم بقاعدة الطالب —
    //    لكل أداةٍ اقتراحاتُها، فوق الحقل قبل أول ردّ ثم في ذيل الردّ.
    test('وقسمُ المعلّم له اقتراحاتُ أداته — «اسأل» تبدأ بها', () {
      final c = _withLesson()..teacherTool = TeacherTool.ask;
      addTearDown(c.dispose);
      expect(c.suggestions.map((s) => s.label),
          TeacherTool.ask.suggestions);
    });

    test('وأدواتُ التوليد والتبسيط لا تقترح قبل أول ردّ', () {
      for (final t in [
        TeacherTool.lessonPlan,
        TeacherTool.homework,
        TeacherTool.simplify,
      ]) {
        final c = _withLesson()..teacherTool = t;
        addTearDown(c.dispose);
        expect(c.suggestions, isEmpty, reason: t.id);
        c.messages = [
          {"role": "user", "text": "س"},
          {"role": "ai", "text": "ج"},
        ];
        expect(c.suggestions.map((s) => s.label), t.suggestions,
            reason: 'بعد الردّ الأول — ${t.id}');
        c.messages.addAll([
          {"role": "user", "text": "س"},
          {"role": "ai", "text": "ج٢"},
        ]);
        expect(c.suggestions, isEmpty, reason: 'جولتان ثم تغيب — ${t.id}');
      }
    });
  });

  group('🔄 وتتبدّل بعد أول جواب', () {
    test('⏳ وتنطفئ بعد جولتين — «الثالثة خلاص ما عاد شي داعي»', () {
      // قرارُ المالك (2026-09-16). والحدُّ ليس تجميلاً: الاقتراحُ يخدم
      // **البداية**؛ فمن سأل مرّتين فقد عرف ما يستطيع طلبه، وبقاؤها بعدها
      // يضيّق الشاشةَ ويغري بضغطةٍ بلا حاجة تُخصم من حصّته.
      final c = _withLesson();
      addTearDown(c.dispose);
      c.messages = [
        {"role": "user", "text": "س"}, {"role": "ai", "text": "ج١"},
        {"role": "user", "text": "س"}, {"role": "ai", "text": "ج٢"},
      ];
      expect(c.suggestions, isEmpty);
    });

    test('وثلاثُ شرائحَ في وضع الشرح مع الزرّ البارز', () {
      final c = _withLesson();
      addTearDown(c.dispose);
      expect(c.suggestions.where((s) => !s.primary).length, 3);
    });

    test('شرائحُ البداية تصير شرائحَ متابعة', () {
      final c = _withLesson();
      addTearDown(c.dispose);
      expect(c.suggestions.any((s) => s.primary), isTrue);

      c.messages = [
        {"role": "user", "text": "اشرح"},
        {"role": "ai", "text": "الشرح…"},
      ];
      final after = c.suggestions;
      expect(after.any((s) => s.primary), isFalse);
      expect(after.map((s) => s.label), contains('بسّط لي'));
      expect(after.every((s) => s.send), isTrue);
    });

    test('⚠️ ولا شريحةَ متابعةٍ قبل أن يُشرح شيء', () {
      // «بسّط لي» بلا جوابٍ سابق تُنتج رداً بلا معنى وتُستهلك من الحصة.
      final c = _withLesson();
      addTearDown(c.dispose);
      expect(c.suggestions.map((s) => s.label), isNot(contains('بسّط لي')));
    });
  });

  group('⚡ وسمُ «من المحفوظ»', _cachedBadgeTests);

  group('👆 وتنفيذُ الاقتراح', () {
    test('القالبُ يملأ الحقل ويضع المؤشّر في آخره', () {
      final c = _withLesson(mode: "سؤال");
      addTearDown(c.dispose);
      final s = c.suggestions.first;
      c.applySuggestion(s);
      expect(c.inputController.text, s.text);
      expect(c.inputController.selection.baseOffset, s.text.length);
    });

    test('ونصُّ الشريحة أطولُ من عنوانها — اختصارٌ على العين لا على الموديل', () {
      final c = _withLesson();
      addTearDown(c.dispose);
      final chip = c.suggestions.firstWhere((s) => s.label == 'مثال من الحياة');
      expect(chip.text.length, greaterThan(chip.label.length));
      expect(chip.text, contains('الحياة اليومية'));
    });
  });
}

// ==========================================
// ⚡ وسمُ «من المحفوظ» — أن يُرى لا أن يُحزَر
// ==========================================
// ⚖️ سأل المالك (2026-09-16): «سويت اشرح لي، بس ما أدري هل يجي من المخزون
//    ولا ما يجي». فالجوابُ يجب أن يكون **على الشاشة** لا في قياسٍ عندنا.
void _cachedBadgeTests() {
  test('الاستجابةُ تقرأ العلم من الخادم', () {
    final r = AskResponse.fromJson({"answer": "شرح", "cached": true});
    expect(r.cached, isTrue);
    expect(AskResponse.fromJson({"answer": "شرح"}).cached, isFalse);
  });
}
