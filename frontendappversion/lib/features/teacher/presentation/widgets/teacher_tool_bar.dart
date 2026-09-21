import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/teacher_tool.dart';

// ==========================================
// 🧰 شريطُ أدوات المعلم
// ==========================================
// 🎨 **تصميم Figma** — `design/09-teacher/01..04` · إحداثيات مطلقة مقيسة
//    من التصدير (@2x على لوح 390×842):
//
//    الشريط y=138 بارتفاع **41** · هامشٌ جانبيّ 24 · فجوةٌ بين الشرائح **7**
//    الشريحة: r15 · حدٌّ 1 · حشوةٌ أفقية 13 · مربّعُ أيقونةٍ **27×27 r8**
//    وفجوةُ 11 بينه وبين النصّ · النصّ **10**/w900.
//
// 📏 **ولمَ 10 لا 13؟** قيست بمقارنة الحرف بالحرف: ارتفاعُ حبر «خطة درس»
//    في التصدير **10.0** وفي فلاتر عند 13 هو **13.0** — ونفسُ الطريقة
//    عايرتُها على عنوان الشريط (المعلوم أنه 14) فأعطت 14.3. والعرضُ
//    يؤكّدها: عرضُ الشريحة صار 107 كالتصدير بعد أن كان 118.
//    الخاملة: بيضاء بحدّ `#E8EDF3` وحبر `#42526D`.
//    المختارة: تعبئةٌ ٥٠ وحدٌّ ٥٠٠ من سلّم الأداة ([AppColors.toolPalette]).
//
// ⭐ **ولماذا شريطٌ لا أربعُ بطاقات؟** هذا **جوهرُ الفرق** بين ما كان وما
//    صمّمه المصمّم: كانت للمعلّم شاشةُ بوابةٍ فيها أربعُ بطاقاتٍ تفتح
//    الشاتَ في أداة، فيلزمه رجوعٌ وفتحٌ جديدٌ لتبديل الأداة. وفي التصميم
//    **الشاتُ نفسُه هو البيت**، والأدواتُ شريطٌ فوقه يبدّلها بلمسة.
//
// 🔘 **ولا شريحةَ مختارةٌ في البداية** (الإطار ٢): تلك حالةُ «اسأل المساعد»
//    — محادثةٌ مفتوحةٌ بلا بطاقة إعدادات. واللمسُ على المختارة يطويها
//    فيعود إليها. فالشريطُ يختار **أيَّ بطاقةٍ تُفتح**، لا أيُّ أداةٍ تعمل.
class TeacherToolBar extends StatelessWidget {
  const TeacherToolBar({
    super.key,
    required this.open,
    required this.onTap,
  });

  /// الأداةُ التي بطاقتُها مفتوحة — `null` يعني «لا بطاقة» (الإطار ٢).
  final TeacherTool? open;

  final ValueChanged<TeacherTool> onTap;

  /// 📏 مقاساتُ التصميم — مكشوفةٌ كي يقيسها الاختبار بدل أن يُعيد كتابتها.
  static const double height = 41;
  static const double radius = 15;
  static const double gap = 7;
  static const double side = 24;
  static const double iconBox = 27;
  static const double iconBoxRadius = 8;

  @override
  Widget build(BuildContext context) {
    final tools = TeacherToolX.bar;
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: side),
        itemCount: tools.length,
        separatorBuilder: (_, _) => const SizedBox(width: gap),
        itemBuilder: (_, i) => _ToolChip(
          tool: tools[i],
          selected: tools[i] == open,
          onTap: () => onTap(tools[i]),
        ),
      ),
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.tool,
    required this.selected,
    required this.onTap,
  });

  final TeacherTool tool;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.toolPalette(tool.slot);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TeacherToolBar.radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: TeacherToolBar.height,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: selected ? p.fill : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(TeacherToolBar.radius),
            border: Border.all(
                color: selected ? p.accent : AppColors.quizCardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 📐 RTL: المربّعُ أولاً فيقع في **يمين** الشريحة كما في التصدير.
              Container(
                width: TeacherToolBar.iconBox,
                height: TeacherToolBar.iconBox,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.box,
                  borderRadius:
                      BorderRadius.circular(TeacherToolBar.iconBoxRadius),
                ),
                child: tool.iconWidget(size: 16, color: p.ink),
              ),
              const SizedBox(width: 11),
              Text(
                tool.chipLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: selected ? p.ink : AppColors.rowAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
