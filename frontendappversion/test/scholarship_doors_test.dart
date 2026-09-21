// ══════════════════════════════════════════════════
// 🧭 أبوابُ المنحة — الزرُّ يَعِد، والخادمُ يفي
// ══════════════════════════════════════════════════
//
// 🔴 **علّةُ المالك (2026-09-20):** «تسع نيّات تُجاب من البطاقة، حلو —
//    **وين هالنيّات؟ مش موجودة**. بغيت المواعيد، مش موجود وين مواعيد
//    المنحة… خلّها من ضمن الاقتراحات، لو ضغطها يطلع له الوثائق.»
//
// ⚖️ والخطرُ الحقيقيّ هنا **انفصالُ اللغتين**: نصُّ الزرّ في دارت ونيّتُه
//    في بايثون. حرفٌ يختلف ⇒ الضغطةُ تمضي إلى الموديل، فتتأخّر وتُخصم من
//    الحصة — **والطالبُ لا يفرّق، فلا يشتكي أحد**. ولذلك يُقرأ الملفّان.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/scholarships/data/models/scholarship.dart';

/// منحةٌ تملك كلَّ حقلٍ — فتفتح كلَّ باب.
Scholarship _full({List<String>? fields, List<String>? documents}) => Scholarship(
      id: "turkey",
      name: "المنحة التركية",
      country: "تركيا",
      shortDesc: "تمويل كامل",
      about: "منحة حكومية.",
      fundingType: "full",
      requirements: const ["المعدل 70%"],
      howToApply: const ["سجّل في الموقع"],
      benefits: const ["راتب شهري"],
      documents: documents ?? const ["جواز سفر"],
      fields: fields ?? const ["الهندسة"],
      degreeLevels: const ["بكالوريوس"],
      closeDate: DateTime(2026, 12, 20),
    );

void main() {
  test('🚪 منحةٌ كاملةُ البيانات تفتح النيّات التسع', () {
    final labels = _full().doors.map((d) => d.label).toList();
    for (final expected in [
      "الشروط", "الوثائق المطلوبة", "المواعيد", "المزايا",
      "خطوات التقديم", "التخصصات", "المراحل", "التمويل", "نبذة عن المنحة",
    ]) {
      expect(labels, contains(expected), reason: 'نيّةٌ بلا باب: $expected');
    }
  });

  test('🕳️ وبابٌ بلا بياناتٍ لا يُعرض', () {
    final labels =
        _full(fields: const [], documents: const []).doors.map((d) => d.label);
    expect(labels, isNot(contains("التخصصات")));
    expect(labels, isNot(contains("الوثائق المطلوبة")));
    expect(labels, contains("الشروط"));
  });

  test('📡 وما يرسله الخادمُ يعلو على الحساب المحلّي', () {
    // ⚖️ الخادمُ وحده يعرف أيَّ سؤالٍ يجيبه من البطاقة — فإن أرسل قائمةً
    //    فهي الحقيقة، والمحلّيةُ احتياطٌ لكاشٍ قديم لا بديلٌ منافس.
    final s = Scholarship.fromJson({
      "id": "x", "name": "منحة", "requirements": ["شرط"],
      "suggestions": [
        {"label": "بابٌ من الخادم", "question": "سؤالٌ من الخادم"}
      ],
    });
    expect(s.doors.length, 1);
    expect(s.doors.single.label, "بابٌ من الخادم");
  });

  test('💾 والكاشُ يحفظها فلا تختفي الأزرارُ بلا شبكة', () {
    final s = _full();
    final back = Scholarship.fromJson(
        Scholarship.fromJson({...s.toJson(), "suggestions": [
          {"label": "الشروط", "question": "ما شروط التقديم؟"}
        ]}).toJson());
    expect(back.suggestions.single.question, "ما شروط التقديم؟");
  });

  // ══════════════════════════════════════════════════
  // ☢️ الحارسُ عبر اللغتين
  // ══════════════════════════════════════════════════

  test('🔒 نصوصُ الاحتياط المحلّي مطابقةٌ حرفاً لما في الخادم', () {
    final src = File("../Backend/core/scholarship_facts.py")
        .readAsStringSync();
    final block = RegExp(r'_SUGGESTIONS = \(([\s\S]*?)\n\)')
        .firstMatch(src);
    expect(block, isNotNull, reason: '☢️ لم يعد `_SUGGESTIONS` موجوداً');

    // (النيّة، نصُّ الزرّ، السؤال، البديل)
    final row = RegExp('"([^"]*)",\\s*"([^"]*)",\\s*"([^"]*)"');
    final serverPairs = <String, String>{};
    for (final m in row.allMatches(block!.group(1)!)) {
      serverPairs[m.group(2)!] = m.group(3)!;
    }
    expect(serverPairs.length, greaterThanOrEqualTo(9));

    for (final door in _full().doors) {
      expect(serverPairs.containsKey(door.label), isTrue,
          reason: '☢️ بابٌ لا يعرفه الخادم: ${door.label}');
      expect(door.question, serverPairs[door.label],
          reason: '☢️ نصُّ «${door.label}» اختلف بين التطبيق والخادم — '
              'الضغطةُ ستمضي إلى الموديل وتُخصم من الحصة');
    }
  });
}
