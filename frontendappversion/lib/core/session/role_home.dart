import 'package:flutter/material.dart';

import '../../features/future_masar/presentation/screens/home_screen.dart';
import '../../features/teacher/presentation/teacher_home_screen.dart';
import 'user_session.dart';

// ==========================================
// 🎭 بيت كل دور — الطالب شيء والمعلّم شيء آخر
// ==========================================
// **مصدرٌ واحد للحقيقة.** ثلاثة منافذ تفتح «الرئيسية»: شاشة البداية، وشاشة
// التوثيق، وشاشة تفعيل البريد. ولو قرّر كلٌّ منها بنفسه لظلّ أحدها يفتح
// واجهة الطالب لمعلّمٍ — وهو **بالضبط** نوع العطب الذي لا يظهر في الاختبار
// اليدوي لأنه لا يقع إلا في مسارٍ واحد من ثلاثة.
//
// ⚠️ **ولا شيء يُمسح عند التبديل.** الدور يبدّل *الواجهة* فقط؛ محادثات
//    الطالب ونتائجه ومحفوظاته تبقى في مكانها، فمن عاد طالباً وجدها كما تركها.
class RoleHome {
  const RoleHome._();

  /// الشاشة الأولى لهذا الحساب.
  static Widget screen() =>
      UserSession.I.isTeacher ? const TeacherHomeScreen(isHome: true) : const FutureHomeScreen();

  /// يعيد بناء الرحلة كاملةً على بيت الدور الحالي — يُستدعى بعد تبديل الدور.
  ///
  /// `pushAndRemoveUntil` لا `push`: لو بقيت شاشاتُ الدور السابق في المكدّس
  /// لعاد إليها زرُّ الرجوع — فيجد المعلّمُ نفسه في رئيسية الطالب بضغطةٍ واحدة.
  static void reset(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => screen()),
      (route) => false,
    );
  }
}
