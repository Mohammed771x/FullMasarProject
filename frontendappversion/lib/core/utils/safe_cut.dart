// ==========================================
// ✂️ قصٌّ لا يشطر رمزاً تعبيرياً
// ==========================================
// ☢️ **رُئي في المحاكي (٢٠٢٦-٠٩-٢٣):** «string is not well-formed UTF-16».
//    `substring(0, n)` يعدّ وحداتِ UTF-16 لا الحروف، والرمزُ التعبيريُّ
//    (📝 · 🔬) وحدتان. فالقصُّ بينهما يترك نصفَ رمزٍ يرفضه محرّكُ النصّ —
//    مربّعاً رمادياً في النسخة المنشورة، في عنوان محادثةٍ في الدرج أو في
//    أوّل حرفٍ من اسمٍ على الصورة الرمزية.

/// أوّلُ [n] وحدةً من [s] — وإن وقع القطعُ داخل زوجٍ بديلٍ أُسقط نصفُه.
String safeCut(String s, int n) {
  if (n >= s.length) return s;
  if (n <= 0) return '';
  final last = s.codeUnitAt(n - 1);
  final splitsPair = last >= 0xD800 && last <= 0xDBFF;
  return s.substring(0, splitsPair ? n - 1 : n);
}

/// أوّلُ «حرفٍ» كما تراه العين — الرمزُ التعبيريُّ كاملاً لا نصفُه.
String firstGlyph(String s) {
  if (s.isEmpty) return '';
  final u = s.codeUnitAt(0);
  final pair = u >= 0xD800 && u <= 0xDBFF && s.length > 1;
  return s.substring(0, pair ? 2 : 1);
}
