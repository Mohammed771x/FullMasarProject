import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../widgets/demo_widgets.dart';
import '../../../../core/widgets/screen_tip.dart';
import '../../../../core/widgets/robot_widget.dart';
import 'aptitude_screen.dart';
import 'quiz_setup_screen.dart';

// ==========================================
// 🧠 قسم اختبر نفسك — كرتان
// ==========================================
class QuizHomeScreen extends StatelessWidget {
  const QuizHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Column(
            children: [
              const GlassBar(title: "اختبر نفسك 🧠", subtitle: "قِس مستواك واكتشف تخصصك"),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                  children: [
                    FadeInSlide(child: _bigCard(
                      context,
                      "📝 اختبر مستواك في مادة",
                      "أسئلة اختيار من متعدد مع تصحيح فوري وخريطة نقاط ضعفك.",
                      const [Color(0xFF3B82F6), Color(0xFF6D28D9)],
                      RobotState.think,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuizSetupScreen())),
                    )),
                    const SizedBox(height: 18),
                    FadeInSlide(delay: 0.1, child: _bigCard(
                      context,
                      "🧭 اكتشف تخصصك",
                      "اختبار ميول من 15 سؤالاً يكشف مجالك المهني الأنسب.",
                      const [Color(0xFFEC4899), Color(0xFF8B5CF6)],
                      RobotState.point,
                      () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AptitudeScreen())),
                    )),
                  ],
                ),
              ),
            ],
          ),
          const ScreenTip(screenId: "quiz", text: "اختبر نفسك 🧠 اختر مادة ووحدة وعدد الأسئلة، وبعدها ستظهر لك نقاط ضعفك."),
        ],
      ),
    );
  }

  Widget _bigCard(BuildContext context, String title, String desc, List<Color> g, RobotState st, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(gradient: LinearGradient(colors: g, begin: Alignment.topRight, end: Alignment.bottomLeft), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: g.last.withValues(alpha: 0.3), blurRadius: 18, offset: const Offset(0, 10))]),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Text(desc, style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: Text("ابدأ الآن", style: TextStyle(color: g.last, fontWeight: FontWeight.bold, fontSize: 12.5))),
                ],
              ),
            ),
            RobotWidget(size: 92, state: st),
          ],
        ),
      ),
    );
  }
}
