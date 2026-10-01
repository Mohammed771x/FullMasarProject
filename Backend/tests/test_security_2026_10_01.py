"""🔒 فحص الأمان 2026-10-01 — كلُّ علّةٍ مقيسةٍ هنا لها اختبارٌ يمنع عودتها.

١. فكُّ الحظر بحذف `users/{uid}` ([core/user_controls]).
٢. بريدُ الإدارة غير الموثَّق ([core/admin.is_admin_identity]).
٣. `/ingest` يُحلَّل قبل التوثيق ([core/body_limit._ingest_denial]).
٤. نداءاتُ الموديل من سكربتٍ لا من التطبيق ([core/app_check]).
٥. صورةُ Docker: الأسرار خارجها، وبايثون يبني المتطلّبات فعلاً.
"""
import pytest
from fastapi.testclient import TestClient

import api
from core import admin as adm
from core import firebase_auth as fa
from core import quota as q
from core import ratelimit as rl
from core import user_controls
from core import user_state
from tests.test_admin import HDR, _DB, seed


@pytest.fixture()
def db(monkeypatch):
    fake = _DB()
    monkeypatch.setattr(q, "_firestore", lambda: fake)
    return fake


@pytest.fixture()
def client(no_real_api_calls, monkeypatch):
    rl.reset()
    q.reset_memory()
    user_state.reset()
    monkeypatch.setattr(adm, "ADMIN_KEY", "s3cret-key")
    monkeypatch.setattr(adm, "ADMIN_EMAILS", set())
    return TestClient(api.app)


def _as_student(monkeypatch, uid="u1"):
    monkeypatch.setattr(fa, "verify", lambda t: {
        "uid": uid, "email": "", "email_verified": True,
        "provider": "password", "is_guest": False, "name": ""})


def _ask(client):
    return client.post("/ask", json={"subject": "فيزياء", "mode": "شرح",
                                     "input_type": "برومت", "content": "اشرح"},
                       headers={"Authorization": "Bearer t"})


def _student_deletes_own_doc(db, uid="u1"):
    """ما تسمح به القواعد لصاحب الحساب: `deleteDoc(doc(db,'users',uid))`."""
    db.cols["users"].pop(uid, None)
    user_state.reset()          # لا نعتمد على كاشٍ دافئ يُخفي العلّة


# ══════════════ ١. الحظر يصمد أمام حذف المستند ══════════════

def test_ban_survives_the_student_deleting_their_doc(client, db, monkeypatch):
    seed(db, uid="u1")
    client.post("/admin/users/u1/ban", json={"banned": True}, headers=HDR)
    assert db.cols["user_controls"]["u1"]["banned"] is True

    _student_deletes_own_doc(db)
    _as_student(monkeypatch)
    r = _ask(client)
    assert r.status_code == 403, "حذفُ المستند فكّ الحظر"


def test_ban_survives_delete_then_clean_recreate(client, db, monkeypatch):
    seed(db, uid="u1")
    client.post("/admin/users/u1/ban", json={"banned": True}, headers=HDR)
    _student_deletes_own_doc(db)
    seed(db, uid="u1")                      # مستندٌ جديد بلا `banned` — تسمح به القواعد
    user_state.reset()

    _as_student(monkeypatch)
    assert _ask(client).status_code == 403
    rows = client.get("/admin/users", headers=HDR).json()["users"]
    assert rows[0]["banned"] is True, "اللوحة تعرض المستند المُعاد إنشاؤه غير محظور"


def test_admin_can_unban_a_user_who_deleted_their_doc(client, db):
    seed(db, uid="u1")
    client.post("/admin/users/u1/ban", json={"banned": True}, headers=HDR)
    _student_deletes_own_doc(db)

    r = client.post("/admin/users/u1/ban", json={"banned": False}, headers=HDR)
    assert r.status_code == 200
    assert adm.is_banned("u1") is False
    assert "u1" not in db.cols["users"], "رفعُ الحظر أنشأ مستنداً فارغاً"


def test_quota_override_survives_delete(client, db):
    seed(db, uid="u1")
    client.post("/admin/users/u1/quota", json={"limit": 0}, headers=HDR)   # حظرٌ ليّن
    _student_deletes_own_doc(db)
    assert q.limit_for(False, "u1") == 0


def test_unban_wins_over_a_stale_users_copy(db):
    """الحَكَم هو `user_controls` لا «أو» — وإلا بقي المرفوعُ حظرُه محظوراً."""
    seed(db, uid="u1", banned=True)
    user_controls.write(db, "u1", banned=False)
    user_state.reset()
    assert adm.is_banned("u1") is False


