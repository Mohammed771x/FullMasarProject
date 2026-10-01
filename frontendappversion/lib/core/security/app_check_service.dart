import 'dart:async';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

// ==========================================
// 📱 App Check — «هذا الطلب من نسخة مسار الأصلية»
// ==========================================
// ☢️ **لماذا (فحص الأمان 2026-10-01):** مفتاحُ Firebase علنيٌّ بالتصميم،
//    فسكربتٌ يصنع حساباتِ زوّارٍ بلا عدد ويأخذ أسئلةَ كلٍّ منها. توكنُ
//    App Check لا يصدر إلا لتطبيقٍ أصليّ على جهازٍ حقيقي (Play Integrity ·
//    DeviceCheck)، والخادمُ يقرؤه في ترويسة `X-Firebase-AppCheck`
//    ([Backend/core/app_check.py]) قبل أي نداء موديل.
//
// ⚖️ **متزامنٌ عن قصد:** `ApiClient.authHeaders` تُنادى في ١٦ موضعاً بلا
//    `await`، فالتوكنُ يُحفظ هنا ويُحدَّث بنفسه (`onTokenChange`) — لا يُطلب
//    مع كل طلب. وغيابُه (أول ثوانٍ من الإقلاع · فشل التهيئة) يعني طلباً
//    بلا ترويسة: الخادمُ في وضع `monitor` يعدّه ولا يمنعه.
//
// 🧪 **نسخُ التطوير** تستعمل مزوّد التصحيح: يطبع توكنَ تصحيحٍ في السجل عند
//    أول تشغيل، يُسجَّل في Firebase Console ← App Check ← Manage debug tokens.
//    بدون تسجيله يرفضه الخادمُ حين يُشغَّل وضعُ المنع.
class AppCheckService {
  AppCheckService._();

  static String? _token;
  static StreamSubscription<String?>? _sub;

  /// آخر توكنٍ صالح — أو `null` قبل أن يصل.
  static String? get token => _token;

  /// للاختبارات وحدها — بلا Firebase ولا منصّة.
  @visibleForTesting
  static set tokenForTest(String? value) => _token = value;

  /// يُنادى **بـawait** بعد `Firebase.initializeApp` مباشرةً وقبل أي نداء
  /// للتوثيق أو Firestore. لا يرمي، ولا ينتظر التوكن نفسه.
  ///
  /// ⚠️ **الترتيبُ شرطٌ لا تفضيل** (قيسَ في المحاكي 2026-10-01): في iOS يُنشئ
  ///    أولُ نداءٍ من Auth/Firestore نسخةَ App Check بمزوّدها الافتراضي
  ///    (DeviceCheck) — فإن سبق `activate` ضاع مزوّدُ التصحيح وظهر:
  ///    «DeviceCheckProvider is not supported on current platform».
  ///    لذلك التفعيلُ هنا منتظَر، وجلبُ التوكن وحده في الخلفية.
  static Future<void> start() async {
    // 🌐 الويب يحتاج reCAPTCHA ومفتاحَ موقع — غير مضبوطين، فلا تفعيل.
    if (kIsWeb) return;
    final FirebaseAppCheck appCheck;
    try {
      appCheck = FirebaseAppCheck.instance;
      await appCheck.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode
            ? const AppleDebugProvider()
            : const AppleDeviceCheckProvider(),
      );
    } catch (e) {
      // 🛟 بلا توكن يبقى التطبيق يعمل كما كان — الخادمُ هو من يقرّر.
      debugPrint("⚠️ App Check (تفعيل): $e");
      return;
    }
    unawaited(_fetch(appCheck));
  }

  static Future<void> _fetch(FirebaseAppCheck appCheck) async {
    try {
      await appCheck.setTokenAutoRefreshEnabled(true);
      _sub ??= appCheck.onTokenChange.listen((t) {
        if (t != null && t.isNotEmpty) _token = t;
      });
      final first = await _getOnce(appCheck) ??
          // 🔁 **محاولةٌ ثانية لا أكثر** (قيسَ في المحاكي 2026-10-01): أولُ
          //    `getToken` يلتحق بطلبٍ بدأه SDK قبل `activate` بمزوّده
          //    الافتراضي، فيعود بخطأ DeviceCheck رغم أن مزوّد التصحيح صار
          //    فعّالاً. الثاني يمرّ بالمزوّد الصحيح.
          await Future<void>.delayed(const Duration(seconds: 2))
              .then((_) => _getOnce(appCheck));
      if (first != null && first.isNotEmpty) {
        _token = first;
        debugPrint("📱 App Check: توكنٌ جاهز");
      }
    } catch (e) {
      debugPrint("⚠️ App Check (توكن): $e");
    }
  }

  static Future<String?> _getOnce(FirebaseAppCheck appCheck) async {
    try {
      return await appCheck.getToken();
    } catch (e) {
      debugPrint("⚠️ App Check (توكن): $e");
      return null;
    }
  }
}
