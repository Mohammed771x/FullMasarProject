import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/demo_data.dart';
import '../../data/demo_state.dart';
import '../widgets/demo_chat.dart';
import '../widgets/demo_widgets.dart';
import '../../../../core/widgets/screen_tip.dart';

// ==========================================
// 🎓 قسم التعليم = واجهة المدرّس (صف + مادة + وضع + شات ذكي)
// ==========================================
class EducationScreen extends StatefulWidget {
  final String? initialSubject;
  final String? autoPrompt; // لإرسال سؤال تلقائي (من نقاط ضعف الاختبار)
  const EducationScreen({super.key, this.initialSubject, this.autoPrompt});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class _EducationScreenState extends State<EducationScreen> {
  late int _grade;
  late String _subject;
  String _mode = "شرح";

  @override
  void initState() {
    super.initState();
    _grade = DemoState.I.grade;
    _subject = widget.initialSubject ?? demoSubjects.first;
  }

  String get _welcome {
    if (widget.autoPrompt != null) {
      return "أهلاً! لنراجع \"${widget.autoPrompt}\" في مادة $_subject 📚 اطلب مني الشرح وسأبدأ.";
    }
    return "مرحباً بك في وضع \"$_mode\" لمادة $_subject 👋\nاكتب موضوعاً أو اسألني، أو جرّب المايك 🎤 والكاميرا 📷. (عرض تجريبي)";
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
              GlassBar(
                title: "مسار الطالب",
                subtitle: "الصف ${_gradeShort(_grade)}  •  $_subject",
                action: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.tips_and_updates_rounded, color: AppColors.secondary, size: 22),
                ),
              ),

              // شرائح الصفوف
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Row(
                  children: List.generate(3, (i) {
                    final g = i + 1;
                    final sel = g == _grade;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i < 2 ? 8 : 0),
                        child: InkWell(
                          onTap: () => setState(() => _grade = g),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary : AppColors.surfaceWhite,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: sel ? AppColors.bubbleShadow : [],
                              border: Border.all(color: sel ? Colors.transparent : AppColors.textSecondary.withValues(alpha: 0.1)),
                            ),
                            child: Center(child: Text("الصف ${_gradeShort(g)}", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textSecondary))),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // شرائح المواد
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  children: demoSubjects.map((s) {
                    final sel = s == _subject;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: sel,
                        selectedColor: AppColors.primary,
                        showCheckmark: false,
                        labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                        backgroundColor: AppColors.surfaceWhite,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.1))),
                        onSelected: (_) => setState(() => _subject = s),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // شرائح الأوضاع
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: demoModes.map((m) {
                    final sel = m == _mode;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: () => setState(() => _mode = m),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                          decoration: BoxDecoration(
                            color: sel ? AppColors.secondary.withValues(alpha: 0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: sel ? AppColors.secondary.withValues(alpha: 0.4) : Colors.transparent),
                          ),
                          child: Text(m, style: TextStyle(color: sel ? AppColors.secondary : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12.5)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 2),

              Expanded(
                child: DemoChat(
                  key: ValueKey("$_grade-$_subject-$_mode-${widget.autoPrompt}"),
                  subject: _subject,
                  contextLabel: "$_subject ($_mode) — الصف ${_gradeShort(_grade)}",
                  welcome: _welcome,
                  quickPrompts: demoSuggestedQuestions[_subject] ?? const [],
                  guestLimited: DemoState.I.isGuest,
                ),
              ),
            ],
          ),
          const ScreenTip(screenId: "education", text: "هنا قسم التعليم 📚 اختر المادة والوضع من الإعدادات، ثم اكتب سؤالك أو اطلب شرح درس."),
        ],
      ),
    );
  }

  String _gradeShort(int g) => switch (g) { 1 => "الأول", 2 => "الثاني", _ => "الثالث" };
}
