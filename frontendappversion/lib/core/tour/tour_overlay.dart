import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/masar_character.dart';
import 'masar_tour.dart';
import 'tour_anchor.dart';
import 'tour_card.dart';

// ==========================================
// 🎬 مسرحُ الجولة — الفتحة والروبوت والفقاعة
// ==========================================
// 🤖 **حركاتُ الروبوت الثلاث** (طلب المالك: «ما يكون في وضعية واحدة»):
//   ① الدخول: يطير من أسفل الشاشة بارتدادٍ ودوّامتُه تحته.
//   ② الانتقال: مع «التالي» يقفز بقوسٍ نحو المكان الجديد، ويميل باتجاه
//      قفزته، ويبدّل وضعيتَه في أعلى القفزة (هلا ↔ تمام ↔ يقرأ ↔ منح…).
//   ③ الكلام: يُكتب الشرحُ كلمةً كلمة وفمُه يتحرّك معه، ثم يطفو ويرمش.
//
// 🔦 **الفتحة** تنزلق من مكانٍ إلى مكان (لا تقفز)، والتغبيشُ خارجها فقط.
// 🧭 **المكان**: تُمرَّر الشاشةُ إليه أولاً إن كان خارجها، ثم يقف الروبوتُ
//    في النصف الأوسع من الشاشة (فوق الفتحة أو تحتها) ويميل نحوها.

class TourOverlay extends StatefulWidget {
  const TourOverlay({super.key, required this.steps});

  final List<TourStep> steps;

  @override
  State<TourOverlay> createState() => _TourOverlayState();
}

/// ما يُحسب لكل خطوة: الفتحةُ ومنطقةُ الروبوت.
class _Frame {
  const _Frame(this.hole, this.region, this.align, this.robotDx);

  /// الفتحة — مستطيلٌ صفريٌّ في المنتصف لخطوةٍ بلا مرساة.
  final RRect hole;

  /// المنطقةُ التي يقف فيها الروبوت وفقاعتُه (فوق الفتحة أو تحتها).
  final Rect region;

  /// −1 أعلى المنطقة (ملاصقٌ لفتحةٍ فوقه) · 1 أسفلها · 0 وسطها.
  final double align;

  /// ميلُ الروبوت أفقياً نحو الفتحة.
  final double robotDx;

  static _Frame lerp(_Frame a, _Frame b, double t) => _Frame(
    RRect.lerp(a.hole, b.hole, t)!,
    Rect.lerp(a.region, b.region, t)!,
    ui.lerpDouble(a.align, b.align, t)!,
    ui.lerpDouble(a.robotDx, b.robotDx, t)!,
  );
}

