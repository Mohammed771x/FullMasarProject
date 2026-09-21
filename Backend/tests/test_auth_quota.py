"""بوابة التوثيق (توكن Firebase) والحصة اليومية.

🗑️ نظام أكواد التفعيل **حُذف بالكامل** — لا مسار يعمل بلا توكن، ولا مفتاح
   بيئةٍ يعيد فتحه. الاختبارات هنا تحرس ذلك صراحةً.
"""
import pytest
from fastapi.testclient import TestClient

import api
from core import ratelimit as rl
from core import firebase_auth as fa
from core import quota as q

# 📌 النسختان الحقيقيتان قبل أن يستبدلهما `conftest` — لاختبار البوابة ذاتها.
_REAL_BEARER = fa.bearer_token
_REAL_VERIFY = fa.verify


@pytest.fixture()
def client(no_real_api_calls):
    rl._buckets.clear()
    q.reset_memory()
    return TestClient(api.app)


def _body(**over):
    body = {
        "subject": "فيزياء", "mode": "شرح", "input_type": "برومت",
    # 🎟️ **وحدةٌ حقيقية وسؤالٌ من داخلها عمداً.**
    #    منذ أن صار الرفضُ لا يخصم من الحصة ([core/billing.py]) لم يعد
    #    طلبٌ بلا وحدة يصلح لاختبار الحصة: يُرفض مجاناً فلا يُخصم شيء.
    #    فاختبارُ الحصة يحتاج طلباً **يكلّف** فعلاً.
        "summary_level": 3, "content": "اشرح لي نظرية بوهر", "unit_name": "الفيزياء الذرية", "lesson_name": "",
        "chat_history": [], "grade": 3, "track": "علمي",
    }
    body.update(over)
    return body


def _fake_verify(monkeypatch, **claims):
    """يستبدل التحقق الحقيقي — لا نداء لجوجل في الاختبارات."""
    ident = {"uid": "uid-1", "email": "a@b.com", "email_verified": True,
             "provider": "password", "is_guest": False, "name": "طالب"}
    ident.update(claims)
    monkeypatch.setattr(fa, "verify", lambda token: dict(ident))
    return ident


# ══════════ استخراج التوكن وتطبيع المطالبات ══════════
def test_bearer_token_parsing():
    # ⚠️ الدالة الأصلية لا المحقونة: `conftest` يستبدلها لتُسهّل بقية
    #    الاختبارات، واختبارُها هنا يجب أن يمسّ الحقيقية.
    parse = fa.bearer_token.__wrapped__ if hasattr(fa.bearer_token, "__wrapped__") else _REAL_BEARER

    class R:
        headers = {"authorization": "Bearer abc.def.ghi"}
    assert parse(R()) == "abc.def.ghi"

    class R2:
        headers = {"authorization": "Basic xyz"}
    assert parse(R2()) == ""


def test_normalize_marks_guest_and_provider():
    ident = fa.normalize({"user_id": "u", "firebase": {"sign_in_provider": "anonymous"}})
    assert ident["is_guest"] is True
    assert ident["uid"] == "u"

    ident2 = fa.normalize({"sub": "u2", "email_verified": True,
                           "firebase": {"sign_in_provider": "google.com"}})
    assert ident2["is_guest"] is False
    assert ident2["email_verified"] is True


def test_verified_email_required_for_password_only():
    assert fa.requires_verified_email({"provider": "password", "email_verified": False}) is True
    assert fa.requires_verified_email({"provider": "password", "email_verified": True}) is False
    assert fa.requires_verified_email({"provider": "google.com", "email_verified": False}) is False
    assert fa.requires_verified_email({"provider": "anonymous", "email_verified": False}) is False


def test_verify_rejects_empty_token():
    with pytest.raises(fa.AuthError):
        _REAL_VERIFY("")


# ══════════ البوابة في /ask ══════════
def test_token_path_accepted(client, monkeypatch):
    _fake_verify(monkeypatch)
    r = client.post("/ask", json=_body(code="لا-يهم"),
                    headers={"Authorization": "Bearer good-token"})
    assert r.status_code == 200
    assert "كود التفعيل" not in r.json()["answer"]


