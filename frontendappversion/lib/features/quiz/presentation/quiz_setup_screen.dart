import 'package:flutter/material.dart';

import '../../../core/config/curriculum.dart';
import '../../../core/session/user_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/masar_brand.dart';
import '../../../core/widgets/modern_dropdown.dart';
import '../../../core/widgets/phosphor.dart';
import '../../chat/data/models/subject_capabilities.dart';
import '../../chat/data/repositories/tutor_content_repository.dart';
import '../data/quiz_resume_store.dart';
import 'quiz_controller.dart';
import 'quiz_play_screen.dart';
import 'widgets/quiz_ui.dart';

// ==========================================
// ⚙️ إعداد الاختبار — صف → مادة → وحدة → حتى 3 دروس → عدد الأسئلة
// ==========================================
// مدخلان يقودان إليها ([31§4]):
//   🏠 كرت «اختبر نفسك» في الرئيسية (الطالب يختار كل شيء)
//   💬 وضع «اختبارات» داخل المادة (المادة والصف محدَّدان مسبقاً)
//
// الوحدات والدروس تأتي من `/content/capabilities` — **نفس مصدر شاشة الشات**،
// فلا قائمة مكتوبة يدوياً ولا استثناء لمادة.
//
// 🎨 **إعادة التصميم (Figma · `design/05-quiz/03-اختبر نفسك`):** رأسٌ
//    بعنوانٍ وأيقونة · فقاعةُ روبوت · ثلاث بطاقاتٍ بيضاء (المادة · الدروس ·
//    عدد الأسئلة) · وزرٌّ أزرقُ بعرض الصفحة. **لم يتغيّر شيءٌ من المنطق**:
//    المصدرُ نفسه والنداءُ نفسه والمتحكّمُ نفسه — تغيّر الرسمُ وحده.
//
// ⛔ **الشريطُ المقسوم `[الاختبار الوزاري] [تحليل مستواي]` حُذف بقرار
//    المالك (2026-09-20):** «ما في الكلام هذا… اختبر نفسك فيها تو على
//    طول». وتحليلُ المستوى يُدخل إليه من «معلومات الطالب» لا من هنا.
//
// ✅ **وما أبقاه المالك صراحةً:** بطاقةُ «لديك اختبار لم يكتمل» — «خليها
//    موجودة وضبطها مع التصميم الجديد… لأنها ممتازة جداً».
class QuizSetupScreen extends StatefulWidget {
  final String? initialSubject;
  final int? initialGrade;
  final String? initialTrack;

  /// دروس مقترحة مسبقاً (اختبار مراجعة من قسم التحليل).
  final List<String>? presetLessons;
  final String? presetUnit;

  /// يُحقن في الاختبارات فقط؛ الإنتاج ينشئ المستودع بنفسه.
  final TutorContentRepository? repository;

  const QuizSetupScreen({
    super.key,
    this.initialSubject,
    this.initialGrade,
    this.initialTrack,
    this.presetLessons,
    this.presetUnit,
    this.repository,
  });

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  static const int maxLessons = 3;

  late final _content = widget.repository ?? TutorContentRepository();

  late int _grade;
  late Track _track;
  late String _subject;
  String _unit = "";

  /// الدروس المختارة **عبر الوحدات كلها** — لا وحدةً واحدة.
  /// ⚠️ كان تغيير الوحدة يمسحها، فيتعذّر اختبار درسين من وحدتين. وهذا
  ///    بالضبط ما كان يكسر «اختبار المراجعة»: أضعف دروسك قد تكون موزّعة.
  final Set<String> _lessons = {};

  /// وحدة كل درس مختار — نحتاجها لأن الدرس قد يأتي من وحدة غير المعروضة.
  final Map<String, String> _lessonUnit = {};
  int _count = 10;

  SubjectCapabilities? _caps;
  bool _loading = true;

  /// ⚠️ فشل الاتصال ≠ «لا توجد دروس». الخلط بينهما يجعل التطبيق يكذب على
  ///    الطالب ويقول إن مادته فارغة بينما دروسها موجودة (حدث فعلاً مع خادم
  ///    قديم لم يكن يرسل `quiz.available`).
  bool _loadFailed = false;

