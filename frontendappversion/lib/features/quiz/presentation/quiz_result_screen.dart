import 'package:flutter/material.dart';

import '../../../core/access/access_repository.dart';
import '../../../core/shell/masar_bottom_nav.dart';
import '../../../core/shell/masar_shell.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/masar_brand.dart';
import '../../../core/widgets/masar_markdown.dart';
import '../../../core/widgets/phosphor.dart';
import '../../chat/presentation/screens/main_chat_screen.dart';
import '../../future_masar/presentation/screens/analysis_screen.dart';
import '../data/models/quiz_models.dart';
import 'quiz_controller.dart';
import 'quiz_play_screen.dart';
import 'quiz_review_screen.dart';
import 'widgets/quiz_ui.dart';

// ==========================================
// 🏁 نتيجة الاختبار + خريطة نقاط الضعف
// ==========================================
// **الحلقة الذهبية** ([31§7]): كل نقطة ضعف تحمل **درسها**، فزر «اشرح لي 📚»
// يفتح الشات على ذلك الدرس بعينه — لا على المادة عموماً.
//
// 🎨 **إعادة التصميم** (`design/05-quiz/07-تقييم`): زرُّ إغلاقٍ 32 في أعلى
//    اليمين · حلقةٌ 138 بسماكة 10.5 · عنوانٌ وسطرُ نطاق · ثلاثُ بطاقات
//    إحصاءٍ ملوّنة بارتفاع 75 · صفوفُ «تحتاج تركيزاً في» · زرّان 53.
//
// ⚠️ **ولا شيءَ من الحساب تغيّر**: النسبةُ واللونُ والعنوانُ ودروسُ الضعف
//    تُحسب كما كانت حرفاً بحرف — تغيّر الرسمُ وحده.
class QuizResultScreen extends StatefulWidget {
  final QuizController controller;
  final QuizResult result;

  const QuizResultScreen({super.key, required this.controller, required this.result});

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _percent;

