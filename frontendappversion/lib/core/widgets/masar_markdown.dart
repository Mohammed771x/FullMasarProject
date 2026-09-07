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

import 'math_text.dart';

/// هل يحتاج هذا السطر رسّام الرياضيات؟
bool _needsMath(String line) =>
    line.contains(r'\frac') ||
    line.contains(r'\sqrt') ||
    line.contains(r'\chem') ||
    line.contains(r'\ring');

/// يرفع الكسور الرقمية البحتة إلى ترميز `\frac` قبل الفحص والرسم.
String _prepare(String text) => liftNumericFractions(text);

/// هل يحتاج النصّ كلّه رسّام الرياضيات؟ (فحص رخيص قبل أي تقسيم)
bool containsMath(String text) => _needsMath(_prepare(text));

class _Block {
  _Block(this.isMath, this.lines);
  final bool isMath;
  final List<String> lines;
  String get text => lines.join('\n');
}

List<_Block> _split(String data) {
  final blocks = <_Block>[];
  for (final line in data.split('\n')) {
    final math = _needsMath(line);
    if (blocks.isNotEmpty && blocks.last.isMath == math) {
      blocks.last.lines.add(line);
    } else {
      blocks.add(_Block(math, [line]));
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

  @override
  Widget build(BuildContext context) {
    final prepared = math ? _prepare(data) : data;
    // 🛡️ لا كسور (أو الرسّام مُطفأ) ⇒ لا تغيير إطلاقاً عن السلوك السابق.
    if (!math || !_needsMath(prepared)) {
      return MarkdownBody(
        data: data,
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
        for (final block in _split(prepared))
          if (block.isMath)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: MathText(block.text, style: base),
            )
          else if (block.text.trim().isNotEmpty)
            MarkdownBody(
              data: block.text,
              styleSheet: styleSheet,
              selectable: selectable,
            ),
      ],
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
  });

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;

  @override
  Widget build(BuildContext context) {
    final prepared = _prepare(text);
    if (!_needsMath(prepared)) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      );
    }
    return MathText(prepared, style: style);
  }
}
