import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

// ==========================================
// 🔐 مستودع التوثيق — الغلاف الوحيد حول Firebase Auth
// ==========================================
// ⚠️ **لا يستدعي أحدٌ FirebaseAuth مباشرةً خارج هذا الملف.**
//    كل التطبيق يمر من هنا، فلو تغيّر مزوّد التوثيق يوماً تُبدَّل طبقة واحدة
//    ([ADR-003] · [27§2]).
//
// ثلاث طرق للدخول (قرار المالك — [27§8]):
//   1. Google            → الاسم والبريد من الحساب، ولا تحقق مطلوب
//   2. بريد + كلمة سر    → **تحقق البريد إلزامي** قبل الدخول
//   3. زائر (anonymous)  → تجربة 5 أسئلة، وعند التسجيل تُربط بحسابه فلا يفقد شيئاً
class AuthRepository {
  AuthRepository({FirebaseAuth? auth}) : _injected = auth;

  final FirebaseAuth? _injected;

  /// ⚠️ `FirebaseAuth.instance` **يرمي** إن لم تُهيَّأ Firebase (إعداد ناقص،
  ///    أو فشل التهيئة في bootstrap). نُرجع null بدل الرمي فيبقى التطبيق
  ///    يعمل محلياً ويظهر كـ«غير مسجَّل» بدل أن ينهار عند الإقلاع.
  FirebaseAuth? get _maybeAuth {
    try {
      return _injected ?? FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  /// للعمليات التي لا معنى لها بلا Firebase — ترمي رسالة عربية واضحة.
  FirebaseAuth get _auth {
    final a = _maybeAuth;
    if (a == null) throw StateError("Firebase غير مهيأة");
    return a;
  }

  /// معرّف عميل الويب (من google-services.json) — تطلبه إضافة جوجل على أندرويد
  /// للحصول على `idToken`. ليس سرّاً: يُشحن داخل التطبيق أصلاً.
  static const String googleServerClientId =
      "1027662199828-m7r0tfjh784a3fsq4aivkdsiqmaohvr9.apps.googleusercontent.com";

  static bool _googleReady = false;

  User? get currentUser => _maybeAuth?.currentUser;
  bool get isSignedIn => currentUser != null;
  bool get isGuest => currentUser?.isAnonymous ?? false;

  /// هل يحتاج المستخدم لتفعيل بريده؟ (مسار كلمة السر وحده)
  bool get needsEmailVerification {
    final u = currentUser;
    if (u == null || u.isAnonymous || u.emailVerified) return false;
    return u.providerData.any((p) => p.providerId == "password");
  }

  Stream<User?> authStateChanges() => _maybeAuth?.authStateChanges() ?? const Stream.empty();

  /// توكن الوصول المرسل للباك اند في ترويسة Authorization.
  /// `refresh: true` بعد تفعيل البريد كي تُحدَّث المطالبة `email_verified`.
  Future<String?> idToken({bool refresh = false}) async {
    try {
      return await currentUser?.getIdToken(refresh);
    } catch (_) {
      return null;
    }
  }

  // ══════════════ بريد + كلمة سر ══════════════

  /// إنشاء حساب: يضبط الاسم ويرسل رابط التحقق فوراً.
  /// يعيد رسالة خطأ عربية، أو null عند النجاح.
  Future<String?> registerWithEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      await cred.user?.updateDisplayName(name.trim());
      await cred.user?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _arabicError(e);
    } on StateError {
      return _notReady;
    } catch (_) {
      return "تعذّر إنشاء الحساب. تأكد من اتصالك بالإنترنت.";
    }
  }

  Future<String?> signInWithEmail({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _arabicError(e);
    } on StateError {
      return _notReady;
    } catch (_) {
      return "تعذّر تسجيل الدخول. تأكد من اتصالك بالإنترنت.";
    }
  }

