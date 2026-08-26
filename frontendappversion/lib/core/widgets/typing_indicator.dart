import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

// ==========================================
// ⌛ مؤشر "يكتب الآن..." (ثلاث نقاط متحركة)
// ==========================================
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});
  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (index) => AnimationController(vsync: this, duration: const Duration(milliseconds: 600)));
    _animations = _controllers.map((controller) => Tween<double>(begin: 0, end: -8).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOutSine))).toList();
    _startAnimation();
  }

  void _startAnimation() async {
    for (int i = 0; i < 3; i++) {
      if (!mounted) return;
      _controllers[i].repeat(reverse: true);
      await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) => AnimatedBuilder(
        animation: _controllers[index],
        builder: (context, child) => Transform.translate(
          offset: Offset(0, _animations[index].value),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 8, height: 8,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
          ),
        ),
      )),
    );
  }
}
