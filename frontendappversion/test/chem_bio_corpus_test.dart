// ⚗️🧬 **الكيمياء والأحياء على عرض الجهاز — بسطورٍ من الكتاب نفسه.**
//
// 🔴 طلبُ المالك (2026-09-12): «شوف الكيمياء والأحياء برضو، وشيك على كل شي».
//
// ⚖️ والمادّتان تشتركان في السهم: ٣٧٧ سطراً في الكيمياء و٥٧ في الأحياء
//    («٦ CO₂ + ١٢ H₂O --(طاقة ضوئية)--> …»). ورسّامُ المعادلات مقصورٌ
//    عليهما ([masar_markdown.chemSubjects]) كي لا يمسّ سهمَ نصٍّ أدبيّ.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/chem_equation.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

const _phone = Size(402, 874);

void main() {
  final rows = (jsonDecode(
          File('test/fixtures/chem_bio_lines.json').readAsStringSync()) as List)
      .cast<Map<String, dynamic>>();

  testWidgets('⭐ لا فيضانَ ولا ترميزَ خام في أيٍّ منهما', (t) async {
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

      expect(t.takeException(), isNull, reason: 'انهار: ${r['out']}');
      for (final tok in const [
        r'\frac', r'\chem', r'\ring', r'\sup', r'\sqrt', r'\ovl'
      ]) {
        expect(find.textContaining(tok), findsNothing,
            reason: 'ترميزٌ خام: ${r['out']}');
      }
    }
  });

  testWidgets('⭐ ورسّامُ المعادلات مقصورٌ على الكيمياء والأحياء', (t) async {
    // ⚖️ سطرُ نهاياتٍ رياضيّ فيه «س←٠» يستوفي شرطَ المعادلة شكلاً؛
    //    والحدُّ الثاني هو المادة، فلا يصل الرسّامَ أصلاً.
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3.0;
    addTearDown(t.view.reset);
    const line = '5) أوجد نهـ (س←0) (س - جا س) / (س + ظا س)';
    for (final subject in const ['رياضيات', 'فيزياء', 'تاريخ']) {
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: MasarMarkdown(data: line, subject: subject)),
        ),
      ));
      await t.pumpAndSettle();
      expect(find.byType(ChemEquation), findsNothing, reason: subject);
    }
  });

  test('🔴 ولا شرطةَ طورٍ صارت كسراً', () {
    // «Zn(s) / Zn+2(aq)» رمزُ نصف خلية — الشرطةُ حدُّ طور لا قسمة،
    //   وكانت تخرج `\frac{Zn(s)}{Zn}+2(aq)` فتقطع الصيغة نصفين.
    for (final r in rows) {
      final out = r['out'] as String;
      expect(RegExp(r'\\frac\{[^{}]*\([slgaq]{1,2}\)').hasMatch(out), isFalse,
          reason: 'حالةُ مادّةٍ داخل كسر: $out');
    }
  });
}
