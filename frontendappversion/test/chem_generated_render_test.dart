// ============================================================
// ⚗️ ١٦٥ شرحاً حقيقياً — كل دروس الكيمياء، على عرض الجهاز
// ============================================================
// 🔴 طلبُ المالك (2026-09-10): «جرب كل الدروس… القوانين والأشكال، ضبط
//    الوضع كامل. المحتوى ما بيتغير، فلو ضبطناه خلاص الأمور طيبة».
//
// 📌 والحمولة **ليست نصّ الملفّات بل ما يولّده الموديل فعلاً**: شُغِّل الشرح
//    على ١٦٥ درساً (أول ٤٣ · ثاني ٦٤ · ثالث ٥٨) وحُفظت الأجوبة. وهذه هي
//    الطبقة التي أفلتت مرّتين — العيوب كانت في **إضافات الموديل**
//    (`\chem{}` حول معادلة · `\frac{X}{→}`) لا في الكتاب.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

const Size _phone = Size(402, 874);

List<Map<String, dynamic>> _corpus() {
  final f = File('test/fixtures/chem_generated.json');
  if (!f.existsSync()) return const [];
  return List<Map<String, dynamic>>.from(jsonDecode(f.readAsStringSync()));
}

Widget _page(String text, {String? subject}) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: MasarMarkdown(data: text, subject: subject),
            ),
          ),
        ),
      ),
    );

void main() {
  final corpus = _corpus();

  test('🛡️ الحمولة مثبّتة — ١٦٥ شرحاً', () {
    expect(corpus.length, greaterThan(150));
  });

  testWidgets('⭐ لا شرحَ واحدٌ يفيض ولا يعرض ترميزاً خاماً', (t) async {
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final overflowed = <String>[];
    final raw = <String>[];

    for (final row in corpus) {
      final text = '${row['text']}';
      await t.pumpWidget(_page(text, subject: 'كيمياء'));

      final err = t.takeException();
      if (err != null && '$err'.contains('overflowed')) {
        overflowed.add('${row['lesson']}');
      }
      for (final marker in [r'\frac', r'\chem', r'\ring', '-->', '<--', '^{']) {
        if (find.textContaining(marker).evaluate().isNotEmpty) {
          raw.add('${row['lesson']}: «$marker»');
        }
      }
    }

    expect(overflowed, isEmpty,
        reason: 'فاض ${overflowed.length}:\n  ${overflowed.take(5).join('\n  ')}');
    expect(raw, isEmpty,
        reason: 'ترميزٌ خام في ${raw.length}:\n  ${raw.take(5).join('\n  ')}');
  }, timeout: const Timeout(Duration(minutes: 6)));

  // ══════════════════════════════════════════════════
  // 🧪 عزلُ المواد — رسّامُ كلِّ مادةٍ في مادته
  // ══════════════════════════════════════════════════
  //
  // ⭐ قرار المالك: «خلّ الرسّام يكون خاص بكل مادة، ما يروح لمادة ثانية
  //    يخربطها». والعزلُ **صريحٌ بالمعامل** لا متروكاً لصدفة المحتوى.
  group('🧪 عزل المواد', () {
    const equation = 'CH3-CH2-OH --[Cu]--> CH3-CHO + H2';

    testWidgets('الكيمياء والأحياء تُرسم فيهما المعادلات', (t) async {
      for (final s in MasarMarkdown.chemSubjects) {
        await t.pumpWidget(_page(equation, subject: s));
        expect(find.textContaining('-->'), findsNothing, reason: s);
        expect(find.text('⟶'), findsOneWidget, reason: s);
      }
    });

    testWidgets('⛔ ولا تُرسم في مادةٍ أخرى', (t) async {
      // ⚠️ نصٌّ فيه سهمٌ في العربي أو التاريخ يبقى نصّاً كما كتبه الكتاب،
      //    فلا يُقحم عليه صندوقُ معادلةٍ لا معنى له هناك.
      for (final s in ['عربي', 'تاريخ', 'انجليزي', 'رياضيات']) {
        await t.pumpWidget(_page(equation, subject: s));
        expect(find.text('⟶'), findsNothing, reason: s);
      }
    });

    testWidgets('ومادةٌ مجهولة تبقى على السلوك السابق', (t) async {
      // 🛡️ شاشةٌ لم تُمرَّر إليها المادة بعد (المحفوظات) لا تفقد معادلاتها.
      await t.pumpWidget(_page(equation));
      expect(find.text('⟶'), findsOneWidget);
    });
  });
}
