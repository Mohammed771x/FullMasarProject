import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../data/demo_state.dart';
import '../widgets/demo_widgets.dart';
import 'education_screen.dart';
import 'subject_analysis_screen.dart';

// ==========================================
// 🏁 نتيجة الاختبار (تصميم بريميوم) + خريطة الضعف + 4 أزرار
// ==========================================
class QuizResultScreen extends StatefulWidget {
  final String subject;
  final int score;
  final int total;
  final List<String> wrongTopics;
  const QuizResultScreen({super.key, required this.subject, required this.score, required this.total, required this.wrongTopics});

  @override
  State<QuizResultScreen> createState() => _QuizResultScreenState();
}

class _QuizResultScreenState extends State<QuizResultScreen> {
  @override
  void initState() {
    super.initState();
    DemoState.I.addResult({"type": "quiz", "subject": widget.subject, "score": widget.score, "total": widget.total, "wrong": widget.wrongTopics});
  }

  double get _pct => widget.total == 0 ? 0 : widget.score / widget.total;
  Color get _color => _pct >= 0.8 ? Colors.green : (_pct >= 0.5 ? Colors.orange : Colors.redAccent);
  String get _level => _pct >= 0.9 ? "ممتاز" : (_pct >= 0.75 ? "جيد جداً" : (_pct >= 0.5 ? "جيد" : "يحتاج تحسين"));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
              children: [
                Align(alignment: Alignment.centerLeft, child: InkWell(onTap: () => Navigator.popUntil(context, (r) => r.isFirst), child: Icon(Icons.close_rounded, color: AppColors.textPrimary))),

                // بطاقة النتيجة البريميوم
                FadeInSlide(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [_color, _color.withValues(alpha: 0.7)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [BoxShadow(color: _color.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 12))],
                    ),
                    child: Column(
                      children: [
                        const Text("🎉", style: TextStyle(fontSize: 44)),
                        const SizedBox(height: 6),
                        const Text("نتيجتك", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _pct),
                          duration: const Duration(milliseconds: 1100),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => Text("${widget.score} / ${widget.total}", style: const TextStyle(color: Colors.white, fontSize: 46, fontWeight: FontWeight.w900)),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(16)),
                          child: Text("مستواك: $_level", style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                // نقاط المراجعة
                if (widget.wrongTopics.isNotEmpty) ...[
                  Row(children: [
                    Icon(Icons.visibility_rounded, color: AppColors.secondary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(child: Text("لاحظنا أنك تحتاج إلى مراجعة:", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
                  ]),
                  const SizedBox(height: 12),
                  ...widget.wrongTopics.asMap().entries.map((e) => FadeInSlide(
                        delay: 0.05 * e.key,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: SoftCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), shape: BoxShape.circle), child: Icon(Icons.check_rounded, color: Colors.green, size: 18)),
                              const SizedBox(width: 12),
                              Expanded(child: Text(e.value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textPrimary))),
                            ]),
                          ),
                        ),
                      )),
                ] else
                  SoftCard(child: Row(children: [
                    Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 26),
                    const SizedBox(width: 12),
                    Expanded(child: Text("أداء مثالي! لا توجد نقاط ضعف 🌟", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                  ])),

                const SizedBox(height: 24),

                // 4 أزرار
                Row(children: [
                  Expanded(child: _actionBtn("📚 شرح الدروس", const [Color(0xFF3B82F6), Color(0xFF1D4ED8)], () => _goEducation("شرح"))),
                  const SizedBox(width: 12),
                  Expanded(child: _actionBtn("📄 تلخيص الدروس", const [Color(0xFF8B5CF6), Color(0xFF6D28D9)], () => _goEducation("تلخيص"))),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _actionBtn("📝 إعادة الاختبار", const [Color(0xFFF59E0B), Color(0xFFEA580C)], () => Navigator.pop(context))),
                  const SizedBox(width: 12),
                  Expanded(child: _actionBtn("📊 عرض تحليل المادة", const [Color(0xFF10B981), Color(0xFF059669)], () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectAnalysisScreen(subjectKey: widget.subject)));
                  })),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _goEducation(String mode) {
    final topic = widget.wrongTopics.isNotEmpty ? widget.wrongTopics.first : null;
    Navigator.push(context, MaterialPageRoute(builder: (_) => EducationScreen(initialSubject: widget.subject, autoPrompt: topic)));
  }

  Widget _actionBtn(String label, List<Color> g, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: g, begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: g.last.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Center(child: Text(label, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900))),
      ),
    );
  }
}

// (محتفظ به إن احتجناه لاحقاً) رسّام حلقة النسبة
class RingPainter extends CustomPainter {
  final double value;
  final Color color;
  RingPainter(this.value, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2 - 10;
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.12)..style = PaintingStyle.stroke..strokeWidth = 16..strokeCap = StrokeCap.round);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2, 2 * math.pi * value, false, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 16..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant RingPainter old) => old.value != value || old.color != color;
}
