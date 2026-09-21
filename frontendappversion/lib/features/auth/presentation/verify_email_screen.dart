import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/session/role_home.dart';

import '../../../core/session/user_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/masar_brand.dart';
import 'widgets/auth_kit.dart';

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
//
// 🎨 **تصميم Figma** — «التحقق من البريد الإلكتروني» (716:16784).
//
// 🔴 **ما لم يُنفَّذ من التصميم ولماذا:** صمّم المصمّم **أربع خانات لرمز
//    تحقّق** (`5` `8` `9` `6`). و«مسار» **لا يملك نظام أكواد إطلاقاً** —
//    حُذف بالكامل في 2026-09-08 بقرار المالك لأنه كان ثغرةً حقيقية
//    (مفتاحٌ مدفون في التطبيق يمنح حساباً بلا حصة ولا حظر ولا تحقق بريد).
//    التفعيل اليوم **رابطُ Firebase** يُفتح من البريد، والتطبيق يستطلع
//    الحالة كل أربع ثوانٍ.
//
//    فبناءُ أربع خاناتٍ لا تتحقّق من شيء واجهةٌ ميتة تُوهم الطالبَ برمزٍ
//    لن يصله. أخذنا **هيكل التصميم** (العنوان · الوصف · البريد مع «تعديل»
//    · الزرّ · عدّاد إعادة الإرسال) ووضعنا في موضع الخانات **ما يعمل فعلاً**.
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
    return AuthScaffold(
      showBack: false,
      children: [
        const SizedBox(height: 10),
        const Center(child: MasarRobot(size: 120)),
        const SizedBox(height: 16),
        AuthHeading(
          title: "التحقق من البريد الإلكتروني",
          subtitle: "أرسلنا رابط التفعيل إلى بريدك الإلكتروني",
        ),
        const SizedBox(height: 14),

        // ✉️ البريد + «تعديل البريد» — من التصميم. و«تعديل» هنا يعني
        //    الخروج والتسجيل ببريدٍ آخر، وهو ما كان يفعله الزرّ السفلي.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(email,
                  textDirection: TextDirection.ltr,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.fieldLabel)),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _changeEmail,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 15, color: AppColors.primary),
                  const SizedBox(width: 4),
                  Text("تعديل البريد",
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),

        // 📬 في موضع خانات الرمز: الإرشاد الفعليّ + مؤشّر الاستطلاع الحيّ.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primaryTintSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text("في انتظار تفعيلك… نفتح لك التطبيق تلقائياً",
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                "افتح الرابط من بريدك ثم عُد إلى هنا.\n"
                "لم تجد الرسالة؟ تحقّق من مجلد الرسائل غير المرغوبة (Spam).",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 11.5,
                    height: 1.8,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),

        AuthPrimaryButton(
            label: "تحقّق الآن", onTap: () => _check(), busy: _busy),
        const SizedBox(height: 8),

        Center(
          child: TextButton(
            onPressed: _secondsLeft > 0 ? null : _resend,
            child: Text(
              _secondsLeft > 0
                  ? "إعادة إرسال الرمز خلال ${_fmt(_secondsLeft)}"
                  : "لم تصلك الرسالة؟ أعد الإرسال",
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _secondsLeft > 0
                      ? AppColors.textSecondary
                      : AppColors.primary),
            ),
          ),
        ),
        Center(
          child: TextButton(
            onPressed: _changeEmail,
            child: Text("تسجيل الخروج / تغيير البريد",
                style: TextStyle(
                    fontSize: 12.5, color: AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }

  /// ⏱️ `00:54` كما في التصميم — لا «٥٤ ثانية».
  String _fmt(int s) =>
      "${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}";

  Future<void> _changeEmail() async {
    await UserSession.I.signOut();
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }
}
