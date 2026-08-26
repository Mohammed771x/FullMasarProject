import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../data/demo_data.dart';
import '../../data/demo_state.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/robot_assistant.dart';
import '../widgets/robot_widget.dart';
import 'analysis_screen.dart';
import 'education_screen.dart';
import 'teacher_assistant_screen.dart';
import 'quiz_home_screen.dart';
import 'scholarships_screen.dart';
import 'scholarship_detail_screen.dart';
import 'services_screen.dart';
import 'settings_screen.dart';

// ==========================================
// 🏠 الشاشة الرئيسية (Home)
// ==========================================
class FutureHomeScreen extends StatefulWidget {
  const FutureHomeScreen({super.key});

  @override
  State<FutureHomeScreen> createState() => _FutureHomeScreenState();
}

class _FutureHomeScreenState extends State<FutureHomeScreen> {
  final _bannerPc = PageController();
  int _banner = 0;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_bannerPc.hasClients) return;
      _banner = (_banner + 1) % demoBanners.length;
      _bannerPc.animateToPage(_banner, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _bannerPc.dispose();
    super.dispose();
  }

  void _go(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          SafeArea(
            child: AnimatedBuilder(
              animation: DemoState.I,
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 110),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 18),
                    _stats(),
                    const SizedBox(height: 20),
                    _bannerCarousel(),
                    const SizedBox(height: 24),
                    _heroEducation(),
                    const SizedBox(height: 16),
                    _threeCards(),
                    const SizedBox(height: 16),
                    _analysisCard(),
                    const SizedBox(height: 16),
                    _teacherCard(),
                    if (DemoState.I.lastChatSubject != null) ...[
                      const SizedBox(height: 20),
                      _continueCard(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const RobotAssistant(screenId: "home"),
        ],
      ),
    );
  }

  Widget _header() {
    final s = DemoState.I;
    return FadeInSlide(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(gradient: AppColors.mainGradient, shape: BoxShape.circle, boxShadow: AppColors.softShadow),
            child: CircleAvatar(radius: 26, backgroundColor: AppColors.surfaceWhite, child: Icon(Icons.person_rounded, size: 30, color: AppColors.primary)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${s.greeting}، ${s.name} 👋", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Text("الصف ${s.gradeLabel}", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                ),
              ],
            ),
          ),
          _circleBtn(Icons.notifications_rounded, () => _snack("لا إشعارات جديدة 🔔"), badge: true),
          const SizedBox(width: 10),
          _circleBtn(Icons.settings_rounded, () => _go(const SettingsScreen())),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {bool badge = false}) {
    return Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.bubbleShadow),
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
        ),
        if (badge) Positioned(right: 8, top: 8, child: Container(width: 9, height: 9, decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: AppColors.surfaceWhite, width: 1.5)))),
      ],
    );
  }

  Widget _stats() {
    return FadeInSlide(
      delay: 0.1,
      child: Row(
        children: [
          _stat(Icons.local_fire_department_rounded, "12", "يوم متتالٍ", Colors.orange),
          const SizedBox(width: 12),
          _stat(Icons.workspace_premium_rounded, "1,250", "نقطة", AppColors.secondary),
          const SizedBox(width: 12),
          _stat(Icons.bookmark_rounded, "${DemoState.I.savedAnswers.length}", "محفوظ", AppColors.primary),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String v, String label, Color color) {
    return Expanded(
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
        child: Column(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(v, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _bannerCarousel() {
    return FadeInSlide(
      delay: 0.15,
      child: Column(
        children: [
          SizedBox(
            height: 140,
            child: PageView.builder(
              controller: _bannerPc,
              onPageChanged: (i) => setState(() => _banner = i),
              itemCount: demoBanners.length,
              itemBuilder: (_, i) {
                final b = demoBanners[i];
                return GestureDetector(
                  onTap: () {
                    if (b.targetScholarshipId != null) {
                      final sch = demoScholarships.firstWhere((s) => s.id == b.targetScholarshipId);
                      _go(ScholarshipDetailScreen(scholarship: sch));
                    } else {
                      _go(const QuizHomeScreen());
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: b.gradient, begin: Alignment.topRight, end: Alignment.bottomLeft),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: b.gradient.last.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8))],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(b.title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, height: 1.3)),
                              const SizedBox(height: 8),
                              Text(b.subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Icon(b.icon, color: Colors.white.withValues(alpha: 0.9), size: 48),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(demoBanners.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: _banner == i ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(color: _banner == i ? AppColors.primary : AppColors.primary.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(8)),
            )),
          ),
        ],
      ),
    );
  }

  Widget _heroEducation() {
    return FadeInSlide(
      delay: 0.2,
      child: InkWell(
        onTap: () => _go(const EducationScreen()),
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.softShadow),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("📚 قسم التعليم", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text("اشرح، لخّص، اسأل، وتدرّب على الوزاري", style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Text("ابدأ التعلّم", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
              const RobotWidget(size: 100, state: RobotState.idle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _threeCards() {
    final items = [
      _C("🎓 المنح", "منح حول العالم", Icons.public_rounded, const [Color(0xFF8B5CF6), Color(0xFF6D28D9)], () => _go(const ScholarshipsScreen())),
      _C("🧠 اختبر نفسك", "اختبارات وميول", Icons.quiz_rounded, const [Color(0xFF0EA5E9), Color(0xFF2563EB)], () => _go(const QuizHomeScreen())),
      _C("🛠️ الخدمات", "قبول وتجهيز", Icons.handshake_rounded, const [Color(0xFF10B981), Color(0xFF0D9488)], () => _go(const ServicesScreen())),
    ];
    return Row(
      children: List.generate(items.length, (i) {
        final c = items[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i < 2 ? 12 : 0),
            child: FadeInSlide(
              delay: 0.25 + i * 0.07,
              child: InkWell(
                onTap: c.onTap,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 130,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: c.gradient, begin: Alignment.topRight, end: Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: c.gradient.last.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)), child: Icon(c.icon, color: Colors.white, size: 20)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(c.sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _analysisCard() {
    return FadeInSlide(
      delay: 0.32,
      child: InkWell(
        onTap: () => _go(const AnalysisScreen()),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF334155)], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: const Text("📊", style: TextStyle(fontSize: 24))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("تحليل مستواي", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text("اعرف نقاط قوتك وضعفك واحصل على توصيات لتحسين مستواك.", style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_circle_left_rounded, color: Colors.white.withValues(alpha: 0.9), size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _teacherCard() {
    return FadeInSlide(
      delay: 0.36,
      child: InkWell(
        onTap: () => _go(const TeacherAssistantScreen()),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF3730A3), Color(0xFF7C3AED)], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: const Text("👨‍🏫", style: TextStyle(fontSize: 24))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("مساعد المعلم", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text("خطط للدروس وأنشئ الواجبات وحسّن طريقة الشرح بالذكاء الاصطناعي.", style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_circle_left_rounded, color: Colors.white.withValues(alpha: 0.9), size: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _continueCard() {
    final s = DemoState.I;
    return FadeInSlide(
      child: InkWell(
        onTap: () => _go(const EducationScreen()),
        borderRadius: BorderRadius.circular(20),
        child: SoftCard(
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.history_rounded, color: AppColors.primary, size: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("أكمل من حيث توقفت", style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text("${s.lastChatSubject} · قبل قليل", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 34),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}

class _C {
  final String title, sub;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  _C(this.title, this.sub, this.icon, this.gradient, this.onTap);
}
