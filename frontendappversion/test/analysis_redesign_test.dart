// 👤📊 «معلومات الطالب / تحليل مستواي» بعد إعادة التصميم (٢٠٢٦-٠٩-٢١).
//
// 🔴 **والتصميمُ كان موجوداً حيث لم أبحث.** مجلّد `design/07-analysis/`
//    فارغ، فبنيتُ القسمَ أوّلاً مشتقّاً من شاشة نتيجة الاختبار. ثم دلّني
//    المالك: «التحليل حوّلناه إلى قسم الطالب» — وهو في
//    `design/03-home/21-معلومات.png` و`22-معلومات.png`. فأُعيد البناءُ
//    على التصدير الحقيقي، وهذه الاختباراتُ تحرسه.
//
// 🛡️ ولماذا حرّاسٌ على نصّ الملفات؟ لأن بناء هذه الشاشات يستدعي Hive
//    وجلسةً ونتائجَ مخزّنة؛ والوظيفةُ نفسُها محروسةٌ في
//    `analysis_screen_test`. هنا نحرس **اللغةَ البصرية** وبقاءَ النداءات.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/theme/app_colors.dart';
import 'package:ye_student_tutor/features/future_masar/presentation/widgets/analysis_ui.dart';
import 'package:ye_student_tutor/features/future_masar/presentation/widgets/student_profile_card.dart';

String _read(String path) => File(path).readAsStringSync();

const _general =
    'lib/features/future_masar/presentation/screens/analysis_screen.dart';
const _subject =
    'lib/features/future_masar/presentation/screens/subject_analysis_screen.dart';
const _ui = 'lib/features/future_masar/presentation/widgets/analysis_ui.dart';
const _profile =
    'lib/features/future_masar/presentation/widgets/student_profile_card.dart';
const _spot =
    'lib/features/future_masar/presentation/widgets/weak_spot_sheet.dart';
const _review =
    'lib/features/future_masar/presentation/widgets/review_quiz_sheet.dart';
const _home = 'lib/features/future_masar/presentation/screens/home_tab.dart';

const _all = [_general, _subject, _ui, _profile, _spot, _review];

