import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/chat_controller.dart';

// ==========================================
// 💡 شرائح الاقتراحات
// ==========================================
// 🎨 **تصميم Figma** — «الرفيق الذاكي» (390:2048 عند y=707):
//    شريطٌ أفقيّ بارتفاع 27 · كل شريحة r12 · تعبئة `#F8FAFC` وحدّ
//    `#E2E8F0` · نصّها 10/w600 `#45556C` · والمقترحةُ الآن بتعبئة
//    `#E6F4FF` وحدّ `#0092FF`.
//
// 📝 **النصوص من التطبيق لا من التصميم** (قاعدة المالك): المصمّم كتب
//    «⚡ لخص أهم 5 قوانين» و«🎯 حل نموذج امتحان وزاري مؤتمت» — وهي
//    عيّنات. والاقتراحاتُ الحقيقية يولّدها [ChatController.suggestions]
//    من المادة والوضع والدرس المختار، وتتبدّل بعد كل جواب.
class ModeSuggestions extends StatelessWidget {
  const ModeSuggestions({super.key, required this.controller});

  final ChatController controller;

  @override
  Widget build(BuildContext context) {
    // ⛔ **البارزُ ليس شريحة.** الاقتراحُ الذي عليه `primary` يُعرض زرّاً
    //    كبيراً فوق المحادثة ([_PrimaryAction])، فإبقاؤه هنا يكرّر «اشرح لي»
    //    مرّتين على شاشةٍ واحدة — رأيتُه في المحاكي بعد اختيار الدرس.
    final items = controller.suggestions.where((s) => !s.primary).toList();
    // 🛡️ لا اقتراحات ⇒ لا شريطَ فارغ يأكل ارتفاعاً من المحادثة.
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: SuggestionChip.height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final s = items[i];
          // ⭐ **الأولى مميّزة** — كما في التصميم: شريحةُ أوّلِ السطر
          //    (يمينُه في RTL) بتعبئةٍ زرقاءَ خفيفةٍ وحدٍّ بلون الهوية.
          final featured = i == 0;
          return SuggestionChip(
            label: s.label,
            featured: featured,
            onTap: () => controller.applySuggestion(s),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 🏷️ شريحةُ اقتراحٍ واحدة — مفردةُ التصميم المشتركة
// ══════════════════════════════════════════════════
/// 27 · r12 · نصٌّ 10/w600. والأولى «مميّزة»: تعبئةٌ `#E6F4FF` وحدٌّ
/// بلون الهوية — كما في التصدير.
///
/// ⭐ **ويستعملها قسمُ المعلم أيضاً**: شرائحُه في التصدير هي هذه بعينها،
///    وكانت عنده `ActionChip` بارتفاع 42 من مادّة جوجل — شريطان مختلفان
///    في شاشةٍ واحدة.
class SuggestionChip extends StatelessWidget {
  const SuggestionChip({
    super.key,
    required this.label,
    required this.onTap,
    this.featured = false,
  });

  static const double height = 27;

  final String label;
  final VoidCallback onTap;
  final bool featured;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: featured
                  ? AppColors.primaryTintSurface
                  : AppColors.chipSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: featured ? AppColors.primary : AppColors.rowBorder),
            ),
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: featured ? AppColors.primary : AppColors.chipInk,
              ),
            ),
          ),
        ),
      );
}
