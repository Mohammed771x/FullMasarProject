import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

// ==========================================
// 🤖 شخصيات مسار — رسومُ المصمّم المجسّمة من Figma
// ==========================================
/// الأصولُ الأصلية كما رفعها المصمّم (سُحبت عبر `/files/:key/images`
/// بدقّتها الكاملة ~١٣١٢ بكسل بشفافية، ثم قُصّت على حدودها وصُغّرت إلى
/// ٩٦٠ — ثلاثةُ أضعاف أكبر عرضٍ تُرسم به).
///
/// 📕 **المرجع: `design/characters/identity/IDENTITY.md`** — يُقرأ قبل أي شخصيةٍ جديدة.
///
/// 🧕 **الهوية الموحّدة (٢٠٢٦-٠٩-٢٦):** الروبوتُ المعمَّم نفسُه في كل مكان
///    — عمامةٌ بيجٌ بحزامٍ كحليّ ونقوشٍ ذهبيةٍ مطفأة، وتتغيّر الوضعيةُ فقط.
///    **المرجعُ ألوانُ شخصية «مرحباً» (`hello`) كما رسمها المصمّم — لا تُمسّ.**
///    والبقيّة تُطابَق عليها (`design/characters/tools/match_palette.py`):
///    نقلُ لونٍ في فضاء Lab **لكل عائلةٍ على حدة** — البيج · النقوش · الكحلي
///    — والأدواتُ في اليد مستثناة. ورأسُ البداية (كان حزامُه أحمر ونقشُه
///    آخر) صار يُقصّ من «مرحباً» نفسِها بدل أن يُلوَّن.
///    ⚠️ لا يُعاد التلوين بإزاحة الصبغة: الذهبيُّ جارُ البرتقاليّ فيُطفأ
///    معه (وقع ٢٠٢٦-٠٩-٢٦ فعكّر النقوشَ والأزرار والقلم في كل الصور).
///    الأصولُ الخام في `design/characters/originals_v2/`، والجيلُ الأول
///    (روبوتاتٌ بلا عمامة) في `legacy_v1/`.
///
/// 👁️ **لكل شخصيةٍ رقعةُ رمش** (`*_blink.png`): العينان ممسوحتان من
///    الشاشة بملءٍ متدرّج على لون الشاشة المحيط، ومرسومٌ مكانهما خطّا LED
///    مغمضان — **والحاجبان باقيان**. تُوضع فوق الصورة في [patch] (بكسلات
///    الصورة) ويُبدَّل بينهما بتلاشٍ سريع.
enum MasarCharacter {
  /// الرأسُ وحده — **مقصوصٌ من صورة «مرحباً» نفسِها** فعمامتُه هي عمامتُها
  /// نقشاً ولوناً (`design/characters/tools/cut_head.py`). للبداية ولكل
  /// موضعٍ يلزمه رأسٌ بلا جسد (كالإطلالة من خلف الجوّال).
  head('robot_head', Size(960, 945), Rect.fromLTRB(151, 393, 726, 728), null),

  /// يرفع إصبعه مرحّباً — «هلا!».
  hello(
    'robot_hello',
    Size(743, 960),
    Rect.fromLTRB(214, 191, 540, 392),
    Offset(0.414, 0.99),
    bubble: Offset(0.16, 0.13),
  ),

  /// علامةُ «تمام» ولوحُ مهامٍّ مؤشَّر — للشرح والتلخيص والتدريب.
  ask(
    'robot_ask',
    Size(924, 960),
    Rect.fromLTRB(284, 193, 616, 396),
    Offset(0.412, 0.99),
  ),

  /// يحمل قبّعة تخرّجٍ وكتباً — للمنح والاختبارات. **صورةُ المالك نفسُه** بعمامة «هلا»
  ///    (٢٠٢٦-٠٩-٢٧، `originals_v2/guide_owner_2026-09-27.webp`) كما هي، بشفافيّتها.
  guide(
    'robot_guide',
    Size(960, 937),
    Rect.fromLTRB(238, 202, 575, 401),
    Offset(0.441, 0.99),
  ),

