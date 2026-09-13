import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../session/user_session.dart';

// ==========================================
// 🎟️ حصّة الطالب — الرقم الذي كان مخفياً
// ==========================================
// 🔴 **ما كان يحدث:** الخادم يحسب المتبقي منذ البداية (`quota.peek`) ولا
//    مسارَ يعرضه ولا شاشةَ تقرؤه. فالطالب يذاكر ثم يُمنع **فجأةً** في منتصف
//    درسه برسالة «وصلت حدّك اليومي» — بلا أي إنذارٍ سابق يجعله يوزّع أسئلته.
//
// ⭐ والعلاج رقمٌ واحد في الأعلى: «متبقٍّ لك ١٧ سؤالاً اليوم». يحوّل الحدَّ
//    من مفاجأةٍ محبطة إلى معلومةٍ يخطّط عليها.
//
// 💰 **ولا يكلّف شيئاً**: `/me/quota` قراءةٌ لا تنادي أي موديل. ومع ذلك لا
//    نسأل الخادم بعد كل رسالة — نُنقص العدّاد محلياً بعد كل سؤال ونُحدّثه
//    من الخادم عند فتح الشاشة وعند تجاوز الحصة فقط.

@immutable
class QuotaStatus {
  const QuotaStatus({
    required this.limit,
    required this.used,
    required this.remaining,
    required this.isGuest,
    required this.resetsDaily,
  });

  final int limit;
  final int used;
  final int remaining;
  final bool isGuest;

  /// الطالب المسجَّل حصّته يومية، والزائر تجربةٌ تراكمية لا تتجدّد.
  /// والفرق يغيّر ما تقوله الواجهة: «تتجدّد بعد منتصف الليل» أم «سجّل لتتابع».
  final bool resetsDaily;

  /// حالةٌ فارغة تُعرض قبل وصول أول قراءة — لا تُظهر رقماً مضلّلاً.
  static const unknown =
      QuotaStatus(limit: 0, used: 0, remaining: -1, isGuest: false, resetsDaily: true);

  bool get isKnown => remaining >= 0 && limit > 0;
  bool get isExhausted => isKnown && remaining <= 0;

  /// ⚠️ يقترب من النفاد — عتبةٌ **نسبية لا رقمٌ ثابت**: حدُّ الزائر خمسة
  ///    وحدُّ الطالب خمسون، فـ«باقٍ ٥» تحذيرٌ للثاني وحالةٌ طبيعية للأول.
  bool get isLow => isKnown && !isExhausted && remaining <= (limit * 0.2).ceil();

  QuotaStatus consumeOne() => remaining <= 0
      ? this
      : QuotaStatus(
          limit: limit,
          used: used + 1,
          remaining: remaining - 1,
          isGuest: isGuest,
          resetsDaily: resetsDaily,
        );

  factory QuotaStatus.fromJson(Map<String, dynamic> j) {
    int asInt(Object? v, [int fallback = 0]) =>
        v is int ? v : (v is num ? v.toInt() : fallback);
    return QuotaStatus(
      limit: asInt(j["limit"]),
      used: asInt(j["used"]),
      remaining: asInt(j["remaining"], -1),
      isGuest: j["is_guest"] == true,
      resetsDaily: j["resets_daily"] != false,
    );
  }
}

class QuotaRepository extends ChangeNotifier {
  QuotaRepository._();
  static final QuotaRepository I = QuotaRepository._();

  /// للاختبارات: حقن عميل وهمي بدل الشبكة.
  @visibleForTesting
  static QuotaRepository forTesting(http.Client client) =>
      QuotaRepository._().._client = client;

  http.Client? _client;
  http.Client get _http => _client ??= http.Client();

  QuotaStatus status = QuotaStatus.unknown;

  DateTime _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);

  /// 🛟 **لا يرمي أبداً ولا يعطّل شيئاً.** عدّادٌ لا يصل ليس عطلاً يستحق
  ///    رسالة خطأ — نُبقي آخر قيمة معروفة ونصمت. الحدُّ يفرضه الخادم على
  ///    أي حال، وهذا عرضٌ لا حراسة.
  Future<void> refresh({bool force = false}) async {
    // ⏱️ لا نسأل أكثر من مرة كل نصف دقيقة: الشاشة تُفتح وتُغلق كثيراً،
    //    ورقمٌ عمره ثوانٍ يكفي تماماً.
    if (!force && DateTime.now().difference(_lastFetch).inSeconds < 30) return;

    final token = await UserSession.I.idToken();
    if (token == null || token.isEmpty) return;

    try {
      final res = await _http.get(
        Uri.parse("${AppConfig.baseUrl}/me/quota"),
        headers: ApiClient.authHeaders(token),
      ).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      status = QuotaStatus.fromJson(data);
      _lastFetch = DateTime.now();
      notifyListeners();
    } catch (_) {
      // صامتٌ عمداً — راجع الشرح أعلاه.
    }
  }

  /// يُنقص العدّاد محلياً بعد سؤالٍ نجح، بلا رحلة شبكة.
  ///
  /// ⚠️ **تقديرٌ لا حقيقة**: الحقيقة عند الخادم، وهذا يجعل الرقم يتحرّك
  ///    فور إرسال السؤال بدل أن يتجمّد حتى القراءة التالية. والفارق يُصحَّح
  ///    عند أول `refresh`.
  void consumeOne() {
    if (!status.isKnown) return;
    status = status.consumeOne();
    notifyListeners();
  }

  /// يُصفّر المعروض عند تبديل الحساب — حصّةُ حسابٍ لا تُعرض لآخر.
  void clear() {
    status = QuotaStatus.unknown;
    _lastFetch = DateTime.fromMillisecondsSinceEpoch(0);
    notifyListeners();
  }
}
