import 'dart:async';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../../../core/widgets/typewriter_text.dart';
import '../../../../core/widgets/typing_indicator.dart';
import '../../data/demo_state.dart';

// ==========================================
// 🤖 شات تجريبي غني (Mock) — مايك/كاميرا/اقتراحات/حفظ/مشاركة/استماع مُحاكاة
// ==========================================
class DemoChat extends StatefulWidget {
  final String subject; // للحفظ والعرض
  final String contextLabel;
  final String welcome;
  final List<String> quickPrompts;
  final bool guestLimited; // تفعيل حد الزائر

  const DemoChat({
    super.key,
    required this.subject,
    required this.contextLabel,
    required this.welcome,
    this.quickPrompts = const [],
    this.guestLimited = false,
  });

  @override
  State<DemoChat> createState() => _DemoChatState();
}

class _DemoChatState extends State<DemoChat> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  final List<_Msg> _messages = [];
  bool _typing = false;
  bool _listening = false;
  String? _pendingImage; // اسم صورة مرفقة (محاكاة)
  Timer? _micTimer;

  @override
  void initState() {
    super.initState();
    _messages.add(_Msg(role: "ai", text: widget.welcome, animate: false));
  }

  @override
  void dispose() {
    _micTimer?.cancel();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _snack(String m, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      backgroundColor: color ?? AppColors.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  void _send([String? preset]) {
    final text = (preset ?? _input.text).trim();
    if ((text.isEmpty && _pendingImage == null) || _typing) return;

    // حد الزائر
    if (widget.guestLimited && !DemoState.I.consumeGuestQuestion()) {
      _showGuestLimitDialog();
      return;
    }

    final shownText = _pendingImage != null ? "📷 [صورة مرفقة] ${text.isEmpty ? 'حلّ هذه المسألة' : text}" : text;
    setState(() {
      _messages.add(_Msg(role: "user", text: shownText, animate: false));
      _input.clear();
      _pendingImage = null;
      _typing = true;
    });
    DemoState.I.recordChat(widget.subject, widget.contextLabel);
    _scrollDown();

    Future.delayed(const Duration(milliseconds: 1100), () {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _messages.add(_Msg(role: "ai", text: _mockReply(text), animate: true));
      });
      if (DemoState.I.autoTts) _snack("🔊 يقرأ الرد تلقائياً... (محاكاة)");
      _scrollDown();
    });
  }

  String _mockReply(String q) {
    // ⚠️ هذا النصّ يُعرض بـ`TypewriterText`/`Text` لا بمحلّل markdown،
    //    فلا نجمتين فيه: كانتا ستظهران للطالب حرفاً على الشاشة.
    return "✨ (عرض تجريبي)\n\n"
        "بخصوص \"${q.isEmpty ? 'المسألة المرفقة' : q}\" في ${widget.contextLabel}:\n\n"
        "هذا ردّ يحاكي مساعد مسار الذكي. في النسخة الكاملة يُحلَّل سؤالك ويُرجَع شرح دقيق ومصادر موثوقة خطوة بخطوة.\n\n"
        "- نقطة توضيحية مرتبطة بالموضوع\n"
        "- مثال عملي مبسّط\n"
        "- خلاصة سريعة تثبّت الفهم 👌";
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      }
    });
  }

  void _toggleMic() {
    if (_listening) {
      _micTimer?.cancel();
      setState(() => _listening = false);
      return;
    }
    setState(() => _listening = true);
    _snack("🎤 يستمع... تحدّث الآن (محاكاة)", color: Colors.redAccent);
    // محاكاة تحويل الكلام لنص تدريجياً
    const demo = "اشرح لي هذا الدرس بالتفصيل";
    int i = 0;
    _micTimer = Timer.periodic(const Duration(milliseconds: 130), (t) {
      if (!mounted || !_listening) {
        t.cancel();
        return;
      }
      i += 2;
      _input.text = demo.substring(0, i.clamp(0, demo.length));
      if (i >= demo.length) {
        t.cancel();
        if (mounted) setState(() => _listening = false);
      } else {
        setState(() {});
      }
    });
  }

  void _attachImage() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 12),
            ListTile(leading: Icon(Icons.camera_alt_rounded, color: AppColors.primary), title: const Text("التقاط صورة"), onTap: () {
              Navigator.pop(ctx);
              setState(() => _pendingImage = "camera.jpg");
            }),
            ListTile(leading: Icon(Icons.photo_library_rounded, color: AppColors.secondary), title: const Text("من المعرض"), onTap: () {
              Navigator.pop(ctx);
              setState(() => _pendingImage = "gallery.jpg");
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showGuestLimitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text("أعجبك مسار؟ 🌟", style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text("انتهت أسئلتك التجريبية. أنشئ حسابك المجاني واحتفظ بكل محادثاتك وتابع رحلتك التعليمية.", style: TextStyle(color: AppColors.textSecondary, height: 1.6, fontWeight: FontWeight.w600)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("لاحقاً", style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx),
            child: const Text("أنشئ حسابي", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            itemCount: _messages.length + (_typing ? 1 : 0),
            itemBuilder: (_, i) {
              if (i == _messages.length) {
                return const Align(alignment: Alignment.centerLeft, child: Padding(padding: EdgeInsets.only(left: 10, top: 8, bottom: 16), child: TypingIndicator()));
              }
              return _bubble(_messages[i]);
            },
          ),
        ),
        if (widget.quickPrompts.isNotEmpty && _messages.length <= 1)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: widget.quickPrompts
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ActionChip(
                          label: Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                          backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                          side: BorderSide(color: AppColors.primary.withValues(alpha: 0.2)),
                          onPressed: () => _send(p),
                        ),
                      ))
                  .toList(),
            ),
          ),
        _inputBar(),
      ],
    );
  }

  Widget _bubble(_Msg m) {
    final isUser = m.role == "user";
    return FadeInSlide(
      beginOffset: Offset(isUser ? -0.05 : 0.05, 0),
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isUser)
              Container(
                margin: const EdgeInsets.only(left: 10, bottom: 30),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.surfaceWhite, shape: BoxShape.circle, boxShadow: AppColors.bubbleShadow),
                child: Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 16),
              ),
            Flexible(
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: isUser ? AppColors.bubbleGradient : null,
                      color: isUser ? null : AppColors.surfaceWhite,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(22),
                        topRight: const Radius.circular(22),
                        bottomLeft: Radius.circular(isUser ? 22 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 22),
                      ),
                      boxShadow: AppColors.bubbleShadow,
                    ),
                    child: m.animate
                        ? TypewriterText(text: m.text, onTyping: _scrollDown)
                        : Text(m.text, style: TextStyle(color: isUser ? Colors.white : AppColors.textPrimary, fontSize: DemoState.I.answerFontSize - 1, fontWeight: FontWeight.w500, height: 1.6)),
                  ),
                  // أزرار رد الذكاء الاصطناعي
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14, right: 6),
                      child: Row(
                        children: [
                          _miniBtn(m.saved ? Icons.star_rounded : Icons.star_border_rounded, m.saved ? "محفوظ" : "حفظ", m.saved ? Colors.amber : AppColors.textSecondary, () {
                            if (!m.saved) {
                              DemoState.I.saveAnswer(widget.subject, m.text);
                              setState(() => m.saved = true);
                              _snack("⭐ حُفظت الإجابة في المحفوظات");
                            }
                          }),
                          const SizedBox(width: 6),
                          _miniBtn(Icons.ios_share_rounded, "مشاركة", AppColors.textSecondary, () => _snack("📤 مشاركة كصورة... (محاكاة)")),
                          const SizedBox(width: 6),
                          _miniBtn(Icons.volume_up_rounded, "استماع", AppColors.textSecondary, () => _snack("🔊 يقرأ الرد صوتياً... (محاكاة)")),
                        ],
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

  Widget _miniBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.bold)),
        ]),
      ),
    );
  }

  Widget _inputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 18),
      child: Column(
        children: [
          // معاينة الصورة المرفقة
          if (_pendingImage != null)
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withValues(alpha: 0.2))),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.image_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text("صورة مرفقة", style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 6),
                  GestureDetector(onTap: () => setState(() => _pendingImage = null), child: Icon(Icons.close_rounded, size: 15, color: AppColors.textSecondary)),
                ]),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: AppColors.softShadow,
                    border: Border.all(color: _listening ? Colors.redAccent.withValues(alpha: 0.5) : AppColors.textSecondary.withValues(alpha: 0.1), width: _listening ? 1.6 : 1),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 6),
                      IconButton(icon: Icon(Icons.camera_alt_rounded, color: AppColors.textSecondary, size: 21), onPressed: _attachImage, splashRadius: 20),
                      IconButton(icon: Icon(Icons.mic_rounded, color: _listening ? Colors.redAccent : AppColors.textSecondary, size: 21), onPressed: _toggleMic, splashRadius: 20),
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          onSubmitted: (_) => _send(),
                          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          decoration: InputDecoration(
                            hintText: _listening ? "يستمع..." : "اكتب سؤالك...",
                            hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.6), fontSize: 14),
                            contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => _send(),
                borderRadius: BorderRadius.circular(30),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(gradient: AppColors.mainGradient, shape: BoxShape.circle, boxShadow: AppColors.softShadow),
                  child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          if (widget.guestLimited)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text("وضع الزائر · ${DemoState.I.guestQuestionsLeft} أسئلة متبقية", style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}

class _Msg {
  final String role;
  final String text;
  final bool animate;
  bool saved = false;
  _Msg({required this.role, required this.text, required this.animate});
}
