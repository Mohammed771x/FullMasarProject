import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/session/role_home.dart';

import '../../../../app/bootstrap.dart';
import '../../../../core/widgets/masar_character.dart';
import '../../../auth/presentation/verify_email_screen.dart';
import 'auth_screen.dart';
import 'onboarding_screen.dart';
import '../../../onboarding/presentation/force_update_screen.dart';

// ==========================================
// 💫 شاشة البداية (Splash)
// ==========================================
// 🎨 **تصميم Figma** — «الشاشة الافتتاحية» (24:18598):
//    صفحةٌ بيضاء · روبوت مسار في الوسط · رقم الإصدار أسفلها بلون `#006EBF`.
//
// 🧕 **الرأسُ المعمَّم (٢٠٢٦-٠٩-٢٦):** رأسُ المصمّم للبداية كانت عمامتُه
//    **حمراء بنقشٍ آخر**، والمالك: «نفس العمامة بالضبط في كل مكان». فصار
//    الرأسُ يُقصّ من شخصية «مرحباً» نفسِها ([MasarCharacter.head]). حيٌّ
//    كشخصيات الترحيب: يدخل وينزل ويرمش ويحوم.
//
// ⛔ **ما حُذف ولماذا:**
//    · `MasarBrand` (الشعار + «مسار» + الشعار النصي) — التصميم يكتفي بالروبوت.
//    · حلقة التحميل السفلية — لا وجود لها في التصميم، والشاشة تنتقل بعد
//      ١٤٠٠ms على أي حال فالمؤشّر يومض ويختفي بلا فائدة.
//    · `SoftWaveBackground` — التصميم صفحةٌ بيضاء نظيفة.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _route();
  }

  Future<void> _route() async {
    final entry = await AppBootstrap.firstScreen();
    // مهلة قصيرة ليظهر الشعار — التهيئة الفعلية تمت قبل رسم التطبيق.
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final Widget next = switch (entry) {
      // 📦 نسخةٌ لم تعد تتفاهم مع الخادم — شاشةٌ واحدة بلا تخطٍّ.
      AppEntry.forceUpdate => ForceUpdateScreen(
        verdict: AppBootstrap.versionVerdict,
      ),
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
        transitionsBuilder: (_, a, _, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🌗 يُعاد البناء عند تبدّل الوضع — شرطُ قبولٍ لكل شاشة في هذا المشروع.
    return ThemeScope(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.bgLight,
        body: SafeArea(
          child: Stack(
            children: [
              // ✨ حركةُ الشخصية تُبقي الشاشة حيّة في الثانية والنصف التي
              //    تسبق التوجيه — بديلُ حلقة التحميل المحذوفة.
              // 📐 **مستقيمٌ في البداية وحدها** (طلب المالك ٢٠٢٦-٠٩-٢٦: «مقصوف،
              //    خلّوه ستريت»): الرأسُ مقصوصٌ من «هلا» حيث يميل مع الوقفة
              //    26.6° (مقيسةً من محور شاشة الوجه). فيُدار هنا بالقدر نفسه عكسياً
              //    — والصورةُ نفسها لا تُمسّ لأن الإطلالة من خلف الجوّال تريدها مائلة.
              Center(
                child: Transform.rotate(
                  angle: -26.6 * math.pi / 180,
                  child: const SizedBox(
                    width: 190,
                    height: 180,
                    child: MasarCharacterView(character: MasarCharacter.head),
                  ),
                ),
              ),
              Positioned(
                bottom: 24,
                left: 0,
                right: 0,
                child: Center(
                  // 🔢 من [AppConstants] لا نصّاً مكتوباً — الرقم يتبع
                  //    `pubspec.yaml` فلا تكذب الشاشةُ على الطالب.
                  child: Text(
                    "v${AppConstants.appVersionName}",
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.primary800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
