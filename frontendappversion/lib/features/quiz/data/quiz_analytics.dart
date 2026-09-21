import 'models/quiz_models.dart';

// ==========================================
// 📊 تحليل المستوى — من نتائج الاختبارات
// ==========================================
// كل ما يعرضه قسم التحليل يُشتقّ هنا **من Hive محلياً**: صفر قراءات سحابية،
// صفر انتظار شبكة، ويعمل بلا إنترنت ([31§7]).
//
// دوالٌّ خالصة (تأخذ قائمة وتُرجع أرقاماً) ⇒ قابلة للاختبار بلا Hive ولا واجهة.

/// إحصاء مادة واحدة.
class SubjectStats {
  final String subject;
  final int quizzes;
  final int totalQuestions;
  final int totalCorrect;
  final DateTime? lastAttempt;

  /// اتجاه التحسّن: الفرق بين متوسط آخر نصف ومتوسط أول نصف (نقاط مئوية).
  final int trend;

  /// نسبة **آخر خمسة اختبارات مرجّحةً بالأحدث** — وعليها يقوم التصنيف.
  final int currentPercent;

  /// كم اختباراً دخل في [currentPercent] — يُعرض كي لا تُقرأ النسبة مجرّدة.
  final int currentQuizzes;

  const SubjectStats({
    required this.subject,
    required this.quizzes,
    required this.totalQuestions,
    required this.totalCorrect,
    required this.trend,
    this.currentPercent = 0,
    this.currentQuizzes = 0,
    this.lastAttempt,
  });

  /// **متوسط سجلّك الكامل** — كل الأسئلة منذ أول اختبار. يُعرض كسجلّ،
  /// ولا يُبنى عليه التصنيف: طالبٌ تحسّن كان يبقى «يحتاج تركيزاً» شهوراً.
  int get percent => totalQuestions == 0 ? 0 : ((totalCorrect / totalQuestions) * 100).round();

  bool get isStrong => currentPercent >= 80;
  bool get isWeak => currentPercent < 50;

  /// ⚠️ التصنيف من [currentPercent] لا من متوسط العمر (قرار المالك):
  /// «مقياس المادة آخر خمسة اختبارات، والكفة الأرجح لآخرها».
  /// وإلا ناقض التصنيفُ قائمةَ نقاط الضعف على الشاشة نفسها: تلك مرجّحة
  /// بالأحدث فتقول «تحسّنت»، وهذا تراكميّ فيقول «يحتاج تركيزاً».
  String get label => switch (currentPercent) {
        >= 90 => "ممتاز",
        >= 80 => "جيد جداً",
        >= 65 => "جيد",
        >= 50 => "مقبول",
        _ => "يحتاج تركيزاً",
      };
}

/// مفهوم بعينه داخل درس، وكم مرة أخطأ فيه الطالب.
class TopicMiss {
  const TopicMiss(this.topic, this.misses);
  final String topic;
  final int misses;
}

/// نقطة ضعف قابلة للتصرّف: نعرف درسها ووحدتها فنفتحها في الشات مباشرة.
///
/// **مستويان عمداً** (قرار المالك): الصفّ الظاهر **درسٌ واحد** بمجموع أخطائه
/// من كل الاختبارات — فلا يتكرّر الدرس ولا تتشتّت مذاكرة الطالب. وبالضغط
/// عليه تنكشف [topics]: المفاهيم داخل الدرس مرتّبةً بالأكثر خطأً، ليعرف
/// **أين ضعفه بالضبط** لا في أي درس فحسب.
class WeakSpot {
  final String subject;
  final String lesson;
  final String unit;

  /// المفهوم الأكثر تكراراً — ملخّصٌ يُعرض في الصفّ المطوي.
  final String topic;

  /// مجموع الأخطاء في هذا الدرس عبر كل الاختبارات.
  final int misses;

  /// مجموع أسئلة هذا الدرس عبر كل الاختبارات.
  final int asked;

