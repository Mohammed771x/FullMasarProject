import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_colors.dart';
import 'robot_widget.dart';

// ==========================================
// 💡 تلميح الشاشة — الروبوت يطلّ من الزاوية ويتكلّم
// ==========================================
// الظهور على مرحلتين حتى يبدو الكلام صادراً من الروبوت نفسه:
//   ١) 🤖 يقفز الروبوت من الزاوية (easeOutBack) وهو **يلوّح**.
//   ٢) بعد 380ms تنفتح فقاعته من زاويته نفسها وذيلها يشير إليه،
//      فيتحوّل إلى وضع **الكلام** (فمه يتحرّك).
//   الخروج معكوس: تنطوي الفقاعة ثم ينسحب الروبوت للزاوية.
//
// الزاوية: **أسفل اليمين** افتراضياً، و**أعلى اليسار** حين `anchorTop`
//          (شاشة الشات: أسفلها لوحة الإعدادات وخانة الكتابة).
//
// وباقي القواعد كما هي:
//   • يظهر مرة واحدة فقط لكل شاشة، عند أول زيارة لها.
//   • "مرة واحدة" حقيقية: محفوظة في SharedPreferences، تنجو من إغلاق التطبيق.
//   • يختفي تلقائياً بعد [autoHideAfter]، أو بـ✕ أو "فهمت 👍".
//   • يطفو فوق المحتوى (Overlay) فلا يأخذ أي مساحة من التخطيط.
//
// الاستخدام: ضعه كآخر عنصر في Stack الشاشة:
//   const ScreenTip(screenId: "home", text: "...")
class ScreenTip extends StatefulWidget {
  final String screenId;
  final String text;
  final Duration autoHideAfter;
  final Duration delayBeforeShow;

  /// المسافة من أسفل الشاشة — ارفعها في الشاشات التي بها خانة كتابة سفلية.
  final double bottomOffset;

  /// يرسو في زاوية **أعلى اليسار** بدل **أسفل اليمين** — للشاشات التي
  /// أسفلها مزدحم (شاشة الشات: لوحة الإعدادات + خانة الكتابة).
  final bool anchorTop;

  /// المسافة من أعلى الشاشة عند anchorTop.
  final double topOffset;

  /// إن كان true يظهر في كل مرة (للتجربة أثناء التطوير فقط).
  final bool alwaysShow;

  const ScreenTip({
    super.key,
    required this.screenId,
    required this.text,
    this.autoHideAfter = const Duration(seconds: 9),
    this.delayBeforeShow = const Duration(milliseconds: 700),
    this.bottomOffset = 18,
    this.anchorTop = false,
    this.topOffset = 12,
    this.alwaysShow = false,
  });

  static String _key(String id) => 'screen_tip_shown_$id';

  /// يصفّر كل التلميحات — يُستدعى من الإعدادات ("أعد عرض التلميحات").
  static Future<void> resetAll(List<String> screenIds) async {
    final p = await SharedPreferences.getInstance();
    for (final id in screenIds) {
      await p.remove(_key(id));
    }
  }

  @override
  State<ScreenTip> createState() => _ScreenTipState();
}

class _ScreenTipState extends State<ScreenTip> {
  // مرحلتان: يقفز الروبوت من الزاوية أولاً، ثم تنفتح فقاعته وكأنه بدأ يتكلّم.
  bool _robotIn = false;
  bool _bubbleIn = false;
  Timer? _hideTimer;
  Timer? _stageTimer;

  /// المهلة بين ظهور الروبوت وانفتاح الفقاعة.
  static const Duration _bubbleDelay = Duration(milliseconds: 380);

  @override
  void initState() {
    super.initState();
    _maybeShow();
  }

  Future<void> _maybeShow() async {
    if (!widget.alwaysShow) {
      final p = await SharedPreferences.getInstance();
      final already = p.getBool(ScreenTip._key(widget.screenId)) ?? false;
      if (already) return;
      await p.setBool(ScreenTip._key(widget.screenId), true);
    }

    await Future.delayed(widget.delayBeforeShow);
    if (!mounted) return;
    setState(() => _robotIn = true);

    _stageTimer = Timer(_bubbleDelay, () {
      if (mounted) setState(() => _bubbleIn = true);
    });

    _hideTimer = Timer(widget.autoHideAfter, _dismiss);
  }

