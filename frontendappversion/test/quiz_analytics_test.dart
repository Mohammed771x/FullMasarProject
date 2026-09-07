// 📊 اشتقاق الإحصائيات من النتائج — دوالّ خالصة بلا Hive ولا شبكة.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_analytics.dart';

QuizResult _r({
  required String subject,
  required int score,
  required int total,
  List<WrongAnswer> wrong = const [],
  DateTime? at,
  String unit = "وحدة",
}) =>
    QuizResult(
      id: "${subject}_${at?.millisecondsSinceEpoch ?? score}_$total",
      subject: subject,
      grade: 3,
      track: "علمي",
      unit: unit,
      lessons: const ["درس"],
      score: score,
      total: total,
      wrong: wrong,
      durationSec: 120,
      createdAt: at ?? DateTime(2026, 8, 1),
    );

WrongAnswer _w(String lesson, {String topic = "مفهوم", String unit = "وحدة"}) =>
    WrongAnswer(topic: topic, lesson: lesson, unit: unit);

void main() {
  group('الملخّص العام', () {
    test('المعدل يُحسب من مجموع الأسئلة لا من متوسط النِّسب', () {
      // 5/5 (100%) و 3/15 (20%) — متوسط النسب 60% وهو مضلّل
      final rs = [_r(subject: "فيزياء", score: 5, total: 5),
                  _r(subject: "فيزياء", score: 3, total: 15)];
      expect(QuizAnalytics.overallPercent(rs), 40); // 8 من 20
    });

    test('قائمة فارغة لا تنهار', () {
      expect(QuizAnalytics.overallPercent([]), 0);
      expect(QuizAnalytics.bySubject([]), isEmpty);
      expect(QuizAnalytics.bestSubject([]), isNull);
      expect(QuizAnalytics.weakSpots([]), isEmpty);
      expect(QuizAnalytics.streakDays([]), 0);
    });

    test('الأيام المتتالية', () {
      final now = DateTime(2026, 8, 28);
      final rs = [
        _r(subject: "فيزياء", score: 1, total: 1, at: now),
        _r(subject: "فيزياء", score: 1, total: 1, at: now.subtract(const Duration(days: 1))),
        _r(subject: "فيزياء", score: 1, total: 1, at: now.subtract(const Duration(days: 2))),
        _r(subject: "فيزياء", score: 1, total: 1, at: now.subtract(const Duration(days: 9))),
      ];
      expect(QuizAnalytics.streakDays(rs, now: now), 3);
    });

    test('انقطاع يوم واحد يكسر السلسلة', () {
      final now = DateTime(2026, 8, 28);
      final rs = [
        _r(subject: "فيزياء", score: 1, total: 1, at: now),
        _r(subject: "فيزياء", score: 1, total: 1, at: now.subtract(const Duration(days: 2))),
      ];
      expect(QuizAnalytics.streakDays(rs, now: now), 1);
    });
  });

  group('لكل مادة', () {
    final rs = [
      _r(subject: "فيزياء", score: 9, total: 10),
      _r(subject: "كيمياء", score: 3, total: 10),
      _r(subject: "كيمياء", score: 4, total: 10),
    ];

    test('أفضل مادة وأضعفها', () {
      expect(QuizAnalytics.bestSubject(rs)!.subject, "فيزياء");
      expect(QuizAnalytics.bestSubject(rs)!.percent, 90);
      expect(QuizAnalytics.weakestSubject(rs)!.subject, "كيمياء");
      expect(QuizAnalytics.weakestSubject(rs)!.percent, 35);
    });

    test('التصنيفات', () {
      final s = QuizAnalytics.bySubject(rs);
      expect(s.first.isStrong, isTrue);
      expect(s.first.label, "ممتاز");
      expect(s.last.isWeak, isTrue);
      expect(s.last.label, "يحتاج تركيزاً");
      expect(s.last.quizzes, 2);
    });

    test('اتجاه التحسّن موجب عند التقدّم', () {
      final t = DateTime(2026, 8, 1);
      final improving = [
        _r(subject: "عربي", score: 2, total: 10, at: t),
        _r(subject: "عربي", score: 8, total: 10, at: t.add(const Duration(days: 1))),
      ];
      expect(QuizAnalytics.bySubject(improving).first.trend, 60);
    });

    test('اختبار واحد ⇒ لا اتجاه بعد', () {
      expect(QuizAnalytics.bySubject([_r(subject: "عربي", score: 5, total: 10)]).first.trend, 0);
    });
  });

  group('نقاط الضعف — مدخلات الحلقة الذهبية', () {
    final rs = [
      _r(subject: "فيزياء", score: 6, total: 10, wrong: [
        _w("نظرية بوهر"), _w("نظرية بوهر"), _w("فيزياء الذرة"),
      ]),
      _r(subject: "فيزياء", score: 7, total: 10, wrong: [_w("نظرية بوهر")]),
    ];

    test('الأكثر تكراراً أولاً', () {
      final spots = QuizAnalytics.weakSpots(rs);
      expect(spots.first.lesson, "نظرية بوهر");
      expect(spots.first.misses, 3);
      expect(spots.first.subject, "فيزياء");
    });

    test('الدرس محفوظ ⇒ يمكن فتحه في الشات', () {
      expect(QuizAnalytics.weakSpots(rs).first.lesson, isNotEmpty);
      expect(QuizAnalytics.weakSpots(rs).first.unit, isNotEmpty);
    });

    test('دروس اختبار المراجعة لمادة بعينها', () {
      final lessons = QuizAnalytics.reviewLessons(rs, "فيزياء");
      expect(lessons, contains("نظرية بوهر"));
      expect(lessons.length, lessThanOrEqualTo(3));
      expect(QuizAnalytics.reviewLessons(rs, "كيمياء"), isEmpty);
    });

    test('الحدّ يُحترم', () {
      expect(QuizAnalytics.weakSpots(rs, limit: 1).length, 1);
    });
  });

  lessonGroupingTests();
  errorRateTests();

  test('خط التقدّم — آخر النتائج بالترتيب الزمني', () {
    final t = DateTime(2026, 8, 1);
    // درجات واقعية 0..10 من عشرة
    final rs = List.generate(11, (i) =>
        _r(subject: "عربي", score: i, total: 10, at: t.add(Duration(days: i))));
    final line = QuizAnalytics.recentPercents(rs, count: 5);

    expect(line, [60, 70, 80, 90, 100]);   // الأحدث في النهاية
    expect(QuizAnalytics.recentPercents(rs, count: 50).length, 11); // أقل من الحد
  });

  test('النسبة والتصنيف في النتيجة الواحدة', () {
    expect(_r(subject: "س", score: 8, total: 10).percent, 80);
    expect(_r(subject: "س", score: 8, total: 10).isExcellent, isTrue);
    expect(_r(subject: "س", score: 4, total: 10).isPass, isFalse);
    expect(_r(subject: "س", score: 0, total: 0).percent, 0);
  });
}

