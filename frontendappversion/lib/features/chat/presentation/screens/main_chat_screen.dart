import 'package:flutter/material.dart';

import '../../../../core/config/curriculum.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/screen_tip.dart';
import '../../../future_masar/presentation/screens/auth_screen.dart';
import '../../../instructions/presentation/instructions_dialog.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/chat_input_area.dart';
import '../widgets/chat_list_view.dart';
import '../widgets/session_settings_panel.dart';
import '../../../teacher/data/teacher_tool.dart';
import '../../../teacher/presentation/widgets/teacher_suggestion_chips.dart';

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

  const MainChatScreen({
    super.key,
    this.showDrawerHelp = false,
    this.openSubject,
    this.openUnit,
    this.openLesson,
    this.openMode,
    this.teacherTool,
  });
  @override
  State<MainChatScreen> createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen> with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ChatController _c;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..forward();

    _c = ChatController();

    // ربط آثار الواجهة (Snackbars / الأنيميشن / التعليمات)
    _c.onShowDataError = _showDataErrorSnackBar;
    _c.onShowStopConfirmation = _showStopConfirmation;
    _c.onShowBusyWarning = _showBusyWarning;
    _c.onShowPagesRequired = _showPagesRequired;
    _c.onVoiceNotice = (msg) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    };
    // 🎟️ انتهت الحصة: للزائر دعوة تسجيل بزر مباشر، وللطالب موعد التجديد.
    _c.onQuotaExceeded = (isGuest) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          isGuest ? "🎁 انتهت أسئلتك التجريبية — سجّل مجاناً وتابع." : "🎟️ حدّك اليومي انتهى — يتجدّد بعد منتصف الليل.",
          style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold),
        ),
        backgroundColor: isGuest ? AppColors.primary : Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
      ));
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

  /// 💡 التعليمات — وهنا **فرقٌ مقصود** عن قسم التعليم (طلب المالك):
  ///    تعليمات المعلم مربوطة بـ**الأداة** لا بالمادة، فتظهر في كل المواد
  ///    بلا استثناء. (في قسم التعليم لكل مادة تعليماتها، ومادةٌ بلا تعليمات
  ///    تعرض رسالة «قيد الإعداد».)
  void _showInstructions({bool force = false}) {
    final tool = widget.teacherTool;
    if (tool != null) {
      InstructionsDialog.showTeacher(context, tool.id, forceShow: force);
      return;
    }
    InstructionsDialog.showIfNeeded(context, _c.selectedSubject,
        grade: _c.grade, track: _c.track.key, forceShow: force);
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
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(message, style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
          backgroundColor: Colors.redAccent.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 3),
        ),
      );
    });
  }

  void _showStopConfirmation() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("⏹️ تم إيقاف الإجابة", style: TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
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
        content: Text("⏳ يرجى انتظار الرد الحالي أو إيقافه أولاً.", style: TextStyle(fontFamily: 'Cairo')),
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
          content: Text("اختر الصفحات أولاً من إعدادات الجلسة 📄",
              style: TextStyle(fontFamily: 'Cairo')),
          backgroundColor: Colors.orange.shade600,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: "افتح",
            textColor: Colors.white,
            onPressed: () =>
                _c.update(() => _c.showSettingsPanel = true),
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
        content: Text("اكتب سؤالك أولاً ✍️", style: TextStyle(fontFamily: 'Cairo')),
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
        final bool showControls = _c.sessionActive && _c.selectedMode == "وزاري";
        final bool showMathButton = _c.selectedSubject == "رياضيات" && _c.mathMode == "شرح";
        double bottomExtra = 0;
        if (showControls) bottomExtra += 74; // زرّا «أكمل» و«إيقاف»
        if (showMathButton) {
          bottomExtra += 90; // زر «ابدأ الشرح الذكي»
          if (_c.selectedLesson.isEmpty) bottomExtra += 84; // تنبيه اختيار الدرس
        }

        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.bgLight,
          drawer: ChatDrawer(controller: _c),
          extendBodyBehindAppBar: true,
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(90 + MediaQuery.of(context).padding.top),
            child: ChatGlassAppBar(
              controller: _c,
              onMenu: () => _scaffoldKey.currentState?.openDrawer(),
              onHelp: () => _showInstructions(force: true),
            ),
          ),
          body: Stack(
            children: [
              // قائمة المحادثة (تملأ الشاشة)
              Positioned.fill(child: ChatListView(controller: _c, bottomExtra: bottomExtra)),

              // ══════════════════════════════════════════════════
              // 🔽 «انزل للأسفل» — لا يظهر إلا حين يلزم
              // ══════════════════════════════════════════════════
              // 📌 الشاشة **لا تتحرك** حين يصعد الطالب ليقرأ (قرار المالك).
              //    ولذلك يلزمه طريقٌ صريحٌ للعودة، وإلا وجد نفسه يمرّر
              //    يدوياً خلف نصٍّ ينمو أسرع منه.
              //
              // ⚠️ ويختفي حين يكون في الأسفل أصلاً: زرٌّ دائم يحجب سطراً من
              //    كل إجابة مقابل لا شيء.
              if (!_c.stick.isStuck && _c.messages.isNotEmpty)
                Positioned(
                  bottom: 150 + bottomExtra,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _ScrollToBottomButton(
                      streaming: _c.isStreaming,
                      onTap: _c.jumpToBottomAndStick,
                    ),
                  ),
                ),

              // خانة الكتابة وأزرار التحكم (مثبتة في الأسفل)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // أزرار التحكم (تظهر فقط في وضع الوزاري)
                    if (showControls) _buildControlButtons(),

                    // ✅ زر بدء الشرح (يظهر دائماً في وضع شرح الرياضيات)
                    if (showMathButton) _buildMathExplainButton(),

                    // 👨‍🏫 شرائح متابعة الأداة («أضف مثالاً من الحياة»…) —
                    //    تُرسل كرسالة متابعة حقيقية لا كنصّ ثابت.
                    if (_c.isTeacher) TeacherSuggestionChips(controller: _c),

                    // ✅ خانة الكتابة العائمة
                    ChatInputArea(controller: _c, onEmptyWarning: _showEmptyWarning),
                  ],
                ),
              ),

              // القائمة المنبثقة للإعدادات (فوق كل شيء)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                bottom: _c.showSettingsPanel ? 90 : -MediaQuery.of(context).size.height,
                left: 16,
                right: 16,
                child: SessionSettingsPanel(controller: _c),
              ),

              // 💡 تلميح أول زيارة (يظهر مرة واحدة ويختفي تلقائياً)
              ScreenTip(
                screenId: _c.isTeacher ? "teacher_chat" : "chat",
                text: _c.isTeacher
                    ? "اختر المادة من القائمة ☰، ثم الوحدة والدرس من زر الإعدادات ⚙️، ثم اضغط زرّ الأداة — وناقش النتيجة بعدها."
                    : "اختر المادة من القائمة الجانبية ☰، وحدّد الوضع والوحدة من زر الإعدادات، ثم اكتب سؤالك.",
                autoHideAfter: Duration(seconds: 11),
                // زاوية أعلى اليسار: أسفل الشاشة مزدحم بلوحة الإعدادات وخانة الكتابة.
                anchorTop: true,
                topOffset: 100,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ElevatedButton.icon(
            onPressed: () => _c.processRequest(customText: "كمل"),
            icon: Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text("أكمل"),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), elevation: 0),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: () => _c.processRequest(customText: "وقف"),
            icon: Icon(Icons.stop_rounded, size: 18),
            label: Text("إيقاف"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent.withValues(alpha: 0.1), foregroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), elevation: 0),
          ),
        ],
      ),
    );
  }

  Widget _buildMathExplainButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ✅ رسالة التنبيه إذا ما اختار درس
        if (_c.selectedLesson.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.info_rounded, color: Colors.orange, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text("اختر درس من القائمة أعلاه لبدء الشرح الذكي 📚", style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 12),

        // الزر الرئيسي
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: _c.selectedLesson.isNotEmpty ? AppColors.mainGradient : null,
              color: _c.selectedLesson.isEmpty ? AppColors.softSurface : null,
              borderRadius: BorderRadius.circular(24),
              boxShadow: _c.selectedLesson.isNotEmpty ? AppColors.softShadow : [],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))),
              onPressed: _c.selectedLesson.isNotEmpty
                  ? () {
                      _c.update(() => _c.isMathExplanationStarted = true);
                      _c.processRequest();
                    }
                  : null,
              child: Text(
                "🚀 ابدأ الشرح الذكي",
                style: TextStyle(fontSize: 18, color: _c.selectedLesson.isNotEmpty ? Colors.white : AppColors.textSecondary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ),
      ],
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
                color: AppColors.textPrimary.withValues(alpha: 0.06)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward_rounded,
                  size: 16,
                  color: streaming ? Colors.white : AppColors.textSecondary),
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
