// 📚 دليلُ الاستخدام — **لكل مادةٍ في كل صفٍّ ومسار**، بلا «قيد الإعداد».
//
// 🔴 **طلبُ المالك (٢٠٢٦-٠٩-٢٢):** «ادخل في دليل استخدام تطبيق مسار على كل
//    درس في كل الأماكن… في كل مكان، الصف الأول… ولا تخليه يقول قيد الإعداد».
//
// 🐞 وكان الدليلُ مكتوباً لستّ موادّ من أربعَ عشرة، ونصُّه مكتوبٌ لصفٍّ واحد:
//    يسمّي وحدات الثالث وأرقامَ صفحاته ويشرح **وضع الوزاري** لطالب الأول
//    الذي لا وزاريَّ في صفّه أصلاً.
//
// ⚖️ وهذا الملفّ **يمشي على المنهج كلِّه** لا على عيّنة: كلُّ مادةٍ في كل
//    صفٍّ وكل مسار — ٣٦ تركيبةً — ويسأل عن كل واحدةٍ الأسئلةَ نفسَها.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/config/curriculum.dart';
import 'package:ye_student_tutor/features/instructions/data/app_instructions.dart';
import 'package:ye_student_tutor/features/teacher/data/teacher_tool.dart';

/// كلُّ (مادة · صف · مسار) في المنهج — لا قائمةٌ مكتوبةٌ باليد.
Iterable<(String, int, Track)> _everySubject() sync* {
  for (var g = Curriculum.minGrade; g <= Curriculum.maxGrade; g++) {
    for (final t in Curriculum.tracksFor(g)) {
      for (final s in Curriculum.subjectsFor(g, t)) {
        yield (s, g, t);
      }
    }
  }
}

