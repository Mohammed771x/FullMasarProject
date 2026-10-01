# ==================================================
# 📱 core/app_check.py — «هل هذا الطلب من تطبيقنا الحقيقي؟»
# ==================================================
# ☢️ **العلّة (فحص 2026-10-01):** مفتاحُ Firebase في التطبيق علنيٌّ بالتصميم،
#    فأيُّ سكربتٍ يصنع حساباً مجهولاً بنداءٍ واحد ويأخذ أسئلةَ الزائر —
#    ثم حساباً ثانياً وثالثاً. الحصةُ لكل حساب، والحساباتُ بلا عدد.
#    [core/guest_pool] يحدّ **الكلفة الكلية** للزوّار؛ وهذا الملف يحدّ **مَن
#    يطرق الباب أصلاً**: توكن App Check يصدر لنسخةٍ أصلية من التطبيق على
#    جهازٍ حقيقي (Play Integrity · App Attest/DeviceCheck)، لا لسكربت.
#
# ⚙️ الوضع من البيئة `APP_CHECK_MODE`:
#    • `monitor` (الافتراضي) — يتحقق ويعدّ ولا يمنع أحداً. يُشغَّل أولاً كي
#      يُعرف كم طلباً يحمل توكناً سليماً قبل أي منع.
#    • `guests` — يمنع **الزائرَ** بلا توكنٍ سليم (حيث تقع الإساءة)، ويترك
#      المسجَّلين كما هم.
#    • `all`    — يمنع كلَّ نداءِ موديلٍ بلا توكنٍ سليم.
#    • `off`    — لا شيء.
#
# 🧱 وسيطٌ ASGI خام قبل قراءة الجسم — كـ[core/body_limit] — فالمرفوضُ لا يكلّف
#    تحليلَ JSON ولا صورة. ومساراتُه هي ما يُنادي موديلاً وحده ([MODEL_PATHS]).
#
# 🛟 **يفشل مفتوحاً على عطلنا لا على عطل العميل**: توكنٌ مزوّر أو منتهٍ ⇒ منعٌ
#    (في وضعَي المنع)، أمّا خادمٌ بلا حساب خدمة أو جوجل لا تردّ ⇒ مرور مع
#    تحذير — كي لا يُطفئ عطلُ إعدادٍ المنصّةَ كلَّها.

import asyncio
import base64
import json
import os
import threading
import time

HEADER = b"x-firebase-appcheck"
MODES = ("off", "monitor", "guests", "all")

# نداءاتُ الموديل وحدها — الباقي رخيصٌ أو بلا هوية (المحتوى · الحصة · الإشعارات).
MODEL_PATHS = frozenset({
    "/ask", "/ask/stream",
    "/teacher/ask", "/teacher/ask/stream",
    "/scholarship/ask", "/scholarship/ask/stream",
    "/quiz/generate", "/voice/clean", "/chat/title",
})

REJECT_MESSAGE = ("📱 تعذّر التحقق من نسخة التطبيق. حدّث «مسار» من المتجر "
                  "ثم أعد فتحه — وإن تكرّر راسل الدعم.")

_CACHE_MAX = 20_000
_cache: dict = {}            # {token: exp} — توكنٌ سليم يُتحقَّق منه مرّةً حتى انتهائه
_lock = threading.Lock()
_stats = {"verified": 0, "missing": 0, "invalid": 0, "unverifiable": 0}
_LOG_EVERY = 50


class Unverifiable(Exception):
    """عطلٌ عندنا (لا حساب خدمة · شبكة) — لا حكمَ على العميل."""


def mode() -> str:
    """يُقرأ عند كل طلب — فتبديلُه في البيئة يسري بإعادة التشغيل أو في الاختبار."""
    m = os.getenv("APP_CHECK_MODE", "monitor").strip().lower()
    return m if m in MODES else "monitor"


def stats() -> dict:
    with _lock:
        return dict(_stats)


def reset() -> None:
    """للاختبارات فقط."""
    with _lock:
        _cache.clear()
        for k in _stats:
            _stats[k] = 0


def _count(kind: str) -> None:
    with _lock:
        _stats[kind] += 1
        total = sum(_stats.values())
        snapshot = dict(_stats) if total % _LOG_EVERY == 0 else None
    if snapshot:
        # 📊 هذا السطر هو ما يُقرأ قبل الانتقال إلى `guests`/`all`.
        print(f"📱 App Check ({mode()}): {snapshot}")


