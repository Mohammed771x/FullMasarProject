import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'prefs_keys.dart';

// ==========================================
// 🔐 التخزين الآمن للمعرّفات الحساسة
// ==========================================
// device_id كان مخزّناً نصاً صريحاً في SharedPreferences. نقلناه إلى
// flutter_secure_storage (Keychain على iOS / Keystore على Android)
// مع ترحيل تلقائي للمستخدمين الحاليين حتى لا يتغيّر معرّفهم.
class SecureStorage {
  SecureStorage._();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _kDeviceId = 'secure_device_id';

  /// يرجع معرّف الجهاز، وينشئه ويخزّنه بأمان إن لم يكن موجوداً.
  /// يرحّل القيمة القديمة من SharedPreferences إن وُجدت.
  /// مقاوم للأعطال: لو فشل التخزين الآمن (أجهزة قديمة جداً مثلاً)
  /// يعود للتخزين العادي بدل أن ينهار التطبيق.
  static Future<String> getOrCreateDeviceId() async {
    try {
      String? id = await _storage.read(key: _kDeviceId);
      if (id != null && id.isNotEmpty) return id;

      // ترحيل من التخزين القديم (SharedPreferences) إن وُجد
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(PrefsKeys.deviceId);
      id = (legacy != null && legacy.isNotEmpty) ? legacy : const Uuid().v4();

      await _storage.write(key: _kDeviceId, value: id);
      // تنظيف النسخة النصية القديمة بعد الترحيل
      if (legacy != null) {
        await prefs.remove(PrefsKeys.deviceId);
      }
      return id;
    } catch (_) {
      // 🛟 خطة بديلة: تخزين عادي (لا ينهار التطبيق على أي جهاز)
      return _fallbackDeviceId();
    }
  }

  static Future<String> _fallbackDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(PrefsKeys.deviceId);
    if (existing != null && existing.isNotEmpty) return existing;
    final id = const Uuid().v4();
    await prefs.setString(PrefsKeys.deviceId, id);
    return id;
  }
}
