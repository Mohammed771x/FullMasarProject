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

// ══════════════════ قائمةُ الترميز ══════════════════

/// 🛡️ **كلُّ ما يرسمه هذا الملف — في مكانٍ واحد.**
///
/// 🔴 **علّةُ المالك (2026-09-12):** «\sup{235}_92U» ظهر نصّاً خاماً داخل
///    صندوق معادلة الانشطار النووي. والسببُ **نسخةٌ محلية متخلّفة**:
///    `chem_equation` كانت تعرف أربعةً من هذه التسعة، فما عداها يُطبع
///    كما هو للطالب.
///
/// ⚠️ **وهي رابعُ مرّةٍ تُخطئ فيها قائمةٌ منسوخة** (راجع `latex_guard.KEPT`
///    في الخادم و`MARKUP_RULES` في `math.py`). فلا تُنسخ هذه القائمة —
///    تُستورد.
const List<String> kMathTokens = [
  r'\frac', r'\sqrt', r'\chem', r'\ring',
  r'\fact', r'\perm', r'\comb', r'\sup', r'\ovl', r'\nuc',
];

/// هل في النصّ ترميزٌ يرسمه [MathText]؟
bool hasMathMarkup(String text) {
  for (final token in kMathTokens) {
    if (text.contains(token)) return true;
  }
  return false;
}

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
/// ⌋ المضروب بالرمز العربي — ضلعٌ يمينَه وقاعدةٌ تحته.
class FactNode extends MathNode {
  final List<MathNode> body;
  const FactNode(this.body);
}

/// ⁿلᵣ التباديل والتوافيق — حرفٌ في الوسط، ن مرفوعةٌ عن يمينه وَر منخفضة.
class CountNode extends MathNode {
  /// «ل» للتباديل و«ق» للتوافيق — حرفُ الكتاب نفسه لا حرفٌ لاتيني.
  final String letter;
  final List<MathNode> n;
  final List<MathNode> r;
  const CountNode(this.letter, this.n, this.r);
}

/// ‾ شرطةٌ علوية: المرافق «ع̅» في الأعداد المركبة، والمتمّمة «أَ» في
/// الاحتمالات. وتمتدّ فوق ما تحتضنه كائناً ما كان — حرفاً أو قوساً كاملاً.
class OvlNode extends MathNode {
  final List<MathNode> body;

  /// عددُ الشرطات: اثنتان في «مرافق المرافق».
  final int lines;
  const OvlNode(this.body, {this.lines = 1});
}

/// ☢️ رمزُ النواة: العددُ الكتلي فوق الذرّي، وكلاهما قبل الرمز — ²³⁵₉₂U.
///
/// 🔴 **وهو واحدٌ لا ثلاثة** (علّةُ المالك 2026-09-12): حين تُقرأ `^` و`_`
///    كلٌّ على حدة يرتّبها الاتجاهُ الثنائي كما يشاء، فيسبق الرمزُ عددَيه
///    ويظهر «Cl7₁³⁵». فاجتماعُها في عقدةٍ واحدة هو ما يثبّت الترتيب.
class NucNode extends MathNode {
  /// العدد الكتلي (فوق).
  final String mass;

  /// العدد الذرّي (تحت).
  final String atomic;

  /// رمزُ العنصر — قد يكون فارغاً في جداول النظائر.
  final String symbol;
  const NucNode(this.mass, this.atomic, this.symbol);
}

class SqrtNode extends MathNode {
  final List<MathNode> body;

  /// دليلُ الجذر: «٣» في التكعيبي و«٤» في الرابع. فارغٌ في التربيعي.
  final String index;
  const SqrtNode(this.body, {this.index = ''});
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

    // 🔴 **قوسٌ معقوفٌ في نصّ الكتاب نفسه.** الاحتمالاتُ تكتب المجموعة
    //    «حـا{(الصندوق الأول ، ز)}»، فإذا صارت بسطاً تداخلت الأقواس:
    //    `\frac{حـا{…}}{…}`. وكان الوقوفُ عند **أول** «}» فينتهي البسط
    //    مبكّراً ويظهر «}{» نصّاً خاماً على الشاشة — وهو ما رآه المالك:
    //    «لما يكون كلام واجد داخل الاحتمال يخبّط». فالعدّ لا الوقوف.
    var depth = 0;

    void flush() {
      if (buffer.isNotEmpty) {
        out.add(TextNode(buffer.toString()));
        buffer.clear();
      }
    }

    while (_i < _src.length) {
      final c = _src[_i];

      if (stopAtBrace && c == '}') {
        if (depth == 0) break;
        depth--;
        buffer.write(c);
        _i++;
        continue;
      }
      if (stopAtBrace && c == '{') {
        depth++;
        buffer.write(c);
        _i++;
        continue;
      }

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
        // 🔴 **دليلُ الجذر بين قوسين معقوفين**: الخادم يرسل
        //    «\sqrt[3]{٨}» للتكعيبي، وكان المُحلِّل يقفز `\sqrt` ثم
        //    ينتظر «{» فيجد «[» — فيخرج الجذرُ مشوّهاً والدليلُ نصّاً
        //    عارياً. رآه المالك (2026-09-11): «جذر تكعيب ما يطلع».
        var index = '';
        if (_i < _src.length && _src[_i] == '[') {
          final close = _src.indexOf(']', _i);
          if (close > _i) {
            index = _src.substring(_i + 1, close);
            _i = close + 1;
          }
        }
        out.add(SqrtNode(_group(), index: index));
        continue;
      }

      if (c == r'\' && _startsWith(r'\fact')) {
        flush();
        _i += 5;
        out.add(FactNode(_group()));
        continue;
      }

