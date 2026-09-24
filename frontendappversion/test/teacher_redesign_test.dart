// 👨‍🏫 قسم المعلم بعد النقل الحرفيّ عن `design/09-teacher` (٢٠٢٦-٠٩-٢١).
//
// 🎨 **ما نقله المصمّم:** ثمانيةُ تصديرات — أربعُ حالاتٍ لشاشة «مساعد
//    المعلم الذكي» (بلا أداة، وبكلٍّ من الأدوات الثلاث)، ودرجُ المعلم،
//    ودليلُ استخدامه، وحوارا التعديل والحذف.
//
// 🔄 **وأكبرُ ما تغيّر بنيةٌ لا لون:** لم يعد للمعلّم شاشةُ بوابةٍ بأربع
//    بطاقات. **الشاتُ نفسُه بيتُه**، وفوقه شريطُ أدواتٍ يبدّلها بلمسة.
//    فهذه الاختباراتُ تحرس ثلاثة أشياء: مقاساتِ التصميم، وسلّمَ ألوانه،
//    و**ألّا يكون زرٌّ من البوابة قد ضاع في الطريق**.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/theme/app_colors.dart';
import 'package:ye_student_tutor/features/teacher/data/teacher_tool.dart';
import 'package:ye_student_tutor/features/teacher/presentation/widgets/teacher_tool_bar.dart';
import 'package:ye_student_tutor/features/teacher/presentation/widgets/teacher_settings_panel.dart';

String _read(String p) => File(p).readAsStringSync();

const _bar = 'lib/features/teacher/presentation/widgets/teacher_tool_bar.dart';
const _panel =
    'lib/features/teacher/presentation/widgets/teacher_settings_panel.dart';
/// 💡 اقتراحاتُ المعلّم تُعرض بشريط الطالب نفسِه منذ ٢٠٢٦-٠٩-٢٤
///    (قرار المالك: «نفس التعليم بالضبط») — لا ملفَّ خاصّاً بها بعد.
const _chips = 'lib/features/chat/presentation/widgets/mode_suggestions.dart';
const _home = 'lib/features/teacher/presentation/teacher_home_screen.dart';
const _drawer = 'lib/features/chat/presentation/widgets/chat_drawer.dart';
const _screen = 'lib/features/chat/presentation/screens/main_chat_screen.dart';
const _appBar = 'lib/features/chat/presentation/widgets/chat_app_bar.dart';
const _list = 'lib/features/chat/presentation/widgets/chat_list_view.dart';

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );

