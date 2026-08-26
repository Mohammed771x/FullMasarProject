import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/demo_data.dart';
import '../widgets/demo_widgets.dart';
import 'quiz_loading_screen.dart';
import 'quiz_screen.dart';

// ==========================================
// ⚙️ إعداد الاختبار — مادة + وحدة + حتى 3 دروس + عدد الأسئلة
// ==========================================
class QuizSetupScreen extends StatefulWidget {
  final String? initialSubject;
  const QuizSetupScreen({super.key, this.initialSubject});

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  late String _subject;
  late String _unit;
  final Set<String> _lessons = {};
  int _count = 10;

  @override
  void initState() {
    super.initState();
    _subject = widget.initialSubject ?? demoSubjects.first;
    _unit = demoCurriculum[_subject]!.keys.first;
  }

  List<String> get _units => demoCurriculum[_subject]!.keys.toList();
  List<String> get _unitLessons => demoCurriculum[_subject]![_unit] ?? const [];

  void _setSubject(String s) {
    setState(() {
      _subject = s;
      _unit = demoCurriculum[s]!.keys.first;
      _lessons.clear();
    });
  }

  void _toggleLesson(String l) {
    setState(() {
      if (_lessons.contains(l)) {
        _lessons.remove(l);
      } else {
        if (_lessons.length >= 3) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Text("يمكنك اختيار 3 دروس كحد أقصى", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
          return;
        }
        _lessons.add(l);
      }
    });
  }

  void _start() {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => QuizLoadingScreen(
      lines: const ["يقوم مسار بإنشاء اختبار مخصص لك...", "بناءً على المادة والدروس التي اخترتها ✍️"],
      next: (_) => QuizScreen(subject: _subject, count: _count),
    )));
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
              const GlassBar(title: "إعداد الاختبار 📝", subtitle: "خصّص اختبارك بالتفصيل"),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                  children: [
                    _label("1. اختر المادة"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: demoSubjects.map((s) => _chip(s, s == _subject, () => _setSubject(s))).toList(),
                    ),
                    const SizedBox(height: 20),
                    _label("2. اختر الوحدة"),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _units.map((u) => _chip(u, u == _unit, () => setState(() { _unit = u; _lessons.clear(); }))).toList(),
                    ),
                    const SizedBox(height: 20),
                    _label("3. اختر الدروس (حتى 3)"),
                    ..._unitLessons.map((l) {
                      final sel = _lessons.contains(l);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: InkWell(
                          onTap: () => _toggleLesson(l),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: sel ? AppColors.primary.withValues(alpha: 0.08) : AppColors.surfaceWhite,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: sel ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.12), width: 1.5),
                              boxShadow: AppColors.bubbleShadow,
                            ),
                            child: Row(children: [
                              Icon(sel ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: sel ? AppColors.primary : AppColors.textSecondary, size: 22),
                              const SizedBox(width: 12),
                              Expanded(child: Text(l, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14))),
                            ]),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 20),
                    _label("4. عدد الأسئلة"),
                    Row(
                      children: [5, 10, 15].map((n) {
                        final sel = n == _count;
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: InkWell(
                              onTap: () => setState(() => _count = n),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surfaceWhite, borderRadius: BorderRadius.circular(14), boxShadow: AppColors.bubbleShadow),
                                child: Center(child: Text("$n", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: sel ? Colors.white : AppColors.textSecondary))),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
                  child: GradientButton(label: "ابدأ الاختبار 🚀", onTap: _start),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(t, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
      );

  Widget _chip(String label, bool sel, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: sel ? AppColors.primary : AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: sel ? Colors.transparent : AppColors.textSecondary.withValues(alpha: 0.12)),
          boxShadow: sel ? AppColors.bubbleShadow : [],
        ),
        child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}