  /// 📖 يقرأ في كتابٍ مفتوح ويتّكئ على كومة كتب — ترحيبُ **قسم التعليم** (محادثة
  ///    الطالب). صورةُ المالك نفسُه (٢٠٢٦-٠٩-٢٧، `originals_v2/study_owner_2026-09-27.webp`).
  study(
    'robot_study',
    Size(915, 960),
    Rect.fromLTRB(302, 227, 661, 406),
    Offset(0.376, 0.99),
  ),

  /// 🧑‍🏫 يرفع قلماً وفي يده دفترٌ مفتوح — ترحيبُ **مساعد المعلّم**. **صورةُ المالك
  ///    نفسُه** (٢٠٢٦-٠٩-٢٧، بعمامة «هلا»؛ الأصل `originals_v2/teach_owner_2026-09-27.webp`)
  ///    كما هي بشفافيّتها — ⚠️ لا تُحوَّل إلى RGB: الشفافُ يصير أسودَ.
  teach(
    'robot_teach',
    Size(822, 960),
    Rect.fromLTRB(210, 206, 564, 412),
    Offset(0.491, 0.99),
  ),

  // ── التوثيق (Figma «تسجيل دخول» · «إنشاء حساب» · «اختر دورك» · «نسيت
  //    كلمة المرور» · «تغيير كلمة المرور») — وضعيةٌ لكل شاشة كما رسمها المصمّم.

  /// يحمل جوّالاً عليه نموذجُ الدخول ويشير إليه — «تسجيل الدخول».
  login(
    'robot_login',
    Size(754, 960),
    Rect.fromLTRB(318, 191, 630, 404),
    Offset(0.52, 0.99),
  ),

  /// يحمل جهازاً عليه «إضافة مستخدم» ويشير إليه — «إنشاء حساب».
  signup(
    'robot_signup',
    Size(750, 960),
    Rect.fromLTRB(302, 195, 626, 398),
    Offset(0.5, 0.99),
  ),

  /// بين يديه صورتا طالبٍ ومعلّم — «مرحباً بك في مسار · اختر دورك».
  roles(
    'robot_roles',
    Size(947, 960),
    Rect.fromLTRB(360, 189, 672, 394),
    Offset(0.48, 0.99),
  ),

  /// يشير إلى جهازٍ عليه قفلٌ و«*****» — «نسيت كلمة المرور؟».
  forgot(
    'robot_forgot',
    Size(724, 960),
    Rect.fromLTRB(126, 203, 442, 372),
    Offset(0.407, 0.99),
  ),

  /// يتأمّل قفلاً بسهمَي تجديد وعلامةِ استفهام — بعد إرسال رابط التعيين.
  reset(
    'robot_reset',
    Size(800, 960),
    Rect.fromLTRB(122, 213, 448, 380),
    Offset(0.359, 0.99),
  ),

  /// يحمل بطاقةَ تنزيلٍ **شريطُها يمتلئ حيّاً ثم يرجع** — **روبوتُ الانتظار
  /// المعتمد**: تفعيلُ البريد اليوم، و«اختبر نفسك» (تجهيزُ الأسئلة) لاحقاً
  /// بقرار المالك. الساعةُ الرملية التي رسمها المصمّم أُزيلت («خلّها هادية»).
  /// 🆕 لا روبوت في إطار التحقق عند المصمّم، والتطبيقُ كان يعرض واحداً.
  waiting(
    'robot_waiting',
    Size(956, 960),
    Rect.fromLTRB(202, 213, 552, 422),
    Offset(0.413, 0.99),
    progress: ProgressTrack(Offset(427, 609), Offset(838, 593), 21),
  );

  const MasarCharacter(
    this._name,
    this.pixels,
    this.patch,
    this.ground, {
    this.bubble,
    this.progress,
  });
  final String _name;

