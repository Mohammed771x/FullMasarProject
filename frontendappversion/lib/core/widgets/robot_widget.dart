import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ==========================================
// 🤖 روبوت مسار المتحرك (Flutter خالص — بلا Rive)
// ==========================================
enum RobotState { idle, wave, talk, think, point }

class RobotWidget extends StatefulWidget {
  final double size;
  final RobotState state;
  /// ⛔ **ليس `const`** — تدرّجه من [AppColors] فيتبع الوضع، و`const`
  /// تُجمّده على ألوان الوضع الذي بُني فيه.
  // ignore: prefer_const_constructors_in_immutables  ← مقصود، انظر أعلاه
  RobotWidget({super.key, this.size = 160, this.state = RobotState.idle});

  @override
  State<RobotWidget> createState() => _RobotWidgetState();
}

class _RobotWidgetState extends State<RobotWidget> with TickerProviderStateMixin {
  late final AnimationController _ambient; // طفو + رمش
  late final AnimationController _action; // تلويح + كلام

  @override
  void initState() {
    super.initState();
    _ambient = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..repeat();
    _action = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ambient.dispose();
    _action.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_ambient, _action]),
      builder: (context, _) {
        final t = _ambient.value; // 0..1
        final floatY = math.sin(t * 2 * math.pi) * (widget.size * 0.03);
        final tilt = math.sin(t * 2 * math.pi) * 0.03;

        // رمش: عين مغلقة قرب نهاية الدورة
        double eye = 1;
        if (t > 0.90) eye = 1 - ((t - 0.90) / 0.05).clamp(0, 1) * (t < 0.95 ? 1 : 0);
        if (t > 0.90 && t <= 0.95) eye = 1 - (t - 0.90) / 0.05;
        if (t > 0.95) eye = (t - 0.95) / 0.05;
        eye = eye.clamp(0.1, 1.0);

        final act = _action.value; // 0..1 ذهاب/إياب
        final mouthOpen = widget.state == RobotState.talk ? (0.3 + act * 0.7) : 0.0;
        final waveAngle = widget.state == RobotState.wave ? (math.sin(act * math.pi) * 0.9 - 0.3) : 0.0;

        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Transform.translate(
            offset: Offset(0, floatY),
            child: Transform.rotate(
              angle: tilt,
              child: CustomPaint(
                painter: _RobotPainter(
                  state: widget.state,
                  eyeOpen: eye,
                  mouthOpen: mouthOpen,
                  waveAngle: waveAngle,
                  glow: 0.5 + 0.5 * math.sin(t * 2 * math.pi),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RobotPainter extends CustomPainter {
  final RobotState state;
  final double eyeOpen;
  final double mouthOpen;
  final double waveAngle;
  final double glow;

  _RobotPainter({required this.state, required this.eyeOpen, required this.mouthOpen, required this.waveAngle, required this.glow});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;

    // ظل أرضي
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.08);
    canvas.drawOval(Rect.fromCenter(center: Offset(cx, h * 0.95), width: w * 0.5, height: h * 0.06), shadow);

    final bodyGrad = LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight);

    // ===== الجسم =====
    final bodyRect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, h * 0.72), width: w * 0.44, height: h * 0.30), Radius.circular(w * 0.12));
    canvas.drawRRect(bodyRect, Paint()..shader = bodyGrad.createShader(bodyRect.outerRect));
    // قلب متوهج بالصدر
    canvas.drawCircle(Offset(cx, h * 0.72), w * 0.06, Paint()..color = Colors.white.withValues(alpha: 0.35 + glow * 0.4));
    canvas.drawCircle(Offset(cx, h * 0.72), w * 0.035, Paint()..color = Colors.white.withValues(alpha: 0.9));

    // ===== الأذرع =====
    final armPaint = Paint()
      ..color = AppColors.secondary
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    // الذراع اليسرى (ثابتة أو للأعلى في التفكير)
    final leftUp = state == RobotState.think ? h * 0.60 : h * 0.74;
    canvas.drawLine(Offset(cx - w * 0.22, h * 0.66), Offset(cx - w * 0.30, leftUp), armPaint);
    canvas.drawCircle(Offset(cx - w * 0.30, leftUp), w * 0.045, Paint()..color = AppColors.primary);

    // الذراع اليمنى (تلوّح/تشير)
    canvas.save();
    canvas.translate(cx + w * 0.22, h * 0.66);
    double rot;
    switch (state) {
      case RobotState.wave:
        rot = -0.9 + waveAngle;
        break;
      case RobotState.point:
        rot = 1.4; // للأسفل
        break;
      case RobotState.think:
        rot = -1.5; // لليد على الذقن
        break;
      default:
        rot = 0.5;
    }
    canvas.rotate(rot);
    canvas.drawLine(Offset.zero, Offset(w * 0.10, 0), armPaint);
    canvas.drawCircle(Offset(w * 0.10, 0), w * 0.045, Paint()..color = AppColors.primary);
    canvas.restore();

    // ===== الرأس =====
    final headRect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, h * 0.40), width: w * 0.58, height: h * 0.44), Radius.circular(w * 0.16));
    // هالة توهج
    canvas.drawRRect(
      RRect.fromRectAndRadius(headRect.outerRect.inflate(w * 0.02), Radius.circular(w * 0.18)),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.12 + glow * 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(headRect, Paint()..shader = bodyGrad.createShader(headRect.outerRect));

    // الهوائي
    canvas.drawLine(Offset(cx, h * 0.18), Offset(cx, h * 0.10), Paint()..color = AppColors.secondary..strokeWidth = w * 0.03..strokeCap = StrokeCap.round);
    canvas.drawCircle(Offset(cx, h * 0.085), w * 0.04 + glow * w * 0.01, Paint()..color = const Color(0xFFFACC15));
    canvas.drawCircle(Offset(cx, h * 0.085), w * 0.07, Paint()..color = const Color(0xFFFACC15).withValues(alpha: 0.25 * glow));

    // شاشة الوجه (داكنة)
    final faceRect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, h * 0.40), width: w * 0.44, height: h * 0.30), Radius.circular(w * 0.10));
    canvas.drawRRect(faceRect, Paint()..color = const Color(0xFF0B1220).withValues(alpha: 0.92));

    // العيون
    final eyePaint = Paint()..color = const Color(0xFF7DD3FC);
    final eyeH = h * 0.075 * eyeOpen;
    for (final dx in [-w * 0.10, w * 0.10]) {
      final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx + dx, h * 0.37), width: w * 0.075, height: eyeH.clamp(2.0, h)), Radius.circular(w * 0.03));
      canvas.drawRRect(r, eyePaint);
    }

    // الفم
    if (mouthOpen > 0.01) {
      final m = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, h * 0.47), width: w * 0.14, height: h * 0.05 * mouthOpen + 2), Radius.circular(w * 0.02));
      canvas.drawRRect(m, Paint()..color = const Color(0xFF7DD3FC));
    } else {
      // ابتسامة
      final smile = Path()..moveTo(cx - w * 0.07, h * 0.46);
      smile.quadraticBezierTo(cx, h * 0.50, cx + w * 0.07, h * 0.46);
      canvas.drawPath(smile, Paint()..color = const Color(0xFF7DD3FC)..style = PaintingStyle.stroke..strokeWidth = w * 0.02..strokeCap = StrokeCap.round);
    }

    // فقاعة تفكير
    if (state == RobotState.think) {
      final tp = Paint()..color = AppColors.textSecondary.withValues(alpha: 0.5);
      canvas.drawCircle(Offset(cx + w * 0.30, h * 0.20), w * 0.02, tp);
      canvas.drawCircle(Offset(cx + w * 0.35, h * 0.14), w * 0.03, tp);
      canvas.drawCircle(Offset(cx + w * 0.42, h * 0.07), w * 0.045, tp);
    }
  }

  @override
  bool shouldRepaint(covariant _RobotPainter old) =>
      old.eyeOpen != eyeOpen || old.mouthOpen != mouthOpen || old.waveAngle != waveAngle || old.glow != glow || old.state != state;
}
