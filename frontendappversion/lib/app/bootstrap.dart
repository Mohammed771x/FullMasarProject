import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

import 'package:firebase_messaging/firebase_messaging.dart';

import '../core/access/access_repository.dart';
import '../core/notifications/notifications_repository.dart';
import '../core/notifications/push_router.dart';
import '../core/notifications/push_service.dart';
import '../core/session/user_session.dart';
import '../core/storage/chat_storage.dart';
import '../core/sync/sync_service.dart';
import '../features/quiz/data/quiz_storage.dart';
import '../features/scholarships/data/scholarship_chat_storage.dart';
import '../core/settings/app_settings.dart';
import '../core/theme/theme_controller.dart';
import '../features/banners/data/banner_repository.dart';
import '../features/saved/data/saved_storage.dart';
import '../core/storage/prefs_keys.dart';
import '../core/version/version_gate.dart';
import '../features/future_masar/presentation/screens/splash_screen.dart';

// ==========================================
// 🚀 تهيئة التطبيق
// ==========================================
// التدفّق:
//   Splash → (أول تشغيل؟) Onboarding → Auth → Home
//          → (مسجّل دخول؟) Home مباشرة
//          → (غير ذلك)    Auth
//
// التهيئة الفعلية تتم هنا قبل رسم أي شيء، وشاشة Splash تعرض الشعار
// وتقرر الوجهة عبر AppBootstrap.firstScreen().
class AppBootstrap {
  AppBootstrap._();

  static Future<Widget> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark),
    );

    // 🔥 Firebase أولاً: التوثيق والمحادثات السحابية يعتمدان عليه.
    //    فشل التهيئة لا يُسقط التطبيق — يبقى العمل المحلي (Hive) قائماً.
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      // 📲 معالج الخلفية يُسجَّل **قبل أي استعمال للرسائل** وبعد تهيئة
      //    Firebase مباشرةً — تسجيلُه لاحقاً يُفوّت رسائل وصلت والتطبيق
      //    مغلق، وهو الوضع الأشيع لا الأندر.
      FirebaseMessaging.onBackgroundMessage(masarBackgroundMessageHandler);
    } catch (e) {
      debugPrint("⚠️ تعذّرت تهيئة Firebase: $e");
    }

    await ChatStorage.init();
    await QuizStorage.init();          // 🧠 نتائج «اختبر نفسك» — غذاء قسم التحليل
    await SchChatStorage.init();       // 🎓 محادثات مساعد المنح — مربوطة بالحساب
    await SavedStorage.init();         // ⭐ الإجابات المحفوظة — تبقى بعد حذف محادثتها
    await AppSettings.I.load();     // ⚙️ تفضيلات الطالب قبل أول رسم
    await UserSession.I.load();

    // 🎏 البانرات و🔐 قواعد الأقسام: الكاش يُقرأ فوراً والشبكة تصحّح بعده
    //    بصمت. كلاهما لا يؤخّر الإقلاع ولا يُسقطه.
    unawaited(BannerRepository.I.load());
    unawaited(AccessRepository.I.load());

    // 📬 صندوق الإشعارات — كاشٌ أولاً كإخوته. وهو **الطريق الأضمن** لا
    //    الاحتياطي: الدفع يحتاج إذناً وجهازاً مسجَّلاً وشبكةً لحظةَ
    //    الإرسال، وسقوطُ أيٍّ منها يضيّع الإعلان بلا أثر — أما الصندوق
    //    فيُقرأ متى فتح الطالب التطبيق.
    unawaited(NotificationsRepository.I.load());

    // 🧭 المُوجِّه **قبل** تشغيل الإشعارات: `start()` يقرأ نقرةَ الإقلاع
    //    (`getInitialMessage`)، فتسجيلُ الوجهة بعده يعني نقرةً تصل بلا
    //    مُوجِّه — تُحفظ في البوفر، لكن التوصيل أولاً أبسط وأضمن.
    PushRouter.attach();

    // 🔔 **إشعارٌ وصل والتطبيق مفتوح ⇒ الصندوق يُحدَّث فوراً.** كان
    //    `onForeground` مُعلَناً بلا مُسنِدٍ إليه، فيرى الطالب الإشعار
    //    يمرّ ثم يفتح الجرس فلا يجده حتى الإقلاع التالي.
    PushService.I.onForeground = () => NotificationsRepository.I.refresh();

    // 📲 الإشعارات: للمسجَّلين وحدهم. الزائر حسابه مؤقت ويُرقّى، فرمزُ
    //    جهازه يُربط بحسابه الدائم عند التسجيل لا قبله.
    if (UserSession.I.loggedIn && !UserSession.I.isGuest) {
      unawaited(PushService.I.start());
    }

    // ☁️ رفع ما تعذّرت مزامنته سابقاً (بلا انتظار — لا يؤخّر الإقلاع).
    SyncService.I.flushPending();

    await ThemeController.I.load();   // 🌗 يرحّل المفتاح القديم ويحفظ الاختيار

    return const SplashScreen();
  }

  /// 📦 حكمُ النسخة — يُملأ في [firstScreen] وتقرؤه شاشة البداية.
  ///
  /// ⚠️ يُحفظ هنا لا يُعاد حسابه: الفحص رحلةُ شبكة، وتكرارها لأجل عرض
  ///    الشاشة نفسها يعني انتظاراً مضاعفاً على شبكةٍ بطيئة.
  static VersionVerdict versionVerdict = VersionVerdict.none;

  /// الوجهة بعد شاشة البداية.
  /// ★ التحقق من البريد بوابة حقيقية: حساب غير مفعّل يذهب لشاشة التحقق
  ///   لا للرئيسية — والباك اند يرفض طلباته أيضاً ([27§7]).
  static Future<AppEntry> firstScreen() async {
    // 📦 **قبل كل شيء آخر**: نسخةٌ لا تتفاهم مع الخادم لا معنى لتوجيهها
    //    إلى تسجيلٍ أو رئيسية — كلاهما سيفشل أمام الطالب برسائل غامضة.
    //    والفحص يفشل مفتوحاً، فلا يحجب أحداً بسبب عطل شبكة ([VersionGate]).
    versionVerdict = await VersionGate.check();
    if (versionVerdict.updateRequired) return AppEntry.forceUpdate;

    final prefs = await SharedPreferences.getInstance();
    final isFirstRun = prefs.getBool(PrefsKeys.isFirstRun) ?? true;
    if (isFirstRun) return AppEntry.onboarding;
    if (UserSession.I.needsVerification) return AppEntry.verifyEmail;
    if (!UserSession.I.loggedIn) return AppEntry.auth;
    return AppEntry.home;
  }

  /// يُستدعى عند إنهاء شاشات الترحيب.
  static Future<void> markOnboardingDone() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(PrefsKeys.isFirstRun, false);
  }
}

enum AppEntry { forceUpdate, onboarding, auth, verifyEmail, home }
