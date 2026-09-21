// ══════════════════════════════════════════════════
// 🎯 ما يصل التطبيقَ من بنك الأسئلة
// ══════════════════════════════════════════════════
//
// ⚖️ **قرار المالك (2026-09-16):** «لما يتخزّن السؤال، لما يُنشل، تُنشل
//    أشياؤه والاختيارات حقّه وكل شيء» — فالسؤالُ ليس نصّاً بل **عقداً**:
//    خياراتُه وصوابُه ونقطتُه ودرسُه وسببُه ومعرّفُه.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_seen_store.dart';

Map<String, dynamic> _fromBank() => {
      "q": "ما قيمة النهاية نهـ (س←٠) جا س / س؟",
      "options": ["صفر", "١", "٢", "غير معرّفة"],
      "correct_index": 1,
      "topic": "القاعدة الأساسية نهـ (س←٠) جا س/س",
      "lesson": "أمثلة متقدمة في النهايات",
      "why": "القاعدة الأساسية في الدرس: نهـ (س←٠) جا س/س = ١.",
      "level": "مبتدئ",
      "weight": 5,
      "id": "abc123def456",
    };

void main() {
  group('📋 السؤالُ يصل كاملاً', () {
    test('يحمل السبب والمستوى والمعرّف زيادةً على ما كان', () {
      final q = QuizQuestion.fromJson(_fromBank());
      expect(q.options.length, 4);
      expect(q.correctIndex, 1);
      expect(q.topic, isNotEmpty);
      expect(q.why, isNotEmpty);
      expect(q.level, "مبتدئ");
      expect(q.id, "abc123def456");
    });

    test('🛟 وما وُلّد حيّاً يصل بلا سبب — ولا ينهار', () {
      final live = Map<String, dynamic>.from(_fromBank())
        ..remove("why")
        ..remove("level")
        ..remove("id");
      final q = QuizQuestion.fromJson(live);
      expect(q.why, isEmpty);
      expect(q.id, isEmpty);
      expect(q.q, isNotEmpty);
    });

    test('والسببُ يعبر إلى المراجعة المحفوظة ويعود منها', () {
      final q = QuizQuestion.fromJson(_fromBank());
      final item = QuizReviewItem.from(q, 0);
      final back = QuizReviewItem.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(item.toJson())) as Map));
      expect(back.why, q.why);
      expect(back.isCorrect, isFalse);
      expect(back.correctText, "١");
    });

    test('⚠️ ومراجعةٌ محفوظةٌ قبل هذا الحقل تُقرأ بلا سبب لا بانهيار', () {
      final old = {
        "q": "س", "options": ["أ", "ب", "ج", "د"],
        "correct": 0, "chosen": 1, "lesson": "د", "topic": "ن",
      };
      final back = QuizReviewItem.fromJson(old);
      expect(back.why, isEmpty);
      expect(back.correctText, "أ");
    });
  });

  group('🔁 ذاكرةُ «لا تُعده عليّ»', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('تحفظ وتُقرأ في نطاق الحساب والدروس', () async {
      final scope = QuizSeenStore.scopeOf("احياء", ["د١", "د٢"]);
      await QuizSeenStore.remember("uid1", scope, ["a", "b", "c"]);
      expect(await QuizSeenStore.read("uid1", scope), ["a", "b", "c"]);
      expect(await QuizSeenStore.read("uid2", scope), isEmpty);
    });

    test('ولا يتأثّر النطاقُ بترتيب اختيار الدروس', () {
      expect(QuizSeenStore.scopeOf("احياء", ["ب", "أ"]),
          QuizSeenStore.scopeOf("احياء", ["أ", "ب"]));
    });

    test('والأحدثُ أوّلاً، والقديمُ يسقط عند السقف', () async {
      final scope = QuizSeenStore.scopeOf("فيزياء", ["د"]);
      await QuizSeenStore.remember(
          "u", scope, [for (var i = 0; i < 50; i++) "old$i"]);
      await QuizSeenStore.remember(
          "u", scope, [for (var i = 0; i < 30; i++) "new$i"]);
      final got = await QuizSeenStore.read("u", scope);
      expect(got.length, QuizSeenStore.maxIds);
      expect(got.first, "new0");
      expect(got.contains("old49"), isFalse,
          reason: 'أقدمُ ما حُفظ لم يسقط عند السقف');
    });

    test('ولا تُكرَّر المعرّفات', () async {
      final scope = QuizSeenStore.scopeOf("كيمياء", ["د"]);
      await QuizSeenStore.remember("u", scope, ["x", "y"]);
      await QuizSeenStore.remember("u", scope, ["y", "z"]);
      final got = await QuizSeenStore.read("u", scope);
      expect(got, ["y", "z", "x"]);
    });
  });
}
