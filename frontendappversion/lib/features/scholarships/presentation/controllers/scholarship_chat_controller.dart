import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/services/image_service.dart';
import '../../../../core/services/stt_service.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/sync/sync_service.dart';
import '../../data/models/scholarship.dart';
import '../../data/models/scholarship_chat.dart';
import '../../data/scholarship_chat_storage.dart';
import '../../data/scholarship_repository.dart';

// ==========================================
// 🧠 متحكّم شات المنحة
// ==========================================
// مسؤولياته ثلاث لا رابع لها:
//   1. سجلّ المحادثات لهذه المنحة (فتح · إنشاء · حذف)
//   2. إرسال السؤال وحفظ الرد **قبل** الشبكة وبعدها
//   3. تجهيز `chat_history` بالسقف المتفق عليه مع الخادم
//
// ⚠️ **الحفظ قبل الرد لا بعده:** لو انقطع الاتصال بعد إرسال السؤال، يبقى
//    سؤال الطالب في السجلّ. حفظٌ بعد الرد وحده يعني ضياع أسئلة على شبكة ضعيفة.

/// ما يراه الموديل من الرسائل السابقة — **يطابق `HISTORY_LAST_N` في الخادم**.
const int kSchHistoryMessages = 6;

/// سقف حروف الرسالة الواحدة المرسلة في التاريخ (الخادم يقصّ عند 2000).
const int kSchHistoryChars = 1500;

class ScholarshipChatController extends ChangeNotifier {
  ScholarshipChatController({
    required this.scholarship,
    ScholarshipRepository? repository,
  }) : _repo = repository ?? ScholarshipRepository() {
    // 🌊 البثّ يشارك عميل المستودع — نقطةُ حقنٍ واحدة للاختبارات.
    _stream = SchAskStream(_repo.injectedClient);
  }

  final Scholarship scholarship;
  final ScholarshipRepository _repo;
  final _uuid = const Uuid();

  /// 🌊 عميل البثّ — يُلغى مع بقية الموارد عند مغادرة الشاشة.
  late final SchAskStream _stream;

  /// هل يُكتب ردٌّ الآن؟ (تقرؤه الفقاعة لتُظهر التلاشي والمؤشّر)
  bool isStreaming = false;

  SchConversation? _current;
  bool _sending = false;
  String? _notice;

  /// 🛑 **حارس التسلسل** — رقم يزيد مع كل إرسال وكل إيقاف.
  ///
  /// ⚠️ إغلاق الاتصال وحده لا يكفي: الرد قد يكون **في الطريق أصلاً** حين
  ///    ضغط الطالب «إيقاف»، أو قد يعود بعد أن بدأ سؤالاً جديداً. الحارس
  ///    يجعل كل رد لا يطابق رقمه الحالي **يُطرح كاملاً** — فلا يُلحق برسالة
  ///    خاطئة ولا يُلصق فوق محادثة انتقل عنها الطالب.
  int _seq = 0;

  bool get canStop => isBusy;

  // 📷 المرفقات — نفس سقف قسم التعليم (صورتان).
  //    الاستعمال هنا: لقطة من موقع المنحة · كشف درجات · وثيقة يسأل عنها.
  static const int maxImages = 2;
  final List<PickedImage> attachedImages = [];
  bool get canAttachMore => attachedImages.length < maxImages;

  SchConversation? get conversation => _current;
  List<SchMessage> get messages => _current?.messages ?? const [];
  bool get isSending => _sending;

  /// 🚦 **مشغولٌ الآن؟ — الانتظارُ والبثُّ معاً.**
  ///
  /// 🔴 `_sending` يُطفأ عمداً عند أول جزءٍ يصل (لينتهي مؤشّر الانتظار
  ///    وتظهر الفقاعة). فبقي **طلبٌ جارٍ والواجهةُ تحسبه منتهياً**: زرّ
  ///    الإيقاف يختفي في منتصف الردّ، وضغطةُ إرسالٍ ثانية تمرّ فوق الأولى
  ///    **فتُفرَّغ الصورة المرفقة ويُطرح الجواب الأول كاملاً**.
  ///    (نفس علّة قسم التعليم — [ChatController.isBusy].)
  bool get isBusy => _sending || isStreaming;

  /// رسالة حالة تُعرض فوق حقل الكتابة (انتهت الحصة · دعوة تسجيل).
  String? get notice => _notice;

  String get _uid => UserSession.I.uid;

