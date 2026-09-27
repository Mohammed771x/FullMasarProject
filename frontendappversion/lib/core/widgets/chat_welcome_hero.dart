import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'masar_brand.dart';
import 'masar_character.dart';

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
//    ثم (٢٠٢٦-٠٩-٢٧) بعد عمامة الهوية: «خلّيه يتحرّك كذا شويّة» ⇒ [_GentleFloat].
//
// 🔁 **واحدٌ للأقسام الثلاثة** (التعليم · المعلّم · المنح) — النصُّ يختلف،
//    والروبوتُ كما في Figma لكل قسم (قرار المالك ٢٠٢٦-٠٩-٢٧): التعليم الطائرُ
//    [MasarRobotPose.fly]، والمنح [MasarCharacter.guide] (قبّعةُ التخرّج والكتب)،
//    والمعلّم [MasarCharacter.teach] (اللوح والكتاب) — كلُّها بزيّ «هلا».
class ChatWelcomeHero extends StatelessWidget {
  const ChatWelcomeHero({
    super.key,
    required this.title,
    required this.body,
    this.tag,
    this.character,
  });

  /// 🤖 شخصيةٌ كاملة (تطفو وترمش) بدل الروبوت الطائر — انظر رأس الملف.
  final MasarCharacter? character;

  /// 📏 ارتفاعُ الشخصية الكاملة — إطارُ Figma في «مساعد المنحة» ٢٨٢×٢٣٢.
  static const double characterHeight = 200;

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
        // 🫧 **يطفو بهدوء** (قرار المالك ٢٠٢٦-٠٩-٢٧: «خلّيه يتحرّك كذا شويّة»)
        //    — إزاحةٌ رأسية ±3 فقط: لا هالة ولا تكبير، فلا يبتعد عن الكلام
        //    ولا يتغيّر مكانُه في التخطيط (قرارُه ٠٩-٢٤ بالقرب باقٍ).
        if (character case final c?)
          SizedBox(
            width: characterHeight * c.aspect / 0.9,
            height: characterHeight / 0.9,
            child: MasarCharacterView(character: c),
          )
        else
          const _GentleFloat(
            child: MasarRobot(size: robotWidth, pose: MasarRobotPose.fly),
          ),
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

/// 🫧 طفوٌ رأسيٌّ خفيف (±3 كل ٣٫٦ ث) — تحويلٌ لا يمسّ التخطيط.
/// ♿ «تقليل الحركة» ⇒ ساكن.
class _GentleFloat extends StatefulWidget {
  const _GentleFloat({required this.child});
  final Widget child;

  @override
  State<_GentleFloat> createState() => _GentleFloatState();
}

class _GentleFloatState extends State<_GentleFloat>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _c.stop();
      _c.value = 0.5;
    } else if (!_c.isAnimating) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 3 - 6 * Curves.easeInOut.transform(_c.value)),
          child: child,
        ),
        child: widget.child,
      );
}