      // ⁿ `\sup{…}` — الأُسّ الموحَّد الذي يرسله الخادم.
      //
      // ⭐ يُعاد استعمال `ScriptNode` نفسِها التي ترسم «^» منذ البداية:
      //    الجديدُ هو **الترميزُ الصريح** لا الرسم. وسببُه أن `_needsMath`
      //    لا تُشغّل الرسّام على «^» وحدها (فكلُّ «^» في نصٍّ عادي تصير
      //    رياضيات)، فبقي «س^(ن-١)» يُطبع خاماً على الشاشة.
      if (c == r'\' && _startsWith(r'\ovl')) {
        flush();
        _i += 4;
        out.add(OvlNode(_group()));
        continue;
      }

      if (c == r'\' && _startsWith(r'\sup')) {
        flush();
        _i += 4;
        out.add(ScriptNode(_group(), superscript: true));
        continue;
      }

      // ☢️ `\nuc{الكتلي}{الذرّي}{الرمز}` — رمزُ النواة وحدةً واحدة.
      if (c == r'\' && _startsWith(r'\nuc')) {
        flush();
        _i += 4;
        out.add(NucNode(_rawGroup(), _rawGroup(), _rawGroup()));
        continue;
      }

      if (c == r'\' && (_startsWith(r'\perm') || _startsWith(r'\comb'))) {
        flush();
        final letter = _startsWith(r'\perm') ? 'ل' : 'ق';
        _i += 5;
        final n = _group();
        final r = _group();
        out.add(CountNode(letter, n, r));
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

  /// سلسلةُ أرقامٍ متتالية (لاتينية أو عربية) من موضع القراءة.
  String _digitRun() {
    final start = _i;
    while (_i < _src.length && _isDigit(_src[_i])) {
      _i++;
    }
    return _src.substring(start, _i);
  }

  static bool _isDigit(String c) =>
      (c.codeUnitAt(0) >= 0x30 && c.codeUnitAt(0) <= 0x39) ||
      (c.codeUnitAt(0) >= 0x660 && c.codeUnitAt(0) <= 0x669);

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
    // 🔴 **والرقمُ يُقرأ كاملاً لا محرفاً واحداً** (2026-09-12): «_92U»
    //    كانت تخرج «₉2U» — تسعةٌ منخفضة ثم «2U» في السطر. والدليلُ في
    //    الكتاب عددٌ لا رقم.
    final digits = _digitRun();
    if (digits.isNotEmpty) return [TextNode(digits)];
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
    this.direction = TextDirection.rtl,
    this.latinSign = false,
  });

  final String source;
  final TextStyle? style;
  final Color? ruleColor;

  /// اتجاهُ السطر. ⚖️ **عربيٌّ إلا في صندوق معادلةٍ كيميائية**: هناك
  /// السطرُ لاتينيّ، والعربيةُ فيه حاشيةٌ لا متن ([ChemEquation]).
  final TextDirection direction;

  /// ➖ **هل تبقى إشارةُ العدد اللاتينيّ يسارَه؟**
  ///
  /// 🔒 **افتراضُها `false` عمداً** — أي أن السلوك القديم هو الأصل، ولا
  ///    يتغيّر إلا حيث يُطلب صراحةً. وهذا نصُّ المالك (2026-09-12):
  ///    «التعديل للكيمياء فقط، **اترك الرياضيات كما هي**».
  ///
  /// ⚖️ والرياضياتُ أرقامُها عربية أصلاً (`arabic_digits.to_arabic` تُنادى
  ///    في الرياضيات والمنطق وحدهما)، لكن أجوبتها تحمل لاتينيةً أحياناً
  ///    («المقام (س - 2) = 0») — فالحدُّ بالمادة لا بشكل الرقم.
  final bool latinSign;

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

    final rtl = direction == TextDirection.rtl;
    // 🔤 **اتجاهُ السطر يسري على صناديقه**: بسطُ الكسر ومقامُه وجسمُ
    //    الأُسّ كانت تُرصّ RTL **دائماً**، فمعادلةٌ لاتينية تُقرأ من
    //    اليسار يخرج مقامُها «٣ R_H» مقلوباً. فصار الاتجاه واحداً من
    //    أعلى ([isLatinMathLine] يحدّده للسطر).
    return Directionality(
      textDirection: direction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            rtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          for (final line in _decorate(lines, base))
            line.nodes.isEmpty
                ? SizedBox(height: (base.fontSize ?? 17) * 0.75)
                : Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1.5),
                    child: Wrap(
                      textDirection: direction,
                      alignment: WrapAlignment.start,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: 4,
                      children: _atoms(line.nodes, line.style, rule,
                          line: direction, latinSign: latinSign),
                    ),
                  ),
        ],
      ),
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

/// ⚖️ **والرقمُ اللاتينيّ لاتينيُّ الاتجاه، والعربيُّ محايد** — وهو نصُّ
///    UAX #9: `EN` يتبع ما قبله (فيصير لاتينياً بعد حرفٍ لاتيني)، و`AN`
///    عربيٌّ لا يجرّ لاتينيةً معه.
///
/// 🔴 **ولماذا لا يُعطى العربيُّ اتجاهاً عربياً صريحاً؟** جُرّب، فانكسر
///    صندوقُ المعادلة اللاتينية: «٤ / ٣» فيه صار «٣ / ٤». والسطرُ
///    العربيُّ الذي تخلّله رمزٌ لاتينيّ («١/λ = R_H») يُعالَج بـ
///    [isLatinMathLine]: يُرسم **كلُّه** من اليسار كما يطبعه الكتاب،
///    لا بترقيعِ اتجاهِ كل ذرّة.
///
/// ⭐ و«T1» دليلٌ على الفرق: رقمُها لاتينيّ فيلزم مجموعتَها فتُقرأ «T1»؛
///    ولو كان محايداً لخرج منها فوقع يمينَها فقُرئت «1T».
final _latinDigit = RegExp(r'[0-9]');

