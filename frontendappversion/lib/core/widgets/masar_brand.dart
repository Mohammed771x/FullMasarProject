import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ==========================================
// 📖 هوية مسار — الشعار الرسمي من assets
// ==========================================
/// ⚠️ **ثابتٌ للأسطح البيضاء دائماً** (كصفيحة الشعار). وللنصّ الذي يجلس
///    على سطحٍ يتبع الوضع استعمل [AppColors.brandInk] — هذا يختفي هناك.
const Color kNavy = Color(0xFF173A6D);
const List<Color> kBlueBtn = [Color(0xFF3B82F6), Color(0xFF1D4ED8)];

/// شعار مسار الرسمي (assets/icon/icon.png).
/// يستبدل الشعار المرسوم بالكود الذي كان في الديمو.
class MasarLogo extends StatelessWidget {
  final double size;
  const MasarLogo({super.key, this.size = 104});

  @override
  Widget build(BuildContext context) {
    // الشعار بخلفية بيضاء أصلاً — نضعه داخل بطاقة دائرية الأطراف
    // حتى لا تظهر حوافه كمربّع حاد فوق خلفية الشاشة.
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(color: kNavy.withValues(alpha: 0.10), blurRadius: size * 0.22, offset: Offset(0, size * 0.06)),
        ],
      ),
      child: Image.asset(
        'assets/icon/icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        // احتياط: لو فشل تحميل الصورة لا تنكسر الشاشة.
        errorBuilder: (_, _, _) => Icon(Icons.auto_stories_rounded, size: size * 0.7, color: kNavy),
      ),
    );
  }
}

/// الشعار + الاسم + الشعار النصي — كتلة واحدة للسبلاش والتوثيق.
class MasarBrand extends StatelessWidget {
  final double logoSize;
  final double titleSize;
  final bool showTagline;
  /// ⛔ **ليس `const` عمداً.** ألوانه تُقرأ من [AppColors] وقت البناء،
  /// و`MasarBrand()` تجعل فلاتر تتخطّى إعادة بنائه — فيبقى «مسار»
  /// بحبر الوضع السابق: نصٌّ فاتحٌ على صفحةٍ بيضاء بعد التبديل.
  /// منعُ `const` في المُنشئ ضمانٌ وقت الترجمة لا تذكّرٌ من المطوّر.
  // ignore: prefer_const_constructors_in_immutables  ← مقصود، انظر أعلاه
  MasarBrand({super.key, this.logoSize = 96, this.titleSize = 32, this.showTagline = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MasarLogo(size: logoSize),
        SizedBox(height: logoSize * 0.06),
        // 🖋️ حبرٌ يتبع الوضع: الاسم على خلفية الصفحة لا على صفيحة الشعار.
        Text("مسار", style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: AppColors.brandInk, letterSpacing: 1)),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text("سفير الطالب اليمني 🇾🇪", style: TextStyle(fontSize: titleSize * 0.4, fontWeight: FontWeight.w800, color: AppColors.brandInk)),
        ],
      ],
    );
  }
}

// خلفية موجية ناعمة (السبلاش والتوثيق والترحيب)
class SoftWaveBackground extends StatelessWidget {
  /// ⛔ **ليس `const`** — للسبب نفسه: لونا الموجة يتبعان الوضع.
  // ignore: prefer_const_constructors_in_immutables  ← مقصود، انظر أعلاه
  SoftWaveBackground({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.infinite,
        // ⚠️ اللونان يُلتقطان **وقت البناء** ويُمرَّران للرسّام: قراءتُهما
        //    داخل `paint` تجعل `shouldRepaint` عاجزاً عن ملاحظة تبدّل الوضع.
        painter: _WavePainter(tint: AppColors.waveTint, glow: AppColors.waveGlow),
      );
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.tint, required this.glow});
  final Color tint;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 3; i++) {
      final dy = h * 0.72 + i * 26;
      final path = Path()
        ..moveTo(0, dy)
        ..cubicTo(w * 0.25, dy - 40, w * 0.55, dy + 40, w, dy - 10);
      canvas.drawPath(path, paint);
    }
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [glow, glow.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.9, h * 0.12), radius: w * 0.4));
    canvas.drawCircle(Offset(w * 0.9, h * 0.12), w * 0.4, glowPaint);
  }

  /// ⚠️ `false` دائماً كان يعني خلفيةً لا تتبدّل مع الوضع: يُبدّل الطالب
  ///    الوضعَ فتبقى الموجة بلون الوضع السابق حتى يُعاد فتح الشاشة.
  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.tint != tint || old.glow != glow;
}
