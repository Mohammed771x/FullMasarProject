import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ==========================================
// 💬 فقاعةُ الروبوت وأزرارُ الجولة — بمفردات «تتبع الخطوات» في Figma
// ==========================================
// الفقاعة: بيضاءُ بزوايا ناعمة، عنوانٌ عريضٌ بحبر الهوية وتحته سطرُ الشرح
// رماديّاً، وذيلُها يشير إلى رأس الروبوت فيبدو الكلامُ خارجاً منه.
// الأزرار: «التالي» مصمتٌ بلون الهوية و«إغلاق» أبيضُ — ٤٧ ارتفاعاً r16
// (زرُّ المصمّم في كل الملف).

class TourBubble extends StatelessWidget {
  const TourBubble({
    super.key,
    required this.title,
    required this.full,
    required this.body,
    required this.tailDx,
    this.onTap,
  });

  final String title;

  /// الشرحُ كاملاً — يحجز ارتفاعَه من البداية.
  final String full;

  /// الشرحُ كما كُشف حتى الآن (يُكتب كلمةً كلمة).
  final String body;

  /// إزاحةُ الذيل عن منتصف الفقاعة — يتبع رأسَ الروبوت.
  final double tailDx;
  final VoidCallback? onTap;

  static const double tailHeight = 12;

  @override
  Widget build(BuildContext context) {
    final surface = AppColors.surfaceWhite;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.14),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.brandInk,
                  ),
                ),
                const SizedBox(height: 6),
                // 📏 ارتفاعُ الشرح كاملاً محجوزٌ من البداية (نصٌّ شفّافٌ تحت
                //    المكشوف) — فلا تتمدّد الفقاعةُ كلما ظهرت كلمة.
                Stack(
                  children: [
                    Opacity(opacity: 0, child: _bodyText(full)),
                    _bodyText(body),
                  ],
                ),
              ],
            ),
          ),
          Transform.translate(
            offset: Offset(tailDx, -1),
            child: CustomPaint(
              size: const Size(26, tailHeight),
              painter: _TailPainter(surface),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bodyText(String t) => Text(
    t,
    style: TextStyle(
      fontSize: 14,
      height: 1.75,
      fontWeight: FontWeight.w600,
      color: AppColors.textSecondary,
    ),
  );
}

class _TailPainter extends CustomPainter {
  _TailPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // ذيلٌ منحنٍ قليلاً — ألطفُ من مثلّثٍ حادّ، كفقاعة المصمّم.
    final w = size.width, h = size.height;
    final p = Path()
      ..moveTo(0, 0)
      ..lineTo(w, 0)
      ..quadraticBezierTo(w * 0.62, h * 0.35, w * 0.42, h)
      ..quadraticBezierTo(w * 0.36, h * 0.4, 0, 0)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TailPainter old) => old.color != color;
}

/// «التالي» و«إغلاق» ونقاطُ التقدّم تحتهما.
class TourControls extends StatelessWidget {
  const TourControls({
    super.key,
    required this.index,
    required this.count,
    required this.onNext,
    required this.onClose,
  });

  final int index;
  final int count;
  final VoidCallback onNext;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final last = index == count - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ⚠️ RTL: أوّلُ ابنٍ يمين ⇒ «التالي» يميناً و«إغلاق» يساره كما في Figma.
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _button(
              label: last ? "لنبدأ" : "التالي",
              fill: AppColors.primaryFill,
              ink: Colors.white,
              width: 118,
              onTap: onNext,
            ),
            if (!last) ...[
              const SizedBox(width: 12),
              _button(
                label: "إغلاق",
                fill: AppColors.surfaceWhite,
                ink: AppColors.brandInk,
                width: 92,
                onTap: onClose,
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 📏 جولةٌ طويلة (قسمُ التعليم ~٢٠ خطوة) تُصغَّر نقاطُها كي لا
            //    يتجاوز سطرُها عرضَ الجوّال.
            for (var i = 0; i < count; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                margin: EdgeInsets.symmetric(
                  horizontal: count > 14 ? 1.5 : 2.5,
                ),
                width: i == index
                    ? (count > 14 ? 14 : 18)
                    : (count > 14 ? 5 : 6),
                height: count > 14 ? 5 : 6,
                decoration: BoxDecoration(
                  color: i == index
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _button({
    required String label,
    required Color fill,
    required Color ink,
    required double width,
    required VoidCallback onTap,
  }) => Material(
    color: fill,
    borderRadius: BorderRadius.circular(16),
    elevation: 0,
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: width,
        height: 47,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: ink,
          ),
        ),
      ),
    ),
  );
}
