import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/modern_dropdown.dart';
import '../controllers/chat_controller.dart';

// ==========================================
// ⚙️ لوحة إعدادات الجلسة (المنبثقة) وكل عناصر الاختيار
// ==========================================
class SessionSettingsPanel extends StatelessWidget {
  final ChatController controller;

  const SessionSettingsPanel({super.key, required this.controller});

  ChatController get c => controller;

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
                Text("إعدادات الجلسة", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.textPrimary)),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => c.setShowSettingsPanel(false),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _modeSelector(),
            if (c.selectedSubject == "رياضيات") ...[
              const SizedBox(height: 16), _mathBranchSelector(),
              if (c.mathMode == "وزاري" && c.selectedMathBranch.isNotEmpty) _mathExamSelector(),
              if (c.mathLessons.isNotEmpty && c.mathMode != "وزاري") ...[
                const SizedBox(height: 12),
                ModernDropdown(
                  hint: "اختر الدرس",
                  value: c.selectedLesson.isEmpty ? null : c.selectedLesson,
                  items: c.mathLessons,
                  onChanged: (v) => c.update(() => c.selectedLesson = v ?? ""),
                  icon: Icons.menu_book_rounded,
                ),
              ],
              if (c.selectedMathBranch.isNotEmpty) const SizedBox(height: 12), _mathModeSelector(),
            ],
            if (c.selectedSubject != "رياضيات") _unitFilterArea(),
            if (c.selectedMode == "تلخيص" && c.selectedSubject != "رياضيات") _summarySlider(),
            if (c.selectedSubject != "رياضيات" && c.selectedMode != "سؤال" && c.selectedMode != "وزاري") _inputTypeSelector(),
          ],
        ),
      ),
    );
  }

  // ===== محدّد الوضع (العام) =====
  Widget _modeSelector() {
    if (c.selectedSubject == "رياضيات") return const SizedBox.shrink();
    Map<String, IconData> modeIcons = {
      "شرح": Icons.auto_stories_rounded,
      "تلخيص": Icons.psychology_rounded,
      "سؤال": Icons.help_outline_rounded,
      "وزاري": Icons.gavel_rounded,
    };
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: ["شرح", "تلخيص", "سؤال", "وزاري"].map((m) => AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: ChoiceChip(
          label: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(modeIcons[m], size: 16, color: c.selectedMode == m ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 8),
            Text(m),
          ]),
          selected: c.selectedMode == m,
          selectedColor: AppColors.primary,
          showCheckmark: false,
          labelStyle: TextStyle(color: c.selectedMode == m ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
          backgroundColor: AppColors.softSurface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
          onSelected: (_) => c.switchContext(() {
            c.selectedMode = m;
            c.mathWazariQuestionsLoaded = false;
            if (c.selectedSubject == "فيزياء") {
              c.selectedPhysicsLesson = "";
              c.physicsLessons = [];
            }
            if (m == "وزاري") {
              c.selectedExamYear = "";
              c.loadAvailableYears();
            } else {
              c.loadAvailableUnits();
            }
          }),
        ),
      )).toList(),
    );
  }

  // ===== محدّد نوع الإدخال (صفحة/برومت) =====
  Widget _inputTypeSelector() {
    if (c.selectedSubject == "فيزياء" || c.selectedSubject == "كيمياء" || c.selectedSubject == "عربي" || c.selectedSubject == "انجليزي" || c.selectedMode == "وزاري" || c.selectedMode == "سؤال") {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(24)),
        child: Row(
          children: ["صفحة", "برومت"].map((t) => Expanded(
            child: InkWell(
              onTap: () => c.update(() => c.inputType = t),
              borderRadius: BorderRadius.circular(20),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: c.inputType == t ? AppColors.surfaceWhite : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: c.inputType == t ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)] : [],
                ),
                child: Center(child: Text(t, style: TextStyle(color: c.inputType == t ? AppColors.primary : AppColors.textSecondary, fontWeight: FontWeight.bold))),
              ),
            ),
          )).toList(),
        ),
      ),
    );
  }

  // ===== فروع الرياضيات =====
  Widget _mathBranchSelector() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: c.mathBranches.map((b) => ChoiceChip(
          label: Text(b),
          selected: c.selectedMathBranch == b,
          selectedColor: AppColors.primary,
          showCheckmark: false,
          labelStyle: TextStyle(color: c.selectedMathBranch == b ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold),
          backgroundColor: AppColors.softSurface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
          onSelected: (_) => c.switchContext(() {
            c.selectedMathBranch = b;
            c.mathMode = "شرح";
            c.selectedLesson = "";
            c.loadMathLessons(b);
            c.mathWazariQuestionsLoaded = false;
          }),
        )).toList(),
      );

  // ===== أوضاع الرياضيات =====
  Widget _mathModeSelector() => Wrap(
        spacing: 10,
        children: ["شرح", "سؤال", "وزاري"].map((mode) => ChoiceChip(
          label: Text(mode),
          selected: c.mathMode == mode,
          selectedColor: AppColors.secondary,
          showCheckmark: false,
          labelStyle: TextStyle(color: c.mathMode == mode ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold),
          backgroundColor: AppColors.softSurface,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
          onSelected: (_) => c.update(() {
            c.mathMode = mode;
            c.selectedMode = mode;
            c.inputType = "برومت";
            c.mathWazariQuestionsLoaded = false;
            if (mode == "وزاري" && c.selectedMathBranch.isNotEmpty) c.loadMathExamYears(c.selectedMathBranch);
          }),
        )).toList(),
      );

  // ===== إعدادات وزاري الرياضيات =====
  Widget _mathExamSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(top: 16),
      decoration: BoxDecoration(color: AppColors.softSurface.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.primary.withValues(alpha: 0.1))),
      child: Column(
        children: [
          Row(children: [
            Icon(Icons.school_rounded, color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text("إعدادات الأسئلة الوزارية", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ]),
          const SizedBox(height: 16),
          if (c.mathExamYears.isNotEmpty)
            ModernDropdown(
              hint: "اختر السنة",
              value: c.selectedMathExamYear.isEmpty ? null : c.selectedMathExamYear,
              items: c.mathExamYears,
              onChanged: (v) => c.update(() {
                c.selectedMathExamYear = v!;
                c.loadMathExamLessons(c.selectedMathBranch, v);
              }),
              icon: Icons.calendar_month_rounded,
            ),
          const SizedBox(height: 12),
          if (c.mathExamLessons.isNotEmpty)
            ModernDropdown(
              hint: "اختر الدرس",
              value: c.selectedMathExamLesson.isEmpty ? null : c.selectedMathExamLesson,
              items: c.mathExamLessons,
              onChanged: (v) => c.update(() => c.selectedMathExamLesson = v!),
              icon: Icons.menu_book_rounded,
            ),
          if (c.selectedMathExamLesson.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Icon(Icons.format_list_numbered_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text("عدد الأسئلة:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                  SizedBox(
                    width: 60,
                    child: TextField(
                      controller: c.questionCountController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                      decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: AppColors.softSurface, contentPadding: const EdgeInsets.symmetric(vertical: 8)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                onPressed: c.selectedMathExamLesson.isEmpty ? null : () {
                  final count = int.tryParse(c.questionCountController.text) ?? 10;
                  final content = "${c.selectedMathExamYear}|${c.selectedMathExamLesson}|$count";
                  c.selectedLesson = c.selectedMathExamLesson;
                  c.update(() => c.mathWazariQuestionsLoaded = true);
                  c.processRequest(customText: content);
                },
                icon: Icon(Icons.download_rounded, size: 20),
                label: Text("جلب الأسئلة", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===== شريط مستوى التلخيص =====
  Widget _summarySlider() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("مستوى التلخيص", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)), child: Text("${c.summaryLevel}", style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold))),
            ],
          ),
          Slider(activeColor: AppColors.primary, inactiveColor: AppColors.softSurface, min: 1, max: 5, divisions: 4, value: c.summaryLevel.toDouble(), onChanged: (v) => c.update(() => c.summaryLevel = v.toInt())),
        ],
      ),
    );
  }

  // ===== منطقة فلترة الوحدات/الوزاري لكل مادة =====
  Widget _unitFilterArea() {
    // 🔴 وضع الوزاري
    if (c.selectedMode == "وزاري") {
      if (c.selectedSubject == "رياضيات") {
        return const SizedBox.shrink();
      }

      // 👇 العربي حصراً
      if (c.selectedSubject == "عربي") {
        bool isArabicReady = c.selectedArabicExamYear.isNotEmpty && c.selectedArabicExamSection.isNotEmpty && c.selectedArabicExamType.isNotEmpty;

        return Column(
          children: [
            const SizedBox(height: 16),
            ModernDropdown(
              hint: "اختر السنة الوزارية",
              value: c.selectedArabicExamYear.isEmpty ? null : c.selectedArabicExamYear,
              items: c.availableYears,
              onChanged: (v) => c.update(() => c.selectedArabicExamYear = v!),
              icon: Icons.calendar_today_rounded,
            ),
            const SizedBox(height: 12),
            ModernDropdown(
              hint: "اختر القسم",
              value: c.selectedArabicExamSection.isEmpty ? null : c.selectedArabicExamSection,
              items: c.arabicExamSections,
              onChanged: (v) => c.update(() {
                c.selectedArabicExamSection = v!;
                c.selectedArabicExamType = "";
              }),
              icon: Icons.category_rounded,
            ),
            const SizedBox(height: 12),
            if (c.selectedArabicExamSection.isNotEmpty)
              ModernDropdown(
                hint: "نوع التدريب (قطعة أم أسئلة عامة؟)",
                value: c.selectedArabicExamType.isEmpty ? null : c.selectedArabicExamType,
                items: c.arabicExamTypes,
                onChanged: (v) => c.update(() => c.selectedArabicExamType = v!),
                icon: Icons.filter_alt_rounded,
              ),
            if (c.selectedArabicExamType.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(Icons.format_list_numbered_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.selectedArabicExamType == "قطعة" ? "عدد القطع:" : "عدد الأسئلة:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: c.arabicQuestionCountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: AppColors.softSurface, contentPadding: const EdgeInsets.symmetric(vertical: 8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isArabicReady ? AppColors.primary : Colors.grey.shade300,
                  foregroundColor: isArabicReady ? Colors.white : Colors.grey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: isArabicReady ? 4 : 0,
                ),
                onPressed: isArabicReady ? () {
                  final count = int.tryParse(c.arabicQuestionCountController.text) ?? (c.selectedArabicExamType == "قطعة" ? 1 : 5);
                  String content = "${c.selectedArabicExamYear}|${c.selectedArabicExamSection}|${c.selectedArabicExamType}|$count";
                  c.setShowSettingsPanel(false);
                  c.processRequest(customText: content);
                } : null,
                icon: Icon(Icons.download_rounded, size: 20),
                label: Text("جلب الأسئلة", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            if (!isArabicReady)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text("اختر جميع الخيارات أولاً", style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
          ],
        );
      }

      // 👇 الإنجليزي حصراً
      if (c.selectedSubject == "انجليزي") {
        return Column(
          children: [
            const SizedBox(height: 16),
            ModernDropdown(
              hint: "Choose Exam Year",
              value: c.selectedEnglishExamYear.isEmpty ? null : c.selectedEnglishExamYear,
              items: ["الكل", ...c.availableYears],
              onChanged: (v) {
                c.update(() {
                  c.selectedEnglishExamYear = v!;
                  c.loadExamSections("انجليزي", v);
                });
              },
              icon: Icons.calendar_today_rounded,
            ),
            const SizedBox(height: 12),
            ModernDropdown(
              hint: "Choose Question Type",
              value: c.selectedEnglishQuestionType.isEmpty ? null : c.selectedEnglishQuestionType,
              items: c.englishQuestionTypes,
              onChanged: (v) => c.update(() => c.selectedEnglishQuestionType = v!),
              icon: Icons.category_rounded,
            ),
            if (c.selectedEnglishQuestionType.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(Icons.format_list_numbered_rounded, color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c.selectedEnglishQuestionType.contains("passage") || c.selectedEnglishQuestionType.contains("paragraph") ? "Number of Passages:" : "Number of Questions:", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                    SizedBox(
                      width: 60,
                      child: TextField(
                        controller: c.englishQuestionCountController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                        decoration: InputDecoration(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), filled: true, fillColor: AppColors.softSurface, contentPadding: const EdgeInsets.symmetric(vertical: 8)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), elevation: 0),
                onPressed: c.selectedEnglishExamYear.isEmpty || c.selectedEnglishQuestionType.isEmpty ? null : () {
                  final count = int.tryParse(c.englishQuestionCountController.text) ?? 5;
                  String content = "${c.selectedEnglishExamYear}|${c.selectedEnglishQuestionType}|$count";
                  c.setShowSettingsPanel(false);
                  c.processRequest(customText: content);
                },
                icon: Icon(Icons.rocket_launch_rounded, size: 20),
                label: Text("Start Practice", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      }

      // 👇 لبقية المواد (فيزياء، كيمياء، أحياء)
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ModernDropdown(
          hint: "اختر السنة الوزارية",
          value: c.selectedExamYear.isEmpty ? null : c.selectedExamYear,
          items: ["الكل", ...c.availableYears],
          onChanged: (v) => c.update(() => c.selectedExamYear = v!),
          icon: Icons.calendar_today_rounded,
        ),
      );
    }

    // 🟡 الأحياء فقط - نظام الصفحات والوحدات
    if (c.selectedSubject == "احياء") {
      return Column(
        children: [
          const SizedBox(height: 16),
          ModernDropdown(
            hint: "اختر الوحدة",
            value: c.selectedUnit.isEmpty ? null : c.selectedUnit,
            items: c.availableUnits.toSet().toList(),
            onChanged: (v) => c.update(() {
              c.selectedUnit = v ?? "الكل";
              c.selectedUnitName = c.selectedUnit;
            }),
            icon: Icons.library_books_rounded,
          ),
        ],
      );
    }

    // 🔵 الفيزياء والكيمياء والعربي والإنجليزي
    if (c.selectedSubject == "فيزياء" || c.selectedSubject == "كيمياء" || c.selectedSubject == "عربي" || c.selectedSubject == "انجليزي") {
      return Column(
        children: [
          const SizedBox(height: 16),
          ModernDropdown(
            hint: "اختر الوحدة",
            value: c.selectedUnit.isEmpty ? null : c.selectedUnit,
            items: c.availableUnits.toSet().toList(),
            onChanged: (v) => c.update(() {
              c.selectedUnit = v ?? "الكل";
              c.selectedUnitName = c.selectedUnit;
              if (c.selectedSubject == "فيزياء" && c.selectedUnit != "الكل") {
                c.loadPhysicsLessons(c.selectedUnit);
              }
              if (c.selectedSubject == "كيمياء" && c.selectedUnit != "الكل") {
                c.loadChemistryLessons(c.selectedUnit);
              }
              if (c.selectedSubject == "عربي" && c.selectedUnit != "الكل") {
                c.loadArabicLessons(c.selectedUnit);
              }
              if (c.selectedSubject == "انجليزي" && c.selectedUnit != "الكل") {
                c.loadEnglishLessons(c.selectedUnit);
              }
            }),
            icon: Icons.library_books_rounded,
          ),
          // الدروس للفيزياء
          if (c.selectedSubject == "فيزياء" && c.physicsLessons.isNotEmpty) ...[
            const SizedBox(height: 12),
            ModernDropdown(
              hint: "اختر الدرس",
              value: c.selectedPhysicsLesson.isEmpty ? null : c.selectedPhysicsLesson,
              items: c.physicsLessons,
              onChanged: (v) => c.update(() => c.selectedPhysicsLesson = v ?? ""),
              icon: Icons.science_rounded,
            ),
          ],
          // الدروس للكيمياء
          if (c.selectedSubject == "كيمياء" && c.chemistryLessons.isNotEmpty) ...[
            const SizedBox(height: 12),
            ModernDropdown(
              hint: "اختر الدرس",
              value: c.selectedChemistryLesson.isEmpty ? null : c.selectedChemistryLesson,
              items: c.chemistryLessons,
              onChanged: (v) => c.update(() => c.selectedChemistryLesson = v ?? ""),
              icon: Icons.science_rounded,
            ),
          ],
          // الدروس للعربي
          if (c.selectedSubject == "عربي" && c.arabicLessons.isNotEmpty) ...[
            const SizedBox(height: 12),
            ModernDropdown(
              hint: "اختر الدرس",
              value: c.selectedArabicLesson.isEmpty ? null : c.selectedArabicLesson,
              items: c.arabicLessons,
              onChanged: (v) => c.update(() => c.selectedArabicLesson = v ?? ""),
              icon: Icons.language_rounded,
            ),
          ],
          // 🟢 الدروس للإنجليزي
          if (c.selectedSubject == "انجليزي" && c.englishLessons.isNotEmpty) ...[
            const SizedBox(height: 12),
            ModernDropdown(
              hint: "اختر الدرس",
              value: c.selectedEnglishLesson.isEmpty ? null : c.selectedEnglishLesson,
              items: c.englishLessons,
              onChanged: (v) => c.update(() => c.selectedEnglishLesson = v ?? ""),
              icon: Icons.language_rounded,
            ),
          ],
        ],
      );
    }

    return const SizedBox.shrink();
  }
}
