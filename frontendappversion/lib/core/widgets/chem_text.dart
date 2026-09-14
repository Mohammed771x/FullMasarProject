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
//   العدد (3..8) · `ar` عطرية · `=1,3,5` روابط ثنائية على الأضلاع ·
//   رمز ذرّة غريبة (N · NH · O · S) وربما بموقعها `N@1` ·
//   `+مجموعة` وربما بموقعها `+CH3@4` · `fuse2`/`fuse3` حلقاتٌ ملتحمة
//
// 🔴 **وما أضافته جولة 2026-09-13 (عطلٌ رآه المالك):** «الهكسان الحلقي
//    والهكسين الحلقي — يقول لي بدون رابطة ثنائية وبها رابطة ثنائية، **وطيب
//    نفس الرسمة**؟» والجواب أنه كان محقّاً: الرسّام لم يكن يعرف الرابطة
//    الثنائية داخل الحلقة أصلاً، ولا موقعَ المجموعة (أورثو/ميتا/بارا رسمةٌ
//    واحدة)، ولا الحلقات الملتحمة (النفثالين والأنثراسين حلقةٌ واحدة).
//    الترقيم: **الرأس 1 هو الأعلى ثم مع عقارب الساعة**، والضلع i بين
//    الرأسين i وi+1 — كترقيم الكتاب.
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

/// مجموعة معلّقة على الحلقة — ونصُّها وموقعُها.
///
/// 📍 **الموقع ليس زينة**: درسُ «أورثو · ميتا · بارا» كلُّه مواقع. ورسمُ
///    مجموعتين على رأسين متجاورين بدل متقابلين يجعل الشكلَ يكذّب الاسمَ
///    المكتوب تحته. فالموقع جزءٌ من الرسم لا تفصيلةٌ فيه.
class ChemSubstituent {
  const ChemSubstituent(this.label, {this.at});

  final String label;

  /// رأسُ الحلقة (1-based): **1 هو الأعلى ثم مع عقارب الساعة** — كترقيم
  /// الكتاب. و`null` تعني «على الرأس الأعلى» (الحالة الشائعة: مجموعة واحدة).
  final int? at;
}

/// حلقة: مضلّع منتظم، وربما عطرية أو فيها ذرّة غريبة أو عليها مجموعات
/// أو فيها روابط ثنائية أو ملتحمة بأخرى.
class ChemRing {
  const ChemRing({
    required this.size,
    this.aromatic = false,
    this.hetero,
    this.heteroAt,
    this.substituents = const [],
    this.doubleBonds = const [],
    this.fused = 1,
  });

  final int size;

  /// عطرية ⇒ دائرةٌ داخل الحلقة (البنزين كما يرسمه الكتاب).
  final bool aromatic;

  /// ذرّة غير الكربون داخل الحلقة (`N` · `NH` · `O` · `S`).
  final String? hetero;

  /// رأسُ الذرّة الغريبة (1-based) — و`null` تعني الرأس الأدنى.
  final int? heteroAt;

  /// المجموعات المعلّقة ومواقعها.
  final List<ChemSubstituent> substituents;
  /// أضلاعٌ عليها رابطة ثنائية (1-based): الضلع i بين الرأسين i وi+1.
  ///
  /// 🔴 **هذا ما كان ينقص الرسّام كلَّه** (كشفه المالك 2026-09-13): الهكسان
  ///    الحلقي والهكسين الحلقي كانا **رسمةً واحدة** — سداسيٌّ أصمّ — والفرق
  ///    بينهما هو الرابطة الثنائية وحدها. والكتاب يرسمهما متجاورين في صفحةٍ
  ///    واحدة ليُظهر الفرق، فخرج الشرحُ يقول «بها رابطة ثنائية» والشكلُ
  ///    لا يُظهرها.
  final List<int> doubleBonds;

  /// عددُ الحلقات الملتحمة أفقياً: 1 عادية · 2 نفثالين · 3 أنثراسين.
  final int fused;

