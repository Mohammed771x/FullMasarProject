import 'package:flutter/material.dart';

import '../widgets/masar_logo.dart';
import 'onboarding_screen.dart';

// ==========================================
// 💫 شاشة البداية (Splash) — نبض الشعار ثم الانتقال
// ==========================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  final List<String> _steps = ["تهيئة المنصة...", "تحميل الإعدادات...", "التحقق من الحساب...", "جاهز 🚀"];
  int _step = 0;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
    _runSteps();
  }

  void _runSteps() async {
    for (int i = 0; i < _steps.length; i++) {
      await Future.delayed(const Duration(milliseconds: 620));
      if (!mounted) return;
      setState(() => _step = i);
    }
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => const OnboardingScreen(),
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
      backgroundColor: const Color(0xFFF3F7FD),
      body: Stack(
        children: [
          const Positioned.fill(child: SoftWaveBackground()),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ScaleTransition(
                  scale: Tween(begin: 0.94, end: 1.06).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
                  child: const MasarLogo(size: 130),
                ),
                const SizedBox(height: 20),
                const Text("مسار", style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: kNavy, letterSpacing: 1)),
                const SizedBox(height: 6),
                const Text("سفير الطالب اليمني 🇾🇪", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kNavy)),
                const SizedBox(height: 46),
                SizedBox(
                  width: 26,
                  height: 26,
                  child: CircularProgressIndicator(strokeWidth: 2.6, valueColor: AlwaysStoppedAnimation(kBlueBtn.first)),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(_steps[_step], key: ValueKey(_step), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF9AA6B6))),
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.account_balance_rounded, size: 14, color: Color(0xFF9AA6B6)),
                  SizedBox(width: 6),
                  Text("Powered by Hadhramout Foundation", style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF9AA6B6))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
