import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../core/quota/quota_repository.dart';
import '../../../core/session/user_session.dart';
import '../../../core/sync/sync_service.dart';
import '../data/models/quiz_models.dart';
import '../data/quiz_repository.dart';
import '../data/quiz_resume_store.dart';
import '../data/quiz_seen_store.dart';
import '../data/quiz_storage.dart';

// ==========================================
// 🧠 متحكّم جلسة الاختبار
// ==========================================
// يحمل الأسئلة في الذاكرة (لا تُخزَّن أبداً)، ويحفظ **النتيجة** فقط عند
// الانتهاء: محلياً أولاً ثم نسخة سحابية بلا انتظار ([31§6]).
class QuizController extends ChangeNotifier {
  QuizController({QuizRepository? repository})
    : _repo = repository ?? QuizRepository();

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

  /// 🧾 معرّف محاولة التوليد الجارية — ثابتٌ عبر إعادات المحاولة.
  String _requestId = "";
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

  /// 🏁 انتهى الاختبار وحُسبت نتيجتُه — لا لقطةَ تُكتب بعدها.
  bool _completed = false;

  /// 🔒 حفظُ النتيجة يقع **مرةً واحدة**: النقرةُ الثانية على «عرض النتيجة»
  ///    تنتظر نفسَ العملية بدل أن تُطلق ثانيةً ([saveResult]).
  Future<QuizResult>? _saving;

  /// هل حُفظت نتيجةُ هذا الاختبار (أو هي قيد الحفظ)؟ — للواجهة.
  bool get isSavingResult => _saving != null;

  QuizQuestion get current => questions[index];
  bool get isLast => index >= questions.length - 1;
  bool get isFinished => questions.isNotEmpty && index >= questions.length;
  int get total => questions.length;
  int get percent => total == 0 ? 0 : ((score / total) * 100).round();

  // ══════════════ التوليد ══════════════

  Future<bool> generate({bool retryAttempt = false}) async {
    isGenerating = true;
    error = null;
    quotaExceeded = false;
    if (!retryAttempt || _requestId.isEmpty) _requestId = const Uuid().v4();
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
        // 🧾 معرّف هذه المحاولة: إعادةُ التوليد بعد مهلةٍ لا تخصم حصةً ثانية
        //    ولا تُنادي الموديل مرتين ([Backend/core/idempotency.py]).
        requestId: _requestId,
        // 🔁 ذاكرةُ «لا تُعده عليّ» — بلا هذا يعيد الاختبارُ نفسَه حرفياً
        //    على من كرّره ليتحسّن، فيصير امتحانَ حفظٍ لا فهم.
        seenIds: await QuizSeenStore.read(
          UserSession.I.uid,
          QuizSeenStore.scopeOf(subject, lessons),
        ),
      );

      if (gen.isEmpty) {
        error = gen.message ?? "تعذّر تجهيز الأسئلة. حاول مرة أخرى.";
        quotaExceeded = gen.quotaExceeded;
        isGuest = gen.isGuest;
        // 🎟️ وعند تجاوز الحصة نسأل الخادم فوراً كي يظهر «٠» لا رقمٌ قديم.
        if (gen.quotaExceeded) unawaited(QuotaRepository.I.refresh(force: true));
        return false;
      }

