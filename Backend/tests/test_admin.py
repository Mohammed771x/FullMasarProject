"""🛡️ لوحة التحكم: الصلاحية أولاً، ثم صحّة الأرقام، ثم أثر الإجراءات.

الاختبار الأهم هنا ليس شكل الأرقام بل **البوابة**: مسارٌ إداري مفتوح
يكشف كل مستخدمي المنصّة. لذلك نبدأ بالرفض ثم نسمح.
"""
import pytest
from fastapi.testclient import TestClient

import api
from core import admin as adm
from core import quota as q
from core import ratelimit as rl


# ══════════ Firestore وهمي في الذاكرة ══════════
# يكفي منه ما تستعمله `admin.py`: collection · document · get · set · stream

class _Snap:
    def __init__(self, doc_id, data):
        self.id = doc_id
        self._data = data
        self.exists = data is not None

    def to_dict(self):
        return dict(self._data or {})


class _Doc:
    def __init__(self, col, doc_id):
        self._col, self.id = col, doc_id

    def get(self):
        return _Snap(self.id, self._col.data.get(self.id))

    def set(self, patch, merge=False):
        cur = dict(self._col.data.get(self.id) or {}) if merge else {}
        cur.update(patch)
        self._col.data[self.id] = cur


class _Col:
    def __init__(self, data):
        self.data = data

    def document(self, doc_id):
        return _Doc(self, doc_id)

    def stream(self):
        return [_Snap(k, v) for k, v in self.data.items()]


class _DB:
    def __init__(self):
        self.cols = {"users": {}, "usage": {}}

    def collection(self, name):
        return _Col(self.cols.setdefault(name, {}))


@pytest.fixture()
def db(monkeypatch):
    fake = _DB()
    monkeypatch.setattr(q, "_firestore", lambda: fake)
    return fake


@pytest.fixture()
def client(no_real_api_calls, monkeypatch):
    rl._buckets.clear()
    q.reset_memory()
    monkeypatch.setattr(adm, "ADMIN_KEY", "s3cret-key")
    monkeypatch.setattr(adm, "ADMIN_EMAILS", set())
    return TestClient(api.app)


HDR = {"X-Admin-Key": "s3cret-key"}


def seed(db, *, uid="u1", name="طالب", email="a@b.c", asks=None, **extra):
    db.cols["users"][uid] = {"name": name, "email": email, "grade": 3,
                             "track": "علمي", **extra}
    for day, n in (asks or {}).items():
        db.cols["usage"][f"{uid}_{day}"] = {"asks": n}
    return uid


# ══════════════ البوابة ══════════════

@pytest.mark.parametrize("path", [
    "/admin/overview", "/admin/users", "/admin/users/u1",
])
def test_reads_require_admin(client, db, path):
    assert client.get(path).status_code == 401


def test_writes_require_admin(client, db):
    assert client.post("/admin/users/u1/ban", json={"banned": True}).status_code == 401
    assert client.post("/admin/users/u1/quota", json={"limit": 5}).status_code == 401


def test_wrong_key_rejected(client, db):
    r = client.get("/admin/overview", headers={"X-Admin-Key": "s3cret-keyX"})
    assert r.status_code == 401


def test_gate_closed_when_nothing_configured(client, db, monkeypatch):
    """بلا ADMIN_KEY ولا ADMIN_EMAILS ⇒ اللوحة مغلقة لا مفتوحة."""
    monkeypatch.setattr(adm, "ADMIN_KEY", "")
    monkeypatch.setattr(adm, "ADMIN_EMAILS", set())
    r = client.get("/admin/overview", headers=HDR)
    assert r.status_code == 503
    assert "غير مفعّلة" in r.json()["error"]


def test_admin_by_firestore_role(client, db, monkeypatch):
    """حساب دوره admin يدخل بتوكنه بلا مفتاح."""
    db.cols["users"]["boss"] = {"role": "admin", "name": "المالك"}
    from core import firebase_auth as fa
    monkeypatch.setattr(fa, "verify", lambda t: {
        "uid": "boss", "email": "", "email_verified": True,
        "provider": "password", "is_guest": False, "name": ""})
    r = client.get("/admin/overview", headers={"Authorization": "Bearer t"})
    assert r.status_code == 200


def test_plain_student_token_is_not_admin(client, db, monkeypatch):
    db.cols["users"]["kid"] = {"role": "student", "name": "طالب"}
    from core import firebase_auth as fa
    monkeypatch.setattr(fa, "verify", lambda t: {
        "uid": "kid", "email": "", "email_verified": True,
        "provider": "password", "is_guest": False, "name": ""})
    assert client.get("/admin/overview",
                      headers={"Authorization": "Bearer t"}).status_code == 401


# ══════════════ الأرقام ══════════════

