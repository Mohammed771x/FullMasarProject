import 'package:flutter/material.dart';

import '../../../../core/config/curriculum.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/storage/chat_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../../../core/widgets/screen_tip.dart';
import '../../../chat/presentation/screens/main_chat_screen.dart';
import '../../../quiz/data/models/quiz_models.dart';
import '../../../quiz/data/quiz_analytics.dart';
import '../../../quiz/data/quiz_storage.dart';
import '../../../quiz/presentation/quiz_setup_screen.dart';
import '../../../quiz/presentation/widgets/quiz_ui.dart';
import '../widgets/analysis_ui.dart';
import '../widgets/review_quiz_sheet.dart';
import '../widgets/student_profile_card.dart';
import '../widgets/weak_spot_sheet.dart';
import 'settings_screen.dart';
import 'subject_analysis_screen.dart';

// ==========================================
// 👤📊 «معلومات الطالب» — وفيها «تحليل مستواي»
// ==========================================
// 🎨 **المصدر:** `design/03-home/21-معلومات.png` و`22-معلومات.png`.
//
// 🔴 **صوابُ المالك (2026-09-21):** «التحليل حوّلناه إلى قسم الطالب… دوّر
//    في فيجما بتحصل تحليل مستواي، تظهر لما نضغط على الطالب». وكنتُ قد
//    بنيتُ القسمَ مشتقّاً من شاشة نتيجة الاختبار لأن مجلّد `07-analysis`
//    فارغ — والتصميمُ كان موجوداً فعلاً، لكن **داخل شاشة الطالب** في
//    مجلّد الرئيسية. فأُعيد البناءُ على التصدير الحقيقي.
//
// كل رقم هنا مُشتقّ من `QuizAnalytics` فوق نتائج `QuizStorage` المحلية:
// **صفر قراءات سحابية وصفر انتظار شبكة** ([31§7]) — يفتح فوراً وبلا إنترنت.
//
// 👤 محكوم بالمالك: جوّالٌ بحسابين لا يخلط تحليلهما ([28§10]).
//
// 🔁 **الحلقة الذهبية**: كل نقطة ضعف تحمل درسها ووحدتها، فزرّ «اشرح لي»
//    يفتح الشات على **ذلك الدرس** مباشرةً، و«اختبار مراجعة» يولّد أسئلة
//    من الدروس الضعيفة وحدها.

