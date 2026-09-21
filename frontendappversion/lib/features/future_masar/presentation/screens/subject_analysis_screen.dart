import 'package:flutter/material.dart';

import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../../chat/presentation/screens/main_chat_screen.dart';
import '../../../quiz/data/models/quiz_models.dart';
import '../../../quiz/data/quiz_analytics.dart';
import '../../../quiz/data/quiz_storage.dart';
import '../../../quiz/presentation/quiz_review_screen.dart';
import '../../../quiz/presentation/quiz_setup_screen.dart';
import '../../../quiz/presentation/widgets/quiz_ui.dart';
import '../widgets/analysis_ui.dart';
import '../widgets/weak_spot_sheet.dart';

// ==========================================
// 📈 تحليل مادة واحدة — من نتائجها الحقيقية
// ==========================================
// نفس مصدر شاشة التحليل العامة: `QuizStorage` محلياً ثم `QuizAnalytics`.
// وكل درس ضعيف هنا زرّان: «اشرح لي» يفتح الدرس في الشات، و«اختبار مراجعة»
// يولّد أسئلة من الدروس الضعيفة وحدها ([31§7]).
//
// 🎨 **قرارُ المالك (2026-09-21):** «أما تحليل كل مادة خلّه زي الأول، ولكن
//    مع تعديل حاجات بسيطة نفس التصميم الجديد لتحليل مستواي».
//
//    فالبِنية **هي بنيتُها الأصلية** — أربعُ بطاقاتِ إحصاءٍ بأيقوناتها،
//    ثم بطاقةُ نصيحةٍ ملوّنة، ثم الدروسُ الضعيفة، ثم زرُّ المراجعة، ثم
//    السجلّ. والمتغيّرُ **اللغةُ البصرية وحدها**: ألوانُ
//    `03-home/22-معلومات` وبطاقاتُه (`#3C65CA` · صفُّ التركيز 65 ·
//    حلقةُ المستوى · بطاقةُ المراجعة البنفسجية).

class SubjectAnalysisScreen extends StatefulWidget {
  const SubjectAnalysisScreen({super.key, required this.subject, this.ownerUid});
  final String subject;

  /// يُحقن في الاختبارات فقط؛ الإنتاج يقرأ من `UserSession`.
  final String? ownerUid;

  @override
  State<SubjectAnalysisScreen> createState() => _SubjectAnalysisScreenState();
}

