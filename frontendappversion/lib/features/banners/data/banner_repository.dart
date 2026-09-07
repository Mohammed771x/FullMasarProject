import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/session/user_session.dart';
import '../../quiz/data/quiz_analytics.dart';
import '../../quiz/data/quiz_storage.dart';
import 'banner_model.dart';

// ==========================================
// 🎏 مستودع البانرات
// ==========================================
// **الكاش أولاً دائماً**: الشاشة الرئيسية لا تنتظر الشبكة أبداً — تُرسم من
// آخر نسخة محفوظة، والخادم يصحّح بعدها بصمت.
//
// 📉 **التوقيع** (`النسخة:اليوم`) هو ما يجعل الطلب رخيصاً: يعود الرد فارغاً
//    ما لم يحرّر الأدمن شيئاً أو يتبدّل اليوم.
class BannerRepository {
  BannerRepository._();
  static final BannerRepository I = BannerRepository._();

  static const _kCache = 'banners_cache_v1';
  static const _kSignature = 'banners_signature_v1';

  final Map<String, List<AppBanner>> _sections = {};
  bool _loaded = false;

  /// تُستدعى مرة عند الإقلاع. لا ترمي أبداً — البانر تزيينٌ لا شرطُ تشغيل.
  Future<void> load() async {
    if (!_loaded) await _readCache();
    _loaded = true;
    await _refresh();
  }

  /// يُنادى بعد تغيير الصف أو المسار — الاستهداف يتبعهما.
  Future<void> refreshForScope() => _refresh();

  /// بانرات قسم واحد: الخادمية أولاً ثم الشخصية المبنيّة محلياً.
  ///
  /// 🎯 التصفية بالفئة تقع هنا **أيضاً** لا في الخادم وحده: الرد مُكيَّش،
  ///    فطالبٌ صحّح صفّه بعد آخر جلبٍ كان سيرى بانرات صفٍّ تركه حتى
  ///    الإقلاع التالي.
  List<AppBanner> forSection(String section) {
    final grade = UserSession.I.grade;
    final track = UserSession.I.track;
    final remote = (_sections[section] ?? const <AppBanner>[])
        .where((b) => b.targets(grade, track))
        .toList();
    final personal = _personal(section);
    return [...remote, ...personal];
  }

  // ══════════════ الشبكة ══════════════

  Future<void> _refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final signature = prefs.getString(_kSignature) ?? '';
      // 🎯 الصف والمسار في الطلب: الخادم يصفّي فلا تُنقل بانراتٌ لن تُعرض،
      //    وبصمتُه تشمل الصفّ فلا يبقى طالبٌ غيّر صفّه على بصمةٍ قديمة.
      final res = await http
          .get(
            Uri.parse('${ApiEndpoints.banners(UserSession.I.grade, UserSession.I.track)}'
                '&signature=${Uri.encodeComponent(signature)}'),
            headers: ApiClient.jsonHeaders,
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return;

      final data = (jsonDecode(res.body) as Map).cast<String, dynamic>();
      if (data['changed'] != true) return; // لا جديد — الكاش صالح

      final raw = (data['sections'] as Map?)?.cast<String, dynamic>() ?? {};
      _sections
        ..clear()
        ..addAll(raw.map((key, value) => MapEntry(
              key,
              ((value as List?) ?? const [])
                  .map((e) => AppBanner.fromJson((e as Map).cast<String, dynamic>()))
                  .toList(),
            )));

      await prefs.setString(_kCache, jsonEncode(raw));
      await prefs.setString(_kSignature, (data['signature'] ?? '').toString());
    } catch (e) {
      // 🛡️ بلا إنترنت أو خادم نائم ⇒ يبقى الكاش. لا رسالة خطأ للطالب:
      //    غياب بانرٍ إعلانيّ ليس عطلاً يستحق مقاطعته.
      debugPrint('🎏 تعذّر تحديث البانرات: $e');
    }
  }

  Future<void> _readCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kCache);
      if (raw == null || raw.isEmpty) return;
      final map = (jsonDecode(raw) as Map).cast<String, dynamic>();
      _sections
        ..clear()
        ..addAll(map.map((key, value) => MapEntry(
              key,
              ((value as List?) ?? const [])
                  .map((e) => AppBanner.fromJson((e as Map).cast<String, dynamic>()))
                  .toList(),
            )));
    } catch (_) {
      // كاش تالف من نسخة أقدم ⇒ نتجاهله ونعيد الجلب.
    }
  }

  @visibleForTesting
  void seed(Map<String, List<AppBanner>> sections) {
    _sections
      ..clear()
      ..addAll(sections);
    _loaded = true;
  }

  // ══════════════ 🎯 البانر الشخصي ══════════════
  // يُبنى هنا لا على الخادم: نتائج «اختبر نفسك» تعيش في Hive على الجهاز
  // ولا تُرفع. رفعُها ليصنع الخادم بانراً واحداً مقايضةٌ خاسرة.

  List<AppBanner> _personal(String section) {
    if (section != BannerSection.home && section != BannerSection.analysis) {
      return const [];
    }
    // 🎓 نتائج الصف الحالي — بانرٌ يقول «راجع درس كذا» عن صفٍّ تركه الطالب
    //    نصيحةٌ خاطئة تُضيّع وقتاً، لا نصيحةٌ متأخرة.
    final results = QuizStorage.all(UserSession.I.uid, scope: UserSession.I.scope);
    // ⚠️ عتبة الاختبارين مقصودة: اختبارٌ واحد ضعيف قد يكون يوماً سيئاً،
    //    والحكم عليه بـ«أنت ضعيف» ظلمٌ يُحبط لا يحفّز.
    if (results.length < 2) return const [];

    final weak = QuizAnalytics.weakestSubject(results);
    if (weak != null && weak.isWeak) {
      final lessons = QuizAnalytics.reviewLessons(results, weak.subject, limit: 1);
      return [
        AppBanner(
          id: 'personal:weak:${weak.subject}',
          title: '${weak.subject} تحتاج تركيزاً 💪',
          subtitle: lessons.isEmpty
              ? 'نسبتك ${weak.currentPercent}% — راجعها الآن'
              : 'ابدأ بدرس «${lessons.first}»',
          icon: 'target',
          colors: const ['#F59E0B', '#B45309'],
          action: 'analysis',
          actionValue: weak.subject,
          order: 900,
        ),
      ];
    }

    final best = QuizAnalytics.bestSubject(results);
    if (best != null && best.isStrong) {
      return [
        AppBanner(
          id: 'personal:strong:${best.subject}',
          title: 'أجدتَ في ${best.subject} 🎉',
          subtitle: '${best.currentPercent}% — واصل، وجرّب مادة أخرى',
          icon: 'trophy',
          colors: const ['#10B981', '#065F46'],
          action: 'quiz',
          actionValue: '',
          order: 900,
        ),
      ];
    }
    return const [];
  }
}
