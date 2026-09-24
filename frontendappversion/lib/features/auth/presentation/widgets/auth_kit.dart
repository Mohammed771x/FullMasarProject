import 'package:flutter/material.dart';

import '../../../../core/auth/password_strength.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../../core/widgets/phosphor.dart';

// ==========================================
// 🧰 مفردات شاشات التوثيق — مقاسات Figma حرفياً
// ==========================================
// 🎨 **المصدر:** قسم «واجهات الدخول» (٩ شاشات) على لوحٍ **390×844**.
//
// 📐 **كيف قيست؟** لا بالنظر. كلُّ رقمٍ هنا مأخوذٌ من تصدير الملف بدقّة ٢×
//    (780×1688) بمسحٍ آليّ: يُلتقط صفُّ البكسل الذي يبدأ عنده كلُّ صندوق
//    وينتهي، فيَنتج موضعُه وارتفاعُه **بالنقطة**. ثم تُقاس اللقطةُ من
//    المحاكي بالطريقة نفسها وتُطرح — فالفرقُ رقمٌ لا انطباع.
//
// 🔴 **ما صُحّح في جولة ٢٠٢٦-٠٩-٢٢** (بعد ملاحظة المالك «ما هو تمام أبداً…
//    كلها مكدّسة في النص»): كانت الشاشة تبدأ من أعلى وتنتهي عند ثلثي
//    الطول، فيبقى تحتها فراغٌ ميّت. والسببُ أن الفجوات كلَّها كانت أصغر
//    من الملف، والروبوتُ أصغر، والزوايا أدور. الجدول:
//
//    | العنصر | كان | الملف |
//    |---|---|---|
//    | الروبوت (عرض) | 120 | **132** (دخول) · **110** (تسجيل) |
//    | أعلى الشاشة → زرّ الرجوع | 16 | **30** |
//    | زرّ الرجوع → الروبوت | 14 | **59.5** |
//    | الوصف → أول عنوان حقل | 20 | **51** |
//    | نصف قطر الزرّ | 16 | **12** |
//    | نصف قطر الحقل | 12 | **10** |
//    | ارتفاع الحقل | 43 و**48** (بحسب الأيقونة) | **42** ثابتاً |
//    | زرّ إظهار كلمة المرور | يميناً | **يساراً** |
//
// 🔵 **وجولة ٢٠٢٦-٠٩-٢٣ نقضت بعضَ أرقام الملف بقرار المالك** — لأن اللوح
//    390×844 والجهازَ 874 وأكثر، ولأن 42 تحت حدّ اللمس (44). وقد كُبّرت
//    أولاً أكثرَ من اللازم ثم رُدّت إلى الوسط في الجولة نفسها: الحقل
//    42←**48**، فجوةُ الحقول 7←**14**، الزرّ 47←**50**، الثانوي
//    39.5←**46**. الجدولُ الكامل في [AuthMetrics].
//    وأُضيفت **حالاتُ الحقل** (خطأ · صحّة · قوّة) — انظر [AuthField].
//
// ⭐ **لماذا ملفٌ واحد؟** المفردة نفسها تتكرر في تسع شاشات. ونسخُها في كل
//    شاشة يعني تسع نسخٍ تتفرّق قيَمُها عند أول تعديل — وهو ما يُفقد
//    «التطابق الحرفي» المطلوب.

/// 📐 ثوابت التخطيط المشتركة — كلُّها من الملف.
class AuthMetrics {
  AuthMetrics._();

  /// عرض المحتوى 342 من لوح 390 ⇒ هامشٌ جانبي 24.
  static const double gutter = 24;

  /// من حافة المنطقة الآمنة إلى أعلى زرّ الرجوع (77 − 47).
  static const double topGap = 30;

  /// وتحت آخر سطرٍ في الشاشة (810 − 794).
  static const double bottomGap = 16;

  /// زرّ الرجوع — مربّعٌ 40×40 بنصف قطر 12.
  static const double backSize = 40;
  static const double backRadius = 12;

  /// الحقل — **ارتفاعٌ ثابت** لا يتبدّل بوجود أيقونةٍ فيه.
  ///
  /// 🔴 **قرارُ المالك ٢٠٢٦-٠٩-٢٣ — نُقض رقمُ الملف عمداً:** «الحقول حقها
  ///    صغيرة، ليش كذا؟ كبّر الحقول شوي». والملفُّ يعطيها **42**، وهو رقمٌ
  ///    صحيحٌ على لوح 390×844 في Figma وخاطئٌ في اليد:
  ///
  ///    - حدُّ أبل لهدف اللمس **44×44** ([HIG · Layout]) — و42 تحته.
  ///    - اللوحُ 844 والأجهزةُ اليوم 852 و874 و932. فما رُسم ممتلئاً على
  ///      844 يترك على 932 **٨٨ نقطةً** فراغاً، وهو ما رآه المالك
  ///      «مكدّسة في النص». وتكبيرُ الحقول يملأ الفراغ بما **يُستعمل**
  ///      بدل أن تتمدّد فجوةٌ فارغة.
  ///
  /// 🔵 **ثم رُدَّت إلى الوسط في الجولة نفسها** — المالك: «جمّ كبّرتها،
  ///    ارجع خلّيها أصغر بشوي، متوسط على الأقل… خلّه نفس اللي في التصميم».
  ///    فـ**54 كانت زيادة**: صندوقٌ يعلو على إيقاع الشاشة كلِّها.
  ///
  ///    | | الملف | جولة أولى | **المعتمد** |
  ///    |---|---|---|---|
  ///    | الحقل | 42 | 54 | **48** |
  ///    | الزرّ الأساسي | 47 | 52 | **50** |
  ///    | الزرّ الثانوي | 39.5 | 48 | **46** |
  ///    | فجوة الحقول | 7 | 16 | **14** |
  ///
  /// ⚖️ و**48 هو أصغرُ ما يجوز**: حدُّ أبل 44، وأربعُ نقاطٍ فوقه هامشُ
  ///    أمانٍ لإصبعٍ يقع على الحافة. والنزولُ إلى 42 (رقمِ الملف) يعيد
  ///    العلّةَ التي بدأ منها التكبير.
  static const double fieldHeight = 48;
  static const double fieldRadius = 12;

