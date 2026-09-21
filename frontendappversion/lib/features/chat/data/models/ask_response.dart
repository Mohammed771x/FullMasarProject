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

  /// 🎟️ **رُدَّ السؤالُ إلى الحصة**: الخادم لم ينادِ موديلاً (سؤالٌ خارج
  /// الوحدة · لا وحدة · لا صفحات)، فلا يُنقص العدّادُ المحليّ شيئاً.
  /// بدونها يرى الطالب رقماً أقلّ من الحقيقة حتى يُعيد فتح التطبيق.
  final bool quotaRefunded;

  /// 🚫 **ردٌّ بلا جواب**: الخادم لم يجد في الوحدة ما يخصّ السؤال. يُعرض
  /// للطالب ولا يُرسل في السجلّ — لا هو ولا السؤال الذي أثاره.
  final bool offTopic;

  /// ⚡ **جاء الجوابُ من الشرح المحفوظ** لا من الموديل
  /// ([core/lesson_cache] على الخادم) — فيصل في جزءٍ من الثانية وبلا خصمٍ
  /// من الحصة. تعرضه الواجهةُ بوسمٍ صغير: سألني المالك «ما أدري هل يجي من
  /// المخزون ولا لا» — والجوابُ يجب أن يكون **مرئياً** لا مقيساً بالسرّ.
  final bool cached;

  /// 📄 نصّ الصورة كما قرأه الخادم — يُخزَّن مع رسالة الطالب ويُرسل في
  /// السياق لاحقاً. بدونه تُنسى الصورة في السؤال التالي (التاريخ نصٌّ لا صور).
  final String imageText;

  const AskResponse({
    required this.answer,
    required this.references,
    required this.sessionActive,
    this.quotaExceeded = false,
    this.isGuest = false,
    this.quotaRefunded = false,
    this.offTopic = false,
    this.imageText = "",
    this.cached = false,
  });

  // نفس قراءة الحقول الأصلية حرفياً (مع القيم الافتراضية ذاتها)
  factory AskResponse.fromJson(Map<String, dynamic> json) => AskResponse(
        answer: json["answer"] ?? "لا يوجد رد",
        references: json["references"] ?? [],
        sessionActive: json["session_active"] ?? false,
        quotaExceeded: json["quota_exceeded"] == true,
        isGuest: json["is_guest"] == true,
        quotaRefunded: json["quota_refunded"] == true,
        offTopic: json["off_topic"] == true,
        imageText: (json["extracted_text"] ?? "").toString(),
        cached: json["cached"] == true,
      );
}