void main() {
  group('📚 تغطيةُ المواد', () {
    test('☢️ لا مادةَ في المنهج بلا دليل — ولا واحدة', () {
      final missing = [
        for (final (s, g, t) in _everySubject())
          if (!AppInstructions.has(s)) "$s (${Curriculum.gradeShort(g)} ${t.label})",
      ];
      expect(missing, isEmpty, reason: 'بلا دليل: $missing');
    });

    test('☢️ ولا نصَّ فيه «قيد الإعداد» ولا «قيد الإضافة»', () {
      for (final (s, g, t) in _everySubject()) {
        final text = AppInstructions.forSubject(s, grade: g, track: t)["text"]!;
        expect(text, isNot(contains("قيد الإعداد")), reason: "$s / $g");
        expect(text, isNot(contains("قيد الإضافة")), reason: "$s / $g");
      }
    });

    test('وكلُّ دليلٍ نصٌّ حقيقيّ لا قالبٌ فارغ', () {
      for (final (s, g, t) in _everySubject()) {
        final text = AppInstructions.forSubject(s, grade: g, track: t)["text"]!;
        expect(text.length, greaterThan(400), reason: "$s / $g قصيرٌ جداً");
        expect(text, contains("كيفية الاستخدام"), reason: "$s / $g");
        expect(text, contains("وضع الاختبارات"), reason: "$s / $g");
      }
    });

    test('ويُصدَّر باسم المادة وصفِّها — فيعرف الطالبُ أنه دليلُه هو', () {
      final text = AppInstructions.forSubject("عربي", grade: 2, track: Track.literary)["text"]!;
      expect(text, contains("اللغة العربية"));
      expect(text, contains("الثاني الثانوي"));
      expect(text, contains("أدبي"));

      // والأولُ الثانويُّ موحّدٌ بلا مسار، فلا يُلصق به «علمي».
      final g1 = AppInstructions.forSubject("مجتمع", grade: 1, track: Track.none)["text"]!;
      expect(g1, contains("الأول الثانوي"));
      expect(g1, isNot(contains("علمي")));
    });
  });

  // ══════════════════════════════════════════════════
  // 🎓 والأوضاعُ المشروحةُ هي المرسومةُ على شاشته
  // ══════════════════════════════════════════════════
  group('🎓 الدليلُ يتبع صفَّ الطالب', () {
    test('☢️ لا يُشرح «وضع الوزاري» لغير الثالث', () {
      for (final (s, g, t) in _everySubject()) {
        final text = AppInstructions.forSubject(s, grade: g, track: t)["text"]!;
        final hasSection = text.contains("وضع الوزاري");
        expect(hasSection, g == 3,
            reason: '$s (${Curriculum.gradeShort(g)}): الوزاريُّ للثالث وحده');
      }
    });

    test('وكلُّ وضعٍ مرسومٍ على الشاشة له فقرةٌ في الدليل', () {
      for (final (s, g, t) in _everySubject()) {
        if (s == "رياضيات") continue; // لها تدفّقُها الخاص (فرع ← درس ← وضع)
        final text = AppInstructions.forSubject(s, grade: g, track: t)["text"]!;
        for (final mode in Curriculum.modesFor(s, grade: g)) {
          // عناوينُ الفقرات معرّفةٌ بالألف واللام: «وضع الشرح» لا «وضع شرح».
          expect(text, contains("وضع ال$mode"),
              reason: 'سقط «وضع ال$mode» من دليل $s (صف $g)');
        }
      }
    });

    test('والرياضياتُ بلا تلخيصٍ في الدليل كما هي بلا تلخيصٍ في الشاشة', () {
      for (var g = 1; g <= 3; g++) {
        final text = AppInstructions.forSubject("رياضيات", grade: g, track: Track.scientific)["text"]!;
        expect(text, isNot(contains("وضع التلخيص")), reason: "صف $g");
        expect(text, contains("الفرع"), reason: "صف $g");
        expect(text.contains("وضع الوزاري"), g == 3, reason: "صف $g");
      }
    });

    // 📌 حقيقةُ محتوىً تخصّ صفّاً بعينه لا تُعمَّم على غيره.
    test('وملاحظةُ «تاريخ الأرض» للثالث وحده', () {
      final g3 = AppInstructions.forSubject("احياء", grade: 3, track: Track.scientific)["text"]!;
      final g1 = AppInstructions.forSubject("احياء", grade: 1, track: Track.none)["text"]!;
      expect(g3, contains("تاريخ الأرض"));
      expect(g3, contains("١٦٢"));
      expect(g1, isNot(contains("تاريخ الأرض")),
          reason: 'صفحاتُ ملخّصِ الثالث ليست من منهج الأول');
    });
  });

  // ══════════════════════════════════════════════════
  // 🗣️ ولكل مادةٍ لغتُها لا نصٌّ واحدٌ منسوخ
  // ══════════════════════════════════════════════════
  test('🗣️ الأمثلةُ من منهج المادة نفسِها', () {
    String of(String s, int g, Track t) =>
        AppInstructions.forSubject(s, grade: g, track: t)["text"]!;

    expect(of("انجليزي", 3, Track.scientific), contains("Passive"));
    expect(of("انجليزي", 3, Track.scientific), contains("بالعربية"));
    expect(of("عربي", 3, Track.literary), contains("النحو والصرف"));
    expect(of("منطق", 3, Track.literary), contains("قياس"));
    expect(of("فلسفة", 3, Track.literary), contains("ديكارت"));
    expect(of("مبادئ علم الخرائط", 3, Track.literary), contains("مقياس الرسم"));
    expect(of("تاريخ", 2, Track.literary), contains("زمنياً"));
    expect(of("جغرافيا", 2, Track.literary), contains("الخريطة"));
    expect(of("علم الاقتصاد", 2, Track.literary), contains("الطلب"));
    expect(of("علم الاجتماع", 2, Track.literary), contains("التنشئة"));
    expect(of("مجتمع", 1, Track.none), contains("المجتمع المدني"));
    expect(of("كيمياء", 1, Track.none), contains("معادلة"));
    expect(of("فيزياء", 1, Track.none), contains("القانون"));

    // ولا يتسرّب مثالُ مادةٍ إلى أخرى.
    expect(of("تاريخ", 3, Track.literary), isNot(contains("Passive")));
  });

  // ══════════════════════════════════════════════════
  // 👨‍🏫 وأدواتُ المعلم الأربع
  // ══════════════════════════════════════════════════
  group('👨‍🏫 دليلُ المعلم', () {
    test('☢️ لكل أداةٍ نصُّها — والأداةُ بلا نصٍّ عطبٌ لا حالةُ محتوى', () {
      for (final tool in TeacherTool.values) {
        final data = AppInstructions.teacher[tool.id];
        expect(data, isNotNull, reason: 'أداةُ ${tool.id} بلا دليل');
        expect(data!["text"]!.length, greaterThan(300), reason: tool.id);
      }
    });

    test('وأسماءُ الأزرار في الدليل هي أسماؤها على الشاشة', () {
      for (final tool in TeacherTool.values) {
        final text = AppInstructions.teacher[tool.id]!["text"]!;
        expect(text, contains(tool.cardTitle),
            reason: 'عنوانُ ${tool.id} في الدليل يخالف بطاقتَه');
        if (tool.generateLabel.isNotEmpty) {
          expect(text, contains(tool.generateLabel),
              reason: 'زرُّ ${tool.id} في الدليل يخالف زرَّه');
        }
      }
    });

    test('ولا يُحيل المعلّمَ على أوضاع الطالب', () {
      for (final tool in TeacherTool.values) {
        final text = AppInstructions.teacher[tool.id]!["text"]!;
        for (final studentMode in ["وضع الشرح", "وضع التلخيص", "وضع الوزاري"]) {
          expect(text, isNot(contains(studentMode)), reason: tool.id);
        }
      }
    });
  });
}
