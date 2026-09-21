import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/phosphor.dart';

// ==========================================
// 🧩 لغةُ «المنح» البصرية — قطعةٌ واحدة لخمس شاشات
// ==========================================
// 🎨 **المصدر:** `design/06-scholarships/` (خمسُ شاشاتٍ في ثماني تصديرات).
//    وكلُّ رقمٍ هنا **مقيسٌ من بكسلات التصدير** (@2x · إطار 390×844):
//
//      الهامش    24 · المسافة بين البطاقات 16
//      البطاقة   r24 · حدٌّ `#E8EDF3` · حشوة 16
//      الوسم     h24 · r8  · حدٌّ بلون حبره · فجوة 6
//      شريحةُ فلتر h36 · r18 · فجوة 6 (وفي شاشة التفاصيل فجوة 4)
//      حقلُ البحث h50 · r16 · حدٌّ `#E4EAF1`
//      الزرّ      h46 · r16 — وزرُّ الكرت الصغير h34
//      المربّع    40×40 · r14 (أزرارُ الرؤوس)
//      الرأس     الأيقونة 40 يميناً ثم فراغ 12 ثم العنوان 28/w900
//      البانر    h92 · r15 · دائرةٌ 24 يساراً ومربّعٌ 42 يميناً
//
// ⭐ **لماذا ملفٌّ مشترك؟** القائمةُ والتفاصيلُ والمساعدُ والدرج تستعمل
//    البطاقةَ نفسها والوسمَ نفسه والزرَّ نفسه. نسخُها خمس مرّات يعني
//    افتراقَها عند أوّل تعديل — وهي غلطةُ الحوارات قبل `MasarDialog`.

/// 📏 ثوابتُ القياس — تُقرأ من الشاشات بدل أن تُكرَّر أرقاماً عارية.
class SchMetrics {
  SchMetrics._();

  static const double margin = 24;
  static const double gap = 16;
  static const double cardRadius = 24;
  static const double cardPad = 16;
  static const double tagHeight = 24;
  static const double tagRadius = 8;
  static const double tagGap = 6;
  static const double filterHeight = 36;
  static const double filterRadius = 18;
  static const double searchHeight = 50;
  static const double searchRadius = 16;
  static const double buttonHeight = 46;
  static const double buttonRadius = 16;
  static const double smallButtonHeight = 34;
  static const double squareButton = 40;
  static const double squareRadius = 14;
  static const double flag = 38;
  static const double bookmark = 33;
  static const double bannerHeight = 92;
  static const double bannerRadius = 15;
  static const double heroHeight = 165;
}

// ══════════════════════════════════════════════════
// • النقطةُ تُزال — الصفُّ نفسُه هو النقطة
// ══════════════════════════════════════════════════
/// 🔴 **علّةُ المالك (2026-09-21):** «في نقطة، بعدين تغطية كامل الرسوم
///    الدراسية — ماشي داعي النقطة هذه».
///
/// نصوصُ اللوحة مكتوبةٌ بنقاطٍ يدويّة («• تغطية كاملة…») لأنها كانت
/// تُعرض فقرةً واحدة. وصارت الآن **صفّاً لكلّ بند** بأيقونته الخاصّة،
/// فالنقطةُ تتكرّر مرّتين: رسماً ونصّاً. تُزال من **العرض** وحده —
/// والبيانات في اللوحة كما كتبها المالك، لا نلمسها.
String stripBullet(String text) =>
    text.replaceFirst(RegExp(r'^\s*[•\-–—*]\s*'), '').trim();

// ══════════════════════════════════════════════════
// 🎯 المعدّلُ المطلوب — يُستخرَج ولا يُختلَق
// ══════════════════════════════════════════════════
/// 📊 **سطرُ «المعدل المطلوب» في أسفل الكرت** (أمرُ المالك 2026-09-21:
///    «خلاص خله fixed إنه المعدل، نفس اللي موجود في التصميم»).
///
/// ⚠️ **ولا حقلَ للمعدّل في بطاقة المنحة** — لا في النموذج ولا في اللوحة
///    ولا في الخادم. وكتابةُ رقمٍ ثابتٍ في الكود تعني عرضَ **معدّلٍ
///    مختلَق** على طالبٍ قد يبني عليه قراره، وهذا أسوأُ من لا شيء.
///
/// ✅ فيُقرأ من شروط المنحة نفسِها: كلُّ نسبةٍ مئويّةٍ في `requirements`
///    ثم **أصغرُها** — لأن الشروط تسرد حدّاً أدنى لكل مرحلة
///    («الدبلوم والبكالوريوس: 70%. الماجستير: 75%») والمطلوبُ للدخول
///    هو الأدنى. والنطاق 40–100 يمنع التقاط أعدادٍ ليست معدّلات.
///
/// وحين لا تذكرها المنحة يُقال ذلك صراحةً بدل اختلاق رقم.
String? minGpaOf(List<String> requirements) {
  final matches = RegExp(r'(\d{2,3})\s*%')
      .allMatches(requirements.join(" "))
      .map((m) => int.tryParse(m.group(1) ?? ""))
      .whereType<int>()
      .where((v) => v >= 40 && v <= 100)
      .toList();
  if (matches.isEmpty) return null;
  matches.sort();
  return "${matches.first}%+";
}

