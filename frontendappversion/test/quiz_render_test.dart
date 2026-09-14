// ══════════════════════════════════════════════════
// 🧠🖌️ «اختبر نفسك» — السؤال والخيارات تُرسم لا تُكتب خاماً
// ══════════════════════════════════════════════════
//
// 🔴 **طلب المالك (2026-09-13):** «كل الأشياء اللي طبقناها في موضوع الرسّام
//    تتطبّق على اختبر نفسك — في كل مادة وكل فرع، عشان لما تطلع الأسئلة
//    والإجابات للطالب تطلع بشكل دقيق.»
//
// ⚖️ والخادمُ صار يُرسل الترميز في السؤال والخيارات والموضوع، فيبقى على
//    الشاشة أن **ترسمه كلَّه**: سؤالاً وخيارات ومراجعةً ونتيجة. وترميزٌ
//    خامٌ في اختبار = ثقةٌ مفقودة عند الطالب، أشدُّ من خطأٍ في شرح.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/presentation/quiz_review_screen.dart';

QuizQuestion _q(String text, List<String> options) => QuizQuestion(
      q: text,
      options: options,
      correctIndex: 0,
      topic: r"تركيز \frac{١}{٢}",
      lesson: "درس",
    );

QuizResult _resultWith(QuizQuestion question) => QuizResult(
      id: "r1",
      subject: "كيمياء",
      grade: 3,
      track: "علمي",
      unit: "وحدة",
      lessons: const ["درس"],
      score: 0,
      total: 1,
      wrong: const [],
      durationSec: 30,
      reviewRaw: [jsonEncode(QuizReviewItem.from(question, 1).toJson())],
    );

Future<void> _pumpReview(WidgetTester tester, QuizQuestion question) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: QuizReviewScreen.saved(_resultWith(question)),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('📋 شاشة المراجعة ترسم ما يصلها', () {
    testWidgets('⚗️ حلقةُ الكيمياء في نصّ السؤال تُرسم', (tester) async {
      await _pumpReview(tester, _q(r"ما اسم \ring{6|ar}؟",
          const ["البنزين", "الهكسان", "التولوين", "الفينول"]));

      expect(find.textContaining(r'\ring'), findsNothing,
          reason: 'ترميزٌ خام على شاشة الطالب');
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('🧮 كسرٌ في الخيارات الأربعة يُرسم كلُّه', (tester) async {
      await _pumpReview(tester, _q(
          r"ما ناتج \frac{١}{٢} + \frac{١}{٤}؟",
          const [r"\frac{٣}{٤}", r"\frac{١}{٣}", r"\frac{٢}{٣}", r"\frac{١}{٨}"]));

      expect(find.textContaining(r'\frac'), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('√ الجذر والأُسّ والمضروب كذلك', (tester) async {
      await _pumpReview(tester, _q(
          r"ما قيمة \sqrt{٢٥} + \fact{٣}؟",
          const [r"٨", r"\sup{٢}", r"\comb{ن}{ر}", r"١١"]));

      expect(find.textContaining(r'\sqrt'), findsNothing);
      expect(find.textContaining(r'\fact'), findsNothing);
      expect(find.textContaining(r'\comb'), findsNothing);
    });

    testWidgets('🛟 وسؤالٌ بلا ترميز يبقى نصّاً عادياً', (tester) async {
      await _pumpReview(tester, _q("ما تعريف التأكسد؟",
          const ["فقد إلكترونات", "كسب إلكترونات", "لا تغيّر", "انصهار"]));

      expect(find.textContaining("ما تعريف التأكسد؟"), findsWidgets);
    });

    testWidgets('🏷️ والموضوعُ المرسوم لا يظهر خاماً', (tester) async {
      // `topic` يحمل كسراً في هذه الحمولة — وتعرضه شاشتا النتيجة والتحليل.
      await _pumpReview(tester, _q("سؤال", const ["أ", "ب", "ج", "د"]));
      expect(find.textContaining(r'\frac'), findsNothing);
    });
  });

  group('🔤 الترميز يعبر التخزين سالماً', () {
    test('السؤال والخيارات تُحفظ وتُقرأ بترميزها', () {
      final item = QuizReviewItem.from(
          _q(r"ما اسم \ring{6|ar}؟",
              const [r"\chem{CH3-OH}", "ب", "ج", "د"]),
          0);
      final back = QuizReviewItem.fromJson(
          Map<String, dynamic>.from(jsonDecode(jsonEncode(item.toJson())) as Map));
      expect(back.question, contains(r"\ring{6|ar}"));
      expect(back.options.first, contains(r"\chem{CH3-OH}"));
    });
  });
}
