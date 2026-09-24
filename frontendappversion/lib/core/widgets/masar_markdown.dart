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

/// ⚡ **شحنةُ الأيون تُعزل كي تبقى فوقَ يمين رمزه.**
///
/// 🔴 **سؤالُ المالك (٢٠٢٦-٠٩-٢٢):** «العناصر الانتقالية… أعتقد إن الأُس
///    يكون فوق العنصر من اليمين». وكان محقّاً، والقياسُ أثبته:
///
/// | النصّ | كما كان يُرسم | الصواب |
/// |---|---|---|
/// | «تمتلك Zn²⁺ شحنة» | «⁺Zn²» | «Zn²⁺» |
/// | «أيون الكلوريد Cl⁻» | «⁻Cl» | «Cl⁻» |
/// | «المركب SO₄²⁻» | «⁻SO₄²» | «SO₄²⁻» |
/// | «الرقم 10⁻³» | «³⁻10» | «10⁻³» |
///
/// ⚖️ **والسببُ في جدول Unicode لا في الخطّ:** الأُسُّ الرقميّ (`²`) صنفُه
///    **EN** فينضمّ إلى الرمز اللاتينيّ، أمّا `⁺` و`⁻` (U+207A/U+207B)
///    فصنفُهما **ES** — فاصلٌ محايد. والمحايدُ في فقرةٍ عربية يأخذ اتجاه
///    الفقرة، فيقفز إلى يسار الرمز ويُقرأ كأنه شحنةُ ما بعده.
///
/// وهي **علّةُ «-1» عينُها** ([isolateSignedNumbers]) وعلاجُها عينُه:
/// عزلُ الرمز وشحنته بمحرفَي الاتجاه (U+2066 … U+2069).
///
/// 🔒 **والحارسُ أنّ الشحنةَ لا تُكتب إلا هكذا**: النمطُ يشترط علامةً
///    مرتفعة (`⁺`/`⁻`) بعد رمزٍ لاتينيٍّ أو عدد — ولا يقع ذلك في نصٍّ
///    عربيّ عادي. و**٨٨٥ موضعاً في المخزون** كانت تُعرض مقلوبة.
final RegExp _chargedFormula = RegExp(
    r'(?:[A-Za-z][A-Za-z0-9₀-₉]*|[0-9]+(?:[.,][0-9]+)?)'
    r'[⁰¹²³⁴-⁹]*'
    r'[⁺⁻]'
    r'[⁰¹²³⁴-⁹]*');

String isolateChargeSigns(String text) {
  // ⚡ خروجٌ سريع: لا علامةَ مرتفعة ⇒ لا عمل (أغلبُ الأسطر).
  if (!text.contains('\u207a') && !text.contains('\u207b')) return text;
  return text.replaceAllMapped(
      _chargedFormula, (m) => '\u2066${m.group(0)}\u2069');
}

/// نصٌّ لا حرفَ عربياً فيه ولا رقماً عربياً — يُقرأ من اليسار.
///
/// ⚖️ **والرقمُ العربيّ يُخرجه من الحكم**: «-٥» إشارتُها يمينَ الرقم بقرار
///    المالك، وهي القاعدة العربية. أمّا «-1» فلاتينيةٌ وإشارتُها يسارَه.
final RegExp _arabicBlock = RegExp(r'[\u0600-\u06FF]');

bool isPureLatin(String text) => !_arabicBlock.hasMatch(text);

