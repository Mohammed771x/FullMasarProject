import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../features/chat/data/models/chat_model.dart';
import '../../features/quiz/data/models/quiz_models.dart';
import '../../features/scholarships/data/models/scholarship_chat.dart';

// ==========================================
// ☁️ مزامنة المحادثات: Hive ↔ Firestore
// ==========================================
// **Hive هو المصدر الأول للعرض دائماً** (سريع + يعمل بلا إنترنت).
// Firestore نسخة سحابية للاستعادة على جهاز جديد لا أكثر.
//
// قواعد تحمي الفاتورة ([27§5.2]):
//   • الكتابة fire-and-forget بعد كل رد — لا ينتظرها الطالب.
//   • **لا Streams ولا مزامنة سحب دورية إطلاقاً.**
//   • السحب مرتين فقط: جهاز جديد، أو زر «استعادة محادثاتي».
//
// وثلاث سياسات تمنع تضخّم التخزين ([27§6.2]) — تُطبَّق على النسخة السحابية
// **فقط**، ونسخة الجهاز تبقى كاملة:
//   1. سقف 200 KB للمستند  ← تُقص أقدم الرسائل
//   2. آخر 30 محادثة تُزامَن ← الأقدم يبقى على الجهاز
//   3. حقل expires_at (+6 أشهر) ← سياسة TTL في Firestore تحذف الخاملة
//
// ⚠️ الحساب بالبايت لا بعدد الرسائل: **الحرف العربي في UTF-8 بايتان**،
//    فمحادثة 3,000 حرف ≈ 6 كيلوبايت لا 3.
class ConversationSync {
  ConversationSync({FirebaseFirestore? db}) : _injected = db;

  // كسول عمداً: `toDoc`/`fromDoc`/سياسات القصّ دوالُّ خالصة تعمل بلا Firebase
  // (وتُختبر وحدوياً)، فلا نُهيّئ العميل إلا عند أول نداء شبكة فعلي.
  final FirebaseFirestore? _injected;
  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  /// سقف حجم المستند الواحد (حد Firestore 1 MiB — نبقى دونه بفارق مريح).
  static const int maxDocBytes = 200 * 1024;

  /// أقصى عدد محادثات تُحفظ سحابياً لكل طالب.
  static const int maxSyncedConversations = 30;

  /// عمر المحادثة السحابية قبل حذفها تلقائياً (Firestore TTL).
  static const Duration cloudRetention = Duration(days: 180);

  /// أقل عدد رسائل نُبقيه مهما بلغ حجمها (وإلا صارت النسخة بلا معنى).
  static const int minKeptMessages = 2;

  /// سقف عدد الرسائل في المستند السحابي.
  /// ⚠️ **يجب أن يطابق `validConversation()` في `firestore.rules`** — القاعدة
  ///    ترفض ما يتجاوزه، فلو رفعنا أحدهما دون الآخر فشلت المزامنة صامتةً.
  static const int maxCloudMessages = 400;

  CollectionReference<Map<String, dynamic>> _col(String uid) =>
      _db.collection("users").doc(uid).collection("conversations");

  // ══════════════ رفع ══════════════

  /// يرفع محادثة واحدة. **لا يُنتظر ولا يرمي**: فشل الشبكة لا يعطّل المحادثة.
  Future<void> push(String uid, ChatConversation c) async {
    if (uid.isEmpty || c.messages.isEmpty) return;
    try {
      await _col(uid).doc(c.id).set(toDoc(c), SetOptions(merge: true));
    } catch (e) {
      debugPrint("⚠️ تعذّرت مزامنة المحادثة ${c.id}: $e");
      rethrow; // يلتقطه المستدعي ليضعها في قائمة المعلّقة
    }
  }

