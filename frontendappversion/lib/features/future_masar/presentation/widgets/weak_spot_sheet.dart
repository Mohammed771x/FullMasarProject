import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_markdown.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../../quiz/data/quiz_analytics.dart';
import '../../../quiz/presentation/widgets/quiz_ui.dart';
import 'analysis_ui.dart';

// ==========================================
// 🔍 تفصيل نقطة الضعف — أين ضعفك بالضبط داخل الدرس
// ==========================================
// الصفّ في شاشة التحليل **درسٌ واحد** بمجموع أخطائه (فلا يتكرّر الدرس).
// وهذه الورقة هي المستوى الثاني: المفاهيم داخله مرتّبةً بالأكثر خطأً —
// ليعرف الطالب أنه ضعيف في «تغيّر الإنتروبي» لا في «الديناميكا» كلها.
//
// 🎨 **إعادةُ التصميم (2026-09-21):** بمفردات `design/05-quiz/07-تقييم`
//    عبر [analysis_ui] — شارةُ النسبة من [QuizBadge]، والزرّان من
//    [QuizPrimaryButton] بارتفاع 53، والهيكلُ من [showAnalysisSheet].

Future<void> showWeakSpotSheet(
  BuildContext context,
  WeakSpot spot, {
  required VoidCallback onExplain,
  required VoidCallback onRetakeQuiz,
}) {
  return showAnalysisSheet(
    context,
    _WeakSpotBody(
        spot: spot, onExplain: onExplain, onRetakeQuiz: onRetakeQuiz),
  );
}

class _WeakSpotBody extends StatelessWidget {
  const _WeakSpotBody(
      {required this.spot, required this.onExplain, required this.onRetakeQuiz});

  final WeakSpot spot;
  final VoidCallback onExplain;
  final VoidCallback onRetakeQuiz;

  @override
  Widget build(BuildContext context) {
    final maxMisses = spot.topics.isEmpty
        ? 1
        : spot.topics.map((t) => t.misses).reduce((a, b) => a > b ? a : b);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🖌️ بالرسّام: اسمُ الدرس قد يكون صيغةً لا كلمة.
        MathOrText(spot.lesson,
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.headingInk)),
        const SizedBox(height: 5),
        Text("${spot.subject}${spot.unit.isEmpty ? '' : ' · ${spot.unit}'}",
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.rowHint)),
        const SizedBox(height: 12),
        // النسبة أولاً لأنها أساس الترتيب، والعيّنة بجوارها كي لا تُقرأ مجرّدة.
        Row(children: [
          // 🏷️ شارةُ النسبة بألوان التصدير: `#FCDFDF` بحبر `#ED2C2C`.
          Container(
            height: 28,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: AppColors.errorTint,
                borderRadius:
                    BorderRadius.circular(AnalysisMetrics.badgeRadius)),
            child: Text("${spot.errorRate}٪ نسبة الخطأ",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error500)),
          ),
          const SizedBox(width: 10),
          Text(
              spot.asked > 0
                  ? "${spot.misses} من ${spot.asked} سؤالاً"
                  : arabicMistakes(spot.misses),
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.rowHint)),
        ]),
        const SizedBox(height: 20),
        if (spot.topics.isEmpty)
          Text("لم تُسجَّل مفاهيم لهذا الدرس بعد.",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.rowHint))
        else ...[
          Row(children: [
            Icon(PI.target.regular, size: 16, color: AppColors.primary),
            const SizedBox(width: 7),
            Text("أين ضعفك بالضبط:",
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.headingInk,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          // شريطٌ نسبيٌّ لكل مفهوم — يُرى الفرق بلمحة لا بقراءة أرقام.
          ...spot.topics.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _TopicBar(topic: t, maxMisses: maxMisses),
              )),
        ],
        const SizedBox(height: 12),
        // 🔁 فعلان لا فعلٌ واحد: الشرح يعالج الضعف، وإعادة الاختبار تقيس
        //    هل زال — وبدونها يبقى الدرس «ضعيفاً» في القائمة أبداً لأن
        //    نسبة الخطأ لا تنزل إلا بمحاولة جديدة.
        QuizPrimaryButton(
          label: "اشرح لي هذا الدرس",
          icon: PI.bookOpen,
          height: AnalysisMetrics.sheetButton,
          onTap: () {
            Navigator.pop(context);
            onExplain();
          },
        ),
        const SizedBox(height: 10),
        // 🎨 ثانويٌّ بلغة التصدير: تعبئةٌ باهتةٌ بلون الهوية وحبرٌ أزرق.
        QuizPrimaryButton(
          label: "إعادة الاختبار على هذا الدرس",
          icon: PI.arrowCounterClockwise,
          height: AnalysisMetrics.sheetButton,
          fill: AppColors.quizTint,
          ink: AppColors.primary,
          onTap: () {
            Navigator.pop(context);
            onRetakeQuiz();
          },
        ),
      ],
    );
  }
}

class _TopicBar extends StatelessWidget {
  const _TopicBar({required this.topic, required this.maxMisses});

  final TopicMiss topic;
  final int maxMisses;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: MathOrText(topic.topic,
                  maxLines: 2,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingInk)),
            ),
            const SizedBox(width: 10),
            Text(arabicMistakes(topic.misses),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.error500)),
          ]),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: topic.misses / maxMisses,
              minHeight: 6,
              backgroundColor: AppColors.rowBorder,
              valueColor: AlwaysStoppedAnimation(AppColors.error500),
            ),
          ),
        ],
      );
}