// 🔢 **ثلاثُ أبجدياتِ أرقامٍ في كتبنا لا اثنتان**: لاتينية `7` · عربية `٧` ·
//    **وفارسية `۷`** (U+06F7). ومسحُ الصفوف الثلاثة (2026-09-17): **٨٤٨٣
//    محرفاً فارسياً في ٣١٥ درساً** — فيُعرض الجدولُ الواحد فيه «٦٠» و«۱۰۰»
//    بخطّين مختلفَي الشكل (٤ و۴ · ٥ و۵ · ٦ و۶ لا تتشابه).
//
// ⚖️ **وعلاجُه عند العرض لا في المصدر**: فيشمل المخزونَ كلَّه (٨١٣ شرحاً
//    و٣١٥ درساً) بلا نداءٍ واحد، وبلا إبطال بصمةِ درسٍ فيبطل شرحُه المخزون.
const Map<String, String> _persianToArabic = {
  '۰': '٠', '۱': '١', '۲': '٢', '۳': '٣', '۴': '٤',
  '۵': '٥', '۶': '٦', '۷': '٧', '۸': '٨', '۹': '٩',
};

String arabizeDigits(String text) {
  if (text.isEmpty) return text;
  final b = StringBuffer();
  for (final ch in text.split('')) {
    b.write(_persianToArabic[ch] ?? ch);
  }
  return b.toString();
}

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

/// هل في النصّ جدولٌ أصلاً؟ — فحصٌ رخيص قبل أي تقسيم.
///
/// 🔴 **بلا هذا الفحص لا يصل الجدولُ إلينا**: `build` يخرج مبكراً إلى
///    `MarkdownBody` حين لا كسورَ ولا معادلات — وجدولُ المقارنة في درس
///    التاريخ ليس فيه واحدةٌ منهما.
bool _hasTable(String text) {
  final lines = text.split('\n');
  for (var i = 0; i + 1 < lines.length; i++) {
    if (isTableRow(lines[i]) && isTableRow(lines[i + 1])) return true;
  }
  return false;
}

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
      // ⚖️ **وكلُّ جدولٍ يمرّ بنا الآن، لا الجداولُ الرياضية وحدها**
      //    (شكوى المالك 2026-09-13: «الجدول في الجوال متداخل والحروف
      //    مقصّصة»). كان جدولُ المقارنة العاديّ يذهب إلى `Table` الذي
      //    يرسمه الماركداون: أعمدةٌ متساوية بلا حدٍّ أدنى، فأربعةُ أعمدةٍ
      //    على شاشة ٤٠٢ نقطة = تسعون نقطةً للعمود، والكلمةُ العربية
      //    تُكسر في وسطها. ومسارانِ للجدول يعني شكلين لا يفهم الطالبُ
      //    لماذا اختلفا — فصار المسارُ واحداً ومسؤولاً.
      if (rows.length >= 2) {
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

// ══════════════════════════════════════════════════
// ↩️ سطرُ الكاتب سطرٌ على الشاشة · والعنوانُ يُرى عنواناً
// ══════════════════════════════════════════════════
//
// 🔴 **علّةُ المالك (2026-09-16): «الكلام محشو، كله ورا بعض».** وهي علّتان:
//
// ① **الماركداونُ يَلحم الأسطرَ المتتالية** في فقرةٍ واحدة ما لم يفصلها
//    سطرٌ فارغ. وقوائمُنا مرقّمةٌ **بأرقامٍ عربية** بقرار المالك
//    ([[arabic-numerals-in-answers]])، و«١-» ليست بنداً في عُرف الماركداون
//    (يعرف `1.` وحدها) — فالبنودُ تُعرض سطراً واحداً متّصلاً. ومسحُ
//    المخزون: **١١٩٩ بنداً ملتحماً في ١٨٢ درساً**. والعلاجُ
//    `softLineBreak` يُرفع — **وفي مسارَي العرض معاً**، فنسيانُ أحدهما
//    يعني عودةَ العلّة في نصف الدروس وهي أصعبُ من عودتها كلِّها.
//
// ② **العنوانُ كان يُرسم بنمط الفقرة**: الشاشاتُ تمرّر
//    `MarkdownStyleSheet(p: …)` وفيها **حقلٌ واحد** وبقيةُ الحقول `null`،
//    فيسقط `h1..h3` إلى الافتراضيّ ويتساوى العنوانُ ونصُّه (قيس: ١٦/w500
//    للاثنين). فشرحٌ من ستّة أقسامٍ يصل كتلةً بلا فاصلٍ يُرى.
//
// ⚖️ **وحجمُ العنوان يُشتقّ من حجم الفقرة لا من الثيم** — وإلا ثبت العنوانُ
//    بينما يكبر النصُّ حوله ([AppSettings.answerFontSize])، فينقلب العنوانُ
//    أصغرَ من فقرته عند من كبّر الخطّ.
MarkdownStyleSheet _withHeadings(MarkdownStyleSheet? sheet, BuildContext ctx) {
  final base = sheet ?? MarkdownStyleSheet.fromTheme(Theme.of(ctx));
  final p = base.p ??
      DefaultTextStyle.of(ctx).style.copyWith(fontSize: 16, height: 1.6);
  final size = p.fontSize ?? 16;
  TextStyle head(double factor) => p.copyWith(
      fontSize: size * factor, fontWeight: FontWeight.w900, height: 1.45);
  return base.copyWith(
    h1: head(1.45),
    h2: head(1.30),
    h3: head(1.18),
    h4: head(1.10),
    listBullet: p,
  );
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
    final wantsTable = _hasTable(prepared);
    if (!math || (!_needsMath(prepared) && !wantsEquations && !wantsTable)) {
      return MarkdownBody(
        // ⚠️ `prepared` لا `data`: الحارس يجب أن يمرّ حتى على النصّ الخالي
        //    من الكسور — وهو بالضبط حيث ظهرت «int» (شرحُ تكاملٍ بلا `\frac`).
        // ⚡ وعزلُ الشحنة **بلا شرط**: صيغةُ الأيون لاتينيةٌ في كل مادة،
        //    و`latinSign` قرارُ الأرقام لا قرارُ الصيغ الكيميائية.
        data: isolateChargeSigns(_latinSign
            ? isolateSignedNumbers(math ? prepared : data)
            : (math ? prepared : data)),
        styleSheet: _withHeadings(styleSheet, context),
        selectable: selectable,
        softLineBreak: true,
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
            MasarTable(block.lines,
                style: base, latinSign: _latinSign, math: math)
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
              data: isolateChargeSigns(_latinSign
                  ? isolateSignedNumbers(block.text)
                  : block.text),
              styleSheet: _withHeadings(styleSheet, context),
              selectable: selectable,
              softLineBreak: true,
            ),
      ],
    );
  }
}

