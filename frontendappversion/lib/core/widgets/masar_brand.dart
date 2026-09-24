import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

// ==========================================
// 📖 هوية مسار — الشعار الرسمي من assets
// ==========================================
/// ⚠️ **ثابتٌ للأسطح البيضاء دائماً** (كصفيحة الشعار). وللنصّ الذي يجلس
///    على سطحٍ يتبع الوضع استعمل [AppColors.brandInk] — هذا يختفي هناك.
///
/// 🎨 حُدِّثا إلى لوحة Figma: `#173A6D` ← `#091E42`، و`#3B82F6→#1D4ED8`
///    ← درجتا الهوية الجديدة. الاسمان باقيان كي لا تنكسر مواضع استعمالهما.
const Color kNavy = AppColors.inkB900;
const List<Color> kBlueBtn = [AppColors.primary500, AppColors.primary700];

/// 🌀 **لون العلامة الحلزونية** كما هي في ملف الشعار — يُستعمل حين تُرسم
///    العلامة أيقونةً مسطّحة بدل الصورة.
const Color kMarkBlue = Color(0xFF2B1FE8);

/// شعار مسار الرسمي (assets/icon/icon.png).
/// يستبدل الشعار المرسوم بالكود الذي كان في الديمو.
class MasarLogo extends StatelessWidget {
  final double size;
  const MasarLogo({super.key, this.size = 104});

  @override
  Widget build(BuildContext context) {
    // الشعار بخلفية بيضاء أصلاً — نضعه داخل بطاقة دائرية الأطراف
    // حتى لا تظهر حوافه كمربّع حاد فوق خلفية الشاشة.
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.06),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(color: kNavy.withValues(alpha: 0.10), blurRadius: size * 0.22, offset: Offset(0, size * 0.06)),
        ],
      ),
      child: Image.asset(
        // 🌀 شعار المصمّم الجديد (العلامة الحلزونية وحدها). `icon.png` يبقى
        //    أيقونةَ المشغّل ولا يُلمس — وهذا أصلٌ منفصل للواجهة.
        'assets/brand/logo_mark.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        // احتياط: لو فشل تحميل الصورة لا تنكسر الشاشة.
        errorBuilder: (_, _, _) => Icon(Icons.auto_stories_rounded, size: size * 0.7, color: kMarkBlue),
      ),
    );
  }
}

// ==========================================
// 🤖 روبوت مسار — شخصية التطبيق
// ==========================================
/// نسختا الروبوت في تصميم Figma.
///
/// ⛔ **حلّ محلّ `RobotWidget` المرسوم بالكود** بحالاته الأربع
///    (`wave` · `idle` · `think` · `point`) — قرار المالك 2026-09-20.
///
/// 📌 **مؤقّت بالتصميم لا بالبنية:** الشخصية ستُعدَّل لاحقاً، واستبدالها
///    يجب أن يكون **تبديلَ ملفَي صورة** لا إعادةَ كتابة شاشات — ولذلك
///    تمرّ كل المواضع من هنا ولا تستدعي `Image.asset` مباشرةً.
enum MasarRobotPose {
  /// الوجه الأمامي — الترحيب · زرّ التنقّل · شاشة التأكيد.
  face,

  /// يطير بهالة — بطاقة التعليم · التسجيل · شاشات التحميل.
  fly,
}

class MasarRobot extends StatelessWidget {
  const MasarRobot({super.key, this.size = 137, this.pose = MasarRobotPose.face});

  final double size;
  final MasarRobotPose pose;

  @override
  Widget build(BuildContext context) => Image.asset(
        switch (pose) {
          MasarRobotPose.face => 'assets/brand/robot_face.png',
          MasarRobotPose.fly => 'assets/brand/robot_fly.png',
        },
        width: size,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        // احتياط: لو فشل تحميل الصورة لا تنكسر الشاشة ولا تترك فراغاً.
        errorBuilder: (_, _, _) => Icon(Icons.smart_toy_rounded,
            size: size * 0.7, color: AppColors.primary),
      );
}

