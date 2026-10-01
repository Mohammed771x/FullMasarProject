// ============================================================
// ⬇️ النهاية «نها» والحدُّ تحتها — في كل مكانٍ تظهر فيه (٢٠٢٦-١٠-٠١).
// ============================================================
// طلبُ المالك: «عدّل في كل مكان موضوع النهايات». فالحارسُ هنا شيئان:
//   ١) كلُّ صيغةٍ وُجدت في الكتب والشروح والاختبارات تتحوّل.
//   ٢) **مسحُ Backend/data كلِّه**: لا يبقى «نهـ» ولا «نها س←…» غيرَ مكدّسة.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/masar_markdown.dart';
import 'package:ye_student_tutor/core/widgets/math_text.dart';

/// بقايا غيرُ مكدّسة: «نهـ»، أو «نها» يتبعها متغيّرٌ وسهمٌ بلا `\sub`.
final _leftover = RegExp(
    r'(?<![ء-ي])(نهـ|نها\s*\(?\s*(عندما\s+)?[ء-يa-zA-Z]\s*(←|→|->)'
    r'|نها(?![ء-ي])(?!\\sub)[^.؟!:\n]{1,100}\sعند(?:ما)?\s+[ء-يa-zA-Z]\s*(←|→|->))');

void main() {
  group('الصيغ', () {
    const cases = {
      'نهـ (س←٠) جا س': r'نها\sub{س←٠} جا س',
      'نهـ(س←∞) \\frac{١}{س}': r'نها\sub{س←∞} \frac{١}{س}',
      'نها (ن ← ∞) أ': r'نها\sub{ن←∞} أ',
      'نهـ (س←π/٢)': r'نها\sub{س←π/٢}',
      'نهـ (س←-٣)،': r'نها\sub{س←-٣}،',
      r'نها س←\frac{٣}{٢} \frac{س}{٢}': r'نها\sub{س←\frac{٣}{٢}} \frac{س}{٢}',
      r'نها س←٢ \sqrt{س}': r'نها\sub{س←٢} \sqrt{س}',
      'نها س←أ د(س)': r'نها\sub{س←أ} د(س)',
      'نهـ (س→٠)': r'نها\sub{س←٠}',
      'نها س->٠ س': r'نها\sub{س←٠} س',
      // «نهـ» وحدها بعد ذكر الحدّ — تصير «نها».
      'يتبقى: نهـ (١ + جتا س)': 'يتبقى: نها (١ + جتا س)',
      // دليلٌ مكتوبٌ أصلاً يُلصق بالرمز.
      r'نها \sub{س←٠} س': r'نها\sub{س←٠} س',
      // ↪️ الحدُّ بعد المقدار (الوزاري) — يُنقل تحت «نها».
      r'(١) نها \frac{١ - س}{جتا س} عندما س ← ١ = ........':
          r'(١) نها\sub{س←١} \frac{١ - س}{جتا س} = ........',
      r'نها د(س) عندما س ← أ = د(أ)': r'نها\sub{س←أ} د(س) = د(أ)',
      r'نها ( أ \frac{ن}{ب} ن ) عندما ن ← ∞ = ∞':
          r'نها\sub{ن←∞} ( أ \frac{ن}{ب} ن ) = ∞',
      // «عندما» داخل القوس.
      r'المساحة = نها (عندما ن ← ∞) لـ مجـ':
          r'المساحة = نها\sub{ن←∞} لـ مجـ',
      // «عند» كـ«عندما» — و«٠.» كانت تُرى صفرين.
      r'نها \frac{جا س}{س} = ١ عند س ← ٠. منها تتفرّع':
          r'نها\sub{س←٠} \frac{جا س}{س} = ١. منها تتفرّع',
      // 🗣️ الصيغةُ بالكلمات.
      r'أوجد نها ظا س عندما س تؤول إلى ٠.': r'أوجد نها\sub{س←٠} ظا س.',
      r'نها \frac{جا س}{س} = ١ عندما س تؤول إلى ٠':
          r'نها\sub{س←٠} \frac{جا س}{س} = ١',
      r'نها (مجـ ر) عندما ن تسعى لـ ∞': r'نها\sub{ن←∞} (مجـ ر)',
      r'نها س × جا(\frac{٣}{س}) عندما س تؤول إلى ∞':
          r'نها\sub{س←∞} س × جا(\frac{٣}{س})',
      // «ما لا نهاية» كلماتٌ لا قيمة — تبقى كما هي.
      r'نها المجموع عندما ن تسعى إلى ما لا نهاية':
          r'نها المجموع عندما ن تسعى إلى ما لا نهاية',
      // 🔒 «عندما» في جملةٍ تالية لا تخصّ النهاية.
      r'نها س = ص. عندما س ← ∞ فإن ص ← ٠': r'نها س = ص. عندما س ← ∞ فإن ص ← ٠',
    };
    cases.forEach((src, want) {
      test(src, () => expect(stackLimitNotation(src), want));
    });

    test('LaTeX من الموديل', () {
      expect(stackLimitNotation(stripUnsupportedLatex(r'\lim_{x \to 0} x')),
          'نها_{x ← 0} x');
    });

    test('كلماتٌ ليست نهاية لا تُمسّ', () {
      for (final s in ['أخذ منها', 'النهاية', 'نهاية الدرس', 'نهار', 'انتهى']) {
        expect(stackLimitNotation(s), s);
      }
    });
  });

  test('«٠.» لا تُرى صفرين — والعشريُّ يبقى', () {
    expect(soloZeroStop('النهاية عند ٠. القانون'), 'النهاية عند ٠ القانون');
    expect(soloZeroStop('الناتج ٠.٥'), 'الناتج ٠.٥');
    expect(soloZeroStop('= ١٠.'), '= ١٠');
    expect(soloZeroStop('......'), '......');
  });

  testWidgets('يُرسم مكدّساً لا نصّاً', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: MasarMarkdown(data: 'نهـ (س←٠) \\frac{جا س}{س}', subject: 'رياضيات'),
        ),
      ),
    ));
    expect(t.takeException(), isNull);
    expect(find.text('نهـ'), findsNothing);
    final parsed = MathParser.parse(stackLimitNotation('نهـ (س←٠) س'));
    // StackNode يُصنع عند البناء من «نها» + دليل.
    expect(parsed.whereType<ScriptNode>(), isNotEmpty);
    expect(find.text('نها'), findsWidgets);
  });

  test('⭐ مسحُ كل ملفات البيانات: لا نهايةَ تبقى غيرَ مكدّسة', () {
    final dir = Directory('../Backend/data');
    if (!dir.existsSync()) return;
    var found = 0;
    final bad = <String>[];
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.json') || f.path.contains('/_rejected/')) continue;
      final raw = f.readAsStringSync();
      if (!raw.contains('نه')) continue;
      void walk(Object? v) {
        if (v is String) {
          for (final line in v.split('\n')) {
            if (!RegExp(r'نه[ـا]').hasMatch(line)) continue;
            final before = _leftover.allMatches(line).length;
            found += before;
            final out = stackLimitNotation(stripUnsupportedLatex(line));
            final m = _leftover.firstMatch(out);
            if (m != null) {
              bad.add('${f.path.split('/data/').last}: '
                  '${out.substring(m.start, (m.start + 40).clamp(0, out.length))}');
            }
          }
        } else if (v is Map) {
          v.values.forEach(walk);
        } else if (v is List) {
          v.forEach(walk);
        }
      }

      walk(jsonDecode(raw));
    }
    expect(found, greaterThan(100), reason: 'الحمولة مثبّتة');
    expect(bad, isEmpty, reason: bad.join('\n'));
  });
}
