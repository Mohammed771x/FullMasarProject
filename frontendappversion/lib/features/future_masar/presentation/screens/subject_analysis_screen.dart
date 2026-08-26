import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../data/demo_data.dart';
import '../widgets/demo_widgets.dart';
import 'education_screen.dart';
import 'quiz_setup_screen.dart';

// ==========================================
// 📈 تحليل مادة محددة
// ==========================================
class SubjectAnalysisScreen extends StatelessWidget {
  final String subjectKey;
  const SubjectAnalysisScreen({super.key, required this.subjectKey});

  @override
  Widget build(BuildContext context) {
    final s = demoAnalysis[subjectKey]!;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Column(
            children: [
              GlassBar(title: "تحليل مادة ${s.subject}", subtitle: "${s.emoji} مستواك: ${s.level}"),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                  children: [
                    // شبكة الإحصائيات
                    FadeInSlide(
                      child: Row(children: [
                        _statCard("${s.avg}%", "متوسط النتائج", AppColors.primary, Icons.trending_up_rounded),
                        const SizedBox(width: 12),
                        _statCard("${s.tests}", "عدد الاختبارات", AppColors.secondary, Icons.assignment_rounded),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    FadeInSlide(
                      delay: 0.05,
                      child: Row(children: [
                        _statCard("${s.best}%", "أفضل نتيجة", Colors.green, Icons.emoji_events_rounded),
                        const SizedBox(width: 12),
                        _statCard("${s.last}%", "آخر نتيجة", Colors.orange, Icons.history_rounded),
                      ]),
                    ),
                    const SizedBox(height: 18),

                    // بطاقة التوصية الكبيرة
                    FadeInSlide(
                      delay: 0.1,
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: AppColors.mainGradient,
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: AppColors.softShadow,
                        ),
                        child: Column(
                          children: [
                            Text(s.recEmoji, style: const TextStyle(fontSize: 44)),
                            const SizedBox(height: 12),
                            Text(s.recText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14.5, height: 1.8, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),

                    const SectionHeader("دروس تحتاج مراجعة 📚"),
                    ...s.lessons.asMap().entries.map((e) => FadeInSlide(
                          delay: 0.1 + e.key * 0.06,
                          child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _lessonCard(context, e.value)),
                        )),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statCard(String value, String label, Color color, IconData icon) {
    return Expanded(
      child: SoftCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }

  Widget _lessonCard(BuildContext context, ReviewLesson l) {
    return InkWell(
      onTap: () => _openLessonSheet(context, l),
      borderRadius: BorderRadius.circular(20),
      child: SoftCard(
        child: Row(children: [
          Container(padding: const EdgeInsets.all(11), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: const Text("📚", style: TextStyle(fontSize: 20))),
          const SizedBox(width: 14),
          Expanded(child: Text(l.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: Colors.redAccent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Text("${l.errors} أخطاء", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ),
        ]),
      ),
    );
  }

  void _openLessonSheet(BuildContext context, ReviewLesson l) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 16),
            Text("ماذا تريد أن تفعل؟", textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            Text(l.name, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            _sheetBtn(context, "📖 شرح الدرس", const [Color(0xFF3B82F6), Color(0xFF1D4ED8)], () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => EducationScreen(initialSubject: subjectKey, autoPrompt: l.name)));
            }),
            const SizedBox(height: 12),
            _sheetBtn(context, "📄 تلخيص الدرس", const [Color(0xFF8B5CF6), Color(0xFF6D28D9)], () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => EducationScreen(initialSubject: subjectKey, autoPrompt: "لخّص لي ${l.name}")));
            }),
            const SizedBox(height: 12),
            _sheetBtn(context, "📝 اختبار جديد", const [Color(0xFF10B981), Color(0xFF059669)], () {
              Navigator.pop(ctx);
              Navigator.push(context, MaterialPageRoute(builder: (_) => QuizSetupScreen(initialSubject: subjectKey)));
            }),
          ],
        ),
      ),
    );
  }

  Widget _sheetBtn(BuildContext context, String label, List<Color> g, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 56,
        decoration: BoxDecoration(gradient: LinearGradient(colors: g, begin: Alignment.centerRight, end: Alignment.centerLeft), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: g.last.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))]),
        child: Center(child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w900))),
      ),
    );
  }
}
