// ============================================================
// 🧾 كل سطرٍ فيه ترميز في الشروح المخزونة (Backend/data/explanations)
//    يُرسم بعرض الجهاز — فلا يظهر أمرٌ خام ولا يفيض سطر.
// ============================================================
// التدقيق الحسابي اليدوي (audits/numeric-2026-09) عدّل مئات الأسطر يدوياً
// (\frac · \sup · \sub · \nuc · \chem …). هذا الحارس يضمن أن كل تعديلٍ
// يُرسم كما قُصد — لا عيّنةً بل كلَّ سطر.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/widgets/math_text.dart';

const Size _phone = Size(402, 874);
final _markup = RegExp(r'\\(frac|sqrt|sup|sub|fact|perm|comb|ovl|chem|ring|nuc)\{');
final _raw = RegExp(r'\\[a-zA-Z]{2,}');

List<String> _lines() {
  final dir = Directory('../Backend/data/explanations');
  if (!dir.existsSync()) return const [];
  final out = <String>{};
  for (final f in dir.listSync(recursive: true).whereType<File>()) {
    if (!f.path.endsWith('.json') || f.path.contains('/_')) continue; // _rejected لا يُسلَّم
    final Map<String, dynamic> d = jsonDecode(f.readAsStringSync());
    for (final v in d.values) {
      for (final l in '${(v as Map)['answer']}'.split('\n')) {
        if (_markup.hasMatch(l)) out.add(l.trim());
      }
    }
  }
  return out.toList()..sort();
}

void main() {
  final lines = _lines();

  test('🛡️ الحمولة مثبّتة', () => expect(lines.length, greaterThan(1000)));

  testWidgets('⭐ لا أمرَ خامٌ ولا فيضان في أي سطر شرح', (t) async {
    t.view.physicalSize = _phone * 3;
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final bad = <String>[];
    for (final line in lines) {
      await t.pumpWidget(MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16), child: MathText(line)),
            ),
          ),
        ),
      ));
      final err = t.takeException();
      if (err != null) bad.add('استثناء ${'$err'.split('\n').first}: $line');
      for (final w in t.widgetList<Text>(find.byType(Text))) {
        final s = w.data ?? w.textSpan?.toPlainText() ?? '';
        if (_raw.hasMatch(s)) { bad.add('خام «${_raw.firstMatch(s)![0]}»: $line'); break; }
      }
      for (final w in t.widgetList<RichText>(find.byType(RichText))) {
        final s = w.text.toPlainText();
        if (_raw.hasMatch(s)) { bad.add('خام «${_raw.firstMatch(s)![0]}»: $line'); break; }
      }
    }
    expect(bad, isEmpty, reason: '${bad.length}/${lines.length}:\n  ${bad.take(40).join('\n  ')}');
  }, timeout: const Timeout(Duration(minutes: 20)));
}