_Dir _dirOf(String s) {
  if (_arabicLetter.hasMatch(s)) return _Dir.rtl;
  if (_ltrLetter.hasMatch(s) || _latinDigit.hasMatch(s)) return _Dir.ltr;
  return _Dir.neutral;
}

/// 🔤 **سطرُ معادلةٍ رموزُه لاتينية** — فيُرسم من اليسار كلُّه.
///
/// 🔴 **ما رآه المالك (2026-09-12):** «١/λ = R_H (١/١² - ١/٢²) = R_H
///    (١/١ - ١/٤)» تخرج مبعثرةً: الأقواسُ منعكسة، و`R_H` تقع بعد قوسها،
///    والأطرافُ مقلوبة. وليست علّةَ ترتيبٍ في الرسّام وحده — **خطُّ
///    الاتجاه الثنائي نفسُه يخرجها كذلك** (قِيس بـ`TextPainter`).
///
/// ⚖️ **والسببُ أن السطر نفسَه لاتينيُّ البنية**: كلُّ رموزه (λ · R_H)
///    لاتينية أو يونانية، ولا كلمةَ عربيةً فيه. فلا ترتيبَ عربيٌّ يجعله
///    يُقرأ — والكتابُ نفسُه يطبعه من اليسار. فيُرسم كما يُطبع.
///
/// ⚠️ **وأسماءُ الترميز تُحجب أوّلاً**: «\frac» و«\sup» حروفُها لاتينية
///    فلولا حجبُها لصار كلُّ سطرٍ فيه كسرٌ «لاتينياً».
final _arabicWord = RegExp(r'[ء-ي\u0671-\u06D3]');
final _commandName = RegExp(r'\\[a-zA-Z]+');

/// اتجاهُ **الأساس** الذي يلتصق به الأُسُّ أو الدليل: آخرُ رمزٍ قويٍّ في
/// آخر كلمةٍ قبله. والرقمُ **ليس** رمزاً قوياً هنا (عربياً كان أو لاتينياً)
/// فيتبع اتجاهَ السطر — «١٠⁻⁵» في سطرٍ عربيّ أُسُّها يسارها، وفي سطرٍ
/// لاتينيّ يمينها، وكلاهما صحيحٌ في موضعه.
///
/// 🔴 **والعلّة التي أوجبته:** «R_H» في مقام كسرٍ سطرُه عربيّ خرجت «ᴴR»
///    لأن الصفَّ أخذ اتجاهَ السطر، والأساسُ لاتينيّ.
_Dir _dirOfBase(String s) {
  final token = s.trimRight().split(' ').last;
  for (final r in token.runes.toList().reversed) {
    final c = String.fromCharCode(r);
    if (_arabicWord.hasMatch(c)) return _Dir.rtl;
    if (_ltrLetter.hasMatch(c)) return _Dir.ltr;
  }
  return _Dir.neutral;
}

bool isLatinMathLine(String source) {
  final bare = source.replaceAll(_commandName, ' ');
  return !_arabicWord.hasMatch(bare) && _ltrLetter.hasMatch(bare);
}