class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key, this.ownerUid});

  /// يُحقن في الاختبارات فقط؛ الإنتاج يقرأ من `UserSession`.
  final String? ownerUid;

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  List<QuizResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    // 🎓 **نتائج هذا الصف وحده.** «أقوى مادة» و«أضعف مادة» ونقاط الضعف
    //    تُشتقّ منها، فخلطُ سنواتٍ يجعل التحليل يشير إلى مادةٍ لا تُدرَّس
    //    هذه السنة أصلاً — وهو أسوأ من غياب التحليل لأنه يُوجّه المذاكرة خطأً.
    setState(() => _results = QuizStorage.all(
          widget.ownerUid ?? UserSession.I.uid,
          scope: UserSession.I.scope,
        ));
  }

  /// يُعاد التحميل بعد العودة من اختبار أو من شاشة مادة — فالأرقام حيّة.
  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final subjects = QuizAnalytics.bySubject(_results);
    final weak = QuizAnalytics.weakSpots(_results, limit: 5);
    final points = QuizAnalytics.recentPercents(_results, count: 10);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      // ⚠️ **`ScreenTip` يرجع `Positioned`** فمكانُه `Stack` مباشرةً لا داخل
      //    عمودٍ — وإلا رمى فلاتر في كل بناءٍ ولم يظهر للطالب أبداً.
      body: Stack(
        children: [
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(AnalysisMetrics.margin, 18,
                  AnalysisMetrics.margin, 28),
              children: [
                _header(),
                const SizedBox(height: 16),
                FadeInSlide(child: _profile()),
                const SizedBox(height: 22),
                const AnalysisSectionTitle("تحليل مستواي"),
                const SizedBox(height: 12),
                if (_results.isEmpty)
                  FadeInSlide(delay: 0.05, child: _emptyAnalysis())
                else ...[
                  FadeInSlide(delay: 0.05, child: _summary()),
                  if (points.length >= 2) ...[
                    const SizedBox(height: AnalysisMetrics.gap),
                    FadeInSlide(delay: 0.08, child: _progress(points)),
                  ],
                  if (weak.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    const AnalysisSectionTitle("الدروس التي تحتاج تركيز"),
                    const SizedBox(height: 12),
                    ...weak.asMap().entries.map((e) => FadeInSlide(
                          delay: 0.1 + e.key * 0.04,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 11),
                            child: _focusRow(e.value),
                          ),
                        )),
                  ],
                  const SizedBox(height: 10),
                  FadeInSlide(delay: 0.14, child: _reviewCard(subjects)),
                  const SizedBox(height: 22),
                  const AnalysisSectionTitle("تحليل المواد"),
                  const SizedBox(height: 12),
                  ...subjects.asMap().entries.map((e) => FadeInSlide(
                        delay: 0.14 + e.key * 0.05,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 11),
                          child: AnalysisSubjectRow(
                            subject: e.value.subject,
                            percent: e.value.currentPercent,
                            label: e.value.label,
                            quizzes: e.value.quizzes,
                            onTap: () => _push(SubjectAnalysisScreen(
                                subject: e.value.subject,
                                ownerUid: widget.ownerUid)),
                          ),
                        ),
                      )),
                ],
              ],
            ),
          ),
          const ScreenTip(
              screenId: "analysis",
              text:
                  "تحليل مستواك 📊 يُبنى من نتائج اختباراتك — كل نقطة ضعف تفتح درسها مباشرةً."),
        ],
      ),
    );
  }

  // ══════════════ الرأس ══════════════

  /// 📐 من التصدير: الرسمُ في **يمين** السطر ثم «معلومات الطالب» 22/w900،
  ///    وسهمُ الرجوع في أقصى اليسار.
  ///
  /// 🎨 والرسمُ أصلُ المصمّم نفسُه — وُجد في `design/assets/`.
  Widget _header() => Row(
        children: [
          SizedBox(
            width: 44,
            height: 40,
            child: Image.asset("assets/art/art_student_info.png",
                fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text("معلومات الطالب",
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.headingInk)),
          ),
          QuizSquareButton(
              icon: PI.arrowRight, onTap: () => Navigator.maybePop(context)),
        ],
      );

  // ══════════════ بطاقة الطالب ══════════════

  Widget _profile() {
    final scope = UserSession.I.scope;
    // 📚 «مادة درستها» — نفسُ حسابِ بطاقات الرئيسية حرفاً: عددُ الموادّ
    //    التي فتح فيها محادثةً فعلاً، من مجموع موادّ صفّه.
    final studied = ChatStorage.getAllConversations(
          widget.ownerUid ?? UserSession.I.uid,
          scope: scope,
        ).map((c) => c.subject).toSet().length;
    final total = Curriculum.subjectsFor(
            UserSession.I.grade, TrackLabel.fromKey(UserSession.I.track))
        .length;

    return StudentProfileCard(
      studied: studied,
      total: total,
      onAvatarChanged: () => setState(() {}),
      // ⚙️ «عرض التفاصيل» يفتح الإعدادات — فهناك تُقرأ بيانات الحساب
      //    كلُّها وتُعدَّل (الاسم · الصف · المسار · نوع الحساب).
      onDetails: () => _push(const SettingsScreen()),
    );
  }

  // ══════════════ ملخّص الأداء ══════════════

  /// 📐 من التصدير: بطاقةٌ `#3C65CA` فيها «ملخص أدائك العام» ثم ثلاثةُ
  ///    أعمدةٍ بفواصلَ رأسية، ثم فاصلٌ أفقيّ، ثم أفضلُ مادةٍ وأضعفُها.
  Widget _summary() {
    final subjects = QuizAnalytics.bySubject(_results);
    final best = subjects.isEmpty ? null : subjects.first;
    // ⚠️ «أضعف مادة» تظهر عند مادتين فأكثر فقط — وإلا كانت هي «أفضل مادة».
    final weakest = subjects.length >= 2 ? subjects.last : null;
    final last = _results.first; // القائمة مرتّبة: الأحدث أولاً

    return AnalysisNavyCard(
      child: Column(
        children: [
          const Text("ملخص أدائك العام",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 16),
          Row(
            children: [
              // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — وهناك «عدد الاختبارات».
              Expanded(
                  child: AnalysisNavyStat(
                      value: "${QuizAnalytics.totalQuizzes(_results)}",
                      label: "عدد الاختبارات")),
              const AnalysisNavyDivider(),
              Expanded(
                  child: AnalysisNavyStat(
                      value: "${QuizAnalytics.overallPercent(_results)}%",
                      label: "المعدل العام")),
              const AnalysisNavyDivider(),
              Expanded(
                  child: AnalysisNavyStat(
                      value: "${last.percent}%", label: "آخر اختبار")),
            ],
          ),
          if (best != null) ...[
            const SizedBox(height: 16),
            Divider(color: Colors.white.withValues(alpha: 0.22), height: 1),
            const SizedBox(height: 16),
            // 🎯 **بلاغ المالك (٢٠٢٦-٠٩-٢٤):** «اختبرتُ مادةً واحدة فقط
            //    فقال: هي أفضل مادة — ما يصلح». الأفضليةُ مقارنةٌ، ومادةٌ
            //    وحيدةٌ لا تُقارَن بشيء: نعرض تقييمَها هي ونقول صراحةً إن
            //    الترتيب ينتظر مادةً ثانية.
            if (weakest == null)
              _singleSubject(best)
            else
              Row(
                children: [
                  Expanded(
                      child: _subjectFact(
                          best.subject, "أفضل مادة", AppColors.success500)),
                  const AnalysisNavyDivider(),
                  Expanded(
                      child: _subjectFact(
                          weakest.subject, "أضعف مادة", AppColors.error500)),
                ],
              ),
          ],
          // 🔥 سلسلةُ الأيام — 🆕 ليست في التصدير، ويملكها التطبيق.
          //    تظهر عند يومين فأكثر: «يومٌ واحدٌ متتالٍ» لا معنى له.
          if (QuizAnalytics.streakDays(_results) > 1) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                  "🔥 ${QuizAnalytics.streakDays(_results)} أيام متتالية — واصل!",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }

  /// مادةٌ وحيدة: تقييمُها («رياضيات · جيد ٧٢٪») وسطرٌ يشرح غيابَ الترتيب.
  Widget _singleSubject(SubjectStats only) {
    final dot = only.isStrong
        ? AppColors.success500
        : only.isWeak
            ? AppColors.error500
            : AppColors.warning500;
    return Column(
      children: [
        _subjectFact(
            // ⇆ النسبةُ معزولةٌ يساراً (LRI…PDI) وإلا قُرئت «%20» وسط العربية.
            only.subject,
            "${only.label} — \u2066${only.currentPercent}%\u2069",
            dot),
        const SizedBox(height: 10),
        Text(
          "اختبرتَ مادةً واحدة حتى الآن — اختبر مادةً ثانية لنعرف أفضلَ موادك وأضعفَها.",
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 11.5,
              height: 1.5,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.86)),
        ),
      ],
    );
  }

  /// «رياضيات» وتحتها «🟢 أفضل مادة» — نقطةٌ ملوّنة كما في التصدير.
  Widget _subjectFact(String subject, String label, Color dot) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(subject,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.86))),
              const SizedBox(width: 6),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            ],
          ),
        ],
      );

  // ══════════════ خطّ التقدّم — 🆕 ══════════════

  Widget _progress(List<int> points) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(AnalysisMetrics.cardRadius),
          border: Border.all(color: AppColors.quizCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(PI.chartLine.regular, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text("تقدّمك في آخر ${arabicQuizzes(points.length, afterAkhir: true)}",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.headingInk)),
            ]),
            const SizedBox(height: 14),
            AnalysisSparkline(points: points),
          ],
        ),
      );

  // ══════════════ نقاط الضعف — الحلقة الذهبية ══════════════

  Widget _focusRow(WeakSpot w) => AnalysisFocusRow(
        title: w.lesson.isEmpty ? w.topic : w.lesson,
        subtitle: "${w.subject}${w.topic.isEmpty ? '' : ' • ${w.topic}'}",
        percent: w.errorRate,
        onTap: () => showWeakSpotSheet(context, w,
            onExplain: () => _explain(w), onRetakeQuiz: () => _retake(w)),
      );

  void _explain(WeakSpot w) => _push(MainChatScreen(
        openSubject: w.subject,
        openUnit: w.unit,
        openLesson: w.lesson,
        openMode: "شرح",
      ));

  /// 🔁 اختبارٌ على هذا الدرس وحده — لقياس هل زال الضعف بعد الشرح.
  void _retake(WeakSpot w) => _push(QuizSetupScreen(
        initialSubject: w.subject,
        presetUnit: w.unit,
        presetLessons: [w.lesson],
      ));

  // ══════════════ اختبار المراجعة ══════════════

  Widget _reviewCard(List<SubjectStats> subjects) => AnalysisReviewCard(
        title: "اختبار مراجعة",
        subtitle: "أسئلة من دروسك الضعيفة وحدها — لا من المنهج كله.",
        onTap: subjects.isEmpty
            ? null
            : () => showReviewQuizSheet(
                  context,
                  subjects: subjects,
                  results: _results,
                  onStart: (subject, unit, lessons) => _push(QuizSetupScreen(
                    initialSubject: subject,
                    presetUnit: unit,
                    presetLessons: lessons,
                  )),
                ),
      );

  // ══════════════ الحالة الفارغة ══════════════

  /// ⚠️ **البطاقةُ تبقى والتحليلُ وحده يفرغ.** الشاشةُ صارت «معلومات
  ///    الطالب»، فمن لم يختبر نفسه بعدُ يرى بياناتِه ويُدعى للاختبار —
  ///    لا شاشةً خاوية.
  Widget _emptyAnalysis() => Container(
        padding: const EdgeInsets.fromLTRB(18, 22, 18, 22),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(AnalysisMetrics.cardRadius),
          border: Border.all(color: AppColors.quizCardBorder),
        ),
        child: Column(
          children: [
            MasarRobot(size: 84, pose: MasarRobotPose.fly),
            const SizedBox(height: 14),
            Text("لا يوجد تحليل بعد",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.headingInk)),
            const SizedBox(height: 8),
            Text(
              "التحليل يُبنى من اختباراتك. اختبر نفسك مرة واحدة "
              "وسترى مستواك في كل مادة ونقاط ضعفك بالدرس.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  fontWeight: FontWeight.w600,
                  color: AppColors.rowHint),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: 220,
              child: QuizPrimaryButton(
                label: "ابدأ اختبارك الأول",
                icon: PI.brain,
                height: 46,
                onTap: () => _push(const QuizSetupScreen()),
              ),
            ),
          ],
        ),
      );
}
