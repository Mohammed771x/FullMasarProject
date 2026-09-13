import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/app_config.dart';
import '../../../core/network/api_client.dart';
import '../../chat/data/repositories/ask_stream.dart';
import '../../../core/network/api_endpoints.dart';
import 'models/scholarship.dart';

// ==========================================
// 🎓 مستودع المنح — الشبكة + الكاش + بروتوكول النسخة
// ==========================================
// ⭐ **بروتوكول النسخة هو جوهر هذا الملف:** الجهاز يحفظ رقم نسخة المحتوى،
//    ويرسله مع كل طلب. إن لم يتغيّر رجع رد صغير بلا أي منحة، وتُعرض القائمة
//    من الكاش. فطالبٌ يفتح قسم المنح عشر مرات في اليوم ينزّل القائمة **مرة
//    واحدة** يوم يضيف المالك منحة لا عشر مرات ([32§4]).
//
// 📴 **الكاش ليس تحسيناً بل شرطُ عمل:** الطالب اليمني على إنترنت متقطّع،
//    والمنح آخر ما يحتمل شاشةَ تحميلٍ فارغة. القائمة تُعرض من القرص فوراً،
//    ثم تُصحَّح من الشبكة إن توفّرت.
//
// ⚠️ **الفشل لا يُفرِّغ الكاش:** انقطاع الشبكة يُبقي آخر قائمة معروفة —
//    منحةٌ قديمة بتاريخٍ صحيح خيرٌ من شاشة خالية.

class ScholarshipsResult {
  final List<Scholarship> items;
  final int version;

  /// من أين جاءت القائمة فعلاً — لعرض «آخر تحديث» بصدق.
  final bool fromCache;

  /// رسالة ودّية من الخادم (قسم غير مهيّأ · لا منح بعد).
  final String? message;

  const ScholarshipsResult({
    required this.items,
    required this.version,
    this.fromCache = false,
    this.message,
  });

  bool get isEmpty => items.isEmpty;
}

class ScholarshipRepository {
  ScholarshipRepository([http.Client? client])
      : _injected = client,
        _client = client ?? http.Client();

  final http.Client _client;

  /// عميل مُدخَل من الاختبارات — **لا يُغلق أبداً**: إغلاقه يُعطّل بقية
  /// الاختبار، والإلغاء في الاختبار يحرسه حارس التسلسل لا قطع الاتصال.
  final http.Client? _injected;

  /// العميل المحقون — أو `null` في الإنتاج.
  ///
  /// ⭐ **نقطة حقنٍ واحدة**: `SchAskStream` يبني عميله من هذا، فحقنُ
  ///    `repository` يغطّي المسارين — العاديّ والبثّ — معاً. وبدونه كان
  ///    اختبار «الإيقاف» يحقن المستودع بينما البثّ يفتح اتصالاً حقيقياً،
  ///    فيقيس شيئاً آخر ويمرّ وهو لا يحرس شيئاً.
  ///
  /// ⚠️ وليست `@visibleForTesting`: الإنتاج يستعملها فعلاً لربط البثّ.
  http.Client? get injectedClient => _injected;

  /// 🛑 عميل مستقل لطلب المساعد وحده — كي يُغلق عند الإيقاف فيُقطع الاتصال
  /// **فعلياً**. تجاهل الرد وحده لا يكفي: الطلب يبقى معلّقاً على الخادم
  /// ويستهلك نداء موديل مدفوعاً كاملاً. (نفس ما يفعله `ChatRepository`.)
  http.Client? _askClient;

  /// يقطع طلب المساعد الجاري — إن وُجد.
  void cancel() {
    if (_injected == null) {
      try {
        _askClient?.close();
      } catch (_) {}
    }
    _askClient = null;
  }

  static const _kVersion = 'sch_cache_version';
  static const _kItems = 'sch_cache_items';
  static const _kFetchedAt = 'sch_cache_fetched_at';

  // ══════════════ الكاش ══════════════

