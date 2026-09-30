import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/config/curriculum.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_dialog.dart';
import '../../../../core/widgets/masar_notice.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../../../core/widgets/tap_to_dismiss_keyboard.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/tour/masar_tour.dart';
import '../../../../core/tour/tour_anchor.dart';
import '../../../future_masar/presentation/tours/education_tour.dart';
import '../../../future_masar/presentation/tours/teacher_tour.dart';
import '../../../future_masar/presentation/screens/auth_screen.dart';
import '../../../instructions/presentation/instructions_dialog.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/chat_input_area.dart';
import '../../../../core/math_keyboard/math_keyboard.dart';
import '../widgets/chat_list_view.dart';
import '../widgets/session_settings_panel.dart';
import '../widgets/mode_suggestions.dart';
import '../../../teacher/data/teacher_tool.dart';
import '../../data/models/chat_suggestion.dart';

// ==========================================
// 🌌 الشاشة الرئيسية (شات بوت مسار)
// ==========================================
class MainChatScreen extends StatefulWidget {
  final bool showDrawerHelp;

  // 🔁 الحلقة الذهبية ([31§7]): من نتيجة اختبار إلى **شرح الدرس الضعيف نفسه**.
  //    تُفتح الشاشة على المادة والوحدة والدرس مباشرةً بلا بحث يدوي من الطالب.
  final String? openSubject;
  final String? openUnit;
  final String? openLesson;
  final String? openMode;

  /// 👨‍🏫 أداة المعلم — `null` يعني **قسم التعليم كما هو تماماً**.
  ///
  /// ⭐ شاشةٌ واحدة للقسمين عن قصد: طلب المالك أن يكون قسم المعلم «مطابقاً
  ///    تماماً» في المحادثة. وشاشةٌ ثانية منسوخة تعني ميزةً تُصلَح في إحداهما
  ///    وتبقى مكسورة في الأخرى — فالمطابقة هنا بالبناء لا بالنسخ.
  final TeacherTool? teacherTool;

  /// 🏠 **أهي بيتُ المعلّم؟** التصميم جعل الشاتَ نفسَه رئيسيةَ المعلّم
  ///    (`design/09-teacher`) — فلا شيءَ تحتها في المكدّس، ولا يُعرض
  ///    زرُّ الخروج في رأس القائمة الجانبية.
  final bool isTeacherHome;

  const MainChatScreen({
    super.key,
    this.showDrawerHelp = false,
    this.openSubject,
    this.openUnit,
    this.openLesson,
    this.openMode,
    this.teacherTool,
    this.isTeacherHome = false,
  });
  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ChatController _c;
  late AnimationController _fadeController;

  /// 📏 ارتفاعُ بطاقة إعدادات الجلسة كما هي الآن — مطويّةً أو مفتوحة.
  ///
  /// 🔴 **ولمَ يُقاس ولا يُكتب رقماً؟** البطاقةُ تتغيّر بالوضع والمادة
  ///    (شرائح · مستوى تلخيص · قوائم · صفحات)، فأيُّ رقمٍ ثابتٍ يصير
  ///    إمّا فجوةً فارغةً فوق المحادثة أو رسالةً مختفيةً خلف البطاقة.
  ///    قيمتُه الأولى تقديرُ الرأس المطويّ حتى يصل القياسُ الحقيقيّ.
  double _panelHeight = 52;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _c = ChatController();

