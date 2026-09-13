import 'package:flutter/material.dart';

import '../../../core/config/curriculum.dart';
import '../../../core/session/user_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/fade_in_slide.dart';
import '../../../core/widgets/robot_widget.dart';
import '../../chat/data/models/subject_capabilities.dart';
import '../../chat/data/repositories/tutor_content_repository.dart';
import '../data/quiz_resume_store.dart';
import 'quiz_controller.dart';
import 'quiz_play_screen.dart';

// ==========================================
// ⚙️ إعداد الاختبار — صف → مادة → وحدة → حتى 3 دروس → عدد الأسئلة
// ==========================================
// مدخلان يقودان إليها ([31§4]):
//   🏠 كرت «اختبر نفسك» في الرئيسية (الطالب يختار كل شيء)
//   💬 وضع «اختبارات» داخل المادة (المادة والصف محدَّدان مسبقاً)
//
// الوحدات والدروس تأتي من `/content/capabilities` — **نفس مصدر شاشة الشات**،
// فلا قائمة مكتوبة يدوياً ولا استثناء لمادة.
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
        backgroundColor: Colors.orange.shade700,
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        title: const Text("اختبر نفسك 🧠",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: FadeInSlide(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              _header(),
              if (_resumable != null) ...[
                const SizedBox(height: 14),
                _resumeCard(_resumable!),
              ],
              // ⛔ **لا صفَّ ولا مسار هنا** (قرار المالك 2026-09-09):
              //    الطالب حدّدهما في إعداداته مرّةً واحدة، وإعادةُ سؤاله
              //    في كل شاشة تُقحم قراراً محسوماً — بل وتُغري بتغييره
              //    فيمتحن نفسه في منهجٍ ليس منهجه.
              //
              // ⭐ فتظهر **مواد صفّه مباشرةً**. وهي نفس القاعدة التي طُبّقت
              //    على القائمة الجانبية في قسم التعليم.
              const SizedBox(height: 18),
              _label("المادة"),
              _subjectChips(),
              const SizedBox(height: 18),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2.6)),
                )
              else if (_loadFailed)
                _failedState()
              else if (_caps?.quizAvailable != true)
                _emptyState()
              else ...[
                _label("الوحدة"),
                _unitPicker(),
                const SizedBox(height: 16),
                _label("الدروس (حتى $maxLessons)"),
                _selectedLessons(),
                _lessonPicker(),
                const SizedBox(height: 18),
                _label("عدد الأسئلة"),
                _countChips(),
                const SizedBox(height: 26),
                _startButton(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────── ⏸️ استئناف اختبار ─────────────────────
  //
  // 🔴 **ما كان يحدث:** مكالمةٌ أو انقطاعُ نتٍّ أو قتلُ النظام للتطبيق في
  //    الخلفية يمحو اختباراً وصل الطالب فيه للسؤال ١٢ من ١٥. ثم إعادته
  //    تخصم حصةً ثانية وتنادي الموديل مرةً أخرى — فيدفع الطالب (ويدفع
  //    المالك) ثمن مقاطعةٍ لم يخترها أحد.
  //
  // ⚠️ والاستئناف **بلا نداء موديل ولا خصم**: الأسئلة محفوظةٌ محلياً كما هي.

  Widget _resumeCard(QuizSnapshot snap) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, color: AppColors.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "لديك اختبار لم يكتمل",
                  style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            "${snap.subject} · ${snap.unit.isEmpty ? 'دروس مختارة' : snap.unit}"
            " — باقٍ ${snap.remaining} من ${snap.questions.length} أسئلة",
            style: TextStyle(fontSize: 12, height: 1.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _resume(snap),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text("أكمل"),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () async {
                  await QuizResumeStore.clear(UserSession.I.uid);
                  if (mounted) setState(() => _resumable = null);
                },
                child: Text("تجاهله",
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
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

  // ───────────────────────── أجزاء ─────────────────────────

  Widget _header() => Row(
        children: [
          RobotWidget(size: 58, state: RobotState.think),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppColors.bubbleShadow,
              ),
              child: Text(
                "اختر دروسك وسأجهّز لك أسئلة **من الدرس نفسه** — سهلة ثم أصعب.",
                style: TextStyle(
                    fontSize: 12.5, height: 1.6,
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
            ),
          ),
        ],
      );

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(t,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
        ),
      );

  Widget _subjectChips() => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: Curriculum.subjectsFor(_grade, _track)
            .map((s) => _chip(s, s == _subject, () => _setSubject(s), compact: true))
            .toList(),
      );

  Widget _countChips() => Row(
        children: const [5, 10, 15].map((n) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _chip("$n سؤال", n == _count, () => setState(() => _count = n)),
            ),
          );
        }).toList(),
      );

  Widget _chip(String label, bool selected, VoidCallback onTap, {bool compact = false}) =>
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(vertical: compact ? 9 : 12, horizontal: compact ? 14 : 6),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.softSurface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: selected ? Colors.white : AppColors.textSecondary)),
        ),
      );

  Widget _unitPicker() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
            color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(16)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _units.contains(_unit) ? _unit : null,
            hint: const Text("اختر الوحدة"),
            items: _units
                .map((u) => DropdownMenuItem(
                    value: u,
                    child: Text(u,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600))))
                .toList(),
            // 🔁 تصفّحُ وحدةٍ أخرى لا يمسح ما اخترته — الاختيار تراكمي.
            onChanged: (v) => setState(() => _unit = v ?? ""),
          ),
        ),
      );

  /// ما اخترته حتى الآن — من كل الوحدات، مع وحدته وزرّ إزالة.
  /// بدونه لا يعرف الطالب أنه اختار درساً في وحدة أخرى غير المعروضة.
  Widget _selectedLessons() {
    if (_lessons.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("المختارة (${_lessons.length}/$maxLessons)",
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _lessons.map((l) {
              final u = _lessonUnit[l] ?? "";
              return InputChip(
                label: Text(
                  u.isEmpty || u == _unit ? l : "$l · $u",
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700),
                ),
                onDeleted: () => setState(() {
                  _lessons.remove(l);
                  _lessonUnit.remove(l);
                }),
                deleteIcon: const Icon(Icons.close_rounded, size: 16),
                backgroundColor: AppColors.primary.withValues(alpha: 0.10),
                side: BorderSide(
                    color: AppColors.primary.withValues(alpha: 0.35)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _lessonPicker() {
    if (_unitLessons.isEmpty) {
      return Text("لا توجد دروس في هذه الوحدة بعد.",
          style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary));
    }
    return Column(
      children: _unitLessons.map((l) {
        final sel = _lessons.contains(l);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _toggleLesson(l),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: sel ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surfaceWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: sel ? AppColors.primary : AppColors.softSurface, width: 1.4),
              ),
              child: Row(
                children: [
                  Icon(sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                      size: 20, color: sel ? AppColors.primary : AppColors.textSecondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(l,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: sel ? FontWeight.bold : FontWeight.w600,
                            color: sel ? AppColors.primary : AppColors.textPrimary)),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// تعذّر الوصول للخادم — نقولها كما هي مع زر إعادة محاولة.
  Widget _failedState() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            RobotWidget(size: 62, state: RobotState.idle),
            const SizedBox(height: 12),
            Text(
              "📡 تعذّر جلب دروس «$_subject» من الخادم.\n"
              "تأكد من اتصالك وحاول مجدداً — الدروس موجودة، والمشكلة في الاتصال.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.8,
                  fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
              onPressed: _loadCaps,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text("حاول مجدداً", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

  Widget _emptyState() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            RobotWidget(size: 62, state: RobotState.idle),
            const SizedBox(height: 12),
            Text(
              "📁 دروس «$_subject» لـ${Curriculum.gradeLabel(_grade)} لم تُضف بعد 🚧\n"
              "الاختبارات تُبنى من الدروس — جرّب مادة أخرى.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, height: 1.8,
                  fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ],
        ),
      );

  Widget _startButton() => SizedBox(
        height: 56,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: _ready ? AppColors.primary : AppColors.softSurface,
            foregroundColor: _ready ? Colors.white : AppColors.textSecondary,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          onPressed: _ready ? _start : null,
          child: Text(
            _lessons.isEmpty ? "اختر درساً واحداً على الأقل" : "ابدأ الاختبار 🚀",
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      );
}
