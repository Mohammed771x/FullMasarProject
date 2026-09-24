import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'phosphor.dart';

// ==========================================
// 🔢 مِعدادٌ بزرّين — لا لوحةَ مفاتيح
// ==========================================
// 🔴 **بلاغُ المالك (٢٠٢٦-٠٩-٢٣):** «في الوزاري لما أبغى خمس قطع، أضغط على
//    الرقم فيطلع الكيبورد وتقفل إعدادات الجلسة».
//
//    كان العددُ حقلَ كتابةٍ داخل البطاقة. ولمسُه يرفع الكيبورد، والبطاقةُ
//    **تُطوى مع الكيبورد** (قرارٌ صحيح: من يكتب في المحادثة لا يضبط
//    إعداداته) — فيختفي الحقلُ من تحت الإصبع قبل أن يُكتب فيه حرف.
//
// ✅ **والعلاجُ من الجذر:** عددٌ صغيرٌ بين حدَّين لا يحتاج كيبورداً أصلاً.
//    زرّا «−» و«+» كمِعداد iOS — لمسةٌ لكل خطوة، والحدّانِ ظاهران بتعطيل
//    الزرّ عندهما. ومعه سقطت ثلاثُ علل كانت تنتظر: «٠» و«-٣» و«٩٩٩٩٩»
//    كانت كلُّها تُكتب في الحقل وتُرسل كما هي.
//
// 🔗 **والقيمةُ في `TextEditingController` نفسِه** الذي كان الحقلُ يكتب فيه:
//    الإرسالُ يقرأ `.text` كما كان، فلا سطرَ في المتحكّم تغيّر.
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.controller,
    required this.fallback,
    this.min = 1,
    this.max = 20,
  });

  final TextEditingController controller;

  /// القيمةُ حين يكون النصُّ فارغاً أو غيرَ رقم.
  final int fallback;
  final int min;
  final int max;

  int get _value {
    final v = int.tryParse(controller.text.trim()) ?? fallback;
    return v.clamp(min, max);
  }

  void _set(int v) => controller.text = '${v.clamp(min, max)}';

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, _, _) {
          final v = _value;
          return Container(
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.softSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ↔️ في العربية أوّلُ ابنٍ يمينَ الصفّ: «+» يميناً كما يقرأ الطالب.
                _StepButton(
                  icon: PI.plus.bold,
                  semantic: 'زِد',
                  onTap: v < max ? () => _set(v + 1) : null,
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '$v',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _StepButton(
                  icon: PI.minus.bold,
                  semantic: 'أنقِص',
                  onTap: v > min ? () => _set(v - 1) : null,
                ),
              ],
            ),
          );
        },
      );
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.semantic, this.onTap});

  final IconData icon;
  final String semantic;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: true,
        label: semantic,
        enabled: onTap != null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          // 📏 ٤٤ عرضاً — حدُّ اللمس المريح، والصفُّ نفسُه ٣٦ ارتفاعاً.
          child: SizedBox(
            width: 44,
            height: 36,
            child: Icon(
              icon,
              size: 16,
              color: onTap == null
                  ? AppColors.textSecondary.withValues(alpha: 0.35)
                  : AppColors.primary,
            ),
          ),
        ),
      );
}
