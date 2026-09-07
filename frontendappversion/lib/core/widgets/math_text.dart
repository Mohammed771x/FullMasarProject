// ============================================================
// 🧮 math_text.dart — رسم الكسور بسطاً ومقاماً داخل نص عربي
// ============================================================
// الخادم يرسل الكسر بترميز `\frac{بسط}{مقام}` (راجع برومبتات subjects/)،
// وهذا الملف يرسمه كما يراه الطالب في كتابه: بسطاً فوق خط فوق مقام.
//
// ⚠️ **لا يوجد استنتاج من الشرطة المائلة هنا عمداً.** الشرطة تبقى شرطة،
//    لأن «٢٠ م/ث» وحدة قياس لا كسر — ولا يمكن لأي كود أن يميّزهما من النص
//    وحده. التمييز مسؤولية البرومبت، والرسم مسؤولية هذا الملف.

import 'package:flutter/material.dart';

import 'chem_text.dart';

// ══════════════════ شجرة التعبير ══════════════════

sealed class MathNode {
  const MathNode();
}

/// نصّ عادي (عربي أو أرقام أو رموز).
class TextNode extends MathNode {
  final String text;
  const TextNode(this.text);
}

/// كسر: بسط فوق مقام يفصلهما خط أفقي.
class FracNode extends MathNode {
  final List<MathNode> numerator;
  final List<MathNode> denominator;
  const FracNode(this.numerator, this.denominator);
}

/// جذر تربيعي.
class SqrtNode extends MathNode {
  final List<MathNode> body;
  const SqrtNode(this.body);
}

/// نصّ عريض (**...**) — يظهر كثيراً في ردود الخادم داخل أسطر الكسور.
class BoldNode extends MathNode {
  final List<MathNode> body;
  const BoldNode(this.body);
}

/// ⚗️ صيغة بنائية مكثّفة `\chem{...}` — يرسمها `chem_text.dart`.
///
/// تعيش هنا لأن `MathNode` **مُغلقة** (sealed) فلا يجوز أن ترثها فئة في
/// ملف آخر؛ والمنطق الكيميائي كلّه في `chem_text.dart` لا هنا.
class ChemNode extends MathNode {
  final String source;
  const ChemNode(this.source);
}

/// ⚗️ حلقة عضوية `\ring{...}`.
class RingNode extends MathNode {
  final String source;
  const RingNode(this.source);
}

/// أُسّ (مرفوع) أو دليل (منخفض).
class ScriptNode extends MathNode {
  final List<MathNode> body;
  final bool superscript;
  const ScriptNode(this.body, {required this.superscript});
}

// ══════════════════ المُحلِّل ══════════════════

class MathParser {
  MathParser(this._src);

  final String _src;
  int _i = 0;

  static List<MathNode> parse(String source) => MathParser(source)._nodes();

  List<MathNode> _nodes({bool stopAtBrace = false}) {
    final out = <MathNode>[];
    final buffer = StringBuffer();

    void flush() {
      if (buffer.isNotEmpty) {
        out.add(TextNode(buffer.toString()));
        buffer.clear();
      }
    }

    while (_i < _src.length) {
      final c = _src[_i];

      if (stopAtBrace && c == '}') break;

      if (c == r'\' && _startsWith(r'\frac')) {
        flush();
        _i += 5;
        final n = _group();
        final d = _group();
        out.add(FracNode(n, d));
        continue;
      }

      if (c == r'\' && _startsWith(r'\chem')) {
        flush();
        _i += 5;
        out.add(ChemNode(_rawGroup()));
        continue;
      }

      if (c == r'\' && _startsWith(r'\ring')) {
        flush();
        _i += 5;
        out.add(RingNode(_rawGroup()));
        continue;
      }

      if (c == r'\' && _startsWith(r'\sqrt')) {
        flush();
        _i += 5;
        out.add(SqrtNode(_group()));
        continue;
      }

      if (c == '*' && _startsWith('**')) {
        final close = _src.indexOf('**', _i + 2);
        if (close > _i + 1) {
          flush();
          final inner = MathParser(_src.substring(_i + 2, close))._nodes();
          out.add(BoldNode(inner));
          _i = close + 2;
          continue;
        }
      }

      if (c == '^' || c == '_') {
        // أُسّ أو دليل. يقبل ^{...} و ^س و ^٢
        flush();
        _i++;
        out.add(ScriptNode(_groupOrSingle(), superscript: c == '^'));
        continue;
      }

      buffer.write(c);
      _i++;
    }

    flush();
    return out;
  }

