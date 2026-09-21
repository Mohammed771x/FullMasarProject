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
    this.height = 106,
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

  // ══════════════════════════════════════════════════
  // 🎏 بطاقة البانر — مقاسات Figma: 342×106 · r14
  // ══════════════════════════════════════════════════
  // 📐 من ملف التصميم (الرئيسية · 24:21174 ← البانر عند y=344):
  //    تدرّجٌ من أعلى اليسار إلى أسفل اليمين · عنوان 12/w700 `#F8F4F4`
  //    ووصف 10/w400 · النصّ **مصفوفٌ لليمين** وينتهي عند حافّة البطاقة
  //    ناقص 8 · وثلاثُ دوائر زخرفية شفيفة بلون التدرّج الفاتح.
  //
  // ⚠️ **النصّ من الخادم لا من التصميم**: عنوان بانر المصمّم «منحة تركيا»
  //    محتوىً توضيحي، والبانرات الحقيقية يكتبها المالك من اللوحة.
  Widget _card(AppBanner b) {
    final gradient = b.gradient;
    return GestureDetector(
      onTap: () => widget.onAction(b.action, b.actionValue),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            // 🫧 دوائرُ زخرفية بلون التدرّج الفاتح — في التصميم ثلاثٌ
            //    تخرج من الحافّة وتعطي البطاقة عمقاً بلا صورة.
            Positioned(right: -2, top: -30, child: _bubble(54, gradient.first)),
            Positioned(right: 122, top: 2, child: _bubble(47, gradient.first)),
            Positioned(right: 84, top: 90, child: _bubble(23, gradient.first)),
            // 🖼️ أيقونة البانر ختمٌ كبير خافت في **يسار** البطاقة.
            Positioned(
              left: 18,
              top: 0,
              bottom: 0,
              child: Center(
                child: Icon(b.iconData,
                    color: Colors.white.withValues(alpha: 0.9), size: 52),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(96, 8, 8, 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    b.title,
                    textAlign: TextAlign.start,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF8F4F4),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 22 / 12,
                    ),
                  ),
                  if (b.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      b.subtitle,
                      textAlign: TextAlign.start,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFF8F4F4),
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        height: 19 / 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bubble(double d, Color c) => Container(
        width: d,
        height: d,
        decoration: BoxDecoration(
            color: c.withValues(alpha: 0.55), shape: BoxShape.circle),
      );
}
