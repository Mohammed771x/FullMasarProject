import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/chat/data/models/chat_model.dart';
import '../../features/quiz/data/models/quiz_models.dart';
import '../../features/quiz/data/quiz_storage.dart';
import '../../features/saved/data/saved_storage.dart';
import '../../features/scholarships/data/models/scholarship_chat.dart';
import '../../features/scholarships/data/scholarship_chat_storage.dart';
import '../session/user_session.dart';
import '../storage/chat_storage.dart';
import 'conversation_sync.dart';

// ==========================================
// 🔄 خدمة المزامنة — الواجهة الوحيدة لبقية التطبيق
// ==========================================
// المتحكّم ينادي `pushConversation` ويمضي؛ كل شيء آخر يحدث هنا:
// طابور المعلّقات، سقف العدد، وتجاهل الزائر.
//
// **الزائر لا يُزامَن إطلاقاً:** حسابه مؤقت، وحين يسجّل تنتقل محادثاته
// المحلية معه بالـuid نفسه (`linkWithCredential`) فترفعها أول مزامنة.
class SyncService {
  SyncService._();
  static final SyncService I = SyncService._();

  @visibleForTesting
  static void overrideBackend(ConversationSync backend) => I._sync = backend;

  ConversationSync? _backend;
  ConversationSync get _sync => _backend ??= ConversationSync();
  set _sync(ConversationSync v) => _backend = v;

  static const _kPending = 'sync_pending_ids';
  static const _kAdopted = 'sync_orphans_adopted';

  /// تأجيل الرفع بعد كل حفظ: الردّ الواحد يستدعي الحفظ عدة مرات
  /// (نهاية الكتابة · الإيقاف · بعد الإرسال) — بلا تأجيل تصير 3 كتابات
  /// Firestore لرسالة واحدة. التأجيل يجعلها **كتابة واحدة**.
  static const Duration writeDebounce = Duration(seconds: 3);

  bool _flushing = false;
  final Map<String, Timer> _debounce = {};
  final Map<String, ChatConversation> _latest = {};

  /// يتغيّر كلما وصلت محادثات من السحابة — الشاشات المفتوحة تُعيد التحميل.
  /// (بديل رخيص عن مستمعي Firestore الممنوعين: إشارة محلية واحدة.)
  final ValueNotifier<int> revision = ValueNotifier(0);

  bool get _enabled => UserSession.I.uid.isNotEmpty && !UserSession.I.isGuest;

  /// رفع محادثة — **لا يُنتظر ولا يرمي**، ويُجمَّع خلال [writeDebounce]
  /// فلا يُكتب المستند إلا مرة واحدة لكل ردّ.
  void pushConversation(ChatConversation c) {
    if (!_enabled) return;
    _latest[c.id] = c;                    // الأحدث دائماً هو ما يُرفع
    _debounce[c.id]?.cancel();
    _debounce[c.id] = Timer(writeDebounce, () => _flushOne(c.id));
  }

  Future<void> _flushOne(String id) async {
    _debounce.remove(id);
    final c = _latest.remove(id);
    if (c == null || !_enabled) return;
    try {
      await _sync.push(UserSession.I.uid, c);
      await _unmarkPending(c.id);
    } catch (_) {
      await _markPending(c.id);
    }
  }

  /// يرفع فوراً ما هو مؤجَّل — عند مغادرة الشاشة أو تسجيل الخروج.
  Future<void> flushNow() async {
    final ids = _debounce.keys.toList();
    for (final id in ids) {
      _debounce[id]?.cancel();
      await _flushOne(id);
    }
    // ★ ومحادثات المنح معها، وإلا ضاعت آخر رسالة عند تسجيل الخروج.
    final schIds = _schDebounce.keys.toList();
    for (final id in schIds) {
      _schDebounce[id]?.cancel();
      await _flushSchOne(id);
    }
  }

  void deleteConversation(String id) {
    _debounce.remove(id)?.cancel();   // لا ترفع ما حُذف
    _latest.remove(id);
    if (!_enabled) return;
    () async {
      await _sync.deleteRemote(UserSession.I.uid, id);
      await _unmarkPending(id);
    }();
  }