  /// 🔁 **أخطاؤك في آخر اختبارٍ لمس هذا الدرس** — لا مجموعَ العمر.
  ///
  /// 🔴 **علّةُ المالك (٢٠٢٦-٠٩-٢٢):** «لو عند الطالب ١٢ خطأً في الدرس،
  ///    ودخل مرّةً ثانية وسوّى ١٤ — يدوم الدرسُ نفسُه لأن أخطاءه كثيرة».
  ///    و[misses] مجموعٌ تراكميّ لا ينزل أبداً: من أخطأ ١٢ ثم **تحسّن**
  ///    فأخطأ ٢ يصير مجموعُه ١٤ فيتصدّر قائمةَ المراجعة بعد أن تحسّن،
  ///    ومن أتقن الدرس تماماً (٠ أخطاء) يبقى فيها بـ«١٢ خطأً» إلى الأبد.
  ///    ويرى الطالبُ رقماً لم يقع في جلسةٍ واحدة قطّ (١٢+١٤ = ٢٦).
  ///
  /// ✅ فالمراجعةُ تقيس **حالتَك الآن**: أخطاءُ آخر محاولة. من تحسّن نزل،
  ///    ومن أتقن خرج، ومن تدهور ظهر برقمه الحقيقيّ (١٤ لا ٢٦).
  final int recentMisses;

  /// أسئلةُ آخر محاولةٍ على هذا الدرس — قرينةُ [recentMisses].
  final int recentAsked;

  /// ⚠️ **اسمٌ مستعارٌ من الوحدة لا اسمُ درسٍ حقيقيّ.**
  ///
  /// خطأٌ يصل بلا اسم درس يُنسب إلى **وحدته** كي لا يضيع من الإحصاء —
  /// وهو الصواب في التحليل. لكنه **ليس درساً في المنهج**، فشاشةُ إعداد
  /// الاختبار لا تجده فتُسقطه بصمت. فتَعِد ورقةُ المراجعة بثلاثة دروس
  /// ويبدأ الاختبارُ باثنين، بلا كلمةٍ للطالب.
  final bool fromUnitFallback;

  /// **نسبة الخطأ 0–100 مرجّحةً بالأحدث** — وعليها يقوم الترتيب.
  final int errorRate;

  /// تفصيل المفاهيم داخل الدرس، الأكثر خطأً أولاً.
  final List<TopicMiss> topics;

  const WeakSpot({
    required this.subject,
    required this.lesson,
    required this.unit,
    required this.topic,
    required this.misses,
    this.asked = 0,
    this.recentMisses = 0,
    this.recentAsked = 0,
    this.fromUnitFallback = false,
    this.errorRate = 0,
    this.topics = const [],
  });
}

/// محاولة واحدة على درس: كم سُئل وكم أخطأ فيها.
class _Attempt {
  const _Attempt(this.asked, this.wrong);
  final int asked;
  final int wrong;
}

/// عدّاد درسٍ واحد عبر محاولاته — يحوّلها إلى [WeakSpot] بنسبة مرجّحة.
class _LessonTally {
  _LessonTally({required this.subject, required this.lesson, required this.unit});

  final String subject;
  final String lesson;
  final String unit;

  /// المحاولات **مرتّبة بالأحدث أولاً** — الترتيب هو ما يعطي الترجيح معناه.
  final List<_Attempt> attempts = [];
  final Map<String, int> topics = {};

  /// هل جاء هذا الاسمُ مرّةً واحدةً على الأقل **باسم درسٍ حقيقي**؟
  bool namedByLesson = false;

  int get misses => attempts.fold(0, (n, a) => n + a.wrong);
  int get asked => attempts.fold(0, (n, a) => n + a.asked);

  /// آخرُ محاولةٍ على هذا الدرس — والقائمةُ **مرتّبةٌ بالأحدث أولاً**.
  int get recentMisses => attempts.isEmpty ? 0 : attempts.first.wrong;
  int get recentAsked => attempts.isEmpty ? 0 : attempts.first.asked;