// ══════════ التجميع بالدرس لا بالمفهوم ══════════
// قرار المالك: «المنفعل الماضي» في اختبارين (5 أخطاء ثم 4) صفٌّ **واحد**
// بتسعة أخطاء، لا صفّان. والمفاهيم تبقى محفوظة للتفصيل عند الضغط.
void lessonGroupingTests() {
  group('نقاط الضعف تُجمَّع بالدرس', () {
    test('درسٌ واحد عبر اختبارين ⇒ صفٌّ واحد بمجموع الأخطاء', () {
      final rs = [
        _r(subject: "عربي", score: 5, total: 10, wrong: [
          _w("المنفعل الماضي", topic: "علامة البناء"),
          _w("المنفعل الماضي", topic: "علامة البناء"),
          _w("المنفعل الماضي", topic: "نائب الفاعل"),
          _w("المنفعل الماضي", topic: "نائب الفاعل"),
          _w("المنفعل الماضي", topic: "الصياغة"),
        ]),
        _r(subject: "عربي", score: 6, total: 10, wrong: [
          _w("المنفعل الماضي", topic: "نائب الفاعل"),
          _w("المنفعل الماضي", topic: "الصياغة"),
          _w("المنفعل الماضي", topic: "علامة البناء"),
          _w("المنفعل الماضي", topic: "الصياغة"),
        ]),
      ];

      final spots = QuizAnalytics.weakSpots(rs);
      expect(spots.length, 1, reason: 'الدرس تكرّر بدل أن يُجمَع');
      expect(spots.first.lesson, "المنفعل الماضي");
      expect(spots.first.misses, 9, reason: '5 + 4');
    });

    test('نفس الدرس بمفاهيم مختلفة لا يتكرّر', () {
      final rs = [
        _r(subject: "كيمياء", score: 5, total: 6, wrong: [
          _w("خلايا خزن الطاقة", topic: "أ"),
          _w("خلايا خزن الطاقة", topic: "ب"),
          _w("خلايا خزن الطاقة", topic: "جـ"),
          _w("خلايا خزن الطاقة", topic: "د"),
          _w("خلايا خزن الطاقة", topic: "هـ"),
          _w("خلايا خزن الطاقة", topic: "و"),
        ]),
      ];
      final spots = QuizAnalytics.weakSpots(rs);
      expect(spots.length, 1, reason: 'ستة مفاهيم ⇒ ستة صفوف وهي درسٌ واحد');
      expect(spots.first.misses, 6);
    });

    test('درسان في مادتين يبقيان منفصلين', () {
      final rs = [
        _r(subject: "فيزياء", score: 1, total: 2, wrong: [_w("درس")]),
        _r(subject: "كيمياء", score: 1, total: 2, wrong: [_w("درس")]),
      ];
      expect(QuizAnalytics.weakSpots(rs).length, 2);
    });

    test('السقف خمسة دروس مهما كثرت الأخطاء', () {
      final rs = [
        _r(subject: "فيزياء", score: 0, total: 9, wrong: [
          for (var i = 1; i <= 9; i++) _w("درس $i"),
        ]),
      ];
      expect(QuizAnalytics.weakSpots(rs).length, 5);
      expect(QuizAnalytics.weakSpots(rs, limit: 3).length, 3);
    });
  });

  group('تفصيل المفاهيم داخل الدرس', () {
    final rs = [
      _r(subject: "عربي", score: 4, total: 10, wrong: [
        _w("المنفعل الماضي", topic: "نائب الفاعل"),
        _w("المنفعل الماضي", topic: "نائب الفاعل"),
        _w("المنفعل الماضي", topic: "نائب الفاعل"),
        _w("المنفعل الماضي", topic: "علامة البناء"),
        _w("المنفعل الماضي", topic: "الصياغة"),
        _w("المنفعل الماضي", topic: "الصياغة"),
      ]),
    ];

    test('المفاهيم مرتّبة بالأكثر خطأً', () {
      final t = QuizAnalytics.weakSpots(rs).first.topics;
      expect(t.map((e) => e.topic).toList(),
          ["نائب الفاعل", "الصياغة", "علامة البناء"]);
      expect(t.map((e) => e.misses).toList(), [3, 2, 1]);
    });

    test('مجموع المفاهيم = أخطاء الدرس', () {
      final spot = QuizAnalytics.weakSpots(rs).first;
      expect(spot.topics.fold<int>(0, (n, e) => n + e.misses), spot.misses);
    });

    test('المفهوم المعروض في الصفّ هو الأكثر تكراراً', () {
      expect(QuizAnalytics.weakSpots(rs).first.topic, "نائب الفاعل");
    });

    test('بلا مفاهيم مسجّلة ⇒ قائمة فارغة لا انهيار', () {
      final bare = [
        _r(subject: "فيزياء", score: 0, total: 1,
            wrong: [const WrongAnswer(topic: "", lesson: "د", unit: "و")]),
      ];
      final spot = QuizAnalytics.weakSpots(bare).first;
      expect(spot.topics, isEmpty);
      expect(spot.topic, "");
      expect(spot.misses, 1);
    });
  });

  test('دروس المراجعة لا تتكرّر بعد التجميع', () {
    final rs = [
      _r(subject: "عربي", score: 1, total: 5, wrong: [
        _w("درس أ", topic: "١"), _w("درس أ", topic: "٢"),
        _w("درس ب", topic: "١"),
      ]),
    ];
    final lessons = QuizAnalytics.reviewLessons(rs, "عربي");
    expect(lessons, ["درس أ", "درس ب"]);
  });
}