/// اتجاهُ **محتوى** صندوقٍ — أوّلُ حرفٍ أو رقمٍ حاسمٍ فيه.
///
/// 🔴 **ولماذا لا يكون الصندوقُ محايداً دائماً؟** الدليلُ والأُسُّ
///    **لاصقانِ بأساسهما** لا عنصرانِ مستقلّان: «R_H» أساسُها لاتينيّ
///    ودليلُها «H»، فلو بقي الدليلُ محايداً لخرج من مجموعة أساسه فوقع
///    **يمينَه** — أي «H R» على الشاشة. وهي علّةٌ رآها المالك.
_Dir _dirOfNodes(List<MathNode> nodes) {
  for (final node in nodes) {
    _Dir d = _Dir.neutral;
    if (node is TextNode) {
      d = _dirOf(node.text);
    } else if (node is ScriptNode) {
      d = _dirOfNodes(node.body);
    } else if (node is BoldNode) {
      d = _dirOfNodes(node.body);
    }
    if (d != _Dir.neutral) return d;
  }
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
/// 🔄 **يعكس مجموعاتِ الاتجاه المخالف لاتجاه السطر.**
///
/// ⚖️ في سطرٍ عربيّ (RTL) تُعكس المجموعاتُ اللاتينية فتُقرأ يساراً، وفي
///    صندوق معادلةٍ كيميائية (LTR) ينعكس الدور: العربيةُ هي المخالفة.
///    وبغير ذلك تخرج حاشيةُ التفاعل «(rapid سريع)» مبعثرةً حول طرفيها.
List<_Atom> _orderOppositeGroups(List<_Atom> atoms, TextDirection line) {
  final opposite = line == TextDirection.rtl ? _Dir.ltr : _Dir.rtl;
  final native = line == TextDirection.rtl ? _Dir.rtl : _Dir.ltr;
  final out = List<_Atom>.from(atoms);
  var i = 0;
  while (i < out.length) {
    if (out[i].dir != opposite) {
      i++;
      continue;
    }
    // المجموعة تمتدّ للأمام عبر المحايدات والفراغات حتى أول ذرّة عربية.
    // ولا تمتدّ للخلف: المحايد السابق للاتينية يتبع اتجاه الفقرة (RTL)
    // وهذا هو سلوك bidi الصحيح: «الطول = RH(x)».
    final startIdx = i;
    var end = i;
    while (end + 1 < out.length && out[end + 1].dir != native) {
      end++;
    }
    // ⚖️ **وتُقلَّم من آخرها إلى آخر ذرّةٍ مخالفة**: المحايدُ بين مقطعَين
    //    لاتينيَّين لاتينيّ، والمحايدُ في آخر المقطع يتبع **اتجاه الفقرة**
    //    (UAX #9 · N1/N2). ولولا التقليم لسحب `R_H` قوسَها ومساواتَها
    //    وكلَّ ما بعدهما إلى اليسار.
    while (end > startIdx && out[end].dir != opposite) {
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
List<Widget> _atoms(List<MathNode> nodes, TextStyle style, Color rule,
        {TextDirection line = TextDirection.rtl,
        bool latinSign = false,
        bool nested = false}) =>
    [
      for (final a in _orderOppositeGroups(
          _build(nodes, style, rule,
              latinSign: latinSign, nested: nested, line: line),
          line))
        a.widget
    ];

/// [nested] = هذه الذرّاتُ **داخل صندوق** (أُسّ · كسر · جذر · شرطة علوية)،
/// أي جزءٌ من مقدارٍ أكبر لا مقدارٌ قائمٌ بنفسه — وعليه يتوقّف موضعُ
/// إشارة السالب. راجع [_loneNegative].
List<_Atom> _build(List<MathNode> nodes, TextStyle style, Color rule,
    {bool latinSign = false,
    bool nested = false,
    TextDirection line = TextDirection.rtl}) {
  final out = <_Atom>[];
  final space = (style.fontSize ?? 17) * 0.26;
  // 🔗 العقدةُ السابقة — يلزمها الأُسُّ ليعرف اتجاهَ أساسه ([_dirOfBase]).
  MathNode? prev;

  for (final node in nodes) {
    switch (node) {
      case TextNode(:final text):
        // ⚖️ «فردياً» = المقدارُ **كلُّه** عددٌ سالب (جوابٌ مفرد في خانة)،
        //    لا مجرّدُ عددٍ بين مسافتين داخل جملة — وإلا لبقيت الإشارة
        //    يساراً في «ص = -٥» وهي معادلة.
        //
        // 🔴 **وداخلَ صندوقٍ لا يكون العددُ فردياً أبداً** (طلبُ المالك
        //    2026-09-12): «الأس يطلع السالب في اليسار — خله في اليمين
        //    بدله، وبرضه لو كان في المقام». و«١٠^{-١٩}» أُسُّها عددٌ
        //    يملأ صندوقَه وحده، لكنه **جزءٌ من مقدار** لا مقدارٌ قائم —
        //    فشرطُ «فردياً» لم يكن ينطبق عليه أصلاً، وكان ينطبق بالغلط
        //    لأن الفحص كان على نصّ الصندوق لا على موضعه.
        //
        // ⭐ و«-٢» سطراً وحدَه تبقى إشارتُه يساره كما أقرّ المالك 2026-09-11.
        final alone = !nested && _loneNegative.hasMatch(text.trim());
        for (final token in _tokenize(text)) {
          if (token == ' ') {
            out.add(_Atom(SizedBox(width: space), _Dir.space));
          } else {
            // ⚠️ علّة bidi الثانية — **داخل الكلمة الواحدة**:
            //    «د(-2)» تُرسم «د(2-)» و«-1.17» تُرسم «1.17-»، لأن إشارة
            //    السالب محايدة فتأخذ اتجاه الفقرة (RTL) وتقفز خلف الرقم.
            // ✅ الحل: فصل الحروف العربية عن المقاطع الرقمية/الرمزية،
            //    وكل مقطع رقمي يُرسم LTR — فتبقى الإشارة ملتصقة بعددها.
            for (final run
                in _bidiRuns(token, alone: alone, latinSign: latinSign)) {
              out.add(_Atom(
                Text(
                  run.text,
                  style: style,
                  // 🔴 **والقوسُ ينعكس باتجاه مقطعه** (المالك 2026-09-12:
                  //    «الأقواس منعكسة»): «(» في مقطعٍ RTL تُرسم «)» —
                  //    وهو **الصواب** في سطرٍ عربي، و**العطلُ** في سطرٍ
                  //    لاتينيّ يُقرأ من اليسار. فالمقطعُ غيرُ الرقميّ
                  //    يأخذ اتجاهَ **السطر** لا العربيةَ دائماً.
                  textDirection: run.arabic ? line : TextDirection.ltr,
                ),
                _dirOf(run.text),
              ));
            }
          }
        }

      case FracNode(:final numerator, :final denominator):
        out.add(_Atom(
          _Fraction(
            numerator: _atoms(numerator, _shrink(style), rule,
                latinSign: latinSign, nested: true, line: line),
            denominator: _atoms(denominator, _shrink(style), rule,
                latinSign: latinSign, nested: true, line: line),
            rule: rule,
          ),
          _Dir.neutral,
        ));

      case FactNode(:final body):
        out.add(_Atom(
          _Factorial(
              body: _atoms(body, style, rule,
                  latinSign: latinSign, nested: true, line: line),
              style: style,
              rule: rule),
          _Dir.neutral,
        ));

      case CountNode(:final letter, :final n, :final r):
        out.add(_Atom(
          _Counting(
            letter: letter,
            n: _atoms(n, _shrink(style), rule,
                latinSign: latinSign, nested: true, line: line),
            r: _atoms(r, _shrink(style), rule,
                latinSign: latinSign, nested: true, line: line),
            style: style,
          ),
          _Dir.neutral,
        ));

      case OvlNode(:final body, :final lines):
        // ⭐ «مرافق المرافق» شرطتان فوق **نفس المقدار**، لا صندوقان
        //    متداخلان بعرضين مختلفين. فتُطوى العقدةُ الداخلية.
        final inner = (body.length == 1 && body.first is OvlNode)
            ? (body.first as OvlNode)
            : null;
        final under = inner?.body ?? body;
        out.add(_Atom(
          _Overline(
            body: _atoms(under, style, rule,
                latinSign: latinSign, nested: true, line: line),
            lines: lines + (inner?.lines ?? 0),
            ink: _inkTop(under),
            style: style,
            rule: rule,
          ),
          _Dir.neutral,
        ));

      case NucNode(:final mass, :final atomic, :final symbol):
        // ⚖️ **ذرّةٌ لاتينية الاتجاه**: رمزُ العنصر لاتينيّ، ووضعُها في
        //    مجموعةٍ لاتينية يُبقيها بجوار ما حولها من صيغٍ في المعادلة.
        out.add(_Atom(_Nuclide(mass, atomic, symbol, style), _Dir.ltr));

      case SqrtNode(:final body, :final index):
        out.add(_Atom(
          _Sqrt(
            body: _atoms(body, style, rule,
                latinSign: latinSign, nested: true, line: line),
            index: index,
            style: style,
            rule: rule,
          ),
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
        // ⚖️ والعريضُ ليس صندوقاً بل تشكيلُ خطٍّ — فيورّث حالتَه كما هي.
        out.addAll(_build(body, style.copyWith(fontWeight: FontWeight.w800), rule,
            latinSign: latinSign, nested: nested, line: line));

      case ScriptNode(:final body, :final superscript):
        final script = Transform.translate(
          offset:
              Offset(0, (style.fontSize ?? 17) * (superscript ? -0.34 : 0.26)),
          child: Wrap(
            // ⬅️ يرث اتجاهَ السطر — راجع [MathText.build].
            crossAxisAlignment: WrapCrossAlignment.center,
            children: _atoms(body, _script(style), rule,
                latinSign: latinSign, nested: true, line: line),
          ),
        );
        // 🔴 **والأُسُّ لا يُترك في سطرٍ وأساسُه في آخر** (رآه المالك
        //    2026-09-12): «… × ١٠» تنتهي السطر و«⁻⁵ سم» تبدأ الذي يليه،
        //    فيظهر الأُسُّ نشازاً بلا عدد. و`Wrap` يلفّ **بين ذرّتين**،
        //    فالأساسُ وأُسُّه يُدمجان ذرّةً واحدة لا تُفرَّق.
        //
        // ⚖️ ولا يُدمج إلا ما كان **لاصقاً**: فراغٌ قبله يعني أُسّاً
        //    مستقلاً («\sup{٢}» في أول سطر) فيبقى وحده.
        if (out.isNotEmpty && out.last.dir != _Dir.space) {
          final base = out.removeLast();
          out.add(_Atom(
            Row(
              mainAxisSize: MainAxisSize.min,
              // ⚖️ **واتجاهُ الصفّ من اتجاه الأساس** لا من اتجاه السطر:
              //    «R_H» أساسُها لاتينيّ فدليلُها يساره («R» ثم «H»)،
              //    و«س²» أساسُها عربيٌّ فأُسُّه يساره كما في الكتاب.
              //    ولولا ذلك خرجت «ᴴR» في مقام كسرٍ عربيّ السطر.
              textDirection: switch (
                  prev is TextNode ? _dirOfBase(prev.text) : _Dir.neutral) {
                _Dir.ltr => TextDirection.ltr,
                _Dir.rtl => TextDirection.rtl,
                _ => line,
              },
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [base.widget, script],
            ),
            base.dir == _Dir.neutral ? _dirOfNodes(body) : base.dir,
          ));
        } else {
          out.add(_Atom(script, _dirOfNodes(body)));
        }
    }
    prev = node;
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
/// ما يجعل الإشارة **ثنائيةً** (طرحاً) لا أحاديةً (سالباً): مقدارٌ قبلها.
///
/// 🔴 **العطل الذي رآه المالك (2026-09-10):** «\frac{ع-١}{ع+١}» خرجت على
///    الشاشة «-١ع» فوق «+١ع». والسبب أن `_numberRun` يبتلع الإشارة فيقرأ
///    «ع-١» كأنها «ع» ثم «سالب واحد»، فيصير المقطعان ذرّتين تُرتّبان RTL
///    فتقفز الإشارة والرقم إلى يسار «ع» معاً.
///
/// ⚖️ والتمييز هو نفسه الذي في [core/fractions.py]: الإشارة بعد **مقدار**
///    عمليةُ حساب، وبعد بدايةٍ أو قوسٍ أو عاملٍ آخر إشارةُ عدد.
final _operandEnd = RegExp(r'[0-9٠-٩\u0621-\u064AA-Za-z)\]}²³⁴⁵⁶⁷⁸⁹⁰⁻⁺]');

/// عددٌ سالبٌ يملأ المقدار وحده: «-٥» · «-١٫١٧».
final _loneNegative = RegExp(r'^[-−+][0-9٠-٩][0-9٠-٩.,٫]*$');

List<_Run> _bidiRuns(String token,
    {bool alone = false, bool latinSign = false}) {
  final raw = <_Run>[];
  var last = 0;
  for (final m in _numberRun.allMatches(token)) {
    var start = m.start;
    var body = m.group(0)!;
    // ➖ إشارةٌ تلي مقداراً ⇒ عاملُ طرحٍ يبقى مع ما قبله، لا جزءاً من العدد.
    if (RegExp(r'^[-−+]').hasMatch(body) &&
        start > 0 &&
        _operandEnd.hasMatch(token[start - 1])) {
      start += 1;
      body = body.substring(1);
    }
    if (start > last) raw.add(_Run(token.substring(last, start), true));

    // ➖➖ **السالبُ الأحاديّ عن يمين العدد** (قرار المالك 2026-09-11):
    //     «في اللغة العربية السالب يكون على يمين الرقم… بس لما يكون
    //     individually خلّيه على يسار الرقم».
    //
    // ⭐ فالإشارةُ تُفصل ذرّةً مستقلّة تسبق العدد **منطقياً**، والصفُّ
    //    RTL يضع الأولَ يميناً — فتظهر «١-» لا «-١».
    //
    // ⚖️ **والاستثناء: العدد وحده.** إن كان المقطعُ كلُّه هو العددَ
    //    السالب («-٥» جواباً مفرداً) بقيت الإشارة يساره كما هي.
    // 🔴 **والقاعدةُ للأرقام العربية وحدها** (توضيحُ المالك 2026-09-12):
    //    «الرقم إنجليزي؟ السالب على **يساره**. رقمٌ عربي؟ على **يمينه**».
    //    فالكيمياء والفيزياء أرقامُهما لاتينية، و«-1» فيهما تُكتب هكذا
    //    لا «1-». والقاعدةُ العربية كانت تُطبَّق على الاثنين.
    final arabicNumber = RegExp(r'^[-−+][٠-٩]').hasMatch(body);
    final unary = RegExp(r'^[-−+]').hasMatch(body);
    if (unary && !alone && (arabicNumber || !latinSign)) {
      raw.add(_Run(body[0], true));
      raw.add(_Run(body.substring(1), false));
    } else {
      raw.add(_Run(body, false));
    }
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
          // ⬅️ يرث اتجاهَ السطر — راجع [MathText.build].
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: atoms,
        ),
      );
}

// ── الجذر: علامة √ يمتد سقفها فوق المقدار ──
/// ⌋ **رمز المضروب العربي** (قرار المالك 2026-09-10، مُصحَّحاً):
/// «خط، بعدين خط إلى اليسار… الـL بس مقلوب لليسار، مش لليمين، والنون فوقه».
///
/// 🔴 أي: ضلعٌ قائم عن **يمين** المقدار، وقاعدةٌ تمتدّ **يساراً تحته** —
///    زاويةٌ تفتح يساراً وأعلى. وكنتُ عكستُها للأعلى فردّها المالك:
///    «أنت عكسته لفوق، لا».
///
/// ⚖️ والقاعدة تطول بطول ما تحتضنه، فمضروبُ «ن²-ن-٢» يجرّ خطّه فوق المقدار
///    كلِّه — وهذا سببُ رسمها حَدّاً لصندوقٍ لا محرفاً ثابت العرض.
///
/// ⚖️ فالطالب اليمني يقرأ «⌋ن» لا «n!»؛ وعلامةُ التعجّب صيغةٌ إنجليزية
///    غريبةٌ عن كتابه.
class _Factorial extends StatelessWidget {
  const _Factorial({required this.body, required this.style, required this.rule});

  final List<Widget> body;
  final TextStyle style;
  final Color rule;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 17;
    return Container(
      // القاعدة أسفل، والضلع عن اليمين — زاويةٌ تفتح يساراً وأعلى.
      padding: EdgeInsets.fromLTRB(size * 0.12, 0, size * 0.2, size * 0.1),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: rule, width: 1.4),
          right: BorderSide(color: rule, width: 1.4),
        ),
      ),
      child: Wrap(
        // ⬅️ يرث اتجاهَ السطر — راجع [MathText.build].
        crossAxisAlignment: WrapCrossAlignment.center,
        children: body,
      ),
    );
  }
}

/// ⁿلᵣ **رمز التباديل/التوافيق العربي** (قرار المالك 2026-09-10):
/// «الـل والقاف… ويكون الـن فوق، والراء تحت».
///
/// ⭐ فالترتيب في العربية من اليمين: **ن مرفوعة** ثم الحرف ثم **ر منخفضة**
///    — مرآةُ ⁿPᵣ اللاتينية. ولذلك الصفُّ `rtl` والإزاحةُ رأسيةٌ صريحة.
///
/// ⚖️ والحرف من الكتاب («ل» · «ق») لا «P» و«C»؛ وقاف الكتاب بذيلها هي
///    نفسُها محرفُ اللغة، فلا حاجة لرسمها يدوياً.
class _Counting extends StatelessWidget {
  const _Counting(
      {required this.letter,
      required this.n,
      required this.r,
      required this.style});

  final String letter;
  final List<Widget> n;
  final List<Widget> r;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 17;
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Transform.translate(
          offset: Offset(0, -size * 0.34),
          child: Wrap(textDirection: TextDirection.rtl, children: n),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: size * 0.05),
          child: Text(letter, style: style, textDirection: TextDirection.rtl),
        ),
        Transform.translate(
          offset: Offset(0, size * 0.30),
          child: Wrap(textDirection: TextDirection.rtl, children: r),
        ),
      ],
    );
  }
}

