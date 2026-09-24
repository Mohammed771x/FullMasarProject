import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// ==========================================
// 🧱 صفوفٌ تملأ عرضَها — `Wrap` لا يتمدّد
// ==========================================
// 🔴 **ملاحظةُ المالك (٢٠٢٦-٠٩-٢٣):** «في جوالي — شاشته عريضة — شريحةُ
//    الاختبارات ما تكون على نهاية الحافة، تكون في النص».
//
//    `Wrap` يرصّ أبناءه بعروضهم الطبيعية ويترك الباقي فراغاً. فعلى
//    iPhone 17 كان السطرُ الأولُ يكاد يبلغ الحافة (المصمّمُ رسمه لهذا
//    العرض)، وعلى Pro Max (٤٤٠) يبقى بعده فراغٌ ظاهر — الشاشةُ تبدو
//    مصمّمةً لجهازٍ غيرِ الذي في اليد.
//
// ✅ **هنا كلُّ سطرٍ يملأ العرضَ كاملاً،** والزيادةُ تُوزَّع على الأبناء
//    **بنسبة عروضهم الطبيعية** — فالشريحةُ الطويلة الاسم تبقى أعرض، ولا
//    يُقصّ نصٌّ ولا تتساوى شريحةُ «شرح» بشريحة «اختبارات» قسراً.
//
// ⚖️ **والأسطرُ متوازنة لا جشِعة:** `Wrap` يملأ الأوّلَ ثم يُلقي الباقيَ في
//    الثاني — فتخرج «٤ + ١»: شريحةٌ يتيمةٌ بعرض البطاقة كلِّها. وهنا يُختار
//    **أقلُّ عددٍ من الأسطر** ثم **أعدلُ تقسيمٍ** بينها («٣ + ٢»)، فيبدو
//    الشريطُ لوحةَ أزرارٍ واحدة على كل عرض.
//
// ↔️ **ويحترم الاتجاه:** في العربية أوّلُ ابنٍ يمينَ السطر كما في `Row`.
class FilledWrap extends MultiChildRenderObjectWidget {
  const FilledWrap({
    super.key,
    required super.children,
    this.spacing = 6,
    this.runSpacing = 6,
  });

  final double spacing;
  final double runSpacing;

  @override
  RenderFilledWrap createRenderObject(BuildContext context) => RenderFilledWrap(
        spacing: spacing,
        runSpacing: runSpacing,
        textDirection: Directionality.of(context),
      );

  @override
  void updateRenderObject(BuildContext context, RenderFilledWrap renderObject) {
    renderObject
      ..spacing = spacing
      ..runSpacing = runSpacing
      ..textDirection = Directionality.of(context);
  }

  /// 🧮 **التقسيمُ وحده** — مكشوفٌ للاختبار بلا رسم.
  ///
  /// يعيد عددَ الأبناء في كل سطر: أقلُّ الأسطر التي تسع [available]، ثم
  /// أصغرُ «أعرضِ سطر» بينها. والأبناءُ ≤ ١٢ في كل استعمالٍ حقيقي، فالمرورُ
  /// على كل التقسيمات (٢^(ن-١)) أرخصُ من خوارزميةٍ ذكية وأوضح.
  @visibleForTesting
  static List<int> partition(
    List<double> widths,
    double available,
    double spacing,
  ) {
    final n = widths.length;
    if (n == 0) return const [];
    if (n > 12) return _greedy(widths, available, spacing);

    double rowWidth(int from, int to) {
      var w = spacing * (to - from - 1);
      for (var i = from; i < to; i++) {
        w += widths[i];
      }
      return w;
    }

    List<int>? best;
    var bestRows = n + 1;
    var bestMax = double.infinity;
    // كلُّ قناعٍ = أين تُقطع الأسطر (بتٌّ لكل فاصلٍ بين ابنين).
    for (var mask = 0; mask < (1 << (n - 1)); mask++) {
      final sizes = <int>[];
      var start = 0;
      var worst = 0.0;
      var fits = true;
      for (var i = 0; i < n; i++) {
        final last = i == n - 1;
        if (last || (mask & (1 << i)) != 0) {
          final w = rowWidth(start, i + 1);
          // سطرٌ من ابنٍ واحدٍ أعرضَ من المتاح يُقبل (يُضغط لاحقاً) — لا مفرّ.
          if (w > available + 0.5 && i + 1 - start > 1) {
            fits = false;
            break;
          }
          worst = math.max(worst, w);
          sizes.add(i + 1 - start);
          start = i + 1;
        }
      }
      if (!fits) continue;
      final rows = sizes.length;
      if (rows < bestRows || (rows == bestRows && worst < bestMax - 0.01)) {
        best = sizes;
        bestRows = rows;
        bestMax = worst;
      }
    }
    return best ?? _greedy(widths, available, spacing);
  }

