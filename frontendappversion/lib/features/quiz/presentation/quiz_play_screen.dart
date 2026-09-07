import 'package:flutter/material.dart';
import '../../../../core/widgets/masar_markdown.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/robot_widget.dart';
import 'quiz_controller.dart';
import 'quiz_result_screen.dart';

// ==========================================
// 📝 شاشة الاختبار — سؤال بسؤال
// ==========================================
// التسلسل: اختيار → «تأكيد» → يتلوّن الصحيح أخضر والخطأ أحمر → «التالي».
// الخروج أثناء الاختبار يحتاج تأكيداً (التقدّم يضيع — الأسئلة لا تُخزَّن).
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
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("إنهاء الاختبار؟", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text("ستفقد تقدّمك في هذا الاختبار ولن تُحفظ النتيجة.",
            style: TextStyle(color: AppColors.textSecondary, height: 1.6, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("أكمل الاختبار", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("خروج", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    return leave ?? false;
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

  Widget _loading() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RobotWidget(size: 110, state: RobotState.think),
            const SizedBox(height: 18),
            Text("أجهّز أسئلتك من دروسك…",
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 10),
            Text("قد تستغرق بضع ثوانٍ",
                style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 22),
            SizedBox(
              width: 150,
              child: LinearProgressIndicator(
                  minHeight: 5, backgroundColor: AppColors.softSurface,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary)),
            ),
          ],
        ),
      );

  Widget _errorView() => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RobotWidget(size: 96, state: RobotState.idle),
              const SizedBox(height: 16),
              Text(c.error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13.5, height: 1.9,
                      fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text("رجوع", style: TextStyle(color: AppColors.textSecondary))),
                  const SizedBox(width: 12),
                  if (!c.quotaExceeded)
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: _generate,
                      child: const Text("حاول مجدداً", style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
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
              RobotWidget(size: 90, state: RobotState.idle),
              const SizedBox(height: 14),
              Text("لم تصل أي أسئلة. جرّب مرة أخرى.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              const SizedBox(height: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: _generate,
                child: const Text("حاول مجدداً", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("رجوع", style: TextStyle(color: AppColors.textSecondary)),
              ),
            ],
          ),
        ),
      );

  Widget _quizBody() {
    // 🛡️ حارس أخير: أي حالة غير متوقّعة تُظهر رسالة وزر رجوع — لا شاشة بيضاء.
    if (c.questions.isEmpty) return _emptyGuard();
    if (c.index >= c.questions.length) return _loading();   // لحظة الانتقال للنتيجة
    final q = c.current;

    return Column(
      children: [
        _topBar(),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
            children: [
              FadeInSlide(
                key: ValueKey(c.index),          // إعادة الأنيميشن لكل سؤال
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: MathOrText(q.q,
                          style: TextStyle(
                              fontSize: 16, height: 1.8,
                              fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                    ),
                    const SizedBox(height: 16),
                    ...List.generate(q.options.length, (i) => _option(i)),
                    if (c.confirmed) _feedback(),
                  ],
                ),
              ),
            ],
          ),
        ),
        _bottomButton(),
      ],
    );
  }

  Widget _topBar() {
    final progress = (c.index + 1) / c.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 6),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                onPressed: () async {
                  final navigator = Navigator.of(context);
                  if (await _confirmExit()) navigator.pop();
                },
              ),
              Expanded(
                child: Text("سؤال ${c.index + 1} من ${c.total}",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12)),
                child: Text("✅ ${c.score}",
                    style: TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.primary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.softSurface,
              valueColor: AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _option(int i) {
    final q = c.current;
    final isSelected = c.selected == i;
    final isCorrect = i == q.correctIndex;

    Color border = AppColors.softSurface;
    Color bg = AppColors.surfaceWhite;
    IconData? icon;
    Color iconColor = AppColors.textSecondary;

    if (c.confirmed) {
      if (isCorrect) {
        border = Colors.green.shade500;
        bg = Colors.green.withValues(alpha: 0.08);
        icon = Icons.check_circle_rounded;
        iconColor = Colors.green.shade600;
      } else if (isSelected) {
        border = Colors.redAccent;
        bg = Colors.red.withValues(alpha: 0.06);
        icon = Icons.cancel_rounded;
        iconColor = Colors.redAccent;
      }
    } else if (isSelected) {
      border = AppColors.primary;
      bg = AppColors.primary.withValues(alpha: 0.07);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: c.confirmed ? null : () => c.select(i),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: 1.6),
          ),
          child: Row(
            children: [
              Expanded(
                child: MathOrText(q.options[i],
                    style: TextStyle(
                        fontSize: 14, height: 1.6,
                        fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ),
              if (icon != null) Icon(icon, color: iconColor, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Widget _feedback() {
    final ok = c.current.isCorrect(c.selected);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: (ok ? Colors.green : Colors.orange).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(ok ? Icons.emoji_events_rounded : Icons.lightbulb_rounded,
                color: ok ? Colors.green.shade600 : Colors.orange.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ok ? "إجابة صحيحة! 🎯" : "الموضوع: ${c.current.topic} — راجعه بعد الاختبار.",
                style: TextStyle(
                    fontSize: 12.5, height: 1.6,
                    fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomButton() {
    final canConfirm = c.selected != null && !c.confirmed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
      child: SizedBox(
        height: 54,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor:
                (canConfirm || c.confirmed) ? AppColors.primary : AppColors.softSurface,
            foregroundColor:
                (canConfirm || c.confirmed) ? Colors.white : AppColors.textSecondary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: () {
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
          child: Text(
            c.confirmed ? (c.isLast ? "عرض النتيجة 🏁" : "التالي") : "تأكيد",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
