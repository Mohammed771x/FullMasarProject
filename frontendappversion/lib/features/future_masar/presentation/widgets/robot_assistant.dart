import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/demo_data.dart';
import '../../data/demo_state.dart';
import 'robot_widget.dart';

// ==========================================
// 🤖 المساعد العائم (فقاعة تعليمات أول زيارة + شات محاكى)
// يُوضع كآخر عنصر في Stack الشاشة ليطفو فوقها.
// ==========================================
class RobotAssistant extends StatefulWidget {
  final String screenId;
  const RobotAssistant({super.key, required this.screenId});

  @override
  State<RobotAssistant> createState() => _RobotAssistantState();
}

class _RobotAssistantState extends State<RobotAssistant> {
  bool _introVisible = false;
  bool _chatOpen = false;
  final List<Map<String, String>> _msgs = [];
  final _input = TextEditingController();
  bool _typing = false;

  @override
  void initState() {
    super.initState();
    // أول زيارة للشاشة → تعليمات تلقائية
    if (!DemoState.I.robotIntroShown.contains(widget.screenId)) {
      DemoState.I.robotIntroShown.add(widget.screenId);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) setState(() => _introVisible = true);
        });
      });
    }
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final t = (preset ?? _input.text).trim();
    if (t.isEmpty || _typing) return;
    setState(() {
      _msgs.add({"role": "user", "text": t});
      _input.clear();
      _typing = true;
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _msgs.add({"role": "ai", "text": _reply(t)});
      });
    });
  }

  String _reply(String q) {
    final intro = robotIntro[widget.screenId] ?? "أنا مساعدك في مسار.";
    return "🤖 (عرض تجريبي) بخصوص \"$q\":\n$intro\n\nهل تريد أن أرشدك خطوة بخطوة؟";
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // فقاعة التعليمات
        if (_introVisible) _introBubble(),
        // لوحة الشات
        if (_chatOpen) _chatPanel(),
        // زر الروبوت العائم
        Positioned(
          right: 16,
          bottom: 24,
          child: GestureDetector(
            onTap: () => setState(() {
              _chatOpen = !_chatOpen;
              _introVisible = false;
            }),
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 18, offset: const Offset(0, 8))],
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 2),
              ),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: RobotWidget(size: 52, state: RobotState.idle),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _introBubble() {
    return Positioned(
      right: 16,
      bottom: 96,
      left: 60,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutBack,
        builder: (context, v, child) => Transform.scale(alignment: Alignment.bottomRight, scale: v, child: child),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius: BorderRadius.circular(22),
            boxShadow: AppColors.softShadow,
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const RobotWidget(size: 42, state: RobotState.wave),
                  const SizedBox(width: 8),
                  Text("مساعد مسار", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 10),
              Text(robotIntro[widget.screenId] ?? "", style: TextStyle(color: AppColors.textPrimary, height: 1.7, fontSize: 13.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: () => setState(() => _introVisible = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                    decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(14)),
                    child: const Text("فهمت 👍", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chatPanel() {
    return Positioned(
      right: 16,
      left: 16,
      bottom: 96,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 380),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(24),
          boxShadow: AppColors.softShadow,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // رأس
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: AppColors.mainGradient,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  const RobotWidget(size: 38, state: RobotState.talk),
                  const SizedBox(width: 8),
                  const Expanded(child: Text("مساعد مسار الذكي", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14))),
                  GestureDetector(onTap: () => setState(() => _chatOpen = false), child: const Icon(Icons.close_rounded, color: Colors.white, size: 22)),
                ],
              ),
            ),
            // رسائل
            Flexible(
              child: _msgs.isEmpty && !_typing
                  ? Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(robotHint[widget.screenId] ?? "اسألني أي شيء 😊", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      shrinkWrap: true,
                      children: [
                        ..._msgs.map((m) => _bubble(m["role"]!, m["text"]!)),
                        if (_typing) _bubble("ai", "..."),
                      ],
                    ),
            ),
            // إدخال
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(20)),
                      child: TextField(
                        controller: _input,
                        onSubmitted: (_) => _send(),
                        style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: "اكتب سؤالك...",
                          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 13),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _send(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(gradient: AppColors.mainGradient, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(String role, String text) {
    final isUser = role == "user";
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 240),
        decoration: BoxDecoration(
          gradient: isUser ? AppColors.bubbleGradient : null,
          color: isUser ? null : AppColors.softSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(text, style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w500, height: 1.5)),
      ),
    );
  }
}
