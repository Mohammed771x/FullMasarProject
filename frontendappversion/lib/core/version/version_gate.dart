import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../network/api_client.dart';

// ==========================================
// 📦 بوابة التحديث — تُضاف قبل أول نشر أو لا تُضاف أبداً
// ==========================================
// ⭐ **لماذا الآن لا لاحقاً:** يوم يتغيّر عقد الـAPI (حقلٌ يُحذف · مسارٌ
//    يُعاد تسميته · شكل ردٍّ يتبدّل)، تنكسر النسخُ القديمة في جيوب الطلاب
//    **صامتةً**: شاشاتٌ فارغة ورسائل «خطأ غير متوقع» لا يفهمها أحد. ولا
//    وسيلة لمخاطبتها — إلا أن تكون قد علّمتها **من قبل** أن تسأل.
//    وبعد النشر لا يمكن تعليم نسخةٍ منشورة أي شيء جديد.
//
// 🔢 **رقم البناء لا اسم الإصدار:** `1.0.0+6` ← الرقم بعد `+`. اسم الإصدار
//    نصٌّ للعرض ومقارنته تحتاج تفكيكاً وقواعد، ورقم البناء عددٌ صحيح يزيد
//    دائماً — فالمقارنة لا تحتمل خطأً.
//
// 🛟 **ويفشل مفتوحاً في كل اتجاه:** لا شبكة · ردٌّ مشوّه · إعداداتٌ غائبة
//    ⇒ «لا تحديث مطلوب». بوابةُ إنقاذٍ معطوبة يجب أن تحجب **نفسها** لا
//    التطبيق: طالبٌ يُمنع من الدراسة بسبب عطلٍ في فحص النسخة كارثةٌ أكبر
//    من النسخة القديمة نفسها.

/// رقم بناء هذه النسخة — يجب أن يطابق `version:` في `pubspec.yaml` (بعد `+`).
///
/// ⚠️ يُمرَّر وقت البناء لضمان التطابق مع ما يُرفع للمتجر:
///    `--dart-define=BUILD_NUMBER=7`
/// وقيمته الافتراضية تتبع `pubspec.yaml` يدوياً — ونسيانُ رفعها يعني بوابةً
/// تظنّ نفسها قديمة، لا العكس: أي أنها تُخطئ في الاتجاه الآمن.
const int kBuildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 6);

@immutable
class VersionVerdict {
  const VersionVerdict({
    this.updateRequired = false,
    this.updateAvailable = false,
    this.message = "",
    this.storeUrl = "",
  });

  /// النسخة أقدم من `min_build` ⇒ **تُحجب حتى التحديث**.
  final bool updateRequired;

  /// يوجد أحدث منها ⇒ يُقترح بلا إلزام.
  final bool updateAvailable;

  final String message;
  final String storeUrl;

  static const none = VersionVerdict();

  factory VersionVerdict.fromJson(Map<String, dynamic> j) => VersionVerdict(
        updateRequired: j["update_required"] == true,
        updateAvailable: j["update_available"] == true,
        message: (j["message"] ?? "").toString(),
        storeUrl: (j["store_url"] ?? "").toString(),
      );
}

class VersionGate {
  VersionGate._();

  static String get _platform {
    if (kIsWeb) return "web";
    try {
      if (Platform.isAndroid) return "android";
      if (Platform.isIOS) return "ios";
    } catch (_) {}
    return "other";
  }

  /// يسأل الخادم عن حال هذه النسخة. **لا يرمي أبداً.**
  ///
  /// ⏱️ مهلةٌ قصيرة عمداً (٦ ثوانٍ): هذا فحصٌ يسبق أول شاشة، وإطالته تعني
  ///    شاشة انتظارٍ يراها كل طالبٍ عند كل إقلاع على شبكةٍ بطيئة.
  static Future<VersionVerdict> check({http.Client? client}) async {
    final http.Client c = client ?? http.Client();
    try {
      final res = await c.get(
        Uri.parse("${AppConfig.baseUrl}/app/version"
            "?build=$kBuildNumber&platform=$_platform"),
        headers: ApiClient.contentHeaders,
      ).timeout(const Duration(seconds: 6));
      if (res.statusCode != 200) return VersionVerdict.none;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      if (data is! Map<String, dynamic>) return VersionVerdict.none;
      return VersionVerdict.fromJson(data);
    } catch (_) {
      return VersionVerdict.none;      // 🛟 فشلٌ مفتوح — راجع الرأس.
    } finally {
      if (client == null) c.close();
    }
  }
}