/// 📊 **ما يُكتب في سطر «المعدل المطلوب»** — الحقلُ أوّلاً، ثم الشروط.
///
/// 🔴 **أمرُ المالك (2026-09-21):** أضاف حقلاً صريحاً للمعدّل في اللوحة،
///    فصار عندنا مصدران: ما كتبه المشرف، وما يُستخرَج من نصّ الشروط.
///
/// ⚖️ **والمكتوبُ يسبق المستخرَج دائماً.** المشرفُ يعرف منحتَه، والتعبيرُ
///    النمطيّ يقرأ نصّاً كُتب لعينٍ بشرية: منحةٌ شرطُها «خصم 30% للمتفوّقين»
///    لا معدَّلَ فيها إطلاقاً. فالاستخراجُ **احتياطٌ لمنحةٍ لم يُملأ حقلُها
///    بعد** — لا بديلٌ عنه.
///
/// ⚠️ وحين يعجز الاثنان تُعاد `null` ويقول الكرتُ «غير محدّد»: رقمٌ
///    مختلَقٌ أمام طالبٍ يبني عليه قرارَه أسوأُ من الصمت.
String? gpaTextOf(int minGpa, List<String> requirements) =>
    minGpa > 0 ? "$minGpa%+" : minGpaOf(requirements);

// ══════════════════════════════════════════════════
// 🪧 رأسُ الصفحة — العنوان ورسمُه
// ══════════════════════════════════════════════════
/// 📐 مقيسٌ من `01-المنح`: الرسمُ في **يمين** السطر (حبرُه 54×40 عند
///    الهامش 24)، ثم فراغ 12، ثم «المنح» 28/w900 بحبر `#21302A`.
///
/// 🎨 **والرسمُ أصلُ المصمّم نفسُه لا نظيرٌ من مكتبة أيقونات.**
///    قاعدةُ المالك: «الشعار والأيقونات كامل نفس اللي موجودة في التصميم».
///    وُجد في تصديرِ الأصول (`design/assets/`) بالمطابقة البصرية، ونُقل
///    إلى `assets/art/art_scholarship.png` كما نُقل `art_analysis` قبله.
class SchHeader extends StatelessWidget {
  const SchHeader({
    super.key,
    required this.title,
    this.art = "assets/art/art_scholarship.png",
    this.onBack,
  });

  final String title;
  final String art;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          // ⚠️ في RTL أوّلُ ابنٍ هو **الأيمن** — وهناك الرسمُ في التصميم.
          SizedBox(
            width: 54,
            height: 44,
            child: Image.asset(art, fit: BoxFit.contain),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: AppColors.headingInk,
              ),
            ),
          ),
          if (onBack != null)
            SchSquareButton(icon: PI.arrowRight, onTap: onBack!),
        ],
      );
}

// ══════════════════════════════════════════════════
// ⬜ مربّعُ 40 — أزرارُ الرؤوس
// ══════════════════════════════════════════════════
/// 📐 من رأس شاشة المساعد: 40×40 · r14 · حدٌّ `#E8EDF3` · حبرٌ `#003359`.
class SchSquareButton extends StatelessWidget {
  const SchSquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.ink,
    this.fill,
    this.border = true,
    this.iconSize = 20,
    this.badge,
    this.tooltip,
  });

  final PIcon icon;
  final VoidCallback onTap;
  final Color? ink;
  final Color? fill;
  final bool border;
  final double iconSize;

  /// شارةُ عددٍ صغيرة أعلى الزرّ (عددُ المحادثات في التصميم).
  final String? badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Color inkColor = ink ?? AppColors.primary990Ink;
    Widget button = Material(
      color: fill ?? AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(SchMetrics.squareRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SchMetrics.squareRadius),
        child: Container(
          width: SchMetrics.squareButton,
          height: SchMetrics.squareButton,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(SchMetrics.squareRadius),
            border: border
                ? Border.all(color: AppColors.quizCardBorder)
                : null,
          ),
          child: Icon(icon.regular, size: iconSize, color: inkColor),
        ),
      ),
    );

    if (badge != null) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 18),
              height: 18,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: AppColors.quizCardBorder),
              ),
              child: Text(
                badge!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      );
    }
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