  bool _startsWith(String token) => _src.startsWith(token, _i);

  /// يقرأ `{...}` مع دعم التداخل. الأقواس المفقودة لا تُسقط البرنامج.
  List<MathNode> _group() {
    _skipSpaces();
    if (_i >= _src.length || _src[_i] != '{') return const [];
    _i++; // {
    final inner = _nodes(stopAtBrace: true);
    if (_i < _src.length && _src[_i] == '}') _i++;
    return inner;
  }

  /// `{...}` كنصّ خام بلا تحليل — محتوى الكيمياء رموزٌ لا تعبير رياضي،
  /// فـ`CH3-CH(CH3)-CH3` يجب أن يصل الرسّام الكيميائي كما هو حرفياً.
  String _rawGroup() {
    _skipSpaces();
    if (_i >= _src.length || _src[_i] != '{') return '';
    final start = ++_i;
    var depth = 1;
    while (_i < _src.length && depth > 0) {
      if (_src[_i] == '{') depth++;
      if (_src[_i] == '}') depth--;
      if (depth > 0) _i++;
    }
    final raw = _src.substring(start, _i);
    if (_i < _src.length && _src[_i] == '}') _i++;
    return raw;
  }

  /// `{...}` أو حرف واحد — ليعمل `س^٢` كما يكتبها المعلّم.
  List<MathNode> _groupOrSingle() {
    _skipSpaces();
    if (_i < _src.length && _src[_i] == '{') return _group();
    if (_i < _src.length) {
      final ch = _src[_i];
      _i++;
      return [TextNode(ch)];
    }
    return const [];
  }

  void _skipSpaces() {
    while (_i < _src.length && _src[_i] == ' ') {
      _i++;
    }
  }
}

// ══════════════════ الرسّام ══════════════════

class MathText extends StatelessWidget {
  const MathText(
    this.source, {
    super.key,
    this.style,
    this.ruleColor,
  });

  final String source;
  final TextStyle? style;
  final Color? ruleColor;

  @override
  Widget build(BuildContext context) {
    final base = style ??
        DefaultTextStyle.of(context).style.copyWith(fontSize: 17, height: 1.7);
    final rule = ruleColor ?? base.color ?? Colors.black;

    // ⚠️ لماذا لا نستعمل `Text.rich` مع `WidgetSpan`؟
    //    لأن خوارزمية الاتجاه الثنائي (bidi) تعامل الكسر ككائن **محايد**،
    //    فتعيد ترتيب ما حوله: «‎\frac{لو أ}{لو ب} = لو_ب أ» تخرج مقلوبةً
    //    «ب = لو ــ أ». هذا سبب فشل كل المحاولات السابقة، والعلّة في bidi
    //    لا في الرسم.
    // ✅ الحل: **ترتيب صريح** — كل سطر صفٌّ من ذرّات (كلمة · مسافة · كسر)
    //    يُرصّ من اليمين لليسار بيدنا، فلا يبقى لـ bidi ما يعيد ترتيبه.
    //    وداخل الكلمة الواحدة يبقى تشكيل العربية طبيعياً تماماً.
    final lines = _splitLines(MathParser.parse(source));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final line in _decorate(lines, base))
          line.nodes.isEmpty
              ? SizedBox(height: (base.fontSize ?? 17) * 0.75)
              : Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1.5),
                  child: Wrap(
                    textDirection: TextDirection.rtl,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: 4,
                    children: _atoms(line.nodes, line.style, rule),
                  ),
                ),
      ],
    );
  }
}


/// سطر مُهيّأ للرسم: عقده ونمطه بعد قراءة علامات الماركداون في أوله.
class _Line {
  const _Line(this.nodes, this.style);
  final List<MathNode> nodes;
  final TextStyle style;
}

