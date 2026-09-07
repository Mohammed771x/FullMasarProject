import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../banners/data/banner_model.dart';
import '../../banners/presentation/banner_carousel.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/screen_tip.dart';
import '../../future_masar/presentation/widgets/demo_widgets.dart';
import '../data/models/scholarship.dart';
import '../data/scholarship_repository.dart';
import 'scholarship_detail_screen.dart';

// ==========================================
// 🎓 قائمة المنح — بيانات حقيقية من الخادم
// ==========================================
// ما تغيّر عن نسخة الديمو (وسببه):
//   • **المصدر:** الخادم + كاش على القرص، بدل قائمة ثابتة في الكود.
//   • **حالات الشاشة الأربع** كلها معالَجة: تحميل · فارغ · خطأ · بيانات.
//     الديمو لم يكن يعرف إلا حالة واحدة لأن بياناته لا تفشل أبداً.
//   • **السحب للتحديث** + شارة «من الكاش» — الطالب يعرف ما يرى.
//   • **فلتر «تُغلق قريباً»** الذي ينقذ من تفويت موعد، و**عدّاد الأيام**
//     على الكرت — أهم رقم في القسم كله.
//   • **الترتيب:** المفتوحة أولاً ثم القريبة ثم المغلقة داخل ترتيب الأدمن.
class ScholarshipsScreen extends StatefulWidget {
  const ScholarshipsScreen({super.key});

  @override
  State<ScholarshipsScreen> createState() => _ScholarshipsScreenState();
}

class _ScholarshipsScreenState extends State<ScholarshipsScreen> {
  final _repo = ScholarshipRepository();
  final _search = TextEditingController();

