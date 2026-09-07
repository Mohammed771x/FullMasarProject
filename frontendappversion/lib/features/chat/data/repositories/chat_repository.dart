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
    required int grade,
    required String track,
    String? contentMode,
    List<String> imagesBase64 = const [],
    String? idToken,
  }) async {
    // إغلاق أي اتصال سابق للتنظيف
    try {
      _activeClient?.close();
    } catch (_) {}

    _activeClient = http.Client();

    final response = await _activeClient!
        .post(
          Uri.parse(ApiEndpoints.ask()),
          headers: ApiClient.authHeaders(idToken),
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
            // ★ الصف والمسار: الباك اند الحالي يخدم الثالث العلمي ويتجاهل هذين
            //   الحقلين (Pydantic يتجاهل الحقول الزائدة افتراضياً). عند إضافة
            //   دعم الصفوف في الخادم يبدأ باستخدامهما دون أي تغيير هنا.
            "grade": grade,
            "track": track,
            // 🆕 وضع المحتوى: "lessons" | "pages" — غيابه = المسار القديم حرفياً
            if (contentMode != null) "content_mode": contentMode,
            // 📷 الصور (حتى صورتين): الخادم يستخرج نصها بجيميناي ثم يتجاهلها فوراً
            if (imagesBase64.isNotEmpty) "images_base64": imagesBase64,
          }),
        )
        .timeout(
          AppConfig.askTimeout,
          onTimeout: () => throw TimeoutException("Timeout after 60s"),
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AskResponse.fromJson(data);
    }

    // 429 مع رسالة = انتهت الحصة، و401/403 = مشكلة توثيق.
    // الثلاثة ردود **مفهومة** لا أعطال شبكة: نعرض رسالة الخادم كما هي.
    if (response.statusCode == 429 || response.statusCode == 401 || response.statusCode == 403) {
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if ((data["answer"] ?? "").toString().isNotEmpty) return AskResponse.fromJson(data);
      } catch (_) {}
    }
    throw HttpException("Server error: ${response.statusCode}");
  }

  /// 👨‍🏫 طلب مساعد المعلم — نفس العميل القابل للإلغاء ونفس معالجة الأخطاء.
  ///
  /// ⭐ **نقطة واحدة للتوليد والمتابعة**: `generate: true` عند ضغط زرّ الأداة،
  ///    و`false` لكل رسالة بعده. الخادم يبدّل البرومبت بناءً عليه، فتبقى
  ///    المحادثة **واحدة متصلة** بدل جلستين منفصلتين.
  Future<AskResponse> teacherAsk({
    required String userId,
    required String code,
    required String deviceId,
    required String tool,
    required bool generate,
    required String subject,
    required int grade,
    required String track,
    required String unitName,
    required String lessonName,
    required String content,
    required List<Map<String, dynamic>> chatHistory,
    String concept = "",
    String difficulty = "متوسط",
    int count = 10,
    List<String> imagesBase64 = const [],
    String? idToken,
  }) async {
    try {
      _activeClient?.close();
    } catch (_) {}

    _activeClient = http.Client();

    final response = await _activeClient!
        .post(
          Uri.parse(ApiEndpoints.teacherAsk()),
          headers: ApiClient.authHeaders(idToken),
          body: jsonEncode({
            "user_id": userId,
            "code": code,
            "device_id": deviceId,
            "tool": tool,
            "generate": generate,
            "subject": subject,
            "grade": grade,
            "track": track,
            "unit_name": unitName,
            "lesson_name": lessonName,
            "content": content,
            "concept": concept,
            "difficulty": difficulty,
            "count": count,
            "chat_history": chatHistory,
            if (imagesBase64.isNotEmpty) "images_base64": imagesBase64,
          }),
        )
        .timeout(
          AppConfig.askTimeout,
          onTimeout: () => throw TimeoutException("Timeout after 60s"),
        );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AskResponse.fromJson(data);
    }

    // نفس سياسة /ask: 429/401/403 ردودٌ **مفهومة** لا أعطال شبكة.
    if (response.statusCode == 429 || response.statusCode == 401 || response.statusCode == 403) {
      try {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        if ((data["answer"] ?? "").toString().isNotEmpty) return AskResponse.fromJson(data);
      } catch (_) {}
    }
    throw HttpException("Server error: ${response.statusCode}");
  }

  /// 🎤 تنظيف نص التسجيل الصوتي عبر /voice/clean.
  /// يرجع النص الخام نفسه عند أي فشل — الميزة لا تعطّل الطالب أبداً.
  Future<String> cleanVoiceText({
    required String userId,
    required String code,
    required String deviceId,
    required String rawText,
    String subject = "",
    String? idToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse(ApiEndpoints.voiceClean()),
            headers: ApiClient.authHeaders(idToken),
            body: jsonEncode({
              "user_id": userId,
              "code": code,
              // 📚 المادة قرينةٌ ترجّح المصطلح عند الالتباس الصوتي.
              "subject": subject,
              "device_id": deviceId,
              "text": rawText,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final cleaned = (data["text"] ?? "").toString().trim();
        if (cleaned.isNotEmpty) return cleaned;
      }
    } catch (_) {}
    return rawText;
  }

  /// إيقاف الطلب الجاري (يغلق العميل فيُلغى الـ Future قيد التنفيذ).
  void cancel() {
    try {
      _activeClient?.close();
    } catch (_) {}
    _activeClient = null;
  }
}
