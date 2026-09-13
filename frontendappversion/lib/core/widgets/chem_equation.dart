// ============================================================
// ⚗️ chem_equation.dart — معادلة التفاعل كما تُطبع في الكتاب
// ============================================================
// 🔴 **ما رآه المالك على الشاشة (2026-09-09):** معادلةُ تحضير الأسيتالدهيد
//    تخرج مبعثرة: «CH3CH-2OH-» بدل «CH3-CH2-OH»، والأسهم تنقلب، وشرط
//    التفاعل يُرسم كسراً.
//
// ⚖️ **والسبب ليس الخطّ ولا الترميز، بل الاتجاه الثنائي (bidi):**
//    المعادلة سلسلةٌ لاتينية داخل فقرةٍ عربية، وحروفُها المحايدة
//    (`-` و`+` و`>` والأرقام) تُحسم إلى **اتجاه الفقرة** فتقفز أطرافها.
//    وهي العلّة نفسها التي أفشلت رسم الكسور قبل عام ([arabic-math-fractions]).
//
// ⭐ **والعلاج عزلُ الاتجاه لا تعديلُ النصّ:** المعادلة تُرسم في سياق
//    `TextDirection.ltr` مستقلّ، فلا يبقى لـbidi ما يرتّبه. والمحتوى
//    يصل كما هو حرفاً بحرف — شرطُ المالك: «المحتوى ضروري يكون نفسه».

import 'package:flutter/material.dart';

import 'chem_text.dart';
import 'math_text.dart';

// ══════════════════════════════════════════════════
// 🔎 هل هذا السطر معادلة؟
// ══════════════════════════════════════════════════
// ⚠️ **الشرط مركّب عمداً**: سهمٌ وحده لا يكفي («← الجواب» نثرٌ عربي)، ووجودُ
//    لاتينيّ وحده لا يكفي («مصطلح (Order)»). فيلزم سهمُ تفاعلٍ **ورمزُ عنصر**.
/// صيغةٌ كيميائية: «H2O» بحرفٍ ورقم · «CHO» بحرفين كبيرين · «R-C» سلسلة.
///
/// ⚠️ **والرقم وحده لا يكفي**: «R-CHO + [O] --> R-COOH» معادلةٌ كاملة بلا
///    رقمٍ واحد، وكانت تسقط من الفحص فتُرسم نصّاً مبعثراً.
///
/// 🔴 **وكان يسقط «NaCl» و«Cu(s)» و«Na+»** (2026-09-12): لا رقمَ بعد
///    الرمز، ولا حرفان كبيران متتاليان. فبقيت أنصافُ تفاعلات الخلية
///    الجلفانية كلُّها نصّاً خاماً. فأُضيفت ثلاث علاماتٍ يقينية:
///    رمزان متتاليان (`NaCl`) · حالةُ مادّة (`Cu(s)`) · شحنة (`Na+`).
/// 📌 وأُضيف الدليلُ المنخفض `₀-₉` (2026-09-12): الخادمُ صار يكتب «H₂O»
///    لا «H2O»، فلو بقي الفحصُ على الرقم اللاتينيّ وحده لأنكر صيغةً
///    يرسمها هو نفسُه.
/// 📌 وأُضيفت الشحنةُ المرفوعة `⁰-⁹⁺⁻` (2026-09-12): «2Cl⁻ ⟶ Cl₂ + 2e⁻»
///    لا رقمَ لاتينياً فيها ولا إشارةَ عادية، فكانت تسقط من الكشف بعد
///    أن رفع الخادمُ شحنتَها. كشفه المسحُ: ٦ معادلات.
final RegExp _element = RegExp(
    // ⚠️ **والمرفوعةُ تُكتب محرفاً محرفاً لا مدىً**: «¹²³» في لاتين-١
    //    (U+00B9/B2/B3) و«⁰⁴-⁹» في كتلةٍ أخرى (U+2070…) — فمدى «⁰-⁹»
    //    لا يشمل ²، وهو ما أسقط «Zn²⁺» من الكشف في المسح.
    r'[A-Z][a-z]?[\d₀-₉⁰¹²³⁴⁵⁶⁷⁸⁹]|[A-Z]{2,}|[A-Z][a-z]?-[A-Z]'
    r'|(?:[A-Z][a-z]?[\d₀-₉]*){2,}|[A-Z][a-z]?\((?:s|l|g|aq)\)'
    r'|[A-Z][a-z]?[+\-⁺⁻]');