def _verify_now(token: str) -> float:
    """تحقّقٌ فعلي بـAdmin SDK — يعيد `exp`، أو يرمي ValueError (توكنٌ فاسد)
    أو [Unverifiable] (عطلٌ عندنا)."""
    try:
        import firebase_admin
        from firebase_admin import app_check
    except ImportError as e:
        raise Unverifiable(f"firebase_admin غير مثبّت: {e}")
    # التطبيقُ الافتراضي يُهيَّأ مع Firestore ([core/quota._firestore]).
    from . import quota
    quota._firestore()
    if not firebase_admin._apps:
        raise Unverifiable("لا حساب خدمة — Admin SDK غير مهيّأ")
    # ☢️ **«لا أستطيع» ≠ «مزوّر»** — وخلطُهما يفتح الباب: توكنٌ مزوّر بمعرّف
    #    مفتاحٍ مجهول (`kid`) أو بـ`alg: none` يرمي `PyJWKClientError` لا
    #    `ValueError` (قيسَ بالمكتبة الحقيقية 2026-10-01). فلو عُدّ كلُّ ما ليس
    #    ValueError عطلاً عندنا لمرّ كلُّ مزوّرٍ بوضع «يفشل مفتوحاً».
    #    فالعطلُ عندنا هو **انقطاعُ الوصول لمفاتيح جوجل وحده**؛ وما عداه فاسد.
    try:
        from jwt import PyJWKClientConnectionError
    except ImportError:                         # PyJWT قديم — لا نخمّن: كلُّه فاسد
        PyJWKClientConnectionError = ()
    try:
        claims = app_check.verify_token(token)
    except PyJWKClientConnectionError as e:
        raise Unverifiable(f"مفاتيح App Check غير متاحة: {e}")
    except Exception as e:                      # noqa: BLE001 — توكنٌ فاسد بأي شكل
        raise ValueError(str(e))
    return float(claims.get("exp") or (time.time() + 300))


def _cached(token: str) -> bool:
    now = time.time()
    with _lock:
        exp = _cache.get(token)
        if exp is None:
            return False
        if exp <= now:
            _cache.pop(token, None)
            return False
        return True


def _remember(token: str, exp: float) -> None:
    with _lock:
        if len(_cache) >= _CACHE_MAX:
            now = time.time()
            for k in [k for k, e in _cache.items() if e <= now] or list(_cache)[: _CACHE_MAX // 4]:
                _cache.pop(k, None)
        _cache[token] = exp


async def verdict(token: str) -> str:
    """`verified` · `missing` · `invalid` · `unverifiable`."""
    if not token:
        return "missing"
    if len(token) > 4096:
        return "invalid"
    if _cached(token):
        return "verified"
    try:
        exp = await asyncio.to_thread(_verify_now, token)
    except ValueError:
        return "invalid"
    except Unverifiable as e:
        print(f"⚠️ App Check غير قابل للتحقق الآن ({e}) — مُرّ.")
        return "unverifiable"
    _remember(token, exp)
    return "verified"


def _is_guest_token(headers) -> bool:
    """هل يحمل الطلب توكنَ زائرٍ مجهول؟ — **قراءةٌ بلا تحقّق، وهذا مقصود**.

    ⚖️ لا يُبنى عليها سماحٌ أبداً: من زوّر مطالبةً تقول «لستُ زائراً» نجا من
       هذا الوسيط ثم سقط في `_authenticate` التي تتحقق من التوقيع. فالتزوير
       لا يربح إلا ما يربحه حسابٌ مسجَّلٌ حقيقي — وذاك يحتاج بريداً موثَّقاً.
       وطلبٌ بلا توكنٍ أصلاً يُعامل زائراً: الأحوطُ في الشك.
    """
    auth = headers.get(b"authorization", b"").decode("latin-1")
    if not auth.lower().startswith("bearer "):
        return True
    try:
        payload = auth[7:].strip().split(".")[1]
        payload += "=" * (-len(payload) % 4)
        claims = json.loads(base64.urlsafe_b64decode(payload))
        return (claims.get("firebase") or {}).get("sign_in_provider") == "anonymous"
    except Exception:                           # noqa: BLE001
        return True


class AppCheckMiddleware:
    """يمنع نداءات الموديل بلا توكن App Check سليم — حسب [mode]."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if (scope.get("type") != "http" or scope.get("method") != "POST"
                or scope.get("path") not in MODEL_PATHS):
            return await self.app(scope, receive, send)
        m = mode()
        if m == "off":
            return await self.app(scope, receive, send)

        headers = dict(scope.get("headers") or [])
        result = await verdict(headers.get(HEADER, b"").decode("latin-1").strip())
        _count(result)

        if result in ("verified", "unverifiable") or m == "monitor":
            return await self.app(scope, receive, send)
        if m == "guests" and not _is_guest_token(headers):
            return await self.app(scope, receive, send)
        return await _reject(send)


async def _reject(send):
    body = json.dumps({"answer": REJECT_MESSAGE, "error": REJECT_MESSAGE,
                       "session_active": False, "app_check_failed": True},
                      ensure_ascii=False).encode("utf-8")
    await send({"type": "http.response.start", "status": 401,
                "headers": [(b"content-type", b"application/json"),
                            (b"content-length", str(len(body)).encode())]})
    await send({"type": "http.response.body", "body": body})