  /// يبني مستند Firestore مع تطبيق سقف الحجم.
  Map<String, dynamic> toDoc(ChatConversation c) {
    final kept = trimToByteBudget(c.messages);
    return {
      "title": c.title,
      "subject": c.subject,
      "mode": c.mode,
      "grade": c.grade,
      "track": c.track,
      "branch": c.branch,
      // 🧭 **وسياقُ الدرس يسافر معها** — وإلا عاد العطلُ من باب السحابة:
      //    طالبٌ أعاد تثبيت التطبيق (أو فتحه على جهازٍ ثانٍ) تُستعاد
      //    محادثاتُه من هنا لا من القرص، فتصل بمادتها **بلا درسها** —
      //    وهي بالضبط الحالةُ التي عالجتها حقولُ [ChatConversation.unit].
      "unit": c.unit,
      "lesson": c.lesson,
      "content_mode": c.contentMode,
      // ⚠️ مقصوصةٌ هنا أيضاً: القاعدةُ ترفض ما فوق ٣ فتسقط المزامنةُ كلُّها.
      "pages": c.pages.take(ChatConversation.maxPages).toList(),
      // ★ إلزامي: بدونه ترجع المحادثات المستعادة بلا نطاق فتختلط الصفوف والمواد.
      "scope_key": c.scopeKey,
      "messages": kept.map(messageToMap).toList(),
      "truncated": kept.length != c.messages.length,
      "created_at": c.createdAt.toIso8601String(),
      "last_updated": c.lastUpdated.toIso8601String(),
      // سياسة TTL في Firestore تحذف المستند تلقائياً عند هذا التاريخ.
      "expires_at": Timestamp.fromDate(c.lastUpdated.add(cloudRetention)),
    };
  }

  /// 🖼️ الصور لا تُرفع أبداً — تبقى على جهاز الطالب ([27§3]).
  ///    نرفع النص المستخرج فقط، ونحتفظ بعدد الصور لعرض تلميح عند الاستعادة.
  static Map<String, dynamic> messageToMap(ChatMessage m) => {
        "role": m.role,
        "text": m.text,
        "refs": m.refs,
        "ts": m.timestamp.toIso8601String(),
        if (m.allImages.isNotEmpty) "images_count": m.allImages.length,
        // ★ النصّ يُرفع (لا الصورة): به تبقى المحادثة مفهومة على جهاز جديد.
        if (m.imageText.isNotEmpty) "image_text": m.imageText,
      };

  static ChatMessage messageFromMap(Map<String, dynamic> m) => ChatMessage(
        role: (m["role"] ?? "user").toString(),
        text: (m["text"] ?? "").toString(),
        refs: List<String>.from(m["refs"] ?? const []),
        timestamp: DateTime.tryParse((m["ts"] ?? "").toString()) ?? DateTime.now(),
        imageText: (m["image_text"] ?? "").toString(),
      );

  /// يقصّ **أقدم** الرسائل حتى يدخل المستند ضمن حدّين معاً:
  /// ميزانية البايت، **وسقف العدد** الذي تفرضه قواعد الأمان.
  /// الأحدث يبقى دائماً لأنه سياق المحادثة الحيّ.
  static List<ChatMessage> trimToByteBudget(List<ChatMessage> messages,
      {int budget = maxDocBytes, int maxCount = maxCloudMessages}) {
    if (messages.isEmpty) return messages;

    // 1) سقف العدد أولاً (رسائل كثيرة صغيرة قد تمرّ من سقف البايت وترفضها القاعدة)
    var list = messages.length > maxCount
        ? messages.sublist(messages.length - maxCount)
        : messages;

    // 2) ثم ميزانية البايت
    final sizes = list.map(_messageBytes).toList();
    int total = sizes.fold(0, (a, b) => a + b);
    if (total <= budget) return list;

    int start = 0;
    while (start < list.length - minKeptMessages && total > budget) {
      total -= sizes[start];
      start++;
    }
    return list.sublist(start);
  }

  static int _messageBytes(ChatMessage m) {
    // utf8.encode يعطي الحجم الحقيقي: الحرف العربي بايتان.
    return utf8.encode(m.text).length + utf8.encode(m.refs.join()).length + 64; // 64 ≈ ترويسة
  }

