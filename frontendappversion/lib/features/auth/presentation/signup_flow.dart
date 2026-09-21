import 'package:flutter/material.dart';

import '../../../core/config/app_constants.dart';
import '../../../core/config/curriculum.dart';
import '../../../core/auth/user_repository.dart';
import '../../../core/session/role_home.dart';
import '../../../core/session/user_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/masar_brand.dart';
import '../../../core/widgets/masar_icons.dart';
import 'verify_email_screen.dart';
import 'widgets/auth_kit.dart';

// ==========================================
// 📝 تدفّق إنشاء الحساب — أربع خطوات
// ==========================================
// 🎨 **تصميم Figma:** «إنشاء حساب جديد» (703:15946) ← «اختيار الدور»
//    (706:16209) ← «اختيار الصف+المسار» (716:16821) ← «تاكيد» (738:17469).
//
// ⭐ **اللوجيك لم يُمسّ.** الحساب يُنشأ بنداءٍ **واحد** في آخر خطوة هو
//    `UserSession.signUp(...)` نفسه الذي كانت تستدعيه الشاشة القديمة
//    بوسائطه نفسها. الخطواتُ تجميعُ بياناتٍ لا غير.
//
// 🇬 **جوجل داخل التدفّق لا قبله:** زرّ جوجل في الخطوة الأولى **يتقدّم**
//    بالخطوات ولا يوثّق فوراً، لأن `signInWithGoogle` يأخذ الصفَّ والمسار
//    والدور — وهي لم تُختَر بعد. توثيقُه يقع في خطوة «تأكيد» كأخيه.
//    وبلا ذلك يُنشأ حسابُ معلّمٍ في صفٍّ لم يخترْه أحد.
class SignUpFlow extends StatefulWidget {
  const SignUpFlow({super.key});

  @override
  State<SignUpFlow> createState() => _SignUpFlowState();
}

/// ما يُجمَع عبر الخطوات — يُسلَّم دفعةً واحدة لـ`signUp`.
class _Draft {
  String name = '';
  String email = '';
  String password = '';
  String role = AppRole.student;
  int grade = 3;
  Track track = Track.scientific;

  /// هل اختار الطالب «المتابعة بحساب جوجل» في الخطوة الأولى؟
  bool viaGoogle = false;
}

class _SignUpFlowState extends State<SignUpFlow> {
  final _pc = PageController();
  final _draft = _Draft();
  int _step = 0;
  bool _busy = false;

  static const _lastStep = 3;

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  void _go(int i) {
    setState(() => _step = i);
    _pc.animateToPage(
      i,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() => _go(_step + 1);

  /// الرجوع من الخطوة الأولى يغادر التدفّق كلَّه إلى شاشة الدخول.
  void _back() => _step == 0 ? Navigator.pop(context) : _go(_step - 1);

  // ══════════════════════════════════════════════════
  // ✅ الخطوة الأخيرة — هنا وحدها يُنشأ الحساب
  // ══════════════════════════════════════════════════
  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);

    final track = Curriculum.normalizeTrack(_draft.grade, _draft.track).key;
    final String? error = _draft.viaGoogle
        ? await UserSession.I.signInWithGoogle(
            grade_: _draft.grade,
            track_: track,
            role_: _draft.role,
          )
        : await UserSession.I.signUp(
            name_: _draft.name,
            email_: _draft.email,
            password: _draft.password,
            grade_: _draft.grade,
            track_: track,
            role_: _draft.role,
          );

    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) return _snack("⚠️  $error", AppColors.error500);
    // ألغى نافذة جوجل — نبقى في مكاننا بلا رسالة خطأ مُربكة.
    if (_draft.viaGoogle && !UserSession.I.loggedIn) return;

