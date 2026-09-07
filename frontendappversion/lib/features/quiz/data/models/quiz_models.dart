import 'package:hive/hive.dart';

part 'quiz_models.g.dart';

// ==========================================
// 🧠 نماذج «اختبر نفسك»
// ==========================================
// **الأسئلة لا تُخزَّن** — تُولَّد من دروس الطالب وتُستهلك في الجلسة ([03§5]).
// **النتيجة تُخزَّن** — لأنها غذاء قسم التحليل ([31§7]).

/// سؤال اختيار من متعدد — يعيش في الذاكرة أثناء الاختبار فقط.
class QuizQuestion {
  final String q;
  final List<String> options;
  final int correctIndex;
  final String topic;   // المفهوم الدقيق — عليه يُبنى تحليل نقاط الضعف
  final String lesson;

  const QuizQuestion({
    required this.q,
    required this.options,
    required this.correctIndex,
    required this.topic,
    required this.lesson,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        q: (j['q'] ?? '').toString(),
        options: List<String>.from(j['options'] ?? const []),
        correctIndex: (j['correct_index'] is int) ? j['correct_index'] as int : 0,
        topic: (j['topic'] ?? '').toString(),
        lesson: (j['lesson'] ?? '').toString(),
      );

  bool isCorrect(int? choice) => choice != null && choice == correctIndex;
}

// ══════════════ النتيجة المحفوظة ══════════════

/// إجابة خاطئة واحدة.
/// ⚠️ **كائن لا نص:** التحليل يحتاج أن يقول «ضعفك في **درس** كذا» **ويفتح ذلك
/// الدرس** في الشات — واسم الموضوع وحده لا يكفي لفتحه ([31§6]).
@HiveType(typeId: 2)
class WrongAnswer {
  @HiveField(0)
  final String topic;

  @HiveField(1)
  final String lesson;

  @HiveField(2)
  final String unit;

  const WrongAnswer({required this.topic, required this.lesson, required this.unit});

  Map<String, dynamic> toMap() => {"topic": topic, "lesson": lesson, "unit": unit};

  factory WrongAnswer.fromMap(Map m) => WrongAnswer(
        topic: (m["topic"] ?? "").toString(),
        lesson: (m["lesson"] ?? "").toString(),
        unit: (m["unit"] ?? "").toString(),
      );
}

@HiveType(typeId: 3)
class QuizResult {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String subject;

  @HiveField(2)
  final int grade;

  @HiveField(3)
  final String track;

  @HiveField(4)
  final String unit;

  @HiveField(5)
  final List<String> lessons;

  @HiveField(6)
  final int score;

  @HiveField(7)
  final int total;

  @HiveField(8)
  final List<WrongAnswer> wrong;

  @HiveField(9)
  final DateTime createdAt;

  @HiveField(10)
  final int durationSec;

  /// 👤 مالك النتيجة — جوّال واحد قد يستعمله أكثر من حساب ([28§10]).
  @HiveField(11, defaultValue: "")
  String ownerUid;

  /// هل رُفعت إلى السحابة؟ (تُستعمل لإعادة المحاولة)
  @HiveField(12, defaultValue: false)
  bool synced;

  /// كم سؤالاً جاء من كل درس: {اسم الدرس: عدد الأسئلة}.
  ///
  /// ⭐ **بدون هذا لا يمكن قياس الضعف نسبةً** — نعرف الأخطاء ولا نعرف من كم
  ///    سؤالاً، فيصير «تسعة أخطاء» أعلى من «خطأ من سؤال واحد» ظلماً.
  ///    والنتائج القديمة تصل فارغةً، فتُقدَّر بتوزيع الأسئلة على الدروس.
  @HiveField(13, defaultValue: <String, int>{})
  final Map<String, int> askedPerLesson;

  QuizResult({
    required this.id,
    required this.subject,
    required this.grade,
    required this.track,
    required this.unit,
    required this.lessons,
    required this.score,
    required this.total,
    required this.wrong,
    required this.durationSec,
    DateTime? createdAt,
    this.ownerUid = "",
    this.synced = false,
    this.askedPerLesson = const {},
  }) : createdAt = createdAt ?? DateTime.now();

  /// عدد أسئلة درسٍ بعينه في هذا الاختبار.
  ///
  /// النتائج القديمة (قبل `askedPerLesson`) تُقدَّر بقسمة الأسئلة على الدروس
  /// المختارة — تقديرٌ معلَن خيرٌ من رقمٍ مفقود يعطّل القياس.

  /// الدروس التي سُئل عنها فعلاً في هذا الاختبار.
  Iterable<String> get lessonsAsked =>
      askedPerLesson.isNotEmpty ? askedPerLesson.keys : lessons;

  int askedFor(String lesson) {
    if (askedPerLesson.isNotEmpty) return askedPerLesson[lesson] ?? 0;
    if (lessons.isEmpty || !lessons.contains(lesson)) return 0;
    return (total / lessons.length).round();
  }

  /// النسبة المئوية 0–100.
  int get percent => total == 0 ? 0 : ((score / total) * 100).round();

  bool get isExcellent => percent >= 80;
  bool get isPass => percent >= 50;

  /// مستند Firestore — `type` يميّزها عن نتائج اختبار الميول لاحقاً.
  Map<String, dynamic> toDoc() => {
        "type": "quiz",
        "subject": subject,
        "grade": grade,
        "track": track,
        "unit": unit,
        "lessons": lessons,
        "score": score,
        "total": total,
        "duration_sec": durationSec,
        "wrong": wrong.map((w) => w.toMap()).toList(),
        "asked_per_lesson": askedPerLesson,
        "created_at": createdAt.toIso8601String(),
      };

  static QuizResult fromDoc(String id, Map<String, dynamic> d) => QuizResult(
        id: id,
        subject: (d["subject"] ?? "").toString(),
        grade: (d["grade"] is int) ? d["grade"] as int : 3,
        track: (d["track"] ?? "علمي").toString(),
        unit: (d["unit"] ?? "").toString(),
        lessons: List<String>.from(d["lessons"] ?? const []),
        score: (d["score"] is int) ? d["score"] as int : 0,
        total: (d["total"] is int) ? d["total"] as int : 0,
        durationSec: (d["duration_sec"] is int) ? d["duration_sec"] as int : 0,
        wrong: ((d["wrong"] as List?) ?? const [])
            .map((w) => WrongAnswer.fromMap(Map.from(w as Map)))
            .toList(),
        askedPerLesson: Map<String, int>.from(d["asked_per_lesson"] ?? const {}),
        createdAt: DateTime.tryParse((d["created_at"] ?? "").toString()) ?? DateTime.now(),
        synced: true,
      );
}
