// ==========================================
// 📝 سياقُ وزاري الرياضيات — ما عُرض في **هذه المحادثة**
// ==========================================
//
// 🎯 **أمرُ المالك (٢٠٢٦-٠٩-٢٧):** «بعد ما تجي الأسئلة نقدر نرسل: السؤال
//    رقم ثلاثة ممكن توضّحه لي… ولو رجع بعدين على المحادثة يوجد نفس الدرس».
//
// ☢️ **ما كان:** الخادمُ يحفظ الأسئلةَ المعروضة في ذاكرةٍ **لكل طالبٍ لا لكل
//    محادثة** (`sessions_math[user_id]`) تموت بعد نصف ساعة ومع كل إعادة
//    تشغيل. فالعائدُ إلى محادثته يُقال له «يرجى جلب الأسئلة أولاً» — أو يُشرح
//    له سؤالٌ من محادثةٍ أخرى جلب فيها درساً آخر.
//
// ✅ **والمحادثةُ تحمل سياقَها:** السنةُ والدرسُ مثبّتان معها، وعددُ المعروض
//    يُقرأ من رسائلها نفسِها — فيُعيد الخادمُ بناءَ القائمة حرفاً بحرف (الجلبُ
//    بادئةُ قائمة الدرس في تلك السنة).

/// رأسُ ردِّ الجلب — «✅ وجدت …» للجلبة الأولى و«📋 الأسئلة الإضافية» لـ«كمل».
/// ⚠️ **ردودُ الجلب وحدها تُعدّ**: شرحُ الموديل لسؤالٍ قد يكتب «السؤال ٣»،
///    وعدُّه كان سيوهم أن المعروضَ أكثرُ مما عُرض.
bool _isFetchReply(String text) {
  final t = text.trimLeft();
  return t.startsWith('✅ وجدت') || t.startsWith('📋 الأسئلة الإضافية');
}

/// 🔢 «📌 السؤال ٣» بأرقامٍ غربية أو عربية — الرسّامُ قد يعرّب الأرقام.
final RegExp _questionMark = RegExp(r'📌\s*السؤال\s*([0-9٠-٩]+)');

int _parseDigits(String s) {
  final western = s.replaceAllMapped(
    RegExp('[٠-٩]'),
    (m) => '${m[0]!.codeUnitAt(0) - 0x0660}',
  );
  return int.tryParse(western) ?? 0;
}

/// كم سؤالاً وزارياً عُرض في هذه المحادثة؟ — أكبرُ رقمٍ في ردود الجلب.
///
/// ⚖️ **أكبرُ رقم لا عددُ العلامات**: جلبٌ ثانٍ لنفس الدرس بعددٍ أقلّ يعيد
///    ١…٥ بعد ١…١٠، والمعروضُ ما زال عشرة بترقيمها نفسِه.
int wazariShownIn(List<Map<String, dynamic>> messages) {
  var shown = 0;
  for (final m in messages) {
    if (m['role'] != 'ai') continue;
    final text = (m['text'] ?? '').toString();
    if (!_isFetchReply(text)) continue;
    for (final match in _questionMark.allMatches(text)) {
      final n = _parseDigits(match[1]!);
      if (n > shown) shown = n;
    }
  }
  return shown;
}

/// فقاعةُ الجلب كما تُعرض للطالب: «جلب أسئلة وزاري: الدرس (2024)».
final RegExp _fetchBubble = RegExp(r'^جلب أسئلة وزاري: (.+) \(([^()]+)\)$');

/// 🕰️ **(السنة، الدرس) من آخر فقاعة جلب** — لمحادثاتٍ حُفظت قبل أن تُحفظ
/// السنةُ معها (`ChatConversation.unit` فارغ)، فتعود قابلةً للمتابعة لا
/// «يرجى جلب الأسئلة». `null` إن لم تُجلب أسئلةٌ فيها قطّ.
(String, String)? wazariFetchIn(List<Map<String, dynamic>> messages) {
  for (final m in messages.reversed) {
    if (m['role'] != 'user') continue;
    final match = _fetchBubble.firstMatch((m['text'] ?? '').toString().trim());
    if (match != null) return (match[2]!.trim(), match[1]!.trim());
  }
  return null;
}