  /// عنوان الحقل ← صندوقه، ثم الصندوق ← عنوان الحقل التالي.
  ///
  /// 🔴 و[fieldGap] رُفع من **7** إلى 16 بطلب المالك («عندك مسافة بين
  ///    البريد الإلكتروني وبين زرّ تسجيل الدخول»): سبعُ نقاطٍ بين حقلين
  ///    تجعلهما كتلةً واحدة، وحقلا الدخول شيئان مختلفان.
  static const double labelGap = 7;
  static const double fieldGap = 14;

  /// الفجوة تحت الحقل حين تظهر رسالةُ خطأ أو شريطُ قوّة.
  static const double helperGap = 6;

  static const double buttonHeight = 50;
  static const double buttonRadius = 14;

  /// الزرّ الثانوي (جوجل · زائر) — **46 لا 39.5**: هدفُ لمسٍ دون 44 يُخطئه
  /// الإصبع، وزرُّ جوجل أكثرُ ما يُضغط في الشاشة.
  static const double secondaryHeight = 46;
  static const double secondaryRadius = 12;

  /// مقاسات النصّ — من الملف، مرفوعةً بنسبة الصندوق.
  ///
  /// ⚠️ **10 للنصّ النائب كان تحت حدّ المقروئية** — أصغرُ ما توصي به
  ///    إرشاداتُ أبل 11، والعربيةُ تحتاج أكثرَ لأن نقاطها تُميّز الحروف.
  static const double labelSize = 12;
  static const double hintSize = 12;
  static const double inputSize = 14;
  static const double primaryLabelSize = 17;
  static const double secondaryLabelSize = 14;
  static const double titleSize = 20;
  static const double subtitleSize = 13;

  /// حبرُ رسالة الخطأ وشريطِ القوّة.
  static const double helperSize = 12;
}

// ══════════════════════════════════════════════════
// 🫱 فجوةٌ تتمدّد — ما يزيد من طول الشاشة يُوزَّع عليها
// ══════════════════════════════════════════════════
/// 🔴 **العلّة التي عالجتها:** الملف مرسومٌ على iPhone 14 (844)، والجهازُ
///    اليوم أطول (874 وأكثر). فإن ثبّتنا كلَّ الفجوات تراكم الفائضُ في
///    الأسفل فراغاً ميّتاً — وهو ما رآه المالك «مكدّسة في النص».
///
/// فالفجوتان اللتان جعلهما المصمّم واسعتين (زرّ الرجوع ← الروبوت،
/// والوصف ← أول حقل) تأخذان الفائض **مناصفةً**، فتبقى النِّسَبُ نسبَه.
/// وحين لا فائض (أو حين تفتح لوحةُ المفاتيح) تعود إلى مقاسها الأدنى
/// تماماً، ثم تمرّر الشاشة.
///
/// 🧩 **وكيف تُنفَّذ؟** لا يمكن أن تكون ودجتاً واحدة: عمودُ فلاتر يوزّع
///    الفائض على أبنائه **المرنين مباشرةً**، و`Spacer` داخل عمودٍ فرعيٍّ
///    بمقاسٍ أدنى يرمي `RenderFlex` (وقع فعلاً). فـ[AuthBody] تفكّها إلى
///    ابنين: `SizedBox(min)` ثابت و`Spacer` مرن — كلاهما في العمود نفسه.
class AuthSlack extends StatelessWidget {
  const AuthSlack(this.min, {super.key});

  /// المقاس في الملف — الحدُّ الأدنى الذي لا ينزل تحته.
  final double min;

  /// خارج [AuthBody] تبقى فجوةً ثابتة بمقاس الملف — لا تنكسر.
  @override
  Widget build(BuildContext context) => SizedBox(height: min);
}

// ══════════════════════════════════════════════════
// 🤖 الروبوت — بعرضٍ من الملف **وارتفاعٍ صريح**
// ══════════════════════════════════════════════════
/// 🔴 **فخٌّ وقع فعلاً وأفسد الشاشة كلَّها:** `Image` بعرضٍ فقط تُبلّغ
///    [RenderBox.computeMaxIntrinsicHeight] بارتفاعها عند **أقصى عرضٍ
///    متاح** لا عند عرضها هي — أي 354×(400÷512)=**276** بدل 103.
///    و[AuthBody] تقيس بالارتفاع الجوهري، فظنّت المحتوى أطولَ بـ١٧٣ نقطة،
///    فأعطت [AuthSlack] فائضاً وهمياً ودفعت نصفَ الشاشة خارجها.
///    (ظهر في المحاكي: الروبوت عند 219 بدل 129.5، والأزرار مقطوعة.)
///
/// فالارتفاعُ هنا **مصرَّحٌ به** من نسبة الملف، فلا يُسأل عن جوهريّه.
class AuthRobot extends StatelessWidget {
  const AuthRobot(this.width, {super.key});

  final double width;

  /// نسبة `assets/brand/robot_fly.png` — 512×400.
  static const double _ratio = 400 / 512;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: width * _ratio,
        child: Center(
            child: MasarRobot(size: width, pose: MasarRobotPose.fly)),
      );
}

// ══════════════════════════════════════════════════
// 🔙 زرّ الرجوع — 40×40 · r12 · سهمٌ 8×13
// ══════════════════════════════════════════════════
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onTap});

  /// `null` ⇒ يرجع بالـNavigator.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(AuthMetrics.backRadius),
          child: Container(
            width: AuthMetrics.backSize,
            height: AuthMetrics.backSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(AuthMetrics.backRadius),
              border: Border.all(color: AppColors.border),
            ),
            // ↩️ **يشير يميناً ولا يُعكس**: في العربية الرجوعُ يمين، والسهمُ
            //    في الملف `›`. و`Phosphor.caretRight` لا تُعكس مع الاتجاه
            //    (بخلاف `arrow_*_ios` في ماتيريال).
            child: Icon(PI.caretRight.bold,
                size: 16, color: AppColors.headingInk),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🏷️ عنوان الشاشة + وصفها
