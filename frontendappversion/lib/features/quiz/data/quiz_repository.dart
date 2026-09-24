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

  /// 💳 ردَّ الخادمُ الحصةَ لأن الاختبار لم يكلّف نداءَ موديل (جاء من
  /// البنك). فلا يُنقص العميلُ عدّادَه ([core/billing.settle_quota]).
  final bool quotaRefunded;

  const QuizGeneration({
    required this.questions,
    this.lessons = const [],
    this.unit = "",
    this.message,
    this.quotaExceeded = false,
    this.isGuest = false,
    this.quotaRefunded = false,
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
    String requestId = "",
    List<String> seenIds = const [],
  }) async {
    // حمولة محاولة ثابتة: 202/retry لا يعيدان قراءة إعدادات قابلة للتغيير.
    final encodedAttempt = jsonEncode({
      "user_id": userId,
      "request_id": requestId,
      "subject": subject,
      "grade": grade,
      "track": track,
      "unit": unit,
      "lessons": List<String>.of(lessons),
      "count": count,
      "seen_ids": List<String>.of(seenIds),
    });
    final deadline = DateTime.now().add(const Duration(seconds: 90));
    http.Response res;
    while (true) {
      res = await _client
          .post(
            Uri.parse("${AppConfig.baseUrl}/quiz/generate"),
            headers: ApiClient.authHeaders(idToken),
            body: encodedAttempt,
          )
          .timeout(
            const Duration(seconds: 90),
            onTimeout: () => throw TimeoutException("quiz timeout"),
          );
      if (res.statusCode != 202) break;
      if (!DateTime.now().isBefore(deadline)) {
        throw TimeoutException("quiz still in flight");
      }
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }

    if (res.statusCode != 200 && res.statusCode != 429) {
      throw HttpException("Server error: ${res.statusCode}");
    }

    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final raw = (data["questions"] as List?) ?? const [];
    return QuizGeneration(
      questions: raw
          .map(
            (e) => QuizQuestion.fromJson(Map<String, dynamic>.from(e as Map)),
          )
          .toList(),
      lessons: List<String>.from(data["lessons"] ?? const []),
      unit: (data["unit"] ?? "").toString(),
      message: (data["answer"] ?? "").toString().isEmpty
          ? null
          : data["answer"].toString(),
      quotaExceeded: data["quota_exceeded"] == true,
      isGuest: data["is_guest"] == true,
      quotaRefunded: data["quota_refunded"] == true,
    );
  }
}
