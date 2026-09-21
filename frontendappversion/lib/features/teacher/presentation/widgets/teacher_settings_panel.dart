import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/modern_dropdown.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../../chat/presentation/controllers/chat_controller.dart';
import '../../data/teacher_tool.dart';

// ==========================================
// ⚙️ بطاقةُ إعدادات أداة المعلم
// ==========================================
// 🎨 **تصميم Figma** — `design/09-teacher/01·03·04` · مقيسٌ من التصدير:
//    البطاقة (24,203) 341×* · r20 · بيضاء بحدّ `#E8EDF3` · حشوةٌ 16 ·
//    العنوان **14**/w900 `#0F172B` · تسميةُ الحقل **12**/w900 `#42526D` ·
//    القوائم 36 r9 (هي [ModernDropdown] نفسُها) ·
//    وزرُّ التوليد **46 · r11 · لونٌ مصمتٌ من سلّم الأداة** ونصُّه أبيض
//    **14**/w900 تسبقه أيقونةُ الأداة وتذيّله «✨».
//
// 📏 **والمقاسات مقيسةٌ بمقارنة الحرف بالحرف** لا مقدَّرة من الصورة:
//    حبرُ عنوان البطاقة في التصدير 17.0 — وهو نفسُ ارتفاع عنوان الشريط
//    العلويّ المعلومِ أنه 14، والفرقُ بينهما الوزنُ لا المقاس.
//
// ⭐ **وهذه هي الفرق الأول** بين قسم المعلم وقسم التعليم (قرار المالك):
//    كل ما عداها من الشات — الفقاعات والصور والصوت والنسخ والإيقاف والسياق
//    وسجلّ المحادثات — **هو نفسه حرفياً** لأنه الشاشة نفسها والمتحكّم نفسه.
//
// 📐 **والبطاقةُ مُدّت لتسع ما لم يرسمه المصمّم** (قاعدة المالك ①): رسم
//    للخطة «المادة + الدرس»، وللواجب «الدرس» وحده، وللتبسيط «المفهوم»
//    وحده. والتطبيق يحتاج **المادة ← الوحدة ← الدرس** في الثلاث (الدرسُ
//    يُعرَّف بوحدته)، ويحتاج للواجب مستوىً وعدداً. فزيدت الحقول بلغة
//    البطاقة نفسِها ولم يُحذف منها شيء.
//
// ⚠️ **لا وضع صفحات ولا محتوى وحدات هنا إطلاقاً**: أدوات المعلم تُبنى من نصّ
//    الدرس وحده، فمادةٌ بلا دروس تُقال صراحةً بدل أن تُنتج خطةً لدرسٍ لا يوجد.
class TeacherSettingsPanel extends StatelessWidget {
  const TeacherSettingsPanel(
      {super.key, required this.controller, this.onGenerated});

  final ChatController controller;

  /// تُنادى بعد ضغط زرّ التوليد — الشاشةُ تطوي البطاقة لتفسح للنتيجة.
  final VoidCallback? onGenerated;

  /// 📏 مقاساتُ التصميم — يقرؤها الاختبار بدل أن يُعيد كتابتها.
  static const double radius = 20;
  static const double padding = 16;
  static const double buttonHeight = 46;
  static const double buttonRadius = 11;

  ChatController get c => controller;
  TeacherTool get tool => c.teacherTool!;