/// يقرأ `###` عنواناً و`- ` نقطةً من أول السطر — وهي كل ما يظهر فعلاً
/// في ردود الخادم داخل أسطر الكسور.
List<_Line> _decorate(List<List<MathNode>> lines, TextStyle base) {
  final out = <_Line>[];
  for (final nodes in lines) {
    if (nodes.isEmpty) {
      out.add(_Line(const [], base));
      continue;
    }
    var style = base;
    var work = List<MathNode>.from(nodes);

    final first = work.first;
    if (first is TextNode) {
      var t = first.text;
      final head = RegExp(r'^(#{1,6})\s+').firstMatch(t);
      if (head != null) {
        final level = head.group(1)!.length;
        style = base.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: (base.fontSize ?? 17) * (level <= 2 ? 1.18 : 1.08),
        );
        t = t.substring(head.end);
      } else if (RegExp(r'^[-*•]\s+').hasMatch(t)) {
        t = t.replaceFirst(RegExp(r'^[-*•]\s+'), '• ');
      }
      work[0] = TextNode(t);
    }
    out.add(_Line(work, style));
  }
  return out;
}

/// يقسّم الشجرة إلى أسطر عند `\n` — الكسر لا يُقسَّم أبداً.
List<List<MathNode>> _splitLines(List<MathNode> nodes) {
  final lines = <List<MathNode>>[[]];
  for (final node in nodes) {
    if (node is TextNode && node.text.contains('\n')) {
      final parts = node.text.split('\n');
      for (var i = 0; i < parts.length; i++) {
        if (i > 0) lines.add(<MathNode>[]);
        if (parts[i].isNotEmpty) lines.last.add(TextNode(parts[i]));
      }
    } else {
      lines.last.add(node);
    }
  }
  return lines;
}

/// اتجاه الذرّة الواحدة — لا اتجاه الكلمة بعد تقسيمها.
///
/// المحايد يتبع ما حوله (رقم · إشارة · قوس · كسر)، والفراغ محايدٌ **طرفيّ**
/// يُستثنى من القلب حتى لا تتزحزح المسافات.
enum _Dir { rtl, ltr, neutral, space }

final _arabicLetter = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿]');
final _ltrLetter = RegExp(r'[A-Za-zͰ-Ͽἀ-῿]');

_Dir _dirOf(String s) {
  if (_arabicLetter.hasMatch(s)) return _Dir.rtl;
  if (_ltrLetter.hasMatch(s)) return _Dir.ltr;
  return _Dir.neutral;
}

/// ذرّة واحدة مع اتجاهها.
class _Atom {
  const _Atom(this.widget, this.dir);
  final Widget widget;
  final _Dir dir;
}

/// ⚠️ علّة bidi الثالثة — **بين الكلمات**:
///    `Wrap` يرصّ الذرّات من اليمين لليسار، وهذا صحيح للعربية وخاطئ تماماً
///    للمقاطع اللاتينية: «HI (g) => H2 ... = -25.9 KJ» كانت تُقرأ مقلوبة
///    «KJ 25.9- = ... H2 <= (g) HI» — أي أن النواتج تسبق المتفاعلات، وهذه
///    كيمياء **خاطئة** على شاشة الطالب لا مجرّد شكل.
/// ✅ الحل: قلبُ ترتيب كل مجموعة لاتينية متّصلة قبل تسليمها لـ`Wrap`،
///    فيلغي القلبان بعضهما وتُقرأ المجموعة LTR. وتبقى كل كلمة ذرّةً مستقلّة
///    فلا يتأثّر لفّ السطر الطويل.
/// 🛡️ السطر العربي الخالص (ولو فيه أرقام) لا يملك ذرّة لاتينية واحدة،
///    فلا تتكوّن فيه مجموعة أصلاً ولا يمسّه هذا الإجراء إطلاقاً.
List<_Atom> _orderLtrGroups(List<_Atom> atoms) {
  final out = List<_Atom>.from(atoms);
  var i = 0;
  while (i < out.length) {
    if (out[i].dir != _Dir.ltr) {
      i++;
      continue;
    }
    // المجموعة تمتدّ للأمام عبر المحايدات والفراغات حتى أول ذرّة عربية.
    // ولا تمتدّ للخلف: المحايد السابق للاتينية يتبع اتجاه الفقرة (RTL)
    // وهذا هو سلوك bidi الصحيح: «الطول = RH(x)».
    final startIdx = i;
    var end = i;
    while (end + 1 < out.length && out[end + 1].dir != _Dir.rtl) {
      end++;
    }
    while (end > startIdx && out[end].dir == _Dir.space) {
      end--;
    }
    if (end > startIdx) {
      out.replaceRange(
        startIdx,
        end + 1,
        out.sublist(startIdx, end + 1).reversed.toList(),
      );
    }
    i = end + 1;
  }
  return out;
}