final RegExp _arabicWord = RegExp(r'[؀-ۿ]{4,}');

/// حرفٌ عربيّ واحد — يكفي لتحديد اتجاه العنوان.
final RegExp _arabicIn = RegExp(r'[؀-ۿ]');

/// دليلٌ أو أُسٌّ داخل صيغةٍ كيميائية: «H_2O» · «Cl^-».
final RegExp _script = RegExp(r'[_^]');

/// ⚗️ **تفاعلٌ بالعربية وحدها**: «فلز + ماء ← هيدروكسيد الفلز + غاز
/// الهيدروجين» — لا رمزَ لاتينياً فيه، وهو معادلةٌ لا نثر.
///
/// ⚖️ والعلامةُ الفارقة **«+» فاصلةٌ بين متفاعلات**، مع غياب علامات
///    الجملة. فـ«أغلب التفاعلات تكون : إما طاردة ← تنتقل الطاقة» نثرٌ
///    فيه نقطتان، و«نضع ف = س + ١ ⟵ د ف» رياضياتٌ لا كيمياء.
final RegExp _plusSeparator = RegExp(r'(?:^|\s)\+(?:\s|$)');
final RegExp _sentenceMark = RegExp(r'[:：؟?؛;]|[.،]\s*$');

/// ⚠️ و«=» علامةُ **معادلةٍ رياضية** لا تفاعل: «نضع ف = س + ١ ⟵ د ف = د س»
///    استوفت شرطَ «+» وغيابِ علامات الجملة، فكادت تُرسم تفاعلاً.
///    (ورسّامُ المعادلات مقصورٌ على الكيمياء والأحياء أصلاً، وهذا حدٌّ ثانٍ.)
final RegExp _mathEquals = RegExp(r'=');

/// سهمٌ نصّيّ (`-->` · `----->` · `<=>`): **علامةُ تفاعلٍ لا تُخطئ.**
///
/// 📊 مسحُ المنهج كلّه: ٤٠١ سطراً تحمله — كيمياء وأحياء — وكلُّها معادلات،
///    ولا سطرَ نثرٍ واحد. فلا يلزمها شرطٌ آخر.
final RegExp _asciiArrow = RegExp(r'--+>|<--+|<=+>');

/// سهمٌ يونيكوديّ: `⇌` اتزانٌ دائماً، أمّا `←`/`⟵` فقد تكون نثراً —
/// «نضع ف = س + ١ ⟵ د ف = د س» في تكامل الرياضيات (١١ موضعاً).
final RegExp _equilibriumGlyph = RegExp(r'⇌');