def test_bans_from_before_this_change_still_hold(client, db, monkeypatch):
    """حسابٌ حُظر قديماً (`users/{uid}.banned` وحده) يبقى محظوراً."""
    seed(db, uid="u1", banned=True)
    _as_student(monkeypatch)
    assert _ask(client).status_code == 403


def test_unknown_uid_still_rejected(client, db):
    r = client.post("/admin/users/ghost/ban", json={"banned": True}, headers=HDR)
    assert r.status_code == 400
    assert "ghost" not in db.cols.get("user_controls", {})


def test_controls_reject_unknown_fields(db):
    with pytest.raises(ValueError):
        user_controls.write(db, "u1", role="admin")


def test_rules_deny_clients_on_user_controls():
    import os
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    for path in ("firestore.rules", "frontendappversion/firestore.rules"):
        rules = open(os.path.join(root, path), encoding="utf-8").read()
        block = rules.split("match /user_controls/{uid}", 1)[1].split("}", 1)[0]
        assert "allow read, write: if false;" in block, path


# ══════════════ ٢. بريد الإدارة يجب أن يكون موثَّقاً ══════════════

def _token_with(monkeypatch, email, verified, provider="password"):
    monkeypatch.setattr(fa, "verify", lambda t: {
        "uid": "x1", "email": email, "email_verified": verified,
        "provider": provider, "is_guest": False, "name": ""})


def test_unverified_admin_email_is_not_admin(client, db, monkeypatch):
    monkeypatch.setattr(adm, "ADMIN_EMAILS", {"boss@masar.test"})
    _token_with(monkeypatch, "Boss@Masar.test", verified=False)
    r = client.get("/admin/overview", headers={"Authorization": "Bearer t"})
    assert r.status_code == 401


def test_verified_admin_email_is_admin(client, db, monkeypatch):
    monkeypatch.setattr(adm, "ADMIN_EMAILS", {"boss@masar.test"})
    _token_with(monkeypatch, "boss@masar.test", verified=True, provider="google.com")
    r = client.get("/admin/overview", headers={"Authorization": "Bearer t"})
    assert r.status_code == 200


# ══════════════ ٣. `/ingest` مقفلةٌ قبل قراءة الجسم ══════════════

def _raw_call(path, headers, body=b"x" * 1024):
    """نداءٌ ASGI مباشر للوسيط وحده — كي نقيس هل قُرئ الجسم أصلاً."""
    import asyncio
    from core.body_limit import BodyLimitMiddleware

    state = {"read": 0, "status": None, "reached_app": False}

    async def app(scope, receive, send):
        state["reached_app"] = True
        while True:
            m = await receive()
            state["read"] += len(m.get("body", b""))
            if not m.get("more_body"):
                break
        await send({"type": "http.response.start", "status": 200, "headers": []})
        await send({"type": "http.response.body", "body": b"ok"})

    async def receive():
        state["read"] += len(body)
        return {"type": "http.request", "body": body, "more_body": False}

    async def send(msg):
        if msg["type"] == "http.response.start":
            state["status"] = msg["status"]

    scope = {"type": "http", "method": "POST", "path": path,
             "headers": [(k.lower().encode(), v.encode()) for k, v in headers.items()]}
    asyncio.run(BodyLimitMiddleware(app)(scope, receive, send))
    return state


@pytest.mark.parametrize("path", ["/ingest", "/ingest/run", "/ingest/save",
                                  "/ingest/targets"])
def test_ingest_is_off_unless_enabled(monkeypatch, path):
    monkeypatch.delenv("INGEST_ENABLED", raising=False)
    st = _raw_call(path, {"x-admin-key": "anything"})
    assert st["status"] == 404 and not st["reached_app"] and st["read"] == 0


def test_ingest_without_key_is_rejected_before_reading_the_body(monkeypatch):
    monkeypatch.setenv("INGEST_ENABLED", "1")
    monkeypatch.setattr(adm, "ADMIN_KEY", "k-test")
    huge = str(300 * 1024 * 1024)          # تحت سقف الأداة — فالسقفُ لا يرفضه
    for headers in ({"content-length": huge},
                    {"content-length": huge, "x-admin-key": "wrong"}):
        st = _raw_call("/ingest/run", headers)
        assert st["status"] == 401, headers
        assert st["read"] == 0 and not st["reached_app"], "قُرئ الجسم قبل التوثيق"