  /// الخروج بالترتيب المعكوس: تنطوي الفقاعة ثم ينسحب الروبوت للزاوية.
  void _dismiss() {
    _hideTimer?.cancel();
    _stageTimer?.cancel();
    if (!mounted) return;
    setState(() => _bubbleIn = false);
    _stageTimer = Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _robotIn = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _stageTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 📐 الزاوية: أسفل اليمين افتراضياً، وأعلى اليسار حين anchorTop
    //    (شاشة الشات — أسفلها مزدحم بلوحة الإعدادات وخانة الكتابة).
    final bool topLeft = widget.anchorTop;
    final Alignment corner = topLeft ? Alignment.topLeft : Alignment.bottomRight;
    final Offset enterFrom = topLeft ? const Offset(-0.55, -0.55) : const Offset(0.55, 0.55);

    final robot = Align(
      alignment: topLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(left: topLeft ? 4 : 0, right: topLeft ? 0 : 4),
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          offset: _robotIn ? Offset.zero : enterFrom,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 420),
            curve: Curves.easeOutBack,
            scale: _robotIn ? 1 : 0,
            child: RobotWidget(
              size: 56,
              // يلوّح أولاً، فإذا انفتحت الفقاعة صار يتكلّم 🗣️
              state: _bubbleIn ? RobotState.talk : RobotState.wave,
            ),
          ),
        ),
      ),
    );

    // ذيل الفقاعة — يشير إلى الروبوت فيبدو الكلام صادراً منه.
    final tail = Align(
      alignment: topLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Padding(
        padding: EdgeInsets.only(left: topLeft ? 22 : 0, right: topLeft ? 0 : 22),
        child: CustomPaint(
          size: const Size(18, 9),
          painter: _TailPainter(color: AppColors.surfaceWhite, pointsUp: topLeft),
        ),
      ),
    );

    final bubble = AnimatedScale(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      // تكبر من زاوية الروبوت نفسها — كأنها خرجت من فمه.
      alignment: corner,
      scale: _bubbleIn ? 1 : 0.55,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 240),
        opacity: _bubbleIn ? 1 : 0,
        child: Padding(
          // تُترك مساحة في الجهة المقابلة للزاوية فتبدو الفقاعة راسية عليها.
          padding: EdgeInsets.only(left: topLeft ? 0 : 26, right: topLeft ? 26 : 0),
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
                    Expanded(
                      child: Text("مساعد مسار",
                          style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 14)),
                    ),
                    InkWell(
                      onTap: _dismiss,
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 19, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(widget.text,
                    style: TextStyle(
                        color: AppColors.textPrimary, height: 1.7, fontSize: 13.5, fontWeight: FontWeight.w500)),
                const SizedBox(height: 12),
                Align(
                  alignment: topLeft ? Alignment.centerRight : Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: _dismiss,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
                      decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(14)),
                      child: const Text("فهمت 👍",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // الذيل يظهر مع الفقاعة فقط.
    final tailShown = AnimatedOpacity(
      duration: const Duration(milliseconds: 240),
      opacity: _bubbleIn ? 1 : 0,
      child: tail,
    );

    return Positioned(
      left: 14,
      right: 14,
      top: topLeft ? widget.topOffset : null,
      bottom: topLeft ? null : widget.bottomOffset,
      child: IgnorePointer(
        ignoring: !_bubbleIn,
        child: Material(
          color: Colors.transparent,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: topLeft
                // 🤖 فوق-يسار: الروبوت أولاً ثم الفقاعة تحته
                ? [robot, Transform.translate(offset: const Offset(0, 1), child: tailShown), bubble]
                // 🤖 تحت-يمين: الفقاعة فوق ثم الروبوت أسفلها
                : [bubble, Transform.translate(offset: const Offset(0, -1), child: tailShown), robot],
          ),
        ),
      ),
    );
  }
}

/// مثلّث صغير يصل الفقاعة بالروبوت.
class _TailPainter extends CustomPainter {
  final Color color;
  final bool pointsUp;
  _TailPainter({required this.color, required this.pointsUp});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path();
    if (pointsUp) {
      p.moveTo(size.width / 2, 0);
      p.lineTo(size.width, size.height);
      p.lineTo(0, size.height);
    } else {
      p.moveTo(0, 0);
      p.lineTo(size.width, 0);
      p.lineTo(size.width / 2, size.height);
    }
    p.close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) => old.color != color || old.pointsUp != pointsUp;
}
