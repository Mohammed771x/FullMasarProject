import 'package:flutter/material.dart';
import '../../../../core/widgets/phosphor.dart';

import '../../../../core/access/access_repository.dart';
import '../../../../core/config/curriculum.dart';
import '../../../../core/notifications/notifications_repository.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/shell/masar_bottom_nav.dart';
import '../../../../core/storage/chat_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../../core/widgets/screen_tip.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../banners/data/banner_model.dart';
import '../../../banners/presentation/banner_carousel.dart';
import '../../../chat/data/edu_session.dart';
import '../../../chat/presentation/screens/main_chat_screen.dart';
import '../../../quiz/data/quiz_analytics.dart';
import '../../../quiz/data/quiz_storage.dart';
import '../../../quiz/presentation/quiz_setup_screen.dart';
import '../../../saved/data/saved_storage.dart';
import '../../../saved/presentation/saved_screen.dart';
import '../../../scholarships/data/models/scholarship.dart';
import '../../../scholarships/data/scholarship_repository.dart';
import '../../../scholarships/presentation/scholarship_detail_screen.dart';
import '../widgets/analysis_ui.dart';
import '../widgets/weak_spot_sheet.dart';
import 'analysis_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

// ==========================================
// 🏠 الرئيسية — محتوى تبويب واحدٍ داخل [MasarShell]
// ==========================================
// 🎨 **تصميم Figma** — «الرئيسية» (24:21174) · إحداثيات مطلقة:
//    رأسٌ (24,74) 342×59 · إحصاءات (24,141) 342×85 (ثلاث بطاقات 108×85 r16)
//    · بطاقة التعليم (24,234) 342×102 r14 `#D9EFFF`
//    · بانر (24,344) 342×106 r14 · نقاطه (172,458)
//    · بطاقة التحليل (24,471) 342×131 r14 `#B7C9F8`
//    · عنوان «الدروس التي تحتاج تركيز» (24,610) · صفوفٌ 342×65 r22.
//
// ⛔ **ما زال من الرئيسية:** البطاقات الثلاث (المنح · اختبر نفسك · الخدمات)
//    — وجهاتُها انتقلت إلى شريط التنقّل، وإبقاؤها يعني طريقين لمكانٍ واحد.
//
// ✅ **ما أُبقي رغم غيابه عن التصميم** (عقد التسليم):
//    · «أكمل من حيث توقفت» — تظهر حين تكون ثمّة محادثةٌ سابقة.
//    · تلميحُ أول زيارة (`ScreenTip`).
//    · حارسُ الأقسام على بطاقتَي التعليم والتحليل.
class HomeTab extends StatefulWidget {
  const HomeTab({super.key, required this.onOpenTab});

  /// يفتح تبويباً من الشريط — تستعمله البانرات وبطاقة التعليم.
  final ValueChanged<MasarTab> onOpenTab;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  void _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  bool _visible(String s) => AccessRepository.I.visible(s);

  void _guard(String section, String label, VoidCallback open) {
    final state = AccessRepository.I.of(section);
    if (state.usable) return open();
    _snack(
      state.message.isNotEmpty ? state.message : "🚧 $label — غير متاح حالياً.",
    );
  }

  /// 🎏 وجهة النقر على البانر — الخادم يرسل الوجهة، والشاشة تعرف كيف تصلها.
  Future<void> _onBannerAction(String action, String value) async {
    switch (action) {
      case "scholarship":
        final Scholarship? sch = await ScholarshipRepository().byId(value);
        if (!mounted) return;
        // ⚠️ المنحة قد تكون حُذفت بعد نشر البانر — عندها نفتح القائمة.
        if (sch == null) return widget.onOpenTab(MasarTab.scholarships);
        _go(ScholarshipDetailScreen(scholarship: sch));
      case "scholarships":
        widget.onOpenTab(MasarTab.scholarships);
      case "education":
        widget.onOpenTab(MasarTab.tutor);
      case "quiz":
        widget.onOpenTab(MasarTab.quiz);
      case "services":
        widget.onOpenTab(MasarTab.services);
      case "analysis":
        _guard(
          AppSection.analysis,
          "تحليل مستواي",
          () => _go(const AnalysisScreen()),
        );
      case "teacher":
        // 🎭 بانرٌ لقسم المعلم وصل إلى طالب — يُشرح لا يُفتح.
        _snack(
          "👨‍🏫 مساعد المعلم لحسابات المعلمين — يمكنك التحويل من الإعدادات.",
        );
      default:
        break;
    }
  }

