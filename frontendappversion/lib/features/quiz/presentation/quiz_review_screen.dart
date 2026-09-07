import 'package:flutter/material.dart';
import '../../../../core/widgets/masar_markdown.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fade_in_slide.dart';
import 'quiz_controller.dart';

// ==========================================
// 📋 راجع إجاباتك
// ==========================================
// الأسئلة ما زالت في ذاكرة الجلسة (لا تُخزَّن)، فالمراجعة مجانية وفورية —
// وهي أهم لحظة تعلّم: يرى الطالب خطأه بجوار الصواب مباشرةً.
class QuizReviewScreen extends StatelessWidget {
  final QuizController controller;
  const QuizReviewScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final qs = controller.questions;
    final answers = controller.answers;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        centerTitle: true,
        title: const Text("مراجعة الإجابات 📋",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: qs.length,
          itemBuilder: (_, i) {
            final q = qs[i];
            final chosen = i < answers.length ? answers[i] : null;
            final ok = q.isCorrect(chosen);

            return FadeInSlide(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: (ok ? Colors.green : Colors.redAccent).withValues(alpha: 0.35),
                      width: 1.4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
                            size: 19, color: ok ? Colors.green.shade600 : Colors.redAccent),
                        const SizedBox(width: 8),
                        Text("سؤال ${i + 1}",
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w900,
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        if (q.lesson.isNotEmpty)
                          Flexible(
                            child: Text("📖 ${q.lesson}",
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    MathOrText(q.q,
                        style: TextStyle(
                            fontSize: 14.5, height: 1.7,
                            fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    const SizedBox(height: 12),
                    ...List.generate(q.options.length, (j) {
                      final isRight = j == q.correctIndex;
                      final isChosen = j == chosen;
                      if (!isRight && !isChosen) {
                        return _plain(q.options[j]);
                      }
                      return _marked(
                        q.options[j],
                        right: isRight,
                        label: isRight
                            ? (isChosen ? "إجابتك ✅" : "الصحيحة ✅")
                            : "إجابتك ❌",
                      );
                    }),
                    if (q.topic.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                              color: AppColors.softSurface,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text("🏷️ ${q.topic}",
                              style: TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _plain(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("•  ", style: TextStyle(color: AppColors.textSecondary)),
            Expanded(
              child: MathOrText(text,
                  style: TextStyle(
                      fontSize: 13, height: 1.6, color: AppColors.textSecondary)),
            ),
          ],
        ),
      );

  Widget _marked(String text, {required bool right, required String label}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: (right ? Colors.green : Colors.redAccent).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: MathOrText(text,
                    style: TextStyle(
                        fontSize: 13, height: 1.6,
                        fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w900,
                      color: right ? Colors.green.shade700 : Colors.redAccent)),
            ],
          ),
        ),
      );
}