class _SubjectAnalysisScreenState extends State<SubjectAnalysisScreen> {
  List<QuizResult> _results = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _results = QuizStorage.forSubject(
        widget.ownerUid ?? UserSession.I.uid,
        widget.subject,
        scope: UserSession.I.scope,
      ));

  Future<void> _push(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final stats = QuizAnalytics.bySubject(_results);
    final s = stats.isEmpty ? null : stats.first;
    final weak = QuizAnalytics.weakSpots(_results, limit: 5);
    // مرتّبة من المخزن: الأحدث أولاً
    final best = _results.isEmpty
        ? 0
        : _results.map((r) => r.percent).reduce((a, b) => a > b ? a : b);
    final last = _results.isEmpty ? 0 : _results.first.percent;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: s == null
            ? _emptyLayout()
            : ListView(
                padding: const EdgeInsets.fromLTRB(AnalysisMetrics.margin, 18,
                    AnalysisMetrics.margin, 28),
                children: [
                  _header(s),
                  const SizedBox(height: 18),
                  // 📊 أربعُ بطاقاتٍ كما كانت — 2×2 بأيقونةٍ ورقمٍ وتسمية.
                  FadeInSlide(
                    child: Row(children: [
                      Expanded(
                          child: _stat(PI.chartLine, "${s.percent}%",
                              "متوسط سجلّك", analysisBand(s.percent))),
                      const SizedBox(width: 11),
                      Expanded(
                          child: _stat(PI.listChecks, "${s.quizzes}",
                              "عدد الاختبارات", AppColors.secondary500)),
                    ]),
                  ),
                  const SizedBox(height: 11),
                  FadeInSlide(
                    delay: 0.05,
                    child: Row(children: [
                      Expanded(
                          child: _stat(PI.trophy, "$best%", "أفضل نتيجة",
                              analysisBand(best))),
                      const SizedBox(width: 11),
                      Expanded(
                          child: _stat(PI.clockCounterClockwise, "$last%",
                              "آخر نتيجة", analysisBand(last))),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  FadeInSlide(delay: 0.1, child: _advice(s)),
                  const SizedBox(height: 22),
                  if (weak.isEmpty)
                    FadeInSlide(delay: 0.15, child: _noMistakes())
                  else ...[
                    const AnalysisSectionTitle("الدروس التي تحتاج تركيز"),
                    const SizedBox(height: 12),
                    ...weak.asMap().entries.map((e) => FadeInSlide(
                          delay: 0.15 + e.key * 0.04,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 11),
                            child: _focusRow(e.value),
                          ),
                        )),
                    const SizedBox(height: 10),
                    FadeInSlide(
                      delay: 0.3,
                      child: AnalysisReviewCard(
                        title: "اختبار مراجعة لهذه الدروس",
                        subtitle: "أسئلة من دروسك الضعيفة في ${widget.subject}.",
                        onTap: () => _push(QuizSetupScreen(
                          initialSubject: widget.subject,
                          presetUnit: weak.first.unit,
                          presetLessons:
                              weak.take(3).map((w) => w.lesson).toList(),
                        )),
                      ),
                    ),
                  ],

                  // 🗂️ السجلّ **تحت نقاط الضعف** لا فوقها.
                  //
                  // ⚠️ وُضع فوقها أولاً فدفعها خارج الشاشة — وهي جوهر هذه
                  //    الشاشة وسبب فتحها. السجلّ مرجعٌ يُطلب عن قصد، فمكانه
                  //    بعد ما يُقرأ أولاً.
                  const SizedBox(height: 26),
                  FadeInSlide(delay: 0.35, child: _history()),
                ],
              ),
      ),
    );
  }

  // ══════════════ الرأس ══════════════

  Widget _header(SubjectStats? s) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox(
                width: 44,
                height: 40,
                child: Image.asset("assets/art/art_analysis.png",
                    fit: BoxFit.contain),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text("تحليل مادة ${widget.subject}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        color: AppColors.headingInk)),
              ),
              QuizSquareButton(
                  icon: PI.arrowRight,
                  onTap: () => Navigator.maybePop(context)),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
                s == null
                    ? "لا اختبارات بعد"
                    : "مستواك: ${s.label} · ${s.currentPercent}% "
                        "(${_lastQuizzes(s.currentQuizzes)})",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.rowHint)),
          ),
        ],
      );

  // ══════════════ بطاقة إحصاء ══════════════

  /// 📐 **كما كانت**: أيقونةٌ فوق، ثم الرقمُ 20/w900 بلونه، ثم التسمية.
  ///    والجديدُ حدُّ التصميم `#E8EDF3` ونصفُ قطره 20 بدل ظلّ الديمو.
  Widget _stat(PIcon icon, String value, String label, Color color) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(AnalysisMetrics.cardRadius),
          border: Border.all(color: AppColors.quizCardBorder),
        ),
        child: Column(children: [
          Icon(icon.regular, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 4),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.rowHint)),
        ]),
      );

  // ══════════════ النصيحة ══════════════

  /// نصيحة مشتقّة من الأرقام لا من قوالب ثابتة.
  ///
  /// 🎨 وسطحُها `#3C65CA` — سطحُ «ملخص أدائك العام» نفسُه في التصميم
  ///    الجديد، بدل تدرّج الديمو القديم.
  Widget _advice(SubjectStats s) {
    final (emoji, title, body) = switch (s) {
      _ when s.isStrong => (
          "🌟",
          "مستواك ممتاز هنا",
          "حافظ عليه باختبار أسبوعي خفيف، وركّز وقتك على المواد الأضعف."
        ),
      _ when s.isWeak => (
          "🎯",
          "هذه المادة أولويّتك",
          "ابدأ بأضعف درس بالأسفل: اقرأ شرحه ثم اختبر نفسك فيه وحده."
        ),
      _ => (
          "💪",
          "أنت في المنتصف",
          "أخطاؤك مركّزة في دروس معدودة — عالجها وسترتفع النسبة بسرعة."
        ),
    };

    final trendLine = s.trend > 0
        ? "📈 تحسّنت ${s.trend} نقطة عن اختباراتك الأولى."
        : (s.trend < 0
            ? "📉 نزلت ${s.trend.abs()} نقطة — راجع الدروس الضعيفة."
            : "");

    return AnalysisNavyCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 10),
        Text(body,
            style: TextStyle(
                fontSize: 12,
                height: 1.8,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.9))),
        if (trendLine.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(trendLine,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
        ],
      ]),
    );
  }

  Widget _noMistakes() => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(AnalysisMetrics.cardRadius),
            border: Border.all(color: AppColors.success500)),
        child: Row(children: [
          MasarRobot(size: 46, pose: MasarRobotPose.fly),
          const SizedBox(width: 12),
          Expanded(
            child: Text("ما عندك أخطاء مسجّلة في هذه المادة — استمر!",
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.7,
                    fontWeight: FontWeight.w800,
                    color: AppColors.headingInk)),
          ),
        ]),
      );

  // ══════════════ نقاط الضعف ══════════════

  Widget _focusRow(WeakSpot w) => AnalysisFocusRow(
        title: w.lesson.isEmpty ? w.topic : w.lesson,
        subtitle: w.topic,
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

  // ══════════════════════════════════════════════════
  // 🗂️ سجلّ الاختبارات — ومنه المراجعة
  // ══════════════════════════════════════════════════
  // 🔴 **الفجوة التي يسدّها:** المراجعة كانت متاحةً بعد الاختبار مباشرةً
  //    **وحدها**، لأن الأسئلة تعيش في ذاكرة المتحكّم وتختفي بإغلاق الشاشة.
  //    فطالبٌ يرى هنا أنه أخطأ في «الأكسدة» قبل يومين لا يستطيع أن يعرف
  //    ماذا أخطأ فيه — والتحليل يشخّص بلا أن يُري الدواء.
  //
  // ⚠️ ونعرض **خمسة** لا كل السجلّ: هذه شاشة تحليل لا أرشيف، والقائمة
  //    الطويلة تدفن نقاط الضعف تحتها وهي الأهمّ.
  Widget _history() {
    final recent = _results.take(5).toList();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AnalysisSectionTitle("اختباراتك الأخيرة"),
        const SizedBox(height: 12),
        for (final r in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: 11),
            child: _historyRow(r),
          ),
      ],
    );
  }

  /// 📐 بلغة صفِّ التركيز نفسِها: 65 · r22 · حدٌّ · شارةٌ 42×38 ثم سطران
  ///    ثم زرٌّ صغير — لكنّ شارتَه **بلون المستوى** لا حمراءَ دائماً.
  Widget _historyRow(QuizResult r) {
    final color = analysisBand(r.percent);
    return Container(
      height: AnalysisMetrics.focusRow,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(AnalysisMetrics.focusRadius),
        border: Border.all(color: AppColors.rowBorder),
      ),
      child: Row(
        children: [
          Container(
            width: AnalysisMetrics.badgeW,
            height: AnalysisMetrics.badgeH,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius:
                  BorderRadius.circular(AnalysisMetrics.badgeRadius),
            ),
            child: Text("${r.percent}%",
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800, color: color)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("${r.score} من ${r.total}",
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.headingInk)),
                Text(_ago(r.createdAt),
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: AppColors.rowHint)),
              ],
            ),
          ),
          // ⚠️ الزرّ يظهر **حين توجد مراجعة فعلاً**: نتيجةٌ قديمة أو
          //    مستعادة من السحابة تصل بلا مراجعة، وزرٌّ يفتح شاشةً
          //    تعتذر أسوأ من غيابه.
          if (r.hasReview)
            AnalysisRowAction(
              label: "راجع",
              icon: PI.notePencil,
              onTap: () => _push(QuizReviewScreen.saved(r)),
            ),
        ],
      ),
    );
  }

  /// «قبل يومين» لا تاريخٌ مجرّد — الطالب يفكّر بالمسافة لا بالتقويم.
  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return "قبل قليل";
    if (d.inHours < 24) return "اليوم";
    if (d.inDays == 1) return "أمس";
    if (d.inDays < 7) return "قبل ${d.inDays} أيام";
    if (d.inDays < 30) return "قبل ${(d.inDays / 7).floor()} أسابيع";
    return "قبل ${(d.inDays / 30).floor()} أشهر";
  }

  /// صيغة الجمع العربية — «آخر ٥ اختبارات» لا «آخر ٥ اختبار».
  static String _lastQuizzes(int n) =>
      n <= 0 ? "لا اختبارات" : "آخر ${arabicQuizzes(n, afterAkhir: true)}";

  // ══════════════ الحالة الفارغة ══════════════

  Widget _emptyLayout() => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AnalysisMetrics.margin, 18, AnalysisMetrics.margin, 0),
            child: _header(null),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  MasarRobot(size: 100, pose: MasarRobotPose.fly),
                  const SizedBox(height: 16),
                  Text("ما اختبرت نفسك في ${widget.subject} بعد",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppColors.headingInk)),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: 220,
                    child: QuizPrimaryButton(
                      label: "ابدأ اختباراً",
                      icon: PI.brain,
                      height: 46,
                      onTap: () => _push(
                          QuizSetupScreen(initialSubject: widget.subject)),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ],
      );
}