  /// المحادثات المرشّحة للمزامنة: الأحدث أولاً وبحد أقصى [maxSyncedConversations].
  static List<ChatConversation> selectForSync(List<ChatConversation> all) {
    final sorted = [...all]..sort((a, b) => b.lastUpdated.compareTo(a.lastUpdated));
    return sorted.take(maxSyncedConversations).toList();
  }

  /// رفع دفعة (عند عودة الاتصال أو أول تسجيل دخول) مع تطبيق سقف العدد.
  /// يعيد معرّفات ما فشل رفعه ليُعاد لاحقاً.
  Future<List<String>> pushBatch(String uid, List<ChatConversation> all) async {
    final failed = <String>[];
    for (final c in selectForSync(all)) {
      try {
        await push(uid, c);
      } catch (_) {
        failed.add(c.id);
      }
    }
    return failed;
  }

  /// يحذف من السحابة ما تجاوز سقف العدد — تنظيف دوري رخيص (استعلام واحد).
  Future<void> pruneRemote(String uid) async {
    try {
      final snap = await _col(uid).orderBy("last_updated", descending: true).get();
      if (snap.docs.length <= maxSyncedConversations) return;
      for (final doc in snap.docs.skip(maxSyncedConversations)) {
        await doc.reference.delete();
      }
    } catch (e) {
      debugPrint("⚠️ تعذّر تنظيف المحادثات السحابية: $e");
    }
  }

  // ══════════════ سحب ══════════════

  /// السحب الوحيد المسموح: جهاز جديد أو زر «استعادة محادثاتي».
  Future<List<ChatConversation>> pullAll(String uid) async {
    final snap = await _col(uid)
        .orderBy("last_updated", descending: true)
        .limit(maxSyncedConversations)
        .get();
    return snap.docs.map((d) => fromDoc(d.id, d.data())).toList();
  }

  static ChatConversation fromDoc(String id, Map<String, dynamic> d) => ChatConversation(
        id: id,
        title: (d["title"] ?? "محادثة").toString(),
        subject: (d["subject"] ?? "احياء").toString(),
        mode: (d["mode"] ?? "شرح").toString(),
        grade: (d["grade"] is int) ? d["grade"] as int : 3,
        track: (d["track"] ?? "علمي").toString(),
        branch: (d["branch"] ?? "").toString(),
        // 🗄️ ومستنداتُ ما قبل هذه الحقول تصل بلا سياق — تُقرأ فارغةً
        //    كما كانت تماماً، فلا ترحيلَ ولا انهيار.
        unit: (d["unit"] ?? "").toString(),
        lesson: (d["lesson"] ?? "").toString(),
        contentMode: (d["content_mode"] ?? "").toString(),
        pages: ChatConversation.pagesFrom(d["pages"]),
        messages: ((d["messages"] as List?) ?? const [])
            .map((m) => messageFromMap(Map<String, dynamic>.from(m as Map)))
            .toList(),
        createdAt: DateTime.tryParse((d["created_at"] ?? "").toString()) ?? DateTime.now(),
        lastUpdated: DateTime.tryParse((d["last_updated"] ?? "").toString()) ?? DateTime.now(),
      );

  /// 🧠 نتيجة اختبار → `users/{uid}/results/{id}` — كتابة واحدة لكل اختبار.
  Future<void> pushResult(String uid, QuizResult r) async {
    if (uid.isEmpty) return;
    await _db.collection("users").doc(uid).collection("results").doc(r.id).set(r.toDoc());
  }

  /// استعادة النتائج على جهاز جديد (مع المحادثات).
  Future<List<QuizResult>> pullResults(String uid, {int limit = 100}) async {
    final snap = await _db
        .collection("users").doc(uid).collection("results")
        .orderBy("created_at", descending: true)
        .limit(limit)
        .get();
    return snap.docs.map((d) => QuizResult.fromDoc(d.id, d.data())).toList();
  }

