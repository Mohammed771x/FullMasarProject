import 'package:flutter/widgets.dart';

// ==========================================
// 🔠 سقفُ تكبير خطّ النظام
// ==========================================
// 🔴 **رُئي في المحاكي (فحص ٢٠٢٦-١٠-٠٢):** عند حجم الخط XXXL — حجمٌ عاديّ
//    في إعدادات iOS لا من أحجام الوصول — قُصّ زرّا «ابدأ التعلّم» و«فتح
//    التحليل» وفاضت بطاقاتُ الإحصاء، وعند أكبر أحجام الوصول (×٣) **اختفى
//    الزرّان تماماً** وفاض الشريطُ السفليّ في تبويباته الخمسة.
//
// ⚖️ **السقفُ ×١٫٣ لا إلغاءُ التكبير:** من رفع خطّ نظامه يحصل على تكبيرٍ
//    حقيقيّ حتى ٣٠٪، والواجهةُ مبنيّةٌ لتتّسع له (البطاقاتُ بحدٍّ أدنى لا
//    بارتفاعٍ ثابت). وما فوقه يكسر تصميماً مبنيّاً على شاشة جوّال — والنصُّ
//    الطويل الذي يُقرأ فعلاً (الأجوبة) له مقياسُه داخل التطبيق
//    ([AppSettings.answerFontSize]).
class TextScaleClamp extends StatelessWidget {
  const TextScaleClamp({super.key, required this.child});

  final Widget child;

  /// أقصى مقياسٍ لخطّ النظام داخل التطبيق.
  static const double maxScale = 1.3;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: maxScale,
        child: child,
      );
}