  /// يُستدعى عند إقلاع التطبيق وبعد تسجيل الدخول: يرفع ما تعذّر رفعه سابقاً.
  Future<void> flushPending() async {
    if (!_enabled || _flushing) return;
    _flushing = true;
    try {
      final p = await SharedPreferences.getInstance();
      final ids = p.getStringList(_kPending) ?? const <String>[];
      if (ids.isEmpty) return;

      final all = ChatStorage.getAllConversations(UserSession.I.uid);
      final byId = {for (final c in all) c.id: c};
      final still = <String>[];
      for (final id in ids) {
        final c = byId[id];
        if (c == null) continue; // حُذفت محلياً
        try {
          await _sync.push(UserSession.I.uid, c);
        } catch (_) {
          still.add(id);
        }
      }
      await p.setStringList(_kPending, still);
    } finally {
      _flushing = false;
    }
  }

  /// ترحيل لمرة واحدة: المحادثات المحفوظة قبل وجود حقل المالك تُنسب
  /// لأول حساب يسجّل الدخول على هذا الجهاز (كان جهازاً بحساب واحد فعلياً).
  /// ⚠️ **لا تُنسب لزائر:** حسابه مؤقت وقد يسجّل غيره بعده.
  Future<int> adoptOrphansOnce() async {
    if (!_enabled) return 0;
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_kAdopted) ?? false) return 0;
    final n = await ChatStorage.adoptOrphans(UserSession.I.uid);
    await QuizStorage.adoptOrphans(UserSession.I.uid);
    await SchChatStorage.adoptOrphans(UserSession.I.uid);
    // 🎓 والمحفوظات بلا صف (نسخةٌ سابقة) تُنسب لصفّ الطالب الحالي.
    //    بدونها تبقى ظاهرةً في **كل** الصفوف إلى الأبد — والفصلُ لا يكتمل.
    final saved = await SavedStorage.adoptScopeless(UserSession.I.uid, UserSession.I.scope);
    if (saved > 0) debugPrint("🎓 نُسبت $saved محفوظة قديمة إلى ${UserSession.I.scope.key}.");
    await p.setBool(_kAdopted, true);
    if (n > 0) debugPrint("👤 تبنّى الحساب الحالي $n محادثة قديمة بلا مالك.");
    return n;
  }

  /// يُستدعى بعد كل تسجيل دخول ناجح. حالتان لا ثالث لهما:
  ///   • **جهاز جديد** (لا محادثات لهذا الحساب محلياً) ⇒ سحب واحد من السحابة
  ///   • جهاز معتاد ⇒ رفع ما لديه محلياً (بحد 30) وتنظيف الزائد سحابياً
  /// يعيد عدد المحادثات المستعادة (صفر في الحالة الثانية).
  Future<int> onLogin() async {
    if (!_enabled) return 0;
    await adoptOrphansOnce();

    final local = ChatStorage.getAllConversations(UserSession.I.uid);
    if (local.isEmpty) {
      // 📲 جهاز جديد أو إعادة تثبيت — السحب المسموح تلقائياً ([27§5 شريحة ب]).
      try {
        return await restoreFromCloud();
      } catch (_) {
        return 0;
      }
    }

    await flushResults();
    await flushScholarshipChats();
    final failed = await _sync.pushBatch(UserSession.I.uid, local);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_kPending, failed);
    await _sync.pruneRemote(UserSession.I.uid);
    return 0;
  }

  // ══════════════ 🧠 نتائج الاختبارات ══════════════
  // نفس سياسة المحادثات: محلي أولاً، ونسخة سحابية fire-and-forget بلا مستمعين.
  // النتيجة **كتابة واحدة لكل اختبار** — وهي غذاء قسم التحليل ([31§6]).

  void pushResult(QuizResult r) {
    if (!_enabled) return;
    () async {
      try {
        await _sync.pushResult(UserSession.I.uid, r);
        await QuizStorage.markSynced(r.id);
      } catch (_) {
        // تبقى `synced=false` ويُعاد رفعها في `flushResults`.
      }
    }();
  }

  /// يرفع ما لم يُرفع من النتائج (عند الإقلاع وبعد الدخول).
  Future<void> flushResults() async {
    if (!_enabled) return;
    for (final r in QuizStorage.pendingSync(UserSession.I.uid)) {
      try {
        await _sync.pushResult(UserSession.I.uid, r);
        await QuizStorage.markSynced(r.id);
      } catch (_) {
        break;      // انقطاع الشبكة — نكمل في المرة القادمة
      }
    }
  }

  // ══════════════ 🎓 محادثات مساعد المنح ══════════════
  // مربوطة بالحساب فعلاً: تُحفظ بـ`ownerUid` محلياً **وتُرفع للسحابة**، فتعود
  // مع الطالب على جهاز جديد ([32§5]). نفس تأجيل الكتابة المستعمل للتعليم
  // كي لا تصير ثلاث كتابات Firestore لردٍّ واحد.

  final Map<String, Timer> _schDebounce = {};
  final Map<String, SchConversation> _schLatest = {};

  void pushScholarshipChat(SchConversation c) {
    if (!_enabled) return;
    _schLatest[c.id] = c;
    _schDebounce[c.id]?.cancel();
    _schDebounce[c.id] = Timer(writeDebounce, () => _flushSchOne(c.id));
  }

  Future<void> _flushSchOne(String id) async {
    _schDebounce.remove(id);
    final c = _schLatest.remove(id);
    if (c == null || !_enabled) return;
    try {
      await _sync.pushScholarshipChat(UserSession.I.uid, c);
      await SchChatStorage.markSynced(c.id);
    } catch (_) {
      // تبقى `synced=false` ويُعاد رفعها في `flushScholarshipChats`.
    }
  }

  void deleteScholarshipChat(String id) {
    _schDebounce.remove(id)?.cancel();
    _schLatest.remove(id);
    if (!_enabled) return;
    () async {
      await _sync.deleteRemoteScholarshipChat(UserSession.I.uid, id);
    }();
  }

  /// يرفع ما لم يُرفع من محادثات المنح (عند الإقلاع وبعد الدخول).
  Future<void> flushScholarshipChats() async {
    if (!_enabled) return;
    for (final c in SchChatStorage.pendingSync(UserSession.I.uid)) {
      try {
        await _sync.pushScholarshipChat(UserSession.I.uid, c);
        await SchChatStorage.markSynced(c.id);
      } catch (_) {
        break;      // انقطاع الشبكة — نكمل في المرة القادمة
      }
    }
  }

  /// «🔄 استعادة محادثاتي» — السحب الوحيد المسموح (جهاز جديد أو بطلب الطالب).
  /// يعيد عدد المحادثات المستعادة.
  Future<int> restoreFromCloud() async {
    if (!_enabled) return 0;
    final remote = await _sync.pullAll(UserSession.I.uid);
    final localIds = ChatStorage.getAllConversations(UserSession.I.uid).map((c) => c.id).toSet();
    var restored = 0;
    for (final c in remote) {
      // last-write-wins: لا نطمس نسخة محلية أحدث.
      final local = ChatStorage.getOwnedConversation(c.id, UserSession.I.uid);
      if (local != null && !local.lastUpdated.isBefore(c.lastUpdated)) continue;
      await ChatStorage.saveConversation(c, ownerUid: UserSession.I.uid);
      if (!localIds.contains(c.id)) restored++;
    }
    // 🧠 والنتائج معها — قسم التحليل يعتمد عليها.
    try {
      for (final r in await _sync.pullResults(UserSession.I.uid)) {
        await QuizStorage.save(r, ownerUid: UserSession.I.uid);
      }
    } catch (_) {
      // المحادثات استُعيدت — والنتائج تُعاد في المحاولة القادمة.
    }

    // 🎓 ومحادثات المنح — «مربوطة بالحساب» تعني أنها تعود معه على جهاز جديد.
    try {
      for (final c in await _sync.pullScholarshipChats(UserSession.I.uid)) {
        final local = SchChatStorage.get(c.id, UserSession.I.uid);
        if (local != null && !local.lastUpdated.isBefore(c.lastUpdated)) continue;
        await SchChatStorage.save(c, ownerUid: UserSession.I.uid);
      }
    } catch (_) {
      // غير حرج — تُستعاد في المحاولة القادمة.
    }

    if (restored > 0) revision.value++;   // أيقظ الشاشات المفتوحة
    return restored;
  }

  Future<void> _markPending(String id) async {
    final p = await SharedPreferences.getInstance();
    final ids = <String>{...(p.getStringList(_kPending) ?? const <String>[]), id}.toList();
    await p.setStringList(_kPending, ids);
  }

  Future<void> _unmarkPending(String id) async {
    final p = await SharedPreferences.getInstance();
    final ids = (p.getStringList(_kPending) ?? const <String>[]).where((e) => e != id).toList();
    await p.setStringList(_kPending, ids);
  }
}
