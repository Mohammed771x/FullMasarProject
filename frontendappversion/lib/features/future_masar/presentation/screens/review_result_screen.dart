import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/robot_widget.dart';

// ==========================================
// 🎉 نتيجة اختبار المراجعة — بطاقة نجاح
// ==========================================
class ReviewResultScreen extends StatelessWidget {
  final String subject;
  final String lesson;
  final int score;
  final int total;
  const ReviewResultScreen({super.key, required this.subject, required this.lesson, required this.score, required this.total});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: FadeInSlide(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const RobotWidget(size: 120, state: RobotState.wave),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(26),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: Column(
                          children: [
                            const Text("🎉", style: TextStyle(fontSize: 50)),
                            const SizedBox(height: 12),
                            Text("لقد تحسّن مستواك في $lesson", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900, height: 1.4)),
                            const SizedBox(height: 10),
                            Text("استمر بهذا الأداء الرائع 💪", style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 18),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(16)),
                              child: Text("نتيجتك: $score / $total", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      GradientButton(label: "رائع، تم ✅", onTap: () => Navigator.popUntil(context, (r) => r.isFirst)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
