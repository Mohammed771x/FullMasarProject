import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import 'models/quiz_models.dart';

// ==========================================
// 🧠 مستودع «اختبر نفسك» — POST /quiz/generate
// ==========================================
// الأسئلة تُولَّد من دروس الطالب وتعيش في الذاكرة حتى نهاية الاختبار.
class QuizGeneration {
  final List<QuizQuestion> questions;
  final List<String> lessons;
  final String unit;

  /// رسالة ودّية من الخادم حين يتعذّر التوليد (محتوى غير مضاف، حصة، منهج).
  final String? message;
  final bool quotaExceeded;
  final bool isGuest;

  const QuizGeneration({
    required this.questions,
    this.lessons = const [],
    this.unit = "",
    this.message,
    this.quotaExceeded = false,
    this.isGuest = false,
  });

  bool get isEmpty => questions.isEmpty;
}

class QuizRepository {
  QuizRepository([http.Client? client]) : _client = client ?? http.Client();

  final http.Client _client;

  /// توليد اختبار. يرمي عند أعطال الشبكة فقط — أما «لا محتوى» و«انتهت الحصة»
  /// فتصل كرسائل داخل [QuizGeneration.message] لتُعرض للطالب كما هي.
  Future<QuizGeneration> generate({
    required String subject,
    required int grade,
    required String track,
    required String unit,
    required List<String> lessons,
    required int count,
    String? idToken,
    String userId = "",
    String deviceId = "",
  }) async {
    final res = await _client
        .post(
          Uri.parse("${AppConfig.baseUrl}/quiz/generate"),
          headers: ApiClient.authHeaders(idToken),
          body: jsonEncode({
            "user_id": userId,
            "code": AppConfig.accessCode,
            "device_id": deviceId,
            "subject": subject,
            "grade": grade,
            "track": track,
            "unit": unit,
            "lessons": lessons,
            "count": count,
          }),
        )
        .timeout(const Duration(seconds: 90),
            onTimeout: () => throw TimeoutException("quiz timeout"));

    if (res.statusCode != 200 && res.statusCode != 429) {
      throw HttpException("Server error: ${res.statusCode}");
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final raw = (data["questions"] as List?) ?? const [];
    return QuizGeneration(
      questions: raw
          .map((e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      lessons: List<String>.from(data["lessons"] ?? const []),
      unit: (data["unit"] ?? "").toString(),
      message: (data["answer"] ?? "").toString().isEmpty ? null : data["answer"].toString(),
      quotaExceeded: data["quota_exceeded"] == true,
      isGuest: data["is_guest"] == true,
    );
  }
}
