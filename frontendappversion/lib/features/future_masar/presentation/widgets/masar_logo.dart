import 'dart:math' as math;
import 'package:flutter/material.dart';

// ==========================================
// 📖 شعار مسار (كتاب مفتوح كحلي + قوس ذهبي) — هوية موحّدة
// ==========================================
const Color kNavy = Color(0xFF173A6D);
const List<Color> kGold = [Color(0xFFE9C268), Color(0xFFB67E22)];
const List<Color> kBlueBtn = [Color(0xFF3B82F6), Color(0xFF1D4ED8)];

class MasarLogo extends StatelessWidget {
  final double size;
  const MasarLogo({super.key, this.size = 104});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 1.27,
      height: size,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(bottom: 0, child: Icon(Icons.auto_stories_rounded, size: size * 0.8, color: kNavy)),
          Positioned(top: 0, child: CustomPaint(size: Size(size, size * 0.48), painter: _GoldCrestPainter())),
        ],
      ),
    );
  }
}

class _GoldCrestPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final shader = const LinearGradient(colors: kGold, begin: Alignment.topCenter, end: Alignment.bottomCenter).createShader(Rect.fromLTWH(0, 0, w, h));
    final p = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.055
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCircle(center: Offset(w / 2, h * 1.05), radius: w * 0.42);
    canvas.drawArc(rect, math.pi * 1.18, math.pi * 0.64, false, p);

    final wing = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    final lp = Path()
      ..moveTo(w * 0.20, h * 0.62)
      ..quadraticBezierTo(w * 0.30, h * 0.40, w * 0.42, h * 0.50);
    final rp = Path()
      ..moveTo(w * 0.80, h * 0.62)
      ..quadraticBezierTo(w * 0.70, h * 0.40, w * 0.58, h * 0.50);
    canvas.drawPath(lp, wing);
    canvas.drawPath(rp, wing);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// خلفية موجية ناعمة (تُستخدم في الدخول والسبلاش)
class SoftWaveBackground extends StatelessWidget {
  const SoftWaveBackground({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.infinite, painter: _WavePainter());
}

class _WavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = const Color(0xFF1D4ED8).withValues(alpha: 0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 3; i++) {
      final dy = h * 0.72 + i * 26;
      final path = Path()
        ..moveTo(0, dy)
        ..cubicTo(w * 0.25, dy - 40, w * 0.55, dy + 40, w, dy - 10);
      canvas.drawPath(path, paint);
    }
    final glow = Paint()
      ..shader = RadialGradient(colors: [const Color(0xFF3B82F6).withValues(alpha: 0.06), const Color(0xFF3B82F6).withValues(alpha: 0.0)]).createShader(Rect.fromCircle(center: Offset(w * 0.9, h * 0.12), radius: w * 0.4));
    canvas.drawCircle(Offset(w * 0.9, h * 0.12), w * 0.4, glow);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
