import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'phosphor.dart';

// ==========================================
// 🔽 قائمة منسدلة موحّدة
// ==========================================
// 🎨 **تصميم Figma** — لوحة إعدادات الجلسة (390:2048):
//    صندوقٌ 316×36 · r9 · تعبئة `#FAFBFB` · حدٌّ خفيف ·
//    نصٌّ 12/w600 `#525252` · وسهمُ `CaretDown` في **بداية** السطر
//    (يسار RTL) بلون `#6C7A71`. وقائمةُ الدرس وحدها تسبقها أيقونة
//    `Notebook` ثنائيةُ اللون بالأزرق.
//
// ⭐ **مصدرٌ واحد لكل القوائم:** تُستعمل في عشرين موضعاً بلوحة الجلسة
//    وحدها — فتعديلُها هنا يضبطها كلها، ونسخُها يفرّق القرار على عشرين.
class ModernDropdown extends StatelessWidget {
  const ModernDropdown({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.leading,
  });

  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  /// 📓 أيقونةٌ ثنائيةُ اللون قبل النصّ.
  ///
  /// 🎨 **في التصميم واحدةٌ فقط تحملها:** قائمةُ **الدرس** وعليها
  ///    `Notebook` بالأزرق الثنائيّ. وما عداها (السنة · القسم · النوع ·
  ///    الوحدة) بلا أيقونة — قِستُ التصدير: سهمٌ ونصٌّ لا ثالثَ لهما.
  ///    فحُذفت أيقونات Material التي كانت على كلٍّ منها.
  final PDIcon? leading;

  /// سطرُ المحتوى — أيقونةٌ (إن وُجدت) ثم النصّ.
  Widget _row(String text) => Row(
        children: [
          if (leading != null) ...[
            PDuo(leading!, size: 16, color: AppColors.primary),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                // 🖋️ **w800 لا w600** — نصُّ القائمة في التصدير أغمقُ
                //    ممّا يخرجه Cairo في فلاتر عند الوزن المكتوب.
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.dropdownInk)),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.fieldFill,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.rowBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          isDense: true,
          // ⬇️ السهم في **بداية** السطر (يسار RTL) كما في التصميم.
          icon: Icon(PI.caretDown.regular,
              size: 16, color: AppColors.dropdownCaret),
          hint: _row(hint),
          value: value,
          dropdownColor: AppColors.elevatedSurface,
          borderRadius: BorderRadius.circular(14),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                  ))
              .toList(),
          // ⚠️ الأيقونةُ في الحالتين — المكتوبةِ والمختارة. وكانت تظهر مع
          //    التلميح وحده فتختفي بمجرّد أن يختار الطالب درساً، فيقفز
          //    النصُّ يميناً 24 بكسلاً بلا سبب.
          selectedItemBuilder: (_) => items.map((e) => _row(e)).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