/// ذرّات سطر واحد: كل كلمة ويدجت مستقلّ، وكل مسافة فراغ بعرض ثابت.
/// الفصل بالكلمة هو ما يسمح لـ `Wrap` بلفّ السطر الطويل طبيعياً.
List<Widget> _atoms(List<MathNode> nodes, TextStyle style, Color rule) =>
    [for (final a in _orderLtrGroups(_build(nodes, style, rule))) a.widget];

List<_Atom> _build(List<MathNode> nodes, TextStyle style, Color rule) {
  final out = <_Atom>[];
  final space = (style.fontSize ?? 17) * 0.26;

  for (final node in nodes) {
    switch (node) {
      case TextNode(:final text):
        for (final token in _tokenize(text)) {
          if (token == ' ') {
            out.add(_Atom(SizedBox(width: space), _Dir.space));
          } else {
            // ⚠️ علّة bidi الثانية — **داخل الكلمة الواحدة**:
            //    «د(-2)» تُرسم «د(2-)» و«-1.17» تُرسم «1.17-»، لأن إشارة
            //    السالب محايدة فتأخذ اتجاه الفقرة (RTL) وتقفز خلف الرقم.
            // ✅ الحل: فصل الحروف العربية عن المقاطع الرقمية/الرمزية،
            //    وكل مقطع رقمي يُرسم LTR — فتبقى الإشارة ملتصقة بعددها.
            for (final run in _bidiRuns(token)) {
              out.add(_Atom(
                Text(
                  run.text,
                  style: style,
                  textDirection:
                      run.arabic ? TextDirection.rtl : TextDirection.ltr,
                ),
                _dirOf(run.text),
              ));
            }
          }
        }

      case FracNode(:final numerator, :final denominator):
        out.add(_Atom(
          _Fraction(
            numerator: _atoms(numerator, _shrink(style), rule),
            denominator: _atoms(denominator, _shrink(style), rule),
            rule: rule,
          ),
          _Dir.neutral,
        ));

      case SqrtNode(:final body):
        out.add(_Atom(
          _Sqrt(body: _atoms(body, style, rule), style: style, rule: rule),
          _Dir.neutral,
        ));

      case ChemNode(:final source):
        out.add(_Atom(
          ChemChainView(parseChemChain(source), style: style),
          _Dir.neutral,
        ));

      case RingNode(:final source):
        out.add(_Atom(
          ChemRingView(parseChemRing(source), style: style),
          _Dir.neutral,
        ));

      case BoldNode(:final body):
        out.addAll(_build(body, style.copyWith(fontWeight: FontWeight.w800), rule));

      case ScriptNode(:final body, :final superscript):
        out.add(_Atom(
          Transform.translate(
            offset:
                Offset(0, (style.fontSize ?? 17) * (superscript ? -0.34 : 0.26)),
            child: Wrap(
              textDirection: TextDirection.rtl,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: _atoms(body, _script(style), rule),
            ),
          ),
          _Dir.neutral,
        ));
    }
  }
  return out;
}


/// مقطع متجانس الاتجاه داخل كلمة واحدة.
class _Run {
  const _Run(this.text, this.arabic);
  final String text;
  final bool arabic;
}

/// الأعداد (ومعها إشارتها) هي وحدها ما يُرسم LTR.
///
/// ⚠️ لا تُفصل الأقواس ولا علامات الترقيم: القوس في سياق RTL **ينعكس** تلقائياً
///    (`(` تُرسم `)`) وهذا هو الصحيح. فصلُه في مقطع LTR يلغي الانعكاس فتخرج
///    «د(س)» على صورة «د)س(» — علّة ظهرت فعلاً وأُصلحت بهذا القيد.
final _numberRun = RegExp(r'[-−+]?[0-9٠-٩][0-9٠-٩.,]*');

