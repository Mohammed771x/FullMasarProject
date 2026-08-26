import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../error/exceptions.dart';

// ==========================================
// 🌐 عميل الشبكة المركزي
// ==========================================
// يوحّد الهيدرات والمهلات وفك ترميز UTF-8 لكل الطلبات،
// بدل تكرارها يدوياً في كل دالة كما في الكود القديم.
class ApiClient {
  ApiClient([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  // هيدر طلبات المحتوى (GET)
  static const Map<String, String> contentHeaders = {
    "ngrok-skip-browser-warning": "true",
  };

  // هيدر طلبات JSON (POST)
  static const Map<String, String> jsonHeaders = {
    "Content-Type": "application/json",
    "ngrok-skip-browser-warning": "true",
  };

  // GET يرجع الـ Response خام (مع الهيدر والمهلة الموحّدة)
  Future<http.Response> getRaw(String url, {Duration? timeout}) {
    return _client
        .get(Uri.parse(url), headers: contentHeaders)
        .timeout(timeout ?? AppConfig.contentTimeout);
  }

  // GET يرجع قائمة نصوص (الاستخدام الأكثر شيوعاً: الوحدات/الدروس/السنوات)
  Future<List<String>> getStringList(String url, {Duration? timeout}) async {
    final res = await getRaw(url, timeout: timeout);
    if (res.statusCode != 200) {
      throw ServerException(res.statusCode);
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return decoded.map((e) => e.toString()).toList();
  }

  void close() => _client.close();
}