  Future<void> deleteRemote(String uid, String convId) async {
    try {
      await _col(uid).doc(convId).delete();
    } catch (e) {
      debugPrint("⚠️ تعذّر حذف المحادثة سحابياً: $e");
    }
  }

  // ══════════════ 🎓 محادثات مساعد المنح ══════════════
  // نفس سياسة محادثات التعليم بالضبط: **Hive أولاً للعرض**، ونسخة سحابية
  // fire-and-forget بلا مستمعين ولا سحب دوري.
  //
  // ★ **انحرافٌ مقصود عن [v3 §5.6]** الذي جعلها «Hive فقط بلا مزامنة»:
  //   المالك طلب أن تكون **مربوطة بالحساب**، وربطٌ لا ينجو من تغيير الجهاز
  //   ليس ربطاً. والكلفة هامشية — شات المنحة قصير ومحدود بـ25 محادثة لكل
  //   منحة على الجهاز و[maxSyncedScholarshipChats] سحابياً.

  /// سقف ما يُزامَن من محادثات المنح لكل طالب.
  static const int maxSyncedScholarshipChats = 40;

  CollectionReference<Map<String, dynamic>> _schCol(String uid) =>
      _db.collection("users").doc(uid).collection("scholarship_chats");

  Future<void> pushScholarshipChat(String uid, SchConversation c) async {
    if (uid.isEmpty || c.messages.isEmpty) return;
    try {
      await _schCol(uid).doc(c.id).set(schToDoc(c), SetOptions(merge: true));
    } catch (e) {
      debugPrint("⚠️ تعذّرت مزامنة محادثة المنحة ${c.id}: $e");
      rethrow;
    }
  }

  /// نفس سقف البايت وسقف العدد المطبَّقين على محادثات التعليم — القاعدة
  /// الأمنية ترفض ما يتجاوزهما، فالقصّ هنا لا هناك.
  Map<String, dynamic> schToDoc(SchConversation c) {
    final kept = trimSchMessages(c.messages);
    return {
      "title": c.title,
      "scholarship_id": c.scholarshipId,
      "scholarship_name": c.scholarshipName,
      "messages": kept.map((m) => m.toMap()).toList(),
      "truncated": kept.length != c.messages.length,
      "created_at": c.createdAt.toIso8601String(),
      "last_updated": c.lastUpdated.toIso8601String(),
      "expires_at": Timestamp.fromDate(c.lastUpdated.add(cloudRetention)),
    };
  }

  /// يقصّ **أقدم** الرسائل حتى تدخل ضمن ميزانية البايت وسقف العدد.
  /// ⚠️ بالبايت لا بالعدد: الحرف العربي في UTF-8 بايتان.
  static List<SchMessage> trimSchMessages(List<SchMessage> messages,
      {int budget = maxDocBytes, int maxCount = maxCloudMessages}) {
    if (messages.isEmpty) return messages;
    var list = messages.length > maxCount
        ? messages.sublist(messages.length - maxCount)
        : messages;

    final sizes = list.map((m) => utf8.encode(m.text).length + 64).toList();
    int total = sizes.fold(0, (a, b) => a + b);
    if (total <= budget) return list;

    int start = 0;
    while (start < list.length - minKeptMessages && total > budget) {
      total -= sizes[start];
      start++;
    }
    return list.sublist(start);
  }

  Future<List<SchConversation>> pullScholarshipChats(String uid) async {
    final snap = await _schCol(uid)
        .orderBy("last_updated", descending: true)
        .limit(maxSyncedScholarshipChats)
        .get();
    return snap.docs.map((d) => SchConversation.fromDoc(d.id, d.data())).toList();
  }

  Future<void> deleteRemoteScholarshipChat(String uid, String id) async {
    try {
      await _schCol(uid).doc(id).delete();
    } catch (e) {
      debugPrint("⚠️ تعذّر حذف محادثة المنحة سحابياً: $e");
    }
  }
}
