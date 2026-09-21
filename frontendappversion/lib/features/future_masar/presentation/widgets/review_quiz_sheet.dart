import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_markdown.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../../quiz/data/models/quiz_models.dart';
import '../../../quiz/data/quiz_analytics.dart';
import '../../../quiz/presentation/widgets/quiz_ui.dart';
import 'analysis_ui.dart';

// ==========================================
// 📅 ورقةُ «اختبار مراجعة» — أسئلةٌ من أخطائك وحدها
// ==========================================
// ⭐ **الفرقُ عن «اختبر نفسك» العاديّ:** هناك يختار الطالبُ الدرسَ بنفسه،
//    وهنا **تُختار له دروسُه الضعيفة** من سجلّ أخطائه. وهذا هو ما يجعل
//    التحليلَ حلقةً مغلقة: تشخيصٌ ثم علاجٌ ثم قياس.
//
// 🗂️ **وكانت مكتوبةً داخل `analysis_screen`** (مئةُ سطرٍ في شاشةٍ تجاوزت
//    السبعمئة). فُصلت بأمر المالك «خلي كل قسمٍ في ملفٍ لحاله».

Future<void> showReviewQuizSheet(
  BuildContext context, {
  required List<SubjectStats> subjects,
  required List<QuizResult> results,
  required void Function(String subject, String unit, List<String> lessons)
      onStart,
}) {
  if (subjects.isEmpty) return Future.value();
  return showAnalysisSheet(
    context,
    _ReviewBody(subjects: subjects, results: results, onStart: onStart),
  );
}

class _ReviewBody extends StatefulWidget {
  const _ReviewBody(
      {required this.subjects, required this.results, required this.onStart});

  final List<SubjectStats> subjects;
  final List<QuizResult> results;
  final void Function(String subject, String unit, List<String> lessons) onStart;

  @override
  State<_ReviewBody> createState() => _ReviewBodyState();
}

class _ReviewBodyState extends State<_ReviewBody> {
  /// نبدأ بأضعف مادة — فهي الأولى بالمراجعة (القائمة مرتّبةٌ تنازلياً).
  late String _subject = widget.subjects.last.subject;

  @override
  Widget build(BuildContext context) {
    final spots = QuizAnalytics.weakSpots(
        widget.results.where((r) => r.subject == _subject).toList(),
        limit: 3);
    final unit = spots.isEmpty ? "" : spots.first.unit;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("اختبار مراجعة 📅",
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.headingInk)),
        const SizedBox(height: 16),
        const AnalysisSectionTitle("المادة:"),
        const SizedBox(height: 10),
        // 🔘 شرائحُ `QuizChip` نفسُها — شريحةُ المادة في شاشة الإعداد.
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: widget.subjects
              .map((s) => SizedBox(
                    width: 104,
                    child: QuizChip(
                      label: s.subject,
                      selected: s.subject == _subject,
                      onTap: () => setState(() => _subject = s.subject),
                    ),
                  ))
              .toList(),
        ),
        const SizedBox(height: 18),
        Row(children: [
          Icon(PI.sparkle.regular, size: 16, color: AppColors.primary),
          const SizedBox(width: 7),
          Expanded(
            child: Text("دروس مختارة من أخطائك السابقة:",
                style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: AppColors.headingInk,
                    fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 10),
        if (spots.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text("ما عندك أخطاء في «$_subject» 🎉 اختر مادة أخرى.",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.rowHint)),
          )
        else
          ...spots.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: QuizCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  child: Row(children: [
                    // ⚠️ RTL: علامةُ الاختيار أوّلُ ابنٍ ⇒ يميناً.
                    Icon(PI.checkCircle.fill,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                        child: MathOrText(s.lesson,
                            maxLines: 2,
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppColors.headingInk,
                                fontSize: 12))),
                    const SizedBox(width: 10),
                    QuizBadge(arabicMistakes(s.misses),
                        fill: AppColors.errorTint,
                        ink: AppColors.error500),
                  ]),
                ),
              )),
        const SizedBox(height: 22),
        QuizPrimaryButton(
          label: "ابدأ اختبار المراجعة",
          icon: PI.rocketLaunch,
          height: AnalysisMetrics.sheetButton,
          // ⚠️ **يُعطَّل ولا يُخفى** حين لا أخطاءَ في المادة المختارة: زرٌّ
          //    يختفي يترك الورقةَ تبدو معطوبة، والمعطَّلُ يقول «اختر أخرى».
          enabled: spots.isNotEmpty,
          onTap: () {
            Navigator.pop(context);
            widget.onStart(
                _subject, unit, spots.map((s) => s.lesson).toList());
          },
        ),
      ],
    );
  }
}
