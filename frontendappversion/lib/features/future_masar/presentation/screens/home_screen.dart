import 'analysis_screen.dart';
import 'package:flutter/material.dart';

import '../../../../core/access/access_repository.dart';
import '../../../../core/notifications/notifications_repository.dart';
import '../../../../core/config/curriculum.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/storage/chat_storage.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../../../core/widgets/screen_tip.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../banners/data/banner_model.dart';
import '../../../banners/presentation/banner_carousel.dart';
import '../../../saved/data/saved_storage.dart';
import '../../../saved/presentation/saved_screen.dart';
import '../../../chat/presentation/screens/main_chat_screen.dart';
import '../../data/demo_state.dart';
import '../widgets/demo_widgets.dart';
import '../../../../core/widgets/robot_widget.dart';
import '../../../scholarships/data/models/scholarship.dart';
import '../../../scholarships/data/scholarship_repository.dart';
import '../../../scholarships/presentation/scholarship_detail_screen.dart';
import '../../../scholarships/presentation/scholarships_screen.dart';
import '../../../quiz/presentation/quiz_setup_screen.dart';
import 'notifications_screen.dart';
import 'settings_screen.dart';

// ==========================================
// 🏠 الشاشة الرئيسية (Home)
// ==========================================
class FutureHomeScreen extends StatefulWidget {
  const FutureHomeScreen({super.key});

  @override
  State<FutureHomeScreen> createState() => _FutureHomeScreenState();
}

class _FutureHomeScreenState extends State<FutureHomeScreen> {

  void _go(Widget page) => Navigator.push(context, MaterialPageRoute(builder: (_) => page));

