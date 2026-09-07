import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// ==========================================
// 🎨 ويدجتس مشتركة لديمو "مسار المستقبل"
// ==========================================

/// خلفية متوهّجة بكرات تدرّج لونية (نفس روح شاشة الترحيب).
class GlowBackground extends StatelessWidget {
  final Widget child;
  const GlowBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned(top: -160, left: -110, child: _orb(AppColors.primary, 420)),
        Positioned(bottom: -140, right: -150, child: _orb(AppColors.secondary, 520)),
        Positioned(top: MediaQuery.of(context).size.height * 0.35, right: -120, child: _orb(AppColors.primary, 300)),
        child,
      ],
    );
  }

  Widget _orb(Color color, double size) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.0)], stops: const [0.0, 1.0]),
        ),
      ),
    );
  }
}

/// خلفية متوهّجة تملأ الشاشة (تُوضع كـ Positioned.fill داخل Stack).
class GlowBackgroundStatic extends StatelessWidget {
  const GlowBackgroundStatic({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(top: -160, left: -110, child: _orb(AppColors.primary, 420)),
            Positioned(bottom: -140, right: -150, child: _orb(AppColors.secondary, 520)),
          ],
        ),
      ),
    );
  }

  Widget _orb(Color color, double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color.withValues(alpha: 0.14), color.withValues(alpha: 0.0)]),
        ),
      );
}

/// شريط علوي زجاجي بسيط مع زر رجوع وعنوان واختياري إجراء.
class GlassBar extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final Widget? action;
  const GlassBar({super.key, required this.title, this.subtitle, this.showBack = true, this.action});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, bottom: 16, left: 18, right: 18),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite.withValues(alpha: 0.96),
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (showBack)
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.maybePop(context),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
                child: Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary, size: 22),
              ),
            ),
          if (showBack) const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary)),
                ],
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

/// عنوان قسم أنيق.
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  const SectionHeader(this.title, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 5, height: 22, decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(8))),
              const SizedBox(width: 10),
              Text(title, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            ],
          ),
          if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// شريحة معلومة صغيرة (Pill).
class InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const InfoPill(this.icon, this.label, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14), border: Border.all(color: c.withValues(alpha: 0.18))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: c)),
        ],
      ),
    );
  }
}

/// بطاقة ميزة كبيرة بتدرّج لوني (تُستخدم في الرئيسية).
class FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  const FeatureCard({super.key, required this.title, required this.subtitle, required this.icon, required this.gradient, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: gradient, begin: Alignment.topRight, end: Alignment.bottomLeft),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [BoxShadow(color: gradient.last.withValues(alpha: 0.35), blurRadius: 22, offset: const Offset(0, 12))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(16)),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                Icon(Icons.arrow_outward_rounded, color: Colors.white.withValues(alpha: 0.9), size: 20),
              ],
            ),
            const SizedBox(height: 18),
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
            const SizedBox(height: 4),
            Text(subtitle, style: TextStyle(fontSize: 11.5, height: 1.4, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.92))),
          ],
        ),
      ),
    );
  }
}

/// زر أساسي بتدرّج (Primary CTA).
class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final double height;
  const GradientButton({super.key, required this.label, this.icon, required this.onTap, this.height = 56});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(gradient: AppColors.mainGradient, borderRadius: BorderRadius.circular(20), boxShadow: AppColors.softShadow),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[Icon(icon, color: Colors.white, size: 20), const SizedBox(width: 10)],
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// بطاقة بيضاء بسيطة بظل ناعم.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SoftCard({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(24),
        // 🌙 الحدّ لا الظلّ: على خلفية داكنة الظلّ غير مرئي، فبدونه
        //    تفقد البطاقة حدَّها وتذوب الشاشة في لوحٍ واحد.
        border: AppColors.cardBorder,
        boxShadow: AppColors.bubbleShadow,
      ),
      child: child,
    );
  }
}
