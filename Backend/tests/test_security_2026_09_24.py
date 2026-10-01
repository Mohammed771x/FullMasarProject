"""🛡️ إصلاحات فحص الأمان والضغط (2026-09-24) — ثلاث علل مقيسة لا تعود.

① التوثيق كان ينزّل شهادات جوجل في **كل طلب** وعلى حلقة الأحداث:
   ١٠٠ طلبٍ متزامن ⇒ تجمّد الخادم كلّه ~٢٫٥ث، والتوكن المزيّف ينزّلها أيضاً.
② حدُّ المعدل كان مفتاحُه `IP|uid` والـIP من `X-Forwarded-For` الذي يكتبه
   العميل ⇒ تدويرُه تخطّى الحدّ كلياً (٤٠/٤٠ والحدّ ٢٠).
③ لا سقف لحجم الطلب، والجسم يُحلَّل قبل التوكن ⇒ ٨٣MB بلا حساب = +٢٩٠MB ذاكرة.
"""
import asyncio
import json
import time

import pytest
from fastapi.testclient import TestClient

import api
from core import body_limit
from core import firebase_auth as fa
from core import quota as q
from core import ratelimit as rl

# 📌 الحقيقية قبل أن يستبدلها `conftest` — نختبر التحقق نفسه هنا.
_REAL_VERIFY = fa.verify


# ══════════════════════════════════════════════════
# 🔑 توكناتٌ حقيقية موقّعة بمفتاح RSA — وجوجل مزيّفة تَعُدّ التنزيلات
# ══════════════════════════════════════════════════

def _keypair():
    from cryptography.hazmat.primitives import serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    private = key.private_bytes(serialization.Encoding.PEM,
                                serialization.PrivateFormat.PKCS8,
                                serialization.NoEncryption())
    public = key.public_key().public_bytes(
        serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo)
    return private, public


_PRIVATE, _PUBLIC = _keypair()


def _token(kid="k1", uid="teacher-1", exp_in=3600, aud=None):
    from google.auth import crypt, jwt
    now = int(time.time())
    signer = crypt.RSASigner.from_string(_PRIVATE, key_id=kid)
    payload = {
        "iss": f"https://securetoken.google.com/{fa.FIREBASE_PROJECT_ID}",
        "aud": aud or fa.FIREBASE_PROJECT_ID, "sub": uid, "user_id": uid,
        "iat": now - 10, "exp": now + exp_in, "auth_time": now - 10,
        "email": "t@example.com", "email_verified": True,
        "firebase": {"sign_in_provider": "google.com"},
    }
    return jwt.encode(signer, payload).decode()


@pytest.fixture()
def google(monkeypatch):
    """شهاداتُ جوجل المزيّفة: `calls` يعدّ كل تنزيلٍ فعليّ."""
    state = {"calls": 0, "delay": 0.0, "max_age": 3600.0}

    def fake_fetch():
        state["calls"] += 1
        if state["delay"]:
            time.sleep(state["delay"])
        return {"certs": {"k1": _PUBLIC.decode()}, "max_age": state["max_age"]}

    fa.reset_cache()
    monkeypatch.setattr(fa, "_fetch_certs", fake_fetch)
    monkeypatch.setattr(fa, "verify", _REAL_VERIFY)
    yield state
    fa.reset_cache()


# ══════════════ ① الشهادات تُنزَّل مرّة لا في كل طلب ══════════════

def test_valid_token_is_verified_with_real_signature(google):
    ident = fa.verify(_token(uid="abc"))
    assert ident["uid"] == "abc" and ident["provider"] == "google.com"


def test_many_verifications_download_certificates_once(google):
    """🔴 كان: ١٠٠ تحقق = ١٠٠ تنزيل على حلقة الأحداث."""
    for i in range(100):
        fa.verify(_token(uid=f"u{i}"))
    assert google["calls"] == 1


def test_forged_tokens_do_not_trigger_downloads(google):
    """التوكن المزيّف كان يُنزّل الشهادات أيضاً — بابُ تجميدٍ بلا حساب."""
    fa.verify(_token())                                   # كاشٌ ساخن
    for junk in ["a.b.c", "garbage", _token(aud="other-project")] * 20:
        with pytest.raises(fa.AuthError):
            fa.verify(junk)
    assert google["calls"] == 1


def test_unknown_key_id_refetches_at_most_once_per_cooldown(google):
    """🔄 تدويرُ المفاتيح يستحقّ تنزيلاً — لكن لا يصير كلُّ `kid` عشوائيٍّ تنزيلاً."""
    fa.verify(_token())
    google["calls"] = 0
    fa._certs["fetched"] = time.time() - fa._REFRESH_COOLDOWN - 1   # آخر تنزيلٍ قديم
    for i in range(50):
        with pytest.raises(fa.AuthError):
            fa.verify(_token(kid=f"rotated-{i}"))
    assert google["calls"] == 1


