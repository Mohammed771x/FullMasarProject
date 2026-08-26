import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/storage/prefs_keys.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/typewriter_text.dart';
import '../../chat/presentation/screens/main_chat_screen.dart';

// ==========================================
// 🚀 شاشة الترحيب (Onboarding - Premium Cinematic Version)
// ==========================================
class AnimatedWelcomeScreen extends StatefulWidget {
  const AnimatedWelcomeScreen({super.key});
  @override
  State<AnimatedWelcomeScreen> createState() => _AnimatedWelcomeScreenState();
}

class _AnimatedWelcomeScreenState extends State<AnimatedWelcomeScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late AnimationController _floatController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -15, end: 15).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOutCubic));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  void _onNext() async {
    // ✅ غيرناها إلى 3 لأن صار عندنا 4 صفحات بدال 3
    if (_currentPage < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
    } else {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(PrefsKeys.isFirstRun, false);
      // 🔻 سابقاً كانت تنتقل لشاشة التفعيل — حُذف نظام التفعيل، فننتقل مباشرة للشات
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 1000),
            pageBuilder: (_, _, _) => const MainChatScreen(showDrawerHelp: true),
            transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
          ),
        );
      }
    }
  }

  void _onPrevious() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 800), curve: Curves.easeInOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          Positioned(top: -150, left: -100, child: _buildGlowOrb(AppColors.primary, 400)),
          Positioned(bottom: -100, right: -150, child: _buildGlowOrb(AppColors.secondary, 500)),

          PageView(
            controller: _pageController,
            onPageChanged: (index) => setState(() => _currentPage = index),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildPage(Icons.bubble_chart_rounded, "مرحباً بكم في مسار", "وجهتك الأولى للتعليم الذكي.\nرفيقك الدائم لشرح المواد وتلخيصها بذكاء."),
              _buildPage(Icons.psychology_rounded, "عقلٌ اصطناعي متطور", "تم بناء هذه المنصة بأحدث تقنيات الذكاء الاصطناعي لخدمة الطالب اليمني."),

              // ✅ صارت الشاشة الثالثة هنا!
              _buildDeveloperPage(),

              _buildPage(Icons.rocket_launch_rounded, "انطلق نحو المستقبل", "احصل على شروحات، تلخيصات، وأسئلة وزارية مصممة خصيصاً لمنهجك الدراسي."),
            ],
          ),

          Positioned(
            bottom: 60, left: 30, right: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                GestureDetector(
                  onTap: _currentPage > 0 ? _onPrevious : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                    decoration: BoxDecoration(
                      color: _currentPage > 0 ? AppColors.surfaceWhite : AppColors.softSurface,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: _currentPage > 0 ? AppColors.primary.withValues(alpha: 0.3) : Colors.transparent, width: 1.5),
                      boxShadow: _currentPage > 0 ? AppColors.softShadow : [],
                    ),
                    child: Text("رجوع", style: TextStyle(color: _currentPage > 0 ? AppColors.primary : AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),

                // ✅ غيرنا العداد إلى 4
                Row(
                  children: List.generate(4, (index) =>
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 32 : 10,
                      height: 10,
                      decoration: BoxDecoration(color: _currentPage == index ? AppColors.primary : AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),

                GestureDetector(
                  onTap: _onNext,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
                    decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(30), boxShadow: AppColors.softShadow),
                    // ✅ غيرنا الشرط لـ 3 عشان تظهر كلمة ابدأ الآن في آخر صفحة
                    child: Text(_currentPage == 3 ? "ابدأ الآن" : "التالي", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // خدعة الـ RadialGradient لشاشة الترحيب (تعديل الشفافية والانتشار)
  Widget _buildGlowOrb(Color color, double size) {
    return Container(
      width: size * 1.5,
      height: size * 1.5,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
          stops: const [0.0, 1.0],
        ),
      ),
    );
  }

  Widget _buildPage(IconData icon, String title, String desc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _floatAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(color: AppColors.surfaceWhite.withValues(alpha: 0.8), shape: BoxShape.circle, boxShadow: AppColors.softShadow, border: Border.all(color: AppColors.surfaceWhite, width: 3)),
              child: Icon(icon, size: 90, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 70),
        FadeInSlide(delay: 0.2, child: Text(title, style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5))),
        const SizedBox(height: 24),
        FadeInSlide(delay: 0.4, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: TypewriterText(text: desc, isCentered: true))),
      ],
    );
  }

  // ✅ تصميم شاشة المطور (متناسق 100% مع باقي الواجهات)
  Widget _buildDeveloperPage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _floatAnimation,
          builder: (context, child) => Transform.translate(
            offset: Offset(0, _floatAnimation.value),
            child: Container(
              padding: const EdgeInsets.all(48), // نفس مقاس الواجهات السابقة
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite.withValues(alpha: 0.8), // خلفية بيضاء
                shape: BoxShape.circle,
                boxShadow: AppColors.softShadow,
                border: Border.all(color: AppColors.surfaceWhite, width: 3),
              ),
              // أيقونة لابتوب/مبرمج عصرية باللون الأزرق
              child: Icon(Icons.laptop_mac_rounded, size: 90, color: AppColors.primary),
            ),
          ),
        ),
        const SizedBox(height: 70), // نفس المسافة في الواجهات الثانية
        FadeInSlide(
          delay: 0.2,
          child: Text("هندسة وتطوير 👨‍💻", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: AppColors.textPrimary, letterSpacing: -0.5)), // عبارة جديدة وفخمة
        ),
        const SizedBox(height: 24),
        FadeInSlide(
          delay: 0.4,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "تم بناء هذا الذكاء الاصطناعي لخدمة الطلاب وتسهيل مسيرتهم التعليمية من قبل المطور:\nم. محمد الديني",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary, height: 1.8, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 35),
        FadeInSlide(
          delay: 0.6,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildDevChip(Icons.phone_rounded, "780278574"),
              const SizedBox(width: 12),
              _buildDevChip(Icons.camera_alt_rounded, "Instagram"),
              const SizedBox(width: 12),
              _buildDevChip(Icons.email_rounded, "Email"),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDevChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        ],
      ),
    );
  }
}
