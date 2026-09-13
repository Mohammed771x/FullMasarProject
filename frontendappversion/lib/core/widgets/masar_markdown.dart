// ============================================================
// 📝 masar_markdown.dart — ماركداون المشروع + كسور بسطاً ومقاماً
// ============================================================
// المشكلة: `MarkdownBody` يرسم النص ممتازاً لكنه لا يعرف `\frac`. ورسمُ
// الكسر يحتاج ويدجت داخل السطر — و`WidgetSpan` في فقرة عربية **تُقلب
// ترتيبها** خوارزميةُ الاتجاه الثنائي (راجع `math_text.dart`).
//
// الحل هنا مُحافظ عمداً:
//   • السطر الذي **لا يحوي** `\frac` أو `\sqrt` ⇒ يمرّ إلى `MarkdownBody`
//     كما كان حرفياً — فلا يتغيّر شيء في ٩٥٪ من الرسائل.
//   • السطر الذي يحوي كسراً ⇒ يُرسم بـ`MathText` مع دعم مبسّط للماركداون
//     الذي يظهر فعلاً في ردود الخادم (**عريض** · ### عنوان · - نقطة).
//
// الأسطر المتجاورة من النوع نفسه تُجمَّع في كتلة واحدة كي تبقى القوائم
// والجداول سليمة كما يبنيها `MarkdownBody`.

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'chem_equation.dart';
import 'math_text.dart';

// ══════════════════════════════════════════════════
// 🛡️ حارس اللاتيك على الجهاز — نظير `core/latex_guard.py`
// ══════════════════════════════════════════════════
// 🔴 **لماذا يلزم حارسٌ ثانٍ والخادم ينظّف؟** لأن **البثّ يسبق التنظيف**:
//    الخادم يُنقّي الجواب في نهايته ويرسله في حدث `done`، أما الأجزاء
//    فتصل خاماً لحظةً بلحظة. فطالبٌ يشاهد شرح تكاملٍ يُبثّ يرى «int»
//    و«quad» تمرّ أمامه ثم تُصحَّح — ومرورُها هو ما اشتكى منه المالك.
//
// 🎯 والمطلوب يقينٌ لا احتمال: «ما أبغى ولا واحد بالمية». فالخادم يحرس
//    المحفوظ، وهذا يحرس **ما يُعرض**.
//
// ⚠️ ولا يمسّ ما يرسمه التطبيق: `\frac` · `\sqrt` · `\chem` · `\ring`.
const Map<String, String> _latexSymbols = {
  r'\iint': '∬', r'\oint': '∮', r'\int': '∫',
  r'\sum': 'Σ', r'\prod': '∏', r'\infty': '∞',
  r'\theta': 'θ', r'\alpha': 'α', r'\beta': 'β', r'\gamma': 'γ',
  r'\delta': 'δ', r'\Delta': 'Δ', r'\lambda': 'λ', r'\mu': 'μ',
  r'\sigma': 'σ', r'\omega': 'ω', r'\pi': 'π',
  r'\times': '×', r'\div': '÷', r'\pm': '±', r'\mp': '∓',
  r'\leq': '≤', r'\le': '≤', r'\geq': '≥', r'\ge': '≥',
  r'\neq': '≠', r'\ne': '≠', r'\approx': '≈', r'\equiv': '≡',
  r'\implies': '⟸', r'\Rightarrow': '⟸',
  r'\rightarrow': '←', r'\to': '←', r'\leftarrow': '→',
  r'\propto': '∝', r'\notin': '∉', r'\in': '∈',
  r'\subset': '⊂', r'\cup': '∪', r'\cap': '∩',
  r'\forall': '∀', r'\exists': '∃', r'\partial': '∂', r'\nabla': '∇',
  r'\circ': '∘', r'\cdot': '·', r'\ldots': '…', r'\dots': '…',
  r'\prime': '′', r'\angle': '∠', r'\perp': '⊥', r'\parallel': '∥',
  r'\therefore': '∴', r'\because': '∵',
};

