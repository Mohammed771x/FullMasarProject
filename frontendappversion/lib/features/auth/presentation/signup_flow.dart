import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/auth_validators.dart';
import '../../../core/auth/password_strength.dart';
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

  /// 📨 خطأٌ يخصّ **حقل البريد** جاء من الخادم في الخطوة الأخيرة.
  ///    يُمرَّر إلى [_StepAccount] ويرجع التدفّقُ إليها — انظر [_finish].
  String? _serverEmailError;

  /// 📣 خطأٌ لا حقلَ له (شبكة · إعدادُ جوجل · رفضٌ عامّ) — يُعرض في
  ///    شاشة «تأكيد» فوق الزرّ الذي ضُغط للتوّ.
  String? _formError;

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
    // ☢️ **جوجل يرجع نتيجةً بثلاث حالات** ([GoogleAuthResult]) — والإلغاءُ
    //    منها يُسقَط هنا صامتاً قبل أن يمسّ شيئاً. كان يُحرَس بـ`loggedIn`
    //    تحت، والزائرُ الذي يسجّل من «سجّل الآن» `loggedIn` أصلاً.
    final GoogleAuthResult? google = _draft.viaGoogle
        ? await UserSession.I.signInWithGoogle(
            grade_: _draft.grade,
            track_: track,
            role_: _draft.role,
          )
        : null;
    if (google != null && google.cancelled) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    final String? error = google != null
        ? google.error
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

    if (error != null) return _routeError(error);
    // 🔒 حارسٌ ثانٍ لا يعتمد على الأول: جوجل بلا دخولٍ مُثبَت لا يمضي.
    if (google != null && !google.signedIn) return;

    // 💾 نجاحٌ مؤكَّد ⇒ يُسأل مديرُ كلمات المرور أن يحفظها.
    TextInput.finishAutofillContext();

    // 🧹 **وتُمحى كلمةُ المرور من الذاكرة.** كانت تبقى في `_Draft` حيّةً
    //    ما بقيت الشاشة — نصّاً صريحاً في كومة التطبيق. ولا حاجة إليها
    //    بعد النداء، وما لا يُحتاج لا يُحتفظ به.
    _draft.password = '';

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

  // ══════════════════════════════════════════════════
  // 📍 خطأُ الخطوة الأخيرة — يُعاد إلى الحقل الذي يخصّه
  // ══════════════════════════════════════════════════
  /// 🔴 **العطل الذي يعالجه:** «هذا البريد مسجّل مسبقاً» لا تُعرف إلا عند
  ///    `createUser` — أي في الخطوة **الرابعة**. وكانت تخرج `SnackBar`
  ///    في شاشة «تأكيد»: رسالةٌ عن حقلٍ لا وجود له في الشاشة، والطالبُ
  ///    لا يعرف أنه يستطيع الرجوع ثلاثَ خطواتٍ ليصحّحه.
  ///
  /// فما يخصّ البريد **يُعيد التدفّق إلى الخطوة الأولى** وقد احمرّ حقلُه
  /// وتحته سببُه. وما لا يخصّ حقلاً يبقى شريطاً في مكانه.
  void _routeError(String message) {
    final aboutEmail = message.contains('البريد') &&
        (message.contains('مسجّل') || message.contains('صيغة'));
    if (aboutEmail) {
      setState(() {
        _serverEmailError = message;
        _formError = null;
      });
      _go(0);
      return;
    }
    setState(() => _formError = message);
  }

  // ══════════════════════════════════════════════════
  // 👀 جرّب كزائر — الزرّ الثالث في الملف
  // ══════════════════════════════════════════════════
  /// 🎨 التصميم يرسم في «إنشاء حساب جديد» ثلاثة أزرار كما في «تسجيل دخول»:
  ///    الأساسي ثم جوجل ثم **«جرب كزائر»**. وكان الزرّ الثالث ساقطاً من
  ///    هذه الخطوة وحدها.
  ///
  /// 🔒 ولا لوجيك جديد: هو `continueAsGuest` نفسُه الذي يستدعيه زرُّ الزائر
  ///    في شاشة الدخول، بالانتقال نفسِه.
  Future<void> _guest() async {
    if (_busy) return;
    setState(() => _busy = true);
    final error = await UserSession.I.continueAsGuest();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) return _routeError(error);
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
                AuthMetrics.topGap,
                AuthMetrics.gutter,
                AuthMetrics.bottomGap,
              ),
              child: Column(
                children: [
                  // 📐 صفُّ الرجوع في الملف **فارغٌ إلا من الزرّ** — فوُضع
                  //    فيه مؤشّرُ الخطوات (وهو إضافتُنا) بدل أن يأخذ سطراً
                  //    أسفل الشاشة. الفرق 27 نقطة كانت تقطع آخر سطرٍ في
                  //    خطوة «إنشاء حساب» على الأجهزة الطويلة.
                  SizedBox(
                    height: AuthMetrics.backSize,
                    child: Stack(
                      children: [
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AuthBackButton(onTap: _back),
                        ),
                        Align(alignment: Alignment.center, child: _dots()),
                      ],
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
                          onGuest: _guest,
                          onSignIn: () => Navigator.pop(context),
                          serverEmailError: _serverEmailError,
                          onEmailTouched: () {
                            if (_serverEmailError == null) return;
                            setState(() => _serverEmailError = null);
                          },
                        ),
                        _StepRole(draft: _draft, onNext: _next),
                        _StepGrade(draft: _draft, onNext: _next),
                        _StepConfirm(
                          draft: _draft,
                          busy: _busy,
                          onFinish: _finish,
                          error: _formError,
                          onDismissError: () =>
                              setState(() => _formError = null),
                        ),
                      ],
                    ),
                  ),
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
    mainAxisSize: MainAxisSize.min,
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

}

