// ============================================================
// ⚗️ chem_text.dart — رسم الصيغ البنائية والحلقات العضوية
// ============================================================
// المشكلة التي يحلّها هذا الملف (مرصودة على ردود حقيقية 2026-09-04):
//   الطالب يسأل «سمِّ CH3-NH-CH3 وارسم صيغته» فيرد الموديل برسم ASCII
//   **خاطئ كيميائياً** (نيتروجين بثلاث هيدروجينات وكربون معلّق)، أو يقول
//   صراحةً «لا أستطيع رسم الأشكال» للحلقات. ووحدة الكيمياء العضوية كلها
//   قائمة على الصيغ البنائية — فبلا رسم تصير الوحدة بلا فائدة.
//
// 🧭 **القاعدة المستفادة من الكسور:** لا يُطلب من الموديل أن **يرسم**،
//    بل أن يكتب **ترميزاً** والتطبيق يرسمه. الرسم عندئذٍ مضمون لا مُخمَّن،
//    والخطأ الكيميائي يصير مستحيلاً لا نادراً.
//
// الترميزان (يولّدهما الخادم — راجع `core/chem.py` وبرومبتات `subjects/`):
//
//   \chem{CH3-CH(CH3)-CH3}     سلسلة مكثّفة، الفرع بين قوسين يُرفع فوق أصله
//   \ring{6|ar|+NH2}           حلقة: ٦ أضلاع · عطرية · عليها مجموعة NH2
//
// تفصيل `\ring{...}` — أجزاء يفصلها `|` بأي ترتيب:
//   العدد (3..8) · `ar` عطرية · رمز ذرّة غريبة (N · NH · O · S) · `+مجموعة`
//
// ⚠️ الأرقام داخل المجموعات تُرسم **منخفضة** (CH₃ لا CH3) — هكذا الكتاب.

import 'dart:math' as math;

import 'package:flutter/material.dart';

// ══════════════════ النموذج ══════════════════

/// نوع الرابطة بين مجموعتين.
enum ChemBond { single, double_, triple }

int _bondLines(ChemBond b) => switch (b) {
      ChemBond.single => 1,
      ChemBond.double_ => 2,
      ChemBond.triple => 3,
    };

/// مجموعة واحدة في السلسلة (CH3 · NH · C …) وما يتفرّع عنها.
class ChemGroup {
  ChemGroup(this.label);

  /// نصّ المجموعة كما يُكتب: `CH3` · `NH2` · `COOH`.
  final String label;

  /// الفروع المرفوعة فوق هذه المجموعة (بترتيب ورودها).
  final List<ChemBranch> up = [];

  /// الفروع المتدلّية تحتها — يُستعمل حين يزيد الفرع عن واحد.
  final List<ChemBranch> down = [];

  /// الرابطة الواصلة لما بعدها (`null` في آخر المجموعة).
  ChemBond? bondAfter;
}

/// فرعٌ معلّق على مجموعة: نصُّه ونوعُ رابطته.
///
/// ⚗️ الكربونيل `C(=O)` هو سبب وجود [bond]: الأكسجين يُرسم فوق الكربون
///    بخطّين لا خطّ — وهكذا يرسمه الكتاب في الأميدات والأحماض.
class ChemBranch {
  const ChemBranch(this.label, {this.bond = ChemBond.single});
  final String label;
  final ChemBond bond;
}

/// سلسلة مكثّفة: مجموعات تصل بينها روابط، وفروع فوق وتحت.
class ChemChain {
  const ChemChain(this.groups);
  final List<ChemGroup> groups;
}

/// حلقة: مضلّع منتظم، وربما عطرية أو فيها ذرّة غريبة أو عليها مجموعة.
class ChemRing {
  const ChemRing({
    required this.size,
    this.aromatic = false,
    this.hetero,
    this.substituent,
  });

  final int size;
  final bool aromatic;

  /// ذرّة غير الكربون داخل الحلقة (`N` · `NH` · `O` · `S`) — تُرسم أسفلها.
  final String? hetero;