  /// أبعادُ الصورة بالبكسل — تحدّد نسبة العرض إلى الارتفاع.
  final Size pixels;

  /// موضعُ رقعة الرمش داخل الصورة، بالبكسل.
  final Rect patch;

  /// رأسُ الدوّامة التي يطفو عليها (نسبةً من العرض والارتفاع) — تحته
  /// يُرسم الظلّ. `null` لروبوتٍ بلا دوّامة: ظلٌّ تحت خصره بقعةٌ لا ظلّ.
  final Offset? ground;

  /// أين يقع رأسُ ذيل فقاعة الكلام (نسبةً من الصورة) — فوق اليد المرفوعة
  /// أو قرب الرأس. `null` ⇒ الفقاعة فوق منتصف الصورة.
  final Offset? bubble;

  /// مجرى شريط تحميلٍ مرسومٍ في الصورة (فارغاً) — يملؤه التطبيق حيّاً.
  final ProgressTrack? progress;

  String get asset => 'assets/characters/$_name.png';
  String get blinkAsset => 'assets/characters/${_name}_blink.png';
  double get aspect => pixels.width / pixels.height;
}

/// 📏 مجرى شريطٍ مائلٍ داخل الصورة، بالبكسل: مركزا طرفَيه المدوّرين ونصفُ قطره.
///
/// ✏️ طلب المالك (٢٠٢٦-٠٩-٢٦) في روبوت الانتظار: «خلّوا شريط الانتظار
///    يمتلئ، وإذا كمل يرجع لورا» — فمُسحت التعبئةُ المرسومة من الصورة
///    (`design/characters/tools/calm_waiting.py`، ومعها الساعةُ الرملية)
///    وصار يملؤها [MasarCharacterView] بتدرّجها الأصليّ نفسِه.
class ProgressTrack {
  const ProgressTrack(this.start, this.end, this.radius);
  final Offset start;
  final Offset end;
  final double radius;
}

/// 🎬 شخصيةٌ حيّة: تحوم، تتمايل، ترمش، تقفز حين تُلمس، وتدخل بارتدادٍ
/// نابض كلما صارت صفحتُها الظاهرة.
///
/// الحركةُ كلّها تحويلاتٌ فوق الصورة (لا إطاراتِ فيديو ولا Lottie):
///   · **الحوم** — صعودٌ وهبوط كل ٣٫٥ ثانية، وميلٌ ±١٫٥° بنصف السرعة، فلا
///     يتزامنان ويبدو الروبوت طافياً لا متأرجحاً كبندول.
///     (المالك ٢٠٢٦-٠٩-٢٦: «خلّوه هادي» — حيٌّ بلا ربشة؛ فخُفّف المدى
///     والهالة، وصار الدخولُ انسياباً لا ارتداداً مطّاطياً.)
///   · **الظلّ والهالة** — ظلٌّ بيضاويّ تحته يصغر حين يرتفع، وهالةٌ زرقاء
///     خلفه تشتدّ معه؛ هما ما يجعل الحوم يُقرأ «طيراناً».
///   · **الرمش** — كل ٢٫٥–٥٫٥ ثانية عشوائياً، ومرّةً من كل أربع رمشتان.
///   · **الدخول** — حين تصبح [active] صحيحة: ينزل قليلاً ويكبر بتجاوزٍ
///     ناعم ثم يرمش — «يستيقظ».
///   · **الكلام** — إن مُرّر [say]: فقاعةٌ تنبثق بعد الدخول وتطفو معه،
///     وتنبثق من جديد مع كل لمسة.
///   · **اللمس** — قفزةٌ صغيرة وهزّة رأس ورمشة، واهتزازٌ خفيف للجهاز.
///
/// ♿ «تقليل الحركة» في النظام يُعيدها صورةً ساكنة ويوقف كل المؤقّتات.
class MasarCharacterView extends StatefulWidget {
  const MasarCharacterView({
    super.key,
    required this.character,
    this.active = true,
    this.say,
  });