// ══════════════════════════════════════════════════
// ① بيانات الحساب
// ══════════════════════════════════════════════════
// 🚦 **الأخطاء تحت حقولها — ٢٠٢٦-٠٩-٢٣.** كانت الأربعةُ كلُّها تخرج
//    `SnackBar` واحداً في وسط الشاشة: «كلمتا المرور غير متطابقتين» في
//    شاشةٍ فيها **حقلا مرورٍ** لا تقول أيَّهما يصحّح. فصار كلُّ حقلٍ يحمل
//    خطأه، ويُمسح الخطأ عند أول حرفٍ يكتبه الطالب.
//
// 🔋 **وشريطُ القوّة** تحت حقل كلمة المرور — طلبُ المالك: «لما يكتب، تقعة
//    برتقالية، بعدها تقعة خضراء». والسياسةُ كلُّها في [PasswordStrength].
class _StepAccount extends StatefulWidget {
  const _StepAccount({
    required this.draft,
    required this.onNext,
    required this.onGoogle,
    required this.onGuest,
    required this.onSignIn,
    this.serverEmailError,
    this.onEmailTouched,
  });

  final _Draft draft;
  final VoidCallback onNext;
  final VoidCallback onGoogle;
  final VoidCallback onGuest;
  final VoidCallback onSignIn;

  /// 📨 خطأٌ جاء من الخادم في **الخطوة الأخيرة** ويخصّ هذا الحقل.
  ///
  /// 🔴 «هذا البريد مسجّل مسبقاً» لا يُعرف إلا عند `createUser` — أي بعد
  ///    ثلاث خطوات. وعرضُه هناك يترك الطالب أمام رسالةٍ لا حقلَ لها،
  ///    فيرجع التدفّقُ به إلى هنا **وقد احمرّ الحقلُ الصحيح**.
  final String? serverEmailError;

  /// يُنادى حين يعدّل الطالبُ البريد — ليمسح [serverEmailError] من الأب.
  final VoidCallback? onEmailTouched;

  @override
  State<_StepAccount> createState() => _StepAccountState();
}

