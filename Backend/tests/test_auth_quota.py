"""بوابة التوثيق (توكن Firebase) والحصة اليومية — بديل نظام الأكواد."""
import pytest
from fastapi.testclient import TestClient

import api
from core import ratelimit as rl
from core import firebase_auth as fa
from core import quota as q


@pytest.fixture()
def client(no_real_api_calls):
    rl._buckets.clear()
    q.reset_memory()
    return TestClient(api.app)


def _body(**over):
    body = {
        "user_id": "u1", "code": "SUPER_USER", "device_id": "d1",
        "subject": "فيزياء", "mode": "شرح", "input_type": "برومت",
        "summary_level": 3, "content": "اشرح", "unit_name": "", "lesson_name": "",
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
    class R:
        headers = {"authorization": "Bearer abc.def.ghi"}
    assert fa.bearer_token(R()) == "abc.def.ghi"

    class R2:
        headers = {"authorization": "Basic xyz"}
    assert fa.bearer_token(R2()) == ""


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
        fa.verify("")


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


def test_legacy_code_still_works_during_transition(client):
    r = client.post("/ask", json=_body())
    assert r.status_code == 200


def test_legacy_code_rejected_when_switched_off(client, monkeypatch):
    monkeypatch.setattr(api, "AUTH_ALLOW_LEGACY_CODE", False)
    r = client.post("/ask", json=_body())
    assert r.status_code == 401
    assert "تسجيل الدخول" in r.json()["answer"]


def test_bad_code_rejected(client):
    r = client.post("/ask", json=_body(code="كود-مزيف"))
    assert r.status_code == 401


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


def test_legacy_users_are_outside_quota(client):
    """مستخدم بالكود لا تُحتسب عليه حصة — كي لا يُحرم فجأة قبل الترقية."""
    q.reset_memory()
    for _ in range(3):
        assert client.post("/ask", json=_body()).status_code == 200
    assert q.peek("legacy:u1") == q.STUDENT_DAILY_ASKS


def test_missing_google_auth_falls_back_to_code(client, monkeypatch):
    """نشر ناقص (بلا google-auth) لا يُسقط كل المستخدمين — الكود القديم يعمل."""
    monkeypatch.setattr(fa, "available", lambda: False)
    r = client.post("/ask", json=_body(), headers={"Authorization": "Bearer whatever"})
    assert r.status_code == 200


def test_missing_google_auth_with_code_off_is_rejected(client, monkeypatch):
    """وإن كان الكود مُطفأً، يُرفض الطلب بوضوح بدل تمريره بلا توثيق."""
    monkeypatch.setattr(fa, "available", lambda: False)
    monkeypatch.setattr(api, "AUTH_ALLOW_LEGACY_CODE", False)
    r = client.post("/ask", json=_body(), headers={"Authorization": "Bearer whatever"})
    assert r.status_code == 401
