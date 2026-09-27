# ==================================================
# 🔐 core/firebase_auth.py — التحقق من توكن Firebase
# ==================================================
# يستبدل نظام الأكواد: العميل يرسل `Authorization: Bearer <idToken>`
# والخادم يتحقق من التوقيع بمفاتيح جوجل العامة.
#
# ⭐ نقطة مهمة: التحقق **لا يحتاج Service Account** إطلاقاً — فقط
#    معرّف المشروع ومفاتيح جوجل العامة. الـService Account مطلوب فقط
#    للكتابة في Firestore (عدّاد الحصة) — راجع core/quota.py.
#
# النتيجة قاموس المطالبات (claims) وفيه:
#   uid · email · email_verified · sign_in_provider (password|google.com|anonymous)

import os
import time
import threading

FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "masar-b9925")

_ISSUER = f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}"

# مهلة قصيرة على فشل التحقق المتكرر — لا نضرب جوجل في كل طلب فاشل
_lock = threading.Lock()
_request_session = None


class AuthError(Exception):
    """توكن مفقود أو غير صالح — الرسالة موجّهة للطالب."""


def available() -> bool:
    """هل مكتبة التحقق مثبّتة؟ (google-auth)"""
    try:
        import google.oauth2.id_token  # noqa: F401
        return True
    except ImportError:
        return False


def _session():
    global _request_session
    with _lock:
        if _request_session is None:
            import google.auth.transport.requests
            _request_session = google.auth.transport.requests.Request()
        return _request_session


# ══════════════════════════════════════════════════
# 🔑 شهادات جوجل — تُنزَّل مرّةً وتُحفظ حتى تنتهي صلاحيتها
# ══════════════════════════════════════════════════
# 🔴 **العطل (فحص 2026-09-24):** `verify_firebase_token` تنزّل الشهادات من
#    جوجل **في كل نداء** (لا كاش في google-auth)، والنداءُ متزامن على حلقة
#    الأحداث. قيسَ: ١٠٠ طلبٍ متزامن ⇒ **تجمّد الخادم كلّه ~٢٫٥ ثانية**،
#    تتوقّف فيها كل الأجوبة المبثوثة للطلاب. والتوكن المزيّف ينزّلها أيضاً،
#    فمن يرسل توكنات عشوائية يجمّد الخادم بلا حساب.
#
# ⭐ الشهادات تتغيّر كل بضع ساعات، وجوجل تعلن عمرها في `Cache-Control:
#    max-age`. فتُنزَّل مرّةً وتُحفظ حتى ينتهي عمرها، ويصير التحقق حساباً
#    محلياً (توقيع RSA) لا رحلةً شبكية.
#
# 🔄 **وتدويرُ المفاتيح:** توكنٌ بمعرّف مفتاحٍ (`kid`) غير موجود قد يعني أن
#    جوجل دوّرت مفاتيحها قبل انتهاء الكاش، فنعيد التنزيل **مرّةً كل
#    [_REFRESH_COOLDOWN] ثانية على الأكثر** — وإلا صار كلُّ توكنٍ مزيّف
#    بمعرّفٍ عشوائي تنزيلاً جديداً، وهو العطل نفسه من بابٍ آخر.
_CERTS_URL = ("https://www.googleapis.com/robot/v1/metadata/x509/"
              "securetoken@system.gserviceaccount.com")
_DEFAULT_MAX_AGE = 3600.0       # إن لم تُعلن جوجل عمراً
_MIN_MAX_AGE = 60.0
_REFRESH_COOLDOWN = 60.0
_certs_lock = threading.Lock()
_certs = {"data": None, "expires": 0.0, "fetched": 0.0}


def _max_age(headers) -> float:
    cc = ""
    try:
        cc = headers.get("cache-control", "") or headers.get("Cache-Control", "")
    except Exception:           # noqa: BLE001
        pass
    for part in str(cc).split(","):
        part = part.strip().lower()
        if part.startswith("max-age="):
            try:
                return max(_MIN_MAX_AGE, float(part.split("=", 1)[1]))
            except ValueError:
                break
    return _DEFAULT_MAX_AGE


def _fetch_certs() -> dict:
    """تنزيلٌ فعليّ واحد — لا يُنادى إلا من [_certificates]."""
    import json as _json
    resp = _session()(url=_CERTS_URL, method="GET")
    if resp.status != 200:
        raise AuthError("⚠️ تعذّر التحقق من الجلسة الآن. حاول بعد قليل.")
    data = resp.data.decode("utf-8") if isinstance(resp.data, bytes) else resp.data
    return {"certs": _json.loads(data), "max_age": _max_age(resp.headers)}


