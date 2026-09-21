import 'package:flutter/material.dart';
import '../widgets/phosphor.dart';

import '../theme/app_colors.dart';
import '../widgets/masar_brand.dart';

// ==========================================
// 🧭 شريط التنقّل السفلي
// ==========================================
// 🎨 **تصميم Figma** — «الرئيسية» (24:21174) · إحداثيات مطلقة:
//    الشريط (0,767) 390×77 · تعبئة `#E6F4FF` · زواياه العليا r26.
//    خمسة أزرار بعرض 78 لكل واحد:
//      (312) الرئيسية · (234) اختبر نفسك · (156) مسار · (78) المنح · (0) الخدمات
//    الأيقونة 24 عند y=785 · النصّ 12/w700 `#243757` عند y=812.
//    والنشط عليه لوحٌ 64×63 r20 ونصُّه `#0092FF`.
//    وزرّ «مسار» **يعلو الشريط**: دائرةٌ 47×46 عند y=751 — أي 16 فوق حافّته.
//
// ⭐ **الشريط جديدٌ كلياً على التطبيق**: كان التنقّل ببطاقاتٍ في الرئيسية
//    و`Navigator.push`. وهو يظهر في التصميم على **الرئيسية · اختبر نفسك ·
//    المنح · معلومات الطالب** — وغائبٌ عن شاشة المحادثة عمداً، فهي تُفتح
//    ملءَ الشاشة من زرّ «مسار» الأوسط.

/// أقسام الشريط — الترتيب من **يمين** الشاشة إلى يسارها.
enum MasarTab { home, quiz, tutor, scholarships, services }

class MasarBottomNav extends StatelessWidget {
  const MasarBottomNav({
    super.key,
    required this.current,
    required this.onTap,
    this.lockedHint,
  });

  final MasarTab current;
  final ValueChanged<MasarTab> onTap;

  /// أقسامٌ تُعرض «قريباً» — يقرّرها الخادم عبر `AccessRepository`.
  final Set<MasarTab>? lockedHint;

  static const double barHeight = 77;

  /// كم يعلو زرُّ «مسار» فوق حافّة الشريط (من التصميم: 767 ← 751).
  static const double tutorLift = 16;

  @override
  Widget build(BuildContext context) {
    // 📱 مساحة مؤشّر الشاشة أسفل الجهاز تُضاف تحت الشريط لا داخله —
    //    وإلا ارتفعت الأيقونات عن مواضعها في التصميم على أجهزة الحافّة.
    final safe = MediaQuery.viewPaddingOf(context).bottom;
    return SizedBox(
      height: barHeight + safe + tutorLift,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            height: barHeight + safe,
            padding: EdgeInsets.only(bottom: safe),
            decoration: BoxDecoration(
              color: AppColors.navSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
              border: Border(top: BorderSide(color: AppColors.navBorder)),
            ),
            child: Row(
              children: [
                // 🎯 **أيقونات المصمّم نفسها** — `Phosphor`، وهي المكتبة
                //    التي بنى بها الملفَ (أسماء العقد: `CloudCheck`،
                //    `AirplaneInFlight`، `House`…). والنشط `fill`
                //    والخامل `regular` كما في التصميم.
                _item(MasarTab.home, PI.house, "الرئيسية"),
                _item(MasarTab.quiz, PI.listChecks, "اختبر نفسك"),
                // فراغٌ محجوزٌ لزرّ «مسار» الطافي — لا يُبنى هنا كي يعلو
                // فوق الشريط بلا أن يقصّه.
                const Expanded(child: SizedBox.shrink()),
                _item(MasarTab.scholarships, PI.airplaneInFlight, "المنح"),
                _item(MasarTab.services, PI.cloudCheck, "الخدمات"),
              ],
            ),
          ),
          // 📐 **من أعلى المكدّس لا من أسفله.** ارتفاع المكدّس =
          //    الشريط + المساحة الآمنة + [tutorLift]، فوضعُ الزرّ عند
          //    `top: 0` يجعل رأس الدائرة يعلو حافّةَ الشريط بـ16 بالضبط
          //    كما في التصميم (الشريط 767 والدائرة 751).
          Positioned(top: 0, child: _tutorButton()),
        ],
      ),
    );
  }

  /// دالةُ أيقونة Phosphor: تُعطى النمط فتعيد الأيقونة.
  /// (`PhosphorIcons.house` تُستدعى بنمطٍ لا تُمرَّر كثابت.)
  Widget _item(MasarTab tab, PIcon icon, String label) {
    final active = current == tab;
    final locked = lockedHint?.contains(tab) ?? false;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(tab),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.surfaceWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon(active: active),
                      size: 25,
                      color: active ? AppColors.primary : AppColors.navInk),
                  // 🔒 نقطةٌ صغيرة على القسم الذي أقفلته اللوحة — أوضحُ من
                  //    زرٍّ يبدو عاملاً ثم يرفض حين يُضغط.
                  if (locked)
                    Positioned(
                      right: -3,
                      top: -2,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                            color: AppColors.warning600,
                            shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3),
              Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.visible,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: active ? AppColors.primary : AppColors.navInk,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  /// 🤖 زرّ «مسار» — دائرةٌ 47 تحمل الروبوت وتعلو الشريط.
  Widget _tutorButton() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => onTap(MasarTab.tutor),
              customBorder: const CircleBorder(),
              child: Container(
                width: 47,
                height: 47,
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.primaryFill,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary500.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: const MasarRobot(size: 43),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text("مسار",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navInk)),
        ],
      );
}