/// 🔴 **والسهمُ بشرطةٍ واحدة `->` كان يسقط كلَّه** (شكوى المالك 2026-09-12:
///    «ادخل على الكيمياء في المعادلات… ما طاع يضبط»). فمعادلاتُ الانشطار
///    النووي وتفاعلاتُ التعادل تصل الطالبَ نصّاً خاماً يعبث به الاتجاه
///    الثنائي: «Al-27 + :قذيفة ألفا» و«3n <- (سريع)» — والسهمُ نفسُه
///    ينقلب `<-` لأنه محايد في فقرةٍ عربية.
///
/// 📊 **وهو ما يكتبه الموديل فعلاً:** مسحُ محادثات الجهاز (٦٢٤ ك.ب) وجد
///    `->` في **٣٠** موضعاً، مقابل `-->` في ١٢٠.
///
/// ⚠️ **ولا يجوز عدُّه معادلةً بلا قرينة** كما يُعدّ `-->`: مسحُ المنهج
///    وجد ٢٩٨ موضعاً في الكيمياء وحدها ليست تفاعلات — «4s -> 4p -> 4d»
///    ترتيبُ مستويات، و«فتات كائنات ميتة -> ديدان أرض» سلسلةٌ غذائية،
///    وكلُّها عربيةٌ خالصة تُقرأ صحيحةً كما هي. فمكانُه مع الأسهم اللينة:
///    **لا يُرسم إلا برمز عنصر أو بـ«+» فاصلة.**
final RegExp _softArrow = RegExp(r'⟶|⟵|→|←|->|<-|=>');

/// سطرٌ يستحقّ رسمَ المعادلة.
///
/// 🔴 **وكان يشترط صيغةً لاتينية فيسقط ٩٣ مقطعاً**: كتاب كيمياء الأول يكتب
///    التفاعل بالعربية («معدن --تسخين--> كلس + فلوجستون»)، و«NaCl --> Na+»
///    ليس فيها حرفان كبيران متتاليان. فوصل السهمُ الخام إلى الشاشة.
bool looksLikeEquation(String line) {
  final t = line.trim();
  if (t.isEmpty || t.length > 400) return false;

  // ١) سهمُ تفاعلٍ صريح ⇒ معادلة، عربيةً كانت أو لاتينية.
  if (_asciiArrow.hasMatch(t) || _equilibriumGlyph.hasMatch(t)) return true;

  if (!_softArrow.hasMatch(t)) return false;
  final outside = t.replaceAll(_softArrow, ' ');

  // ٢) سهمٌ ليّن + رمزُ عنصر ⇒ معادلة، ما لم يغرق في الكلام.
  //
  // ⚖️ **وما بين قوسين ليس كلاماً بل حاشية**: «2NaCl (مصهور) → 2Na(s) +
  //    Cl2(g) (تيار كهربي مستمر)» معادلةٌ تامّة، وحواشيها أربعُ كلمات
  //    كانت تُسقطها من الفحص. فتُطرح الأقواسُ قبل العدّ.
  if (_element.hasMatch(t)) {
    final bare = outside.replaceAll(RegExp(r'\([^()]*\)'), ' ');
    return _arabicWord.allMatches(bare).length <= 3;
  }

  // ٣) وبلا رمزٍ لاتينيّ: «+» تفصل المتفاعلات، ولا علامةَ جملة.
  //
  // ⚖️ **والنقطةُ الأخيرة وحدَها لا تُسقط السطر**: «حمض + قاعدة -> ملح +
  //    ماء.» صيغةُ تفاعلٍ عامّة ختمها الكتابُ بنقطة. ومسحُ المنهج كلِّه
  //    يقول إنها **السطرُ الوحيد** الذي يتغيّر حكمُه بهذا التساهل — أمّا
  //    النثرُ فتُسقطه «:» و«=» و«،» وهي باقية على حالها.
  final ended = t.replaceFirst(RegExp(r'\.\s*$'), '');
  return _plusSeparator.hasMatch(t) &&
      !_sentenceMark.hasMatch(ended) &&
      !_mathEquals.hasMatch(t) &&
      _arabicWord.allMatches(outside).length <= 12;
}

