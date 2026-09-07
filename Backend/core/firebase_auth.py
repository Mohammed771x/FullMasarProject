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


def verify(id_token: str) -> dict:
    """يتحقق من التوكن ويعيد المطالبات، أو يرمي AuthError.

    ما يُفحص: التوقيع بمفاتيح جوجل · aud == معرّف المشروع ·
    iss == securetoken · انتهاء الصلاحية.
    """
    if not id_token:
        raise AuthError("⛔ الرجاء تسجيل الدخول أولاً.")
    if not available():
        raise AuthError("⚠️ خدمة التوثيق غير مهيأة على الخادم.")

    try:
        from google.oauth2 import id_token as google_id_token
        claims = google_id_token.verify_firebase_token(
            id_token, _session(), audience=FIREBASE_PROJECT_ID
        )
    except Exception:
        raise AuthError("⛔ جلستك انتهت. سجّل الدخول من جديد.")

    if not claims:
        raise AuthError("⛔ جلستك انتهت. سجّل الدخول من جديد.")
    if claims.get("iss") != _ISSUER:
        raise AuthError("⛔ توكن غير صالح.")
    if claims.get("exp", 0) < time.time():
        raise AuthError("⛔ جلستك انتهت. سجّل الدخول من جديد.")

    return normalize(claims)


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
