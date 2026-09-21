import 'package:flutter/material.dart';

// 🌙 الوضع المُطبَّق فعلاً (بعد حلّ «اتبع النظام») — تقرأه كل الشاشات.
//    مالكُ القرار `ThemeController`، وهذا مجرّد مرآة له.
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);

// ==========================================
// 🎨 نظام الألوان — لوحة المصمّم (Figma · 2026-09-19)
// ==========================================
// 📐 **المصدر:** ملف «مسار» على Figma، مستخرَجٌ عبر REST API لا مقروءاً من
//    صورة. كل قيمةٍ هنا هي القيمة الأصلية في الملف حرفاً بحرف.
//
// 🔄 **ما تغيّر عن اللوحة السابقة:**
//    ① الهوية: `#3B82F6` (أزرق Tailwind) ← **`#0092FF`** أنصع وأكثر حيوية.
//    ② الثانوي: **البنفسجي أُلغي.** `#8B5CF6` ← `#3C65CA` كحليّ. الهوية زرقاء
//       بالكامل الآن، وكل بنفسجيٍّ باقٍ في شاشةٍ ما فهو بقيّةٌ تُنظَّف.
//    ③ الأزرار **مصمتة لا متدرّجة** — تبسيطٌ مقصود من المصمّم. `primaryButton`
//       أُبقي اسماً ووظيفةً لكنه صار تدرّجاً من لونٍ واحد إلى نفسه، فلا
//       تنكسر الشاشات التي تطلبه ولا يظهر تدرّجٌ لم يُصمَّم.
//
// ⚠️ **القاعدة التي تحكم الوضع الداكن** (لم يصمّمه المصمّم — اشتُقّ هنا):
//    ① الغائر أغمق من البطاقة، والمرتفع أفتح — في الوضعين.
//    ② الظلّ لا يُرى على الأسود، فالفصل هناك مهمّة `border` لا الظلّ.
//    ③ لونُ الهوية يُفتَّح ليُقرأ **كنصّ**، ويُعمَّق ليَحمل **نصّاً أبيض**.
//       خلطُ الدورين يهبط بالتباين إلى ٢٫٦:١ — وهي أشهر زلّة في الوضع الداكن.
// ══════════════════════════════════════════════════
// 🎨 سلّمُ أداةٍ واحدة — خمسُ درجاتٍ بأسمائها لا بأرقامها
// ══════════════════════════════════════════════════
/// تُبنى من [AppColors.toolPalette]، ولا تُنشأ في الشاشات: اللونُ قرارُ
/// اللوحة لا قرارُ الودجت.
class ToolPalette {
  const ToolPalette({
    required this.box,
    required this.accent,
    required this.ink,
    required this.fill,
    required this.cta,
  });

  /// مربّعُ الأيقونة خلف الأيقونة (الدرجة 100).
  final Color box;

  /// الأيقونةُ وحدُّ الشريحة المختارة (الدرجة 500).
  final Color accent;

  /// حبرُ عنوان الشريحة المختارة — أغمقُ من [accent] ليُقرأ.
  final Color ink;

  /// تعبئةُ الشريحة المختارة (الدرجة 50).
  final Color fill;

  /// زرُّ التوليد المصمت تحت نصٍّ أبيض (الدرجة 800).
  final Color cta;
}

class AppColors {
  // ══════════════════════════════════════════════════════════
  // 🎨 السلالم الخام — كما هي في Figma
  // ══════════════════════════════════════════════════════════
  // تُستعمل مباشرةً حين تحتاج الشاشةُ درجةً بعينها (شارة، حالة، رسم بياني).

  /// Primary · أزرق سماوي
  static const primary50  = Color(0xFFE6F4FF); // Light
  static const primary100 = Color(0xFFD9EFFF); // Light :hover
  static const primary200 = Color(0xFFB0DDFF); // Light :active
  static const primary500 = Color(0xFF0092FF); // ⭐ Normal — لون الهوية
  static const primary600 = Color(0xFF0083E6); // Normal :hover
  static const primary700 = Color(0xFF0075CC); // Normal :active
  static const primary800 = Color(0xFF006EBF); // Dark
  static const primary900 = Color(0xFF005899); // Dark :hover
  static const primary950 = Color(0xFF004273); // Dark :active
  static const primary990 = Color(0xFF003359); // Darker

  /// Secondary · كحليّ
  static const secondary50  = Color(0xFFECF0FA);
  static const secondary100 = Color(0xFFE2E8F7);
  static const secondary200 = Color(0xFFC3CFEF);
  static const secondary500 = Color(0xFF3C65CA); // ⭐ Normal
  static const secondary600 = Color(0xFF365BB6);
  static const secondary700 = Color(0xFF3051A2);
  static const secondary800 = Color(0xFF2D4C98);
  static const secondary900 = Color(0xFF243D79);
  static const secondary950 = Color(0xFF1B2D5B);
  static const secondary990 = Color(0xFF152347);

  /// Error · أحمر
  static const error50  = Color(0xFFFDEAEA);
  static const error100 = Color(0xFFFCDFDF);
  static const error200 = Color(0xFFF9BEBE);
  static const error500 = Color(0xFFED2C2C); // ⭐ Normal
  static const error600 = Color(0xFFD52828);
  static const error700 = Color(0xFFBE2323);
  static const error800 = Color(0xFFB22121);
  static const error900 = Color(0xFF8E1A1A);

  /// Success · أخضر
  static const success50  = Color(0xFFE9FBEE);
  static const success100 = Color(0xFFDEF9E6);
  static const success200 = Color(0xFFBAF3CB);
  static const success500 = Color(0xFF20D958); // ⭐ Normal
  static const success600 = Color(0xFF1DC34F);
  static const success700 = Color(0xFF1AAE46);
  static const success800 = Color(0xFF18A342);
  static const success900 = Color(0xFF138235);

  /// Warning · أصفر
  static const warning50  = Color(0xFFFEFBE8);
  static const warning100 = Color(0xFFFDF8DD);
  static const warning200 = Color(0xFFFBF1B8);
  static const warning500 = Color(0xFFF3D31B); // ⭐ Normal
  static const warning600 = Color(0xFFDBBE18);
  static const warning700 = Color(0xFFC2A916);
  static const warning800 = Color(0xFFB69E14);
  static const warning900 = Color(0xFF927F10);
  static const warning950 = Color(0xFF6D5F0C);