// ══════════════════════════════════════════════════
class AuthHeading extends StatelessWidget {
  /// ⛔ **ليس `const` عمداً.** ألوانه تُقرأ من [AppColors] وقت البناء،
  /// و`const AuthHeading(...)` تجعل فلاتر **تتخطّى إعادة بنائه** لأن
  /// الودجت الثابتة موحَّدة الهوية — فيبقى العنوان بحبر الوضع السابق.
  ///
  /// 🔴 **وقع فعلاً في المحاكي:** عنوان شاشة التأكيد ظلّ `#2C2C2C` على
  ///    خلفيةٍ سوداء بعد تبديل الوضع — أغمقَ من الوصف الذي تحته.
  // ignore: prefer_const_constructors_in_immutables  ← مقصود، انظر أعلاه
  AuthHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.titleSize = AuthMetrics.titleSize,
    this.align = TextAlign.center,
  });

  final String title;
  final String? subtitle;
  final double titleSize;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final cross = switch (align) {
      TextAlign.center => CrossAxisAlignment.center,
      _ => CrossAxisAlignment.start,
    };
    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(title,
            textAlign: align,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: AppColors.headingTitle,
            )),
        if (subtitle != null) ...[
          // 6 في الملف بين حبر العنوان وحبر الوصف.
          const SizedBox(height: 6),
          Text(subtitle!,
              textAlign: align,
              style: TextStyle(
                fontSize: AuthMetrics.subtitleSize,
                fontWeight: FontWeight.w400,
                height: 1.6,
                color: AppColors.textSecondary,
              )),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════
// ✍️ حقل إدخال — عنوانٌ فوقه، صندوقٌ بارتفاعٍ ثابت، ورسالتُه تحته
// ══════════════════════════════════════════════════
// 📐 العنوان 13/w700 · فجوة 8 · الصندوق **54** · r12 · تعبئة `#FAFBFB` ·
//    حدّ `#EBEDF0` · النصّ النائب 13/`#B5BDC7` · حشوةٌ أفقية 14.
//
// 🔴 **لماذا `SizedBox` حول الحقل ولا نترك `InputDecorator` يقيس؟** لأنه
//    يقيس بمحتواه: الحقلُ العاري خرج 43 وحقلُ كلمة المرور **48** لأن
//    الأيقونة تفرض حدّاً أدنى. فظهر في المحاكي صندوقان بارتفاعين
//    مختلفين في شاشةٍ واحدة — والملف يعطيهما مقاساً واحداً.
//
// ⚠️ **العنوان فوق الحقل لا داخله**: التصميم لا يستعمل `label` عائماً،
//    والعنوانُ الثابت يبقى مقروءاً أثناء الكتابة.
//
// ══════════════════════════════════════════════════
// 🚦 حالاتُ الحقل — أُضيفت ٢٠٢٦-٠٩-٢٣
// ══════════════════════════════════════════════════
// 🔴 **ملاحظةُ المالك:** «ما يعجبني إنه يطلع كلام [في النص]. البريد
//    الإلكتروني خطأ ⇒ الحقلُ يحمرّ ويظهر تحته الكلام، نفس التطبيقات
//    الأخرى».
//
// وكان كلُّ خطأ — صيغةُ بريدٍ خاطئة، كلمةُ مرورٍ قصيرة، كلمتان غير
// متطابقتين — يخرج `SnackBar` عائماً أسفل الشاشة. ثلاثةُ عيوبٍ فيه:
//
//   ① **لا يقول أين الخطأ.** «تحقّق من صيغة البريد» في شاشةٍ فيها أربعةُ
//      حقول تترك الطالب يبحث.
//   ② **يختفي بعد ثوانٍ** — فإن نظر بعيداً ضاعت الرسالة ولم يبقَ أثر.
//   ③ **يحجب الزرّ** الذي ضغطه للتوّ، فيظن أن ضغطته لم تصل فيعيد.
//
// فصارت الرسالةُ تحت حقلها، والحقلُ يحمرّ، والاثنان يبقيان حتى يصحّح.
//
// ⚖️ **ولماذا يبقى `SnackBar` لأخطاء الخادم غير المنسوبة؟** «لا يوجد
//    اتصال بالإنترنت» ليست خطأ حقلٍ بعينه. وما يُنسب إلى حقل يُعرض تحته،
//    وما لا يُنسب يبقى شريطاً — انظر [AuthAlert].
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.ltr = false,
    this.helper,
    this.textInputAction,
    this.onSubmitted,
    this.onChanged,
    this.enabled = true,
    this.errorText,
    this.invalid = false,
    this.ok = false,
    this.strength,
    this.autofillHints,
    this.focusNode,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;

  /// البريد وكلمة المرور **يُكتبان حروفاً لاتينية** فاتجاهُ محتواهما `ltr`
  /// — لكنهما في الملف **محاذيان لليمين** كبقية الشاشة. فالاتجاه للنصّ
  /// والمحاذاةُ للتصميم، ولا تعارض.
  final bool ltr;

  /// سطرُ إرشادٍ تحت الحقل (مثل شروط كلمة المرور).
  ///
  /// ⚠️ **يُخفيه [errorText]**: سطران تحت حقلٍ واحد — أحدهما أزرقُ يشرح
  ///    والآخر أحمرُ يمنع — يزاحمان بعضهما ويطيلان الشاشة. والخطأ أولى.
  final String? helper;

  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// ⚠️ **الشاشةُ تمسح الخطأ من هنا** حالما يكتب الطالب حرفاً — إبقاءُ
  ///    الحقل أحمرَ وهو يصحّح عقوبةٌ على التصحيح.
  final ValueChanged<String>? onChanged;

  final bool enabled;

  /// 🔴 رسالةُ الخطأ — `null` يعني لا خطأ. وجودُها يحمّر الإطار والتعبئة.
  final String? errorText;

  /// 🔴 **يحمّر الحقل بلا رسالةٍ تحته.**
  ///
  /// ⚠️ ليست تكراراً لـ[errorText]: «البريد أو كلمة المرور غير صحيحة» خطأٌ
  ///    في **الاثنين معاً ولا يُعرف أيُّهما** — ولو نسبناه إلى أحدهما
  ///    لأفشينا أيُّ البُرُد مسجَّلٌ عندنا. فالحقلان يحمرّان، والرسالةُ
  ///    واحدةٌ فوق الزرّ في [AuthAlert].
  final bool invalid;

  /// ✅ الحقلُ استوفى شرطَه — إطارٌ أخضر وعلامةٌ صغيرة بجوار عنوانه.
  final bool ok;

  /// 🔋 شريطُ قوّة كلمة المرور — يُعرض تحت الحقل حين يكون غير `null`.
  final PasswordStrength? strength;

  /// 🔐 **أمانٌ لا زينة:** بلا هذه لا يعرض مديرُ كلمات المرور (Keychain ·
  ///    Google Password Manager) اقتراحَه، فيكتب الطالب كلمةً يحفظها —
  ///    ويعيدها في كل موقع. ومديرُ الكلمات أكبرُ مكسبٍ أمنيٍّ في شاشةٍ
  ///    كهذه، وثمنُه سطرٌ واحد.
  final List<String>? autofillHints;

  final FocusNode? focusNode;

  /// 🔑 مفتاحُ الصندوق المرسوم — به تجده الاختباراتُ دون أن تعدّ
  ///    `Container`ات الشريط والرسالة.
  static const ValueKey<String> boxKey = ValueKey('auth-field-box');

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;
  late final FocusNode _focus = widget.focusNode ?? FocusNode();

  /// ⚠️ لا نتخلّص من عقدةٍ لم نُنشئها — صاحبُها يتخلّص منها.
  late final bool _ownsFocus = widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    if (_ownsFocus) _focus.dispose();
    super.dispose();
  }

  /// الإطارُ أحمرُ إمّا برسالةٍ تحته أو بلا رسالة — انظر [AuthField.invalid].
  bool get _hasError => widget.errorText != null || widget.invalid;

  Color get _borderColor {
    if (_hasError) return AppColors.fieldErrorBorder;
    if (_focus.hasFocus) return AppColors.primary;
    if (widget.ok) return AppColors.fieldOkBorder;
    return AppColors.fieldBorder;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _labelRow(),
        const SizedBox(height: AuthMetrics.labelGap),
        // ⏱️ 160ms: يكفي لتُرى النقلةُ ولا يكفي لتُنتظر.
        AnimatedContainer(
          key: AuthField.boxKey,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          height: AuthMetrics.fieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _hasError ? AppColors.fieldErrorFill : AppColors.fieldFill,
            borderRadius: BorderRadius.circular(AuthMetrics.fieldRadius),
            border: Border.all(
              color: _borderColor,
              width: _hasError || _focus.hasFocus ? 1.5 : 1,
            ),
          ),
          // ⚠️ RTL: أوّلُ ابنٍ يميناً ⇒ النصّ يمين والعينُ يسار، كما الملف.
          child: Row(
            children: [
              Expanded(child: _input()),
              if (widget.obscure) _reveal(),
            ],
          ),
        ),
        _below(),
      ],
    );
  }

  /// عنوانُ الحقل، وبجانبه علامةُ ✓ حين يستوفي شرطَه.
  ///
  /// ⚠️ **العلامةُ في العنوان لا داخل الصندوق**: داخلَه تزاحم زرَّ العين
  ///    في حقل كلمة المرور فتظهر أيقونتان متلاصقتان لا يُفرَّق بينهما.
  Widget _labelRow() => Row(
        children: [
          Text(widget.label,
              style: TextStyle(
                fontSize: AuthMetrics.labelSize,
                fontWeight: FontWeight.w700,
                height: 1.5,
                color: _hasError
                    ? AppColors.fieldErrorInk
                    : AppColors.fieldLabel,
              )),
          if (widget.ok && !_hasError) ...[
            const SizedBox(width: 6),
            Icon(PI.checkCircle.fill,
                size: 15, color: AppColors.fieldOkBorder),
          ],
        ],
      );

  Widget _input() => TextField(
        controller: widget.controller,
        focusNode: _focus,
        obscureText: _hidden,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        onSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        autofillHints: widget.autofillHints,
        // 🔐 **التصحيحُ التلقائي والاقتراحاتُ مطفأةٌ في كل حقول التوثيق.**
        //    لا لأنها تزعج، بل لأن لوحة المفاتيح **تتعلّم** ما يُكتب فيها:
        //    كلمةُ مرورٍ مرّت بقاموس التعلّم تظهر اقتراحاً في تطبيقٍ آخر.
        //    و`obscureText` تطفئها على iOS تلقائياً — لا على أندرويد.
        autocorrect: false,
        enableSuggestions: false,
        // 📋 **ولا قائمةَ لصقٍ فوق كلمة المرور**: نسخُها يضعها في الحافظة
        //    المشتركة التي يقرأها أيُّ تطبيقٍ آخر.
        enableInteractiveSelection: !widget.obscure,
        textDirection: widget.ltr ? TextDirection.ltr : null,
        textAlign: TextAlign.right,
        style: TextStyle(
            fontSize: AuthMetrics.inputSize,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary),
        decoration: InputDecoration(
          isCollapsed: true,
          contentPadding: EdgeInsets.zero,
          // 🔴 **`filled: false` وحدودٌ صفر — صراحةً.** ثيمُ التطبيق يعطي
          //    كلَّ `TextField` تعبئةً وحدّاً (`inputDecorationTheme`)،
          //    فظهر **صندوقٌ داخل صندوق**: إطارُنا المرسوم ثم إطارُ الثيم.
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          hintText: widget.hint,
          hintTextDirection:
              widget.ltr ? TextDirection.ltr : TextDirection.rtl,
          hintStyle: TextStyle(
              fontSize: AuthMetrics.hintSize,
              fontWeight: FontWeight.w400,
              color: AppColors.fieldHint),
        ),
      );

  /// ما تحت الصندوق: خطأٌ، أو شريطُ قوّة، أو سطرُ إرشاد — **واحدٌ فقط**.
  ///
  /// 🧩 `AnimatedSize` تجعل الشاشة تتمدّد بنعومةٍ حين تظهر الرسالة بدل أن
  ///    تقفز الأزرارُ تحتها قفزةً واحدة.
  Widget _below() {
    final Widget child;
    // ⚠️ `_hasError` لا تكفي شرطاً هنا: [AuthField.invalid] تحمّر بلا نصّ،
    //    و`errorText!` عندها تُرمى. الرسالةُ تتبع وجودَ نصٍّ لا وجودَ حمرة.
    if (widget.errorText != null) {
      child = _message(widget.errorText!);
    } else if (widget.strength != null &&
        widget.strength!.level != PasswordLevel.empty) {
      child = _StrengthBar(widget.strength!);
    } else if (widget.helper != null) {
      child = Padding(
        padding: const EdgeInsets.only(top: AuthMetrics.helperGap),
        child: Text(widget.helper!,
            style: TextStyle(
                fontSize: AuthMetrics.helperSize,
                fontWeight: FontWeight.w400,
                height: 1.5,
                color: AppColors.primary900)),
      );
    } else {
      child = const SizedBox(width: double.infinity);
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  /// 🔴 سطرُ الخطأ — أيقونةٌ ثم نصّ.
  ///
  /// ♿ `liveRegion` تجعل قارئَ الشاشة ينطق الرسالة **حين تظهر** دون أن
  ///    ينتقل إليها المستخدم — وإلا فالكفيفُ يضغط «دخول» ولا يسمع شيئاً.
  ///
  /// ⚠️ **ولا يُعتمد على اللون وحده** (WCAG 1.4.1): الأيقونةُ والنصُّ
  ///    يقولان الخطأ لمن لا يميّز الأحمر.
  Widget _message(String text) => Semantics(
        liveRegion: true,
        child: Padding(
          padding: const EdgeInsets.only(top: AuthMetrics.helperGap),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1.5),
                child: Icon(PI.warningCircle.fill,
                    size: 14, color: AppColors.fieldErrorInk),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(text,
                    style: TextStyle(
                        fontSize: AuthMetrics.helperSize,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                        color: AppColors.fieldErrorInk)),
              ),
            ],
          ),
        ),
      );

  /// 👁️ حبرُ العين في الملف عند حافة الصندوق اليسرى، ومربّعُ لمسٍ 34×54.
  Widget _reveal() => Semantics(
        button: true,
        label: _hidden ? "إظهار كلمة المرور" : "إخفاء كلمة المرور",
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _hidden = !_hidden),
          child: SizedBox(
            width: 34,
            height: AuthMetrics.fieldHeight,
            child: Icon(_hidden ? PI.eye.regular : PI.eyeSlash.regular,
                size: 21, color: AppColors.n650),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🔋 شريط قوّة كلمة المرور — ثلاثُ تقعاتٍ وكلمةٌ واحدة
// ══════════════════════════════════════════════════
/// 🔴 **طلبُ المالك:** «لما يكتب، تقعة مثلاً برتقالية، بعدها تقعة خضراء».
///
/// 📐 ثلاثُ تقعاتٍ متساوية بارتفاع 5 و r3، تمتلئ من **اليمين** لأن
///    الشاشة عربية — والامتلاءُ من اليسار يُقرأ نقصاناً.
///
/// ⚠️ **واللونُ يتبع الدرجةَ كلَّها لا كلَّ تقعةٍ لونَها:** تقعةٌ حمراء
///    وأخرى برتقالية وثالثةٌ خضراء معاً تقول ثلاثة أشياء في آن. فالتقعاتُ
///    المملوءة بلونٍ واحد، وعددُها هو المقياس.
class _StrengthBar extends StatelessWidget {
  const _StrengthBar(this.strength);

  final PasswordStrength strength;

  Color get _color => switch (strength.level) {
        PasswordLevel.strong => AppColors.strengthStrong,
        PasswordLevel.fair => AppColors.strengthFair,
        _ => AppColors.strengthWeak,
      };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AuthMetrics.helperGap),
        child: Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  height: 5,
                  decoration: BoxDecoration(
                    color:
                        i < strength.filled ? _color : AppColors.strengthTrack,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              if (i < 2) const SizedBox(width: 5),
            ],
            const SizedBox(width: 10),
            // 🏷️ الكلمةُ بعرضٍ يكفي «متوسطة» فلا يهتزّ الشريطُ مع كل حرف.
            SizedBox(
              width: 52,
              child: Text(strength.label,
                  textAlign: TextAlign.left,
                  style: TextStyle(
                      fontSize: AuthMetrics.helperSize,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: _color)),
            ),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════
// 📣 شريطُ خطأٍ لا ينتمي إلى حقل
// ══════════════════════════════════════════════════
/// 🔴 **لماذا وُجد؟** «البريد أو كلمة المرور غير صحيحة» **لا تُنسب إلى
///    حقل** — ولو نُسبت لكانت ثغرةَ إحصاءِ حسابات: من يرى «البريد غير
///    مسجّل» تحت حقل البريد وحده يعرف **أيُّ البُرُد مسجّلٌ عندنا**،
///    فيجمع قائمةً بمستخدمي التطبيق ويوجّه إليها تصيّداً.
///
/// فالرسالةُ الغامضة قصدٌ أمنيّ، وموضعُها فوق الزرّ لا تحت حقل.
/// ويبقى الحقلان محمّرَي الإطار (فالمالك طلب «يحمر») **بلا رسالةٍ تحت
/// أيٍّ منهما** — فالشكلُ يقول «راجعهما» ولا يقول أيُّهما.
class AuthAlert extends StatelessWidget {
  const AuthAlert({super.key, required this.message, this.onClose});

  final String message;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          decoration: BoxDecoration(
            color: AppColors.fieldErrorFill,
            borderRadius: BorderRadius.circular(AuthMetrics.fieldRadius),
            border: Border.all(color: AppColors.fieldErrorBorder, width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1.5),
                child: Icon(PI.warningCircle.fill,
                    size: 16, color: AppColors.fieldErrorInk),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(message,
                    style: TextStyle(
                        fontSize: AuthMetrics.helperSize + 0.5,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: AppColors.fieldErrorInk)),
              ),
              if (onClose != null)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 2, left: 2),
                    child: Icon(PI.x.bold,
                        size: 14, color: AppColors.fieldErrorInk),
                  ),
                ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🔘 الزرّ الأساسي — 47 · r12 · تعبئة مصمتة · نصّ 17
