import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/demo_data.dart';
import '../../data/demo_state.dart';
import '../widgets/demo_chat.dart';
import '../widgets/demo_widgets.dart';
import 'aptitude_screen.dart';

// ==========================================
// 🏆 تفاصيل المنحة — تبويبات + مساعد المنحة
// ==========================================
class ScholarshipDetailScreen extends StatelessWidget {
  final Scholarship scholarship;
  const ScholarshipDetailScreen({super.key, required this.scholarship});

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: Column(
          children: [
            // رأس متدرّج
            Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 18, left: 18, right: 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: s.gradient, begin: Alignment.topRight, end: Alignment.bottomLeft),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
                boxShadow: [BoxShadow(color: s.gradient.last.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _iconBtn(context, Icons.arrow_back_rounded, () => Navigator.maybePop(context)),
                      const Spacer(),
                      _iconBtn(context, Icons.bookmark_border_rounded, () {}),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(s.flag, style: const TextStyle(fontSize: 50)),
                  const SizedBox(height: 4),
                  Text(s.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(s.shortDesc, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9))),
                ],
              ),
            ),

            // تبويبات
            Container(
              margin: const EdgeInsets.fromLTRB(14, 14, 14, 4),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.center,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(12), boxShadow: AppColors.bubbleShadow),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                tabs: const [Tab(text: "نبذة"), Tab(text: "المتطلبات"), Tab(text: "المواعيد"), Tab(text: "التقديم")],
              ),
            ),

            Expanded(
              child: TabBarView(
                children: [
                  _aboutTab(context, s),
                  _listTab(s.requirements, Icons.check_circle_rounded, Colors.green),
                  _datesTab(s),
                  _listTab(s.howToApply, Icons.arrow_circle_left_rounded, AppColors.primary, numbered: true),
                ],
              ),
            ),

            // زر مساعد المنحة
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: GradientButton(
                        label: "💬 اسأل مساعد المنحة",
                        onTap: () => _openAssistant(context, s),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () {
                          DemoState.I.scholarshipReminders.add(s.id);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: const Text("🔔 سنذكّرك قبل الإغلاق (محاكاة)", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                            backgroundColor: AppColors.secondary,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ));
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.4)),
                          child: Center(child: Text("🔔 ذكّرني", style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.white, size: 22)),
    );
  }

  Widget _aboutTab(BuildContext context, Scholarship s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      children: [
        // شريط اختبار الميول إن لم يُجرَ
        if (!DemoState.I.aptitudeDone)
          InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AptitudeScreen())),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: AppColors.secondary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.secondary.withValues(alpha: 0.2))),
              child: Row(children: [
                Icon(Icons.explore_rounded, color: AppColors.secondary),
                const SizedBox(width: 10),
                Expanded(child: Text("🧭 محتار في التخصص؟ جرّب اختبار الميول أولاً", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.secondary, fontSize: 12.5))),
                Icon(Icons.chevron_left_rounded, color: AppColors.secondary),
              ]),
            ),
          ),
        Row(children: [
          InfoPill(Icons.workspace_premium_rounded, s.fundingType == "full" ? "ممولة بالكامل" : "تمويل جزئي", color: s.gradient.first),
        ]),
        const SizedBox(height: 16),
        const SectionHeader("نبذة عن المنحة"),
        SoftCard(child: Text(s.about, style: TextStyle(fontSize: 14, height: 1.9, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
      ],
    );
  }

  Widget _listTab(List<String> items, IconData icon, Color color, {bool numbered = false}) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      itemCount: items.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SoftCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              numbered
                  ? Container(width: 28, height: 28, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle), child: Center(child: Text("${i + 1}", style: TextStyle(color: color, fontWeight: FontWeight.w900))))
                  : Icon(icon, color: color, size: 22),
              const SizedBox(width: 12),
              Expanded(child: Text(items[i], style: TextStyle(fontSize: 13.5, height: 1.5, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datesTab(Scholarship s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
      children: [
        _dateCard("📅 فتح التقديم", s.openDate, Colors.green),
        const SizedBox(height: 12),
        _dateCard("⏳ إغلاق التقديم", s.closeDate, Colors.redAccent),
        const SizedBox(height: 12),
        SoftCard(
          child: Row(children: [
            Icon(Icons.info_rounded, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text("راقب المواعيد جيداً وجهّز ملفك مبكراً — التقديم المبكر يزيد فرصك.", style: TextStyle(fontSize: 12.5, height: 1.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
          ]),
        ),
      ],
    );
  }

  Widget _dateCard(String label, DateTime d, Color color) {
    return SoftCard(
      child: Row(children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.event_rounded, color: color)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text("${d.day} / ${d.month} / ${d.year}", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        ])),
      ]),
    );
  }

  void _openAssistant(BuildContext context, Scholarship s) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Column(
            children: [
              GlassBar(title: "مساعد ${s.country}", subtitle: s.name),
              Expanded(
                child: DemoChat(
                  subject: s.name,
                  contextLabel: "منحة ${s.country}",
                  welcome: "أهلاً! أنا مساعد ${s.name} 😊 اسألني عن الشروط، المواعيد، الوثائق، أو نصائح القبول. (عرض تجريبي)",
                  quickPrompts: const ["ما شروط التقديم؟", "ما الوثائق المطلوبة؟", "متى آخر موعد؟", "كيف أكتب خطاب الدافع؟"],
                ),
              ),
            ],
          ),
        ],
      ),
    )));
  }
}