    // ربط آثار الواجهة (Snackbars / الأنيميشن / التعليمات)
    _c.onShowDataError = _showDataErrorSnackBar;
    _c.onShowStopConfirmation = _showStopConfirmation;
    _c.onShowBusyWarning = _showBusyWarning;
    _c.onShowPagesRequired = _showPagesRequired;
    _c.onSendBlocked = _showSendBlocked;
    _c.onConfirmNewConversation = _confirmNewConversation;
    _c.onVoiceNotice = (msg) {
      if (!mounted) return;
      MasarNotice.info(context, msg, kind: NoticeKind.warning);
    };
    // 🎟️ انتهت الحصة: للزائر دعوة تسجيل بزر مباشر، وللطالب موعد التجديد.
    _c.onQuotaExceeded = (isGuest) {
      if (!mounted) return;
      if (!isGuest) {
        MasarNotice.info(
          context,
          "حدّك اليومي انتهى — يتجدّد بعد منتصف الليل.",
          title: "انتهى حدّ اليوم",
          kind: NoticeKind.warning,
        );
        return;
      }
      MasarNotice.info(
        context,
        "انتهت أسئلتك التجريبية — سجّل مجاناً وتابع.",
        title: "سجّل وتابع",
        icon: PD.graduationCap,
        action: "سجّل الآن",
        cancelLabel: "لاحقاً",
        onAction: () async {
          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const AuthScreen()),
            (r) => false,
          );
        },
      );
    };
    _c.onFadeReplay = () {
      _fadeController.reset();
      _fadeController.forward();
    };
    _c.onRequestInstructions = (subject) {
      // تأخير قصير: يمنع تصادم النافذة مع أنيميشن إغلاق القائمة الجانبية.
      Future.delayed(const Duration(milliseconds: 320), () {
        if (!mounted) return;
        _showInstructions();
      });
    };

    _c.init(
      openSubject: widget.openSubject,
      openUnit: widget.openUnit,
      openLesson: widget.openLesson,
      openMode: widget.openMode,
      teacher: widget.teacherTool,
    );

    // ✅ إظهار التعليمات مرة واحدة فقط في أول فتح
    if (widget.showDrawerHelp) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showInstructions());
    }
    _tour();
  }

  /// 🧰 **لمسةُ شريحة أداةٍ في «إعدادات الجلسة».**
  ///
  /// [ChatController.setTeacherTool] يبدّل سجلَّ المحادثات ويفتح محادثةً
  /// جديدة للأداة — لا شيءَ من ذلك مكتوبٌ هنا. ولمسةُ العاملةِ لا تفعل
  /// شيئاً (لا تمحو خطةً وُلّدت للتوّ).
  void _onToolTap(TeacherTool tool) {
    if (tool == _c.teacherTool) return;
    FocusScope.of(context).unfocus();
    _c.setTeacherTool(tool);
    // 💡 دليلُ الأداة عند أول فتحٍ لها — `showTeacher` تحرسه بمفتاحٍ لكل
    //    أداة فلا يتكرّر.
    _showInstructions();
  }

  /// 💡 التعليمات — وهنا **فرقٌ مقصود** عن قسم التعليم (طلب المالك):
  ///    تعليمات المعلم مربوطة بـ**الأداة** لا بالمادة، فتظهر في كل المواد
  ///    بلا استثناء. (في قسم التعليم لكل مادة تعليماتها، ومادةٌ بلا تعليمات
  ///    تعرض رسالة «قيد الإعداد».)
  void _showInstructions({bool force = false}) {
    // 🧰 **الأداةُ الحالية لا التي فُتحت بها الشاشة**: الشريطُ يبدّلها،
    //    فقراءةُ `widget` كانت ستعرض دليلَ أداةٍ غادرها المعلّم.
    final tool = _c.teacherTool;
    if (tool != null) {
      InstructionsDialog.showTeacher(
        context,
        tool.id,
        forceShow: force,
        onTour: () => _startTour(force: true),
      ).then((_) => _tour());
      return;
    }
    InstructionsDialog.showIfNeeded(
      context,
      _c.selectedSubject,
      grade: _c.grade,
      track: _c.track.key,
      forceShow: force,
      onTour: () => _startTour(force: true),
    ).then((_) => _tour());
  }

  // ══════════════════════════════════════════════════
  // 🤖 جولةُ الشرح — أوّلَ دخولٍ لقسم التعليم ([EducationTour])
  // ══════════════════════════════════════════════════
  // ⏱️ **بعد الدليل لا فوقه**: دليلُ المادة يُفتح أوّلَ مرّةٍ أيضاً، فالجولةُ
  //    تنتظر حتى تكون الشاشةُ هي الظاهرة ([ModalRoute.isCurrent]) — وتُعاد
  //    المحاولةُ عند إغلاق الدليل. و`Timer` يُلغى في `dispose` لا
  //    `Future.delayed` ([masar-testing-traps]).
  Timer? _tourTimer;

  void _tour() {
    _tourTimer?.cancel();
    _tourTimer = Timer(const Duration(milliseconds: 900), _startTour);
  }

  Future<void> _startTour({bool force = false}) async {
    if (!mounted) return;
    // 👨‍🏫 الشاشةُ واحدةٌ للقسمين، والجولةُ لكلٍّ منهما ([TeacherTour]).
    final teacher = _c.isTeacher;
    final tourId = teacher ? TeacherTour.id : EducationTour.id;
    if (!force && (ModalRoute.of(context)?.isCurrent != true)) return;
    if (!force && await MasarTour.seen(tourId)) return;
    if (!mounted) return;
    FocusScope.of(context).unfocus();

    // 🎭 ما يُعرض للتوضيح يُحفظ مرجعُه — ويُمحى بعد الجولة **إن بقي هو هو**
    //    (لو حمّل المتحكّمُ محادثةً حقيقيةً أثناءها فلا تُمسّ).
    final panelWasOpen = _c.showSettingsPanel;
    final demoReply = _c.messages.isEmpty;
    final demoChats = _c.conversations.isEmpty;
    List<Map<String, dynamic>>? shownMessages;
    List<dynamic>? shownChats;
    Future<void> settle(int ms) =>
        Future<void>.delayed(Duration(milliseconds: ms));

    Future<void> openPanel() async {
      _c.tourDemo = true;
      _c.setShowSettingsPanel(true);
      await settle(320);
    }

    // 💬 البطاقةُ تُطوى كي لا تغطّي الردّ — فهي تطفو فوق المحادثة.
    Future<void> showReply() async {
      _c.setShowSettingsPanel(false);
      if (_c.messages.isEmpty) {
        _c.messages = shownMessages = teacher
            ? TeacherTour.demoMessages(_c.selectedSubject)
            : EducationTour.demoMessages(_c.selectedSubject);
        _c.refresh();
      }
      await settle(520);
    }

    Future<void> openDrawer() async {
      if (_c.conversations.isEmpty) {
        final demo = EducationTour.demoConversations(
          subject: _c.selectedSubject,
          mode: _c.selectedMode,
          grade: _c.grade,
          track: _c.track.key,
          teacher: teacher,
        );
        _c.conversations = demo;
        shownChats = demo;
        _c.refresh();
      }
      _scaffoldKey.currentState?.openDrawer();
      await settle(420);
    }

    Future<void> closeDrawer() async {
      _scaffoldKey.currentState?.closeDrawer();
      await settle(320);
    }

    await MasarTour.maybeStart(
      context,
      id: tourId,
      force: force,
      steps: teacher
          ? TeacherTour.steps(
              guest: UserSession.I.isGuest,
              demoLesson: _c.v3LessonsUnits.isEmpty && !_c.capsLoading,
              demoReply: demoReply,
              demoChats: demoChats,
              openPanel: openPanel,
              showReply: showReply,
              openDrawer: openDrawer,
              closeDrawer: closeDrawer,
            )
          : EducationTour.steps(
              guest: UserSession.I.isGuest,
              wazari: _c.grade == 3,
              demoLesson: _c.lessonPickerEmpty,
              demoReply: demoReply,
              demoChats: demoChats,
              openPanel: openPanel,
              showReply: showReply,
              openDrawer: openDrawer,
              closeDrawer: closeDrawer,
            ),
    );
    if (!mounted) return;
    if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
      _scaffoldKey.currentState?.closeDrawer();
    }
    if (shownMessages != null && identical(_c.messages, shownMessages)) {
      _c.messages = <Map<String, dynamic>>[];
    }
    if (shownChats != null && identical(_c.conversations, shownChats)) {
      _c.conversations = [];
    }
    _c.tourDemo = false;
    _c.setShowSettingsPanel(panelWasOpen);
  }

  @override
  void dispose() {
    _tourTimer?.cancel();
    _fadeController.dispose();
    _c.dispose();
    super.dispose();
  }

  // ========== آثار الواجهة — رسالةُ وسط الشاشة ([MasarNotice]) ==========
  void _showDataErrorSnackBar(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      MasarNotice.info(
        context,
        message,
        title: "تعذّر الاتصال",
        kind: NoticeKind.error,
        icon: PD.wifiSlash,
      );
    });
  }

  void _showStopConfirmation() {
    if (!mounted) return;
    MasarNotice.toast(context, "أُوقفت الإجابة", kind: NoticeKind.info);
  }

  void _showBusyWarning() {
    if (!mounted) return;
    MasarNotice.info(
      context,
      "انتظر الرد الحالي حتى يكتمل، أو أوقفه أولاً.",
      title: "لحظة من فضلك",
    );
  }

  /// 📄 وضعُ الصفحات بلا اختيار — **الصمت هنا يبدو عطلاً**: الطالب يضغط
  ///    الإرسال فلا يحدث شيء ولا يعرف لماذا. (طلب المالك 2026-09-09)
  void _showPagesRequired() {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    MasarNotice.info(
      context,
      "اختر الصفحات أولاً من «إعدادات الجلسة».",
      title: "اختر الصفحات",
      icon: PD.filePdf,
      action: "افتح الإعدادات",
      onAction: () async => _c.update(() => _c.showSettingsPanel = true),
    );
  }

  /// 🚦 **ما ينقص قبل الإرسال** ([ChatController.sendBlocker]) — يُقال بعينه،
  ///    وتُفتح البطاقةُ حيث يُختار، ويُنزل الكيبورد كي تُرى كاملةً.
  void _showSendBlocked(String reason) {
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    _c.setShowSettingsPanel(true);
    MasarNotice.info(
      context,
      reason,
      title: "قبل أن تسأل",
      icon: PD.fadersHorizontal,
    );
  }

  /// 🔒 **«اخترتَ درساً جديداً — نفتح محادثةً جديدة؟»**
  ///    ([ChatController.onConfirmNewConversation]) — للقسمين.
  ///
  /// 🎨 بقالب حوارات التطبيق ([MasarDialog]) لا `AlertDialog`: مربّعُ
  ///    أيقونةٍ ملوّن وعنوانٌ ثم زرٌّ ممتلئ و«إلغاء» نصّاً — كحوار الحذف
  ///    والتسمية في التصميم. والرفضُ لا يمسّ شيئاً: القائمةُ تعود لقيمتها.
  Future<bool> _confirmNewConversation(ContextChange change) async {
    if (!mounted) return false;
    FocusScope.of(context).unfocus();
    final lesson = _c.isMathBranches && !_c.isTeacher
        ? _c.selectedLesson
        : _c.selectedV3Lesson;
    final pages = _c.conversationPages.join("، ");
    final (String title, String body) = switch (change) {
      ContextChange.lesson => (
        "اخترتَ درساً جديداً",
        lesson.isEmpty
            ? "هذه المحادثة عن درسٍ آخر."
            : "هذه المحادثة عن درس «$lesson».",
      ),
      ContextChange.unit => (
        "اخترتَ وحدةً جديدة",
        "هذه المحادثة عن وحدة «${_c.selectedUnit}».",
      ),
      ContextChange.pages => (
        "صفحةٌ من خارج هذه المحادثة",
        "هذه المحادثة عن الصفحات $pages — تستطيع إزالةَ صفحةٍ منها "
            "أو إعادتها، أمّا الصفحةُ الجديدة فمكانُها محادثةٌ جديدة.",
      ),
      ContextChange.contentMode => (
        "غيّرتَ مصدر المحتوى",
        "هذه المحادثة بدأت على مصدرٍ آخر (دروس/صفحات).",
      ),
    };
    var accepted = false;
    await showDialog<void>(
      context: context,
      builder: (_) => MasarDialog(
        icon: PD.chat,
        title: title,
        primaryLabel: "محادثة جديدة",
        cancelLabel: "ابقَ هنا",
        onPrimary: () async => accepted = true,
        child: Text(
          "$body\n\nكي يبقى الشرحُ مركّزاً ولا تختلطَ الدروس، الأفضلُ أن "
          "تفتح محادثةً جديدة — وتبقى هذه محفوظةً في القائمة.",
          style: TextStyle(
            fontSize: 13.5,
            height: 1.7,
            fontWeight: FontWeight.w600,
            color: AppColors.chipInk,
          ),
        ),
      ),
    );
    return accepted;
  }

  void _showEmptyWarning() {
    if (!mounted) return;
    // 🚦 البوّابةُ أولاً: ما ينقصُ اختيارٌ لا كتابة.
    final blocker = _c.sendBlocker;
    if (blocker != null) return _showSendBlocked(blocker);
    // 📄 في وضع الصفحات العائقُ ليس النصّ بل الاختيار — و«اكتب سؤالك أولاً»
    //    تُرسل الطالب يكتب ثم يُرفض ثانيةً. فنقول له ما يمنعه فعلاً.
    if (_c.canPickPages && _c.selectedPages.isEmpty) {
      _showPagesRequired();
      return;
    }
    MasarNotice.info(
      context,
      "اكتب سؤالك أولاً، أو أرفق صورة.",
      title: "الرسالة فارغة",
      icon: PD.notePencil,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // ما يظهر أسفل الشاشة فوق خانة الكتابة — تُحجز له مساحة في
        // نهاية قائمة الرسائل حتى لا تختفي آخر رسالة خلفه.
        final bool showControls =
            _c.sessionActive && _c.selectedMode == "وزاري";
        double bottomExtra = 0;
        if (showControls) bottomExtra += 74; // زرّا «أكمل» و«إيقاف»

        return ThemeScope(
          // ⌨️ **تُقرأ فوق الـ`Scaffold`**: هو يبتلع `viewInsets` السفليّ
          //    عن جسمه، فمن قرأها من داخله وجدها صفراً أبداً.
          builder: (context) => Builder(
            builder: (context) {
              // 🧮 كيبوردُ الرياضيات كيبوردٌ كذلك — لا `viewInsets` له لأنه
              //    ودجتٌ في الشاشة لا نافذةٌ من النظام.
              final bool mathKeyboard = _c.mathKeyboardOpen;
              final bool keyboardOpen =
                  MediaQuery.viewInsetsOf(context).bottom > 0 || mathKeyboard;
              return Scaffold(
                key: _scaffoldKey,
                backgroundColor: AppColors.bgLight,
                drawer: ChatDrawer(
                  controller: _c,
                  isHome: widget.isTeacherHome,
                ),
                body: Stack(
                  children: [
                    // 🌈 **خلفيّةُ المحادثة ليست بيضاء** (ملاحظة المالك).
                    //    قِستُ عمودَ التصدير: أبيضُ في الأعلى يزرقّ حتى ذروةٍ
                    //    عند ثلثي الشاشة ثم يرمدّ في القاع — تدرّجٌ رأسيٌّ
                    //    يعمّ الشاشة، لا قرصٌ صغيرٌ في زاوية.
                    // 🤍 **وقسمُ المعلم أبيضُ لا متدرّج**: قِستُ عمودَ
                    //    تصديره فما تغيّر لونٌ واحد من أعلى الشاشة إلى
                    //    أسفلها — بخلاف قسم التعليم. تصميمان لا واحد.
                    // 🌈 **وقسمُ المعلم مثلُه الآن** (قرار المالك ٢٠٢٦-٠٩-٢٤:
                    //    «ما في داعي تكون بيضاء — نفس التعليم ونفس المنح
                    //    بالأزرق المتموّج بالضبط»). كان أبيضَ كتصديره.
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppColors.chatBackdrop,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      children: [
                        ChatGlassAppBar(
                          controller: _c,
                          onMenu: () {
                            // ⌨️ الكيبورد ينزل قبل أن تنزلق القائمة:
                            //    وإلا فُتحت فوقه فلا يُرى منها إلا ثلثها.
                            FocusScope.of(context).unfocus();
                            _scaffoldKey.currentState?.openDrawer();
                          },
                          onHelp: () => _showInstructions(force: true),
                        ),
                        Expanded(
                          child: Stack(
                            children: [
                              // 💬 **القائمة تمتدّ تحت البطاقة كاملةً** —
                              //    لا في نافذةٍ تحتها. وحشوتُها العلويّة
                              //    بمقدار ارتفاع البطاقة الحاليّ، فلا يختفي
                              //    شيءٌ خلفها ولا ينشأ فاصلٌ بينهما، والنصُّ
                              //    يمرّ تحتها عند التمرير.
                              //
                              // ⌨️ **ونقرةٌ عليها تُنزل الكيبورد** كما في
                              //    ChatGPT — والسحبُ للتمرير لا يمسّه
                              //    ([TapToDismissKeyboard]). مشتركٌ للقسمين.
                              Positioned.fill(
                                child: TapToDismissKeyboard(
                                  child: ChatListView(
                                    controller: _c,
                                    bottomExtra: bottomExtra,
                                    topExtra: _panelHeight + 10,
                                    followUpsBuilder: (items) => _FollowUps(
                                      items: items,
                                      onTap: _c.applySuggestion,
                                    ),
                                  ),
                                ),
                              ),
                              // 🃏 **بطاقةُ الجلسة مثبّتةٌ فوق المحادثة**
                              //    (قرار المالك: «تكون قدّامي أقدر أعدّلها
                              //    في أي وقت»). لا تُمرَّر مع الرسائل ولا
                              //    تطير مع أوّل ردّ.
                              Positioned(
                                top: 0,
                                left: 24,
                                right: 24,
                                child: _MeasureHeight(
                                  onChange: (h) {
                                    if ((h - _panelHeight).abs() > 0.5) {
                                      setState(() => _panelHeight = h);
                                    }
                                  },
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // ⌨️ تُطوى لكيبورد **المحادثة** وحده
                                      //    ([ChatController.inputFocus]) —
                                      //    لا لكيبوردِ حقلٍ في البطاقة نفسِها.
                                      TourAnchor(
                                        id: EducationTour.panel,
                                        child: SessionSettingsPanel(
                                          controller: _c,
                                          keyboardOpen:
                                              keyboardOpen &&
                                              _c.chatInputFocused,
                                          onTeacherTool: _onToolTap,
                                        ),
                                      ),
                                      // 📖 **زرُّ الطلب المخزون** — «اشرح
                                      //    لي» أو «لخّص لي». وهو في المتحكّم
                                      //    اقتراحٌ عليه `primary`: لا نداءَ
                                      //    جديد ولا نصَّ مكتوبٌ هنا.
                                      if (_primary != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                          ),
                                          child: _PrimaryAction(
                                            label: _primary!.label,
                                            busy: _c.isBusy,
                                            onTap: () =>
                                                _c.applySuggestion(_primary!),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              // 🔽 «انزل للأسفل» — يظهر مع التمرير ويختفي
                              //    بعده. 📌 الشاشة **لا تتحرك** حين يصعد
                              //    الطالب ليقرأ (قرار المالك)، فيلزمه طريقٌ
                              //    صريحٌ للعودة — لكنه لا يجلس فوق النصّ
                              //    يحجبه ما دام يقرأ (ملاحظة المالك).
                              if (!_c.stick.isStuck && _c.messages.isNotEmpty)
                                Positioned(
                                  bottom: 12 + bottomExtra,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: _AutoHideScrollButton(
                                      controller: _c,
                                      streaming: _c.isStreaming,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // أزرار الوزاري (أكمل · إيقاف)
                        if (showControls) _buildControlButtons(),
                        // 💡 **شريطُ الاقتراحات للبداية وحدها — في القسمين**
                        //
                        // 📌 ما دامت المحادثة فارغةً فصاحبُها لا يعرف ماذا
                        //    يطلب — فتُعرض له فوق الحقل. وبعد أول ردٍّ تنتقل
                        //    الاقتراحاتُ إلى **ذيل الردّ نفسه** أسهماً، لجولتين
                        //    ثم تغيب ([ChatController.suggestions]). وقسمُ
                        //    المعلم مثلُه (قرار المالك ٢٠٢٦-٠٩-٢٤): كان شريطُه
                        //    فوق الحقل دائماً «يشيل مساحة كبيرة جداً».
                        //
                        // 🚦 **ولا اقتراحاتٍ قبل اكتمال الاختيار**: شريحةٌ
                        //    تُرسل ولا درسَ مختار تُرفض ([ChatController.sendBlocker]).
                        //
                        // 📷 **ومع صورةٍ مرفقة تغيب** (أمرُ المالك ٢٠٢٦-٠٩-٢٤:
                        //    «لما نرفع صورة الاقتراحات اللي فوق تروح… المنظر
                        //    يتشوّه») — والصورةُ نفسُها سؤالٌ فلا حاجةَ لاقتراح.
                        //    وشرائحُ الصفحات لا تُمسّ: هي في بطاقة الإعدادات.
                        //    كمساعد المنح حرفياً ([ScholarshipChatScreen]).
                        if (_c.messages.isEmpty &&
                            _c.selectionComplete &&
                            !_c.hasAttachments &&
                            !_c.isRecording)
                          TourAnchor(
                            id: EducationTour.suggest,
                            child: ModeSuggestions(controller: _c),
                          ),
                        const SizedBox(height: 8),
                        // ⌨️ فوق كيبورد الرياضيات لا حشوةَ لشريط المنزل:
                        //    الكيبوردُ تحته هو من يحجزها.
                        MediaQuery.removePadding(
                          context: context,
                          removeBottom: mathKeyboard,
                          child: ChatInputArea(
                            controller: _c,
                            onEmptyWarning: _showEmptyWarning,
                            keyboardOpen: keyboardOpen,
                          ),
                        ),
                        if (mathKeyboard)
                          MathKeyboard(
                            editor: _c.mathEditor,
                            onChanged: _c.refresh,
                            onSystemKeyboard: () => _c.setMathKeyboard(false),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// الاقتراحُ البارز (`primary`) إن وُجد — يُعرض زرّاً لا شريحة.
  ChatSuggestion? get _primary {
    for (final s in _c.suggestions) {
      if (s.primary) return s;
    }
    return null;
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () => _c.processRequest(customText: "كمل"),
            icon: Icon(PI.arrowLeft.bold, size: 18),
            label: Text("أكمل"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryFill,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => _c.processRequest(customText: "وقف"),
            icon: Icon(PI.stop.fill, size: 18),
            label: Text("إيقاف"),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorTint,
              foregroundColor: AppColors.error500,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 📏 يقيس ابنَه ويُبلّغ بارتفاعه بعد كل إطار
// ══════════════════════════════════════════════════
// 🎯 يُستعمل لبطاقة الجلسة الطافية: تُقاس ثم تُحجز لها حشوةٌ بمقدارها في
//    أعلى قائمة المحادثة — فلا فجوةَ ولا اختفاء.
//
// ⚠️ والتبليغُ **بعد** الإطار (`addPostFrameCallback`): القياسُ أثناء
//    البناء يستدعي `setState` وسطَ بناءٍ جارٍ فيسقط التطبيق. والمستدعي
//    يقارن قبل أن يُعيد البناء، وإلا دارت الحلقةُ بلا نهاية.
class _MeasureHeight extends StatefulWidget {
  const _MeasureHeight({required this.child, required this.onChange});

  final Widget child;
  final ValueChanged<double> onChange;

  @override
  State<_MeasureHeight> createState() => _MeasureHeightState();
}

class _MeasureHeightState extends State<_MeasureHeight> {
  final GlobalKey _key = GlobalKey();

  void _report(_) {
    final box = _key.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) widget.onChange(box.size.height);
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback(_report);
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

// ══════════════════════════════════════════════════
// ↗️ اقتراحاتُ المتابعة — أسهمٌ في ذيل الردّ
// ══════════════════════════════════════════════════
// 🎯 **من الرسالة نفسها لا من أسفل الشاشة** (قرار المالك): بعد أول ردٍّ
//    تنزل الاقتراحاتُ إلى ذيله صفوفاً، كلُّ صفٍّ سهمٌ ونصّ. وبهذا يبقى
//    أسفلُ الشاشة للكتابة وحدها، وتُقرأ الاقتراحاتُ في سياق ما تقترح عليه.
//
// 📜 **والنصوص من المتحكّم** لا مكتوبةً هنا: هي `suggestions` نفسُها التي
//    كانت تُعرض شرائح — تغيّر شكلُها لا مصدرُها ولا ما تفعله.
//
// ↖️ والسهم `ArrowUpLeft` لا `ArrowUpRight`: الواجهةُ عربيةٌ، والسهمُ
//    يشير إلى جهة الكتابة.
class _FollowUps extends StatelessWidget {
  const _FollowUps({required this.items, required this.onTap});

  final List<ChatSuggestion> items;
  final ValueChanged<ChatSuggestion> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, right: 6, left: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(height: 1, thickness: 1, color: AppColors.rowBorder),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => onTap(items[i]),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          items[i].label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.chipInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        PI.arrowUpLeft.bold,
                        size: 15,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 🔽 زرّ العودة إلى أسفل المحادثة — يظهر مع التمرير ويختفي بعده
// ══════════════════════════════════════════════════
// 🔴 **كان يجلس فوق النصّ ما دام الطالبُ صاعداً** — أي ما دام يقرأ
//    بالضبط (ملاحظة المالك: «لو نبقره الآن بيعطّل عليّ القراءة»).
//    فصار يُظهر نفسه عند كل حركةِ تمرير ويغيب بعد ثلاثِ ثوانٍ من السكون.
//
// ⏱️ والمؤقّتُ يُصفَّر مع كل حركة، فلا يومض بين تمريرتين متتاليتين.
//    وأثناء البثّ يبقى ظاهراً: هناك جديدٌ يُكتب في الأسفل يستحقّ أن يُرى.
class _AutoHideScrollButton extends StatefulWidget {
  const _AutoHideScrollButton({
    required this.controller,
    required this.streaming,
  });

  final ChatController controller;
  final bool streaming;

  @override
  State<_AutoHideScrollButton> createState() => _AutoHideScrollButtonState();
}

class _AutoHideScrollButtonState extends State<_AutoHideScrollButton> {
  static const Duration _linger = Duration(seconds: 3);

  Timer? _timer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    widget.controller.scrollController.addListener(_onScroll);
    _restart();
  }

  @override
  void dispose() {
    widget.controller.scrollController.removeListener(_onScroll);
    _timer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (!_visible) setState(() => _visible = true);
    _restart();
  }

  void _restart() {
    _timer?.cancel();
    _timer = Timer(_linger, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool show = _visible || widget.streaming;
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        opacity: show ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        child: _ScrollToBottomButton(
          streaming: widget.streaming,
          onTap: widget.controller.jumpToBottomAndStick,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 🔽 زرّ العودة إلى أسفل المحادثة
// ══════════════════════════════════════════════════
// ⭐ نصُّه يتغيّر بالحالة: أثناء البثّ يقول «الرد يُكتب…» فيعرف الطالب أن
//    في الأسفل جديداً يستحق النزول — لا مجرد نهاية قائمة.
class _ScrollToBottomButton extends StatelessWidget {
  const _ScrollToBottomButton({required this.streaming, required this.onTap});

  final bool streaming;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: streaming ? AppColors.primaryFill : AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppColors.softShadow,
            border: Border.all(
              color: AppColors.textPrimary.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                PI.arrowDown.bold,
                size: 16,
                color: streaming ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                streaming ? "الرد يُكتب…" : "انزل للأسفل",
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: streaming ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 📖 الزرّ البارز — 342×58 · r16 · `#0092FF`
// ══════════════════════════════════════════════════
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  final String label;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 58,
    child: ElevatedButton(
      onPressed: busy ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryFill,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primaryFill.withValues(alpha: 0.5),
        disabledForegroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
          ),
          const SizedBox(width: 8),
          // ✨ `Sparkle` **عادياً لا ممتلئاً** — في التصديرِ نجمةٌ كبيرة
          //    وأخرى صغيرة وحلقةٌ **مفرّغة**، والممتلئُ يصمِت الحلقة.
          //    وحجمُها 19: قِستُ عرضَها في التصدير 37 بكسلة عند 2×.
          Icon(PI.sparkle.regular, size: 19),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════
// 🌫️ هالة الخلفية — قرصٌ متدرّج خافت
// ══════════════════════════════════════════════════
/// في التصميم `Frame 2147224832` (565×468 · r88) بتدرّجٍ شفيف خلف المحادثة.
/// يعطي الشاشةَ عمقاً بلا صورةٍ ولا وزن.
