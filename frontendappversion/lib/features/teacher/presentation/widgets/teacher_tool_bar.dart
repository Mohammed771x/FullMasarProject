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
  const TeacherToolBar({super.key, required this.open, required this.onTap});

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

/// 🧰 **شرائحُ الأدوات داخل «إعدادات الجلسة»** — الشرائحُ نفسُها (أيقونةً
///    ولوناً ومقاساً)، في شبكةٍ ٢×٢ متساويةِ الأعمدة.
///
/// 🎯 **قرار المالك (٢٠٢٦-٠٩-٢٤):** «ما في داعي لشريطٍ فوق وبطاقةٍ تحته —
///    خلّه نفس التعليم بالضبط: إعدادات الجلسة، يدخل يحصل خطة الدرس، واجب،
///    اسأل المساعد… بنفس الرموز والألوان، كله تحت إعدادات الجلسة، عشان
///    تكون مساحةٌ كبيرة للشات». فالشريطُ الدائمُ فوق المحادثة انطوى في
///    البطاقة، والبطاقةُ تُطوى — فتبقى الشاشةُ للمحادثة.
///
/// 🔘 والمختارةُ هنا **الأداةُ العاملة** — لا «بطاقةٌ مفتوحة» كما كان.
class TeacherToolChips extends StatelessWidget {
  const TeacherToolChips({
    super.key,
    required this.selected,
    required this.onTap,
  });

  final TeacherTool? selected;
  final ValueChanged<TeacherTool> onTap;

  // 🔲 **شبكةٌ ٢×٢ بعرضٍ متساوٍ** (قرار المالك ٢٠٢٦-٠٩-٢٤: «مش متناسق —
  //    تبسيط مفهوم أطول من اللي فوقه… خلّها رباعية منسّقة»). `FilledWrap`
  //    يوزّع العرضَ بنسبة طول النصّ فتتفاوت الأعمدة؛ والأدواتُ أربعٌ ثابتة،
  //    فالعمودان المتساويان أوضحُ للعين من صفوفٍ تملأ السطر.
  @override
  Widget build(BuildContext context) {
    final tools = TeacherToolX.bar;
    Widget cell(TeacherTool t) => Expanded(
      child: _ToolChip(
        tool: t,
        selected: t == selected,
        onTap: () => onTap(t),
        centered: true,
      ),
    );
    return Column(
      children: [
        for (var i = 0; i < tools.length; i += 2) ...[
          if (i > 0) const SizedBox(height: TeacherToolBar.gap),
          Row(
            children: [
              cell(tools[i]),
              const SizedBox(width: TeacherToolBar.gap),
              if (i + 1 < tools.length) cell(tools[i + 1]) else const Spacer(),
            ],
          ),
        ],
      ],
    );
  }
}

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.tool,
    required this.selected,
    required this.onTap,
    this.centered = false,
  });

  final TeacherTool tool;
  final bool selected;
  final VoidCallback onTap;

  /// عرضٌ يفرضه الأب ([FilledWrap]) ⇒ المحتوى في الوسط لا في الطرف.
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.toolPalette(tool.slot);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(TeacherToolBar.radius),
        child: Semantics(
          button: true,
          selected: selected,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            height: TeacherToolBar.height,
            // 📐 **البدايةُ لا الوسط** في الشبكة (قرار المالك: «الأيقونات واحدة فوق
          //    وواحدة تحت، مش فوق بعض»): توسيطُ «أيقونة + نصّ» يُزيح الأيقونةَ
          //    بطول النصّ، فلا تقع أيقونتا العمود على خطٍّ واحد. من البداية
          //    تصطفّ الأيقوناتُ عموداً والنصوصُ بعدها.
          alignment: centered ? AlignmentDirectional.centerStart : null,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            decoration: BoxDecoration(
              color: selected ? p.fill : AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(TeacherToolBar.radius),
              border: Border.all(
                color: selected ? p.accent : AppColors.quizCardBorder,
              ),
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
                    borderRadius: BorderRadius.circular(
                      TeacherToolBar.iconBoxRadius,
                    ),
                  ),
                  child: tool.iconWidget(size: 16, color: p.ink),
                ),
                const SizedBox(width: 11),
                Flexible(
                  child: Text(
                    tool.chipLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      // 📏 في البطاقة ١٣ كشرائح أوضاع الطالب جارتِها — والـ١٠
                      //    مقاسُ الشريط الضيّق القديم (مقيسٌ من التصدير).
                      fontSize: centered ? 13 : 10,
                      fontWeight: FontWeight.w900,
                      color: selected ? p.ink : AppColors.rowAction,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