  /// Neutrals · ١٨ درجة
  static const n0   = Color(0xFFFFFFFF);
  static const n50  = Color(0xFFFAFAFA);
  static const n100 = Color(0xFFF5F5F5);
  static const n200 = Color(0xFFEBEBEB);
  static const n300 = Color(0xFFDEDEDE);
  static const n400 = Color(0xFFBFBFBF);
  static const n450 = Color(0xFFB0B0B0);
  static const n500 = Color(0xFFA3A3A3);
  static const n550 = Color(0xFF949494);
  static const n600 = Color(0xFF858585);
  static const n650 = Color(0xFF757575);
  static const n700 = Color(0xFF666666);
  static const n750 = Color(0xFF626262); // نصّ الوصف في شاشات المصمّم
  static const n800 = Color(0xFF575757);
  static const n850 = Color(0xFF4A4A4A);
  static const n875 = Color(0xFF3B3B3B);
  static const n900 = Color(0xFF2E2E2E);
  static const n925 = Color(0xFF1C1C1C);
  static const n950 = Color(0xFF121212); // Black/700
  static const n975 = Color(0xFF0D0D0D);
  static const n1000 = Color(0xFF000000);

  /// 🪨 **سلّم الـSlate** — المصمّم يستعمله جنباً إلى جنب مع `Neutrals`
  ///    في شاشات التوثيق (عناوين الأقسام · وصف البطاقات · حدود الصفوف).
  ///    وهو مائلٌ للأزرق بخلاف الرمادي الحيادي، والخلطُ بينهما يُفقد
  ///    الشاشةَ برودتها المقصودة.
  static const slate50  = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate700 = Color(0xFF334155);
  static const slate900 = Color(0xFF0F172A);
  static const slateInk = Color(0xFF0B2546); // عناوين البطاقات في التصميم

  /// أزرق التأسيس — أغمق درجتين يستعملهما المصمّم للعناوين على الفاتح.
  static const inkB800 = Color(0xFF15294B);
  static const inkB900 = Color(0xFF091E42);
  static const pageB10 = Color(0xFFFAFBFB);

  static bool get _dark => isDarkModeNotifier.value;

  // ══════════════════════════════════════════════════════════
  // 🏷️ الأدوار الدلالية — ما تستعمله الشاشات
  // ══════════════════════════════════════════════════════════

  /// لون الهوية **كنصّ وأيقونة**. في الداكن مُفتَّح ليُقرأ على السطح الأسود.
  static Color get primary => _dark ? const Color(0xFF4DB3FF) : primary500;

  /// الثانوي كنصّ وأيقونة.
  static Color get secondary => _dark ? const Color(0xFF8AA5E8) : secondary500;

  /// 🎯 **تعبئةٌ تحمل نصّاً أبيض** (زرّ ممتلئ · شارة مختارة).
  ///
  /// 🔴 ليست [primary]: ذاك فُتِّح ليُقرأ **كنصّ**، ووضعُ أبيضَ فوقه يعكس
  ///    الدور فيهبط التباين. في الداكن نعمّق بدل أن نفتّح.
  static Color get primaryFill => _dark ? primary700 : primary500;
  static Color get secondaryFill => _dark ? secondary700 : secondary500;

  /// 🔘 **الحالة الخاملة لعنصرٍ نشطُه [primaryFill]** — نقطة مؤشّر، شريحة
  ///    غير مختارة، خطوةٌ لم تُبلَغ بعد.
  ///
  /// ⚠️ `primary200` (`#B0DDFF`) يصلح على الأبيض ويكاد **يزاحم النشط** على
  ///    الأسود: تصير النقاط الأربع متساويةً في الحضور فيضيع معنى المؤشّر.
  static Color get primaryMuted =>
      _dark ? primary500.withValues(alpha: 0.30) : primary200;

  // ══════════ سُلّم الأسطح ══════════
  // القاعدة الواحدة في الوضعين: **الغائر أغمق من البطاقة، والمرتفع أفتح.**

  /// خلفية الصفحة.
  static Color get bgLight => _dark ? n975 : n0;

  /// البطاقة — السطح الذي يحمل المحتوى.
  static Color get surfaceWhite => _dark ? n925 : n0;

  /// سطحٌ **غائر داخل البطاقة**: حقل إدخال، شارة، خانة ثانوية.
  static Color get softSurface => _dark ? n950 : n100;

  /// سطحٌ **مرتفع فوق البطاقة**: قائمة منسدلة، ورقة سفلية، حوار.
  static Color get elevatedSurface => _dark ? n900 : n0;

  /// ✏️ الخطّ الشعري الفاصل.
  ///
  /// ⚠️ في لوحة المصمّم البطاقةُ **بيضاء على صفحةٍ بيضاء**، فالحدُّ هنا ليس
  ///    زينةً بل هو **كلّ ما يفصل البطاقة عن الصفحة** — وإسقاطُه يُذيب
  ///    الشاشة في لوحٍ أبيض واحد، تماماً كما يفعل الظلُّ على الأسود.
  static Color get border => _dark ? n875 : n200;

  // ══════════ النصّ ══════════
  /// ⚠️ ليس أبيض ناصعاً في الداكن: الأبيض على شبه الأسود يُحدث هالةً
  ///    تُتعب العين في القراءة الطويلة، وهذه شاشة درسٍ لا شاشة تنبيه.
  ///
  /// 📏 **سقفُ التباين ١٦ شرطٌ يفرضه `dark_theme_test`.** المحسوب من
  ///    سلّم المصمّم: `n100` ⇒ ١٧٫٨ و`n200` ⇒ ١٦٫٣ — كلاهما يتجاوز.
  ///    و`n300` يعطي **١٤٫٥ على الصفحة و١٢٫٧ على البطاقة** (الحدّ الأدنى ٧)،
  ///    ويحفظ سُلّم الأسطح كما هو بلا رفع خلفية الصفحة.
  static Color get textPrimary => _dark ? n300 : n925;

  /// نصّ الوصف — `#626262` هو ما اعتمده المصمّم في كل الشاشات.
  static Color get textSecondary => _dark ? n500 : n750;

  // ══════════ مفردات النماذج (من شاشات التوثيق في Figma) ══════════

  /// عنوان الشاشة في شاشات التوثيق — `#2C2C2C`، أفتح قليلاً من [headingInk].
  static Color get headingTitle => _dark ? n100 : const Color(0xFF2C2C2C);

  /// عنوان الحقل فوقه — `#2E2E2E`.
  static Color get fieldLabel => _dark ? n300 : const Color(0xFF2E2E2E);

  /// تعبئة الحقل — `#FAFBFB` (سطحٌ غائر شديد الخفوت على الأبيض).
  static Color get fieldFill => _dark ? n950 : pageB10;

  /// حدّ الحقل — `#EBEDF0`.
  static Color get fieldBorder => _dark ? n875 : const Color(0xFFEBEDF0);

