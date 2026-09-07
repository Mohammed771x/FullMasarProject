import 'dart:async';

import 'package:flutter/material.dart';

// ==========================================
// ✨ أداة أنيميشن الظهور الانزلاقي السلس
// ==========================================
class FadeInSlide extends StatefulWidget {
  final Widget child;
  final double delay;
  final Offset beginOffset;

  const FadeInSlide({
    super.key,
    required this.child,
    this.delay = 0,
    this.beginOffset = const Offset(0, 0.1),
  });

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  /// ⚠️ مؤقّت التأخير **يُملَك ويُلغى**. كان `Future.delayed` طليقاً: يبقى
  ///    معلّقاً بعد التخلّص من الويدجت — تسريبٌ في الإنتاج، وتعليقٌ في
  ///    اختبارات الويدجت («A Timer is still pending»).
  Timer? _delay;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _offsetAnimation = Tween<Offset>(begin: widget.beginOffset, end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeInCubic);

    final ms = (widget.delay * 1000).toInt();
    if (ms <= 0) {
      _controller.forward();
    } else {
      _delay = Timer(Duration(milliseconds: ms), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(position: _offsetAnimation, child: widget.child),
    );
  }
}