// ══════════════════════════════════════════════════
// ⚗️ دليلُ الصيغة ينخفض: H2SO4 ⇐ H₂SO₄
// ══════════════════════════════════════════════════
/// 🔴 **طلبُ المالك (2026-09-12):** «H2SO4 — الاثنان بعد الـH تكون صغيرة
///    وتحته بشوية، والأربعة كذلك. ولا تخلط بينها وبين الأرقام التي
///    **قبل**: في 2H2O الأولى كبيرة والثانية تحت».
///
/// ⚖️ **والفارقُ ما قبل الرقم**: دليلٌ إن سبقه **رمزُ عنصر أو قوسٌ مغلق**
///    («H2» · «(OH)2»)، ومعاملٌ إن سبقه فراغٌ أو بدايةُ الصيغة («2H2O»).
///    وهي القاعدة نفسُها في [ChemLabel] منذ رسم الصيغ البنائية.
///
/// ⚠️ **وما داخل `\cmd{...}` لا يُمسّ**: `\nuc{235}{92}{U}` أرقامُها
///    مرسومةٌ أصلاً، ولو أُقحم فيها `_` لانكسر الترميز.
final RegExp _cmdArg = RegExp(r'\\[a-zA-Z]+(?:\{[^{}]*\})+');
final RegExp _subscript = RegExp(r'(?<=[A-Za-z)\]])(\d+)');

/// يحوّل دليلَ الصيغة إلى ترميز الرسّام: «H2SO4» ⇐ «H_2SO_4».
String subscriptFormulas(String source) {
  final shield = <String>[];
  final masked = source.replaceAllMapped(_cmdArg, (m) {
    shield.add(m.group(0)!);
    return '\u0001${shield.length - 1}\u0001';
  });
  final lifted = masked.replaceAllMapped(_subscript, (m) => '_${m.group(1)}');
  var out = lifted;
  for (var i = 0; i < shield.length; i++) {
    out = out.replaceAll('\u0001$i\u0001', shield[i]);
  }
  return out;
}

// ══════════════════════════════════════════════════
// 📊 صفُّ جدولٍ بالماركداون
// ══════════════════════════════════════════════════
/// «| نوع التحول | المعادلة | … |» — صفٌّ بأعمدةٍ لا معادلة.
bool isTableRow(String line) {
  final t = line.trim();
  return t.length > 2 &&
      t.startsWith('|') &&
      t.endsWith('|') &&
      '|'.allMatches(t).length >= 3;
}

/// «|----|----|» — سطرُ الفصل بين الترويسة والصفوف، لا يُعرض.
bool isTableDivider(String line) {
  if (!isTableRow(line)) return false;
  return splitRow(line).every((c) => RegExp(r'^:?-{2,}:?$').hasMatch(c.trim()));
}

/// خلايا الصفّ بلا العمودين الطرفيين.
List<String> splitRow(String line) {
  final t = line.trim();
  final body = t.substring(1, t.length - 1);
  return body.split('|').map((c) => c.trim()).toList();
}

// ══════════════════════════════════════════════════
// ☢️ صيغةُ الشرطة «Al-27» ⇐ رمزُ النواة ²⁷₁₃Al
// ══════════════════════════════════════════════════
/// 🔴 **ما رآه المالك (2026-09-12):** «Al-27 + He-4 ⟶ P-30 + n-1».
///    وسأل: «هل هذه صيغة صحيحة؟» — لا. الصيغةُ التي في الكتاب
///    `^27_13Al`، وصيغةُ الشرطة **ناقصة**: تُسقط العددَ الذرّي فلا تتّزن
///    المعادلة ولا يعرف الطالبُ شحنةَ النواة.
///
/// ⚖️ **والعددُ الذرّي ليس معلومةً تُخترع**: هو **تعريفُ العنصر نفسِه** —
///    الألمنيومُ ١٣ دائماً، والرمزُ «Al» يحدّده وحده. فاستردادُه من
///    جدولٍ ثابت استكمالُ صيغةٍ لا إضافةُ محتوى.
///
/// ⚠️ **وداخل المعادلة وحدها**: «النظير Cl-35» في نثر الكتاب (٢٢ موضعاً)
///    اسمُ نظيرٍ لا معادلة، ويبقى كما كتبه الكتاب.
///
/// 📌 وهو يُصلح **المحادثات المحفوظة** أيضاً: نصُّها مخزَّنٌ كما وصل،
///    فلا يبلغها إصلاحُ الخادم — ويبلغها الرسّام في كل عرض.
const String _elementOrder =
    'H He Li Be B C N O F Ne Na Mg Al Si P S Cl Ar K Ca Sc Ti V Cr Mn Fe Co '
    'Ni Cu Zn Ga Ge As Se Br Kr Rb Sr Y Zr Nb Mo Tc Ru Rh Pd Ag Cd In Sn Sb '
    'Te I Xe Cs Ba La Ce Pr Nd Pm Sm Eu Gd Tb Dy Ho Er Tm Yb Lu Hf Ta W Re '
    'Os Ir Pt Au Hg Tl Pb Bi Po At Rn Fr Ra Ac Th Pa U Np Pu Am Cm Bk Cf Es '
    'Fm Md No Lr Rf Db Sg Bh Hs Mt Ds Rg Cn Nh Fl Mc Lv Ts Og';

