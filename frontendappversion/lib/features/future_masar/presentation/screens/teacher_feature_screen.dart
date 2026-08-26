import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../../../core/widgets/modern_dropdown.dart';
import '../../../../core/widgets/typewriter_text.dart';
import '../../../../core/widgets/typing_indicator.dart';
import '../../data/demo_data.dart';
import '../../data/demo_state.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/robot_widget.dart';

enum TeacherFeature { lessonPlan, simplify, homework, openChat }

const _grades = ["الأول الثانوي", "الثاني الثانوي", "الثالث الثانوي"];

// ==========================================
// 👨‍🏫 صفحة ميزة مساعد المعلم (إعداد + محادثة مستقلة محفوظة)
// ==========================================
class TeacherFeatureScreen extends StatefulWidget {
  final TeacherFeature feature;
  const TeacherFeatureScreen({super.key, required this.feature});

  @override
  State<TeacherFeatureScreen> createState() => _TeacherFeatureScreenState();
}

class _TeacherFeatureScreenState extends State<TeacherFeatureScreen> {
  final _input = TextEditingController();
  final _concept = TextEditingController();
  final _scroll = ScrollController();

  late String _subject;
  late String _grade;
  late String _unit;
  late String _lesson;
  String _difficulty = "متوسط";
  int _count = 10;

  bool _generating = false;
  bool _typing = false;

  String get _key => switch (widget.feature) {
        TeacherFeature.lessonPlan => "plan",
        TeacherFeature.simplify => "simplify",
        TeacherFeature.homework => "homework",
        TeacherFeature.openChat => "chat",
      };

  String get _title => switch (widget.feature) {
        TeacherFeature.lessonPlan => "📖 خطة درس جديدة",
        TeacherFeature.simplify => "💡 تبسيط مفهوم",
        TeacherFeature.homework => "📝 إنشاء واجب",
        TeacherFeature.openChat => "🤖 مساعد المعلم",
      };

  List<TeacherMsg> get _messages => DemoState.I.teacherChats[_key]!;

  bool get _hasSetup => widget.feature != TeacherFeature.openChat;

  @override
  void initState() {
    super.initState();
    _subject = demoSubjects.first;
    _grade = _grades[DemoState.I.grade - 1];
    _unit = demoCurriculum[_subject]!.keys.first;
    _lesson = demoCurriculum[_subject]![_unit]!.first;
  }