/// يقسّم الكلمة إلى مقاطع: أعداد (LTR) وما سواها (RTL)، مع دمج المتجاور.
List<_Run> _bidiRuns(String token) {
  final raw = <_Run>[];
  var last = 0;
  for (final m in _numberRun.allMatches(token)) {
    if (m.start > last) raw.add(_Run(token.substring(last, m.start), true));
    raw.add(_Run(m.group(0)!, false));
    last = m.end;
  }
  if (last < token.length) raw.add(_Run(token.substring(last), true));
  if (raw.isEmpty) return [_Run(token, true)];

  // دمج المتجاور المتساوي الاتجاه: «٢+٣-١٢» مقطع واحد لا ثلاثة.
  final merged = <_Run>[raw.first];
  for (final r in raw.skip(1)) {
    final prev = merged.last;
    if (prev.arabic == r.arabic) {
      merged[merged.length - 1] = _Run(prev.text + r.text, r.arabic);
    } else {
      merged.add(r);
    }
  }
  return merged;
}

/// يفصل الكلمات عن المسافات مع الحفاظ على كل مسافة (مسافتان ⇒ فراغان).
List<String> _tokenize(String text) {
  final out = <String>[];
  final buffer = StringBuffer();
  for (final ch in text.split('')) {
    if (ch == ' ') {
      if (buffer.isNotEmpty) {
        out.add(buffer.toString());
        buffer.clear();
      }
      out.add(' ');
    } else {
      buffer.write(ch);
    }
  }
  if (buffer.isNotEmpty) out.add(buffer.toString());
  return out;
}

/// الكسر المتداخل يصغر قليلاً — كما في الكتاب المدرسي.
TextStyle _shrink(TextStyle s) =>
    s.copyWith(fontSize: (s.fontSize ?? 17) * 0.93);

TextStyle _script(TextStyle s) =>
    s.copyWith(fontSize: (s.fontSize ?? 17) * 0.62);

// ── الكسر: عمود من بسط · خط · مقام، وعرض الخط = عرض الأوسع ──
class _Fraction extends StatelessWidget {
  const _Fraction({
    required this.numerator,
    required this.denominator,
    required this.rule,
  });

  final List<Widget> numerator;
  final List<Widget> denominator;
  final Color rule;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          // stretch ⇒ الخط يأخذ عرض أعرض الطرفين تلقائياً
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _part(numerator),
            Container(
              height: 1.6,
              margin: const EdgeInsets.symmetric(vertical: 2.5),
              color: rule,
            ),
            _part(denominator),
          ],
        ),
      ),
    );
  }

  Widget _part(List<Widget> atoms) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        child: Wrap(
          textDirection: TextDirection.rtl,
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: atoms,
        ),
      );
}

// ── الجذر: علامة √ يمتد سقفها فوق المقدار ──
class _Sqrt extends StatelessWidget {
  const _Sqrt({required this.body, required this.style, required this.rule});

  final List<Widget> body;
  final TextStyle style;
  final Color rule;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.ltr, // √ ثم المقدار تحت السقف
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text('√',
            style: style.copyWith(fontSize: (style.fontSize ?? 17) * 1.3)),
        Container(
          padding: const EdgeInsets.fromLTRB(3, 2, 3, 0),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: rule, width: 1.4)),
          ),
          child: Wrap(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: body,
          ),
        ),
      ],
    );
  }
}

// ══════════════════ شبكة أمان ضيّقة: كسر رقمي بحت ══════════════════
// البرومبت يطلب `\frac`، لكن امتثال الموديل ليس مطلقاً: يمرّ أحياناً
// «١/٥ جا⁵ س». فنحوّل **الأعداد وحدها** — ولا شيء غيرها.
//
// ⚠️ لماذا الأعداد وحدها؟ لأن «م/ث» و«كجم.م/ث» و«كم/ساعة» **وحدات قياس**
//    لا كسور، وكلها تحوي حروفاً. فقصرُ التحويل على الأرقام يجعل الخطأ
//    مستحيلاً لا نادراً. وما فيه حروف («دص/دس») يبقى على البرومبت وحده.
final _pureNumericFraction = RegExp(
  r'(?<![\w٠-٩؀-ۿ])'   // لا حرف ولا رقم قبله
  r'([0-9٠-٩]+)\s*/\s*([0-9٠-٩]+)'
  r'(?![\w٠-٩/])',               // ولا بعده (ولا شرطة ثانية)
);

/// يحوّل «١/٥» إلى `\frac{١}{٥}` ويترك ما عداه كما هو.
String liftNumericFractions(String text) {
  if (!text.contains('/')) return text;
  return text.replaceAllMapped(
    _pureNumericFraction,
    (m) => '\\frac{${m.group(1)}}{${m.group(2)}}',
  );
}