final Map<String, int> _atomicNumber = () {
  final symbols = _elementOrder.split(' ');
  return <String, int>{
    for (var i = 0; i < symbols.length; i++) symbols[i]: i + 1,
    // ⚛️ والجسيماتُ ليست عناصر لكنها تُكتب مثلها في المعادلة النووية.
    'n': 0,
    'p': 1,
  };
}();

/// «Al-27» · «He-4» · «n-1» — رمزٌ ثم شرطةٌ ثم عددٌ كتليّ.
final RegExp _dashNuclide =
    RegExp(r'(?<![A-Za-z0-9])([A-Z][a-z]?|[np])-(\d{1,3})(?![0-9A-Za-z])');

String _liftDashNuclides(String source) =>
    source.replaceAllMapped(_dashNuclide, (m) {
      final z = _atomicNumber[m.group(1)!];
      if (z == null) return m.group(0)!;
      return '\\nuc{${m.group(2)}}{$z}{${m.group(1)}}';
    });

// ══════════════════════════════════════════════════
// 🏷️ عنوانُ المعادلة — ما قبلها من ترقيمٍ ووصف
// ══════════════════════════════════════════════════
/// معادلةٌ مفصولةٌ عن عنوانها.
class EquationLine {
  const EquationLine(this.label, this.equation);

  /// «١. تفاعل الألومنيوم مع قذيفة ألفا:» — يُعرض عربياً فوق الصندوق.
  final String label;

  /// «Al-27 + He-4 -> P-30 + n-1» — وحدَها تدخل الصندوق.
  final String equation;
}

/// علامةُ قائمةٍ في أول السطر: «- » · «* » · «١. » · «2) » · «a) ».
///
/// ⚠️ **والحرفُ اللاتيني منها**: كتابُ الكيمياء يرقّم تمارين المعادلات
///    «a)‏ b)‏ c)» — وبقاؤها داخل الصندوق يُخرجها «(a» لأن القوس محايد.
final RegExp _listMarker = RegExp(r'^(?:[-*•]|\d+[.)]|[A-Za-z][.)])\s+');

/// تشديدُ الماركداون — يُنزع كي لا يظهر نجوماً داخل الصندوق.
final RegExp _emphasis = RegExp(r'\*\*|__');

