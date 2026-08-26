import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../../../core/widgets/typewriter_text.dart';
import '../widgets/masar_logo.dart';
import '../widgets/robot_widget.dart';
import 'auth_screen.dart';

// ==========================================
// 🚀 شاشة الترحيب (Onboarding) — 4 صفحات بالروبوت
// ==========================================
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _page = 0;

  static const _pages = [
    _Ob("مرحباً بك في مسار 👋", "رفيقك من أول ثانوي حتى المنحة الجامعية.\nكل ما تحتاجه في مكان واحد.", RobotState.wave),
    _Ob("اشرح، لخّص، اسأل، وتدرّب", "شروحات وتلخيصات وأسئلة وزارية ذكية لكل المواد وكل الصفوف.", RobotState.idle),
    _Ob("منح واختبارات تكشف تخصصك", "منح دراسية حول العالم، واختبار ميول يرشدك لتخصصك الأنسب.", RobotState.think),
    _Ob("أنا معك في كل شاشة!", "اسألني متى شئت، وابدأ رحلتك الآن 🚀", RobotState.point),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _pc.nextPage(duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    } else {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 700),
          pageBuilder: (_, _, _) => const AuthScreen(),
          transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FD),
      body: Stack(
        children: [
          const Positioned.fill(child: SoftWaveBackground()),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: () => _pc.jumpToPage(_pages.length - 1),
                    child: Text("تخطي", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pc,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => _buildPage(_pages[i]),
                  ),
                ),
                _bottomBar(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_Ob ob) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RobotWidget(size: MediaQuery.of(context).size.width * 0.45, state: ob.state),
          const SizedBox(height: 24),
          // فقاعة كلام
          FadeInSlide(
            key: ValueKey(ob.title),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppColors.softShadow,
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.08)),
              ),
              child: Column(
                children: [
                  Text(ob.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: kNavy)),
                  const SizedBox(height: 12),
                  TypewriterText(key: ValueKey("t${ob.title}"), text: ob.desc, isCentered: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final last = _page == _pages.length - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(30, 10, 30, 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: _page > 0 ? () => _pc.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeOut) : null,
            child: Opacity(
              opacity: _page > 0 ? 1 : 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.softShadow),
                child: Text("رجوع", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          Row(
            children: List.generate(_pages.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _page == i ? 30 : 9,
              height: 9,
              decoration: BoxDecoration(color: _page == i ? AppColors.primary : AppColors.primary.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(10)),
            )),
          ),
          GestureDetector(
            onTap: _next,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.softShadow),
              child: Text(last ? "أنشئ حسابك 🚀" : "التالي", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ob {
  final String title;
  final String desc;
  final RobotState state;
  const _Ob(this.title, this.desc, this.state);
}
