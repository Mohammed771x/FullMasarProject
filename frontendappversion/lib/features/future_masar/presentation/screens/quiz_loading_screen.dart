import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/typewriter_text.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/robot_widget.dart';

// ==========================================
// 🤖 شاشة تحميل توليد الاختبار (محاكاة)
// ==========================================
class QuizLoadingScreen extends StatefulWidget {
  final List<String> lines;
  final WidgetBuilder next;
  const QuizLoadingScreen({super.key, required this.lines, required this.next});

  @override
  State<QuizLoadingScreen> createState() => _QuizLoadingScreenState();
}

class _QuizLoadingScreenState extends State<QuizLoadingScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: widget.next));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 34),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const RobotWidget(size: 130, state: RobotState.think),
                  const SizedBox(height: 26),
                  ...widget.lines.map((l) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: TypewriterText(text: l, isCentered: true),
                      )),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: 34,
                    height: 34,
                    child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