  List<Scholarship> _all = const [];
  SchFilter _filter = SchFilter.all;
  String _query = "";
  bool _loading = true;
  bool _fromCache = false;
  String? _error;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    if (!force) {
      // 📴 اعرض الكاش فوراً إن وُجد، ثم صحّح من الشبكة — بلا شاشة تحميل بيضاء.
      final cached = await _repo.readCache();
      if (cached != null && mounted) {
        setState(() {
          _all = cached.items;
          _fromCache = true;
          _loading = false;
        });
      }
    }
    try {
      final result = await _repo.fetch(force: force);
      if (!mounted) return;
      setState(() {
        _all = result.items;
        _fromCache = result.fromCache;
        _message = result.message;
        _error = null;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_all.isEmpty) _error = "تعذّر تحميل المنح — تحقّق من اتصالك بالإنترنت.";
      });
    }
  }

  /// الترتيب النهائي: ترتيب الأدمن أولاً، ثم الحالة (المفتوح قبل المغلق).
  /// ★ منحة مغلقة أعلى القائمة تُشعر الطالب أن القسم مهجور.
  List<Scholarship> get _visible {
    final list = _all.where((s) => s.matches(_query) && _filter.test(s)).toList();
    int rank(SchStatus s) => switch (s) {
          SchStatus.open => 0,
          SchStatus.soon => 1,
          SchStatus.closed => 2,
        };
    list.sort((a, b) {
      final byStatus = rank(a.status).compareTo(rank(b.status));
      if (byStatus != 0) return byStatus;
      return a.order.compareTo(b.order);
    });
    return list;
  }

  int get _openCount => _all.where((s) => s.status == SchStatus.open).length;

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
                title: "المنح الدراسية 🎓",
                subtitle: _all.isEmpty
                    ? "فرصتك للدراسة حول العالم"
                    : "$_openCount منحة مفتوحة الآن من ${_all.length}",
                action: IconButton(
                  tooltip: "تحديث",
                  onPressed: () => _load(force: true),
                  icon: Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
                ),
              ),
              _searchField(),
              // 🎏 بانر قسم المنح — يُدار من لوحة التحكم.
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                child: BannerCarousel(
                  section: BannerSection.scholarships,
                  onAction: _onBannerAction,
                  height: 110,
                ),
              ),
              _filterChips(),
              Expanded(child: _body()),
            ],
          ),
          const ScreenTip(
            screenId: "scholarships",
            text: "تصفّح المنح 🎓 افتح أي منحة لترى شروطها ومواعيدها — "
                "ثم اسأل مساعدها عن أي تفصيل.",
          ),
        ],
      ),
    );
  }

  // ══════════════ الأجزاء ══════════════

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(18),
          boxShadow: AppColors.bubbleShadow,
        ),
        child: TextField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: "ابحث عن منحة أو دولة...",
            hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    icon: Icon(Icons.close_rounded,
                        size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = "");
                    },
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: SchFilter.values.map((f) {
          final selected = f == _filter;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(f.label),
              selected: selected,
              selectedColor: AppColors.primary,
              showCheckmark: false,
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
              backgroundColor: AppColors.surfaceWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
                side: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.1)),
              ),
              onSelected: (_) => setState(() => _filter = f),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _body() {
    if (_loading && _all.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _all.isEmpty) {
      return _empty(Icons.wifi_off_rounded, _error!, retry: true);
    }
    if (_all.isEmpty) {
      return _empty(Icons.school_outlined,
          _message ?? "لا منح متاحة حالياً 🎓\nنضيفها تباعاً — عد إلينا قريباً.",
          retry: true);
    }

    final list = _visible;
    if (list.isEmpty) {
      return _empty(Icons.search_off_rounded,
          "لا نتائج لهذا البحث أو الفلتر.\nجرّب «الكل».");
    }

    return RefreshIndicator(
      onRefresh: () => _load(force: true),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        itemCount: list.length + 1,
        itemBuilder: (_, i) {
          if (i == list.length) return _footer();
          return FadeInSlide(
            delay: 0.04 * i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _card(list[i]),
            ),
          );
        },
      ),
    );
  }

  Widget _footer() {
    if (!_fromCache) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: Text("📴 معروضة من نسخة محفوظة — اسحب للتحديث",
            style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
      ),
    );
  }

  Widget _empty(IconData icon, String text, {bool retry = false}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(30, 70, 30, 30),
      children: [
        Icon(icon, size: 56, color: AppColors.textSecondary.withValues(alpha: 0.5)),
        const SizedBox(height: 16),
        Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13.5,
                height: 1.8,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
        if (retry) ...[
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 170,
              child: GradientButton(
                  label: "أعد المحاولة", height: 46, onTap: () => _load(force: true)),
            ),
          ),
        ],
      ],
    );
  }

  // ══════════════ كرت المنحة ══════════════

  Widget _card(Scholarship s) {
    final days = s.daysLeft;
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ScholarshipDetailScreen(scholarship: s))),
      borderRadius: BorderRadius.circular(24),
      child: SoftCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _logo(s),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(s.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary)),
                      ),
                      Icon(Icons.chevron_left_rounded,
                          color: AppColors.textSecondary, size: 22),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    s.shortDesc.isEmpty ? s.country : s.shortDesc,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11.5,
                        height: 1.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _chip(s.statusLabel, s.statusColor),
                      if (s.isFullyFunded)
                        _chip("💰 ممولة بالكامل", AppColors.primary)
                      else
                        _chip("💰 تمويل جزئي", AppColors.textSecondary),
                      // ⏳ أهم رقم في الكرت: يحوّل «مفتوحة» إلى فعلٍ الآن.
                      if (days != null && days <= 45)
                        _chip(days == 0 ? "⏳ آخر يوم!" : "⏳ باقٍ $days يوماً",
                            days <= 7 ? Colors.redAccent : Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// شعار الجامعة إن رفعه الأدمن، وإلا علم الدولة على تدرّج المنحة.
  Widget _logo(Scholarship s) {
    final box = BoxDecoration(
      gradient: LinearGradient(colors: s.colors),
      borderRadius: BorderRadius.circular(18),
    );
    if (s.logoUrl.isEmpty) {
      return Container(
        width: 58,
        height: 58,
        decoration: box,
        child: Center(child: Text(s.badge, style: const TextStyle(fontSize: 26))),
      );
    }
    return Container(
      width: 58,
      height: 58,
      decoration: box,
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: s.logoUrl,
        fit: BoxFit.cover,
        // ⚠️ رابط صورة معطوب لا يجوز أن يترك مربعاً فارغاً — نعود للعلم.
        errorWidget: (_, _, _) =>
            Center(child: Text(s.badge, style: const TextStyle(fontSize: 26))),
        placeholder: (_, _) =>
            Center(child: Text(s.badge, style: const TextStyle(fontSize: 26))),
      ),
    );
  }

  Widget _chip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Text(label,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
      );
  /// 🎏 نقر البانر داخل قسم المنح — الوجهة الوحيدة ذات المعنى هنا منحةٌ
  /// بعينها؛ ما عداها يعني الخروج من القسم فنتركه للشاشة الرئيسية.
  Future<void> _onBannerAction(String action, String value) async {
    if (action != "scholarship" || value.isEmpty) return;
    final match = _all.where((s) => s.id == value).toList();
    if (match.isEmpty || !mounted) return;
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => ScholarshipDetailScreen(scholarship: match.first)));
  }

}