def _certificates(force: bool = False) -> dict:
    """الشهادات من الكاش، أو تنزيلٌ واحد عند انتهائها (أو عند التدوير)."""
    now = time.time()
    with _certs_lock:
        fresh = _certs["data"] is not None and now < _certs["expires"]
        if fresh and not force:
            return _certs["data"]
        if force and fresh and now - _certs["fetched"] < _REFRESH_COOLDOWN:
            return _certs["data"]          # تدويرٌ حديث — لا تنزيل ثانٍ
        got = _fetch_certs()
        _certs.update(data=got["certs"], expires=now + got["max_age"], fetched=now)
        return _certs["data"]


def certs_are_fresh() -> bool:
    """هل يكفي الكاش للتحقق بلا شبكة؟ (يقرّر بها [averify] أين يعمل.)"""
    with _certs_lock:
        return _certs["data"] is not None and time.time() < _certs["expires"]


def _decode(id_token: str) -> dict:
    """توقيع + جمهور + انتهاء — بالشهادات المحفوظة، وتدويرٌ واحد عند الحاجة."""
    from google.auth import jwt as google_jwt
    try:
        return google_jwt.decode(id_token, certs=_certificates(),
                                 audience=FIREBASE_PROJECT_ID)
    except ValueError as e:
        # `kid` غير معروف ⇒ ربما دُوّرت المفاتيح: تنزيلٌ واحد ثم محاولةٌ أخيرة.
        if "Certificate for key id" not in str(e):
            raise
        return google_jwt.decode(id_token, certs=_certificates(force=True),
                                 audience=FIREBASE_PROJECT_ID)


def reset_cache() -> None:
    """للاختبارات فقط."""
    with _certs_lock:
        _certs.update(data=None, expires=0.0, fetched=0.0)


def verify(id_token: str) -> dict:
    """يتحقق من التوكن ويعيد المطالبات، أو يرمي AuthError.

    ما يُفحص: التوقيع بمفاتيح جوجل · aud == معرّف المشروع ·
    iss == securetoken · انتهاء الصلاحية.

    ⚠️ **متزامنة** — من المسارات تُنادى [averify] لا هذه.
    """
    if not id_token:
        raise AuthError("⛔ الرجاء تسجيل الدخول أولاً.")
    if not available():
        raise AuthError("⚠️ خدمة التوثيق غير مهيأة على الخادم.")

    try:
        claims = _decode(id_token)
    except AuthError:
        raise
    except Exception:
        raise AuthError("⛔ جلستك انتهت. سجّل الدخول من جديد.")

    if not claims:
        raise AuthError("⛔ جلستك انتهت. سجّل الدخول من جديد.")
    if claims.get("iss") != _ISSUER:
        raise AuthError("⛔ توكن غير صالح.")
    if claims.get("exp", 0) < time.time():
        raise AuthError("⛔ جلستك انتهت. سجّل الدخول من جديد.")

    return normalize(claims)


async def averify(id_token: str) -> dict:
    """نسخةٌ لا تحجب حلقة الأحداث — **هذه التي تُنادى من المسارات**.

    ⚡ والكاش ساخنٌ في الغالب، فيبقى التحقق هنا حساباً محلياً قصيراً بلا
       خيطٍ جانبي (بركةُ الخيوط ثمانية، ويتقاسمها Firestore والبحث). ولا
       يُنقل إلى خيطٍ إلا حين قد يلزم تنزيلٌ فعليّ.

    ⚠️ و`verify` تُقرأ من مجال الوحدة **وقت النداء** لا عند الاستيراد، كي
       يصل استبدالُها في الاختبارات (`monkeypatch.setattr(fa, "verify", …)`).
    """
    fn = globals()["verify"]
    if certs_are_fresh():
        return fn(id_token)
    import asyncio
    return await asyncio.to_thread(fn, id_token)


def normalize(claims: dict) -> dict:
    """يوحّد شكل المطالبات مهما اختلفت مصادرها."""
    provider = (claims.get("firebase") or {}).get("sign_in_provider", "")
    return {
        "uid": claims.get("user_id") or claims.get("sub") or "",
        "email": claims.get("email") or "",
        "email_verified": bool(claims.get("email_verified")),
        "provider": provider,
        "is_guest": provider == "anonymous",
        "name": claims.get("name") or "",
    }


def bearer_token(request) -> str:
    """يستخرج التوكن من ترويسة Authorization."""
    header = request.headers.get("authorization", "") or request.headers.get("Authorization", "")
    if header.lower().startswith("bearer "):
        return header[7:].strip()
    return ""


def requires_verified_email(identity: dict) -> bool:
    """التحقق من البريد إلزامي لمسار البريد/كلمة السر وحده.

    جوجل يتحقق من البريد بنفسه، والزائر بلا بريد أصلاً.
    """
    return identity.get("provider") == "password" and not identity.get("email_verified")
