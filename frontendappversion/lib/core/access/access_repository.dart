import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../session/user_session.dart';

// ==========================================
// 🔐 core/access/access_repository.dart — أي الأقسام تُعرض لهذا الطالب
// ==========================================
// المالك يتحكم من لوحة التحكم بظهور الأقسام **بلا إصدار نسخة جديدة**:
// «أخفِ المنح عن الأول والثاني» · «الخدمات قريباً» · «عطّل قسماً مؤقتاً».
//
// 🔴 **وهذا إخفاءٌ لا حماية.** الحماية الحقيقية في الخادم: `_section_gate`
//    يرفض `/ask` و`/quiz/generate` و`/teacher/ask` و`/scholarship/ask`
//    بـ403 ويقرأ الصفَّ من `users/{uid}` لا من الطلب. ما هنا يمنع الطالبَ
//    من رؤية زرٍّ يفشل — وهو لطفٌ بالواجهة لا حاجزُ أمان.
//
// 🛟 **ويفشل مفتوحاً في كل طريق**: بلا شبكة، أو بردٍّ مشوّه، أو بقسمٍ لا
//    يعرفه الخادم ⇒ **مفتوح**. تعطيلُ الدراسة لعطلٍ في نظام الإخفاء
//    مقايضةٌ خاسرة بكل مقياس.
//
// ⚡ **الكاش أولاً كالبانرات**: الرئيسية لا تنتظر الشبكة. تُرسم من آخر
//    نسخة محفوظة، والخادم يصحّح بعدها بصمت — والتغيير يظهر في الإقلاع
//    التالي كما تقول اللوحة للأدمن حرفياً.

/// أوضاع القسم — نفس مفاتيح الخادم ([core/access.py]).
class SectionMode {
  static const on = 'on';
  static const soon = 'soon';
  static const off = 'off';
}

/// مفاتيح الأقسام — نفس مفاتيح الخادم واللوحة.
class AppSection {
  static const education = 'education';
  static const quiz = 'quiz';
  static const analysis = 'analysis';
  static const scholarships = 'scholarships';
  static const teacher = 'teacher';
  static const services = 'services';

  static const all = [education, quiz, analysis, scholarships, teacher, services];
}

@immutable
class SectionState {
  const SectionState({
    required this.mode,
    required this.message,
  });

  final String mode;
  final String message;

  /// مفتوحٌ افتراضاً — القيمة التي تُعاد عند أي شكٍّ أو عطل.
  static const open = SectionState(mode: SectionMode.on, message: '');

  /// يُعرض في الواجهة؟ (`soon` يُعرض ولا يُفتح)
  bool get visible => mode != SectionMode.off;

  /// يُفتح فعلاً؟
  bool get usable => mode == SectionMode.on;

  factory SectionState.fromJson(Map<String, dynamic> json) {
    final mode = (json['mode'] ?? SectionMode.on).toString();
    return SectionState(
      // ⚠️ وضعٌ لا نعرفه (خادمٌ أحدث من التطبيق) يُقرأ **مفتوحاً**: النسخة
      //    القديمة لا يجوز أن تُخفي قسماً لأنها لم تفهم كلمةً جديدة.
      mode: const [SectionMode.on, SectionMode.soon, SectionMode.off].contains(mode)
          ? mode
          : SectionMode.on,
      message: (json['message'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {'mode': mode, 'message': message};
}

class AccessRepository extends ChangeNotifier {
  AccessRepository._();
  static final AccessRepository I = AccessRepository._();

  static const _kCache = 'access_cache_v1';
  static const _kScope = 'access_scope_v1';

  final Map<String, SectionState> _sections = {};
  bool _loaded = false;

  @visibleForTesting
  static void overrideClient(http.Client? client) => I._client = client;
  http.Client? _client;
  http.Client get _http => _client ??= http.Client();

  /// حالة قسم — **مفتوحٌ** ما لم يُقل الخادم غير ذلك صراحةً.
  SectionState of(String section) => _sections[section] ?? SectionState.open;

  bool visible(String section) => of(section).visible;
  bool usable(String section) => of(section).usable;

  /// تُستدعى مرة عند الإقلاع. لا ترمي أبداً.
  Future<void> load() async {
    if (!_loaded) await _readCache();
    _loaded = true;
    await refresh();
  }

  /// يُنادى أيضاً بعد تغيير الصف أو المسار **أو الدور** — القواعد تختلف
  /// بالثلاثة: اللوحة قد تُخفي «المنح» عن المعلمين كما تُخفيها عن الأول.
  ///
  /// ⚠️ **وبدونه يبقى طالبٌ صحّح صفّه يرى أقسام صفٍّ تركه** حتى الإقلاع
  ///    التالي، فيظن التطبيق معطوباً.
  Future<void> refresh() async {
    final grade = UserSession.I.grade;
    final track = UserSession.I.track;
    final role = UserSession.I.role;
    try {
      final res = await _http
          .get(Uri.parse(ApiEndpoints.appAccess(grade, track, role)),
              headers: ApiClient.contentHeaders)
          .timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return;

      final data = (jsonDecode(utf8.decode(res.bodyBytes)) as Map).cast<String, dynamic>();
      final raw = (data['sections'] as Map?)?.cast<String, dynamic>();
      // ردٌّ بلا `sections` (خطأ أو وسيطٌ يعترض) ⇒ نُبقي الكاش ولا نُخفي شيئاً.
      if (raw == null || raw.isEmpty) return;

      _sections
        ..clear()
        ..addAll(raw.map((key, value) => MapEntry(
              key,
              SectionState.fromJson((value as Map).cast<String, dynamic>()),
            )));

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCache, jsonEncode(raw));
      await prefs.setString(_kScope, '$grade|$track|$role');
      notifyListeners();
    } catch (e) {
      // 🛟 بلا إنترنت ⇒ يبقى الكاش (أو المفتوح إن لم يكن). لا رسالة خطأ:
      //    الطالب لم يطلب هذا ولا يستطيع إصلاحه.
      debugPrint('🔐 تعذّر تحديث صلاحيات الأقسام: $e');
    }
  }

  Future<void> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ⚠️ كاشُ صفٍّ آخر يُهمل: طالبٌ غيّر صفّه لا يُحكم عليه بقواعد صفّه
      //    القديم ولو للحظة — والإخفاء الخاطئ أسوأ من الإظهار الخاطئ هنا،
      //    لأن الخادم يحرس الفتح والواجهة لا تحرس شيئاً.
      final scope = prefs.getString(_kScope) ?? '';
      // 🎭 والدور جزءٌ من المفتاح: كاشُ معلّمٍ لا يحكم على طالبٍ ولا العكس.
      if (scope !=
          '${UserSession.I.grade}|${UserSession.I.track}|${UserSession.I.role}') {
        return;
      }

      final raw = prefs.getString(_kCache);
      if (raw == null || raw.isEmpty) return;
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _sections
        ..clear()
        ..addAll(map.map((key, value) => MapEntry(
              key,
              SectionState.fromJson((value as Map).cast<String, dynamic>()),
            )));
    } catch (_) {
      // كاش تالف من نسخة أقدم ⇒ نتجاهله ونعيد الجلب. ولا إخفاء بلا يقين.
    }
  }

  @visibleForTesting
  void seed(Map<String, SectionState> sections) {
    _sections
      ..clear()
      ..addAll(sections);
    _loaded = true;
    notifyListeners();
  }

  @visibleForTesting
  void reset() {
    _sections.clear();
    _loaded = false;
  }
}
