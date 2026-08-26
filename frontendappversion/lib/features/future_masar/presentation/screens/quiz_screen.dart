import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/demo_data.dart';
import '../widgets/demo_widgets.dart';
import 'quiz_result_screen.dart';
import 'review_result_screen.dart';

// ==========================================
// 📝 شاشة الاختبار — سؤال بسؤال
// ==========================================
class QuizScreen extends StatefulWidget {
  final String subject;
  final int count;
  final bool isReview;
  final String? reviewLesson;
  const QuizScreen({super.key, required this.subject, required this.count, this.isReview = false, this.reviewLesson});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<QuizQ> _qs;
  int _i = 0;
  int? _selected;
  bool _confirmed = false;
  int _score = 0;
  final List<String> _wrong = [];

  @override
  void initState() {
    super.initState();
    final bank = demoQuizBank[widget.subject] ?? const [];
    _qs = List.generate(widget.count, (k) => bank[k % bank.length]);
  }

  void _confirm() {
    if (_selected == null) return;
    setState(() {
      _confirmed = true;
      if (_selected == _qs[_i].correct) {
        _score++;
      } else {
        _wrong.add(_qs[_i].topic);
      }
    });
  }

  void _next() {
    if (_i < _qs.length - 1) {
      setState(() {
        _i++;
        _selected = null;
        _confirmed = false;
      });
    } else if (widget.isReview) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ReviewResultScreen(
        subject: widget.subject,
        lesson: widget.reviewLesson ?? "دروسك الضعيفة",
        score: _score,
        total: _qs.length,
      )));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuizResultScreen(
        subject: widget.subject,
        score: _score,
        total: _qs.length,
        wrongTopics: _wrong.toSet().toList(),
      )));
    }
  }

  Future<bool> _confirmExit() async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("الخروج من الاختبار؟", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text("ستفقد تقدمك في هذا الاختبار.", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("متابعة", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("خروج", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
        ],
      ),
    );
    return r ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final q = _qs[_i];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmExit()) nav.pop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: Stack(
          children: [
            const GlowBackgroundStatic(),
            SafeArea(
              child: Column(
                children: [
                  // رأس + تقدم
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                    child: Row(
                      children: [
                        InkWell(onTap: () async { final nav = Navigator.of(context); if (await _confirmExit()) nav.pop(); }, child: Icon(Icons.close_rounded, color: AppColors.textPrimary)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(value: (_i + 1) / _qs.length, minHeight: 8, backgroundColor: AppColors.softSurface, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text("${_i + 1}/${_qs.length}", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(24), boxShadow: AppColors.bubbleShadow),
                          child: Column(
                            children: [
                              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Text(widget.subject, style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12))),
                              const SizedBox(height: 14),
                              Text(q.q, textAlign: TextAlign.center, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary, height: 1.5)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        ...List.generate(q.options.length, (k) => _option(q, k)),
                        if (_confirmed) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                            child: Row(children: [
                              Icon(Icons.lightbulb_rounded, color: AppColors.secondary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(child: Text("الموضوع: ${q.topic}", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 13))),
                            ]),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // زر أسفل
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                      child: _confirmed
                          ? GradientButton(label: _i < _qs.length - 1 ? "السؤال التالي" : "عرض النتيجة", icon: Icons.arrow_forward_rounded, onTap: _next)
                          : InkWell(
                              onTap: _confirm,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                width: double.infinity,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: _selected != null ? AppColors.mainGradient : null,
                                  color: _selected == null ? AppColors.softSurface : null,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Center(child: Text("تأكيد", style: TextStyle(color: _selected != null ? Colors.white : AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold))),
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(QuizQ q, int k) {
    Color border = AppColors.textSecondary.withValues(alpha: 0.12);
    Color bg = AppColors.surfaceWhite;
    Color txt = AppColors.textPrimary;
    IconData? icon;
    if (_confirmed) {
      if (k == q.correct) {
        border = Colors.green;
        bg = Colors.green.withValues(alpha: 0.08);
        icon = Icons.check_circle_rounded;
      } else if (k == _selected) {
        border = Colors.redAccent;
        bg = Colors.redAccent.withValues(alpha: 0.08);
        icon = Icons.cancel_rounded;
      }
    } else if (k == _selected) {
      border = AppColors.primary;
      bg = AppColors.primary.withValues(alpha: 0.06);
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _confirmed ? null : () => setState(() => _selected = k),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18), border: Border.all(color: border, width: 1.6)),
          child: Row(
            children: [
              Expanded(child: Text(q.options[k], style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: txt))),
              if (icon != null) Icon(icon, color: border, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