  /// يفتح قسم التعليم = شاشة الشات الفعلية (وليست شاشة الديمو).
  Future<void> _openEducation() async {
    final state = AccessRepository.I.of(AppSection.education);
    if (!state.usable) {
      _snack(state.message.isNotEmpty ? state.message : "📚 التعليم — غير متاح حالياً.");
      return;
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const MainChatScreen()));
    if (mounted) setState(() {}); // تحديث عدّاد المحادثات بعد العودة
  }

  /// 🎓 قسم المنح — بيانات حقيقية من الخادم لا من الديمو.
  Future<void> _openScholarships() async {
    final state = AccessRepository.I.of(AppSection.scholarships);
    if (!state.usable) {
      _snack(state.message.isNotEmpty ? state.message : "🎓 المنح — غير متاح حالياً.");
      return;
    }
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ScholarshipsScreen()));
    if (mounted) setState(() {});
  }

  /// 🎏 وجهة النقر على البانر — الخادم يرسل الوجهة، والشاشة تعرف كيف تصلها.
  ///
  /// ⚠️ المنحة قد تكون حُذفت أو أُخفيت من اللوحة بعد نشر البانر — عندها
  ///    نفتح القائمة بدل إظهار شاشة تفاصيل فارغة.
  Future<void> _onBannerAction(String action, String value) async {
    switch (action) {
      case "scholarship":
        final Scholarship? sch = await ScholarshipRepository().byId(value);
        if (!mounted) return;
        if (sch == null) {
          await _openScholarships();
          return;
        }
        _go(ScholarshipDetailScreen(scholarship: sch));
      case "scholarships":
        await _openScholarships();
      case "education":
        await _openEducation();
      case "quiz":
        _guard(AppSection.quiz, "اختبر نفسك", () => _go(const QuizSetupScreen()));
      case "analysis":
        _guard(AppSection.analysis, "تحليل مستواي", () => _go(const AnalysisScreen()));
      case "teacher":
        // 🎭 بانرٌ لقسم المعلم وصل إلى طالب — يُشرح لا يُفتح.
        _snack("👨‍🏫 مساعد المعلم لحسابات المعلمين — يمكنك التحويل من الإعدادات.");
      case "services":
        _comingSoon("الخدمات");
      default:
        break;
    }
  }

  /// أقسام لم تُوصَل بالخادم بعد — تُعرض ولا تُفتح.
  void _comingSoon(String section) => _snack("🚧 $section — قيد التطوير، قريباً بإذن الله");

  // ══════════════ 🔐 حارس الأقسام ══════════════
  // ⭐ **إخفاءٌ لا حماية.** الحماية في الخادم: `_section_gate` يرفض المسار
  //    نفسه بـ403 ويقرأ الصفَّ من `users/{uid}` لا من الطلب. ما هنا يمنع
  //    الطالبَ من رؤية زرٍّ يفشل — وهو لطفٌ بالواجهة لا حاجزُ أمان.
  //
  // 🛟 ويفشل مفتوحاً: القسم الذي لا يقول عنه الخادم شيئاً **مفتوح**.

  /// يفتح القسم إن كان مسموحاً، وإلا شرح للطالب لماذا لا يُفتح.
  ///
  /// ⚠️ الرسالة **من اللوحة لا من الكود**: المالك يكتب «يفتح بعد
  ///    الاختبارات» فيقرأها الطالب حرفياً — ورسالةٌ عامة مكتوبة هنا كانت
  ///    ستطمس ما أراد قوله.
  void _guard(String section, String label, VoidCallback open) {
    final state = AccessRepository.I.of(section);
    if (state.usable) {
      open();
      return;
    }
    _snack(state.message.isNotEmpty
        ? state.message
        : "🚧 $label — غير متاح حالياً.");
  }

  bool _visible(String section) => AccessRepository.I.visible(section);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          SafeArea(
            // 🔄 نستمع للقواعد أيضاً: أول رسمٍ يأتي من الكاش، ثم يصل ردّ
            //    الخادم بعد لحظة — وبلا هذا يبقى قسمٌ أُخفي ظاهراً حتى
            //    ينتقل الطالب لشاشةٍ أخرى ويعود.
            child: AnimatedBuilder(
              animation: Listenable.merge([DemoState.I, AccessRepository.I]),
              builder: (context, _) => SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _header(),
                    const SizedBox(height: 18),
                    _stats(),
                    const SizedBox(height: 20),
                    BannerCarousel(
                      section: BannerSection.home,
                      onAction: _onBannerAction,
                    ),
                    const SizedBox(height: 24),
                    if (_visible(AppSection.education)) ...[
                      _heroEducation(),
                      const SizedBox(height: 16),
                    ],
                    _threeCards(),
                    const SizedBox(height: 16),
                    if (_visible(AppSection.analysis)) ...[
                      _analysisCard(),
                      const SizedBox(height: 16),
                    ],
                    // 👨‍🏫 **لا بطاقة معلم هنا إطلاقاً.** هذه رئيسية الطالب،
                    //    ومن اختار «معلّم» يفتح التطبيق على [TeacherHomeScreen]
                    //    مباشرةً ولا يمرّ بهذه الشاشة أصلاً ([RoleHome]).
                    //    وبطاقةٌ تعرض على الطالب قسماً لغيره دعوةٌ للتشتّت.
                    if (DemoState.I.lastChatSubject != null) ...[
                      const SizedBox(height: 20),
                      _continueCard(),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // 💡 بديل الروبوت العائم: تلميح يظهر مرة واحدة ويختفي تلقائياً.
          const ScreenTip(
            screenId: "home",
            text: "أهلاً بك في مسار 👋 ابدأ من بطاقة «قسم التعليم» — بقية الأقسام تُفتح تباعاً.",
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final s = UserSession.I;
    return FadeInSlide(
      child: Row(
        children: [
          // 👤 صورة الطالب — النقر يفتح خيارات التغيير مباشرةً من هنا.
          UserAvatar(radius: 26, editable: !s.isGuest, onChanged: () => setState(() {})),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${s.greeting}، ${s.name} 👋", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(10)),
                  child: Text(
                    "الصف ${s.gradeLabel}${Curriculum.hasTracks(s.grade) ? ' — ${s.track}' : ''}",
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          // 🔔 **الجرس يفتح الصندوق، والشارة من عدّادٍ حقيقي.** كان يعرض
          //    نصّاً ثابتاً بشارةٍ حمراء لا تنطفئ: تُخبر الطالبَ أن ثمّة
          //    جديداً دائماً، فيتعلّم تجاهُلها — فحين يصل جديدٌ فعلاً لا يراها.
          ListenableBuilder(
            listenable: NotificationsRepository.I,
            builder: (_, _) => _circleBtn(
              Icons.notifications_rounded,
              () => _go(const NotificationsScreen()),
              badge: NotificationsRepository.I.hasUnread,
            ),
          ),
          const SizedBox(width: 10),
          _circleBtn(Icons.settings_rounded, () => _go(const SettingsScreen())),
        ],
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {bool badge = false}) {
    return Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(16), boxShadow: AppColors.bubbleShadow),
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
        ),
        if (badge) Positioned(right: 8, top: 8, child: Container(width: 9, height: 9, decoration: BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle, border: Border.all(color: AppColors.surfaceWhite, width: 1.5)))),
      ],
    );
  }

  Widget _stats() {
    // ✅ أرقام حقيقية من Hive والجلسة — لا نقاط ولا أيام متتالية وهمية.
    // 🎓 **أرقام الصف الحالي وحده** — تبديلُ الصف من الإعدادات يبدّلها كلها.
    final scope = UserSession.I.scope;
    final conversations =
        ChatStorage.getAllConversations(UserSession.I.uid, scope: scope);
    final subjectsUsed = conversations.map((c) => c.subject).toSet().length;

    return FadeInSlide(
      delay: 0.1,
      child: Row(
        children: [
          _stat(Icons.forum_rounded, "${conversations.length}", "محادثة", AppColors.primary),
          const SizedBox(width: 12),
          _stat(Icons.menu_book_rounded, "$subjectsUsed", "مادة درستها", AppColors.secondary),
          const SizedBox(width: 12),
          _stat(Icons.star_rounded, "${SavedStorage.count(UserSession.I.uid, scope: scope)}", "محفوظ", Colors.orange,
              onTap: () async {
                await Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SavedScreen()));
                if (mounted) setState(() {});
              }),
        ],
      ),
    );
  }

  Widget _stat(IconData icon, String v, String label, Color color, {VoidCallback? onTap}) {
    final card = SoftCard(
      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 8),
      child: Column(children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(v, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
      ]),
    );
    return Expanded(
      child: onTap == null
          ? card
          : InkWell(borderRadius: BorderRadius.circular(20), onTap: onTap, child: card),
    );
  }

  Widget _heroEducation() {
    return FadeInSlide(
      delay: 0.2,
      child: InkWell(
        onTap: _openEducation,
        borderRadius: BorderRadius.circular(28),
        child: Container(
          height: 150,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(28), boxShadow: AppColors.softShadow),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("📚 قسم التعليم", style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text("اشرح، لخّص، اسأل، وتدرّب على الوزاري", style: TextStyle(color: Colors.white.withValues(alpha: 0.92), fontSize: 12.5, height: 1.4, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                      child: Text("ابدأ التعلّم", style: TextStyle(color: AppColors.onWhite, fontWeight: FontWeight.bold, fontSize: 12.5)),
                    ),
                  ],
                ),
              ),
              RobotWidget(size: 100, state: RobotState.idle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _threeCards() {
    // ⚠️ **تُبنى ثم تُصفّى، لا العكس**: الفهرس يحكم الحشوة بين البطاقات،
    //    فبناءُ قائمةٍ منقوصةٍ ابتداءً كان سيترك فراغاً في يمين الصف حيث
    //    كان القسم المخفيّ.
    final items = [
      if (_visible(AppSection.scholarships))
        _C("🎓 المنح", "منح حول العالم", Icons.public_rounded,
            const [Color(0xFF8B5CF6), Color(0xFF6D28D9)], _openScholarships,
            ready: AccessRepository.I.usable(AppSection.scholarships)),
      if (_visible(AppSection.quiz))
        _C("🧠 اختبر نفسك", "اختبارات من دروسك", Icons.quiz_rounded,
            const [Color(0xFF0EA5E9), Color(0xFF2563EB)],
            () => _guard(AppSection.quiz, "اختبر نفسك",
                () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const QuizSetupScreen()))),
            ready: AccessRepository.I.usable(AppSection.quiz)),
      if (_visible(AppSection.services))
        _C("🛠️ الخدمات", "قبول وتجهيز", Icons.handshake_rounded,
            const [Color(0xFF10B981), Color(0xFF0D9488)],
            () => _guard(AppSection.services, "قسم الخدمات",
                () => _comingSoon("قسم الخدمات"))),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Row(
      children: List.generate(items.length, (i) {
        final c = items[i];
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: i < items.length - 1 ? 12 : 0),
            child: FadeInSlide(
              delay: 0.25 + i * 0.07,
              child: InkWell(
                onTap: c.onTap,
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  height: 130,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: c.gradient, begin: Alignment.topRight, end: Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [BoxShadow(color: c.gradient.last.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 8))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)), child: Icon(c.icon, color: Colors.white, size: 20)),
                          const Spacer(),
                          if (!c.ready)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.26), borderRadius: BorderRadius.circular(8)),
                              child: const Text("قريباً", style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900)),
                            ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.title, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 2),
                          Text(c.sub, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// 📊 قسم التحليل — يُبنى من نتائج الاختبارات المحفوظة محلياً.
  Future<void> _openAnalysis() async {
    final state = AccessRepository.I.of(AppSection.analysis);
    if (!state.usable) {
      _snack(state.message.isNotEmpty ? state.message : "📊 تحليل مستواي — غير متاح حالياً.");
      return;
    }
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const AnalysisScreen()));
    if (mounted) setState(() {}); // العدّادات أعلى الصفحة قد تتغيّر
  }

  Widget _analysisCard() {
    return FadeInSlide(
      delay: 0.32,
      child: InkWell(
        onTap: _openAnalysis,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0F172A), Color(0xFF334155)], begin: Alignment.topRight, end: Alignment.bottomLeft),
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.softShadow,
          ),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)), child: const Text("📊", style: TextStyle(fontSize: 24))),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("تحليل مستواي", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text("اعرف نقاط قوتك وضعفك واحصل على توصيات لتحسين مستواك.", style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Icon(Icons.arrow_circle_left_rounded, color: Colors.white.withValues(alpha: 0.9), size: 26),
            ],
          ),
        ),
      ),
    );
  }


  Widget _continueCard() {
    final s = DemoState.I;
    return FadeInSlide(
      child: InkWell(
        onTap: _openEducation,
        borderRadius: BorderRadius.circular(20),
        child: SoftCard(
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14)), child: Icon(Icons.history_rounded, color: AppColors.primary, size: 22)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("أكمل من حيث توقفت", style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 3),
                    Text("${s.lastChatSubject} · قبل قليل", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                  ],
                ),
              ),
              Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 34),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}

class _C {
  /// هل القسم يعمل فعلاً؟ الجاهز بلا شارة «قريباً» — وإلا كذبت الواجهة
  /// على الطالب وأخفت قسماً مكتملاً.
  final bool ready;

  final String title, sub;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  _C(this.title, this.sub, this.icon, this.gradient, this.onTap, {this.ready = false});
}
