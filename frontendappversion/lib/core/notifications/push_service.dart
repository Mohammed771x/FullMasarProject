import 'dart:convert';
import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../session/user_session.dart';

// ==========================================
// 📲 core/notifications/push_service.dart — إشعارات الدفع
// ==========================================
// ⭐ **الرمز يُرسل للخادم لا يُكتب في Firestore.** قواعد الأمان تمنع العميل
//    من لمس `fcm_tokens` صراحةً، لأن `arrayUnion` من العميل لا يمكن تحديدها
//    بسقف — جهازٌ مصاب أو حلقةٌ خاطئة تكتب آلاف الرموز في مستندٍ واحد
//    فتُثقل كل قراءةٍ له بعدها. الخادم يقرأ ويقصّ ويكتب.
//
// 🔕 **ولا نطلب الإذن عند أول إقلاع.** نافذة إذنٍ تظهر قبل أن يفهم الطالب
//    ما التطبيق تُرفض غالباً — ورفضُ iOS **نهائي** لا يُسأل بعده إلا من
//    الإعدادات. فنطلبه عند أول دخولٍ ناجح، حين يكون قد رأى قيمة التطبيق.
//
// 🛡️ **وكل شيء هنا يفشل صامتاً.** الإشعار تحسينٌ لا شرطُ تشغيل: جهازٌ بلا
//    خدمات جوجل (شائع في اليمن) يجب أن يفتح التطبيق كاملاً بلا رسالة خطأ
//    واحدة عن ميزةٍ لم يطلبها.

/// 🔔 يُنادى حين تصل رسالة والتطبيق مغلق تماماً.
///
/// ⚠️ **دالّة عليا خارج أي صنف** — يشترطها Flutter لأنها تعمل في عزلة
///    (isolate) ثانية لا ترى حالة التطبيق. جعلُها تابعةً لصنفٍ يُفشل
///    التسجيل صامتاً على أندرويد.
@pragma('vm:entry-point')
Future<void> masarBackgroundMessageHandler(RemoteMessage message) async {
  // لا عمل هنا عمداً: النظام يعرض الإشعار بنفسه، وأي تهيئةٍ ثقيلة في هذه
  // العزلة تُبطئ وصوله. المحتوى يُقرأ من الصندوق عند فتح التطبيق.
  debugPrint('📲 إشعار في الخلفية: ${message.messageId}');
}

/// وجهة النقر على الإشعار — تلتقطها الشاشة الرئيسية.
typedef PushTapHandler = void Function(String link, String notificationId);

class PushService {
  PushService._();
  static final PushService I = PushService._();

  /// تُحقن في الاختبارات.
  @visibleForTesting
  static void overrideClient(http.Client? client) => I._client = client;
  http.Client? _client;
  http.Client get _http => _client ??= http.Client();

  FirebaseMessaging? _fm;
  FirebaseMessaging get _messaging => _fm ??= FirebaseMessaging.instance;

  @visibleForTesting
  set messagingForTest(FirebaseMessaging value) => _fm = value;

  String _token = '';
  bool _wired = false;
  /// 🧭 وجهة النقر. ضبطُها **يُفرِّغ نقرةً محفوظة** إن وُجدت.
  ///
  /// ⚠️ **البوفر ليس ترفاً:** نقرةٌ فتحت التطبيق من الصفر تصل عبر
  ///    `getInitialMessage()` أثناء التهيئة — قبل أن يوجد مُوجِّهٌ أو
  ///    `Navigator` أصلاً. وبلا حفظها تضيع النقرةُ صامتةً، فينقر الطالب
  ///    الإشعار فيفتح التطبيق على الرئيسية ولا يفهم لماذا.
  PushTapHandler? get onTap => _onTap;
  set onTap(PushTapHandler? handler) {
    _onTap = handler;
    final waiting = _pendingTap;
    if (handler == null || waiting == null) return;
    _pendingTap = null;
    handler(waiting.$1, waiting.$2);
  }

  PushTapHandler? _onTap;
  (String, String)? _pendingTap;

  /// يُنادى حين يصل إشعارٌ والتطبيق مفتوح — لتحديث صندوق الإشعارات.
  void Function()? onForeground;

