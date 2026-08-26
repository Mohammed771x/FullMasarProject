import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../data/demo_state.dart';
import '../widgets/masar_logo.dart';
import '../widgets/robot_widget.dart';
import 'home_screen.dart';

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
  int _grade = 3;
  final _name = TextEditingController();
  final _email = TextEditingController(text: "student@masar.app");
  final _pass = TextEditingController(text: "123456");

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _enter({bool guest = false}) {
    DemoState.I.signIn(
      name_: _name.text,
      email_: guest ? "guest@masar.app" : _email.text,
      grade_: _grade,
      guest: guest,
    );
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 700),
        pageBuilder: (_, _, _) => const FutureHomeScreen(),
        transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7FD),
      body: Stack(
        children: [
          const Positioned.fill(child: SoftWaveBackground()),
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
                        const RobotWidget(size: 70, state: RobotState.wave),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.bubbleShadow),
                          child: Text(_login ? "أهلاً بعودتك! 👋" : "سعيد بانضمامك! 🎉", style: const TextStyle(fontWeight: FontWeight.bold, color: kNavy, fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const MasarLogo(size: 72),
                    const SizedBox(height: 8),
                    const Text("مسار", style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: kNavy)),
                    const Text("سفير الطالب اليمني 🇾🇪", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNavy)),
                    const SizedBox(height: 22),

                    // البطاقة
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceWhite,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.06)),
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
                            Align(alignment: Alignment.centerRight, child: Text("اختر صفك الدراسي:", style: TextStyle(fontWeight: FontWeight.bold, color: kNavy, fontSize: 13))),
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
                          ],

                          if (_login)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(onPressed: () => _snack("📧 تم إرسال رابط الاستعادة (محاكاة)"), child: const Text("نسيت كلمة المرور؟", style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, fontSize: 13))),
                            ),
                          const SizedBox(height: 12),

                          // زر رئيسي
                          InkWell(
                            onTap: () => _enter(),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              height: 54,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(colors: kBlueBtn, begin: Alignment.centerRight, end: Alignment.centerLeft),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: kBlueBtn.last.withValues(alpha: 0.32), blurRadius: 16, offset: const Offset(0, 8))],
                              ),
                              child: Center(child: Text(_login ? "تسجيل الدخول" : "إنشاء الحساب", style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(children: [
                            Expanded(child: Divider(color: AppColors.softSurface)),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text("أو", style: TextStyle(color: AppColors.textSecondary, fontSize: 12))),
                            Expanded(child: Divider(color: AppColors.softSurface)),
                          ]),
                          const SizedBox(height: 16),
                          // زائر
                          InkWell(
                            onTap: () => _enter(guest: true),
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
                      children: const [
                        Icon(Icons.account_balance_rounded, size: 13, color: Color(0xFF9AA6B6)),
                        SizedBox(width: 6),
                        Text("Powered by Hadhramout Foundation", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9AA6B6))),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

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
            color: sel ? AppColors.primary : AppColors.softSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: sel ? AppColors.primary : Colors.transparent),
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
      style: const TextStyle(fontWeight: FontWeight.w600, color: kNavy, fontSize: 14.5),
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