    if (UserSession.I.needsVerification) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VerifyEmailScreen()),
      );
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => RoleHome.screen(),
        transitionsBuilder: (_, a, _, c) =>
            FadeTransition(opacity: a, child: c),
      ),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      builder: (context) => PopScope(
        // 🔙 زرّ الرجوع في النظام يتراجع **خطوةً** لا يهدم التدفّق كلّه.
        canPop: _step == 0,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: Scaffold(
          backgroundColor: AppColors.bgLight,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AuthMetrics.gutter,
                16,
                AuthMetrics.gutter,
                20,
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 40,
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: AuthBackButton(onTap: _back),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pc,
                      // 🚫 لا تمرير بالإصبع: كل خطوة لها شرطُ صحّةٍ يجب أن
                      //    يمرّ عبر «متابعة» — والتمرير يتخطّاه.
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        _StepAccount(
                          draft: _draft,
                          onNext: _next,
                          onGoogle: () {
                            _draft.viaGoogle = true;
                            _next();
                          },
                          onSignIn: () => Navigator.pop(context),
                        ),
                        _StepRole(draft: _draft, onNext: _next),
                        _StepGrade(draft: _draft, onNext: _next),
                        _StepConfirm(
                          draft: _draft,
                          busy: _busy,
                          onFinish: _finish,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _dots(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 🆕 مؤشّر الخطوات — غير موجود في التصميم، وأُضيف لأن التدفّق صار أربع
  ///    شاشاتٍ متتابعة: بلا مؤشّر لا يعرف الطالب كم بقي ولا أين هو.
  Widget _dots() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      _lastStep + 1,
      (i) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.symmetric(horizontal: 3),
        width: _step == i ? 22 : 7,
        height: 7,
        decoration: BoxDecoration(
          color: _step == i ? AppColors.primaryFill : AppColors.primaryMuted,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    ),
  );

  void _snack(String m, Color c) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        m,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: c,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ══════════════════════════════════════════════════
// ① بيانات الحساب
// ══════════════════════════════════════════════════
class _StepAccount extends StatefulWidget {
  const _StepAccount({
    required this.draft,
    required this.onNext,
    required this.onGoogle,
    required this.onSignIn,
  });

  final _Draft draft;
  final VoidCallback onNext;
  final VoidCallback onGoogle;
  final VoidCallback onSignIn;

  @override
  State<_StepAccount> createState() => _StepAccountState();
}

class _StepAccountState extends State<_StepAccount> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// ✅ **تحقّقٌ في الواجهة لا في اللوجيك.** خانة «تأكيد كلمة المرور» جديدةٌ
  ///    من التصميم، وفحصُها هنا يمنع خطأً يكتشفه الطالب بعد ثلاث خطوات.
  void _next() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty) return _err("اكتب اسمك الكامل");
    if (!email.contains('@') || !email.contains('.')) {
      return _err("تحقّق من صيغة البريد الإلكتروني");
    }
    if (_pass.text.length < 6) {
      return _err("كلمة المرور ٦ أحرف على الأقل");
    }
    if (_pass.text != _confirm.text) {
      return _err("كلمتا المرور غير متطابقتين");
    }
    widget.draft
      ..name = name
      ..email = email
      ..password = _pass.text
      ..viaGoogle = false;
    widget.onNext();
  }

  void _err(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        "⚠️  $m",
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: AppColors.warning900,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Center(child: MasarRobot(size: 104, pose: MasarRobotPose.fly)),
        const SizedBox(height: 8),
        AuthHeading(
          title: "إنشاء حساب جديد",
          subtitle: "أنشئ حسابك لتبدأ رحلتك التعليمية مع مسار",
          titleSize: 20,
        ),
        const SizedBox(height: 18),
        AuthField(
          label: "الاسم الكامل",
          hint: "أدخل اسمك الكامل",
          controller: _name,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        AuthField(
          label: "البريد الإلكتروني",
          hint: "example@domain.com",
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          ltr: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        AuthField(
          label: "كلمة المرور",
          hint: "••••••••",
          controller: _pass,
          obscure: true,
          ltr: true,
          helper: "٦ أحرف على الأقل، ويُستحسن رمزٌ خاص (@#\$&)",
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: 10),
        AuthField(
          label: "تأكيد كلمة المرور",
          hint: "••••••••",
          controller: _confirm,
          obscure: true,
          ltr: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _next(),
        ),
        const SizedBox(height: 18),
        AuthPrimaryButton(label: "إنشاء حساب", onTap: _next),
        const SizedBox(height: 14),
        AuthOutlineButton(
          label: "المتابعة بحساب جوجل",
          leading: const GoogleGlyph(),
          onTap: widget.onGoogle,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "لديك حساب بالفعل؟ ",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
            AuthLink(label: "تسجيل الدخول", onTap: widget.onSignIn),
          ],
        ),
        const SizedBox(height: 10),
        Center(
          child: Text(
            "v${AppConstants.appVersionName}",
            textDirection: TextDirection.ltr,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.n500,
            ),
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════
// ② اختيار الدور
// ══════════════════════════════════════════════════
class _StepRole extends StatefulWidget {
  const _StepRole({required this.draft, required this.onNext});
  final _Draft draft;
  final VoidCallback onNext;

  @override
  State<_StepRole> createState() => _StepRoleState();
}

class _StepRoleState extends State<_StepRole> {
  // 📐 **مقاسات Figma حرفياً** (اختيار الدور · 706:16209 — إحداثيات مطلقة):
  //    روبوت 80×69 @y128 · عنوان @y201 (h37) · وصف @y246 (h22) ·
  //    «اختر دورك» @y276 (h30) · البطاقات @y344 (158×214، فجوة 14) ·
  //    الزرّ @y765. والفجوةُ الكبيرة بين البطاقات والزرّ **من التصميم**
  //    لا سهوٌ منّا — لذلك `Spacer` بينهما لا حشوةٌ ثابتة.
  static const double _cardW = 158;
  static const double _cardH = 214;
  static const double _cardGap = 14;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 11),
                  const MasarRobot(size: 80, pose: MasarRobotPose.fly),
                  const SizedBox(height: 4),
                  Text("مرحباً بك في مسار",
                      style: TextStyle(
                          fontSize: 20,
                          height: 37 / 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cardInk)),
                  const SizedBox(height: 8),
                  Text("معاً نصنع مستقبلاً أفضل",
                      style: TextStyle(
                          fontSize: 12,
                          height: 22 / 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.sectionLabel)),
                  const SizedBox(height: 8),
                  Text("اختر دورك",
                      style: TextStyle(
                          fontSize: 16,
                          height: 30 / 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.cardInk)),
                  const SizedBox(height: 28),
                  // ⚠️ **عرضٌ ثابت 158 لا `Expanded`**: عرض الشاشة يتغيّر
                  //    بين الأجهزة، وتمديدُ البطاقتين يجعلهما أعرض من
                  //    التصميم على الشاشات الكبيرة فتفقدان نسبتهما.
                  //    وارتفاعٌ ثابت 214 يغني عن `IntrinsicHeight`.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoleCard(
                        width: _cardW,
                        height: _cardH,
                        title: "طالب",
                        hint: "تعلّم، طوّر مهاراتك\nوحقّق أهدافك",
                        glyph: MasarIconPaths.roleStudent,
                        accent: AppColors.primary500,
                        selected: widget.draft.role == AppRole.student,
                        onTap: () =>
                            setState(() => widget.draft.role = AppRole.student),
                      ),
                      const SizedBox(width: _cardGap),
                      _RoleCard(
                        width: _cardW,
                        height: _cardH,
                        title: "معلّم",
                        hint: "أدر دروسك، تابع طلابك\nوشارك معرفتك",
                        glyph: MasarIconPaths.roleTeacher,
                        accent: AppColors.secondary500,
                        selected: widget.draft.role == AppRole.teacher,
                        onTap: () =>
                            setState(() => widget.draft.role = AppRole.teacher),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // 🔁 يطمئنه أن الاختيار ليس نهائياً — كان في الشاشة القديمة
                  //    وأُبقي: بدونه يتردّد عند أول سؤال فيترك التسجيل.
                  Text("يمكنك تغيير نوع الحساب لاحقاً من الإعدادات.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cardHint)),
                ],
              ),
            ),
          ),
          AuthPrimaryButton(label: "متابعة", onTap: widget.onNext),
        ],
      );
}

