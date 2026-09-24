import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/banners/data/banner_repository.dart';
import '../../features/chat/data/edu_session.dart';
import '../access/access_repository.dart';
import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../notifications/notifications_repository.dart';
import '../quota/quota_repository.dart';
import '../../features/scholarships/data/scholarship_favorites.dart';
import '../notifications/push_service.dart';
import '../settings/app_settings.dart';
import '../auth/auth_repository.dart';
import '../auth/auth_validators.dart';
import '../auth/login_throttle.dart';
import '../auth/password_strength.dart';
import '../auth/user_repository.dart';
import 'grade_scope.dart';
import '../media/avatar_service.dart';
import '../sync/sync_service.dart';
import '../utils/safe_cut.dart';

// ==========================================
// 👤 جلسة المستخدم — المصدر الوحيد لبيانات الحساب
// ==========================================
// التوثيق الحقيقي في `AuthRepository` (Firebase Auth)، ومستند الحساب في
// `UserRepository` (Firestore). هذا الملف يجمعهما ويقدّمهما لبقية التطبيق
// بواجهة واحدة لم تتغيّر — فما كان يقرأ `UserSession.I.grade` لا يزال يعمل.
//
// **الكاش المحلي (SharedPreferences) مقصود**: الطالب اليمني على إنترنت متقطّع،
// فالتطبيق يفتح ويعرض صفه ومادته فوراً بلا انتظار الشبكة، والسحابة تصحّح لاحقاً.
//
// الحالات الثلاث ([27§7]):
//   • مسجَّل ومتحقَّق → كل شيء مفتوح
//   • مسجَّل ببريد غير مفعّل → `needsVerification` ⇒ شاشة التحقق
//   • زائر → 5 أسئلة، ثم `upgradeGuest*` تنقله لحساب دائم بلا فقدان شيء
class UserSession extends ChangeNotifier {
  UserSession._();
  static final UserSession I = UserSession._();

  /// تُحقن في الاختبارات فقط.
  @visibleForTesting
  static void overrideRepositories({AuthRepository? auth, UserRepository? users}) {
    // ⚠️ لا `?? I._users`: قراءةُ الحقل تُنشئ المستودعَ الحقيقيّ فتنادي
    //    Firestore — وهو غيرُ مهيّأٍ في الاختبار، فيسقط حقنُ أحدهما وحده.
    if (auth != null) I._auth = auth;
    if (users != null) I._users = users;
  }

  AuthRepository? _authRepo;
  UserRepository? _usersRepo;
  AuthRepository get _auth => _authRepo ??= AuthRepository();
  UserRepository get _users => _usersRepo ??= UserRepository();
  set _auth(AuthRepository v) => _authRepo = v;
  set _users(UserRepository v) => _usersRepo = v;

  static const _kIsGuest = 'session_is_guest';
  static const _kName = 'session_name';
  static const _kEmail = 'session_email';
  static const _kGrade = 'session_grade';
  static const _kTrack = 'session_track';
  static const _kPhoto = 'session_photo';
  // الصف/المسار المختاران أثناء التسجيل — يُكتبان في المستند بعد تفعيل البريد.
  static const _kPendingGrade = 'session_pending_grade';
  static const _kPendingTrack = 'session_pending_track';
  static const _kRole = 'session_role';
  // الدور المختار أثناء التسجيل — يُكتب في المستند بعد تفعيل البريد.
  static const _kPendingRole = 'session_pending_role';

  bool isGuest = false;
  String name = 'طالب مسار';
  String email = '';
  int grade = 3; // 1 | 2 | 3
  String track = 'علمي'; // عام | علمي | أدبي

  /// 🎭 دور الحساب: `student` أو `teacher` — **يحكم أيّ تطبيقٍ يرى صاحبه**.
  ///
  /// المعلّم لا يرى الإحصائيات ولا الاختبارات ولا المنح، والطالب لا يرى
  /// أدوات المعلم. وهو **قابل للتبديل من الإعدادات** بلا فقدان شيء: بيانات
  /// كلا الوجهين تبقى في مكانها، فمن بدّل وعاد وجد سجلّه كما تركه.
  String role = AppRole.student;

