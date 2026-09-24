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
        .replaceAllMapped(_easternDigit, (m) => _westernDigit(m[0]!))
        .toLowerCase()
        .trim();
  }

  /// 🔢 **الأرقامُ الهنديّة والفارسية = اللاتينية** — لوحةُ الطالب العربية
  ///    تكتب «٤٥» والجوابُ فيه «45» (رُئي في المحاكي: «٥» بلا نتيجة).
  static final RegExp _easternDigit = RegExp(r'[٠-٩۰-۹]');

  static String _westernDigit(String d) {
    final c = d.codeUnitAt(0);
    final zero = c >= 0x06F0 ? 0x06F0 : 0x0660;
    return String.fromCharCode(0x30 + c - zero);
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

// ══════════════════════════════════════════════════
// 📍 نتائجُ البحث كما في ChatGPT — كلُّ موضعٍ ذُكرت فيه الكلمة
// ══════════════════════════════════════════════════
// 🎯 **طلبُ المالك (٢٠٢٦-٠٩-٢٤):** «لما نبحث ما يطلع لي وين المكان — يطلع
//    اسم المحادثة. ما أدري هل الكلام فعلاً هو اللي بغيته. خلّه يطلع كم سطر
//    من المكان الفعلي، نفس ChatGPT، والكلمة مغطّاة، ويوديني على المحادثة
//    المطلوبة — وكل النتائج اللي طلعت فيها الكلمة في كل المحادثات».
//
// ⚖️ **نتيجةٌ لكل رسالةٍ ذُكرت فيها** لا لكل محادثة: المحادثةُ الطويلة قد
//    تذكر «التناضح» في سؤالٍ وفي ثلاثة أجوبة، والمقصودُ أحدُها. وتُسقَف
//    بـ[maxHitsPerConversation] و[maxHits] كي لا تبتلع محادثةٌ واحدةٌ
//    القائمةَ ولا يثقل البحثُ على جوالٍ قديم.
//
// 🎯 **وموضعُ الكلمة دقيقٌ في النصّ الأصلي** ([_normalizeWithMap]): كان
//    المقتطفُ يقصّ النصَّ الأصليَّ بمؤشّر النصّ المطبَّع، والتشكيلُ يُحذف في
//    التطبيع فينزاح المؤشّر — مقبولٌ لمقتطفٍ تقريبيّ، لا لكلمةٍ تُلوَّن.

/// رسالةٌ كما يراها البحث — يملؤها كلُّ قسمٍ من نموذجه.
class SearchableMessage {
  const SearchableMessage(this.text, {required this.isUser});
  final String text;
  final bool isUser;
}

/// موضعٌ واحدٌ وُجدت فيه الكلمة.
class SearchHit<T> {
  const SearchHit({
    required this.conversation,
    required this.messageIndex,
    required this.isUser,
    required this.before,
    required this.match,
    required this.after,
    this.position = 0,
  });

  final T conversation;

  /// 📍 موضعُ الكلمة في رسالتها نسبةً من طولها (٠…١) — كي يُمرَّر إليها هي
  ///    لا إلى أوّل رسالةٍ طويلة قد تكون الكلمةُ في ذيلها.
  final double position;

  /// ترتيبُ الرسالة في المحادثة — `-1` حين يكون التطابقُ في العنوان وحده.
  final int messageIndex;
  final bool isUser;

  /// المقتطف مقسوماً ثلاثاً كي تُلوَّن الكلمةُ وحدها.
  final String before;
  final String match;
  final String after;
}

abstract final class ConversationSearchHits {
  static const int maxHits = 80;
  static const int maxHitsPerConversation = 6;

  /// 📏 ما يُعرض قبل الكلمة وبعدها — «كم سطر» على عرض الجوال.
  ///    قبلها أقلّ من بعدها كي تبقى الكلمةُ في السطر الأول أو الثاني فلا
  ///    يقصّها حدُّ الأسطر الثلاثة.
  static const int contextBefore = 60;
  static const int contextAfter = 140;
}

/// 📍 كلُّ المواضع، مرتّبةً بترتيب المحادثات (الأحدثُ أولاً) ثم الرسائل.
List<SearchHit<T>> searchHits<T>(
  List<T> conversations,
  String query, {
  required String Function(T) titleOf,
  required List<SearchableMessage> Function(T) messagesOf,
}) {
  final q = ConversationSearch.normalize(query);
  if (q.isEmpty) return const [];
  final hits = <SearchHit<T>>[];
  for (final conv in conversations) {
    var inThis = 0;
    final msgs = messagesOf(conv);
    for (var i = 0; i < msgs.length; i++) {
      if (inThis >= ConversationSearchHits.maxHitsPerConversation) break;
      final hit = _hitIn(conv, i, msgs[i], q);
      if (hit == null) continue;
      hits.add(hit);
      inThis++;
      if (hits.length >= ConversationSearchHits.maxHits) return hits;
    }
    // 🏷️ في العنوان وحده (اسمٌ اختاره الطالب) ⇒ نتيجةٌ بلا مقتطف رسالة.
    if (inThis == 0) {
      final title = titleOf(conv);
      final found = _locate(title, q);
      if (found != null) {
        hits.add(SearchHit(
          conversation: conv,
          messageIndex: -1,
          isUser: true,
          before: title.substring(0, found.$1),
          match: title.substring(found.$1, found.$2),
          after: title.substring(found.$2),
        ));
        if (hits.length >= ConversationSearchHits.maxHits) return hits;
      }
    }
  }
  return hits;
}

SearchHit<T>? _hitIn<T>(T conv, int index, SearchableMessage m, String q) {
  final found = _locate(m.text, q);
  if (found == null) return null;
  final (start, end) = found;
  final src = m.text;
  var from = (start - ConversationSearchHits.contextBefore).clamp(0, src.length);
  var to = (end + ConversationSearchHits.contextAfter).clamp(0, src.length);
  // ✂️ على حدّ كلمة لا في منتصفها.
  if (from > 0) {
    final space = src.indexOf(' ', from);
    if (space != -1 && space < start) from = space + 1;
  }
  if (to < src.length) {
    final space = src.lastIndexOf(' ', to);
    if (space > end) to = space;
  }
  // 🧹 مقتطفٌ يُقرأ لا ترميزٌ يُرى: علاماتُ الماركداون («**» · «#» · «`»)
  //    كانت تظهر خاماً في النتائج (رُئي في المحاكي: «**2. العرض…**»).
  String flat(String s) => s
      .replaceAll(RegExp(r'\*\*|__|`+|^#{1,6}\s*', multiLine: true), '')
      .replaceAll(RegExp(r'^\s*[*\-•]\s+', multiLine: true), '')
      .replaceAll(RegExp(r'\s+'), ' ');
  return SearchHit(
    conversation: conv,
    messageIndex: index,
    isUser: m.isUser,
    before: "${from > 0 ? '…' : ''}${flat(src.substring(from, start)).trimLeft()}",
    match: src.substring(start, end),
    after: "${flat(src.substring(end, to)).trimRight()}${to < src.length ? '…' : ''}",
    position: src.isEmpty ? 0 : start / src.length,
  );
}

/// موضعُ أول تطابقٍ **في النصّ الأصلي** — `(بداية، نهاية)` أو `null`.
(int, int)? _locate(String source, String normalizedQuery) {
  final (norm, map) = _normalizeWithMap(source);
  final at = norm.indexOf(normalizedQuery);
  if (at < 0) return null;
  final start = map[at];
  final lastIndex = at + normalizedQuery.length - 1;
  var end = map[lastIndex] + 1;
  // ✍️ تشكيلُ الحرف الأخير (والتطويل) جزءٌ من الكلمة — يُظلَّل معها.
  final mark = RegExp(r'[ً-ٰٟـ]');
  while (end < source.length && mark.hasMatch(source[end])) {
    end++;
  }
  return (start, end.clamp(start, source.length));
}

/// التطبيعُ نفسُه ([ConversationSearch.normalize]) مع خريطةٍ من كل حرفٍ
/// مطبَّعٍ إلى موضعه في الأصل — التشكيلُ والتطويلُ يُحذفان فينزاح الترقيم.
(String, List<int>) _normalizeWithMap(String source) {
  final out = StringBuffer();
  final map = <int>[];
  final diacritic = RegExp(r'[ً-ٰٟ]');
  for (var i = 0; i < source.length; i++) {
    final ch = source[i];
    if (ch == 'ـ' || diacritic.hasMatch(ch)) continue;
    final n = switch (ch) {
      'أ' || 'إ' || 'آ' || 'ٱ' => 'ا',
      'ة' => 'ه',
      'ى' => 'ي',
      _ when ConversationSearch._easternDigit.hasMatch(ch) =>
        ConversationSearch._westernDigit(ch),
      _ => ch.toLowerCase(),
    };
    // حرفٌ لاتينيٌّ نادرٌ يطول بالتصغير (İ) — كلُّ ما خرج يُنسب إلى أصله.
    for (var k = 0; k < n.length; k++) {
      map.add(i);
    }
    out.write(n);
  }
  return (out.toString(), map);
}
