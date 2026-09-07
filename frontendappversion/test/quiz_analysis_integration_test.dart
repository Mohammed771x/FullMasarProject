// 🔬 تشابك «اختبر نفسك» مع «تحليل مستواي» — سيناريوهات صعبة.
//
// القسمان متشابكان في ثلاث نقاط، وكل واحدة كسرت مرّة:
//   ١) الاختبار يكتب `QuizResult` ⇒ التحليل يقرؤه
//   ٢) نقطة الضعف تفتح الشات على (مادة · وحدة · درس)
//   ٣) «إعادة الاختبار» تفتح الإعداد بدروس التحليل
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/quiz/data/models/quiz_models.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_analytics.dart';

SubjectCapabilities _caps(Map<String, List<String>> units) => SubjectCapabilities(
      subject: "كيمياء",
      lessonsAvailable: true,
      pagesAvailable: false,
      lessonsUnits: [
        for (final e in units.entries) LessonsUnit(unit: e.key, lessons: e.value)
      ],
      pagesUnits: const [],
    );

QuizResult _r({
  required String subject,
  required String unit,
  required List<String> lessons,
  required int score,
  required int total,
  List<WrongAnswer> wrong = const [],
  Map<String, int> asked = const {},
  DateTime? at,
  String owner = "u1",
}) =>
    QuizResult(
      id: "${subject}_${unit}_${at?.microsecondsSinceEpoch ?? score}_$total",
      subject: subject,
      grade: 3,
      track: "علمي",
      unit: unit,
      lessons: lessons,
      score: score,
      total: total,
      wrong: wrong,
      durationSec: 90,
      createdAt: at ?? DateTime(2026, 8, 1),
      ownerUid: owner,
      askedPerLesson: asked,
    );

