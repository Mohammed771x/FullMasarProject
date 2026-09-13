import '../data/models/chat_model.dart';

// ==========================================
// 🔎 البحث في المحادثات — دالّةٌ خالصة تُختبر وحدها
// ==========================================
// 🔴 **لماذا صار لازماً:** بعد شهرين من الاستعمال يصير عند الطالب عشرات
//    المحادثات في القائمة الجانبية، مرتّبةً بالأحدث بلا أي وسيلة للوصول
//    إلى واحدةٍ بعينها إلا التمرير. و«اشرح لي الأكسدة» التي كتبها قبل
//    أسبوعين تصير غير موجودة عملياً.
//
// 📴 **البحث محليّ بالكامل** — على `Hive` لا على السحابة: يعمل بلا إنترنت،
//    ولا يكلّف قراءةً واحدة في Firestore. ومحادثاتُ الطالب كلها على جهازه
//    أصلاً ([conversation_sync.dart]).
//
// 🔤 **والتطبيع عربيٌّ لا لاتينيّ:** `toLowerCase` وحدها لا تفيد العربية.
//    الطالب يكتب «الاكسده» ويبحث عن «الأكسدة» — همزةٌ وتاءٌ مربوطة وتشكيل.
//    وبلا توحيدها يفشل البحث على كلماتٍ **موجودةٍ حرفياً** أمامه، فيستنتج
//    أن الميزة معطوبة. وهذا التطبيع نفسه يُطبَّق في الخادم
//    ([Backend/subjects/common.py::normalize_arabic]) — والاتفاق مقصود.
class ConversationSearch {
  ConversationSearch._();

  /// يوحّد النص للمقارنة: الألفات · التاء المربوطة · الألف المقصورة ·
  /// التشكيل · التطويل · حالة الأحرف اللاتينية.
  static String normalize(String text) {
    if (text.isEmpty) return text;
    return text
        .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[ً-ٰٟ]'), '')  // التشكيل
        .replaceAll('ـ', '')                          // التطويل ـــ
        .toLowerCase()
        .trim();
  }

  /// هل تطابق هذه المحادثة الاستعلام؟ (العنوان أو أيّ نصّ رسالة)
  ///
  /// ⚠️ يبحث في **نصوص الرسائل** لا في العنوان وحده: العنوان مقتطعٌ من أول
  ///    سؤال عند ٥٠ حرفاً، فالكلمة التي يتذكّرها الطالب غالباً في متن
  ///    المحادثة لا في عنوانها.
  static bool matches(ChatConversation conv, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    if (normalize(conv.title).contains(normalizedQuery)) return true;
    for (final m in conv.messages) {
      if (normalize(m.text).contains(normalizedQuery)) return true;
    }
    return false;
  }

  /// يصفّي القائمة مع **الحفاظ على ترتيبها الأصلي** (الأحدث أولاً).
  static List<ChatConversation> filter(
      List<ChatConversation> conversations, String query) {
    final q = normalize(query);
    if (q.isEmpty) return conversations;
    return conversations.where((c) => matches(c, q)).toList();
  }

  /// 📄 مقتطفٌ يُظهر **أين** وُجدت الكلمة داخل المحادثة.
  ///
  /// ⭐ بدونه تعرض النتائج عناوينَ متشابهة («شرح درس: الأكسدة») ولا يعرف
  ///    الطالب أيَّها يفتح. والمقتطف يجعل الاختيار فورياً.
  ///
  /// يعيد نصاً فارغاً إن كان التطابق في العنوان وحده — فلا مقتطف يُضاف.
  static String snippet(ChatConversation conv, String query,
      {int radius = 34}) {
    final q = normalize(query);
    if (q.isEmpty) return "";
    for (final m in conv.messages) {
      final normalized = normalize(m.text);
      final at = normalized.indexOf(q);
      if (at < 0) continue;
      // ⚠️ القصّ على **النص الأصلي** بمؤشّرات النص المطبَّع: التطبيع هنا
      //    يستبدل حرفاً بحرف ولا يحذف إلا التشكيل والتطويل، فقد ينزاح
      //    المؤشّر قليلاً في نصٍّ مشكَّل. والانزياح يوسّع النافذة ولا
      //    يكسرها — ولذلك تُقصّ بهامشٍ من الجانبين لا بدقّةٍ حرفية.
      final source = m.text;
      final start = (at - radius).clamp(0, source.length);
      final end = (at + q.length + radius).clamp(0, source.length);
      final cut = source.substring(start, end).replaceAll('\n', ' ').trim();
      return "${start > 0 ? '…' : ''}$cut${end < source.length ? '…' : ''}";
    }
    return "";
  }
}