def test_ingest_with_key_passes_through(monkeypatch):
    monkeypatch.setenv("INGEST_ENABLED", "1")
    monkeypatch.setattr(adm, "ADMIN_KEY", "k-test")
    st = _raw_call("/ingest/run", {"x-admin-key": "k-test"})
    assert st["status"] == 200 and st["reached_app"]


def test_ingest_page_itself_needs_no_key_when_enabled(monkeypatch):
    """في الصفحة يُكتب المفتاح — فطلبُها بمفتاحٍ مستحيل."""
    monkeypatch.setenv("INGEST_ENABLED", "1")
    assert _raw_call("/ingest", {})["status"] == 200


def test_other_paths_untouched_by_the_ingest_gate(monkeypatch):
    monkeypatch.delenv("INGEST_ENABLED", raising=False)
    for path in ("/ask", "/admin", "/ingestion-not-ours"):
        assert _raw_call(path, {})["status"] == 200, path


def test_admin_pages_carry_security_headers(client):
    r = client.get("/admin")
    assert r.status_code == 200
    csp = r.headers["content-security-policy"]
    assert "connect-src 'self'" in csp and "frame-ancestors 'none'" in csp
    assert r.headers["x-frame-options"] == "DENY"
    assert r.headers["x-content-type-options"] == "nosniff"


# ══════════════ ٤. App Check ══════════════

import base64 as _b64
import json as _json

from core import app_check


def _id_token(provider):
    """توكنٌ بشكل JWT — يكفي لقراءة المطالبات بلا تحقق (والتحقق في `_authenticate`)."""
    claims = {"firebase": {"sign_in_provider": provider}, "user_id": "u1"}
    body = _b64.urlsafe_b64encode(_json.dumps(claims).encode()).decode().rstrip("=")
    return f"h.{body}.sig"


@pytest.fixture()
def fake_verifier(monkeypatch):
    """«good» توكنٌ سليم، وما عداه فاسد — بلا شبكةٍ ولا Admin SDK."""
    app_check.reset()

    def verify(token):
        if token == "good":
            import time
            return time.time() + 3600
        if token == "boom":
            raise app_check.Unverifiable("لا حساب خدمة")
        raise ValueError("bad token")
    monkeypatch.setattr(app_check, "_verify_now", verify)
    yield
    app_check.reset()


def _mw_call(path, headers, method="POST"):
    import asyncio
    state = {"status": None, "reached": False}

    async def app(scope, receive, send):
        state["reached"] = True
        await send({"type": "http.response.start", "status": 200, "headers": []})
        await send({"type": "http.response.body", "body": b"ok"})

    async def receive():
        return {"type": "http.request", "body": b"{}", "more_body": False}

    async def send(msg):
        if msg["type"] == "http.response.start":
            state["status"] = msg["status"]

    scope = {"type": "http", "method": method, "path": path,
             "headers": [(k.lower().encode(), v.encode()) for k, v in headers.items()]}
    asyncio.run(app_check.AppCheckMiddleware(app)(scope, receive, send))
    return state


GUEST = {"authorization": "Bearer " + _id_token("anonymous")}
MEMBER = {"authorization": "Bearer " + _id_token("google.com")}


def test_monitor_mode_blocks_nobody_but_counts(monkeypatch, fake_verifier):
    monkeypatch.delenv("APP_CHECK_MODE", raising=False)      # الافتراضي
    assert app_check.mode() == "monitor"
    assert _mw_call("/ask", GUEST)["status"] == 200
    assert _mw_call("/ask", {**GUEST, "x-firebase-appcheck": "forged"})["status"] == 200
    assert app_check.stats()["missing"] == 1 and app_check.stats()["invalid"] == 1


@pytest.mark.parametrize("path", sorted(app_check.MODEL_PATHS))
def test_all_mode_blocks_every_model_path_without_a_valid_token(monkeypatch, fake_verifier, path):
    monkeypatch.setenv("APP_CHECK_MODE", "all")
    for headers in (MEMBER, {**MEMBER, "x-firebase-appcheck": "forged"}):
        st = _mw_call(path, headers)
        assert st["status"] == 401 and not st["reached"], path
    assert _mw_call(path, {**MEMBER, "x-firebase-appcheck": "good"})["status"] == 200