  /// نسبة الخطأ 0–100.
  ///
  /// **ترجيحٌ بالأحدث:** المحاولة الأحدث وزنها ١، وما قبلها ½، ثم ¼… فمن
  /// ذاكر الدرس وأعاد الاختبار تنزل نسبته سريعاً ويخرج من القائمة —
  /// وهو المطلوب. عدُّ الأخطاء المجرّد كان يفعل العكس: كلما اختبرت الدرس
  /// أكثر تراكمت أخطاؤه فبقي متصدّراً وإن تحسّنت.
  ///
  /// **وتنعيم لابلاس** (`+1` و`+2`): يمنع سؤالاً واحداً أخطأ فيه الطالب من
  /// أن يصير «١٠٠٪ ضعف» ويتصدّر على درسٍ أخطأ فيه ٨ من ١٠. العيّنة الصغيرة
  /// تُسحب نحو المنتصف حتى تكبر.
  int get errorRate {
    var wWrong = 0.0, wAsked = 0.0, w = 1.0;
    for (final a in attempts) {
      wWrong += w * a.wrong;
      // درسٌ سُجّل خطؤه بلا عدد أسئلة (نتيجة قديمة) ⇒ لا تقلّ أسئلته عن أخطائه
      wAsked += w * (a.asked > 0 ? a.asked : a.wrong);
      w /= 2;
    }
    if (wAsked <= 0) return 0;
    return (((wWrong + 1) / (wAsked + 2)) * 100).round().clamp(0, 100);
  }

  WeakSpot toSpot() {
    final sorted = topics.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return WeakSpot(
      subject: subject,
      lesson: lesson,
      unit: unit,
      topic: sorted.isEmpty ? "" : sorted.first.key,
      misses: misses,
      asked: asked,
      recentMisses: recentMisses,
      recentAsked: recentAsked,
      fromUnitFallback: !namedByLesson,
      errorRate: errorRate,
      topics: sorted.map((e) => TopicMiss(e.key, e.value)).toList(),
    );
  }
}

/// ترتيبُ قائمة نقاط الضعف — **ومقياسُها هو ما تعرضه الشاشة**.
///
/// شاشاتُ التحليل تعرض **نسبةَ الخطأ** في شارةٍ مئوية، فترتيبُها بها.
/// وورقةُ المراجعة تعرض **عددَ أخطاء آخر محاولة**، فترتيبُها به
/// ([QuizAnalytics.reviewSpots] وفيها العلّةُ كاملةً).
enum WeakOrder { errorRate, recentMisses }

class QuizAnalytics {
  QuizAnalytics._();

  // ══════════════ ملخّص عام ══════════════

  static int totalQuizzes(List<QuizResult> rs) => rs.length;

  static int totalQuestions(List<QuizResult> rs) =>
      rs.fold(0, (n, r) => n + r.total);

  static int totalCorrect(List<QuizResult> rs) => rs.fold(0, (n, r) => n + r.score);

  /// المعدل العام: يُحسب من **مجموع الأسئلة** لا من متوسط النِّسب،
  /// وإلا ساوى اختبارٌ من 5 أسئلة اختباراً من 15.
  static int overallPercent(List<QuizResult> rs) {
    final q = totalQuestions(rs);
    return q == 0 ? 0 : ((totalCorrect(rs) / q) * 100).round();
  }