/// بطاقة الدور — **158×214** · أيقونة 84×84 r18 · نصف قطر 20.
///
/// 📐 توزيعُ ارتفاعها من التصميم: حشوة 18 ← أيقونة 84 ← 11 ← عنوان 30
///    ← 15 ← وصفٌ سطران 38 ← حشوة 18 = **214 بالضبط**.
///
/// 🎨 التعبئة والحدّ مشتقّان من لون الدور:
///    مختارة ⇒ اللون بـ١٠٪ وحدٌّ كامل · خاملة ⇒ ٤٪ وحدٌّ بـ١٣٪.
///    وهذا يُنتج `#E6F4FF` للطالب المختار و`#F6F4FE` للمعلّم الخامل —
///    وهما القيمتان في الملف حرفاً بحرف.
///
/// ⚠️ **نصف القطر وُحِّد على 20**: الملفُ يعطي المعلّم `r24` والطالب `r16`،
///    وهو **سهوُ تصميمٍ لا قرار**: البطاقتان متجاورتان متطابقتا الدور،
///    وتغيُّرُ نصف القطر عند الاختيار يبدو عطلاً لا حركة.
class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.width,
    required this.height,
    required this.title,
    required this.hint,
    required this.glyph,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  final double width, height;
  final String title, hint;

  /// 🎯 متّجهُ الأيقونة من ملف المصمّم — لا `IconData`.
  final List<IconPath> glyph;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = isDarkModeNotifier.value;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: height,
        // 📐 التصميم يعطي حشوةً 18 وفجوةً 15، لكن سطرَي الوصف بخطّ Cairo
        //    يحتاجان 40px لا 38 — فيتجاوز البطاقةَ ببكسلين. خُصم البكسلان
        //    من الحشوة والفجوة، وبقي الارتفاع الكلّي **214 كما في الملف**.
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: accent.withValues(
              alpha: selected ? (dark ? 0.18 : 0.10) : (dark ? 0.07 : 0.04)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : accent.withValues(alpha: 0.13),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(18)),
              // 📐 **الرسم 68 داخل مربّع 84** — كما في الملف حرفياً (٨١٪).
              //    وكان 44 (٥٢٪) فبدا ضائعاً وسط مساحةٍ فارغة.
              child: MasarIcon(glyph, size: 68, color: Colors.white),
            ),
            const SizedBox(height: 11),
            SizedBox(
              height: 30,
              child: Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      height: 30 / 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.cardInk)),
            ),
            const SizedBox(height: 12),
            // ⚠️ `Expanded` لا ارتفاعٌ ثابت: النصّ العربي يتمدّد بالتشكيل
            //    وبإعدادات حجم الخط في النظام، وارتفاعٌ ثابت يعني شريطَ
            //    التجاوز الأصفر على جهاز طالبٍ رفع حجم الخط.
            Expanded(
              child: Align(
                alignment: Alignment.topCenter,
                child: Text(hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11,
                        height: 19 / 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cardHint)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// ③ الصف والمسار
// ══════════════════════════════════════════════════
class _StepGrade extends StatefulWidget {
  const _StepGrade({required this.draft, required this.onNext});
  final _Draft draft;
  final VoidCallback onNext;

  @override
  State<_StepGrade> createState() => _StepGradeState();
}

class _StepGradeState extends State<_StepGrade> {
  // 📐 **مقاسات Figma حرفياً** (اختيار الصف+المسار · 716:16821):
  //    عنوان @y132 (h32) · وصف @y170 (h26) · «الصف الدراسي» @y208 (h22) ·
  //    صفوفٌ 342×84 بفجوة 8 · «المسار» @y520 · بطاقتان 165×112 بفجوة 12 ·
  //    تنبيهٌ 342×70 · زرٌّ @y765.
  static const _grades = [
    (1, "الصف الأول الثانوي", "سنة عامة مشتركة"),
    (2, "الصف الثاني الثانوي", "مرحلة التخصص"),
    (3, "الصف الثالث الثانوي", "الشهادة العامة"),
  ];

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    // 🎓 المسار للصفّين الثاني والثالث فقط — الأول سنةٌ موحّدة. شرطٌ من
    //    `Curriculum` لا من التصميم، والتصميم يعرض المسار دائماً.
    final hasTracks = Curriculum.hasTracks(d.grade);
    final teacher = d.role == AppRole.teacher;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Text(teacher ? "الصف الذي تُدرّسه" : "اختر مرحلتك الدراسية",
                    style: TextStyle(
                        fontSize: 24,
                        height: 32 / 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.slateTitle)),
                const SizedBox(height: 6),
                Text(
                    // 👨‍🏫 المعلّم يختار صفاً أيضاً: أدواته تُبنى من دروس صفٍّ
                    //    بعينه، فبلا صفٍّ لا دروس تُجلَب.
                    teacher
                        ? "تُبنى أدواتك من دروس هذا الصف ومنهجه."
                        : "حدّد الصف والمسار لتخصيص خطتك ونماذج الاختبار.",
                    style: TextStyle(
                        fontSize: 14,
                        height: 26 / 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.cardHint)),
                const SizedBox(height: 12),
                _label("الصف الدراسي"),
                const SizedBox(height: 8),
                for (final g in _grades) ...[
                  _GradeRow(
                    number: g.$1,
                    title: g.$2,
                    hint: g.$3,
                    selected: d.grade == g.$1,
                    onTap: () => setState(() => d.grade = g.$1),
                  ),
                  if (g != _grades.last) const SizedBox(height: 8),
                ],
                if (hasTracks) ...[
                  const SizedBox(height: 12),
                  _label("المسار"),
                  const SizedBox(height: 8),
                  // ⚠️ عرضٌ ثابت 165 لا `Expanded` — كبطاقتي الدور.
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _TrackCard(
                        title: "المسار العلمي",
                        hint: "رياضيات، فيزياء، كيمياء",
                        icon: Icons.science_outlined,
                        selected: d.track == Track.scientific,
                        onTap: () => setState(() => d.track = Track.scientific),
                      ),
                      const SizedBox(width: 12),
                      _TrackCard(
                        title: "المسار الأدبي",
                        hint: "لغة عربية، تاريخ، جغرافيا",
                        icon: Icons.menu_book_outlined,
                        selected: d.track == Track.literary,
                        onTap: () => setState(() => d.track = Track.literary),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                _tip(),
              ],
            ),
          ),
        ),
        AuthPrimaryButton(label: "متابعة", onTap: widget.onNext),
      ],
    );
  }

  Widget _label(String s) => Align(
        alignment: AlignmentDirectional.centerStart,
        child: SizedBox(
          height: 22,
          child: Text(s,
              style: TextStyle(
                  fontSize: 12,
                  height: 22 / 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.sectionLabel)),
        ),
      );

  /// 💡 شريط التنبيه — 342×70، والأيقونة في **نهاية** السطر كما في التصميم.
  Widget _tip() => Container(
        height: 70,
        padding: const EdgeInsets.symmetric(horizontal: 15),
        decoration: BoxDecoration(
          color: AppColors.warningTintSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.warningTintBorder),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                  "سيخصّص مسار محتوى الشرح والاختبارات تلقائياً حسب اختيارك.",
                  style: TextStyle(
                      fontSize: 12,
                      height: 22 / 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning900)),
            ),
            const SizedBox(width: 12),
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.warning500.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.bolt_rounded,
                  size: 17, color: AppColors.warning900),
            ),
          ],
        ),
      );
}

