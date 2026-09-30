/// 🇬🇧🇾🇪 **اسمُ درسٍ بلغتين يُعرض سطرين** — الإنجليزيُّ في سطرٍ والعربيُّ في سطر.
///
/// 🔴 **رآه المالك في المحاكي (2026-09-29):** أسماءُ دروس الإنجليزي في الكتاب
///    لغتان في سطرٍ واحد: «Expressions of time with prepositions at, in and on
///    | حروف الجر الزمنية at و in و on». وفي فقرةٍ عربيةِ الاتجاه يتداخل
///    الشقّان، وتقفز «?» في «(should / Why not ...?)» إلى غير مكانها،
///    لأن العلامة محايدةُ الاتجاه فتأخذ اتجاهَ الفقرة.
///
/// ⚖️ **العرضُ وحده يتغيّر، والاسمُ المخزون لا يُلمس**: هو مفتاحُ بنك
///    الأسئلة والشرح المخزون وتقدّم الطالب، وتغييرُه يُسقطها كلَّها.
///
/// والكلماتُ اللاتينية داخل السطر العربي تُعزل بـLRI/PDI، فتبقى «...?»
/// ملاصقةً لكلمتها و«have / has / had» بترتيبها.
library;

const String _lri = '\u2066';
const String _pdi = '\u2069';

final RegExp _arabic = RegExp(r'[\u0600-\u06FF]');
final RegExp _latin = RegExp(r'[A-Za-z]');

/// كلمةٌ لاتينية أو عبارة: تبدأ بحرفٍ وتنتهي بحرفٍ أو رقمٍ أو «?!.'».
/// فلا تبتلع «+» أو «-» في طرفها؛ تلك تبقى محايدةً بين الشقّين.
///
/// 🔗 **و«و» بين كلمتين لاتينيتين من العبارة**: «at و in و on» لو عُزلت
///    كلُّ كلمةٍ وحدها لقُرئت من اليمين «on و in و at»، ولبدت «و» الصغيرة
///    بين الحروف اللاتينية كأنها g. فتُعزل العبارةُ كلُّها كتلةً واحدة.
const String _word = r"[A-Za-z](?:[A-Za-z0-9'’/.,?!\- ]*[A-Za-z0-9'’?!.])?";
final RegExp _latinRun = RegExp('$_word(?: و $_word)*');

/// «Review of tenses - فعل الكينونة …»: شقٌّ لاتينيٌّ خالص ثم « - » ثم عربي.
final RegExp _dashSplit = RegExp(r'^([^\u0600-\u06FF]+?)\s+-\s+(.+)$');

String _isolateLatin(String s) {
  if (!_latin.hasMatch(s)) return s;
  if (!_arabic.hasMatch(s)) return '$_lri$s$_pdi';
  return s.replaceAllMapped(_latinRun, (m) => '$_lri${m.group(0)}$_pdi');
}

List<String> _parts(String name) {
  final s = name.trim();
  if (!_arabic.hasMatch(s) || !_latin.hasMatch(s)) return [s];
  final bar = s.indexOf('|');
  if (bar > 0 && bar < s.length - 1) {
    final a = s.substring(0, bar).trim(), b = s.substring(bar + 1).trim();
    if (a.isNotEmpty && b.isNotEmpty) {
      // الإنجليزيُّ أولاً في كل الدروس — فلا تتقلّب القائمةُ بين درسٍ وآخر.
      return _arabic.hasMatch(a) && !_arabic.hasMatch(b) ? [b, a] : [a, b];
    }
  }
  final m = _dashSplit.firstMatch(s);
  if (m != null && _arabic.hasMatch(m.group(2)!)) {
    return [m.group(1)!.trim(), m.group(2)!.trim()];
  }
  return [s];
}

/// سطران (أو سطرٌ واحد إن لم يكن الاسمُ بلغتين) — لكل `Text` يتّسع لسطرين.
String bilingualLabel(String name) =>
    _parts(name).map(_isolateLatin).join('\n');

/// سطرٌ واحد للأماكن الضيّقة (رأسُ القائمة المنسدلة): الشقّان بفاصل،
/// وكلٌّ معزولُ الاتجاه.
String bilingualInline(String name) =>
    _parts(name).map(_isolateLatin).join('  ·  ');
