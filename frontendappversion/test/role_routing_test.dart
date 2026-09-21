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

  testWidgets('رئيسيةُ المعلّم هي شاتُه: شريطُ الأدوات وترحيبُه، ولا شريط رجوع',
      (tester) async {
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

    // 🧰 شريطُ الأدوات — أربعُ شرائح بترتيب التصميم.
    expect(find.byType(TeacherToolBar), findsOneWidget);
    for (final t in TeacherToolX.bar) {
      expect(find.text(t.chipLabel), findsOneWidget,
          reason: 'شريحةُ «${t.chipLabel}» مفقودة من الشريط');
    }

    // 👋 لوحةُ الترحيب باسم المعلّم (لا فقاعةُ الطالب).
    expect(find.textContaining('أستاذ خالد'), findsOneWidget);

    // 🔘 **ولا بطاقةَ إعداداتٍ في البداية** — الإطار ٢ من التصميم.
    expect(find.byType(TeacherSettingsPanel), findsNothing);

    // بيتُ الدور لا يُرجع إلى شيء.
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('لمسةُ شريحةٍ تفتح بطاقتَها، ولمسةٌ ثانيةٌ تطويها', (tester) async {
    UserSession.I
      ..role = AppRole.teacher
      ..name = 'أستاذ خالد'
      ..grade = 1;

    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: TeacherHomeScreen(isHome: true),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('خطة درس'));
    await tester.pump();
    expect(find.byType(TeacherSettingsPanel), findsOneWidget);
    // 🎨 وعنوانُها كما سمّاه المالك لا كما كتبه المصمّم.
    expect(find.text('إعداد خطة الدرس'), findsOneWidget);

    await tester.tap(find.text('خطة درس'));
    await tester.pump();
    expect(find.byType(TeacherSettingsPanel), findsNothing);
  });

  // 🔽 **طلبُ المالك ٢٠٢٦-٠٩-٢١:** «سهم جنب … إنك تقدر بعدين تطوي البطاقة».
  //    فاللمسُ على الشريحة ثانيةً يُخفيها كلَّها ولا يدلّ عليه شيءٌ على
  //    الشاشة؛ والسهمُ يطويها **ويُبقي عنوانَها** فيعرف أيَّ أداةٍ يخاطب.
  testWidgets('سهمُ الرأس يطوي البطاقة ويُبقي عنوانَها', (tester) async {
    UserSession.I
      ..role = AppRole.teacher
      ..name = 'أستاذ خالد'
      ..grade = 1;

    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: TeacherHomeScreen(isHome: true),
      ),
    ));
    await tester.pump();

    await tester.tap(find.text('خطة درس'));
    await tester.pump();
    expect(find.text('المادة الدراسية:'), findsOneWidget);

    // اللمسُ على الرأس (العنوان أو سهمُه) يطوي الجسم.
    await tester.tap(find.text('إعداد خطة الدرس'));
    await tester.pump();
    expect(find.text('المادة الدراسية:'), findsNothing);
    // 🔑 والعنوانُ باقٍ — وإلا لم يعرف المعلّمُ ما طوى ولا كيف يفتحه.
    expect(find.text('إعداد خطة الدرس'), findsOneWidget);
    expect(find.byType(TeacherSettingsPanel), findsOneWidget);

    await tester.tap(find.text('إعداد خطة الدرس'));
    await tester.pump();
    expect(find.text('المادة الدراسية:'), findsOneWidget);
  });
}