class _StepAccountState extends State<_StepAccount> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  final _nameKey = GlobalKey();
  final _emailKey = GlobalKey();
  final _passKey = GlobalKey();
  final _confirmKey = GlobalKey();

  String? _nameError;
  String? _emailError;
  String? _passError;
  String? _confirmError;

  /// 📊 يُحسب مع كل حرف — والشريطُ يعرضه، والفحصُ يقرأ [PasswordStrength.blocker].
  PasswordStrength _strength = PasswordStrength.of('');

  @override
  void initState() {
    super.initState();
    // 🔁 استعادةُ ما كُتب حين يرجع الطالبُ من خطوةٍ تالية — `PageView`
    //    تُبقي الحالة، لكنّ `_draft` هي مصدرُ الحقيقة بعد «متابعة».
    _name.text = widget.draft.name;
    _email.text = widget.draft.email;
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
    super.dispose();
  }

  /// خطأُ البريد المعروض: المحلّيُّ أولاً ثم ما جاء من الخادم.
  String? get _emailShown => _emailError ?? widget.serverEmailError;

  // ══════════════════════════════════════════════════
  // ✅ الفحص — كلُّ حقلٍ يحمل خطأه
  // ══════════════════════════════════════════════════
  /// ⚠️ **يُفحص الأربعةُ معاً لا حتى أوّل خطأ:** إظهارُ خطأٍ واحدٍ في كل
  ///    ضغطةٍ يجعل الطالب يضغط «إنشاء حساب» أربع مرّات. والشاشةُ تقول كلَّ
  ///    ما فيها مرّةً واحدة، وتُساق الرؤيةُ إلى **أوّلها** لا غير.
  void _next() {
    final nameError = AuthValidators.name(_name.text);
    final emailError = AuthValidators.email(_email.text);
    final strength = PasswordStrength.of(_pass.text,
        email: _email.text, name: _name.text);
    final confirmError = AuthValidators.confirm(_pass.text, _confirm.text);

    setState(() {
      _nameError = nameError;
      _emailError = emailError;
      _strength = strength;
      _passError = strength.blocker;
      // ⚠️ «غير متطابقتين» لا تُعرض وكلمةُ المرور نفسُها مرفوضة: خطآن
      //    تحت حقلين متجاورين يُقرآن مشكلةً واحدةً مضاعَفة.
      _confirmError = strength.blocker == null ? confirmError : null;
    });

    final firstBad = nameError != null
        ? _nameKey
        : emailError != null
            ? _emailKey
            : strength.blocker != null
                ? _passKey
                : confirmError != null
                    ? _confirmKey
                    : null;
    if (firstBad != null) return _reveal(firstBad);

    widget.draft
      ..name = _name.text.trim()
      ..email = _email.text.trim()
      ..password = _pass.text
      ..viaGoogle = false;
    FocusScope.of(context).unfocus();
    widget.onNext();
  }

  void _reveal(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(ctx,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          alignment: 0.2);
    });
  }

  /// ✅ علامةُ الصحّة — لا تظهر على حقلٍ فارغ ولا على حقلٍ لم يُكتب فيه.
  bool _ok(TextEditingController c, String? Function(String) check) =>
      c.text.isNotEmpty && check(c.text) == null;

  // 📐 **إحداثيات الملف** («إنشاء حساب جديد» · 703:15946)، مطروحةً من
  //    حافة المنطقة الآمنة 47:
  //
  //    | العنصر | الملف |
  //    |---|---|
  //    | الروبوت | 88 · عرض **110** (أصغر من شاشة الدخول) |
  //    | العنوان (حبر) | 193 |
  //    | صندوق الاسم | **286 → 328** |
  //    | صندوق البريد | **362 → 404** |
  //    | صندوق كلمة المرور | **435 → 476** |
  //    | سطر الشرط (أزرق) | 482 |
  //    | صندوق التأكيد | **529 → 569.5** |
  //    | الزرّ الأساسي | **578 → 625** |
  //    | زرّ جوجل | **633 → 672** |
  //    | زرّ الزائر | **680.5 → 719.5** |
  //    | «لديك حساب بالفعل؟» | 740 |
  //
  // ⚠️ والارتفاعاتُ كبرت ٢٠٢٦-٠٩-٢٣ — انظر [AuthMetrics]. فهذه الشاشة
  //    **تمرّر** على الأجهزة القصيرة، وهو مقصود: أربعةُ حقولٍ وثلاثةُ
  //    أزرارٍ بمقاسٍ يُلمس لا تسع شاشةَ 844 إلا بتصغيرها دون حدّ اللمس.
  @override
  Widget build(BuildContext context) => AutofillGroup(
        child: AuthBody(
          children: [
            const SizedBox(height: 14),
            const AuthRobot(110),
            const SizedBox(height: 10),
            AuthHeading(
              title: "إنشاء حساب جديد",
              subtitle: "أنشئ حسابك لتبدأ رحلتك التعليمية مع مسار",
            ),
            const AuthSlack(16),
            AuthField(
              key: _nameKey,
              label: "الاسم الكامل",
              hint: "أدخل اسمك الكامل",
              controller: _name,
              textInputAction: TextInputAction.next,
              errorText: _nameError,
              ok: _ok(_name, AuthValidators.name),
              onChanged: (_) => setState(() => _nameError = null),
              autofillHints: const [AutofillHints.name],
            ),
            const SizedBox(height: AuthMetrics.fieldGap),
            AuthField(
              key: _emailKey,
              label: "البريد الإلكتروني",
              hint: "example@domain.com",
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              ltr: true,
              textInputAction: TextInputAction.next,
              errorText: _emailShown,
              ok: _emailShown == null && _ok(_email, AuthValidators.email),
              onChanged: (_) {
                widget.onEmailTouched?.call();
                setState(() => _emailError = null);
              },
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: AuthMetrics.fieldGap),
            AuthField(
              key: _passKey,
              label: "كلمة المرور",
              hint: "••••••••",
              controller: _pass,
              obscure: true,
              ltr: true,
              helper: "${PasswordStrength.minLengthLabel} أحرف على الأقل — "
                  "امزج حروفاً وأرقاماً",
              textInputAction: TextInputAction.next,
              errorText: _passError,
              strength: _strength,
              onChanged: (v) => setState(() {
                _passError = null;
                _strength = PasswordStrength.of(v,
                    email: _email.text, name: _name.text);
                // 🔁 تغييرُ كلمة المرور يُبطل تطابقَ التأكيد المعروض.
                if (_confirmError != null) _confirmError = null;
              }),
              // 🔐 `newPassword` لا `password`: بها يعرض مديرُ الكلمات
              //    **توليدَ كلمةٍ قوية** بدل اقتراح كلمةٍ محفوظة.
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: AuthMetrics.fieldGap),
            AuthField(
              key: _confirmKey,
              label: "تأكيد كلمة المرور",
              hint: "••••••••",
              controller: _confirm,
              obscure: true,
              ltr: true,
              textInputAction: TextInputAction.done,
              errorText: _confirmError,
              ok: _confirm.text.isNotEmpty && _confirm.text == _pass.text,
              onChanged: (_) => setState(() => _confirmError = null),
              onSubmitted: (_) => _next(),
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 18),
            AuthPrimaryButton(label: "إنشاء حساب", onTap: _next),
            const SizedBox(height: 12),
            AuthOutlineButton(
              label: "المتابعة بحساب جوجل",
              leading: const GoogleGlyph(),
              onTap: widget.onGoogle,
            ),
            const SizedBox(height: 12),
            // 👀 الزرّ الثالث كما في الملف — انظر `_SignUpFlowState._guest`.
            AuthOutlineButton(
              label: "جرّب كزائر",
              leading: const Text("👀", style: TextStyle(fontSize: 15)),
              onTap: widget.onGuest,
            ),
            const SizedBox(height: 8),
            // 📏 **على خطّ الكتابة لا على المركز** (ملاحظة المالك ٢٠٢٦-٠٩-٢٣:
            //    «تسجيل الدخول مرفوعة لفوق شوي»). الرابطُ المضغوط حشوتُه
            //    6 فوق و16 تحت، فتوسيطُ الصندوقين يرفع حبرَه خمسَ نقاط عن
            //    السؤال بجانبه. والمحاذاةُ بالخطّ تقرأ موضعَ الحبر نفسِه،
            //    فلا تتأثّر بأيّ حشوةٍ تُعطى للرابط يوماً.
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  "لديك حساب بالفعل؟ ",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    height: 1.65,
                    color: AppColors.textSecondary,
                  ),
                ),
                // 🔴 `dense` هنا لا في شاشة الدخول: هذه الشاشة أربعةُ حقولٍ
                //    وثلاثةُ أزرار، وحشوةُ الرابط 12+12 كانت تقطع سطر الإصدار.
                AuthLink(
                    label: "تسجيل الدخول", dense: true, onTap: widget.onSignIn),
              ],
            ),
            Center(
              child: Text(
                "v${AppConstants.appVersionName}",
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.65,
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
    this.error,
    this.onDismissError,
  });

  final _Draft draft;
  final bool busy;
  final VoidCallback onFinish;

  /// 📣 خطأُ النداء الأخير — يُعرض **فوق الزرّ** لا في وسط الشاشة.
  final String? error;
  final VoidCallback? onDismissError;

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
        if (error != null) ...[
          AuthAlert(message: error!, onClose: onDismissError),
          const SizedBox(height: 12),
        ],
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