  /// النصّ النائب داخل الحقل — `#6B788E`.
  static Color get fieldHint => _dark ? n600 : const Color(0xFF6B788E);

  /// سطحٌ مصبوغٌ بلون الهوية — أزرار جوجل والزائر وبطاقة الاختيار المحدّدة.
  ///
  /// ⚠️ في الداكن لا يصلح `#E6F4FF` (يصير لوحاً أبيض يبهر)، فنستعمل لون
  ///    الهوية بشفافيةٍ منخفضة فيبقى «مصبوغاً» لا مضيئاً.
  static Color get primaryTintSurface =>
      _dark ? primary500.withValues(alpha: 0.12) : primary50;

  /// 💡 سطحُ التنبيه الأصفر وحدُّه — شريط الإرشاد في «اختيار الصف».
  static Color get warningTintSurface =>
      _dark ? warning500.withValues(alpha: 0.10) : warning50;
  static Color get warningTintBorder =>
      _dark ? warning500.withValues(alpha: 0.28) : warning200;

  /// عنوان قسمٍ صغير فوق مجموعة (الصف الدراسي · المسار · اختر دورك).
  static Color get sectionLabel => _dark ? n600 : slate400;

  /// وصفٌ داخل بطاقة اختيار.
  static Color get cardHint => _dark ? n500 : slate500;

  /// حبر عناوين البطاقات — `#0B2546` في التصميم.
  static Color get cardInk => _dark ? n100 : slateInk;

  /// عنوان صفٍّ أو بطاقة في شاشات الاختيار — `#0F172A`.
  static Color get slateTitle => _dark ? n100 : slate900;

  /// رقم الشارة والأيقونة الخاملة — `#334155`.
  static Color get slateNumber => _dark ? n300 : slate700;

  /// حدّ الصفّ الخامل — `#E2E8F0`.
  static Color get rowBorder => _dark ? n875 : slate200;

  // ══════════ بطاقات الرئيسية (من Figma) ══════════
  /// بطاقة قسم التعليم — `#D9EFFF`.
  static Color get eduCardSurface =>
      _dark ? primary500.withValues(alpha: 0.13) : primary100;

  /// بطاقة تحليل مستواي — `#B7C9F8`.
  static Color get analysisCardSurface =>
      _dark ? secondary500.withValues(alpha: 0.16) : const Color(0xFFB7C9F8);

  /// 🖋️ **حبر بطاقة التحليل** — `#152347` على اللافندر الفاتح.
  ///
  /// 🔴 كان ثابتاً (`secondary990`) فصار **كحليّاً على كحليّ** في الوضع
  ///    الداكن: العنوان والوصف يكادان يختفيان. وهذه علّةُ كل نصٍّ يجلس على
  ///    سطحٍ ملوّن: السطحُ يتبع الوضع، فالحبر الذي فوقه يجب أن يتبعه.
  static Color get analysisCardInk => _dark ? n100 : secondary990;

  // ══════════════════════════════════════════════════════════
  // 📊 «معلومات الطالب / تحليل مستواي» — من `03-home/22-معلومات`
  // ══════════════════════════════════════════════════════════
  // ⭐ **أكثرُها ليس جديداً**: قِستُ التصدير فوجدتُ المصمّم يبني الشاشة من
  //    سلالم المشروع — `#3C65CA` هو `secondary500`، وحلقتا المستوى
  //    `#20D958`/`#0092FF` هما `success500`/`primary500` حرفاً.

  /// 🔵 **سطحُ بطاقة الملخّص والنصيحة** — `#3C65CA`.
  ///
  /// 🌙 ويُعمَّق في الداكن: كحليٌّ ساطعٌ بمساحةِ بطاقةٍ كاملة في ليلٍ يُتعب
  ///    العين، والنصُّ الأبيض يبقى مقروءاً على الأعمق.
  static Color get analysisNavy =>
      _dark ? const Color(0xFF243D79) : secondary500;

