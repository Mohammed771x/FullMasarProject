import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/scholarship_chat.dart';

// ==========================================
// 💾 تخزين محادثات المنح محلياً (Hive)
// ==========================================
// **Hive أولاً دائماً**: القائمة الجانبية تُفتح فوراً وبلا إنترنت، والسحابة
// نسخةٌ للاستعادة على جهاز جديد لا مصدرٌ للعرض ([27§5.2]).
//
// 👤 كل استعلام محكوم بالمالك، و🎓 كل قائمة محكومة بالمنحة.
class SchChatStorage {
  static const String _boxName = 'scholarship_chats';

  /// سقف ما نحتفظ به لكل (حساب + منحة) — أقدم من ذلك يُحذف تلقائياً.
  /// شات المنحة خفيف وموسمي، ولا معنى لتكديس مئات المحادثات عن منحة واحدة.
  static const int maxPerScholarship = 25;

  static Box<SchConversation>? _box;

  static Future<void> init() async {
    _registerAdapters();
    _box = await Hive.openBox<SchConversation>(_boxName);
  }

  @visibleForTesting
  static Future<void> initForTests(String path) async {
    Hive.init(path);
    _registerAdapters();
    _box = await Hive.openBox<SchConversation>(_boxName);
    await _box!.clear();
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(4)) Hive.registerAdapter(SchMessageAdapter());
    if (!Hive.isAdapterRegistered(5)) Hive.registerAdapter(SchConversationAdapter());
  }

  // ══════════════ كتابة ══════════════

  static Future<void> save(SchConversation c, {String? ownerUid}) async {
    if (ownerUid != null && ownerUid.isNotEmpty) c.ownerUid = ownerUid;
    c.lastUpdated = DateTime.now();
    await _box?.put(c.id, c);
    await _trim(c.ownerUid, c.scholarshipId);
  }

  static Future<void> markSynced(String id) async {
    final c = _box?.get(id);
    if (c != null) {
      c.synced = true;
      await _box?.put(id, c);
    }
  }

  static Future<void> delete(String id) async => _box?.delete(id);

  /// حذف كل محادثات منحةٍ لحساب واحد — «امسح محادثات هذه المنحة».
  static Future<int> clearForScholarship(String ownerUid, String scholarshipId) async {
    final ids = forScholarship(ownerUid, scholarshipId).map((c) => c.id).toList();
    await _box?.deleteAll(ids);
    return ids.length;
  }

  static Future<int> clearForOwner(String ownerUid) async {
    final ids = _ownedBy(ownerUid).map((c) => c.id).toList();
    await _box?.deleteAll(ids);
    return ids.length;
  }

  static Future<void> clearAll() async => _box?.clear();

  /// يحذف الأقدم متى تجاوز السجلّ السقف — بلا تدخّل من الطالب.
  static Future<void> _trim(String ownerUid, String scholarshipId) async {
    final list = forScholarship(ownerUid, scholarshipId);
    if (list.length <= maxPerScholarship) return;
    await _box?.deleteAll(list.skip(maxPerScholarship).map((c) => c.id));
  }

  // ══════════════ قراءة ══════════════

  static Iterable<SchConversation> _ownedBy(String uid) =>
      (_box?.values ?? const <SchConversation>[]).where((c) => c.ownerUid == uid);

  static SchConversation? get(String id, String ownerUid) {
    final c = _box?.get(id);
    return (c != null && c.ownerUid == ownerUid) ? c : null;
  }

  /// محادثات منحة واحدة لهذا الحساب — الأحدث أولاً.
  static List<SchConversation> forScholarship(String ownerUid, String scholarshipId) {
    final list = _ownedBy(ownerUid)
        .where((c) => c.scholarshipId == scholarshipId && c.messages.isNotEmpty)
        .toList();
    list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return list;
  }

  /// كل محادثات المنح لهذا الحساب (لشاشة الإعدادات وعدّاد الرئيسية).
  static List<SchConversation> all(String ownerUid) {
    final list = _ownedBy(ownerUid).where((c) => c.messages.isNotEmpty).toList();
    list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return list;
  }

  static List<SchConversation> pendingSync(String ownerUid) =>
      _ownedBy(ownerUid).where((c) => !c.synced && c.messages.isNotEmpty).toList();

  static int countFor(String ownerUid, String scholarshipId) =>
      forScholarship(ownerUid, scholarshipId).length;

  // ══════════════ ترحيل ══════════════

  /// محادثات حُفظت قبل وجود حقل المالك — يتبنّاها أول حساب (مرة واحدة).
  static Future<int> adoptOrphans(String ownerUid) async {
    if (ownerUid.isEmpty) return 0;
    final orphans = (_box?.values ?? const <SchConversation>[])
        .where((c) => c.ownerUid.isEmpty)
        .toList();
    for (final c in orphans) {
      c.ownerUid = ownerUid;
      await _box?.put(c.id, c);
    }
    return orphans.length;
  }
}