/// أوامر يُحذف اسمها ويبقى ما حولها (`\left(` ⇒ `(`).
const List<String> _latexFormatting = [
  r'\displaystyle', r'\textstyle', r'\nolimits', r'\limits',
  r'\qquad', r'\quad', r'\left', r'\right',
];

/// أوامر بوسيطٍ واحد يبقى وسيطها (`\text{كلام}` ⇒ «كلام»).
final RegExp _latexArgCmd = RegExp(
    r'\\(text|mathrm|mathbf|mathit|textbf|textit|operatorname|boxed)\s*\{([^{}]*)\}');

/// ما يرسمه التطبيق فلا يُمسّ.
/// ⚠️ **مُشتقٌّ من [kMathTokens] لا مكتوبٌ بيده**: قائمةٌ منسوخة تتخلّف
///    يوماً عن الأصل فيُمسح ترميزٌ يرسمه التطبيق (أو يبقى واحدٌ لا يرسمه).
final RegExp _latexLeftover = RegExp(
    r'\\(?!' +
        kMathTokens.map((t) => t.substring(1)).join('|') +
        r')([a-zA-Z]+)');

/// يحوّل كل LaTeX لا يرسمه التطبيق إلى رمزه، أو يحذفه.
///
/// ⚠️ **يعمل على النصّ المعروض لا على الجزء الواصل**: أمرٌ مقطوع بين جزأين
///    (`\in` ثم `t`) كان سيُحوَّل خطأً إلى «∈» ثم يظهر «t» وحدها. والعرض
///    يبني النصّ المتراكم كاملاً في كل مرة، فلا يقع ذلك هنا.
String stripUnsupportedLatex(String text) {
  if (!text.contains(r'\')) return text;   // 🚀 الغالبية تخرج فوراً

  var out = text;
  for (var i = 0; i < 3 && _latexArgCmd.hasMatch(out); i++) {
    out = out.replaceAllMapped(_latexArgCmd, (m) => m.group(2) ?? '');
  }

  // ⚠️ الأطول أولاً: وإلا التهمت `\in` بدايةَ `\infty`.
  final ordered = _latexSymbols.keys.toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final cmd in ordered) {
    if (out.contains(cmd)) {
      out = out.replaceAll(RegExp('${RegExp.escape(cmd)}(?![a-zA-Z])'),
          _latexSymbols[cmd]!);
    }
  }
  for (final cmd in _latexFormatting) {
    if (out.contains(cmd)) {
      out = out.replaceAll(RegExp('${RegExp.escape(cmd)}(?![a-zA-Z])'), '');
    }
  }
  // ما بقي ولم نعرفه: يُحذف اسمه ولا يبقى إنجليزياً على شاشة الطالب.
  out = out.replaceAll(_latexLeftover, '');
  return out.replaceAll(RegExp(r'[ \t]{2,}'), ' ');
}


/// ما يدلّ على أن ما بين القوسين **معادلةٌ** لا بنيةً واحدة.
final RegExp _equationInsideChem = RegExp(r'--+>|<--+|<=+>|⇌|\+');

/// يفكّ `\chem{}` إذا غلّف معادلةً كاملة — نظير `core/chem.unwrap_equation_chem`.
///
/// 🔴 **ما رآه المالك (2026-09-09):** «RIGHT OVERFLOWED BY 140 PIXELS» وقوسٌ
///    شاردٌ «}» في درس الإيثرات. والسبب أن الموديل كتب
///    `\chem{CH3CH2-O-CH2CH3 + 2HBr --> …}` — و`\chem` تعني «سلسلةٌ واحدة»
///    فيبني الرسّام صفّاً لا ينكسر عرضُه أضعافُ الشاشة.
///
/// ⚖️ **ولماذا هنا والخادمُ ينزعه؟** لنفس سبب حارس اللاتيك أعلاه: **البثّ
///    يسبق التنظيف**، فالأجزاء تصل خاماً وتُعرض قبل أن يُنقّى الجواب.
String unwrapEquationChem(String text) {
  if (!text.contains(r'\chem{')) return text;
  final out = StringBuffer();
  var i = 0;
  while (true) {
    final j = text.indexOf(r'\chem{', i);
    if (j < 0) {
      out.write(text.substring(i));
      break;
    }
    out.write(text.substring(i, j));
    var k = j + 6;
    var depth = 1;
    while (k < text.length && depth > 0) {
      if (text[k] == '{') {
        depth++;
      } else if (text[k] == '}') {
        depth--;
      }
      k++;
    }
    final body = depth == 0
        ? text.substring(j + 6, k - 1)
        : text.substring(j + 6);
    out.write(_equationInsideChem.hasMatch(body) ? body : text.substring(j, k));
    i = k;
    if (depth > 0) break;
  }
  return out.toString();
}

/// ➖ **إشارةُ العدد اللاتينيّ تُعزل كي تبقى يسارَه.**
///
/// 🔴 **ما رآه المالك (2026-09-12):** «الرقم إنجليزي والسالب يظهر على
///    يمينه — المفروض على يساره». والقياسُ يؤكّده حرفياً:
///
/// | النصّ | كما يُرسم | الصواب |
/// |---|---|---|
/// | `-1` وحده | «1-» | «-1» |
/// | «الطاقة -25.9 كيلوجول» | «25.9-» | «-25.9» |
/// | «قيمة ΔH = -286 …» | «-286» ✓ | — |
///
/// ⚖️ والثالثةُ تصحّ وحدها لأن «ΔH» لاتينيٌّ قويٌّ قبلها. فالعلّةُ تقع
///    حيثما جاور العددَ **حرفٌ عربي**، وعلاجُها عزلُ العدد بمحارف
///    الاتجاه (U+2066 … U+2069) فيُقرأ من اليسار داخل الفقرة العربية.
///
/// 🔒 **وثلاثةُ حرّاس تمنع الخلط** — كلُّها من مسح المنهج:
///    1. **أرقامٌ لاتينية فقط**: «-٥» إشارتُها يمينَها بقرار المالك،
///       و«٢- اكتب» ترقيمُ سؤال.
///    2. **لا طرحاً ثنائياً**: «90 - 30 = 60» و«370-428 هـ» مدىً وطرح،
///       يسبقُ الإشارةَ فيهما رقمٌ أو قوسٌ مغلق (١٨٣ موضعاً).
///    3. **الرقمُ يلي الإشارةَ بلا فراغ**: «( 370 - 428 )» تخرج بذلك.
final RegExp _signedNumber = RegExp(r'[-−+]\d+(?:[.,]\d+)?');

/// ما يجعل الإشارةَ عاملَ طرحٍ لا إشارةَ عدد: مقدارٌ قبلها.
final RegExp _operandBefore = RegExp(r'[0-9٠-٩A-Za-z)\]]');

String isolateSignedNumbers(String text) {
  if (!text.contains(RegExp(r'[-−+]\d'))) return text;
  return text.replaceAllMapped(_signedNumber, (m) {
    var i = m.start - 1;
    while (i >= 0 && text[i] == ' ') {
      i--;
    }
    if (i >= 0 && _operandBefore.hasMatch(text[i])) return m.group(0)!;
    return '\u2066${m.group(0)}\u2069';
  });
}

/// نصٌّ لا حرفَ عربياً فيه ولا رقماً عربياً — يُقرأ من اليسار.
///
/// ⚖️ **والرقمُ العربيّ يُخرجه من الحكم**: «-٥» إشارتُها يمينَ الرقم بقرار
///    المالك، وهي القاعدة العربية. أمّا «-1» فلاتينيةٌ وإشارتُها يسارَه.
final RegExp _arabicBlock = RegExp(r'[\u0600-\u06FF]');

bool isPureLatin(String text) => !_arabicBlock.hasMatch(text);

/// هل يحتاج هذا السطر رسّام الرياضيات؟ — القائمةُ في [kMathTokens] وحدها.
bool _needsMath(String line) => hasMathMarkup(line);

/// يرفع الكسور الرقمية البحتة إلى ترميز `\frac` قبل الفحص والرسم.
String _prepare(String text) =>
    liftNumericFractions(stripUnsupportedLatex(unwrapEquationChem(text)));

/// هل يحتاج النصّ كلّه رسّام الرياضيات؟ (فحص رخيص قبل أي تقسيم)
bool containsMath(String text) => _needsMath(_prepare(text));

/// هل فيه معادلةُ تفاعلٍ تحتاج عزلَ الاتجاه؟
///
/// 🔴 **بلا هذا الفحص لا يعمل الإصلاح إطلاقاً**: شرحُ الألدهيدات كلُّه
///    معادلاتٌ ولا كسرَ فيه، فكان الخروج المبكر يسلّمه إلى `MarkdownBody`
///    قبل أن يصل التقسيمُ أصلاً — أي إصلاحٌ لا يُنادى.
/// أرخصُ فحصٍ ممكن قبل تقسيم الأسطر.
///
/// ⚠️ **وقد أخطأ مرّتين لأنه حاول أن يكون أذكى من اللازم**: اشترط «>»
///    فأسقط سهمَ الاتزان «⇌»، ثم أسقط السهمَ الأيسر «<--تكثف--» لأنه بلا
///    «>» أيضاً. فصار الشرطُ على **ما يشترك فيه كل الأسهم** لا على صورةٍ
///    منها: شرطتان متتاليتان، أو رمزُ سهمٍ يونيكوديّ.
///
/// 🔴 وأُضيف `->` و`<-` و`=>` (2026-09-12): شرطةٌ واحدة لا شرطتان، وهي
///    ما يكتبه الموديل في ثلث معادلاته — فكان الفحصُ يخرج من بابه الأول
///    ولا تصل المعادلةُ الرسّامَ أصلاً.
final RegExp _arrowHint = RegExp(r'->|<-|--|=>|⇌|⟶|⟵|→|←');

bool _hasEquation(String text) =>
    _arrowHint.hasMatch(text) &&
    text.split('\n').any((l) => readEquation(l) != null);

/// نوع الكتلة: نصٌّ عادي · سطرُ كسور · معادلةُ تفاعل · جدول.
enum _Kind { text, math, equation, table }

class _Block {
  _Block(this.kind, this.lines, {this.label = ''});
  final _Kind kind;
  final List<String> lines;

  /// عنوانُ المعادلة إن كان لها عنوان ([readEquation]).
  final String label;
  String get text => lines.join('\n');
}

/// هل في كتلة الجدول ترميزٌ يعجز عنه الماركداون؟
///
/// ⚖️ **وإلّا فالماركداون أولى**: هو يرسم الجداول أصلاً وأجمل، فلا
///    نعترضها إلا حين تحمل خليّةٌ ما لا يعرفه — كسراً أو رمزَ نواة أو
///    معادلةَ تفاعل.
bool _tableNeedsUs(List<String> rows) => rows.any((r) =>
    _needsMath(r) || RegExp(r'--+>|<--+|⇌|⟶|⟵|→|←|->').hasMatch(r));

List<_Block> _split(String data, {bool equations = true}) {
  final lines = data.split('\n');
  final blocks = <_Block>[];
  final buffer = <String>[];

  void flush() {
    if (buffer.isEmpty) return;
    blocks.addAll(_splitPlain(buffer.join('\n'), equations: equations));
    buffer.clear();
  }

  // 📊 **الجداول تُلتقط أولاً**: صفُّ جدولٍ فيه معادلة كان يُخطف إلى صندوق
  //    المعادلة بأعمدته وشرطاته — وهي علّةُ المالك (2026-09-12).
  var i = 0;
  while (i < lines.length) {
    if (isTableRow(lines[i])) {
      var end = i;
      while (end + 1 < lines.length && isTableRow(lines[end + 1])) {
        end++;
      }
      final rows = lines.sublist(i, end + 1);
      if (rows.length >= 2 && _tableNeedsUs(rows)) {
        flush();
        blocks.add(_Block(_Kind.table, rows));
        i = end + 1;
        continue;
      }
    }
    buffer.add(lines[i]);
    i++;
  }
  flush();
  return blocks;
}

List<_Block> _splitPlain(String data, {bool equations = true}) {
  final blocks = <_Block>[];
  for (final line in data.split('\n')) {
    // ⚗️ **المعادلة تسبق فحص الكسور**: «--[Cu / 200 م]-->» فيها شرطة
    //    مائلة، فلو فُحصت ككسرٍ أولاً لسُحبت إلى رسّام الرياضيات وخرجت
    //    شرطُ التفاعل بسطاً ومقاماً — وهو عين ما اشتكى منه المالك.
    // ⭐ و`readEquation` تفصل العنوانَ عن المعادلة: «2. **معادلة انشطار
    //    اليورانيوم-235:** U-235 + …» عنوانُها عربيّ ومعادلتُها لاتينية،
    //    وخلطُهما في فقرةٍ واحدة هو عين ما رآه المالك مشوَّهاً.
    final eq = equations ? readEquation(line) : null;
    final kind = eq != null
        ? _Kind.equation
        : (_needsMath(line) ? _Kind.math : _Kind.text);
    // ⚠️ ولا تُجمَّع المعادلات: كلُّ معادلةٍ كتلةٌ قائمة بذاتها كي تُفصل
    //    عمّا حولها («خلي فواصل» — طلب المالك).
    if (kind != _Kind.equation &&
        blocks.isNotEmpty &&
        blocks.last.kind == kind) {
      blocks.last.lines.add(line);
    } else {
      blocks.add(kind == _Kind.equation
          ? _Block(kind, [eq!.equation], label: eq.label)
          : _Block(kind, [line]));
    }
  }
  return blocks;
}

class MasarMarkdown extends StatelessWidget {
  const MasarMarkdown({
    super.key,
    required this.data,
    this.styleSheet,
    this.selectable = false,
    this.math = true,
    this.subject,
  });

  final String data;
  final MarkdownStyleSheet? styleSheet;
  final bool selectable;

  /// هل يُشغَّل رسّام الرياضيات؟
  ///
  /// 🔴 **اجعلها `false` في كل سياق بلا رياضيات.** `liftNumericFractions`
  ///    ترفع أي «رقم/رقم» إلى كسر — وهذا صحيح في درس فيزياء، وكارثة في شات
  ///    المنح: تاريخ «20/02/2026» ظهر **كسراً مرسوماً** على شاشة الطالب.
  ///    الافتراضي `true` كي لا يتغيّر سلوك قسم التعليم.
  final bool math;

  /// 🧪 **المادة — كي يبقى رسّامُ كلِّ مادةٍ في مادته.**
  ///
  /// ⭐ قرار المالك (2026-09-10): «خلّ الرسّام يكون خاص بكل مادة، ما يروح
  ///    لمادة ثانية يخربطها». فرسمُ معادلات التفاعل وبِنى الكيمياء العضوية
  ///    لا يُفعَّل إلا حيث له معنى.
  ///
  /// ⚠️ و`null` تعني «لا أعرف المادة» فيبقى السلوك كما كان — كي لا تنطفئ
  ///    المعادلات في شاشةٍ لم تُمرَّر إليها المادة بعد (المحفوظات مثلاً).
  final String? subject;

  /// المواد التي تُرسم فيها معادلاتُ التفاعل والبِنى.
  ///
  /// 📊 مسحُ المنهج: أسهمُ التفاعل في الكيمياء (٣٤٤) والأحياء (٥٧) وحدهما —
  ///    والبناءُ الضوئي وتفاعلاتُ النترتة معادلاتٌ حقيقية تستحقّ الرسم.
  static const Set<String> chemSubjects = {'كيمياء', 'احياء'};

  /// ➖ **المواد التي تُكتب إشارةُ عددها اللاتينيّ يسارَه.**
  ///
  /// 🔒 **الكيمياء وحدها بنصّ المالك (2026-09-12):** «التعديل للكيمياء
  ///    فقط، لا للرياضيات — اترك الرياضيات كما هي». والرياضياتُ أرقامُها
  ///    عربية وإشارتُها يمينَها بقراره القديم، وهو قرارٌ قائم.
  ///
  /// 🔬 **والفيزياءُ خرجت من المسألة أصلاً (2026-09-12):** بكلمة المالك
  ///    «حوّل أرقام الفيزياء كامل بالعربية، والسالب من جهة يمين الرقم»
  ///    صارت أرقامُها ٠١٢٣ في الخادم (`ARABIC_DIGIT_SUBJECTS`)، والرقمُ
  ///    العربي إشارتُه يمينَه **من نفسها** — فلا تُضمّ هنا أبداً، وإلا
  ///    انقلبت إشارتُها إلى يسارها وهو عكسُ المطلوب.
  ///
  /// ⚠️ **وتبقى الأحياءُ** أرقامُها لاتينية بلا قرار — إضافتُها سطرٌ واحد.
  static const Set<String> latinSignSubjects = {'كيمياء'};

  bool get _latinSign => latinSignSubjects.contains(subject);

  bool get _drawsChemistry =>
      subject == null || chemSubjects.contains(subject);

  @override
  Widget build(BuildContext context) {
    final prepared = math ? _prepare(data) : data;
    // 🛡️ لا كسور ولا معادلات (أو الرسّام مُطفأ) ⇒ لا تغيير عن السلوك السابق.
    final wantsEquations = _drawsChemistry && _hasEquation(prepared);
    if (!math || (!_needsMath(prepared) && !wantsEquations)) {
      return MarkdownBody(
        // ⚠️ `prepared` لا `data`: الحارس يجب أن يمرّ حتى على النصّ الخالي
        //    من الكسور — وهو بالضبط حيث ظهرت «int» (شرحُ تكاملٍ بلا `\frac`).
        data: _latinSign
            ? isolateSignedNumbers(math ? prepared : data)
            : (math ? prepared : data),
        styleSheet: styleSheet,
        selectable: selectable,
      );
    }

    final base = styleSheet?.p ??
        DefaultTextStyle.of(context).style.copyWith(fontSize: 16, height: 1.6);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final block in _split(prepared, equations: _drawsChemistry))
          if (block.kind == _Kind.table)
            MasarTable(block.lines, style: base, latinSign: _latinSign)
          else if (block.kind == _Kind.equation)
            ChemEquation(block.text, label: block.label, style: base)
          else if (block.kind == _Kind.math)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: MathText(block.text,
                  style: base,
                  latinSign: _latinSign,
                  // 🔤 **ورموزُ السطر تحدّد اتجاهَه** (المالك 2026-09-12):
                  //    «١/λ = R_H (...)» لا كلمةَ عربيةً فيها، فتُرسم من
                  //    اليسار كما يطبعها الكتاب — راجع [isLatinMathLine].
                  direction: isLatinMathLine(block.text)
                      ? TextDirection.ltr
                      : TextDirection.rtl),
            )
          else if (block.text.trim().isNotEmpty)
            MarkdownBody(
              data: _latinSign
                  ? isolateSignedNumbers(block.text)
                  : block.text,
              styleSheet: styleSheet,
              selectable: selectable,
            ),
      ],
    );
  }
}