  @override
  void dispose() {
    _input.dispose();
    _concept.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<String> get _units => demoCurriculum[_subject]!.keys.toList();
  List<String> get _unitLessons => demoCurriculum[_subject]![_unit] ?? const [];
  List<String> get _allLessons => demoCurriculum[_subject]!.values.expand((e) => e).toList();

  void _onSubject(String s) {
    setState(() {
      _subject = s;
      _unit = demoCurriculum[s]!.keys.first;
      _lesson = demoCurriculum[s]![_unit]!.first;
    });
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
    });
  }

  // ===== توليد المحتوى (خطة/تبسيط/واجب) =====
  void _generate() {
    String userText;
    String aiText;
    switch (widget.feature) {
      case TeacherFeature.lessonPlan:
        userText = "أنشئ خطة درس لدرس: $_lesson ($_subject — $_grade)";
        aiText = _planResponse();
        break;
      case TeacherFeature.simplify:
        final concept = _concept.text.trim();
        if (concept.isEmpty) {
          _snack("اكتب المفهوم الذي تريد تبسيطه أولاً");
          return;
        }
        userText = "بسّط مفهوم: $concept ($_subject)";
        aiText = _simplifyResponse(concept);
        break;
      case TeacherFeature.homework:
        userText = "أنشئ واجباً: $_lesson — $_difficulty — $_count أسئلة";
        aiText = _homeworkResponse();
        break;
      case TeacherFeature.openChat:
        return;
    }

    setState(() => _generating = true);
    _scrollDown();
    Future.delayed(const Duration(milliseconds: 2300), () {
      if (!mounted) return;
      _messages.add(TeacherMsg("user", userText));
      _messages.add(TeacherMsg("ai", aiText, animate: true));
      setState(() => _generating = false);
      _scrollDown();
    });
  }

  // ===== المحادثة العادية =====
  void _send([String? preset]) {
    final t = (preset ?? _input.text).trim();
    if (t.isEmpty || _typing || _generating) return;
    _messages.add(TeacherMsg("user", t));
    _input.clear();
    setState(() => _typing = true);
    _scrollDown();
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      _messages.add(TeacherMsg("ai", _chatReply(t), animate: true));
      setState(() => _typing = false);
      _scrollDown();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Column(
            children: [
              GlassBar(title: _title, subtitle: "مساعد المعلم — عرض تجريبي"),
              Expanded(
                child: Stack(
                  children: [
                    ListView(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      children: [
                        if (_hasSetup) _setupCard(),
                        if (_hasSetup) const SizedBox(height: 8),
                        ..._messages.map(_bubble),
                        if (_typing) const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: 10, top: 6, bottom: 14), child: TypingIndicator())),
                      ],
                    ),
                    if (_generating) _loadingOverlay(),
                  ],
                ),
              ),
              _suggestionChips(),
              _inputBar(),
            ],
          ),
        ],
      ),
    );
  }

  // ===== إعداد كل ميزة =====
  Widget _setupCard() {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.tune_rounded, color: AppColors.primary, size: 18),
            const SizedBox(width: 8),
            Text("إعدادات ${widget.feature == TeacherFeature.homework ? 'الواجب' : (widget.feature == TeacherFeature.simplify ? 'التبسيط' : 'الدرس')}", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary, fontSize: 14)),
          ]),
          const SizedBox(height: 14),
          ModernDropdown(hint: "المادة", value: _subject, items: demoSubjects, onChanged: (v) => _onSubject(v!), icon: Icons.book_rounded),
          const SizedBox(height: 10),
          ModernDropdown(hint: "الصف", value: _grade, items: _grades, onChanged: (v) => setState(() => _grade = v!), icon: Icons.school_rounded),
          if (widget.feature == TeacherFeature.lessonPlan) ...[
            const SizedBox(height: 10),
            ModernDropdown(hint: "الوحدة", value: _unit, items: _units, onChanged: (v) => setState(() { _unit = v!; _lesson = _unitLessons.first; }), icon: Icons.library_books_rounded),
            const SizedBox(height: 10),
            ModernDropdown(hint: "الدرس", value: _lesson, items: _unitLessons, onChanged: (v) => setState(() => _lesson = v!), icon: Icons.menu_book_rounded),
          ] else if (widget.feature == TeacherFeature.homework) ...[
            const SizedBox(height: 10),
            ModernDropdown(hint: "الدرس", value: _allLessons.contains(_lesson) ? _lesson : _allLessons.first, items: _allLessons, onChanged: (v) => setState(() => _lesson = v!), icon: Icons.menu_book_rounded),
            const SizedBox(height: 12),
            Text("مستوى الصعوبة:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(children: ["سهل", "متوسط", "صعب"].map((d) => _pill(d, _difficulty == d, () => setState(() => _difficulty = d))).toList()),
            const SizedBox(height: 12),
            Text("عدد الأسئلة:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12.5)),
            const SizedBox(height: 8),
            Row(children: [5, 10, 15].map((n) => _pill("$n", _count == n, () => setState(() => _count = n))).toList()),
          ] else if (widget.feature == TeacherFeature.simplify) ...[
            const SizedBox(height: 10),
            ModernDropdown(hint: "الدرس", value: _allLessons.contains(_lesson) ? _lesson : _allLessons.first, items: _allLessons, onChanged: (v) => setState(() => _lesson = v!), icon: Icons.menu_book_rounded),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
              child: TextField(
                controller: _concept,
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: "ما المفهوم الذي تريد تبسيطه؟",
                  hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13.5),
                  prefixIcon: Icon(Icons.lightbulb_outline_rounded, color: AppColors.secondary, size: 20),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          GradientButton(label: _genLabel, onTap: _generate, height: 52),
        ],
      ),
    );
  }

  String get _genLabel => switch (widget.feature) {
        TeacherFeature.lessonPlan => "🚀 إنشاء خطة الدرس",
        TeacherFeature.simplify => "✨ تبسيط المفهوم",
        TeacherFeature.homework => "🚀 إنشاء الواجب",
        TeacherFeature.openChat => "",
      };

  Widget _pill(String label, bool sel, VoidCallback onTap) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.softSurface, borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(label, style: TextStyle(fontWeight: FontWeight.w900, color: sel ? Colors.white : AppColors.textSecondary, fontSize: 13))),
          ),
        ),
      ),
    );
  }

  // ===== فقاعة الرسالة =====
  Widget _bubble(TeacherMsg m) {
    final isUser = m.role == "user";
    return FadeInSlide(
      beginOffset: Offset(isUser ? -0.05 : 0.05, 0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser)
              Container(
                margin: const EdgeInsets.only(left: 10, bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.surfaceWhite, shape: BoxShape.circle, boxShadow: AppColors.bubbleShadow),
                child: Icon(Icons.co_present_rounded, color: AppColors.primary, size: 16),
              ),
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                decoration: BoxDecoration(
                  gradient: isUser ? AppColors.bubbleGradient : null,
                  color: isUser ? null : AppColors.surfaceWhite,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(22),
                    topRight: const Radius.circular(22),
                    bottomLeft: Radius.circular(isUser ? 22 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 22),
                  ),
                  boxShadow: AppColors.bubbleShadow,
                ),
                child: (m.animate && !isUser)
                    ? TypewriterText(
                        text: m.text,
                        onTyping: _scrollDown,
                        onFinished: () {
                          m.animate = false;
                          if (mounted) setState(() {});
                        },
                      )
                    : Text(m.text, style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary, fontSize: 14.5, fontWeight: FontWeight.w500, height: 1.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ===== شرائح الاقتراحات =====
  Widget _suggestionChips() {
    // تظهر فقط بعد وجود رسائل (لتكملة المحادثة)
    if (_messages.isEmpty) return const SizedBox.shrink();
    final chips = switch (widget.feature) {
      TeacherFeature.lessonPlan => ["أضف مثالاً من الحياة", "اجعل النشاط مناسباً للمجموعات", "أضف سؤال تقويم إضافي"],
      TeacherFeature.simplify => ["اعطني تشبيهاً آخر", "كيف أشرحه لطالب ضعيف؟", "أضف نشاطاً بصرياً"],
      TeacherFeature.homework => ["أضف سؤال مقال", "اجعله أصعب قليلاً", "أضف الحلول النموذجية"],
      TeacherFeature.openChat => ["كيف أدير وقت الحصة؟", "أفكار لتقييم سريع", "كيف أتعامل مع الطلاب الخجولين؟"],
    };
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: chips
            .map((p) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ActionChip(
                    label: Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                    onPressed: () => _send(p),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.softShadow, border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.1))),
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                onSubmitted: (_) => _send(),
                style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: "اكتب رسالتك...",
                  hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            onTap: () => _send(),
            borderRadius: BorderRadius.circular(30),
            child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(gradient: AppColors.mainGradient, shape: BoxShape.circle, boxShadow: AppColors.softShadow), child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22)),
          ),
        ],
      ),
    );
  }

  Widget _loadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: AppColors.bgLight.withValues(alpha: 0.85),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const RobotWidget(size: 110, state: RobotState.think),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: TypewriterText(text: _loadingText, isCentered: true),
              ),
              const SizedBox(height: 20),
              SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation(AppColors.primary))),
            ],
          ),
        ),
      ),
    );
  }

  String get _loadingText => switch (widget.feature) {
        TeacherFeature.lessonPlan => "يقوم مسار بإعداد خطة الدرس...",
        TeacherFeature.simplify => "يقوم مسار بتبسيط المفهوم...",
        TeacherFeature.homework => "يقوم مسار بإنشاء الواجب...",
        TeacherFeature.openChat => "",
      };

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  // ===== ردود وهمية =====
  String _planResponse() =>
      "📖 **خطة درس: $_lesson**\n($_subject — الصف $_grade)\n\n"
      "**🎯 أهداف الدرس:**\n- أن يتعرّف الطالب على $_lesson.\n- أن يطبّق المفاهيم في أمثلة عملية.\n- أن يحلّ تمارين متنوعة بثقة.\n\n"
      "**⏱️ التهيئة (5 دقائق):**\nسؤال تحفيزي يربط $_lesson بحياة الطالب اليومية لجذب الانتباه.\n\n"
      "**📚 خطوات الشرح:**\n1. مقدمة مبسطة عن الموضوع.\n2. شرح المفهوم الأساسي مدعوماً بالأمثلة.\n3. مناقشة تفاعلية وأسئلة موجّهة.\n\n"
      "**✏️ النشاط:**\nنشاط جماعي: يحل الطلاب تمريناً في مجموعات صغيرة ثم يعرضون نتائجهم.\n\n"
      "**✅ التقويم:**\nأسئلة قصيرة شفوية وكتابية للتأكد من تحقق الأهداف.\n\n"
      "**🏠 الواجب:**\nحل تمارين الكتاب المتعلقة بـ $_lesson مع إعداد مثال شخصي.\n\n"
      "*(عرض تجريبي — مساعد المعلم من مسار)*";

  String _simplifyResponse(String concept) =>
      "💡 **تبسيط مفهوم: $concept**\n\n"
      "**الفكرة باختصار:** يمكن تقديم \"$concept\" كخطوة منطقية تبني على ما يعرفه الطالب مسبقاً.\n\n"
      "**تشبيه من الحياة:** تخيّل أن \"$concept\" مثل موقف يومي قريب من الطالب — اربطه بشيء ملموس يراه كل يوم.\n\n"
      "**أفضل طريقة للشرح:**\n1. ابدأ بمثال محسوس من الواقع.\n2. اربط المثال بالمفهوم المجرّد تدريجياً.\n3. اطلب من الطلاب توليد أمثلتهم الخاصة.\n4. اختم بسؤال قصير يقيس الفهم.\n\n"
      "*(عرض تجريبي)*";

  String _homeworkResponse() {
    final b = StringBuffer();
    b.writeln("📝 **واجب: $_lesson**");
    b.writeln("المستوى: $_difficulty — عدد الأسئلة: $_count\n");
    for (int i = 1; i <= _count; i++) {
      b.writeln("$i. سؤال ($_difficulty) حول $_lesson يقيس فهم الطالب وتطبيقه.");
    }
    b.write("\n*(عرض تجريبي — يمكن تصدير الواجب وطباعته في النسخة الكاملة)*");
    return b.toString();
  }

  String _chatReply(String q) =>
      "🤖 **(عرض تجريبي)** بخصوص \"$q\":\n\n"
      "إليك اقتراحاً عملياً يناسب صفّك وقابلاً للتطبيق مباشرة في الحصة، مع خطوات واضحة وأمثلة. تريد أن أفصّل أكثر أو أجهّز لك خطة/واجباً جاهزاً؟";
}
