import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/role_home.dart';

import '../../../core/session/user_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/robot_widget.dart';

// ==========================================
// 📧 شاشة تفعيل البريد
// ==========================================
// بوابة إلزامية لمسار «بريد + كلمة سر» ([27§7]): لا يدخل الطالب قبل
// `emailVerified == true` — والباك اند يرفض طلباته كذلك، فالبوابة ليست تجميلية.
//
// السلوك:
//   • فحص تلقائي كل 4 ثوانٍ (الطالب يفتح الرابط في تطبيق البريد ويعود)
//   • زر «تحققت، افتح لي» للفحص الفوري
//   • «أعد الإرسال» بمهلة 60 ثانية تمنع إغراق بريده وحظر Firebase المؤقت
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const int _resendCooldown = 60;

  Timer? _poll;
  Timer? _tick;
  int _secondsLeft = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _check(silent: true));
    _startCooldown(); // أول رسالة أُرسلت عند التسجيل
  }

  @override
  void dispose() {
    _poll?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _secondsLeft = _resendCooldown);
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _check({bool silent = false}) async {
    if (_busy) return;
    if (!silent) setState(() => _busy = true);

    final ok = await UserSession.I.checkEmailVerified();
    if (!mounted) return;
    if (!silent) setState(() => _busy = false);

    if (ok) {
      _poll?.cancel();
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, _, _) => RoleHome.screen(),
          transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
        ),
      );
    } else if (!silent) {
      _snack("لم يُفعَّل بعد — افتح الرابط في بريدك ثم أعد المحاولة.", Colors.orange.shade700);
    }
  }

  Future<void> _resend() async {
    if (_secondsLeft > 0 || _busy) return;
    setState(() => _busy = true);
    final error = await UserSession.I.resendVerificationEmail();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      _snack(error, Colors.redAccent);
      return;
    }
    _startCooldown();
    _snack("📨 أُرسلت رسالة جديدة إلى بريدك.", Colors.green.shade600);
  }

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  @override
  Widget build(BuildContext context) {
    final email = UserSession.I.email;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: FadeInSlide(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RobotWidget(size: 96, state: RobotState.point),
                  const SizedBox(height: 16),
                  Text("فعّل بريدك أولاً 📧",
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  const SizedBox(height: 12),
                  Text(
                    "أرسلنا رابط تفعيل إلى:",
                    style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(email,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    "افتح الرابط من بريدك ثم عُد إلى هنا — سنفتح لك التطبيق تلقائياً.\n"
                    "لم تجد الرسالة؟ تحقّق من مجلد الرسائل غير المرغوبة (Spam).",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12.5, height: 1.8, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _busy ? null : () => _check(),
                      child: _busy
                          ? const SizedBox(
                              width: 20, height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                          : const Text("تحققت — افتح لي التطبيق ✅",
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _secondsLeft > 0 ? null : _resend,
                    child: Text(
                      _secondsLeft > 0
                          ? "إعادة الإرسال بعد $_secondsLeft ثانية"
                          : "لم تصلك الرسالة؟ أعد الإرسال",
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _secondsLeft > 0 ? AppColors.textSecondary : AppColors.secondary),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () async {
                      await UserSession.I.signOut();
                      if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: Text("تسجيل الخروج / تغيير البريد",
                        style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
