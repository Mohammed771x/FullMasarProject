import 'package:flutter/material.dart';

import '../../../core/session/user_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/masar_brand.dart';
import 'widgets/auth_kit.dart';

// ==========================================
// 🔑 نسيت كلمة المرور؟
// ==========================================
// 🎨 **تصميم Figma** — «نسيت كلمة المرور؟» (713:16540): خلفية `#F2F8F0` ·
//    روبوت 137 · عنوان 24/w600 · وصف 14/w400 · حقل بريد · زرّ «ارسال».
//
// 🔄 **كانت حواراً (`AlertDialog`) داخل شاشة الدخول** فصارت شاشةً كاملة
//    كما صمّمها المصمّم. الوظيفة نفسها حرفياً: `UserSession.resetPassword`
//    ترسل رابط Firebase.
//
// ⛔ **ولا شاشة «تغيير كلمة المرور»**: صمّمها المصمّم بحقلَي كلمة مرور
//    جديدة وتأكيدها — والتطبيق **لا يملك هذا المسار**. تغييرُ كلمة المرور
//    يتم برابطٍ من Firebase يُفتح في المتصفّح، وبناءُ حقلين لا يكتبان شيئاً
//    شاشةٌ ميتة تكذب على الطالب.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail});

  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email =
      TextEditingController(text: widget.initialEmail?.trim() ?? '');
  bool _busy = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy) return;
    final email = _email.text.trim();
    if (!email.contains('@') || !email.contains('.')) {
      return _snack("⚠️  تحقّق من صيغة البريد الإلكتروني", AppColors.warning900);
    }
    setState(() => _busy = true);
    final error = await UserSession.I.resetPassword(email);
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) return _snack("⚠️  $error", AppColors.error500);

    // ✅ **الحالة الناجحة تبقى على الشاشة** لا تُغلقها: الطالب يحتاج أن يعرف
    //    أين يبحث عن الرسالة، وإغلاقُ الشاشة فوراً يترك رسالةً عابرة وحدها.
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        background: AppColors.recoveryBg,
        children: [
          const SizedBox(height: 8),
          const Center(child: MasarRobot(size: 137)),
          const SizedBox(height: 16),
          AuthHeading(
            title: _sent ? "تفقّد بريدك 📨" : "نسيت كلمة المرور؟",
            subtitle: _sent
                ? "أرسلنا رابط تعيين كلمة مرور جديدة إلى ${_email.text.trim()}.\nافتح الرابط ثم عد لتسجيل الدخول."
                : "أدخل بريد حسابك وسنرسل لك رابط تعيين كلمة مرور جديدة.",
          ),
          const SizedBox(height: 22),
          if (!_sent) ...[
            AuthField(
              label: "البريد الإلكتروني",
              hint: "example@domain.com",
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              ltr: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _send(),
            ),
            const SizedBox(height: 22),
            AuthPrimaryButton(label: "إرسال", onTap: _send, busy: _busy),
          ] else ...[
            AuthPrimaryButton(
                label: "العودة لتسجيل الدخول",
                onTap: () => Navigator.pop(context)),
            const SizedBox(height: 12),
            // 🔁 لم تصل؟ يعود للحالة الأولى ليصحّح بريده أو يعيد الإرسال.
            Center(
              child: TextButton(
                onPressed: () => setState(() => _sent = false),
                child: Text("لم تصلك الرسالة؟ أعد الإرسال",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ),
            ),
          ],
        ],
      );

  void _snack(String m, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: c,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}
