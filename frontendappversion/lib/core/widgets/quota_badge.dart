import 'package:flutter/material.dart';

import '../quota/quota_repository.dart';
import '../theme/app_colors.dart';

// ==========================================
// 🎟️ شارة الحصة — «متبقٍّ لك ١٧ سؤالاً»
// ==========================================
// 🔴 **ما كانت تعالجه:** الطالب يذاكر بلا أي مؤشّر، ثم يُمنع فجأةً في
//    منتصف درسه. الرقم كان محسوباً في الخادم منذ البداية ولا شاشةَ تعرضه.
//
// 🎨 **ثلاث حالات لونية عمداً** — والشارة ليست زينة بل إنذارٌ متدرّج:
//    • عادية (> ٢٠٪)  ← رمادية هادئة، لا تسرق الانتباه من المحادثة
//    • منخفضة (≤ ٢٠٪) ← برتقالية: «وزّع ما تبقّى»
//    • نافدة          ← حمراء: هنا يعرف **لماذا** توقف قبل أن يجرّب
//    والعتبة **نسبية لا رقمية**: حدُّ الزائر خمسة وحدُّ الطالب خمسون،
//    فـ«باقٍ ٥» تحذيرٌ للثاني وحالةٌ طبيعية تماماً للأول.
//
// 👻 وتختفي تماماً قبل وصول أول قراءة: صفرٌ مؤقّتٌ أسوأ من لا شيء.
class QuotaBadge extends StatelessWidget {
  const QuotaBadge({super.key, this.compact = false});

  /// النسخة المصغّرة (شريط علوي ضيّق): رقمٌ وأيقونة بلا كلمات.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: QuotaRepository.I,
      builder: (context, _) {
        final q = QuotaRepository.I.status;
        if (!q.isKnown) return const SizedBox.shrink();

        final Color tint = q.isExhausted
            ? Colors.redAccent
            : q.isLow
                ? Colors.orange
                : AppColors.textSecondary;

        return Semantics(
          // ♿ قارئ الشاشة يقرأ جملةً مفهومة لا رقماً عائماً بلا سياق.
          //
          // ⚠️ `container` و`excludeSemantics` كلاهما لازم: بدونهما يبقى
          //    نصُّ الشارة الخام («17») عقدةً مستقلة بجانب الوصف، فيسمع
          //    الطالب الرقم مرتين — مرةً بلا أي سياق.
          container: true,
          excludeSemantics: true,
          label: q.isExhausted
              ? "انتهت أسئلتك"
              : "متبقٍّ ${q.remaining} من ${q.limit} أسئلة",
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10, vertical: compact ? 3 : 5),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  q.isExhausted
                      ? Icons.hourglass_disabled_rounded
                      : Icons.bolt_rounded,
                  size: compact ? 12 : 14,
                  color: tint,
                ),
                const SizedBox(width: 3),
                Text(
                  compact ? "${q.remaining}" : "${q.remaining} سؤالاً",
                  style: TextStyle(
                    fontSize: compact ? 10.5 : 11.5,
                    fontWeight: FontWeight.w800,
                    color: tint,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