double _atLeastZero(double v) => v > 0 ? v : 0;

/// 📊 **جدولُ المحتوى — يرسمه التطبيق لا الماركداون.**
///
/// 🔴 **علّتان اجتمعتا:**
///  ① (2026-09-12) الموديل يضع معادلة التحول النووي في عمودٍ من جدول،
///     فيُخطف الصفُّ كلُّه إلى صندوق المعادلة فتظهر أعمدتُه «|» للطالب.
///  ② (2026-09-13) **«الجدول في الجوال متداخل والحروف مقصّصة، مستحيل
///     يفهمه الطالب».** وهي العلّة الأكبر: `Table` الذي يرسمه الماركداون
///     يقسّم العرض بالتساوي بلا حدٍّ أدنى، فأربعةُ أعمدةٍ على شاشة ٤٠٢
///     نقطة تعطي ٩٠ نقطةً للعمود — وكلمةُ «الكهربائي» وحدها أعرضُ من ذلك،
///     فتُكسر في وسطها حرفاً حرفاً.
///
/// ⚖️ **والحلُّ ليس تمريراً أفقياً**: جُرّب فأخفى نصفَ الجدول خلف الحافّة
///    بلا ما يدلّ الطالبَ أن هناك بقيّة. الحلُّ أن **يقيس الجدولُ نفسه**:
///
///    • يتّسع بلا كسرِ كلمة  ⇒ **شبكةٌ** بأعمدةٍ متناسبة مع محتواها
///      (لا متساوية: «الخاصية» لا تحتاج عرضَ «موصلة جيدة للتيار»).
///    • لا يتّسع            ⇒ **بطاقةٌ لكل صف**: عنوانُ الصفّ في رأسها،
///      ثم «الترويسة: القيمة» سطراً سطراً. تُقرأ بلا كسرٍ ولا تمرير،
///      ويبقى المعنى كاملاً — وهو ما تفعله المواقعُ الجادّة في جداولها.
class MasarTable extends StatelessWidget {
  const MasarTable(this.rows,
      {super.key, this.style, this.latinSign = false, this.math = true});

