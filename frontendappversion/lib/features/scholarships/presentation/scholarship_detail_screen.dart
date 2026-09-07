import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../future_masar/presentation/widgets/demo_widgets.dart';
import '../data/models/scholarship.dart';
import '../data/scholarship_chat_storage.dart';
import '../data/scholarship_repository.dart';
import '../../../core/session/user_session.dart';
import 'scholarship_chat_screen.dart';

// ==========================================
// 🏆 تفاصيل المنحة
// ==========================================
// ما ضُبط عن نسخة الديمو (وسببه):
//   • **الغلاف الحقيقي** إن رفعه الأدمن، وإلا رأس متدرّج — لا فراغ.
//   • **تبويبات ديناميكية:** التبويب الفارغ **لا يُعرض**. الديمو كان يعرض
//     أربعة تبويبات دائماً فيقف الطالب أمام «المتطلبات» خالية.
//   • **شريط عدّاد** أعلى: باقٍ كذا يوماً · نوع التمويل · المراحل.
//   • **زر الموقع الرسمي** — التقديم يتم هناك، وإخفاؤه يقطع الرحلة.
//   • **زر المساعد يعرض عدد محادثاتك السابقة** فيعرف الطالب أن له سجلاً.
class ScholarshipDetailScreen extends StatefulWidget {
  final Scholarship scholarship;
  const ScholarshipDetailScreen({super.key, required this.scholarship});

  @override
  State<ScholarshipDetailScreen> createState() => _ScholarshipDetailScreenState();
}

class _ScholarshipDetailScreenState extends State<ScholarshipDetailScreen> {
  Scholarship get scholarship => widget.scholarship;

  /// 🖼️ بايتات الغلاف — تُجلب **عند فتح هذه الشاشة وحدها**، لا مع القائمة.
  Uint8List? _cover;

  @override
  void initState() {
    super.initState();
    // 🖼️ الغلاف الحديث رابطٌ يتكفّل به `CachedNetworkImage`. وهذا المسار
    //    يبقى **سقوطاً آمناً** لأغلفة رُفعت قبل تفعيل Storage (تعيش في
    //    Firestore بلا رابط) — فلا تفقد منحةٌ قديمة صورتها.
    if (scholarship.hasCover && scholarship.coverUrl.isEmpty) _loadCover();
  }

  Future<void> _loadCover() async {
    final b64 = await ScholarshipRepository().cover(scholarship.id);
    if (!mounted || b64.isEmpty) return;
    try {
      final clean = b64.contains(',') ? b64.split(',').last : b64;
      setState(() => _cover = base64Decode(clean));
    } catch (_) {
      // صورة مشوّهة ⇒ يبقى الرأس المتدرّج، لا شاشة عطل.
    }
  }