  static List<int> _greedy(List<double> widths, double available, double spacing) {
    final sizes = <int>[];
    var count = 0;
    var w = 0.0;
    for (final cw in widths) {
      final next = count == 0 ? cw : w + spacing + cw;
      if (count > 0 && next > available) {
        sizes.add(count);
        count = 1;
        w = cw;
      } else {
        count++;
        w = next;
      }
    }
    if (count > 0) sizes.add(count);
    return sizes;
  }
}

class _FilledWrapParentData extends ContainerBoxParentData<RenderBox> {}

class RenderFilledWrap extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _FilledWrapParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _FilledWrapParentData> {
  RenderFilledWrap({
    required double spacing,
    required double runSpacing,
    required TextDirection textDirection,
  })  : _spacing = spacing,
        _runSpacing = runSpacing,
        _textDirection = textDirection;

  double _spacing;
  set spacing(double v) {
    if (v == _spacing) return;
    _spacing = v;
    markNeedsLayout();
  }

  double _runSpacing;
  set runSpacing(double v) {
    if (v == _runSpacing) return;
    _runSpacing = v;
    markNeedsLayout();
  }

  TextDirection _textDirection;
  set textDirection(TextDirection v) {
    if (v == _textDirection) return;
    _textDirection = v;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FilledWrapParentData) {
      child.parentData = _FilledWrapParentData();
    }
  }

  List<RenderBox> get _kids {
    final out = <RenderBox>[];
    var c = firstChild;
    while (c != null) {
      out.add(c);
      c = childAfter(c);
    }
    return out;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _kids.fold(0.0, (m, c) => math.max(m, c.getMinIntrinsicWidth(height)));

  @override
  double computeMaxIntrinsicWidth(double height) {
    final kids = _kids;
    if (kids.isEmpty) return 0;
    return kids.fold(0.0, (s, c) => s + c.getMaxIntrinsicWidth(height)) +
        _spacing * (kids.length - 1);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, dry: true);

  @override
  void performLayout() => size = _layout(constraints, dry: false);

  Size _layout(BoxConstraints constraints, {required bool dry}) {
    final kids = _kids;
    final maxW = constraints.maxWidth;
    if (kids.isEmpty) return constraints.constrain(Size(maxW.isFinite ? maxW : 0, 0));
    // 🧭 عرضٌ غيرُ محدود ⇒ لا «ملء» له معنى: سطرٌ واحدٌ بالعروض الطبيعية.
    final available = maxW.isFinite ? maxW : computeMaxIntrinsicWidth(double.infinity);

    final natural = [for (final c in kids) c.getMaxIntrinsicWidth(double.infinity)];
    final rows = FilledWrap.partition(natural, available, _spacing);

    var y = 0.0;
    var index = 0;
    for (var r = 0; r < rows.length; r++) {
      final count = rows[r];
      final from = index;
      final to = index + count;
      final spaceForKids = available - _spacing * (count - 1);
      var sumNatural = 0.0;
      for (var i = from; i < to; i++) {
        sumNatural += natural[i];
      }
      // 📏 نصيبُ كل ابنٍ بنسبة عرضه الطبيعي — والمجموعُ = العرضُ كاملاً.
      final widths = [
        for (var i = from; i < to; i++)
          sumNatural <= 0 ? spaceForKids / count : natural[i] / sumNatural * spaceForKids,
      ];

      // الارتفاعُ: أعلى أبناء السطر — ثم يُعاد رسمُهم به كي تتساوى الشرائح.
      var rowH = 0.0;
      for (var i = from; i < to; i++) {
        final c = BoxConstraints.tightFor(width: widths[i - from]);
        final s = dry ? kids[i].getDryLayout(c) : (kids[i]..layout(c, parentUsesSize: true)).size;
        rowH = math.max(rowH, s.height);
      }

      var x = _textDirection == TextDirection.rtl ? available : 0.0;
      for (var i = from; i < to; i++) {
        final w = widths[i - from];
        if (!dry) {
          kids[i].layout(BoxConstraints.tightFor(width: w, height: rowH), parentUsesSize: true);
          final pd = kids[i].parentData! as _FilledWrapParentData;
          pd.offset = _textDirection == TextDirection.rtl
              ? Offset(x - w, y)
              : Offset(x, y);
        }
        x += _textDirection == TextDirection.rtl ? -(w + _spacing) : (w + _spacing);
      }
      y += rowH;
      if (r < rows.length - 1) y += _runSpacing;
      index = to;
    }
    return constraints.constrain(Size(available, y));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
