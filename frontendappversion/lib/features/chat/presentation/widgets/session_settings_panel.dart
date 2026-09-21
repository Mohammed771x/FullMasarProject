import 'package:flutter/material.dart';

import '../../../../core/config/curriculum.dart';
import '../../../quiz/presentation/quiz_setup_screen.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/modern_dropdown.dart';
import '../../../../core/widgets/phosphor.dart';
import '../controllers/chat_controller.dart';
import 'page_picker.dart';
import '../../../teacher/presentation/widgets/teacher_settings_panel.dart';

// ==========================================
// ⚙️ لوحة إعدادات الجلسة (المنبثقة) وكل عناصر الاختيار
// ==========================================
class SessionSettingsPanel extends StatelessWidget {
  final ChatController controller;

  /// ⌨️ هل لوحةُ المفاتيح مرفوعةٌ الآن؟
  ///
  /// 🔴 **ولماذا تُمرَّر ولا تُقرأ هنا؟** `Scaffold` يبتلع `viewInsets`
  ///    السفليّ عن كل ما في جسمه (`resizeToAvoidBottomInset`)، فقراءتُها
  ///    من داخل البطاقة تعطي صفراً دائماً. جرّبتُها في المحاكي فبقيت
  ///    البطاقةُ مفتوحةً فوق الكيبورد و«تجاوزٌ بمقدار 80 بكسلة».
  ///    فتُقرأ من فوق الـ`Scaffold` وتُمرَّر.
  final bool keyboardOpen;

  /// 👨‍🏫 يُنادى بعد ضغط زرّ توليد أداةِ المعلم — تطوي الشاشةُ البطاقة.
  final VoidCallback? onTeacherGenerated;

  const SessionSettingsPanel({
    super.key,
    required this.controller,
    this.keyboardOpen = false,
    this.onTeacherGenerated,
  });

  ChatController get c => controller;

