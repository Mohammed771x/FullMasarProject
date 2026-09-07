import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../session/user_session.dart';

// ==========================================
// 📬 core/notifications/notifications_repository.dart — صندوق إشعارات الطالب
// ==========================================
// 🔴 **لماذا وُجد هذا الملف:** الخادم كان يحفظ الإشعار في صندوق كل مستلَم
//    منذ اليوم الأول، و`/notifications/inbox` جاهزٌ ومختبَر — **ولم يكن في
//    التطبيق سطرٌ واحد يناديه.** وجرسُ الرئيسية كان يعرض
//    `_snack("لا إشعارات جديدة")` **نصّاً ثابتاً** بشارةٍ حمراء لا تنطفئ.
//    فيرسل المالك إعلاناً، وتقول اللوحة بصدق «محفوظ في صناديقهم»، ويفتح
//    الطالب الجرس فيُقال له «لا إشعارات» — والاثنان يظنّان الخلل في الآخر.
//
// ⭐ **والصندوق ليس ترفاً بجانب الدفع بل هو الطريق الأضمن:** الدفع يحتاج
//    إذناً وجهازاً مسجَّلاً وشبكةً لحظةَ الإرسال، وأيٌّ منها يسقط فيضيع
//    الإعلان بلا أثر. أما الصندوق فيُقرأ متى فتح الطالب التطبيق.
//
// ⚡ **الكاش أولاً** كالبانرات وقواعد الأقسام: الجرس يفتح فوراً على آخر ما
//    وصل، والشبكة تصحّح بعده. ولا شاشةَ انتظارٍ لأجل إعلان.
//
// 👁️ **وحالة القراءة محليّة بالجهاز ومربوطةٌ بالـuid**: جوّالٌ يتشاركه
//    أخوان لا يجوز أن يُطفئ أحدهما شارةَ الآخر. ولا تُرفع للخادم لأنها لا
//    تعني شيئاً لأحدٍ غير صاحبها.

@immutable
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.body,
    required this.link,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;

  /// وجهة النقر — نفس مفاتيح الأقسام في الخادم واللوحة ([push_router]).
  final String link;

  /// نصّ ISO كما يكتبه الخادم. يُترك نصّاً: الترتيب يتم به حرفياً، وتحويله
  /// لتاريخٍ ثم إعادته يفتح باب اختلاف المناطق الزمنية بلا فائدة.
  final String createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        body: (json['body'] ?? '').toString(),
        link: (json['link'] ?? 'none').toString(),
        createdAt: (json['created_at'] ?? '').toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'link': link,
        'created_at': createdAt,
      };
}

/// 👤 **صاحب الصندوق** — من `UserSession` افتراضاً.
///
/// ⭐ **لماذا صنفٌ صغيرٌ بدل قراءةٍ مباشرة؟** لأن قواعد الصندوق التي يجب
///    أن تُختبر (الزائر لا صندوق له · كاشُ حسابٍ آخر يُهمل · القصّ عند
///    تبديل الحساب) كلها **قواعدُ هويّة** — واختبارها عبر `UserSession`
///    يعني تهيئة Firebase في كل اختبار، فلا تُختبر أصلاً. وهي بالضبط
///    القواعد التي يكشف انكسارُها صندوقَ أخٍ في يد أخيه.
class InboxIdentity {
  const InboxIdentity();

  String get uid => UserSession.I.uid;
  bool get isGuest => UserSession.I.isGuest;
  Future<String?> idToken() => UserSession.I.idToken();
}

class NotificationsRepository extends ChangeNotifier {
  NotificationsRepository._();
  static final NotificationsRepository I = NotificationsRepository._();

  static const _kCache = 'notifications_cache_v1';
  static const _kOwner = 'notifications_owner_v1';
  static const _kRead = 'notifications_read_v1';

  final List<NotificationItem> _items = [];
  final Set<String> _read = {};
  bool _loaded = false;

  /// آخر محاولة تحديثٍ فشلت؟ تُعرض في الشاشة ولا تُخفي الكاش.
  bool lastRefreshFailed = false;

  @visibleForTesting
  static void overrideClient(http.Client? client) => I._client = client;
  http.Client? _client;
  http.Client get _http => _client ??= http.Client();

  @visibleForTesting
  static void overrideIdentity(InboxIdentity? identity) =>
      I._identity = identity ?? const InboxIdentity();
  InboxIdentity _identity = const InboxIdentity();

  List<NotificationItem> get items => List.unmodifiable(_items);

  bool isRead(String id) => _read.contains(id);

  int get unreadCount => _items.where((n) => !_read.contains(n.id)).length;

  bool get hasUnread => unreadCount > 0;

  /// تُستدعى مرة عند الإقلاع. **لا ترمي أبداً** — الإشعار ليس جوهر التطبيق.
  Future<void> load() async {
    if (!_loaded) await _readCache();
    _loaded = true;
    await refresh();
  }