// ══════════════════════════════════════════════════
// 🗂️ البطاقة — بيضاء · r24 · حدٌّ رفيع
// ══════════════════════════════════════════════════
class SchCard extends StatelessWidget {
  const SchCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SchMetrics.cardPad),
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(SchMetrics.cardRadius),
        border: Border.all(color: AppColors.quizCardBorder),
      ),
      child: child,
    );
    if (onTap == null) return decorated;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SchMetrics.cardRadius),
        child: decorated,
      ),
    );
  }
}

/// 💧 سطحٌ باهتٌ بلون الهوية يحمل نصّاً طويلاً — «نبذة» و«المجالات».
class SchTintCard extends StatelessWidget {
  const SchTintCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(SchMetrics.cardPad),
    this.radius = SchMetrics.cardRadius,
  });

  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: AppColors.schTint,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      );
}

// ══════════════════════════════════════════════════
// 🏷️ الوسم — h24 · r8 · حدٌّ بلون حبره
// ══════════════════════════════════════════════════
/// 📐 قِستُ الكرتَ الثاني لا الأوّل: الأوّلُ في التصدير مُطّاطٌ («fill
///    container» في Figma) فخرجت وسومُه الثلاثة **متساويةَ العرض** —
///    وهو ما لا يصمد أمام نصٍّ حقيقي. والبقيّةُ كلُّها بعرض محتواها.
class SchTag extends StatelessWidget {
  const SchTag({
    super.key,
    required this.label,
    required this.fill,
    required this.ink,
    this.icon,
    this.maxWidth,
    this.center = false,
  });

  final String label;
  final Color fill;
  final Color ink;
  final PIcon? icon;

  /// حدٌّ أعلى للعرض — تخصّصٌ طويل لا يجوز أن يدفع الوسمَ خارج الكرت.
  final double? maxWidth;

  /// في شريط التفاصيل تملأ الوسومُ السطرَ بالتساوي، فيُوسَّط محتواها.
  final bool center;

  @override
  Widget build(BuildContext context) {
    final body = Container(
      height: SchMetrics.tagHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(SchMetrics.tagRadius),
        border: Border.all(color: ink),
      ),
      child: Row(
        mainAxisSize: center ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment:
            center ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon!.regular, size: 12, color: ink),
            const SizedBox(width: 5),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          ),
        ],
      ),
    );
    if (maxWidth == null) return body;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth!),
      child: body,
    );
  }
}