  final List<String> rows;
  final TextStyle? style;

  /// ➖ إشارةُ العدد اللاتينيّ يسارَه — الكيمياء وحدها ([MasarMarkdown]).
  final bool latinSign;

  /// هل تُرسم الخلايا برسّام الرياضيات؟ (`false` في سياقٍ بلا رياضيات).
  final bool math;

  /// خليّةٌ واحدة: معادلةً إن كانت معادلة، وإلا نصّاً برسّام الرياضيات.
  ///
  /// 🔴 **وبغير هذا يظهر السهم `-->` نصّاً مقلوباً `<-`** داخل الخليّة:
  ///    رسّامُ الرياضيات لا يعرف الأسهم، وهي شأنُ [ChemEquation].
  Widget _cell(String text, TextStyle style, {TextAlign? align}) {
    if (!math) {
      return Text(text, style: style, textAlign: align);
    }
    final eq = readEquation(text);
    if (eq != null) {
      return ChemEquation(eq.equation, style: style, dense: true);
    }
    return MathOrText(text, style: style, latinSign: latinSign, textAlign: align);
  }

  /// 📏 **تقريبُ ما سيُرسم، لا ما كُتب**: الخليّة التي فيها
  /// `\frac{٢س + ٣}{س - ١}` تُرسم بسطاً فوق مقام بعرضِ أطولهما — أما
  /// قياسُ الترميز حرفياً فيعطي ضعفَ العرض تقريباً، فيأخذ العمودُ حصّةً
  /// لا يحتاجها ويضيق جارُه بلا سبب.
  static final RegExp _innerFrac =
      RegExp(r'\\frac\{([^{}]*)\}\{([^{}]*)\}');
  static final RegExp _innerCmd = RegExp(r'\\[a-zA-Z]+\{([^{}]*)\}');

  static String _asDrawn(String text) {
    var out = text;
    for (var i = 0; i < 4; i++) {
      final before = out;
      out = out.replaceAllMapped(_innerFrac, (m) {
        final a = m[1] ?? '';
        final b = m[2] ?? '';
        return a.length >= b.length ? a : b;      // البسط أو المقام، أطولُهما
      });
      out = out.replaceAllMapped(_innerCmd, (m) => m[1] ?? '');
      if (out == before) break;
    }
    return out;
  }

  /// عرضُ النصّ لو كُتب في سطرٍ واحد، وعرضُ أطولِ كلمةٍ فيه.
  ///
  /// ⚠️ **أطولُ كلمةٍ هي الحدُّ الذي لا يُنزل تحته**: العربية لا تُوصَل
  ///    بشرطة، فالعمودُ الأضيقُ من كلمته يكسرها في وسطها — وهو عينُ
  ///    «الحروف مقصّصة».
  static (double, double) _measure(
      String text, TextStyle style, TextScaler scaler) {
    final painter =
        TextPainter(textDirection: TextDirection.rtl, textScaler: scaler);
    double widthOf(String t) {
      painter.text = TextSpan(text: t, style: style);
      painter.layout();
      return painter.width;
    }

    // ⚠️ **هامشُ أمانٍ نصفُ حرف**: قياسُ `TextPainter` قد يقلّ عن التخطيط
    //    الفعليّ بكسرِ نقطة (تشكيلُ الحروف وتقريبُ الأعداد)، وكسرُ النقطة
    //    يكفي لأن تنزل آخرُ حرفٍ سطراً — وهو عينُ «الحروف مقصّصة».
    final guard = (style.fontSize ?? 16) * 0.12 + 1;
    final drawn = _asDrawn(text);
    final full = widthOf(drawn) + guard;
    var longest = 0.0;
    for (final word in drawn.split(RegExp(r'\s+'))) {
      if (word.isEmpty) continue;
      final w = widthOf(word);
      if (w > longest) longest = w;
    }
    painter.dispose();
    return (full, longest + guard);
  }

