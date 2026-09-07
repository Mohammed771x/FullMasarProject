// ==========================================
// 📦 نموذج استجابة /ask
// ==========================================
class AskResponse {
  final String answer;
  final List<dynamic> references;
  final bool sessionActive;

  /// 🎟️ انتهت حصة اليوم (أو أسئلة الزائر) — الواجهة تعرض دعوة للتسجيل.
  final bool quotaExceeded;
  final bool isGuest;

  /// 📄 نصّ الصورة كما قرأه الخادم — يُخزَّن مع رسالة الطالب ويُرسل في
  /// السياق لاحقاً. بدونه تُنسى الصورة في السؤال التالي (التاريخ نصٌّ لا صور).
  final String imageText;

  const AskResponse({
    required this.answer,
    required this.references,
    required this.sessionActive,
    this.quotaExceeded = false,
    this.isGuest = false,
    this.imageText = "",
  });

  // نفس قراءة الحقول الأصلية حرفياً (مع القيم الافتراضية ذاتها)
  factory AskResponse.fromJson(Map<String, dynamic> json) => AskResponse(
        answer: json["answer"] ?? "لا يوجد رد",
        references: json["references"] ?? [],
        sessionActive: json["session_active"] ?? false,
        quotaExceeded: json["quota_exceeded"] == true,
        isGuest: json["is_guest"] == true,
        imageText: (json["extracted_text"] ?? "").toString(),
      );
}
