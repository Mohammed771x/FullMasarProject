// 🧭 نقرة الإشعار: من الوصول إلى الوجهة.
//
// 🔴 **العطلان اللذان كانا يُسقطان النقرة صامتةً:**
//   ① لا أحد يضبط `onTap` إطلاقاً — فالنقرة تصل وتُهمَل.
//   ② النقرة التي **تفتح التطبيق من الصفر** تصل عبر `getInitialMessage()`
//      أثناء التهيئة، قبل أن يوجد `Navigator` أو مُوجِّه — فتضيع حتى بعد
//      إصلاح ①. ولذلك تُحفظ وتُفرَّغ عند تسجيل المُوجِّه.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ye_student_tutor/core/access/access_repository.dart';
import 'package:ye_student_tutor/core/auth/user_repository.dart';
import 'package:ye_student_tutor/core/session/user_session.dart';
import 'package:ye_student_tutor/core/notifications/push_router.dart';
import 'package:ye_student_tutor/core/notifications/push_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PushService.I.resetForTest();
    AccessRepository.I.reset();
    UserSession.I
      ..isGuest = false
      ..role = AppRole.student;
  });

  group('توصيل النقرة بالوجهة', () {
    test('نقرةٌ بعد تسجيل المُوجِّه تصل فوراً', () {
      final seen = <String>[];
      PushService.I.onTap = (link, id) => seen.add('$link|$id');

      PushService.I.simulateTap('quiz', 'n1');
      expect(seen, ['quiz|n1']);
    });

    test('⭐ نقرةٌ وصلت **قبل** المُوجِّه تُحفظ وتُفرَّغ عند تسجيله', () {
      // هذا بالضبط ما يحدث حين تفتح النقرةُ التطبيقَ من الصفر.
      PushService.I.simulateTap('scholarships', 'n2');

      final seen = <String>[];
      PushService.I.onTap = (link, id) => seen.add('$link|$id');
      expect(seen, ['scholarships|n2'],
          reason: 'النقرة المحفوظة يجب أن تُفرَّغ لحظة تسجيل المُوجِّه');
    });

    test('لا تُفرَّغ النقرة مرّتين', () {
      PushService.I.simulateTap('teacher', 'n3');
      final seen = <String>[];
      PushService.I.onTap = (link, id) => seen.add(link);
      PushService.I.onTap = (link, id) => seen.add('ثانية:$link');
      expect(seen, ['teacher']);
    });

    test('وجهة `none` أو فارغة لا تُحرّك شيئاً', () {
      final seen = <String>[];
      PushService.I.onTap = (link, id) => seen.add(link);
      PushService.I.simulateTap('none', 'x');
      PushService.I.simulateTap('', 'y');
      expect(seen, isEmpty);
    });

    test('إلغاء المُوجِّه لا يُسقط التطبيق', () {
      PushService.I.onTap = null;
      PushService.I.simulateTap('quiz', 'n4');   // يُحفظ بلا انفجار
      final seen = <String>[];
      PushService.I.onTap = (link, id) => seen.add(link);
      expect(seen, ['quiz']);
    });
  });

  group('المُوجِّه يحترم قواعد الأقسام', () {
    Widget host() => MaterialApp(
          navigatorKey: masarNavigatorKey,
          home: const Scaffold(body: Text('الرئيسية')),
        );

    testWidgets('🔐 قسمٌ مُخفى ⇒ لا يُفتح، وتُعرض رسالة اللوحة', (tester) async {
      AccessRepository.I.seed({
        AppSection.scholarships: const SectionState(
            mode: SectionMode.off, message: 'المنح للثالث فقط'),
      });
      await tester.pumpWidget(host());

      PushRouter.attach();
      PushService.I.simulateTap(AppSection.scholarships, 'n2');
      await tester.pumpAndSettle();

      // ⭐ الإشعار ليس باباً خلفياً يلتفّ على قاعدة الإخفاء.
      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('المنح للثالث فقط'), findsOneWidget);
    });

    testWidgets('قسمٌ بوضع «قريباً» ⇒ لا يُفتح كذلك', (tester) async {
      AccessRepository.I.seed({
        AppSection.quiz: const SectionState(
            mode: SectionMode.soon, message: 'يفتح بعد الاختبارات'),
      });
      await tester.pumpWidget(host());

      PushRouter.attach();
      PushService.I.simulateTap(AppSection.quiz, 'n3');
      await tester.pumpAndSettle();

      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.text('يفتح بعد الاختبارات'), findsOneWidget);
    });

    // 👨‍🏫 «مساعد المعلم» خرج من قواعد الوصول ([35§7]) — فحارسه **الدور**.
    //
    // 🔴 وبلا هذا الحارس يفتح **إشعارٌ واحد** أدواتِ المعلم لطالبٍ فُصل عنها
    //    في كل شاشة أخرى: ثغرةٌ من باب خلفي لا من الواجهة.
    testWidgets('🎭 إشعار «مساعد المعلم» لا يفتح لطالب', (tester) async {
      UserSession.I.role = AppRole.student;
      await tester.pumpWidget(host());

      PushRouter.attach();
      PushService.I.simulateTap(AppSection.teacher, 'n4');
      await tester.pumpAndSettle();

      expect(find.text('الرئيسية'), findsOneWidget);
      expect(find.textContaining('لحسابات المعلمين'), findsOneWidget);
    });

    testWidgets('🎭 ويفتح للمعلّم ولو لم تُعرَّف له قاعدة وصول', (tester) async {
      // 💡 التلميح مجدولٌ بمؤقّت، ورئيسية المعلم لا «تستقرّ» أبداً —
      //    فنعلّمه «عُرض» وندفع إطاراتٍ معدودة بدل `pumpAndSettle`.
      SharedPreferences.setMockInitialValues({
        'screen_tip_shown_teacher_chat': true,
        // 💡 ودليلُ الأداة يُعرض مرّةً عند أول فتح — نعلّمه «عُرض».
        'teacher_instruction_shown_ask': true,
      });
      UserSession.I.role = AppRole.teacher;
      await tester.pumpWidget(host());

      PushRouter.attach();
      PushService.I.simulateTap(AppSection.teacher, 'n5');
      await tester.pump();
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 300));
      }

      // ✅ وصل مساعدَ المعلم فعلاً — ولا رسالةَ منعٍ ظهرت.
      //    (العنوان في الشريط العلويّ وفي لوحة الترحيب معاً.)
      expect(find.text('مساعد المعلم الذكي'), findsWidgets);
      expect(find.textContaining('لحسابات المعلمين'), findsNothing);
    });

    testWidgets('🛟 وجهةٌ لا يعرفها التطبيق لا تُسقطه', (tester) async {
      await tester.pumpWidget(host());
      PushRouter.attach();
      PushService.I.simulateTap('galaxy_mode', 'n4');
      await tester.pumpAndSettle();
      expect(find.text('الرئيسية'), findsOneWidget);
    });
  });

  group('جدول الوجهات', () {
    test('كل وجهةٍ تعرضها اللوحة تُترجم لقسمٍ معروف', () {
      // ⚠️ لو انحرف مفتاحٌ هنا عن الخادم لصار خيارٌ في اللوحة لا يفتح شيئاً.
      for (final link in AppSection.all) {
        expect(PushRouter.sectionFor(link), link, reason: link);
      }
    });

    test('منحةٌ بعينها تُترجم لقسم المنح', () {
      expect(PushRouter.sectionFor('scholarship:india'), AppSection.scholarships);
    });

    test('`none` ووجهةٌ مجهولة ⇒ لا قسم', () {
      expect(PushRouter.sectionFor('none'), isNull);
      expect(PushRouter.sectionFor('galaxy_mode'), isNull);
      expect(PushRouter.sectionFor(''), isNull);
    });

    test('قسمٌ مفتوح يُفتح، ومُخفىً لا يُفتح', () {
      AccessRepository.I.seed({
        AppSection.quiz: SectionState.open,
        AppSection.scholarships: const SectionState(mode: SectionMode.off, message: ''),
        AppSection.teacher: const SectionState(mode: SectionMode.soon, message: ''),
      });
      expect(PushRouter.opens(AppSection.quiz), isTrue);
      expect(PushRouter.opens(AppSection.scholarships), isFalse);
      expect(PushRouter.opens(AppSection.teacher), isFalse);
      expect(PushRouter.opens('scholarship:india'), isFalse,
          reason: 'منحةٌ بعينها تتبع قاعدة قسم المنح');
    });

    test('🛟 بلا قواعد ⇒ كل قسمٍ موصولٍ يُفتح', () {
      AccessRepository.I.reset();
      expect(PushRouter.opens(AppSection.education), isTrue);
      expect(PushRouter.opens(AppSection.analysis), isTrue);
      // الخدمات لم تُوصَل بعد — تُقال «قريباً» ولا تُفتح شاشةٌ فارغة.
      expect(PushRouter.opens(AppSection.services), isFalse);
    });
  });
}