/// صفّ الصف — **342×84** · حشوة جانبية 17 · شارة 32×32 r12 · دائرة 20×20.
class _GradeRow extends StatelessWidget {
  const _GradeRow({
    required this.number,
    required this.title,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final int number;
  final String title, hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 84,
          padding: const EdgeInsets.symmetric(horizontal: 17),
          decoration: BoxDecoration(
            color:
                selected ? AppColors.primaryTintSurface : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.rowBorder,
                width: selected ? 1.5 : 1),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color:
                      selected ? AppColors.primaryFill : AppColors.neutralTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text("$number",
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : AppColors.slateNumber)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 14,
                            height: 26 / 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slateTitle)),
                    Text(hint,
                        style: TextStyle(
                            fontSize: 12,
                            height: 22 / 12,
                            fontWeight: FontWeight.w400,
                            color: selected
                                ? AppColors.primary
                                : AppColors.cardHint)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // ⚪ دائرة الاختيار في **نهاية** السطر (يسار RTL) كما في التصميم.
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.primaryFill : Colors.transparent,
                  border: Border.all(
                      color:
                          selected ? AppColors.primaryFill : AppColors.slate300,
                      width: 1.5),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      );
}

/// بطاقة المسار — **165×112** · أيقونة 36×36 r12.
class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.title,
    required this.hint,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String title, hint;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 165,
          height: 112,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color:
                selected ? AppColors.primaryTintSurface : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.rowBorder,
                width: selected ? 1.5 : 1),
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.14)
                      : AppColors.neutralTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon,
                    size: 20,
                    color:
                        selected ? AppColors.primary : AppColors.slateNumber),
              ),
              const SizedBox(height: 6),
              Text(title,
                  style: TextStyle(
                      fontSize: 14,
                      height: 24 / 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.slateTitle)),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(hint,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          height: 18 / 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.cardHint)),
                ),
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// ④ التأكيد
// ══════════════════════════════════════════════════
class _StepConfirm extends StatelessWidget {
  const _StepConfirm({
    required this.draft,
    required this.busy,
    required this.onFinish,
  });

