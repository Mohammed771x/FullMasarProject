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
import 'package:ye_student_tutor/features/future_masar/presentation/screens/home_screen.dart';
import 'package:ye_student_tutor/features/teacher/presentation/teacher_home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 💡 تلميح الشاشة يجدول مؤقّتاً حيّاً بعد انتهاء الاختبار فيُسقطه
    //    («A Timer is still pending»). نعلّمه «عُرض» فيخرج مبكراً — نحن
    //    نختبر الترويسة لا التلميح.
    SharedPreferences.setMockInitialValues({'screen_tip_shown_teacher_home': true});
    UserSession.I
      ..isGuest = false
      ..role = AppRole.student
      ..grade = 3
      ..track = 'علمي';
  });

  test('حساب الطالب يفتح على رئيسية الطالب', () {
    expect(RoleHome.screen(), isA<FutureHomeScreen>());
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
    expect(RoleHome.screen(), isA<FutureHomeScreen>());
  });

  testWidgets('رئيسية المعلّم تعرض ترويسة حسابه ولا شريط رجوع', (tester) async {
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

    expect(find.textContaining('أستاذ خالد'), findsOneWidget);
    // 👨‍🏫 «أُدرّس …» لا «الصف …» — والمسار يظهر معه.
    expect(find.textContaining('أُدرّس الثاني الثانوي'), findsOneWidget);
    expect(find.textContaining('أدبي'), findsOneWidget);
    // بيتُ الدور لا يُرجع إلى شيء.
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('نفس الشاشة كصفحةٍ فرعية: شريط عنوان بدل الترويسة', (tester) async {
    UserSession.I.name = 'أستاذ خالد';
    await tester.pumpWidget(const MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: TeacherHomeScreen(),
      ),
    ));
    await tester.pump();

    expect(find.text('مساعد المعلم 👨‍🏫'), findsOneWidget);
    expect(find.textContaining('أستاذ خالد'), findsNothing);
  });
}
