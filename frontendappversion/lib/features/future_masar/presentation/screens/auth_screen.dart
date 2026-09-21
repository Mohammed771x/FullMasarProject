import 'package:flutter/material.dart';

import '../../../../core/config/app_constants.dart';
import '../../../../core/session/role_home.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../auth/presentation/forgot_password_screen.dart';
import '../../../auth/presentation/signup_flow.dart';
import '../../../auth/presentation/verify_email_screen.dart';
import '../../../auth/presentation/widgets/auth_kit.dart';

// ==========================================
// 🔑 تسجيل الدخول
// ==========================================
// 🎨 **تصميم Figma** — «تسجيل دخول» (703:15904).
//
// 🔄 **أكبر تغيير بنيوي في هذا القسم:** كانت شاشةً واحدة بتبويبين
//    (تسجيل الدخول | حساب جديد) تحمل كل شيء — الاسم والصف والمسار والدور.
//    صارت **شاشتين برابطٍ بينهما**، والتسجيل تدفّقٌ من أربع خطوات
//    ([SignUpFlow]). لا شيء من وظائفها فُقد: كل حقلٍ وكل زرّ انتقل معه.
//
// 📝 **نصوص المصمّم لم تُنقل** (قرار المالك): كتب «تسجيل دخول ولي الأمر»
//    و«أدخل بياناتك لتعالم ابسط و اسهل» — وهو محتوى قالبٍ لتطبيقٍ آخر،
//    ولا وجود لولي أمرٍ في «مسار» أصلاً.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await UserSession.I.signIn(
        email_: _email.text, password: _pass.text);
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) return _error(error);
    // ★ حسابٌ ببريدٍ غير مفعّل ⇒ لا دخول (الباك اند يرفضه أيضاً).
    if (UserSession.I.needsVerification) return _goVerify();
    _goHome();
  }

  /// 🇬 الدخول بجوجل من شاشة **الدخول**: بلا صفٍّ ولا دورٍ ولا مسار —
  ///    الحساب قائمٌ ولا يجوز أن نكتب فوق بياناته قيَماً لم يطلبها.
  Future<void> _google() async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await UserSession.I.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) return _error(error);
    if (!UserSession.I.loggedIn) return; // ألغى نافذة جوجل
    _goHome();
  }

  Future<void> _guest() async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await UserSession.I.continueAsGuest();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) return _error(error);
    _goHome();
  }

  void _goVerify() => Navigator.pushReplacement(
      context, MaterialPageRoute(builder: (_) => const VerifyEmailScreen()));

  void _goHome() => Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, _, _) => RoleHome.screen(),
          transitionsBuilder: (_, a, _, c) =>
              FadeTransition(opacity: a, child: c),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      // 🚪 لا رجوع من شاشة الدخول: هي أول الطريق بعد الترحيب.
      showBack: false,
      children: [
        const SizedBox(height: 4),
        const Center(child: MasarRobot(size: 120, pose: MasarRobotPose.fly)),
        const SizedBox(height: 10),
        AuthHeading(
          title: "تسجيل الدخول",
          subtitle: "أدخل بياناتك لتتابع رحلتك من حيث توقفت",
          titleSize: 20,
        ),
        const SizedBox(height: 20),
        AuthField(
          label: "البريد الإلكتروني",
          hint: "example@domain.com",
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          ltr: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 12),
        AuthField(
          label: "كلمة المرور",
          hint: "••••••••",
          controller: _pass,
          obscure: true,
          ltr: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AuthLink(
            label: "نسيت كلمة المرور؟",
            fontSize: 12,
            color: AppColors.fieldLabel,
            onTap: _busy
                ? null
                : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            ForgotPasswordScreen(initialEmail: _email.text))),
          ),
        ),
        const SizedBox(height: 12),
        AuthPrimaryButton(
            label: "تسجيل الدخول", onTap: _submit, busy: _busy),
        const SizedBox(height: 16),
        AuthOutlineButton(
          label: "المتابعة بحساب جوجل",
          leading: const GoogleGlyph(),
          onTap: _busy ? null : _google,
        ),
        const SizedBox(height: 8),
        AuthOutlineButton(
          label: "جرّب كزائر",
          leading: const Text("👀", style: TextStyle(fontSize: 14)),
          onTap: _busy ? null : _guest,
        ),
        const SizedBox(height: 16),
        _signUpLink(),
        const SizedBox(height: 14),
        _appInfo(),
      ],
    );
  }

  Widget _signUpLink() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text("ليس لديك حساب؟ ",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          AuthLink(
            label: "إنشاء حساب",
            onTap: _busy
                ? null
                : () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SignUpFlow())),
          ),
        ],
      );

  /// 🏛️ **سطر المؤسسة أُبقي** رغم غيابه عن التصميم — كان في الشاشة القديمة،
  ///    وعقد التسليم أن لا يختفي شيء. والنسخة أُضيفت من التصميم.
  Widget _appInfo() => Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.account_balance_rounded,
                  size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text("Powered by Hadhramout Foundation",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          Text("v${AppConstants.appVersionName}",
              textDirection: TextDirection.ltr,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.n500)),
        ],
      );

  void _error(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("⚠️  $m",
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.error500,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}