  @override
  Widget build(BuildContext context) {
    // 👨‍🏫 **الفرق الأول والوحيد في الشاشة** بين قسم المعلم وقسم التعليم:
    //    لوحة إعدادات أخرى. وما عداها — الشات كله — هو نفسه بالبناء لا بالنقل.
    if (c.isTeacher) {
      return TeacherSettingsPanel(
          controller: c, onGenerated: onTeacherGenerated);
    }

    // ══════════════════════════════════════════════════
    // 🃏 بطاقةٌ في **أعلى** الشاشة لا لوحةٌ منزلقة من أسفلها
    // ══════════════════════════════════════════════════
    // 🎨 **تصميم Figma** — «الرفيق الذاكي» (390:2048 عند y=134):
    //    بطاقةٌ 342 عرضاً · r12 · بيضاء بحدٍّ خفيف. رأسُها 316×52:
    //    سهمُ الطيّ في اليسار · «إعدادات الجلسة» 14/w900 `#15294B` ·
    //    وأيقونة `FadersHorizontal` في اليمين بلون `#006EBF`.
    //
    // 🔄 **لماذا تغيّر الموضع؟** كانت تنزلق من الأسفل فتغطّي المحادثة
    //    وحقلَ الكتابة. وفي التصميم هي **رأس الشاشة**: الطالب يرى سياقه
    //    (الوضع والمادة والدرس) قبل أن يكتب، ويطويها بضغطةٍ حين لا يحتاجه.
    // ⌨️ **الكيبورد يطوي البطاقة** (ملاحظة المالك): من فتح لوحة المفاتيح
    //    فهو يكتب الآن لا يضبط إعداداته — وبقاؤها مفتوحةً يأكل الشاشة
    //    فوق الكيبورد حتى لا تبقى للمحادثة سطور، ويُخرج «تجاوز الحدّ».
    //    وهذا **عرضٌ لا حالة**: لا نُطفئ `showSettingsPanel` في المتحكّم،
    //    فتعود البطاقة كما تركها الطالب بمجرّد أن يُغلق الكيبورد.
    final open = c.showSettingsPanel && !keyboardOpen;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.rowBorder),
        boxShadow: AppColors.bubbleShadow,
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ══════ الرأس — يطوي ويفتح ══════
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // ⌨️ وبالعكس: من فتحها وهو يكتب نُنزل له الكيبورد —
                //    وإلا فتحها فوجدها مطويّةً من جديد.
                FocusScope.of(context).unfocus();
                c.setShowSettingsPanel(!open);
              },
              child: SizedBox(
                height: 52,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  child: Row(
                    children: [
                      // 🎨 `FadersHorizontal` **ثنائيُّ اللون** — اسمُ العقدة
                      //    في ملف Figma حرفياً، ولوحُه الأزرقُ الباهتُ خلف
                      //    الخطّين لا يُنتجه نمطٌ ممتلئ.
                      PDuo(PD.fadersHorizontal,
                          size: 20, color: AppColors.panelTitleIcon),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text("إعدادات الجلسة",
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: AppColors.panelTitle)),
                      ),
                      AnimatedRotation(
                        turns: open ? 0.5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: Icon(PI.caretDown.regular,
                            size: 20, color: AppColors.dropdownCaret),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // ══════ الجسم ══════
          // ⚠️ `AnimatedSize` لا `Visibility`: الطيُّ حركةٌ يتابعها الطالب،
          //    والاختفاءُ المفاجئ يجعله يظنّ أن الشاشة قفزت.
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !open
                ? const SizedBox(width: double.infinity)
                : _body(context),
          ),
        ],
      ),
    );
  }

  Widget _body(BuildContext context) {
    // 📏 **تُفتح كاملةً بلا سقفٍ ولا تمريرٍ داخليّ** (ملاحظة المالك: «أول
    //    ما نضغط يجيك كامل، ولا ينزل كامل»).
    //
    // 🔴 كان عليها `maxHeight` فتُقصّ «صفحة/برومت» نصفين ويختفي ما بعدهما،
    //    ويلزم تمريرٌ **داخل** لوحةٍ لا يبدو عليها أنها تُمرَّر — فيظنّ
    //    الطالب أن ما تحتها غيرُ موجود.
    //
    // ✅ وصار ممكناً لأن البطاقة نفسَها **أوّلُ عناصر قائمة المحادثة**:
    //    تمريرُ الشاشة يمرّرها معه، فطولُها لا يقتطع من أحد.
    return Padding(
        padding: const EdgeInsets.fromLTRB(13, 0, 13, 13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _modeSelector(context),
            // 📊 **مستوى التلخيص تحت الشرائح مباشرةً** (ملاحظة المالك):
            //    كان آخرَ عنصرٍ في اللوحة فلا يُرى إلا بتمرير. ومن اختار
            //    «تلخيص» فأوّلُ ما يريد ضبطه هو مستواه.
            if (c.selectedMode == "تلخيص" && c.selectedSubject != "رياضيات")
              _summarySlider(),
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
                  leading: PD.notebook,
                ),
              ],
              if (c.selectedMathBranch.isNotEmpty) const SizedBox(height: 12), _mathModeSelector(),
            ],
            // 🆕 مصدر المحتوى (وضع الدروس / وضع الوحدات) — لكل المواد عدا الرياضيات والوزاري
            if (c.usesContentModes) ...[
              const SizedBox(height: 16),
              _contentModeSelector(),
            ],
            // وضع الدروس: وحدة ← درس (من /content/capabilities)
            if (c.usesContentModes && c.contentMode == "lessons") _lessonsModeArea(),
            // وضع الوحدات/الصفحات: الواجهة القديمة نفسها + الوزاري كما هو
            if (c.selectedSubject != "رياضيات" &&
                (!c.usesContentModes || c.contentMode == "pages")) _unitFilterArea(),

            if (c.selectedSubject != "رياضيات" && c.selectedMode != "سؤال" && c.selectedMode != "وزاري" &&
                (!c.usesContentModes || c.contentMode == "pages")) _inputTypeSelector(),
            // 📄 **المُنتقي تحت المحدّد مباشرةً**: من ضغط «صفحة» يرى الصفحات
            //    في اللحظة نفسها — لا يبحث عن مكانٍ ثالثٍ يختار منه.
            //
            // 🔒 **لا يُنقل من هنا** (قرار المالك ٢٠٢٦-٠٩-٢٠): جرّبتُ نقلَه
            //    إلى ورقةٍ سفليّة توفيراً للمساحة، فقال: «الصفحات بنظامها
            //    الأول، خلّوه زي ما كان أول». فرُدَّ كما كان.
            if (c.canPickPages) ...[
              const SizedBox(height: 16),
              PagePicker(c),
            ],
          ],
        ));
  }

  // ===== محدّد الوضع (العام) =====
  // ══════════════════════════════════════════════════
  // 🎛️ شرائح الأوضاع — مجموعةٌ واحدة بخلفيةٍ غائرة
  // ══════════════════════════════════════════════════
  // 🎨 **تصميم Figma:** حاويةٌ 316×84 r12 بتعبئة `#EBEDF0`، وداخلها
  //    شرائح r12 بارتفاع 35: اختبارات · سؤال · تلخيص · **شرح** (مختار،
  //    تعبئة `#0092FF` ونصّه أبيض) في صفّ، و**وزاري** في الصفّ الثاني.
  //    نصُّ الشريحة 10/w700 `#42526D` وأيقونتها 14.
  //
  // 📚 والأوضاعُ من `Curriculum.modesFor` لا مكتوبةً هنا — التصميمُ يعرض
  //    خمسةً، والمنهجُ يقرّر ما يظهر لكل مادةٍ وصف.
  Widget _modeSelector(BuildContext context) {
    if (c.selectedSubject == "رياضيات") return const SizedBox.shrink();

    // 🎯 **أيقوناتُ المصمّم بأعيانها** — قرأتُها من تصديره مكبّراً:
    //    الكتابُ المفتوح للشرح · **البرق** للتلخيص (لا ورقةً) ·
    //    **علامةُ الاستفهام** للسؤال (لا فقاعةَ محادثة) ·
    //    و**ورقةٌ عليها صحّ** للوزاريّ وللاختبارات معاً.
    // 📏 **16 لا 14، وعريضٌ لا عادي.** قِستُ التصدير بكسلةً بكسلة:
    //    دائرةُ «سؤال» 13pt وارتفاعُ ورقة «وزاري» 13pt — ونسبةُ كلٍّ منهما
    //    في مربّع Phosphor 0.8125، فالحجمُ 16 بالضبط. وسماكةُ خطّها 1.5pt
    //    = 24/256 من 16 — وهذه سماكةُ النمط **العريض** لا العادي (1pt).
    final icons = <String, Widget Function(Color)>{
      "شرح": (col) => Icon(PI.bookOpen.bold, size: 16, color: col),
      "تلخيص": (col) => Icon(PI.lightning.bold, size: 16, color: col),
      "سؤال": (col) => Icon(PI.question.bold, size: 16, color: col),
      "وزاري": (col) => PFileCheck(size: 16, color: col, bold: true),
      "اختبارات": (col) => PFileCheck(size: 16, color: col, bold: true),
    };

    final modes = _inDesignOrder(Curriculum.modesFor(
      c.selectedSubject,
      grade: c.grade, // ★ الثالث يحتفظ بالوزاري دائماً
      examsAvailable: c.caps?.examsAvailable ?? true,
    ));

    return Container(
      // 📏 **بعرض البطاقة كاملاً.** `Wrap` يقيس نفسه على أعرض سطرٍ فيه،
      //    فكانت الحاويةُ الرماديّة تنكمش إلى عرض الشرائح ويبقى نصفُ
      //    البطاقة فارغاً على اليسار — وهي في التصميم تملأ ما بين حافّتيها.
      width: double.infinity,
      // 📏 حشوةُ الحاوية 4: 4 + 35 + 6 + 35 + 4 = 84 — ارتفاعُ التصميم.
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.modeGroupSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final m in modes)
            _ModeChip(
              label: m,
              icon: icons[m] ??
                  (col) => Icon(PI.sparkle.bold, size: 16, color: col),
              selected: c.selectedMode == m,
              onTap: () => _pickMode(context, m),
            ),
        ],
      ),
    );
  }

  /// ترتيبُ العرض كما في التصميم — **عرضٌ فقط**، لا يمسّ `Curriculum`.
  ///
  /// 🎨 المصمّم رتّبها: شرح · تلخيص · سؤال · اختبارات · وزاري. والمنهجُ
  ///    يعيدها بترتيبٍ آخر يضع «اختبارات» في الذيل، فيقع «وزاري» في
  ///    السطر الأول و«اختبارات» في الثاني — معكوسَين عمّا في الملف.
  ///    وما لا يعرفه هذا الترتيب يبقى في ذيل القائمة كما جاء.
  static const List<String> _designOrder = [
    "شرح",
    "تلخيص",
    "سؤال",
    "اختبارات",
    "وزاري",
  ];

  List<String> _inDesignOrder(List<String> modes) {
    final known = [for (final m in _designOrder) if (modes.contains(m)) m];
    return [...known, ...modes.where((m) => !_designOrder.contains(m))];
  }

  void _pickMode(BuildContext context, String m) {
    // 🧠 «اختبارات» ليست وضع محادثة — تفتح شاشة الاختبار مباشرةً
    //    بالمادة والصف المحدَّدين مسبقاً ([31§4]).
    if (m == Curriculum.quizMode) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => QuizSetupScreen(
            initialSubject: c.selectedSubject,
            initialGrade: c.grade,
            initialTrack: c.track.key,
          ),
        ),
      );
      return;
    }
    c.switchContext(() {
      c.selectedMode = m;
      c.mathWazariQuestionsLoaded = false;
      if (m == "وزاري") {
        c.selectedExamYear = "";
        c.loadAvailableYears();
      } else {
        c.loadAvailableUnits();
      }
    });
  }

  // ===== محدّد نوع الإدخال (صفحة/برومت) =====
  Widget _inputTypeSelector() {
    // ⛔ الوزاري والسؤال وحدهما بلا اختيار (السؤال بحثٌ دلالي دائماً).
    //    وما عداهما: **كل المواد سواء** — كان الشرط يذكر أسماء مواد بعينها،
    //    فتظهر «صفحة/برومت» للأحياء وحدها ويبقى وضع الوحدات نصفَ واجهة.
    if (c.selectedMode == "وزاري" || c.selectedMode == "سؤال") {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          for (final t in const ["صفحة", "برومت"]) ...[
            Expanded(
                child: _PillToggle(
                    label: t,
                    selected: c.inputType == t,
                    onTap: () => c.update(() => c.inputType = t))),
            if (t == "صفحة") const SizedBox(width: 8),
          ],
        ],
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
          // ★ switchContext (وليس update): وضع الرياضيات جزء من نطاق المحادثات،
          //   فتبديله يجب أن يبدّل سجلّ المحادثات أيضاً.
          onSelected: (_) => c.switchContext(() {
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
            Icon(PI.graduationCap.regular, color: AppColors.primary, size: 20),
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
            ),
          const SizedBox(height: 12),
          if (c.mathExamLessons.isNotEmpty)
            ModernDropdown(
              hint: "اختر الدرس",
              value: c.selectedMathExamLesson.isEmpty ? null : c.selectedMathExamLesson,
              items: c.mathExamLessons,
              onChanged: (v) => c.update(() => c.selectedMathExamLesson = v!),
              leading: PD.notebook,
            ),
          if (c.selectedMathExamLesson.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  Icon(PI.listNumbers.regular, color: AppColors.primary, size: 20),
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
                icon: Icon(PI.downloadSimple.bold, size: 20),
                label: Text("جلب الأسئلة", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // 📊 مستوى التلخيص — شريطٌ بخمس درجات
  // ══════════════════════════════════════════════════
  // 🎨 **تصميم Figma** («الرفيق الذاكي» في وضع التلخيص · 12):
  //    عنوانٌ «مستوى التلخيص:» فوق الشريط، والشريطُ بعرض البطاقة كاملاً:
  //    ارتفاعُه 6 · الخاملُ `#E6F4FF` والنشطُ `#0092FF` · وأربع نقاطٍ
  //    زرقاءَ تقسمه خمس درجات · ومقبضٌ دائريٌّ نصفُ قطره 6.
  //
  // 📌 **والنشطُ يمتدّ من اليمين** — الشريطُ في RTL يبدأ من جهة القراءة،
  //    وفلاتر تتكفّل بذلك ما دام الاتجاه محفوظاً.
  //
  // 🔢 **والرقمُ باقٍ** وإن لم يرسمه المصمّم: من يحرّك مقبضاً بلا رقمٍ
  //    لا يعرف أين وقف ولا كيف يعود. وُضع في طرف السطر صغيراً بلون
  //    الهوية — لا شارةً رماديّةً كما كان.
  Widget _summarySlider() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text("مستوى التلخيص:",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.chipInk)),
              ),
              Text("${c.summaryLevel}",
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
            ],
          ),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              activeTrackColor: AppColors.primaryFill,
              inactiveTrackColor: AppColors.primaryTintSurface,
              thumbColor: AppColors.primaryFill,
              activeTickMarkColor: AppColors.surfaceWhite,
              inactiveTickMarkColor: AppColors.primaryFill,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              overlayColor: AppColors.primary500.withValues(alpha: 0.12),
              // 🚫 لا فقاعةَ قيمةٍ تطفو: الرقمُ مكتوبٌ فوق الشريط دائماً.
              showValueIndicator: ShowValueIndicator.never,
            ),
            child: Slider(
              min: 1,
              max: 5,
              divisions: 4,
              value: c.summaryLevel.toDouble(),
              onChanged: (v) => c.update(() => c.summaryLevel = v.toInt()),
            ),
          ),
        ],
      ),
    );
  }

  // ===== منطقة فلترة الوحدات/الوزاري لكل مادة =====
  // ===== 🆕 محدد مصدر المحتوى =====
  // ══════════════════════════════════════════════════
  // 📚 مصدر المحتوى — زرّان 154×32 · r12
  // ══════════════════════════════════════════════════
  // 🎨 **تصميم Figma:** عنوانٌ «اختر مصدر المحتوى:» 10/w700 `#62748E`،
  //    وتحته زرّان: الخامل `#F8FAFC` بحدّ `#E2E8F0` ونصُّه `#45556C`،
  //    والمختار `#E6F4FF` بحدّ `#0092FF` ونصُّه `#155DFC`. بلا أيقونات.
  Widget _contentModeSelector() {
    final lessonsOk = c.caps?.lessonsAvailable ?? false;
    final pagesOk = c.caps?.pagesAvailable ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🖋️ العناوينُ الصغيرة **غامقة** — الملف يقول w700 لكن Cairo في
        //    فلاتر يخرج أخفَّ من تصدير Figma، فالمطابقةُ بالمُخرَج.
        Text("اختر مصدر المحتوى:",
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: AppColors.sectionLabel)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
                child: _PillToggle(
                    label: "وضع الدروس",
                    selected: c.contentMode == "lessons",
                    // 🚧 «قيد الإضافة» يبقى: مادةٌ لم تُرفع دروسُها بعد
                    //    يجب أن يعرف الطالبُ لماذا لا تعمل.
                    disabledNote: lessonsOk ? null : "قيد الإضافة",
                    onTap: () => c.setContentMode("lessons"))),
            const SizedBox(width: 8),
            Expanded(
                child: _PillToggle(
                    label: "وضع الوحدات",
                    selected: c.contentMode == "pages",
                    disabledNote: pagesOk ? null : "قيد الإضافة",
                    onTap: () => c.setContentMode("pages"))),
          ],
        ),
      ],
    );
  }

  // ===== 🆕 منتقيا وضع الدروس (وحدة ← درس) =====
  Widget _lessonsModeArea() {
    if (c.capsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    final units = c.v3LessonsUnits;
    if (units.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text("📁 محتوى وضع الدروس لهذه المادة قيد الإضافة 🚧",
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );
    }
    return Column(children: [
      const SizedBox(height: 14),
      ModernDropdown(
        hint: "اختر الوحدة",
        value: c.selectedV3Unit.isEmpty ? null : c.selectedV3Unit,
        items: units,
        onChanged: (v) => c.setV3Unit(v ?? ""),
      ),
      const SizedBox(height: 12),
      ModernDropdown(
        hint: "اختر الدرس",
        value: c.selectedV3Lesson.isEmpty ? null : c.selectedV3Lesson,
        items: c.v3LessonsInSelectedUnit,
        onChanged: (v) => c.setV3Lesson(v ?? ""),
        leading: PD.notebook,
      ),
      if (c.selectedV3Lesson.isNotEmpty) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          // ❓ **والوعدُ يتبع الوضع**: في وضع السؤال لا يعمل الإرسالُ الفارغ
          //    ([ChatController.questionNeedsTypedText])، فالسطرُ القديم
          //    «اضغط إرسال مباشرة» كان سيَعِد بما لا يقع — وهي بعينها
          //    العلّةُ التي جعلت الزرَّ رمادياً ووعدَ اللوحة قائماً من قبل.
          child: Text(
              c.questionNeedsTypedText
                  ? "❓ اكتب سؤالك عن الدرس — وضعُ السؤال للإجابات القصيرة المحدّدة"
                  : "✅ اضغط إرسال مباشرة لشرح الدرس كاملاً، أو اكتب سؤالك فيه",
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
        ),
      ],
    ]);
  }

  Widget _unitFilterArea() {
    // 🔴 وضع الوزاري
    if (c.selectedMode == "وزاري") {
      if (c.selectedSubject == "رياضيات") {
        return const SizedBox.shrink();
      }

      // 🚧 بنك الوزاري مخزَّن لكل صف على حدة — إن كان صف الطالب بلا بنك
      //    نقولها صراحةً بدل قوائم فارغة بلا تفسير.
      if (c.yearsLoading) {
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
        );
      }
      if (c.availableYears.isEmpty) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            "📁 الأسئلة الوزارية لـ«${c.selectedSubject}» في ${c.gradeLabel}"
            "${Curriculum.hasTracks(c.grade) ? ' ${c.trackLabel}' : ''} لم تُضف بعد 🚧",
            style: TextStyle(fontSize: 12.5, height: 1.6, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
          ),
        );
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
            ),
            const SizedBox(height: 12),
            if (c.selectedArabicExamSection.isNotEmpty)
              ModernDropdown(
                hint: "نوع التدريب (قطعة أم أسئلة عامة؟)",
                value: c.selectedArabicExamType.isEmpty ? null : c.selectedArabicExamType,
                items: c.arabicExamTypes,
                onChanged: (v) => c.update(() => c.selectedArabicExamType = v!),
              ),
            if (c.selectedArabicExamType.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(PI.listNumbers.regular, color: AppColors.primary, size: 20),
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
                  backgroundColor: isArabicReady ? AppColors.primary : AppColors.softSurface,
                  foregroundColor: isArabicReady ? Colors.white : AppColors.textSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  elevation: isArabicReady ? 4 : 0,
                ),
                onPressed: isArabicReady ? () {
                  final count = int.tryParse(c.arabicQuestionCountController.text) ?? (c.selectedArabicExamType == "قطعة" ? 1 : 5);
                  String content = "${c.selectedArabicExamYear}|${c.selectedArabicExamSection}|${c.selectedArabicExamType}|$count";
                  c.setShowSettingsPanel(false);
                  c.processRequest(customText: content);
                } : null,
                icon: Icon(PI.downloadSimple.bold, size: 20),
                label: Text("جلب الأسئلة", style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
            if (!isArabicReady)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text("اختر جميع الخيارات أولاً", style: TextStyle(color: AppColors.warning800, fontSize: 12, fontWeight: FontWeight.w600)),
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
            ),
            const SizedBox(height: 12),
            ModernDropdown(
              hint: "Choose Question Type",
              value: c.selectedEnglishQuestionType.isEmpty ? null : c.selectedEnglishQuestionType,
              items: c.englishQuestionTypes,
              onChanged: (v) => c.update(() => c.selectedEnglishQuestionType = v!),
            ),
            if (c.selectedEnglishQuestionType.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    Icon(PI.listNumbers.regular, color: AppColors.primary, size: 20),
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
                icon: Icon(PI.rocketLaunch.regular, size: 20),
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
        ),
      );
    }

    // ══ وضع الوحدات: وحدة ← (صفحة/برومت) — لكل المواد بالبناء نفسه ══
    // 📄 **لا اسم مادة هنا.** الوحدات تأتي من `/content/capabilities`
    //    (`pages.units`)، فأي مادة يُضاف لها ملف في `unit_mode` تظهر وحداتها
    //    تلقائياً. وهنا كان العطل: الشاشة تسأل عن **اسم المادة** لا عن
    //    المحتوى، فالكيمياء تُعبَّأ بياناتها ولا تنال ما نالته الأحياء —
    //    وتُعرض لها بدلها قائمةُ دروسٍ من المسار القديم يتجاهلها الخادم أصلاً.
    if (c.capsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))),
      );
    }
    if (c.availableUnits.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Text("📄 محتوى وضع الوحدات لهذه المادة قيد الإضافة 🚧",
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: ModernDropdown(
        hint: "اختر الوحدة",
        value: c.availableUnits.contains(c.selectedUnit) ? c.selectedUnit : null,
        items: c.availableUnits.toSet().toList(),
        onChanged: (v) => c.update(() {
          // 📚 لا «الكل» بعد اليوم — قائمةُ الوحدات وحدها ([_applyPagesUnits]).
          c.selectedUnit = v ?? c.selectedUnit;
          c.selectedUnitName = c.selectedUnit;
        }),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 🏷️ شريحة وضعٍ واحدة — ارتفاع 35 · r12
// ══════════════════════════════════════════════════
class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;

  /// بانيةُ الأيقونة باللون — لا `IconData`: «ورقةٌ عليها صحّ» مركّبةٌ من
  /// رمزين ([PFileCheck])، فلا يسعُها نوعُ الأيقونة الواحدة.
  final Widget Function(Color) icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 35,
            // 📏 **16 لا 11** — مقيسةٌ من التصدير: الفجوةُ بين نصَّي شريحتين
            //    متجاورتين 38pt = حشوةٌ يمنى 16 + فاصل 6 + حشوةٌ يسرى 16.
            //    وبها يمتلئ الصفُّ عرضَ الحاوية ويلتفّ «وزاري» إلى السطر
            //    الثاني في الموضع نفسه الذي التفّ فيه عند المصمّم —
            //    وبالـ11 كانت الشرائحُ تتكوّم يميناً ويبقى اليسارُ فارغاً.
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryFill : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon(selected ? Colors.white : AppColors.rowAction),
                const SizedBox(width: 6),
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        // 🖋️ **w900 لا w700**: خطّ Cairo في فلاتر يخرج أخفَّ
                        //    من تصدير Figma عند الوزن نفسه — تقاس المطابقة
                        //    بالمُخرَج لا بالرقم المكتوب في الملف.
                        fontWeight: FontWeight.w900,
                        color:
                            selected ? Colors.white : AppColors.rowAction)),
              ],
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🔘 زرّ اختيارٍ مسطّح — 32 ارتفاعاً · r12
// ══════════════════════════════════════════════════
class _PillToggle extends StatelessWidget {
  const _PillToggle({
    required this.label,
    required this.selected,
    required this.onTap,
    this.disabledNote,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// سببُ عدم التوفّر — يُعرض سطراً صغيراً تحت الاسم بدل إخفاء الزرّ.
  final String? disabledNote;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: const BoxConstraints(minHeight: 32),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primaryTintSurface
                  : AppColors.chipSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? AppColors.primary : AppColors.rowBorder),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: selected
                            ? AppColors.sendButton
                            : AppColors.chipInk)),
                if (disabledNote != null)
                  Text(disabledNote!,
                      style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          color: AppColors.warning900)),
              ],
            ),
          ),
        ),
      );
}