  List<SchConversation> get history =>
      SchChatStorage.forScholarship(_uid, scholarship.id);

  bool get isEmpty => messages.isEmpty;
  bool get hasAttachments => attachedImages.isNotEmpty;

  // ══════════════ إدارة المحادثات ══════════════

  /// يفتح آخر محادثة لهذه المنحة، أو يبدأ واحدة جديدة.
  /// ⭐ الطالب يعود لشات المنحة فيجد كلامه السابق — لا شاشة بيضاء.
  void start() {
    final past = history;
    if (past.isNotEmpty) {
      _current = past.first;
    } else {
      _newConversation();
    }
    notifyListeners();
  }

  void _newConversation() {
    _current = SchConversation(
      id: _uuid.v4(),
      title: "محادثة جديدة",
      scholarshipId: scholarship.id,
      scholarshipName: scholarship.name,
      ownerUid: _uid,
    );
  }

  /// محادثة جديدة — تُهمل الحالية إن كانت فارغة فلا تتراكم سجلات خاوية.
  void newChat() {
    stop();                 // 🛑 لا يُلحق ردٌّ قديم بمحادثة جديدة
    _notice = null;
    _newConversation();
    notifyListeners();
  }

  void openConversation(String id) {
    final c = SchChatStorage.get(id, _uid);
    if (c == null) return;
    stop();                 // 🛑 الرد الجاري يخصّ المحادثة السابقة
    _notice = null;
    _current = c;
    notifyListeners();
  }

  Future<void> deleteConversation(String id) async {
    await SchChatStorage.delete(id);
    SyncService.I.deleteScholarshipChat(id);
    if (_current?.id == id) _newConversation();
    notifyListeners();
  }

  Future<void> clearAll() async {
    await SchChatStorage.clearForScholarship(_uid, scholarship.id);
    _newConversation();
    notifyListeners();
  }

  /// 🛑 إيقاف الطلب الجاري — **فوراً وفعلياً**.
  ///
  /// ثلاث خطوات لا تُختصر إحداها:
  ///   ① رفع الحارس ⇒ أي رد في الطريق يُطرح ولا يُعرض.
  ///   ② إغلاق الاتصال ⇒ الخادم يرى القطع ولا يبقى الطلب معلّقاً.
  ///   ③ تفريغ حالة الإرسال ⇒ الواجهة تعود قابلة للاستعمال فوراً.
  void stop() {
    // 🌊 والبثُّ أيضاً: كان `_sending` مُطفأً وقتها فتخرج الدالة بلا عمل،
    //    أي أن الردّ المبثوث لم يكن يُوقَف أبداً ([isBusy]).
    if (!isBusy) return;
    _seq++;                 // ① يُبطل ما هو في الطريق
    _repo.cancel();         // ② يقطع الاتصال فعلاً
    _stream.cancel();       //    والبثّ معه — وإلا بقي يكتب في فقاعةٍ مهجورة
    _sending = false;       // ③
    isStreaming = false;    //    وما وصل يبقى معروضاً في فقاعته
    _notice = null;
    notifyListeners();
  }

  // ══════════════ 🎤 الإدخال الصوتي ══════════════
  // نفس تدفّق قسم التعليم حرفياً: تسجيل → إنهاء → **تنظيف بالموديل** →
  // النص يظهر في الحقل ليراجعه الطالب قبل الإرسال ([23]).
  // ⚠️ التنظيف ليس ترفاً: التعرّف الآلي يشوّه المصطلحات، وهنا يمرّ النص
  //    على `/voice/clean` بقرينة «منح دراسية» فيصحّح ما شوّهه المحرّك.

  /// ⚠️ كاذبة قبل أول `init` (وهو كسول داخل `start`) — لذلك **لا يُخفى زر
  /// المايك بناءً عليها**، بل يُعرض ويُبلَّغ الطالب عند الفشل الفعلي.
  bool get sttAvailable => SttService.I.isAvailable;
  bool isRecording = false;
  bool isCleaningVoice = false;

  /// يبدأ التسجيل. يعيد رسالة خطأ عربية أو null.
  Future<String?> startVoiceRecording() async {
    if (isRecording || isBusy) return null;
    final started = await SttService.I.start();
    if (!started) return "🎤 التعرف على الكلام غير متاح على هذا الجهاز";
    isRecording = true;
    notifyListeners();
    return null;
  }