/// 🔴 **علّةُ المالك (2026-09-12):** الموديل يكتب المعادلة **في سطر عنوانها**:
///    «2. **معادلة انشطار اليورانيوم-235:** U-235 + n (بطيء) -> Ba-141 …».
///    فيقع العنوانُ العربيّ والمعادلةُ اللاتينية في فقرةٍ واحدة، ويخلطهما
///    الاتجاهُ الثنائي: «U-235 + n :235-معادلة انشطار اليورانيوم».
///
/// ⭐ فيُفصل العنوان عن المعادلة: العنوانُ نصٌّ عربيّ، والمعادلةُ وحدَها
///    في صندوقها المعزول — وهو الشرط الذي يجعل الرسم صحيحاً أصلاً.
///
/// ⚖️ **والفاصلُ نقطتان قبل السهم**، لا أيُّ تشديد: «**حمض قوي + قاعدة
///    قوية** -> ملح + ماء» عنوانُها **هو** المتفاعلات، فلو قُطعت عند
///    التشديد لخرجت معادلةٌ بلا طرفٍ أيمن.
///
/// ترجع `null` إن لم يكن السطر معادلة.
EquationLine? readEquation(String line) {
  final t = line.trim();
  if (t.isEmpty || t.length > 400) return null;
  // 🔴 **وصفُّ الجدول ليس معادلة** (لقطةُ المالك 2026-09-12): الموديل يضع
  //    المعادلة في عمودٍ من جدول مقارنة، فكان الصفُّ كلُّه يُخطف إلى صندوق
  //    المعادلة بأعمدته وشرطاته — «| ⁶⁰₂₇Co ⟶ … | +1 | 0 |». والجدولُ
  //    له رسّامُه ([MasarTable]).
  if (isTableRow(t)) return null;

  final marker = _listMarker.firstMatch(t)?.group(0) ?? '';
  var rest = t.substring(marker.length);

  // ⚖️ الترقيمُ يبقى («١.» و«a)» ترتيبُ خطوةٍ يعنيه الشرح)، والنقطةُ
  //    المجرّدة تسقط — علامةُ قائمةٍ لا معنى لها داخل صندوق المعادلة.
  var label = RegExp(r'^[-*•]').hasMatch(marker) ? '' : marker.trim();
  final arrow = _softArrow.firstMatch(rest)?.start ??
      _asciiArrow.firstMatch(rest)?.start ??
      _equilibriumGlyph.firstMatch(rest)?.start ??
      rest.length;
  final colon = rest.indexOf(':');
  if (colon > 0 && colon < arrow) {
    final head = rest.substring(0, colon);
    // ⚠️ ولا يُقتطع رأسٌ فيه **متفاعل**: «مثال: HCl + NaOH» عنوانُها كلمة،
    //    أمّا رأسٌ فيه «+» أو رمزُ عنصر فهو من المعادلة لا عنوانٌ لها.
    if (!head.contains('+') && !_element.hasMatch(head)) {
      label = '$label ${head.replaceAll(_emphasis, '').trim()}:'.trim();
      rest = rest.substring(colon + 1);
    }
  }

  final equation = rest.replaceAll(_emphasis, '').trim();
  // ⚠️ **بعد الحكم لا قبله**: `\nuc{…}` ليست «رمزَ عنصر» في نظر الفحص،
  //    فتحويلُها أولاً كان يُسقط المعادلةَ من الرسم أصلاً.
  if (!looksLikeEquation(equation)) return null;
  return EquationLine(label, _liftDashNuclides(equation));
}

// ══════════════════════════════════════════════════
// 🧩 التفكيك
// ══════════════════════════════════════════════════
class _Arrow {
  final String? above;   // شرط التفاعل: «Cu / 200-300 م»
  final String glyph;
  const _Arrow(this.glyph, this.above);
}

/// سهمٌ بشرطٍ بين قوسين معقوفين: `--[Cu / 200 م]-->`
final RegExp _condArrow = RegExp(r'--+\[([^\]]*)\]--*>');
/// سهمٌ بشرطٍ عارٍ: `--725م/Ni-->` و`--(-H2O)-->`
final RegExp _bareCondArrow = RegExp(r'--+([^\s\[\]>-][^\[\]>]*?)--+>');

