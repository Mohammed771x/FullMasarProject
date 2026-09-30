import 'package:flutter/material.dart';

import '../widgets/math_text.dart';
import 'math_editor.dart';

// ============================================================
// ✍️ math_input_field.dart — حقلُ الكتابة وهو يرسم ما يُكتب
// ============================================================
// ⭐ **الطالب يرى المسألة كما في كتابه وهو يكتبها** — كسرٌ بسطُه فوق
//    مقامه، وأُسٌّ مرفوع، وجذرٌ بسقفه، والمؤشرُ الوامض داخل الخانة التي
//    يكتب فيها. لا يرى `\frac{…}{…}` أبداً.
//
// 🎯 **التركيزُ هو تركيزُ حقل المحادثة نفسُه** ([focusNode]) — فنقرةٌ على
//    المحادثة تُنزل كيبورد الرياضيات كما تُنزل كيبورد الجوال، وبطاقةُ
//    الإعدادات تُطوى معه، بلا منطقٍ ثانٍ يُنسى.
class MathInputField extends StatelessWidget {
  const MathInputField({
    super.key,
    required this.editor,
    required this.focusNode,
    required this.hint,
    required this.style,
    required this.hintStyle,
    this.enabled = true,
  });

  final MathEditor editor;
  final FocusNode focusNode;
  final String hint;
  final TextStyle style;
  final TextStyle hintStyle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled
            ? () {
                // النقرةُ الأولى تفتح الكيبورد، والمؤشرُ يبقى حيث كان.
                if (!focusNode.hasFocus) focusNode.requestFocus();
              }
            : null,
        child: ListenableBuilder(
          listenable: Listenable.merge([editor.controller, focusNode]),
          builder: (context, _) {
            final focused = focusNode.hasFocus;
            final empty = editor.text.isEmpty;
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 34, maxHeight: 150),
              child: SingleChildScrollView(
                reverse: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: empty && !focused
                      ? Text(
                          hint,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: hintStyle,
                        )
                      : empty
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            MathText(kCaretMark, style: style),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                hint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: hintStyle,
                              ),
                            ),
                          ],
                        )
                      : MathText(
                          editor.display(showCaret: focused),
                          style: style,
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