      questions = gen.questions;
      if (gen.unit.isNotEmpty) unit = gen.unit;
      if (gen.lessons.isNotEmpty) lessons = gen.lessons;
      _reset();
      // 🔓 اختبارٌ جديد ⇒ يُفتح الحساب للقطات بعد ختمِ الاختبار السابق.
      QuizResumeStore.unseal(UserSession.I.uid);
      // 🎟️ **والعدّاد ينزل هنا كما ينزل في المحادثة** — كان الاختبار
      //    يخصم على الخادم ولا يمسّ الرقم المعروض، فيبقى الطالب يرى
      //    حصةً أكبر من حقيقتها حتى يُعيد فتح التطبيق.
      //
      // ⚖️ وما ردّه الخادمُ لا يُخصم: اختبارٌ من البنك لا يكلّف نداءً
      //    فتُردّ حصّتُه ويصل `quota_refunded` ([core/billing.py]).
      if (!gen.quotaRefunded) QuotaRepository.I.consumeOne();
      // ⏸️ لقطةٌ فور التوليد: خروجٌ قبل أول إجابة يبقى قابلاً للاستئناف —
      //    وهو أهمّ ما يُحفظ، فالأسئلة نفسها كلّفت حصةً ونداءَ موديل.
      _persistProgress();
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
    _completed = false;
    _saving = null;
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
    if (confirmed) return; // بعد التأكيد لا تغيير
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
      _wrong.add(
        WrongAnswer(
          topic: current.topic.isEmpty ? current.lesson : current.topic,
          lesson: current.lesson,
          unit: unit,
        ),
      );
    }
    notifyListeners();
    return ok;
  }

  void next() {
    index++;
    selected = null;
    confirmed = false;
    notifyListeners();
    // ⏸️ لقطةٌ بعد كل سؤال: مكالمةٌ أو انقطاعُ نتٍّ أو قتلُ النظام للتطبيق
    //    في الخلفية كان يمحو الاختبار كاملاً — ويكلّف حصةً ثانية لإعادته.
    _persistProgress();
  }

  // ══════════════ ⏸️ الاستئناف ══════════════

  /// يحفظ لقطةً عن الاختبار الجاري — **محلياً ومؤقتاً** ([QuizResumeStore]).
  ///
  /// ⚠️ بلا `await`: هذا يقع في مسار نقرة الطالب، وربطُه بالقرص يجعل الزرّ
  ///    يتأخّر على أجهزةٍ بطيئة مقابل لا شيء.
  void _persistProgress() {
    // 🏁 و`isFinished` وحدها لا تكفي: هي `false` على **آخر** سؤال، وهناك
    //    بالضبط يضغط الطالب «عرض النتيجة». فالعلامةُ الصريحة هي الحارس.
    if (questions.isEmpty || isFinished || _completed) return;
    QuizResumeStore.save(
      QuizSnapshot(
        ownerUid: UserSession.I.uid,
        subject: subject,
        grade: grade,
        track: track,
        unit: unit,
        lessons: lessons,
        questions: questions,
        answers: List<int?>.of(answers),
        index: index,
        score: score,
        savedAt: DateTime.now(),
        startedAt: _startedAt ?? DateTime.now(),
      ),
    );
  }

  /// يستأنف اختباراً محفوظاً من حيث توقّف الطالب — **بلا نداء موديل ولا حصة**.
  void resumeFrom(QuizSnapshot snap) {
    subject = snap.subject;
    grade = snap.grade;
    track = snap.track;
    unit = snap.unit;
    lessons = snap.lessons;
    questions = snap.questions;

    index = snap.index;
    score = snap.score;
    selected = null;
    confirmed = false;

    answers
      ..clear()
      ..addAll(snap.answers);

    // ⚠️ نُعيد بناء قائمة الأخطاء من الإجابات المحفوظة لا نحفظها معها:
    //    مصدرٌ واحد للحقيقة، فلا تتناقض النتيجة مع تحليل نقاط الضعف.
    _wrong.clear();
    for (var i = 0; i < answers.length && i < questions.length; i++) {
      final q = questions[i];
      if (!q.isCorrect(answers[i])) {
        _wrong.add(
          WrongAnswer(
            topic: q.topic.isEmpty ? q.lesson : q.topic,
            lesson: q.lesson,
            unit: unit,
          ),
        );
      }
    }

    // ⏱️ المدّة تُحتسب من البداية الحقيقية لا من لحظة الاستئناف.
    _startedAt = snap.startedAt;
    _completed = false;
    _saving = null;
    QuizResumeStore.unseal(snap.ownerUid);
    notifyListeners();
  }

  // ══════════════ الحفظ ══════════════

  // ══════════════════════════════════════════════════
  // 🔒 **النتيجةُ تُحفظ مرةً واحدة** مهما تكرّرت النقرة
  // ══════════════════════════════════════════════════
  //
  // 🔴 **العطل:** `_finish()` في شاشة اللعب تُنادى من `onTap` بلا `await`
  //    ولا حارس، والزرُّ يبقى حيّاً طوال الحفظ (`c.confirmed` لا تتغيّر).
  //    فنقرتان متتاليتان على «عرض النتيجة 🏁» — وهي نقرةُ حماسٍ في نهاية
  //    الاختبار — تُنتجان:
  //      • **نتيجتين** في السجلّ بمعرّفين مختلفين: يرى الطالب اختباره
  //        مرتين في «تقدّمي»، ومتوسّطُه يُحسب على محاولةٍ وهمية.
  //      • رفعتين إلى السحابة ([SyncService.pushResult]).
  //      • شاشتَي نتيجةٍ مكدّستين (`pushReplacement` مرتين).
  //
  // ⚖️ **والحارسُ هنا لا في الواجهة وحدها:** الشاشةُ تحرس نفسها أيضاً،
  //    لكنّ سلامةَ السجلّ لا يجوز أن تتعلّق بمن ينادي. فالمستدعي الثاني
  //    ينتظر **نفسَ** العملية ويأخذ **نفسَ** النتيجة.
  Future<QuizResult> saveResult() => _saving ??= _saveResultOnce();

  /// يحفظ النتيجة محلياً ويرفعها بلا انتظار. يعيد النتيجة المحفوظة.
  Future<QuizResult> _saveResultOnce() async {
    // 🏁 قبل أي `await`: لقطةٌ معلّقة من آخر «التالي» لا تُحيي اختباراً
    //    انتهى — والطابورُ في [QuizResumeStore] يحفظ الترتيب بعدها.
    _completed = true;
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
      // 📋 **المراجعة**: السؤال وخياراته والصواب وما اختاره الطالب.
      //    بدونها يعرف الطالب أنه أخطأ ولا يعرف الصواب أبداً — وهي أخصب
      //    لحظة للتعلّم في المنتج كله وكانت تمرّ فارغة.
      reviewRaw: _buildReview(),
      durationSec: _startedAt == null
          ? 0
          : DateTime.now().difference(_startedAt!).inSeconds,
    );

    await QuizStorage.save(result, ownerUid: UserSession.I.uid);
    // 🔁 وتُقيَّد أسئلةُ هذه المحاولة كي لا تعود في التالية.
    await QuizSeenStore.remember(
      UserSession.I.uid,
      QuizSeenStore.scopeOf(subject, lessons),
      [
        for (final q in questions)
          if (q.id.isNotEmpty) q.id,
      ],
    );
    SyncService.I.pushResult(result); // fire-and-forget

    // 🧹 اكتمل الاختبار ⇒ لا لقطة تُستأنف. تركُها يعني زرّ «استأنف» يفتح
    //    اختباراً منتهياً — وهو أسوأ من غياب الميزة.
    //
    // 🔒 و`seal` تُغلق الباب على أي كتابةٍ **ما زالت في الطريق**: بلا ختمٍ
    //    كان المحوُ قد يسبقها فتُعيد كتابة اللقطة بعده.
    await QuizResumeStore.clear(UserSession.I.uid, seal: true);
    return result;
  }

  /// 📋 يبني مراجعة الاختبار من الأسئلة وإجابات الطالب.
  ///
  /// ⚠️ `answers` قد تكون أقصر من `questions` (اختبارٌ لم يكتمل)، فالسؤال
  ///    غير المُجاب يُسجَّل بـ`null` ويُعرض «لم تُجب» — لا يُحذف ولا يُعتبر
  ///    خطأً، فكلاهما يكذب على الطالب.
  List<String> _buildReview() {
    final out = <String>[];
    for (var i = 0; i < questions.length; i++) {
      final chosen = i < answers.length ? answers[i] : null;
      out.add(jsonEncode(QuizReviewItem.from(questions[i], chosen).toJson()));
    }
    return out;
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
  Future<bool> retry() => generate(retryAttempt: true);
}