// ==========================================
// 🤖✨ روبوتٌ يتحرّك — لشاشات الانتظار
// ==========================================
/// **يطفو ويتنفّس هالتُه** بينما يُجهَّز شيءٌ للطالب.
///
/// 🎯 طلبُ المالك (2026-09-20): «لما جاهز تجهيز أسئلتك، خلّي الروبوت
///    يتحرّك». والانتظارُ في «اختبر نفسك» ثوانٍ يقضيها الطالب أمام صورةٍ
///    ساكنة، فيظنّ التطبيقَ متجمّداً.
///
/// 🔒 **الصورةُ لا تُمسّ.** الحركةُ كلُّها تحويلاتٌ فوق [MasarRobot] —
///    إزاحةٌ رأسية وهالةٌ مرسومةٌ خلفه — كي يبقى استبدالُ الشخصية
///    **تبديلَ ملفٍّ** كما نصّ عليه [MasarRobot] نفسه.
///
/// ♿ ويحترم «تقليل الحركة» في إعدادات النظام: يعود صورةً ساكنة، فلا
///    يدوخ من طلب ألّا يتحرّك شيء.
class MasarRobotAnimated extends StatefulWidget {
  const MasarRobotAnimated({
    super.key,
    this.size = 120,
    this.pose = MasarRobotPose.fly,
    this.tight = false,
  });

  final double size;
  final MasarRobotPose pose;

  /// 📏 **صندوقٌ بقدر الصورة** (+ مدى الطفو) لا ١١٨٪ من العرض — صورةُ
  ///    الطيران ٥١٢×٤٠٠ فارتفاعُها ٧٨٪ من عرضها، والصندوقُ الواسع يترك فوقها
  ///    وتحتها فراغاً يُبعدها عن الكلام. (قرار المالك ٢٠٢٦-٠٩-٢٤: «الروبوت
  ///    بعيد من الكتابة — قرّبه كما في تصميم المنح».)
  final bool tight;

  @override
  State<MasarRobotAnimated> createState() => _MasarRobotAnimatedState();
}

class _MasarRobotAnimatedState extends State<MasarRobotAnimated>
    with TickerProviderStateMixin {
  /// الطفو — دورةٌ بطيئة صعوداً وهبوطاً.
  late final AnimationController _float;

  /// نبضُ الهالة — أسرعُ قليلاً كي لا يتزامن الاثنان فيبدوا حركةً واحدة.
  late final AnimationController _halo;

  // 🔴 **ولماذا في `initState` لا في `late final … = …`؟** المُهيّئُ الكسول
  //    لا يعمل إلا عند أول قراءة. وحين يطلب النظامُ تسكينَ الحركة لا تُقرأ
  //    المتحكّمات في البناء أصلاً، فتُقرأ **أوّلَ مرّة داخل `dispose`** —
  //    فيُنشأ `Ticker` على عنصرٍ مُبطَل ويُرمى:
  //    «Looking up a deactivated widget's ancestor is unsafe».
  //    (سقط فعلاً في `test/masar_robot_animated_test.dart`.)
  @override
  void initState() {
    super.initState();
    _float = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    _halo = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1700));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ♿ التسكينُ يُوقف المؤقّتات نفسَها لا الرسمَ وحده.
    if (MediaQuery.disableAnimationsOf(context)) {
      _float.stop();
      _halo.stop();
    } else if (!_float.isAnimating) {
      _float.repeat(reverse: true);
      _halo.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _halo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final robot = MasarRobot(size: widget.size, pose: widget.pose);
    final lift = widget.size * 0.055; // ±٥٫٥٪ — يُرى ولا يقفز
    final boxHeight = widget.tight
        ? widget.size * (widget.pose == MasarRobotPose.fly ? 0.78 : 1.0) +
            2 * lift
        : widget.size * 1.18;

    // ♿ لا حركةَ إن طلب النظامُ ذلك — ولا حتى مؤقّتاتٍ تدور بلا فائدة.
    if (MediaQuery.disableAnimationsOf(context)) {
      return SizedBox(height: boxHeight, child: Center(child: robot));
    }

    return SizedBox(
      height: boxHeight,
      child: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_float, _halo]),
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_float.value);
            final h = Curves.easeInOut.transform(_halo.value);
            return Stack(
              alignment: Alignment.center,
              children: [
                // 🌀 هالةٌ تتنفّس خلفه — بلون الهوية، فتذوب في الوضعين.
                Opacity(
                  opacity: 0.16 + 0.16 * h,
                  child: Container(
                    width: widget.size * (0.78 + 0.16 * h),
                    height: widget.size * (0.78 + 0.16 * h),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0),
                      ]),
                    ),
                  ),
                ),
                Transform.translate(
                    offset: Offset(0, lift - 2 * lift * t), child: child),
              ],
            );
          },
          child: robot,
        ),
      ),
    );
  }
}