def test_guests_mode_targets_anonymous_accounts_only(monkeypatch, fake_verifier):
    monkeypatch.setenv("APP_CHECK_MODE", "guests")
    assert _mw_call("/ask/stream", GUEST)["status"] == 401
    assert _mw_call("/ask/stream", {})["status"] == 401, "بلا توكنٍ أصلاً = زائرٌ في الشك"
    assert _mw_call("/ask/stream", {**GUEST, "x-firebase-appcheck": "good"})["status"] == 200
    assert _mw_call("/ask/stream", MEMBER)["status"] == 200


def test_cheap_and_read_paths_are_never_checked(monkeypatch, fake_verifier):
    monkeypatch.setenv("APP_CHECK_MODE", "all")
    for path, method in (("/subjects/units", "GET"), ("/me/quota", "GET"),
                         ("/me/device", "POST"), ("/ask", "GET")):
        assert _mw_call(path, {}, method)["status"] == 200, path


def test_our_own_misconfiguration_fails_open(monkeypatch, fake_verifier):
    """خادمٌ بلا حساب خدمة لا يُطفئ المنصّة — يمرّ مع تحذير."""
    monkeypatch.setenv("APP_CHECK_MODE", "all")
    assert _mw_call("/ask", {**MEMBER, "x-firebase-appcheck": "boom"})["status"] == 200
    assert app_check.stats()["unverifiable"] == 1


def test_valid_token_is_verified_once_then_cached(monkeypatch, fake_verifier):
    calls = []
    real = app_check._verify_now
    monkeypatch.setattr(app_check, "_verify_now", lambda t: calls.append(t) or real(t))
    monkeypatch.setenv("APP_CHECK_MODE", "all")
    for _ in range(5):
        assert _mw_call("/ask", {**MEMBER, "x-firebase-appcheck": "good"})["status"] == 200
    assert calls == ["good"]


def test_app_check_middleware_is_mounted(client, monkeypatch, fake_verifier):
    """مُركَّبٌ في التطبيق الحقيقي لا في الاختبار وحده — ورفضُه يصل قبل التوثيق."""
    monkeypatch.setenv("APP_CHECK_MODE", "all")
    r = client.post("/ask", json={"subject": "فيزياء", "mode": "شرح",
                                  "input_type": "برومت", "content": "x"})
    assert r.status_code == 401 and r.json().get("app_check_failed") is True


def test_forged_tokens_are_invalid_not_unverifiable(monkeypatch):
    """☢️ المزوّر بمعرّف مفتاحٍ مجهول يرمي `PyJWKClientError` — وكان يُعدّ عطلاً
    عندنا فيمرّ مفتوحاً. انقطاعُ الاتصال وحده هو العطل."""
    import firebase_admin
    import jwt
    from firebase_admin import app_check as fb_ac
    monkeypatch.setattr(firebase_admin, "_apps", {"[DEFAULT]": object()})
    monkeypatch.setattr(q, "_firestore", lambda: None)

    for exc in (jwt.PyJWKClientError('Unable to find a signing key that matches: "x"'),
                ValueError("bad signature"), RuntimeError("anything else")):
        monkeypatch.setattr(fb_ac, "verify_token", lambda t, e=exc: (_ for _ in ()).throw(e))
        with pytest.raises(ValueError):
            app_check._verify_now("t")

    monkeypatch.setattr(fb_ac, "verify_token", lambda t: (_ for _ in ()).throw(
        jwt.PyJWKClientConnectionError("network down")))
    with pytest.raises(app_check.Unverifiable):
        app_check._verify_now("t")



# ══════════════ ٥. Docker والنشر ══════════════

import os as _os
import re as _re

_BACKEND = _os.path.dirname(_os.path.dirname(_os.path.abspath(__file__)))


def _read(name):
    return open(_os.path.join(_BACKEND, name), encoding="utf-8").read()


def test_dockerignore_keeps_secrets_out_of_the_image():
    lines = {l.strip() for l in _read(".dockerignore").splitlines()
             if l.strip() and not l.startswith("#")}
    for must in (".env", ".env.*", ".dev_store.json", ".venv/", "*.log", "tests/", "tools/"):
        assert must in lines, must


def test_dockerfile_python_can_build_the_pinned_requirements():
    """numpy 2.3 وscipy 1.16 تحتاجان 3.11+ — و3.9 كانت تُسقط البناء بصمت."""
    m = _re.search(r"^FROM python:(\d+)\.(\d+)", _read("Dockerfile"), _re.M)
    assert m and (int(m.group(1)), int(m.group(2))) >= (3, 11)
    assert "INGEST_ENABLED=0" in _read("Dockerfile")


def test_no_compiled_only_or_unused_heavy_packages():
    assert "llama_cpp_python" not in _read("requirements.txt")