def test_unverified_email_blocked(client, monkeypatch):
    _fake_verify(monkeypatch, email_verified=False)
    r = client.post("/ask", json=_body(), headers={"Authorization": "Bearer t"})
    assert r.status_code == 403
    assert "فعّل بريدك" in r.json()["answer"]


def test_google_user_without_verified_flag_passes(client, monkeypatch):
    _fake_verify(monkeypatch, provider="google.com", email_verified=False)
    r = client.post("/ask", json=_body(), headers={"Authorization": "Bearer t"})
    assert r.status_code == 200


def test_invalid_token_rejected(client, monkeypatch):
    def boom(_t):
        raise fa.AuthError("⛔ جلستك انتهت. سجّل الدخول من جديد.")
    monkeypatch.setattr(fa, "verify", boom)
    r = client.post("/ask", json=_body(), headers={"Authorization": "Bearer bad"})
    assert r.status_code == 401
    assert "جلستك انتهت" in r.json()["answer"]


def test_no_token_is_rejected(client, anonymous):
    """🗑️ بلا توكن = 401. لا كود ولا استثناء ولا مسار جانبي."""
    r = client.post("/ask", json=_body())
    assert r.status_code == 401
    assert "تسجيل الدخول" in r.json()["answer"]


def test_activation_code_field_is_ignored_entirely(client, anonymous):
    """الكود القديم لم يعد يفتح شيئاً — حتى `SUPER_USER` نفسه.

    🔴 كان هذا الحقل يمنح **بلا حصة ولا حظر ولا تحقق بريد**، وقيمته مدفونة
       في التطبيق ⇒ من فكّ الـAPK فتح فاتورة الموديلات كلها.
    """
    for code in ("SUPER_USER", "MY_MASTER_CODE_2025", "1235353"):
        r = client.post("/ask", json=_body(code=code, device_id="d", user_id="u"))
        assert r.status_code == 401, f"«{code}» ما زال يفتح المسار!"


def test_client_cannot_choose_its_own_user_id(client, monkeypatch):
    """🔐 `user_id` من التوكن لا من الجسم — وإلا قرأ طالبٌ جلسة غيره.

    معالجات المواد تُمفتِح جلساتها بـ`req.user_id` (`sessions_math` وأخواتها)،
    فلو بقي قادماً من الطلب لكفى المهاجمَ أن يكتب معرّف ضحيته.
    """
    seen = {}

    async def _spy(req, *a, **k):
        seen["uid"] = req.user_id
        return {"answer": "ok", "references": [], "session_active": False}

    monkeypatch.setattr(api, "handle_physics_request", _spy)
    r = client.post("/ask", json=_body(user_id="uid-of-another-student"),
                    headers={"Authorization": "Bearer t"})
    assert r.status_code == 200
    assert seen["uid"] == "test-uid"          # هوية التوكن لا ما أرسله العميل


# ══════════ الحصة ══════════
def test_guest_gets_five_then_blocked():
    q.reset_memory()
    for i in range(q.GUEST_TOTAL_ASKS):
        allowed, remaining = q.check_and_consume("g1", is_guest=True)
        assert allowed, f"السؤال {i + 1} كان يجب أن يمر"
    allowed, remaining = q.check_and_consume("g1", is_guest=True)
    assert allowed is False and remaining == 0


def test_student_daily_limit():
    q.reset_memory()
    for _ in range(q.STUDENT_DAILY_ASKS):
        assert q.check_and_consume("s1", is_guest=False)[0]
    assert q.check_and_consume("s1", is_guest=False)[0] is False


def test_guest_counter_is_cumulative_not_daily():
    """الزائر: تجربة واحدة لا تتجدد يومياً — وإلا التفّ عليها بالانتظار."""
    assert "guest_" in q.doc_id("x", True)
    assert q.doc_id("x", True) == "guest_x"          # بلا تاريخ
    assert q.doc_id("x", False).startswith("x_20")   # بتاريخ اليوم


def test_quotas_are_isolated_per_user():
    q.reset_memory()
    for _ in range(q.GUEST_TOTAL_ASKS):
        q.check_and_consume("g1", is_guest=True)
    assert q.check_and_consume("g2", is_guest=True)[0] is True


