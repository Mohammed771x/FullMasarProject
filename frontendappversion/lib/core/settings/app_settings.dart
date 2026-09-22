import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../session/user_session.dart';

// ==========================================
// ⚙️ core/settings/app_settings.dart — تفضيلات الطالب
// ==========================================
// ⭐ **الفرق عن `DemoState`**: هذه تُحفظ فعلاً وتنجو من إغلاق التطبيق.
//    كانت الإعدادات تعيش في الذاكرة فتعود لافتراضاتها عند كل إقلاع — يضبط
//    الطالب حجم الخط لضعف بصره، ثم يجده صغيراً في اليوم التالي.
//
// 🔔 `ChangeNotifier` لا `ValueNotifier` لكل حقل: الشاشات تستمع مرة واحدة
//    وتلتقط أي تغيير، فلا يُنسى ربط حقلٍ جديد.
class AppSettings extends ChangeNotifier {
  AppSettings._();
  static final AppSettings I = AppSettings._();

  static const _kFontSize = 'settings_answer_font';
  static const _kNotifScholarships = 'settings_notif_scholarships';
  static const _kNotifGeneral = 'settings_notif_general';
  static const _kThinking = 'settings_thinking';

  /// حدود حجم خط الإجابة. الأدنى ١٤ لأن ما دونه لا يُقرأ على شاشة صغيرة،
  /// والأعلى ٢٤ ليخدم ضعيف البصر فعلاً لا شكلاً.
  static const double minFont = 14;
  static const double maxFont = 24;
  static const double defaultFont = 16;

  double _answerFontSize = defaultFont;
  bool _notifScholarships = true;
  bool _notifGeneral = true;

  /// 🧠 **«تفكير» — يختاره الطالبُ عند الإرسال** (قرار المالك 2026-09-22:
  /// «هو الطالب يقدر يختار thinking ولا مش thinking؟ … كما ChatGPT»).
  ///
  /// 📏 والفرقُ مقيسٌ على ٣٣ مسألةَ فيزياءٍ وكيمياءَ محسوبةٍ باليد ×٣:
  ///   · مُطفأً  ⇐ **٩٦٪** · ٠٫٨ ثانية
  ///   · مُشغّلاً ⇐ **١٠٠٪** · ١٫٥ ثانية
  /// وفي الشرح الطويل يقفز إلى ٢٠ ثانية — **فالافتراضُ إطفاء**، لأن
  /// أكثرَ ما يُسأل شرحٌ لا حساب، والطالبُ يشعله للمسائل بضغطةٍ واحدة.
  bool _thinking = false;

  double get answerFontSize => _answerFontSize;
  bool get notifScholarships => _notifScholarships;
  bool get notifGeneral => _notifGeneral;
  bool get thinking => _thinking;

  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _answerFontSize =
        (_prefs!.getDouble(_kFontSize) ?? defaultFont).clamp(minFont, maxFont);
    _notifScholarships = _prefs!.getBool(_kNotifScholarships) ?? true;
    _notifGeneral = _prefs!.getBool(_kNotifGeneral) ?? true;
    _thinking = _prefs!.getBool(_kThinking) ?? false;
    notifyListeners();
  }

  Future<void> setAnswerFontSize(double value) async {
    _answerFontSize = value.clamp(minFont, maxFont);
    notifyListeners();
    await (_prefs ??= await SharedPreferences.getInstance())
        .setDouble(_kFontSize, _answerFontSize);
  }

  /// 🧠 يُبدَّل من شريط الكتابة — ويبقى بعد إغلاق التطبيق، فمن يذاكر
  /// الرياضيات لا يعيد إشعالَه كل مرة. ولا يُرفع للخادم: تفضيلُ **جهاز**
  /// لا تفضيلُ حساب، شأنُه شأنُ حجم الخط.
  Future<void> setThinking(bool value) async {
    _thinking = value;
    notifyListeners();
    await (_prefs ??= await SharedPreferences.getInstance())
        .setBool(_kThinking, value);
  }

  Future<void> setNotifScholarships(bool value) async {
    _notifScholarships = value;
    notifyListeners();
    await (_prefs ??= await SharedPreferences.getInstance())
        .setBool(_kNotifScholarships, value);
    unawaited(_syncNotifications());
  }

  Future<void> setNotifGeneral(bool value) async {
    _notifGeneral = value;
    notifyListeners();
    await (_prefs ??= await SharedPreferences.getInstance())
        .setBool(_kNotifGeneral, value);
    unawaited(_syncNotifications());
  }

  // ══════════════ 🔔 المفتاحان يصلان الخادم ══════════════
  // ⭐ **بدون هذا المزامن كان المفتاحان زينةً محضة:** يُطفئهما الطالب في
  //    جواله، ويبقى الخادم يعدّه ضمن جمهور كل إشعار ويدفع إلى جهازه.
  //    والأسوأ أن لوحة التحكم كانت تعرض للمالك عدد مستلمين أكبر من
  //    الحقيقة — رقمٌ لا يكذب عمداً، لكنه يقيس ما لا يقيسه أحد.
  //
  // 🔑 الاسمان مطابقان لما يقرؤه الخادم (`analytics._notif_on`): تغييرُ
  //    أحدهما دون الآخر يعطّل الاحترام **صامتاً** — يظل المفتاح يعمل في
  //    الشاشة ولا يعمل في الواقع.
  //
  // 🛟 ويفشل صامتاً: التفضيل محفوظ محلياً ويُعاد رفعه عند التغيير التالي،
  //    ولا يجوز أن يوقف شبكةٌ متقطّعة تبديلَ مفتاحٍ في الإعدادات.
  Future<void> _syncNotifications() async {
    try {
      await UserSession.I.patchSettings({
        'notif_general': _notifGeneral,
        'notif_scholarships': _notifScholarships,
        // مفتاحٌ جامع للقراءة السريعة في التحليلات — «أطفأ كل شيء؟»
        'notifications': _notifGeneral || _notifScholarships,
      });
    } catch (_) {
      // محفوظ محلياً — يلحق في التبديل التالي أو عند الدخول.
    }
  }

  /// يرفع الحالة الحالية كما هي — يُنادى بعد أول دخولٍ ناجح كي يبدأ
  /// الحساب الجديد بتفضيلات هذا الجهاز لا بافتراضات الخادم.
  Future<void> pushToCloud() => _syncNotifications();

  /// يعيد كل شيء لافتراضه — يُستدعى عند حذف الحساب لا عند الخروج:
  /// حجم الخط تفضيلُ **عينٍ** لا تفضيلُ حساب، فمن يخرج ويعود يجده كما تركه.
  Future<void> resetAll() async {
    _answerFontSize = defaultFont;
    _notifScholarships = true;
    _notifGeneral = true;
    _thinking = false;
    notifyListeners();
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.remove(_kFontSize);
    await p.remove(_kNotifScholarships);
    await p.remove(_kNotifGeneral);
    await p.remove(_kThinking);
  }
}
