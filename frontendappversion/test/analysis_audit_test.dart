// 🔬 فحصٌ كاملٌ لقسم «تحليل مستواي» — بطلب المالك (٢٠٢٦-٠٩-٢٢):
//    «تأكد من قسم تحليل مستواي كامل إذا هو مضبوط من كل النواحي… لو حصل
//     كذا لو حصل كذا».
//
// كلُّ ما يعرضه القسم رقمٌ يُشتقّ من `QuizAnalytics`، والأرقامُ تُقرأ على
// أنها حقائق. فهذا الملفّ يمشي على **الحالات القاسية** لا على الحالة
// السعيدة: سجلٌّ فارغ · اختبارٌ من سؤالٍ واحد · نتائجُ ما قبل الحقول
// الجديدة · درسٌ بلا اسم · درسٌ في وحدتين · قسمةٌ على صفر.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_analytics.dart';
import 'package:ye_student_tutor/features/future_masar/presentation/widgets/analysis_ui.dart';

QuizResult _q({
  String subject = "احياء",
  String unit = "و",
  Map<String, int> asked = const {},
  Map<String, int> wrong = const {},
  int? score,
  int? total,
  List<String>? lessons,
  List<WrongAnswer>? rawWrong,
  required DateTime at,
}) {
  final int t = total ?? asked.values.fold<int>(0, (a, b) => a + b);
  final int w = wrong.values.fold<int>(0, (a, b) => a + b);
  return QuizResult(
    id: "$subject|$unit|${at.microsecondsSinceEpoch}",
    subject: subject,
    grade: 3,
    track: "علمي",
    unit: unit,
    lessons: lessons ?? asked.keys.toList(),
    askedPerLesson: asked,
    score: score ?? (t - w),
    total: t,
    wrong: rawWrong ??
        [
          for (final e in wrong.entries)
            for (var i = 0; i < e.value; i++)
              WrongAnswer(topic: "مفهوم-${e.key}", lesson: e.key, unit: unit),
        ],
    durationSec: 90,
    createdAt: at,
  );
}