  /// مجموعة معلّقة على الحلقة (`NH2` · `CH3` · `NH-CH3`) — تُرسم أعلاها.
  final String? substituent;
}

// ══════════════════ المُحلِّل ══════════════════

/// يقرأ محتوى `\chem{...}` إلى سلسلة.
///
/// يقبل ما يكتبه الكتاب فعلاً: `CH3-CH2-NH2` و`CH3 CH2 CH2 NH2`
/// (الفراغ رابطةٌ أحادية ضمناً) و`CH3-CH(NH2)-CH3` و`C=O` و`C#N`.
ChemChain parseChemChain(String source) {
  final groups = <ChemGroup>[];
  var i = 0;
  ChemBond? pending;

  void addGroup(String label) {
    if (label.isEmpty) return;
    if (groups.isNotEmpty) groups.last.bondAfter = pending ?? ChemBond.single;
    pending = null;
    groups.add(ChemGroup(label));
  }

  final buffer = StringBuffer();
  void flush() {
    addGroup(buffer.toString().trim());
    buffer.clear();
  }

  while (i < source.length) {
    final c = source[i];

    if (c == '-' || c == '–' || c == '—') {
      flush();
      pending = ChemBond.single;
      i++;
    } else if (c == '=') {
      flush();
      pending = ChemBond.double_;
      i++;
    } else if (c == '#' || c == '≡') {
      flush();
      pending = ChemBond.triple;
      i++;
    } else if (c == '(') {
      // فرعٌ يخصّ المجموعة **السابقة** — لا مجموعةً جديدة.
      flush();
      final close = _matchParen(source, i);
      final inner = source.substring(i + 1, close).trim();
      if (groups.isNotEmpty && inner.isNotEmpty) {
        final target = groups.last;
        // `(=O)` فرعٌ برابطة مزدوجة · `(#N)` ثلاثية · وما عداهما أحادية.
        var text = inner;
        var bond = ChemBond.single;
        if (text.startsWith('=')) {
          bond = ChemBond.double_;
          text = text.substring(1).trim();
        } else if (text.startsWith('#') || text.startsWith('≡')) {
          bond = ChemBond.triple;
          text = text.substring(1).trim();
        }
        if (text.isEmpty) {
          i = close + 1;
          continue;
        }
        (target.up.isEmpty ? target.up : target.down)
            .add(ChemBranch(text, bond: bond));
      }
      i = close + 1;
    } else if (c == ' ') {
      // فراغ بين مجموعتين = رابطة أحادية (صيغة الكتاب: `CH3 CH2 CH2 NH2`).
      flush();
      i++;
    } else {
      buffer.write(c);
      i++;
    }
  }
  flush();
  return ChemChain(groups);
}

