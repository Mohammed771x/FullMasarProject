import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/phosphor.dart';
import '../../banners/data/banner_model.dart';
import '../../banners/presentation/banner_carousel.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/screen_tip.dart';
import '../data/models/scholarship.dart';
import '../data/scholarship_favorites.dart';
import '../data/scholarship_repository.dart';
import 'scholarship_detail_screen.dart';
import 'widgets/scholarship_ui.dart';

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
//
// 🎨 **إعادة التصميم (2026-09-21):** الشكلُ كلُّه من `design/06-scholarships/
//    01-المنح.png` — الرأس 28/w900 بأيقونة `GraduationCap` ثنائية، بطاقةُ
//    إلحاحٍ حمراء 92، حقلُ بحثٍ 50/r16، شرائحُ فلترٍ 36/r18، وكرتٌ r24
//    بوسومٍ 24 وخطٍّ فاصلٍ وزرِّ تفاصيل. **ولا لوجيك مسّ**: نفسُ المستودع
//    ونفسُ الفلاتر ونفسُ المفضّلة ونفسُ النداءات.
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
    // ⭐ المفضّلة تُحمَّل قبل أول رسم كي لا يومض الفلتر فارغاً ثم يمتلئ.
    ScholarshipFavorites.I.load().then((_) {
      if (mounted) setState(() {});
    });
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
      // 🧹 منحةٌ حُذفت من اللوحة تخرج من المفضّلة — وإلا ناقض العدّادُ القائمة.
      unawaited(ScholarshipFavorites.I.pruneAgainst(result.items));
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
    final favorites = ScholarshipFavorites.I.ids;
    final list = _all
        .where((s) => s.matches(_query) && _filter.test(s, favoriteIds: favorites))
        .toList();
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
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: () => _load(force: true),
              child: _scroller(),
            ),
            const ScreenTip(
              screenId: "scholarships",
              text: "تصفّح المنح 🎓 افتح أي منحة لترى شروطها ومواعيدها — "
                  "ثم اسأل مساعدها عن أي تفصيل.",
            ),
          ],
        ),
      ),
    );
  }

  /// 📜 **الصفحةُ كلُّها تمريرةٌ واحدة** — كما في التصدير (3906 بكسل من
  ///    الرأس إلى آخر كرت). والرأسُ كان شريطاً ثابتاً فوق قائمةٍ منفصلة،
  ///    فصار عنصرَ القائمة الأوّل: يمرّ مع المحتوى ويبقى السحبُ للتحديث
  ///    عاملاً على الشاشة كلِّها لا على جزئها الأسفل.
  Widget _scroller() {
    final list = _visible;
    final body = _bodySlivers(list);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
          SchMetrics.margin, 22, SchMetrics.margin, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: body.length + 1,
      itemBuilder: (_, i) => i == 0 ? _headerBlock() : body[i - 1],
    );
  }

  List<Widget> _bodySlivers(List<Scholarship> list) {
    if (_loading && _all.isEmpty) {
      return const [
        SizedBox(height: 80),
        Center(child: CircularProgressIndicator()),
      ];
    }
    if (_error != null && _all.isEmpty) {
      return [
        SchEmptyState(
            icon: PI.wifiSlash,
            text: _error!,
            onRetry: () => _load(force: true)),
      ];
    }
    if (_all.isEmpty) {
      return [
        SchEmptyState(
          icon: PI.graduationCap,
          text: _message ?? "لا منح متاحة حالياً 🎓\nنضيفها تباعاً — عد إلينا قريباً.",
          onRetry: () => _load(force: true),
        ),
      ];
    }
    if (list.isEmpty) {
      // ⚠️ رسالةٌ خاصة للمفضّلة الفارغة: «لا نتائج للفلتر» تُوهم الطالب أن
      //    شيئاً معطوب، والحقيقة أنه لم يتابع منحةً بعد — وهو فرقٌ يغيّر
      //    ما يفعله تالياً.
      if (_filter == SchFilter.favorites && ScholarshipFavorites.I.isEmpty) {
        return const [
          SchEmptyState(
            icon: PI.bookmarkSimple,
            text: "لم تتابع أي منحة بعد ⭐\nاضغط العلامة على أي منحة لتتابعها،\n"
                "وننبّهك قبل إغلاقها.",
          ),
        ];
      }
      return const [
        SchEmptyState(
          icon: PI.magnifyingGlass,
          text: "لا نتائج لهذا البحث أو الفلتر.\nجرّب «الكل».",
        ),
      ];
    }

    return [
      for (var i = 0; i < list.length; i++)
        FadeInSlide(
          delay: 0.04 * i,
          child: Padding(
            padding: const EdgeInsets.only(bottom: SchMetrics.gap),
            child: _card(list[i]),
          ),
        ),
      _footer(),
    ];
  }

  // ══════════════ الرأس ══════════════

  Widget _headerBlock() {
    final soon = ScholarshipFavorites.I.closingSoon(_all);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SchHeader(title: "المنح")),
            // 🔄 التحديثُ اليدويُّ زرٌّ قائمٌ في التطبيق — لا يُحذف لأن
            //    السحبَ لا يخطر ببال كل طالب.
            SchSquareButton(
              icon: PI.arrowCounterClockwise,
              tooltip: "تحديث",
              onTap: () => _load(force: true),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _all.isEmpty
              ? "فرصتك للدراسة حول العالم"
              : "$_openCount منحة مفتوحة الآن من ${_all.length}",
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.schMutedInk,
          ),
        ),
        if (soon.isNotEmpty) ...[
          const SizedBox(height: 18),
          _closingSoonAlert(soon),
        ],
        // 🎏 بانر قسم المنح — يُدار من لوحة التحكم، وبمقاس بطاقة الإلحاح
        //    نفسها كي لا يتنافر الشريطان.
        const SizedBox(height: 18),
        BannerCarousel(
          section: BannerSection.scholarships,
          onAction: _onBannerAction,
          height: SchMetrics.bannerHeight,
        ),
        const SizedBox(height: 18),
        SchSearchField(
          controller: _search,
          hint: "ابحث عن منحة، دولة، أو تخصص...",
          showClear: _query.isNotEmpty,
          onChanged: (v) => setState(() => _query = v),
          onClear: () {
            _search.clear();
            setState(() => _query = "");
          },
        ),
        const SizedBox(height: 16),
        _filterChips(),
        const SizedBox(height: 18),
      ],
    );
  }

  /// شرائحُ الفلتر — تخرج عن هامش الصفحة عمداً كي تلامس حافّتها عند التمرير.
  Widget _filterChips() {
    return SizedBox(
      height: SchMetrics.filterHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        itemCount: SchFilter.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: SchMetrics.tagGap),
        itemBuilder: (_, i) {
          final f = SchFilter.values[i];
          return SchFilterChip(
            label: f.label,
            selected: f == _filter,
            onTap: () => setState(() => _filter = f),
          );
        },
      ),
    );
  }

  /// 🔔 **تنبيهُ الإغلاق للمنح المتابَعة** — الميزة التي تجعل العلامة تساوي شيئاً.
  ///
  /// ⚠️ الطالب لا يفوّت منحةً لأنه لم يهتمّ بها، بل لأنه **نسي تاريخها**.
  /// ⚠️ ويظهر فقط حين يوجد ما يُنبَّه عليه: شريطٌ دائم يصير خلفيةً لا يراها أحد.
  Widget _closingSoonAlert(List<Scholarship> soon) {
    final first = soon.first;
    final days = first.daysLeft ?? 0;
    final more = soon.length - 1;
    final when = days == 0
        ? "تُغلق اليوم"
        : days == 1
            ? "تُغلق غداً"
            : "تُغلق بعد $days يوماً";

    return SchUrgentBanner(
      title: first.name,
      badge: "عاجل",
      subtitle: more > 0
          ? "$when — جهّز أوراقك الآن، و$more منحة أخرى تقترب."
          : "$when — جهّز أوراقك الآن وراجع الشروط.",
      onTap: () => setState(() => _filter = SchFilter.favorites),
    );
  }

  Widget _footer() {
    if (!_fromCache) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Center(
        child: Text("📴 معروضة من نسخة محفوظة — اسحب للتحديث",
            style: TextStyle(fontSize: 11.5, color: AppColors.schMutedInk)),
      ),
    );
  }

  // ══════════════ كرت المنحة ══════════════

  /// ⭐ زرّ المتابعة على الكرت — **في مسار التصفّح لا داخل التفاصيل**.
  ///
  /// ⚠️ وضعُه في شاشة التفاصيل وحدها كان سيعني فتحَ كل منحة لمتابعتها،
  ///    وهو ما لا يفعله أحد. القرار يُتخذ أثناء التصفّح فيجب أن يكون هناك.
  ///
  /// 📐 في التصميم: مربّعٌ 33 في **يسار** رأس الكرت — تعبئةٌ `#FCF8DD`
  ///    وعلامةٌ ممتلئة `#F3D31B` حين يتابعها، وأبيضُ بحدٍّ وعلامةٍ مفرغة
  ///    حين لا يتابعها (الكرتان الثالث والخامس في التصدير).
  Widget _favoriteButton(Scholarship s) {
    final on = ScholarshipFavorites.I.contains(s.id);
    return Tooltip(
      message: on ? "إلغاء المتابعة" : "تابع هذه المنحة",
      child: Material(
        color: on ? AppColors.schSaveFill : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final added = await ScholarshipFavorites.I.toggle(s.id);
            if (!mounted) return;
            setState(() {});
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                duration: const Duration(seconds: 2),
                content: Text(added
                    ? "⭐ تتابع «${s.name}» — سننبّهك قبل إغلاقها"
                    : "أُزيلت «${s.name}» من المتابَعة"),
              ));
          },
          child: Container(
            width: SchMetrics.bookmark,
            height: SchMetrics.bookmark,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: on ? AppColors.schSaveFill : AppColors.quizCardBorder),
            ),
            child: Icon(
              PI.bookmarkSimple(active: on),
              size: 18,
              color: on ? AppColors.schSaveInk : AppColors.chipInk,
            ),
          ),
        ),
      ),
    );
  }

  Widget _card(Scholarship s) {
    return SchCard(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ScholarshipDetailScreen(scholarship: s))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _logo(s),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.headingInk)),
                    if (s.country.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(s.country,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.chipInk)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _favoriteButton(s),
            ],
          ),
          if (s.shortDesc.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              s.shortDesc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  height: 1.7,
                  color: AppColors.chipInk,
                  fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: SchMetrics.tagGap,
            runSpacing: SchMetrics.tagGap,
            children: _tags(s),
          ),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: AppColors.neutralTint),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _factLine(s)),
              const SizedBox(width: 10),
              SchGhostButton(
                label: "التفاصيل والشروط",
                icon: PI.arrowLeft,
                height: SchMetrics.smallButtonHeight,
                onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => ScholarshipDetailScreen(scholarship: s))),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🏷️ وسومُ الكرت الثلاثة كما في التصدير: التمويل (أخضر) · التخصّص
  ///    (أزرق) · المهلة (أحمر).
  ///
  /// ⚠️ **وحالةُ المنحة لم تسقط**: المصمّم طوى الحالةَ في وسم المهلة
  ///    («باقٍ 12 يوماً» · «مفتوح»)، فالمغلقةُ والتي لم تُفتح بعدُ تقولان
  ///    ذلك في المكان نفسه — لا وسمَ رابعاً ولا معلومةً ضائعة.
  List<Widget> _tags(Scholarship s) {
    final days = s.daysLeft;
    final deadline = switch (s.status) {
      SchStatus.closed => "مغلق حالياً",
      SchStatus.soon => "يفتح قريباً",
      SchStatus.open => days == null
          ? "التقديم مفتوح"
          : days == 0
              ? "آخر يوم!"
              : "باقٍ $days يوماً",
    };
    return [
      SchTag(
        label: s.isFullyFunded ? "ممولة بالكامل" : "تمويل جزئي",
        icon: PI.sparkle,
        fill: AppColors.schGreenFill,
        ink: AppColors.schGreenInk,
      ),
      if (s.fields.isNotEmpty)
        SchTag(
          // ⚠️ لا «+3» بعد الاسم: في سياقٍ عربيٍّ تقفز الإشارةُ إلى الطرف
          //    الخطأ فتُقرأ «3+» ملتصقةً بالكلمة. فالعدُّ بالكلمات.
          label: s.fields.length == 1
              ? s.fields.first
              : "${s.fields.first} و${s.fields.length - 1} غيرها",
          icon: PI.graduationCap,
          fill: AppColors.schBlueFill,
          ink: AppColors.schBlueInk,
          maxWidth: 240,
        ),
      SchTag(
        label: deadline,
        icon: PI.clock,
        fill: AppColors.schRedFill,
        ink: AppColors.schRedInk,
      ),
    ];
  }

  /// سطرُ الحقيقة أسفل الكرت — تسميةٌ باهتة ثم قيمةٌ داكنة، كما في التصدير.
  ///
  /// 🎯 **التسميةُ ثابتةٌ «المعدل المطلوب»** كما في التصميم (أمرُ المالك
  ///    2026-09-21) — لا تتبدّل بين «المراحل» و«الدولة» كما كانت.
  ///    والقيمةُ من **حقل المنحة في اللوحة**، وإلا فمن شروطها نفسِها
  ///    ([gpaTextOf])، ولا تُختلق حين لا يذكرها الاثنان.
  Widget _factLine(Scholarship s) {
    final gpa = gpaTextOf(s.minGpa, s.requirements);
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: "المعدل المطلوب: ",
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.schMutedInk),
          ),
          TextSpan(
            text: gpa ?? "غير محدّد",
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.inputBarText),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  /// شعار الجامعة إن رفعه الأدمن، وإلا علم الدولة على تدرّج المنحة.
  Widget _logo(Scholarship s) {
    final box = BoxDecoration(
      gradient: LinearGradient(colors: s.colors),
      borderRadius: BorderRadius.circular(12),
    );
    if (s.logoUrl.isEmpty) {
      return Container(
        width: SchMetrics.flag,
        height: SchMetrics.flag,
        decoration: box,
        child: Center(child: Text(s.badge, style: const TextStyle(fontSize: 18))),
      );
    }
    return Container(
      width: SchMetrics.flag,
      height: SchMetrics.flag,
      decoration: box,
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: s.logoUrl,
        fit: BoxFit.cover,
        // ⚠️ رابط صورة معطوب لا يجوز أن يترك مربعاً فارغاً — نعود للعلم.
        errorWidget: (_, _, _) =>
            Center(child: Text(s.badge, style: const TextStyle(fontSize: 18))),
        placeholder: (_, _) =>
            Center(child: Text(s.badge, style: const TextStyle(fontSize: 18))),
      ),
    );
  }

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