// ══════════════════════════════════════════════════
// ⚪ شريحةُ الفلتر — h36 · r18
// ══════════════════════════════════════════════════
class SchFilterChip extends StatelessWidget {
  const SchFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? AppColors.primaryFill : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(SchMetrics.filterRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SchMetrics.filterRadius),
          child: Container(
            height: SchMetrics.filterHeight,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SchMetrics.filterRadius),
              border: Border.all(
                  color: selected
                      ? AppColors.primaryFill
                      : AppColors.quizCardBorder),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : AppColors.chipInk,
              ),
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🔤 عنوانُ قسمٍ داخل الصفحة — 16/w900
// ══════════════════════════════════════════════════
class SchSectionTitle extends StatelessWidget {
  const SchSectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.headingInk,
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🔘 الأزرار — h46 · r16
// ══════════════════════════════════════════════════
/// 🌙 **`primaryFill` لا `primary`.** الثاني فُتِّح كي **يُقرأ نصّاً** على
///    خلفيةٍ داكنة، ووضعُ أبيضَ فوقه يهبط بالتباين إلى 2.1:1 — أشهرُ
///    زلّةٍ في الوضع الداكن، ورُصدت في قسم «اختبر نفسك» في المحاكي.
class SchPrimaryButton extends StatelessWidget {
  const SchPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.height = SchMetrics.buttonHeight,
    this.gradient,
  });

  final String label;
  final VoidCallback? onTap;
  final PIcon? icon;
  final double height;

  /// تدرّجٌ بدل اللون المصمت — زرُّ «اسأل مساعد المنحة» وحدَه في التصدير.
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) => Material(
        color: gradient != null && onTap != null
            ? Colors.transparent
            : (onTap == null
                ? AppColors.quizButtonIdle
                : AppColors.primaryFill),
        borderRadius: BorderRadius.circular(SchMetrics.buttonRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SchMetrics.buttonRadius),
          child: Container(
            height: height,
            decoration: gradient != null && onTap != null
                ? BoxDecoration(
                    gradient: gradient,
                    borderRadius:
                        BorderRadius.circular(SchMetrics.buttonRadius))
                : null,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon!.regular, size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// زرٌّ ثانويّ — تعبئةٌ باهتة بلون الهوية وحبرٌ داكنٌ منها.
class SchGhostButton extends StatelessWidget {
  const SchGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.height = SchMetrics.buttonHeight,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onTap;
  final PIcon? icon;
  final double height;

  /// في شريط التفاصيل السفلي يُرسم بحدٍّ وخلفيةٍ باهتة معاً.
  final bool outlined;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.schBlueFill,
        borderRadius: BorderRadius.circular(SchMetrics.buttonRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SchMetrics.buttonRadius),
          child: Container(
            height: height,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SchMetrics.buttonRadius),
              border:
                  outlined ? Border.all(color: AppColors.schBlueInk) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.schBlueInk,
                    ),
                  ),
                ),
                if (icon != null) ...[
                  const SizedBox(width: 8),
                  Icon(icon!.regular, size: 18, color: AppColors.schBlueInk),
                ],
              ],
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🔎 حقلُ البحث — h50 · r16
// ══════════════════════════════════════════════════
class SchSearchField extends StatelessWidget {
  const SchSearchField({
    super.key,
    required this.controller,
    required this.hint,
    required this.onChanged,
    required this.onClear,
    required this.showClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final bool showClear;

  @override
  Widget build(BuildContext context) => Container(
        height: SchMetrics.searchHeight,
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(SchMetrics.searchRadius),
          border: Border.all(color: AppColors.schSearchBorder),
        ),
        child: Row(
          children: [
            // ⚠️ في RTL أوّلُ ابنٍ هو الأيمن — وهناك العدسةُ في التصدير.
            const SizedBox(width: 14),
            Icon(PI.magnifyingGlass.regular,
                size: 22, color: AppColors.chipInk),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                decoration: InputDecoration(
                  isCollapsed: true,
                  // ⚠️ **الخمسةُ جميعاً، لا `border` وحدها.** سمةُ التطبيق
                  //    العامّة (`inputDecorationTheme`) تملأ الحقلَ برماديٍّ
                  //    `#F5F5F5` **وتعطيه `enabledBorder`/`focusedBorder`
                  //    مستديرَين**، فظهر **مربّعٌ داخل مربّع** في حقل بحثٍ
                  //    التصميمُ يرسمه إطاراً أبيضَ واحداً (علّةُ المالك
                  //    2026-09-21). نفسُ الفخّ الذي عُولج في شريط كتابة
                  //    قسم التعليم حرفاً بحرف.
                  filled: false,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: AppColors.schMutedInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (showClear)
              IconButton(
                icon: Icon(PI.x.regular, size: 16, color: AppColors.chipInk),
                onPressed: onClear,
              )
            else
              const SizedBox(width: 14),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════
// 🔴 بطاقةُ الإلحاح — «تُغلق بعد N يوماً»
// ══════════════════════════════════════════════════
/// 📐 من `01-المنح`: بطاقةٌ 344×92 · r15 · تدرّجٌ أحمر · مربّعٌ 42/r14
///    بأيقونةِ ساعةٍ في **يمينها**، وسهمُ متابعةٍ 24 دائريٌّ في يسارها،
///    وشارةُ «عاجل» 34×19 بجانب العنوان.
///
/// ⭐ **والمحتوى من التطبيق لا من التصميم**: المصمّم كتب «منحة الأزهر…»
///    عيّنةً، والنصُّ الحقيقيُّ هو تنبيهُ [ScholarshipFavorites] عن أقربِ
///    منحةٍ يتابعها الطالب إلى الإغلاق.
class SchUrgentBanner extends StatelessWidget {
  const SchUrgentBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(SchMetrics.bannerRadius),
          child: Container(
            height: SchMetrics.bannerHeight,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [Color(0xFFC10107), Color(0xFFAA0006)],
              ),
              borderRadius: BorderRadius.circular(SchMetrics.bannerRadius),
            ),
            child: Row(
              children: [
                // ⏰ المربّعُ في اليمين (أوّلُ ابنٍ في RTL) كما في التصدير.
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(PI.clock.regular, size: 20, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            height: 19,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(PI.caretLeft.regular,
                      size: 13, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🕳️ الحالةُ الفارغة — أيقونةٌ ونصٌّ وزرُّ إعادة
// ══════════════════════════════════════════════════
class SchEmptyState extends StatelessWidget {
  const SchEmptyState({
    super.key,
    required this.icon,
    required this.text,
    this.onRetry,
    this.retryLabel = "أعد المحاولة",
  });

  final PIcon icon;
  final String text;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const SizedBox(height: 60),
          Icon(icon.regular, size: 56, color: AppColors.schMutedInk),
          const SizedBox(height: 16),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.8,
              fontWeight: FontWeight.w600,
              color: AppColors.schMutedInk,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
              child: SchPrimaryButton(label: retryLabel, onTap: onRetry),
            ),
          ],
        ],
      );
}
