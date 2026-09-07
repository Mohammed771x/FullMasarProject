import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/session/role_home.dart';

import '../../../../app/bootstrap.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../auth/presentation/verify_email_screen.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';

// ==========================================
// 💫 شاشة البداية (Splash) — الشعار الرسمي ثم التوجيه
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _route();
  }

  Future<void> _route() async {
    final entry = await AppBootstrap.firstScreen();
    // مهلة قصيرة ليظهر الشعار — التهيئة الفعلية تمت قبل رسم التطبيق.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final Widget next = switch (entry) {
      AppEntry.onboarding => const OnboardingScreen(),
      AppEntry.auth => const AuthScreen(),
      AppEntry.verifyEmail => const VerifyEmailScreen(),
      // 🎭 بيت الدور: المعلّم يفتح على أدواته، والطالب على رئيسيته.
      AppEntry.home => RoleHome.screen(),
    };

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 650),
        pageBuilder: (_, _, _) => next,
        transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // 🌗 خلفية الصفحة تتبع الوضع — كانت ثابتةً فاتحة، فيصير الوضع
      //    الداكن بطاقاتٍ داكنة تطفو على صفحةٍ بيضاء.
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          Positioned.fill(child: SoftWaveBackground()),
          Center(
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.06).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
              child: MasarBrand(logoSize: 150, titleSize: 44),
            ),
          ),
          Positioned(
            bottom: 46,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6, valueColor: AlwaysStoppedAnimation(kBlueBtn.first)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