/// سهمٌ **أيسر** بشرط: `<--تكثف أكبر من تبخر--`
/// ⚠️ صورةٌ ثالثة كشفها المسح؛ وبغيرها تبقى «--» عاريةً بعد الرمز.
final RegExp _condArrowLeft = RegExp(r'<--+([^\[\]<>]*?)--+');
final RegExp _plainRight = RegExp(r'-+>|⟶|→|=>');
final RegExp _plainLeft = RegExp(r'<-+|⟵|←');
final RegExp _equilibrium = RegExp(r'<=+>|⇌|<-+>');

List<Object> _parse(String line) {
  final out = <Object>[];
  var rest = line;

  while (rest.isNotEmpty) {
    // نبحث عن أقرب سهم بأي صورة
    final candidates = <RegExpMatch>[
      for (final re in [
        _equilibrium, _condArrow, _bareCondArrow,
        _condArrowLeft, _plainRight, _plainLeft,
      ])
        if (re.firstMatch(rest) != null) re.firstMatch(rest)!,
    ];
    if (candidates.isEmpty) {
      out.add(rest);
      break;
    }
    // ⚠️ وعند تساوي البداية يفوز **الأطول**: «<--تكثف--» يطابقها
    //    `_condArrowLeft` و`_plainLeft` من الموضع نفسه، وترتيبُ `sort`
    //    غيرُ مضمون في دارت — فالشرطُ صريحٌ لا اتّكالٌ على الترتيب.
    candidates.sort((a, b) => a.start != b.start
        ? a.start.compareTo(b.start)
        : (b.end - b.start).compareTo(a.end - a.start));
    final m = candidates.first;
    if (m.start > 0) out.add(rest.substring(0, m.start));

    final text = m.group(0)!;
    String glyph;
    String? above;
    if (_equilibrium.hasMatch(text)) {
      glyph = '⇌';
    } else if (text.startsWith('<') && !text.endsWith('>')) {
      glyph = '⟵';
      final c = _condArrowLeft.firstMatch(text);
      if (c != null) {
        final cond = c.group(1)!.trim();
        if (cond.isNotEmpty) above = cond;
      }
    } else {
      glyph = '⟶';
      final c = _condArrow.firstMatch(text) ?? _bareCondArrow.firstMatch(text);
      if (c != null && c.groupCount >= 1) {
        final cond = c.group(1)!.trim();
        if (cond.isNotEmpty) above = cond;
      }
    }
    out.add(_Arrow(glyph, above));
    rest = rest.substring(m.end);
  }
  return out;
}

// ══════════════════════════════════════════════════
// 🖼️ الرسم
// ══════════════════════════════════════════════════
class ChemEquation extends StatelessWidget {
  const ChemEquation(this.line,
      {super.key, this.style, this.label = '', this.dense = false});

  final String line;
  final TextStyle? style;

  /// عنوانُ المعادلة كما كتبه الموديل — يُعرض عربياً فوقها ([readEquation]).
  final String label;

  /// 📊 **بلا إطارٍ ولا خلفية** — حين تكون المعادلة **خليّةً في جدول**:
  /// للجدول إطارُه، وإطارٌ داخل إطار حشوٌ يضيّق الخليّة.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final base = (style ?? DefaultTextStyle.of(context).style)
        .copyWith(height: 1.35);
    final parts = _parse(line.trim());

