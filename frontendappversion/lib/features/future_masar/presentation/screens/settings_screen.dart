import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/user_avatar.dart';
import '../../../chat/presentation/widgets/chat_dialogs.dart';
import '../../../../core/auth/user_repository.dart';
import '../../../../core/config/curriculum.dart';
import '../../../../core/session/role_home.dart';
import '../../../../core/config/app_links.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/settings/app_settings.dart';
import '../../../../core/theme/theme_controller.dart';
import '../../../../core/storage/chat_storage.dart';
import '../../../../core/widgets/screen_tip.dart';
import '../../data/demo_state.dart';
import '../widgets/demo_widgets.dart';
import '../../../banners/data/banner_repository.dart';
import '../../../quiz/data/quiz_storage.dart';
import '../../../saved/data/saved_storage.dart';
import '../../../saved/presentation/saved_screen.dart';
import '../../../scholarships/data/scholarship_chat_storage.dart';
import 'auth_screen.dart';

// ==========================================
// ⚙️ الإعدادات
// ==========================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final u = UserSession.I;
    final set = AppSettings.I;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Column(
            children: [
              const GlassBar(title: "الإعدادات ⚙️"),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
                  children: [
                    // الملف الشخصي
                    SoftCard(
                      child: Row(children: [
                        UserAvatar(radius: 28, editable: !u.isGuest, onChanged: () => setState(() {})),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(u.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(u.isGuest ? "حساب زائر — أنشئ حساباً لحفظ تقدمك" : u.email, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ])),
                        if (!u.isGuest)
                          IconButton(
                            tooltip: "تعديل الاسم",
                            onPressed: _editName,
                            icon: Icon(Icons.edit_rounded, color: AppColors.primary),
                          ),
                      ]),
                    ),
                    const SizedBox(height: 8),

                    // 🎭 نوع الحساب — **وللزائر أيضاً**: هو الطريق الوحيد
                    //    ليجرّب المعلّمُ قسمَه، فزرّ «جرّب كزائر» لا يمرّ
                    //    بشاشة اختيار الدور. واختياره ينتقل معه عند التسجيل.
                    _sectionTitle("نوع الحساب"),
                    _roleCard(u),

                    // 🎓 والصف يبقى للاثنين: الطالب يدرسه، والمعلّم يُدرّسه —
                    //    وأدوات المعلم تُبنى من دروس صفٍّ بعينه فلا غنى عنه.
                    _sectionTitle(u.isTeacher ? "الصف الذي أُدرّسه" : "الصف الدراسي"),
                    Row(children: List.generate(3, (i) {
                      final g = i + 1;
                      final sel = u.grade == g;
                      return Expanded(child: Padding(
                        padding: EdgeInsets.only(left: i < 2 ? 8 : 0),
                        child: InkWell(
                          onTap: () async { await u.setGrade(g); if (context.mounted) setState(() {}); },
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surfaceWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? Colors.transparent : AppColors.textSecondary.withValues(alpha: 0.1))),
                            child: Center(child: Text(switch (g) { 1 => "أول", 2 => "ثاني", _ => "ثالث" }, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textSecondary))),
                          ),
                        ),
                      ));
                    })),

                    if (Curriculum.hasTracks(u.grade)) ...[
                      _sectionTitle("المسار"),
                      Row(children: Curriculum.tracksFor(u.grade).asMap().entries.map((e) {
                        final t = e.value;
                        final sel = TrackLabel.fromKey(u.track) == t;
                        return Expanded(child: Padding(
                          padding: EdgeInsets.only(left: e.key == 0 ? 8 : 0),
                          child: InkWell(
                            onTap: () async { await u.setTrack(t.key); if (context.mounted) setState(() {}); },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: sel ? AppColors.secondary : AppColors.surfaceWhite,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: sel ? Colors.transparent : AppColors.textSecondary.withValues(alpha: 0.1)),
                              ),
                              child: Center(child: Text(t.label, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textSecondary))),
                            ),
                          ),
                        ));
                      }).toList()),
                    ],

                    _sectionTitle("المظهر"),
                    _themeCard(),
                    _fontSizeCard(),

                    // 🔇 حُذفت «القراءة الصوتية التلقائية»: لا نطق في التطبيق أصلاً،
                    //    ومفتاحٌ لا يفعل شيئاً يُفقد بقية الإعدادات مصداقيتها.
                    _sectionTitle("الإشعارات"),
                    _switchTile(Icons.school_rounded, "إشعارات المنح", set.notifScholarships,
                        (v) async { await set.setNotifScholarships(v); if (mounted) setState(() {}); }),
                    _switchTile(Icons.campaign_rounded, "إشعارات عامة", set.notifGeneral,
                        (v) async { await set.setNotifGeneral(v); if (mounted) setState(() {}); }),

                    _sectionTitle("الحساب والأمان"),
                    if (!u.isGuest)
                      _actionTile(Icons.lock_reset_rounded, "تغيير كلمة المرور", AppColors.textPrimary, _resetPassword),
                    if (u.isGuest)
                      _actionTile(Icons.person_add_alt_rounded, "أنشئ حساباً دائماً", AppColors.primary,
                          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()))),

                    _sectionTitle("البيانات والتخزين"),
                    // ☁️ لا زرّ استعادة بعد اليوم: `SyncService.onLogin` يستعيد
                    //    تلقائياً حين يكون الجهاز فارغاً (جهاز جديد أو إعادة تثبيت).
                    //    الزرّ كان يطلب من الطالب أن يفعل ما يفعله التطبيق وحده.
                    _storageCard(),
                    // 📌 المحفوظات تخصّ الاثنين — المعلّم يحفظ خطط دروسه أيضاً.
                    _actionTile(Icons.star_rounded, "المحفوظات", AppColors.textPrimary, () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => const SavedScreen()));
                      if (mounted) setState(() {});
                    }),
                    _actionTile(Icons.delete_sweep_rounded, "مسح المحادثات المحلية", AppColors.textPrimary, _confirmClearChats),
                    _actionTile(Icons.cleaning_services_rounded, "مسح الكاش المؤقّت", AppColors.textPrimary, _clearCache),
                    _actionTile(Icons.person_off_rounded, "حذف الحساب نهائياً", Colors.redAccent, () => _confirmDelete()),

                    _actionTile(Icons.lightbulb_outline_rounded, "أعد عرض تلميحات الشاشات", AppColors.textPrimary, () async {
                      await ScreenTip.resetAll(_tipScreens);
                      if (context.mounted) _snack("💡 ستظهر التلميحات مجدداً عند فتح الشاشات");
                    }),

                    _sectionTitle("المساعدة"),
                    _actionTile(Icons.chat_rounded, "تواصل مع الدعم (واتساب)", AppColors.textPrimary,
                        () => _open(AppLinks.supportWhatsapp)),
                    _actionTile(Icons.mail_outline_rounded, "راسلنا بالبريد", AppColors.textPrimary,
                        () => _open("mailto:${AppLinks.supportEmail}")),

                    _sectionTitle("عن مسار"),
                    _actionTile(Icons.info_outline_rounded, "الإصدار 2.0", AppColors.textPrimary, () {}),
                    _actionTile(Icons.support_agent_rounded, "المطور: م. محمد الديني", AppColors.textPrimary,
                        () => ChatDialogs.showDeveloperInfo(context)),
                    // ⚠️ الرابط الفارغ لا يُعرض زرّه: زرٌّ لا يفتح شيئاً يبدو عطلاً.
                    if (AppLinks.has(AppLinks.privacyPolicy))
                      _actionTile(Icons.privacy_tip_rounded, "سياسة الخصوصية", AppColors.textPrimary,
                          () => _open(AppLinks.privacyPolicy)),
                    if (AppLinks.has(AppLinks.terms))
                      _actionTile(Icons.gavel_rounded, "شروط الاستخدام", AppColors.textPrimary,
                          () => _open(AppLinks.terms)),

                    const SizedBox(height: 12),
                    _actionTile(Icons.logout_rounded, "تسجيل الخروج", Colors.redAccent, () async {
                      DemoState.I.signOut();
                      await UserSession.I.signOut();
                      if (!context.mounted) return;
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (r) => false);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// شاشات التلميحات — قائمة واحدة تُستعمل في إعادة العرض وفي حذف الحساب،
  /// فلا تُنسى شاشةٌ في أحدهما.
  static const List<String> _tipScreens = [
    "home", "chat", "education", "scholarships", "quiz", "services", "analysis",
  ];

  // ══════════════ بطاقات ══════════════

  /// 🌗 ثلاث حالات لا مفتاح: «حسب النظام» هو ما يتوقّعه مستخدم الهاتف اليوم،
  /// وغيابه يجبره على تبديل التطبيق يدوياً كلما تبدّل جهازه ليلاً.
  Widget _themeCard() {
    const options = {
      AppThemeMode.system: (Icons.brightness_auto_rounded, "حسب النظام"),
      AppThemeMode.light: (Icons.light_mode_rounded, "فاتح"),
      AppThemeMode.dark: (Icons.dark_mode_rounded, "داكن"),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: options.entries.map((e) {
            final selected = ThemeController.I.mode == e.key;
            final (icon, label) = e.value;
            return Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  await ThemeController.I.setMode(e.key);
                  if (mounted) setState(() {});
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(children: [
                    Icon(icon,
                        size: 20,
                        color: selected ? Colors.white : AppColors.textSecondary),
                    const SizedBox(height: 6),
                    Text(label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: selected ? Colors.white : AppColors.textSecondary,
                        )),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// ⚙️ حجم خط الإجابة — مع **معاينة حيّة بالحجم نفسه**.
  /// بلا المعاينة يضبط الطالب رقماً مجرّداً ثم يخرج ليرى النتيجة ويعود.
  Widget _fontSizeCard() {
    final set = AppSettings.I;
    return SoftCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.format_size_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text("حجم خط الإجابات",
              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const Spacer(),
          Text("${set.answerFontSize.round()}",
              style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary)),
        ]),
        Slider(
          min: AppSettings.minFont,
          max: AppSettings.maxFont,
          divisions: (AppSettings.maxFont - AppSettings.minFont).round(),
          value: set.answerFontSize,
          activeColor: AppColors.primary,
          inactiveColor: AppColors.softSurface,
          onChanged: (v) async {
            await set.setAnswerFontSize(v);
            if (mounted) setState(() {});
          },
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.softSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            "هكذا ستظهر إجابات مسار لك.",
            style: TextStyle(
              fontSize: set.answerFontSize,
              height: 1.6,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ]),
    );
  }

  // ══════════════ 🎭 نوع الحساب ══════════════

  /// بطاقة تبديل الدور — زرّان ووصفٌ صريح لما سيحدث.
  ///
  /// ⭐ **الوصف جزءٌ من الميزة لا زينة**: من يقرأ «معلّم» بلا شرحٍ يظنّ أنه
  ///    سيفقد محادثاته، فلا يجرّب. والحقيقة أن شيئاً لا يُمسح — والقول
  ///    الصريح بها هو ما يجعل الخيار قابلاً للاستعمال أصلاً.
  Widget _roleCard(UserSession u) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              _roleChip("🎓", "طالب", AppRole.student, u.role),
              const SizedBox(width: 10),
              _roleChip("👨‍🏫", "معلّم", AppRole.teacher, u.role),
            ]),
            const SizedBox(height: 10),
            Text(
              u.isTeacher
                  ? "👨‍🏫 تظهر لك أدوات المعلم فقط — خطط الدروس والواجبات والتبسيط."
                  : "🎓 تظهر لك واجهات الطالب — الشرح والاختبارات وتحليل المستوى والمنح.",
              style: TextStyle(
                  fontSize: 11.5,
                  height: 1.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roleChip(String emoji, String label, String value, String current) {
    final sel = current == value;
    return Expanded(
      child: InkWell(
        onTap: sel ? null : () => _confirmRoleChange(value, label),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? AppColors.primary : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: sel
                    ? Colors.transparent
                    : AppColors.textSecondary.withValues(alpha: 0.1)),
          ),
          child: Center(
            child: Text("$emoji  $label",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: sel ? Colors.white : AppColors.textSecondary)),
          ),
        ),
      ),
    );
  }

  /// ⚠️ **تأكيدٌ قبل التبديل** لأنه يبدّل التطبيق كلَّه في لحظة: من ضغط
  ///    بالخطأ يجد واجهةً لا يعرفها ويظنّ التطبيق تعطّل.
  Future<void> _confirmRoleChange(String value, String label) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("التحوّل إلى «$label»",
            style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
          value == AppRole.teacher
              ? "ستظهر لك أدوات المعلم فقط، وتُخفى واجهات الطالب.\n\n"
                  "✅ لا يُحذف شيء: محادثاتك ونتائجك ومحفوظاتك تبقى محفوظة، "
                  "وتعود كما هي إذا رجعت «طالباً»."
              : "ستعود إليك واجهات الطالب كاملةً بإحصائياتك وسجلّك كما تركته.\n\n"
                  "✅ ومحادثات أدوات المعلم تبقى محفوظة أيضاً.",
          style: TextStyle(fontSize: 13, height: 1.7, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text("إلغاء", style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("تحويل", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final error = await UserSession.I.setRole(value);
    if (!mounted) return;
    if (error != null) {
      _snack("⚠️ $error");
      return;
    }
    // 🎭 ومكدّس الشاشات يُعاد بناؤه على بيت الدور الجديد — وإلا بقي المعلّم
    //    واقفاً على إعدادات فُتحت من رئيسية الطالب، ويعود إليها بزرّ الرجوع.
    RoleHome.reset(context);
  }

  /// 📊 ما يشغله الحساب على هذا الجهاز — رقمٌ يسبق زرّ المسح، فلا يمسح
  /// الطالب في الفراغ ولا يتردّد وهو لا يدري ما لديه.
  Widget _storageCard() {
    final uid = UserSession.I.uid;
    // 🎓 أرقام **الصف الحالي** — لا مجموع السنوات الثلاث. الطالب يقرؤها
    //    ليقرّر المسح، فرقمٌ يشمل صفوفاً لا يراها يجعل قراره في العمى.
    final scope = UserSession.I.scope;
    final chats = ChatStorage.getAllConversations(uid, scope: scope).length;
    final quizzes = QuizStorage.all(uid, scope: scope).length;
    final saved = SavedStorage.count(uid, scope: scope);
    final schChats = SchChatStorage.all(uid).length;

    // 👨‍🏫 المعلّم لا اختبارات له ولا شات منح — وعرضُ صفرٍ دائمٍ في خانتين
    //    يجعل البطاقة تبدو معطوبة لا مختصرة.
    final isTeacher = UserSession.I.isTeacher;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        child: Row(children: [
          _stat("$chats", "محادثة"),
          if (!isTeacher) _stat("$schChats", "شات منح"),
          if (!isTeacher) _stat("$quizzes", "اختبار"),
          _stat("$saved", "محفوظ"),
        ]),
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
        ]),
      );

  // ══════════════ أفعال ══════════════

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) _snack("⚠️ تعذّر فتح الرابط على هذا الجهاز.");
    }
  }

  Future<void> _editName() async {
    final controller = TextEditingController(text: UserSession.I.name);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("تعديل الاسم",
            style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: "اسمك كما يظهر في التطبيق"),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text("إلغاء", style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text("حفظ", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (value == null) return;
    final error = await UserSession.I.setName(value);
    if (!mounted) return;
    setState(() {});
    _snack(error ?? "✅ تم تحديث اسمك");
  }

  Future<void> _resetPassword() async {
    final error = await UserSession.I.sendPasswordReset();
    if (!mounted) return;
    _snack(error ?? "📧 أُرسل رابط تغيير كلمة المرور إلى ${UserSession.I.email}");
  }

  /// 🧹 يمسح ما يُعاد جلبه من الخادم وحده — لا شيء يخصّ الطالب.
  /// مفيدٌ حين يعلق محتوى قديم بعد تحديث من اللوحة.
  Future<void> _clearCache() async {
    final p = await SharedPreferences.getInstance();
    for (final k in p.getKeys().toList()) {
      if (k.startsWith('banners_') || k.startsWith('scholarships_')) {
        await p.remove(k);
      }
    }
    await BannerRepository.I.load();
    if (!mounted) return;
    _snack("🧹 مُسح الكاش — سيُجلب المحتوى من جديد");
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 18, 6, 10),
        child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
      );

  Widget _switchTile(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13.5))),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
        ]),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13.5))),
            Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 22),
          ]),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text("حذف الحساب؟", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent)),
      content: Text("سيُحذف نهائياً: حسابك وبريدك · محادثاتك ومحادثات المنح · نتائج اختباراتك · محفوظاتك · صورتك — من هذا الجهاز ومن السحابة معاً. لا يمكن التراجع.",
          style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
        TextButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final uid = UserSession.I.uid; // يُلتقط قبل الحذف — بعده يصير فارغاً
            final error = await UserSession.I.deleteAccount();
            if (!mounted) return;
            if (error != null) {
              _snack("⚠️ $error");
              return;
            }
            // 🧹 **كل** مخازن هذا الحساب على الجهاز — لا محادثاته وحدها.
            //    نسيانُ مخزنٍ يعني بقاء بيانات طالبٍ حذف حسابه على جهازٍ
            //    قد يستعمله غيره، وهذا أسوأ من عدم الحذف: وعدٌ لم يُنفَّذ.
            await ChatStorage.clearForOwner(uid);
            await SchChatStorage.clearForOwner(uid);
            await QuizStorage.clearForOwner(uid);
            await SavedStorage.clear(uid);
            await AppSettings.I.resetAll();
            await ScreenTip.resetAll(_tipScreens);
            DemoState.I.signOut();
            if (!mounted) return;
            Navigator.pushAndRemoveUntil(
                context, MaterialPageRoute(builder: (_) => const AuthScreen()), (r) => false);
          },
          child: const Text("حذف", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
        ),
      ],
    ));
  }

  void _confirmClearChats() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("مسح المحادثات", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        content: Text("سيتم حذف محادثات هذا الحساب على هذا الجهاز. لا يمكن التراجع.",
            style: TextStyle(color: AppColors.textSecondary, height: 1.6, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: TextStyle(color: AppColors.textSecondary))),
          TextButton(
            onPressed: () async {
              // 👤 محادثات هذا الحساب فقط — حساب آخر على الجهاز لا يُمَس.
              final n = await ChatStorage.clearForOwner(UserSession.I.uid);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _snack("🗑️ مُسحت $n محادثة من هذا الحساب");
            },
            child: const Text("مسح", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
}