  /// أيام متتالية فيها اختبار واحد على الأقل (حتى اليوم).
  static int streakDays(List<QuizResult> rs, {DateTime? now}) {
    if (rs.isEmpty) return 0;
    final today = _dayOf(now ?? DateTime.now());
    final days = rs.map((r) => _dayOf(r.createdAt)).toSet();
    var streak = 0;
    var cursor = today;
    // يُسمح بأن يكون آخر اختبار أمس (اليوم لم ينتهِ بعد).
    if (!days.contains(cursor)) cursor = cursor.subtract(const Duration(days: 1));
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

  // ══════════════ لكل مادة ══════════════

  static List<SubjectStats> bySubject(List<QuizResult> rs) {
    final groups = <String, List<QuizResult>>{};
    for (final r in rs) {
      groups.putIfAbsent(r.subject, () => []).add(r);
    }

    final out = groups.entries.map((e) {
      final list = [...e.value]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final level = _currentLevel(list);
      return SubjectStats(
        subject: e.key,
        quizzes: list.length,
        totalQuestions: totalQuestions(list),
        totalCorrect: totalCorrect(list),
        trend: _trend(list),
        currentPercent: level.$1,
        currentQuizzes: level.$2,
        lastAttempt: list.last.createdAt,
      );
    }).toList();

    out.sort((a, b) => b.currentPercent.compareTo(a.currentPercent));
    return out;
  }

  /// نافذة التصنيف: **آخر خمسة اختبارات** (قرار المالك).
  static const int levelWindow = 5;

  /// (النسبة، عدد الاختبارات) لآخر [levelWindow] اختبارات، **مرجّحةً بالأحدث**.
  ///
  /// الأوزان `1, ½, ¼, ⅛, 1/16` — فالاختبار الأحدث يحمل نحو **٥٢٪** من القرار
  /// والأربعة الباقية **٤٨٪**: «الكفة الأرجح لآخر اختبار، ولكن الأربعة
  /// البقية لهم حمل في النسبة».
  ///
  /// ولمَ لا آخر اختبار وحده؟ لأن اختباراً واحداً حظّه سيء (أو سهل) كان يقلب
  /// تصنيف المادة كلَّه؛ والنافذة تجعل القلب ممكناً لكن لا مجّانياً. وهي
  /// تُغني عن حارس العيّنة: اختبار الخمسة أسئلة لا يقرّر وحده لأن الأربعة
  /// التي قبله باقيةٌ في الحساب.
  static (int, int) _currentLevel(List<QuizResult> chronological) {
    var wCorrect = 0.0, wTotal = 0.0, w = 1.0, used = 0;
    for (final r in chronological.reversed) {
      if (used >= levelWindow) break;
      wCorrect += w * r.score;
      wTotal += w * r.total;
      w /= 2;
      used++;
    }
    if (wTotal <= 0) return (0, used);
    return (((wCorrect / wTotal) * 100).round().clamp(0, 100), used);
  }

  /// أقلُّ عددِ أسئلةٍ يصحّ أن يُقاس عليه اتجاهُ التحسّن في **كل نصف**.
  ///
  /// 🔴 **بلا هذا يكذب السطرُ على الطالب:** اختبارٌ من **سؤالٍ واحد** أخطأه
  ///    ثم اختبارٌ من خمسة عشر أصابها كلَّها كان يعطي «📈 تحسّنت **١٠٠**
  ///    نقطة عن اختباراتك الأولى» — جملةٌ قاطعةٌ مبنيّةٌ على سؤالٍ واحد.
  ///    والعكسُ أقسى: سؤالٌ واحدٌ أصابه ثم اختبارٌ متوسط ⇒ «📉 نزلت ٤٠ نقطة».
  static const int trendMinQuestions = 5;

  /// فرق النصف الأخير عن النصف الأول (نقاط مئوية). يحتاج اختبارين فأكثر،
  /// و[trendMinQuestions] سؤالاً في كل نصف — وإلا فلا اتجاهَ يُعلن.
  static int _trend(List<QuizResult> chronological) {
    if (chronological.length < 2) return 0;
    final mid = chronological.length ~/ 2;
    final first = chronological.sublist(0, mid);
    final last = chronological.sublist(mid);
    if (totalQuestions(first) < trendMinQuestions ||
        totalQuestions(last) < trendMinQuestions) {
      return 0;   // ⚖️ صمتٌ خيرٌ من رقمٍ واثقٍ بلا أساس
    }
    return overallPercent(last) - overallPercent(first);
  }

  static SubjectStats? bestSubject(List<QuizResult> rs) {
    final s = bySubject(rs);
    return s.isEmpty ? null : s.first;
  }

  static SubjectStats? weakestSubject(List<QuizResult> rs) {
    final s = bySubject(rs);
    return s.isEmpty ? null : s.last;
  }

  // ══════════════ نقاط الضعف ══════════════

  /// أضعف الدروس — **صفٌّ واحد لكل درس**، مرتّبة تنازلياً بمجموع الأخطاء.
  ///
  /// ⚠️ **التجميع بالدرس لا بالمفهوم** (قرار المالك): كان المفتاح يضمّ
  ///    `topic`، فيظهر الدرس الواحد مرّةً لكل مفهومٍ أخطأ فيه الطالب —
  ///    «خلايا خزن الطاقة» ستّ مرات وهي درسٌ واحد. الطالب يقرأ ذلك «ستّ
  ///    نقاط ضعف» فتتشتّت مذاكرته. والآن تُجمَع أخطاء الدرس **من كل
  ///    الاختبارات**، وتُحفظ المفاهيم في [WeakSpot.topics] لمن يريد التفصيل.
  ///
  /// ★ هذه هي مدخلات «الحلقة الذهبية»: زر «اشرح لي» يفتح `lesson` في الشات.
  ///
  /// **الترتيب بنسبة الخطأ لا بعددها** (قرار المالك): العدّ المجرّد يجعل
  /// أكثر الدروس اختباراً أكثرها «ضعفاً» ولو تحسّن الطالب فيه. راجع
  /// [_LessonTally.errorRate] لتفصيل الترجيح والتنعيم.
  static List<WeakSpot> weakSpots(List<QuizResult> rs,
      {int limit = 5, WeakOrder order = WeakOrder.errorRate}) {
    // الأحدث أولاً — عليه يقوم ترجيح النسبة.
    final sorted = [...rs]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final byLesson = <String, _LessonTally>{};

    for (final r in sorted) {
      // أخطاء هذا الاختبار موزّعةً على دروسها
      final wrongs = <String, int>{};
      final unitOf = <String, String>{};
      // 🏷️ أسماءٌ استُعيرت من الوحدة لأن الخطأ وصل بلا اسم درس.
      final borrowed = <String>{};
      for (final w in r.wrong) {
        final lesson = w.lesson.isEmpty ? r.unit : w.lesson;
        if (w.lesson.isEmpty) borrowed.add(lesson);
        wrongs[lesson] = (wrongs[lesson] ?? 0) + 1;
        unitOf[lesson] = w.unit.isEmpty ? r.unit : w.unit;
      }

      // ⭐ الدروس التي **سُئل عنها** لا التي أخطأ فيها فقط: بدونها لا تنزل
      //    نسبةُ درسٍ أعاد الطالب اختباره ونجح فيه — فيبقى «ضعيفاً» ظلماً.
      final lessons = {...r.lessonsAsked, ...wrongs.keys};

      for (final lesson in lessons) {
        if (lesson.isEmpty) continue;
        final tally = byLesson.putIfAbsent(
          "${r.subject}|$lesson",
          () => _LessonTally(
            subject: r.subject,
            lesson: lesson,
            unit: unitOf[lesson] ?? r.unit,
          ),
        );
        if (!borrowed.contains(lesson) || r.lessonsAsked.contains(lesson)) {
          tally.namedByLesson = true;
        }
        tally.attempts.add(_Attempt(r.askedFor(lesson), wrongs[lesson] ?? 0));
      }

      for (final w in r.wrong) {
        if (w.topic.isEmpty) continue;
        final lesson = w.lesson.isEmpty ? r.unit : w.lesson;
        final tally = byLesson["${r.subject}|$lesson"];
        if (tally == null) continue;
        tally.topics[w.topic] = (tally.topics[w.topic] ?? 0) + 1;
      }
    }

    // درسٌ بلا خطأ واحد ليس نقطة ضعف مهما كثرت أسئلته.
    //
    // ⚠️ **والمعيارُ يتبع الترتيب**: قائمةُ المراجعة تقيس آخر محاولة، فدرسٌ
    //    أتقنه الطالبُ في آخر اختبارٍ يخرج منها — ولو كان في سجلّه القديم
    //    عشرةُ أخطاء. أما قوائمُ التحليل فتعرض سجلَّه كما هو.
    final list = byLesson.values
        .where((t) => order == WeakOrder.recentMisses
            // 🏷️ واسمٌ مستعارٌ من الوحدة لا يصلح درساً لاختبار
            //    ([WeakSpot.fromUnitFallback]).
            ? t.recentMisses > 0 && t.namedByLesson
            : t.misses > 0)
        .map((t) => t.toSpot())
        .toList()
      ..sort((a, b) => switch (order) {
            // نسبةُ الخطأ أولاً، وعددُ الأخطاء يفكّ التعادل.
            WeakOrder.errorRate => b.errorRate.compareTo(a.errorRate) != 0
                ? b.errorRate.compareTo(a.errorRate)
                : b.misses.compareTo(a.misses),
            // أخطاءُ آخر محاولةٍ أولاً، والنسبةُ تفكّ التعادل.
            WeakOrder.recentMisses =>
              b.recentMisses.compareTo(a.recentMisses) != 0
                  ? b.recentMisses.compareTo(a.recentMisses)
                  : b.errorRate.compareTo(a.errorRate),
          });
    return list.take(limit).toList();
  }

  // ══════════════════════════════════════════════════
  // 📅 دروسُ اختبار المراجعة
  // ══════════════════════════════════════════════════
  //
  // 🔴 **قاعدةُ المالك (٢٠٢٦-٠٩-٢٢) حرفياً:** «لما تدخل اختبار المراجعة
  //    يطلع لك **أكثر ثلاثة دروس فيها أخطاء** من كل مادة **بالترتيب**.
  //    أقصى شي ثلاثة دروس. لو اختبرت في عشرة دروس وأكثر ثلاثة فيها أخطاء
  //    يطلعها لي عشان نقدر نراجعها.»
  //
  // 🐞 **وما كان يقع فعلاً** (مقيسٌ من جهاز المالك، مادة الأحياء بخمسة
  //    اختبارات — والورقةُ تعرض **عددَ الأخطاء** على كل صفّ):
  //
  //    | تُعرض؟ | النسبة | الأخطاء | سُئل | الدرس |
  //    |---|---|---|---|---|
  //    | ✅ ١ | 75٪ | **٢** | ٢ | المستقبلات الضوئية في العين |
  //    | ✅ ٢ | 69٪ | ٥ | ٧ | السيال العصبي |
  //    | ✅ ٣ | 67٪ | ٧ | ١٠ | التكاثر الخضري |
  //    | ❌ | 62٪ | **١٤** | ٢٠ | التنظيم العصبي في وحيدة الخلية |
  //
  //    فالدرسُ الذي أخطأ فيه **أربع عشرة مرة** يسقط من الورقة، ويتصدّرها
  //    درسٌ أخطأ فيه **مرّتين** — والأرقامُ المعروضة نفسُها تصعد ٢ ← ٥ ← ٧
  //    أمام عينه. هذا ما سمّاه «مخبوط»، وهو محقّ.
  //
  // ⚖️ **والسببُ لا العطل:** الترتيبُ كان بنسبة الخطأ (مرجّحةً بالأحدث
  //    ومنعَّمةً بلابلاس)، والورقةُ تعرض العدد — مقياسان مختلفان في شاشةٍ
  //    واحدة. والنسبةُ على عيّنةٍ صغيرة مضلّلة أصلاً: درسٌ سُئل عنه سؤالان
  //    فأخطأهما = 75٪، ودرسٌ سُئل عنه عشرون فأخطأ أربعةَ عشر = 62٪.
  //
  // ✅ فصار للمراجعة ترتيبُها: **الأكثرُ أخطاءً أولاً**، والنسبةُ تفكّ
  //    التعادل — وهو الترتيبُ الذي تُظهره الورقةُ بأرقامها.
  //
  // 🔁 **وأخطاءُ آخرِ محاولةٍ لا مجموعُ العمر** ([WeakSpot.recentMisses]):
  //    المجموعُ التراكميّ لا ينزل أبداً، فمن تحسّن يتصدّر ومن أتقن يبقى.
  //    وهذا ما نبّه إليه المالكُ حين سأل عن القسم كلِّه.
  //
  // ⚠️ **ولا يُمَسّ ترتيبُ شاشات التحليل**: شاراتُها **نسبةٌ مئوية** لا
  //    عدداً، فترتيبُها بالنسبة متّسقٌ مع ما تعرضه.
  static List<WeakSpot> reviewSpots(List<QuizResult> rs, String subject,
          {int limit = 3}) =>
      weakSpots(rs.where((r) => r.subject == subject).toList(),
          limit: limit, order: WeakOrder.recentMisses);

  /// الدروس المرشّحة لاختبار مراجعة في مادة معيّنة.
  static List<String> reviewLessons(List<QuizResult> rs, String subject, {int limit = 3}) =>
      reviewSpots(rs, subject, limit: limit)
          .map((w) => w.lesson)
          .where((l) => l.isNotEmpty)
          .toSet()
          .take(limit)
          .toList();

  // ══════════════ التقدّم الزمني ══════════════

  /// نسب آخر [count] اختبارات بالترتيب الزمني — لرسم خط التقدّم.
  static List<int> recentPercents(List<QuizResult> rs, {int count = 10}) {
    final sorted = [...rs]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final tail = sorted.length <= count ? sorted : sorted.sublist(sorted.length - count);
    return tail.map((r) => r.percent).toList();
  }
}
