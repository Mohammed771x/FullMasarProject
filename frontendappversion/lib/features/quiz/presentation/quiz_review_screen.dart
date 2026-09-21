import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/masar_markdown.dart';
import '../../../core/widgets/phosphor.dart';
import '../data/models/quiz_models.dart';
import 'quiz_controller.dart';
import 'widgets/quiz_ui.dart';

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
//
// 🎨 **إعادة التصميم** (`design/05-quiz/08-راجع إجاباتك`): رأسٌ فيه العنوان
//    وأيقونتُه وزرُّ رجوعٍ 32 · بطاقةٌ لكل سؤال r16 · الصحيحُ في صندوقٍ أخضر
//    والمختارُ الخاطئ في أحمر وشارةُ «إجابتك» في نهاية السطر · والبدائلُ
//    الباقية أسطراً باهتة · وشارةُ الموضوع كهرمانيّةٌ في الأسفل.
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

  String get _title => title == null ? "مراجعة الإجابات" : "مراجعة: $title";

  @override
  Widget build(BuildContext context) {
    final qs = items;

    // 🛟 نتيجةٌ قديمة حُفظت قبل وجود المراجعة، أو مستعادةٌ من السحابة (لا
    //    تُرفع المراجعة عمداً) ⇒ شاشةٌ تشرح بدل قائمةٍ فارغة تبدو عطلاً.
    if (qs.isEmpty) return _unavailable(context);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(
              QuizMetrics.margin, 27, QuizMetrics.margin, 28),
          itemCount: qs.length + 1,
          itemBuilder: (_, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: QuizHeader(
                  title: _title,
                  fontSize: 17,
                  iconSize: 28,
                  icon: PD.notePencil,
                  art: null,
                  onBack: () => Navigator.pop(context),
                ),
              );
            }
            return FadeInSlide(child: _card(qs[i - 1], i - 1));
          },
        ),
      ),
    );
  }

  // ───────────────────── بطاقةُ سؤال ─────────────────────

  Widget _card(QuizReviewItem q, int i) {
    final chosen = q.chosenIndex;
    final ok = q.isCorrect;
    final ltr = isLatinCard(q.question, q.options);

    // ⚠️ ثلاث حالات لا اثنتان: «لم تُجب» ليست خطأً. اختبارٌ استُؤنف ولم
    //    يكتمل يترك أسئلةً بلا إجابة، وعدُّها أخطاءً يكذب على الطالب.
    final Color state = q.isSkipped
        ? AppColors.chipInk
        : (ok ? AppColors.quizRight : AppColors.quizWrong);
    final IconData stateIcon = q.isSkipped
        ? PI.warningCircle.fill
        : (ok ? PI.checkCircle.fill : PI.xCircle.fill);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: QuizCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                // ⚠️ RTL: «سؤال ن» أوّلُ ابنٍ ⇒ يميناً، وأيقونتُها إلى يسارها.
                Text("سؤال ${i + 1}",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.panelTitle)),
                const SizedBox(width: 7),
                Icon(stateIcon, size: 17, color: state),
                const Spacer(),
                if (q.lesson.isNotEmpty)
                  Flexible(
                    child: Container(
                      height: 23,
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 9),
                      decoration: BoxDecoration(
                        color: AppColors.quizTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(q.lesson,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                          ),
                          const SizedBox(width: 6),
                          Icon(PI.bookOpen.regular,
                              size: 13, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            MathOrText(q.question,
                forceLtr: ltr,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    fontWeight: FontWeight.w900,
                    color: AppColors.panelTitle)),
            const SizedBox(height: 12),
            for (var j = 0; j < q.options.length; j++)
              if (j == q.correctIndex || j == chosen)
                _marked(
                  q.options[j],
                  ltr: ltr,
                  right: j == q.correctIndex,
                  label: j == q.correctIndex
                      ? (j == chosen ? "إجابتك" : "الصحيحة")
                      : "إجابتك",
                )
              else
                _plain(q.options[j], ltr: ltr),
            // 💡 **لماذا هذا هو الصواب** — أهمُّ سطرٍ في الشاشة.
            //
            // 🔴 كانت المراجعةُ تُري الطالبَ **ما** الصواب ولا تقول
            //    **لماذا**، واختبارٌ لا يُصحَّح تقييمٌ لا تعليم.
            //    ويأتي من البنك المخزون؛ فإن وُلّد السؤالُ حيّاً
            //    بقي فارغاً واختفى السطرُ بلا فراغٍ يشغل الشاشة.
            if (q.why.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.quizTint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border(
                    right: BorderSide(color: AppColors.primary, width: 3),
                  ),
                ),
                child: MathOrText("💡 ${q.why}",
                    forceLtr: isLatinSentence(q.why),
                    style: TextStyle(
                        fontSize: 12,
                        height: 1.7,
                        fontWeight: FontWeight.w600,
                        color: AppColors.panelTitle)),
              ),
            ],
            if (q.topic.isNotEmpty) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 25),
                  alignment: Alignment.center,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.quizTagFill,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.quizTagBorder)),
                  // 🖌️ بالرسّام: الموضوع قد يكون صيغةً لا كلمة —
                  //    و[MathOrText] تعود نصّاً عادياً حين لا ترميز.
                  child: MathOrText("🏷️ ${q.topic}",
                      maxLines: 2,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.quizTagInk)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// بديلٌ لم يُختر ولم يكن صواباً — سطرٌ باهتٌ بنقطةٍ في بدايته.
  Widget _plain(String text, {bool ltr = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("•  ",
                style: TextStyle(
                    fontSize: 12, color: AppColors.quizCheckBorder)),
            Expanded(
              child: MathOrText(text,
                  forceLtr: ltr,
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cardHint)),
            ),
          ],
        ),
      );

  /// الصوابُ أو ما اختاره الطالب — صندوقٌ ملوّنٌ وشارةٌ في نهاية السطر.
  Widget _marked(String text,
          {required bool right, required String label, bool ltr = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color:
                right ? AppColors.quizRightFill : AppColors.quizWrongFill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: right ? AppColors.quizRight : AppColors.quizWrong),
          ),
          child: Row(
            children: [
              Expanded(
                child: MathOrText(text,
                    forceLtr: ltr,
                    style: TextStyle(
                        fontSize: 11,
                        height: 1.6,
                        fontWeight: FontWeight.w800,
                        color: AppColors.panelTitle)),
              ),
              const SizedBox(width: 8),
              Container(
                height: 22,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 📐 الحبرُ كحليٌّ والعلامةُ ملوّنة — كما في `08`
                    //    بالضبط (قِستُ الشارة: `#091E42` للنصّ و`#20D958`
                    //    للصحّ).
                    Text(label,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: AppColors.panelTitle)),
                    const SizedBox(width: 5),
                    Icon(right ? PI.check.bold : PI.x.bold,
                        size: 11,
                        color: right
                            ? AppColors.quizRight
                            : AppColors.quizWrong),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  /// 🛟 لا مراجعة محفوظة — نقول السبب بدل قائمةٍ فارغة تبدو عطلاً.
  Widget _unavailable(BuildContext context) => Scaffold(
        backgroundColor: AppColors.bgLight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                QuizMetrics.margin, 27, QuizMetrics.margin, 28),
            child: Column(
              children: [
                QuizHeader(
                  title: _title,
                  fontSize: 17,
                  iconSize: 28,
                  icon: PD.notePencil,
                  art: null,
                  onBack: () => Navigator.pop(context),
                ),
                const Spacer(),
                Icon(PI.clockCounterClockwise.regular,
                    size: 44, color: AppColors.quizCheckBorder),
                const SizedBox(height: 14),
                Text(
                  "لا تتوفّر مراجعة لهذا الاختبار.\n"
                  "الاختبارات الجديدة تُحفظ مراجعتها تلقائياً على هذا الجهاز.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      fontWeight: FontWeight.w600,
                      color: AppColors.chipInk),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      );
}
