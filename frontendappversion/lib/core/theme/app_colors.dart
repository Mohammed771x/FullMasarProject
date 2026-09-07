import 'package:flutter/material.dart';

// 🌙 الوضع المُطبَّق فعلاً (بعد حلّ «اتبع النظام») — تقرأه كل الشاشات.
//    مالكُ القرار `ThemeController`، وهذا مجرّد مرآة له.
final ValueNotifier<bool> isDarkModeNotifier = ValueNotifier(false);

// ==========================================
// 🎨 نظام الألوان
// ==========================================
// ⚠️ **لماذا أُعيدت كتابة اللوحة الداكنة؟**
//    كانت القيم التسع كلها رموز Tailwind الافتراضية بلا تعديل
//    (`slate-900/800/700/50/400/500/100` و`blue-500` و`violet-500`) — وهذه
//    بصمةُ القوالب الجاهزة التي يلمحها المصمّم من أول نظرة.
//
// وثلاث علل **بنيوية** كانت أهمّ من القيم نفسها:
//
//   ① **سُلّم الأسطح كان مقلوباً.** في الفاتح: الخلفية ثم السطح الغائر ثم
//      البطاقة البيضاء — فالغائر أغمق من البطاقة. وفي الداكن كان الغائر
//      (`#334155`) **أفتح** من البطاقة (`#1E293B`)، فيبدو العنصر المُنخفض
//      مرتفعاً وينقلب نحو الواجهة كلّه.
//
//   ② **الظلّ لا يعمل على خلفية سوداء.** ظلٌّ أسود على `#0F172A` غير مرئي،
//      فتفقد كل بطاقة حدَّها وتذوب الشاشة في لوحٍ داكن واحد. الوضع الداكن
//      يعبّر عن الارتفاع بـ**سطحٍ أفتح وخطٍّ شعري**، لا بظلٍّ أغمق.
//
//   ③ **لون الهوية لم يتغيّر بين الوضعين.** أزرقٌ مشبع يُقرأ على الأبيض
//      يهتزّ على الأسود. النظم الحقيقية تُفتّحه وتخفّف تشبّعه في الداكن.
class AppColors {
  // ══════════ الهوية ══════════
  // ⚠️ getters لا ثوابت: اللون نفسه يختلف بين الوضعين.
  static const Color _primaryLight = Color(0xFF3B82F6);
  static const Color _primaryDark = Color(0xFF5B9DFF);
  static const Color _secondaryLight = Color(0xFF8B5CF6);
  static const Color _secondaryDark = Color(0xFFA98BFF);

  static bool get _dark => isDarkModeNotifier.value;

  static Color get primary => _dark ? _primaryDark : _primaryLight;
  static Color get secondary => _dark ? _secondaryDark : _secondaryLight;

  /// تدرّج الهوية. في الداكن **أعمق** لا أفتح: النصّ فوقه أبيض، والتدرّج
  /// الفاتح يهبط بتباينه إلى 3.7:1. والأعمق يرفعه إلى 5.7:1 ويمنع الوهج.
  static LinearGradient get mainGradient => LinearGradient(
        colors: _dark
            ? const [Color(0xFF2F62C4), Color(0xFF6B4FC4)]
            : const [_primaryLight, _secondaryLight],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get bubbleGradient => LinearGradient(
        colors: _dark
            ? const [Color(0xFF2F62C4), Color(0xFF3E77D8)]
            : const [Color(0xFF3B82F6), Color(0xFF60A5FA)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      );

  // ══════════ سُلّم الأسطح ══════════
  // القاعدة الواحدة في الوضعين: **الغائر أغمق من البطاقة، والمرتفع أفتح.**

  /// خلفية الصفحة.
  static Color get bgLight =>
      _dark ? const Color(0xFF10141F) : const Color(0xFFF8FAFC);

  /// البطاقة — السطح الذي يحمل المحتوى.
  static Color get surfaceWhite =>
      _dark ? const Color(0xFF1A2030) : const Color(0xFFFFFFFF);

  /// سطحٌ **غائر داخل البطاقة**: حقل إدخال، شارة، خانة ثانوية.
  static Color get softSurface =>
      _dark ? const Color(0xFF151A28) : const Color(0xFFF1F5F9);

  /// سطحٌ **مرتفع فوق البطاقة**: قائمة منسدلة، ورقة سفلية، حوار.
  static Color get elevatedSurface =>
      _dark ? const Color(0xFF232B3D) : const Color(0xFFFFFFFF);

  /// ✏️ الخطّ الشعري الفاصل — وهو ما يحمل الارتفاع في الوضع الداكن بعد أن
  ///    عجز الظلّ عنه. في الفاتح خفيفٌ جداً لأن الظلّ يكفي هناك.
  static Color get border =>
      _dark ? const Color(0xFF2E3752) : const Color(0xFFE6EBF2);

  // ══════════ النصّ ══════════
  /// ⚠️ ليس أبيض ناصعاً في الداكن: الأبيض على شبه الأسود يُحدث هالةً
  ///    تُتعب العين في القراءة الطويلة، وهذه شاشة درسٍ لا شاشة تنبيه.
  static Color get textPrimary =>
      _dark ? const Color(0xFFE7EBF3) : const Color(0xFF0F172A);

  static Color get textSecondary =>
      _dark ? const Color(0xFF98A2B8) : const Color(0xFF64748B);

  // ══════════ الظلال ══════════
  // 🌙 في الداكن تكاد تختفي — عمداً. الفصلُ هناك مهمّة `border`.
  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: _dark
              ? Colors.black.withValues(alpha: 0.45)
              : _primaryLight.withValues(alpha: 0.12),
          blurRadius: _dark ? 20 : 30,
          offset: Offset(0, _dark ? 6 : 10),
        )
      ];