  @override
  Widget build(BuildContext context) {
    final base = style ?? DefaultTextStyle.of(context).style;
    final head = base.copyWith(fontWeight: FontWeight.w700);
    final body = [for (final r in rows) if (!isTableDivider(r)) splitRow(r)];
    if (body.isEmpty) return const SizedBox.shrink();
    final columns = body.map((r) => r.length).reduce((a, b) => a > b ? a : b);
    if (columns < 2) return const SizedBox.shrink();

    String at(int r, int c) => c < body[r].length ? body[r][c] : '';

    // 🔤 مُكبِّرُ الخطّ من إعدادات النظام — بغيره يُقاس الجدولُ بحجمٍ
    //    غيرِ الذي يُرسم به، فتنكسر الكلماتُ عند من كبّر خطَّ جهازه.
    final scaler = MediaQuery.textScalerOf(context);

    // 📏 قياسُ كل عمود: ما يحتاجه في سطرٍ واحد، وما لا يُنزل تحته.
    final want = List<double>.filled(columns, 0);
    final floor = List<double>.filled(columns, 0);
    for (var c = 0; c < columns; c++) {
      for (var r = 0; r < body.length; r++) {
        final (full, longest) =
            _measure(at(r, c), r == 0 ? head : base, scaler);
        if (full > want[c]) want[c] = full;
        if (longest > floor[c]) floor[c] = longest;
      }
    }

    return LayoutBuilder(builder: (context, box) {
      // 🔴 **الحسابُ على عرضِ المحتوى لا على عرضِ الخليّة**: الخطأ الأول
      //    كان أن يُعطى العمودُ عرضاً يساوي أرضيّته ثم تُقتطع منه الحشوةُ
      //    والحدّ — فينزل المحتوى تحت الأرضيّة وتنكسر الكلمة رغم الحساب.
      const pad = 10.0;
      final gutters = columns * pad * 2 + (columns - 1) + 2;
      final avail = box.maxWidth - gutters;

      // ① شرطٌ لا يُتجاوز: كلُّ عمودٍ يسع **أطولَ كلمةٍ** فيه. وإلا كُسرت
      //    الكلمةُ في وسطها — وهي شكوى المالك حرفاً بحرف.
      final needFloor = floor.fold(0.0, (a, b) => a + b);
      if (avail <= 0 || needFloor > avail) {
        return _cards(context, body, columns, base, head);
      }

      // توزيعٌ متناسب مع الحاجة، ثم رفعُ كل عمودٍ إلى أرضيّته، ثم خصمُ
      // الزيادة من أصحاب الفائض وحدهم — والمجموعُ يساوي المتاح تماماً
      // فلا تبقى فجوةٌ بيضاء على الحافّة.
      final wantTotal = want.fold(0.0, (a, b) => a + b);
      final widths = List<double>.generate(columns,
          (c) => wantTotal <= 0 ? avail / columns : avail * want[c] / wantTotal);
      for (var c = 0; c < columns; c++) {
        if (widths[c] < floor[c]) widths[c] = floor[c];
      }
      var over = widths.fold(0.0, (a, b) => a + b) - avail;
      if (over > 0) {
        var slack = 0.0;
        for (var c = 0; c < columns; c++) {
          slack += _atLeastZero(widths[c] - floor[c]);
        }
        if (slack > 0) {
          for (var c = 0; c < columns; c++) {
            widths[c] -= over * (_atLeastZero(widths[c] - floor[c]) / slack);
          }
        }
      } else if (over < 0) {
        // فائضٌ يُوزَّع بالتناسب كي يملأ الجدولُ عرضَ الشاشة.
        for (var c = 0; c < columns; c++) {
          widths[c] += (-over) *
              (wantTotal <= 0 ? 1 / columns : want[c] / wantTotal);
        }
      }
      // ② وشرطُ جودةٍ بعد القياس: عمودٌ يلتفّ محتواه إلى أكثر من أربعة
      //    أسطر يجعل الصفَّ برجاً من الكلمات المفردة — يُقرأ بالعين لا
      //    بالمعنى. عندها البطاقةُ أصدق. (ولهذا لا نحكم بعدد الأعمدة:
      //    خمسةُ أعمدةٍ أرقامُها قصيرة تُقرأ، وثلاثةٌ فقراتُها طويلة لا.)
      var worst = 1;
      for (var c = 0; c < columns; c++) {
        if (widths[c] <= 0) continue;
        final lines = (want[c] / widths[c]).ceil();
        if (lines > worst) worst = lines;
      }
      if (worst > 4) return _cards(context, body, columns, base, head);
      return _grid(context, body, columns, widths, pad, base, head);
    });
  }