def test_overview_counts_and_series(client, db):
    from core.admin import _today
    today = _today()
    seed(db, uid="u1", asks={today: 4, "2020-01-01": 6})
    seed(db, uid="u2", name="ثانٍ", asks={"2020-01-01": 3})
    db.cols["usage"]["guest_g1"] = {"asks": 2}

    d = client.get("/admin/overview", headers=HDR).json()
    assert d["users"] == 2
    assert d["asks_today"] == 4
    assert d["asks_total"] == 13          # 4+6+3
    assert d["guest_asks_total"] == 2
    assert d["requests_total"] == 15
    assert d["active_today"] == 1
    assert d["guests"] == 1
    assert len(d["series"]) == 30
    assert d["series"][-1]["day"] == today


def test_series_has_no_gaps(client, db):
    """أيامٌ بلا استخدام تظهر أصفاراً — وإلا كذب الرسم البياني."""
    d = client.get("/admin/overview?days=7", headers=HDR).json()
    assert [p["asks"] for p in d["series"]] == [0] * 7


def test_users_list_sorted_by_today(client, db):
    from core.admin import _today
    today = _today()
    seed(db, uid="quiet", name="هادئ", asks={today: 1})
    seed(db, uid="busy", name="نشط", asks={today: 9, "2020-01-01": 2})

    rows = client.get("/admin/users", headers=HDR).json()["users"]
    assert [r["uid"] for r in rows] == ["busy", "quiet"]
    assert rows[0]["asks_today"] == 9
    assert rows[0]["asks_total"] == 11
    assert rows[0]["active_days"] == 2


def test_users_search_matches_name_email_uid(client, db):
    seed(db, uid="aaa", name="سالم", email="salem@x.com")
    seed(db, uid="bbb", name="نورة", email="noura@x.com")
    for needle, expect in [("سالم", "aaa"), ("noura", "bbb"), ("aaa", "aaa")]:
        rows = client.get(f"/admin/users?search={needle}", headers=HDR).json()["users"]
        assert [r["uid"] for r in rows] == [expect], needle


def test_user_detail_series_is_that_user_only(client, db):
    from core.admin import _today
    today = _today()
    seed(db, uid="u1", asks={today: 5})
    seed(db, uid="u2", name="آخر", asks={today: 99})

    d = client.get("/admin/users/u1", headers=HDR).json()
    assert d["asks_total"] == 5
    assert d["series"][-1]["asks"] == 5, "تسرّب استخدام مستخدم آخر"


def test_unknown_user_gives_arabic_error(client, db):
    r = client.get("/admin/users/ghost", headers=HDR)
    assert r.status_code == 400
    assert "لا يوجد مستخدم" in r.json()["error"]


# ══════════════ الإجراءات وأثرها ══════════════

def test_ban_then_unban_persists(client, db):
    seed(db, uid="u1")
    assert client.post("/admin/users/u1/ban", json={"banned": True},
                       headers=HDR).json()["banned"] is True
    assert db.cols["users"]["u1"]["banned"] is True
    assert adm.is_banned("u1") is True

    client.post("/admin/users/u1/ban", json={"banned": False}, headers=HDR)
    assert adm.is_banned("u1") is False


def test_banned_user_is_blocked_at_the_gate(client, db, monkeypatch):
    """⭐ الحظر يجب أن يمنع الطلب فعلاً — لا أن يظهر في اللوحة وحدها."""
    seed(db, uid="u1", banned=True)
    from core import firebase_auth as fa
    monkeypatch.setattr(fa, "verify", lambda t: {
        "uid": "u1", "email": "", "email_verified": True,
        "provider": "password", "is_guest": False, "name": ""})

    r = client.post("/ask", json={"user_id": "u1", "code": "x", "device_id": "d",
                                  "subject": "فيزياء", "mode": "شرح",
                                  "input_type": "برومت", "content": "اشرح"},
                    headers={"Authorization": "Bearer t"})
    assert r.status_code == 403
    assert "موقوف" in r.json()["answer"]


def test_quota_override_changes_the_real_limit(client, db):
    seed(db, uid="u1")
    assert q.limit_for(False, "u1") == q.STUDENT_DAILY_ASKS

    client.post("/admin/users/u1/quota", json={"limit": 3}, headers=HDR)
    assert q.limit_for(False, "u1") == 3, "الحدّ الخاص لم يسرِ على الحصة"

    client.post("/admin/users/u1/quota", json={"limit": None}, headers=HDR)
    assert q.limit_for(False, "u1") == q.STUDENT_DAILY_ASKS


def test_quota_rejects_out_of_range(client, db):
    seed(db, uid="u1")
    assert client.post("/admin/users/u1/quota", json={"limit": -5},
                       headers=HDR).status_code == 422


def test_guest_limit_untouched_by_override(client, db):
    seed(db, uid="u1")
    client.post("/admin/users/u1/quota", json={"limit": 1}, headers=HDR)
    assert q.limit_for(True, "u1") == q.GUEST_TOTAL_ASKS


# ══════════════ الصفحة ══════════════

def test_admin_page_is_served(client):
    r = client.get("/admin")
    assert r.status_code == 200
    assert "لوحة تحكم مسار" in r.text
