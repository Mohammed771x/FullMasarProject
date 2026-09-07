import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/stt_service.dart';
import '../theme/app_colors.dart';

// ==========================================
// 🎙️ شريط التسجيل الصوتي (بنمط ChatGPT)
// ==========================================
// 📍 يعيش في `core/widgets` لأن **قسمين** يستعملانه: التعليم ومساعد المنح —
//    وتجربة التسجيل يجب أن تكون واحدة في الاثنين لا اثنتين متشابهتين.
// [🗑️ حذف]  ~~~ موجات ~~~ 0:12  [⏹️ إيقاف]  [➤ إرسال]
// لا يتوقف تلقائياً — الطالب وحده من ينهيه.
//
// ⚠️ الموجة تُحسب **من الزمن مباشرة** داخل الرسّام، لا من مخزن يُحدَّث بـ setState.
//    السبب: الحلول المعتمدة على Timer/setState ظهرت جامدة (تُخنَق أو لا تُطلق).
//    الآن AnimatedBuilder يعيد الرسم كل إطار vsync، والارتفاع دالة في (الموضع، الزمن).
class VoiceRecordingBar extends StatefulWidget {
  final VoidCallback onDelete;
  final VoidCallback onStopToText;
  final VoidCallback onSend;

  const VoiceRecordingBar({
    super.key,
    required this.onDelete,
    required this.onStopToText,
    required this.onSend,
  });

  @override
  State<VoiceRecordingBar> createState() => _VoiceRecordingBarState();
}

class _VoiceRecordingBarState extends State<VoiceRecordingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ticker;

  @override
  void initState() {
    super.initState();
    // دورة كاملة كل ثانيتين — موجة سائرة هادئة لا محمومة.
    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return "$m:$s";
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(30),
        boxShadow: AppColors.softShadow,
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.35), width: 1.4),
      ),
      child: Row(
        children: [
          _iconButton(
            icon: Icons.delete_outline_rounded,
            color: Colors.redAccent,
            tooltip: "حذف التسجيل",
            onTap: widget.onDelete,
          ),

          // ~~~ الموجات ~~~
          Expanded(
            // ⚠️ SizedBox إلزامي: داخل Row يرث CustomPaint ارتفاع أطول عنصر
            //    ويُتجاهل معامل size — بدونه تظهر الموجات كنقاط مسطّحة.
            child: SizedBox(
              height: 36,
              child: AnimatedBuilder(
                animation: Listenable.merge([_ticker, SttService.I.soundLevel]),
                builder: (_, _) => CustomPaint(
                  size: Size.infinite,
                  painter: _WavePainter(
                    t: _ticker.value,
                    level: SttService.I.soundLevel.value,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 6),
          ValueListenableBuilder<Duration>(
            valueListenable: SttService.I.elapsed,
            builder: (_, d, _) => Text(
              _fmt(d),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: AppColors.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 4),

          _iconButton(
            icon: Icons.stop_rounded,
            color: AppColors.textSecondary,
            tooltip: "إيقاف وتحويل لنص",
            onTap: widget.onStopToText,
          ),

          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: InkWell(
              onTap: widget.onSend,
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: AppColors.mainGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_upward_rounded, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, color: color, size: 23),
        ),
      ),
    );
  }
}

/// موجة سائرة: ارتفاع كل عمود دالة في موضعه وفي الزمن.
/// [t] 0..1 دورة كاملة · [level] مستوى الصوت 0..1 (يرفع السعة عند الكلام).
class _WavePainter extends CustomPainter {
  final double t;
  final double level;
  final Color color;

  _WavePainter({required this.t, required this.level, required this.color});

  // عدد قليل نسبياً ⇒ أعمدة عريضة واضحة
  static const int _bars = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final slot = size.width / _bars;
    final barW = math.max(3.5, slot * 0.46);
    final mid = size.height / 2;
    const twoPi = math.pi * 2;

    // مستوى صوت حقيقي (أندرويد) يرفع السعة مع الكلام؛
    // وإلا تبقى سعة أساسية نابضة (iOS لا يرسل مستوى صوت غالباً).
    final amp = 0.45 + level.clamp(0.0, 1.0) * 0.5;

    for (int i = 0; i < _bars; i++) {
      // موجتان بترددين مختلفين ⇒ نبض غير رتيب يشبه الصوت الحقيقي
      final phase = t * twoPi;
      final w1 = math.sin(phase * 2 + i * 0.55);
      final w2 = math.sin(phase * 3 + i * 0.31);
      final envelope = 0.55 + 0.45 * math.sin(phase + i * 0.18);
      final unit = ((w1 * 0.6 + w2 * 0.4) * 0.5 + 0.5) * envelope;

      final level01 = (0.14 + unit * amp).clamp(0.10, 1.0);
      final h = size.height * level01;
      final x = size.width - (i + 1) * slot + (slot - barW) / 2;

      final paint = Paint()
        ..color = color.withValues(alpha: 0.45 + 0.55 * unit)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, mid - h / 2, barW, h),
          Radius.circular(barW / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => old.t != t || old.level != level;
}
