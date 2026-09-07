import 'package:flutter/material.dart';

import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../../../core/widgets/screen_tip.dart';
import '../../../chat/presentation/screens/main_chat_screen.dart';
import '../../../quiz/data/models/quiz_models.dart';
import '../../../quiz/data/quiz_analytics.dart';
import '../../../quiz/data/quiz_storage.dart';
import '../../../quiz/presentation/quiz_setup_screen.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/weak_spot_sheet.dart';
import 'subject_analysis_screen.dart';

// ==========================================
// 📊 «تحليل مستواي» — على نتائج الاختبارات الحقيقية
// ==========================================
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

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Column(
            children: [
              const GlassBar(
                  title: "تحليل مستواي 📊", subtitle: "قوتك، ضعفك، وتوصياتك"),
              Expanded(
                child: _results.isEmpty
                    ? _EmptyState(onStart: () => _push(const QuizSetupScreen()))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                        children: [
                          FadeInSlide(child: _summaryCard()),
                          const SizedBox(height: 14),
                          FadeInSlide(delay: 0.05, child: _progressCard()),
                          const SizedBox(height: 18),
                          if (weak.isNotEmpty) ...[
                            const SectionHeader("الدروس التي تحتاج تركيز 🎯"),
                            ...weak.asMap().entries.map((e) => FadeInSlide(
                                  delay: 0.08 + e.key * 0.05,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _weakCard(e.value),
                                  ),
                                )),
                            const SizedBox(height: 8),
                          ],
                          FadeInSlide(delay: 0.12, child: _reviewCard(subjects)),
                          const SizedBox(height: 22),
                          const SectionHeader("تحليل المواد"),
                          ...subjects.asMap().entries.map((e) => FadeInSlide(
                                delay: 0.12 + e.key * 0.06,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _subjectCard(e.value),
                                ),
                              )),
                        ],
                      ),
              ),
            ],
          ),
          const ScreenTip(
              screenId: "analysis",
              text:
                  "تحليل مستواك 📊 يُبنى من نتائج اختباراتك — كل نقطة ضعف تفتح درسها مباشرةً."),
        ],
      ),
    );
  }

  // ══════════════ الملخّص ══════════════

  Widget _summaryCard() {
    final subjects = QuizAnalytics.bySubject(_results);
    final best = subjects.isEmpty ? null : subjects.first;
    // ⚠️ «أضعف مادة» تظهر عند مادتين فأكثر فقط — وإلا كانت هي «أفضل مادة».
    final weakest = subjects.length >= 2 ? subjects.last : null;
    final streak = QuizAnalytics.streakDays(_results);
    final last = _results.first; // القائمة مرتّبة: الأحدث أولاً

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          const Text("ملخص أدائك العام",
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(children: [
            _sumTile("${QuizAnalytics.totalQuizzes(_results)}", "عدد الاختبارات"),
            _divider(),
            _sumTile("${QuizAnalytics.overallPercent(_results)}%", "المعدل العام"),
            _divider(),
            _sumTile("${last.percent}%", "آخر اختبار"),
          ]),
          const Divider(color: Colors.white24, height: 26),
          Row(children: [
            _sumTile(best?.subject ?? "—", "💪 أفضل مادة"),
            if (weakest != null) ...[
              _divider(),
              _sumTile(weakest.subject, "🎯 أضعف مادة"),
            ],
          ]),
          if (streak > 1) ...[
            const SizedBox(height: 14),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text("🔥 $streak أيام متتالية — واصل!",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sumTile(String value, String label) => Expanded(
        child: Column(children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600)),
        ]),
      );

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white24);

  // ══════════════ خط التقدّم ══════════════

  Widget _progressCard() {
    final points = QuizAnalytics.recentPercents(_results, count: 10);
    if (points.length < 2) return const SizedBox.shrink();

    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.show_chart_rounded, size: 18, color: AppColors.primary),
            const SizedBox(width: 8),
            Text("تقدّمك في آخر ${points.length} اختبارات",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 14),
          SizedBox(height: 66, child: _Sparkline(points: points)),
        ],
      ),
    );
  }

  // ══════════════ نقاط الضعف — الحلقة الذهبية ══════════════

  Widget _weakCard(WeakSpot w) {
    // 👆 البطاقة كلّها هدفٌ للنقر لا الزرّ الصغير وحده — أرحم لإصبع الطالب.
    return InkWell(
      onTap: () => showWeakSpotSheet(context, w,
                onExplain: () => _explain(w), onRetakeQuiz: () => _retake(w)),
      borderRadius: BorderRadius.circular(24),
      child: SoftCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text("${w.errorRate}٪",
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.redAccent)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.lesson.isEmpty ? w.topic : w.lesson,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text("${w.subject}${w.topic.isEmpty ? '' : ' · ${w.topic}'}",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textSecondary)),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () =>
                showWeakSpotSheet(context, w,
                onExplain: () => _explain(w), onRetakeQuiz: () => _retake(w)),
            icon: const Icon(Icons.chevron_left_rounded, size: 19),
            label: const Text("التفاصيل",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    ),
    );
  }

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

  Widget _reviewCard(List<SubjectStats> subjects) {
    return InkWell(
      onTap: subjects.isEmpty ? null : () => _openReviewSheet(subjects),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF7C3AED)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16)),
            child: const Text("📅", style: TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("اختبار مراجعة",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text("أسئلة من دروسك الضعيفة وحدها — لا من المنهج كله.",
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: 11.5,
                        height: 1.4,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          Icon(Icons.arrow_circle_left_rounded,
              color: Colors.white.withValues(alpha: 0.9), size: 26),
        ]),
      ),
    );
  }

  void _openReviewSheet(List<SubjectStats> subjects) {
    // نبدأ بأضعف مادة — فهي الأولى بالمراجعة.
    var subject = subjects.last.subject;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final spots = QuizAnalytics.weakSpots(
              _results.where((r) => r.subject == subject).toList(),
              limit: 3);
          final unit = spots.isEmpty ? "" : spots.first.unit;

          return Padding(
            padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                      child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                              color: AppColors.softSurface,
                              borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 16),
                  Text("اختبار مراجعة 📅",
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  Text("المادة:",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: subjects
                        .map((s) => _sheetChip(s.subject, s.subject == subject,
                            () => setSheet(() => subject = s.subject)))
                        .toList(),
                  ),
                  const SizedBox(height: 18),
                  Row(children: [
                    Icon(Icons.auto_awesome_rounded,
                        size: 16, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text("دروس مختارة من أخطائك السابقة:",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary,
                              fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  if (spots.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                          "ما عندك أخطاء في «$subject» 🎉 اختر مادة أخرى.",
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    )
                  else
                    ...spots.map((s) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.4),
                                  width: 1.4),
                            ),
                            child: Row(children: [
                              Icon(Icons.check_box_rounded,
                                  color: AppColors.primary, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                  child: Text(s.lesson,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.textPrimary,
                                          fontSize: 13.5))),
                              Text("${s.misses} أخطاء",
                                  style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.redAccent)),
                            ]),
                          ),
                        )),
                  const SizedBox(height: 22),
                  GradientButton(
                    label: "🚀 ابدأ اختبار المراجعة",
                    onTap: spots.isEmpty
                        ? () {}
                        : () {
                            Navigator.pop(ctx);
                            _push(QuizSetupScreen(
                              initialSubject: subject,
                              presetUnit: unit,
                              presetLessons:
                                  spots.map((s) => s.lesson).toList(),
                            ));
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetChip(String label, bool sel, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
              color: sel ? AppColors.primary : AppColors.softSurface,
              borderRadius: BorderRadius.circular(16)),
          child: Text(label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: sel ? Colors.white : AppColors.textSecondary)),
        ),
      );

  // ══════════════ بطاقة مادة ══════════════

  Widget _subjectCard(SubjectStats s) {
    return InkWell(
      onTap: () => _push(SubjectAnalysisScreen(
          subject: s.subject, ownerUid: widget.ownerUid)),
      borderRadius: BorderRadius.circular(22),
      child: SoftCard(
        child: Row(
          children: [
            _Ring(percent: s.currentPercent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.subject,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Text(s.label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _levelColor(s))),
                    const SizedBox(width: 8),
                    Text("· ${s.quizzes} اختبار",
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary)),
                    if (s.trend != 0) ...[
                      const SizedBox(width: 8),
                      Icon(
                          s.trend > 0
                              ? Icons.trending_up_rounded
                              : Icons.trending_down_rounded,
                          size: 15,
                          color: s.trend > 0 ? Colors.green : Colors.orange),
                      Text("${s.trend > 0 ? '+' : ''}${s.trend}",
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color:
                                  s.trend > 0 ? Colors.green : Colors.orange)),
                    ],
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded,
                color: AppColors.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }

  Color _levelColor(SubjectStats s) => s.isStrong
      ? Colors.green
      : (s.isWeak ? Colors.redAccent : AppColors.primary);
}

// ══════════════ الحالة الفارغة ══════════════

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("📊", style: TextStyle(fontSize: 56)),
            const SizedBox(height: 18),
            Text("لا يوجد تحليل بعد",
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text(
              "التحليل يُبنى من اختباراتك. اختبر نفسك مرة واحدة "
              "وسترى مستواك في كل مادة ونقاط ضعفك بالدرس.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.7,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 26),
            GradientButton(label: "🧠 ابدأ اختبارك الأول", onTap: onStart),
          ],
        ),
      ),
    );
  }
}