  /// توافقٌ للخلف — أولُ مجموعةٍ معلّقة (كان الحقل مفرداً).
  String? get substituent =>
      substituents.isEmpty ? null : substituents.first.label;
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

/// موقعٌ لاحقٌ بالجزء: `+CH3@4` · `N@1`.
final RegExp _atPosition = RegExp(r'@(\d+)$');

/// يقرأ محتوى `\ring{...}` — الأجزاء يفصلها `|` بأي ترتيب.
///
/// الأجزاء المفهومة:
///   `6` العدد · `ar` عطرية · `=1,3,5` روابط ثنائية على الأضلاع ·
///   `N` / `N@1` ذرّة غريبة · `+OH` / `+CH3@4` مجموعة معلّقة ·
///   `fuse2` / `fuse3` حلقتان/ثلاث ملتحمة (نفثالين · أنثراسين).
///
/// ⚠️ وما لا يُفهم يُهمل بصمت: ترميزٌ من نسخةٍ أحدث لا يجوز أن يُفرغ
///    الشاشة عند طالبٍ لم يحدّث بعد.
ChemRing parseChemRing(String source) {
  var size = 6;
  var aromatic = false;
  String? hetero;
  int? heteroAt;
  var fused = 1;
  final substituents = <ChemSubstituent>[];
  final doubleBonds = <int>[];

  for (final raw in source.split('|')) {
    final part = raw.trim();
    if (part.isEmpty) continue;

    final n = int.tryParse(part);
    if (n != null) {
      size = n.clamp(3, 8);
      continue;
    }
    if (part == 'ar' || part == 'aromatic') {
      aromatic = true;
      continue;
    }
    if (part.startsWith('=')) {
      for (final piece in part.substring(1).split(',')) {
        final edge = int.tryParse(piece.trim());
        if (edge != null) doubleBonds.add(edge);
      }
      continue;
    }
    if (part.startsWith('fuse')) {
      fused = (int.tryParse(part.substring(4).trim()) ?? 2).clamp(1, 3);
      continue;
    }
    if (part.startsWith('+')) {
      var text = part.substring(1).trim();
      int? at;
      final m = _atPosition.firstMatch(text);
      if (m != null) {
        at = int.parse(m.group(1)!);
        text = text.substring(0, m.start).trim();
      }
      if (text.isNotEmpty) substituents.add(ChemSubstituent(text, at: at));
      continue;
    }
    var text = part;
    final m = _atPosition.firstMatch(text);
    if (m != null) {
      heteroAt = int.parse(m.group(1)!);
      text = text.substring(0, m.start).trim();
    }
    if (text.isNotEmpty) hetero = text;
  }

  return ChemRing(
    size: size,
    aromatic: aromatic,
    hetero: hetero,
    heteroAt: heteroAt,
    substituents: substituents,
    doubleBonds: doubleBonds,
    fused: fused,
  );
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

/// مسمّىً مرسومٌ في موضعه: نصُّه ومركزُه وطرفا رابطته.
class _PlacedLabel {
  _PlacedLabel(this.text, this.painter, this.center, this.from, this.to);

  /// نصُّ المسمّى كما يُكتب — يُرسم بـ[ChemLabel] فتنخفض أرقامُه.
  final String text;

  /// قياسٌ تقريبيّ للنصّ — للصندوق وحده، والرسمُ ويدجت.
  final TextPainter painter;
  final Offset center;

  /// طرفا الخطّ الواصل بين رأس الحلقة والمسمّى (`null` لذرّة الحلقة نفسها).
  final Offset? from;
  final Offset? to;
}

/// هندسةُ الحلقة محسوبةً مرّةً واحدة: الرؤوس · المسمّيات · صندوق الرسم.
///
/// ⚖️ **ولماذا صنفٌ مستقلّ؟** الويدجت يحتاج **المقاس** قبل الرسم، والرسّام
///    يحتاج **المواضع** أثناءه. وحسابُهما في مكانين بقاعدتين متقاربتين هو
///    بالضبط ما كان يقصّ المجموعةَ عند الحافة: المقاس كان تقديراً ثابتاً
///    (`size * 1.9` فوق الحلقة) والرسمُ حقيقة. فالحساب هنا مرّةً واحدة،
///    والاثنان يقرآن منه.
class _RingGeometry {
  _RingGeometry({
    required this.ring,
    required this.radius,
    required this.style,
    required this.scaler,
  }) {
    final n = ring.size;
    final fused = ring.fused.clamp(1, 3);

    // 🔄 رأسٌ لأعلى دائماً — فيبقى للحلقة رأسٌ أعلى تُعلَّق عليه المجموعة
    //    ورأسٌ أدنى تجلس فيه الذرّة الغريبة (البيريدين كما الكتاب).
    //    **إلا المربّع**: رأسه لأعلى يجعله معيّناً ◇ لا مربّعاً □، والكتاب
    //    يرسم السيكلوبيوتان مربّعاً — فيُدار نصف زاوية.
    final startAngle = n == 4 ? -math.pi / 4 : -math.pi / 2;

    // 🔗 الحلقات الملتحمة تتقاسم **ضلعاً كاملاً** لا نقطة: مركزُ التالية
    //    يبعد وترَ الضلع (√3·r للسداسي) فينطبق ضلعها الأيسر على الأيمن
    //    تماماً — وهكذا يُرسم النفثالين والأنثراسين في الكتاب.
    final step = radius * math.sqrt(3);
    final firstDx = -step * (fused - 1) / 2;

    for (var k = 0; k < fused; k++) {
      final c = Offset(firstDx + step * k, 0);
      centers.add(c);
      vertices.add([
        for (var i = 0; i < n; i++)
          Offset(
            c.dx + radius * math.cos(startAngle + 2 * math.pi * i / n),
            c.dy + radius * math.sin(startAngle + 2 * math.pi * i / n),
          ),
      ]);
    }

    final main = vertices.first;

    // ذرّة الحلقة الغريبة: في موقعها المذكور، وإلا في الرأس الأدنى.
    if (ring.hetero != null && ring.hetero!.isNotEmpty) {
      heteroIndex = ring.heteroAt != null
          ? (ring.heteroAt! - 1) % n
          : _extremeIndex(main, lowest: true);
      final tp = _paint(ring.hetero!);
      hetero = _PlacedLabel(ring.hetero!, tp, main[heteroIndex!], null, null);
    }

    // المجموعات المعلّقة: كلٌّ على رأسها، ورابطتها شعاعٌ للخارج.
    for (final s in ring.substituents) {
      if (s.label.isEmpty) continue;
      final index =
          s.at != null ? (s.at! - 1) % n : _extremeIndex(main, lowest: false);
      final v = main[index];
      final dir = (v - centers.first) / radius; // متجه وحدة نحو الخارج
      final tp = _paint(s.label);
      final end = v + dir * (radius * 0.46);
      // نصفُ امتداد المسمّى في اتجاه الشعاع — فلا يركب الخطَّ ولا يبتعد.
      final half = (dir.dx.abs() * tp.width + dir.dy.abs() * tp.height) / 2;
      labels.add(
          _PlacedLabel(s.label, tp, end + dir * (half + radius * 0.1), v, end));
    }

    // 📦 الصندوق: المضلّعات ثم كلُّ مسمّى — لا تقديرَ ولا ثابت.
    var box = Rect.fromPoints(main.first, main.first);
    for (final poly in vertices) {
      for (final p in poly) {
        box = box.expandToInclude(Rect.fromCircle(center: p, radius: 1.5));
      }
    }
    for (final l in [if (hetero != null) hetero!, ...labels]) {
      box = box.expandToInclude(Rect.fromCenter(
          center: l.center, width: l.painter.width, height: l.painter.height));
    }
    box = box.inflate(1.5);
    origin = -box.topLeft;
    canvasSize = box.size;
  }

  final ChemRing ring;
  final double radius;
  final TextStyle style;
  final TextScaler scaler;

  final List<Offset> centers = [];
  final List<List<Offset>> vertices = [];
  final List<_PlacedLabel> labels = [];
  _PlacedLabel? hetero;
  int? heteroIndex;

  late final Offset origin;
  late final Size canvasSize;

  TextPainter _paint(String text) => TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();

  static int _extremeIndex(List<Offset> points, {required bool lowest}) {
    var best = 0;
    for (var i = 1; i < points.length; i++) {
      final better =
          lowest ? points[i].dy > points[best].dy : points[i].dy < points[best].dy;
      if (better) best = i;
    }
    return best;
  }
}

class ChemRingView extends StatelessWidget {
  const ChemRingView(this.ring, {super.key, required this.style});

  final ChemRing ring;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final fontSize = style.fontSize ?? 15;
    final geometry = _RingGeometry(
      ring: ring,
      radius: fontSize * 1.55,
      style: style,
      scaler: MediaQuery.textScalerOf(context),
    );

    // 🔤 **المسمّيات ويدجت لا نصٌّ في اللوحة**: `CH3` يجب أن تُرسم CH₃
    //    كما في الكتاب، وخفضُ الرقم عملُ [ChemLabel] — و`TextPainter`
    //    المجرّد لا يبلغه. (خسرناه لحظةً حين نُقلت المسمّيات إلى الرسّام.)
    final labels = [
      if (geometry.hetero != null) geometry.hetero!,
      ...geometry.labels,
    ];

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: fontSize * 0.3, vertical: 2),
        child: SizedBox(
          width: geometry.canvasSize.width,
          height: geometry.canvasSize.height,
          child: Stack(
            children: [
              CustomPaint(
                size: geometry.canvasSize,
                painter: _RingPainter(
                  geometry: geometry,
                  color: style.color ?? Colors.black,
                ),
              ),
              for (final l in labels)
                Positioned(
                  left: geometry.origin.dx + l.center.dx - l.painter.width / 2,
                  top: geometry.origin.dy + l.center.dy - l.painter.height / 2,
                  width: l.painter.width,
                  height: l.painter.height,
                  child: Center(child: ChemLabel(l.text, style: style)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.geometry, required this.color});

  final _RingGeometry geometry;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(geometry.origin.dx, geometry.origin.dy);

    final ring = geometry.ring;
    final n = ring.size;
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // فجوةٌ حول رمز الذرّة الغريبة كي لا تمرّ الأضلاع فوقه.
    final heteroLabel = geometry.hetero;
    final gap = heteroLabel == null
        ? 0.0
        : math.max(heteroLabel.painter.width, heteroLabel.painter.height) * 0.72;

    for (var k = 0; k < geometry.vertices.length; k++) {
      final points = geometry.vertices[k];
      final center = geometry.centers[k];
      final isMain = k == 0;

      for (var i = 0; i < n; i++) {
        var a = points[i];
        var b = points[(i + 1) % n];
        if (isMain && geometry.heteroIndex == i) a = _shrink(a, b, gap);
        if (isMain && geometry.heteroIndex == (i + 1) % n) b = _shrink(b, a, gap);
        canvas.drawLine(a, b, stroke);

        // ➖➖ الرابطة الثنائية: خطٌّ موازٍ **داخل** الحلقة، أقصرُ من الضلع
        //     قليلاً — هكذا تُطبع في الكتاب، ولو رُسم خارجها لبدا مجموعةً
        //     معلّقة لا رابطة.
        if (isMain && ring.doubleBonds.contains(i + 1)) {
          _innerBond(canvas, stroke, a, b, center);
        }
      }

      if (ring.aromatic) {
        canvas.drawCircle(center, geometry.radius * 0.58, stroke);
      }
    }

    // رابطةُ كل مجموعة — ونصُّها يُرسم ويدجت فوق اللوحة ([ChemRingView]).
    for (final l in geometry.labels) {
      if (l.from != null && l.to != null) canvas.drawLine(l.from!, l.to!, stroke);
    }
  }

  /// يرسم خطّ الرابطة الثانية موازياً للضلع ومزاحاً نحو مركز الحلقة.
  void _innerBond(Canvas canvas, Paint stroke, Offset a, Offset b, Offset center) {
    final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
    final toCenter = center - mid;
    final len = toCenter.distance;
    if (len == 0) return;
    final inward = toCenter / len * (geometry.radius * 0.17);
    // تقصيرٌ من الطرفين: الخطّ الداخلي لا يلامس الرأسين.
    final shift = (b - a) * 0.17;
    canvas.drawLine(a + inward + shift, b + inward - shift, stroke);
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
      old.color != color || !_sameRing(old.geometry.ring, geometry.ring);

  /// ⚠️ بالحقول لا بالهوية: `parseChemRing` تُنشئ كائناً جديداً في كل
  ///    بناء، فمقارنةُ المرجعين تعني إعادةَ رسمٍ دائمة بلا سبب.
  static bool _sameRing(ChemRing a, ChemRing b) =>
      a.size == b.size &&
      a.aromatic == b.aromatic &&
      a.hetero == b.hetero &&
      a.heteroAt == b.heteroAt &&
      a.fused == b.fused &&
      a.doubleBonds.join(',') == b.doubleBonds.join(',') &&
      a.substituents.map((s) => '${s.label}@${s.at}').join('|') ==
          b.substituents.map((s) => '${s.label}@${s.at}').join('|');
}
