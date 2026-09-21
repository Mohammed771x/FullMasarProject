import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/masar_brand.dart';
import '../../../core/widgets/masar_dialog.dart';
import '../../../core/widgets/masar_markdown.dart';
import '../../../core/widgets/phosphor.dart';
import 'quiz_controller.dart';
import 'quiz_result_screen.dart';
import 'widgets/quiz_ui.dart';

// ==========================================
// 📝 شاشة الاختبار — سؤال بسؤال
// ==========================================
// التسلسل: اختيار → «تأكيد» → يتلوّن الصحيح أخضر والخطأ أحمر → «التالي».
// الخروج أثناء الاختبار يحتاج تأكيداً (التقدّم يضيع — الأسئلة لا تُخزَّن).
//
// 🎨 **إعادة التصميم** (`design/05-quiz/` · 02 · 04 · 05 · 06 · 03-تحميل):
//    شريطٌ علويٌّ فيه شارةُ النقاط والعنوان وزرُّ الإغلاق · قضيبُ تقدّمٍ
//    10.5 · بطاقةُ السؤال r12 · خياراتٌ 46 **نصُّها في الوسط** · صندوقُ
//    نتيجةٍ ملوّن · وزرٌّ أزرقُ 58. والمعطَّلُ منه أزرقُ فاتحٌ لا رماديّ.
//
// ⚠️ **ولا شيءَ من المنطق تغيّر**: `QuizController` هو هو، والنداءُ هو هو،
//    وحارسُ الخروج والحفظُ والانتقال إلى النتيجة كما كانت حرفاً بحرف.
class QuizPlayScreen extends StatefulWidget {
  final QuizController controller;
  const QuizPlayScreen({super.key, required this.controller});

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> {
  QuizController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    if (c.questions.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _generate());
    }
  }

  Future<void> _generate() async {
    // ⚠️ لا setState هنا: الشاشة تستمع للمتحكّم عبر AnimatedBuilder أدناه.
    //    (العلّة السابقة: كان البناء يُعاد عند الفشل فقط، فمسار النجاح يبقى
    //     على أول إطار — questions فارغة و isGenerating=false ⇒ شاشة بيضاء.)
    await c.generate();
  }

  Future<bool> _confirmExit() async {
    if (c.questions.isEmpty || c.isFinished) return true;
    // 🪟 بقالب حوارات التطبيق — لا `AlertDialog` بمقاسات العهد السابق.
    //    و`MasarDialog` يُغلق نفسه، فالنتيجةُ تُلتقط في متغيّرٍ لا بالعودة.
    bool leave = false;
    await showDialog<void>(
      context: context,
      builder: (_) => MasarDialog(
        icon: PD.warning,
        iconTint: AppColors.quizWrongFill,
        iconInk: AppColors.quizWrong,
        title: "إنهاء الاختبار؟",
        primaryLabel: "خروج",
        primaryColor: AppColors.quizWrong,
        cancelLabel: "أكمل الاختبار",
        onPrimary: () async => leave = true,
        child: Text(
          "ستفقد تقدّمك في هذا الاختبار ولن تُحفظ النتيجة.",
          style: TextStyle(
              fontSize: 12,
              height: 1.7,
              fontWeight: FontWeight.w600,
              color: AppColors.chipInk),
        ),
      ),
    );
    return leave;
  }

  Future<void> _finish() async {
    final result = await c.saveResult();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => QuizResultScreen(controller: c, result: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final navigator = Navigator.of(context);   // يُلتقط قبل الانتظار
        if (await _confirmExit()) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: SafeArea(
          // 🔄 كل تغيّر في المتحكّم (توليد · اختيار · تأكيد · انتقال) يعيد البناء.
          child: AnimatedBuilder(
            animation: c,
            builder: (_, _) => c.isGenerating
                ? _loading()
                : (c.error != null ? _errorView() : _quizBody()),
          ),
        ),
      ),
    );
  }

  // ───────────────────────── الحالات ─────────────────────────

  /// ⏳ **«جارٍ تجهيز أسئلتك»** — وهنا يتحرّك الروبوت.
  ///
  /// 🎯 طلبُ المالك: «لما جاهز تجهيز أسئلتك، خلّي الروبوت يتحرّك». والحركةُ
  ///    في [MasarRobotAnimated] فوق الصورة لا داخلها: تبديلُ الشخصية يبقى
  ///    تبديلَ ملفٍّ كما هو العهد.
  Widget _loading() => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const MasarRobotAnimated(size: 118),
              const SizedBox(height: 14),
              Text("جارٍ تجهيز أسئلتك…",
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.panelTitle)),
              const SizedBox(height: 12),
              Text(
                "أقرأ دروسك وأصوغ منها أسئلةً سهلةً ثم أصعب.\n"
                "قد تستغرق بضع ثوانٍ.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    fontWeight: FontWeight.w600,
                    color: AppColors.chipInk),
              ),
            ],
          ),
        ),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MasarRobot(size: 96, pose: MasarRobotPose.fly),
              const SizedBox(height: 16),
              Text(c.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      height: 1.9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.panelTitle)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!c.quotaExceeded)
                    SizedBox(
                      width: 170,
                      child: QuizPrimaryButton(
                        label: "حاول مجدداً",
                        icon: PI.arrowCounterClockwise,
                        height: 46,
                        onTap: _generate,
                      ),
                    ),
                  const SizedBox(width: 12),
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("رجوع",
                          style: TextStyle(
                              color: AppColors.chipInk,
                              fontWeight: FontWeight.w800))),
                ],
              ),
            ],
          ),
        ),
      );

  /// لا يُفترض الوصول إليها — لكن وجودها يمنع الشاشة البيضاء إن حدث.
  Widget _emptyGuard() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              MasarRobot(size: 90, pose: MasarRobotPose.fly),
              const SizedBox(height: 14),
              Text("لم تصل أي أسئلة. جرّب مرة أخرى.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColors.panelTitle)),
              const SizedBox(height: 18),
              SizedBox(
                width: 170,
                child: QuizPrimaryButton(
                  label: "حاول مجدداً",
                  icon: PI.arrowCounterClockwise,
                  height: 46,
                  onTap: _generate,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("رجوع",
                    style: TextStyle(
                        color: AppColors.chipInk,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ),
      );

  // ───────────────────────── الجسم ─────────────────────────

  Widget _quizBody() {
    // 🛡️ حارس أخير: أي حالة غير متوقّعة تُظهر رسالة وزر رجوع — لا شاشة بيضاء.
    if (c.questions.isEmpty) return _emptyGuard();
    if (c.index >= c.questions.length) return _loading();   // لحظة الانتقال للنتيجة
    final q = c.current;
    final ltr = isLatinCard(q.q, q.options);

    return Column(
      children: [
        _topBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                QuizMetrics.margin, 25, QuizMetrics.margin, 28),
            children: [
              FadeInSlide(
                key: ValueKey(c.index),          // إعادة الأنيميشن لكل سؤال
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 📄 بطاقةُ السؤال — r12 كما قِستُها، لا r16 كبطاقات الإعداد.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.quizCardBorder),
                        boxShadow: isDarkModeNotifier.value
                            ? const []
                            : AppColors.softShadow,
                      ),
                      child: MathOrText(q.q,
                          forceLtr: ltr,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 14,
                              height: 1.6,
                              fontWeight: FontWeight.w900,
                              color: AppColors.panelTitle)),
                    ),
                    const SizedBox(height: 17),
                    for (var i = 0; i < q.options.length; i++) ...[
                      if (i > 0) const SizedBox(height: 11),
                      _option(i, ltr),
                    ],
                    if (c.confirmed) ...[
                      const SizedBox(height: 27),
                      _feedback(),
                    ],
                    const SizedBox(height: 11),
                    _bottomButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────── الشريط العلوي ─────────────────────
  //
  // 📐 مقيس: صندوقان 32×32 r10 عند الهامشين، وعنوانٌ 13/w900 في الوسط،
  //    ثم فراغ 12 وقضيبُ تقدّمٍ 10.5 بنصف قطرٍ كامل.

  Widget _topBar() {
    final progress = (c.index + 1) / c.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          QuizMetrics.margin, 27, QuizMetrics.margin, 0),
      child: Column(
        children: [
          Row(
            children: [
              // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — وزرُّ الإغلاق هناك في التصميم.
              QuizSquareButton(
                icon: PI.x,
                onTap: () async {
                  final navigator = Navigator.of(context);
                  if (await _confirmExit()) navigator.pop();
                },
              ),
              Expanded(
                child: Text("سؤال ${c.index + 1} من ${c.total}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: AppColors.panelTitle)),
              ),
              _scoreBadge(),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10.5,
              backgroundColor: AppColors.quizChipFill,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  /// ☑️ **عدّادُ النقاط** — صندوقٌ 32 فيه `CheckSquare` ثنائيةُ اللون
  ///    بلونٍ زمرّديٍّ `#00D492` ثم الرقم. (قِستُ التعبئة `#CCF2E5` فوجدتُها
  ///    اللونَ نفسَه بشفافية 0.20 — توقيعُ نمط Duotone بالضبط.)
  Widget _scoreBadge() => Container(
        height: QuizMetrics.squareButton,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.quizCardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — والرقمُ هناك في التصدير
            //    (المربّعُ عند x=37 والرقمُ عند x=59.5، أي المربّعُ يساراً).
            Text("${c.score}",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: AppColors.panelTitle)),
            const SizedBox(width: 7),
            PDuo(PD.checkSquare, size: 20, color: AppColors.quizEmerald),
          ],
        ),
      );

  // ───────────────────────── الخيارات ─────────────────────────
  //
  // 📐 46 · r12 · النصُّ **في الوسط** وأيقونةُ الحالة في نهاية السطر (يسار).

  Widget _option(int i, bool ltr) {
    final q = c.current;
    final isSelected = c.selected == i;
    final isCorrect = i == q.correctIndex;

    Color border = AppColors.quizOptionBorder;
    Color bg = AppColors.quizOptionFill;
    Color ink = AppColors.textPrimary;
    IconData? icon;
    Color iconColor = AppColors.quizRight;

    if (c.confirmed) {
      if (isCorrect) {
        border = AppColors.quizRight;
        bg = AppColors.quizRightFill;
        icon = PI.checkCircle.fill;
      } else if (isSelected) {
        border = AppColors.quizWrong;
        bg = AppColors.quizWrongFill;
        icon = PI.xCircle.fill;
        iconColor = AppColors.quizWrong;
      }
    } else if (isSelected) {
      border = AppColors.primary;
      bg = AppColors.quizTint;
      // 📐 **والحبرُ يبقى كما هو.** قِستُ `04-سؤال تحديد`: نصُّ الخيار
      //    المحدَّد `#101010` لا أزرق — الأزرقُ للحدّ والتعبئة وحدهما.
    }

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: c.confirmed ? null : () => c.select(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints:
            const BoxConstraints(minHeight: QuizMetrics.optionHeight),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            // ⚖️ خانتان متساويتان على الطرفين كي يبقى النصُّ في **وسط
            //    الصفّ** لا في وسط ما تبقّى منه بعد الأيقونة.
            const SizedBox(width: 26),
            Expanded(
              child: MathOrText(q.options[i],
                  forceLtr: ltr,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                      color: ink)),
            ),
            SizedBox(
              width: 26,
              child: icon == null
                  ? null
                  : Icon(icon, color: iconColor, size: 22),
            ),
          ],
        ),
      ),
    );
  }

  /// 🟩🟥 صندوقُ النتيجة تحت الخيارات — بلون الحالة وحدٍّ منها.
  Widget _feedback() {
    final ok = c.current.isCorrect(c.selected);
    return Container(
      constraints: const BoxConstraints(minHeight: 53),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: ok ? AppColors.quizRightFill : AppColors.quizWrongFill,
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: ok ? AppColors.quizRight : AppColors.quizWrong),
      ),
      // 📐 **ونصُّه كحليٌّ لا ملوّن.** قِستُ `05` و`06` فوجدتُ أغمقَ حبرٍ
      //    في الصندوقين `#091E42` في الحالتين — اللونُ في الحدّ والتعبئة،
      //    والنصُّ يُقرأ. (وأخضرُ `#20D958` على `#E9FBEE` نسبتُه 1.6:1.)
      child: Text(
        ok
            ? "إجابة صحيحة! 🎯"
            : "الموضوع: ${c.current.topic} — راجعه بعد الاختبار.",
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 12,
            height: 1.6,
            fontWeight: FontWeight.w800,
            color: AppColors.panelTitle),
      ),
    );
  }

  Widget _bottomButton() {
    final canConfirm = c.selected != null && !c.confirmed;
    return QuizPrimaryButton(
      label: c.confirmed ? (c.isLast ? "عرض النتيجة 🏁" : "التالي") : "تأكيد",
      enabled: canConfirm || c.confirmed,
      onTap: () {
        if (c.confirmed) {
          if (c.isLast) {
            _finish();
          } else {
            c.next();
          }
          return;
        }
        if (!canConfirm) return;
        HapticFeedback.selectionClick();
        c.confirm();
      },
    );
  }
}
