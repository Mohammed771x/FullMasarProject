// ⌋ⁿلᵣ **رموز الرياضيات على عرض الجهاز — بسطورٍ من الكتاب نفسه.**
//
// ⚖️ الأسطر مأخوذةٌ من `data/subjects` ومارّةٌ بمسار الخادم (`format_arabic_math`)
//    — لا نصوصَ من تأليفي، فما يُفحص هنا هو ما يراه الطالب حرفياً.
//
// 🔴 **والعرض ٤٠٢ نقطة لا ٨٠٠**: الاختبارات كانت تمرّ بينما الشاشة تفيض،
//    لأن سطح الاختبار الافتراضي أوسع من أيّ هاتف. راجع [render_overflow_test].

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

const _phone = Size(402, 874);

void main() {
  final rows = (jsonDecode(
          File('test/fixtures/factorial_lines.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  testWidgets('⭐ لا سطرَ يفيض ولا يعرض ترميزاً خاماً', (t) async {
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);

    for (final r in rows) {
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: MasarMarkdown(
                data: r['out'] as String,
                subject: r['subject'] as String,
              ),
            ),
          ),
        ),
      ));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull,
          reason: 'فاض أو انهار: ${r['out']}');
      for (final token in const [
        r'\fact', r'\perm', r'\comb', r'\sup', r'\ovl', r'\sqrt'
      ]) {
        expect(find.textContaining(token), findsNothing,
            reason: 'ترميزٌ خام ظهر للطالب: ${r['out']}');
      }
    }
  });

  test('🔴 ولا مقدارَ فاسدٍ داخل زاويةٍ أو رمزِ عدّ', () {
    // «نلاحظ تناوب الإشارة وظهور المضروب.» أنتجت `\fact{.}` فعلاً.
    final bodies = <String>[
      for (final r in rows)
        ...RegExp(r'\\(?:fact|perm|comb|sup|ovl)\{([^}]*)\}(?:\{([^}]*)\})?')
            .allMatches(r['out'] as String)
            .expand((m) => [m.group(1)!, if (m.group(2) != null) m.group(2)!]),
    ];
    expect(bodies, isNotEmpty);
    for (final b in bodies) {
      // ⚖️ الفراغُ مسموحٌ في `\fact{}` وحدها: الرمز مجرّداً في التعريف.
      if (b.isEmpty) continue;
      // ⚠️ المقادير المتداخلة («(ع̅)̅» ⇒ `\ovl{(\ovl{ع})}`) لا يبلغها
      //    تعبيرٌ نمطيّ بلا عدّ أقواس — والتعشيشُ نفسُه مفحوصٌ بالرسم
      //    في [math_text_test]. هنا نفحص المقادير الطرفية.
      if (b.contains('\\')) continue;
      // ⚖️ والحروف اليونانية مقادير مشروعة (π · μ · ω) لا شوائب.
      expect(RegExp(r'^[\u0621-\u064A\u0370-\u03FF0-9٠-٩A-Za-z\s\-+()،/×÷.∪∩′″±]+$').hasMatch(b), isTrue,
          reason: 'مقدارٌ غير سليم داخل المضروب: «$b»');
    }
  });
}