  /// آخر رمز سُجِّل — يُستعمل عند الخروج لفصله.
  String get token => _token;

  /// هل منح الطالب الإذن؟ (للعرض في شاشة الإعدادات)
  bool granted = false;

  // ══════════════ الإقلاع ══════════════

  /// يُنادى بعد تهيئة Firebase وبعد أن يصير للطالب حساب.
  ///
  /// آمنٌ للنداء المتكرر: كل إقلاعٍ يناديه، ولا يكتب شيئاً إن لم يتغيّر الرمز.
  Future<void> start() async {
    if (kIsWeb) return; // الويب يحتاج Service Worker — خارج نطاقنا الآن
    try {
      await _wire();
      await _requestPermission();
      if (!granted) {
        // ⚠️ يُقال صراحةً: رفضُ iOS **نهائي** ولا يُسأل بعده إلا من إعدادات
        //    النظام — فصمتٌ هنا يجعل العطل يبدو في الخادم لا في الإذن.
        debugPrint('📲 الإشعارات مرفوضة من الطالب — لا تسجيل. '
            'تُفتح من إعدادات النظام وحدها بعد الرفض.');
        return;
      }
      await _syncToken();
    } catch (e) {
      // 🛡️ جهازٌ بلا خدمات جوجل أو مشروعٌ بلا APNs ⇒ لا إشعارات، ولا عطل.
      debugPrint('📲 تعذّر تشغيل الإشعارات: $e');
    }
  }

  Future<void> _wire() async {
    if (_wired) return;
    _wired = true;

    // ⚠️ الرمز يتغيّر من تلقاء نفسه (إعادة تثبيت · استعادة نسخة · تنظيف
    //    جوجل الدوري). بلا هذا المستمع يبقى الخادم يدفع لرمزٍ ميت ويظن
    //    الطالبُ أن الإشعارات تعطّلت.
    _messaging.onTokenRefresh.listen((fresh) {
      _token = fresh;
      _send(fresh);
    });

    // 🔔 **والتطبيق مفتوح؟ يجب أن يُرى الإشعار أيضاً.**
    //    iOS يبتلع إشعارات المقدّمة افتراضياً: تصل الجهازَ ولا تظهر شيئاً.
    //    فيرسل الأدمن إعلاناً، ويكون الطالب داخل التطبيق، فلا يرى شيئاً —
    //    ويستنتج الاثنان أن الإشعارات معطّلة وهي تعمل. (أندرويد يعرضها
    //    بنفسه، وهذا النداء لا يضرّه.)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true, badge: true, sound: true,
    );

