import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

// ==========================================
// ⚙️ إعدادات التطبيق المركزية
// ==========================================
// كل القيم الحساسة/البيئية تُمرّر وقت البناء عبر --dart-define بدل كتابتها
// صريحة داخل الكود، مثال:
//   flutter build apk --dart-define=API_BASE_URL=https://...
// مع قيم افتراضية آمنة للتطوير حتى لا ينكسر التشغيل المحلي.
class AppConfig {
  AppConfig._();

  // 🌐 رابط السيرفر للإنتاج (قابل للتغيير وقت البناء دون لمس الكود)
  static const String _prodBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://mohammed771-my-tutor-backend.hf.space',
  );

  // 🌐 رابط السيرفر المحلي للويب
  static const String _webBaseUrl = String.fromEnvironment(
    'API_BASE_URL_WEB',
    defaultValue: 'http://127.0.0.1:8000',
  );

  // 📱 خادم التطوير على الشبكة المحلية (لتجربة الجوال الحقيقي).
  //
  // ⭐ **اسم mDNS لا عنوان IP** — وهذا ما أنهى فخّاً تكرّر ثلاث مرات:
  //    عنوان الماك يتغيّر بالـDHCP (`.35` ← `.63` ← `.35` في يومين)، وهو
  //    مدفونٌ **وقت البناء**، فيظل التطبيق ينادي عنواناً لم يعد لأحد ويظهر
  //    «لا يوجد اتصال بالإنترنت» بينما الإنترنت يعمل تماماً.
  //    اسم `.local` يبقى ثابتاً مهما تغيّر العنوان.
  //
  // ⚠️ يلزمه في `Info.plist`: `NSAllowsLocalNetworking` (موجود) و
  //    `NSLocalNetworkUsageDescription` (موجود) — وiOS يسأل الطالب مرة.
  // ⚠️ يتغيّر فقط لو غيّرتَ اسم الماك: `scutil --get LocalHostName`.
  //    وللتجاوز: `--dart-define=API_BASE_URL_LAN=http://<عنوان>:8000`
  //
  // ⚠️ يُستخدم في وضع Debug **على جهاز حقيقي وحده** — المحاكي يستعمل
  //    `127.0.0.1` (أدناه)، ونسخ Release تذهب لخادم الإنتاج دائماً.
  static const String _devLanBaseUrl = String.fromEnvironment(
    'API_BASE_URL_LAN',
    defaultValue: 'http://MFDs-MacBook-Air.local:8000',
  );

  /// هل نعمل داخل محاكي iOS؟
  ///
  /// ⭐ **لماذا هذا الفحص موجود:** المحاكي يشارك شبكة الماك، فيصل إلى
  ///    `127.0.0.1` دائماً. أما عنوان الشبكة المحلية (`192.168.x.y`) فيتغيّر
  ///    بالـDHCP — وقد سقط الفحص فعلاً مرتين لأن العنوان المدفون وقت البناء
  ///    صار قديماً (`.35` ← `.63`)، والعرَض المضلّل: «لا يوجد اتصال بالإنترنت»
  ///    بينما الإنترنت يعمل. الجهاز الحقيقي وحده هو من يحتاج عنوان الشبكة.
  static bool get _isIosSimulator {
    if (kIsWeb) return false;
    try {
      if (!Platform.isIOS) return false;
      // إشارتان لا واحدة: متغيّر البيئة **لا يصل** لعملية التطبيق حين
      //   يُشغَّل بـ`simctl launch`، فنسند إليه مسار الملف التنفيذي —
      //   وهو تحت `CoreSimulator/Devices/…` في المحاكي وحده.
      return Platform.environment.containsKey('SIMULATOR_DEVICE_NAME') ||
          Platform.resolvedExecutable.contains('/CoreSimulator/');
    } catch (_) {
      return false;
    }
  }

  // الرابط الفعّال حسب المنصة
  static String get baseUrl {
    final url = _resolveBaseUrl();
    // 🩺 يُطبع مرة واحدة في التطوير: «لا يوجد اتصال بالإنترنت» ضلّلنا مرتين
    //    وسببه عنوانٌ قديم لا انقطاعُ شبكة. طباعته تُنهي التخمين.
    if (kDebugMode && !_announced) {
      _announced = true;
      debugPrint("🌐 AppConfig.baseUrl = $url "
          "(محاكي: $_isIosSimulator · ويب: $kIsWeb)");
    }
    return url;
  }

  static bool _announced = false;

  static String _resolveBaseUrl() {
    if (kIsWeb) return _webBaseUrl;
    if (kDebugMode) {
      // المحاكي يشارك شبكة الماك ⇒ العنوان المحلي ثابت لا يتغيّر بالـDHCP.
      if (_isIosSimulator) return _webBaseUrl;
      if (_devLanBaseUrl.isNotEmpty) return _devLanBaseUrl;
    }
    return _prodBaseUrl;
  }

  // 🗑️ **`accessCode` حُذف بالكامل** (2026-09-08).
  //
  // 🔴 كان `String.fromEnvironment('ACCESS_CODE', defaultValue: 'SUPER_USER')`
  //    يُرسَل مع كل طلب، ونوعه على الخادم `master` ⇒ بلا ربط جهاز، بلا حصة،
  //    بلا حظر، بلا تحقق بريد. أي أن **استخراج نصٍّ واحد من الـAPK كان يفتح
  //    فاتورة الموديلات كلها**.
  //
  // ⚠️ و`--obfuscate` لا يحمي منه: التشويش يعيد تسمية الرموز **ولا يخفي
  //    النصوص الثابتة** — `strings app.so | grep SUPER` كان يكفي. وتمريره
  //    بـ`--dart-define` لا يغيّر شيئاً: القيمة تُدفَن في الملف التنفيذي
  //    وقت البناء كما هي.
  //
  // ✅ البديل: توكن Firebase قصير العمر يتجدّد تلقائياً ويُربط بحسابٍ حقيقي.

  // ⏱️ المهلات الزمنية
  //
  // ⚠️ **مهلة `/ask` أطول من مهلة الخادم عمداً**: قطعُ العميل قبل أن ينهي
  //    الخادمُ عملَه يعني حصةً خُصمت وجواباً ضاع. و`request_id` يمنع الخصم
  //    المزدوج عند الإعادة، لكن انتظارَ الجواب أصلاً أفضل من إعادته.
  static const Duration askTimeout = Duration(seconds: 90);
  static const Duration contentTimeout = Duration(seconds: 20);
}