  /// 🟦 **تدرّجُ بطاقة الطالب** — قِستُ أربعَ زوايا: `#A5C0FC` أعلى اليمين
  ///    تخبو إلى `#7B9CEE` أسفل اليسار، وفوقها دوائرُ زينةٍ أغمق.
  static LinearGradient get analysisProfileGradient => LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: _dark
            ? const [Color(0xFF3C5391), Color(0xFF2A3B69)]
            : const [Color(0xFFA5C0FC), Color(0xFF7B9CEE)],
      );

  /// دوائرُ الزينة داخل بطاقة الطالب — الأساسُ نفسُه أغمقَ قليلاً.
  static Color get analysisProfileBlob =>
      _dark ? Colors.white.withValues(alpha: 0.05)
            : const Color(0xFF7497EB).withValues(alpha: 0.55);

  /// حبرُ بطاقة الطالب — `#15294B` على أزرقَ فاتح.
  static Color get analysisProfileInk =>
      _dark ? n100 : inkB800;

  /// شريطُ «مادة درستها» — المقطوعُ `#D5EAD1` والباقي `#3C65CA`.
  static Color get analysisBarDone =>
      _dark ? const Color(0xFF7FB98F) : const Color(0xFFD5EAD1);
  static Color get analysisBarRest =>
      _dark ? const Color(0xFF1B2D5B) : secondary500;

  /// زرُّ «عرض التفاصيل» داخل البطاقة — `#F2F8F0` بحبر `#3C65CA`.
  static Color get analysisProfileButton =>
      _dark ? const Color(0xFF12203D) : const Color(0xFFF2F8F0);
  static Color get analysisProfileButtonInk =>
      _dark ? const Color(0xFF9FB5E8) : secondary500;

  /// 📅 **تدرّجُ بطاقة «اختبار مراجعة»** — `#36259D` يميناً إلى `#5047E6`
  ///    يساراً. بنفسجيٌّ قصداً: هو الفعلُ الوحيد في الصفحة الذي **يُنشئ**
  ///    شيئاً، فيُميَّز عن الأزرق الذي يعرض.
  static LinearGradient get analysisReviewGradient => LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: _dark
            ? const [Color(0xFF241A6A), Color(0xFF3A32A8)]
            : const [Color(0xFF36259D), Color(0xFF5047E6)],
      );

  /// سطحُ شارة النسبة الحمراء — `#FCDFDF` فاتحاً، وشفافاً في الداكن.
  static Color get errorTint =>
      _dark ? error500.withValues(alpha: 0.16) : error100;

  /// «مرحباً 👋» — `#6C7A71`.
  static Color get greetInk => _dark ? n500 : const Color(0xFF6C7A71);

  /// وصفُ الدرس في صفوف «تحتاج تركيز» — `#667085`.
  static Color get rowHint => _dark ? n500 : const Color(0xFF667085);

  /// «التفاصيل» وسهمُها — `#42526D`.
  static Color get rowAction => _dark ? n300 : const Color(0xFF42526D);

  /// شارة الإشعارات الحمراء — `#FB2C36`.
  static Color get badgeRed => const Color(0xFFFB2C36);

  // ══════════ الدرج الجانبي ══════════
  /// تدرّج «محادثة جديدة» — `#0092FF → #1D5783` في التصميم.
  static List<Color> get newChatGradient => _dark
      ? const [Color(0xFF0B5E9E), Color(0xFF13375A)]
      : const [Color(0xFF0092FF), Color(0xFF0B7ACD), Color(0xFF136CAF), Color(0xFF1D5783)];

  /// صفُّ الدرج المختار — `#EFF6FF` بحدّ `#51A2FF`.
  static Color get drawerRowSelected =>
      _dark ? primary500.withValues(alpha: 0.14) : const Color(0xFFEFF6FF);
  static Color get drawerRowSelectedBorder =>
      _dark ? primary500.withValues(alpha: 0.5) : const Color(0xFF51A2FF);

  // ══════════ القوائم المنسدلة ══════════
  /// نصّ القائمة — `#525252`.
  static Color get dropdownInk => _dark ? n300 : const Color(0xFF525252);

  /// سهمها — `#6C7A71`.
  static Color get dropdownCaret => _dark ? n600 : const Color(0xFF6C7A71);

  /// سطح مجموعة الأوضاع — `#EBEDF0`.
  static Color get modeGroupSurface => _dark ? n950 : const Color(0xFFEBEDF0);

  // ══════════ شرائح الاقتراحات ══════════
  /// سطح الشريحة الخاملة — `#F8FAFC`.
  static Color get chipSurface => _dark ? n950 : slate50;

  /// حبرها — `#45556C`.
  static Color get chipInk => _dark ? n400 : const Color(0xFF45556C);

  // ══════════ شريط الكتابة في الشات (من Figma) ══════════
  /// حدّ شريط الكتابة — `#CAD5E2`.
  static Color get inputBarBorder => _dark ? n875 : const Color(0xFFCAD5E2);

  /// أيقوناته والنصّ النائب — `#90A1B9`.
  static Color get inputBarIcon => _dark ? n600 : const Color(0xFF90A1B9);

  /// نصّ الكتابة — `#1D293D`.
  static Color get inputBarText => _dark ? n200 : const Color(0xFF1D293D);

  /// زرّ الإرسال — `#155DFC`.
  static Color get sendButton => _dark ? const Color(0xFF2E6BE0) : const Color(0xFF155DFC);

  /// حبرٌ داكنٌ جداً لأيقونات شريط العنوان — `#003359`.
  static Color get primary990Ink => _dark ? n200 : primary990;

  // ══════════ شريط التنقّل السفلي ══════════
  /// سطح الشريط — `#E6F4FF` في التصميم.
  static Color get navSurface => _dark ? n925 : primary50;

  /// خطّه العلوي.
  static Color get navBorder =>
      _dark ? n875 : primary500.withValues(alpha: 0.14);

  /// حبر العناصر الخاملة — `#243757`.
  static Color get navInk => _dark ? n500 : const Color(0xFF243757);

  /// 🌿 خلفيةُ شاشتَي الاستعادة — `#F2F8F0` في التصميم.
  ///    في الداكن تعود إلى خلفية الصفحة: خضرةٌ خافتة على الأسود تُقرأ وسخاً.
  static Color get recoveryBg => _dark ? n975 : const Color(0xFFF2F8F0);

  /// سطحٌ محايدٌ غائر داخل بطاقة — `#F1F5F9` (شارة رقم الصف · أيقونة المسار).
  static Color get neutralTint => _dark ? n900 : const Color(0xFFF1F5F9);

  /// 🖋️ **حبر العناوين** — `#21302A` كما في كل شاشات المصمّم.
  ///
  /// ⚠️ ليس أسود الحياد (`n925`) ولا أزرق التأسيس: هو رماديٌّ مخضرٌّ خافت
  ///    اختاره المصمّم لعناوين الشاشات، وأدقُّ منهما في مطابقة التصميم.
  ///    وفي الداكن يتبع النصَّ الأساسي لأن حبراً داكناً هناك لا يُقرأ.
  static Color get headingInk => _dark ? n100 : const Color(0xFF21302A);

  /// 🖋️ **حبر الهوية** — «مسار» وعناوين البطاقات وحقول الإدخال.
  ///    يتبع الوضع: حبرٌ داكن ثابت يجعل نصَّ الحقل غير مرئيٍّ في الداكن.
  static Color get brandInk => _dark ? const Color(0xFFDCE6FA) : inkB900;

  /// 🃏 **عنوان بطاقة إعدادات الجلسة** — `#15294B` في التصميم.
  ///
  /// 🔴 كان ثابتاً، فبقي كحليّاً غامقاً فوق بطاقةٍ سوداء في الوضع الداكن:
  ///    رأيتُه في المحاكي فلم أكد أقرأ «إعدادات الجلسة».
  static Color get panelTitle => _dark ? n300 : inkB800;

  /// أيقونةُ رأس تلك البطاقة — زرقاءُ داكنة في الفاتح، فاتحةٌ في الداكن.
  static Color get panelTitleIcon => _dark ? primary : primary800;

  /// 🌈 **خلفيّةُ شاشة المحادثة** — تدرّجٌ رأسيٌّ لا هالةٌ دائرية.
  ///
  /// 📐 **مقيسٌ من التصدير بكسلةً بكسلة** على عمودٍ نظيفٍ عند حافّة اللوح
  ///    (ارتفاع الشاشة 842): أبيضُ خالصٌ حتى 320، ثم يزرقّ تدريجاً حتى
  ///    ذروته `#B7D9F2` عند 560، ثم يفقد زرقتَه إلى رماديٍّ `#C1C8CE`
  ///    في القاع. وكانت عندي قرصاً باهتاً فبقيت الشاشة بيضاء.
  ///
  /// 🌙 **والداكن مشتقٌّ منه لا منسوخ:** المنحنى نفسه — حيادٌ في الأعلى،
  ///    ذروةٌ زرقاء في الثلث السفلي، ثم عودةٌ إلى القاع. وسقفُ فتاحته
  ///    `#16304D` كي يبقى حبرُ الفقاعات فوقه في حدّ التباين.
  static LinearGradient get chatBackdrop => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _dark
            ? const [
                Color(0xFF0B1220),
                Color(0xFF0B1220),
                Color(0xFF102037),
                Color(0xFF16304D),
                Color(0xFF13273C),
                Color(0xFF0D1522),
                Color(0xFF0A1018),
              ]
            : const [
                Color(0xFFFFFFFF),
                Color(0xFFFFFFFF),
                Color(0xFFEBF6FE),
                Color(0xFFC4E2F8),
                Color(0xFFB7D9F2),
                Color(0xFFC8DCEB),
                Color(0xFFC1C8CE),
              ],
        stops: const [0.0, 0.38, 0.475, 0.57, 0.665, 0.79, 1.0],
      );

  // ══════════ بطاقاتُ «دليل استخدام تطبيق مسار» (03-home/20) ══════════
  // 🎨 أربعُ بطاقاتٍ ملوّنة، لكلٍّ تعبئةٌ وحدٌّ ومربّعُ أيقونةٍ وحبرُ عنوان.
  //    مقيسةٌ من التصدير بكسلةً بكسلة — وكلُّها من سلالم المصمّم نفسِها
  //    (`primary200` · `warning200` · `success200`).
  //
  // 🌙 وفي الداكن: التعبئةُ لونُ الحالة بشفافيةٍ خفيفةٍ فوق السطح، والحبرُ
  //    يُرفع إلى درجةٍ فاتحةٍ — فالحبرُ الداكن (`#1C398E`) على لوحٍ أسود
  //    لا يُقرأ.
  static List<Color> get guideFills => _dark
      ? [
          const Color(0xFF10233F),
          const Color(0xFF2A2312),
          const Color(0xFF0D2A20),
          const Color(0xFF1E1633),
          const Color(0xFF191D24),
        ]
      : const [
          Color(0xFFEFF6FF),
          Color(0xFFFFFBEB),
          Color(0xFFECFCF5),
          Color(0xFFFAF5FF),
          Color(0xFFF8FAFC),
        ];

  static List<Color> get guideBorders => _dark
      ? [
          const Color(0xFF1D3E6B),
          const Color(0xFF4A3D14),
          const Color(0xFF14523C),
          const Color(0xFF39275C),
          const Color(0xFF2B313B),
        ]
      : const [
          Color(0xFFDBEAFE),
          Color(0xFFFEF3C6),
          Color(0xFFD0FAE5),
          Color(0xFFF5EBFF),
          Color(0xFFE2E8F0),
        ];

  static List<Color> get guideTiles => _dark
      ? [
          const Color(0xFF1B4E7E),
          const Color(0xFF5C4C15),
          const Color(0xFF15613C),
          const Color(0xFF3A3A73),
          const Color(0xFF39414E),
        ]
      : const [
          primary200,
          warning200,
          success200,
          Color(0xFFC3CFEF),
          Color(0xFFE2E8F0),
        ];

  static List<Color> get guideInks => _dark
      ? [
          const Color(0xFF9EC9FF),
          const Color(0xFFE8C88A),
          const Color(0xFF8FE3C4),
          const Color(0xFFCDA8E8),
          const Color(0xFFB6BEC9),
        ]
      : const [
          Color(0xFF1C398E),
          Color(0xFF7B3306),
          Color(0xFF004F3B),
          Color(0xFF59168B),
          Color(0xFF334155),
        ];

  /// حبرُ مثلّث التشغيل داخل مربّع كل بطاقة.
  static List<Color> get guideAccents =>
      const [primary500, warning600, success600, secondary500, slate700];

  /// ⭐ **لونُ «محفوظ»** — نجمةُ الحفظ فوق الردّ.
  ///
  /// 🎨 كان `Colors.amber` جاهزاً من Material فيختلف عن سلّم المصمّم
  ///    ولا يتبع الوضع الداكن. وسلّمُ التحذير عنده أصفرُ فاتح، فيُعتمد.
  static Color get savedInk => _dark ? warning500 : warning800;
  static Color get savedSurface =>
      _dark ? warning900.withValues(alpha: 0.22) : warning100;

  /// ✅ **لونُ «نُسخ»** — يومض لحظةً بعد النسخ.
  static Color get copiedInk => _dark ? success500 : success800;

  /// 🏷️ **شارةُ نطاق المحادثات** في القائمة الجانبية — `#D9EFFF` في التصميم.
  ///
  /// 🔴 كانت ثابتةً فبقيت لوحاً أزرقَ ساطعاً وحيداً في قائمةٍ سوداء.
  static Color get scopeSurface => _dark ? primary990 : primary100;
  static Color get scopeInk => _dark ? primary200 : primary900;

  /// 🔵 لون النصّ **على سطحٍ أبيض دائماً** — كالقرص داخل بطاقة ملوّنة.
  ///    لا يتبع الوضع لأن ما تحته أبيضُ في الوضعين.
  static const Color onWhite = primary800;

  // ══════════════════════════════════════════════════════════
  // 🧠 لوحةُ «اختبر نفسك» — مقيسةٌ من `design/05-quiz/`
  // ══════════════════════════════════════════════════════════
  // 📐 كلُّ قيمةٍ هنا قُرئت من بكسلات التصدير (@2x · إطار 390×844)، لا
  //    قُدّرت بالعين. والداكنُ **اشتقاقٌ** — المصمّم لم يرسمه:
  //    ① السطحُ الغائر أغمق من البطاقة ② الحدُّ يحمل الفصل لا الظلّ
  //    ③ لونُ الحالة يُفتَّح ليُقرأ نصّاً ويُعمَّق ليَحمل نصّاً.

  /// حدُّ بطاقات الاختبار — `#E8EDF3` في التصدير (أفتحُ من `rowBorder`).
  ///
  /// 🌙 والداكنُ `#343434` لا `#2A2A2A`: قِستُ الأخير على `n925` فكانت
  ///    نسبتُه 1.19:1 — أي **حدٌّ لا يُرى**، والظلُّ هناك لا يعوّضه.
  static Color get quizCardBorder =>
      _dark ? const Color(0xFF343434) : const Color(0xFFE8EDF3);

  /// شريحةٌ خاملة: تعبئة `#F8FAFC` وحدٌّ `#E7ECF2`.
  static Color get quizChipFill => _dark ? n950 : slate50;
  static Color get quizChipBorder =>
      _dark ? const Color(0xFF2F2F2F) : const Color(0xFFE7ECF2);

  /// خيارٌ خامل في شاشة السؤال — `#FAFBFB` على حدٍّ `#EBEDF0`.
  static Color get quizOptionFill => _dark ? n950 : const Color(0xFFFAFBFB);
  static Color get quizOptionBorder =>
      _dark ? const Color(0xFF2E2E2E) : const Color(0xFFEBEDF0);

  /// مربّعُ الاختيار في قائمة الدروس — حدُّه `#CAD5E2` قبل الاختيار.
  static Color get quizCheckBorder => _dark ? n700 : const Color(0xFFCAD5E2);

  /// شارةُ «تم اختيار ١» — `#D4E4FE` بحبرٍ `#155DFC`.
  static Color get quizBadgeFill =>
      _dark ? const Color(0xFF16305C) : const Color(0xFFD4E4FE);
  static Color get quizBadgeInk =>
      _dark ? const Color(0xFF9DBEFF) : const Color(0xFF155DFC);

  /// ✅ **الصواب** — `#20D958` على `#E9FBEE`.
  static Color get quizRight => _dark ? success500 : success500;
  static Color get quizRightFill =>
      _dark ? const Color(0xFF0E2B18) : success50;

  /// ❌ **الخطأ** — `#ED2C2C` على `#FCEAEA`.
  static Color get quizWrong => _dark ? const Color(0xFFFF6B6B) : error500;
  static Color get quizWrongFill =>
      _dark ? const Color(0xFF331414) : const Color(0xFFFCEAEA);

  /// 💚 **زمرّدةُ الشارة** — `#00D492`. ليست `success500`: المصمّم يستعمل
  ///    الأخضرَ للإجابة الصحيحة وهذه لعدّاد النقاط، والخلطُ بينهما يُفقد
  ///    الشريطَ تمييزَه.
  static Color get quizEmerald =>
      _dark ? const Color(0xFF34E3AB) : const Color(0xFF00D492);

  /// 🌸 **ورديُّ بطاقة الأخطاء** في شاشة النتيجة — `#FF637E` على `#FFE8EF`.
  static Color get quizPink =>
      _dark ? const Color(0xFFFF8FA3) : const Color(0xFFFF637E);
  static Color get quizPinkFill =>
      _dark ? const Color(0xFF351A22) : const Color(0xFFFFE8EF);

  /// 💧 **سماويُّ بطاقة الوقت** — `#00BCFF` على `#E6F4FF`.
  static Color get quizSky =>
      _dark ? const Color(0xFF4FCDFF) : const Color(0xFF00BCFF);

  /// سطحٌ باهتٌ بلون الهوية — فقاعةُ الترحيب والشريحةُ المختارة (`#E6F4FF`).
  static Color get quizTint =>
      _dark ? const Color(0xFF0C2B45) : primary50;

  /// 🏷️ **شارةُ الموضوع في «راجع إجاباتك»** — كهرمانيّةٌ `#FEF4E5` بحدٍّ
  ///    `#FEE2B7`.
  ///
  /// ⚠️ **وحبرُها وحده لم يُنقل حرفياً.** في التصدير `#FFD541` — أصفرُ
  ///    ساطعٌ على تعبئةٍ كريميّة، نسبتُه 1.5:1 أي **غيرُ مقروء**. فأُخذ
  ///    كهرمانُ المصمّم الغامق نفسُه (`#7B3306` من بطاقات دليل الاستخدام)
  ///    فبقيت لوحتُه ولم يبقَ نصٌّ لا يُقرأ. (مسجَّلٌ في `INVENTORY.md`.)
  static Color get quizTagFill =>
      _dark ? const Color(0xFF2A2312) : const Color(0xFFFEF4E5);
  static Color get quizTagBorder =>
      _dark ? const Color(0xFF4A3D1C) : const Color(0xFFFEE2B7);
  static Color get quizTagInk =>
      _dark ? const Color(0xFFE8C88A) : const Color(0xFF7B3306);

  /// زرٌّ أساسيٌّ معطَّل — `#B0DDFF` (`primary200`) بحبرٍ أبيض كما في التصميم.
  static Color get quizButtonIdle =>
      _dark ? const Color(0xFF1B3D57) : primary200;

  // ══════════════════════════════════════════════════════════
  // 🎓 لوحةُ «المنح» — مقيسةٌ من `design/06-scholarships/`
  // ══════════════════════════════════════════════════════════
  // ⭐ **أكثرُها ليس جديداً.** قِستُ التصدير فوجدتُ المصمّم بنى القسمَ من
  //    سلالم المشروع نفسِها حرفاً بحرف: `#E6F4FF`=`primary50` ·
  //    `#D9EFFF`=`primary100` · `#006EBF`=`primary800` ·
  //    `#003359`=`primary990` · `#DEF9E6`=`success100` ·
  //    `#18A342`=`success800` · `#B22121`=`error800` ·
  //    `#F3D31B`=`warning500` · `#E2E8F7`=`secondary100`.
  //    فلا يُخترع لونٌ حيث توجد درجة — وما يلي هو ما **ليس** في السلالم،
  //    ومشتقّاتُ الوضع الداكن (لم يرسمه المصمّم، وهو شرطُ قبولٍ عندنا).

  /// حدُّ حقل البحث — `#E4EAF1`؛ أفتحُ درجةً من حدّ البطاقة `#E8EDF3`،
  /// لأن الحقل يعلو البطاقةَ في الهرم فلا يزاحمها.
  static Color get schSearchBorder => _dark ? n875 : const Color(0xFFE4EAF1);

  /// حبرُ التسميات الثانوية على الكرت («المعدل المطلوب») — `#62748E`.
  static Color get schMutedInk => _dark ? n500 : const Color(0xFF62748E);

  /// سطحُ المحتوى الطويل في شاشة التفاصيل — `#D9EFFF` بحبر `#15294B`.
  ///
  /// 🌙 الداكنُ `#143049`: أزرقٌ عميقٌ يُبقي **دلالةَ اللون** (هذا سطحُ
  ///    معلومة لا بطاقة عادية). وقِستُه على خلفية الصفحة `n975` فكانت
  ///    1.43:1 — لوحٌ يُرى؛ والدرجةُ الأولى التي جرّبتُها (`#0E2233`)
  ///    كانت 1.20 أي لوحاً يذوب في الصفحة.
  static Color get schTint => _dark ? const Color(0xFF143049) : primary100;
  static Color get schTintInk => _dark ? n200 : inkB800;

  /// زرُّ المتابعة ⭐ — `#FCF8DD` بحبر `#F3D31B`.
  ///
  /// ⚠️ النسبةُ بين الاثنين في الفاتح **1.5:1** — وهي مقبولةٌ هنا وحدَها
  ///    لأنه **رسمٌ لا نصّ**: علامةٌ مملوءةٌ بحجم 18 يميّزها الشكلُ لا
  ///    الحدّة، وحالتُها الأخرى (غيرُ متابَعة) تختلف بالشكل أيضاً.
  static Color get schSaveFill =>
      _dark ? const Color(0xFF2E2A10) : const Color(0xFFFCF8DD);
  static Color get schSaveInk => warning500;

  /// 🏷️ وسومُ الكرت الثلاثة — التمويل (أخضر) · التخصّص (أزرق) · المهلة
  ///    (أحمر). ثلاثتُها من السلالم في الفاتح، ومعمَّقةٌ في الداكن.
  static Color get schGreenFill =>
      _dark ? const Color(0xFF0E2B18) : success100;
  static Color get schGreenInk => _dark ? success500 : success800;
  static Color get schBlueFill => _dark ? const Color(0xFF0C2B45) : primary50;
  static Color get schBlueInk =>
      _dark ? const Color(0xFF6CC5FF) : primary800;
  static Color get schRedFill =>
      _dark ? const Color(0xFF331414) : const Color(0xFFFCEAEA);
  static Color get schRedInk =>
      _dark ? const Color(0xFFFF8080) : error800;

  /// عنوانُ المحادثة في درج المنحة — `#1C398E`.
  static Color get schDrawerInk =>
      _dark ? const Color(0xFF9FB5E8) : const Color(0xFF1C398E);

  /// ✏️🗑️ **زرّا بطاقة المحادثة في الدرج** — قِستُ التصدير بكسلاً بكسلاً:
  ///
  ///    التعديل: تعبئة `#E2E8F7` · حدّ `#C3CFEF` · حبر `#2D4C98`
  ///    الحذف:   تعبئة `#FCDFDF` · حدّ `#F9BEBE` · حبر `#B22121`
  ///
  /// ⭐ وستّتُها من السلالم لا مخترعة: `secondary100/200/800` و
  ///    `error100/200/800`. وهذا ما جعلني أُبقيها تسميةً جديدة بدل
  ///    `quizWrongFill` الذي كان يُستعمل هنا: ذاك `#FCEAEA` وهذا `#FCDFDF`،
  ///    درجةٌ واحدةٌ فرقاً — لكنها فرقٌ بين «قريب» و«مطابق».
  static Color get schEditFill =>
      _dark ? const Color(0xFF17203C) : secondary100;
  static Color get schEditBorder =>
      _dark ? const Color(0xFF2B3A66) : secondary200;
  static Color get schEditInk =>
      _dark ? const Color(0xFF9FB5E8) : secondary800;

  static Color get schDeleteFill =>
      _dark ? const Color(0xFF331414) : error100;
  static Color get schDeleteBorder =>
      _dark ? const Color(0xFF5C2323) : error200;
  static Color get schDeleteInk =>
      _dark ? const Color(0xFFFF8080) : error800;

  /// 🔵 **تدرّجُ زرّ «اسأل مساعد المنحة»** — قِستُ صفَّ البكسلات: من
  ///    `#1E65FF` عند الحافّة اليمنى إلى `#0140CD` عند اليسرى. وهو أزرقٌ
  ///    ملكيٌّ أعمقُ من لون الهوية عمداً: زرُّ الفعل الرئيسيّ في الشاشة.
  static LinearGradient get schCtaGradient => LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: _dark
            ? const [Color(0xFF1B4FCB), Color(0xFF0B2E8F)]
            : const [Color(0xFF1E65FF), Color(0xFF0140CD)],
      );

  /// 🔵 **تدرّجُ زرّ «محادثة جديدة» في الدرج** — من `#0193FF` يميناً إلى
  ///    `#47779A` يساراً (أزرقُ الهوية يخبو إلى رماديٍّ مزرقّ).
  static LinearGradient get schDrawerGradient => LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: _dark
            ? const [Color(0xFF0272C6), Color(0xFF32536B)]
            : const [Color(0xFF0193FF), Color(0xFF47779A)],
      );

  // ══════════════════════════════════════════════════════════
  // 👨‍🏫 لوحةُ أدوات المعلم — سلّمٌ كاملٌ لكلّ أداة
  // ══════════════════════════════════════════════════════════
  // 🎨 **مقيسةٌ من `design/09-teacher` (الإطارات ١–٤) بكسلةً بكسلة.**
  //    لكل أداةٍ سلّمٌ واحدٌ من سلالم التوكنات، وأربعُ درجاتٍ منه في أربعة
  //    مواضع — والنظامُ مطّردٌ في الأدوات الثلاث:
  //
  //    | الموضع | الدرجة | خطة درس | واجب واختبار | تبسيط مفهوم |
  //    |---|---|---|---|---|
  //    | مربّع الأيقونة | 100 | `#E2E8F7` | `#DEF9E6` | `#FDF8DD` |
  //    | الأيقونة والحدّ | 500 | `#3C65CA` | `#20D958` | `#F3D31B` |
  //    | تعبئة الشريحة المختارة | 50 | `#ECF0FA` | `#E9FBEE` | `#FEFBE8` |
  //    | زرّ التوليد | 800 | `#2D4C98` | `#18A342` | `#B69E14` |
  //
  // 🔎 **وكيف عُرف أنه سلّمٌ لا ألوانٌ متفرّقة؟** الإطارات الأربعة تناقضت:
  //    مربّعُ «واجب» فيها `#D0FAE5`/`#007A55` مرّةً و`#DEF9E6`/`#20D958`
  //    مرّةً. والأولى ليست في سلالم الملف أصلاً (هي `emerald` من اللوحة
  //    القديمة)، والثانية `success100`/`success500` حرفاً. فالمتناقضُ
  //    بقيّةٌ لم تُحدَّث، والمطّردُ هو النظام.
  //
  // 🔴 **والحبرُ درجةٌ أغمق — وهو الفرق الوحيد عن التصدير.**
  //
  //    التصديرُ نفسُه متردّد: في الحالة **الخاملة** يرسم أيقونةَ الواجب
  //    `#007A55` وأيقونةَ التبسيط `#BB4D00` — حبرانِ داكنان يُقرآن؛ وفي
  //    الحالة **المختارة** يرسمهما ويرسم عنوانَيهما بلون الحدّ نفسِه:
  //    الأخضرُ `#20D958` على `#E9FBEE` بتباين **١٫٨:١**، والأصفرُ
  //    `#F3D31B` على `#FEFBE8` بتباين **١٫٥:١** — نصٌّ لا يُقرأ على
  //    هاتفٍ بيد معلّمٍ في فصل.
  //
  //    فاختيرَ **الحبرُ الداكن في الحالتين** (وهو نيّةُ المصمّم في
  //    الخاملة حرفاً)، ودرجتُه من **سلّم الأداة نفسِه** لا من خارجه.
  //    ويبقى الـ500 **للحدّ** فتبقى الشريحةُ المختارةُ مميّزةً بلونها
  //    كما في التصدير. وحدُّ التباين ٤٫٥ للنصّ و٣ للأيقونة مكتوبٌ في
  //    `dark_theme_test` فلا يُخفَّض صامتاً.
  //
  // 🆕 **والسلّم الرابع (سماويّ) لأداةٍ لم يرسمها المصمّم**: «اسأل
  //    المساعد» أداةٌ قائمةٌ في الخادم (`tool: "ask"`)، ورسم المصمّم
  //    ثلاثاً. فبُنيت بلغته من سلّم الهوية نفسِه.
  static ToolPalette toolPalette(int slot) => switch (slot) {
        // 📖 خطة الدرس — السلّم الثانوي (الكحليّ).
        0 => ToolPalette(
            box: _dark ? secondary500.withValues(alpha: 0.20) : secondary100,
            accent: _dark ? const Color(0xFF8AA5E8) : secondary500,
            ink: _dark ? const Color(0xFF8AA5E8) : secondary500,
            fill: _dark ? secondary500.withValues(alpha: 0.13) : secondary50,
            cta: _dark ? secondary700 : secondary800,
          ),
        // 📄 الواجب والاختبار — سلّم النجاح.
        1 => ToolPalette(
            box: _dark ? success500.withValues(alpha: 0.20) : success100,
            accent: _dark ? const Color(0xFF5FE38A) : success500,
            ink: _dark ? const Color(0xFF5FE38A) : success900,
            fill: _dark ? success500.withValues(alpha: 0.13) : success50,
            cta: success800,
          ),
        // 💡 تبسيط المفهوم — سلّم التحذير (الأصفر).
        2 => ToolPalette(
            box: _dark ? warning500.withValues(alpha: 0.20) : warning100,
            accent: _dark ? const Color(0xFFF0DE6B) : warning500,
            ink: _dark ? const Color(0xFFF0DE6B) : warning950,
            fill: _dark ? warning500.withValues(alpha: 0.13) : warning50,
            cta: _dark ? warning900 : warning800,
          ),
        // 🤖 اسأل المساعد 🆕 — سلّم الهوية.
        _ => ToolPalette(
            box: _dark ? primary500.withValues(alpha: 0.20) : primary50,
            accent: _dark ? const Color(0xFF4DB3FF) : primary500,
            ink: _dark ? const Color(0xFF4DB3FF) : primary800,
            fill: _dark ? primary500.withValues(alpha: 0.13) : primary50,
            cta: _dark ? primary700 : primary800,
          ),
      };

  // ══════════════════════════════════════════════════════════
  // 🌈 التدرّجات
  // ══════════════════════════════════════════════════════════

  /// تدرّج الهوية — للبطاقات الكبيرة والأسطح المميّزة.
  static LinearGradient get mainGradient => LinearGradient(
        colors: _dark
            ? const [Color(0xFF0B5E9E), Color(0xFF2D4C98)]
            : const [primary500, secondary500],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// فقاعة رسالة المستخدم.
  static LinearGradient get bubbleGradient => LinearGradient(
        colors: _dark
            ? const [Color(0xFF0B5E9E), Color(0xFF0075CC)]
            : const [primary500, Color(0xFF47B4FF)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      );

  /// 🔘 الزرّ الأساسي.
  ///
  /// ⚠️ **لونٌ مصمت لا تدرّج** — هكذا صمّمه المصمّم (`342×47 · r16 · #0092FF`).
  ///    أُبقي `LinearGradient` نوعاً كي لا تنكسر الشاشات التي تطلبه، لكن
  ///    طرفيه لونٌ واحد فلا يظهر تدرّجٌ لم يُطلب.
  static LinearGradient get primaryButton {
    final c = primaryFill;
    return LinearGradient(colors: [c, c]);
  }

  // ══════════════════════════════════════════════════════════
  // 🌑 الظلال
  // ══════════════════════════════════════════════════════════
  // 🌙 في الداكن تكاد تختفي — عمداً. الفصلُ هناك مهمّة `border`.

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: _dark
              ? Colors.black.withValues(alpha: 0.45)
              : inkB900.withValues(alpha: 0.06),
          blurRadius: _dark ? 20 : 24,
          offset: Offset(0, _dark ? 6 : 8),
        )
      ];

  static List<BoxShadow> get bubbleShadow => [
        BoxShadow(
          color: _dark
              ? Colors.black.withValues(alpha: 0.35)
              : inkB900.withValues(alpha: 0.04),
          blurRadius: _dark ? 10 : 12,
          offset: const Offset(0, 3),
        )
      ];

  // ══════════════════════════════════════════════════════════
  // 🌊 الخلفية الموجية
  // ══════════════════════════════════════════════════════════
  /// ⚠️ لونٌ داكن بشفافية ٤٪ يختفي على خلفيةٍ داكنة — فتفقد الشاشة عمقها.
  ///    في الداكن نضيء بدل أن نُعتم.
  static Color get waveTint => _dark
      ? const Color(0xFF8FB4FF).withValues(alpha: 0.06)
      : primary500.withValues(alpha: 0.04);

  static Color get waveGlow => _dark
      ? const Color(0xFF4DB3FF).withValues(alpha: 0.10)
      : primary500.withValues(alpha: 0.06);

  /// حدّ البطاقة الجاهز — قرارٌ واحد لا يتفرّق على عشرات الشاشات.
  static Border get cardBorder => Border.all(
        color: border,
        width: _dark ? 1 : 1,
      );
}

// ==========================================
// 🌗 نطاق الوضع — يُعيد البناء عند تبدّله
// ==========================================
/// ⚠️ **لماذا يلزم أصلاً؟** [AppColors] تقرأ متغيّراً عامّاً لا
///    `InheritedWidget`. فالشاشة المدفوعة على `Navigator` لا تعلم بتبدّل
///    الوضع ولا يُعاد بناؤها: يبدّل الطالب وضعَ جهازه فتتغيّر ألوان
///    `Theme` (حدود حقول الإدخال) وتبقى ألوان `AppColors` (الخلفية
///    والبطاقات) على حالها — **نصفُ شاشةٍ داكنة ونصفٌ فاتح**.
///
/// الحلّ الصغير: تشترك الشاشة في المتغيّر نفسه فتُعاد بناؤها معه.
class ThemeScope extends StatelessWidget {
  const ThemeScope({super.key, required this.builder});

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: isDarkModeNotifier,
        builder: (context, _, _) => builder(context),
      );
}
