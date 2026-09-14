import 'package:flutter/material.dart';

import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_markdown.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../../chat/presentation/screens/main_chat_screen.dart';
import '../../../quiz/data/models/quiz_models.dart';
import '../../../quiz/data/quiz_analytics.dart';
import '../../../quiz/data/quiz_storage.dart';
import '../../../quiz/presentation/quiz_setup_screen.dart';
import '../../../quiz/presentation/quiz_review_screen.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/weak_spot_sheet.dart';

// ==========================================
// 📈 تحليل مادة واحدة — من نتائجها الحقيقية
// ==========================================
// نفس مصدر شاشة التحليل العامة: `QuizStorage` محلياً ثم `QuizAnalytics`.
// وكل درس ضعيف هنا زرّان: «اشرح لي» يفتح الدرس في الشات، و«اختبار مراجعة»
// يولّد أسئلة من الدروس الضعيفة وحدها ([31§7]).

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
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Column(
            children: [
              GlassBar(
                title: "تحليل مادة ${widget.subject}",
                subtitle: s == null
                    ? "لا اختبارات بعد"
                    : "مستواك: ${s.label} · ${s.currentPercent}% "
                        "(${_lastQuizzes(s.currentQuizzes)})",
              ),
              Expanded(
                child: s == null
                    ? _empty()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                        children: [
                          FadeInSlide(
                            child: Row(children: [
                              _statCard("${s.percent}%", "متوسط سجلّك",
                                  AppColors.primary, Icons.trending_up_rounded),
                              const SizedBox(width: 12),
                              _statCard("${s.quizzes}", "عدد الاختبارات",
                                  AppColors.secondary, Icons.assignment_rounded),
                            ]),
                          ),
                          const SizedBox(height: 12),
                          FadeInSlide(
                            delay: 0.05,
                            child: Row(children: [
                              _statCard("$best%", "أفضل نتيجة", Colors.green,
                                  Icons.emoji_events_rounded),
                              const SizedBox(width: 12),
                              _statCard("$last%", "آخر نتيجة", Colors.orange,
                                  Icons.history_rounded),
                            ]),
                          ),
                          const SizedBox(height: 18),
                          FadeInSlide(delay: 0.1, child: _adviceCard(s)),
                          const SizedBox(height: 22),
                          if (weak.isEmpty)
                            FadeInSlide(
                              delay: 0.15,
                              child: SoftCard(
                                child: Row(children: [
                                  const Text("🎉",
                                      style: TextStyle(fontSize: 26)),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                        "ما عندك أخطاء مسجّلة في هذه المادة — استمر!",
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.textPrimary)),
                                  ),
                                ]),
                              ),
                            )
                          else ...[
                            const SectionHeader("الدروس التي تحتاج تركيز"),
                            ...weak.asMap().entries.map((e) => FadeInSlide(
                                  delay: 0.15 + e.key * 0.05,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: _weakTile(e.value),
                                  ),
                                )),
                            const SizedBox(height: 16),
                            FadeInSlide(
                              delay: 0.3,
                              child: GradientButton(
                                label: "🚀 اختبار مراجعة لهذه الدروس",
                                onTap: () => _push(QuizSetupScreen(
                                  initialSubject: widget.subject,
                                  presetUnit: weak.first.unit,
                                  presetLessons: weak
                                      .take(3)
                                      .map((w) => w.lesson)
                                      .toList(),
                                )),
                              ),
                            ),
                          ],

                          // 🗂️ السجلّ **تحت نقاط الضعف** لا فوقها.
                          //
                          // ⚠️ وُضع فوقها أولاً فدفعها خارج الشاشة — وهي
                          //    جوهر هذه الشاشة وسبب فتحها. السجلّ مرجعٌ
                          //    يُطلب عن قصد، فمكانه بعد ما يُقرأ أولاً.
                          const SizedBox(height: 26),
                          FadeInSlide(delay: 0.35, child: _history()),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

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
        Align(
          alignment: Alignment.centerRight,
          child: Text("🗂️ اختباراتك الأخيرة",
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
        ),
        const SizedBox(height: 10),
        for (final r in recent) _historyRow(r),
      ],
    );
  }

  Widget _historyRow(QuizResult r) {
    final color = r.percent >= 80
        ? Colors.green.shade600
        : r.percent >= 50
            ? Colors.orange
            : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10)),
              child: Text("${r.percent}%",
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900, color: color)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${r.score} من ${r.total}",
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(_ago(r.createdAt),
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
              ),
            ),
            // ⚠️ الزرّ يظهر **حين توجد مراجعة فعلاً**: نتيجةٌ قديمة أو
            //    مستعادة من السحابة تصل بلا مراجعة، وزرٌّ يفتح شاشةً
            //    تعتذر أسوأ من غيابه.
            if (r.hasReview)
              TextButton.icon(
                onPressed: () => _push(QuizReviewScreen.saved(r)),
                icon: const Icon(Icons.fact_check_rounded, size: 16),
                label: const Text("راجع",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
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

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text("🧠", style: TextStyle(fontSize: 52)),
            const SizedBox(height: 16),
            Text("ما اختبرت نفسك في ${widget.subject} بعد",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 20),
            GradientButton(
              label: "ابدأ اختباراً",
              onTap: () =>
                  _push(QuizSetupScreen(initialSubject: widget.subject)),
            ),
          ]),
        ),
      );

  /// صيغة الجمع العربية — «آخر ٥ اختبارات» لا «آخر ٥ اختبار».
  static String _lastQuizzes(int n) => switch (n) {
        <= 0 => "لا اختبارات",
        1 => "آخر اختبار",
        2 => "آخر اختبارين",
        _ => "آخر $n اختبارات",
      };

  Widget _statCard(String value, String label, Color color, IconData icon) =>
      Expanded(
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
          child: Column(children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 3),
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ]),
        ),
      );

  /// نصيحة مشتقّة من الأرقام لا من قوالب ثابتة.
  Widget _adviceCard(SubjectStats s) {
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

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w900)),
        ]),
        const SizedBox(height: 12),
        Text(body,
            style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: 12.5,
                height: 1.7,
                fontWeight: FontWeight.w600)),
        if (trendLine.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(trendLine,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800)),
        ],
      ]),
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

  // 👆 البطاقة كلّها هدفٌ للنقر لا الزرّ الصغير وحده.
  Widget _weakTile(WeakSpot w) => InkWell(
        onTap: () =>
            showWeakSpotSheet(context, w,
                onExplain: () => _explain(w), onRetakeQuiz: () => _retake(w)),
        borderRadius: BorderRadius.circular(24),
        child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10)),
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
                // 🖌️ بالرسّام: موضوعُ الضعف قد يكون صيغةً لا كلمة.
                MathOrText(w.lesson.isEmpty ? w.topic : w.lesson,
                    maxLines: 1,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary)),
                if (w.topic.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  MathOrText(w.topic,
                      maxLines: 1,
                      style: TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                ],
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
        ]),
        ),
      );
}