void main() {
  // ══════════════════════════════════════════════════════════
  group('١) الحلقة الذهبية عبر الوحدات — وحدةُ النتيجة تكذب', () {
    // اختبار المراجعة يجمع دروساً من وحدات مختلفة، والنتيجة تُختم بوحدة
    // **أول درس** وحدها. فأخطاء بقية الدروس تحمل وحدةً ليست وحدتها.
    final caps = _caps({
      "الكيمياء الحرارية": ["قانون هس", "المعادلة الحرارية"],
      "الكيمياء الكهربائية": ["خلايا خزن الطاقة", "قوانين فاراداي"],
      "العناصر الانتقالية": ["خواص الحديد"],
    });

    test('★ درسٌ من وحدةٍ أخرى يُوجد رغم أن الوحدة القادمة خاطئة', () {
      // النتيجة مختومة بـ«الكيمياء الحرارية» (وحدة أول درس) والدرس من غيرها
      final unit = ChatController.resolveLessonUnit(
          caps, "الكيمياء الحرارية", "خلايا خزن الطاقة");
      expect(unit, "الكيمياء الكهربائية");
      expect(caps.lessonsIn(unit).contains("خلايا خزن الطاقة"), isTrue,
          reason: "وإلا وصل الطالب وضعَ الدروس بلا درس مختار");
    });

    test('الوحدة الصحيحة تُقبل كما هي', () {
      expect(ChatController.resolveLessonUnit(caps, "الكيمياء الحرارية", "قانون هس"),
          "الكيمياء الحرارية");
    });

    test('بلا وحدة قادمة يُبحث عن الدرس', () {
      expect(ChatController.resolveLessonUnit(caps, null, "خواص الحديد"),
          "العناصر الانتقالية");
    });

    test('درسٌ لا وجود له لا يُسقط الشاشة ولا يخترع وحدة', () {
      final u = ChatController.resolveLessonUnit(caps, "العناصر الانتقالية", "درس وهمي");
      expect(u, "العناصر الانتقالية");
      expect(caps.lessonsIn(u).contains("درس وهمي"), isFalse);
    });

    test('قدرات فارغة لا تنهار', () {
      expect(ChatController.resolveLessonUnit(_caps({}), "أي وحدة", "أي درس"), "");
    });
  });

  // ══════════════════════════════════════════════════════════
  group('٢) اختبار مراجعة عبر ثلاث وحدات — الإحصاء', () {
    // 10 أسئلة موزّعة 4+3+3 على ثلاثة دروس من ثلاث وحدات،
    // والنتيجة كلّها مختومة بوحدة أول درس.
    final rs = [
      _r(
        subject: "كيمياء",
        unit: "الكيمياء الحرارية",
        lessons: const ["قانون هس", "خلايا خزن الطاقة", "خواص الحديد"],
        score: 4,
        total: 10,
        asked: const {"قانون هس": 4, "خلايا خزن الطاقة": 3, "خواص الحديد": 3},
        wrong: [
          for (var i = 0; i < 1; i++)
            WrongAnswer(topic: "المحتوى الحراري", lesson: "قانون هس", unit: "الكيمياء الحرارية"),
          for (var i = 0; i < 3; i++)
            WrongAnswer(topic: "الأقطاب", lesson: "خلايا خزن الطاقة", unit: "الكيمياء الحرارية"),
          for (var i = 0; i < 2; i++)
            WrongAnswer(topic: "التأكسد", lesson: "خواص الحديد", unit: "الكيمياء الحرارية"),
        ],
        at: DateTime(2026, 8, 5),
      ),
    ];

    test('كل درسٍ صفٌّ مستقل بعيّنته الصحيحة', () {
      final spots = QuizAnalytics.weakSpots(rs);
      expect(spots.length, 3);
      final byLesson = {for (final s in spots) s.lesson: s};
      expect(byLesson["قانون هس"]!.asked, 4);
      expect(byLesson["قانون هس"]!.misses, 1);
      expect(byLesson["خلايا خزن الطاقة"]!.asked, 3);
      expect(byLesson["خلايا خزن الطاقة"]!.misses, 3);
      expect(byLesson["خواص الحديد"]!.asked, 3);
    });

    test('الترتيب بالنسبة: 3/3 يسبق 1/4 مهما تساوت الأعداد', () {
      final spots = QuizAnalytics.weakSpots(rs);
      expect(spots.first.lesson, "خلايا خزن الطاقة");
      expect(spots.last.lesson, "قانون هس");
    });

    test('مجموع أخطاء المفاهيم = أخطاء الدرس', () {
      for (final s in QuizAnalytics.weakSpots(rs)) {
        expect(s.topics.fold<int>(0, (n, t) => n + t.misses), s.misses);
      }
    });

    test('«إعادة الاختبار» ترشّح ≤3 دروسٍ مختلفة', () {
      final ls = QuizAnalytics.reviewLessons(rs, "كيمياء");
      expect(ls.length, lessThanOrEqualTo(3));
      expect(ls.toSet().length, ls.length, reason: "بلا تكرار");
    });
  });

  // ══════════════════════════════════════════════════════════
  group('٣) حالات بيانات قاسية', () {
    test('نتيجة قديمة (بلا askedPerLesson) مع جديدة لا تُفسد النسبة', () {
      final rs = [
        _r(subject: "فيزياء", unit: "و", lessons: const ["د1", "د2"],
            score: 5, total: 10, at: DateTime(2026, 8, 1),
            wrong: [WrongAnswer(topic: "ت", lesson: "د1", unit: "و")]),
        _r(subject: "فيزياء", unit: "و", lessons: const ["د1"],
            score: 8, total: 10, at: DateTime(2026, 8, 2),
            asked: const {"د1": 10},
            wrong: [WrongAnswer(topic: "ت", lesson: "د1", unit: "و")]),
      ];
      final s = QuizAnalytics.weakSpots(rs).firstWhere((w) => w.lesson == "د1");
      expect(s.errorRate, inInclusiveRange(0, 100));
      expect(s.asked, greaterThan(0));
    });

    test('اختبار بلا أسماء دروس (وضع الوحدات) يُنسب للوحدة', () {
      final rs = [
        _r(subject: "احياء", unit: "الوراثة", lessons: const [],
            score: 6, total: 10,
            wrong: [for (var i = 0; i < 4; i++)
              WrongAnswer(topic: "", lesson: "", unit: "")]),
      ];
      final spots = QuizAnalytics.weakSpots(rs);
      expect(spots.single.lesson, "الوراثة");
      expect(spots.single.misses, 4);
    });

    test('درسٌ سُئل عنه ولم يُخطئ فيه لا يُعدّ نقطة ضعف', () {
      final rs = [
        _r(subject: "كيمياء", unit: "و", lessons: const ["نظيف", "سيء"],
            score: 5, total: 10, asked: const {"نظيف": 5, "سيء": 5},
            wrong: [for (var i = 0; i < 5; i++)
              WrongAnswer(topic: "ت", lesson: "سيء", unit: "و")]),
      ];
      final spots = QuizAnalytics.weakSpots(rs);
      expect(spots.map((s) => s.lesson), ["سيء"]);
    });

    test('اختباران في اللحظة نفسها لا يُسقطان الترتيب', () {
      final t = DateTime(2026, 8, 3, 12, 0, 0);
      final rs = [
        _r(subject: "عربي", unit: "و", lessons: const ["د"], score: 10, total: 10, at: t),
        _r(subject: "عربي", unit: "و", lessons: const ["د"], score: 0, total: 10, at: t),
      ];
      final s = QuizAnalytics.bySubject(rs).single;
      expect(s.currentQuizzes, 2);
      expect(s.currentPercent, inInclusiveRange(0, 100));
    });

    test('صفر أسئلة لا يقسم على صفر', () {
      final rs = [_r(subject: "عربي", unit: "و", lessons: const [], score: 0, total: 0)];
      expect(QuizAnalytics.overallPercent(rs), 0);
      expect(QuizAnalytics.bySubject(rs).single.currentPercent, 0);
      expect(QuizAnalytics.weakSpots(rs), isEmpty);
    });

    test('سلسلة الأيام: فجوةُ يومٍ تقطعها', () {
      final rs = [
        _r(subject: "عربي", unit: "و", lessons: const ["د"], score: 5, total: 10,
            at: DateTime(2026, 8, 1)),
        _r(subject: "عربي", unit: "و", lessons: const ["د"], score: 5, total: 10,
            at: DateTime(2026, 8, 3)),
        _r(subject: "عربي", unit: "و", lessons: const ["د"], score: 5, total: 10,
            at: DateTime(2026, 8, 4)),
      ];
      expect(QuizAnalytics.streakDays(rs, now: DateTime(2026, 8, 4)), 2);
    });

    test('السقف يُحترم ويُبقي الأسوأ', () {
      final rs = [
        for (var i = 0; i < 9; i++)
          _r(subject: "كيمياء", unit: "و", lessons: ["د$i"], score: 0, total: 5,
              asked: {"د$i": 5}, at: DateTime(2026, 8, 1 + i),
              wrong: [for (var k = 0; k < i + 1; k++)
                WrongAnswer(topic: "ت", lesson: "د$i", unit: "و")]),
      ];
      final spots = QuizAnalytics.weakSpots(rs, limit: 5);
      expect(spots.length, 5);
      expect(spots.map((s) => s.lesson).toSet().length, 5, reason: "دروس مختلفة");
    });
  });

  // ══════════════════════════════════════════════════════════
  group('٤) اتّساق التصنيف مع نقاط الضعف', () {
    test('من تحسّن: التصنيف يرتفع ونسبة ضعف درسه تنزل معاً', () {
      final rs = [
        for (var d = 0; d < 5; d++)
          _r(subject: "فيزياء", unit: "و", lessons: const ["د"],
              score: 2 + d * 2, total: 10, asked: const {"د": 10},
              at: DateTime(2026, 8, 1 + d),
              wrong: [for (var k = 0; k < 8 - d * 2; k++)
                WrongAnswer(topic: "ت", lesson: "د", unit: "و")]),
      ];
      final s = QuizAnalytics.bySubject(rs).single;
      final spot = QuizAnalytics.weakSpots(rs).single;
      // كلاهما يقول «تحسّن» — لا يتناقضان كما كانا
      expect(s.currentPercent, greaterThan(s.percent));
      expect(spot.errorRate, lessThan(50));
    });
  });
}
