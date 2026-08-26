import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../instructions/presentation/instructions_dialog.dart';
import '../controllers/chat_controller.dart';
import '../widgets/chat_app_bar.dart';
import '../widgets/chat_drawer.dart';
import '../widgets/chat_input_area.dart';
import '../widgets/chat_list_view.dart';
import '../widgets/session_settings_panel.dart';

// ==========================================
// 🌌 الشاشة الرئيسية (شات بوت مسار)
// ==========================================
class MainChatScreen extends StatefulWidget {
  final bool showDrawerHelp;
  const MainChatScreen({super.key, this.showDrawerHelp = false});
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
    _c.onFadeReplay = () {
      _fadeController.reset();
      _fadeController.forward();
    };
    _c.onRequestInstructions = (subject) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        InstructionsDialog.showIfNeeded(context, subject);
      });
    };

    _c.init();

    // ✅ إظهار التعليمات مرة واحدة فقط في أول فتح
    if (widget.showDrawerHelp) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        InstructionsDialog.showIfNeeded(context, _c.selectedSubject);
      });
    }
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

  void _showEmptyWarning() {
    if (!mounted) return;
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
              onHelp: () => InstructionsDialog.showIfNeeded(context, _c.selectedSubject, forceShow: true),
            ),
          ),
          body: Stack(
            children: [
              // قائمة المحادثة (تملأ الشاشة)
              Positioned.fill(child: ChatListView(controller: _c)),

              // خانة الكتابة وأزرار التحكم (مثبتة في الأسفل)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // أزرار التحكم (تظهر فقط في وضع الوزاري)
                    if (_c.sessionActive && _c.selectedMode == "وزاري") _buildControlButtons(),

                    // ✅ زر بدء الشرح (يظهر دائماً في وضع شرح الرياضيات)
                    if (_c.selectedSubject == "رياضيات" && _c.mathMode == "شرح") _buildMathExplainButton(),

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
