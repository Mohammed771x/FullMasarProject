import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/quiz_models.dart';

// ==========================================
// ⏸️ استئناف اختبارٍ لم يكتمل
// ==========================================
// 🔴 **العطل من زاوية الطالب:** يبدأ اختباراً من ١٥ سؤالاً، يصل للسؤال ١٢،
//    فتأتيه مكالمة أو ينقطع النت أو يقتل النظامُ التطبيقَ في الخلفية —
//    **فيضيع كل شيء**. والأسوأ أن إعادة التوليد تخصم حصةً ثانية وتنادي
//    الموديل مرةً أخرى: الطالب يدفع مرتين ثمن مكالمةٍ لم يخترها.
//
// ⚖️ **ولماذا يخالف هذا «الأسئلة لا تُخزَّن» ([31§5])؟** لا يخالفه: القرار
//    كان ألّا تُخزَّن **على الخادم** — تُولَّد وتُستهلك، والمحفوظ هو النتيجة.
//    وهذا تخزينٌ **محليٌّ مؤقّت** على جهاز الطالب وحده، يُمحى لحظة انتهاء
//    الاختبار. لا يصل السحابة ولا يُزامَن ولا يُقرأ بعد الانتهاء.
//
// 👤 ومربوطٌ بالحساب: جوّالٌ بحسابين لا يستأنف أحدُهما اختبار الآخر.
//
// ⏳ وله عمرٌ (٢٤ ساعة): اختبارٌ متروكٌ من أسبوع ليس «قيد التقدّم» بل
//    منسيّ، وعرضُ استئنافه يربك أكثر مما يفيد.
class QuizResumeStore {
  QuizResumeStore._();

  static const String _prefix = "quiz_in_progress_";
  static const Duration maxAge = Duration(hours: 24);

  static String _key(String uid) => "$_prefix$uid";

  /// يحفظ لقطةً كاملة عن الاختبار الجاري. **لا يرمي أبداً.**
  static Future<void> save(QuizSnapshot snap) async {
    if (snap.ownerUid.isEmpty || snap.questions.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key(snap.ownerUid), jsonEncode(snap.toJson()));
    } catch (_) {
      // 🛟 تعذُّرُ الحفظ لا يوقف اختباراً جارياً — يفقد الاستئناف فقط.
    }
  }

  /// يقرأ اللقطة إن وُجدت وكانت حديثة، وإلا `null` (ويمسح المنتهية).
  static Future<QuizSnapshot?> read(String uid) async {
    if (uid.isEmpty) return null;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(uid));
      if (raw == null || raw.isEmpty) return null;

      final snap = QuizSnapshot.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map), uid);

      if (DateTime.now().difference(snap.savedAt) > maxAge) {
        await clear(uid);
        return null;
      }
      // ⚠️ لقطةٌ بلا أسئلة أو بمؤشّرٍ خارج المدى تُمسح بدل أن تُعرض:
      //    زرُّ «استأنف» يفتح شاشةً تنهار أسوأُ من ألّا يظهر أصلاً.
      if (snap.questions.isEmpty || snap.index >= snap.questions.length) {
        await clear(uid);
        return null;
      }
      return snap;
    } catch (_) {
      // بياناتٌ مشوّهة (تغيّر شكل الحفظ مثلاً) ⇒ تُمحى ولا تُسقط الشاشة.
      await clear(uid);
      return null;
    }
  }

  static Future<void> clear(String uid) async {
    if (uid.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(uid));
    } catch (_) {}
  }
}

/// لقطةٌ عن اختبارٍ جارٍ — كل ما يلزم لاستئنافه من حيث توقّف.
class QuizSnapshot {
  const QuizSnapshot({
    required this.ownerUid,
    required this.subject,
    required this.grade,
    required this.track,
    required this.unit,
    required this.lessons,
    required this.questions,
    required this.answers,
    required this.index,
    required this.score,
    required this.savedAt,
    required this.startedAt,
  });

  final String ownerUid;
  final String subject;
  final int grade;
  final String track;
  final String unit;
  final List<String> lessons;
  final List<QuizQuestion> questions;

  /// إجابة الطالب لكل سؤال أُجيب عنه (`null` = لم يُجَب بعد).
  final List<int?> answers;

  final int index;
  final int score;
  final DateTime savedAt;

  /// ⏱️ يُحفظ كي تبقى مدّة الاختبار صحيحةً في النتيجة بعد الاستئناف.
  final DateTime startedAt;

  int get remaining => questions.length - index;

  Map<String, dynamic> toJson() => {
        "subject": subject,
        "grade": grade,
        "track": track,
        "unit": unit,
        "lessons": lessons,
        "questions": questions
            .map((q) => {
                  "q": q.q,
                  "options": q.options,
                  "correct_index": q.correctIndex,
                  "topic": q.topic,
                  "lesson": q.lesson,
                })
            .toList(),
        "answers": answers,
        "index": index,
        "score": score,
        "saved_at": DateTime.now().toIso8601String(),
        "started_at": startedAt.toIso8601String(),
      };

  factory QuizSnapshot.fromJson(Map<String, dynamic> j, String uid) {
    final rawQuestions = (j["questions"] as List?) ?? const [];
    final rawAnswers = (j["answers"] as List?) ?? const [];
    return QuizSnapshot(
      ownerUid: uid,
      subject: (j["subject"] ?? "").toString(),
      grade: j["grade"] is int ? j["grade"] as int : 3,
      track: (j["track"] ?? "علمي").toString(),
      unit: (j["unit"] ?? "").toString(),
      lessons: List<String>.from(j["lessons"] ?? const []),
      questions: rawQuestions
          .map((e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      answers: rawAnswers.map((e) => e is int ? e : null).toList(),
      index: j["index"] is int ? j["index"] as int : 0,
      score: j["score"] is int ? j["score"] as int : 0,
      savedAt: DateTime.tryParse((j["saved_at"] ?? "").toString()) ?? DateTime.now(),
      startedAt:
          DateTime.tryParse((j["started_at"] ?? "").toString()) ?? DateTime.now(),
    );
  }
}