  @override
  Widget build(BuildContext context) {
    final p = AppColors.toolPalette(tool.slot);
    return Container(
      // 📏 **19 لا 16 من أعلى**: حشوةُ التصدير 16 في الجهات الأربع، لكنّ
      //    قيادةَ سطرِ Cairo في فلاتر أقصرُ بثلاثٍ منها في Figma — فلو
      //    نُقل الرقمُ حرفياً لوقع الحبرُ أعلى بثلاثٍ من موضعه في الملف.
      //    والمنقولُ **موضعُ الحبر** لا رقمُ الحشوة.
      padding:
          const EdgeInsets.fromLTRB(padding, padding + 3, padding, padding),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.quizCardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tool.cardTitle,
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: AppColors.slateTitle)),
          const SizedBox(height: 17),
          ..._fields(),
          if (tool.hasGenerate) ...[
            const SizedBox(height: 9),
            _generateButton(p),
          ],
        ],
      ),
    );
  }

  // ───────────────── الحقول ─────────────────

  List<Widget> _fields() {
    if (c.capsLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(
              child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4))),
        ),
      ];
    }

    return [
      _label("المادة الدراسية:"),
      const SizedBox(height: 7),
      // 📚 **المادةُ في البطاقة كما في التصميم** — وهي القائمةُ الجانبية
      //    نفسُها تُستدعى من موضعٍ ثانٍ: `setSubject` واحدةٌ للاثنين.
      ModernDropdown(
        hint: "اختر المادة",
        value: c.subjects.contains(c.selectedSubject) ? c.selectedSubject : null,
        items: c.subjects,
        onChanged: (v) => v == null ? null : c.setSubject(v),
      ),
      const SizedBox(height: 12),
      ..._lessonFields(),
      ..._toolFields(),
    ];
  }

  List<Widget> _lessonFields() {
    final units = c.v3LessonsUnits;
    if (units.isEmpty) {
      // ⚠️ رسالة صريحة لا سقوطٌ صامت على محتوى الوحدات.
      return [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.warningTintSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.warningTintBorder, width: 1.5),
          ),
          child: Row(
            children: [
              const Text("🚧", style: TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  "دروس «${c.selectedSubject}» لهذا الصف لم تُضف بعد.\n"
                  "أدوات المعلم تُبنى من نصّ الدرس — اختر مادة أخرى.",
                  style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                      color: AppColors.savedInk),
                ),
              ),
            ],
          ),
        ),
      ];
    }

    return [
      _label("الوحدة:"),
      const SizedBox(height: 7),
      ModernDropdown(
        hint: "اختر الوحدة",
        value: c.selectedV3Unit.isEmpty ? null : c.selectedV3Unit,
        items: units,
        onChanged: (v) => c.setV3Unit(v ?? ""),
      ),
      const SizedBox(height: 12),
      _label(tool.lessonFieldLabel),
      const SizedBox(height: 7),
      ModernDropdown(
        hint: "اختر الدرس",
        value: c.selectedV3Lesson.isEmpty ? null : c.selectedV3Lesson,
        items: c.v3LessonsInSelectedUnit,
        onChanged: (v) => c.setV3Lesson(v ?? ""),
        leading: PD.notebook,
      ),
      if (tool == TeacherTool.ask) ...[
        const SizedBox(height: 8),
        Text(
          "اختيار الدرس اختياري هنا — اسأل عنه أو عن التدريس عموماً.",
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primary),
        ),
      ],
    ];
  }

  // ───────────────── حقول كل أداة ─────────────────

  List<Widget> _toolFields() {
    switch (tool) {
      case TeacherTool.simplify:
        return [
          const SizedBox(height: 12),
          _label("اكتب المفهوم أو المصطلح:"),
          const SizedBox(height: 7),
          _conceptField(),
        ];

      case TeacherTool.homework:
        return [
          const SizedBox(height: 12),
          _label("مستوى الصعوبة:"),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final d in kTeacherDifficulties)
                _pill(d, c.teacherDifficulty == d,
                    () => c.update(() => c.teacherDifficulty = d)),
            ],
          ),
          const SizedBox(height: 12),
          _label("عدد الأسئلة:"),
          const SizedBox(height: 6),
          Row(
            children: [
              for (final n in kTeacherCounts)
                _pill("$n", c.teacherCount == n,
                    () => c.update(() => c.teacherCount = n)),
            ],
          ),
        ];

      case TeacherTool.lessonPlan:
      case TeacherTool.ask:
        return const [];
    }
  }

  /// 💡 حقلُ المفهوم — بصندوق [ModernDropdown] نفسِه (36 · r9 · `#FAFBFB`)
  ///    لأن المصمّم رسمه صندوقاً واحداً لا صندوقين مختلفين.
  Widget _conceptField() => Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: AppColors.rowBorder),
        ),
        child: TextField(
          controller: c.conceptController,
          // ⭐ إعادة البناء ضرورية: زرّ التوليد معطَّل حتى يُكتب المفهوم،
          //    وبدونها يبقى رمادياً بعد الكتابة حتى يلمس المعلّمُ شيئاً آخر.
          onChanged: (_) => c.refresh(),
          textAlignVertical: TextAlignVertical.center,
          style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: AppColors.dropdownInk),
          decoration: InputDecoration(
            isDense: true,
            hintText: "مثال: قاعدة لوشاتيليه · الاشتقاق الضمني",
            hintStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.dropdownCaret),
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      );

  // ───────────────── زرّ التوليد ─────────────────

  Widget _generateButton(ToolPalette p) {
    final ready = c.canGenerateTeacher;
    final reason = _blockedReason();
    // 🔴 **والحبرُ يتبع الحالة**: الأبيضُ على الزرّ المعطَّل الباهت كان
    //    يختفي تماماً — رأيتُه في المحاكي قبل أن يراه أحد.
    final Color ink = ready ? Colors.white : AppColors.rowHint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: ready ? p.cta : AppColors.quizButtonIdle,
          borderRadius: BorderRadius.circular(buttonRadius),
          child: InkWell(
            onTap: ready
                ? () {
                    c.generateTeacher();
                    onGenerated?.call();
                  }
                : null,
            borderRadius: BorderRadius.circular(buttonRadius),
            child: SizedBox(
              height: buttonHeight,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  tool.iconWidget(size: 18, color: ink),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      "${tool.generateLabel} ✨",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: ink),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!ready && reason.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(reason,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.rowHint)),
        ],
      ],
    );
  }

  /// ⭐ **يقول للمعلّم لماذا الزرّ رمادي** بدل أن يتركه يضغط بلا استجابة.
  String _blockedReason() {
    if (c.isLoading) return "⏳ انتظر انتهاء الرد الحالي أو أوقفه.";
    // ⚠️ «اختر الدرس» نصيحةٌ كاذبة حين لا دروس أصلاً — المطلوب تبديل المادة.
    if (c.v3LessonsUnits.isEmpty && !c.capsLoading) {
      return "🚧 لا دروس لهذه المادة — اختر مادة أخرى.";
    }
    if (!c.teacherLessonReady) return "📖 اختر الوحدة ثم الدرس أولاً.";
    if (tool == TeacherTool.simplify && c.conceptController.text.trim().isEmpty) {
      return "💡 اكتب المفهوم الذي تريد تبسيطه.";
    }
    return "";
  }

  // ───────────────── عناصر صغيرة ─────────────────

  Widget _label(String text) => Text(text,
      style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w900,
          color: AppColors.rowAction));

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    final p = AppColors.toolPalette(tool.slot);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Material(
          color: selected ? p.cta : AppColors.fieldFill,
          borderRadius: BorderRadius.circular(9),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(9),
            child: SizedBox(
              height: 34,
              child: Center(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: selected ? Colors.white : AppColors.rowAction)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
