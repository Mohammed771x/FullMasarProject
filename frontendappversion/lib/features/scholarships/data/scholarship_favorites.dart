import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/session/user_session.dart';
import 'models/scholarship.dart';

// ==========================================
// ⭐ منحُ الطالب المتابَعة — «مفضّلتي»
// ==========================================
// 🔴 **ما كان ينقص:** الطالب يتصفّح عشرين منحة، تعجبه ثلاث، فيغلق التطبيق
//    ثم يفتحه غداً فيبدأ من الصفر. لا وسيلة لقول «هذه تهمّني» — والمنح
//    محتوى متغيّر يُدار من اللوحة، فقد تختفي المنحة من الصدارة غداً.
//
// 👤 **محكومة بالحساب لا بالجهاز**: جوّالٌ يتشاركه أخوان لا تُخلط مفضّلتاهما
//    ([28§10] — نفس قاعدة المحادثات والنتائج).
//
// 💾 **محلية عمداً (SharedPreferences) لا Firestore:** قائمةُ معرّفاتٍ
//    قصيرة، وقراءتها من السحابة تعني رحلةَ شبكةٍ عند كل فتحةٍ للقسم مقابل
//    لا شيء. وضياعُها عند تغيير الجهاز خسارةٌ محتملة — لكن نقلها لاحقاً
//    إلى `users/{uid}` لا يحتاج إلا تغييرَ هذا الملف وحده.
class ScholarshipFavorites extends ChangeNotifier {
  ScholarshipFavorites._();
  static final ScholarshipFavorites I = ScholarshipFavorites._();

  static const String _prefix = "sch_favorites_";

  Set<String> _ids = <String>{};
  String _loadedFor = "";

  Set<String> get ids => Set.unmodifiable(_ids);
  bool get isEmpty => _ids.isEmpty;
  int get count => _ids.length;

  String get _key => "$_prefix${UserSession.I.uid}";

  /// يحمّل مفضّلة الحساب الحالي. **يُعاد تحميلها عند تبديل الحساب.**
  ///
  /// ⚠️ الحارس `_loadedFor` ليس تحسيناً: بدونه تبقى مفضّلةُ الحساب السابق
  ///    معروضةً بعد تبديل المستخدم حتى أول إعادة تحميلٍ صريحة.
  Future<void> load() async {
    final uid = UserSession.I.uid;
    if (_loadedFor == uid && uid.isNotEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _ids = (prefs.getStringList(_key) ?? const <String>[]).toSet();
      _loadedFor = uid;
      notifyListeners();
    } catch (_) {
      // 🛟 تخزينٌ معطوب لا يُسقط القسم — تبقى المفضّلة فارغة لهذه الجلسة.
      _ids = <String>{};
    }
  }

  bool contains(String id) => _ids.contains(id);

  /// يبدّل الحالة ويعيد الحالة الجديدة (لتقولها الواجهة في رسالةٍ فورية).
  Future<bool> toggle(String id) async {
    if (id.isEmpty) return false;
    final added = !_ids.contains(id);
    if (added) {
      _ids.add(id);
    } else {
      _ids.remove(id);
    }
    notifyListeners();          // الواجهة تتحدّث فوراً، والقرص يلحق بعدها
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _ids.toList());
    } catch (_) {}
    return added;
  }

  /// يُنظّف معرّفات منحٍ لم تعد موجودة (حُذفت أو أُخفيت من اللوحة).
  ///
  /// ⚠️ لازمٌ لا تجميل: بدونه ينتفخ التخزين بمعرّفاتٍ ميتة، ويقول العدّاد
  ///    «٥ منح متابَعة» بينما القائمة تُظهر ثلاثاً — تناقضٌ يراه الطالب.
  Future<void> pruneAgainst(List<Scholarship> live) async {
    if (_ids.isEmpty) return;
    final alive = live.map((s) => s.id).toSet();
    final kept = _ids.intersection(alive);
    if (kept.length == _ids.length) return;
    _ids = kept;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_key, _ids.toList());
    } catch (_) {}
  }

  /// 🔔 **المنح المتابَعة التي تُغلق خلال [withinDays]** — مرتّبةً بالأقرب.
  ///
  /// ⭐ هذا هو ما يجعل المتابعة تساوي شيئاً: نجمةٌ بلا تنبيهٍ مجرّدُ زينة.
  ///    والطالب لا يفوّت منحةً لأنه لم يهتم، بل لأنه **نسي التاريخ**.
  List<Scholarship> closingSoon(List<Scholarship> all, {int withinDays = 14}) {
    final soon = all
        .where((s) => _ids.contains(s.id))
        .where((s) {
          final d = s.daysLeft;
          return d != null && d <= withinDays;
        })
        .toList();
    soon.sort((a, b) => (a.daysLeft ?? 9999).compareTo(b.daysLeft ?? 9999));
    return soon;
  }

  /// يُصفّر المعروض عند الخروج — مفضّلةُ حسابٍ لا تُعرض لآخر.
  void clear() {
    _ids = <String>{};
    _loadedFor = "";
    notifyListeners();
  }
}
