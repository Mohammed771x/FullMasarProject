// 📅 دروسُ «اختبار المراجعة» — **الأكثرُ أخطاءً أولاً، وثلاثةٌ كحدّ أقصى**.
//
// 🔴 **قاعدةُ المالك (٢٠٢٦-٠٩-٢٢) حرفياً:** «لما تدخل اختبار المراجعة يطلع
//    لك أكثر ثلاثة دروس فيها أخطاء من كل مادة **بالترتيب**. أقصى شي ثلاثة
//    دروس… لو اختبرت في عشرة دروس وأكثر ثلاثة فيها أخطاء يطلعها لي عشان
//    نقدر نراجعها.»
//
// 🐞 **وما كان يقع:** الورقةُ تعرض **عددَ الأخطاء** على كل صفّ وترتّب
//    بـ**نسبة الخطأ** — مقياسان في شاشةٍ واحدة. فقُرئت الأرقامُ صاعدةً
//    (٢ ← ٥ ← ٧) وسقط من القائمة درسٌ أخطأ فيه الطالبُ أربعَ عشرةَ مرّة.
//
// 📱 وحالةُ الأحياء أدناه **منقولةٌ رقماً برقم من جهاز المالك** (خمسةُ
//    اختبارات) — فالاختبارُ يعيد إنتاج العطل الذي رآه بعينه لا حالةً مخترعة.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_analytics.dart';

QuizResult _r({
  String subject = "احياء",
  required String unit,
  required Map<String, int> asked,
  required Map<String, int> wrongPerLesson,
  required DateTime at,
}) {
  final total = asked.values.fold(0, (a, b) => a + b);
  final wrongCount = wrongPerLesson.values.fold(0, (a, b) => a + b);
  return QuizResult(
    id: "$subject-${at.microsecondsSinceEpoch}",
    subject: subject,
    grade: 3,
    track: "علمي",
    unit: unit,
    lessons: asked.keys.toList(),
    askedPerLesson: asked,
    score: total - wrongCount,
    total: total,
    wrong: [
      for (final e in wrongPerLesson.entries)
        for (var i = 0; i < e.value; i++)
          WrongAnswer(topic: "مفهوم ${e.key}", lesson: e.key, unit: unit),
    ],
    durationSec: 120,
    createdAt: at,
  );
}

/// 📱 سجلُّ الأحياء كما هو على جهاز المالك — الأعدادُ والنِّسب مطابقة.
List<QuizResult> _biologyHistory() => [
      // ١٤ خطأً من ٢٠ سؤالاً — **أسوأُ درسٍ في المادة على الإطلاق**.
      _r(
        unit: "التنظيم العصبي",
        asked: const {"التنظيم العصبي في وحيدة الخلية": 20},
        wrongPerLesson: const {"التنظيم العصبي في وحيدة الخلية": 14},
        at: DateTime(2026, 9, 10),
      ),
      _r(
        unit: "التكاثر",
        asked: const {"التكاثر الخضري": 10},
        wrongPerLesson: const {"التكاثر الخضري": 7},
        at: DateTime(2026, 9, 12),
      ),
      _r(
        unit: "التنظيم العصبي",
        asked: const {"السيال العصبي": 7},
        wrongPerLesson: const {"السيال العصبي": 5},
        at: DateTime(2026, 9, 14),
      ),
      // ✋ سؤالان فقط — عيّنةٌ صغيرةٌ ترفع النسبة ولا تعني ضعفاً أكبر.
      _r(
        unit: "المستقبلات الحسية",
        asked: const {"المستقبلات الضوئية": 2},
        wrongPerLesson: const {"المستقبلات الضوئية": 2},
        at: DateTime(2026, 9, 16),
      ),
      _r(
        unit: "التنظيم العصبي",
        asked: const {"النسيج العصبي": 5},
        wrongPerLesson: const {"النسيج العصبي": 3},
        at: DateTime(2026, 9, 17),
      ),
    ];

