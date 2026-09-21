import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../../core/widgets/phosphor.dart';

// ==========================================
// 🧩 لغةُ «اختبر نفسك» البصرية — قطعةٌ واحدة لأربع شاشات
// ==========================================
// 🎨 **المصدر:** `design/05-quiz/` — الشاشات التسع. وكلُّ رقمٍ هنا **مقيسٌ
//    من بكسلات التصدير** (@2x · إطار 390×844) لا مقدَّرٌ بالعين:
//
//      الهامش   24 · المسافة بين البطاقات 16
//      البطاقة  r16 · حدٌّ `#E8EDF3` · حشوة 16 (وفي بطاقة العدد 13)
//      الشريحة  h37 · r12 · حدٌّ `#E7ECF2` · تعبئة `#F8FAFC`
//      الصفّ    h40 · r12 · حدٌّ `#E2E8F0`
//      الخيار   h46 · r12
//      الزرّ     h58 · r16 — لا 47 كما في بقيّة التطبيق؛ قِستُه مرّتين.
//      المربّع   32×32 · r10 (الإغلاق وشارة النقاط)
//
// ⭐ **لماذا ملفٌّ مشترك؟** الأربعُ تستعمل البطاقة نفسها والشريحة نفسها
//    والزرّ نفسه. نسخُها أربع مرّات يعني افتراقَها عند أوّل تعديل — وهي
//    الغلطةُ التي وقعت في الحوارات قبل `MasarDialog`.

/// 📏 ثوابتُ القياس — تُقرأ من الشاشات بدل أن تُكرَّر أرقاماً عارية.
class QuizMetrics {
  QuizMetrics._();

  static const double margin = 24;
  static const double gap = 16;
  static const double cardRadius = 16;
  static const double cardPad = 16;
  static const double chipHeight = 37;
  static const double chipRadius = 12;
  static const double rowHeight = 40;
  static const double optionHeight = 46;
  static const double buttonHeight = 58;
  static const double buttonRadius = 16;
  static const double squareButton = 32;
}

// ══════════════════════════════════════════════════
// 🪧 رأسُ الصفحة — العنوان وأيقونته
// ══════════════════════════════════════════════════
/// 📐 مقيسٌ من `03-اختبر نفسك`: الأيقونةُ في **يمين** السطر (36×36 عند
///    الهامش 24)، ثم فراغ 12، ثم العنوان 22/w900 — والكلُّ محاذٍ لليمين.
///
/// 🎨 **الأيقونة:** رسمها المصمّم مجسّمةً (أصلٌ نقطيّ)، وقاعدةُ المشروع
///    أن نظيرَها من مكتبته هو المعتمد — تماماً كما فُعل في الشريط السفلي
///    حيث صارت `ListChecks` من Phosphor.
///
/// ⬅️ **وزرُّ الرجوع يظهر حين يكون له معنى فقط**: الشاشة تُفتح تبويباً من
///    الشريط السفلي (لا شيءَ خلفها) وتُفتح مدفوعةً من التحليل والمحادثة.
///    سهمٌ لا يرجع إلى شيء كان يظهر في الحالة الأولى.
class QuizHeader extends StatelessWidget {
  const QuizHeader({
    super.key,
    required this.title,
    this.icon = PD.listChecks,
    this.art = "assets/art/art_checklist.png",
    this.onBack,
    this.fontSize = 22,
    this.iconSize = 36,
  });

  final String title;
  final PDIcon icon;

  /// 🎨 **رسمُ المصمّم نفسُه حين يوجد.** قاعدةُ المالك (2026-09-21):
  ///    «الشعار والأيقونات كامل نفس اللي موجودة في التصميم». ورسمُ رأس
  ///    «اختبر نفسك» موجودٌ في تصدير الأصول، فيُعرض هو؛ و`icon` يبقى
  ///    للرؤوس التي رسمها المصمّم أيقونةً صغيرة (شاشة المراجعة).
  final String? art;
  final VoidCallback? onBack;

  /// 📏 22 في شاشة الإعداد و17 في «راجع إجاباتك» — قِستُ الاثنين.
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          // ⚠️ في RTL أوّلُ ابنٍ هو **الأيمن** — وهناك الرسمُ في التصميم.
          if (art != null)
            SizedBox(
              width: iconSize + 8,
              height: iconSize + 4,
              child: Image.asset(art!, fit: BoxFit.contain),
            )
          else
            PDuo(icon, size: iconSize, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w900,
                  color: AppColors.panelTitle),
            ),
          ),
          if (onBack != null) QuizSquareButton(icon: PI.arrowRight, onTap: onBack!),
        ],
      );
}

// ══════════════════════════════════════════════════
// ⬜ مربّعُ 32 — الإغلاق والرجوع
// ══════════════════════════════════════════════════
class QuizSquareButton extends StatelessWidget {
  const QuizSquareButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.ink,
  });

  final PIcon icon;
  final VoidCallback onTap;
  final Color? ink;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: QuizMetrics.squareButton,
            height: QuizMetrics.squareButton,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.quizCardBorder),
            ),
            child: Icon(icon.regular,
                size: 16, color: ink ?? AppColors.inputBarIcon),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🗂️ البطاقة البيضاء