  Future<ScholarshipsResult?> readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kItems);
      if (raw == null || raw.isEmpty) return null;
      final list = (jsonDecode(raw) as List)
          .map((e) => Scholarship.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return ScholarshipsResult(
        items: list,
        version: prefs.getInt(_kVersion) ?? 0,
        fromCache: true,
      );
    } catch (e) {
      debugPrint("⚠️ تعذّرت قراءة كاش المنح: $e");
      return null;
    }
  }

  Future<void> _writeCache(List<Scholarship> items, int version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kItems, jsonEncode(items.map((s) => s.toJson()).toList()));
      await prefs.setInt(_kVersion, version);
      await prefs.setInt(_kFetchedAt, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint("⚠️ تعذّرت كتابة كاش المنح: $e");
    }
  }

  Future<DateTime?> lastFetchedAt() async {
    final ms = (await SharedPreferences.getInstance()).getInt(_kFetchedAt);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  /// يُستدعى عند «مسح بيانات التطبيق» — الكاش لا يُترك ليتيماً.
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kItems);
    await prefs.remove(_kVersion);
    await prefs.remove(_kFetchedAt);
    await _clearCovers(prefs);
  }

  // ══════════════ الشبكة ══════════════

  /// يجلب القائمة. [force] يتجاهل رقم النسخة (زر «تحديث» اليدوي).
  ///
  /// لا يرمي عند أعطال الشبكة: يعيد الكاش. الرمي محجوز لحالة
  /// «لا كاش ولا شبكة» كي تعرض الشاشة حالة فارغة صريحة.
  Future<ScholarshipsResult> fetch({bool force = false}) async {
    final cached = await readCache();
    final knownVersion = force ? -1 : (cached?.version ?? -1);

    try {
      final res = await _client
          .get(Uri.parse(ApiEndpoints.scholarships(knownVersion)),
              headers: ApiClient.contentHeaders)
          .timeout(AppConfig.contentTimeout);

      if (res.statusCode != 200) throw HttpException("HTTP ${res.statusCode}");
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;

      // لم يتغيّر شيء ⇒ الكاش صحيح، وصفر بايت نُقلت من القائمة.
      if (data["changed"] == false && cached != null) {
        return ScholarshipsResult(
            items: cached.items, version: cached.version, fromCache: true);
      }

      final items = ((data["items"] as List?) ?? const [])
          .map((e) => Scholarship.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList()
        ..sort((a, b) => a.order.compareTo(b.order));
      final version = (data["version"] is int) ? data["version"] as int : 0;

      // ⚠️ لا نكتب قائمة فارغة فوق كاشٍ عامر: خادمٌ غير مهيّأ يرجع فارغاً،
      //    ولا يجوز أن يمسح منحاً صحيحة على جهاز الطالب.
      if (items.isNotEmpty || cached == null || cached.items.isEmpty) {
        // ⚠️ النسخة تغيّرت ⇒ قد يكون الأدمن بدّل غلافاً، فنُسقط كاش الأغلفة.
        if (cached != null && cached.version != version) {
          await _clearCovers(await SharedPreferences.getInstance());
        }
        await _writeCache(items, version);
      } else {
        return ScholarshipsResult(
            items: cached.items,
            version: cached.version,
            fromCache: true,
            message: (data["answer"] ?? "").toString().isEmpty
                ? null
                : data["answer"].toString());
      }

      return ScholarshipsResult(
        items: items,
        version: version,
        message: (data["answer"] ?? "").toString().isEmpty
            ? null
            : data["answer"].toString(),
      );
    } catch (e) {
      debugPrint("⚠️ تعذّر جلب المنح: $e");
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// منحة واحدة بمعرّفها — للروابط العميقة (بانر · إشعار).
  /// يبحث في الكاش أولاً فلا يكلّف طلباً في الحالة الشائعة.
  Future<Scholarship?> byId(String id) async {
    final cached = await readCache();
    for (final s in cached?.items ?? const <Scholarship>[]) {
      if (s.id == id) return s;
    }
    try {
      final res = await _client
          .get(Uri.parse(ApiEndpoints.scholarship(id)),
              headers: ApiClient.contentHeaders)
          .timeout(AppConfig.contentTimeout);
      if (res.statusCode != 200) return null;
      return Scholarship.fromJson(
          Map<String, dynamic>.from(jsonDecode(utf8.decode(res.bodyBytes)) as Map));
    } catch (_) {
      return null;
    }
  }

  // ══════════════ 💬 مساعد المنحة ══════════════

  /// يرسل سؤالاً مع آخر [history] رسائل. يعيد الرد أو رسالة ودّية.
  Future<SchAnswer> ask({
    required String scholarshipId,
    required String question,
    required List<Map<String, String>> history,
    List<String> imagesBase64 = const [],
    String? idToken,
    String userId = "",
    String requestId = "",
  }) async {
    // عميل جديد لكل طلب: إغلاق السابق يقطعه ولا يُعطّل ما بعده.
    // (وفي الاختبارات نستعمل المُدخَل كما هو — راجع `_injected`.)
    cancel();
    final client = _injected ?? http.Client();
    _askClient = client;

    try {
      final res = await client
          .post(
            Uri.parse(ApiEndpoints.scholarshipAsk()),
            headers: ApiClient.authHeaders(idToken),
            body: jsonEncode({
              "user_id": userId,
              "request_id": requestId,
              "scholarship_id": scholarshipId,
              "question": question,
              "chat_history": history,
              // 📷 الصورة تُقرأ على الخادم ثم تُنسى — لا تُحفظ ولا تُسجَّل.
              if (imagesBase64.isNotEmpty) "images_base64": imagesBase64,
            }),
          )
          .timeout(Duration(seconds: imagesBase64.isEmpty ? 60 : 90),
              onTimeout: () => throw TimeoutException("scholarship ask timeout"));

      // 429 (حصة/معدل) و404 يحملان رسالة عربية جاهزة — نعرضها كما هي.
      if (res.statusCode >= 500) throw HttpException("HTTP ${res.statusCode}");
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return SchAnswer(
        text: (data["answer"] ?? "").toString(),
        ok: data["ok"] == true,
        quotaExceeded: data["quota_exceeded"] == true,
        isGuest: data["is_guest"] == true,
        imageText: (data["extracted_text"] ?? "").toString(),
      );
    } on TimeoutException {
      return const SchAnswer(
          text: "⏳ تأخّر الرد. تحقّق من اتصالك وأعد المحاولة.", ok: false);
    } catch (e) {
      debugPrint("⚠️ مساعد المنحة: $e");
      // إغلاقُنا نحن للعميل يصل هنا أيضاً — والمتحكّم يميّزه بحارس التسلسل.
      return const SchAnswer(
          text: "⚠️ تعذّر الوصول للمساعد. تأكد من اتصالك بالإنترنت.", ok: false);
    } finally {
      if (identical(_askClient, client)) _askClient = null;
    }
  }

  // ══════════════ 🖼️ غلاف المنحة ══════════════

  static const _kCoverPrefix = 'sch_cover_';

  /// يجلب غلاف منحة — من الكاش أولاً، ثم الشبكة.
  ///
  /// ⭐ **يُجلب عند فتح شاشة المنحة وحدها** لا مع القائمة: الغلاف ~50 ك.ب،
  ///   وحمله في القائمة يُثقل كل تحديث على كل طالب ([32§4]).
  /// 📴 والكاش يجعل الفتحة الثانية فورية وبلا إنترنت.
  Future<String> cover(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('$_kCoverPrefix$id');
    if (cached != null && cached.isNotEmpty) return cached;

    try {
      final res = await _client
          .get(Uri.parse(ApiEndpoints.scholarshipCover(id)),
              headers: ApiClient.contentHeaders)
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return "";
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      final image = (data["image"] ?? "").toString();
      if (image.isNotEmpty) await prefs.setString('$_kCoverPrefix$id', image);
      return image;
    } catch (e) {
      debugPrint("⚠️ غلاف المنحة: $e");
      return "";
    }
  }

  /// يُمسح مع كاش القائمة — غلافٌ قديم لمنحة حُذفت لا معنى له.
  Future<void> _clearCovers(SharedPreferences prefs) async {
    for (final key in prefs.getKeys().where((k) => k.startsWith(_kCoverPrefix))) {
      await prefs.remove(key);
    }
  }

  // ══════════════ 🎤 تنظيف النص الصوتي ══════════════

  /// يمرّر نص التسجيل على `/voice/clean` بقرينة «منح دراسية».
  /// يعيد النص المنظّف، أو فارغاً عند أي فشل (فيُستعمل الخام).
  Future<String> cleanVoice({
    required String rawText,
    String? idToken,
    String userId = "",
  }) async {
    try {
      final res = await _client
          .post(
            Uri.parse(ApiEndpoints.voiceClean()),
            headers: ApiClient.authHeaders(idToken),
            body: jsonEncode({
              "user_id": userId,
              "text": rawText,
              // 📚 القرينة تُرجّح مصطلحات المنح («الابتعاث» · «خطاب الدافع»)
              "subject": "منح دراسية",
            }),
          )
          .timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return "";
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return (data["text"] ?? "").toString();
    } catch (e) {
      debugPrint("⚠️ تنظيف الصوت: $e");
      return "";      // الخام أفضل من لا شيء
    }
  }
}

/// 🌊 بثّ ردّ مساعد المنحة — نفس بروتوكول قسم التعليم حرفياً.
///
/// ⚠️ يُعيد استعمال [AskStream] بدل عميلٍ ثانٍ: البروتوكول واحد (SSE
///    بأحداث `delta`/`done`/`error`)، ونسخُ فكّ الترميز كان يعني مكانين
///    يُصلَح فخّ التقطيع في أحدهما وحده.
class SchAnswer {
  final String text;
  final bool ok;
  final bool quotaExceeded;
  final bool isGuest;

  /// 📄 نصّ الصورة كما قرأه الخادم — يُخزَّن مع رسالة الطالب لا يُعرض.
  final String imageText;

  const SchAnswer({
    required this.text,
    required this.ok,
    this.quotaExceeded = false,
    this.isGuest = false,
    this.imageText = "",
  });
}


// ══════════════════════════════════════════════════
// 🌊 بثّ ردّ مساعد المنحة
// ══════════════════════════════════════════════════
class SchAskStream {
  SchAskStream([http.Client? client]) : _stream = AskStream(client);

  final AskStream _stream;

  /// يبثّ الرد. `onDelta` تُنادى مع كل جزء، والقيمة المعادة هي الرد النهائي.
  ///
  /// 🛟 لا يرمي: الانقطاع يعود كـ`SchAnswer(ok: false)` برسالةٍ عربية،
  ///    فيتعامل معه المتحكّم كأي ردٍّ غير ناجح بلا `try/catch` إضافي.
  Future<SchAnswer> ask({
    required String scholarshipId,
    required String question,
    required List<Map<String, String>> history,
    required void Function(String) onDelta,
    List<String> imagesBase64 = const [],
    String? idToken,
    String userId = "",
    String requestId = "",
  }) async {
    Map<String, dynamic>? done;
    String? failure;

    await for (final ev in _stream.open(
      url: Uri.parse(ApiEndpoints.scholarshipAskStream()),
      headers: ApiClient.authHeaders(idToken),
      timeout: Duration(seconds: imagesBase64.isEmpty ? 90 : 120),
      body: {
        "user_id": userId,
        "request_id": requestId,
        "scholarship_id": scholarshipId,
        "question": question,
        "chat_history": history,
        // 📷 الصورة تُقرأ على الخادم ثم تُنسى — لا تُحفظ ولا تُسجَّل.
        if (imagesBase64.isNotEmpty) "images_base64": imagesBase64,
      },
    )) {
      switch (ev) {
        case AskDelta(text: final piece):
          onDelta(piece);
        case AskDone(payload: final p):
          done = p;
        case AskFailure(message: final m):
          failure = m;
      }
    }

    if (done == null) {
      return SchAnswer(
          text: failure ?? "⚠️ تعذّر الوصول للمساعد الآن. حاول بعد قليل.",
          ok: false);
    }
    return SchAnswer(
      text: (done["answer"] ?? "").toString(),
      ok: done["ok"] != false,
      quotaExceeded: done["quota_exceeded"] == true,
      isGuest: done["is_guest"] == true,
      imageText: (done["extracted_text"] ?? "").toString(),
    );
  }

  void cancel() => _stream.cancel();
}
