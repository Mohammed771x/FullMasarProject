import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../data/demo_data.dart';
import '../widgets/demo_widgets.dart';
import '../widgets/robot_assistant.dart';
import 'scholarship_detail_screen.dart';

// ==========================================
// 🌍 قائمة المنح — بحث + فلاتر + شارة الحالة
// ==========================================
class ScholarshipsScreen extends StatefulWidget {
  const ScholarshipsScreen({super.key});

  @override
  State<ScholarshipsScreen> createState() => _ScholarshipsScreenState();
}

class _ScholarshipsScreenState extends State<ScholarshipsScreen> {
  String _query = "";
  String _filter = "الكل";
  final _filters = ["الكل", "ممولة بالكامل", "جزئية", "مفتوحة الآن"];

  List<Scholarship> get _list {
    return demoScholarships.where((s) {
      if (_query.isNotEmpty && !s.name.contains(_query) && !s.country.contains(_query)) return false;
      switch (_filter) {
        case "ممولة بالكامل":
          return s.fundingType == "full";
        case "جزئية":
          return s.fundingType == "partial";
        case "مفتوحة الآن":
          return s.status == SchStatus.open;
        default:
          return true;
      }
    }).toList();
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
              const GlassBar(title: "المنح الدراسية 🎓", subtitle: "فرصتك للدراسة حول العالم"),
              // بحث
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(18), boxShadow: AppColors.bubbleShadow),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                    decoration: InputDecoration(
                      hintText: "ابحث عن منحة أو دولة...",
                      hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                  ),
                ),
              ),
              // فلاتر
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  children: _filters.map((f) {
                    final sel = f == _filter;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: ChoiceChip(
                        label: Text(f),
                        selected: sel,
                        selectedColor: AppColors.primary,
                        showCheckmark: false,
                        labelStyle: TextStyle(color: sel ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold, fontSize: 12.5),
                        backgroundColor: AppColors.surfaceWhite,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.1))),
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    );
                  }).toList(),
                ),
              ),
              // القائمة
              Expanded(
                child: _list.isEmpty
                    ? Center(child: Text("لا توجد نتائج", style: TextStyle(color: AppColors.textSecondary)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
                        itemCount: _list.length,
                        itemBuilder: (_, i) => FadeInSlide(delay: 0.05 * i, child: Padding(padding: const EdgeInsets.only(bottom: 14), child: _card(_list[i]))),
                      ),
              ),
            ],
          ),
          const RobotAssistant(screenId: "scholarships"),
        ],
      ),
    );
  }

  Widget _card(Scholarship s) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ScholarshipDetailScreen(scholarship: s))),
      borderRadius: BorderRadius.circular(24),
      child: SoftCard(
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(gradient: LinearGradient(colors: s.gradient), borderRadius: BorderRadius.circular(18)),
              child: Center(child: Text(s.flag, style: const TextStyle(fontSize: 30))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  const SizedBox(height: 3),
                  Text(s.shortDesc, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _statusBadge(s.status),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(SchStatus st) {
    final (String label, Color color) = switch (st) {
      SchStatus.open => ("🟢 التقديم مفتوح", Colors.green),
      SchStatus.soon => ("🟡 يفتح قريباً", Colors.orange),
      SchStatus.closed => ("🔴 مغلق حالياً", Colors.redAccent),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