int _matchParen(String s, int open) {
  var depth = 0;
  for (var i = open; i < s.length; i++) {
    if (s[i] == '(') depth++;
    if (s[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return s.length - 1;
}

/// يقرأ محتوى `\ring{...}` — الأجزاء يفصلها `|` بأي ترتيب.
ChemRing parseChemRing(String source) {
  var size = 6;
  var aromatic = false;
  String? hetero;
  String? substituent;

  for (final raw in source.split('|')) {
    final part = raw.trim();
    if (part.isEmpty) continue;
    final n = int.tryParse(part);
    if (n != null) {
      size = n.clamp(3, 8);
    } else if (part == 'ar' || part == 'aromatic') {
      aromatic = true;
    } else if (part.startsWith('+')) {
      substituent = part.substring(1).trim();
    } else {
      hetero = part;
    }
  }
  return ChemRing(
      size: size, aromatic: aromatic, hetero: hetero, substituent: substituent);
}

// ══════════════════ الرسم — نصّ المجموعة ══════════════════

/// يرسم `CH3` بالرقم منخفضاً: CH₃، و`Pb(s)` بحالتها منخفضة: Pb₍s₎.
///
/// الأرقام وحدها تنخفض؛ ورقمُ **بداية** المقطع (مثل `2` في `2CH3`) يبقى
/// عادياً لأنه معامل لا دليل.
///
/// ⚗️ **وحالةُ المادّة تنخفض كذلك** (من صفحة الكتاب التي أرسلها المالك
///    2026-09-12): «Pb₍s₎ + SO₄²⁻₍aq₎ ⟶ PbSO₄₍s₎ + 2e⁻» — الحالةُ أصغرُ
///    وأخفضُ من الصيغة، لا بحجمها.
///
/// ⚠️ **ولا يبلغها يونيكود**: لا وجودَ لـ«q» ولا «g» منخفضتين في يونيكود
///    أصلاً، فلا سبيل إلا الرسم. ولذلك تبقى الحالةُ في النثر كما هي —
///    وهو الصواب هناك: «عدد الكم الثانوي (l)» ليست حالةَ سائل.
final RegExp _state = RegExp(r'^\((?:s|l|g|aq)\)');
class ChemLabel extends StatelessWidget {
  const ChemLabel(this.text, {super.key, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 15;
    final spans = <InlineSpan>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isNotEmpty) {
        spans.add(TextSpan(text: buffer.toString()));
        buffer.clear();
      }
    }

    for (var i = 0; i < text.length; i++) {
      final c = text[i];
      // ⚗️ «(s)» · «(aq)» — حالةُ المادّة تنخفض كما في الكتاب.
      final state = c == '(' ? _state.firstMatch(text.substring(i)) : null;
      if (state != null) {
        flush();
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.02),
            child: Text(state.group(0)!,
                textDirection: TextDirection.ltr,
                style: style.copyWith(fontSize: size * 0.7)),
          ),
        ));
        i += state.group(0)!.length - 1;
        continue;
      }
      final isDigit = c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39;
      final afterLetter = i > 0 && RegExp(r'[A-Za-z)\]]').hasMatch(text[i - 1]);
      if (isDigit && afterLetter) {
        flush();
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.bottom,
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.02),
            child: Text(c,
                textDirection: TextDirection.ltr,
                style: style.copyWith(fontSize: size * 0.7)),
          ),
        ));
      } else {
        buffer.write(c);
      }
    }
    flush();

    return Text.rich(
      TextSpan(children: spans, style: style),
      textDirection: TextDirection.ltr,
    );
  }
}

// ══════════════════ الرسم — السلسلة ══════════════════

/// صيغة بنائية مكثّفة: مجموعات تصلها روابط أفقية، وفروعٌ فوقها وتحتها.
///
/// 🔒 الاتجاه **LTR دائماً** مهما كان النص حولها عربياً: الصيغة الكيميائية
///    تُقرأ من اليسار كما في الكتاب، وقلبها يغيّر المركّب لا شكله فقط.
class ChemChainView extends StatelessWidget {
  const ChemChainView(this.chain, {super.key, required this.style});

  final ChemChain chain;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 15;
    final color = style.color ?? Colors.black;
    final hasUp = chain.groups.any((g) => g.up.isNotEmpty);
    final hasDown = chain.groups.any((g) => g.down.isNotEmpty);

