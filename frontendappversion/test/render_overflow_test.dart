// ============================================================
// 📏 لا فيضانَ ولا ترميزٌ خام — على عرض الهاتف الحقيقي
// ============================================================
// 🔴 **ما رآه المالك (2026-09-09):** شريطٌ أحمر «RIGHT OVERFLOWED BY 259
//    PIXELS» فوق معادلةٍ في درس الإيثرات — خطأُ تخطيطٍ يراه الطالب.
//
// ⚠️ **ولماذا لم يكشفه اختبارُ الحزمة السابق؟** لأنه يعمل على سطحٍ
//    افتراضيّ عرضُه ٨٠٠ بكسل، والهاتف ٤٠٢ نقطة. فالمعادلة تتّسع هناك
//    وتفيض هنا — اختبارٌ أخضرُ على عيبٍ قائم، وهو أسوأ من لا اختبار.
//
// ⭐ فيُثبَّت العرضُ على مقاس الجهاز، ويُفحص **نصُّ الدروس كاملاً** كما
//    يصل الطالب (٢٣٩٢ مقطعاً من كل المواد والصفوف) لا أسطرَ المعادلات وحدها.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';

/// مقاس iPhone 17 Pro بالنقاط — الجهاز الذي يجرّب عليه المالك.
const Size _phone = Size(402, 874);

List<Map<String, dynamic>> _corpus() {
  final f = File('test/fixtures/lesson_render.json');
  if (!f.existsSync()) return const [];
  return List<Map<String, dynamic>>.from(jsonDecode(f.readAsStringSync()));
}

void main() {
  final corpus = _corpus();

  test('🛡️ الحمولة مثبّتة (وإلا مرّ المسح على فراغ)', () {
    expect(corpus.length, greaterThan(2000));
  });

  testWidgets('⭐ لا مقطعَ واحدٌ يفيض عن عرض الشاشة', (t) async {
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    final overflowed = <String>[];
    final raw = <String>[];

    for (final row in corpus) {
      final text = '${row['text']}';
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MasarMarkdown(data: text),
              ),
            ),
          ),
        ),
      ));

      // 📏 `takeException` تلتقط ما سجّله الإطار وتُفرغه — وهي الطريقة
      //    الصحيحة؛ واستبدالُ `FlutterError.onError` يصطدم بالإطار نفسه.
      final err = t.takeException();
      if (err != null && '$err'.contains('overflowed')) {
        overflowed.add('${row['scope']}: ${text.split('\n').first}');
      }

      // 🚫 ولا ترميزٌ خام يصل الشاشة في النفَس نفسه.
      for (final marker in [r'\frac', r'\chem', r'\ring', '-->', '<--']) {
        if (find.textContaining(marker).evaluate().isNotEmpty) {
          raw.add('${row['scope']}: «$marker» في ${text.split('\n').first}');
        }
      }
    }

    expect(overflowed, isEmpty,
        reason: 'فاض ${overflowed.length} مقطعاً:\n  '
            '${overflowed.take(6).join('\n  ')}');
    expect(raw, isEmpty,
        reason: 'ترميزٌ خام في ${raw.length} مقطعاً:\n  '
            '${raw.take(6).join('\n  ')}');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets(r'⭐ ولا يفيض ما يغلّفه الموديل بـ\chem — الثغرة التي أفلتت',
      (t) async {
    // 🔴 **لماذا لم يكشفه المسح الأول؟** لأنه فحص **نصّ الدروس** كما هو في
    //    الملفّات، والموديل يضيف `\chem{}` من عنده وفق قاعدة الترميز. فغلّف
    //    معادلةً كاملة، والرسّام يبني لها صفّاً واحداً لا ينكسر ⇦ فيضان.
    //
    // ⚖️ والدرس: حمولةُ الاختبار يجب أن تشبه **ما يصل الشاشة** لا ما في
    //    قاعدة البيانات. فتُحاكى هنا صيغةُ الموديل نفسها.
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);

    const samples = [
      r'\chem{CH3CH2-O-CH2CH3 + 2HBr --[H2SO4 مركز] / 120 م--> 2CH3CH2Br + H2O}',
      r'\chem{C6H5-O-CH3 + HI --> C6H5-OH + CH3I}',
      r'\chem{CH3-CH2-CH2-CH2-CH2-CH2-CH2-CH2-CH2-CH2-CH2-CH2-CH2-CH3}',
      r'المعادلة: \chem{CH3-OH + CH3-OH --[H2SO4 مركز] / 140 م--> CH3-O-CH3 + H2O}',
    ];
    final bad = <String>[];
    for (final s in samples) {
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: MasarMarkdown(data: s),
              ),
            ),
          ),
        ),
      ));
      final err = t.takeException();
      if (err != null && '$err'.contains('overflowed')) bad.add(s);
      if (find.textContaining('}').evaluate().isNotEmpty) {
        bad.add('قوسٌ شارد في: $s');
      }
    }
    expect(bad, isEmpty, reason: bad.join('\n  '));
  });

}
