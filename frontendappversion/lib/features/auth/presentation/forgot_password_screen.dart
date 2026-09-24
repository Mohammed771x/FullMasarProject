import 'package:flutter/material.dart';

import '../../../core/auth/auth_validators.dart';
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

  String? _emailError;
  String? _formError;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════
  // 🛡️ ثغرةُ إحصاء الحسابات — أُغلقت ٢٠٢٦-٠٩-٢٣
  // ══════════════════════════════════════════════════
  /// 🔴 **ما كان يحدث:** `sendPasswordResetEmail` لبريدٍ غير مسجّل ترمي
  ///    `user-not-found`، و`AuthRepository._arabicError` تترجمها «البريد
  ///    أو كلمة المرور غير صحيحة» — فكانت الشاشةُ تعرضها.
  ///
  ///    والنتيجة أن هذه الشاشة **تجيب عن سؤالٍ لا يجوز أن تجيب عنه**:
  ///    «هل لهذا البريد حسابٌ عندكم؟». يكتب المهاجمُ بريداً فإن رأى
  ///    «تفقّد بريدك» عرف أن صاحبَه مستخدمٌ عندنا، وإن رأى الخطأ عرف
  ///    أنه ليس كذلك. فيجمع قائمةَ مستخدمي التطبيق بلا كلمةِ مرورٍ واحدة.
  ///
  /// ✅ **والعلاج المعياريّ:** الردُّ **واحدٌ في الحالتين** — «إن كان لهذا
  ///    البريد حساب، فقد وصلته الرسالة». والبريدُ الحقيقي يصله الرابط،
  ///    وغيرُه لا يصله شيء، ولا فرق في ما تراه الشاشة.
  ///
  /// ⚠️ **وما يُعرض فعلاً من الأخطاء؟** ما لا يخصّ وجودَ الحساب وحده:
  ///    انقطاعُ الشبكة، وصيغةُ البريد، وسقفُ المحاولات. وهذه لا تفشي شيئاً
  ///    — بل إخفاؤها يترك الطالب ينتظر رسالةً لن تُرسَل أصلاً.
  static const Set<String> _revealingErrors = {
    'البريد أو كلمة المرور غير صحيحة.',
    'هذا الحساب موقوف. تواصل معنا.',
  };

  Future<void> _send() async {
    if (_busy) return;
    final emailError = AuthValidators.email(_email.text);
    if (emailError != null) {
      return setState(() {
        _emailError = emailError;
        _formError = null;
      });
    }
    setState(() {
      _busy = true;
      _emailError = null;
      _formError = null;
    });
    final error = await UserSession.I.resetPassword(_email.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null && !_revealingErrors.contains(error)) {
      return setState(() => _formError = error);
    }

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
            // ⚠️ **صيغةُ الشرط مقصودة**: «إن كان لهذا البريد حساب». وهي
            //    التي تجعل الردَّ واحداً للمسجَّل ولغيره — انظر [_send].
            subtitle: _sent
                ? "إن كان لهذا البريد حساب في مسار، فقد أرسلنا إليه رابط تعيين كلمة مرور جديدة.\nتفقّد ${_email.text.trim()} ومجلّد الرسائل غير المرغوبة، ثم عد لتسجيل الدخول."
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
              enabled: !_busy,
              errorText: _emailError,
              onChanged: (_) {
                if (_emailError == null && _formError == null) return;
                setState(() {
                  _emailError = null;
                  _formError = null;
                });
              },
              onSubmitted: (_) => _send(),
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 22),
            if (_formError != null) ...[
              AuthAlert(
                message: _formError!,
                onClose: () => setState(() => _formError = null),
              ),
              const SizedBox(height: 12),
            ],
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

}
