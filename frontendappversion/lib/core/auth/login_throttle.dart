import 'package:shared_preferences/shared_preferences.dart';

// ==========================================
// ⏳ مهلةُ التهدئة بعد المحاولات الفاشلة
// ==========================================
// 🔐 **طلبُ المالك (٢٠٢٦-٠٩-٢٣):** «سوِّ حماياتٍ جداً… rate limit في
//    تسجيل الدخول».
//
// ⚖️ **وما هي وما ليست:** الحدُّ الحقيقيُّ لمن ينادي Firebase مباشرةً هو
//    `too-many-requests` **الخادميّ** ومعه App Check — فهذا لا يوقف مهاجماً
//    يتجاوز تطبيقنا. وظيفتُه ما لا يفعله ذاك:
//      ① جوّالٌ مسروقٌ أو مُعار: من يجرّب كلماتِ صاحبه **من الشاشة نفسها**
//         يُبطَّأ تصاعدياً بعد خمس محاولات.
//      ② لا يُحرق حسابُ الطالب عند Firebase: قفلُه الخادميُّ يصيب **الحسابَ
//         كلَّه** على كل الأجهزة، والتهدئةُ هنا تسبقه فتوقف السيلَ على هذا
//         الجهاز قبل أن يُقفَل صاحبُه الحقيقيّ خارج حسابه.
//      ③ «نسيت كلمة المرور» لا تصير مِدفعَ رسائلَ على بريدِ غيرك.
//
// 💾 **على القرص لا في الذاكرة:** إغلاقُ التطبيق وفتحُه كان سيصفّرها —
//    وهو أوّلُ ما يجرّبه من يريد الالتفاف.
//
// 🕐 **والساعةُ محقونة** (`now`) كي يُختبر التصاعدُ بلا انتظارٍ حقيقي.
class LoginThrottle {
  LoginThrottle._(this._bucket, {DateTime Function()? now})
      : _now = now ?? DateTime.now;

  /// محاولاتُ الدخول بكلمة المرور.
  static final LoginThrottle signIn = LoginThrottle._('signin');

  /// طلباتُ رابط الاستعادة — [resetGap] بين كل طلبين.
  static final LoginThrottle reset = LoginThrottle._('reset');

  /// للاختبارات وحدها: عدّادٌ بساعةٍ مزيّفة ومفتاحٍ مستقل.
  factory LoginThrottle.forTest(String bucket, DateTime Function() now) =>
      LoginThrottle._(bucket, now: now);

  final String _bucket;
  final DateTime Function() _now;

  /// المحاولاتُ المسموحةُ قبل أوّل تهدئة.
  static const int freeAttempts = 5;

  /// أوّلُ مهلة — ثم تتضاعف مع كل فشلٍ بعدها حتى [maxLock].
  static const Duration firstLock = Duration(seconds: 30);
  static const Duration maxLock = Duration(minutes: 15);

  /// الفاصلُ بين طلبَي استعادة.
  static const Duration resetGap = Duration(seconds: 60);

  String get _kFails => 'throttle_${_bucket}_fails';
  String get _kUntil => 'throttle_${_bucket}_until';

  /// كم بقي من المهلة؟ — `Duration.zero` إن كان الطريقُ مفتوحاً.
  Future<Duration> remaining() async {
    final p = await SharedPreferences.getInstance();
    final until = p.getInt(_kUntil) ?? 0;
    final left = until - _now().millisecondsSinceEpoch;
    return left > 0 ? Duration(milliseconds: left) : Duration.zero;
  }

  /// فشلٌ جديد — يعيد مدّةَ القفل الذي بدأ الآن (أو صفراً).
  Future<Duration> recordFailure() async {
    final p = await SharedPreferences.getInstance();
    final fails = (p.getInt(_kFails) ?? 0) + 1;
    await p.setInt(_kFails, fails);
    if (fails < freeAttempts) return Duration.zero;
    // 5 ⇒ 30ث · 6 ⇒ 60ث · 7 ⇒ 2د · … حتى 15د
    final steps = fails - freeAttempts;
    var lock = firstLock * (1 << (steps > 10 ? 10 : steps));
    if (lock > maxLock) lock = maxLock;
    await p.setInt(_kUntil, _now().add(lock).millisecondsSinceEpoch);
    return lock;
  }

  /// يقفل مدّةً ثابتة (الاستعادة: طلبٌ واحد كل [resetGap]).
  Future<void> lockFor(Duration d) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kUntil, _now().add(d).millisecondsSinceEpoch);
  }

  /// نجاح ⇒ العدّادُ يُمحى كلُّه.
  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kFails);
    await p.remove(_kUntil);
  }

  /// «حاول بعد ٤٥ ثانية» — أرقامٌ عربية كبقية الواجهة.
  static String waitMessage(Duration d) {
    final secs = d.inSeconds + (d.inMilliseconds % 1000 > 0 ? 1 : 0);
    final String span;
    if (secs < 60) {
      span = '${_ar(secs)} ثانية';
    } else {
      final mins = (secs / 60).ceil();
      span = mins == 1 ? 'دقيقة' : '${_ar(mins)} دقائق';
    }
    return 'محاولاتٌ كثيرة. حاول مجدداً بعد $span.';
  }

  static String _ar(int n) {
    const d = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    return n.toString().split('').map((c) => d[int.parse(c)]).join();
  }
}
