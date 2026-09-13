import 'package:flutter/material.dart';
import '../../../../core/widgets/masar_markdown.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../data/models/quiz_models.dart';
import 'quiz_controller.dart';

// ==========================================
// 📋 راجع إجاباتك
// ==========================================
// أهم لحظة تعلّم في المنتج: يرى الطالب خطأه بجوار الصواب مباشرةً.
//
// 🔴 **وكانت متاحةً بعد الاختبار مباشرةً وحده.** الأسئلة تعيش في ذاكرة
//    `QuizController`، فبمجرد إغلاق الشاشة تختفي إلى الأبد. فطالبٌ يفتح
//    «تحليل مستواي» ويرى أنه أخطأ في «الأكسدة» قبل يومين **لا يستطيع أن
//    يعرف ماذا أخطأ فيه** — والتحليل يشخّص ولا يُري الدواء.
//
// ✅ فصارت الشاشة تقبل مصدرين، وتعرضهما بنفس الرسم حرفياً:
//    • [QuizReviewScreen.live]  ← جلسة الاختبار الجارية (كما كان)
//    • [QuizReviewScreen.saved] ← نتيجة محفوظة ([QuizResult.review])
class QuizReviewScreen extends StatelessWidget {
  const QuizReviewScreen._({required this.items, this.title});

  /// مراجعة الجلسة الجارية — الأسئلة ما زالت في الذاكرة.
  factory QuizReviewScreen.live({required QuizController controller}) {
    final qs = controller.questions;
    final answers = controller.answers;
    return QuizReviewScreen._(
      items: [
        for (var i = 0; i < qs.length; i++)
          QuizReviewItem.from(qs[i], i < answers.length ? answers[i] : null),
      ],
    );
  }

  /// مراجعة نتيجةٍ محفوظة — من سجلّ الاختبارات أو قسم التحليل.
  factory QuizReviewScreen.saved(QuizResult result) => QuizReviewScreen._(
        items: result.review,
        title: result.subject.isEmpty ? null : result.subject,
      );

  final List<QuizReviewItem> items;

  /// عنوانٌ فرعي يقول **أيّ اختبارٍ** نراجع — يلزم حين تُفتح من السجلّ.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final qs = items;

    // 🛟 نتيجةٌ قديمة حُفظت قبل وجود المراجعة، أو مستعادةٌ من السحابة (لا
    //    تُرفع المراجعة عمداً) ⇒ شاشةٌ تشرح بدل قائمةٍ فارغة تبدو عطلاً.
    if (qs.isEmpty) return _unavailable(context);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        centerTitle: true,
        title: Text(title == null ? "مراجعة الإجابات 📋" : "مراجعة: $title 📋",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      ),
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: qs.length,
          itemBuilder: (_, i) {
            final q = qs[i];
            final chosen = q.chosenIndex;
            final ok = q.isCorrect;

            return FadeInSlide(
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: (q.isSkipped
                              ? AppColors.textSecondary
                              : ok
                                  ? Colors.green
                                  : Colors.redAccent)
                          .withValues(alpha: 0.35),
                      width: 1.4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        // ⚠️ ثلاث حالات لا اثنتان: «لم تُجب» ليست خطأً.
                        //    اختبارٌ استُؤنف ولم يكتمل يترك أسئلةً بلا
                        //    إجابة، وعدُّها أخطاءً يكذب على الطالب.
                        Icon(
                            q.isSkipped
                                ? Icons.remove_circle_outline_rounded
                                : ok
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                            size: 19,
                            color: q.isSkipped
                                ? AppColors.textSecondary
                                : ok
                                    ? Colors.green.shade600
                                    : Colors.redAccent),
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
                    MathOrText(q.question,
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

  /// 🛟 لا مراجعة محفوظة — نقول السبب بدل قائمةٍ فارغة تبدو عطلاً.
  Widget _unavailable(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgLight,
        appBar: AppBar(
          backgroundColor: AppColors.surfaceWhite,
          elevation: 0,
          centerTitle: true,
          title: const Text("مراجعة الإجابات 📋",
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_toggle_off_rounded,
                    size: 44, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                const SizedBox(height: 14),
                Text(
                  "لا تتوفّر مراجعة لهذا الاختبار.\n"
                  "الاختبارات الجديدة تُحفظ مراجعتها تلقائياً على هذا الجهاز.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
}
