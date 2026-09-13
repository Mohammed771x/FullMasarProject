// ============================================================
// 📊 مسحٌ شامل: كل سطرٍ فيه سهمُ تفاعل في المنهج كلّه
// ============================================================
// 🔴 طلبُ المالك (2026-09-09): «جرب كل الدروس… ما تعطيني شي إلا وهو مضبوط
//    مية بالمية». فالعيّنة لا تكفي حكماً — راجع [sweep-siblings-before-reporting].
//
// 📌 والحمولة **مستخرجةٌ من ملفّات المنهج نفسها** لا مصنوعة: ٤٩٧ سطراً
//    فريداً من الكيمياء (٤٢٨) والأحياء (٥٨) والرياضيات (١١) عبر الصفوف الثلاثة.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/chem_equation.dart';

List<Map<String, dynamic>> _corpus() {
  final f = File('test/fixtures/curriculum_equations.json');
  if (!f.existsSync()) return const [];
  return List<Map<String, dynamic>>.from(jsonDecode(f.readAsStringSync()));
}

void main() {
  final corpus = _corpus();

  test('🛡️ الحمولة مثبّتة فعلاً (وإلا مرّ المسح على فراغ)', () {
    expect(corpus.length, greaterThan(400));
  });

  test('⚗️ معادلات الكيمياء تُعرف معادلاتٍ', () {
    // ⚠️ ليس كل سطرٍ فيه سهم معادلةً: بعضها نثرٌ عربي فيه «←».
    //    فنقيس **النسبة** في الكيمياء وحدها حيث الغالبية معادلات.
    final chem = corpus.where((r) => '${r['scope']}'.startsWith('كيمياء'));
    final known = chem.where((r) => looksLikeEquation('${r['line']}')).length;
    expect(known / chem.length, greaterThan(0.75),
        reason: 'تعرّفنا على $known من ${chem.length}');
  });

  testWidgets('⭐ لا سطرَ واحدٌ يُسقط الرسّام — ٤٩٧ سطراً', (t) async {
    // 🎯 **هذا هو الاختبار الذي يهمّ**: انهيارُ الرسّام على معادلةٍ واحدة
    //    يعني شاشةً حمراء لطالبٍ في درسٍ ما، ولن نعرف أيّ درس.
    final failures = <String>[];
    for (final row in corpus) {
      final line = '${row['line']}';
      if (!looksLikeEquation(line)) continue;
      try {
        await t.pumpWidget(MaterialApp(
          home: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(body: SingleChildScrollView(child: ChemEquation(line))),
          ),
        ));
        // 🚫 **وفي النفَس نفسه**: لا يبقى ترميزُ سهمٍ خام على الشاشة.
        //    «-->» ثلاثةُ محارف محايدة هي بالضبط ما ينقلبه الاتجاه الثنائي،
        //    فبقاؤها يعني أن العطل لم يُعالَج بل انتقل.
        if (find.textContaining('-->').evaluate().isNotEmpty ||
            find.textContaining('<--').evaluate().isNotEmpty) {
          failures.add('${row['scope']}: بقي سهمٌ خام في «$line»');
        }
      } catch (e) {
        failures.add('${row['scope']}: ${line.substring(0, line.length.clamp(0, 60))} → $e');
      }
    }
    expect(failures, isEmpty,
        reason: 'انهار الرسّام على:\n  ${failures.take(5).join('\n  ')}');
  });
}
