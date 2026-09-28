// ✏️ «أعرب ما تحته خط» — الخطُّ يُرسم في فقاعة الشرح، لا عريضاً.
//
// 🔴 **ما أوجبه (2026-09-29):** نحوُ الأول والثاني يطلب إعرابَ «ما تحته خط»،
//    والشرحُ يؤشّر الكلمةَ بـ`__كلمة__`. و`MarkdownBody` يجعلها **عريضةً**
//    بقاعدة الماركداون المعيارية — فيضيع التمييزُ الذي بُني عليه السؤال.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

/// كلُّ مقطعٍ نصّيٍّ مرسوم — مع زخرفته وثقله.
List<(String, TextDecoration?, FontWeight?)> _spans(WidgetTester t) {
  final out = <(String, TextDecoration?, FontWeight?)>[];
  void walk(InlineSpan s, TextStyle? inherited) {
    if (s is TextSpan) {
      final st = inherited?.merge(s.style) ?? s.style;
      if (s.text != null && s.text!.trim().isNotEmpty) {
        out.add((s.text!, st?.decoration, st?.fontWeight));
      }
      for (final c in s.children ?? const <InlineSpan>[]) {
        walk(c, st);
      }
    }
  }
  for (final e in t.widgetList<RichText>(find.byType(RichText))) {
    walk(e.text, null);
  }
  return out;
}

Future<void> _pump(WidgetTester t, String md) => t.pumpWidget(MaterialApp(
    home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: MasarMarkdown(data: md)))));

void main() {
  testWidgets('__كلمة__ تُرسم مخطوطاً تحتها — ورموزُها لا تظهر', (t) async {
    await _pump(t, 'أعرب ما تحته خط: «إنّما __البيعُ__ مثلُ الرّبا».');
    final s = _spans(t);
    final hit = s.where((e) => e.$1.contains('البيعُ')).toList();
    expect(hit, isNotEmpty);
    expect(hit.first.$2, TextDecoration.underline,
        reason: 'الكلمةُ المقصودة تحتها خطّ لا مجرّدُ تغميق');
    expect(s.any((e) => e.$1.contains('__')), isFalse,
        reason: 'الشرطتان ترميزٌ يُرسم لا يُعرض');
  });

  testWidgets('و**العريض** باقٍ عريضاً بلا خطّ — لم يُمسّ', (t) async {
    await _pump(t, 'هذا **مفعولٌ مطلق** منصوب.');
    final hit = _spans(t).where((e) => e.$1.contains('مفعولٌ مطلق')).first;
    expect(hit.$2, isNot(TextDecoration.underline));
    expect(hit.$3, isNotNull);
  });

  testWidgets('والفراغُ ____ يبقى فراغاً — ليس كلمةً مخطوطاً تحتها', (t) async {
    await _pump(t, 'أكمل: جاء الطالبُ ____ .');
    expect(_spans(t).any((e) => e.$2 == TextDecoration.underline), isFalse);
  });

  testWidgets('وفي الإنجليزية كذلك — Make questions of the __underlined__ word',
      (t) async {
    await _pump(t, 'She went to __school__ by bus.');
    final hit = _spans(t).where((e) => e.$1.contains('school')).first;
    expect(hit.$2, TextDecoration.underline);
  });
}