    // 🛡️ **شبكةُ أمان ضد الفيضان.** السلسلة صفٌّ واحد لا ينكسر بطبعه،
    //    فسلسلةٌ طويلة تتجاوز عرض الشاشة وتُظهر شريط
    //    «RIGHT OVERFLOWED BY …» — رآه المالك على جهازه (2026-09-09).
    //
    // ⚖️ والتمريرُ الأفقيّ أصدقُ من القصّ: الصيغة تبقى كاملةً ويصل إليها
    //    الطالب بإصبعه، بينما القصّ يُخفي ذرّاتٍ فيغيّر المركّب.
    //
    // ⚠️ والعلاجُ الجذريّ في الخادم ([core/chem.py]): `\chem{}` لا تغلّف
    //    معادلةً كاملة. وهذا يحرس ما يفلت.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const ClampingScrollPhysics(),
        child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < chain.groups.length; i++) ...[
            _cell(
              main: ChemLabel(chain.groups[i].label, style: style),
              up: chain.groups[i].up.isEmpty ? null : chain.groups[i].up.first,
              down: chain.groups[i].down.isEmpty
                  ? null
                  : chain.groups[i].down.first,
              size: size,
              color: color,
              hasUp: hasUp,
              hasDown: hasDown,
            ),
            if (chain.groups[i].bondAfter != null)
              _cell(
                main: _horizontalBond(chain.groups[i].bondAfter!, size, color),
                up: null,
                down: null,
                size: size,
                color: color,
                hasUp: hasUp,
                hasDown: hasDown,
              ),
          ],
        ],
        ),
      ),
    );
  }

  /// خليّة من ثلاثة طوابق: فرعٌ فوق · الأصل · فرعٌ تحت.
  ///
  /// ⚠️ **بلا أي ارتفاع مكتوب بالأرقام.** الطابق الفارغ يحمل نسخةً مخفيّة
  ///    (`Visibility` بـ`maintainSize`) من الشكل نفسه، فيتطابق ارتفاعه مع
  ///    الطابق المملوء مهما كان حجم الخطّ أو تكبير النظام. المحاولة الأولى
  ///    استعملت `SizedBox` بارتفاع محسوب فطفح الصفّ ١٣ بكسل.
  Widget _cell({
    required Widget main,
    required ChemBranch? up,
    required ChemBranch? down,
    required double size,
    required Color color,
    required bool hasUp,
    required bool hasDown,
  }) {
    Widget branch(ChemBranch? b, {required bool above}) {
      final label = ChemLabel(b?.label ?? 'C', style: style);
      final bond = _verticalBond(size, color, b?.bond ?? ChemBond.single);
      final content = Column(
        mainAxisSize: MainAxisSize.min,
        children: above ? [label, bond] : [bond, label],
      );
      return b == null
          ? Visibility(
              visible: false,
              maintainSize: true,
              maintainAnimation: true,
              maintainState: true,
              child: content,
            )
          : content;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasUp) branch(up, above: true),
        main,
        if (hasDown) branch(down, above: false),
      ],
    );
  }

  /// الرابطة الرأسية — خطٌّ أو خطّان (الكربونيل) أو ثلاثة.
  Widget _verticalBond(double size, Color color, [ChemBond bond = ChemBond.single]) {
    final lines = _bondLines(bond);
    final gap = size * 0.16;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < lines; i++) ...[
          if (i > 0) SizedBox(width: gap),
          Container(width: 1.4, height: size * 0.62, color: color),
        ],
      ],
    );
  }

  /// الرابطة الأفقية — خطٌّ أو خطّان أو ثلاثة حسب نوعها، بارتفاع سطر
  /// المجموعة نفسه (نسخة مخفيّة من الحرف تضبطه) فتبقى السلسلة مستقيمة.
  Widget _horizontalBond(ChemBond bond, double size, Color color) {
    final lines = _bondLines(bond);
    final gap = size * 0.16;
    return Stack(
      alignment: Alignment.center,
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: ChemLabel('C', style: style),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < lines; i++) ...[
              if (i > 0) SizedBox(height: gap),
              Container(width: size * 0.78, height: 1.4, color: color),
            ],
          ],
        ),
      ],
    );
  }
}

// ══════════════════ الرسم — الحلقة ══════════════════

/// حلقة عضوية: مضلّع منتظم رأسه لأعلى، مع دائرة داخلية للعطرية،
/// وذرّة غريبة أسفلها ومجموعة معلّقة أعلاها عند الحاجة.
class ChemRingView extends StatelessWidget {
  const ChemRingView(this.ring, {super.key, required this.style});

  final ChemRing ring;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 15;
    final r = size * 1.55; // نصف قطر المضلّع
    final color = style.color ?? Colors.black;

