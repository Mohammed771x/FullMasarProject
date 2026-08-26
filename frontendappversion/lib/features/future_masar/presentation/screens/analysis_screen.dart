import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../data/demo_data.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/robot_assistant.dart';
import 'quiz_loading_screen.dart';
import 'quiz_screen.dart';
import 'subject_analysis_screen.dart';

// ==========================================
// 📊 صفحة "تحليل مستواي"
// ==========================================
class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Column(
            children: [
              const GlassBar(title: "تحليل مستواي 📊", subtitle: "قوتك، ضعفك، وتوصياتك"),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                  children: [
                    FadeInSlide(child: _summaryCard()),
                    const SizedBox(height: 18),
                    FadeInSlide(delay: 0.1, child: _examPrepCard(context)),
                    const SizedBox(height: 22),
                    const SectionHeader("تحليل المواد"),
                    ...demoAnalysis.entries.toList().asMap().entries.map((e) => FadeInSlide(
                          delay: 0.1 + e.key * 0.06,
                          child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _subjectCard(context, e.value.key, e.value.value)),
                        )),
                  ],
                ),
              ),
            ],
          ),
          const RobotAssistant(screenId: "analysis"),
        ],
      ),
    );
  }

  Widget _summaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.mainGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          const Text("ملخص أدائك العام", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 16),
          Row(
            children: [
              _sumTile("${demoOverall.tests}", "عدد الاختبارات"),
              _divider(),
              _sumTile("${demoOverall.avg}%", "متوسط النتائج"),
            ],
          ),
          const Divider(color: Colors.white24, height: 26),
          Row(
            children: [
              _sumTile(demoOverall.bestSubject, "أفضل مادة"),
              _divider(),
              _sumTile("${demoOverall.lastResult}%", "آخر اختبار"),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sumTile(String value, String label) {
    return Expanded(
      child: Column(children: [
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: Colors.white24);

  Widget _examPrepCard(BuildContext context) {
    return InkWell(
      onTap: () => _openExamPrep(context),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF7C3AED)], begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(16)), child: const Text("📅", style: TextStyle(fontSize: 24))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("مراجعة سريعة قبل الاختبار", style: TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 5),
                  Text("أنشئ اختبار مراجعة يعتمد على نقاط ضعفك قبل الاختبار.", style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.arrow_circle_left_rounded, color: Colors.white.withValues(alpha: 0.9), size: 26),
          ],
        ),
      ),
    );
  }

  Widget _subjectCard(BuildContext context, String key, SubjectStats s) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectAnalysisScreen(subjectKey: key))),
      borderRadius: BorderRadius.circular(22),
      child: SoftCard(
        child: Row(
          children: [
            Text(s.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.subject, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    _stars(s.stars),
                    const SizedBox(width: 10),
                    Text(s.level, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _levelColor(s.stars))),
                  ]),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _stars(int n) => Row(children: List.generate(5, (i) => Icon(i < n ? Icons.star_rounded : Icons.star_outline_rounded, size: 17, color: Colors.amber)));

  Color _levelColor(int stars) => stars >= 5 ? Colors.green : (stars >= 4 ? AppColors.primary : Colors.orange);

  // ===== Bottom Sheet: مراجعة قبل الاختبار =====
  void _openExamPrep(BuildContext context) {
    String subjectKey = "رياضيات";
    int timing = 0; // 0 غداً / 1 خلال 3 أيام / 2 هذا الأسبوع
    int count = 10;
    final Set<String> enabledLessons = {...demoAnalysis[subjectKey]!.lessons.map((l) => l.name)};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final lessons = demoAnalysis[subjectKey]!.lessons;
          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 18, bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(4)))),
                  const SizedBox(height: 16),
                  Text("مراجعة قبل الاختبار 📅", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  const SizedBox(height: 16),
                  Text("المادة:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: demoAnalysis.keys.map((k) {
                      final sel = k == subjectKey;
                      return _sheetChip(demoAnalysis[k]!.subject, sel, () => setSheet(() {
                        subjectKey = k;
                        enabledLessons
                          ..clear()
                          ..addAll(demoAnalysis[k]!.lessons.map((l) => l.name));
                      }));
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  Text("موعد الاختبار:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _timeChip("غداً", timing == 0, () => setSheet(() => timing = 0)),
                    const SizedBox(width: 8),
                    _timeChip("خلال 3 أيام", timing == 1, () => setSheet(() => timing = 1)),
                    const SizedBox(width: 8),
                    _timeChip("هذا الأسبوع", timing == 2, () => setSheet(() => timing = 2)),
                  ]),
                  const SizedBox(height: 18),
                  Row(children: [
                    Icon(Icons.auto_awesome_rounded, size: 16, color: AppColors.secondary),
                    const SizedBox(width: 6),
                    Text("دروس مختارة تلقائياً حسب أخطائك السابقة:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 12)),
                  ]),
                  const SizedBox(height: 10),
                  ...lessons.map((l) {
                    final on = enabledLessons.contains(l.name);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => setSheet(() => on ? enabledLessons.remove(l.name) : enabledLessons.add(l.name)),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: on ? AppColors.primary.withValues(alpha: 0.07) : AppColors.softSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: on ? AppColors.primary.withValues(alpha: 0.4) : Colors.transparent, width: 1.4),
                          ),
                          child: Row(children: [
                            Icon(on ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: on ? AppColors.primary : AppColors.textSecondary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(child: Text(l.name, style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 13.5))),
                            Text("${l.errors} أخطاء", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.redAccent)),
                          ]),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Text("عدد الأسئلة:", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary, fontSize: 13)),
                  const SizedBox(height: 10),
                  Row(children: [5, 10, 15].map((n) {
                    final sel = n == count;
                    return Expanded(child: Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: InkWell(
                        onTap: () => setSheet(() => count = n),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.softSurface, borderRadius: BorderRadius.circular(14)), child: Center(child: Text("$n", style: TextStyle(fontWeight: FontWeight.w900, color: sel ? Colors.white : AppColors.textSecondary)))),
                      ),
                    ));
                  }).toList()),
                  const SizedBox(height: 22),
                  GradientButton(
                    label: "🚀 إنشاء اختبار المراجعة",
                    onTap: enabledLessons.isEmpty
                        ? () {}
                        : () {
                            final firstLesson = enabledLessons.first;
                            Navigator.pop(ctx);
                            Navigator.push(context, MaterialPageRoute(builder: (_) => QuizLoadingScreen(
                              lines: const ["يقوم مسار بتحليل نتائجك السابقة...", "ويجهّز اختبار مراجعة مخصصاً لك 🎯"],
                              next: (_) => QuizScreen(subject: subjectKey, count: count, isReview: true, reviewLesson: firstLesson),
                            )));
                          },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetChip(String label, bool sel, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }

  Widget _timeChip(String label, bool sel, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: sel ? AppColors.secondary : AppColors.softSurface, borderRadius: BorderRadius.circular(14)),
          child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textSecondary))),
        ),
      ),
    );
  }
}
