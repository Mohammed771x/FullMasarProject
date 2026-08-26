// ==========================================
// 📦 نموذج استجابة /ask
// ==========================================
class AskResponse {
  final String answer;
  final List<dynamic> references;
  final bool sessionActive;

  const AskResponse({
    required this.answer,
    required this.references,
    required this.sessionActive,
  });

  // نفس قراءة الحقول الأصلية حرفياً (مع القيم الافتراضية ذاتها)
  factory AskResponse.fromJson(Map<String, dynamic> json) => AskResponse(
        answer: json["answer"] ?? "لا يوجد رد",
        references: json["references"] ?? [],
        sessionActive: json["session_active"] ?? false,
      );
}
