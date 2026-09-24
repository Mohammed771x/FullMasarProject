import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'masar_brand.dart';

// ==========================================
// 🤖 ترحيبُ المحادثة الفارغة — روبوتٌ فوق الكلام مباشرةً
// ==========================================
// 🎨 **تصميم Figma** — `design/06-scholarships/05-الرفيق الذاكي` (@2x على
//    لوح 390): الروبوتُ ١٠٥ عرضاً، وتحته **مباشرةً** العنوانُ ١٨/w900 في
//    سطرين إن طال، ثم فقرةٌ ١٢٫٥ وسطيّةٌ **بعرض الشاشة** لا عمودٌ ضيّق.
//
// 🎯 **قرار المالك (٢٠٢٦-٠٩-٢٤):** «الروبوت بعيد من الكتابة… خلّه زي المنح،
//    متناسق مع الكلام، فوق الكلام — في كل الأماكن. متحرك بس قرّبه». فكان
//    بين الروبوت والعنوان فراغان: هالةٌ ١٩٠ حوله، وصندوقُ حركةٍ ١١٨٪ من
//    عرضه — أُزيلا. ثم قال: «لا تحرّك الروبوت، خلّه ثابت مال المنح بالضبط».
//
// 🔁 **واحدٌ للأقسام الثلاثة** (التعليم · المعلّم · المنح) — النصُّ وحده يختلف.
class ChatWelcomeHero extends StatelessWidget {
  const ChatWelcomeHero({
    super.key,
    required this.title,
    required this.body,
    this.tag,
  });

  final String title;
  final String body;

  /// 🏷️ سطرٌ صغيرٌ خافتٌ تحت العنوان — «فيزياء · تلخيص». **صغيرٌ عمداً**
  ///    (قرار المالك: «ما في داعي فيزياء تلخيص كذا كبير — صغّره»).
  final String? tag;

  /// 📏 من التصدير: ٢١٠ بكسلة عند ٢× ⇒ ١٠٥.
  static const double robotWidth = 105;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 🧍 **ثابتٌ لا يتحرّك** — كتصميم المنح حرفاً (قرار المالك).
        const MasarRobot(size: robotWidth, pose: MasarRobotPose.fly),
        const SizedBox(height: 14),
        Text(title,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 18,
                height: 1.6,
                fontWeight: FontWeight.w900,
                color: AppColors.headingInk)),
        if (tag != null) ...[
          const SizedBox(height: 2),
          Text(tag!,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.cardHint)),
        ],
        const SizedBox(height: 10),
        Text(body,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5,
                height: 1.85,
                fontWeight: FontWeight.w600,
                color: AppColors.chipInk)),
      ],
    );
  }
}