// ══════════ الترتيب بنسبة الخطأ لا بعددها ══════════
// قرار المالك: عدُّ الأخطاء يجعل أكثر الدروس اختباراً أكثرها «ضعفاً» دائماً،
// ولا يكافئ من ذاكر وأعاد الاختبار. القياس صار نسبةً مرجّحةً بالأحدث.
QuizResult _rq({
  required String subject,
  required Map<String, int> asked,
  required List<WrongAnswer> wrong,
  required DateTime at,
}) =>
    QuizResult(
      id: "$subject-${at.millisecondsSinceEpoch}",
      subject: subject,
      grade: 3,
      track: "علمي",
      unit: "وحدة",
      lessons: asked.keys.toList(),
      score: asked.values.fold(0, (n, v) => n + v) - wrong.length,
      total: asked.values.fold(0, (n, v) => n + v),
      wrong: wrong,
      durationSec: 60,
      createdAt: at,
      askedPerLesson: asked,
    );

void errorRateTests() {
  group('نسبة الخطأ', () {
    test('درسٌ كثير الاختبار لا يتصدّر لمجرّد تراكم أخطائه', () {
      final t = DateTime(2026, 8, 20);
      final rs = [
        // «مكرّر»: 6 أخطاء لكن من 30 سؤالاً (20%)
        for (var i = 0; i < 3; i++)
          _rq(subject: "كيمياء", asked: {"مكرّر": 10},
              wrong: [for (var k = 0; k < 2; k++) _w("مكرّر")],
              at: t.add(Duration(days: i))),
        // «نادر»: 3 أخطاء من 4 أسئلة (75%) — هو الأولى بالتركيز
        _rq(subject: "كيمياء", asked: {"نادر": 4},
            wrong: [for (var k = 0; k < 3; k++) _w("نادر")],
            at: t.add(const Duration(days: 3))),
      ];

      final spots = QuizAnalytics.weakSpots(rs);
      expect(spots.first.lesson, "نادر",
          reason: 'العدّ المجرّد كان يقدّم «مكرّر» بستة أخطاء');
      expect(spots.first.misses, 3);
      expect(spots.last.misses, 6);
    });

    test('من ذاكر وأعاد الاختبار تنزل نسبته', () {
      final t = DateTime(2026, 8, 20);
      final before = QuizAnalytics.weakSpots([
        _rq(subject: "عربي", asked: {"الحال": 5},
            wrong: [for (var k = 0; k < 4; k++) _w("الحال")], at: t),
      ]).first.errorRate;

      final after = QuizAnalytics.weakSpots([
        _rq(subject: "عربي", asked: {"الحال": 5},
            wrong: [for (var k = 0; k < 4; k++) _w("الحال")], at: t),
        // أعاد الاختبار بعد المذاكرة ولم يخطئ
        _rq(subject: "عربي", asked: {"الحال": 5}, wrong: const [],
            at: t.add(const Duration(days: 1))),
      ]).first.errorRate;

      expect(after, lessThan(before), reason: 'المذاكرة لم تُكافأ');
    });

    test('سؤال واحد أخطأ فيه لا يعطي 100٪ ولا يتصدّر', () {
      final t = DateTime(2026, 8, 20);
      final rs = [
        _rq(subject: "فيزياء", asked: {"عابر": 1}, wrong: [_w("عابر")], at: t),
        _rq(subject: "فيزياء", asked: {"ثقيل": 10},
            wrong: [for (var k = 0; k < 8; k++) _w("ثقيل")],
            at: t.add(const Duration(days: 1))),
      ];
      final spots = QuizAnalytics.weakSpots(rs);
      expect(spots.first.lesson, "ثقيل", reason: 'عيّنة سؤالٍ واحد تصدّرت');
      expect(spots.firstWhere((s) => s.lesson == "عابر").errorRate,
          lessThan(100));
    });

    test('درسٌ سُئل عنه ولم يُخطئ فيه أبداً ليس نقطة ضعف', () {
      final rs = [
        _rq(subject: "فيزياء", asked: {"سليم": 5, "ضعيف": 5},
            wrong: [_w("ضعيف")], at: DateTime(2026, 8, 20)),
      ];
      final spots = QuizAnalytics.weakSpots(rs);
      expect(spots.map((s) => s.lesson), ["ضعيف"]);
    });

    test('العيّنة محفوظة: الأخطاء ومجموع الأسئلة', () {
      final spot = QuizAnalytics.weakSpots([
        _rq(subject: "فيزياء", asked: {"د": 10},
            wrong: [for (var k = 0; k < 3; k++) _w("د")],
            at: DateTime(2026, 8, 20)),
      ]).first;
      expect(spot.misses, 3);
      expect(spot.asked, 10);
      expect(spot.errorRate, inInclusiveRange(20, 40)); // ≈ (3+1)/(10+2)
    });

    test('النتائج القديمة (بلا askedPerLesson) تُقدَّر ولا تنهار', () {
      final rs = [
        _r(subject: "فيزياء", score: 6, total: 10,
            wrong: [_w("درس أ"), _w("درس أ")]),
      ];
      final spots = QuizAnalytics.weakSpots(rs);
      expect(spots.first.misses, 2);
      expect(spots.first.errorRate, greaterThan(0));
    });
  });

  group('التصنيف بآخر خمسة اختبارات مرجّحةً (قرار المالك)', () {
    test('الأحدث أرجح كفّةً لكنه لا يقرّر وحده', () {
      // أربعة بـ30٪ ثم 10/10 — يقفز كثيراً، ولا يمحو الأربعة
      final rs = [
        for (var d = 0; d < 4; d++)
          _r(subject: "فيزياء", score: 3, total: 10, at: DateTime(2026, 8, 1 + d)),
        _r(subject: "فيزياء", score: 10, total: 10, at: DateTime(2026, 8, 7)),
      ];
      final s = QuizAnalytics.bySubject(rs).single;
      expect(s.currentPercent, greaterThan(60));   // قفزة كبيرة من 30٪
      expect(s.currentPercent, lessThan(85));      // لكنها ليست 100٪
      expect(s.currentQuizzes, 5);
      expect(s.percent, 44);                       // السجلّ الكامل محفوظ
    });

    test('اختبارٌ سيءٌ واحد لا يهدم مادةً ممتازة', () {
      final rs = [
        for (var d = 0; d < 4; d++)
          _r(subject: "كيمياء", score: 10, total: 10, at: DateTime(2026, 8, 1 + d)),
        _r(subject: "كيمياء", score: 3, total: 10, at: DateTime(2026, 8, 6)),
      ];
      final s = QuizAnalytics.bySubject(rs).single;
      expect(s.currentPercent, greaterThan(50));   // لم ينهر إلى 30٪
      expect(s.currentPercent, lessThan(80));      // ولم يبقَ «ممتازاً»
    });

    test('التحسّن المتتابع يرفع التصنيف', () {
      // 40٪ → 90٪ عبر أسبوع
      final rs = [
        for (var (i, sc) in [4, 5, 6, 7, 8, 9, 9].indexed)
          _r(subject: "أحياء", score: sc, total: 10, at: DateTime(2026, 8, 1 + i)),
      ];
      final s = QuizAnalytics.bySubject(rs).single;
      expect(s.currentPercent, greaterThanOrEqualTo(80));
      expect(s.label, anyOf("ممتاز", "جيد جداً"));
      expect(s.percent, 69);   // التراكمي كان يقول «جيد» ظلماً
    });

    test('ما قبل الخامس لا يدخل الحساب إطلاقاً', () {
      // صفرٌ قديم جداً + خمسة كاملة بعده
      final rs = [
        _r(subject: "فيزياء", score: 0, total: 10, at: DateTime(2026, 7, 1)),
        for (var d = 0; d < 5; d++)
          _r(subject: "فيزياء", score: 10, total: 10, at: DateTime(2026, 8, 1 + d)),
      ];
      final s = QuizAnalytics.bySubject(rs).single;
      expect(s.currentPercent, 100);
      expect(s.currentQuizzes, 5);
    });

    test('اختبار الخمسة أسئلة لا يقرّر وحده — النافذة تحميه', () {
      final rs = [
        for (var d = 0; d < 4; d++)
          _r(subject: "أحياء", score: 0, total: 10, at: DateTime(2026, 8, 1 + d)),
        _r(subject: "أحياء", score: 5, total: 5, at: DateTime(2026, 8, 6)),
      ];
      final s = QuizAnalytics.bySubject(rs).single;
      expect(s.currentPercent, lessThan(80));   // ليست 100٪ رغم الكمال
      expect(s.currentQuizzes, 5);
    });

    test('أفضل وأضعف مادة بالمستوى الحالي لا بمتوسط العمر', () {
      final rs = [
        _r(subject: "فيزياء", score: 10, total: 10, at: DateTime(2026, 8, 1)),
        _r(subject: "فيزياء", score: 2, total: 10, at: DateTime(2026, 8, 5)),
        _r(subject: "كيمياء", score: 1, total: 10, at: DateTime(2026, 8, 2)),
        _r(subject: "كيمياء", score: 10, total: 10, at: DateTime(2026, 8, 6)),
      ];
      expect(QuizAnalytics.bestSubject(rs)!.subject, "كيمياء");
      expect(QuizAnalytics.weakestSubject(rs)!.subject, "فيزياء");
    });

    test('بلا اختبارات لا ينهار', () {
      expect(QuizAnalytics.bySubject([]), isEmpty);
    });
  });
}