/// ‾ **الشرطة العلوية مرسومةً لا محرفاً** (قرار المالك 2026-09-11).
///
/// 🔴 الكتاب يكتبها محرفاً مركّباً: «ع̅» (U+0305) للمرافق، وفتحةً «أَ»
///    للمتمّمة. وكلاهما يعمل فوق **حرفٍ واحد** فقط؛ فإذا وقع بعد قوسٍ
///    مغلق — «(أ ∪ ب)َ» — التصق بالقوس نفسه فلا يظهر شيء.
///    وهذا نصُّ شكوى المالك: «لما تكون الشرطة على القوس كامل… ما تطلع».
///
/// ⭐ فالعلاج حَدٌّ علويّ لصندوقٍ يحتضن المقدار كلَّه، فيطول بطوله.
/// 📏 **أعلى ما يبلغه حبرُ المقدار فوق سطر الكتابة** — بنسبةِ قياس الخط.
///
/// ⚖️ فلاتر لا تكشف حدودَ الحبر (ink bounds): كلُّ ما تعطيه `TextPainter`
///    هو صعودُ **الخطّ كلِّه**، رقمٌ واحد لا يفرّق بين «ع» و«أ». فقِيست
///    الأرقامُ من ملفّ خطّ التطبيق نفسِه (Cairo Regular ⇐ `google_fonts`)
///    بـ `fontTools`: `glyph.yMax / unitsPerEm`.
///
/// 🔴 **وهي علّةُ المالك (2026-09-12):** «الألف الخط يشبك مع الهمزة».
///    فالهمزةُ فوق الألف تبلغ ٠٫٩٦ من قياس الخط، و«ع» و«ب» يقفان عند
///    ٠٫٥٠ — أي أن بينهما **٧٫٩ بكسل** عند قياس ١٧. وخلوصٌ ثابتٌ من سقف
///    الصندوق يقع فوق «ع» مريحاً ويمرّ في **وسط الهمزة**.
double _inkTop(List<MathNode> nodes) {
  var top = 0.50; // القاعدة: «ع ب م س ح و ر د ه ي ج ص»
  for (final n in nodes) {
    switch (n) {
      case TextNode(:final text):
        for (final r in text.runes) {
          final h = _inkOf[String.fromCharCode(r)];
          if (h != null && h > top) top = h;
        }
      case BoldNode(:final body) || OvlNode(:final body):
        final h = _inkTop(body);
        if (h > top) top = h;
      default:
        // ⚠️ كسرٌ أو جذرٌ أو أُسٌّ تحت الشرطة: صندوقُه أعلى من أيّ حرف،
        //    فتُرفع الشرطةُ فوق الصندوق كلِّه ولا تُخمَّن ارتفاعاً.
        return _lineAscent;
    }
  }
  return top;
}