  /// ⏸️ اختبارٌ لم يكتمل — يُعرض في أعلى الشاشة إن وُجد.
  QuizSnapshot? _resumable;

  @override
  void initState() {
    super.initState();
    // ⏸️ نسأل عن لقطةٍ محفوظة بلا أن نؤخّر بناء الشاشة.
    QuizResumeStore.read(UserSession.I.uid).then((snap) {
      if (mounted && snap != null) setState(() => _resumable = snap);
    });
    _grade = widget.initialGrade ?? UserSession.I.grade;
    _track = Curriculum.normalizeTrack(
        _grade, TrackLabel.fromKey(widget.initialTrack ?? UserSession.I.track));
    _subject = widget.initialSubject ?? Curriculum.defaultSubject(_grade, _track);
    _loadCaps();
  }

  Future<void> _loadCaps() async {
    setState(() {
      _loading = true;
      _loadFailed = false;
    });
    try {
      final caps = await _content.getCapabilities(_subject, _grade, _track.key);
      if (!mounted) return;
      setState(() {
        _caps = caps;
        final units = caps.unitsWithLessons;
        _unit = widget.presetUnit != null && units.contains(widget.presetUnit)
            ? widget.presetUnit!
            : (units.isEmpty ? "" : units.first);
        // ⭐ الدروس المقترحة تُقبل **من أي وحدة**: أضعف دروس الطالب موزّعة
        //    بطبيعتها، وتقييدها بوحدة الأولى كان يُسقط الباقي بصمت.
        _lessons.clear();
        _lessonUnit.clear();
        for (final l in (widget.presetLessons ?? const <String>[])) {
          if (_lessons.length >= maxLessons) break;
          final home = caps.unitOfLesson(l);
          if (home == null) continue;
          _lessons.add(l);
          _lessonUnit[l] = home;
        }
        // نفتح على وحدة أول درس مقترح كي يراه الطالب مؤشَّراً
        if (_lessons.isNotEmpty) _unit = _lessonUnit[_lessons.first]!;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  List<String> get _units => _caps?.unitsWithLessons ?? const [];
  List<String> get _unitLessons => _caps?.lessonsIn(_unit) ?? const [];
  bool get _ready => _caps?.quizAvailable == true && _lessons.isNotEmpty;

  void _setSubject(String s) {
    setState(() {
      _subject = s;
      _lessons.clear();
      _lessonUnit.clear();
    });
    _loadCaps();
  }

  void _toggleLesson(String l) {
    setState(() {
      if (_lessons.contains(l)) {
        _lessons.remove(l);
        _lessonUnit.remove(l);
      } else if (_lessons.length >= maxLessons) {
        _snack("يمكنك اختيار $maxLessons دروس كحد أقصى 📚");
      } else {
        _lessons.add(l);
        _lessonUnit[l] = _unit;
      }
    });
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.warning800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));

  Future<void> _start() async {
    final c = QuizController()
      ..subject = _subject
      ..grade = _grade
      ..track = _track.key
      // الخادم يبحث عن الدرس في وحدته وإلا في الكتاب كله، فتكفيه وحدة الأول.
      ..unit = _lessons.isEmpty ? _unit : (_lessonUnit[_lessons.first] ?? _unit)
      ..lessons = _lessons.toList()
      ..count = _count;

    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizPlayScreen(controller: c)),
    );
    if (!mounted) return;
    // 🔴 **وبدون هذا السطر لا تظهر البطاقةُ التي أبقاها المالك.** الخروجُ
    //    من اختبارٍ لم يكتمل **يكتب اللقطة**، ثم يعود الطالب إلى هذه
    //    الشاشة نفسِها — وهي محفوظةٌ حيّةً في `MasarShell` فلا يُعاد
    //    `initState`، فتبقى `_resumable` فارغةً حتى يُغلق التطبيق ويُفتح.
    //    (رُصد في المحاكي 2026-09-20.) و`_resume` كانت تفعلها منذ البدء.
    final snap = await QuizResumeStore.read(UserSession.I.uid);
    if (mounted) setState(() => _resumable = snap);
  }

  @override
  Widget build(BuildContext context) {
    // ⬅️ سهمٌ يرجع إلى شيء، أو لا سهمَ إطلاقاً. الشاشة تُعرض تبويباً داخل
    //    `MasarShell` (لا شيءَ خلفها) وتُفتح مدفوعةً من التحليل والمحادثة.
    //
    // 🔴 **`ModalRoute.isFirst` لا `Navigator.canPop()`** (بلاغ المالك
    //    ٢٠٢٦-٠٩-٢٤: «زرّ رجوع ظهر في اختبر نفسك، ضغطناه فشاشةٌ سوداء»).
    //    `canPop` يسأل **الملّاح كلّه**: هل فيه أكثرُ من مسار؟ والتبويبُ
    //    يُبنى داخل القشرة بينما النتيجةُ والتحليلُ مدفوعان فوقها — فيجيب
    //    «نعم» ويظهر سهمٌ يُسقط **القشرةَ نفسَها** من تحتها. والسؤالُ
    //    الصحيح: هل **مساري أنا** فوق شيء؟
    final canBack = ModalRoute.of(context)?.isFirst == false;

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        bottom: false,
        child: FadeInSlide(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                QuizMetrics.margin, 34, QuizMetrics.margin, 28),
            children: [
              QuizHeader(
                title: "اختبر نفسك",
                onBack: canBack ? () => Navigator.pop(context) : null,
              ),
              const SizedBox(height: 18),
              _greeting(),
              // ⏸️ أعلى الشاشة مباشرةً: أوّلُ ما يُفعل قبل إعدادِ اختبارٍ جديد.
              if (_resumable != null) ...[
                const SizedBox(height: QuizMetrics.gap),
                _resumeCard(_resumable!),
              ],
              // ⛔ **لا صفَّ ولا مسار هنا** (قرار المالك 2026-09-09):
              //    الطالب حدّدهما في إعداداته مرّةً واحدة، وإعادةُ سؤاله
              //    في كل شاشة تُقحم قراراً محسوماً — بل وتُغري بتغييره
              //    فيمتحن نفسه في منهجٍ ليس منهجه.
              //
              // ⭐ فتظهر **مواد صفّه مباشرةً**. وهي نفس القاعدة التي طُبّقت
              //    على القائمة الجانبية في قسم التعليم.
              const SizedBox(height: QuizMetrics.gap),
              _subjectCard(),
              const SizedBox(height: QuizMetrics.gap),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.6)),
                )
              else if (_loadFailed)
                _failedState()
              else if (_caps?.quizAvailable != true)
                _emptyState()
              else ...[
                _lessonsCard(),
                const SizedBox(height: QuizMetrics.gap),
                _countCard(),
                const SizedBox(height: QuizMetrics.gap),
                _startButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── 💬 الترحيب ─────────────────────────

  Widget _greeting() => QuizRobotBubble(
        // 🔴 كان هنا نصٌّ واحد فيه `**…**` داخل `Text` عادي، فكان
        //    الطالب يقرأ النجمتين كما هما على الشاشة (رُصد في المحاكي
        //    2026-09-13). والنصُّ ثابتٌ من عندنا، فأصدقُ علاجٍ أن
        //    يُكتب التوكيدُ توكيداً لا ترميزاً.
        child: Text.rich(
          TextSpan(children: const [
            TextSpan(text: "اختر دروسك وسأجهّز لك أسئلة "),
            TextSpan(
                text: "من الدرس نفسه",
                style: TextStyle(fontWeight: FontWeight.w900)),
            TextSpan(text: " — سهلة ثم أصعب."),
          ]),
          style: TextStyle(
              fontSize: 16,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: AppColors.panelTitle),
        ),
      );

  // ───────────────────── ⏸️ استئناف اختبار ─────────────────────
  //
  // 🔴 **ما كان يحدث:** مكالمةٌ أو انقطاعُ نتٍّ أو قتلُ النظام للتطبيق في
  //    الخلفية يمحو اختباراً وصل الطالب فيه للسؤال ١٢ من ١٥. ثم إعادته
  //    تخصم حصةً ثانية وتنادي الموديل مرةً أخرى — فيدفع الطالب (ويدفع
  //    المالك) ثمن مقاطعةٍ لم يخترها أحد.
  //
  // ⚠️ والاستئناف **بلا نداء موديل ولا خصم**: الأسئلة محفوظةٌ محلياً كما هي.
  //
  // 🎨 أُعيد رسمها بلغة التصميم الجديدة: بطاقةٌ r16 بحدٍّ أزرق وتعبئةٍ
  //    باهتة، وزرٌّ ممتلئٌ 40 وزرُّ تجاهلٍ نصّيّ — بلا أيقونات Material.

  Widget _resumeCard(QuizSnapshot snap) {
    return Container(
      padding: const EdgeInsets.all(QuizMetrics.cardPad),
      decoration: BoxDecoration(
        color: AppColors.quizTint,
        borderRadius: BorderRadius.circular(QuizMetrics.cardRadius),
        border: Border.all(color: AppColors.primary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(PI.playCircle.fill, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "لديك اختبار لم يكتمل",
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: AppColors.panelTitle),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "${snap.subject} · ${snap.unit.isEmpty ? 'دروس مختارة' : snap.unit}"
            " — باقٍ ${snap.remaining} من ${snap.questions.length} أسئلة",
            style: TextStyle(
                fontSize: 11,
                height: 1.6,
                fontWeight: FontWeight.w600,
                color: AppColors.chipInk),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: QuizPrimaryButton(
                  label: "أكمل",
                  icon: PI.play,
                  height: 40,
                  onTap: () => _resume(snap),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () async {
                  await QuizResumeStore.clear(UserSession.I.uid);
                  if (mounted) setState(() => _resumable = null);
                },
                child: Text("تجاهله",
                    style: TextStyle(
                        color: AppColors.chipInk,
                        fontSize: 12,
                        fontWeight: FontWeight.w800)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resume(QuizSnapshot snap) async {
    final c = QuizController()..resumeFrom(snap);
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuizPlayScreen(controller: c)),
    );
    if (!mounted) return;
    // 🔄 عند العودة: إن كان الاختبار قد اكتمل فاللقطة مُسحت — نُحدّث الشاشة.
    final still = await QuizResumeStore.read(UserSession.I.uid);
    if (mounted) setState(() => _resumable = still);
  }

  // ───────────────────── ① بطاقة المادة ─────────────────────
  //
  // 📐 مقيسة: حشوة 16 · عنوان 11 · فراغ 10 · شرائحُ 37 في صفوفٍ ثلاثية
  //    بفراغ 8 أفقياً و9 رأسياً.

  Widget _subjectCard() {
    final subjects = Curriculum.subjectsFor(_grade, _track);
    final rows = <List<String>>[];
    for (var i = 0; i < subjects.length; i += 3) {
      rows.add(subjects.sublist(i, (i + 3).clamp(0, subjects.length)));
    }
    return QuizCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const QuizCardLabel("١. اختر المادة الدراسية:"),
          const SizedBox(height: 10),
          for (var r = 0; r < rows.length; r++) ...[
            if (r > 0) const SizedBox(height: 9),
            QuizChipRow(children: [
              for (final s in rows[r])
                QuizChip(
                    label: s,
                    selected: s == _subject,
                    onTap: () => _setSubject(s)),
              // 🧱 صفٌّ ناقصٌ يبقى بثلاث خاناتٍ كي لا تتمدّد الشريحة
              //    الأخيرة فتختلف عن أخواتها — وهي حالةُ مادةٍ سابعة.
              for (var f = rows[r].length; f < 3; f++)
                const SizedBox.shrink(),
            ]),
          ],
        ],
      ),
    );
  }

  // ───────────────────── ② بطاقة الدروس ─────────────────────
  //
  // 🎯 **ترتيبُ المالك (2026-09-20) حرفياً:** «ضروري تخلّي الطالب يختار
  //    الوحدة… عنده مكتوب اختر الوحدة وبعدين اختر الدروس، وفوق هالاثنتين
  //    موجودة الدروس اللي اختارها». فالبطاقة ثلاثُ طبقات بهذا الترتيب:
  //
  //      ① ما اخترتَه حتى الآن   (شرائحُ فيها وحدةُ كلِّ درس وزرُّ إزالة)
  //      ② اختر الوحدة           (قائمةٌ منسدلة — **تظهر دائماً**)
  //      ③ اختر الدروس           (صفوفُ الوحدة المعروضة)
  //
  // 🔴 **وكانت القائمة تُخفى حين للمادة وحدةٌ واحدة.** إخفاءٌ «ذكيّ» يكسر
  //    الخطوةَ الأولى: الطالبُ لا يرى أن هناك وحدةً أصلاً، فلا يفهم من أين
  //    جاءت هذه الدروس ولا أنّ ثمّة غيرَها. الظهورُ الثابت يُعلّم التسلسل.

  Widget _lessonsCard() => QuizCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            QuizCardLabel(
              "٢. اختر الدروس (حتى $maxLessons دروس):",
              trailing: _lessons.isEmpty
                  ? null
                  : QuizBadge("تم اختيار ${_lessons.length}"),
            ),
            const SizedBox(height: 10),
            // ① فوق الاثنتين: ما اخترتَه — من كل الوحدات لا من المعروضة.
            _selectedChips(),
            // ② الوحدة.
            _step("اختر الوحدة"),
            const SizedBox(height: 6),
            // 🆕 **منتقي الوحدة** — لا وجودَ له في تصميم المصمّم (رسم مادةً
            //    ذاتَ وحدةٍ واحدة)، وبدونه لا يبلغ الطالبُ دروسَ بقيّة
            //    الكتاب. بُني بلغته: نفسُ `ModernDropdown` في كل التطبيق.
            ModernDropdown(
              hint: "اختر الوحدة",
              value: _units.contains(_unit) ? _unit : null,
              items: _units,
              // 🔁 تصفّحُ وحدةٍ أخرى لا يمسح ما اخترته — الاختيار تراكمي.
              onChanged: (v) => setState(() => _unit = v ?? ""),
            ),
            const SizedBox(height: 12),
            // ③ الدروس.
            _step("اختر الدروس"),
            const SizedBox(height: 6),
            if (_unitLessons.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text("لا توجد دروس في هذه الوحدة بعد.",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.chipInk)),
              )
            else
              for (var i = 0; i < _unitLessons.length; i++) ...[
                if (i > 0) const SizedBox(height: 7),
                _lessonRow(_unitLessons[i]),
              ],
          ],
        ),
      );

  /// عنوانُ خطوةٍ داخل البطاقة — «اختر الوحدة» ثم «اختر الدروس».
  Widget _step(String text) => Align(
        alignment: Alignment.centerRight,
        child: Text(text,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.chipInk)),
      );

  /// 🏷️ **الدروسُ المختارة — كلُّها** فوق منتقي الوحدة وقائمةِ الدروس،
  ///     وكلُّ شريحةٍ تحمل وحدتَها وزرَّ إزالة.
  ///
  /// 🔴 كانت تعرض دروسَ الوحدات **الأخرى** وحدها. وحينئذٍ لا يرى الطالب
  ///    اختيارَه مجموعاً في مكانٍ واحد — وهو ما طلبه المالك صراحةً.
  Widget _selectedChips() {
    if (_lessons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final l in _lessons)
            InkWell(
              onTap: () => setState(() {
                _lessons.remove(l);
                _lessonUnit.remove(l);
              }),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                constraints: const BoxConstraints(minHeight: 28),
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.quizTint,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                          // وحدةُ الدرس تُذكر حين لا تكون الوحدةَ المعروضة
                          // — فلا يبدو الدرسُ مفقوداً ولا مكرَّراً.
                          (_lessonUnit[l] ?? "") == _unit
                              ? l
                              : "$l · ${_lessonUnit[l] ?? ''}",
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary)),
                    ),
                    const SizedBox(width: 6),
                    Icon(PI.x.bold, size: 11, color: AppColors.primary),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 📐 صفُّ درسٍ مقيس: 40 · r12 · مربّعُ اختيارٍ 16 في **بداية** السطر
  ///    (يسار RTL كما في التصميم) والنصُّ إلى يمينه.
  Widget _lessonRow(String lesson) {
    final sel = _lessons.contains(lesson);
    return InkWell(
      onTap: () => _toggleLesson(lesson),
      borderRadius: BorderRadius.circular(QuizMetrics.chipRadius),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        constraints:
            const BoxConstraints(minHeight: QuizMetrics.rowHeight),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: sel ? AppColors.quizTint : AppColors.quizChipFill,
          borderRadius: BorderRadius.circular(QuizMetrics.chipRadius),
          border: Border.all(
              color: sel ? AppColors.primary : AppColors.rowBorder),
        ),
        child: Row(
          children: [
            // ⚠️ RTL: النصُّ أوّلُ ابنٍ ⇒ يميناً، والمربّعُ آخرُه ⇒ يساراً.
            Expanded(
              child: Text(lesson,
                  style: TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      color: sel ? AppColors.primary : AppColors.chipInk)),
            ),
            const SizedBox(width: 10),
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: sel ? AppColors.primary : AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color:
                        sel ? AppColors.primary : AppColors.quizCheckBorder),
              ),
              child:
                  sel ? Icon(PI.check.bold, size: 11, color: Colors.white) : null,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────── ③ بطاقة عدد الأسئلة ─────────────────────

  Widget _countCard() => QuizCard(
        // 📐 حشوتها 13 أفقياً و15 أسفل في التصدير — لا 16 كأختيها.
        padding: const EdgeInsets.fromLTRB(13, 14, 13, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const QuizCardLabel("عدد الأسئلة:"),
            const SizedBox(height: 10),
            // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — و**٥ في اليمين** في التصميم.
            QuizChipRow(
              spacing: 7,
              children: [
                for (final n in const [5, 10, 15])
                  _CountChip(
                    value: n,
                    selected: n == _count,
                    onTap: () => setState(() => _count = n),
                  ),
              ],
            ),
          ],
        ),
      );

  // ───────────────────── ▶️ زرّ البدء ─────────────────────

  Widget _startButton() => QuizPrimaryButton(
        label: _ready ? "ابدأ الاختبار الآن" : "اختر درساً واحداً على الأقل",
        icon: _ready ? PI.sparkle : null,
        enabled: _ready,
        onTap: _start,
      );

  // ───────────────────── 🛟 حالتان لا شاشةَ بيضاء ─────────────────────

  /// تعذّر الوصول للخادم — نقولها كما هي مع زر إعادة محاولة.
  Widget _failedState() => QuizCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            MasarRobot(size: 62, pose: MasarRobotPose.fly),
            const SizedBox(height: 12),
            Text(
              "📡 تعذّر جلب دروس «$_subject» من الخادم.\n"
              "تأكد من اتصالك وحاول مجدداً — الدروس موجودة، والمشكلة في الاتصال.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  fontWeight: FontWeight.w600,
                  color: AppColors.chipInk),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 170,
              child: QuizPrimaryButton(
                label: "حاول مجدداً",
                icon: PI.arrowCounterClockwise,
                height: 44,
                onTap: _loadCaps,
              ),
            ),
          ],
        ),
      );

  Widget _emptyState() => QuizCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            MasarRobot(size: 62, pose: MasarRobotPose.fly),
            const SizedBox(height: 12),
            Text(
              "📁 دروس «$_subject» لـ${Curriculum.gradeLabel(_grade)} لم تُضف بعد 🚧\n"
              "الاختبارات تُبنى من الدروس — جرّب مادة أخرى.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  fontWeight: FontWeight.w600,
                  color: AppColors.chipInk),
            ),
          ],
        ),
      );
}

/// 🔢 شريحةُ العدد — رقمٌ وحده 11/w900، وارتفاعها 40 لا 37.
class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final int value;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(QuizMetrics.chipRadius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: QuizMetrics.rowHeight,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppColors.quizTint : AppColors.quizChipFill,
            borderRadius: BorderRadius.circular(QuizMetrics.chipRadius),
            border: Border.all(
                color: selected ? AppColors.primary : AppColors.quizChipBorder),
          ),
          child: Text("$value",
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: selected ? AppColors.primary : AppColors.chipInk)),
        ),
      );
}