  /// التبويبات المبنية على ما هو موجود فعلاً — لا تبويب فارغ.
  List<_Tab> _tabs() {
    final s = scholarship;
    return [
      const _Tab("نبذة", _TabKind.about),
      if (s.requirements.isNotEmpty) const _Tab("الشروط", _TabKind.requirements),
      if (s.documents.isNotEmpty) const _Tab("الوثائق", _TabKind.documents),
      const _Tab("المواعيد", _TabKind.dates),
      if (s.howToApply.isNotEmpty) const _Tab("التقديم", _TabKind.apply),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final s = scholarship;
    final tabs = _tabs();
    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: Column(
          children: [
            _header(context, s),
            _summaryStrip(s),
            _tabBar(tabs),
            Expanded(
              child: TabBarView(
                children: tabs.map((t) => _tabBody(context, s, t.kind)).toList(),
              ),
            ),
            _bottomBar(context, s),
          ],
        ),
      ),
    );
  }

  // ══════════════ الرأس ══════════════

  Widget _header(BuildContext context, Scholarship s) {
    final top = MediaQuery.of(context).padding.top;
    final content = Column(
      children: [
        Row(
          children: [
            _iconBtn(context, Icons.arrow_back_rounded, () => Navigator.maybePop(context)),
            const Spacer(),
            if (s.website.isNotEmpty)
              _iconBtn(context, Icons.open_in_new_rounded, () => _openSite(context, s)),
          ],
        ),
        // 🚫 لا شعار هنا: الغلاف **هو** هوية المنحة داخل شاشتها، وشعارٌ
        //    فوقه يزاحمه ويقطع الصورة من نصفها. الشعار مكانه كرت القائمة
        //    — قبل الدخول — حيث لا غلاف يعرّف بالمنحة.
        const SizedBox(height: 18),
        Text(s.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 21, fontWeight: FontWeight.w900, color: Colors.white)),
        if (s.shortDesc.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(s.shortDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.9))),
        ],
      ],
    );

    final decoration = BoxDecoration(
      gradient: LinearGradient(
          colors: s.colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
      borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
      boxShadow: [
        BoxShadow(
            color: s.colors.last.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10))
      ],
    );

    // الأولوية للغلاف المرفوع من اللوحة، ثم رابط خارجي، ثم الرأس المتدرّج.
    final Widget? background = _cover != null
        ? Image.memory(_cover!, fit: BoxFit.cover)
        : (s.coverUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: s.coverUrl,
                fit: BoxFit.cover,
                errorWidget: (_, _, _) => const SizedBox.shrink())
            : null);

    if (background == null) {
      return Container(
        padding: EdgeInsets.only(top: top + 12, bottom: 18, left: 18, right: 18),
        decoration: decoration,
        child: content,
      );
    }

    // 🖼️ غلاف حقيقي + طبقة داكنة تضمن قراءة الاسم مهما كانت الصورة فاتحة.
    return Container(
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: background),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.25),
                    Colors.black.withValues(alpha: 0.62),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: top + 12, bottom: 18, left: 18, right: 18),
            child: content,
          ),
        ],
      ),
    );
  }

  /// شريط أرقام سريع تحت الرأس — ما يريد الطالب معرفته في ثانيتين.
  Widget _summaryStrip(Scholarship s) {
    final days = s.daysLeft;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            InfoPill(s.statusIcon, s.statusText, color: s.statusColor),
            const SizedBox(width: 8),
            InfoPill(
                Icons.workspace_premium_rounded,
                s.isFullyFunded ? "ممولة بالكامل" : "تمويل جزئي",
                color: s.colors.first),
            if (days != null) ...[
              const SizedBox(width: 8),
              InfoPill(Icons.timer_outlined,
                  days == 0 ? "آخر يوم للتقديم" : "باقٍ $days يوماً",
                  color: days <= 7 ? Colors.redAccent : Colors.orange),
            ],
            if (s.degreeLevels.isNotEmpty) ...[
              const SizedBox(width: 8),
              InfoPill(Icons.school_rounded, s.degreeLevels.join(" · "),
                  color: AppColors.secondary),
            ],
            if (s.country.isNotEmpty) ...[
              const SizedBox(width: 8),
              InfoPill(Icons.public_rounded, s.country),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tabBar(List<_Tab> tabs) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
      child: TabBar(
        // ⚠️ **غير قابل للتمرير عمداً.** الشريط القابل للتمرير كان يقصّ التبويب
        //    الأول («نبذة») عند خمسة تبويبات مهما كانت المحاذاة. والعناوين هنا
        //    كلها قصيرة، فالتوزيع المتساوي يسعها ولا يقصّ شيئاً.
        isScrollable: false,
        labelPadding: EdgeInsets.zero,
        dividerColor: Colors.transparent,
        // ⚠️ **إلزامي مع مؤشّر الحبّة:** Material 3 يجعل `indicatorSize`
        //    افتراضياً `label`، فتُرسم الحبّة بعرض الكلمة لا بعرض التبويب —
        //    فتظهر أضيق من النصّ ويبدو كأنه مقصوص. `tab` تملأ التبويب.
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.symmetric(horizontal: 2),
        indicator: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(12),
            boxShadow: AppColors.bubbleShadow),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        tabs: tabs.map((t) => Tab(height: 38, text: t.label)).toList(),
      ),
    );
  }

  // ══════════════ التبويبات ══════════════

  Widget _tabBody(BuildContext context, Scholarship s, _TabKind kind) {
    switch (kind) {
      case _TabKind.about:
        return _aboutTab(s);
      case _TabKind.requirements:
        return _listTab(s.requirements, Icons.check_circle_rounded, Colors.green);
      case _TabKind.documents:
        return _listTab(s.documents, Icons.description_rounded, AppColors.secondary);
      case _TabKind.dates:
        return _datesTab(s);
      case _TabKind.apply:
        return _listTab(s.howToApply, Icons.arrow_circle_left_rounded,
            AppColors.primary,
            numbered: true, footer: s.website.isEmpty ? null : _siteCard(context, s));
    }
  }

  Widget _aboutTab(Scholarship s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      children: [
        if (s.about.isNotEmpty) ...[
          const SectionHeader("نبذة عن المنحة"),
          SoftCard(
            child: Text(s.about,
                style: TextStyle(
                    fontSize: 14,
                    height: 1.9,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 16),
        ],
        if (s.benefits.isNotEmpty) ...[
          const SectionHeader("ماذا تشمل؟"),
          ...s.benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SoftCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const Text("✨", style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(b,
                            style: TextStyle(
                                fontSize: 13.5,
                                height: 1.5,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary))),
                  ]),
                ),
              )),
          const SizedBox(height: 8),
        ],
        if (s.fields.isNotEmpty) ...[
          const SectionHeader("المجالات المتاحة"),
          SoftCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: s.fields
                  .map((f) => InfoPill(Icons.category_rounded, f,
                      color: AppColors.secondary))
                  .toList(),
            ),
          ),
        ],
        if (s.about.isEmpty && s.benefits.isEmpty && s.fields.isEmpty)
          _placeholder("لم تُضف تفاصيل هذه المنحة بعد."),
      ],
    );
  }

  Widget _listTab(List<String> items, IconData icon, Color color,
      {bool numbered = false, Widget? footer}) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      children: [
        ...items.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SoftCard(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    numbered
                        ? Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                shape: BoxShape.circle),
                            child: Center(
                                child: Text("${e.key + 1}",
                                    style: TextStyle(
                                        color: color, fontWeight: FontWeight.w900))))
                        : Icon(icon, color: color, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(e.value,
                            style: TextStyle(
                                fontSize: 13.5,
                                height: 1.6,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary))),
                  ],
                ),
              ),
            )),
        if (footer != null) footer,
      ],
    );
  }

  Widget _datesTab(Scholarship s) {
    final days = s.daysLeft;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 20),
      children: [
        if (s.openDate == null && s.closeDate == null)
          _placeholder("لم تُعلن مواعيد هذه المنحة بعد — تابعنا، ننشرها فور صدورها.")
        else ...[
          if (s.openDate != null)
            _dateCard("📅 فتح التقديم", s.openDate!, Colors.green),
          if (s.openDate != null && s.closeDate != null) const SizedBox(height: 12),
          if (s.closeDate != null)
            _dateCard("⏳ إغلاق التقديم", s.closeDate!, Colors.redAccent),
          const SizedBox(height: 12),
          SoftCard(
            child: Row(children: [
              Icon(days != null && days <= 7
                      ? Icons.warning_amber_rounded
                      : Icons.info_rounded,
                  color: days != null && days <= 7 ? Colors.redAccent : AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  days == null
                      ? "راقب المواعيد جيداً وجهّز ملفك مبكراً — التقديم المبكر يزيد فرصك."
                      : days <= 7
                          ? "⚠️ باقٍ $days أيام فقط! جهّز وثائقك اليوم لا غداً."
                          : "باقٍ $days يوماً على الإغلاق — ابدأ بتجهيز الوثائق من الآن.",
                  style: TextStyle(
                      fontSize: 12.5,
                      height: 1.6,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ]),
          ),
        ],
      ],
    );
  }

  Widget _dateCard(String label, DateTime d, Color color) {
    return SoftCard(
      child: Row(children: [
        Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(Icons.event_rounded, color: color)),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text("${d.day} / ${d.month} / ${d.year}",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
        ])),
      ]),
    );
  }

  Widget _siteCard(BuildContext context, Scholarship s) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: GradientButton(
        label: "🌐 افتح الموقع الرسمي",
        height: 50,
        onTap: () => _openSite(context, s),
      ),
    );
  }

  Widget _placeholder(String text) => Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(children: [
          Icon(Icons.hourglass_empty_rounded,
              size: 46, color: AppColors.textSecondary.withValues(alpha: 0.4)),
          const SizedBox(height: 14),
          Text(text,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.8,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ]),
      );

  // ══════════════ الشريط السفلي ══════════════

  Widget _bottomBar(BuildContext context, Scholarship s) {
    final past = SchChatStorage.countFor(UserSession.I.uid, s.id);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: GradientButton(
                label: past == 0
                    ? "💬 اسأل مساعد المنحة"
                    : "💬 المساعد ($past محادثة)",
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ScholarshipChatScreen(scholarship: s)));
                  // العودة من الشات قد تغيّر عدد المحادثات على الزر.
                  if (context.mounted) (context as Element).markNeedsBuild();
                },
              ),
            ),
            if (s.website.isNotEmpty) ...[
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: () => _openSite(context, s),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            width: 1.4)),
                    child: Center(
                        child: Text("🌐 التقديم",
                            style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13))),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openSite(BuildContext context, Scholarship s) async {
    final raw = s.website.trim();
    final uri = Uri.tryParse(raw.startsWith("http") ? raw : "https://$raw");
    final ok = uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text("تعذّر فتح الرابط",
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  Widget _iconBtn(BuildContext context, IconData icon, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: Colors.white, size: 22)),
    );
  }
}

enum _TabKind { about, requirements, documents, dates, apply }

class _Tab {
  final String label;
  final _TabKind kind;
  const _Tab(this.label, this.kind);
}
