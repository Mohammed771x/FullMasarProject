// يمرّر **حمولة حقيقية من الخادم** على ويدجت التطبيق نفسها.
// الملف `fixtures/live_quiz.json` مأخوذ من `/quiz/generate` مباشرةً.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  // حمولتان حقيقيتان: رياضيات (deepseek) وفيزياء (gpt-4o-mini)
  final questions = <Map<String, dynamic>>[];
  for (final name in ['live_quiz.json', 'live_quiz_physics.json']) {
    final f = File('test/fixtures/$name');
    if (!f.existsSync()) continue;
    final d = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    questions.addAll((d['questions'] as List).cast<Map<String, dynamic>>());
  }
  if (questions.isEmpty) return;

  test('الحمولة الحيّة سليمة البنية', () {
    expect(questions, isNotEmpty);
    for (final q in questions) {
      expect((q['options'] as List).length, 4);
      expect(q['correct_index'], inInclusiveRange(0, 3));
    }
  });

  testWidgets('كل سؤال وخيار من الخادم يُرسم بلا انهيار', (t) async {
    for (final q in questions) {
      final texts = <String>[q['q'] as String, ...(q['options'] as List).cast<String>()];
      for (final s in texts) {
        await t.pumpWidget(_wrap(MathOrText(s)));
        expect(_noException(t), isTrue, reason: 'انهار عند: $s');
      }
    }
  });

  testWidgets('كل كسر في الحمولة يُرسم بخط فاصل', (t) async {
    var drawn = 0;
    for (final q in questions) {
      final texts = <String>[q['q'] as String, ...(q['options'] as List).cast<String>()];
      for (final s in texts) {
        if (!containsMath(s)) continue;
        await t.pumpWidget(_wrap(MathOrText(s)));
        final rules = t.widgetList<Container>(find.byType(Container)).where((c) {
          final box = c.constraints;
          return box != null && box.maxHeight == 1.6;
        });
        expect(rules, isNotEmpty, reason: 'كسر بلا خط: $s');
        drawn += rules.length;
      }
    }
    // ignore: avoid_print
    print('✅ كسور مرسومة من حمولة الخادم الحيّة: $drawn');
  });
}

bool _noException(WidgetTester t) => t.takeException() == null;
