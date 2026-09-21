import 'package:flutter/material.dart';

import '../access/access_repository.dart';
import '../session/user_session.dart';
import '../theme/app_colors.dart';
import '../../features/chat/presentation/screens/main_chat_screen.dart';
import '../../features/future_masar/presentation/screens/home_tab.dart';
import '../../features/quiz/presentation/quiz_setup_screen.dart';
import '../../features/scholarships/presentation/scholarships_screen.dart';
import 'masar_bottom_nav.dart';

// ==========================================
// 🏛️ هيكل التطبيق — الأقسام تحت شريطٍ واحد
// ==========================================
// 🎨 **تصميم Figma:** الشريط يظهر على «الرئيسية · اختبر نفسك · المنح ·
//    معلومات الطالب» — فهو **قشرةٌ دائمة** لا زينةٌ في شاشةٍ واحدة.
//
// ⭐ **ما تغيّر وما لم يتغيّر:**
//    · تغيّر: طريقُ الوصول إلى الأقسام (شريطٌ بدل بطاقاتٍ في الرئيسية).
//    · لم يتغيّر: **الشاشاتُ نفسها ولا نداءاتها**. `QuizSetupScreen` و
//      `ScholarshipsScreen` تُعرضان كما هما — والشريطُ يجلس تحتهما.
//
// 🔐 **حارس الأقسام باقٍ كما هو:** ما تُخفيه اللوحة لا يُفتح، والرسالةُ
//    من اللوحة لا من الكود. وهذا **إخفاءٌ لا حماية** — الحمايةُ في الخادم.
class MasarShell extends StatefulWidget {
  const MasarShell({super.key, this.initial = MasarTab.home});

  final MasarTab initial;

  @override
  State<MasarShell> createState() => _MasarShellState();
}

class _MasarShellState extends State<MasarShell> {
  late MasarTab _tab = widget.initial;

  /// 🧠 **تُبنى عند أول زيارة وتبقى حيّة بعدها** — الطالب يتنقّل بين
  ///    «اختبر نفسك» والرئيسية عشرات المرات في الجلسة، وإعادةُ بناء شاشة
  ///    الاختبار في كل مرة تفقده اختياراته وتعيد جلب الدروس بلا سبب.
  final Map<MasarTab, Widget> _built = {};

  // ══════════════════════════════════════════════════
  // 🎓 تغيُّرُ الصفّ أو المسار يُبطل ما بُني
  // ══════════════════════════════════════════════════
  //
  // 🔴 **عطلٌ رآه المالك (2026-09-20):** «دخلت غيّرت الصف من الإعدادات،
  //    ما تغيّر عندي». والسبب أنّ البقاءَ الذي أعلاه نعمةٌ ونقمة: شاشةُ
  //    «اختبر نفسك» تقرأ الصفَّ والمسارَ **مرّةً في `initState`** ثم تعيش
  //    محفوظةً في `_built` — فيُبدّل الطالبُ صفَّه وتبقى أمامه موادُّ صفٍّ
  //    تركه. ولا يُصلحها `setState` هنا: الودجت **هي هي**.
  //
  // ✅ فالنطاقُ يُراقَب، وعند تبدّله تُرمى الصفحات المبنيّة كلُّها فتُبنى
  //    من جديد على الصفّ الجديد. (وكلُّها تقرأ النطاق في `initState`:
  //    الرئيسية والاختبارات والمنح — فلا فائدةَ من إبطاء واحدةٍ دون أخرى.)
  String _scope = "";

  String get _currentScope =>
      "${UserSession.I.grade}|${UserSession.I.track}";

  @override
  void initState() {
    super.initState();
    _scope = _currentScope;
    UserSession.I.addListener(_onSessionChanged);
  }

  @override
  void dispose() {
    UserSession.I.removeListener(_onSessionChanged);
    super.dispose();
  }

  void _onSessionChanged() {
    if (_currentScope == _scope) return;
    _scope = _currentScope;
    if (mounted) setState(_built.clear);
  }

