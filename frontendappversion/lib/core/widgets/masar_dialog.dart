import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'phosphor.dart';

// ==========================================
// 🪟 نافذةٌ بمواصفات Figma — قالبٌ واحد لحوارات التطبيق
// ==========================================
// 🎨 **مقيسةٌ من ثلاثة تصاميم** في `design/03-home/`:
//    `18` حذف المحادثة · `19` تعديل أسم المحادثة · `20` دليل الاستخدام.
//    وهي متّفقةٌ على شكلٍ واحد:
//
//      اللوح : أبيض · r26 · حشوة 20 · ظلٌّ خفيف
//      الرأس : **مربّعُ أيقونةٍ 48 r14 بتعبئةٍ ملوّنة** في بداية السطر
//              (يمين RTL) · ثم العنوان 17/w900 `#15294B`
//              · وزرُّ `×` دائريٌّ 36 في نهايته (حين يُطلب)
//      الأفعال: زرٌّ ممتلئٌ 46 r14 في **نهاية** السطر (يسار RTL)
//               وإلى يمينه «إلغاء» نصّاً — أو زرٌّ واحدٌ بعرض اللوح.
//
// ⭐ **قالبٌ لا نسخ:** الثلاثةُ كانت `AlertDialog` بمقاساتٍ من عهدٍ سابق
//    (r28 · تدرّجات · أيقونات Material)، ونسخُ اللغة الجديدة في كلٍّ منها
//    يعني افتراقَها عند أول تعديل.
class MasarDialog extends StatelessWidget {
  const MasarDialog({
    super.key,
    required this.icon,
    required this.title,
    required this.child,
    required this.primaryLabel,
    this.iconTint,
    this.iconInk,
    this.subtitle,
    this.onPrimary,
    this.primaryColor,
    this.cancelLabel,
    this.fullWidthAction = false,
    this.closable = false,
    this.divider = false,
  });

  /// أيقونةُ الرأس — ثنائيةُ اللون كما في رأس شاشة المحادثة.
  final PDIcon icon;

  /// تعبئةُ مربّع الأيقونة وحبرُها — الافتراضُ أزرقُ الهوية.
  final Color? iconTint;
  final Color? iconInk;

  final String title;

  /// سطرٌ صغيرٌ تحت العنوان: النطاق («الثالث · علمي») أو وصفٌ قصير.
  final String? subtitle;

  final Widget child;

  final String primaryLabel;

  /// لونُ الزرّ الممتلئ — أحمرُ للحذف، أزرقُ لما عداه.
  final Color? primaryColor;

  /// ما يُنفَّذ قبل الإغلاق — والإغلاقُ يقع دائماً.
  final Future<void> Function()? onPrimary;

  /// نصُّ زرّ التراجع — يغيب إن كان الفعلُ واحداً لا خيار فيه.
  final String? cancelLabel;

  /// زرٌّ واحدٌ بعرض اللوح (دليل الاستخدام) بدل صفِّ زرَّين.
  final bool fullWidthAction;

  /// زرُّ `×` في نهاية الرأس.
  final bool closable;

  /// خطٌّ فاصلٌ تحت الرأس (دليل الاستخدام وحده في التصميم).
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final Color fill = primaryColor ?? AppColors.primaryFill;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: AppColors.rowBorder),
          boxShadow: AppColors.softShadow,
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ══════ الرأس ══════
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: iconTint ?? AppColors.primaryTintSurface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: PDuo(icon,
                      size: 24, color: iconInk ?? AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: AppColors.panelTitle)),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary)),
                      ],
                    ],
                  ),
                ),
                if (closable)
                  Material(
                    color: AppColors.fieldFill,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.pop(context),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Icon(PI.x.bold,
                            size: 16, color: AppColors.chipInk),
                      ),
                    ),
                  ),
              ],
            ),
            if (divider) ...[
              const SizedBox(height: 16),
              Divider(height: 1, thickness: 1, color: AppColors.rowBorder),
            ],
            const SizedBox(height: 16),
            // ══════ الجسم ══════
            // 📏 سقفُه 58% من الشاشة: يبقى الرأسُ والزرُّ مرئيَّين مهما طال
            //    المحتوى — و«دليل الاستخدام» فيه خمسُ بطاقاتٍ وتفاصيلُ مادة.
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.58),
                child: SingleChildScrollView(child: child),
              ),
            ),
            const SizedBox(height: 18),
            // ══════ الأفعال ══════
            if (fullWidthAction)
              SizedBox(height: 47, child: _primaryButton(context, fill))
            else
              Row(
                // ⬅️ في RTL تعني `end` **اليسار** — وهناك يجلس الزرُّ
                //    الممتلئ في التصميم، و«إلغاء» إلى يمينه.
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (cancelLabel != null) ...[
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(cancelLabel!,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: AppColors.chipInk)),
                    ),
                    const SizedBox(width: 8),
                  ],
                  SizedBox(height: 46, child: _primaryButton(context, fill)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _primaryButton(BuildContext context, Color fill) => ElevatedButton(
        onPressed: () async {
          await onPrimary?.call();
          if (context.mounted) Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: fullWidthAction ? 0 : 26),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(fullWidthAction ? 16 : 14)),
        ),
        child: Text(primaryLabel,
            style:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
      );
}

// ══════════════════════════════════════════════════
// 📋 صفٌّ داخل النافذة — بمواصفات صفوف القائمة الجانبية
// ══════════════════════════════════════════════════
class MasarDialogRow extends StatelessWidget {
  const MasarDialogRow({
    super.key,
    required this.child,
    this.onTap,
    this.height = 46,
    this.highlighted = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double height;

  /// صفٌّ مفتوحٌ أو مختار — بلون الهوية الخفيف وحدٍّ أزرق، كما في المواد.
  final bool highlighted;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            constraints: BoxConstraints(minHeight: height),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: highlighted
                  ? AppColors.drawerRowSelected
                  : AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: highlighted
                      ? AppColors.drawerRowSelectedBorder
                      : AppColors.rowBorder),
            ),
            child: child,
          ),
        ),
      );
}