Widget _wrap(Widget child) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  // ══════════════════════════════════════════════════
  // ① لا فعلَ سقط
  // ══════════════════════════════════════════════════
  group('① كلُّ فعلٍ كان موجوداً ما زال موجوداً', () {
    test('شاشة معلومات الطالب', () {
      final s = _read(_general);
      for (final call in [
        'QuizStorage.all',                 // 📥 مصدرُ الأرقام
        'QuizAnalytics.bySubject',         // 📚 بطاقاتُ المواد
        'QuizAnalytics.weakSpots',         // 🎯 نقاطُ الضعف
        'QuizAnalytics.recentPercents',    // 📈 خطُّ التقدّم
        'QuizAnalytics.streakDays',        // 🔥 الأيامُ المتتالية
        'QuizAnalytics.overallPercent',    // 🔢 المعدلُ العام
        'StudentProfileCard',              // 👤 بطاقةُ الطالب
        'SettingsScreen',                  // ⚙️ «عرض التفاصيل»
        'showWeakSpotSheet',               // 🔍 ورقةُ التفصيل
        'showReviewQuizSheet',             // 📅 ورقةُ المراجعة
        'SubjectAnalysisScreen',           // ➡️ الدخولُ لمادة
        'MainChatScreen',                  // 🔁 الحلقةُ الذهبية
        'QuizSetupScreen',                 // 🧠 بدءُ اختبار
        'ScreenTip',                       // 💡 تلميحُ الشاشة
        'Navigator.maybePop',              // ⬅️ الرجوع
      ]) {
        expect(s.contains(call), isTrue, reason: 'سقط من الشاشة العامة: $call');
      }
    });

    test('شاشة المادة — بنيتُها الأصلية كما أمر المالك', () {
      final s = _read(_subject);
      for (final call in [
        'QuizStorage.forSubject',
        'QuizAnalytics.weakSpots',
        'showWeakSpotSheet',
        'QuizReviewScreen.saved',          // 🗂️ «راجع» من السجلّ
        'r.hasReview',                     // ⚠️ ولا يظهر بلا مراجعة محفوظة
        'MainChatScreen',
        'QuizSetupScreen',
        'presetLessons',                   // 🎯 اختبارٌ على الدروس الضعيفة
        'QuizAnalytics.reviewSpots',       // 📅 وبنفس دروس ورقة المراجعة
        'متوسط سجلّك',                      // 📊 البطاقاتُ الأربع كما كانت
        'عدد الاختبارات',
        'أفضل نتيجة',
        'آخر نتيجة',
        'Navigator.maybePop',
      ]) {
        expect(s.contains(call), isTrue, reason: 'سقط من شاشة المادة: $call');
      }
    });

    test('الورقتان', () {
      expect(_read(_spot).contains('onExplain'), isTrue);
      expect(_read(_spot).contains('onRetakeQuiz'), isTrue);
      expect(_read(_spot).contains('spot.topics'), isTrue,
          reason: 'خريطةُ المفاهيم داخل الدرس سقطت');
      // 📅 **`reviewSpots` لا `weakSpots`** (قاعدةُ المالك ٢٠٢٦-٠٩-٢٢):
      //    الورقةُ تعرض **عددَ الأخطاء** فترتّب به، وشاشاتُ التحليل تعرض
      //    **نسبةً مئوية** فترتّب بها. ملفٌّ كامل يحرس القاعدة:
      //    `review_quiz_order_test.dart`.
      expect(_read(_review).contains('QuizAnalytics.reviewSpots'), isTrue);
      expect(_read(_review).contains('onStart'), isTrue);
    });

    // 📸 صورةُ الطالب في الرئيسية صارت باباً لهذه الشاشة — وبابُ **تغيير
    //    الصورة** لم يضع: انتقل إلى البطاقة نفسِها.
    test('وتغييرُ الصورة لم يضع بعد نقل النقر', () {
      expect(_read(_profile).contains('editable: !s.isGuest'), isTrue,
          reason: 'لم يعد للطالب بابٌ لتغيير صورته');
      expect(_read(_home).contains('AnalysisScreen()'), isTrue);
    });
  });

  // ══════════════════════════════════════════════════
  // ② أيقوناتُ Phosphor حصراً
  // ══════════════════════════════════════════════════
  test('② لا أيقونة Material في القسم', () {
    for (final path in _all) {
      final hits = RegExp(r'Icons\.[a-zA-Z_]+')
          .allMatches(_read(path))
          .map((m) => m.group(0))
          .toSet();
      expect(hits, isEmpty, reason: '$path ما زال يستعمل: $hits');
    }
  });

  // ══════════════════════════════════════════════════
  // ③ اللغةُ القديمة انصرفت
  // ══════════════════════════════════════════════════
  test('③ لا بقايا من لغة الديمو', () {
    for (final path in _all) {
      final s = _read(path);
      for (final old in ['GlassBar', 'SoftCard', 'GradientButton',
                         'SectionHeader', 'GlowBackgroundStatic',
                         'demo_widgets']) {
        expect(s.contains(old), isFalse, reason: '$path ما زال فيه $old');
      }
    }
  });

  // ══════════════════════════════════════════════════
  // ④ المقاساتُ من `22-معلومات`
  // ══════════════════════════════════════════════════
  test('④ الأرقامُ مقيسةٌ من التصدير', () {
    expect(AnalysisMetrics.margin, 24);
    expect(AnalysisMetrics.cardRadius, 20);
    expect(AnalysisMetrics.focusRow, 65);
    expect(AnalysisMetrics.focusRadius, 22);
    expect(AnalysisMetrics.badgeW, 42);
    expect(AnalysisMetrics.badgeH, 38);
    expect(AnalysisMetrics.action, 39);
    expect(AnalysisMetrics.actionRadius, 16);
    expect(AnalysisMetrics.ring, 46);
    expect(AnalysisMetrics.ringStroke, 4);
    expect(AnalysisMetrics.subjectCard, 78);
    expect(AnalysisMetrics.reviewCard, 83);
    expect(AnalysisMetrics.bar, 9);
  });

  // ══════════════════════════════════════════════════
  // ⑤ ألوانُ المستوى من سلالم المشروع
  // ══════════════════════════════════════════════════
  //
  // 🎨 قِستُ حلقتَي التصدير: «100» على `#20D958` و«79» على `#0092FF` —
  //    وهما `success500` و`primary500` حرفاً. فالمصمّم بنى الحلقة من
  //    السلالم، ولا لونَ مخترَعاً هنا.
  test('⑤ الحلقةُ خضراءُ ثم زرقاءُ ثم حمراء', () {
    expect(analysisBand(100), AppColors.success500);
    expect(analysisBand(80), AppColors.success500);
    expect(analysisBand(79), AppColors.primary500);
    expect(analysisBand(50), AppColors.primary500);
    expect(analysisBand(49), AppColors.error500);
  });

  // ══════════════════════════════════════════════════
  // ⑥ ودجتٌ حيّة — لا نصُّ ملفّ
  // ══════════════════════════════════════════════════
  group('⑥ القطعُ المشتركة تُبنى فعلاً', () {
    testWidgets('صفُّ التركيز: 65 · شارةٌ يميناً · زرٌّ يساراً', (t) async {
      await t.pumpWidget(_wrap(SizedBox(
        width: 342,
        child: AnalysisFocusRow(
            title: "نظرية بوهر",
            subtitle: "فيزياء • الفيزياء الذرية",
            percent: 78,
            onTap: () {}),
      )));
      expect(find.text("78%"), findsOneWidget);
      expect(find.text("نظرية بوهر"), findsOneWidget);
      expect(find.text("التفاصيل"), findsOneWidget);
      expect(t.getSize(find.byType(AnalysisFocusRow)).height,
          AnalysisMetrics.focusRow);
      // ⚠️ RTL: أوّلُ ابنٍ هو **الأيمن** — الشارةُ يمينَ العنوان.
      expect(t.getCenter(find.text("78%")).dx,
          greaterThan(t.getCenter(find.text("نظرية بوهر")).dx));
      expect(t.getCenter(find.text("التفاصيل")).dx,
          lessThan(t.getCenter(find.text("نظرية بوهر")).dx));
    });

    testWidgets('حلقةُ المستوى: **دائرةٌ كاملة** بلا علامة نسبة', (t) async {
      await t.pumpWidget(_wrap(const AnalysisScoreRing(percent: 79)));
      // 📐 في التصدير «79» بلا `%` — ودائرتُها مكتملةٌ كدائرة «100»،
      //    فهي شارةُ مستوى لا مقياسُ تقدّم.
      expect(find.text("79"), findsOneWidget);
      expect(find.text("79%"), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(t.getSize(find.byType(AnalysisScoreRing)).width,
          AnalysisMetrics.ring);
    });

    testWidgets('صفُّ المادة: الحلقةُ يميناً والسهمُ يساراً', (t) async {
      await t.pumpWidget(_wrap(SizedBox(
        width: 342,
        child: AnalysisSubjectRow(
            subject: "رياضيات",
            percent: 100,
            label: "ممتاز",
            quizzes: 1,
            onTap: () {}),
      )));
      expect(find.text("رياضيات"), findsOneWidget);
      expect(find.text("ممتاز • اختبار واحد"), findsOneWidget);
      expect(t.getCenter(find.text("100")).dx,
          greaterThan(t.getCenter(find.text("رياضيات")).dx));
    });

    testWidgets('بطاقةُ المراجعة: تقويمٌ يميناً ودائرةٌ بيضاء يساراً', (t) async {
      await t.pumpWidget(_wrap(SizedBox(
        width: 342,
        child: AnalysisReviewCard(
            title: "اختبار مراجعة", subtitle: "أسئلة من دروسك الضعيفة", onTap: () {}),
      )));
      expect(find.text("اختبار مراجعة"), findsOneWidget);
      expect(find.byType(Icon), findsNWidgets(2));
    });

    // 🔴 **علّةٌ رأيتُها في المحاكي مرّتين:** شريطُ «مادة درستها» كان
    //    يُبنى بعرض **صفر** (قيدٌ رخوٌ + `Expanded`)، فيوجد في الشجرة
    //    ولا يراه أحد. الحارسُ يقيس عرضَه فعلاً.
    testWidgets('شريطُ «مادة درستها» له عرضٌ حقيقيّ وارتفاعُ 9', (t) async {
      await t.pumpWidget(_wrap(SizedBox(
        width: 342,
        child: StudentProfileCard(
            studied: 3, total: 8, onDetails: () {}),
      )));
      final bar = find.byKey(StudentProfileCard.barKey);
      expect(bar, findsOneWidget);
      expect(t.getSize(bar).height, AnalysisMetrics.bar);
      expect(t.getSize(bar).width, greaterThan(200));

      // ⚠️ **والمقطوعُ نفسُه يُقاس** لا الصندوقُ وحده: كان الصندوقُ
      //    342×9 صحيحاً بينما جزءاه بارتفاع **صفر** (`ColoredBox` بلا
      //    ابنٍ يأخذ أصغرَ القيود) — فمرّ الحارسُ الأوّلُ على عيبٍ قائم.
      final done = t.getSize(find.byKey(StudentProfileCard.doneKey));
      expect(done.height, AnalysisMetrics.bar,
          reason: 'المقطوعُ بلا ارتفاع — الشريطُ غائبٌ عن العين');
      // 3 من 8 ⇒ نحوُ 37% من عرض الشريط.
      expect(done.width / t.getSize(bar).width, closeTo(0.375, 0.02));
    });

    // 🔤 المثنّى العربي — «آخر 2 اختبارات» عربيّةٌ مكسورة، و«آخر اختباران»
    //    مكسورةٌ أيضاً: ما بعد «آخر» مضافٌ إليه.
    test('جمعُ «اختبار» يُراعي المثنّى وحالةَ الإضافة', () {
      expect(arabicQuizzes(0), "لا اختبارات");
      expect(arabicQuizzes(1), "اختبار واحد");
      expect(arabicQuizzes(2), "اختباران");
      expect(arabicQuizzes(1, afterAkhir: true), "اختبار");
      expect(arabicQuizzes(2, afterAkhir: true), "اختبارين");
      expect(arabicQuizzes(7), "7 اختبارات");
    });

    test('وتمييزُ عدد الأخطاء', () {
      expect(arabicMistakes(1), "خطأ");
      expect(arabicMistakes(2), "خطآن");
      expect(arabicMistakes(3), "3 أخطاء");
      expect(arabicMistakes(11), "11 خطأً");
    });
  });
}
