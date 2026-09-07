import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../../../core/config/curriculum.dart';
import '../../../../core/auth/user_repository.dart';
import '../../../../core/session/role_home.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../../core/widgets/robot_widget.dart';
import '../../../auth/presentation/verify_email_screen.dart';

// ==========================================
// 🔑 التوثيق (تسجيل دخول | حساب جديد) + زائر — محاكاة كاملة
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _login = true; // تبويب
  bool _obscure = true;
  bool _busy = false;
  int _grade = 3;
  Track _track = Track.scientific;

  /// 🎭 **أول سؤال في إنشاء الحساب** (قرار المالك): طالب أم معلّم؟
  ///    عليه تنبني الواجهة كلها بعد الدخول، فيُسأل قبل الاسم لا بعده.
  String _role = AppRole.student;

  bool get _isTeacherSignup => _role == AppRole.teacher;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _busy = true);

    final String? error = _login
        ? await UserSession.I.signIn(email_: _email.text, password: _pass.text)
        : await UserSession.I.signUp(
            name_: _name.text,
            email_: _email.text,
            password: _pass.text,
            grade_: _grade,
            track_: Curriculum.normalizeTrack(_grade, _track).key,
            role_: _role,
          );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) {
      _error(error);
      return;
    }
    // ★ حساب جديد ببريد ⇒ لا دخول قبل التفعيل (الباك اند يرفضه أيضاً).
    if (UserSession.I.needsVerification) {
      _goVerify();
      return;
    }
    _goHome();
  }

  Future<void> _signInWithGoogle() async {
    if (_busy) return;
    setState(() => _busy = true);
    // 🎭 في تبويب «حساب جديد» نمرّر اختياره؛ وفي «تسجيل الدخول» لا نمرّر
    //    شيئاً كي لا نلمس مستنداً قائماً بقيمٍ لم يطلبها.
    final error = await UserSession.I.signInWithGoogle(
      grade_: _login ? null : _grade,
      track_: _login ? null : Curriculum.normalizeTrack(_grade, _track).key,
      role_: _login ? null : _role,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      _error(error);
      return;
    }
    if (!UserSession.I.loggedIn) return; // ألغى نافذة جوجل
    _goHome();
  }

  /// «نسيت كلمة المرور؟» — رابط إعادة تعيين من Firebase.
  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text.trim());
    final send = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("استعادة كلمة المرور", style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("اكتب بريدك وسنرسل لك رابط تعيين كلمة مرور جديدة.",
                style: TextStyle(fontSize: 13, height: 1.6, color: AppColors.textSecondary)),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: InputDecoration(
                hintText: "you@example.com",
                filled: true,
                fillColor: AppColors.softSurface,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("إلغاء", style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("إرسال", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (send != true || !mounted) return;

    final error = await UserSession.I.resetPassword(controller.text);
    if (!mounted) return;
    if (error != null) {
      _error(error);
      return;
    }
    _snack("📨 أرسلنا رابط الاستعادة إلى بريدك.");
  }

  Future<void> _enterAsGuest() async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await UserSession.I.continueAsGuest();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      _error(error);
      return;
    }
    _goHome();
  }

  void _goVerify() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
    );
  }

  void _goHome() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => RoleHome.screen(),
        transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🌗 يُعاد البناء عند تبدّل الوضع — وإلا بقيت الخلفية على لون سابق.
    return ThemeScope(builder: (context) => Scaffold(
      // 🌗 خلفية الصفحة تتبع الوضع — كانت ثابتةً فاتحة، فيصير الوضع
      //    الداكن بطاقاتٍ داكنة تطفو على صفحةٍ بيضاء.
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          Positioned.fill(child: SoftWaveBackground()),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: FadeInSlide(
                child: Column(
                  children: [
                    const SizedBox(height: 6),
                    // روبوت + فقاعة
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        RobotWidget(size: 70, state: RobotState.wave),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.bubbleShadow),
                          child: Text(_login ? "أهلاً بعودتك! 👋" : "سعيد بانضمامك! 🎉", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandInk, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    MasarBrand(logoSize: 88, titleSize: 30),
                    const SizedBox(height: 22),

                    // البطاقة
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(26),
                        border: AppColors.cardBorder,
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Column(
                        children: [
                          // تبويب
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(18)),
                            child: Row(
                              children: [
                                _tab("تسجيل الدخول", _login, () => setState(() => _login = true)),
                                _tab("حساب جديد", !_login, () => setState(() => _login = false)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          if (!_login) ...[
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text("أنشئ حسابك كـ:",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.brandInk,
                                      fontSize: 13)),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _roleCard(
                                    emoji: "🎓",
                                    label: "طالب",
                                    hint: "شرح · اختبارات · تحليل مستوى",
                                    value: AppRole.student),
                                const SizedBox(width: 10),
                                _roleCard(
                                    emoji: "👨‍🏫",
                                    label: "معلّم",
                                    hint: "خطط دروس · واجبات · تبسيط",
                                    value: AppRole.teacher),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // 🔁 يطمئنه أن الاختيار ليس نهائياً — وإلا تردّد
                            //    عند أول سؤال في التطبيق فترك التسجيل.
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                  "يمكنك تغيير نوع الحساب لاحقاً من الإعدادات.",
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textSecondary)),
                            ),
                            const SizedBox(height: 16),
                            _field(_name, "الاسم الكامل", Icons.person_outline_rounded),
                            const SizedBox(height: 14),
                          ],
                          _field(_email, "البريد الإلكتروني", Icons.alternate_email_rounded),
                          const SizedBox(height: 14),
                          _field(_pass, "كلمة المرور", Icons.lock_outline_rounded, obscure: _obscure, suffix: IconButton(
                            splashRadius: 20,
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textSecondary, size: 20),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          )),

                          if (!_login) ...[
                            const SizedBox(height: 16),
                            Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                    // 👨‍🏫 المعلّم يختار الصف أيضاً: أدواته تُبنى من
                                    //    دروس صفٍّ بعينه، فبلا صفٍّ لا دروس تُجلَب.
                                    _isTeacherSignup
                                        ? "الصف الذي تُدرّسه:"
                                        : "اختر صفك الدراسي:",
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.brandInk,
                                        fontSize: 13))),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                _gradeChip("أول ثانوي", 1),
                                const SizedBox(width: 8),
                                _gradeChip("ثاني ثانوي", 2),
                                const SizedBox(width: 8),
                                _gradeChip("ثالث ثانوي", 3),
                              ],
                            ),
                            // المسار: للصفين الثاني والثالث فقط (الأول موحّد)
                            if (Curriculum.hasTracks(_grade)) ...[
                              const SizedBox(height: 14),
                              Align(
                                alignment: Alignment.centerRight,
                                child: Text("المسار:",
                                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.brandInk, fontSize: 13)),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _trackChip("علمي", Track.scientific),
                                  const SizedBox(width: 8),
                                  _trackChip("أدبي", Track.literary),
                                ],
                              ),
                            ],
                          ],

                          if (_login)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(onPressed: _busy ? null : _forgotPassword, child: Text("نسيت كلمة المرور؟", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13))),
                            ),
                          const SizedBox(height: 12),

                          // زر رئيسي
                          InkWell(
                            onTap: _busy ? null : _submit,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: AppColors.primaryButton,
                                borderRadius: BorderRadius.circular(16),
                                // 🌙 الهالة الزرقاء تحت الزرّ توهجٌ على الأسود
                                //    لا عمق — تُخفَّف في الداكن كبقيّة الظلال.
                                boxShadow: [BoxShadow(
                                    color: kBlueBtn.last.withValues(alpha: isDarkModeNotifier.value ? 0.16 : 0.32),
                                    blurRadius: 16, offset: const Offset(0, 8))],
                              ),
                              child: Center(
                                child: _busy
                                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, valueColor: AlwaysStoppedAnimation(Colors.white)))
                                    : Text(_login ? "تسجيل الدخول" : "إنشاء الحساب", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: Divider(color: AppColors.softSurface)),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text("أو", style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                            Expanded(child: Divider(color: AppColors.softSurface)),
                          ]),
                          const SizedBox(height: 16),
                          // 🇬 الدخول بجوجل — الاسم والبريد يأتيان من الحساب
                          InkWell(
                            onTap: _busy ? null : _signInWithGoogle,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.surfaceWhite,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppColors.border, width: 1.2),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const _GoogleGlyph(size: 20),
                                  const SizedBox(width: 10),
                                  Text("المتابعة بحساب جوجل",
                                      style: TextStyle(color: AppColors.brandInk, fontSize: 15, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // زائر
                          InkWell(
                            onTap: _busy ? null : _enterAsGuest,
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              height: 52,
                              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.4)),
                              child: Center(child: Text("جرّب كزائر 👀", style: TextStyle(color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold))),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      // ⚠️ لا `const` هنا: اللون صار getter يتبع الوضع.
                      children: [
                        Icon(Icons.account_balance_rounded, size: 13, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text("Powered by Hadhramout Foundation", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }

  void _snack(String m, {Color? color}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: color ?? AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  void _error(String m) => _snack("⚠️  $m", color: Colors.redAccent.shade400);

  Widget _tab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: active ? AppColors.surfaceWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: active ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)] : [],
          ),
          child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: active ? AppColors.primary : AppColors.textSecondary))),
        ),
      ),
    );
  }

  /// 🎭 بطاقة اختيار الدور — أكبر من الشريحة عمداً: هذا أهم خيارٍ في الشاشة،
  ///    وحجمُه في العين يجب أن يوازي أثرَه في التطبيق.
  Widget _roleCard({
    required String emoji,
    required String label,
    required String hint,
    required String value,
  }) {
    final sel = _role == value;
    return Expanded(
      child: InkWell(
        onTap: _busy ? null : () => setState(() => _role = value),
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
          decoration: BoxDecoration(
            color: sel ? AppColors.primaryFill : AppColors.softSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: sel ? AppColors.primaryFill : Colors.transparent, width: 1.5),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(height: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      color: sel ? Colors.white : AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text(hint,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 10,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.white.withValues(alpha: 0.85)
                          : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _trackChip(String label, Track t) {
    final sel = _track == t;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _track = t),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            // 🎯 تعبئةٌ تحمل نصّاً أبيض ⇒ [secondaryFill] لا [secondary].
            color: sel ? AppColors.secondaryFill : AppColors.softSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.bold,
                    color: sel ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }

  Widget _gradeChip(String label, int g) {
    final sel = _grade == g;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _grade = g),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? AppColors.primaryFill : AppColors.softSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? AppColors.primaryFill : Colors.transparent),
          ),
          child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textSecondary))),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, {bool obscure = false, Widget? suffix}) {
    return TextField(
      controller: c,
      obscureText: obscure,
      // 🔴 **أسوأ ما كان في الوضع الداكن**: نصُّ الحقل بحبرٍ داكن ثابت على
      //    حقلٍ داكن — يكتب الطالب بريده فلا يرى ما يكتب إطلاقاً.
      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.brandInk, fontSize: 14.5),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13.5),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 21),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.softSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    );
  }
}

// ==========================================
// 🇬 شعار جوجل — مرسوم بالكود
// ==========================================
// لا صورة شبكية ولا أصل خارجي: الشاشة تُفتح بلا إنترنت، والحجم صفر بايت.
class _GoogleGlyph extends StatelessWidget {
  final double size;
  const _GoogleGlyph({this.size = 20});

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _GooglePainter()));
}

class _GooglePainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.22;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, w - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // أربع قطاعات بألوان جوجل (من اليمين وعكس عقارب الساعة)
    canvas.drawArc(rect, -0.35, -1.25, false, p..color = _red);      // أعلى
    canvas.drawArc(rect, -1.60, -1.35, false, p..color = _yellow);   // يسار
    canvas.drawArc(rect, -2.95, -1.30, false, p..color = _green);    // أسفل
    canvas.drawArc(rect, 0.62, -0.97, false, p..color = _blue);      // يمين

    // الشرطة الأفقية للحرف G
    final bar = Paint()..color = _blue;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.50, w * 0.42, w * 0.42, stroke * 0.92),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