// ══════════════ حلقة النسبة ══════════════

class _Ring extends StatelessWidget {
  const _Ring({required this.percent});
  final int percent;

  @override
  Widget build(BuildContext context) {
    final color = percent >= 80
        ? Colors.green
        : (percent >= 50 ? AppColors.primary : Colors.redAccent);
    return SizedBox(
      width: 46,
      height: 46,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: 4.5,
              backgroundColor: AppColors.softSurface,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          Text("$percent",
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w900, color: color)),
        ],
      ),
    );
  }
}

// ══════════════ خط التقدّم ══════════════
// رسم يدوي بـ`CustomPaint` — بلا أي مكتبة رسوم بيانية إضافية.

class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.points});
  final List<int> points;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: _SparklinePainter(points, AppColors.primary),
        child: const SizedBox.expand(),
      );
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.points, this.color);
  final List<int> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    // المحور الرأسي ثابت 0–100 حتى لا يبالغ الرسم في تضخيم فروق صغيرة.
    double x(int i) => size.width * i / (points.length - 1);
    double y(int v) => size.height * (1 - v / 100);

    final line = Path()..moveTo(x(0), y(points.first));
    for (var i = 1; i < points.length; i++) {
      line.lineTo(x(i), y(points[i]));
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
        fill, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(
          Offset(x(i), y(points[i])), 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparklinePainter old) => old.points != points;
}
