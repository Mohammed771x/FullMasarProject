import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/banner_model.dart';
import '../data/banner_repository.dart';

// ==========================================
// 🎏 شريط البانرات — ويدجت واحد لكل الأقسام
// ==========================================
// كل قسم يستدعيه باسمه فيأخذ بانراته وحدها. توحيدُه مقصود: البانر يظهر في
// سبع شاشات، ونسخُه سبع مرات يعني سبعة أماكن تُنسى عند أول تعديل.
class BannerCarousel extends StatefulWidget {
  const BannerCarousel({
    super.key,
    required this.section,
    required this.onAction,
    this.height = 140,
  });

  final String section;

  /// وجهة النقر — الشاشة المستضيفة هي التي تعرف كيف تتنقّل.
  /// `(action, value)` مثل `("scholarship", "india")`.
  final void Function(String action, String value) onAction;

  final double height;

  @override
  State<BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<BannerCarousel> {
  final _pc = PageController();
  Timer? _timer;
  int _index = 0;

  List<AppBanner> get _items => BannerRepository.I.forSection(widget.section);

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  void _startAutoPlay() {
    _timer?.cancel();
    // ⚠️ بانر واحد لا يُدار: التحريك حينها اهتزازٌ بلا معنى ويستهلك بطارية.
    if (_items.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_pc.hasClients || _items.length < 2) return;
      _index = (_index + 1) % _items.length;
      _pc.animateToPage(_index,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    // 🛡️ لا بانرات ⇒ لا مساحة فارغة ولا هيكل تحميل: القسم يبدو كأنه بلا
    //    شريط أصلاً، وهذا أنظف من صندوق رماديّ ينتظر شبكةً قد لا تأتي.
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView.builder(
            controller: _pc,
            onPageChanged: (i) => setState(() => _index = i),
            itemCount: items.length,
            itemBuilder: (_, i) => _card(items[i]),
          ),
        ),
        if (items.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              items.length,
              (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _index == i ? 22 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: _index == i
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _card(AppBanner b) {
    final gradient = b.gradient;
    return GestureDetector(
      onTap: () => widget.onAction(b.action, b.actionValue),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                  if (b.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      b.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(b.iconData,
                color: Colors.white.withValues(alpha: 0.9), size: 48),
          ],
        ),
      ),
    );
  }
}