    FirebaseMessaging.onMessage.listen((m) {
      debugPrint('📲 إشعار والتطبيق مفتوح: ${m.notification?.title ?? m.messageId}');
      onForeground?.call();
    });

    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  Future<void> _requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true, badge: true, sound: true,
    );
    granted = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// ⏳ مهل الانتظار بين محاولات قراءة رمز APNs (تراكمياً ≈ ٨ ثوانٍ).
  ///
  /// ⚠️ **لماذا انتظارٌ لا محاولةٌ واحدة؟** تسجيلُ APNs غير متزامن: النظام
  ///    يطلبه من آبل بعد منح الإذن مباشرةً، ويصل الرمز بعد ثانيةٍ أو ثلاث.
  ///    وقراءتُه فور الإذن تعيد `null` **بلا خطأ** — فيبدو كل شيء ناجحاً
  ///    ولا يُسجَّل جهازٌ واحد. وهذا ما حدث فعلاً في أول تجربة حقيقية:
  ///    وصلت التفضيلات إلى Firestore ولم يصل رمزُ جهازٍ واحد.
  static const _apnsBackoff = [400, 800, 1200, 1600, 2000, 2400];

  Future<String?> _awaitApnsToken() async {
    for (final wait in _apnsBackoff) {
      try {
        final t = await _messaging.getAPNSToken();
        if (t != null && t.isNotEmpty) return t;
      } catch (e) {
        debugPrint('📲 قراءة رمز APNs: $e');
      }
      await Future<void>.delayed(Duration(milliseconds: wait));
    }
    return null;
  }

  Future<void> _syncToken() async {
    // 📱 على iOS لا يصدر رمز FCM قبل أن يسلّم APNs رمزَه.
    if (!kIsWeb && Platform.isIOS) {
      final apns = await _awaitApnsToken();
      if (apns == null) {
        // 🛟 **ولا نستسلم هنا**: نجرّب `getToken()` رغم ذلك — قد ينجح،
        //    وإخفاقه يُقال بسببه بدل صمتٍ يُخفي العطل. والتأجيل «للإقلاع
        //    التالي» وحده كان يعني جهازاً لا يُسجَّل أبداً لمن يفتح
        //    التطبيق مرّةً ويمنح الإذن.
        debugPrint('📲 لم يصل رمز APNs خلال المهلة — نجرّب FCM رغم ذلك.');
      } else {
        debugPrint('📲 APNs جاهز (${apns.length} حرفاً).');
      }
    }
    try {
      final fresh = await _messaging.getToken();
      if (fresh == null || fresh.isEmpty) {
        debugPrint('📲 لم يصدر رمز FCM — تحقّق من مفتاح APNs في Firebase Console.');
        return;
      }
      _token = fresh;
      debugPrint('📲 رمز FCM جاهز — نسجّله في الخادم.');
      await _send(fresh);
    } catch (e) {
      // السبب الأشيع: مفتاح APNs غير مرفوع في Firebase Console.
      debugPrint('📲 تعذّر إصدار رمز FCM: $e');
    }
  }

  Future<void> _send(String value) async {
    if (UserSession.I.isGuest || UserSession.I.uid.isEmpty) return;
    try {
      final idToken = await UserSession.I.idToken();
      if (idToken == null || idToken.isEmpty) return;
      await _http
          .post(
            Uri.parse(ApiEndpoints.device()),
            headers: ApiClient.authHeaders(idToken),
            body: jsonEncode({
              'token': value,
              'platform': kIsWeb ? 'web' : (Platform.isIOS ? 'ios' : 'android'),
            }),
          )
          .timeout(const Duration(seconds: 12));
    } catch (e) {
      // الرمز يُعاد إرساله في الإقلاع التالي — لا حاجة لطابور إعادة محاولة.
      debugPrint('📲 تعذّر تسجيل الجهاز: $e');
    }
  }

  // ══════════════ الخروج ══════════════

  /// يفصل هذا الجهاز عن الحساب الحالي.
  ///
  /// ⚠️ **لازمٌ لا تحسين:** جوّالٌ يتشاركه أخوان — يخرج الأول ويدخل الثاني،
  ///    فتظل إشعارات الأول تصل جهازاً في يد الثاني.
  Future<void> stop() async {
    final value = _token;
    if (value.isEmpty) return;
    try {
      final idToken = await UserSession.I.idToken();
      if (idToken != null && idToken.isNotEmpty) {
        await _http
            .delete(
              Uri.parse('${ApiEndpoints.device()}?token=${Uri.encodeComponent(value)}'),
              headers: ApiClient.authHeaders(idToken),
            )
            .timeout(const Duration(seconds: 8));
      }
    } catch (e) {
      debugPrint('📲 تعذّر فصل الجهاز: $e');
    }
    _token = '';
  }

  void _handleTap(RemoteMessage message) {
    final data = message.data;
    final link = (data['link'] ?? '').toString();
    final id = (data['notification_id'] ?? '').toString();
    debugPrint('📲 نُقر إشعار → وجهة: "$link"');
    if (link.isEmpty || link == 'none') return;
    final handler = _onTap;
    if (handler == null) {
      // لا مُوجِّه بعد (إقلاعٌ من نقرة) — نحفظها ليُفرِّغها عند تسجيله.
      _pendingTap = (link, id);
      return;
    }
    handler(link, id);
  }

  /// 🧪 للاختبارات: يحاكي وصول نقرة بوجهةٍ بعينها.
  @visibleForTesting
  void simulateTap(String link, [String id = '']) =>
      _handleTap(RemoteMessage(data: {'link': link, 'notification_id': id}));

  @visibleForTesting
  void resetForTest() {
    _onTap = null;
    _pendingTap = null;
    _token = '';
    _wired = false;
  }
}
