import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/robot_widget.dart';
import 'teacher_feature_screen.dart';

// ==========================================
// 👨‍🏫 الصفحة الرئيسية لمساعد المعلم — 4 ميزات
// ==========================================
class TeacherAssistantScreen extends StatelessWidget {
  const TeacherAssistantScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _F("📖 إنشاء خطة درس", "أنشئ خطة تدريس احترافية تتضمن الأهداف، خطوات الشرح، الأنشطة، التقويم والواجب.", const [Color(0xFF3B82F6), Color(0xFF1D4ED8)], TeacherFeature.lessonPlan),
      _F("💡 تبسيط مفهوم", "ساعدني في تبسيط مفهوم معين واقترح أفضل طريقة لشرحه للطلاب.", const [Color(0xFFF59E0B), Color(0xFFEA580C)], TeacherFeature.simplify),
      _F("📝 إنشاء واجب", "أنشئ واجبات وأسئلة صفية مناسبة لمستوى الطلاب ودرجة الصعوبة.", const [Color(0xFF10B981), Color(0xFF059669)], TeacherFeature.homework),
      _F("🤖 اسأل المساعد", "محادثة مفتوحة مع مساعد المعلم لأي سؤال تربوي أو تعليمي.", const [Color(0xFF8B5CF6), Color(0xFF6D28D9)], TeacherFeature.openChat),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Column(
            children: [
              const GlassBar(title: "مساعد المعلم 👨‍🏫", subtitle: "خطّط، بسّط، وأنشئ الواجبات"),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  children: [
                    FadeInSlide(child: _hero()),
                    const SizedBox(height: 20),
                    const SectionHeader("أدوات المعلم"),
                    ...List.generate(items.length, (i) => FadeInSlide(
                          delay: 0.1 + i * 0.07,
                          child: Padding(padding: const EdgeInsets.only(bottom: 14), child: _card(context, items[i])),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF3730A3)], begin: Alignment.topRight, end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("مساعدك التعليمي الذكي 🎓", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text("وفّر وقتك وحسّن طريقة شرحك مع أدوات مسار المصممة للمعلم اليمني.", style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const RobotWidget(size: 90, state: RobotState.point),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, _F f) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TeacherFeatureScreen(feature: f.feature))),
      borderRadius: BorderRadius.circular(24),
      child: SoftCard(
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(gradient: LinearGradient(colors: f.gradient), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: f.gradient.last.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6))]),
              child: Center(child: Text(f.title.characters.first, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(f.desc, style: TextStyle(fontSize: 11.5, height: 1.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }
}

class _F {
  final String title;
  final String desc;
  final List<Color> gradient;
  final TeacherFeature feature;
  _F(this.title, this.desc, this.gradient, this.feature);
}