/// الشعار + الاسم + الشعار النصي — كتلة واحدة للسبلاش والتوثيق.
class MasarBrand extends StatelessWidget {
  final double logoSize;
  final double titleSize;
  final bool showTagline;
  /// ⛔ **ليس `const` عمداً.** ألوانه تُقرأ من [AppColors] وقت البناء،
  /// و`MasarBrand()` تجعل فلاتر تتخطّى إعادة بنائه — فيبقى «مسار»
  /// بحبر الوضع السابق: نصٌّ فاتحٌ على صفحةٍ بيضاء بعد التبديل.
  /// منعُ `const` في المُنشئ ضمانٌ وقت الترجمة لا تذكّرٌ من المطوّر.
  // ignore: prefer_const_constructors_in_immutables  ← مقصود، انظر أعلاه
  MasarBrand({super.key, this.logoSize = 96, this.titleSize = 32, this.showTagline = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MasarLogo(size: logoSize),
        SizedBox(height: logoSize * 0.06),
        // 🖋️ حبرٌ يتبع الوضع: الاسم على خلفية الصفحة لا على صفيحة الشعار.
        Text("مسار", style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w900, color: AppColors.brandInk, letterSpacing: 1)),
        if (showTagline) ...[
          const SizedBox(height: 4),
          Text("سفير الطالب اليمني 🇾🇪", style: TextStyle(fontSize: titleSize * 0.4, fontWeight: FontWeight.w800, color: AppColors.brandInk)),
        ],
      ],
    );
  }
}

// خلفية موجية ناعمة (السبلاش والتوثيق والترحيب)
class SoftWaveBackground extends StatelessWidget {
  /// ⛔ **ليس `const`** — للسبب نفسه: لونا الموجة يتبعان الوضع.
  // ignore: prefer_const_constructors_in_immutables  ← مقصود، انظر أعلاه
  SoftWaveBackground({super.key});
  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.infinite,
        // ⚠️ اللونان يُلتقطان **وقت البناء** ويُمرَّران للرسّام: قراءتُهما
        //    داخل `paint` تجعل `shouldRepaint` عاجزاً عن ملاحظة تبدّل الوضع.
        painter: _WavePainter(tint: AppColors.waveTint, glow: AppColors.waveGlow),
      );
}

class _WavePainter extends CustomPainter {
  const _WavePainter({required this.tint, required this.glow});
  final Color tint;
  final Color glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = tint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < 3; i++) {
      final dy = h * 0.72 + i * 26;
      final path = Path()
        ..moveTo(0, dy)
        ..cubicTo(w * 0.25, dy - 40, w * 0.55, dy + 40, w, dy - 10);
      canvas.drawPath(path, paint);
    }
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [glow, glow.withValues(alpha: 0.0)],
      ).createShader(Rect.fromCircle(center: Offset(w * 0.9, h * 0.12), radius: w * 0.4));
    canvas.drawCircle(Offset(w * 0.9, h * 0.12), w * 0.4, glowPaint);
  }

  /// ⚠️ `false` دائماً كان يعني خلفيةً لا تتبدّل مع الوضع: يُبدّل الطالب
  ///    الوضعَ فتبقى الموجة بلون الوضع السابق حتى يُعاد فتح الشاشة.
  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.tint != tint || old.glow != glow;
}