/// ارتفاعُ حبر كلِّ محرفٍ يعلو القاعدة — ما لم يُذكر فهو ٠٫٥٠.
const Map<String, double> _inkOf = {
  'أ': 0.96, 'آ': 0.87, 'ش': 0.81, 'ؤ': 0.77,
  'ا': 0.72, 'إ': 0.72, 'ل': 0.72, 'ك': 0.72, 'ط': 0.72, 'ظ': 0.72,
  '(': 0.75, ')': 0.75, '[': 0.75, ']': 0.75, '{': 0.75, '}': 0.75,
  '/': 0.71, '|': 0.72, '؟': 0.70, '?': 0.70, '!': 0.69,
  // ⚠️ رموزُ المجموعات ليست في Cairo أصلاً — يرسمها خطٌّ احتياطيّ مجهولُ
  //    المقاييس، فتُقدَّر بارتفاع القوس وهو أعلى ما يُنتظر منها.
  '∪': 0.75, '∩': 0.75, '∈': 0.75, '∅': 0.75, '⇔': 0.75, '←': 0.75,
  '→': 0.75, '∴': 0.75, '−': 0.31, '-': 0.31, '=': 0.38, '،': 0.23,
  '.': 0.12, ',': 0.11, 'ـ': 0.07, 'ء': 0.43, '٠': 0.37,
  'ة': 0.68, 'ذ': 0.68, 'ز': 0.68, 'غ': 0.68, 'ف': 0.68, 'ق': 0.68,
  'ض': 0.68, 'خ': 0.66, 'ث': 0.71, 'ن': 0.59, 'ت': 0.58,
  '١': 0.66, '٢': 0.66, '٣': 0.66, '٤': 0.68, '٥': 0.66, '٦': 0.66,
  '٧': 0.66, '٨': 0.66, '٩': 0.66,
  '0': 0.67, '1': 0.66, '2': 0.67, '3': 0.67, '4': 0.66, '5': 0.66,
  '6': 0.67, '7': 0.66, '8': 0.67, '9': 0.67,
};