  // ══════════════ شبكة: أعمدةٌ متناسبة مع محتواها ══════════════
  Widget _grid(BuildContext context, List<List<String>> body, int columns,
      List<double> widths, double pad, TextStyle base, TextStyle head) {
    final line = Theme.of(context).colorScheme.outlineVariant;
    final headBg = Theme.of(context)
        .colorScheme
        .surfaceContainerHighest
        .withValues(alpha: 0.45);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: line),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < body.length; r++)
            Container(
              color: r == 0 ? headBg : null,
              child: IntrinsicHeight(
                child: Row(
                  // 🧭 عربيٌّ: أولُ عمودٍ إلى اليمين.
                  textDirection: TextDirection.rtl,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var c = 0; c < columns; c++)
                      SizedBox(
                        width: widths[c] + pad * 2,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: pad, vertical: 8),
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
                                r == 0 ? head : base),
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

  // ══════════════ بطاقات: صفٌّ = بطاقة، لا كسرَ ولا تمرير ══════════════
  //
  // ⚖️ **لماذا البطاقة لا التمرير؟** الطالبُ يقرأ على شاشةٍ بعرض إبهامه،
  //    والمقارنةُ التي لا تُقرأ لا قيمة لها. البطاقةُ تحفظ **المعنى**
  //    كاملاً (كلُّ قيمةٍ منسوبةٌ إلى ترويستها بالاسم) وتخسر **الشكل**
  //    الشبكيّ وحده — وهي مقايضةٌ رابحة بلا تردّد.
  Widget _cards(BuildContext context, List<List<String>> body, int columns,
      TextStyle base, TextStyle head) {
    final scheme = Theme.of(context).colorScheme;
    final line = scheme.outlineVariant;
    final headers = body.first;
    final label = base.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: (base.fontSize ?? 16) - 1.5,
        color: scheme.primary);

    String header(int c) => c < headers.length ? headers[c].trim() : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var r = 1; r < body.length; r++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              border: Border.all(color: line),
              borderRadius: BorderRadius.circular(12),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 🏷️ رأسُ البطاقة = الخليّة الأولى (وهي عنوانُ الصفّ عادةً)،
                //    ومعها ترويستُها فوقها صغيرةً كي لا يضيع معناها.
                Container(
                  width: double.infinity,
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (header(0).isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text(header(0), style: label),
                        ),
                      _cell(body[r].isNotEmpty ? body[r][0] : '', head),
                    ],
                  ),
                ),
                for (var c = 1; c < columns; c++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: line.withValues(alpha: 0.6)),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (header(c).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 3),
                            child: Text(header(c), style: label),
                          ),
                        _cell(c < body[r].length ? body[r][c] : '—', base),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// نصّ قصير (سؤال اختبار · خيار) قد يحوي كسراً.
