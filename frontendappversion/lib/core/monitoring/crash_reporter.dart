import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

import '../utils/safe_cut.dart';

// ==========================================
// 🧯 مراقبةُ الأعطال في نسخة الإنتاج
// ==========================================
// 🔴 **لماذا (فحص ٢٠٢٦-١٠-٠٢):** لم يكن في التطبيق `FlutterError.onError`
//    ولا `PlatformDispatcher.onError` ولا أيُّ مُبلِّغ — فكلُّ استثناءٍ عند
//    الطالب يموت على جهازه بلا أثر. استثناءُ النقر على نصّ الجواب مثلاً كان
//    يقع مع **كل** نقرة ولم يكن ليُعرف إلا بـ`flutter run` على المحاكي.
//
// 🔒 **وما لا يُرسَل أبداً — محتوى الطالب:**
//    • لا `setUserIdentifier` ولا مفاتيح مخصّصة ولا `log` — لا مُعرّفَ حساب
//      ولا بريد ولا اسم.
//    • نصُّ الاستثناء **يُنظَّف** قبل الرفع ([scrub]): أيُّ نصٍّ عربيّ يُستبدل
//      بـ«…» (العربيُّ في رسالة استثناءٍ هو كلامُ الطالب أو الموديل، لا
//      كلامُ الكود)، ويُقصّ إلى ٣٠٠ حرف، و`FormatException` يُرفع بلا مصدره
//      (`jsonDecode` يُلحق به مقطعاً من النصّ الذي فشل).
//    • و`FlutterErrorDetails` لا تُرفع بمعلوماتها التشخيصية الكاملة (قد تحمل
//      نصوصَ ودجتات) — النوعُ والسياقُ القصير والمكدّس وحدها.
//
// ⚙️ **مطفأٌ في التصحيح** — أعطالُ التطوير تُقرأ في الطرفية لا في اللوحة،
//    ولا تُخلط بأعطال الطلاب.
class CrashReporter {
  CrashReporter._();

  static bool _enabled = false;

  /// هل يُرفع شيءٌ الآن؟ (للاختبارات والتشخيص)
  static bool get enabled => _enabled;

  /// يُنادى بعد `Firebase.initializeApp` مباشرةً. لا يرمي أبداً.
  static Future<void> start() async {
    try {
      _enabled = kReleaseMode;
      await FirebaseCrashlytics.instance
          .setCrashlyticsCollectionEnabled(_enabled);
    } catch (e) {
      _enabled = false;
      debugPrint("⚠️ Crashlytics: $e");
      return;
    }

    // 🖼️ أعطالُ الإطار (بناء · رسم · إيماءات): تُعرض كما كانت في التصحيح،
    //    وتُرفع منظَّفةً في الإنتاج.
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      if (previous != null) {
        previous(details);
      } else {
        FlutterError.presentError(details);
      }
      _report(
        details.exception,
        details.stack,
        reason: details.context?.toDescription(),
        fatal: false,
      );
    };

    // ⚡ ما يفلت من الإطار كلِّه (Future بلا ممسك، عزلٌ آخر): انهيارٌ حقيقيّ.
    PlatformDispatcher.instance.onError = (error, stack) {
      _report(error, stack, fatal: true);
      return true;
    };
  }

  /// يرفع خطأً التُقط يدوياً (غير قاتل).
  static void record(Object error, StackTrace? stack, {String? reason}) =>
      _report(error, stack, reason: reason, fatal: false);

  static void _report(
    Object error,
    StackTrace? stack, {
    String? reason,
    required bool fatal,
  }) {
    if (!_enabled) return;
    try {
      unawaited(FirebaseCrashlytics.instance.recordError(
        ScrubbedError(error),
        stack,
        reason: reason == null ? null : scrub(reason),
        fatal: fatal,
        printDetails: false,
      ));
    } catch (_) {}
  }

  static final RegExp _arabicRun = RegExp(r'[؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]+(?:[\s؀-ۿݐ-ݿﭐ-﷿ﹰ-﻿]+)*');

  /// 🔒 نصٌّ آمنٌ للرفع: العربيُّ «…»، والطولُ ٣٠٠ حرفاً على الأكثر.
  @visibleForTesting
  static String scrub(String s) {
    final cleaned = s.replaceAll(_arabicRun, '«…»');
    // ✂️ `safeCut` لا `substring`: القصُّ لا يشطر رمزاً تعبيرياً نصفين.
    return cleaned.length <= 300 ? cleaned : '${safeCut(cleaned, 300)}…';
  }

  /// نصُّ الخطأ قبل التنظيف — بلا مصدر `FormatException`.
  @visibleForTesting
  static String describe(Object error) {
    if (error is FormatException) return 'FormatException: ${error.message}';
    return error.toString();
  }
}

/// غلافٌ يرفع **نوعَ** الخطأ ونصَّه منظَّفاً ([CrashReporter.scrub]).
/// المكدّسُ يُمرَّر بجانبه كما هو — أسماءُ دوالٍّ وملفاتٍ لا محتوى.
class ScrubbedError {
  ScrubbedError(Object error)
      : type = error.runtimeType.toString(),
        message = CrashReporter.scrub(CrashReporter.describe(error));

  final String type;
  final String message;

  @override
  String toString() => message.startsWith(type) ? message : '$type: $message';
}