    // مساحة إضافية للمجموعة المعلّقة أعلى الحلقة ولذرّة الحلقة أسفلها.
    final subText = ring.substituent;
    final topExtra = subText == null ? 0.0 : size * 1.9;
    final bottomExtra = ring.hetero == null ? 0.0 : size * 0.75;

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: size * 0.3, vertical: 2),
        child: SizedBox(
          width: r * 2 + size * 0.6,
          height: r * 2 + topExtra + bottomExtra + size * 0.6,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (subText != null)
                Positioned(
                  top: 0,
                  child: ChemLabel(subText, style: style),
                ),
              Positioned(
                top: topExtra,
                child: CustomPaint(
                  size: Size(r * 2 + size * 0.6, r * 2 + size * 0.6),
                  painter: _RingPainter(
                    ring: ring,
                    color: color,
                    radius: r,
                    labelStyle: style,
                    textScaler: MediaQuery.textScalerOf(context),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.ring,
    required this.color,
    required this.radius,
    required this.labelStyle,
    required this.textScaler,
  });

  final ChemRing ring;
  final Color color;
  final double radius;
  final TextStyle labelStyle;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final n = ring.size;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // 🔄 الاتجاه: رأسٌ لأعلى دائماً — فيبقى للحلقة رأسٌ أعلى تُعلَّق عليه
    //    المجموعة ورأسٌ أدنى تجلس فيه الذرّة الغريبة (البيريدين كما الكتاب).
    //    **إلا المربّع**: رأسه لأعلى يجعله معيّناً ◇ لا مربّعاً □، والكتاب
    //    يرسم السيكلوبيوتان مربّعاً — فيُدار نصف زاوية.
    final start = n == 4 ? -math.pi / 4 : -math.pi / 2;
    final points = <Offset>[
      for (var i = 0; i < n; i++)
        Offset(
          center.dx + radius * math.cos(start + 2 * math.pi * i / n),
          center.dy + radius * math.sin(start + 2 * math.pi * i / n),
        ),
    ];

    // ذرّة الحلقة الغريبة تُوضع في الرأس الأدنى (الأقرب للأسفل).
    int? heteroIndex;
    if (ring.hetero != null) {
      var best = 0;
      for (var i = 1; i < n; i++) {
        if (points[i].dy > points[best].dy) best = i;
      }
      heteroIndex = best;
    }

    TextPainter? heteroPainter;
    if (heteroIndex != null) {
      heteroPainter = TextPainter(
        text: TextSpan(text: ring.hetero, style: labelStyle),
        textDirection: TextDirection.ltr,
        textScaler: textScaler,
      )..layout();
    }

    // نصف عرض الفجوة التي تُترك حول رمز الذرّة كي لا تمرّ الأضلاع فوقه.
    final gap = heteroPainter == null
        ? 0.0
        : math.max(heteroPainter.width, heteroPainter.height) * 0.72;

    for (var i = 0; i < n; i++) {
      var a = points[i];
      var b = points[(i + 1) % n];
      if (heteroIndex == i) a = _shrink(a, b, gap);
      if (heteroIndex == (i + 1) % n) b = _shrink(b, a, gap);
      canvas.drawLine(a, b, stroke);
    }

    if (ring.aromatic) {
      canvas.drawCircle(center, radius * 0.58, stroke);
    }

    if (heteroPainter != null && heteroIndex != null) {
      final p = points[heteroIndex];
      heteroPainter.paint(
        canvas,
        Offset(p.dx - heteroPainter.width / 2, p.dy - heteroPainter.height / 2),
      );
    }

    // رابطةُ المجموعة المعلّقة: خطٌّ قصير من الرأس الأعلى إلى أعلى المربّع.
    if (ring.substituent != null) {
      var top = 0;
      for (var i = 1; i < n; i++) {
        if (points[i].dy < points[top].dy) top = i;
      }
      canvas.drawLine(points[top], Offset(points[top].dx, 0), stroke);
    }
  }

  /// يزحزح نقطة نحو الأخرى بمقدار [by] — لفتح فجوة حول رمز الذرّة.
  Offset _shrink(Offset from, Offset to, double by) {
    final d = to - from;
    final len = d.distance;
    if (len == 0 || by <= 0) return from;
    return from + d * (by / len);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.ring.size != ring.size ||
      old.ring.aromatic != ring.aromatic ||
      old.ring.hetero != ring.hetero ||
      old.ring.substituent != ring.substituent ||
      old.color != color ||
      old.radius != radius;
}