void main() {
  // ══════════════════════════════════════════════════
  // ⓪ سجلٌّ فارغ — لا قسمةَ على صفر ولا انهيار
  // ══════════════════════════════════════════════════
  group('⓪ لا نتائج بعد', () {
    const none = <QuizResult>[];
    test('كلُّ رقمٍ يعود صفراً بلا استثناء', () {
      expect(QuizAnalytics.totalQuizzes(none), 0);
      expect(QuizAnalytics.totalQuestions(none), 0);
      expect(QuizAnalytics.totalCorrect(none), 0);
      expect(QuizAnalytics.overallPercent(none), 0);
      expect(QuizAnalytics.streakDays(none), 0);
      expect(QuizAnalytics.recentPercents(none), isEmpty);
      expect(QuizAnalytics.bySubject(none), isEmpty);
      expect(QuizAnalytics.weakSpots(none), isEmpty);
      expect(QuizAnalytics.bestSubject(none), isNull);
      expect(QuizAnalytics.weakestSubject(none), isNull);
      expect(QuizAnalytics.reviewSpots(none, "احياء"), isEmpty);
    });

    test('واختبارٌ بصفر أسئلة لا يقسم على صفر', () {
      final rs = [_q(total: 0, score: 0, at: DateTime(2026, 9, 1))];
      expect(QuizAnalytics.overallPercent(rs), 0);
      expect(rs.single.percent, 0);
      expect(QuizAnalytics.bySubject(rs).single.currentPercent, 0);
    });
  });

  // ══════════════════════════════════════════════════
  // ① المعدّل العام: من الأسئلة لا من متوسط النِّسب
  // ══════════════════════════════════════════════════
  test('① اختبارٌ من ٥ لا يساوي اختباراً من ١٥ في المعدّل', () {
    final rs = [
      _q(asked: const {"د": 5}, wrong: const {"د": 0}, at: DateTime(2026, 9, 1)),
      _q(asked: const {"د": 15}, wrong: const {"د": 15}, at: DateTime(2026, 9, 2)),
    ];
    // ٥ صحيحة من ٢٠ = ٢٥٪ — لا متوسّطَ (100+0)/2 = 50٪.
    expect(QuizAnalytics.overallPercent(rs), 25);
  });

  // ══════════════════════════════════════════════════
  // ② اتجاهُ التحسّن — **لا يُعلَن على عيّنةٍ تافهة**
  // ══════════════════════════════════════════════════
  //
  // 🔴 رُصد في الفحص: اختبارٌ من **سؤالٍ واحد** أخطأه، ثم اختبارٌ من خمسة
  //    عشر أصابها كلَّها ⇒ «📈 تحسّنت **١٠٠** نقطة». جملةٌ قاطعةٌ مبنيّة
  //    على سؤالٍ واحد — والعكسُ أقسى: «📉 نزلت ٤٠ نقطة».
  group('② اتجاهُ التحسّن', () {
    test('☢️ سؤالٌ واحدٌ لا يصنع اتجاهاً', () {
      final rs = [
        _q(asked: const {"د": 1}, wrong: const {"د": 1}, at: DateTime(2026, 9, 1)),
        _q(asked: const {"د": 15}, wrong: const {}, at: DateTime(2026, 9, 2)),
      ];
      expect(QuizAnalytics.bySubject(rs).single.trend, 0,
          reason: 'لا سطرَ اتجاهٍ أصلاً — والصمتُ خيرٌ من رقمٍ كاذب');
    });

    test('وعيّنةٌ كافيةٌ تُعلن الاتجاه صحيحاً', () {
      final rs = [
        _q(asked: const {"د": 10}, wrong: const {"د": 6}, at: DateTime(2026, 9, 1)),
        _q(asked: const {"د": 10}, wrong: const {"د": 2}, at: DateTime(2026, 9, 2)),
      ];
      // ٤٠٪ ← ٨٠٪
      expect(QuizAnalytics.bySubject(rs).single.trend, 40);
    });

    test('واختبارٌ واحدٌ لا اتجاهَ له', () {
      final rs = [
        _q(asked: const {"د": 10}, wrong: const {"د": 5}, at: DateTime(2026, 9, 1)),
      ];
      expect(QuizAnalytics.bySubject(rs).single.trend, 0);
    });
  });

  // ══════════════════════════════════════════════════
  // ③ تصنيفُ المادة — آخرُ خمسةٍ مرجّحةً بالأحدث
  // ══════════════════════════════════════════════════
  group('③ التصنيف', () {
    test('من تحسّن أخيراً يرتفع تصنيفُه ولا يبقى أسيرَ سجلّه', () {
      final rs = [
        for (var d = 1; d <= 6; d++)
          _q(
            asked: {"د": 10},
            wrong: {"د": d <= 4 ? 8 : 1}, // أربعةٌ سيّئة ثم اثنان ممتازان
            at: DateTime(2026, 9, d),
          ),
      ];
      final st = QuizAnalytics.bySubject(rs).single;
      expect(st.currentPercent, greaterThan(st.percent),
          reason: 'المرجّحُ بالأحدث يسبق متوسّطَ العمر');
      expect(st.quizzes, 6);
      expect(st.currentQuizzes, QuizAnalytics.levelWindow);
    });

    test('وحدودُ المسمّيات على حوافّها بالضبط', () {
      String labelAt(int correct, int total) => QuizAnalytics.bySubject([
            _q(
              asked: {"د": total},
              wrong: {"د": total - correct},
              at: DateTime(2026, 9, 1),
            )
          ]).single.label;
      expect(labelAt(90, 100), "ممتاز");
      expect(labelAt(89, 100), "جيد جداً");
      expect(labelAt(80, 100), "جيد جداً");
      expect(labelAt(79, 100), "جيد");
      expect(labelAt(65, 100), "جيد");
      expect(labelAt(64, 100), "مقبول");
      expect(labelAt(50, 100), "مقبول");
      expect(labelAt(49, 100), "يحتاج تركيزاً");
    });
  });

  // ══════════════════════════════════════════════════
  // ④ السلسلة اليومية
  // ══════════════════════════════════════════════════
  group('④ أيامُ المواظبة', () {
    List<QuizResult> onDays(List<int> days) => [
          for (final d in days)
            _q(asked: const {"د": 5}, at: DateTime(2026, 9, d, 22, 30)),
        ];

    test('أيامٌ متّصلةٌ تُعدّ، والفجوةُ تقطع', () {
      expect(
          QuizAnalytics.streakDays(onDays([1, 2, 4, 5, 6]),
              now: DateTime(2026, 9, 6, 8)),
          3);
    });

    test('واختبارُ أمسِ يُبقي السلسلة (اليومُ لم ينتهِ)', () {
      expect(
          QuizAnalytics.streakDays(onDays([5, 6]), now: DateTime(2026, 9, 7, 9)),
          2);
    });

    test('ويومان بلا اختبارٍ يقطعانها', () {
      expect(
          QuizAnalytics.streakDays(onDays([5, 6]), now: DateTime(2026, 9, 8, 9)),
          0);
    });

    test('واختباران في يومٍ واحدٍ يومٌ واحد', () {
      final rs = [
        _q(asked: const {"د": 5}, at: DateTime(2026, 9, 6, 8)),
        _q(asked: const {"د": 5}, at: DateTime(2026, 9, 6, 20)),
      ];
      expect(QuizAnalytics.streakDays(rs, now: DateTime(2026, 9, 6, 23)), 1);
    });
  });

  // ══════════════════════════════════════════════════
  // ⑤ نتائجُ ما قبل الحقول الجديدة
  // ══════════════════════════════════════════════════
  //
  // ⚠️ `askedPerLesson` أُضيف لاحقاً. والنتائجُ الأقدم تُقدَّر بقسمة أسئلة
  //    الاختبار على دروسه — تقديرٌ **معلَن**، والمهمّ ألّا يفسد الترتيب.
  group('⑤ نتائجُ قديمة', () {
    test('تُقدَّر ولا تُسقط ولا تُفسد النسبة', () {
      final old = _q(
        lessons: const ["درس أ", "درس ب"],
        total: 10,
        score: 6,
        rawWrong: const [
          WrongAnswer(topic: "م", lesson: "درس أ", unit: "و"),
          WrongAnswer(topic: "م", lesson: "درس أ", unit: "و"),
          WrongAnswer(topic: "م", lesson: "درس أ", unit: "و"),
          WrongAnswer(topic: "م", lesson: "درس ب", unit: "و"),
        ],
        at: DateTime(2026, 8, 1),
      );
      final spots = QuizAnalytics.weakSpots([old]);
      final a = spots.firstWhere((s) => s.lesson == "درس أ");
      expect(a.misses, 3);
      expect(a.asked, 5, reason: '١٠ سؤالاً على درسين');
      expect(spots.first.lesson, "درس أ", reason: 'الأسوأُ يتصدّر');
    });

    test('وقديمةٌ مع جديدةٍ في الدرس نفسِه لا تُربك الحساب', () {
      final rs = [
        _q(
          lessons: const ["درس أ"],
          total: 10,
          score: 4,
          rawWrong: [
            for (var i = 0; i < 6; i++)
              const WrongAnswer(topic: "م", lesson: "درس أ", unit: "و"),
          ],
          at: DateTime(2026, 8, 1),
        ),
        _q(asked: const {"درس أ": 10}, wrong: const {"درس أ": 1}, at: DateTime(2026, 9, 1)),
      ];
      final s = QuizAnalytics.weakSpots(rs).single;
      expect(s.misses, 7);
      expect(s.recentMisses, 1, reason: 'المراجعةُ تقيس آخرَ محاولة');
      expect(s.errorRate, inInclusiveRange(1, 99));
    });
  });

  // ══════════════════════════════════════════════════
  // ⑥ أسماءٌ ناقصة
  // ══════════════════════════════════════════════════
  //
  // 🔴 خطأٌ يصل **بلا اسم درس** يُنسب إلى وحدته كي لا يضيع من الإحصاء.
  //    لكنّ اسمَ الوحدة **ليس درساً في المنهج**: شاشةُ إعداد الاختبار لا
  //    تجده فتُسقطه بصمت — فتَعِد ورقةُ المراجعة بثلاثة وتبدأ باثنين.
  group('⑥ خطأٌ بلا اسم درس', () {
    final rs = [
      _q(
        unit: "الوحدة الأولى",
        lessons: const [],
        total: 10,
        score: 8,
        rawWrong: const [
          WrongAnswer(topic: "م", lesson: "", unit: ""),
          WrongAnswer(topic: "م", lesson: "", unit: ""),
        ],
        at: DateTime(2026, 9, 1),
      ),
      _q(asked: const {"درس حقيقي": 5}, wrong: const {"درس حقيقي": 1}, at: DateTime(2026, 9, 2)),
    ];

    test('يبقى في التحليل — فالخطأُ وقع فعلاً', () {
      final names = QuizAnalytics.weakSpots(rs).map((s) => s.lesson);
      expect(names, contains("الوحدة الأولى"));
    });

    test('☢️ ويخرج من المراجعة — لأنه لا يصلح درساً لاختبار', () {
      final review = QuizAnalytics.reviewSpots(rs, "احياء");
      expect(review.map((s) => s.lesson), ["درس حقيقي"]);
      expect(review.every((s) => !s.fromUnitFallback), isTrue);
    });
  });

  // ══════════════════════════════════════════════════
  // ⑦ الدرسُ نفسُه في وحدتين
  // ══════════════════════════════════════════════════
  test('⑦ صفٌّ واحد، ووحدتُه من آخر اختبار', () {
    final rs = [
      _q(unit: "وحدة أ", asked: const {"مشترك": 5}, wrong: const {"مشترك": 3}, at: DateTime(2026, 9, 1)),
      _q(unit: "وحدة ب", asked: const {"مشترك": 5}, wrong: const {"مشترك": 2}, at: DateTime(2026, 9, 2)),
    ];
    final spots = QuizAnalytics.weakSpots(rs);
    expect(spots.length, 1, reason: 'درسٌ واحدٌ لا صفّان');
    expect(spots.single.misses, 5);
    expect(spots.single.unit, "وحدة ب", reason: 'أحدثُ وحدةٍ رآه فيها');
  });

  // ══════════════════════════════════════════════════
  // ⑧ المفاهيم داخل الدرس
  // ══════════════════════════════════════════════════
  test('⑧ مجموعُ أخطاء المفاهيم = أخطاءُ الدرس، والأكثرُ أولاً', () {
    final rs = [
      QuizResult(
        id: "t", subject: "احياء", grade: 3, track: "علمي", unit: "و",
        lessons: const ["د"], askedPerLesson: const {"د": 10},
        score: 4, total: 10,
        wrong: const [
          WrongAnswer(topic: "مفهوم ب", lesson: "د", unit: "و"),
          WrongAnswer(topic: "مفهوم أ", lesson: "د", unit: "و"),
          WrongAnswer(topic: "مفهوم أ", lesson: "د", unit: "و"),
          WrongAnswer(topic: "مفهوم أ", lesson: "د", unit: "و"),
          WrongAnswer(topic: "مفهوم ب", lesson: "د", unit: "و"),
          WrongAnswer(topic: "مفهوم ج", lesson: "د", unit: "و"),
        ],
        durationSec: 90, createdAt: DateTime(2026, 9, 1),
      ),
    ];
    final s = QuizAnalytics.weakSpots(rs).single;
    expect(s.topics.fold<int>(0, (n, t) => n + t.misses), s.misses);
    expect(s.topics.first.topic, "مفهوم أ");
    expect(s.topic, "مفهوم أ", reason: 'ملخّصُ الصفّ هو الأكثرُ تكراراً');
  });

  // ══════════════════════════════════════════════════
  // ⑨ فصلُ المواد
  // ══════════════════════════════════════════════════
  test('⑨ أفضلُ مادةٍ وأضعفُها ومجموعُ كلٍّ منها مفصولة', () {
    final rs = [
      _q(subject: "احياء", asked: const {"د1": 10}, wrong: const {"د1": 1}, at: DateTime(2026, 9, 1)),
      _q(subject: "كيمياء", asked: const {"د2": 10}, wrong: const {"د2": 9}, at: DateTime(2026, 9, 2)),
    ];
    expect(QuizAnalytics.bestSubject(rs)!.subject, "احياء");
    expect(QuizAnalytics.weakestSubject(rs)!.subject, "كيمياء");
    expect(QuizAnalytics.bySubject(rs).map((s) => s.subject), ["احياء", "كيمياء"]);
    // 🎓 ولا يتسرّب درسُ مادةٍ إلى مراجعة أخرى.
    expect(QuizAnalytics.reviewSpots(rs, "احياء").single.lesson, "د1");
  });

  // ══════════════════════════════════════════════════
  // ⑪ عربيّةُ الأرقام المعروضة
  // ══════════════════════════════════════════════════
  //
  // 🔴 رُصد في سجلّ اختبارات الأحياء: **«قبل 1 أسابيع»**. والشاشةُ يقرؤها
  //    طالبٌ يدرس اللغة العربية — فالتمييزُ بابٌ لا زينة.
  group('⑪ تمييزُ العدد في «قبل …»', () {
    String days(int n) => arabicAgo(n,
        one: "يوم", two: "يومين", few: "أيام", many: "يوماً");
    String weeks(int n) => arabicAgo(n,
        one: "أسبوع", two: "أسبوعين", few: "أسابيع", many: "أسبوعاً");

    test('المفردُ بلا رقم', () {
      expect(weeks(1), "قبل أسبوع");
      expect(days(1), "قبل يوم");
    });

    test('والمثنّى بصيغته', () {
      expect(days(2), "قبل يومين");
      expect(weeks(2), "قبل أسبوعين");
    });

    test('وجمعُ القلّة حتى العشرة', () {
      expect(days(3), "قبل 3 أيام");
      expect(days(10), "قبل 10 أيام");
    });

    test('وما فوق العشرة مفردٌ منصوب', () {
      expect(days(11), "قبل 11 يوماً");
    });
  });

  // ══════════════════════════════════════════════════
  // ⑩ منحنى التقدّم
  // ══════════════════════════════════════════════════
  test('⑩ آخرُ عشرةٍ بالترتيب الزمنيّ لا بترتيب المخزن', () {
    final rs = [
      for (var d = 1; d <= 12; d++)
        _q(asked: {"د": 10}, wrong: {"د": (10 - d).clamp(0, 10)}, at: DateTime(2026, 9, d)),
    ].reversed.toList(); // المخزنُ يعطيها الأحدثَ أولاً
    final line = QuizAnalytics.recentPercents(rs);
    expect(line.length, 10);
    for (var i = 1; i < line.length; i++) {
      expect(line[i], greaterThanOrEqualTo(line[i - 1]),
          reason: 'المنحنى يصعد زمنياً: $line');
    }
    expect(line.last, 100);
  });
}