  QuizResult get r => widget.result;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));
    _percent = Tween<double>(begin: 0, end: r.percent / 100)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _anim.forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Color get _color => r.percent >= 80
      ? AppColors.quizRight
      : (r.percent >= 50 ? AppColors.warning800 : AppColors.quizWrong);

  String get _headline => r.percent >= 90
      ? "ممتاز! أنت متمكّن 🌟"
      : r.percent >= 80
          ? "أداء قوي 👏"
          : r.percent >= 50
              ? "جيد — وفيه مجال للأفضل 💪"
              : "لا بأس، هذه بداية الطريق 🌱";

  /// دروس فريدة أخطأ فيها، مرتّبة بعدد الأخطاء.
  List<MapEntry<String, int>> get _weakLessons {
    final counts = <String, int>{};
    for (final w in r.wrong) {
      final key = w.lesson.isEmpty ? w.topic : w.lesson;
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final list = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: FadeInSlide(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                QuizMetrics.margin, 27, QuizMetrics.margin, 28),
            children: [
              // ⚠️ RTL: `centerRight` هو موضعُ الزرّ في التصميم — أعلى اليمين.
              Align(
                alignment: Alignment.centerRight,
                child: QuizSquareButton(
                  icon: PI.x,
                  onTap: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ),
              const SizedBox(height: 51),
              _circle(),
              const SizedBox(height: 44),
              Text(_headline,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.panelTitle)),
              const SizedBox(height: 8),
              Text("${r.subject} · ${r.unit}",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.chipInk)),
              const SizedBox(height: 22),
              _stats(),
              const SizedBox(height: 22),
              if (_weakLessons.isNotEmpty) _weakMap() else _perfect(),
              const SizedBox(height: 33),
              _actions(),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────── ⭕ الحلقة ─────────────────────
  //
  // 📐 قطرُها 138 وسماكتُها 10.5 — مقيسةٌ من التصدير.

  Widget _circle() => AnimatedBuilder(
        animation: _percent,
        builder: (_, _) => SizedBox(
          height: 138,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 138,
                height: 138,
                child: CircularProgressIndicator(
                  value: _percent.value,
                  strokeWidth: 10.5,
                  strokeCap: StrokeCap.round,
                  backgroundColor: AppColors.rowBorder,
                  valueColor: AlwaysStoppedAnimation(_color),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("${(_percent.value * 100).round()}%",
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          color: _color)),
                  const SizedBox(height: 2),
                  Text("${r.score} من ${r.total}",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.panelTitle)),
                ],
              ),
            ],
          ),
        ),
      );

  // ───────────────────── 📊 بطاقات الإحصاء ─────────────────────
  //
  // 📐 ثلاثٌ بارتفاع 75 وفراغ 5، وكلٌّ بتعبئةِ حالتها وحبرِها.
  // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — و**الصحيحة في اليمين** في التصميم.

  Widget _stats() => Row(
        children: [
          Expanded(
              child: _stat("✓ صحيحة", "${r.score}", AppColors.quizEmerald,
                  AppColors.quizRightFill)),
          const SizedBox(width: 5),
          Expanded(
              child: _stat("✗ خاطئة", "${r.total - r.score}",
                  AppColors.quizPink, AppColors.quizPinkFill)),
          const SizedBox(width: 5),
          Expanded(
              child: _stat("⏱ الوقت", _fmt(r.durationSec), AppColors.quizSky,
                  AppColors.quizTint)),
        ],
      );

  static String _fmt(int sec) {
    final m = sec ~/ 60, s = sec % 60;
    return m > 0 ? "$m:${s.toString().padLeft(2, '0')}" : "$s ث";
  }

  Widget _stat(String label, String value, Color ink, Color fill) => Container(
        height: 75,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: fill, borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: ink)),
            const SizedBox(height: 4),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: ink)),
          ],
        ),
      );

  // ───────────────────── 🎯 خريطة الضعف ─────────────────────

  Widget _perfect() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: AppColors.quizRightFill,
            borderRadius: BorderRadius.circular(QuizMetrics.cardRadius),
            border: Border.all(color: AppColors.quizRight)),
        child: Row(
          children: [
            MasarRobot(size: 52, pose: MasarRobotPose.fly),
            const SizedBox(width: 12),
            Expanded(
              child: Text("لا أخطاء في هذا الاختبار — أتقنت هذه الدروس 🎯",
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.7,
                      fontWeight: FontWeight.w800,
                      color: AppColors.panelTitle)),
            ),
          ],
        ),
      );

  Widget _weakMap() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text("🎯 تحتاج تركيزاً في:",
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.panelTitle)),
          ),
          const SizedBox(height: 10),
          for (final e in _weakLessons)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: QuizCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 11),
                child: Row(
                  children: [
                    // ⚠️ RTL: الشارةُ أوّلُ ابنٍ ⇒ يميناً، والزرُّ آخرُه ⇒ يساراً.
                    QuizBadge("x${e.value}",
                        fill: AppColors.quizPinkFill,
                        ink: AppColors.quizPink),
                    const SizedBox(width: 10),
                    Expanded(
                      // 🖌️ بالرسّام لا بنصٍّ خام: الموضوع قد يكون صيغةً
                      //    («\frac{ن}{ر}») — و[MathOrText] تعود نصّاً
                      //    عادياً حين لا ترميزَ فيه، فلا كلفةَ لها.
                      child: MathOrText(e.key,
                          maxLines: 2,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.panelTitle)),
                    ),
                    const SizedBox(width: 10),
                    // 🔁 الحلقة الذهبية: من الخطأ إلى شرح الدرس نفسه
                    InkWell(
                      onTap: () => _explain(e.key),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.quizTint,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("اشرح لي",
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primary)),
                            const SizedBox(width: 7),
                            Icon(PI.bookOpen.regular,
                                size: 16, color: AppColors.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );

  /// يفتح شاشة الشات على **درس** نقطة الضعف مباشرةً.
  void _explain(String lesson) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => MainChatScreen(
          openSubject: r.subject,
          openUnit: r.unit,
          openLesson: lesson,
          openMode: "شرح",
        ),
      ),
      (route) => route.isFirst,
    );
  }

  // ───────────────────── ▶️ الزرّان ─────────────────────

  /// 📊 **طلبُ المالك (٢٠٢٦-٠٩-٢٤):** «زرٌّ يقول متابعة ورؤية مستواي،
  ///    ولما نرجع من تحليل مستواي يرجعنا إلى اختبر نفسك لا إلى النتيجة».
  ///    فالمكدّسُ يُطوى حتى القشرة وقد طُلب تبويبُ الاختبار، ثم يُدفع
  ///    التحليلُ فوقها — «رجوع» منه يقع على «اختبر نفسك» أينما بدأ الاختبار.
  void _seeLevel() {
    MasarShell.tabRequest.value = MasarTab.quiz;
    final nav = Navigator.of(context);
    nav.popUntil((route) => route.isFirst);
    if (!AccessRepository.I.usable(AppSection.analysis)) return;
    nav.push(MaterialPageRoute(builder: (_) => const AnalysisScreen()));
  }

  Widget _actions() => Column(
        children: [
          if (AccessRepository.I.visible(AppSection.analysis)) ...[
            QuizPrimaryButton(
              label: "متابعة ورؤية مستواي",
              icon: PI.chartLine,
              height: 53,
              onTap: _seeLevel,
            ),
            const SizedBox(height: 10),
          ],
          QuizPrimaryButton(
            label: "اختبار جديد بنفس الدروس",
            icon: PI.arrowCounterClockwise,
            height: 53,
            fill: AppColors.quizTint,
            ink: AppColors.primary,
            onTap: () {
              final c = widget.controller;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                    builder: (_) =>
                        QuizPlayScreen(controller: c..questions = const [])),
              );
            },
          ),
          const SizedBox(height: 10),
          // 🎨 ثانويٌّ في التصميم: تعبئةٌ باهتةٌ بلون الهوية وحبرٌ أزرق.
          QuizPrimaryButton(
            label: "راجع إجاباتك",
            icon: PI.notePencil,
            height: 53,
            fill: AppColors.quizTint,
            ink: AppColors.primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) =>
                      QuizReviewScreen.live(controller: widget.controller)),
            ),
          ),
        ],
      );
}
