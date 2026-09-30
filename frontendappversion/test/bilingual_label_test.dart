import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/utils/bilingual_label.dart';

final _arabic = RegExp(r'[؀-ۿ]');
String _plain(String s) => s.replaceAll(RegExp('[\u2066\u2069]'), '');

void main() {
  test('اسمٌ بلغتين ⇒ سطرٌ إنجليزيٌّ خالص ثم سطرٌ عربي', () {
    final l = bilingualLabel(
      'Expressions of time with prepositions at, in and on | حروف الجر الزمنية at و in و on',
    );
    final lines = l.split('\n');
    expect(lines, hasLength(2));
    expect(_arabic.hasMatch(lines[0]), isFalse);
    expect(
      _plain(lines[0]),
      'Expressions of time with prepositions at, in and on',
    );
    expect(_plain(lines[1]), 'حروف الجر الزمنية at و in و on');
  });

  test('«?» تبقى داخل عزلِ كلمتها', () {
    final l = bilingualLabel(
      'Making recommendations | تقديم النصائح والاقتراحات (should / Why not ...?)',
    );
    expect(l.split('\n')[1], contains('\u2066should / Why not ...?\u2069'));
  });

  test('العربيُّ أولاً في الكتاب ⇒ الإنجليزيُّ أولاً في العرض', () {
    final l = bilingualLabel('Parts of Speech|أقسام الكلام');
    final r = bilingualLabel(
      'كون سؤال من الكلمات التي تحتها خط |Make questions of the underlined word',
    );
    expect(_plain(l.split('\n')[0]), 'Parts of Speech');
    expect(_plain(r.split('\n')[0]), 'Make questions of the underlined word');
  });

  test('« - » بعد شقٍّ لاتينيٍّ خالص يفصل أيضاً', () {
    final l = bilingualLabel(
      'Review of tenses - فعل الكينونة (am / is / are - was / were) والمضارع المستمر والماضي المستمر',
    );
    expect(_plain(l.split('\n')[0]), 'Review of tenses');
  });

  test('«at و in و on» كتلةٌ واحدة تُقرأ من اليسار', () {
    final l = bilingualLabel(
      'Expressions of time with prepositions at, in and on | حروف الجر الزمنية at و in و on',
    );
    expect(l.split('\n')[1], endsWith('\u2066at و in و on\u2069'));
  });

  test('اسمٌ بلغةٍ واحدة لا يتغيّر', () {
    expect(bilingualLabel('التشبيه وأقسامه'), 'التشبيه وأقسامه');
    expect(_plain(bilingualLabel('Language review 1')), 'Language review 1');
  });

  test(
    'كلُّ درس إنجليزي في الكتب: لا حرفَ يضيع، ولا عربيَّ في السطر الإنجليزي',
    () {
      final files = Directory('../Backend/data/subjects/انجليزي')
          .listSync(recursive: true)
          .whereType<File>()
          .where(
            (f) =>
                f.path.contains('lessons_mode') &&
                f.path.endsWith('.json') &&
                !f.path.contains('_TEMPLATE'),
          );
      var n = 0;
      for (final f in files) {
        final d = jsonDecode(f.readAsStringSync()) as Map;
        for (final u in d['الوحدات'] as List) {
          for (final les in u['الدروس'] as List) {
            final name = les['اسم_الدرس'] as String;
            final lines = bilingualLabel(name).split('\n');
            n++;
            String strip(String s) =>
                _plain(s).replaceAll(RegExp(r'[\s|\-]'), '');
            final got = lines.map(strip).toList()..sort();
            expect(strip(name).length, got.join().length, reason: name);
            if (lines.length == 2) {
              expect(_arabic.hasMatch(lines[0]), isFalse, reason: name);
              expect(_arabic.hasMatch(lines[1]), isTrue, reason: name);
            }
          }
        }
      }
      expect(n, greaterThan(60));
    },
  );
}