def test_expired_cache_is_refreshed(google):
    fa.verify(_token())
    fa._certs["expires"] = time.time() - 1
    fa.verify(_token())
    assert google["calls"] == 2


def test_expired_and_wrong_audience_tokens_still_rejected(google):
    with pytest.raises(fa.AuthError):
        fa.verify(_token(exp_in=-60))
    with pytest.raises(fa.AuthError):
        fa.verify(_token(aud="someone-else"))


def test_max_age_is_read_from_cache_control():
    assert fa._max_age({"cache-control": "public, max-age=19800, must-revalidate"}) == 19800
    assert fa._max_age({}) == fa._DEFAULT_MAX_AGE
    assert fa._max_age({"cache-control": "max-age=1"}) == fa._MIN_MAX_AGE


def test_cold_cache_download_does_not_freeze_the_event_loop(google):
    """⚡ التنزيل البطيء (٣٠٠ms) يقع في خيطٍ جانبي — الحلقة تبقى تعمل."""
    google["delay"] = 0.3

    async def scenario():
        worst = 0.0
        done = asyncio.Event()

        async def ticker():
            nonlocal worst
            while not done.is_set():
                t = time.perf_counter()
                await asyncio.sleep(0.01)
                worst = max(worst, time.perf_counter() - t - 0.01)

        tick = asyncio.create_task(ticker())
        ident = await fa.averify(_token(uid="cold"))
        done.set()
        await tick
        return ident, worst

    ident, worst = asyncio.run(scenario())
    assert ident["uid"] == "cold"
    assert worst < 0.1, f"الحلقة تجمّدت {worst * 1000:.0f}ms"


def test_averify_honours_patched_verify(monkeypatch):
    """الاختبارات تستبدل `fa.verify` — و`averify` يجب أن تراها."""
    monkeypatch.setattr(fa, "verify", lambda t: {"uid": "patched"})
    assert asyncio.run(fa.averify("x"))["uid"] == "patched"


def test_authenticate_goes_through_averify():
    import inspect
    src = inspect.getsource(api._authenticate)
    assert "averify" in src and "v3_auth.verify(" not in src


# ══════════════ ② حدُّ المعدل لا يُتخطّى بتزوير الترويسة ══════════════

class _Req:
    def __init__(self, fwd):
        self.headers = {"x-forwarded-for": fwd}
        self.client = type("C", (), {"host": "127.0.0.1"})()


@pytest.fixture()
def client():
    rl.reset()
    q.reset_memory()
    yield TestClient(api.app)
    rl.reset()


def test_rotating_forwarded_for_no_longer_bypasses_teacher_limit(client):
    """🔴 كان: ٤٠ طلباً بـ٤٠ IP مزوّراً مرّت كلها والحدُّ ٢٠."""
    codes = []
    for i in range(rl.ASK_LIMIT + 5):
        r = client.post("/teacher/ask",
                        json={"tool": "no-such-tool", "subject": "احياء", "content": "x"},
                        headers={"X-Forwarded-For": f"10.0.{i}.{i}"})
        codes.append(r.status_code)
    assert codes[:rl.ASK_LIMIT].count(429) == 0
    assert codes[rl.ASK_LIMIT:] == [429] * 5


def test_rotating_forwarded_for_no_longer_bypasses_ask_limit(client):
    codes = [client.post("/ask",
                         json={"subject": "مادة غير موجودة", "mode": "شرح",
                               "input_type": "برومت", "content": "x"},
                         headers={"X-Forwarded-For": f"172.16.0.{i}"}).status_code
             for i in range(rl.ASK_LIMIT + 3)]
    assert codes[rl.ASK_LIMIT:] == [429] * 3


def test_user_limit_ignores_headers_entirely():
    rl.reset()
    for _ in range(rl.ASK_LIMIT):
        assert rl.check_user("uid-1")
    assert rl.check_user("uid-1") is False
    assert rl.check_user("uid-2") is True            # طالبٌ آخر خلف نفس البوابة


def test_user_scopes_stay_separate():
    """النطاقات القديمة محفوظة: قراءةُ الحصة لا تأكل رصيد الأسئلة."""
    rl.reset()
    for _ in range(30):
        assert rl.check_user("uid-1", rl.CONTENT_LIMIT, rl.CONTENT_WINDOW)
    assert rl.check_user("uid-1")


def test_spoofed_ip_flood_cannot_reset_student_limits(monkeypatch):
    """🔴 كان امتلاءُ المخزن يُفرغه كلَّه — فعشرة آلاف IP مزوّر تصفّر حدود الجميع."""
    rl.reset()
    monkeypatch.setattr(rl, "_MAX_KEYS", 50)
    for _ in range(rl.ASK_LIMIT):
        rl.check_user("student")
    assert rl.check_user("student") is False
    for i in range(500):                                  # فيضانُ IPs مزوّرة
        rl.check(_Req(f"6.6.{i // 250}.{i % 250}"), "content")
    assert rl.check_user("student") is False, "الفيضان صفّر حدّ الطالب"