  /// 📌 البانراتُ الرسمية الأربعة — ثابتةٌ في الكود فلا فراغَ تحت أبداً
  ///    (راجع [BannerCarousel.pinned]). ترتيبُها ترتيبُ الأقسام في الشريط،
  ///    وقسمٌ أطفأه الأدمن يغيب بانرُه معه.
  ///    (الخدماتُ «قيد التطوير» فلا يُعلَن عنها بعد.)
  List<AppBanner> _pinnedBanners() => [
        if (_visible(AppSection.education))
          const AppBanner(
            id: 'pinned:education',
            title: 'قسم التعليم 📚',
            subtitle: 'اشرح، لخّص، واسأل عن أي درسٍ من كتابك — مع مسار',
            icon: 'book',
            colors: ['#0EA5E9', '#0369A1'],
            action: 'education',
          ),
        if (_visible(AppSection.scholarships))
          const AppBanner(
            id: 'pinned:scholarships',
            title: 'قسم المنح الدراسية 🎓',
            subtitle: 'منحٌ داخل الدولة وخارجها — شروطُها ومواعيدُها في مكانٍ واحد',
            icon: 'flight',
            colors: ['#3B82F6', '#1D4ED8'],
            action: 'scholarships',
          ),
        if (_visible(AppSection.quiz))
          const AppBanner(
            id: 'pinned:quiz',
            title: 'اختبر نفسك 📝',
            subtitle: 'اختبارٌ قصير من دروسك يكشف ما أتقنتَه وما تحتاج مراجعته',
            icon: 'quiz',
            colors: ['#8B5CF6', '#5B21B6'],
            action: 'quiz',
          ),
        if (_visible(AppSection.analysis))
          const AppBanner(
            id: 'pinned:analysis',
            title: 'تحليل مستواي 📊',
            subtitle: 'مستواك في كل مادة، ونقاطُ قوّتك وما يحتاج تركيزاً',
            icon: 'chart',
            colors: ['#10B981', '#047857'],
            action: 'analysis',
          ),
      ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: AccessRepository.I,
        // 🔴 **`ScreenTip` يرجع `Positioned`، فمكانُه `Stack` لا `Column`.**
        //    كان آخرَ أبناء العمود داخل التمرير، فكان فلاتر يرمي
        //    «Incorrect use of ParentDataWidget» في **كل بناء** ولا يظهر
        //    التلميحُ للطالب أبداً. (رُصد في سجلّ `flutter run` أثناء
        //    فحص الاستثناءات 2026-09-21؛ العلّةُ سابقةٌ لقسم المنح.)
        builder: (context, _) => Stack(
          children: [
            SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 8),
              _stats(),
              const SizedBox(height: 8),
              if (_visible(AppSection.education)) ...[
                _EduCard(onTap: () => widget.onOpenTab(MasarTab.tutor)),
                const SizedBox(height: 8),
              ],
              BannerCarousel(
                section: BannerSection.home,
                onAction: _onBannerAction,
                pinned: _pinnedBanners(),
              ),
              const SizedBox(height: 8),
              if (_visible(AppSection.analysis)) ...[
                _AnalysisCard(
                  onTap: () => _guard(
                    AppSection.analysis,
                    "تحليل مستواي",
                    () => _go(const AnalysisScreen()),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              _weakSpots(),
              _continueCard(),
            ],
          ),
        ),
            // 💡 تلميح أول زيارة — يظهر مرة واحدة ويختفي تلقائياً.
            const ScreenTip(
              screenId: "home",
              text:
                  "أهلاً بك في مسار 👋 ابدأ من بطاقة «قسم التعليم»، وتنقّل بين الأقسام من الشريط السفلي.",
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // 👤 الرأس — (24,74) 342×59
  // ══════════════════════════════════════════════════
  Widget _header() {
    final s = UserSession.I;
    return SizedBox(
      height: 59,
      // 📐 **ترتيب RTL:** أول ابنٍ في `Row` هو **الأيمن**. والتصميم يضع
      //    الصورة في أقصى اليمين (x=314) ثم الاسم، والجرسَ والإعدادات في
      //    أقصى اليسار (x=72 و24) — فهذا ترتيبُ الأبناء بالضبط.
      child: Row(
        children: [
          // 👤 صورة الطالب 52×52 — أقصى اليمين.
          //
          // 🔴 **أمرُ المالك (2026-09-21):** «تظهر لمّا نضغط على الطالب» —
          //    فالنقرُ صار يفتح «معلومات الطالب» (وفيها تحليلُ مستواه).
          //    وبابُ **تغيير الصورة** لم يضع: انتقل إلى الصورة نفسِها
          //    داخل بطاقة تلك الشاشة، حيث هي أكبرُ وأوضح.
          InkWell(
            onTap: () => _guard(
              AppSection.analysis,
              "معلومات الطالب",
              () => _go(const AnalysisScreen()),
            ),
            customBorder: const CircleBorder(),
            child: const UserAvatar(radius: 26),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Text(
                    "مرحباً 👋",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.greetInk,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    s.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      color: AppColors.headingInk,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                "الصف ${s.gradeLabel}${Curriculum.hasTracks(s.grade) ? ' — ${s.track}' : ''}",
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary900,
                ),
              ),
            ],
          ),
          const Spacer(),
          ListenableBuilder(
            listenable: NotificationsRepository.I,
            builder: (_, _) => _circleBtn(
              PI.bell.regular,
              () => _go(const NotificationsScreen()),
              badgeCount: NotificationsRepository.I.unreadCount,
            ),
          ),
          const SizedBox(width: 8),
          _circleBtn(PI.gear.regular, () => _go(const SettingsScreen())),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {int badgeCount = 0}) =>
      Stack(
        clipBehavior: Clip.none,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.rowBorder),
              ),
              child: Icon(icon, color: AppColors.slateNumber, size: 20),
            ),
          ),
          // 🔴 **عددٌ حقيقي لا نقطةٌ دائمة**: شارةٌ لا تنطفئ تُعلّم الطالبَ
          //    تجاهُلها، فحين يصل جديدٌ فعلاً لا يراه.
          if (badgeCount > 0)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                padding: const EdgeInsets.symmetric(horizontal: 5),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.badgeRed,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceWhite, width: 2),
                ),
                child: Text(
                  badgeCount > 9 ? "9+" : "$badgeCount",
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      );

  // ══════════════════════════════════════════════════
  // 📊 الإحصاءات — ثلاث بطاقات 108×85 r16
  // ══════════════════════════════════════════════════
  Widget _stats() {
    // ✅ أرقام حقيقية من Hive والجلسة. و🎓 **أرقام الصف الحالي وحده** —
    //    تبديلُ الصف من الإعدادات يبدّلها كلها.
    final scope = UserSession.I.scope;
    // 👨‍🏫 **ومحادثاتُ قسم التعليم وحدها.** رئيسيةُ الطالب لا يدخلها معلّم،
    //    لكنّ الدورَ يُبدَّل من الإعدادات — فحسابٌ جرّب القسمين كان يقرأ
    //    «٥ محادثة» وفيها خططُ دروسٍ وواجباتٌ لا تخصّ الطالبَ في شيء،
    //    وتُحسب معها «مادة درستها» ([isTeacherMode]).
    final conversations = ChatStorage.getAllConversations(
      UserSession.I.uid,
      scope: scope,
      teacher: false,
    );
    final subjects = conversations.map((c) => c.subject).toSet().length;
    final saved = SavedStorage.count(UserSession.I.uid, scope: scope);

    return SizedBox(
      height: 85,
      child: Row(
        children: [
          _stat(
            PI.chats.fill,
            "${conversations.length}",
            "محادثة",
            AppColors.secondary500,
          ),
          const SizedBox(width: 9),
          _stat(
            PI.bookOpenText.fill,
            "$subjects",
            "مادة درستها",
            AppColors.primary700,
          ),
          const SizedBox(width: 9),
          _stat(
            PI.star.fill,
            "$saved",
            "محفوظ",
            AppColors.warning600,
            onTap: () => _go(const SavedScreen()),
          ),
        ],
      ),
    );
  }

  Widget _stat(
    IconData icon,
    String value,
    String label,
    Color tint, {
    VoidCallback? onTap,
  }) {
    final card = Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.rowBorder),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 📐 **الرسم عارياً بلا مربّعٍ ملوّن** — التصميم لا يضع خلفيةً
          //    تحت أيقونة الإحصاءة، والمربّع الملوّن يصغّرها بصرياً.
          //    و35 هو مقاس الإطار في الملف، والرسمُ يملؤه.
          SizedBox(height: 35, child: Icon(icon, size: 33, color: tint)),
          const SizedBox(height: 4),
          // 🖋️ **w900 لا w700**: الملف يقول 700، لكن Cairo في تصدير Figma
          //    يظهر أثقل من `FontWeight.w700` في فلاتر — والمطابقةُ بما
          //    يراه الطالب لا بالرقم المكتوب. والرقمُ والتسمية كلاهما
          //    غامقٌ في التصميم بلون `#091E42`.
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.brandInk,
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: AppColors.brandInk,
            ),
          ),
        ],
      ),
    );
    return Expanded(
      child: onTap == null
          ? card
          : InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: card,
            ),
    );
  }

  // ══════════════════════════════════════════════════
  // 🎯 الدروس التي تحتاج تركيز — (24,610) ثم صفوفٌ 342×65 r22
  // ══════════════════════════════════════════════════
  // ⭐ **من التصميم، وبياناتُه من التطبيق**: `QuizAnalytics` هي مصدر نقاط
  //    الضعف اليوم في شاشة التحليل — والرئيسيةُ تعرض أوّلَ ثلاثةٍ منها.
  Widget _weakSpots() {
    // 🎓 **نتائج هذا الصف وحده** — كما في شاشة التحليل تماماً. وخلطُ سنواتٍ
    //    يجعل الرئيسية تشير إلى درسٍ لا يُدرَّس هذه السنة.
    final results = QuizStorage.all(
      UserSession.I.uid,
      scope: UserSession.I.scope,
    );
    final weak = QuizAnalytics.weakSpots(results, limit: 3);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        SizedBox(
          height: 30,
          // 📐 التصميم: العنوان في اليمين (ينتهي عند 366) و«عرض الكل»
          //    في اليسار (x=24) — فالعنوان أولُ ابنٍ في RTL.
          child: Row(
            children: [
              Text(
                "الدروس التي تحتاج تركيز",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.headingInk,
                ),
              ),
              const Spacer(),
              // 🔗 **«عرض الكل» تختفي وحدها حين لا شيءَ يُعرض** — رابطٌ
              //    يفتح شاشةً فارغة يبدو عطلاً، والبطاقةُ تحته تقول
              //    للطالب ما يفعل بدلاً منه.
              if (weak.isNotEmpty)
                InkWell(
                  onTap: () => _guard(
                    AppSection.analysis,
                    "تحليل مستواي",
                    () => _go(const AnalysisScreen()),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Text(
                      "عرض الكل",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (weak.isEmpty) _weakSpotsEmpty(),
        for (final w in weak) ...[
          // 🧩 **القطعةُ المشتركة** — الصفُّ نفسُه في شاشة التحليل وشاشة
          //    المادة. كان منسوخاً هنا، فافترق عن نفسِه عند أوّل تعديل.
          AnalysisFocusRow(
            title: w.lesson,
            subtitle: "${w.subject} · ${w.unit}",
            // 📉 الرقم المعروض **نسبة الخطأ** — وهو ما ترتّب به الدروس
            //    وما تعرضه شاشة التحليل، فلا يختلف رقمان لدرسٍ واحد.
            percent: w.errorRate,
            onTap: () => showWeakSpotSheet(
              context,
              w,
              onExplain: () => _go(
                MainChatScreen(
                  openSubject: w.subject,
                  openUnit: w.unit,
                  openLesson: w.lesson,
                  openMode: "شرح",
                ),
              ),
              onRetakeQuiz: () => _go(
                QuizSetupScreen(
                  initialSubject: w.subject,
                  presetUnit: w.unit,
                  presetLessons: [w.lesson],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // ══════════════════════════════════════════════════
  // 🎯 وحين لا أخطاءَ بعد — بطاقةٌ تدعو لا فراغٌ أبيض
  // ══════════════════════════════════════════════════
  /// 🔴 **ملاحظةُ المالك (٢٠٢٦-٠٩-٢٢):** «أوّلُ ما يدخل الطالب، تحت ماشي
  ///    دروسٌ تحتاج تركيز… ماشي مكانٌ فاضي يكون».
  ///
  /// وكان القسمُ كلُّه يُحذف (`SizedBox.shrink`) فيبقى تحت بطاقة التحليل
  /// بياضٌ لا يقول شيئاً — **وأوّلُ شاشةٍ يراها الطالبُ في حياته مع
  /// التطبيق هي هذه**. فصار مكانَه بابٌ إلى أوّل خطوةٍ يحتاجها: اختبار.
  ///
  /// 🎨 وبمفردات الملف نفسِها: نصفُ قطرِ صفِّ التركيز (22)، ومربّعُ أيقونةٍ
  ///    مصبوغٌ بلون الهوية، وزرٌّ 150×27 r8 هو زرُّ بطاقة التعليم عينُه.
  Widget _weakSpotsEmpty() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.fieldFill,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.fieldBorder),
        ),
        // ⚠️ RTL: أوّلُ ابنٍ يميناً ⇒ الأيقونةُ يمين والنصُّ إلى يسارها،
        //    كترتيب صفِّ «الدروس التي تحتاج تركيز» فوقها.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primaryTintSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(PI.target.regular,
                  size: 22, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "هنا تظهر دروسك التي تحتاج تركيز",
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: AppColors.headingInk,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "اختبر نفسك في أي درس، ونرتّب لك بعدها ما تحتاج "
                    "مراجعته — من الأكثر خطأً إلى الأقل.",
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.6,
                      fontWeight: FontWeight.w400,
                      color: AppColors.rowHint,
                    ),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () => _guard(
                      AppSection.quiz,
                      "اختبر نفسك",
                      () => widget.onOpenTab(MasarTab.quiz),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 150,
                      height: 27,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.primaryFill,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "ابدأ اختباراً الآن",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  /// 🔁 «أكمل من حيث توقفت» — غير موجودة في التصميم، وأُبقيت لأنها ميزةٌ قائمة.
  ///
  /// 🔴 **عطلُ المالك (٢٠٢٦-٠٩-٢٢): «الزرّ مو شغّال».** وكان صادقاً: البطاقةُ
  ///    تقرأ آخر محادثةٍ لتعرض اسم مادتها، ثم تفتح القسمَ بـ`onOpenTab`
  ///    **بلا أن تخبره بشيء** — فيبدأ القسمُ كأيّ فتحةٍ جديدة: أوّلُ مادةٍ
  ///    في قائمة الصف ومحادثةٌ فارغة. أي أن البطاقة تَعِد بالمتابعة وتفتح
  ///    بداية — والاسمُ المعروض عليها يجعل العطلَ أوضح.
  ///
  /// ✅ والوجهةُ الآن تُكتب في [EduSession] قبل فتح التبويب، وهي الآليّةُ
  ///    نفسُها التي يستعيد بها القسمُ مكانَه (لا مسارٌ ثانٍ ينحرف عنها).
  ///
  /// 🎓 **والمحادثةُ من نطاق الصف الحالي** (`scope`) — فبطاقةٌ تظهر لطالبٍ
  ///    بدّل صفَّه تحمل آخر محادثةٍ في صفِّه **الجديد**، أو تختفي إن لم
  ///    يبدأ فيه شيئاً بعد.
  Widget _continueCard() {
    final scope = UserSession.I.scope;
    // 👨‍🏫 **محادثاتُ قسم التعليم وحدها** — وهذا نصفُ العطل الثاني: رُصد في
    //    المحاكي (٢٠٢٦-٠٩-٢٢) أن البطاقة تلتقط آخر محادثةِ **معلّم**
    //    («خطة درس · تاريخ»)، فتفتح قسم التعليم على مادتها بلا رسائلها —
    //    لأن تلك المحادثة ليست في سجلّ الطالب أصلاً ([isTeacherMode]).
    final all = ChatStorage.getAllConversations(
      UserSession.I.uid,
      scope: scope,
      teacher: false,
    );
    if (all.isEmpty) return const SizedBox.shrink();
    final last = all.first;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        onTap: () {
          EduSession.I.rememberConversation(last, UserSession.I.uid);
          widget.onOpenTab(MasarTab.tutor);
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.rowBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: AppColors.primaryTintSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  PI.clockCounterClockwise.regular,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "أكمل من حيث توقفت",
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        color: AppColors.cardHint,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      last.subject,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.headingInk,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(PI.playCircle.fill, color: AppColors.primary, size: 30),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        m,
        style: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: AppColors.primaryFill,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

// ══════════════════════════════════════════════════
// 📚 بطاقة قسم التعليم — 342×102 r14 `#D9EFFF`
// ══════════════════════════════════════════════════
// 🤖 الروبوت في **بداية** البطاقة (يمين RTL) كما في التصميم، والنصّ يليه.
class _EduCard extends StatelessWidget {
  const _EduCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      height: 102,
      clipBehavior: Clip.hardEdge,
      // ⚠️ **لا حشوة على البطاقة** — الحشوةُ للنصّ وحده. وحشوةٌ عامّة
      //    تقصّ من ارتفاع الرسم فيصغر عن التصميم (ملاحظة المالك).
      decoration: BoxDecoration(
        color: AppColors.eduCardSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
              child: Column(
                // ⚠️ `start` لا `end`: في RTL تعني **اليمين**، وهناك
                //    يجلس العنوان والزرّ في التصميم (ينتهيان عند 350).
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "قسم التعليم",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.brandInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "اشرح، لخّص، اسأل، وتدرّب على الوزاري",
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: AppColors.brandInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 150,
                    height: 27,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.primaryFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "ابدأ التعلّم",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 🤖 **يملأ ارتفاع البطاقة** — في التصميم صورةٌ خلفية تشغل
          //    الارتفاع كاملاً وتبرز إلى ثلث العرض.
          const SizedBox(
            height: 102,
            child: MasarRobot(size: 146, pose: MasarRobotPose.fly),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════
// 📈 بطاقة تحليل مستواي — 342×131 r14 `#B7C9F8`
// ══════════════════════════════════════════════════
class _AnalysisCard extends StatelessWidget {
  const _AnalysisCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: Container(
      height: 131,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: AppColors.analysisCardSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 8, 8, 8),
              child: Column(
                // ⚠️ `start` لا `end`: في RTL تعني **اليمين**، وهناك
                //    يجلس العنوان والزرّ في التصميم (ينتهيان عند 350).
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "تحليل مستواي",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.analysisCardInk,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "اعرف نقاط قوتك وضعفك واحصل على توصيات لتحسين مستواك.",
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.8,
                      fontWeight: FontWeight.w600,
                      color: AppColors.analysisCardInk,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 150,
                    height: 27,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryFill,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      "فتح التحليل",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 📐 **يملأ ارتفاع البطاقة** — في التصميم يشغل 118 من 131.
          Image.asset(
            'assets/art/art_analysis.png',
            height: 129,
            fit: BoxFit.contain,
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════
// 🎯 صفّ درسٍ يحتاج تركيز — 342×65 r22
// ══════════════════════════════════════════════════