/// يرسم بالرسّام عند الحاجة، وإلا فـ`Text` عادي بنفس النمط تماماً.



/// جملةٌ إنجليزيةٌ كاملة — تُرسم من اليسار كما تُكتب.
///
/// 🔴 **رُئي في المحاكي (2026-09-18)** بعد أن صار «اختبر نفسك» في الإنجليزية
///    كلُّه إنجليزياً: «?What is the passive form of 'Ali is washing his car
///    now» يلتفّ في فقرةٍ عربيةِ الاتجاه، فتقفز علامةُ الاستفهام والاقتباسُ
///    إلى **يسار السطر الثاني**: «?'car now». والعلامةُ محايدةُ الاتجاه
///    فتأخذ اتجاهَ الفقرة — وهو عينُ علّةِ «-1» ([isolateSignedNumbers]).
///
/// ⚖️ **وحدُّه ثلاثُ كلماتٍ فأكثر** كي لا يُزحزح رمزٌ مفرد: «NaCl» و«pH»
///    و«CO2» تبقى في مكانها من الفقرة العربية.
final RegExp _latinWords = RegExp("[A-Za-z][A-Za-z'\u2019-]*");

bool isLatinSentence(String text) =>
    isPureLatin(text) && _latinWords.allMatches(text).length >= 3;

/// 🇬🇧 بطاقةُ سؤالٍ إنجليزيةٌ كلُّها — نصّاً وخياراتٍ — فتُرسم من اليسار.
///
/// ⚖️ **والمجموعةُ تعرف ما لا يعرفه الخيارُ وحده**: «Noun + Adjective»
///    كلمتان فلا تبلغان حدَّ [isLatinSentence]، لكنّها في بطاقةٍ سؤالُها
///    «?What is the correct order of adjectives and nouns» وخياراتُها
///    الأربعةُ لاتينية — فاتجاهُها يسارٌ قطعاً. أمّا سؤالٌ عربيٌّ خياراتُه
///    صيغٌ كيميائية فيبقى على حاله ([chem_equation]).
bool isLatinCard(String question, List<String> options) =>
    isPureLatin(question) &&
    options.isNotEmpty &&
    options.every(isPureLatin) &&
    _latinWords.allMatches(question).length >= 3;

/// 📝 **مادّةُ التمرين تُرسم ولا تُعرض برموزها** — نجمتان وشرطتان.
///
/// أسئلةُ الإنجليزية تحمل مادّتَها بين نجمتين: «*.Change into the passive:
/// *They built the school»، وتؤشّر كلمتَها المقصودة بشرطتين مزدوجتين:
/// «*.The __cut__ on his arm was bleeding badly*». و[MathOrText] يرسم نصّاً
/// خاماً، فتظهر الرموزُ للطالب علاماتٍ لا معنى لها.
///
/// 🔴 **وأمرُ المالك (2026-09-19) شقّان:** «موجود فيه الستار… لا يطبّق موضوع
///    الستار» — أي تُرسم لا تُعرض؛ و«المفروض الجملة دي تكون **أغمق**» — أي
///    تُميَّز بصرياً لا تُمال إمالةً باهتة.
///
/// ⚖️ والحدّ: `*` مفردةٌ محيطةٌ بنصٍّ غيرِ فارغ — فـ«٣ * ٤» و«a * b» تبقى.
///    و`__` شرطتان لا ثلاث — فالفراغُ `____` يبقى فراغاً.
final RegExp _emphasis = RegExp(r'(?<!\*)\*([^*\n]{2,}?)\*(?!\*)');
final RegExp _underlined = RegExp(r'(?<!_)__([^_\n]{1,40}?)__(?!_)');

bool hasEmphasis(String text) =>
    _emphasis.hasMatch(text) || _underlined.hasMatch(text);