  /// 👤 رابط صورة الحساب في Storage — فارغ ⇒ يُعرض أول الاسم.
  String photoUrl = '';

  SharedPreferences? _prefs;

  // ===== الحالة =====

  /// دخل التطبيق فعلاً؟ (الزائر داخل، وغير المتحقَّق ليس داخلاً)
  bool get loggedIn => _auth.isSignedIn && !needsVerification;

  /// حساب ببريد لم يُفعَّل بعد ⇒ تُعرض شاشة التحقق.
  bool get needsVerification => _auth.needsEmailVerification;

  String get uid => _auth.currentUser?.uid ?? '';

  /// 🎓 نطاق الصف الحالي — عليه تُفلتَر المحادثات والنتائج والمحفوظات.
  GradeScope get scope => GradeScope(grade, track);

  /// معلّم؟
  ///
  /// ⚠️ **والزائر يجوز أن يكون معلّماً.** من يضغط «جرّب كزائر» لا يمرّ بشاشة
  ///    اختيار الدور إطلاقاً، فحرمانُه منه كان يعني أن المعلّم يجرّب التطبيق
  ///    فلا يرى منه شيئاً يخصّه — ثم يحكم عليه بأنه «للطلاب». والتجربة هي
  ///    ما يقنعه بالتسجيل، فيجب أن تكون تجربةَ قسمه هو.
  ///    حصّته تبقى خمسة أسئلة كما هي، فلا يُفتح بابٌ للالتفاف.
  bool get isTeacher => role == AppRole.teacher;

  /// توكن الوصول للباك اند (ترويسة Authorization).
  Future<String?> idToken({bool refresh = false}) => _auth.idToken(refresh: refresh);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    isGuest = _auth.isGuest || (_prefs!.getBool(_kIsGuest) ?? false);
    name = _prefs!.getString(_kName) ?? _auth.currentUser?.displayName ?? 'طالب مسار';
    email = _prefs!.getString(_kEmail) ?? _auth.currentUser?.email ?? '';
    grade = _prefs!.getInt(_kGrade) ?? 3;
    track = _prefs!.getString(_kTrack) ?? 'علمي';
    // ⚠️ الدور من الكاش لا من الشبكة: التوجيه إلى واجهة المعلم يحدث في
    //    أول إطار، فانتظارُ Firestore كان يعني ومضةَ واجهةِ الطالبِ لمعلّمٍ
    //    في كل إقلاع — والسحابة تصحّح بعد لحظة إن اختلفت.
    role = AppRole.sanitize(_prefs!.getString(_kRole));
    photoUrl = _prefs!.getString(_kPhoto) ?? '';