def test_full_store_evicts_oldest_not_everything(monkeypatch):
    rl.reset()
    monkeypatch.setattr(rl, "_MAX_KEYS", 8)
    for i in range(8):
        rl.check_user(f"u{i}")
    for _ in range(rl.ASK_LIMIT - 1):
        rl.check_user("u7")                               # الأحدث نشاطاً
    rl.check_user("newcomer")                             # يُطلق الإخلاء
    assert rl.check_user("u7") is False, "الإخلاء مسح دلواً نشطاً"
    assert len(rl._user_buckets) <= 8


def test_paid_routes_all_use_check_user():
    """كلُّ مسارٍ معه هويةٌ موثَّقة يُعدّ بها — لا يُنسى واحد."""
    import pathlib
    root = pathlib.Path(api.__file__).parent
    offenders = []
    for path in [root / "api.py", *(root / "apiparts").glob("*.py")]:
        for n, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if "ratelimit.check(request, " in line and (
                    'identity["uid"]' in line or "ident.get(" in line or ", uid," in line):
                offenders.append(f"{path.name}:{n}")
    assert not offenders, offenders


# ══════════════ ③ سقفُ حجم الطلب قبل قراءته ══════════════

def test_oversized_body_rejected_before_auth(client, monkeypatch):
    """🔴 كان: ٨٣MB بلا توكن تُقرأ وتُحلَّل كاملةً ثم يأتي 401."""
    seen = []
    monkeypatch.setattr(fa, "verify", lambda t: seen.append(t) or {})
    big = b'{"content":"' + b"x" * (body_limit.MAX_BODY_BYTES + 10) + b'"}'
    r = client.post("/teacher/ask", content=big,
                    headers={"content-type": "application/json"})
    assert r.status_code == 413
    assert "أكبر من المسموح" in r.json()["answer"]
    assert seen == [], "وصل الطلبُ التوثيقَ — أي أن جسمه قُرئ"


def test_oversized_chunked_body_rejected_without_content_length(client):
    """بلا `Content-Length` (chunked): يُقطع أثناء القراءة لا بعدها."""
    chunk = b"x" * (1024 * 1024)

    def body():
        yield b'{"content":"'
        for _ in range(body_limit.MAX_BODY_BYTES // len(chunk) + 2):
            yield chunk
        yield b'"}'

    r = client.post("/ask/stream", content=body(),
                    headers={"content-type": "application/json"})
    assert r.status_code == 413


def test_largest_legitimate_request_still_passes(client):
    """صورتان بأقصى حجم + سجلٌّ كامل + سؤال — يجب ألّا يمسّها السقف."""
    from config import HISTORY_MAX_CHARS, HISTORY_MAX_MESSAGES
    payload = {
        "tool": "no-such-tool", "subject": "احياء", "content": "س" * 6000,
        "images_base64": ["A" * 2_000_000, "A" * 2_000_000],
        "chat_history": [{"role": "user", "content": "ت" * HISTORY_MAX_CHARS}]
        * HISTORY_MAX_MESSAGES,
    }
    raw = json.dumps(payload, ensure_ascii=False).encode()
    assert len(raw) < body_limit.MAX_BODY_BYTES
    r = client.post("/teacher/ask", content=raw,
                    headers={"content-type": "application/json"})
    assert r.status_code != 413


def test_ingest_tool_keeps_its_larger_ceiling(client, monkeypatch):
    """أداةُ الإدخال للأدمن (٤٠ صفحة) لا تُرفض بسقف الطالب.

    ⚠️ ومنذ 2026-10-01 لا تصلها الأجسامُ إلا مُشغَّلةً وبمفتاح الإدارة
       ([core/body_limit._ingest_denial]) — فالفحصُ بهما، وإلا كان 401/404
       يُمرِّر الاختبار بلا أن يمسّ السقف أصلاً."""
    from core import admin as adm
    monkeypatch.setenv("INGEST_ENABLED", "1")
    monkeypatch.setattr(adm, "ADMIN_KEY", "k-test")
    assert body_limit.limit_for("/ingest/run") > 40 * 8 * 1024 * 1024
    big = b"x" * (body_limit.MAX_BODY_BYTES + 1024)
    r = client.post("/ingest/run", content=big,
                    headers={"content-type": "multipart/form-data; boundary=zz",
                             "X-Admin-Key": "k-test"})
    assert r.status_code not in (401, 404, 413)


def test_streaming_answers_still_flow_through_the_middleware(client):
    """الوسيطُ خام (لا `BaseHTTPMiddleware`) كي لا يُجمّع البثّ في دفعةٍ واحدة."""
    from starlette.middleware.base import BaseHTTPMiddleware
    assert not issubclass(body_limit.BodyLimitMiddleware, BaseHTTPMiddleware)
    r = client.post("/teacher/ask/stream",
                    json={"tool": "ask", "subject": "احياء", "content": "مرحبا"})
    assert r.status_code == 200
    assert "text/event-stream" in r.headers["content-type"]