def test_peek_does_not_consume():
    q.reset_memory()
    assert q.peek("s9") == q.STUDENT_DAILY_ASKS
    assert q.peek("s9") == q.STUDENT_DAILY_ASKS


def test_exhausted_guest_gets_429_with_signup_invite(client, monkeypatch):
    _fake_verify(monkeypatch, provider="anonymous", is_guest=True, uid="g-exhausted")
    q.reset_memory()
    for _ in range(q.GUEST_TOTAL_ASKS):
        q.check_and_consume("g-exhausted", is_guest=True)

    r = client.post("/ask", json=_body(), headers={"Authorization": "Bearer t"})
    assert r.status_code == 429
    data = r.json()
    assert data["quota_exceeded"] is True
    assert data["is_guest"] is True
    assert "سجّل حساباً" in data["answer"]


def test_every_authenticated_ask_consumes_quota(client):
    """🎟️ **لا مستخدمَ خارج الحصة بعد اليوم.**

    كان `if not identity.get("legacy")` يُخرج مستخدمي الكود منها كلياً —
    وهم كل من يعرف `SUPER_USER`. الآن الحصة تُخصم على الجميع بلا استثناء.
    """
    q.reset_memory()
    before = q.peek("test-uid")
    assert client.post("/ask", json=_body(),
                       headers={"Authorization": "Bearer t"}).status_code == 200
    assert q.peek("test-uid") == before - 1


def test_no_env_switch_can_reopen_the_code_gate(client, anonymous):
    """🔒 لا متغيّر بيئةٍ يعيد فتح المسار القديم — الرمز نفسه غير موجود."""
    assert not hasattr(api, "AUTH_ALLOW_LEGACY_CODE")
    assert client.post("/ask", json=_body()).status_code == 401

# ══════════════════════════════════════════════════
# 🧪 حساب الفحص — بلا حصّة
# ══════════════════════════════════════════════════
# 🔴 العلّة: المحاكي زائرٌ وحصّتُه تراكميةٌ في Firestore الحقيقي، فتنفد بعد
#    خمسة أسئلة ويتوقّف فحصُ قسمٍ كامل. والبديلُ السيّئ الذي **لم يُتّخذ**:
#    رفعُ `quota_guest` من اللوحة — وهي تمسّ كل زائرٍ حقيقيّ على الإنترنت.
#    فالاستثناءُ **بالهوية** لا بالحدّ، ومن البيئة لا من اللوحة.

def test_an_unlisted_uid_keeps_its_normal_limit(monkeypatch):
    monkeypatch.delenv("QUOTA_UNLIMITED_UIDS", raising=False)
    assert q.limit_for(True, "someone") == q.limit_for(True)
    assert q.limit_for(True, "someone") < q.UNLIMITED_ASKS


def test_a_listed_uid_has_no_limit_even_as_guest(monkeypatch):
    monkeypatch.setenv("QUOTA_UNLIMITED_UIDS", "sim-uid-1, sim-uid-2")
    assert q.limit_for(True, "sim-uid-1") == q.UNLIMITED_ASKS
    assert q.limit_for(False, "sim-uid-2") == q.UNLIMITED_ASKS
    # وغيرُهما لا يتأثّر — القائمةُ استثناءٌ لا مفتاحٌ عام.
    assert q.limit_for(True, "real-guest") < q.UNLIMITED_ASKS


def test_an_empty_list_changes_nothing(monkeypatch):
    """⚠️ الحارسُ الأهمّ: الإنتاجُ لا يضبط هذا المتغيّر، فيجب ألا يُغيّر شيئاً."""
    monkeypatch.setenv("QUOTA_UNLIMITED_UIDS", "")
    assert q.limit_for(True, "sim-uid-1") == q.limit_for(True)
    assert q.limit_for(False, "") == q.limit_for(False)


def test_a_listed_guest_really_gets_more_than_five_asks(monkeypatch):
    """لا يكفي أن يرتفع الرقم — لا بدّ أن **يمرّ** السؤالُ السادس فعلاً."""
    monkeypatch.setenv("QUOTA_UNLIMITED_UIDS", "sim-uid-1")
    q.reset_memory()
    for _ in range(12):
        allowed, _ = q.check_and_consume("sim-uid-1", True)
        assert allowed is True
