import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../banners/data/banner_model.dart';
import '../../../banners/presentation/banner_carousel.dart';
import '../../../../core/widgets/fade_in_slide.dart';
import '../../data/demo_data.dart';
import '../widgets/demo_widgets.dart';
import '../../../../core/widgets/screen_tip.dart';

// ==========================================
// 🤝 قسم الخدمات
// ==========================================
class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Column(
            children: [
              const GlassBar(title: "الخدمات 🛠️", subtitle: "نرافقك في كل خطوة"),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
                  children: [
                    // 🎏 بانر القسم — يُدار من لوحة التحكم.
                    BannerCarousel(
                      section: BannerSection.services,
                      onAction: (a, v) => _onBannerAction(context, a, v),
                      height: 120,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF0D9488)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: AppColors.softShadow,
                      ),
                      child: Row(children: [
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                          Text("خدمات مسار", style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                          SizedBox(height: 6),
                          Text("فريقنا يساعدك في ملف تقديمك خطوة بخطوة 🤝", style: TextStyle(color: Colors.white, fontSize: 12.5, height: 1.5, fontWeight: FontWeight.w600)),
                        ])),
                        const Icon(Icons.handshake_rounded, color: Colors.white, size: 44),
                      ]),
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader("خدماتنا"),
                    ...List.generate(demoServices.length, (i) => FadeInSlide(
                          delay: 0.06 * i,
                          child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _card(context, demoServices[i])),
                        )),
                  ],
                ),
              ),
            ],
          ),
          const ScreenTip(screenId: "services", text: "قسم الخدمات 🛠️ فريق مسار يساعدك في سيرتك الذاتية وخطاب الدافع وملف التقديم."),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, ServiceItem s) {
    return InkWell(
      onTap: () => _openSheet(context, s),
      borderRadius: BorderRadius.circular(22),
      child: SoftCard(
        child: Row(children: [
          Container(width: 52, height: 52, decoration: BoxDecoration(color: s.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)), child: Icon(s.icon, color: s.color, size: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              const SizedBox(height: 3),
              Text(s.desc, style: TextStyle(fontSize: 12, height: 1.4, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ]),
          ),
          Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 24),
        ]),
      ),
    );
  }

  void _openSheet(BuildContext context, ServiceItem s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceWhite,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(4)))),
            const SizedBox(height: 18),
            Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: s.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)), child: Icon(s.icon, color: s.color, size: 24)),
              const SizedBox(width: 12),
              Expanded(child: Text(s.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary))),
            ]),
            const SizedBox(height: 16),
            Text(s.fullDesc, style: TextStyle(fontSize: 13.5, height: 1.9, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            const SizedBox(height: 22),
            InkWell(
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text("💬 فتح واتساب: ${s.whatsappMessage} (محاكاة)", style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFF25D366),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(color: const Color(0xFF25D366), borderRadius: BorderRadius.circular(18), boxShadow: [BoxShadow(color: const Color(0xFF25D366).withValues(alpha: 0.35), blurRadius: 14, offset: const Offset(0, 6))]),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.chat_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text("تواصل معنا عبر واتساب", style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
  /// 🎏 وجهة النقر على بانر هذا القسم. البانر هنا داخليّ غالباً، فالوجهات
  /// الخارجة عن القسم تُترك للشاشة الرئيسية بدل فتح شاشات متداخلة بلا نهاية.
  void _onBannerAction(BuildContext context, String action, String value) {
    if (action == "url" || action == "none") return;
    Navigator.pop(context);
  }

}
