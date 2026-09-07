import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/session/user_session.dart';
import '../../../core/sync/sync_service.dart';
import '../data/models/quiz_models.dart';
import '../data/quiz_repository.dart';
import '../data/quiz_storage.dart';

// ==========================================
// 🧠 متحكّم جلسة الاختبار
// ==========================================
// يحمل الأسئلة في الذاكرة (لا تُخزَّن أبداً)، ويحفظ **النتيجة** فقط عند
// الانتهاء: محلياً أولاً ثم نسخة سحابية بلا انتظار ([31§6]).
class QuizController extends ChangeNotifier {
  QuizController({QuizRepository? repository}) : _repo = repository ?? QuizRepository();

  final QuizRepository _repo;

  // ===== الإعداد =====
  String subject = "";
  int grade = 3;
  String track = "علمي";
  String unit = "";
  List<String> lessons = const [];
  int count = 10;

  // ===== الحالة =====
  bool isGenerating = false;
  String? error;
  bool quotaExceeded = false;
  bool isGuest = false;

  List<QuizQuestion> questions = const [];
  int index = 0;
  int? selected;
  bool confirmed = false;
  int score = 0;

  /// إجابة الطالب لكل سؤال — تُستعمل في شاشة «راجع إجاباتك».
  final List<int?> answers = [];
  final List<WrongAnswer> _wrong = [];

  DateTime? _startedAt;

  QuizQuestion get current => questions[index];
  bool get isLast => index >= questions.length - 1;
  bool get isFinished => questions.isNotEmpty && index >= questions.length;
  int get total => questions.length;
  int get percent => total == 0 ? 0 : ((score / total) * 100).round();

  // ══════════════ التوليد ══════════════

  Future<bool> generate() async {
    isGenerating = true;
    error = null;
    quotaExceeded = false;
    notifyListeners();

    try {
      final gen = await _repo.generate(
        subject: subject,
        grade: grade,
        track: track,
        unit: unit,
        lessons: lessons,
        count: count,
        idToken: await UserSession.I.idToken(),
        userId: UserSession.I.uid,
      );

      if (gen.isEmpty) {
        error = gen.message ?? "تعذّر تجهيز الأسئلة. حاول مرة أخرى.";
        quotaExceeded = gen.quotaExceeded;
        isGuest = gen.isGuest;
        return false;
      }

      questions = gen.questions;
      if (gen.unit.isNotEmpty) unit = gen.unit;
      if (gen.lessons.isNotEmpty) lessons = gen.lessons;
      _reset();
      return true;
    } catch (_) {
      error = "📡 تعذّر الاتصال بالخادم. تأكد من الإنترنت وحاول مجدداً.";
      return false;
    } finally {
      isGenerating = false;
      notifyListeners();
    }
  }

  void _reset() {
    index = 0;
    selected = null;
    confirmed = false;
    score = 0;
    answers.clear();
    _wrong.clear();
    _startedAt = DateTime.now();
  }

  // ══════════════ اللعب ══════════════

  void select(int i) {
    if (confirmed) return;      // بعد التأكيد لا تغيير
    selected = i;
    notifyListeners();
  }

  /// يؤكّد الإجابة ويعيد: هل كانت صحيحة؟
  bool confirm() {
    if (confirmed || selected == null) return false;
    confirmed = true;
    answers.add(selected);

    final ok = current.isCorrect(selected);
    if (ok) {
      score++;
    } else {
      _wrong.add(WrongAnswer(
        topic: current.topic.isEmpty ? current.lesson : current.topic,
        lesson: current.lesson,
        unit: unit,
      ));
    }
    notifyListeners();
    return ok;
  }

  void next() {
    index++;
    selected = null;
    confirmed = false;
    notifyListeners();
  }

  // ══════════════ الحفظ ══════════════

  /// يحفظ النتيجة محلياً ويرفعها بلا انتظار. يعيد النتيجة المحفوظة.
  Future<QuizResult> saveResult() async {
    final result = QuizResult(
      id: const Uuid().v4(),
      subject: subject,
      grade: grade,
      track: track,
      unit: unit,
      lessons: lessons,
      score: score,
      total: total,
      wrong: List.of(_wrong),
      // 🧮 كم سؤالاً جاء من كل درس — أساس قياس الضعف نسبةً لا عدداً
      askedPerLesson: _askedPerLesson(),
      durationSec: _startedAt == null ? 0 : DateTime.now().difference(_startedAt!).inSeconds,
    );

    await QuizStorage.save(result, ownerUid: UserSession.I.uid);
    SyncService.I.pushResult(result);      // fire-and-forget
    return result;
  }

  /// توزيع أسئلة هذا الاختبار على دروسها.
  Map<String, int> _askedPerLesson() {
    final counts = <String, int>{};
    for (final q in questions) {
      final key = q.lesson.isEmpty ? unit : q.lesson;
      if (key.isEmpty) continue;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  /// إعادة الاختبار بنفس الإعدادات.
  Future<bool> retry() => generate();
}
