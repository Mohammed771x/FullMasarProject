import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../../../core/widgets/quota_badge.dart';
import '../controllers/chat_controller.dart';

// ==========================================
// 🪟 شريط قسم التعليم
// ==========================================
// 🎨 **تصميم Figma** — «الرفيق الذاكي» (390:2048) · إحداثيات مطلقة:
//    الشريط (24,74) 342×50 · زرّ المصباح (24,79) 40×40 r16 أبيض بحدّ
//    `#E2E8F0` · العنوان (156,86) 14/w700 `#091E42` في الوسط ·
//    وزرّ القائمة (326,79) 40×40 في اليمين.
//
// 🔄 **ما تغيّر:** كان شريطاً زجاجياً عريضاً بعنوانٍ وسطر «بوصلة» تحته.
//    صار شريطاً نظيفاً بزرّين وعنوانٍ واحد — والبوصلةُ انتقلت إلى لوحة
//    إعدادات الجلسة حيث تُختار أصلاً.
//
// ✅ **وما أُبقي:** زرّ التعليمات (المصباح) و**شارة الحصة** — غائبةٌ عن
//    التصميم، وهي معلومةٌ يحتاجها الطالب قبل أن يكتب لا بعد أن يُرفض.
//    وُضعت تحت العنوان بحجمٍ صغير فلا تزاحم الشريط.
class ChatGlassAppBar extends StatelessWidget {
  const ChatGlassAppBar({
    super.key,
    required this.controller,
    required this.onMenu,
    required this.onHelp,
  });

  final ChatController controller;
  final VoidCallback onMenu;
  final VoidCallback onHelp;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.bgLight,
      padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 8,
          bottom: 8,
          left: 24,
          right: 24),
      child: SizedBox(
        height: 50,
        child: Row(
          children: [
            // 📐 ترتيب RTL: القائمة أولاً (يمين) والمصباح أخيراً (يسار).
            _SquareButton(icon: PD.textAlignJustify, onTap: onMenu),
            const Spacer(),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  // 🎨 «مساعد المعلم الذكي» حرفاً كما في تصدير قسم المعلم.
                  controller.isTeacher
                      ? "مساعد المعلم الذكي"
                      : "مسار الطالب",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.brandInk),
                ),
                // 🎟️ شارة الحصة — صغيرةٌ تحت العنوان.
                const SizedBox(height: 2),
                const QuotaBadge(compact: true),
              ],
            ),
            const Spacer(),
            _SquareButton(icon: PD.lightbulbFilament, onTap: onHelp),
          ],
        ),
      ),
    );
  }
}

/// زرٌّ مربّع 40×40 r16 — مواصفات التصميم.
class _SquareButton extends StatelessWidget {
  const _SquareButton({required this.icon, required this.onTap});

  /// 🎨 **ثنائيّةُ اللون كما في التصميم** — قِستُ التصدير مكبّراً فوجدتُ
  /// داخلَ المصباح رماديّاً فاتحاً وخلفَ خطوط القائمة لوحاً باهتاً؛ وهو
  /// نمطُ Phosphor `Duotone` لا `fill`. و**فتيلةُ** المصباح
  /// (`LightbulbFilament`) لا المصباحُ الساذج: في التصدير خطٌّ على هيئة Y.
  final PDIcon icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.rowBorder),
            ),
            child: Center(
              child: PDuo(icon, size: 20, color: AppColors.primary990Ink),
            ),
          ),
        ),
      );
}