// ══════════════════════════════════════════════════
class QuizCard extends StatelessWidget {
  const QuizCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(QuizMetrics.cardPad),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(QuizMetrics.cardRadius),
          border: Border.all(color: AppColors.quizCardBorder),
          // 🌑 الظلُّ لا يُرى على الأسود — فالفصلُ هناك مهمّةُ الحدّ وحده.
          boxShadow: isDarkModeNotifier.value ? const [] : AppColors.softShadow,
        ),
        child: child,
      );
}

/// عنوانٌ صغيرٌ داخل البطاقة — «١. اختر المادة الدراسية:».
class QuizCardLabel extends StatelessWidget {
  const QuizCardLabel(this.text, {super.key, this.trailing});

  final String text;

  /// شارةٌ في **يسار** السطر (شارة «تم اختيار ن» في التصميم).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: AppColors.panelTitle));
    if (trailing == null) {
      return Align(alignment: Alignment.centerRight, child: label);
    }
    return Row(
      children: [
        Expanded(child: label),
        const SizedBox(width: 8),
        trailing!,
      ],
    );
  }
}

/// شارةُ العدّ — `#D4E4FE` بحبر `#155DFC`، r6، ارتفاع 23.
class QuizBadge extends StatelessWidget {
  const QuizBadge(this.text, {super.key, this.fill, this.ink});

  final String text;
  final Color? fill;
  final Color? ink;

  @override
  Widget build(BuildContext context) => Container(
        height: 23,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 9),
        decoration: BoxDecoration(
          color: fill ?? AppColors.quizBadgeFill,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: ink ?? AppColors.quizBadgeInk)),
      );
}

// ══════════════════════════════════════════════════
// 🔘 شريحةُ اختيار — المادة وعدد الأسئلة
// ══════════════════════════════════════════════════
class QuizChip extends StatelessWidget {
  const QuizChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.fontSize = 11,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final double fontSize;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QuizMetrics.chipRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: QuizMetrics.chipHeight,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.quizTint : AppColors.quizChipFill,
            borderRadius: BorderRadius.circular(QuizMetrics.chipRadius),
            border: Border.all(
                color:
                    selected ? AppColors.primary : AppColors.quizChipBorder),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.primary : AppColors.chipInk),
          ),
        ),
      );
}

/// صفُّ شرائحَ متساويةِ العرض — بفراغٍ 8 كما في التصميم.
class QuizChipRow extends StatelessWidget {
  const QuizChipRow({super.key, required this.children, this.spacing = 8});

  final List<Widget> children;
  final double spacing;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(width: spacing),
            Expanded(child: children[i]),
          ],
        ],
      );
}

// ══════════════════════════════════════════════════
// 🔵 الزرّ الأساسي — h58 r16
// ══════════════════════════════════════════════════
/// ⚠️ **المعطَّلُ أزرقُ فاتحٌ بحبرٍ أبيض** (`#B0DDFF`) لا رماديّ — قِستُه في
///    `02-سؤال1`. والفرقُ مقصود: الزرُّ يبقى زرَّ الشاشة، ويُقرأ أنه ينتظر
///    شيئاً منك لا أنه معطوب.
class QuizPrimaryButton extends StatelessWidget {
  const QuizPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.enabled = true,
    this.fill,
    this.ink,
    this.height = QuizMetrics.buttonHeight,
  });

  final String label;
  final VoidCallback? onTap;
  final PIcon? icon;
  final bool enabled;
  final Color? fill;
  final Color? ink;
  final double height;

  @override
  Widget build(BuildContext context) {
    // 🌙 **`primaryFill` لا `primary`.** الثاني هو الأزرقُ المفتَّح كي
    //    **يُقرأ نصّاً** على خلفيةٍ داكنة، ووضعُ أبيضَ فوقه يهبط بالتباين
    //    إلى 2.1:1 — أشهرُ زلّةٍ في الوضع الداكن، ورُصدت هنا في المحاكي.
    //    و`primaryFill` هو التوكن المُعمَّق الذي **يَحمل** النصّ الأبيض.
    final Color bg =
        enabled ? (fill ?? AppColors.primaryFill) : AppColors.quizButtonIdle;
    final Color fg = enabled ? (ink ?? Colors.white) : Colors.white;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(QuizMetrics.buttonRadius),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(QuizMetrics.buttonRadius),
        child: SizedBox(
          height: height,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 📐 في التصميم الأيقونةُ **يمينَ** النصّ بفراغ 11.
              if (icon != null) ...[
                Icon(icon!.bold, size: 18, color: fg),
                const SizedBox(width: 11),
              ],
              Flexible(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 💬 فقاعةُ الروبوت — رأسُ شاشة الإعداد
// ══════════════════════════════════════════════════
/// 📐 مقيسة: الروبوت 64 عند الهامش الأيمن، والفقاعة `#E6F4FF` r18 بحشوة
///    أفقية 14 ورأسية 12، ونصُّها 16/w600 بارتفاع سطر 1.35.
class QuizRobotBubble extends StatelessWidget {
  const QuizRobotBubble({super.key, required this.child, this.robotSize = 64});

  final Widget child;
  final double robotSize;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ⚠️ RTL: الروبوتُ أوّلُ ابنٍ ⇒ يجلس يميناً كما في التصميم.
          MasarRobot(size: robotSize, pose: MasarRobotPose.fly),
          Expanded(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.quizTint,
                borderRadius: BorderRadius.circular(18),
              ),
              child: child,
            ),
          ),
        ],
      );
}