/// 📊 **جدولُ مقارنةٍ فيه معادلات** — يرسمه التطبيق لا الماركداون.
///
/// 🔴 **علّةُ المالك (2026-09-12):** الموديل يضع معادلة التحول النووي في
///    عمودٍ من جدول، فيُخطف الصفُّ كلُّه إلى صندوق المعادلة فتظهر أعمدتُه
///    «|» وشرطاتُه للطالب وينهار الجدول.
///
/// ⚖️ **ولا يُعترض إلا حين يلزم**: الماركداون يرسم الجداول أصلاً وأجمل،
///    فلا نأخذها منه إلا إذا حملت خليّةٌ ترميزاً لا يعرفه.
class MasarTable extends StatelessWidget {
  const MasarTable(this.rows,
      {super.key, this.style, this.latinSign = false});

  final List<String> rows;
  final TextStyle? style;

  /// ➖ إشارةُ العدد اللاتينيّ يسارَه — الكيمياء وحدها ([MasarMarkdown]).
  final bool latinSign;

  /// خليّةٌ واحدة: معادلةً إن كانت معادلة، وإلا نصّاً برسّام الرياضيات.
  ///
  /// 🔴 **وبغير هذا يظهر السهم `-->` نصّاً مقلوباً `<-`** داخل الخليّة:
  ///    رسّامُ الرياضيات لا يعرف الأسهم، وهي شأنُ [ChemEquation].
  Widget _cell(String text, TextStyle style) {
    final eq = readEquation(text);
    if (eq != null) {
      return ChemEquation(eq.equation, style: style, dense: true);
    }
    return MathOrText(text, style: style, latinSign: latinSign);
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final body = [for (final r in rows) if (!isTableDivider(r)) splitRow(r)];
    if (body.isEmpty) return const SizedBox.shrink();
    final columns =
        body.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    final line = Theme.of(context).colorScheme.outlineVariant;
    final head = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.45);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      // ⚖️ **يملأ العرض ولا يمرّر أفقياً**: التمريرُ الأفقيّ كان يُخفي
      //    عمودَ المعادلة كلَّه خلف حافّة الشاشة — والعمودُ هو المقصود.
      //    فالأعمدةُ تتقاسم العرض ويلتفّ ما طال منها.
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < body.length; r++)
            Container(
              color: r == 0 ? head : null,
              child: IntrinsicHeight(
                child: Row(
                  // 🧭 عربيٌّ: أولُ عمودٍ إلى اليمين.
                  textDirection: TextDirection.rtl,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < columns; c++)
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                          decoration: BoxDecoration(
                            border: Border(
                              left: c == columns - 1
                                  ? BorderSide.none
                                  : BorderSide(color: line),
                              bottom: r == body.length - 1
                                  ? BorderSide.none
                                  : BorderSide(color: line),
                            ),
                          ),
                          child: Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: _cell(
                              c < body[r].length ? body[r][c] : '',
                              r == 0
                                  ? base.copyWith(fontWeight: FontWeight.w700)
                                  : base,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// نصّ قصير (سؤال اختبار · خيار) قد يحوي كسراً.
/// يرسم بالرسّام عند الحاجة، وإلا فـ`Text` عادي بنفس النمط تماماً.
class MathOrText extends StatelessWidget {
  const MathOrText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.latinSign = false,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  /// ➖ إشارةُ العدد اللاتينيّ يسارَه — الكيمياء وحدها ([MasarMarkdown]).
  final bool latinSign;

  @override
  Widget build(BuildContext context) {
    final prepared = _prepare(text);
    if (!_needsMath(prepared)) {
      return Text(
        latinSign ? isolateSignedNumbers(text) : text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
        // 🔴 **«-1» كانت تخرج «1-»** (توضيحُ المالك 2026-09-12): إشارةُ
        //    السالب محايدة، ففي فقرةٍ عربية تأخذ اتجاهها وتقفز يمينَ
        //    الرقم. وهذا صوابٌ مع الأرقام العربية وخطأٌ مع اللاتينية.
        textDirection:
            latinSign && isPureLatin(text) ? TextDirection.ltr : null,
      );
    }
    return MathText(prepared,
        style: style,
        latinSign: latinSign,
        // 🔤 سطرُ معادلةٍ رموزُه لاتينية يُرسم من اليسار — [isLatinMathLine].
        direction: isLatinMathLine(prepared)
            ? TextDirection.ltr
            : TextDirection.rtl);
  }
}