// ══════════════════════════════════════════════════
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: AuthMetrics.buttonHeight,
        child: ElevatedButton(
          onPressed: busy ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryFill,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppColors.primaryFill.withValues(alpha: 0.55),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AuthMetrics.buttonRadius)),
          ),
          child: busy
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      valueColor: AlwaysStoppedAnimation(Colors.white)))
              : Text(label,
                  style: const TextStyle(
                      fontSize: AuthMetrics.primaryLabelSize,
                      fontWeight: FontWeight.w700)),
        ),
      );
}

// ══════════════════════════════════════════════════
// ⬜ الزرّ الثانوي — 48 · r12 · `#E6F4FF` بحدّ `#006EBF`
// ══════════════════════════════════════════════════
/// 🔴 **الأيقونةُ يساراً لا يميناً** — طلبُ المالك ٢٠٢٦-٠٩-٢٣.
///
/// كانت [leading] أوّلَ ابنٍ في `Row`، والشاشةُ عربيةٌ (RTL) فأوّلُ ابنٍ
/// **يمين** — فظهر شعارُ جوجل على يمين النصّ.
///
/// ⚠️ **وليست مسألةَ ذوق:** إرشاداتُ «Sign in with Google» تضع الشعار على
///    اليسار في كل اللغات، ومنها العربية — لأن الشعارَ علامةٌ تجارية
///    مثبّتةُ الموضع لا عنصرُ جملةٍ يتبع اتجاهَ القراءة. والمستخدمُ يتعرّف
///    على الزرّ من موضع الشعار قبل أن يقرأ نصَّه.
///
/// 🧩 **كيف؟** `textDirection: ltr` على **الصفّ وحده**: فيصير أوّلُ ابنٍ
///    يساراً. والنصُّ العربيُّ داخل [Text] يُشكَّل باتجاهه هو ولا يتأثّر
///    — الاتجاهُ هنا ترتيبُ صندوقين لا ترتيبُ حروف.
class AuthOutlineButton extends StatelessWidget {
  const AuthOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;

