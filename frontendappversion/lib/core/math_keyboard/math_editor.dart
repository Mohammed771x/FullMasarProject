import 'package:flutter/widgets.dart';

import '../widgets/math_text.dart';

// ============================================================
// 🧮 math_editor.dart — منطقُ محرّر الرياضيات (بلا واجهة)
// ============================================================
// ⭐ **مصدرُ الحقيقة نصٌّ واحد** هو `TextEditingController` المحادثة نفسُه،
//    بترميز الرسّام ذاته (`\frac{}{}` · `\sup{}` · `\sqrt{}` …). فما يكتبه
//    الطالب هو حرفياً ما يُرسل للموديل، وما يُرسم في فقاعته، وما يُحفظ
//    في السجلّ — لا صيغةَ وسيطة تُترجم فتخطئ.
//
// ⌨️ والمحرّر لا يعرف إلا ثلاثة أشياء: **أين يقف المؤشر** (مواضعُ صالحة
//    لا تقع داخل اسم أمر)، و**كيف يُدرج قالباً** ويدخل أولى خاناته، و**كيف
//    يحذف** بحيث يُمحى القالبُ الفارغ كلُّه بضغطةٍ لا بعشر.

/// موضعُ المؤشر داخل القالب — «‸» لا «|» لأن «|» نفسَها قيمةٌ مطلقة.
const String kTemplateCaret = '‸';

/// أوامرُ الترميز وعددُ خاناتها — ما عداها نصٌّ عاديّ.
const Map<String, int> _arity = {
  r'\frac': 2,
  r'\perm': 2,
  r'\comb': 2,
  r'\sqrt': 1,
  r'\sup': 1,
  r'\sub': 1,
  r'\fact': 1,
  r'\ovl': 1,
};

/// أسماءُ الدوال التي تُمحى كتلةً واحدة: من كتب «جتا» لا يحذفها بثلاث ضغطات.
const List<String> kMathFunctions = [
  'جتا',
  'ظتا',
  'قتا',
  'جا',
  'ظا',
  'قا',
  'لو',
  'لط',
  'نها',
];

final _command = RegExp(r'\\[a-zA-Z]+');

/// أمرٌ واحد بموضعه وخاناته — `groups` أزواجُ (فتح، إغلاق) لكل خانة.
class _Span {
  _Span(this.start, this.end, this.groups);
  final int start, end;
  final List<(int, int)> groups;
}

class MathEditor {
  MathEditor(this.controller);

  final TextEditingController controller;

  String get text => controller.text;

  int get caret {
    final o = controller.selection.baseOffset;
    return (o < 0 || o > text.length) ? text.length : o;
  }