  final _Draft draft;
  final bool busy;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final gradeLabel = switch (draft.grade) {
      1 => "الصف الأول الثانوي",
      2 => "الصف الثاني الثانوي",
      _ => "الصف الثالث الثانوي",
    };
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 10),
                const MasarRobot(size: 130),
                const SizedBox(height: 16),
                AuthHeading(
                  title: "هل تأكّدت من كل البيانات؟",
                  subtitle: "بعد هذه الخطوة تُعتمد بياناتك رسمياً في حسابك.",
                ),
                const SizedBox(height: 20),
                // 📋 **ملخّص ما اختاره** — غير موجود في التصميم، وأُضيف لأن
                //    شاشة تأكيدٍ لا تعرض ما تؤكّده تطلب موافقةً على المجهول.
                _summary(gradeLabel),
              ],
            ),
          ),
        ),
        AuthPrimaryButton(label: "متابعة", onTap: onFinish, busy: busy),
      ],
    );
  }

  Widget _summary(String gradeLabel) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.softSurface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        if (!draft.viaGoogle) ...[
          _row(Icons.person_outline_rounded, "الاسم", draft.name),
          _row(Icons.alternate_email_rounded, "البريد", draft.email, ltr: true),
        ] else
          _row(Icons.account_circle_outlined, "الحساب", "سيُستكمل بحساب جوجل"),
        _row(
          draft.role == AppRole.teacher
              ? Icons.co_present_rounded
              : Icons.school_rounded,
          "نوع الحساب",
          draft.role == AppRole.teacher ? "معلّم" : "طالب",
        ),
        _row(Icons.menu_book_rounded, "الصف", gradeLabel),
        if (Curriculum.hasTracks(draft.grade))
          _row(
            Icons.alt_route_rounded,
            "المسار",
            draft.track == Track.scientific ? "علمي" : "أدبي",
          ),
      ],
    ),
  );

  Widget _row(IconData icon, String label, String value, {bool ltr = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 17, color: AppColors.primary),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                textDirection: ltr ? TextDirection.ltr : null,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
}
