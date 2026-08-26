import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/ask_response.dart';

// ==========================================
// 🤖 مستودع المحادثة (الاتصال بنقطة /ask)
// ==========================================
// يحتفظ بعميل HTTP قابل للإلغاء حتى نتمكّن من إيقاف الطلب أثناء التحميل،
// تماماً كما كان يفعل _activeHttpClient في الكود الأصلي.
class ChatRepository {
  http.Client? _activeClient;

  /// يرسل سؤالاً إلى السيرفر. يبني الجسم بنفس حقول الكود الأصلي حرفياً.
  /// يرمي [TimeoutException] / [SocketException] / [HttpException] عند الفشل.
  Future<AskResponse> ask({
    required String userId,
    required String code,
    required String deviceId,
    required String subject,
    required String mode,
    required String inputType,
    required int summaryLevel,
    required String lessonName,
    required String content,
    required String unitName,
    required List<Map<String, dynamic>> chatHistory,
  }) async {
    // إغلاق أي اتصال سابق للتنظيف
    try {
      _activeClient?.close();
    } catch (_) {}

    _activeClient = http.Client();

    final response = await _activeClient!
        .post(
          Uri.parse(ApiEndpoints.ask()),
          headers: ApiClient.jsonHeaders,
          body: jsonEncode({
            "user_id": userId,
            "code": code,
            "device_id": deviceId,
            "subject": subject,
            "mode": mode,
            "input_type": inputType,
            "summary_level": summaryLevel,
            "lesson_name": lessonName,
            "content": content,
            "unit_name": unitName,
            "chat_history": chatHistory,
          }),
        )
        .timeout(
          AppConfig.askTimeout,
          onTimeout: () => throw TimeoutException("Timeout after 60s"),
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AskResponse.fromJson(data);
    } else {
      throw HttpException("Server error: ${response.statusCode}");
    }
  }

  /// إيقاف الطلب الجاري (يغلق العميل فيُلغى الـ Future قيد التنفيذ).
  void cancel() {
    try {
      _activeClient?.close();
    } catch (_) {}
    _activeClient = null;
  }
}
