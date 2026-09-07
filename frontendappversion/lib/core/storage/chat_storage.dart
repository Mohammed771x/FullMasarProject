import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../features/chat/data/models/chat_model.dart';
import '../session/grade_scope.dart';

// ==========================================
// 💾 تخزين المحادثات محلياً عبر Hive
// ==========================================
// 👤 **كل استعلام محكوم بالمالك (`ownerUid`).**
//    الجوّال الواحد قد يستعمله أكثر من حساب — وزائر — فلا يجوز أن يرى
//    حسابٌ محادثاتِ حساب آخر ولو كانا على الجهاز نفسه.
//
// **الزائر:** له `uid` مجهول ثابت على الجهاز، فمحادثاته منفصلة تماماً،
// وعند تسجيله يبقى الـuid نفسه (`linkWithCredential`) فتنتقل معه بلا نسخ.
//
// 🎓 **والصف طبقةٌ ثانية فوق المالك ([GradeScope]).** الحساب واحد لثلاث
//    سنوات، فمن بدّل صفّه يجب أن يبدّل سجلَّه معه — لا أن يرى محادثاتِ
//    صفٍّ تركه مختلطةً بمحادثات صفّه الجديد.
class ChatStorage {
  static const String _boxName = 'conversations';
  static Box<ChatConversation>? _box;

  // تهيئة Hive
  static Future<void> init() async {
    await Hive.initFlutter();
    _registerAdapters();
    _box = await Hive.openBox<ChatConversation>(_boxName);
  }

  /// تهيئة للاختبارات: Hive على مجلد مؤقت بلا إضافات المنصّة.
  @visibleForTesting
  static Future<void> initForTests(String path) async {
    Hive.init(path);
    _registerAdapters();
    _box = await Hive.openBox<ChatConversation>(_boxName);
    await _box!.clear();
  }

  static void _registerAdapters() {
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ChatConversationAdapter());
    }
  }

  // ══════════════ كتابة ══════════════

  /// حفظ محادثة. [ownerUid] يُثبَّت على المحادثة إن لم يكن لها مالك بعد.
  static Future<void> saveConversation(ChatConversation conversation, {String? ownerUid}) async {
    if (ownerUid != null && ownerUid.isNotEmpty) conversation.ownerUid = ownerUid;
    await _box?.put(conversation.id, conversation);
  }

  static Future<void> deleteConversation(String id) async {
    await _box?.delete(id);
  }

  /// حذف محادثات مالك واحد فقط — «مسح محادثاتي» لا يمسّ الحسابات الأخرى.
  static Future<int> clearForOwner(String ownerUid) async {
    final ids = _ownedBy(ownerUid).map((c) => c.id).toList();
    await _box?.deleteAll(ids);
    return ids.length;
  }

  /// حذف كل شيء على الجهاز — للاختبارات وإعادة الضبط الكاملة فقط.
  static Future<void> clearAll() async {
    await _box?.clear();
  }

  static Future<void> updateLastUsed(String id) async {
    final conv = _box?.get(id);
    if (conv != null) {
      conv.lastUpdated = DateTime.now();
      await _box?.put(id, conv);
    }
  }

  // ══════════════ قراءة ══════════════

  static ChatConversation? getConversation(String id) => _box?.get(id);

  /// محادثة يملكها هذا الحساب فقط — يمنع تسرّب مستند لحساب آخر.
  static ChatConversation? getOwnedConversation(String id, String ownerUid) {
    final c = _box?.get(id);
    if (c == null) return null;
    return c.ownerUid == ownerUid ? c : null;
  }

  static Iterable<ChatConversation> _ownedBy(String ownerUid) =>
      (_box?.values ?? const <ChatConversation>[]).where((c) => c.ownerUid == ownerUid);

  /// كل محادثات حساب معيّن، الأحدث أولاً.
  ///
  /// [scope] يقصرها على صفٍّ ومسارٍ بعينهما — ومرّره **كلما عُرضت الأرقام
  /// للطالب**. تركُه فارغاً يعني «كل صفوف الحساب»، وهو ما تحتاجه المزامنة
  /// والحذف الكامل وحدهما.
  static List<ChatConversation> getAllConversations(String ownerUid, {GradeScope? scope}) {
    final list = _inScope(ownerUid, scope).toList();
    list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return list;
  }

  static Iterable<ChatConversation> _inScope(String ownerUid, GradeScope? scope) {
    final owned = _ownedBy(ownerUid);
    if (scope == null) return owned;
    return owned.where((c) => scope.includes(c.grade, c.track));
  }

  /// محادثات نطاق معيّن (صف + مسار + مادة + فرع + وضع) **لهذا الحساب**.
  /// ★ هذا ما يجعل تبديل الصف أو المادة أو الوضع يبدّل سجلّ المحادثات كاملاً.
  static List<ChatConversation> getConversationsByScope(String scopeKey, String ownerUid) {
    final list = _ownedBy(ownerUid).where((c) => c.scopeKey == scopeKey).toList();
    list.sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return list;
  }

  static int countInScope(String scopeKey, String ownerUid) =>
      _ownedBy(ownerUid).where((c) => c.scopeKey == scopeKey).length;

  static int countForOwner(String ownerUid, {GradeScope? scope}) =>
      _inScope(ownerUid, scope).length;

  /// حذف محادثات صفٍّ واحد لهذا الحساب — «مسح محادثات صفّي الحالي».
  static Future<int> clearForScope(String ownerUid, GradeScope scope) async {
    final ids = _inScope(ownerUid, scope).map((c) => c.id).toList();
    await _box?.deleteAll(ids);
    return ids.length;
  }

  // ══════════════ ترحيل ══════════════

  /// المحادثات التي حُفظت قبل وجود حقل المالك (`ownerUid == ""`).
  static List<ChatConversation> orphanConversations() =>
      (_box?.values ?? const <ChatConversation>[]).where((c) => c.ownerUid.isEmpty).toList();

  /// يتبنّى المحادثات بلا مالك لحساب واحد — **مرة واحدة على الجهاز**.
  /// قبل هذه النسخة كان الجهاز بحساب واحد فعلياً، فأول من يسجّل الدخول هو صاحبها.
  static Future<int> adoptOrphans(String ownerUid) async {
    if (ownerUid.isEmpty) return 0;
    final orphans = orphanConversations();
    for (final c in orphans) {
      c.ownerUid = ownerUid;
      await _box?.put(c.id, c);
    }
    return orphans.length;
  }
}