  static List<BoxShadow> get bubbleShadow => [
        BoxShadow(
          color: _dark
              ? Colors.black.withValues(alpha: 0.35)
              : Colors.black.withValues(alpha: 0.04),
          blurRadius: _dark ? 10 : 15,
          offset: const Offset(0, 4),
        )
      ];

  /// 🎯 **لون التعبئة لعنصرٍ يحمل نصّاً أبيض** (شارة مختارة · زرّ ممتلئ).
  ///
  /// 🔴 **ليس `primary` ولا `secondary`**: هذان فُتِّحا ليُقرآ **كنصٍّ** على
  ///    خلفيةٍ داكنة. ووضعُ نصٍّ أبيض فوقهما يعكس الدور فيهبط التباين إلى
  ///    ٢٫٦:١ — شارةُ «ثالث ثانوي» المختارة تصير أسوأ قراءةً في الداكن منها
  ///    في الفاتح. وهي العلّة نفسها التي عولجت في [mainGradient]، وبقيت
  ///    الشارات خارجها.
  static Color get primaryFill => _dark ? const Color(0xFF2F62C4) : _primaryLight;
  static Color get secondaryFill => _dark ? const Color(0xFF6B4FC4) : _secondaryLight;

  /// 🔘 تدرّج الزرّ الأساسي (تسجيل الدخول · إنشاء الحساب).
  ///
  /// ⚠️ `kBlueBtn` ثابتٌ مشبع (`#3B82F6→#1D4ED8`): يُقرأ جميلاً على الأبيض
  ///    ويهتزّ على الأسود — وهي العلّة نفسها التي فُتّح لأجلها `primary`.
  ///    في الداكن نخفّف تشبّعه ونعمّقه، والنصّ الأبيض فوقه يبقى مقروءاً.
  static LinearGradient get primaryButton => LinearGradient(
        colors: _dark
            ? const [Color(0xFF3B6FD4), Color(0xFF2350A8)]
            : const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
      );

  /// 🖋️ **حبر الهوية** — «مسار» وعناوين بطاقات الترحيب وحقول الإدخال.
  ///
  /// ⚠️ **لماذا وُجد؟** كان `kNavy` (`#173A6D`) ثابتاً يُستعمل في كل ذلك.
  ///    وهو يُقرأ على الأبيض ويكاد **يختفي** على السطح الداكن: عنوان
  ///    بطاقة الترحيب صار غير مقروء، و**نصُّ حقل الإدخال صار غير مرئيّ
  ///    أصلاً** — يكتب الطالب بريده فلا يرى ما يكتب.
  ///    والقاعدة هنا كقاعدة `primary`: اللون يتبع الوضع لا يثبت عليه.
  static Color get brandInk =>
      _dark ? const Color(0xFFDCE6FA) : const Color(0xFF173A6D);

  /// 🌊 لون الخلفية الموجية الخافتة (`SoftWaveBackground`).
  ///
  /// ⚠️ أزرقٌ داكن بشفافية ٤٪ يختفي تماماً على خلفيةٍ داكنة — فتفقد
  ///    الشاشة عمقها وتصير لوحاً مسطّحاً. في الداكن نضيء بدل أن نُعتم.
  static Color get waveTint => _dark
      ? const Color(0xFF8FB4FF).withValues(alpha: 0.06)
      : const Color(0xFF1D4ED8).withValues(alpha: 0.04);

  static Color get waveGlow => _dark
      ? const Color(0xFF5B9DFF).withValues(alpha: 0.10)
      : const Color(0xFF3B82F6).withValues(alpha: 0.06);

  /// 🔵 لون النصّ **على سطحٍ أبيض دائماً** — كالقرص داخل بطاقة التدرّج.
  ///
  /// ⚠️ لا يصلح `primary` هنا: تباينه على الأبيض 3.7:1 في الفاتح، وهبط إلى
  ///    2.7:1 بعد تفتيحه للوضع الداكن. والقرص أبيضُ في الوضعين، فاللون
  ///    الذي فوقه لا يتبع الوضع — بل يثبت داكناً كي يُقرأ في الحالتين.
  static const Color onWhite = Color(0xFF1D4ED8);

  /// حدّ البطاقة الجاهز — يُستعمل في `SoftCard` وكل سطحٍ مماثل، فلا يتفرّق
  /// القرار على عشرات الشاشات.
  static Border get cardBorder => Border.all(
        color: border,
        width: _dark ? 1 : 0.8,
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
