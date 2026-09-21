import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/config/curriculum.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../../../core/widgets/screen_tip.dart';
import '../../../future_masar/presentation/screens/auth_screen.dart';
import '../../../instructions/presentation/instructions_dialog.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/chat_input_area.dart';
import '../widgets/chat_list_view.dart';
import '../widgets/session_settings_panel.dart';
import '../widgets/mode_suggestions.dart';
import '../../../teacher/data/teacher_tool.dart';
import '../../data/models/chat_suggestion.dart';
import '../../../teacher/presentation/widgets/teacher_suggestion_chips.dart';
import '../../../teacher/presentation/widgets/teacher_tool_bar.dart';

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

  /// 👨‍🏫 **الأداةُ التي بطاقتُها مفتوحة** — `null` يعني «لا بطاقة».
  ///
  /// 🎨 الإطار ٢ من `design/09-teacher` يعرض الشاشة **بلا شريحةٍ مختارة
  ///    وبلا بطاقة**: تلك حالةُ «اسأل المساعد» — محادثةٌ مفتوحةٌ لا تحتاج
  ///    إعداداً. فالشريطُ يختار **أيَّ بطاقةٍ تُفتح**، والأداةُ العاملةُ
  ///    في المتحكّم هي المفتوحةُ أو «اسأل» حين لا شيءَ مفتوح.
  TeacherTool? _openTool;

  @override
  void initState() {
    super.initState();
    _openTool = widget.teacherTool == TeacherTool.ask ? null : widget.teacherTool;
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
    _c.onVoiceNotice = (msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    };
    // 🎟️ انتهت الحصة: للزائر دعوة تسجيل بزر مباشر، وللطالب موعد التجديد.
    _c.onQuotaExceeded = (isGuest) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isGuest
                ? "🎁 انتهت أسئلتك التجريبية — سجّل مجاناً وتابع."
                : "🎟️ حدّك اليومي انتهى — يتجدّد بعد منتصف الليل.",
            style: const TextStyle(
              fontFamily: 'Cairo',
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: isGuest ? AppColors.primary : Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          action: isGuest
              ? SnackBarAction(
                  label: "سجّل الآن",
                  textColor: Colors.white,
                  onPressed: () => Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const AuthScreen()),
                    (r) => false,
                  ),
                )
              : null,
        ),
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
  }

  /// 🧰 **لمسةُ شريحةٍ في شريط الأدوات.**
  ///
  /// اللمسُ على المفتوحة يطويها (فتعود الشاشةُ إلى حالة الإطار ٢)،
  /// وعلى غيرها يفتحها ويبدّل الأداةَ العاملة. و[ChatController.setTeacherTool]
  /// هو من يبدّل سجلَّ المحادثات — لا شيءَ من ذلك مكتوبٌ هنا.
  void _onToolTap(TeacherTool tool) {
    // ⌨️ الكيبورد ينزل: البطاقةُ تفتح تحته فلا يُرى منها شيء.
    FocusScope.of(context).unfocus();
    // 🔽 **لمسةٌ على المفتوحة = طيُّ بطاقتها وحدها.**
    //
    // 🔴 ولا تُبدَّل الأداةُ هنا إطلاقاً: `setTeacherTool` تفتح محادثةً
    //    جديدة، فطيُّ البطاقةِ بعد توليد خطةٍ كان سيمحو الخطةَ من الشاشة.
    //    الشريحةُ المضيئة تعني «بطاقتي مفتوحة» لا «أنا العاملة».
    if (_openTool == tool) {
      setState(() => _openTool = null);
      return;
    }
    setState(() => _openTool = tool);
    _c.setTeacherTool(tool);
    // 💡 دليلُ الأداة عند أول فتحٍ لها — نفسُ سلوك بطاقات البوابة قبلها
    //    (`showDrawerHelp: true`)، و`showTeacher` تحرسه بمفتاحٍ لكل أداة
    //    فلا يتكرّر.
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
      InstructionsDialog.showTeacher(context, tool.id, forceShow: force);
      return;
    }
    InstructionsDialog.showIfNeeded(
      context,
      _c.selectedSubject,
      grade: _c.grade,
      track: _c.track.key,
      forceShow: force,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _c.dispose();
    super.dispose();
  }

  // ========== آثار الواجهة (Snackbars) ==========
  void _showDataErrorSnackBar(String message) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(PI.wifiSlash.regular, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'Cairo',
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.redAccent.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _showStopConfirmation() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "⏹️ تم إيقاف الإجابة",
          style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.orange.shade700,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showBusyWarning() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "⏳ يرجى انتظار الرد الحالي أو إيقافه أولاً.",
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.blue.shade600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// 📄 وضعُ الصفحات بلا اختيار — **الصمت هنا يبدو عطلاً**: الطالب يضغط
  ///    الإرسال فلا يحدث شيء ولا يعرف لماذا. (طلب المالك 2026-09-09)
  void _showPagesRequired() {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            "اختر الصفحات أولاً من إعدادات الجلسة 📄",
            style: TextStyle(fontFamily: 'Cairo'),
          ),
          backgroundColor: Colors.orange.shade600,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: "افتح",
            textColor: Colors.white,
            onPressed: () => _c.update(() => _c.showSettingsPanel = true),
          ),
        ),
      );
  }

  void _showEmptyWarning() {
    if (!mounted) return;
    // 📄 في وضع الصفحات العائقُ ليس النصّ بل الاختيار — و«اكتب سؤالك أولاً»
    //    تُرسل الطالب يكتب ثم يُرفض ثانيةً. فنقول له ما يمنعه فعلاً.
    if (_c.canPickPages && _c.selectedPages.isEmpty) {
      _showPagesRequired();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          "اكتب سؤالك أولاً ✍️",
          style: TextStyle(fontFamily: 'Cairo'),
        ),
        backgroundColor: Colors.orange.shade600,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
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
              final bool keyboardOpen =
                  MediaQuery.viewInsetsOf(context).bottom > 0;
              // 🧰 بطاقةُ المعلّم تتبع شريطَ الأدوات لا `showSettingsPanel`:
              //    لا شريحةَ مفتوحة ⇒ لا بطاقة (الإطار ٢ من التصميم).
              //
              // 🔴 **ولا تُطوى مع الكيبورد** بخلاف بطاقة الطالب: فيها
              //    حقلُ «اكتب المفهوم أو المصطلح» — فطيُّها عند فتح
              //    الكيبورد يسحب الحقلَ من تحت الإصبع فيُكتب في الهواء.
              //    رأيتُها في المحاكي: لمستُ الحقلَ فاختفت البطاقةُ كلُّها.
              final bool showPanel = !_c.isTeacher || _openTool != null;
              return Scaffold(
                key: _scaffoldKey,
                backgroundColor: AppColors.bgLight,
                drawer: ChatDrawer(
                    controller: _c, isHome: widget.isTeacherHome),
                body: Stack(
                  children: [
                    // 🌈 **خلفيّةُ المحادثة ليست بيضاء** (ملاحظة المالك).
                    //    قِستُ عمودَ التصدير: أبيضُ في الأعلى يزرقّ حتى ذروةٍ
                    //    عند ثلثي الشاشة ثم يرمدّ في القاع — تدرّجٌ رأسيٌّ
                    //    يعمّ الشاشة، لا قرصٌ صغيرٌ في زاوية.
                    // 🤍 **وقسمُ المعلم أبيضُ لا متدرّج**: قِستُ عمودَ
                    //    تصديره فما تغيّر لونٌ واحد من أعلى الشاشة إلى
                    //    أسفلها — بخلاف قسم التعليم. تصميمان لا واحد.
                    if (!_c.isTeacher)
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
                        // 🧰 **شريطُ أدوات المعلم** — y=138 في التصميم،
                        //    أي على بُعد 6 من أسفل الشريط العلويّ، ثم 23
                        //    قبل البطاقة. والقياسان من التصدير.
                        if (_c.isTeacher) ...[
                          const SizedBox(height: 6),
                          TeacherToolBar(open: _openTool, onTap: _onToolTap),
                          const SizedBox(height: 23),
                        ],
                        Expanded(
                          child: Stack(
                            children: [
                              // 💬 **القائمة تمتدّ تحت البطاقة كاملةً** —
                              //    لا في نافذةٍ تحتها. وحشوتُها العلويّة
                              //    بمقدار ارتفاع البطاقة الحاليّ، فلا يختفي
                              //    شيءٌ خلفها ولا ينشأ فاصلٌ بينهما، والنصُّ
                              //    يمرّ تحتها عند التمرير.
                              Positioned.fill(
                                child: ChatListView(
                                  controller: _c,
                                  bottomExtra: bottomExtra,
                                  topExtra: showPanel ? _panelHeight + 10 : 0,
                                  followUpsBuilder: (items) => _FollowUps(
                                    items: items,
                                    onTap: _c.applySuggestion,
                                  ),
                                ),
                              ),
                              // 🃏 **بطاقةُ الجلسة مثبّتةٌ فوق المحادثة**
                              //    (قرار المالك: «تكون قدّامي أقدر أعدّلها
                              //    في أي وقت»). لا تُمرَّر مع الرسائل ولا
                              //    تطير مع أوّل ردّ.
                              if (showPanel)
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
                                        SessionSettingsPanel(
                                          controller: _c,
                                          keyboardOpen: keyboardOpen,
                                          // 📖 بعد التوليد تُطوى البطاقة:
                                          //    خطةُ درسٍ في ثلاثِ شاشاتٍ
                                          //    خلفَ بطاقةٍ بارتفاع 300
                                          //    ليست نتيجةً تُقرأ.
                                          onTeacherGenerated: () =>
                                              setState(() => _openTool = null),
                                        ),
                                        // 📖 **زرُّ الطلب المخزون** — «اشرح
                                        //    لي» أو «لخّص لي». وهو في المتحكّم
                                        //    اقتراحٌ عليه `primary`: لا نداءَ
                                        //    جديد ولا نصَّ مكتوبٌ هنا.
                                        if (_primary != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 10),
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
                        // 👨‍🏫 شرائح متابعة أداة المعلم · 💡 واقتراحات الطالب
                        //
                        // 📌 **شريطُ الشرائح للبداية وحدها** (قرار المالك):
                        //    ما دامت المحادثة فارغةً فالطالب لا يعرف ماذا
                        //    يطلب — فتُعرض له. وبعد أول ردٍّ تنتقل الاقتراحاتُ
                        //    إلى **ذيل الردّ نفسه** أسهماً، فلا يزدحم أسفلُ
                        //    الشاشة بالشرائح والصفحات والحقل معاً.
                        if (_c.isTeacher)
                          TeacherSuggestionChips(controller: _c)
                        else if (_c.messages.isEmpty)
                          ModeSuggestions(controller: _c),
                        const SizedBox(height: 8),
                        ChatInputArea(
                          controller: _c,
                          onEmptyWarning: _showEmptyWarning,
                          keyboardOpen: keyboardOpen,
                        ),
                      ],
                    ),
                    // 💡 تلميح أول زيارة (يظهر مرة واحدة ويختفي تلقائياً)
                    ScreenTip(
                      screenId: _c.isTeacher ? "teacher_chat" : "chat",
                      text: _c.isTeacher
                          ? "اختر أداةً من الشريط فوق، ثم المادة والوحدة والدرس في بطاقتها، ثم اضغط زرّ التوليد — وناقش النتيجة بعدها."
                          : "اختر المادة من القائمة ☰، وحدّد الوضع والدرس من «إعدادات الجلسة» في الأعلى، ثم اكتب سؤالك.",
                      autoHideAfter: const Duration(seconds: 11),
                      anchorTop: true,
                      topOffset: 100,
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
              backgroundColor: AppColors.primary,
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
                      Icon(PI.arrowUpLeft.bold,
                          size: 15, color: AppColors.primary),
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
  const _AutoHideScrollButton(
      {required this.controller, required this.streaming});

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
            color: streaming ? AppColors.primary : AppColors.surfaceWhite,
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