  /// 🗑️ إلغاء — لا شيء يصل لحقل الكتابة.
  Future<void> cancelVoiceRecording() async {
    if (!isRecording) return;
    await SttService.I.discard();
    isRecording = false;
    notifyListeners();
  }

  /// ⏹️ إنهاء → تنظيف → يعيد النص ليوضع في الحقل (أو null).
  Future<String?> stopVoiceToText() async {
    if (!isRecording) return null;
    final raw = await SttService.I.finish();
    isRecording = false;
    if (raw.trim().isEmpty) {
      notifyListeners();
      return null;
    }

    isCleaningVoice = true;
    notifyListeners();
    final cleaned = await _repo.cleanVoice(
      rawText: raw,
      idToken: await UserSession.I.idToken(),
      userId: _uid,
    );
    isCleaningVoice = false;
    notifyListeners();
    return cleaned.isEmpty ? raw : cleaned;
  }

  // ══════════════ 📷 المرفقات ══════════════

  /// يرجع رسالة خطأ عربية، أو null عند النجاح/الإلغاء.
  Future<String?> attachImage({required bool fromCamera}) async {
    if (isBusy) return "⏳ انتظر انتهاء الرد الحالي أو أوقفه.";
    if (!canAttachMore) return "📷 الحد الأقصى $maxImages صور";
    try {
      final picked = await ImageService.I.pick(fromCamera: fromCamera);
      if (picked == null) return null;   // ألغى الطالب — ليس خطأ
      attachedImages.add(picked);
      notifyListeners();
      return null;
    } on ImageException catch (e) {
      return e.message;
    } catch (_) {
      return "📷 تعذّر إرفاق الصورة. حاول مجدداً.";
    }
  }

  /// يستبدل مرفقاً بنسخته المحرَّرة (بعد القص أو الرسم).
  /// ⚠️ يُحذف الملف القديم إن تغيّر المسار — وإلا تراكمت نسخ لا يراها أحد.
  void replaceImage(int index, PickedImage edited) {
    if (index < 0 || index >= attachedImages.length) return;
    final old = attachedImages[index];
    attachedImages[index] = edited;
    notifyListeners();
    if (old.path != edited.path) ImageService.I.delete(old.path);
  }

  Future<void> removeAttachedImage(int index) async {
    if (index < 0 || index >= attachedImages.length) return;
    final img = attachedImages.removeAt(index);
    notifyListeners();
    await ImageService.I.delete(img.path);
  }

  // ══════════════ الإرسال ══════════════

  /// آخر [kSchHistoryMessages] رسائل مقصوصة — بلا الرسالة الجارية.
  List<Map<String, String>> _history() {
    final all = messages;
    final slice = all.length <= kSchHistoryMessages
        ? all
        : all.sublist(all.length - kSchHistoryMessages);
    return slice.map((m) {
      // ★ `contextText` لا `text`: يحمل نصّ الصورة معه، وبدونه تُنسى الصورة
      //   في السؤال التالي لأن التاريخ نصٌّ لا صور.
      final content = m.contextText;
      return {
        "role": m.isUser ? "user" : "assistant",
        "content": content.length <= kSchHistoryChars
            ? content
            : content.substring(0, kSchHistoryChars),
      };
    }).toList();
  }

