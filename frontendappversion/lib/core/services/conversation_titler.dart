import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../session/user_session.dart';
import '../utils/safe_cut.dart';

// ==========================================
// 🏷️ اسمُ المحادثة من أول سؤال — نفس ChatGPT
// ==========================================
// 🎯 **طلبُ المالك (٢٠٢٦-٠٩-٢٤):** «أول سؤال من المحادثة خلّ الـAI يعطيه
//    اسم — نفس ChatGPT، أول سؤال فقط. ولو كان من المحفوظ: شرح درس كذا.
//    وفي كل مكان: التعليم والمعلم والمنح».
//
// ⚖️ **مرّةً واحدة لكل محادثة، بعد أول جواب** ([shouldName]): الاسمُ المؤقّت
//    (أولُ السؤال مقصوصاً) يظهر فوراً كما كان، ثم يُستبدل حين يصل الاسم.
//    وفشلُ الشبكة أو الموديل يُبقيه — لا رسالةَ خطأ على شيءٍ تجميليّ.
//
// 🔒 **ولا يُكتب فوق اسمٍ اختاره صاحبُ المحادثة**: المُنادي يقارن الاسمَ
//    الحاليّ بالمؤقّت قبل الإسناد ([applies]).
class ConversationTitler {
  ConversationTitler._();

  /// للاختبارات: يُستبدل النداءُ الحقيقيّ بدالة.
  @visibleForTesting
  static Future<String?> Function(String question, String answer,
      String subject, String section)? debugOverride;

  /// «شرح درس …» — اسمُ المحادثة التي بدأت بالشرح المخزون (بلا نداء).
  static String storedLessonTitle(String lesson) =>
      safeCut("شرح درس $lesson", 60);

  /// الاسمُ المؤقّت من أول رسالة — ما يُعرض حتى يصل اسمُ الموديل.
  static String provisional(String firstText) {
    final t = firstText.trim();
    if (t.isEmpty) return 'محادثة جديدة';
    return t.length > 50 ? '${safeCut(t, 47)}...' : t;
  }

  /// هل هذه لحظةُ التسمية؟ رسالةُ صاحبها الأولى وأولُ ردٍّ عليها — لا غير.
  static bool shouldName(List<Map<String, dynamic>> messages) =>
      messages.where((m) => m["role"] == "user").length == 1 &&
      messages.where((m) => m["role"] == "ai").length == 1;

  /// يُسنَد الاسمُ الجديد ما دام الحاليُّ هو المؤقّتَ نفسَه.
  static bool applies(String current, String provisionalTitle) =>
      current.trim().isEmpty ||
      current.trim() == 'محادثة جديدة' ||
      current.trim() == provisionalTitle.trim();

  /// الاسمُ من الخادم أو `null` — لا يرمي أبداً.
  static Future<String?> suggest({
    required String question,
    String answer = "",
    String subject = "",
    required String section,
  }) async {
    final q = question.trim();
    if (q.isEmpty) return null;
    final override = debugOverride;
    if (override != null) return override(q, answer, subject, section);
    try {
      final token = await UserSession.I.idToken();
      final res = await http
          .post(
            Uri.parse(ApiEndpoints.chatTitle()),
            headers: ApiClient.authHeaders(token),
            body: jsonEncode({
              // 📏 سقوفُ الخادم نفسُها (`TitleRequest`) — ما زاد يُرفض 422.
              "question": safeCut(q, 1800),
              "answer": safeCut(answer.trim(), 1800),
              "subject": safeCut(subject, 60),
              "section": section,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      final title = (data is Map ? data["title"] : null)?.toString().trim();
      if (title == null || title.isEmpty) return null;
      return safeCut(title, 60);
    } catch (e) {
      debugPrint('🏷️ تعذّرت تسميةُ المحادثة: $e');
      return null;
    }
  }
}