  /// يجلب الصندوق من الخادم. يُنادى عند الإقلاع، وعند فتح شاشة الإشعارات،
  /// وعند وصول إشعارٍ والتطبيق مفتوح.
  Future<void> refresh() async {
    // 🚪 الزائر لا صندوق له: حسابه مؤقت ولا يدخل جمهوراً أصلاً. ونداءٌ
    //    بلا توكن يعود ٤٠١ فيُعدّ «فشلاً» ويُظهر رسالة عطلٍ لا سبب لها.
    if (_identity.isGuest || _identity.uid.isEmpty) {
      if (_items.isNotEmpty) {
        _items.clear();
        notifyListeners();
      }
      return;
    }
    try {
      final idToken = await _identity.idToken();
      if (idToken == null || idToken.isEmpty) return;

      final res = await _http
          .get(Uri.parse(ApiEndpoints.notificationsInbox()),
              headers: ApiClient.authHeaders(idToken))
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        lastRefreshFailed = true;
        notifyListeners();
        return;
      }

      final data = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
      final raw = data['items'];
      // ردٌّ مشوّه (وسيطٌ يعترض · خادمٌ أقدم) ⇒ نُبقي الكاش ولا نمسح صندوقاً.
      if (raw is! List) {
        lastRefreshFailed = true;
        notifyListeners();
        return;
      }

      _items
        ..clear()
        ..addAll(raw
            .whereType<Map>()
            .map((e) => NotificationItem.fromJson(e.cast<String, dynamic>()))
            .where((n) => n.id.isNotEmpty));
      lastRefreshFailed = false;

      // 🧹 حالةُ القراءة تُقلَّم على ما وصل: الإشعار ينتهي بعد ٣٠ يوماً في
      //    الخادم، فمعرّفاتٌ لا مقابل لها تتراكم بلا حدٍّ في جهاز الطالب.
      _read.removeWhere((id) => !_items.any((n) => n.id == id));

      await _writeCache();
      notifyListeners();
    } catch (e) {
      // 🛟 بلا شبكة ⇒ يبقى الكاش. ولا رسالةَ خطأٍ مقتحِمة: الطالب لم يطلب
      //    هذا التحديث ولا يملك إصلاحه — الشاشة وحدها تقول إن التحديث تعذّر.
      lastRefreshFailed = true;
      debugPrint('📬 تعذّر تحديث صندوق الإشعارات: $e');
      notifyListeners();
    }
  }

  /// يضع إشعاراً في المقروء. يُنادى عند فتحه.
  Future<void> markRead(String id) async {
    if (id.isEmpty || !_read.add(id)) return;
    notifyListeners();
    await _writeCache();
  }

  /// يضع كل ما وصل في المقروء — زرّ «تعليم الكل كمقروء».
  Future<void> markAllRead() async {
    final before = _read.length;
    _read.addAll(_items.map((n) => n.id));
    if (_read.length == before) return;
    notifyListeners();
    await _writeCache();
  }

  /// 🚪 عند تبديل الحساب: صندوق الأول لا يُعرض للثاني ولو للحظة.
  Future<void> clear() async {
    _items.clear();
    _read.clear();
    _loaded = false;
    lastRefreshFailed = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kCache);
      await prefs.remove(_kRead);
      await prefs.remove(_kOwner);
    } catch (_) {/* لا شيء يُفعل — والصندوق فُرِّغ في الذاكرة أصلاً */}
  }

  Future<void> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ⚠️ **كاشُ حسابٍ آخر يُهمل**: الجوّال المتشارَك يجعل صندوق الأخ
      //    يظهر لأخيه لحظةً قبل أن يصحّحه الخادم — ولحظةٌ تكفي.
      if ((prefs.getString(_kOwner) ?? '') != _identity.uid) return;

      final raw = prefs.getString(_kCache);
      if (raw != null && raw.isNotEmpty) {
        _items
          ..clear()
          ..addAll((jsonDecode(raw) as List)
              .whereType<Map>()
              .map((e) => NotificationItem.fromJson(e.cast<String, dynamic>())));
      }
      _read
        ..clear()
        ..addAll(prefs.getStringList(_kRead) ?? const []);
    } catch (_) {
      // كاش تالف من نسخة أقدم ⇒ يُتجاهل ويُعاد الجلب.
    }
  }

  Future<void> _writeCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCache, jsonEncode(_items.map((n) => n.toJson()).toList()));
      await prefs.setStringList(_kRead, _read.toList());
      await prefs.setString(_kOwner, _identity.uid);
    } catch (e) {
      debugPrint('📬 تعذّر حفظ صندوق الإشعارات: $e');
    }
  }

  @visibleForTesting
  void seed(List<NotificationItem> items, {Set<String> read = const {}}) {
    _items
      ..clear()
      ..addAll(items);
    _read
      ..clear()
      ..addAll(read);
    _loaded = true;
    lastRefreshFailed = false;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _items.clear();
    _read.clear();
    _loaded = false;
    lastRefreshFailed = false;
  }
}