    // تصحيح من السحابة إن توفّرت (بلا تعطيل الإقلاع).
    if (_auth.isSignedIn && !isGuest) {
      unawaited(_hydrateFromCloud());
    }
  }

  Future<void> _hydrateFromCloud() async {
    try {
      final p = await _users.fetch(uid);
      if (p == null) return;
      name = p.name.isNotEmpty ? p.name : name;
      email = p.email.isNotEmpty ? p.email : email;
      grade = p.grade;
      track = p.track;
      role = p.role;
      photoUrl = p.photoUrl;
      await _persist();
      notifyListeners();
    } catch (_) {
      // بلا إنترنت أو صلاحية ⇒ نبقى على الكاش المحلي.
    }
  }

  Future<void> _persist() async {
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setBool(_kIsGuest, isGuest);
    await p.setString(_kName, name);
    await p.setString(_kEmail, email);
    await p.setInt(_kGrade, grade);
    await p.setString(_kTrack, track);
    await p.setString(_kRole, role);
    await p.setString(_kPhoto, photoUrl);
  }

  // ===== التسميات =====
  String get gradeLabel => switch (grade) {
        1 => 'الأول الثانوي',
        2 => 'الثاني الثانوي',
        _ => 'الثالث الثانوي',
      };

  String get gradeShort => switch (grade) { 1 => 'الأول', 2 => 'الثاني', _ => 'الثالث' };

  String get greeting {
    final h = DateTime.now().hour;
    if (h >= 5 && h < 12) return 'صباح الخير';
    if (h >= 12 && h < 17) return 'مساء النور';
    return 'مساء الخير';
  }

  /// 👤 يثبّت رابط الصورة محلياً وفي المستند السحابي.
  ///
  /// ⚠️ الكتابة المحلية **أولاً** ثم السحابية: الطالب على شبكة يمنية متقطّعة
  ///    يرى صورته فوراً، وفشل المزامنة لا يبتلع ما رفعه بالفعل.
  Future<void> setPhoto(String url) async {
    photoUrl = url;
    await _persist();
    notifyListeners();
    if (!isGuest && uid.isNotEmpty) {
      try {
        await _users.patch(uid, {"photo_url": url});
      } catch (_) {
        // بلا إنترنت ⇒ الرابط محفوظ محلياً ويُصحَّح عند أول مزامنة.
      }
    }
  }

  /// أول حرف من الاسم — يُستخدم في صورة الحساب الافتراضية.
  String get initial {
    final t = name.trim();
    return t.isEmpty ? 'م' : firstGlyph(t); // ✂️ الرمزُ كاملاً لا نصفُه
  }

  // ===== إنشاء حساب =====

  /// يرجع رسالة خطأ عربية، أو null عند النجاح.
  /// ⚠️ النجاح هنا **لا يعني الدخول**: تُرسل رسالة تحقق ويُنتظر تفعيلها.
  Future<String?> signUp({
    required String name_,
    required String email_,
    required String password,
    required int grade_,
    String track_ = 'علمي',
    String role_ = AppRole.student,
  }) async {
    // 🛡️ **الفحصُ هنا هو الحارسُ الأخير لا الأول.** الشاشاتُ تفحص لتُظهر
    //    الخطأ تحت حقله، وهذا يفحص لأن `signUp` قد تُنادى من غيرها —
    //    وبالقواعد نفسها بالضبط ([AuthValidators] · [PasswordStrength])
    //    فلا تقبل شاشةٌ ما يرفضه اللوجيك.
    final nameError = AuthValidators.name(name_);
    if (nameError != null) return '$nameError.';
    if (!_isValidEmail(email_.trim().toLowerCase())) return 'صيغة البريد الإلكتروني غير صحيحة.';
    // 🔴 **٨ لا ٦** منذ مراجعة الأمان ٢٠٢٦-٠٩-٢٣ — انظر [PasswordStrength].
    //    وهي سياسةُ **الإنشاء** وحدها: `signIn` لا تفحص طولاً، فلا يُحبس
    //    صاحبُ حسابٍ قديمٍ خارج حسابه.
    final blocker =
        PasswordStrength.of(password, email: email_, name: name_).blocker;
    if (blocker != null) return '$blocker.';

    // زائر يسجّل ⇒ نرقّي حسابه فتنتقل محادثاته وحصته معه.
    final error = _auth.isGuest
        ? await _auth.upgradeGuestToEmail(name: name_, email: email_, password: password)
        : await _auth.registerWithEmail(name: name_, email: email_, password: password);
    if (error != null) return error;

    name = name_.trim();
    email = email_.trim().toLowerCase();
    grade = grade_;
    track = grade_ == 1 ? 'عام' : track_;
    role = AppRole.sanitize(role_);
    isGuest = false;
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setInt(_kPendingGrade, grade);
    await p.setString(_kPendingTrack, track);
    // 🎭 والدور معهما: المستند لا يُكتب إلا بعد تفعيل البريد، وبدون هذا
    //    كان المعلّم يفعّل بريده فيجد نفسه طالباً — ويختفي القسم الذي سجّل لأجله.
    await p.setString(_kPendingRole, role);
    await _persist();
    notifyListeners();
    return null;
  }

  Future<String?> signIn({required String email_, required String password}) async {
    final e = email_.trim().toLowerCase();
    if (!_isValidEmail(e)) return 'صيغة البريد الإلكتروني غير صحيحة.';
    if (password.isEmpty) return 'اكتب كلمة المرور.';

    // ⏳ **التهدئة قبل الشبكة** ([LoginThrottle]): خمسُ محاولاتٍ خاطئة
    //    ثم مهلةٌ تتضاعف — والفحصُ هنا في اللوجيك لا في الشاشة، فكلُّ
    //    بابٍ إلى الدخول يمرّ بها.
    final wait = await LoginThrottle.signIn.remaining();
    if (wait > Duration.zero) return LoginThrottle.waitMessage(wait);

    final error = await _auth.signInWithEmail(email: e, password: password);
    if (error != null) {
      // 🎯 تُعدّ **البياناتُ الخاطئة وحدها** — انقطاعُ الشبكة ليس تخميناً.
      if (error == AuthRepository.genericCredentialError) {
        final lock = await LoginThrottle.signIn.recordFailure();
        if (lock > Duration.zero) return LoginThrottle.waitMessage(lock);
      }
      return error;
    }
    await LoginThrottle.signIn.clear();

    email = e;
    isGuest = false;
    name = _auth.currentUser?.displayName ?? name;
    await _persist();
    if (!needsVerification) {
      await _ensureProfile();
      unawaited(syncAfterLogin().then((_) {}));
    }
    notifyListeners();
    return null;
  }

  /// دخول بجوجل. حين يأتي من **تبويب «حساب جديد»** يُمرَّر ما اختاره
  /// المستخدم هناك (الدور والصف والمسار) فيُكتب في مستنده عند إنشائه.
  ///
  /// ⚠️ **لماذا هذه المعاملات أصلاً؟** بدونها كان كل من يسجّل بجوجل يصير
  ///    «طالب ثالث علمي» حتماً — فالمعلّم يختار «معلّم» في الشاشة ثم يضغط
  ///    زرّ جوجل فيجد نفسه طالباً، ولا يعرف أن عليه زيارة الإعدادات.
  ///
  /// 🛡️ ولحسابٍ **قائم** لا أثر لها: `upsert` لا تكتب الدور إلا عند الإنشاء،
  ///    و`_hydrateFromCloud` بعدها تُرجع الصف والمسار من مستنده هو.
  ///
  /// ☢️ **ويرجع [GoogleAuthResult] لا `String?`:** كان الإلغاءُ يُعرف بسؤال
  ///    «هل من مستخدم؟» — والزائرُ مستخدم. فكان «Cancel» على الآيفون
  ///    يمضي بالزائر إلى هنا فيصير `isGuest = false` ويُنشأ له ملفّ، ويدخل
  ///    باسم «طالب مسار». الآن لا يُلمَس شيءٌ من الحالة إلا بعد نجاحٍ
  ///    **تحقّق منه المستودع** ([AuthRepository.signInWithGoogle]).
  Future<GoogleAuthResult> signInWithGoogle({int? grade_, String? track_, String? role_}) async {
    final result = await _auth.signInWithGoogle();
    if (!result.signedIn) return result; // فشلٌ برسالته، أو إلغاءٌ بلا أثر

    if (grade_ != null || role_ != null) {
      final p = _prefs ??= await SharedPreferences.getInstance();
      if (grade_ != null) {
        await p.setInt(_kPendingGrade, grade_);
        await p.setString(_kPendingTrack, grade_ == 1 ? 'عام' : (track_ ?? track));
      }
      if (role_ != null) await p.setString(_kPendingRole, AppRole.sanitize(role_));
    }

    final u = _auth.currentUser!;
    // 🏷️ الاسمُ من حساب جوجل، ثم من بريده — لا «زائر» يُورَث من جلسة
    //    الضيف قبل الربط، ولا «طالب مسار» الافتراضيّ.
    final display = (u.displayName ?? '').trim();
    final mailName = (u.email ?? '').split('@').first.trim();
    name = display.isNotEmpty ? display : (mailName.isNotEmpty ? mailName : name);
    email = u.email ?? '';
    isGuest = false;
    await _persist();
    await _ensureProfile(photoUrl: u.photoURL ?? '');
    await _hydrateFromCloud();
    unawaited(syncAfterLogin().then((_) {}));
    notifyListeners();
    return result;
  }

  /// دخول كزائر — 5 أسئلة تجريبية، وحسابه المجهول يحمل حصته.
  Future<String?> continueAsGuest() async {
    final error = await _auth.signInAsGuest();
    if (error != null) return error;
    name = 'زائر';
    email = '';
    isGuest = true;
    grade = 3;
    track = 'علمي';
    role = AppRole.student;
    await _persist();
    notifyListeners();
    return null;
  }

  // ===== تفعيل البريد =====

  Future<String?> resendVerificationEmail() => _auth.sendVerificationEmail();

  /// يسأل الخادم: هل فُعّل البريد؟ وعند النجاح يُنشئ مستند الحساب.
  Future<bool> checkEmailVerified() async {
    final ok = await _auth.refreshEmailVerified();
    if (ok) {
      await _ensureProfile();
      unawaited(syncAfterLogin().then((_) {}));
      notifyListeners();
    }
    return ok;
  }

  Future<String?> resetPassword(String email_) {
    final e = email_.trim().toLowerCase();
    if (!_isValidEmail(e)) return Future.value('صيغة البريد الإلكتروني غير صحيحة.');
    return _throttledReset(e);
  }

  /// 📨 رابطُ استعادةٍ واحدٌ كل دقيقة من هذا الجهاز — وإلا صار الزرُّ
  ///    مِدفعاً يُغرق بريدَ أيّ أحدٍ برسائل «مسار» ([LoginThrottle.reset]).
  Future<String?> _throttledReset(String e) async {
    final wait = await LoginThrottle.reset.remaining();
    if (wait > Duration.zero) return LoginThrottle.waitMessage(wait);
    final error = await _auth.sendPasswordReset(e);
    await LoginThrottle.reset.lockFor(LoginThrottle.resetGap);
    return error;
  }

  /// بعد كل دخول ناجح: جهاز جديد ⇒ استعادة، وإلا رفع المحلي وتنظيف السحابة.
  ///
  /// 📲 وهنا **أول طلبٍ للإذن بالإشعارات** لا عند أول إقلاع: نافذةٌ تظهر
  ///    قبل أن يفهم الطالب ما التطبيق تُرفض غالباً — ورفضُ iOS **نهائي**
  ///    لا يُسأل بعده إلا من إعدادات النظام. فنطلبه بعد أن يرى قيمته.
  /// 🔔 و**تفضيلاته ترتفع معه**: مفتاحان أطفأهما قبل التسجيل يجب أن
  ///    يعرفهما الخادم، وإلا عدّه ضمن جمهور إشعارٍ رفضه صراحةً.
  Future<int> syncAfterLogin() async {
    final count = await SyncService.I.onLogin();
    if (!isGuest) {
      unawaited(PushService.I.start());
      unawaited(AppSettings.I.pushToCloud());
      unawaited(AccessRepository.I.refresh());
    }
    return count;
  }

  /// ينشئ/يحدّث `users/{uid}` — **لا يُستدعى قبل تفعيل البريد**.
  Future<void> _ensureProfile({String photoUrl = ''}) async {
    if (uid.isEmpty || isGuest) return;
    final p = _prefs ??= await SharedPreferences.getInstance();
    final g = p.getInt(_kPendingGrade) ?? grade;
    final t = p.getString(_kPendingTrack) ?? track;
    final r = AppRole.sanitize(p.getString(_kPendingRole) ?? role);
    try {
      final created = await _users.upsert(
        uid: uid,
        name: name,
        email: email,
        grade: g,
        track: t,
        role: r,
        photoUrl: photoUrl,
      );
      // ⚠️ المعامل يحجب الحقل هنا — `this` إلزامية وإلا بقيت الصورة فارغة
      //    حتى أول مزامنة سحابية.
      // 🛡️ وصورة المزوّد لا تُزيح صورةً موجودة: `_hydrateFromCloud` قد سبقت
      //    بصورة الطالب المرفوعة، وهذا السطر كان سيمحوها من الشاشة.
      if (photoUrl.isNotEmpty && this.photoUrl.isEmpty) this.photoUrl = photoUrl;
      grade = g;
      track = t;
      // ⚠️ **الدور من السحابة لا من الجهاز إن كان المستند قائماً.**
      //    `upsert` تكتب الدور عند الإنشاء وحده، فمعلّمٌ يدخل من جوّالٍ
      //    جديد كان كاشُه الفارغ سيجعله «طالباً» ويخفي قسمه كلَّه —
      //    فنسحب مستنده بدل أن نخمّن.
      if (created) {
        role = r;
      } else {
        unawaited(_hydrateFromCloud());
      }
      await p.remove(_kPendingGrade);
      await p.remove(_kPendingTrack);
      await p.remove(_kPendingRole);
      await _persist();
    } catch (_) {
      // بلا إنترنت ⇒ يُعاد المحاولة عند الدخول التالي.
    }
  }

  // ===== التعديلات =====

  /// ✏️ يغيّر الاسم المعروض — محلياً ثم في المستند وحساب Firebase.
  /// يعيد رسالة خطأ عربية أو `null` عند النجاح.
  Future<String?> setName(String value) async {
    final clean = value.trim();
    if (clean.length < 2) return "⚠️ الاسم قصير جداً.";
    if (clean.length > 40) return "⚠️ الاسم طويل — 40 حرفاً كحدّ أقصى.";

    name = clean;
    await _persist();
    notifyListeners();
    if (isGuest || uid.isEmpty) return null;
    try {
      await _users.patch(uid, {"name": clean});
      await _auth.currentUser?.updateDisplayName(clean);
    } catch (_) {
      // الاسم محفوظ محلياً ويُصحَّح في المزامنة التالية.
    }
    return null;
  }

  /// 🔑 يرسل بريد إعادة تعيين كلمة المرور لبريد الحساب نفسه.
  Future<String?> sendPasswordReset() async {
    if (isGuest || email.isEmpty) {
      return "⚠️ هذه الميزة للحسابات المسجَّلة ببريد إلكتروني.";
    }
    return _throttledReset(email); // ⏳ نفسُ سقف شاشة «نسيت كلمة المرور»
  }

  Future<void> setGrade(int g) async {
    grade = g;
    // الأول الثانوي موحّد بلا مسار.
    if (g == 1) {
      track = 'عام';
    } else if (track == 'عام') {
      track = 'علمي';
    }
    await _persist();
    unawaited(_patchCloud({'grade': grade, 'track': track}));
    _onScopeChanged();
    notifyListeners();
  }

  /// 🎭 يبدّل نوع الحساب بين طالب ومعلّم.
  ///
  /// ⭐ **لا يُمسح شيء ولا يُصفَّر شيء.** محادثات الطالب ونتائجه ومحفوظاته
  ///    تبقى كما هي، ومحادثات أدوات المعلم كذلك — لأن مفتاح النطاق يفصل
  ///    بينهما أصلاً. فمن بدّل وعاد بعد شهر وجد كلَّ جانبٍ كما تركه.
  ///
  /// يعيد رسالة خطأ عربية أو `null` عند النجاح.
  Future<String?> setRole(String value) async {
    final next = AppRole.sanitize(value);
    if (next == role) return null;

    role = next;
    await _persist();
    notifyListeners();

    // 👤 **الزائر محلياً فقط**: لا مستند له في Firestore أصلاً (`_ensureProfile`
    //    تتجاوزه)، وكتابةٌ هنا كانت ستُنشئ مستنداً ناقصاً ترفضه القواعد بصمت.
    //    ودورُه ينتقل معه عند التسجيل لأن الـuid لا يتغيّر (`linkWithCredential`).
    if (!isGuest && uid.isNotEmpty) {
      try {
        await _users.setRole(uid, next);
      } catch (_) {
        // 🛟 محفوظ محلياً والواجهة تبدّلت فوراً؛ السحابة تلحق في المزامنة
        //    التالية. وقفلُ الشاشة على عطل شبكةٍ عقوبةٌ بلا سبب.
      }
    }
    // 🔄 قواعد الأقسام تختلف بالدور كما تختلف بالصف — بلا هذا يبقى من
    //    صار معلّماً يرى بطاقاتِ طالبٍ حتى الإقلاع التالي.
    _onScopeChanged();
    return null;
  }

  Future<void> setTrack(String t) async {
    track = t;
    await _persist();
    unawaited(_patchCloud({'track': track}));
    _onScopeChanged();
    notifyListeners();
  }

  /// 🔄 الصف والمسار يحكمان **ما يُعرض** لا ما يُدرَّس وحده.
  ///
  /// ⚠️ بدون هذا يبقى طالبٌ صحّح صفّه يرى أقسام صفٍّ تركه وبانراته حتى
  ///    الإقلاع التالي — فيظن التطبيق معطوباً ويشكو ما لا عيب فيه.
  void _onScopeChanged() {
    // 🔄 والخادم أولاً: حارس الأقسام يقرأ صفّي ودوري من `users/{uid}` بكاشٍ
    //    عمرُه دقيقتان، فبلا إسقاطه يبقى يمنعني من قسمٍ صار من حقّي —
    //    ويرى الطالبُ زرّاً مفتوحاً في الواجهة يردّه الخادم بـ403.
    unawaited(_notifyProfileChanged());
    unawaited(AccessRepository.I.refresh());
    unawaited(BannerRepository.I.refreshForScope());
  }

  /// 🔄 يُخبر الخادم أن ملفّي تغيّر فيُسقط كاشه — **بلا انتظار وبلا شكوى**.
  ///
  /// فشلُه لا يعني شيئاً للطالب: أسوأ ما يحدث أن يسري التحويل بعد دقيقتين
  /// بدل الفور، فلا رسالة خطأ ولا حبس للشاشة على نداءٍ تجميلي.
  Future<void> _notifyProfileChanged() async {
    if (isGuest || uid.isEmpty) return;
    try {
      final token = await idToken();
      if (token == null || token.isEmpty) return;
      await http
          .post(Uri.parse(ApiEndpoints.profileChanged()),
              headers: ApiClient.authHeaders(token))
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // بلا شبكة ⇒ الكاش ينقضي وحده بعد دقيقتين.
    }
  }

  Future<void> updateProfile({String? name_, int? grade_, String? track_}) async {
    if (name_ != null && name_.trim().isNotEmpty) name = name_.trim();
    if (grade_ != null) grade = grade_;
    if (track_ != null) track = track_;
    await _persist();
    unawaited(_patchCloud({'name': name, 'grade': grade, 'track': track}));
    notifyListeners();
  }

  /// ⚙️ يرفع تفضيلات الطالب إلى `users/{uid}.settings` — يستعملها
  /// [AppSettings] لمفتاحَي الإشعارات، ويقرؤها الخادم عند بناء الجمهور.
  ///
  /// ⚠️ **دمجٌ لا استبدال**: `updateSettings` تكتب الخريطة كاملةً، فتمرير
  ///    مفتاحين وحدهما كان سيمحو حجم الخط ووضع الليل من المستند.
  ///
  /// ⚠️ وخريطةٌ متداخلة **لا مفاتيح منقوطة**: `set(merge: true)` يدمج
  ///    الخرائط المتداخلة دمجاً عميقاً، أما `"settings.notif_general"`
  ///    فيُنشئ حقلاً اسمه هكذا حرفياً بنقطته — فيبقى المفتاح الحقيقي
  ///    كما كان ولا يقرأ الخادمُ شيئاً، بلا خطأٍ يُنبّه.
  Future<void> patchSettings(Map<String, dynamic> values) async {
    if (uid.isEmpty || isGuest || values.isEmpty) return;
    await _users.patch(uid, {'settings': Map<String, dynamic>.from(values)});
  }

  Future<void> _patchCloud(Map<String, dynamic> fields) async {
    if (uid.isEmpty || isGuest) return;
    try {
      await _users.patch(uid, fields);
    } catch (_) {
      // الكاش المحلي هو المعروض؛ السحابة تلحق لاحقاً.
    }
  }

  Future<void> signOut() async {
    // ★ ارفع المؤجَّل قبل الخروج، وإلا ضاعت آخر رسالة من النسخة السحابية.
    await SyncService.I.flushNow();
    // 📲 وافصل الجهاز **قبل** إبطال التوكن: بعد `signOut` لا سلطة لنا
    //    على المستند. وبلا هذا تصل إشعارات من خرج إلى جهازٍ يستعمله غيره
    //    — وهو حالٌ شائع في جوّالٍ يتشاركه إخوة.
    await PushService.I.stop();
    // 📬 وصندوق الإشعارات يُفرَّغ معه: الجوّال المتشارَك يعني أن إعلانات
    //    من خرج تبقى معروضةً لمن دخل بعده — بنفس منطق فصلِ الجهاز أعلاه.
    await NotificationsRepository.I.clear();
    // 🎟️⭐ وحالتان معروضتان تخصّان الحساب لا الجهاز: حصّةُ من خرج ومفضّلته.
    //    بقاؤهما يعني أن من يدخل بعده يرى «متبقٍّ ٣ أسئلة» ونجومَ غيره —
    //    نفس منطق إفراغ صندوق الإشعارات أعلاه.
    QuotaRepository.I.clear();
    ScholarshipFavorites.I.clear();
    // 🪑 وآخرُ مكانٍ في قسم التعليم: جوّالٌ يتشاركه أخوان كان من يدخل بعد
    //    الآخر يجد قسمَ التعليم مفتوحاً على محادثة من سبقه ([EduSession]).
    EduSession.I.clear();
    await _auth.signOut();
    isGuest = false;
    name = 'طالب مسار';
    photoUrl = '';
    // 🎭 والدور يعود طالباً: جوّالٌ يتشاركه معلّمٌ وطالب كان يفتح لمن دخل
    //    بعده واجهةَ من خرج قبله، حتى تصل السحابة.
    role = AppRole.student;
    final p = _prefs ??= await SharedPreferences.getInstance();
    await p.setBool(_kIsGuest, false);
    await p.remove(_kPhoto);
    await p.remove(_kRole);
    await p.remove(_kPendingRole);
    notifyListeners();
  }

  /// حذف الحساب: تُمسح بياناته السحابية **قبل** حذف الحساب — بعد الحذف
  /// يفقد صلاحيته فتبقى بياناته يتيمة.
  Future<String?> deleteAccount() async {
    final id = uid;
    if (id.isNotEmpty && !isGuest) {
      // 📲 رمز الجهاز أولاً: بعد حذف الحساب لا يبقى مستندٌ يُفصل منه.
      await PushService.I.stop();
      // 🖼️ الصورة أولاً: بعد حذف الحساب يفقد التوكن صلاحيته، فيبقى الملف
      //    في Storage يتيماً لا يستطيع أحد حذفه — ولا يُدفع ثمنه إلا نحن.
      if (photoUrl.isNotEmpty) {
        try {
          await AvatarService.I.upload(null);
        } catch (_) {
          // فشل الحذف لا يوقف حذف الحساب — الملف بلا مالك ولا يُعرض.
        }
      }
      try {
        await _users.deleteAllData(id);
      } catch (_) {
        // قد تمنعها الشبكة — نُكمل الحذف ولا نحبس الطالب.
      }
    }
    final error = await _auth.deleteAccount();
    if (error != null) return error;
    await signOut();
    return null;
  }

  /// ⚠️ **التعبيرُ النمطيّ انتقل إلى [AuthValidators]** ٢٠٢٦-٠٩-٢٣.
  ///    كان هنا نسخةٌ وفي الشاشات نسخةٌ أضعف (`contains('@')`)، فتقبل
  ///    الشاشةُ `a@b.` وترفضها هذه بعد **ثلاث خطوات** من التسجيل. وهذا
  ///    غلافٌ باقٍ ليبقى اللوجيك يحرس نفسَه ولو نودي من غير الشاشات.
  static bool _isValidEmail(String s) => AuthValidators.isEmail(s);
}

/// تشغيل عملية غير حرجة بلا انتظار — تُبقي الواجهة فورية.
void unawaited(Future<void> f) {
  f.catchError((_) {});
}
