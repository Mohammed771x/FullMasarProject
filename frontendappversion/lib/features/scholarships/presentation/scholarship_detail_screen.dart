import 'dart:convert';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/phosphor.dart';
import '../data/models/scholarship.dart';
import '../data/scholarship_repository.dart';
import 'scholarship_chat_screen.dart';
import 'widgets/scholarship_ui.dart';

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
//
// 🎨 **إعادة التصميم (2026-09-21):** من `design/06-scholarships/02·03·04`.
//    رأسٌ ممتدٌّ 165 بزاويتين سفليتين، زرّان 40/r14، عنوانٌ 16/w900، ثم
//    شريطُ وسومٍ 26، ثم **شرائحُ التبويب** 36/r18 بدل `TabBar`، ثم أقسامٌ
//    على سطحٍ باهت `#D9EFFF` بحبر `#15294B`، وشريطٌ سفليٌّ بزرّين 46/r16.
//
// ⚠️ **التبويبُ صار مؤشّراً لا `TabController`** — تغييرُ عرضٍ محض: نفسُ
//    [_tabs] ونفسُ [_tabBody] ونفسُ الشروط التي تُخفي التبويبَ الفارغ.
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

  int _tab = 0;

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
    final index = _tab.clamp(0, tabs.length - 1);
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Column(
        children: [
          _header(context, s),
          const SizedBox(height: 14),
          _summaryStrip(s),
          const SizedBox(height: 16),
          _tabBar(tabs, index),
          const SizedBox(height: 18),
          Expanded(child: _tabBody(context, s, tabs[index].kind)),
          _bottomBar(context, s),
        ],
      ),
    );
  }

  // ══════════════ الرأس ══════════════

  /// 📐 مقيسٌ من `02-المنح2`: الرأسُ يمتدّ من حافةٍ إلى حافة (بلا هامش)
  ///    بارتفاع 165 وزاويتين سفليتين 24، وفيه زرّان 40/r14 في أعلاه
  ///    (الرجوعُ يميناً والرابطُ الخارجيُّ يساراً)، ثم العنوانُ 16/w900
  ///    والوصفُ 12/w600 محاذيين لليمين عند هامش 24.
  Widget _header(BuildContext context, Scholarship s) {
    final top = MediaQuery.of(context).padding.top;

    final content = Padding(
      padding: EdgeInsets.fromLTRB(
          SchMetrics.margin, top + 10, SchMetrics.margin, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SchSquareButton(
                icon: PI.arrowRight,
                onTap: () => Navigator.maybePop(context),
                fill: Colors.white.withValues(alpha: 0.22),
                ink: Colors.white,
                border: false,
                tooltip: "رجوع",
              ),
              const Spacer(),
              if (s.website.isNotEmpty)
                SchSquareButton(
                  icon: PI.arrowSquareOut,
                  onTap: () => _openSite(context, s),
                  fill: Colors.white.withValues(alpha: 0.22),
                  ink: Colors.white,
                  border: false,
                  tooltip: "الموقع الرسمي",
                ),
            ],
          ),
          const Spacer(),
          // 🚫 لا شعار هنا: الغلاف **هو** هوية المنحة داخل شاشتها، وشعارٌ
          //    فوقه يزاحمه ويقطع الصورة من نصفها. الشعار مكانه كرت القائمة
          //    — قبل الدخول — حيث لا غلاف يعرّف بالمنحة.
          Text(s.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
          if (s.shortDesc.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(s.shortDesc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.92))),
          ],
        ],
      ),
    );

    final decoration = BoxDecoration(
      gradient: LinearGradient(
          colors: s.colors, begin: Alignment.topRight, end: Alignment.bottomLeft),
      borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
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

    return Container(
      height: top + SchMetrics.heroHeight,
      decoration: decoration,
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 🏳️ ختمُ العلم الخافت في يمين الرأس — كما في التصدير.
          if (background == null)
            Positioned(
              right: -10,
              top: top + 6,
              child: Opacity(
                opacity: 0.18,
                child: Text(s.badge, style: const TextStyle(fontSize: 128)),
              ),
            ),
          if (background != null) ...[
            Positioned.fill(child: background),
            // 🖼️ طبقة داكنة تضمن قراءة الاسم مهما كانت الصورة فاتحة.
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
          ],
          content,
        ],
      ),
    );
  }

  /// شريط أرقام سريع تحت الرأس — ما يريد الطالب معرفته في ثانيتين.
  ///
  /// 📐 **ثلاثُ بطاقاتٍ تملأ السطر** (أمرُ المالك 2026-09-21: «خليها هذه
  ///    المربعات تكون على ملء المكان، تكون واحد اثنين ثلاثة»): الحالة ·
  ///    التمويل · المهلة، متساويةَ العرض بفجوة 8 من الهامش إلى الهامش —
  ///    كما في `02-المنح2` حيث تمتدّ من x=54 إلى x=726.
  ///
  /// ⚠️ والمهلةُ **لا تغيب أبداً** وإلا صارتا اثنتين: منحةٌ مغلقةٌ تقول
  ///    «انتهى التقديم» في المكان نفسه.
  Widget _summaryStrip(Scholarship s) {
    final days = s.daysLeft;
    final deadline = switch (s.status) {
      SchStatus.closed => "انتهى التقديم",
      SchStatus.soon => "لم يُفتح بعد",
      SchStatus.open => days == null
          ? "بلا موعد إغلاق"
          : days == 0
              ? "آخر يوم للتقديم"
              : "باقٍ $days يوماً",
    };
    final tags = <Widget>[
      SchTag(
          label: s.statusText,
          icon: s.status == SchStatus.open ? PI.checkCircle : PI.clock,
          fill: AppColors.schBlueFill,
          ink: AppColors.schBlueInk,
          center: true),
      SchTag(
          label: s.isFullyFunded ? "ممولة بالكامل" : "تمويل جزئي",
          icon: PI.shieldCheck,
          fill: AppColors.schGreenFill,
          ink: AppColors.schGreenInk,
          center: true),
      SchTag(
          label: deadline,
          icon: PI.clock,
          fill: AppColors.schRedFill,
          ink: AppColors.schRedInk,
          center: true),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: SchMetrics.margin),
      child: Row(
        children: [
          for (var i = 0; i < tags.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: tags[i]),
          ],
        ],
      ),
    );
  }

  /// 🪄 **التبويبات شرائحُ لا شريط.** في التصدير خمسُ شرائح 36/r18، المختارةُ
  ///    مملوءةٌ بلون الهوية والبقيّةُ بيضاءُ بحدٍّ رفيع — وهي تمرّ أفقياً
  ///    فلا تُقصّ عند خمسة عناوين كما كان يفعل `TabBar`.
  Widget _tabBar(List<_Tab> tabs, int index) {
    return SizedBox(
      height: SchMetrics.filterHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SchMetrics.margin),
        itemCount: tabs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 4),
        itemBuilder: (_, i) => SchFilterChip(
          label: tabs[i].label,
          selected: i == index,
          onTap: () => setState(() => _tab = i),
        ),
      ),
    );
  }

  // ══════════════ التبويبات ══════════════

  Widget _tabBody(BuildContext context, Scholarship s, _TabKind kind) {
    switch (kind) {
      case _TabKind.about:
        return _aboutTab(s);
      case _TabKind.requirements:
        return _listTab(s.requirements, PI.checkCircle);
      case _TabKind.documents:
        return _listTab(s.documents, PI.fileText);
      case _TabKind.dates:
        return _datesTab(s);
      case _TabKind.apply:
        return _listTab(s.howToApply, PI.listNumbers,
            numbered: true, footer: s.website.isEmpty ? null : _siteCard(context, s));
    }
  }

  static const _pagePad = EdgeInsets.fromLTRB(
      SchMetrics.margin, 0, SchMetrics.margin, 20);

  Widget _aboutTab(Scholarship s) {
    // 📊 المعدّلُ المطلوب: من حقل اللوحة، وإلا فمن الشروط — وهو نفسُ
    //    ما يقرؤه كرتُ القائمة حرفاً، فلا يختلف الرقمان أمام الطالب.
    final gpa = gpaTextOf(s.minGpa, s.requirements);
    final hasQuick =
        s.degreeLevels.isNotEmpty || s.country.isNotEmpty || gpa != null;
    return ListView(
      padding: _pagePad,
      children: [
        if (s.about.isNotEmpty) ...[
          const SchSectionTitle("نبذة عن المنحة"),
          SchTintCard(
            child: Text(s.about,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.9,
                    color: AppColors.schTintInk,
                    fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 22),
        ],
        // 🆕 **المراحلُ والدولة** — بياناتٌ تملكها البطاقة ولم يرسم لها
        //    المصمّم مكاناً، وخرجتا من الشريط العلويّ حين صار ثلاثَ
        //    بطاقاتٍ بالضبط. فوُضعتا هنا بلغة الصفوف نفسِها.
        if (hasQuick) ...[
          if (s.degreeLevels.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _tintRow(
                  PI.graduationCap, "المراحل: ${s.degreeLevels.join(" · ")}"),
            ),
          if (s.country.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: gpa == null ? 0 : 8),
              child: _tintRow(PI.globe, "الدولة: ${s.country}"),
            ),
          if (gpa != null) _tintRow(PI.target, "المعدل المطلوب: $gpa"),
          const SizedBox(height: 22),
        ],
        if (s.benefits.isNotEmpty) ...[
          const SchSectionTitle("ماذا تشمل؟"),
          ...s.benefits.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _tintRow(PI.sparkle, stripBullet(b)),
              )),
          const SizedBox(height: 14),
        ],
        if (s.fields.isNotEmpty) ...[
          // 🏷️ **«التخصصات المتاحة» لا «المجالات»** (أمرُ المالك
          //    2026-09-21) — وهي التسميةُ التي تُستعمل في لوحة التحكم.
          const SchSectionTitle("التخصصات المتاحة"),
          SchTintCard(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: s.fields.map((f) => _fieldPill(stripBullet(f))).toList(),
            ),
          ),
        ],
        if (s.about.isEmpty &&
            s.benefits.isEmpty &&
            s.fields.isEmpty &&
            !hasQuick)
          _placeholder("لم تُضف تفاصيل هذه المنحة بعد."),
      ],
    );
  }

  /// صفٌّ باهتٌ بأيقونةٍ ونصّ — لبنةُ «ماذا تشمل؟» والشروط والوثائق.
  Widget _tintRow(PIcon icon, String text, {String? number}) {
    return Container(
      constraints: const BoxConstraints(minHeight: 50),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.schTint,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — وهناك الأيقونة في التصدير.
          if (number != null)
            SizedBox(
              width: 22,
              child: Text(number,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.schBlueInk)),
            )
          else
            Icon(icon.regular, size: 20, color: AppColors.schBlueInk),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                    color: AppColors.schTintInk)),
          ),
        ],
      ),
    );
  }

  Widget _fieldPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.schTintInk),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PI.stack.regular, size: 16, color: AppColors.schBlueInk),
            const SizedBox(width: 8),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.schTintInk)),
            ),
          ],
        ),
      );

  Widget _listTab(List<String> items, PIcon icon,
      {bool numbered = false, Widget? footer}) {
    return ListView(
      padding: _pagePad,
      children: [
        ...items.asMap().entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _tintRow(icon, stripBullet(e.value),
                  number: numbered ? "${e.key + 1}" : null),
            )),
        if (footer != null) ...[const SizedBox(height: 10), footer],
      ],
    );
  }

  Widget _datesTab(Scholarship s) {
    final days = s.daysLeft;
    return ListView(
      padding: _pagePad,
      children: [
        if (s.openDate == null && s.closeDate == null)
          _placeholder("لم تُعلن مواعيد هذه المنحة بعد — تابعنا، ننشرها فور صدورها.")
        else ...[
          if (s.openDate != null)
            _dateCard("فتح التقديم", s.openDate!, AppColors.schGreenInk),
          if (s.openDate != null && s.closeDate != null) const SizedBox(height: 10),
          if (s.closeDate != null)
            _dateCard("إغلاق التقديم", s.closeDate!, AppColors.schRedInk),
          const SizedBox(height: 10),
          _tintRow(
            days != null && days <= 7 ? PI.warningCircle : PI.info,
            days == null
                ? "راقب المواعيد جيداً وجهّز ملفك مبكراً — التقديم المبكر يزيد فرصك."
                : days <= 7
                    ? "باقٍ $days أيام فقط! جهّز وثائقك اليوم لا غداً."
                    : "باقٍ $days يوماً على الإغلاق — ابدأ بتجهيز الوثائق من الآن.",
          ),
        ],
      ],
    );
  }

  Widget _dateCard(String label, DateTime d, Color color) {
    return SchCard(
      child: Row(children: [
        Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14)),
            child: Icon(PI.calendar.regular, size: 22, color: color)),
        const SizedBox(width: 14),
        Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: AppColors.schMutedInk,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text("${d.day} / ${d.month} / ${d.year}",
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  color: AppColors.inputBarText)),
        ])),
      ]),
    );
  }

  Widget _siteCard(BuildContext context, Scholarship s) => SchPrimaryButton(
        label: "افتح الموقع الرسمي",
        icon: PI.globe,
        onTap: () => _openSite(context, s),
      );

  Widget _placeholder(String text) => SchEmptyState(icon: PI.clock, text: text);

  // ══════════════ الشريط السفلي ══════════════

  Widget _bottomBar(BuildContext context, Scholarship s) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            SchMetrics.margin, 10, SchMetrics.margin, 12),
        child: Row(
          children: [
            // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — وهناك الزرُّ المملوء في التصدير.
            Expanded(
              flex: 3,
              child: SchPrimaryButton(
                // 🔒 **النصُّ ثابتٌ كما في التصدير** (أمرُ المالك
                //    2026-09-21): «اسأل مساعد المنحة» — لا «المساعد (٤
                //    محادثة)». وعددُ المحادثات لم يضع: شارتُه على زرّ
                //    السجلّ داخل شاشة المساعد نفسِها.
                label: "اسأل مساعد المنحة",
                icon: PI.chatDots,
                gradient: AppColors.schCtaGradient,
                onTap: () async {
                  await Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ScholarshipChatScreen(scholarship: s)));
                  // العودة من الشات قد تغيّر عدد المحادثات على الزر.
                  if (mounted) setState(() {});
                },
              ),
            ),
            if (s.website.isNotEmpty) ...[
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: SchGhostButton(
                  label: "الموقع الرسمي",
                  icon: PI.globe,
                  outlined: true,
                  onTap: () => _openSite(context, s),
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
        backgroundColor: AppColors.quizWrong,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }
}

enum _TabKind { about, requirements, documents, dates, apply }

class _Tab {
  final String label;
  final _TabKind kind;
  const _Tab(this.label, this.kind);
}
