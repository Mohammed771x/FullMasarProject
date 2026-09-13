// 📋 مراجعة الاختبار — تُحفظ مع النتيجة فتبقى بعد إغلاق الشاشة.
//
// 🔴 **الفجوة التي تسدّها:** الأسئلة تعيش في ذاكرة `QuizController` وتختفي
//    بإغلاق الشاشة، فالمراجعة كانت متاحةً بعد الاختبار مباشرةً **وحدها**.
//    وطالبٌ يرى في «تحليل مستواي» أنه أخطأ قبل يومين لا يعرف ماذا أخطأ فيه.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';

QuizQuestion _q(String text, {int correct = 1}) => QuizQuestion(
      q: text,
      options: const ["أ", "ب", "ج", "د"],
      correctIndex: correct,
      topic: "الأكسدة",
      lesson: "التفاعلات",
    );

QuizResult _result({List<String> review = const []}) => QuizResult(
      id: "r1",
      subject: "كيمياء",
      grade: 3,
      track: "علمي",
      unit: "الوحدة الأولى",
      lessons: const ["التفاعلات"],
      score: 2,
      total: 3,
      wrong: const [],
      durationSec: 90,
      reviewRaw: review,
    );

void main() {
  group('📋 عنصر المراجعة', () {
    test('يحمل الخيارات كاملةً لا الصحيح وحده', () {
      // الطالب يحتاج أن يرى ما اختاره **بجانب** الصواب ليفهم أين ضلّ.
      final item = QuizReviewItem.from(_q("ما الأكسدة؟"), 3);
      expect(item.options.length, 4);
      expect(item.correctText, "ب");
      expect(item.chosenText, "د");
    });

    test('الصواب والخطأ يُحسبان من الاختيار', () {
      expect(QuizReviewItem.from(_q("س", correct: 1), 1).isCorrect, isTrue);
      expect(QuizReviewItem.from(_q("س", correct: 1), 2).isCorrect, isFalse);
    });

    test('🔴 «لم تُجب» حالةٌ ثالثة لا خطأ', () {
      // اختبارٌ استُؤنف ولم يكتمل يترك أسئلةً بلا إجابة، وعدُّها أخطاءً
      // يكذب على الطالب ويشوّه تحليل نقاط ضعفه.
      final skipped = QuizReviewItem.from(_q("س"), null);
      expect(skipped.isSkipped, isTrue);
      expect(skipped.isCorrect, isFalse);
      expect(skipped.chosenText, isNull);
    });

    test('يمرّ بالتسلسل ذهاباً وإياباً بلا فقد', () {
      final original = QuizReviewItem.from(_q("ما الأكسدة؟", correct: 2), 0);
      final back = QuizReviewItem.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(original.toJson()))));

      expect(back.question, original.question);
      expect(back.options, original.options);
      expect(back.correctIndex, original.correctIndex);
      expect(back.chosenIndex, original.chosenIndex);
      expect(back.lesson, original.lesson);
      expect(back.topic, original.topic);
    });

    test('🛟 اختيارٌ خارج المدى لا يُسقط الشاشة', () {
      final broken = QuizReviewItem.fromJson({
        "q": "س", "options": ["أ"], "correct": 9, "chosen": 7,
      });
      expect(broken.correctText, isEmpty);
      expect(broken.chosenText, isNull);
    });
  });

  group('🗂️ المراجعة داخل النتيجة', () {
    test('نتيجةٌ بلا مراجعة ⇒ `hasReview` خاطئة فلا يظهر الزرّ', () {
      // نتائج قديمة، أو مستعادة من السحابة (المراجعة لا تُرفع عمداً).
      expect(_result().hasReview, isFalse);
      expect(_result().review, isEmpty);
    });

    test('تُفكّ المراجعة المحفوظة كما حُفظت', () {
      final raw = [
        jsonEncode(QuizReviewItem.from(_q("س١", correct: 0), 0).toJson()),
        jsonEncode(QuizReviewItem.from(_q("س٢", correct: 1), 3).toJson()),
      ];
      final r = _result(review: raw);

      expect(r.hasReview, isTrue);
      expect(r.review.length, 2);
      expect(r.review.first.isCorrect, isTrue);
      expect(r.review.last.isCorrect, isFalse);
      expect(r.review.last.chosenText, "د");
    });

    test('🛟 عنصرٌ مشوّه يُتجاهل ولا يُسقط بقية المراجعة', () {
      final r = _result(review: [
        "{{{ليس JSON",
        jsonEncode(QuizReviewItem.from(_q("س سليم"), 1).toJson()),
      ]);
      expect(r.review.length, 1);
      expect(r.review.single.question, "س سليم");
    });

    test('📤 المراجعة **لا تُرفع** للسحابة — قرارٌ مقصود', () {
      // حجمها عشرة أضعاف بقية المستند وتُقرأ على نفس الجهاز غالباً،
      // ورفعها يضاعف تخزين كل طالبٍ مقابل استعمالٍ نادر.
      final doc = _result(review: [
        jsonEncode(QuizReviewItem.from(_q("س"), 1).toJson()),
      ]).toDoc();

      expect(doc.containsKey("review"), isFalse);
      expect(doc.containsKey("reviewRaw"), isFalse);
      // وبقية المستند كاملٌ كما كان.
      expect(doc["score"], 2);
      expect(doc["asked_per_lesson"], isNotNull);
    });

    test('نتيجةٌ عائدة من السحابة تصل بلا مراجعة ولا تنهار', () {
      final restored = QuizResult.fromDoc("x", _result().toDoc());
      expect(restored.hasReview, isFalse);
      expect(restored.score, 2);
    });
  });
}