  /// إعادة إرسال رابط التحقق (الواجهة تفرض مهلة 60 ثانية بين الطلبين).
  Future<String?> sendVerificationEmail() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _arabicError(e);
    } catch (_) {
      return "تعذّر إرسال رسالة التحقق.";
    }
  }

  /// يعيد تحميل حالة المستخدم من الخادم ويقول: هل فُعّل البريد؟
  Future<bool> refreshEmailVerified() async {
    try {
      await _auth.currentUser?.reload();
      final ok = _auth.currentUser?.emailVerified ?? false;
      if (ok) await _auth.currentUser?.getIdToken(true); // تحديث المطالبة للباك
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// «نسيت كلمة السر» — رابط إعادة تعيين من Firebase.
  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
      return null;
    } on FirebaseAuthException catch (e) {
      return _arabicError(e);
    } catch (_) {
      return "تعذّر إرسال رابط الاستعادة.";
    }
  }

  // ══════════════ Google ══════════════

  Future<String?> signInWithGoogle() async {
    try {
      if (!_googleReady) {
        await GoogleSignIn.instance.initialize(serverClientId: googleServerClientId);
        _googleReady = true;
      }
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return "تعذّر الحصول على بيانات حساب جوجل.";

      final credential = GoogleAuthProvider.credential(idToken: idToken);
      // ★ زائر يسجّل بجوجل: نربط الحساب بدل إنشاء واحد جديد فلا يفقد محادثاته.
      final current = _auth.currentUser;
      if (current != null && current.isAnonymous) {
        try {
          await current.linkWithCredential(credential);
          return null;
        } on FirebaseAuthException catch (e) {
          if (e.code != "credential-already-in-use") return _arabicError(e);
          // الحساب موجود مسبقاً ⇒ ندخل به عادياً
        }
      }
      await _auth.signInWithCredential(credential);
      return null;
    } on GoogleSignInException catch (e) {
      debugPrint("🇬 GoogleSignInException: ${e.code} — ${e.description}");
      switch (e.code) {
        case GoogleSignInExceptionCode.canceled:
          return null; // ألغى بنفسه — ليس خطأ
        case GoogleSignInExceptionCode.clientConfigurationError:
        case GoogleSignInExceptionCode.providerConfigurationError:
          // ★ السبب الأشيع على أندرويد: بصمة SHA-1 غير مسجّلة في Firebase.
          //   وعلى iOS: مخطط الـURL (REVERSED_CLIENT_ID) ناقص في Info.plist.
          return "إعداد الدخول بجوجل غير مكتمل على هذا التطبيق. "
              "جرّب البريد وكلمة المرور، وسنصلحه قريباً.";
        case GoogleSignInExceptionCode.uiUnavailable:
          return "تعذّر فتح نافذة جوجل. أعد المحاولة.";
        case GoogleSignInExceptionCode.interrupted:
          return "انقطعت العملية قبل أن تكتمل. أعد المحاولة.";
        case GoogleSignInExceptionCode.unknownError:
        default:
          return "تعذّر الدخول بجوجل. تأكد من تحديث «خدمات Google Play» ثم أعد المحاولة.";
      }
    } on FirebaseAuthException catch (e) {
      return _arabicError(e);
    } on StateError {
      return _notReady;
    } on MissingPluginException {
      // يحدث حين يُشغَّل التطبيق بـHot Reload بعد إضافة الحزمة بلا بناء كامل.
      debugPrint("🇬 MissingPluginException — إضافة جوجل غير محمّلة أصلاً.");
      return "أوقف التطبيق تماماً وأعد تشغيله (لا Hot Reload) ثم جرّب مجدداً.";
    } on PlatformException catch (e) {
      debugPrint("🇬 PlatformException: ${e.code} — ${e.message}");
      if (e.code == "network_error") return "لا يوجد اتصال بالإنترنت.";
      return "تعذّر الدخول بجوجل (${e.code}). جرّب البريد وكلمة المرور مؤقتاً.";
    } catch (e) {
      // ⚠️ لا نبتلع السبب: نطبعه في اللوج ونذكر نوعه في وضع التطوير.
      debugPrint("🇬 خطأ غير متوقّع في الدخول بجوجل: ${e.runtimeType} — $e");
      return kDebugMode
          ? "تعذّر الدخول بجوجل: ${e.runtimeType}"
          : "تعذّر الدخول بجوجل. أعد المحاولة، وإن تكرر استخدم البريد وكلمة المرور.";
    }
  }

  // ══════════════ الزائر ══════════════

  Future<String?> signInAsGuest() async {
    try {
      await _auth.signInAnonymously();
      return null;
    } on FirebaseAuthException catch (e) {
      return _arabicError(e);
    } on StateError {
      return _notReady;
    } catch (_) {
      return "تعذّر الدخول كزائر. تأكد من اتصالك بالإنترنت.";
    }
  }

  /// ترقية الزائر إلى حساب دائم — **محادثاته وحصته تنتقل معه** لأن الـuid ثابت.
  Future<String?> upgradeGuestToEmail({
    required String name,
    required String email,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null || !user.isAnonymous) {
      return registerWithEmail(name: name, email: email, password: password);
    }
    try {
      final credential = EmailAuthProvider.credential(email: email.trim(), password: password);
      await user.linkWithCredential(credential);
      await user.updateDisplayName(name.trim());
      await user.sendEmailVerification();
      return null;
    } on FirebaseAuthException catch (e) {
      return _arabicError(e);
    } catch (_) {
      return "تعذّر إكمال التسجيل. تأكد من اتصالك بالإنترنت.";
    }
  }

  Future<void> signOut() async {
    try {
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      await _auth.signOut();
    } catch (_) {}
  }

  Future<String?> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == "requires-recent-login") {
        return "لأمانك: سجّل الخروج ثم الدخول من جديد قبل حذف الحساب.";
      }
      return _arabicError(e);
    } catch (_) {
      return "تعذّر حذف الحساب.";
    }
  }

  static const String _notReady =
      "⚠️ خدمة الحساب غير جاهزة على هذا الجهاز. أعد تشغيل التطبيق أو تواصل معنا.";

  // ══════════════ الرسائل ══════════════
  // رسائل Firebase إنجليزية وتقنية — نترجمها لرسائل يفهمها الطالب.
  static String _arabicError(FirebaseAuthException e) {
    switch (e.code) {
      case "invalid-email":
        return "صيغة البريد الإلكتروني غير صحيحة.";
      case "email-already-in-use":
      case "credential-already-in-use":
        return "هذا البريد مسجّل مسبقاً — سجّل الدخول بدلاً من ذلك.";
      case "weak-password":
        return "كلمة المرور ضعيفة — اجعلها 6 أحرف على الأقل.";
      case "user-disabled":
        return "هذا الحساب موقوف. تواصل معنا.";
      case "user-not-found":
      case "wrong-password":
      case "invalid-credential":
        return "البريد أو كلمة المرور غير صحيحة.";
      case "too-many-requests":
        return "محاولات كثيرة متتالية — انتظر قليلاً ثم أعد المحاولة.";
      case "network-request-failed":
        return "لا يوجد اتصال بالإنترنت.";
      case "operation-not-allowed":
        return "طريقة الدخول هذه غير مفعّلة حالياً.";
      default:
        return "حدث خطأ غير متوقع. حاول مرة أخرى.";
    }
  }
}