  final MasarCharacter character;

  /// ما يقوله في فقاعة («هلا!») — نصٌّ حيّ بخط التطبيق لا مرسومٌ في الصورة.
  final String? say;

  /// الصفحة الظاهرة الآن — انتقالُها إلى `true` يُطلق حركة الدخول.
  final bool active;

  @override
  State<MasarCharacterView> createState() => _MasarCharacterViewState();
}

class _MasarCharacterViewState extends State<MasarCharacterView>
    with TickerProviderStateMixin {
  late final AnimationController _idle; // دورة الحوم والميل (٦ ث)
  late final AnimationController _enter; // الدخول
  late final AnimationController _blink; // رمشة واحدة
  late final AnimationController _hop; // قفزة اللمس
  late final AnimationController _say; // انبثاق الفقاعة
  late final AnimationController _fill; // شريط التحميل: يمتلئ ثم يرجع

  final _rng = math.Random();
  Timer? _blinkTimer;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _idle = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7000),
    );
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
      value: widget.active ? 0 : 1,
    );
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 190),
    );
    _hop = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 720),
    );
    _say = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: widget.active ? 0 : 1,
    );
    // 🐢 بطيءٌ هادئ (المالك: «يمشي بشويّة مش بجم») — دورةٌ من ٨ ثوانٍ.
    _fill = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 8000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    if (_still) {
      _idle.stop();
      _enter.value = 1;
      _say.value = 1;
      _fill.value = 0.5; // ساكنٌ في منتصف الامتلاء — يُقرأ «جارٍ»
      _blinkTimer?.cancel();
    } else if (!_idle.isAnimating) {
      _idle.repeat();
      if (widget.character.progress != null) _fill.repeat();
      if (widget.active && _enter.value == 0) _playEntrance();
      _scheduleBlink();
    }
  }

  @override
  void didUpdateWidget(MasarCharacterView old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active && !_still) _playEntrance();
  }

  void _playEntrance() {
    _say.value = 0;
    _enter.forward(from: 0).whenComplete(() {
      if (!mounted || !widget.active) return;
      _doBlink();
      _say.forward(from: 0);
    });
  }

  void _scheduleBlink() {
    _blinkTimer?.cancel();
    _blinkTimer = Timer(
      Duration(milliseconds: 2500 + _rng.nextInt(3000)),
      () async {
        if (!mounted) return;
        await _doBlink();
        // مرّةً من كل أربع: رمشةٌ ثانية سريعة — تكسر الرتابة.
        if (mounted && _rng.nextInt(4) == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 90));
          if (mounted) await _doBlink();
        }
        if (mounted) _scheduleBlink();
      },
    );
  }

  Future<void> _doBlink() async {
    if (_still || _blink.isAnimating) return;
    await _blink.forward(from: 0).orCancel.catchError((_) {});
    if (mounted) _blink.value = 0;
  }

  void _onTap() {
    if (_still) return;
    HapticFeedback.lightImpact();
    _hop.forward(from: 0);
    _doBlink();
    if (widget.say != null) _say.forward(from: 0.35);
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _idle.dispose();
    _enter.dispose();
    _blink.dispose();
    _hop.dispose();
    _say.dispose();
    _fill.dispose();
    super.dispose();
  }

  /// الفقاعة في موضعها: رأسُ ذيلها عند [MasarCharacter.bubble] من الصورة
  /// التي يبدأ صندوقُها عند ([left], [top]).
  Widget? _bubbleFor(
    MasarCharacter c,
    double w,
    double h,
    double left,
    double top,
  ) {
    final text = widget.say;
    if (text == null) return null;
    final anchor = c.bubble ?? const Offset(0.5, 0.05);
    final v = _say.value;
    // انبثاقٌ من الذيل: يكبر بتجاوزٍ ناعم ويظهر في أوّل ثلثه.
    final scale = Curves.easeOutBack.transform(v);
    final fade = Curves.easeOut.transform((v * 3).clamp(0.0, 1.0));
    return Positioned(
      left: left + w * anchor.dx,
      top: top + h * anchor.dy,
      child: FractionalTranslation(
        // الذيلُ في الربع الأيمن من قاع الفقاعة ⇒ تقع الفقاعةُ فوقه ويساره قليلاً.
        translation: const Offset(-0.72, -1),
        child: Opacity(
          opacity: fade,
          child: Transform.scale(
            scale: 0.4 + 0.6 * scale,
            alignment: const Alignment(0.44, 1),
            child: _SpeechBubble(
              text: text,
              fontSize: (w * 0.085).clamp(16.0, 26.0),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.character;
    return LayoutBuilder(
      builder: (context, box) {
        // 📐 أكبرُ صندوقٍ بنسبة الصورة يسع القيد — ومنه تُحسب رقعة الرمش.
        //    ويُترك ٨٪ من الارتفاع لمدى الحوم والظلّ كي لا يُقصّ شيء.
        final maxW = box.hasBoundedWidth ? box.maxWidth : 300.0;
        final maxH = box.hasBoundedHeight ? box.maxHeight * 0.9 : maxW;
        var w = maxW;
        var h = w / c.aspect;
        if (h > maxH) {
          h = maxH;
          w = h * c.aspect;
        }
        final bh = box.hasBoundedHeight
            ? math.min(box.maxHeight, h / 0.9)
            : h / 0.9;
        final image = _Figure(
          character: c,
          width: w,
          height: h,
          blink: _blink,
          fill: _fill,
        );

        if (_still) {
          return Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [image, ?_bubbleFor(c, w, h, 0, 0)],
            ),
          );
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _onTap,
          child: AnimatedBuilder(
            animation: Listenable.merge([_idle, _enter, _hop, _say]),
            builder: (context, child) {
              final t = _idle.value * 2 * math.pi;
              final bob = math.sin(2 * t); // −١..١ · دورة ٣٫٥ ث
              final lift = h * 0.022;
              final tilt = math.sin(t) * 1.5 * math.pi / 180; // ±١٫٥° · ٧ ث
              final drift = math.cos(t) * w * 0.006;

              // الدخول: نزولٌ قصير + تكبيرٌ بتجاوزٍ ناعم + ظهورٌ متلاشٍ.
              final e = _enter.value;
              final fall = (1 - Curves.easeOutCubic.transform(e)) * -h * 0.08;
              final pop = 0.82 + 0.18 * Curves.easeOutBack.transform(e);
              final fade = Curves.easeOut.transform((e * 2.2).clamp(0.0, 1.0));

              // اللمس: قفزةٌ بقوس جيبيّ + هزّةٌ تخمد.
              final p = _hop.value;
              final hopY = -math.sin(math.pi * p) * h * 0.09;
              final wiggle =
                  math.sin(p * math.pi * 4) * (1 - p) * 7 * math.pi / 180;
              final squash = 1 + math.sin(math.pi * p) * 0.035;

              final y = -lift * bob + fall + hopY;
              // 0 في القاع و1 في القمّة — يقود الظلّ والهالة.
              final height01 = ((-y / (lift + h * 0.09)) + 1) / 2;

              return Opacity(
                opacity: fade,
                child: SizedBox(
                  width: maxW,
                  height: bh,
                  child: Stack(
                    alignment: Alignment.center,
                    clipBehavior: Clip.none,
                    children: [
                      // 🌀 هالةٌ تتنفّس خلفه.
                      Opacity(
                        opacity: (0.07 + 0.07 * height01).clamp(0.0, 1.0),
                        child: Container(
                          width: w * 0.95,
                          height: w * 0.95,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.primary,
                                AppColors.primary.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 🌑 ظلٌّ تحت رأس الدوّامة يصغر ويخفت حين يرتفع.
                      if (c.ground case final g?)
                        Positioned(
                          left: (maxW - w) / 2 + w * g.dx - w * 0.15,
                          top: (bh - h) / 2 + h * g.dy,
                          child: Transform.scale(
                            scale: 1.1 - 0.25 * height01,
                            // بيضاويٌّ ممسوحُ الحوافّ: ظلُّه هو المرئيّ لا جسمُه.
                            child: Container(
                              width: w * 0.30,
                              height: h * 0.022,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.all(
                                  Radius.elliptical(w * 0.15, h * 0.011),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.30 - 0.14 * height01,
                                    ),
                                    blurRadius: h * 0.03,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      Transform.translate(
                        offset: Offset(drift, y),
                        child: Transform.rotate(
                          angle: tilt + wiggle,
                          // المحور قرب القاعدة — يتمايل كجسمٍ طافٍ لا كصورةٍ تدور.
                          alignment: const Alignment(0, 0.6),
                          child: Transform.scale(
                            scaleX: pop / squash,
                            scaleY: pop * squash,
                            alignment: Alignment.bottomCenter,
                            child: child,
                          ),
                        ),
                      ),
                      // 💬 الفقاعة تطفو مع الجسد (نفسُ الإزاحة) لكنها لا
                      //    تميل معه — نصٌّ مائلٌ يُقرأ بصعوبة.
                      ?_bubbleFor(
                        c,
                        w,
                        h,
                        (maxW - w) / 2 + drift,
                        (bh - h) / 2 + y,
                      ),
                    ],
                  ),
                ),
              );
            },
            child: image,
          ),
        );
      },
    );
  }
}

/// الصورة ورقعةُ الرمش فوقها في موضعها بالضبط.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.character,
    required this.width,
    required this.height,
    required this.blink,
    required this.fill,
  });

  final MasarCharacter character;
  final double width;
  final double height;
  final Animation<double> blink;
  final Animation<double> fill;

  @override
  Widget build(BuildContext context) {
    final c = character;
    final k = width / c.pixels.width;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              c.asset,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => Icon(
                Icons.smart_toy_rounded,
                size: height * 0.6,
                color: AppColors.primary,
              ),
            ),
          ),
          Positioned(
            left: c.patch.left * k,
            top: c.patch.top * k,
            width: c.patch.width * k,
            height: c.patch.height * k,
            child: AnimatedBuilder(
              animation: blink,
              builder: (context, child) {
                // مثلّث: يُغمض في الثلث الأول ويبقى لحظة ثم يفتح.
                final v = blink.value;
                final o = v < 0.3
                    ? v / 0.3
                    : v < 0.55
                    ? 1.0
                    : 1 - (v - 0.55) / 0.45;
                return Opacity(opacity: o.clamp(0.0, 1.0), child: child);
              },
              child: Image.asset(
                c.blinkAsset,
                fit: BoxFit.fill,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
          // ⏳ شريطُ التحميل الحيّ — فوق المجرى الفارغ المرسوم في الصورة.
          if (c.progress case final t?)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _ProgressPainter(track: t, scale: k, anim: fill),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// يملأ [ProgressTrack] من طرفه الأيسر (كما رسمه المصمّم) ثم يُفرغه:
///   ٠–٠٫٧٥ يمتلئ بانسياب (٦ ث) · ٠٫٧٥–٠٫٨٥ يبقى ممتلئاً لحظة ·
///   ٠٫٨٥–١ يرجع إلى أوّله بهدوء — ثم يعيد. الدورة ٨ ثوانٍ. تدرّجُه **ألوانُ التعبئة الأصلية
///   مقيسةً من الصورة** (سماويٌّ في الأعلى إلى أزرقَ عميقٍ في الأسفل).
class _ProgressPainter extends CustomPainter {
  _ProgressPainter({
    required this.track,
    required this.scale,
    required this.anim,
  }) : super(repaint: anim);

  final ProgressTrack track;
  final double scale;
  final Animation<double> anim;

  static double level(double t) {
    if (t < 0.75) return Curves.easeInOutSine.transform(t / 0.75);
    if (t < 0.85) return 1;
    return 1 - Curves.easeInOutSine.transform((t - 0.85) / 0.15);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = level(anim.value);
    if (p <= 0.001) return;
    final a = track.start * scale;
    final b = track.end * scale;
    final r = track.radius * scale;
    final d = b - a;
    final len = d.distance;
    canvas.save();
    canvas.translate(a.dx, a.dy);
    canvas.rotate(math.atan2(d.dy, d.dx));
    // من الطرف الأيسر: يبدأ دائرةً ويمتدّ على طول المجرى.
    final rect = Rect.fromLTRB(-r, -r, r + len * p, r);
    final pill = RRect.fromRectAndRadius(rect, Radius.circular(r));
    canvas.drawRRect(
      pill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF05DEFB),
            Color(0xFF00B2FF),
            Color(0xFF0079FB),
            Color(0xFF0257FF),
          ],
          stops: [0.0, 0.35, 0.7, 1.0],
        ).createShader(rect),
    );
    // لمعةٌ رفيعة في الأعلى — كالرسم الأصليّ (حين يطول الشريطُ بما يكفيها).
    if (rect.width > r * 1.5) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(
            rect.left + r * 0.5,
            -r * 0.78,
            rect.right - r * 0.5,
            -r * 0.5,
          ),
          Radius.circular(r),
        ),
        Paint()..color = Colors.white.withValues(alpha: 0.35),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ProgressPainter old) =>
      old.track != track || old.scale != scale || old.anim != anim;
}

/// 💬 فقاعةُ كلامٍ بلغة التصميم: سطحٌ أبيض بزوايا 18 وظلٌّ أزرق خافت،
/// وذيلٌ مثلّثٌ في الربع الأيمن من قاعها يشير إلى المتكلّم.
///
/// ⚠️ لا `const` في مُنشئها استعمالاً — تقرأ [AppColors] فتتبع الوضع الداكن.
class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text, required this.fontSize});
  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final tail = fontSize * 0.55;
    return CustomPaint(
      painter: _BubblePainter(
        fill: AppColors.surfaceWhite,
        stroke: AppColors.primary.withValues(alpha: 0.18),
        shadow: AppColors.primary.withValues(alpha: 0.22),
        tail: tail,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          fontSize * 0.8,
          fontSize * 0.25,
          fontSize * 0.8,
          fontSize * 0.25 + tail,
        ),
        child: Text(
          text,
          textDirection: TextDirection.rtl,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            height: 1.5,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter({
    required this.fill,
    required this.stroke,
    required this.shadow,
    required this.tail,
  });
  final Color fill;
  final Color stroke;
  final Color shadow;
  final double tail;

  @override
  void paint(Canvas canvas, Size size) {
    final body = Rect.fromLTWH(0, 0, size.width, size.height - tail);
    final r = math.min(18.0, body.height / 2);
    final tipX = size.width * 0.72;
    final tailPath = Path()
      ..moveTo(tipX - tail * 0.9, body.bottom - 1)
      ..quadraticBezierTo(
        tipX - tail * 0.1,
        body.bottom + tail * 0.4,
        tipX + tail * 0.15,
        size.height,
      )
      ..quadraticBezierTo(
        tipX + tail * 0.05,
        body.bottom + tail * 0.3,
        tipX + tail * 0.55,
        body.bottom - 1,
      )
      ..close();
    // شكلٌ واحد لا شكلان — وإلا رُسم الحدُّ خطّاً عبر قاعدة الذيل.
    final path = Path.combine(
      PathOperation.union,
      Path()..addRRect(RRect.fromRectAndRadius(body, Radius.circular(r))),
      tailPath,
    );
    canvas.drawShadow(path, shadow, 6, false);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawPath(
      path,
      Paint()
        ..color = stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.fill != fill || old.stroke != stroke || old.tail != tail;
}