  void _set(String t, int c) {
    controller.value = TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(offset: c.clamp(0, t.length)),
    );
  }

  // ══════════════ البنية ══════════════

  /// كلُّ أمرٍ في النصّ بخاناته — يُعدّ الأقواس المتداخلة ولا يقف عند أوّلها.
  List<_Span> _spans([String? source]) {
    final t = source ?? text;
    final out = <_Span>[];
    for (final m in _command.allMatches(t)) {
      final want = _arity[m.group(0)];
      if (want == null) continue;
      var i = m.end;
      final groups = <(int, int)>[];
      // دليلُ الجذر «[٣]» خانةٌ إضافية قبل جسمه.
      if (m.group(0) == r'\sqrt' && i < t.length && t[i] == '[') {
        final close = _match(t, i, '[', ']');
        if (close < 0) continue;
        groups.add((i, close));
        i = close + 1;
      }
      for (var k = 0; k < want; k++) {
        if (i >= t.length || t[i] != '{') break;
        final close = _match(t, i, '{', '}');
        if (close < 0) break;
        groups.add((i, close));
        i = close + 1;
      }
      if (groups.isNotEmpty) out.add(_Span(m.start, i, groups));
    }
    return out;
  }

  static int _match(String t, int open, String o, String c) {
    var depth = 0;
    for (var i = open; i < t.length; i++) {
      if (t[i] == o) depth++;
      if (t[i] == c) {
        depth--;
        if (depth == 0) return i;
      }
    }
    return -1;
  }

  /// مواضعُ المؤشر الصالحة. ⚖️ لا يقف المؤشر **داخل اسم أمر** («\fr|ac»)
  /// ولا **بين خانتين** («}|{») — فهذان موضعان لا معنى للكتابة فيهما.
  List<int> stops([String? source]) {
    final t = source ?? text;
    final bad = <int>{};
    for (final m in _command.allMatches(t)) {
      for (var i = m.start + 1; i <= m.end; i++) {
        bad.add(i);
      }
    }
    for (var i = 1; i < t.length; i++) {
      if ((t[i - 1] == '}' || t[i - 1] == ']') && (t[i] == '{')) bad.add(i);
    }
    return [
      for (var i = 0; i <= t.length; i++)
        if (!bad.contains(i)) i,
    ];
  }

  // ══════════════ الحركة ══════════════

  /// ⬅️ خطوةٌ منطقية للأمام (يساراً على الشاشة في العربية).
  void forward() {
    final s = stops();
    var next = s.firstWhere((x) => x > caret, orElse: () => caret);
    // 🔴 **الخروجُ من خانةٍ يتجاوز المسافةَ بعدها**: «جتا\sup{٣}‸ (٢س)»
    //    كان يكتب «(٢س)» قبل المسافة فيلتصق بالأُسّ ويُدفع الفراغُ آخراً.
    final t = text;
    if (next > 0 && next < t.length && t[next - 1] == '}' && t[next] == ' ') {
      next++;
    }
    _set(t, next);
  }

  /// ➡️ خطوةٌ منطقية للخلف.
  void backward() {
    final s = stops();
    final prev = s.lastWhere((x) => x < caret, orElse: () => caret);
    _set(text, prev);
  }

  void toEnd() => _set(text, text.length);

  // ══════════════ الإدراج ══════════════

  /// يُدرج نصّاً عادياً عند المؤشر.
  void insert(String s) {
    final c = caret;
    _set(text.replaceRange(c, c, s), c + s.length);
  }

  /// يُدرج قالباً — و`‸` فيه موضعُ المؤشر بعد الإدراج (أوّلُ خانة غالباً).
  ///
  /// ⭐ **والأُسُّ بعد اسم دالة يلتصق بالاسم لا بالمسافة**: «جا ‸» ثم «²»
  ///    تصير «جا² ‸» لا «جا ²» — وهذا عينُ ما أفسد صورةَ المالك: موضعُ
  ///    التربيع بين الدالة ومتغيّرها هو المعنى كلُّه.
  void insertTemplate(String template) {
    var c = caret;
    var t = text;
    final isScript =
        template.startsWith(r'\sup{') || template.startsWith(r'\sub{');
    if (isScript && c > 0 && t[c - 1] == ' ') {
      final before = t.substring(0, c - 1);
      if (kMathFunctions.any(before.endsWith)) {
        // يُدرج قبل المسافة، والمسافةُ تبقى بعد الأُسّ.
        final body = template.replaceAll(kTemplateCaret, '');
        final at = template.indexOf(kTemplateCaret);
        final filled = !template.contains('{$kTemplateCaret}');
        t = t.replaceRange(c - 1, c - 1, body);
        final caretAt = filled ? c + body.length : c - 1 + at;
        _set(t, caretAt);
        return;
      }
    }
    final at = template.indexOf(kTemplateCaret);
    final body = template.replaceAll(kTemplateCaret, '');
    t = t.replaceRange(c, c, body);
    c = c + (at < 0 ? body.length : at);
    _set(t, c);
  }

  // ══════════════ الحذف ══════════════

  /// ⌫ الحذف كما في آلات الحساب الحديثة:
  /// * بعد قالبٍ مغلق ⇐ يدخل آخرَ خاناته (لا يمحو القوسَ فيكسر الترميز).
  /// * في أوّل خانةٍ ⇐ إن كان القالبُ فارغاً كلُّه مُحي بضغطة، وإلا رجع خطوة.
  /// * بعد اسم دالة ⇐ يمحو الاسمَ كلَّه.
  void backspace() {
    final c = caret;
    final t = text;
    if (c == 0) return;
    final prev = t[c - 1];

    if (prev == '}' || prev == ']') {
      _set(t, c - 1);
      return;
    }
    if (prev == '{' || prev == '[') {
      for (final sp in _spans()) {
        if (sp.groups.any((g) => g.$1 == c - 1)) {
          final empty = sp.groups.every((g) => g.$2 == g.$1 + 1);
          if (empty) {
            _set(t.replaceRange(sp.start, sp.end, ''), sp.start);
          } else {
            backward();
          }
          return;
        }
      }
      backward();
      return;
    }
    // اسمُ دالةٍ كاملاً (ومعه مسافتُه إن وُجدت).
    final trail = prev == ' ' ? 1 : 0;
    final head = t.substring(0, c - trail);
    for (final f in kMathFunctions) {
      if (head.endsWith(f)) {
        final from = head.length - f.length;
        final lead = from == 0 || !RegExp(r'[ء-ي]').hasMatch(t[from - 1]);
        if (lead) {
          _set(t.replaceRange(from, c, ''), from);
          return;
        }
      }
    }
    _set(t.replaceRange(c - 1, c, ''), c - 1);
  }

  void clear() => _set('', 0);

  // ══════════════ العرض ══════════════

  /// نصُّ **العرض**: المؤشرُ مدسوسٌ في موضعه، وكلُّ خانةٍ فارغة تحمل علامة
  /// خانة ([kSlotMark]) — فيرى الطالب مربّعاً منقّطاً ينتظر الكتابة.
  String display({bool showCaret = true}) {
    final t = text;
    final c = caret;
    final b = StringBuffer();
    for (var i = 0; i <= t.length; i++) {
      final emptyGroup =
          i > 0 &&
          i < t.length &&
          ((t[i - 1] == '{' && t[i] == '}') ||
              (t[i - 1] == '[' && t[i] == ']'));
      if (i == c && showCaret) b.write(kCaretMark);
      if (emptyGroup) b.write(kSlotMark);
      if (i < t.length) b.write(t[i]);
    }
    return b.toString();
  }
}
