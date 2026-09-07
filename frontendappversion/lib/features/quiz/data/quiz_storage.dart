import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/session/grade_scope.dart';
import 'models/quiz_models.dart';

// ==========================================
// 💾 تخزين نتائج الاختبارات محلياً
// ==========================================
// **Hive أولاً دائماً**: قسم التحليل يقرأ من هنا فيصير فورياً وبصفر قراءات
// سحابية ([31§7]). Firestore نسخة احتياطية للاستعادة على جهاز جديد.
//
// 👤 كل استعلام محكوم بالمالك — جوّال بحسابين لا يخلط نتائجهما ([28§10]).
//
// 🎓 **وبالصف كذلك ([GradeScope]).** «أضعف مادة» و«أقوى مادة» ونقاط الضعف
//    كلها تُشتقّ من هنا، فخلطُ نتائج ثالث علمي بنتائج أول ثانوي يجعل التحليل
//    يقول للطالب إن ضعفه في درسٍ لم يدرسه هذه السنة أصلاً. الحقلان `grade`
//    و`track` موجودان في `QuizResult` منذ البداية — ما كان ناقصاً هو **أن
//    يفلتر بهما أحد**.
class QuizStorage {
  static const String _boxName = 'quiz_results';
  static Box<QuizResult>? _box;

  static Future<void> init() async {
    _registerAdapters();
    _box = await Hive.openBox<QuizResult>(_boxName);
  }

  @visibleForTesting
  static Future<void> initForTests(String path) async {
    Hive.init(path);
    _registerAdapters();
    _box = await Hive.openBox<QuizResult>(_boxName);
    await _box!.clear();
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(WrongAnswerAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(QuizResultAdapter());
  }

  // ══════════════ كتابة ══════════════

  static Future<void> save(QuizResult r, {String? ownerUid}) async {
    if (ownerUid != null && ownerUid.isNotEmpty) r.ownerUid = ownerUid;
    await _box?.put(r.id, r);
  }

  static Future<void> markSynced(String id) async {
    final r = _box?.get(id);
    if (r != null) {
      r.synced = true;
      await _box?.put(id, r);
    }
  }

  static Future<int> clearForOwner(String ownerUid) async {
    final ids = _ownedBy(ownerUid).map((r) => r.id).toList();
    await _box?.deleteAll(ids);
    return ids.length;
  }

  static Future<void> clearAll() async => _box?.clear();

  // ══════════════ قراءة ══════════════

  static Iterable<QuizResult> _ownedBy(String uid) =>
      (_box?.values ?? const <QuizResult>[]).where((r) => r.ownerUid == uid);

  static Iterable<QuizResult> _inScope(String ownerUid, GradeScope? scope) {
    final owned = _ownedBy(ownerUid);
    if (scope == null) return owned;
    return owned.where((r) => scope.includes(r.grade, r.track));
  }

  /// كل نتائج حساب، الأحدث أولاً.
  ///
  /// [scope] يقصرها على صفٍّ ومسار — ومرّره في **كل** ما يُعرض للطالب.
  /// تركُه فارغاً للمزامنة والحذف الكامل وحدهما.
  static List<QuizResult> all(String ownerUid, {GradeScope? scope}) {
    final list = _inScope(ownerUid, scope).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  static List<QuizResult> forSubject(String ownerUid, String subject, {GradeScope? scope}) =>
      all(ownerUid, scope: scope).where((r) => r.subject == subject).toList();

  /// ⚠️ **بلا نطاق عمداً**: النتيجة تُرفع لسحابةِ الحساب أياً كان صفُّها،
  ///    وطالبٌ بدّل صفّه قبل أن تُرفع نتيجتُه لا يجوز أن تضيع.
  static List<QuizResult> pendingSync(String ownerUid) =>
      _ownedBy(ownerUid).where((r) => !r.synced).toList();

  static int countForOwner(String ownerUid, {GradeScope? scope}) =>
      _inScope(ownerUid, scope).length;

  /// حذف نتائج صفٍّ واحد لهذا الحساب.
  static Future<int> clearForScope(String ownerUid, GradeScope scope) async {
    final ids = _inScope(ownerUid, scope).map((r) => r.id).toList();
    await _box?.deleteAll(ids);
    return ids.length;
  }

  /// نتائج بلا مالك (حُفظت قبل وجود الحقل) — يتبنّاها أول حساب.
  static Future<int> adoptOrphans(String ownerUid) async {
    if (ownerUid.isEmpty) return 0;
    final orphans = (_box?.values ?? const <QuizResult>[]).where((r) => r.ownerUid.isEmpty).toList();
    for (final r in orphans) {
      r.ownerUid = ownerUid;
      await _box?.put(r.id, r);
    }
    return orphans.length;
  }
}