/// يقسّم نصّاً على الشرطتين المزدوجتين — الكلمةُ المؤشَّرة تحتها خطّ.
List<InlineSpan> _underlineSpans(String text, TextStyle style) {
  final spans = <InlineSpan>[];
  var at = 0;
  for (final m in _underlined.allMatches(text)) {
    if (m.start > at) {
      spans.add(TextSpan(text: text.substring(at, m.start), style: style));
    }
    spans.add(TextSpan(
        text: m.group(1),
        style: style.copyWith(
            decoration: TextDecoration.underline,
            decorationThickness: 2,
            fontWeight: FontWeight.w800)));
    at = m.end;
  }
  if (at < text.length) {
    spans.add(TextSpan(text: text.substring(at), style: style));
  }
  return spans;
}

List<InlineSpan> emphasisSpans(String text, TextStyle? base) {
  final plain = base ?? const TextStyle();
  // 🎨 **المادّةُ أغمقُ وأمْيَل** — طلبُ المالك: «الجملة دي تكون أغمق».
  final material = plain.copyWith(
      fontStyle: FontStyle.italic, fontWeight: FontWeight.w700);
  final spans = <InlineSpan>[];
  var at = 0;
  for (final m in _emphasis.allMatches(text)) {
    if (m.start > at) {
      spans.addAll(_underlineSpans(text.substring(at, m.start), plain));
    }
    // 📌 والتأشيرُ داخلَ المادّة — «*The __cut__ on his arm*».
    spans.addAll(_underlineSpans(m.group(1)!, material));
    at = m.end;
  }
  if (at < text.length) {
    spans.addAll(_underlineSpans(text.substring(at), plain));
  }
  return spans;
}


class MathOrText extends StatelessWidget {
  const MathOrText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.latinSign = false,
    this.forceLtr = false,
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  /// 🇬🇧 **يفرضه النداء حين يعرف ما لا يعرفه النصّ وحده**: خيارُ «+ Noun
  ///    Adjective» كلمتان فلا يبلغ حدَّ [isLatinSentence]، لكنّ **الخيارات
  ///    الأربعة والسؤالَ كلَّها لاتينية** — فالبطاقةُ إنجليزيةٌ كلُّها
  ///    وتُرسم من اليسار. و[quiz_play_screen] هو مَن يرى المجموعة.
  final bool forceLtr;

  /// ➖ إشارةُ العدد اللاتينيّ يسارَه — الكيمياء وحدها ([MasarMarkdown]).
  final bool latinSign;

  @override
  Widget build(BuildContext context) {
    // 🔢 ونفسُ التوحيد في المسار السطريّ — عناوينُ الجداول والبطاقات
    //    تمرّ من هنا لا من [MasarMarkdown].
    final text = arabizeDigits(this.text);
    final prepared = _prepare(text);
    if (!_needsMath(prepared)) {
      // 📝 والمادّةُ المقتبَسة تُمال — [emphasisSpans].
      if (hasEmphasis(text)) {
        return Text.rich(
          TextSpan(style: style, children: emphasisSpans(text, style)),
          textAlign: textAlign,
          maxLines: maxLines,
          overflow: maxLines != null ? TextOverflow.ellipsis : null,
          textDirection:
              forceLtr || isLatinSentence(text) ? TextDirection.ltr : null,
        );
      }
      return Text(
        isolateChargeSigns(latinSign ? isolateSignedNumbers(text) : text),
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
        // 🔴 **«-1» كانت تخرج «1-»** (توضيحُ المالك 2026-09-12): إشارةُ
        //    السالب محايدة، ففي فقرةٍ عربية تأخذ اتجاهها وتقفز يمينَ
        //    الرقم. وهذا صوابٌ مع الأرقام العربية وخطأٌ مع اللاتينية.
        textDirection: forceLtr ||
                (latinSign && isPureLatin(text)) ||
                isLatinSentence(text)
            ? TextDirection.ltr
            : null,
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
