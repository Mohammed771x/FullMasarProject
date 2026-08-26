import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../data/demo_data.dart';
import '../../data/demo_state.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/robot_widget.dart';
import 'scholarship_detail_screen.dart';

// ==========================================
// 🧭 تقرير اختبار الميول
// ==========================================
class AptitudeResultScreen extends StatefulWidget {
  final Map<AptDim, int> tally;
  const AptitudeResultScreen({super.key, required this.tally});

  @override
  State<AptitudeResultScreen> createState() => _AptitudeResultScreenState();
}

class _AptitudeResultScreenState extends State<AptitudeResultScreen> {
  late final AptDim _top;
  late final List<MapEntry<AptDim, int>> _sorted;

  @override
  void initState() {
    super.initState();
    _sorted = widget.tally.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    _top = _sorted.first.key;
    DemoState.I.addResult({"type": "aptitude", "field": aptDimNames[_top], "score": _sorted.first.value, "total": 15});
  }

  String get _report =>
      "بناءً على إجاباتك، ميولك تتجه بقوة نحو **${aptDimNames[_top]}**. "
      "أنت تميل للتفكير والعمل ضمن هذا المجال، وتنسجم شخصيتك مع تحدياته. "
      "ننصحك باستكشاف التخصصات المقترحة أدناه، والتحدث مع مرشد أكاديمي، والاطلاع على المنح التي تدعم هذا المسار. "
      "تذكّر: الشغف + المهارة = مستقبل مشرق 🌟 (عرض تجريبي)";

  @override
  Widget build(BuildContext context) {
    final majors = aptSuggestedMajors[_top] ?? const [];
    final suggested = demoScholarships.where((s) => s.fundingType == "full").take(3).toList();
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
              children: [
                Align(alignment: Alignment.centerLeft, child: InkWell(onTap: () => Navigator.popUntil(context, (r) => r.isFirst), child: Icon(Icons.close_rounded, color: AppColors.textPrimary))),
                // بطاقة النتيجة
                FadeInSlide(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFEC4899), Color(0xFF8B5CF6)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: AppColors.softShadow,
                    ),
                    child: Column(
                      children: [
                        const RobotWidget(size: 90, state: RobotState.wave),
                        const SizedBox(height: 8),
                        const Text("مجالك الأقرب 🎯", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        Text(aptDimNames[_top] ?? "", textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // توزيع الميول
                const SectionHeader("توزيع ميولك"),
                ..._sorted.take(3).map((e) {
                  final pct = (e.value / 15).clamp(0.0, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        SizedBox(width: 120, child: Text(aptDimNames[e.key] ?? "", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textPrimary))),
                        const SizedBox(width: 8),
                        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(8), child: LinearProgressIndicator(value: pct, minHeight: 9, backgroundColor: AppColors.softSurface, valueColor: AlwaysStoppedAnimation(AppColors.secondary)))),
                        const SizedBox(width: 8),
                        Text("${(pct * 100).round()}%", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.secondary)),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                const SectionHeader("قراءة النتيجة 🤖"),
                SoftCard(child: Text(_report.replaceAll("**", ""), style: TextStyle(fontSize: 13.5, height: 1.9, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
                const SizedBox(height: 20),

                const SectionHeader("تخصصات مقترحة لك"),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: majors.map((m) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2)), boxShadow: AppColors.bubbleShadow),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.school_rounded, size: 16, color: AppColors.secondary),
                      const SizedBox(width: 8),
                      Text(m, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                    ]),
                  )).toList(),
                ),
                const SizedBox(height: 22),

                const SectionHeader("منح تناسب مجالك 🎓"),
                ...suggested.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScholarshipDetailScreen(scholarship: s))),
                        borderRadius: BorderRadius.circular(18),
                        child: SoftCard(
                          padding: const EdgeInsets.all(12),
                          child: Row(children: [
                            Container(width: 44, height: 44, decoration: BoxDecoration(gradient: LinearGradient(colors: s.gradient), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(s.flag, style: const TextStyle(fontSize: 22)))),
                            const SizedBox(width: 12),
                            Expanded(child: Text(s.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
                            Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary),
                          ]),
                        ),
                      ),
                    )),
                const SizedBox(height: 20),
                GradientButton(label: "مشاركة التقرير كصورة 📤", onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text("📤 مشاركة التقرير... (محاكاة)", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: AppColors.secondary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