// ══════════ مقاييسُ خطّ التطبيق (Cairo Regular) ══════════
// hhea: ascent = 1.303 em · descent = 0.571 em · lineGap = 0.
const double _fontAscent = 1.303;
const double _fontDescent = 0.571;

/// صعودُ **سطرٍ بقياسٍ طبيعيّ** — يُستعمل حين لا يكون تحت الشرطة حرفٌ
/// يُقاس (كسرٌ مثلاً)، فتُرفع الشرطة فوق الصندوق كلِّه.
const double _lineAscent = _fontAscent;

/// ‾ **الشرطة العلوية مرسومةً لا محرفاً** (قرار المالك 2026-09-11).
///
/// 🔴 الكتاب يكتبها محرفاً مركّباً: «ع̅» (U+0305) للمرافق، وفتحةً «أَ»
///    للمتمّمة. وكلاهما يعمل فوق **حرفٍ واحد** فقط؛ فإذا وقع بعد قوسٍ
///    مغلق — «(أ ∪ ب)َ» — التصق بالقوس نفسه فلا يظهر شيء.
///    وهذا نصُّ شكوى المالك: «لما تكون الشرطة على القوس كامل… ما تطلع».
///
/// ⭐ فالعلاج حَدٌّ علويّ لصندوقٍ يحتضن المقدار كلَّه، فيطول بطوله.
class _Overline extends StatelessWidget {
  const _Overline(
      {required this.body,
      required this.lines,
      required this.ink,
      required this.style,
      required this.rule});

  final List<Widget> body;
  final int lines;

  /// أعلى ما يبلغه حبرُ ما تحتها — راجع [_inkTop].
  final double ink;
  final TextStyle style;
  final Color rule;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 17;

    // 🔴 **الشرطة تلامس الحرف** (قرار المالك 2026-09-11): «الشرطة بعيدة
    //    من العين… ضروري تكون فوقه، خلّه بالمعقول».
    //
    // ⚖️ ولا تُقاس من سقف الصندوق: صندوقُ النصّ أطولُ من الحرف بكثير
    //    («ع» بقياس ١٧ في صندوقٍ ٢٩)، وارتفاعُ الحرف نفسِه متغيّر. فتُقاس
    //    من **أعلى حبر الحرف** — فتبقى الفجوة واحدةً فوق «ب» وفوق «أ»،
    //    وهي علّةُ المالك الأخيرة: «الألف الخط يشبك مع الهمزة».
    const clearance = 0.347; // ما أقرّه المالك فوق «ب» — ٥٫٩ بكسل عند ١٧
    const thickness = 1.3;
    const step = 0.17; // بين الشرطتين في «مرافق المرافق»