void main() {
  group('📅 ترتيبُ دروس المراجعة', () {
    test('☢️ الحالةُ التي رآها المالك: الأكثرُ أخطاءً يتصدّر ولا يسقط', () {
      final spots = QuizAnalytics.reviewSpots(_biologyHistory(), "احياء");

      expect(spots.map((s) => s.lesson).toList(), [
        "التنظيم العصبي في وحيدة الخلية", // ١٤
        "التكاثر الخضري", //  ٧
        "السيال العصبي", //  ٥
      ]);
      expect(spots.map((s) => s.recentMisses).toList(), [14, 7, 5]);
    });

    test('☢️ وأرقامُ الشارات تنزل ولا تصعد — وهي عينُ ما شكا منه', () {
      final misses =
          QuizAnalytics.reviewSpots(_biologyHistory(), "احياء")
              .map((s) => s.recentMisses)
              .toList();
      for (var i = 1; i < misses.length; i++) {
        expect(misses[i], lessThanOrEqualTo(misses[i - 1]),
            reason: 'الورقةُ تعرض العدد، فيجب أن ترتّب به: $misses');
      }
    });

    test('✋ درسُ السؤالين لا يزيح درسَ العشرين', () {
      final spots = QuizAnalytics.reviewSpots(_biologyHistory(), "احياء");
      expect(spots.map((s) => s.lesson), isNot(contains("المستقبلات الضوئية")));
    });

    test('📏 ثلاثةٌ كحدٍّ أقصى مهما كثرت الدروس', () {
      expect(QuizAnalytics.reviewSpots(_biologyHistory(), "احياء").length, 3);
      expect(QuizAnalytics.reviewLessons(_biologyHistory(), "احياء").length, 3);
    });

    // 🎯 «إذا كان في بس في المادة اختبار واحد يطلعه عادي» — نصُّ المالك.
    test('واختبارٌ واحدٌ في المادة يُخرج ما فيه ولا يُشترط ثلاثة', () {
      final one = [
        _r(
          subject: "كيمياء",
          unit: "الكيمياء الحرارية",
          asked: const {"قانون هس": 5},
          wrongPerLesson: const {"قانون هس": 2},
          at: DateTime(2026, 9, 18),
        ),
      ];
      final spots = QuizAnalytics.reviewSpots(one, "كيمياء");
      expect(spots.length, 1);
      expect(spots.single.lesson, "قانون هس");
      expect(spots.single.recentMisses, 2);
    });

    test('ودرسٌ بلا خطأٍ واحد لا يدخل المراجعة مهما كثرت أسئلته', () {
      final rs = [
        _r(
          subject: "فيزياء",
          unit: "و",
          asked: const {"أتقنته": 20, "أخطأت فيه": 3},
          wrongPerLesson: const {"أخطأت فيه": 1},
          at: DateTime(2026, 9, 18),
        ),
      ];
      final spots = QuizAnalytics.reviewSpots(rs, "فيزياء");
      expect(spots.map((s) => s.lesson), ["أخطأت فيه"]);
    });

    test('ومادةٌ بلا أخطاء تُرجع قائمةً فارغة (الزرُّ يُعطَّل عندها)', () {
      final rs = [
        _r(
          subject: "عربي",
          unit: "و",
          asked: const {"النحو": 5},
          wrongPerLesson: const {},
          at: DateTime(2026, 9, 18),
        ),
      ];
      expect(QuizAnalytics.reviewSpots(rs, "عربي"), isEmpty);
    });

    test('ولا تخلط المواد: مراجعةُ الأحياء لا تحمل درسَ كيمياء', () {
      final rs = [
        ..._biologyHistory(),
        _r(
          subject: "كيمياء",
          unit: "الكيمياء الحرارية",
          asked: const {"قانون هس": 30},
          wrongPerLesson: const {"قانون هس": 29}, // أكثرُ أخطاءٍ في السجلّ كلّه
          at: DateTime(2026, 9, 18),
        ),
      ];
      final spots = QuizAnalytics.reviewSpots(rs, "احياء");
      expect(spots.every((s) => s.subject == "احياء"), isTrue);
      expect(spots.map((s) => s.lesson), isNot(contains("قانون هس")));
    });
  });

  // ══════════════════════════════════════════════════
  // 🔁 والعدُّ **لآخر محاولة** لا لمجموع العمر
  // ══════════════════════════════════════════════════
  //
  // 🔴 **سؤالُ المالك (٢٠٢٦-٠٩-٢٢):** «لو عند الطالب ١٢ خطأً في الدرس،
  //    ودخل مرّةً ثانية وسوّى ١٤ — يدوم الدرسُ نفسُه لأن أخطاءه كثيرة.»
  //    والمجموعُ التراكميّ **لا ينزل أبداً**: فمن تحسّن يتصدّر، ومن أتقن
  //    يبقى، ويرى الطالبُ رقماً لم يقع في جلسةٍ واحدة قطّ.
  group('🔁 المراجعةُ تقيس حالتَك الآن', () {
    List<QuizResult> improved() => [
          _r(
            unit: "و",
            asked: const {"درس أ": 20},
            wrongPerLesson: const {"درس أ": 12},
            at: DateTime(2026, 9, 1),
          ),
          _r(
            unit: "و",
            asked: const {"درس ب": 10},
            wrongPerLesson: const {"درس ب": 5},
            at: DateTime(2026, 9, 2),
          ),
          // ✅ عاد فتحسّن تحسّناً كبيراً: خطآن من عشرين.
          _r(
            unit: "و",
            asked: const {"درس أ": 20},
            wrongPerLesson: const {"درس أ": 2},
            at: DateTime(2026, 9, 10),
          ),
        ];

    test('☢️ من تحسّن ينزل ولا يتصدّر بمجموعه القديم', () {
      final spots = QuizAnalytics.reviewSpots(improved(), "احياء");
      expect(spots.first.lesson, "درس ب",
          reason: 'درس أ مجموعُه ١٤ لكنّ حالتَه الآن خطآن');
      expect(spots.first.recentMisses, 5);
      expect(spots.last.recentMisses, 2);
      // والسجلُّ التراكميّ باقٍ كما هو لمن يريده.
      expect(spots.last.misses, 14);
    });

    test('☢️ ومن أتقن الدرس يخرج من المراجعة تماماً', () {
      final rs = [
        _r(
          unit: "و",
          asked: const {"درس أ": 20},
          wrongPerLesson: const {"درس أ": 12},
          at: DateTime(2026, 9, 1),
        ),
        _r(
          unit: "و",
          asked: const {"درس ب": 10},
          wrongPerLesson: const {"درس ب": 3},
          at: DateTime(2026, 9, 2),
        ),
        // 🎯 أعاد الاختبار فأصاب كلَّ أسئلة الدرس.
        _r(
          unit: "و",
          asked: const {"درس أ": 20},
          wrongPerLesson: const {},
          at: DateTime(2026, 9, 10),
        ),
      ];
      final spots = QuizAnalytics.reviewSpots(rs, "احياء");
      expect(spots.map((s) => s.lesson), ["درس ب"]);
    });

    test('☢️ ومن تدهور يظهر برقمه الحقيقيّ (١٤) لا بمجموعه (٢٦)', () {
      final rs = [
        _r(
          unit: "و",
          asked: const {"درس أ": 20},
          wrongPerLesson: const {"درس أ": 12},
          at: DateTime(2026, 9, 1),
        ),
        _r(
          unit: "و",
          asked: const {"درس أ": 20},
          wrongPerLesson: const {"درس أ": 14},
          at: DateTime(2026, 9, 10),
        ),
      ];
      final s = QuizAnalytics.reviewSpots(rs, "احياء").single;
      expect(s.recentMisses, 14, reason: 'وهو ما يُعرض على الشارة');
      expect(s.misses, 26, reason: 'والمجموعُ باقٍ في السجلّ لا على الشارة');
    });
  });

  // ══════════════════════════════════════════════════
  // ⚖️ وشاشاتُ التحليل لم تُمَسّ
  // ══════════════════════════════════════════════════
  // شاراتُها **نسبةٌ مئوية** لا عدداً، فترتيبُها بالنسبة متّسقٌ مع ما تعرضه.
  // وهذا الاختبارُ يمنع «توحيدَ» المقياسين سهواً في الاتجاه الخاطئ.
  test('⚖️ ترتيبُ نقاط الضعف العام ما زال بنسبة الخطأ', () {
    final spots = QuizAnalytics.weakSpots(_biologyHistory(), limit: 99);
    for (var i = 1; i < spots.length; i++) {
      expect(spots[i].errorRate, lessThanOrEqualTo(spots[i - 1].errorRate),
          reason: 'الشارةُ هناك نسبةٌ مئوية، فالترتيبُ بها');
    }
    // وعيّنةُ السؤالين تتصدّرها بالنسبة — وهو ما لا يصحّ في ورقة المراجعة.
    expect(spots.first.lesson, "المستقبلات الضوئية");
  });
}
