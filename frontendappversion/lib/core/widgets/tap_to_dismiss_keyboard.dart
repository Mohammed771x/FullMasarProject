import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

// ==========================================
// ⌨️ نقرةٌ على المحادثة تُنزل الكيبورد — والتمريرُ لا
// ==========================================
// 🎯 **طلبُ المالك (٢٠٢٦-٠٩-٢٣):** «جانا رد وأبغى أقرأ — ما نقدر ننزل
//    الكيبورد. أبغى لو ضغطت على نص الشاشة، كما ChatGPT، الكيبورد يخرج
//    وأقرأ براحتي… **مش إنه لو حركت لفوق ولا تحت، لا — لو ضغطت كذا ضغطة**».
//
// ⚖️ **لماذا `Listener` لا `GestureDetector(onTap)`:** الثاني يدخل ساحةَ
//    الإيماءات فيخسر أمام كل ما تحته يلتقط النقر — تحديدُ النصّ في
//    الفقاعة، والروابط، وأزرارُ النسخ — فتصير النقرةُ على نصِّ الجواب
//    (وهو أغلبُ الشاشة) بلا أثر. والمستمعُ الخامُ **يرى النقرةَ ولا
//    ينافس عليها**: ما تحته يعمل كما كان، والكيبورد ينزل معه.
//
// 📏 **والتمييزُ بين النقرة والسحب بالمسافة والزمن:** إصبعٌ تحرّك أكثر من
//    [kTouchSlop] سحبٌ للتمرير فلا يُمسّ الكيبورد، وإصبعٌ بقي أكثر من
//    [_maxTapDuration] ضغطةٌ مطوّلةٌ (تحديدُ نصّ) لا نقرة.
//
// 🔒 **ولا يلمس إلا تركيزَ حقلٍ نصّيّ:** `unfocus` على لا شيء لا يفعل شيئاً،
//    فلا تتغيّر حالةٌ حين لا كيبوردَ أصلاً.
class TapToDismissKeyboard extends StatefulWidget {
  const TapToDismissKeyboard({super.key, required this.child});

  final Widget child;

  @override
  State<TapToDismissKeyboard> createState() => _TapToDismissKeyboardState();
}

class _TapToDismissKeyboardState extends State<TapToDismissKeyboard> {
  static const Duration _maxTapDuration = Duration(milliseconds: 350);

  int? _pointer;
  Offset _downAt = Offset.zero;
  bool _moved = false;

  /// ⏱️ مؤقّتٌ لا طوابعُ زمنية: طوابعُ الأحداث قد تصل أصفاراً (أحداثٌ
  ///    مُركَّبة)، والمؤقّتُ يعمل على الجهاز وفي الاختبار سواءً.
  Timer? _holdTimer;

  @override
  void dispose() {
    _holdTimer?.cancel();
    super.dispose();
  }

  void _onDown(PointerDownEvent e) {
    // إصبعٌ ثانٍ (قرصٌ للتكبير) يُلغي النقرةَ كلَّها.
    if (_pointer != null) {
      _moved = true;
      return;
    }
    _pointer = e.pointer;
    _downAt = e.position;
    _moved = false;
    _holdTimer?.cancel();
    _holdTimer = Timer(_maxTapDuration, () => _moved = true); // ضغطةٌ مطوّلة
  }

  void _onMove(PointerMoveEvent e) {
    if (e.pointer != _pointer) return;
    if ((e.position - _downAt).distance > kTouchSlop) _moved = true;
  }

  void _onUp(PointerUpEvent e) {
    if (e.pointer != _pointer) return;
    _holdTimer?.cancel();
    final isTap = !_moved;
    _pointer = null;
    if (!isTap) return;
    final focus = FocusManager.instance.primaryFocus;
    final ctx = focus?.context;
    if (focus == null || ctx == null) return;
    // لا نُسقط تركيزَ ما ليس حقلَ كتابة (زرٌّ مُركَّزٌ بلوحة مفاتيحٍ خارجية).
    final isTextField = ctx.widget is EditableText ||
        ctx.findAncestorWidgetOfExactType<EditableText>() != null;
    if (isTextField) focus.unfocus();
  }

  void _onCancel(PointerCancelEvent e) {
    if (e.pointer != _pointer) return;
    _holdTimer?.cancel();
    _pointer = null;
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: widget.child,
      );
}