void main() {
  // ══════════════════════════════════════════════════
  group('① مقاساتُ التصميم مقيسةٌ لا مقدَّرة', () {
    test('شريطُ الأدوات — 41 · r15 · فجوة 7 · هامش 24 · مربّع 27 r8', () {
      expect(TeacherToolBar.height, 41);
      expect(TeacherToolBar.radius, 15);
      expect(TeacherToolBar.gap, 7);
      expect(TeacherToolBar.side, 24);
      expect(TeacherToolBar.iconBox, 27);
      expect(TeacherToolBar.iconBoxRadius, 8);
    });

    test('بطاقةُ الإعدادات — r20 · حشوة 16 · زرٌّ 46 r11', () {
      expect(TeacherSettingsPanel.radius, 20);
      expect(TeacherSettingsPanel.padding, 16);
      expect(TeacherSettingsPanel.buttonHeight, 46);
      expect(TeacherSettingsPanel.buttonRadius, 11);
    });
  });

  // ══════════════════════════════════════════════════
  group('② سلّمُ الأداة درجاتٌ من سلالم التوكنات لا ألوانٌ متفرّقة', () {
    setUp(() => isDarkModeNotifier.value = false);

    test('خطةُ الدرس — السلّم الثانوي كما في التصدير', () {
      final p = AppColors.toolPalette(TeacherTool.lessonPlan.slot);
      expect(p.box, AppColors.secondary100);   // #E2E8F7
      expect(p.accent, AppColors.secondary500); // #3C65CA
      expect(p.fill, AppColors.secondary50);    // #ECF0FA
      expect(p.cta, AppColors.secondary800);    // #2D4C98
    });

    test('الواجبُ والاختبار — سلّم النجاح', () {
      final p = AppColors.toolPalette(TeacherTool.homework.slot);
      expect(p.box, AppColors.success100);   // #DEF9E6
      expect(p.accent, AppColors.success500); // #20D958
      expect(p.fill, AppColors.success50);    // #E9FBEE
      expect(p.cta, AppColors.success800);    // #18A342
    });

    test('تبسيطُ المفهوم — سلّم التحذير', () {
      final p = AppColors.toolPalette(TeacherTool.simplify.slot);
      expect(p.box, AppColors.warning100);   // #FDF8DD
      expect(p.accent, AppColors.warning500); // #F3D31B
      expect(p.fill, AppColors.warning50);    // #FEFBE8
      expect(p.cta, AppColors.warning800);    // #B69E14
    });

    test('🆕 «اسأل المساعد» بسلّم الهوية — أداةٌ لم يرسمها المصمّم', () {
      final p = AppColors.toolPalette(TeacherTool.ask.slot);
      expect(p.accent, AppColors.primary500);
      expect(p.fill, AppColors.primary50);
    });

    test('لكل أداةٍ سلّمٌ لا يشاركها فيه غيرُها', () {
      final accents =
          TeacherToolX.bar.map((t) => AppColors.toolPalette(t.slot).accent);
      expect(accents.toSet().length, TeacherToolX.bar.length);
    });
  });

  // ══════════════════════════════════════════════════
  group('③ نصوصُ التصميم حرفاً', () {
    // 🔴 **وعناوينُ البطاقات من المالك لا من المصمّم** (٢٠٢٦-٠٩-٢١):
    //    «إعداد خطة التحضير الوزاري» تَعِد بوثيقةٍ رسميةٍ لا تُنتجها
    //    الأداة — فقُصّرت هي وأخواتُها. و«الوزاري» ممنوعةٌ هنا صراحةً.
    test('عناوينُ البطاقات قصيرةٌ وصادقة', () {
      expect(TeacherTool.lessonPlan.cardTitle, 'إعداد خطة الدرس');
      expect(TeacherTool.homework.cardTitle, 'إعداد واجب واختبار');
      expect(TeacherTool.simplify.cardTitle, 'تبسيط مفهوم للطلاب');
      for (final t in TeacherToolX.bar) {
        expect(t.cardTitle.contains('الوزاري'), isFalse);
      }
    });

    test('أسماءُ الشرائح قصيرةٌ كما في الشريط', () {
      expect(TeacherTool.lessonPlan.chipLabel, 'خطة درس');
      expect(TeacherTool.homework.chipLabel, 'واجب واختبار');
      expect(TeacherTool.simplify.chipLabel, 'تبسيط مفهوم');
    });

    test('ترتيبُ الشريط: خطة ← واجب ← تبسيط ← اسأل', () {
      expect(TeacherToolX.bar, [
        TeacherTool.lessonPlan,
        TeacherTool.homework,
        TeacherTool.simplify,
        TeacherTool.ask,
      ]);
    });

    test('عنوانُ الشريط العلويّ «مساعد المعلم الذكي»', () {
      expect(_read(_appBar), contains('مساعد المعلم الذكي'));
      expect(_read(_appBar), isNot(contains('"مساعد المعلّم"')));
    });
  });

  // ══════════════════════════════════════════════════
  group('④ لا بقايا من اللغة القديمة', () {
    test('لا أيقونةَ Material في قسم المعلم — Phosphor حصراً', () {
      for (final f in [_bar, _panel, _chips, _home]) {
        expect(RegExp(r'\bIcons\.').hasMatch(_read(f)), isFalse,
            reason: '$f فيه أيقونةُ Material');
      }
    });

    test('لا تدرّجاتٍ في الأزرار — المصمّم جعلها مصمتة', () {
      expect(_read(_panel).contains('LinearGradient'), isFalse);
      expect(_read('lib/features/teacher/data/teacher_tool.dart')
          .contains('gradient'), isFalse);
    });

    test('لا شرائحَ من مادّة جوجل في شريط الاقتراحات', () {
      expect(_read(_chips).contains('ActionChip('), isFalse);
      expect(_read(_chips), contains('SuggestionChip'));
    });

    // 🔄 قرار المالك ٢٠٢٦-٠٩-٢٤: «نفس التعليم ونفس المنح بالأزرق المتموّج».
    test('خلفيّةُ قسم المعلم متدرّجةٌ كالتعليم — لا بيضاء', () {
      final src = _read(_screen);
      expect(src, contains('AppColors.chatBackdrop'));
      expect(src, isNot(contains('if (!_c.isTeacher)\n                      Positioned.fill(')));
    });

    // 🔄 قرار المالك ٢٠٢٦-٠٩-٢٤: ترحيبٌ واحدٌ للقسمين والمنح — روبوتٌ في
    //    الوسط وكلامٌ بحسب الأداة. فالمطلوب الآن **ألّا** يفترقا.
    test('ترحيبُ المعلّم هو ترحيبُ الطالب — ونصُّه بحسب الأداة', () {
      expect(_read(_list), contains('_ChatWelcome'));
      expect(_read(_list), isNot(contains('_TeacherWelcome')));
      expect(_read(_list), contains('TeacherTool.simplify =>'));
    });
  });

  // ══════════════════════════════════════════════════
  group('⑤ لا زرَّ فُقد مع البوابة المحذوفة', () {
    // 🔴 البوابةُ كانت تحمل خمسةَ منافذ لا توجد في التصميم الجديد.
    //    مكانُها الآن الدرج — وهذا الاختبارُ يمنع أن تُنسى فيه.
    test('المحفوظات · الإشعارات · الإعدادات · البانر — كلُّها في الدرج', () {
      final d = _read(_drawer);
      expect(d, contains('SavedScreen'));
      expect(d, contains('NotificationsScreen'));
      expect(d, contains('SettingsScreen'));
      expect(d, contains('BannerSection.teacher'));
      expect(d, contains('UserAvatar'));
    });

    test('مبدّلُ الصفّ للمعلّم وحده (تصديرُ درجه)', () {
      final d = _read(_drawer);
      expect(d, contains('_gradeSwitcher'));
      expect(d, contains('if (c.isTeacher) ..._gradeSwitcher()'));
    });

    test('دليلُ المعلّم يعرض أدواتِه لا أوضاعَ الطالب', () {
      final g =
          _read('lib/features/instructions/presentation/instructions_dialog.dart');
      expect(g, contains('_teacherModes'));
      expect(g, contains('وضع خطة درس'));
      expect(g, contains('وضع واجب واختبار'));
    });

    test('زرُّ التوليد ونداؤه باقيان لكل أداةٍ تولّد', () {
      expect(_read(_panel), contains('c.generateTeacher()'));
      for (final t in TeacherToolX.bar) {
        if (!t.hasGenerate) continue;
        expect(t.generateLabel.trim(), isNotEmpty);
      }
    });

    test('أيقونةُ «واجب واختبار» هي `PFileCheck` المركّبة لا بديلٌ يشبهها', () {
      // 🔴 `file-check` ليست في خطّ Phosphor الذي بين أيدينا، وهي مركّبةٌ
      //    أصلاً لشرائح «وزاري» عند الطالب — فاستعمالُ `fileText` بدلَها
      //    كان سيعطي المعلّمَ ورقةً بخطوطٍ لا ورقةً بعلامةِ صحّ.
      expect(_read('lib/features/teacher/data/teacher_tool.dart'),
          contains('PFileCheck'));
    });

    // 🏷️ رأيتُه في المحاكي: «احياء · معلم:homework» تحت عنوان المحادثة.
    test('مفتاحُ نطاقِ المعلّم لا يُعرض خاماً للمعلّم', () {
      expect(teacherModeLabel('معلم:homework'), 'إنشاء واجب');
      expect(teacherModeLabel('معلم:plan'), 'إنشاء خطة درس');
      // وضعُ الطالب يعود كما هو — الدالةُ لا تمسّ ما ليس لها.
      expect(teacherModeLabel('شرح'), 'شرح');
      // ومفتاحٌ لأداةٍ مجهولة يعود كما هو لا فارغاً.
      expect(teacherModeLabel('معلم:nope'), 'معلم:nope');
      expect(_read(_drawer), contains('teacherModeLabel(conv.mode)'));
    });

    test('معرّفاتُ الخادم لم تتغيّر — وإلا انفصل المعلّم عن سجلّه', () {
      expect(TeacherTool.lessonPlan.id, 'plan');
      expect(TeacherTool.simplify.id, 'simplify');
      expect(TeacherTool.homework.id, 'homework');
      expect(TeacherTool.ask.id, 'ask');
    });
  });

  // ══════════════════════════════════════════════════
  group('⑥ الشريطُ حيّاً', () {
    setUp(() => isDarkModeNotifier.value = false);

    testWidgets('أربعُ شرائح بارتفاع 41 ومربّعاتٍ 27', (tester) async {
      await tester.pumpWidget(_wrap(
        TeacherToolBar(open: TeacherTool.lessonPlan, onTap: (_) {}),
      ));
      await tester.pump();

      for (final t in TeacherToolX.bar) {
        expect(find.text(t.chipLabel), findsOneWidget);
      }
      final bar = tester.getSize(find.byType(TeacherToolBar));
      expect(bar.height, TeacherToolBar.height);
    });

    testWidgets('المختارةُ وحدَها تلبس لونَ أداتِها', (tester) async {
      TeacherTool? tapped;
      await tester.pumpWidget(_wrap(
        TeacherToolBar(
            open: TeacherTool.homework, onTap: (t) => tapped = t),
      ));
      await tester.pump();

      final p = AppColors.toolPalette(TeacherTool.homework.slot);
      final selected = tester.widget<Text>(find.text('واجب واختبار'));
      expect(selected.style!.color, p.ink);

      final idle = tester.widget<Text>(find.text('خطة درس'));
      expect(idle.style!.color, AppColors.rowAction);

      await tester.tap(find.text('تبسيط مفهوم'));
      expect(tapped, TeacherTool.simplify);
    });
  });
}
