import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/auth/auth_repository.dart';
import '../../../../core/auth/auth_validators.dart';
import '../../../../core/config/app_constants.dart';
import '../../../../core/session/role_home.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/forgot_password_screen.dart';
import '../../../auth/presentation/signup_flow.dart';
import '../../../auth/presentation/verify_email_screen.dart';
import '../../../auth/presentation/widgets/auth_kit.dart';
import 'onboarding_screen.dart';

// ==========================================
// 🔑 تسجيل الدخول
// ==========================================
// 🎨 **تصميم Figma** — «تسجيل دخول» (703:15904)، لوح 390×844.
//
// 📐 **الشاشة مبنيّةٌ على إحداثيات الملف المطلقة** (مقيسةً من التصدير ٢×،
//    والأرقام هنا مطروحةٌ من حافة المنطقة الآمنة 47):
//
//    | العنصر | الملف | هنا |
//    |---|---|---|
//    | زرّ الرجوع | 30 | حشوة `AuthScaffold` العليا |
//    | الروبوت | 129.5 · عرض **132** | `AuthSlack(59.5)` ثم `MasarRobot(132)` |
//    | العنوان (حبر) | 249 | |
//    | الوصف (حبر) | 281.5 | |
//    | عنوان «البريد» (حبر) | 353.5 | `AuthSlack(51)` |
//    | صندوق البريد | **371 → 413** | |
//    | صندوق كلمة المرور | **444 → 486** | |
//    | «نسيت كلمة المرور؟» | 491 | `AuthLink(dense: true)` |
//    | الزرّ الأساسي | **515 → 562** | |
//    | زرّ جوجل | **574 → 613.5** | |
//    | زرّ الزائر | **629.5 → 669** | |
//    | «ليس لديك حساب؟» | 695 | |
//
//    وما زاد من طول الجهاز عن 844 يذهب إلى [AuthSlack] وحدهما.
//    ⚠️ ومقاساتُ الصناديق نفسها كبرت في جولة ٢٠٢٦-٠٩-٢٣ بقرار المالك —
//    انظر [AuthMetrics]، فالجدولُ أعلاه يصف **المواضع** لا الارتفاعات.
//
// 🔄 **أكبر تغيير بنيوي في هذا القسم:** كانت شاشةً واحدة بتبويبين
//    (تسجيل الدخول | حساب جديد) تحمل كل شيء — الاسم والصف والمسار والدور.
//    صارت **شاشتين برابطٍ بينهما**، والتسجيل تدفّقٌ من أربع خطوات
//    ([SignUpFlow]). لا شيء من وظائفها فُقد: كل حقلٍ وكل زرّ انتقل معه.
//
// 📝 **نصوص المصمّم لم تُنقل** (قرار المالك): كتب «تسجيل دخول ولي الأمر»
//    و«أدخل بياناتك لتعالم ابسط و اسهل» — وهو محتوى قالبٍ لتطبيقٍ آخر،
//    ولا وجود لولي أمرٍ في «مسار» أصلاً.
//
// ══════════════════════════════════════════════════
// 🚦 الأخطاء ٢٠٢٦-٠٩-٢٣ — تحت الحقل لا في وسط الشاشة
// ══════════════════════════════════════════════════
// 🔴 **طلبُ المالك:** «ما يعجبني إنه يطلع كلام [في النص]. الحقلُ يحمرّ
//    ويظهر تحته الكلام، نفس التطبيقات الأخرى».
//
// 🛡️ **وقاعدةُ الأمان التي حكمت التنفيذ:** خطأُ الدخول **لا يُنسب إلى
//    حقل**. «هذا البريد غير مسجّل» تحت حقل البريد وحده تحوّل الشاشة إلى
//    **أداةِ إحصاءِ حسابات**: يكتب المهاجمُ بُرُداً بالجملة، فما ردّت عليه
//    الشاشةُ «كلمة المرور خاطئة» فصاحبُه **مسجَّلٌ عندنا** — فتُجمع قائمةُ
//    مستخدمي التطبيق ويوجَّه إليها تصيُّد.
//
//    | الحالة | ما يُعرض | أين |
//    |---|---|---|
//    | صيغةُ بريدٍ خاطئة | «تحقّق من صيغة البريد» | تحت حقل البريد |
//    | كلمةُ مرورٍ فارغة | «اكتب كلمة المرور» | تحت حقل المرور |
//    | **بيانات دخولٍ خاطئة** | «البريد أو كلمة المرور غير صحيحة» | **[AuthAlert] فوق الزرّ** — والحقلان يحمرّان بلا رسالة |
//    | انقطاعُ شبكة · حسابٌ موقوف | رسالةُ الخادم كما هي | [AuthAlert] |
//
//    فالحقلان يحمرّان (كما طلب المالك) ولا يقول أيُّهما الخطأ (كما يوجب
//    الأمان) — والشكلُ والأمانُ لا يتعارضان هنا.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();

  /// 🎯 **لماذا مفاتيح؟** حين تظهر رسالةُ خطأٍ تحت حقلٍ خرج من الشاشة
  ///    (لوحةُ المفاتيح مفتوحة، أو جهازٌ قصير) لا يراها الطالب فيظنّ أن
  ///    ضغطته لم تصل. فأولُ حقلٍ أخطأ **يُساق إلى الرؤية**.
  final _emailKey = GlobalKey();
  final _passKey = GlobalKey();

  bool _busy = false;

  String? _emailError;
  String? _passError;

  /// خطأٌ لا ينتمي إلى حقل — انظر جدول الحالات أعلى الملف.
  String? _formError;

  /// حمرةٌ بلا رسالة: بياناتُ دخولٍ خاطئة، والحقلُ لا يُدان بعينه.
  bool _credentialsWrong = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  // ══════════════════════════════════════════════════
  // 🧹 مسحُ الخطأ عند أول حرف
  // ══════════════════════════════════════════════════
  /// ⚠️ **إبقاءُ الحقل أحمرَ وهو يصحّح عقوبةٌ على التصحيح.** وحمرةُ
  ///    «البيانات خاطئة» تُمسح من الحقلين معاً لأنها كانت عليهما معاً.
  void _clearEmailError(String _) {
    if (_emailError == null && !_credentialsWrong && _formError == null) return;
    setState(() {
      _emailError = null;
      _credentialsWrong = false;
      _formError = null;
    });
  }

  void _clearPassError(String _) {
    if (_passError == null && !_credentialsWrong && _formError == null) return;
    setState(() {
      _passError = null;
      _credentialsWrong = false;
      _formError = null;
    });
  }

  /// يفحص الحقلين محلياً. يعيد `true` حين يصحّ كلاهما.
  ///
  /// ⚠️ **الفحصُ المحلّي ليس أماناً** — هو توفيرُ نداءِ شبكةٍ ورحلةٍ
  ///    ذهاباً وإياباً لخطأٍ مطبعيّ. والرفضُ الحقيقي عند Firebase.
  bool _validate() {
    final emailError = AuthValidators.email(_email.text);
    final passError = _pass.text.isEmpty ? 'اكتب كلمة المرور' : null;

    setState(() {
      _emailError = emailError;
      _passError = passError;
      _formError = null;
      _credentialsWrong = false;
    });

    final firstBad = emailError != null ? _emailKey : (passError != null ? _passKey : null);
    if (firstBad == null) return true;
    _reveal(firstBad);
    return false;
  }

  /// يسوق حقلاً إلى داخل الشاشة — بعد الإطار كي يكون قد بُني برسالته.
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

  Future<void> _submit() async {
    if (_busy) return;
    if (!_validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    final error = await UserSession.I.signIn(
        email_: _email.text, password: _pass.text);
    if (!mounted) return;
    setState(() => _busy = false);

    if (error != null) return _showError(error);

    // 💾 **هنا يُسأل مديرُ كلمات المرور «أأحفظها؟»** — بعد نجاحٍ مؤكَّد
    //    لا قبله. ونداؤه على بياناتٍ خاطئة يحفظ كلمةً لا تعمل.
    TextInput.finishAutofillContext();

    // ★ حسابٌ ببريدٍ غير مفعّل ⇒ لا دخول (الباك اند يرفضه أيضاً).
    if (UserSession.I.needsVerification) return _goVerify();
    _goHome();
  }

  // ══════════════════════════════════════════════════
  // 📍 توجيهُ رسالة الخادم إلى موضعها
  // ══════════════════════════════════════════════════
  /// رسائلُ `AuthRepository` عربيةٌ جاهزة، وما يلزم هنا هو **أين تُعرض**.
  ///
  /// 🛡️ و«البريد أو كلمة المرور غير صحيحة» هي الرسالةُ الموحَّدة لثلاثة
  ///    أكواد (`user-not-found` · `wrong-password` · `invalid-credential`)
  ///    — وتوحيدُها هناك هو ما يمنع الإحصاء، وعدمُ نسبِها هنا يُتمّه.
  void _showError(String message) {
    // ⚠️ **مقارنةٌ بالثابت لا بمقطعٍ نصّي**: `contains('البريد')` تلتقط
    //    «صيغة البريد» و«هذا البريد مسجّل» معها، فتُخفي رسائلَ تخصّ حقلاً.
    final isCredentials = message == AuthRepository.genericCredentialError;
    final isFormat = message.contains('صيغة البريد');

    setState(() {
      _credentialsWrong = isCredentials;
      _emailError = isFormat ? message : null;
      _passError = null;
      _formError = isFormat ? null : message;
    });
    if (isFormat) _reveal(_emailKey);
  }

  /// 🇬 الدخول بجوجل من شاشة **الدخول**: بلا صفٍّ ولا دورٍ ولا مسار —
  ///    الحساب قائمٌ ولا يجوز أن نكتب فوق بياناته قيَماً لم يطلبها.
  Future<void> _google() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _formError = null;
    });
    final result = await UserSession.I.signInWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.error != null) return _showError(result.error!);
    // ☢️ **الدخولُ بإثباتٍ لا بغياب الخطأ.** كان هنا «لا خطأ ⇒ ادخل»
    //    و`loggedIn` حارساً للإلغاء — والزائرُ `loggedIn` أصلاً، فكان
    //    «Cancel» يُدخله باسم «طالب مسار» ([GoogleAuthResult]).
    if (!result.signedIn) return; // ألغى نافذة جوجل — نبقى بلا أثر
    _goHome();
  }

  Future<void> _guest() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _formError = null;
    });
    final error = await UserSession.I.continueAsGuest();
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) return _showError(error);
    _goHome();
  }

  /// ↩️ العودة إلى شاشة الترحيب — انظر تعليق `showBack` في [build].
  void _goOnboarding() => Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, _, _) => const OnboardingScreen(),
          transitionsBuilder: (_, a, _, c) =>
              FadeTransition(opacity: a, child: c),
        ),
      );

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
    // 🔐 **مجموعةُ التعبئة التلقائية.** بلا [AutofillGroup] تبقى
    //    `autofillHints` تلميحاً للوحة المفاتيح ولا يُعرض على المستخدم
    //    **حفظُ** كلمته في مدير كلمات المرور — وحفظُها هو المكسب: من
    //    يحفظها يختار كلمةً قوية لأنه لن يكتبها مرّةً أخرى.
    return AutofillGroup(
      child: AuthScaffold(
      // 🔙 **زرُّ الرجوع إلى الترحيب** — أُعيد ٢٠٢٦-٠٩-٢٣ بطلب المالك:
      //    «الزرّ حقّ الرجوع لما بترجع للقائمة الافتتاحية مش موجود».
      //
      // ⚠️ **ولا يصلح `Navigator.pop` هنا:** شاشةُ الترحيب تدخل إلى هذه
      //    بـ`pushReplacement` — فلا شيءَ تحتها في المكدّس، و`pop` تخرج
      //    من التطبيق أو لا تفعل شيئاً. فالزرُّ **يُعيد بناء** شاشة
      //    الترحيب باستبدالٍ مقابل، فتُقرأ رجوعاً وهي بناءٌ جديد.
      //
      // 📝 و`markOnboardingDone` لا تُنقض: الترحيبُ يُفتح يدوياً، وفتحُه
      //    لا يعني أن الطالب لم يره — فلا يُعاد عرضُه في الإقلاع التالي.
      showBack: true,
      onBack: _goOnboarding,
      children: [
        // 🔴 **الفجوتان صغُرتا ٢٠٢٦-٠٩-٢٣ (59.5→20 · 51→22).**
        //    كانتا مقاسَ الملف، وهو مقاسُ شاشةٍ حقولُها 42. وبعد تكبير
        //    الحقول والأزرار صار المحتوى **٧٦١ نقطة** في فراغٍ طولُه 695
        //    على iPhone 17 — فظهر في المحاكي سطرُ «ليس لديك حساب؟»
        //    **مقطوعاً** وسطرُ المؤسسة خارج الشاشة.
        //
        // ⚖️ **ولا شيء ضاع:** [AuthSlack] حدٌّ **أدنى** لا مقاسٌ ثابت —
        //    فعلى الأجهزة الأطول يتمدّد الفائضُ فيهما كما كان تماماً،
        //    وعلى القصيرة تنكمشان بدل أن يُقطع آخرُ الشاشة.
        const AuthSlack(20),
        const AuthRobot(132),
        const SizedBox(height: 4),
        AuthHeading(
          title: "تسجيل الدخول",
          subtitle: "أدخل بياناتك لتتابع رحلتك من حيث توقفت",
        ),
        const AuthSlack(22),
        AuthField(
          key: _emailKey,
          label: "البريد الإلكتروني",
          hint: "example@domain.com",
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          ltr: true,
          textInputAction: TextInputAction.next,
          enabled: !_busy,
          errorText: _emailError,
          invalid: _credentialsWrong,
          onChanged: _clearEmailError,
          // 🔐 يفتح مديرَ كلمات المرور على النظامين — انظر [AuthField].
          autofillHints: const [AutofillHints.username, AutofillHints.email],
        ),
        const SizedBox(height: AuthMetrics.fieldGap),
        AuthField(
          key: _passKey,
          label: "كلمة المرور",
          hint: "••••••••",
          controller: _pass,
          obscure: true,
          ltr: true,
          textInputAction: TextInputAction.done,
          enabled: !_busy,
          errorText: _passError,
          invalid: _credentialsWrong,
          onChanged: _clearPassError,
          onSubmitted: (_) => _submit(),
          autofillHints: const [AutofillHints.password],
        ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AuthLink(
            label: "نسيت كلمة المرور؟",
            fontSize: 13,
            dense: true,
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
        // 📣 الخطأُ غيرُ المنسوب — فوق الزرّ حيث تقع العينُ بعد الضغط.
        if (_formError != null) ...[
          AuthAlert(
            message: _formError!,
            onClose: () => setState(() {
              _formError = null;
              _credentialsWrong = false;
            }),
          ),
          const SizedBox(height: 12),
        ],
        AuthPrimaryButton(
            label: "تسجيل الدخول", onTap: _submit, busy: _busy),
        const SizedBox(height: 12),
        AuthOutlineButton(
          label: "المتابعة بحساب جوجل",
          leading: const GoogleGlyph(),
          onTap: _busy ? null : _google,
        ),
        const SizedBox(height: 12),
        AuthOutlineButton(
          label: "جرّب كزائر",
          leading: const Text("👀", style: TextStyle(fontSize: 15)),
          onTap: _busy ? null : _guest,
        ),
        const SizedBox(height: 6),
        _signUpLink(),
        _appInfo(),
      ],
      ),
    );
  }

  /// 📐 17/w700 في الملف — حبرُ السطر `#4B5563` والرابطُ `#0092FF`.
  ///
  /// 📏 **محاذاةٌ بخطّ الكتابة** — نفسُ علاج «لديك حساب بالفعل؟» في
  ///    [SignUpFlow]: السؤالُ والرابطُ صندوقان بحشوتين مختلفتين، فالتوسيطُ
  ///    يضع حبرَيهما على ارتفاعين. الخطُّ يقرأ الحبرَ لا الصندوق.
  Widget _signUpLink() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text("ليس لديك حساب؟ ",
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.65,
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
}