  Future<void> send(String raw) async {
    final text = raw.trim();
    // 📷 صورة بلا نص إرسالٌ صحيح: «اقرأ لي هذه» ضمنية.
    if ((text.isEmpty && attachedImages.isEmpty) || isBusy) return;

    _sending = true;
    _notice = null;
    final seq = ++_seq;     // 🛑 بصمة هذا الطلب — يُطرح إن تغيّرت
    // 🧾 معرّف المحاولة: انتهت المهلة فأعاد الطالب السؤال ⇒ الخادم يرجع
    //    الجواب المخزَّن بلا خصم حصةٍ ثانية ([Backend/core/idempotency.py]).
    final requestId = _uuid.v4();

    // نلتقط المرفقات ونفرّغ الشريط فوراً كي لا تُرسل مرتين بضغطة مزدوجة.
    final sending = List<PickedImage>.of(attachedImages);
    attachedImages.clear();
    final conv = _current ??= SchConversation(
      id: _uuid.v4(),
      title: "محادثة جديدة",
      scholarshipId: scholarship.id,
      scholarshipName: scholarship.name,
      ownerUid: _uid,
    );

    // ⭐ التاريخ يُلتقط **قبل** إضافة السؤال الحالي — وإلا وصل السؤال مرتين.
    final history = _history();

    conv.messages.add(SchMessage(
      role: "user",
      text: text.isEmpty
          ? (sending.length > 1 ? "📷 صورتان" : "📷 صورة")
          : text,
      imagePaths: sending.map((e) => e.path).toList(),
    ));
    conv.retitleFromFirstQuestion();
    await _persist(conv);
    notifyListeners();

    // 🌊 **البثّ هنا أيضاً**: مساعد المنحة يجيب بفقراتٍ طويلة (شروط،
    //    مستندات، خطوات)، والانتظار الصامت عليها أطول من قسم التعليم لا أقصر.
    //
    // 📌 الفقاعة تُنشأ عند أول جزء ثم تنمو، ويُستبدل نصّها بالنهائي في
    //    `done` — لا يُلحق (الخادم يُنقّي الناتج بعد التوليد).
    int? streamIndex;
    final answer = await _stream.ask(
      scholarshipId: scholarship.id,
      question: text,
      history: history,
      imagesBase64: sending.map((e) => e.base64Data).toList(),
      idToken: await UserSession.I.idToken(),
      userId: _uid,
      requestId: requestId,
      onDelta: (piece) {
        if (seq != _seq) return;      // 🛑 طلبٌ أحدث بدأ ⇒ نتجاهل القديم
        if (streamIndex == null) {
          conv.messages.add(SchMessage(role: "ai", text: piece));
          streamIndex = conv.messages.length - 1;
        } else {
          final m = conv.messages[streamIndex!];
          conv.messages[streamIndex!] =
              SchMessage(role: m.role, text: m.text + piece, timestamp: m.timestamp);
        }
        _sending = false;          // ⏳ وصل أول جزء ⇒ ينتهي مؤشّر الانتظار
        isStreaming = true;
        notifyListeners();
      },
    );
    isStreaming = false;

    // 🛑 أُوقف الطلب أو بدأ غيرُه أثناء انتظار الرد ⇒ نطرحه كاملاً.
    //    (سؤال الطالب يبقى محفوظاً — أُضيف قبل الشبكة عن قصد.)
    if (seq != _seq) return;

    // ★ نصّ الصورة يُثبَّت على **رسالة الطالب** لا على الرد — فهو جزء من سؤاله.
    if (answer.imageText.isNotEmpty && sending.isNotEmpty) {
      final last = conv.messages.length - 1;
      final userMsg = conv.messages.lastWhere((m) => m.isUser,
          orElse: () => conv.messages.isEmpty
              ? SchMessage(role: "user", text: text)
              : conv.messages[last]);
      final index = conv.messages.indexOf(userMsg);
      if (index >= 0) {
        conv.messages[index] = SchMessage(
          role: userMsg.role,
          text: userMsg.text,
          timestamp: userMsg.timestamp,
          imagePaths: userMsg.imagePaths,
          imageText: answer.imageText,
        );
      }
    }

    // 🌊 فقاعةٌ نمت أثناء البثّ ⇒ نُثبّت فيها النصّ النهائي بدل إضافة
    //    فقاعةٍ ثانية (كانت ستُظهر الجواب مرتين).
    if (streamIndex != null && streamIndex! < conv.messages.length) {
      final m = conv.messages[streamIndex!];
      conv.messages[streamIndex!] =
          SchMessage(role: m.role, text: answer.text, timestamp: m.timestamp);
    } else {
      conv.messages.add(SchMessage(role: "ai", text: answer.text));
    }
    await _persist(conv);

    if (answer.quotaExceeded) {
      _notice = answer.isGuest
          ? "سجّل حساباً مجانياً لتتابع سؤال المساعد ✨"
          : "تتجدّد حصتك بعد منتصف الليل 🌙";
    }
    _sending = false;
    notifyListeners();
  }

  Future<void> _persist(SchConversation c) async {
    c.synced = false;
    await SchChatStorage.save(c, ownerUid: _uid);
    SyncService.I.pushScholarshipChat(c);   // fire-and-forget مؤجَّل
  }

  /// يُستدعى عند مغادرة الشاشة — يرفع المؤجَّل بدل انتظار المؤقّت.
  Future<void> flush() => SyncService.I.flushNow();

  @override
  void dispose() {
    _stream.cancel();
    stop();                 // 🛑 لا طلب معلّق بعد إغلاق الشاشة
    super.dispose();
  }
}