    // 🧭 **العزل هنا وحده يكفي**: كل ما بداخل هذا السياق يُرتَّب من اليسار
    //    إلى اليمين كما كُتب، ولا يتسرّب اتجاهُ الفقرة العربية إليه.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Container(
        width: dense ? null : double.infinity,
        margin: dense
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(vertical: 6),
        padding: dense
            ? EdgeInsets.zero
            : const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: dense
            ? null
            : BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(10),
              ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 🏷️ العنوانُ عربيٌّ **خارج** العزل: لو دخل سياق LTR لانقلب
            //    ترتيبُ كلماته. فله اتجاهُه ومحاذاتُه.
            if (label.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Directionality(
                  // ⚖️ واتجاهُه من **محتواه**: «a)» لاتينيّ فيبقى «a)»،
                  //    ولو أُعطي RTL لانقلب قوسُه فظهر «(a».
                  textDirection: _arabicIn.hasMatch(label)
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  child: Text(label,
                      style: base.copyWith(fontWeight: FontWeight.w700),
                      textAlign: _arabicIn.hasMatch(label)
                          ? TextAlign.right
                          : TextAlign.left),
                ),
              ),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 2,
              runSpacing: 6,
              children: [
                for (final p in parts)
                  if (p is _Arrow)
                    _arrowWidget(p, base)
                  else
                    _text(p as String, base),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🔴 **ولا يُلغي هذا رسّامَ البِنى**: أول تجربةٍ في المحاكي أظهرت
  ///    «\ring{6|ar} + CH3Cl ⟶ تولوين» — أي أن حلقة البنزين خرجت
  ///    **ترميزاً عارياً** لأن كتلة المعادلة سحبت السطر من `MathText`.
  ///
  /// ⭐ فالطرفُ الذي فيه ترميزٌ يُرسم بالرسّام، وما عداه نصّاً — فيجتمع
  ///    عزلُ الاتجاه ورسمُ الحلقات والكسور معاً.
  Widget _text(String s, TextStyle base) {
    final t = s.trim();
    if (t.isEmpty) return const SizedBox.shrink();
    // 🔴 **وكانت تعرف أربعةً من تسعة** (لقطةُ المالك 2026-09-12): معادلةُ
    //    انشطار اليورانيوم خرجت «\sup{235}_92U» نصّاً خاماً في الصندوق،
    //    لأن `\sup` لم يكن في النسخة المحلية. فصارت القائمةُ واحدة.
    // ⚠️ **و`_` و`^` داخل المعادلة دليلان ونُسب لا محارف**: الكتاب يكتب
    //    «C_{12}H_{22}O_{11}» فتظهر شرطاتُها وأقواسُها للطالب إن لم تمرّ
    //    بالرسّام. وفي صندوق المعادلة لا معنى آخر لهما.
    if (hasMathMarkup(t) || _script.hasMatch(t)) {
      // ⚖️ **واتجاهُ السطر لاتينيّ هنا**: الصندوقُ معزولٌ LTR، ورسّامُ
      //    الرياضيات يرصّ ذرّاته عربياً بطبعه — فلولا التصريح لخرجت
      //    حاشيةُ التفاعل «(rapid سريع)» في غير موضعها.
      return MathText(subscriptFormulas(t),
          style: base, direction: TextDirection.ltr);
    }
    // ⚗️ **والدليلُ ينخفض**: «H2SO4» تُرسم H₂SO₄ — [ChemLabel] تعرف
    //    الفرقَ بين دليلٍ بعد الرمز ومعاملٍ قبله.
    return ChemLabel(t, style: base);
  }

  /// السهم وشرطُه **فوقه** — كما يُطبع في كتاب الكيمياء، لا بين قوسين
  /// في وسط السطر حيث يلتبس بالمتفاعلات.
  Widget _arrowWidget(_Arrow a, TextStyle base) {
    final glyph = Text(a.glyph,
        style: base.copyWith(fontSize: (base.fontSize ?? 16) + 4),
        textDirection: TextDirection.ltr);
    // ⚠️ **وشرطُ التفاعل يمرّ بنفس المعالجة**: محادثاتٌ محفوظة قبل إصلاح
    //    الخادم تحمل «\frac{Cu}{200}» داخل الشرط، فعرضُها نصّاً خاماً
    //    يُبقي العطلَ ظاهراً للطالب وإن صحّ ما يأتي بعده. رُصد في المحاكي.
    if (a.above == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: glyph,
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _text(
              a.above!,
              base.copyWith(
                  fontSize: (base.fontSize ?? 16) * 0.72,
                  fontWeight: FontWeight.w600)),
          glyph,
        ],
      ),
    );
  }
}
