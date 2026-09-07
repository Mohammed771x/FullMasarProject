import 'package:flutter/material.dart';

import '../access/access_repository.dart';
import '../session/user_session.dart';
import '../../features/chat/presentation/screens/main_chat_screen.dart';
import '../../features/future_masar/presentation/screens/analysis_screen.dart';
import '../../features/quiz/presentation/quiz_setup_screen.dart';
import '../../features/scholarships/data/models/scholarship.dart';
import '../../features/scholarships/data/scholarship_repository.dart';
import '../../features/scholarships/presentation/scholarship_detail_screen.dart';
import '../../features/scholarships/presentation/scholarships_screen.dart';
import '../../features/teacher/presentation/teacher_home_screen.dart';
import 'push_service.dart';

// ==========================================
// 🧭 core/notifications/push_router.dart — أين يذهب الطالب حين ينقر الإشعار
// ==========================================
// ⭐ **مفتاح ملاحةٍ عامّ لا `context` شاشة**: الإشعار يُنقر والتطبيق قد يكون
//    مغلقاً تماماً، أو على شاشةٍ عميقة، أو في الخلفية. لا `BuildContext`
//    مضمونٌ في أيٍّ من ذلك — فالملاحة تمرّ بمفتاحٍ يعيش مع التطبيق نفسه.
//
// 🔐 **والوجهة تمرّ بحارس الأقسام**: قاعدةٌ في اللوحة تُخفي قسماً يجب أن
//    تمنع فتحَه من الإشعار أيضاً، وإلا صار الإشعار باباً خلفياً يلتفّ على
//    القاعدة — ويرى الطالبُ قسماً أُخفي عنه عمداً.

/// مفتاح الملاحة العامّ — يُركَّب على `MaterialApp`.
final GlobalKey<NavigatorState> masarNavigatorKey = GlobalKey<NavigatorState>();

class PushRouter {
  PushRouter._();

  /// يُوصَّل مرّةً واحدة عند الإقلاع.
  ///
  /// ⚠️ **قبل أن تُرسم أي شاشة**: نقرةُ إشعارٍ فتحت التطبيق من الصفر تصل
  ///    عبر `getInitialMessage()` أثناء التهيئة — ولو انتظرنا الشاشةَ
  ///    الرئيسية لضاعت النقرة صامتةً.
  static void attach() {
    PushService.I.onTap = open;
  }

  /// القسم الذي تعنيه هذه الوجهة — أو `null` لوجهةٍ بلا قسم (`none`
  /// أو مفتاحٌ من خادمٍ أحدث من التطبيق).
  ///
  /// ⭐ **مفصولةٌ عن الفتح عمداً**: القرار هو المنطق، وبناءُ الشاشة سباكة.
  ///    وفصلُهما يجعل جدول الوجهات قابلاً للاختبار كاملاً بلا تركيب شاشةٍ
  ///    تحتاج تخزيناً وشبكةً لتُبنى.
  static String? sectionFor(String link) {
    if (link.startsWith('scholarship:')) return AppSection.scholarships;
    return AppSection.all.contains(link) ? link : null;
  }

  /// هل تُفتح هذه الوجهة لهذا الطالب الآن؟
  ///
  /// ⚠️ `services` يعود `false` لأنه لم يُوصَل بعد — يُقال «قريباً» ولا
  ///    تُفتح شاشةٌ فارغة.
  static bool opens(String link) {
    final section = sectionFor(link);
    if (section == null || section == AppSection.services) return false;
    return AccessRepository.I.usable(section);
  }

  /// يفتح وجهة الإشعار. `link` من مفاتيح الأقسام نفسها في الخادم واللوحة.
  static Future<void> open(String link, String notificationId) async {
    final nav = masarNavigatorKey.currentState;
    if (nav == null) return; // لا تطبيق مرسوم بعد — تُعاد المحاولة بالمخزَن

    // 🎓 منحة بعينها: الوجهة تحمل معرّفها بعد نقطتين (`scholarship:india`).
    if (link.startsWith('scholarship:')) {
      final id = link.substring('scholarship:'.length);
      if (!_allowed(nav, AppSection.scholarships)) return;
      final Scholarship? sch = await ScholarshipRepository().byId(id);
      // ⚠️ المنحة قد تكون حُذفت أو أُخفيت بعد إرسال الإشعار — نفتح القائمة
      //    بدل شاشة تفاصيل فارغة.
      _push(nav, sch == null
          ? const ScholarshipsScreen()
          : ScholarshipDetailScreen(scholarship: sch));
      return;
    }

    switch (link) {
      case AppSection.education:
        if (_allowed(nav, link)) _push(nav, const MainChatScreen());
      case AppSection.quiz:
        if (_allowed(nav, link)) _push(nav, const QuizSetupScreen());
      case AppSection.analysis:
        if (_allowed(nav, link)) _push(nav, const AnalysisScreen());
      case AppSection.scholarships:
        if (_allowed(nav, link)) _push(nav, const ScholarshipsScreen());
      case AppSection.teacher:
        // 👨‍🏫 **الدور لا قاعدةُ الوصول**: «مساعد المعلم» خرج من
        //    `access.SECTIONS` لأنه صار تطبيق المعلّم كلَّه ([35§7])، فلا
        //    قاعدةَ تحكمه — والحارس الوحيد هو من أنت.
        //
        // ⚠️ وبلا هذا الشرط يفتح **إشعارٌ واحد** أدواتِ المعلم لطالبٍ فصلناه
        //    عنها في كل شاشة أخرى — ثغرةٌ من باب خلفي لا من الواجهة.
        if (UserSession.I.isTeacher) {
          _push(nav, const TeacherHomeScreen(isHome: true));
        } else {
          _say(nav, '👨‍🏫 مساعد المعلم لحسابات المعلمين — يمكنك التحويل من الإعدادات.');
        }
      case AppSection.services:
        // قسمٌ لم يُوصَل بعد — نقولها بدل شاشةٍ فارغة.
        _say(nav, '🚧 قسم الخدمات — قيد التطوير، قريباً بإذن الله');
      default:
        break; // `none` أو وجهةٌ لا يعرفها التطبيق ⇒ يبقى مكانه
    }
  }

  /// 🔐 القاعدة تسري على الإشعار كما تسري على الزرّ.
  static bool _allowed(NavigatorState nav, String section) {
    final state = AccessRepository.I.of(section);
    if (state.usable) return true;
    _say(nav, state.message.isNotEmpty ? state.message : '🔒 هذا القسم غير متاح حالياً.');
    return false;
  }

  static void _push(NavigatorState nav, Widget page) {
    nav.push(MaterialPageRoute(builder: (_) => page));
  }

  static void _say(NavigatorState nav, String text) {
    final ctx = nav.context;
    ScaffoldMessenger.maybeOf(ctx)?.showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }
}