    // موضعُ خطّ الكتابة داخل الصندوق: `height` توزّع الفراغ على الصعود
    // والهبوط بنسبتهما في الخط، فلا يصحّ أخذُ الصعود خاماً.
    final h = style.height;
    final ascent = h == null
        ? _fontAscent
        : _fontAscent / (_fontAscent + _fontDescent) * h;

    // من سقف الصندوق إلى أعلى الحبر، ثم إلى أعلى الشرطة.
    final barTop = (ascent - ink) * size - clearance * size - thickness;

    // ⭐ فإن ضاق الصندوق عن الشرطة — والألفُ تبلغ سقفَه تقريباً — زِيد
    //    السطرُ ارتفاعاً بدل أن تُقحم الشرطةُ في السطر الذي فوقه.
    final head = barTop < 0 ? -barTop : 0.0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsets.only(top: head + size * step * (lines - 1)),
          child: Wrap(
            // ⬅️ يرث اتجاهَ السطر — راجع [MathText.build].
            crossAxisAlignment: WrapCrossAlignment.center,
            children: body,
          ),
        ),
        for (var k = 0; k < lines; k++)
          Positioned(
            left: 0,
            right: 0,
            top: head + barTop + size * step * k,
            child: Container(height: thickness, color: rule),
          ),
      ],
    );
  }
}


/// ☢️ **العددُ الكتلي فوق الذرّي ثم الرمز** — كما يُطبع في كتاب الكيمياء.
///
/// ⚖️ والعددان **مصفوفان إلى اليمين**: هكذا تُطبع في الكتاب حين يختلف
///    طولُهما (²³⁵ فوق ₉₂)، فيلتقيان عند حافّة الرمز.
class _Nuclide extends StatelessWidget {
  const _Nuclide(this.mass, this.atomic, this.symbol, this.style);

  final String mass;
  final String atomic;
  final String symbol;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 17;
    final small = style.copyWith(fontSize: size * 0.62, height: 1.05);
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(mass, style: small, textDirection: TextDirection.ltr),
              Text(atomic, style: small, textDirection: TextDirection.ltr),
            ],
          ),
          if (symbol.isNotEmpty)
            Text(symbol, style: style, textDirection: TextDirection.ltr),
        ],
      ),
    );
  }
}

class _Sqrt extends StatelessWidget {
  const _Sqrt(
      {required this.body,
      required this.index,
      required this.style,
      required this.rule});

  final List<Widget> body;
  final String index;
  final TextStyle style;
  final Color rule;

  @override
  Widget build(BuildContext context) {
    // 🔴 **جذرٌ عربيّ يُقرأ من اليمين** (قرار المالك 2026-09-10):
    //    «حط جذر حق اللغة العربية، اللي هو من اليمين لليسار».
    //
    // ⚖️ فالعلامة على **يمين** المقدار وسقفُها يمتدّ يساراً فوقه — كما
    //    تُطبع في كتب الرياضيات العربية. والرمز نفسه يُعكس أفقياً، وإلا
    //    خرج ذيلُه في الجهة الخطأ فبدا الجذر مكسوراً.
    final size = style.fontSize ?? 17;
    // ⭐ الدليلُ يقع في **حضن العلامة**: أعلاها وفي الجهة التي يبدأ منها
    //    الرسم — وهي هنا **اليمين** لأن العلامة معكوسة للعربية.
    final sign = Transform(
      alignment: Alignment.center,
      transform: Matrix4.diagonal3Values(-1, 1, 1),
      child: Text('√', style: style.copyWith(fontSize: size * 1.3)),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      textDirection: TextDirection.rtl,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (index.isEmpty)
          sign
        else
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              sign,
              Positioned(
                top: -size * 0.12,
                right: size * 0.62,
                child: Text(index,
                    style: style.copyWith(
                        fontSize: size * 0.6, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        Container(
          padding: const EdgeInsets.fromLTRB(3, 2, 3, 0),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: rule, width: 1.4)),
          ),
          child: Wrap(
            // ⬅️ يرث اتجاهَ السطر — راجع [MathText.build].
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
// 🔴 **والعدد العشريّ لا يُقطع** (2026-09-12): «١ / ١٠٩٧٣٧.٣١» كانت
//    تُقرأ «١ على ١٠٩٧٣٧» ويتشرّد «.٣١» وحده في السطر — ثابتُ ريدبيرغ
//    يخرج مبعثراً على الشاشة. فالعشريُّ جزءٌ من عدده بسطاً ومقاماً.
// 🔴 **وأُسُّ المقام جزءٌ منه** (2026-09-12): «١/١\sup{٢}» كانت تُرفع
//    «\frac{١}{١}» ويبقى الأُسُّ **خارج** الكسر فيطفو بجانبه بلا أساس —
//    ومعناها ١/١² لا (١/١)². فيُلتقط مع مقامه.
final _decimal = r'[0-9٠-٩]+(?:[.,][0-9٠-٩]+)?';
final _supTail = r'(?:\\sup\{[^{}]*\})?';
final _pureNumericFraction = RegExp(
  r'(?<![\w٠-٩؀-ۿ.,])'          // لا حرف ولا رقم ولا فاصلةَ عشريّ قبله
  '($_decimal$_supTail)' r'\s*/\s*' '($_decimal$_supTail)'
  r'(?![\w٠-٩/\\]|[.,][0-9٠-٩])', // ولا بعده (ولا شرطةٌ ثانية ولا ترميز)
);

/// يحوّل «١/٥» إلى `\frac{١}{٥}` ويترك ما عداه كما هو.
String liftNumericFractions(String text) {
  if (!text.contains('/')) return text;
  return text.replaceAllMapped(
    _pureNumericFraction,
    (m) => '\\frac{${m.group(1)}}{${m.group(2)}}',
  );
}