  // ══════════════════════════════════════════════════
  // 🔐 القسم المسموح من اللوحة
  // ══════════════════════════════════════════════════
  static const _sectionOf = {
    MasarTab.quiz: AppSection.quiz,
    MasarTab.tutor: AppSection.education,
    MasarTab.scholarships: AppSection.scholarships,
    MasarTab.services: AppSection.services,
  };

  Set<MasarTab> get _locked => {
        for (final e in _sectionOf.entries)
          if (!AccessRepository.I.usable(e.value)) e.key,
      };

  void _onTap(MasarTab tab) {
    if (tab == _tab && tab != MasarTab.tutor) return;

    final section = _sectionOf[tab];
    if (section != null) {
      final state = AccessRepository.I.of(section);
      if (!state.usable) {
        _snack(state.message.isNotEmpty
            ? state.message
            : "🚧 ${_label(tab)} — غير متاح حالياً.");
        return;
      }
    }

    // 🤖 «مسار» ليس تبويباً: يفتح المحادثة **ملء الشاشة** بلا شريط —
    //    هكذا في التصميم، وهي شاشةٌ تحتاج كل بكسل.
    if (tab == MasarTab.tutor) {
      Navigator.push(context,
              MaterialPageRoute(builder: (_) => const MainChatScreen()))
          .then((_) {
        if (mounted) setState(() {}); // عدّاد المحادثات في الرئيسية
      });
      return;
    }

    if (tab == MasarTab.services) {
      _snack("🚧 قسم الخدمات — قيد التطوير، قريباً بإذن الله");
      return;
    }

    // 🔴 **تُبنى الصفحة قبل تبديل الفهرس.** كان `IndexedStack` يسأل
    //    «هل بُنيت؟» ليقرّر بناءها — فلا تُبنى أبداً، ويرى الطالب **شاشةً
    //    بيضاء فارغة** عند أول ضغطة على التبويب (وقع فعلاً في المحاكي).
    _page(tab);
    setState(() => _tab = tab);
  }

  String _label(MasarTab t) => switch (t) {
        MasarTab.home => "الرئيسية",
        MasarTab.quiz => "اختبر نفسك",
        MasarTab.tutor => "قسم التعليم",
        MasarTab.scholarships => "المنح",
        MasarTab.services => "الخدمات",
      };

  Widget _page(MasarTab tab) => _built.putIfAbsent(tab, () => switch (tab) {
        MasarTab.quiz => const QuizSetupScreen(),
        MasarTab.scholarships => const ScholarshipsScreen(),
        _ => HomeTab(onOpenTab: _onTap),
      });

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      builder: (context) => ListenableBuilder(
        // 🔄 قواعد الأقسام تصل من الخادم بعد أول رسم — وبلا الاستماع يبقى
        //    قسمٌ أُقفل مفتوحاً حتى يعيد الطالب فتح التطبيق.
        listenable: AccessRepository.I,
        builder: (context, _) => Scaffold(
          backgroundColor: AppColors.bgLight,
          body: IndexedStack(
            index: switch (_tab) {
              MasarTab.quiz => 1,
              MasarTab.scholarships => 2,
              _ => 0,
            },
            children: [
              _page(MasarTab.home),
              // 🧠 تبويبٌ لم يُزَر بعد يبقى فارغاً — فلا نجلب دروسَ الاختبار
              //    ولا منحَ الخادم لطالبٍ لم يطلبهما.
              _built.containsKey(MasarTab.quiz)
                  ? _built[MasarTab.quiz]!
                  : const SizedBox.shrink(),
              _built.containsKey(MasarTab.scholarships)
                  ? _built[MasarTab.scholarships]!
                  : const SizedBox.shrink(),
            ],
          ),
          bottomNavigationBar:
              MasarBottomNav(current: _tab, onTap: _onTap, lockedHint: _locked),
        ),
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m,
            style: const TextStyle(
                fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primaryFill,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}
