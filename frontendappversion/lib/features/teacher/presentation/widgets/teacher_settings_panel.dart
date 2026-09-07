import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/modern_dropdown.dart';
import '../../../chat/presentation/controllers/chat_controller.dart';
import '../../data/teacher_tool.dart';

// ==========================================
// ⚙️ لوحة إعدادات المعلم (بديلة لوحة إعدادات الطالب)
// ==========================================
// ⭐ **هذه هي الفرق الأول** بين قسم المعلم وقسم التعليم (قرار المالك):
//    كل ما عداها من الشات — الفقاعات والصور والصوت والنسخ والإيقاف والسياق
//    وسجلّ المحادثات — **هو نفسه حرفياً** لأنه الشاشة نفسها والمتحكّم نفسه.
//
// التسلسل ثابت في الأدوات الأربع: **الوحدة ← الدرس**، ثم حقول الأداة، ثم الزر.
// (المادة والصف والمسار من القائمة الجانبية — تماماً كقسم التعليم.)
//
// ⚠️ **لا وضع صفحات ولا محتوى وحدات هنا إطلاقاً**: أدوات المعلم تُبنى من نصّ
//    الدرس وحده، فمادةٌ بلا دروس تُقال صراحةً بدل أن تُنتج خطةً لدرسٍ لا يوجد.
class TeacherSettingsPanel extends StatelessWidget {
  final ChatController controller;

  const TeacherSettingsPanel({super.key, required this.controller});

  ChatController get c => controller;
  TeacherTool get tool => c.teacherTool!;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: AppColors.softShadow,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text("${tool.emoji} ${tool.settingsTitle}",
                      style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: AppColors.textPrimary)),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => c.setShowSettingsPanel(false),
                ),
              ],
            ),
            Text("المادة والصف من القائمة الجانبية ☰",
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            _lessonPickers(),
            ..._toolFields(),
            if (tool.hasGenerate) ...[
              const SizedBox(height: 18),
              _generateButton(),
            ],
          ],
        ),
      ),
    );
  }

  // ───────────────── الوحدة ← الدرس ─────────────────

  Widget _lessonPickers() {
    if (c.capsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
            child: SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }

    final units = c.v3LessonsUnits;
    if (units.isEmpty) {
      // ⚠️ رسالة صريحة لا سقوطٌ صامت على محتوى الوحدات.
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            const Text("🚧", style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "دروس «${c.selectedSubject}» لهذا الصف لم تُضف بعد.\n"
                "أدوات المعلم تُبنى من نصّ الدرس — اختر مادة أخرى من القائمة ☰.",
                style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade800),
              ),
            ),
          ],
        ),
      );
    }

    return Column(children: [
      ModernDropdown(
        hint: "اختر الوحدة",
        value: c.selectedV3Unit.isEmpty ? null : c.selectedV3Unit,
        items: units,
        onChanged: (v) => c.setV3Unit(v ?? ""),
        icon: Icons.folder_rounded,
      ),
      const SizedBox(height: 12),
      ModernDropdown(
        hint: "اختر الدرس",
        value: c.selectedV3Lesson.isEmpty ? null : c.selectedV3Lesson,
        items: c.v3LessonsInSelectedUnit,
        onChanged: (v) => c.setV3Lesson(v ?? ""),
        icon: Icons.menu_book_rounded,
      ),
      if (tool == TeacherTool.ask) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            "اختيار الدرس اختياري هنا — اسأل عنه أو عن التدريس عموماً.",
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
          ),
        ),
      ],
    ]);
  }

  // ───────────────── حقول كل أداة ─────────────────

  List<Widget> _toolFields() {
    switch (tool) {
      case TeacherTool.simplify:
        return [
          const SizedBox(height: 14),
          _label("المفهوم الذي تريد تبسيطه:"),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
                color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
            child: TextField(
              controller: c.conceptController,
              // ⭐ إعادة البناء ضرورية: زرّ التوليد معطَّل حتى يُكتب المفهوم،
              //    وبدونها يبقى رمادياً بعد الكتابة حتى يلمس المعلّم شيئاً آخر.
              onChanged: (_) => c.refresh(),
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: "مثال: الانتشار الغشائي · الاشتقاق الضمني",
                hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13.5),
                prefixIcon:
                    Icon(Icons.lightbulb_outline_rounded, color: AppColors.secondary, size: 20),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 15),
              ),
            ),
          ),
        ];

      case TeacherTool.homework:
        return [
          const SizedBox(height: 16),
          _label("مستوى الصعوبة:"),
          const SizedBox(height: 8),
          Row(
            children: kTeacherDifficulties
                .map((d) => _pill(d, c.teacherDifficulty == d,
                    () => c.update(() => c.teacherDifficulty = d)))
                .toList(),
          ),
          const SizedBox(height: 14),
          _label("عدد الأسئلة:"),
          const SizedBox(height: 8),
          Row(
            children: kTeacherCounts
                .map((n) => _pill("$n", c.teacherCount == n,
                    () => c.update(() => c.teacherCount = n)))
                .toList(),
          ),
        ];

      case TeacherTool.lessonPlan:
      case TeacherTool.ask:
        return const [];
    }
  }

  // ───────────────── زرّ التوليد ─────────────────

  Widget _generateButton() {
    final ready = c.canGenerateTeacher;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 54,
          decoration: BoxDecoration(
            gradient: ready ? LinearGradient(colors: tool.gradient) : null,
            color: ready ? null : AppColors.softSurface,
            borderRadius: BorderRadius.circular(22),
            boxShadow: ready ? AppColors.softShadow : const [],
          ),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            ),
            onPressed: ready ? () => c.generateTeacher() : null,
            child: Text(
              tool.generateLabel,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ready ? Colors.white : AppColors.textSecondary),
            ),
          ),
        ),
        if (!ready) ...[
          const SizedBox(height: 8),
          Text(_blockedReason(),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ],
      ],
    );
  }

  /// ⭐ **يقول للمعلّم لماذا الزرّ رمادي** بدل أن يتركه يضغط بلا استجابة.
  String _blockedReason() {
    if (c.isLoading) return "⏳ انتظر انتهاء الرد الحالي أو أوقفه.";
    // ⚠️ «اختر الدرس» نصيحةٌ كاذبة حين لا دروس أصلاً — المطلوب تبديل المادة.
    if (c.v3LessonsUnits.isEmpty && !c.capsLoading) {
      return "🚧 لا دروس لهذه المادة — اختر مادة أخرى من القائمة ☰.";
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
          fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12.5));

  Widget _pill(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: selected ? AppColors.primary : AppColors.softSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: selected ? Colors.white : AppColors.textSecondary,
                      fontSize: 13)),
            ),
          ),
        ),
      ),
    );
  }
}
