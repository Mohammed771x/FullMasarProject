// 🎭 توجيه الدور — من اختار «معلّم» يفتح التطبيق على أدواته لا على رئيسية الطالب.
//
// 🔴 **لماذا هذا الاختبار موجود:** ثلاثة منافذ تفتح «الرئيسية» (البداية،
//    التوثيق، تفعيل البريد). عطبُ «منفذٍ واحدٍ نسي الدور» لا يظهر في التجربة
//    اليدوية لأنه لا يقع إلا في مسارٍ واحدٍ من ثلاثة — فيُثبَّت هنا بدل ذلك.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ye_student_tutor/core/auth/user_repository.dart';
import 'package:ye_student_tutor/core/session/role_home.dart';
import 'package:ye_student_tutor/core/session/user_session.dart';
import 'package:ye_student_tutor/core/shell/masar_shell.dart';
import 'package:ye_student_tutor/features/teacher/data/teacher_tool.dart';
import 'package:ye_student_tutor/features/teacher/presentation/teacher_home_screen.dart';
import 'package:ye_student_tutor/features/teacher/presentation/widgets/teacher_settings_panel.dart';
import 'package:ye_student_tutor/features/teacher/presentation/widgets/teacher_tool_bar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 💡 تلميح الشاشة يجدول مؤقّتاً حيّاً بعد انتهاء الاختبار فيُسقطه
    //    («A Timer is still pending»). نعلّمه «عُرض» فيخرج مبكراً — نحن
    //    نختبر الترويسة لا التلميح.
    SharedPreferences.setMockInitialValues({
      'screen_tip_shown_teacher_chat': true,
      // 💡 دليلُ الأداة يُعرض عند أول فتح — نعلّمه «عُرض» فلا يحجب الشاشة.
      'teacher_instruction_shown_ask': true,
      'teacher_instruction_shown_plan': true,
    });
    UserSession.I
      ..isGuest = false
      ..role = AppRole.student
      ..grade = 3
      ..track = 'علمي';
  });

  test('حساب الطالب يفتح على رئيسية الطالب', () {
    expect(RoleHome.screen(), isA<MasarShell>());
  });

  test('حساب المعلّم يفتح على أدوات المعلم — وكبيتٍ لا كشاشةٍ فرعية', () {
    UserSession.I.role = AppRole.teacher;
    final screen = RoleHome.screen();
    expect(screen, isA<TeacherHomeScreen>());
    expect((screen as TeacherHomeScreen).isHome, isTrue);
  });

  // 👤 **الزائر يجوز أن يكون معلّماً**: «جرّب كزائر» لا يمرّ بشاشة اختيار
  //    الدور، فحرمانُه يعني معلّماً يجرّب التطبيق فلا يرى منه ما يخصّه.
  test('الزائر يستطيع تجربة قسم المعلم', () {
    UserSession.I
      ..isGuest = true
      ..role = AppRole.teacher;
    expect(UserSession.I.isTeacher, isTrue);
    expect(RoleHome.screen(), isA<TeacherHomeScreen>());
  });

  test('الزائر يبدأ طالباً حتى يبدّل بنفسه', () {
    UserSession.I.isGuest = true;
    expect(UserSession.I.isTeacher, isFalse);
    expect(RoleHome.screen(), isA<MasarShell>());
  });

  // 🎯 **قرار المالك (٢٠٢٦-٠٩-٢٤):** «خلّه نفس التعليم بالضبط — مكتوب
  //    إعدادات الجلسة، يدخل يحصل خطة الدرس، واجب، اسأل المساعد… كله تحت
  //    إعدادات الجلسة عشان تكون مساحة كبيرة للشات». فلا شريطَ فوق المحادثة.
  Future<void> openTeacherHome(WidgetTester tester) async {
    // 📱 مقاسُ جوالٍ لا ٨٠٠×٦٠٠: البطاقةُ المفتوحة أطولُ من سطح الاختبار
    //    الافتراضيّ، فتقع الشرائحُ تحت تلميح الشاشة ولا تصلها اللمسة.
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    UserSession.I
      ..role = AppRole.teacher
      ..name = 'أستاذ خالد'
      ..grade = 2
      ..track = 'أدبي';
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: TeacherHomeScreen(isHome: true),
      ),
    ));
    await tester.pump();
    // 💡 دليلُ «اسأل المساعد» يُعرض أولَ فتح — يُغلق كي تُلمس الشاشة.
    final close = find.byType(ElevatedButton);
    if (close.evaluate().isNotEmpty && find.byType(Dialog).evaluate().isNotEmpty) {
      await tester.tap(close.last);
      await tester.pump(const Duration(milliseconds: 400));
    }
  }

  // 🔄 ٢٠٢٦-٠٩-٢٤: البطاقةُ **مطويّةٌ** عند الدخول (الروبوتُ وترحيبُه أولاً)،
  //    وتُفتح بلمس رأسها.
  Future<void> openPanel(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 800)); // يُغلق الدليلُ تماماً
    await tester.tap(find.text('إعدادات الجلسة'));
    // ⏱️ إطارٌ يبدأ فيه `AnimatedSize` ثم زمنُه — وإلا بقي الجسمُ بارتفاعٍ صفر
    //    وإن وُجدت شرائحُه في الشجرة، فلا تصلها اللمسة.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(TeacherToolChips), findsOneWidget);
  }

  testWidgets('رئيسيةُ المعلّم: «إعدادات الجلسة» مطويّةٌ ثم فيها الأدوات، ولا شريطَ فوق',
      (tester) async {
    await openTeacherHome(tester);
    expect(find.text('إعدادات الجلسة'), findsOneWidget);
    expect(find.byType(TeacherToolChips), findsNothing,
        reason: 'مطويّةٌ عند الدخول');
    expect(find.text('مساعد المعلم الذكي'), findsWidgets,
        reason: 'الروبوتُ وترحيبُه في الوسط');
    await openPanel(tester);

    expect(find.byType(TeacherToolBar), findsNothing,
        reason: 'الشريطُ الدائم انطوى في البطاقة');
    expect(find.text('إعدادات الجلسة'), findsOneWidget);
    expect(find.byType(TeacherToolChips), findsOneWidget);
    for (final t in TeacherToolX.bar) {
      expect(find.text(t.chipLabel), findsWidgets,
          reason: 'شريحةُ «${t.chipLabel}» مفقودة من البطاقة');
    }
    // 👋 لوحةُ الترحيب باسم المعلّم (لا فقاعةُ الطالب).
    expect(find.textContaining('أستاذ خالد'), findsOneWidget);
    // بيتُ الدور لا يُرجع إلى شيء.
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('لمسةُ شريحةٍ تبدّل الأداة — وزرُّ التوليد لأداته وحدها', (tester) async {
    await openTeacherHome(tester);
    await openPanel(tester);
    // «اسأل المساعد» بلا زرّ توليد.
    expect(find.text('توليد خطة الدرس ✨'), findsNothing);

    await tester.tap(find.text('خطة درس'));
    await tester.pump(const Duration(milliseconds: 400));
    final dialog = find.byType(Dialog);
    if (dialog.evaluate().isNotEmpty) {
      await tester.tap(find.byType(ElevatedButton).last);
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('توليد خطة الدرس ✨'), findsOneWidget);
    expect(find.byType(TeacherSettingsPanel), findsOneWidget);
  });

  testWidgets('رأسُ «إعدادات الجلسة» يطوي الجسم ويُبقي العنوان', (tester) async {
    await openTeacherHome(tester);
    await openPanel(tester);
    expect(find.text('المادة الدراسية:'), findsOneWidget);

    await tester.tap(find.text('إعدادات الجلسة'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('المادة الدراسية:'), findsNothing);
    expect(find.text('إعدادات الجلسة'), findsOneWidget);

    await tester.tap(find.text('إعدادات الجلسة'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('المادة الدراسية:'), findsOneWidget);
  });
}
