import 'package:flutter/foundation.dart';

// ==========================================
// ⚙️ إعدادات التطبيق المركزية
// ==========================================
// كل القيم الحساسة/البيئية تُمرّر وقت البناء عبر --dart-define بدل كتابتها
// صريحة داخل الكود، مثال:
//   flutter build apk --dart-define=API_BASE_URL=https://... --dart-define=ACCESS_CODE=SUPER_USER
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

  // الرابط الفعّال حسب المنصة (نفس منطق التطبيق الأصلي)
  static String get baseUrl => kIsWeb ? _webBaseUrl : _prodBaseUrl;

  // 🔑 كود الوصول المرسل مع كل طلب (مبدئياً SUPER_USER لمطابقة الباك)
  static const String accessCode = String.fromEnvironment(
    'ACCESS_CODE',
    defaultValue: 'SUPER_USER',
  );

  // ⏱️ المهلات الزمنية
  static const Duration askTimeout = Duration(seconds: 60);
  static const Duration contentTimeout = Duration(seconds: 10);
}