class _TourOverlayState extends State<TourOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _intro; // ظهورُ المسرح والروبوت
  late final AnimationController _move; // انتقالُ الفتحة والقفزة

  late List<TourStep> _steps = widget.steps;
  int _index = 0;
  _Frame? _from;
  _Frame? _to;
  MasarCharacter _pose = MasarCharacter.hello;

  // ✍️ الكتابةُ كلمةً كلمة.
  List<String> _words = const [];
  int _shown = 0;
  Timer? _typer;
  bool _busy = false;
  bool _still = false;
  final Set<TourStep> _ran = {}; // خطواتٌ نُفّذ ما قبلها ([TourStep.before])

  TourStep get _step => _steps[_index];

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _move = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 820),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _begin());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void dispose() {
    _typer?.cancel();
    _intro.dispose();
    _move.dispose();
    super.dispose();
  }

  // ══════════════ التسلسل ══════════════

  Future<void> _begin() async {
    // 🔢 الخطواتُ الاختياريةُ الغائبة تُحذف **قبل** البدء — وإلا عدّت النقاطُ
    //    ١١ خطوةً ثم قفزت إلى ٦ في منتصف الجولة (رُئي في «تحليل مستواي»).
    _prune(0);
    final ok = await _prepare(_index);
    if (!mounted) return;
    if (!ok) return Navigator.of(context).pop();
    final f = _frameFor(_step);
    setState(() {
      _from = f;
      _to = f;
      _pose = _step.pose;
    });
    _move.value = 1;
    if (_still) {
      _intro.value = 1;
    } else {
      await _intro.forward();
    }
    if (mounted) _speak();
  }

  /// يحذف الخطواتِ الاختياريةَ الغائبة من [from] حتى أوّلِ خطوةٍ لها
  /// [TourStep.before] — ما بعدها (داخلَ قائمةٍ لم تُفتح بعد) لا يُحكم عليه
  /// إلا حين يُفتح.
  void _prune(int from) {
    var end = _steps.length;
    for (var k = from + 1; k < _steps.length; k++) {
      if (_steps[k].before != null) {
        end = k;
        break;
      }
    }
    _steps = [
      ..._steps.sublist(0, from),
      for (final s in _steps.sublist(from, end))
        if (!s.optional || s.anchor == null || _present(s.anchor!)) s,
      ..._steps.sublist(end),
    ];
  }

  static bool _present(String id) {
    final r = TourAnchors.rectOf(id);
    return r != null && !r.isEmpty;
  }

  /// يمرّر الشاشةَ إلى مرساة الخطوة إن كانت خارجها، ويتخطّى الخطوات
  /// الاختيارية التي لا عنصرَ لها الآن.
  Future<bool> _prepare(int i) async {
    while (i < _steps.length) {
      final before = _steps[i].before;
      if (before != null && _ran.add(_steps[i])) {
        await before();
        // 🖼️ ما فتحه يُرسم في الإطار التالي — قبله لا مرساةَ تُقاس.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return false;
        _prune(i);
        continue;
      }
      final id = _steps[i].anchor;
      // عنصرٌ مبنيٌّ بلا مساحة (بطاقةٌ لا بيانات لها ترجع `SizedBox.shrink`)
      // كالغائب تماماً.
      if (id == null || _present(id)) break;
      if (!_steps[i].optional) break;
      _steps = [..._steps]..removeAt(i);
    }
    if (i >= _steps.length) return false;
    final id = _steps[i].anchor;
    final ctx = id == null ? null : TourAnchors.contextOf(id);
    if (ctx != null && ctx.mounted) {
      // 📏 العنصرُ الطويل (ملخّصُ الأداء ~٢٧٠) يُرفع إلى أعلى الشاشة كي يبقى
      //    تحته مكانٌ للروبوت بحجمه — وإلا صُغّر المسرحُ كلُّه ليسع.
      final h = TourAnchors.rectOf(id!)?.height ?? 0;
      final tall = h > MediaQuery.sizeOf(context).height * 0.22;
      await Scrollable.ensureVisible(
        ctx,
        alignment: tall ? 0.06 : 0.35,
        alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        duration: _still ? Duration.zero : const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    }
    _index = i;
    return true;
  }

  Future<void> _next() async {
    if (_busy) return;
    HapticFeedback.selectionClick();
    if (_index >= _steps.length - 1) return _close();
    _busy = true;
    _typer?.cancel();
    final from = _current;
    setState(() => _shown = 0);
    final ok = await _prepare(_index + 1);
    if (!mounted) return;
    if (!ok) {
      _busy = false;
      return _close();
    }
    final to = _frameFor(_step);
    final pose = _step.pose;
    setState(() {
      _from = from;
      _to = to;
    });
    if (_still) {
      _move.value = 1;
      setState(() => _pose = pose);
    } else {
      // 🔄 الوضعيةُ الجديدة في أعلى القفزة — حيث الحركةُ أسرعُ ما يكون فلا
      //    يُرى التبديل «قطعاً».
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 330), () {
          if (mounted) setState(() => _pose = pose);
        }),
      );
      await _move.forward(from: 0);
    }
    _busy = false;
    if (mounted) _speak();
  }

  Future<void> _close() async {
    _typer?.cancel();
    if (!_still) await _intro.reverse();
    // ↩️ تعود الشاشةُ إلى **أعلاها** — لا يُترك الطالب في منتصفها حيث أنزلته
    //    الجولة. (كانت تعود إلى أوّل مرساة، فبقي عنوانُ «معلومات الطالب» فوقها
    //    مخفيّاً.)
    final first = _steps.where((s) => s.anchor != null).firstOrNull;
    final ctx = first == null ? null : TourAnchors.contextOf(first.anchor!);
    final pos = (ctx == null || !ctx.mounted)
        ? null
        : Scrollable.maybeOf(ctx)?.position;
    if (pos != null && pos.pixels != pos.minScrollExtent) {
      unawaited(
        pos.animateTo(
          pos.minScrollExtent,
          duration: _still
              ? const Duration(milliseconds: 1)
              : const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        ),
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _speak() {
    _words = _step.body.split(' ');
    _typer?.cancel();
    if (_still) {
      setState(() => _shown = _words.length);
      return;
    }
    setState(() => _shown = 0);
    _typer = Timer.periodic(const Duration(milliseconds: 95), (t) {
      if (!mounted) return t.cancel();
      setState(() => _shown++);
      if (_shown >= _words.length) t.cancel();
    });
  }

  /// نقرُ الفقاعة أثناء الكتابة يُكمل الجملة — طالبٌ سريعُ القراءة لا ينتظر.
  void _finishTyping() {
    if (_shown >= _words.length) return;
    _typer?.cancel();
    setState(() => _shown = _words.length);
  }

  bool get _talking => _shown > 0 && _shown < _words.length;

  _Frame get _current {
    final a = _from, b = _to;
    if (a == null || b == null) return _frameFor(_step);
    final t = Curves.easeInOutCubic.transform(_move.value);
    return _Frame.lerp(a, b, t);
  }

  // ══════════════ الهندسة ══════════════

  _Frame _frameFor(TourStep s) {
    final mq = MediaQuery.of(context);
    final size = mq.size;
    final safe = Rect.fromLTRB(
      0,
      mq.padding.top + 8,
      size.width,
      size.height - mq.padding.bottom - 8,
    );
    final rect = s.anchor == null ? null : TourAnchors.rectOf(s.anchor!);
    if (rect == null) {
      final c = safe.center;
      return _Frame(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: c, width: 0, height: 0),
          Radius.zero,
        ),
        safe,
        0,
        0,
      );
    }
    final RRect hole;
    if (s.shape == TourShape.circle) {
      final d = math.max(rect.width, rect.height) + s.padding * 2;
      hole = RRect.fromRectAndRadius(
        Rect.fromCenter(center: rect.center, width: d, height: d),
        Radius.circular(d / 2),
      );
    } else {
      hole = RRect.fromRectAndRadius(
        _fit(rect.inflate(s.padding), safe),
        const Radius.circular(22),
      );
    }
    const gap = 14.0;
    final above = Rect.fromLTRB(0, safe.top, size.width, hole.top - gap);
    final below = Rect.fromLTRB(0, hole.bottom + gap, size.width, safe.bottom);
    final useBelow = below.height >= above.height;
    final dx = ((hole.center.dx - size.width / 2) * 0.35).clamp(-70.0, 70.0);
    // 🧱 عنصرٌ يملأ الشاشة تقريباً فلا مكانَ فوقه ولا تحته ⇒ يقف الروبوت
    //    فوقه في الطرف البعيد عن مركزه (يُصغَّر ليسع — [FittedBox]).
    // 📏 وما دون ذلك (١٧٠–٢٥٠) يقف في الأوسع مصغَّراً — تصغيرُه أهونُ من أن
    //    يغطّي بجسده ما يشرحه (رُئي في «اختر المادة» بالقائمة الجانبية).
    if (math.max(above.height, below.height) < 170) {
      final up = hole.center.dy > safe.center.dy;
      return _Frame(hole, safe, up ? -1 : 1, dx);
    }
    return _Frame(hole, useBelow ? below : above, useBelow ? -1 : 1, dx);
  }

  /// مساحةُ المسرح الدنيا تحت الفتحة أو فوقها: روبوتٌ مقروء + فقاعة + الأزرار.
  static const double _stageMin = 380;

  /// ✂️ **الفتحةُ لا تأكل مكانَ الروبوت.**
  ///
  /// 🔴 عنصرٌ طويل (قائمةُ المواد · إعداداتُ الجلسة مفتوحةً — وفي الصف الأول
  ///    أطولُ منها في الثالث) كان لا يترك فوقه ولا تحته مسرحاً، فيقف الروبوتُ
  ///    وأزرارُه **فوق** ما يشرحه (رُئي في المحاكي). فالفتحةُ تُقصّ من الجهة
  ///    الأوسع حتى يبقى فيها [_stageMin] — يُرى رأسُ العنصر (عنوانُه وأوّلُ
  ///    صفوفه) ويكفي ليُعرف، والمسرحُ كاملٌ لا مصغَّر. وما خرج من الشاشة لا
  ///    يُحسب أصلاً.
  static Rect _fit(Rect r, Rect safe) {
    const gap = 14.0, keep = 88.0, enough = 300.0;
    var h = r.intersect(safe);
    if (h.height <= 0) return r;
    final above = h.top - safe.top - gap;
    final below = safe.bottom - h.bottom - gap;
    // مسرحٌ يكفي روبوتاً مصغَّراً قليلاً ⇒ لا قصّ: العنصرُ كاملاً أهمّ.
    if (math.max(above, below) >= enough) return h;
    // ✂️ **يُقصّ الذيلُ لا الرأس**: رأسُ العنصر (عنوانُه وأوّلُ صفوفه) هو ما
    //    يعرّفه — قصُّه من أعلاه أخفى أوّلَ مادّةٍ في الدرج (رُئي في المحاكي).
    final bottom = safe.bottom - gap - _stageMin;
    if (bottom >= h.top + keep) {
      return Rect.fromLTRB(h.left, h.top, h.right, math.min(h.bottom, bottom));
    }
    // الرأسُ نفسُه في ذيل الشاشة ⇒ يبقى أسفلُه والمسرحُ فوقه.
    final top = math.min(h.bottom - keep, safe.top + gap + _stageMin);
    return Rect.fromLTRB(h.left, math.max(h.top, top), h.right, h.bottom);
  }

  // ══════════════ الرسم ══════════════

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      builder: (context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _close();
        },
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _move]),
            builder: (context, _) {
              if (_to == null) return const SizedBox.expand();
              final f = _current;
              final fade = Curves.easeOut.transform(
                (_intro.value * 1.8).clamp(0.0, 1.0),
              );
              return Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(opacity: fade, child: _scrim(f.hole)),
                  ),
                  // النقرُ على الفتحة نفسِها = «التالي».
                  if (!f.hole.isEmpty)
                    Positioned.fromRect(
                      rect: f.hole.outerRect,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _next,
                      ),
                    ),
                  Positioned.fromRect(rect: f.region, child: _stage(f)),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _scrim(RRect hole) {
    final dark = isDarkModeNotifier.value;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipPath(
          clipper: _OutsideHole(hole),
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: ColoredBox(
              color: dark
                  ? Colors.black.withValues(alpha: 0.62)
                  : const Color(0xFF4A5566).withValues(alpha: 0.55),
            ),
          ),
        ),
        if (!hole.isEmpty)
          IgnorePointer(child: CustomPaint(painter: _RingPainter(hole))),
      ],
    );
  }

  /// الروبوتُ وفقاعتُه وأزرارُه — عمودٌ يلتصق بجهة الفتحة من منطقته.
  Widget _stage(_Frame f) {
    final width = MediaQuery.sizeOf(context).width;
    final bubbleW = math.min(width - 48, 340.0);
    // 📏 حجمُ الروبوت من المساحة المتاحة: الفقاعةُ ~١٢٠ والأزرارُ ~٨٠.
    final robotH = (f.region.height - 205).clamp(124.0, 230.0);

    // 🦘 القفزة: قوسٌ جيبيّ وميلٌ باتجاه الانتقال، وانضغاطٌ عند الهبوط.
    final a = _from, b = _to;
    final p = _move.value;
    final travel = (a == null || b == null)
        ? 0.0
        : (b.hole.center.dy - a.hole.center.dy).sign;
    final arc = math.sin(math.pi * p);
    final hopY = _still ? 0.0 : -arc * 38;
    final lean = _still ? 0.0 : arc * 0.14 * (travel == 0 ? 1 : travel);
    final land = p > 0.8 ? math.sin((p - 0.8) / 0.2 * math.pi) : 0.0;
    final squash = 1 + land * 0.06;

    // 🛫 الدخول: من أسفل الشاشة بارتدادٍ ودورانٍ خفيف.
    final e = _intro.value;
    final fly =
        (1 - Curves.easeOutBack.transform(((e - 0.1) / 0.7).clamp(0.0, 1.0))) *
        (MediaQuery.sizeOf(context).height * 0.55);
    final spin = (1 - Curves.easeOutCubic.transform(e)) * -0.35;
    final talkIn = Curves.easeOutBack.transform(
      ((e - 0.55) / 0.45).clamp(0.0, 1.0),
    );

    final robot = Transform.translate(
      offset: Offset(f.robotDx, hopY + fly),
      child: Transform.rotate(
        angle: lean + spin,
        alignment: Alignment.bottomCenter,
        child: Transform.scale(
          scaleX: 1 / squash,
          scaleY: squash,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: robotH,
            height: robotH,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              switchInCurve: Curves.easeOutBack,
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(
                  scale: Tween(begin: 0.8, end: 1.0).animate(anim),
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              ),
              child: MasarCharacterView(
                key: ValueKey(_pose),
                character: _pose,
                active: false,
                talking: _talking,
              ),
            ),
          ),
        ),
      ),
    );

    final text = _words.take(_shown).join(' ');
    final bubble = Opacity(
      opacity: talkIn.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.6 + 0.4 * talkIn,
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: bubbleW,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: TourBubble(
              key: ValueKey(_index),
              title: _step.title,
              full: _step.body,
              body: text,
              // الذيلُ يتبع رأسَ الروبوت — ورأسُ «هلا» يمينَ مركز الصورة قليلاً.
              tailDx: f.robotDx + robotH * 0.08,
              onTap: _finishTyping,
            ),
          ),
        ),
      ),
    );

    final controls = Opacity(
      opacity: ((e - 0.7) / 0.3).clamp(0.0, 1.0),
      child: TourControls(
        index: _index,
        count: _steps.length,
        onNext: _next,
        onClose: _close,
      ),
    );

    return Align(
      alignment: Alignment(0, f.align),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [bubble, robot, const SizedBox(height: 10), controls],
        ),
      ),
    );
  }
}

/// يقصّ كلَّ الشاشة **إلا** الفتحة — فالتغبيشُ والتعتيمُ خارجها وحدها.
class _OutsideHole extends CustomClipper<Path> {
  _OutsideHole(this.hole);
  final RRect hole;

  @override
  Path getClip(Size size) => Path()
    ..fillType = PathFillType.evenOdd
    ..addRect(Offset.zero & size)
    ..addRRect(hole);

  @override
  bool shouldReclip(covariant _OutsideHole old) => old.hole != hole;
}

/// حلقةٌ بيضاء متوهّجة حول الفتحة — «الدائرة البيضاء» في تصميم المصمّم.
class _RingPainter extends CustomPainter {
  _RingPainter(this.hole);
  final RRect hole;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRRect(
      hole.inflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..color = Colors.white.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawRRect(
      hole.inflate(1.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.hole != hole;
}