  /// الأيقونة — تُرسم **يسار** النصّ دائماً.
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AuthMetrics.secondaryRadius),
          child: Container(
            width: double.infinity,
            height: AuthMetrics.secondaryHeight,
            decoration: BoxDecoration(
              color: AppColors.primaryTintSurface,
              borderRadius:
                  BorderRadius.circular(AuthMetrics.secondaryRadius),
              border: Border.all(color: AppColors.primary800),
            ),
            child: Row(
              textDirection: TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 10)],
                Text(label,
                    // ↩️ والنصُّ يُقرأ عربياً داخل صفٍّ إنجليزيّ الاتجاه.
                    textDirection: TextDirection.rtl,
                    style: TextStyle(
                        fontSize: AuthMetrics.secondaryLabelSize,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
              ],
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🔗 رابطٌ نصّي بمساحة لمسٍ حقيقية
// ══════════════════════════════════════════════════
/// ⚠️ **لماذا عنصرٌ خاص؟** `GestureDetector` حول `Text` عارٍ يعطي مساحة
///    لمسٍ بحجم الحروف فقط — ولا يزيد على ٢٠pt ارتفاعاً. وقد **فشلت النقرة
///    فعلاً في المحاكي** على «إنشاء حساب» مرّتين قبل أن يُكتشف السبب.
///
/// 🔴 **و`dense` لماذا؟** الملف يترك بين أسفل حقل كلمة المرور وحبر «نسيت
///    كلمة المرور؟» **ستّ نقاط**، ثم 12.5 إلى الزرّ — أي أنّ كلَّ ما يملكه
///    الرابطُ رأسياً **32 نقطة**. وحشوةٌ 12+12 تدفع الزرّ 24 نقطةً لأسفل
///    وتكسر إيقاع الشاشة كلِّها.
///
/// ✅ **والمقايضة أُلغيت ٢٠٢٦-٠٩-٢٣:** كانت مساحةُ اللمس في الوضع
///    المضغوط **≈30** — «كلُّ ما يتركه التصميم». وقد جُرّب في المحاكي
///    فأخطأته ثلاثُ نقراتٍ متتالية على «نسيت كلمة المرور؟»، وهو الرابطُ
///    الذي يُقصد حين **لا يستطيع الطالب الدخول أصلاً** — أسوأُ موضعٍ
///    لهدفٍ يُخطئه الإصبع.
///
///    فصار المضغوطُ **≈43** (حشوة 6 فوق و16 تحت).
///
/// 🧪 **وجُرّبت `OverflowBox` أولاً** لتفيض مساحةُ اللمس خارج السطر —
///    فأخذت `constraints.biggest`: عرضاً **لا نهائياً** داخل `Row`
///    («OVERFLOWED BY Infinity PIXELS»)، وعرضاً كاملاً داخل `Align`
///    فتوسّط الرابطُ بدل أن يلزم يمينه. فرُدّت إلى حشوةٍ صريحة.
class AuthLink extends StatelessWidget {
  const AuthLink({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.fontSize = 17,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final double fontSize;

  /// حشوةٌ غيرُ متناظرة (6 فوق · 16 تحت) بدل 12+12 — تبلغ حدَّ اللمس
  /// وتُبقي **حبرَ السطر** في موضعه من الملف. انظر شرح الصنف أعلاه.
  final bool dense;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          // ⬇️ **المضغوط يتمدّد لأسفل أكثرَ مما يتمدّد لأعلى**: حبرُه في
          //    الملف يبدأ بعد ستّ نقاطٍ من حافة الحقل، فتمدُّدٌ متناظرٌ
          //    يُنزل السطرَ عن موضعه. وحشوتُه الأفقية صفر لأن الملف
          //    يُلزقه بحافة المحتوى.
          padding: dense
              ? const EdgeInsets.only(top: 6, bottom: 16)
              : const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Text(label,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  height: 1.65,
                  color: color ?? AppColors.primary)),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🇬 شعار جوجل — **مسارُه الرسميّ** مرسوماً بالكود
// ══════════════════════════════════════════════════
// 🔴 **ملاحظةُ المالك ٢٠٢٦-٠٩-٢٣:** «الشعار حق حساب جوجل… سيئة جداً».
//    وكان محقّاً: النسخةُ السابقة **تقديرٌ لا شعار** — أربعةُ أقواس
//    (`drawArc`) بزوايا مضبوطةٍ باليد ومستطيلٌ يمثّل الشرطة الأفقية.
//    وثلاثةُ عيوبٍ لا تُصلَح بضبط الأرقام:
//
//      ① **النسبةُ خاطئة.** الحرفُ في شعار جوجل ليس حلقةً مقطوعة: ذراعُه
//         اليمنى أسمكُ من الحلقة، والشرطةُ تنبت من داخلها لا من حافتها.
//      ② **الوصلاتُ مكسورة.** `strokeCap: butt` يترك بين القوس والقوس
//         شقّاً بعرض البكسل يُرى عند 16 نقطة.
//      ③ **المستطيلُ يفيض.** `Rect` صريحةٌ تخرج عن الحلقة يميناً.
//
// ✅ **فالحلُّ أن يُرسم الشعارُ نفسه لا شبيهُه:** أربعةُ مسارات — أحمرُ
//    وأزرقُ وأصفرُ وأخضر — من أصل الشعار الرسميّ على لوح 48×48، تُقرأ
//    بـ[SvgPathParser] وتُقاس إلى المقاس المطلوب. فما يُرسم هو الشكلُ
//    الصحيح بحوافّه ووصلاته، لا محاكاةٌ له.
//
// ⭐ **ولا صورةَ شبكية ولا أصلٌ خارجي:** الشاشة تُفتح بلا إنترنت، والحجمُ
//    صفرُ بايت، والحوافُّ حادّةٌ عند أيّ مقاسٍ وأيّ كثافة بكسل.
//
// 📋 **وشرطُ جوجل محفوظ:** إرشاداتُ «Sign in with Google» تُلزم بالشعار
//    كما هو بألوانه الأربعة، ولا تسمح بإعادة تلوينه — وهو ما يفعله هذا
//    الرسم بالضبط.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key, this.size = 18});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GooglePainter()),
      );
}

class _GooglePainter extends CustomPainter {
  /// 📐 لوحُ الشعار الأصليّ — كلُّ الإحداثيات أدناه منسوبةٌ إليه.
  static const double _board = 48;

  /// ألوانُ جوجل الأربعة — أرقامُها الرسمية لا ما يقاربها.
  static const _red = Color(0xFFEA4335);
  static const _blue = Color(0xFF4285F4);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  /// 🅖 المسارات الأربعة كما هي في الشعار الرسميّ (لوح 48×48).
  ///
  /// ⚠️ **لا تُعدَّل هذه السلاسل يدوياً.** رقمٌ واحدٌ يزيغ يكسر وصلةً بين
  ///    قوسين فيظهر شقٌّ أبيض. وإن لزم تحديثُها تُنسخ من الأصل كاملةً.
  static const List<(String, Color)> _paths = [
    (
      'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 '
          '14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z',
      _red
    ),
    (
      'M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 '
          '5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z',
      _blue
    ),
    (
      'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19'
          'C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z',
      _yellow
    ),
    (
      'M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 '
          '2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z',
      _green
    ),
  ];

  /// 🧠 المسارات تُحلَّل **مرّةً واحدة** لا مع كل إطار: الحلُّ مكلفٌ نسبياً
  ///    والشعارُ ثابتٌ لا يتبدّل. وهو مشتركٌ بين كل نسخ الشعار في التطبيق.
  static List<(Path, Paint)>? _cache;

  static List<(Path, Paint)> get _figures => _cache ??= [
        for (final (d, color) in _paths)
          (
            SvgPathParser.parse(d),
            Paint()
              ..color = color
              ..isAntiAlias = true
              ..style = PaintingStyle.fill,
          ),
      ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _board, size.height / _board);
    for (final (path, paint) in _figures) {
      canvas.drawPath(path, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════
// 🧭 قارئُ مسار SVG — ما يكفي الشعار ولا يزيد
// ══════════════════════════════════════════════════
/// ⚠️ **ليس قارئاً عاماً لـSVG.** لا `flutter_svg` في حزم المشروع، وإضافةُ
///    حزمةٍ كاملة لرسمِ شعارٍ واحد مبالغة. فهذا يقرأ **الأوامر التي في
///    الشعار فقط**: `M/m` و`L/l` و`H/h` و`V/v` و`C/c` و`S/s` و`Z/z`.
///
/// ⛔ ولا يدعم `A` (القوس) ولا `Q/T` — والشعارُ لا يستعملها. فإن مرّ أمرٌ
///    مجهول **يُرمى** بدل أن يُتجاهل صامتاً: مسارٌ ناقصٌ يُرسم شكلاً
///    مشوّهاً لا يُلاحظه أحد، والرميُ يُوقف الاختبار في أول تشغيل.
///
/// 🔢 **والأرقام تُقرأ بمُقسّمٍ خاصّ** لا بـ`split`: في صيغة SVG تُحذف
///    الفواصل بين الأرقام السالبة (`10.53-4.59`) وتُختصر الأصفار
///    (`.76` و`-.38`) — و`split(' ')` تعيدهما رقماً واحداً.
class SvgPathParser {
  SvgPathParser._();

  static Path parse(String d) {
    final path = Path();
    var cursor = Offset.zero; // القلمُ الآن
    var start = Offset.zero; // أولُ نقطةٍ في الشكل الحالي (لأجل `Z`)
    var control = Offset.zero; // انعكاسُ التحكّم لأجل `S`
    String? command;

    final tokens = _tokenize(d);
    var i = 0;

    Offset take(bool relative) {
      final p = Offset(tokens[i].number, tokens[i + 1].number);
      i += 2;
      return relative ? cursor + p : p;
    }

    while (i < tokens.length) {
      if (tokens[i].isCommand) {
        command = tokens[i].command;
        i++;
        if (i >= tokens.length && command != 'Z' && command != 'z') break;
      }
      if (command == null) {
        throw FormatException('مسارٌ يبدأ برقمٍ لا بأمر: $d');
      }

      final relative = command == command.toLowerCase();
      switch (command.toUpperCase()) {
        case 'M':
          cursor = take(relative);
          path.moveTo(cursor.dx, cursor.dy);
          start = cursor;
          // 📌 أرقامٌ زائدة بعد `M` تُقرأ `L` — قاعدةُ المواصفة نفسها.
          command = relative ? 'l' : 'L';
        case 'L':
          cursor = take(relative);
          path.lineTo(cursor.dx, cursor.dy);
        case 'H':
          final x = tokens[i++].number;
          cursor = Offset(relative ? cursor.dx + x : x, cursor.dy);
          path.lineTo(cursor.dx, cursor.dy);
        case 'V':
          final y = tokens[i++].number;
          cursor = Offset(cursor.dx, relative ? cursor.dy + y : y);
          path.lineTo(cursor.dx, cursor.dy);
        case 'C':
          final c1 = take(relative);
          final c2 = take(relative);
          final end = take(relative);
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          control = c2;
          cursor = end;
        case 'S':
          // انعكاسُ نقطة التحكّم الثانية حول النهاية — تعريفُ `S`.
          final c1 = cursor * 2 - control;
          final c2 = take(relative);
          final end = take(relative);
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          control = c2;
          cursor = end;
        case 'Z':
          path.close();
          cursor = start;
          // ⚠️ `Z` لا تأخذ أرقاماً. ورقمٌ بعدها لا يُستهلك، فتدور الحلقةُ
          //    عليه أبداً — عطلٌ صامتٌ يُعلَّق التطبيقَ عند أول رسم.
          if (i < tokens.length && !tokens[i].isCommand) {
            throw FormatException('رقمٌ بعد `Z` في المسار: $d');
          }
        default:
          throw FormatException('أمرٌ غير مدعوم في قارئ المسار: $command');
      }
    }
    return path;
  }

  /// يفصل السلسلة إلى أوامرَ وأرقام.
  static List<_Token> _tokenize(String d) {
    final out = <_Token>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isEmpty) return;
      out.add(_Token.number(double.parse(buffer.toString())));
      buffer.clear();
    }

    for (var k = 0; k < d.length; k++) {
      final c = d[k];
      if (c == ' ' || c == ',' || c == '\n' || c == '\t') {
        flush();
      } else if (RegExp(r'[A-Za-z]').hasMatch(c)) {
        flush();
        out.add(_Token.command(c));
      } else if (c == '-' || c == '+') {
        // سالبٌ يبدأ رقماً جديداً **إلا** بعد `e` في الصيغة الأسّية.
        if (buffer.isNotEmpty && !buffer.toString().endsWith('e')) flush();
        buffer.write(c);
      } else if (c == '.') {
        // `.5.5` رقمان: النقطةُ الثانية تبدأ رقماً جديداً.
        if (buffer.toString().contains('.')) flush();
        buffer.write(c);
      } else {
        buffer.write(c);
      }
    }
    flush();
    return out;
  }
}

class _Token {
  const _Token.command(this.command) : number = 0;
  const _Token.number(this.number) : command = null;

  final String? command;
  final double number;

  bool get isCommand => command != null;
}

// ══════════════════════════════════════════════════
// 🧱 هيكل شاشة توثيق — رجوعٌ أعلى ومحتوىً يملأ الطول
// ══════════════════════════════════════════════════
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.showBack = true,
    this.onBack,
    this.footer,
    this.background,
  });

  final List<Widget> children;
  final bool showBack;
  final VoidCallback? onBack;

  /// يُلصق بأسفل الشاشة خارج التمرير (الزرّ الأساسي في شاشات الخطوات).
  final Widget? footer;

  /// خلفيةٌ مخالفة (شاشتا الاستعادة في التصميم بخلفيةٍ خضراء خافتة).
  final Color? background;

  @override
  Widget build(BuildContext context) => ThemeScope(
        builder: (context) => Scaffold(
          backgroundColor: background ?? AppColors.bgLight,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AuthMetrics.gutter,
                  AuthMetrics.topGap,
                  AuthMetrics.gutter,
                  AuthMetrics.bottomGap),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 🚪 **ولا رجوع من شاشة الدخول**: يُدخل إليها بـ
                  //    `pushReplacement` فلا شيءَ تحتها لتعود إليه.
                  //
                  // 🔴 **ولا يُحجَز موضعُه فارغاً** (كان يُحجَز 40 نقطة «كي
                  //    لا يقفز المحتوى»، والقفزُ لا يقع: الشاشتان لا تتبدّل
                  //    إحداهما إلى الأخرى، كلٌّ منهما تُبنى مرّةً بحالها).
                  //    فأربعون نقطةً بيضاءَ في أعلى شاشةٍ ضيّقة خسارةٌ
                  //    بلا مقابل.
                  //
                  // ⚠️ **وشاشةُ الدخول تعرضه** منذ ٢٠٢٦-٠٩-٢٣ (بطلب
                  //    المالك: «الزرّ حقّ الرجوع… مش موجود») — لا تعتمد
                  //    على `Navigator.pop` بل تمرّر `onBack` صريحاً،
                  //    انظر `AuthScreen`.
                  if (showBack)
                    SizedBox(
                      height: AuthMetrics.backSize,
                      child: Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: AuthBackButton(onTap: onBack)),
                    ),
                  Expanded(child: AuthBody(children: children)),
                  if (footer != null) ...[
                    const SizedBox(height: 12),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 📜 جسمُ الشاشة — يملأ الطول ثم يمرّر عند الضيق
// ══════════════════════════════════════════════════
/// يُستعمل مباشرةً داخل خطوات التسجيل (حيث الهيكل واحدٌ لأربع صفحات).
///
/// 🧩 **الوصفة:** `ConstrainedBox(minHeight)` تضمن ألّا يقصر المحتوى عن
///    النافذة، و`IntrinsicHeight` تعطي العمودَ ارتفاعاً محدَّداً — وبه
///    وحده تعمل [AuthSlack] (فالفجوة المرنة في عمودٍ بلا سقفٍ لا معنى
///    لها). وما زاد على النافذة يُمرَّر كالعادة.
class AuthBody extends StatelessWidget {
  const AuthBody({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          // 🎹 لوحة المفاتيح تُغلق بلمسة خارج الحقل — وإلا حجبت الزرّ في
          //    شاشةٍ قصيرة ولم يجد الطالب مخرجاً.
          keyboardDismissBehavior:
              ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final w in children)
                    if (w is AuthSlack) ...[
                      SizedBox(height: w.min),
                      const Spacer(),
                    ] else
                      w,
                ],
              ),
            ),
          ),
        ),
      );
}
