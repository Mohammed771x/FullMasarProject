import 'package:flutter/material.dart';

import '../../../core/config/curriculum.dart';
import '../../../core/notifications/notifications_repository.dart';
import '../../../core/session/user_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../banners/data/banner_model.dart';
import '../../banners/presentation/banner_carousel.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/robot_widget.dart';
import '../../../core/widgets/screen_tip.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../chat/presentation/screens/main_chat_screen.dart';
import '../../future_masar/presentation/screens/notifications_screen.dart';
import '../../saved/presentation/saved_screen.dart';
import '../../future_masar/presentation/screens/settings_screen.dart';
import '../data/teacher_tool.dart';

// ==========================================
// 👨‍🏫 مساعد المعلم — بوابة الأدوات الأربع
// ==========================================
// ⭐ الفرق عن شاشة الديمو التي حلّت محلّها: الكروت هنا تفتح **شات مسار نفسه**
//    (`MainChatScreen`) بأداةٍ محدّدة، لا شاشةً ثانية بردود مكتوبة في الكود.
//    فكل ما في قسم التعليم — الصور والصوت والنسخ والإيقاف وسجلّ المحادثات
//    والسياق — يعمل هنا **بالبناء لا بالنقل**.
//
// 🎭 **وهي رئيسيةُ المعلّم نفسها** حين [isHome]: من اختار «معلّم» يفتح
//    التطبيق عليها مباشرةً ولا يرى شيئاً من واجهة الطالب — لا إحصائيات ولا
//    اختبارات ولا منح. وهذا نصّ طلب المالك: «واجهات قسم المعلم فقط».
//    الفرق بين الوضعين **ترويسةٌ لا أكثر**: شريطُ رجوعٍ حين تُفتح كشاشة،
//    وترويسةُ حسابٍ (صورة · اسم · صف · جرس · إعدادات) حين تكون البيت.
class TeacherHomeScreen extends StatefulWidget {
  const TeacherHomeScreen({super.key, this.isHome = false});

  /// أهي **الشاشة الأولى** للمعلّم؟ (لا شريط رجوع، وترويسة حساب بدله)
  final bool isHome;

  @override
  State<TeacherHomeScreen> createState() => _TeacherHomeScreenState();
}

class _TeacherHomeScreenState extends State<TeacherHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: widget.isHome ? null : AppBar(
        backgroundColor: AppColors.surfaceWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text("مساعد المعلم 👨‍🏫",
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text("خطّط · بسّط · قوّم — من كتابك المدرسي",
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary)),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
            children: [
              if (widget.isHome) ...[
                _accountHeader(context),
                const SizedBox(height: 18),
              ],
              FadeInSlide(child: _hero()),
              const SizedBox(height: 16),
              // 🎏 بانر قسم مساعد المعلم.
              BannerCarousel(
                section: BannerSection.teacher,
                onAction: (a, v) {},
                height: 110,
              ),
              const SizedBox(height: 16),
              _sectionHeader("أدوات المعلم"),
              const SizedBox(height: 12),
              ...List.generate(
                TeacherTool.values.length,
                (i) => FadeInSlide(
                  delay: 0.1 + i * 0.07,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: _card(context, TeacherTool.values[i]),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _sourceNote(),
            ],
          ),
          const ScreenTip(
            screenId: "teacher_home",
            text: "اختر أداة، ثم حدّد المادة والدرس داخلها — كل شيء يُبنى من كتابك المدرسي.",
            autoHideAfter: Duration(seconds: 10),
            anchorTop: true,
            topOffset: 8,
          ),
        ],
        ),
      ),
    );
  }

  // ══════════════ 🎭 ترويسة حساب المعلّم ══════════════
  // ⭐ **مطابقةٌ لترويسة الطالب في وظيفتها لا في محتواها**: الصورة والاسم
  //    والصف والجرس والإعدادات — بلا أي رقمٍ من أرقام الطالب. المعلّم لا
  //    تعنيه «كم محادثة» ولا «كم محفوظ»، فعرضُها عليه ضجيجٌ لا معلومة.
  Widget _accountHeader(BuildContext context) {
    final s = UserSession.I;
    return FadeInSlide(
      child: Row(
        children: [
          UserAvatar(radius: 26, editable: !s.isGuest, onChanged: () => setState(() {})),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${s.greeting}، ${s.name} 👋",
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10)),
                  // 👨‍🏫 «أُدرّس …» لا «الصف …»: الصف نفسه، والمعنى مختلف —
                  //    والمعلّم يبدّله من الإعدادات كما يبدّله الطالب.
                  child: Text(
                    "👨‍🏫 أُدرّس ${s.gradeLabel}"
                    "${Curriculum.hasTracks(s.grade) ? ' — ${s.track}' : ''}",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          // 💾 **بنك المعلّم.** `SavedStorage` كانت تختم المحفوظ بـ
          //    `section: "teacher"` منذ البداية ([chat_list_view.dart])،
          //    لكن **لا منفذ في رئيسية المعلّم يفتحها** — فكان يولّد خطة
          //    درسٍ أو ورقة أسئلة، يحفظها، ثم لا يجد إليها سبيلاً أبداً.
          //    المخزن كان جاهزاً؛ الناقص بابٌ واحد.
          _circleBtn(Icons.bookmark_rounded, () => _go(const SavedScreen())),
          const SizedBox(width: 10),
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

  Future<void> _go(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) setState(() {});
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap, {bool badge = false}) {
    return Stack(
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(16),
                boxShadow: AppColors.bubbleShadow),
            child: Icon(icon, color: AppColors.textPrimary, size: 22),
          ),
        ),
        if (badge)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surfaceWhite, width: 1.5)),
            ),
          ),
      ],
    );
  }

  Widget _hero() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF3730A3)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft),
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("مساعدك التعليمي الذكي 🎓",
                    style: TextStyle(
                        color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text(
                  "وفّر وقتك وحسّن طريقة شرحك — بأدوات تقرأ درسك من الكتاب المدرسي اليمني نفسه.",
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 12.5,
                      height: 1.5,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          RobotWidget(size: 90, state: RobotState.point),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) => Row(
        children: [
          Container(
            width: 5,
            height: 20,
            decoration: BoxDecoration(
                gradient: AppColors.mainGradient,
                borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(width: 10),
          Text(title,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary)),
        ],
      );

  Widget _card(BuildContext context, TeacherTool tool) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => MainChatScreen(teacherTool: tool, showDrawerHelp: true),
        ),
      ),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: tool.gradient),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: tool.gradient.last.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 6))
                ],
              ),
              child: Center(child: Text(tool.emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${tool.emoji} ${tool.label}",
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textPrimary)),
                  const SizedBox(height: 4),
                  Text(tool.description,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.5,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 24),
          ],
        ),
      ),
    );
  }

  /// ⭐ يقول للمعلّم **من أين يأتي المحتوى** — وهو أهم ما يميّز هذه الأدوات
  ///    عن أي مساعد عام: كلّها من نصّ درسه في الكتاب المقرَّر.
  Widget _sourceNote() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Text("📚", style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "كل ما تنتجه هذه الأدوات مبنيٌّ على نصّ الدرس في الكتاب المدرسي — "
              "لا من خارجه. اختر المادة والوحدة والدرس داخل الأداة.",
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
