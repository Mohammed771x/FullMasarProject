"""📊 لوحة التحكم — التحليلات · الشرائح · الوصول · الإشعارات.

الترتيب مقصود كما في [test_admin]: **البوابة أولاً**، ثم صدق الأرقام، ثم
أثر القواعد الحقيقي. ومسارٌ إداريٌّ واحدٌ مفتوح يكشف المنصّة كلها — فلا
يُختبر شيءٌ قبله.

⭐ والاختبار الثاني في الأهمية هنا: **أن الرقم الغائب يُقال غائباً**. أسهل
   ما تنكسر به لوحةُ إحصاءات ألّا تنكسر: تعرض صفراً هادئاً بدل «لا بيانات»،
   فيطمئن المالك إلى ما لا يعرفه.
"""
import pytest
from fastapi.testclient import TestClient

import api
from core import access as acc
from core import admin as adm
from core import analytics as ana
from core import audience as aud
from core import firebase_auth as fa
from core import notifications as notif
from core import quota as q
from core import ratelimit as rl
from core import scholarships as sch


# ══════════ Firestore وهمي — بفروعٍ ومجموعاتِ فروع ══════════
# نسخةٌ أغنى من فخّ [test_admin]: التحليلات تقرأ `users/{uid}/results`
# بـ`collection_group`، ولا يُختبر ذلك بمخزنٍ مسطّح.

class _Snap:
    def __init__(self, doc_id, data, reference=None):
        self.id = doc_id
        self._data = data
        self.exists = data is not None
        self.reference = reference

    def to_dict(self):
        return dict(self._data or {})


class _Doc:
    def __init__(self, col, doc_id):
        self._col, self.id = col, doc_id

    @property
    def parent(self):
        return self._col

    def get(self):
        return _Snap(self.id, self._col.store.get(self.id), self)

    def set(self, patch, merge=False):
        cur = dict(self._col.store.get(self.id) or {}) if merge else {}
        cur.update(patch)
        self._col.store[self.id] = cur

    def delete(self):
        self._col.store.pop(self.id, None)

    def collection(self, name):
        return _Col(self._col.db, name, (self._col.name, self.id))


class _Col:
    def __init__(self, db, name, owner=None):
        self.db, self.name, self.owner = db, name, owner
        self.store = db.bucket(name, owner)

    @property
    def parent(self):
        """`users/{uid}/results` ⇒ مستندُ المستخدم — عليه يقوم فلتر الشريحة."""
        if not self.owner:
            return None
        return _Doc(_Col(self.db, self.owner[0]), self.owner[1])

    def document(self, doc_id):
        return _Doc(self, doc_id)

    def stream(self):
        return [_Snap(k, v, _Doc(self, k)) for k, v in list(self.store.items())]


class _Group:
    def __init__(self, db, name, fail=False):
        self.db, self.name, self.fail = db, name, fail

    def select(self, fields):
        return self

    def stream(self):
        if self.fail:
            raise RuntimeError("فهرس مفقود")
        for (parent_col, parent_id, sub), store in list(self.db.subs.items()):
            if sub != self.name:
                continue
            col = _Col(self.db, sub, (parent_col, parent_id))
            for k, v in list(store.items()):
                yield _Snap(k, v, _Doc(col, k))


class _DB:
    def __init__(self):
        self.cols = {}
        self.subs = {}
        self.broken_groups = set()

    def bucket(self, name, owner=None):
        if owner is None:
            return self.cols.setdefault(name, {})
        return self.subs.setdefault((owner[0], owner[1], name), {})

    def collection(self, name):
        return _Col(self, name)

    def collection_group(self, name):
        return _Group(self, name, fail=name in self.broken_groups)


@pytest.fixture(autouse=True)
def clean_caches():
    """⚠️ الكاش يعبر الاختبارات إن لم يُمسح: اختبارٌ يسأل «ماذا لو غابت
    Firestore؟» فيتلقّى جواب اختبارٍ سابقٍ محفوظاً — فيمرّ وهو كاذب."""
    ana.invalidate()
    acc.invalidate()
    acc.forget_profile()
    yield
    ana.invalidate()
    acc.invalidate()
    acc.forget_profile()


@pytest.fixture()
def db(monkeypatch):
    fake = _DB()
    monkeypatch.setattr(q, "_firestore", lambda: fake)
    ana.invalidate()
    acc.invalidate()
    acc.forget_profile()
    sch._settings_cache["data"] = None
    sch._settings_cache["ts"] = 0.0
    return fake


@pytest.fixture()
def client(no_real_api_calls, monkeypatch):
    rl._buckets.clear()
    q.reset_memory()
    monkeypatch.setattr(adm, "ADMIN_KEY", "s3cret-key")
    monkeypatch.setattr(adm, "ADMIN_EMAILS", set())
    return TestClient(api.app)


HDR = {"X-Admin-Key": "s3cret-key"}
TODAY = ana._today()
YESTERDAY = ana._day_of(1)


def user(db, uid, *, grade=3, track="علمي", role="student", banned=False,
         asks=None, name=None, **extra):
    db.cols.setdefault("users", {})[uid] = {
        "name": name or uid, "email": f"{uid}@t.c", "grade": grade,
        "track": track, "role": role, "banned": banned, **extra}
    for day, n in (asks or {}).items():
        db.cols.setdefault("usage", {})[f"{uid}_{day}"] = {"asks": n}


def result(db, uid, rid, **fields):
    payload = {"subject": "احياء", "grade": 3, "track": "علمي", "unit": "و1",
               "lessons": ["د1"], "score": 8, "total": 10, "duration_sec": 300,
               "wrong": [], "asked_per_lesson": {"د1": 10},
               "created_at": TODAY + "T10:00:00"}
    payload.update(fields)
    db.subs.setdefault(("users", uid, "results"), {})[rid] = payload


# ══════════════════════════════════════════════════
# 🔒 ١ — البوابة: قبل أي رقم
# ══════════════════════════════════════════════════

NEW_GETS = ["/admin/analytics", "/admin/segments", "/admin/access",
            "/admin/notifications"]


@pytest.mark.parametrize("path", NEW_GETS)
def test_new_endpoints_reject_without_key(client, path):
    assert client.get(path).status_code == 401


@pytest.mark.parametrize("path", NEW_GETS)
def test_new_endpoints_reject_wrong_key(client, path):
    assert client.get(path, headers={"X-Admin-Key": "nope"}).status_code == 401


def test_new_write_endpoints_reject_without_key(client):
    assert client.post("/admin/access/quiz", json={"mode": "off"}).status_code == 401
    assert client.post("/admin/access/quiz/rules", json={"rules": []}).status_code == 401
    assert client.post("/admin/notifications", json={"title": "x", "body": "y"}).status_code == 401
    assert client.post("/admin/notifications/preview", json={}).status_code == 401
    assert client.delete("/admin/notifications/abc").status_code == 401


def test_closed_panel_locks_new_endpoints(client, monkeypatch):
    """بلا ADMIN_KEY ولا ADMIN_EMAILS: مغلقةٌ تماماً — لا وضع مفتوح افتراضياً."""
    monkeypatch.setattr(adm, "ADMIN_KEY", "")
    monkeypatch.setattr(adm, "ADMIN_EMAILS", set())
    for path in NEW_GETS:
        assert client.get(path, headers=HDR).status_code == 503


def test_plain_student_is_not_admin(client, db, monkeypatch):
    """طالبٌ عادي بتوكن صحيح ليس مديراً — الدور من Firestore لا من التوكن."""
    user(db, "u1", role="student")
    monkeypatch.setattr(fa, "verify", lambda t: {"uid": "u1", "email": "u1@t.c"})
    r = client.get("/admin/analytics", headers={"Authorization": "Bearer x"})
    assert r.status_code == 401


# ══════════════════════════════════════════════════
# 🎯 ٢ — الشرائح: تعريفٌ واحد للجميع
# ══════════════════════════════════════════════════

def test_segment_definitions_are_shared():
    """⭐ الشريحة نفسها في الجدول والإشعار والقاعدة — وإلا اختلفت الأعداد."""
    u = {"uid": "x", "grade": 3, "track": "علمي", "role": "student"}
    assert aud.matches("g3_sci", u, {})
    assert not aud.matches("g3_lit", u, {})
    assert aud.matches_profile("g3_sci", 3, "علمي")
    assert not aud.matches_profile("g3_sci", 3, "أدبي")


def test_teachers_segment_separates_roles():
    """🎭 «المعلمون» شريحةٌ قائمة بذاتها، ولا يتقاطع مع «الطلاب» أحد."""
    teacher = {"uid": "t", "grade": 3, "track": "علمي", "role": "teacher"}
    student = {"uid": "s", "grade": 3, "track": "علمي", "role": "student"}

    assert aud.matches("teachers", teacher, {})
    assert not aud.matches("teachers", student, {})
    assert aud.matches("students", student, {})
    assert not aud.matches("students", teacher, {})

    # ⚠️ وشرائح الصفوف للطلاب وحدهم: معلّمٌ يُدرّس الثالث ليس «طالب ثالث»،
    #    فإشعارٌ لـ«ثالث علمي» لا يصل إليه ولا يُحسب في عددهم.
    assert not aud.matches("g3_sci", teacher, {})

    assert aud.matches_profile("teachers", 3, "علمي", "teacher")
    assert not aud.matches_profile("teachers", 3, "علمي", "student")


def test_teachers_segment_is_valid_access_rule():
    """الدور ثابتٌ في المستند لا يتقلّب بالنشاط ⇒ يصلح قاعدةَ إخفاء."""
    assert aud.validate("teachers", for_access=True) == "teachers"
    assert "teachers" in aud.ACCESS_SEGMENTS


def test_admin_is_neither_student_nor_teacher():
    """المدير خارج الشريحتين — وإلا حُسب في أعداد الطلاب أو المعلمين."""
    admin = {"uid": "a", "grade": 3, "track": "علمي", "role": "admin"}
    assert not aud.matches("students", admin, {})
    assert not aud.matches("teachers", admin, {})
    assert aud.matches("admins", admin, {})


def test_activity_segments_rejected_for_access_rules():
    """«غير نشط» تتغيّر كل يوم — قسمٌ يظهر ويختفي بها سلوكٌ لا يُفهم."""
    with pytest.raises(aud.AudienceError):
        aud.validate("inactive", for_access=True)
    assert aud.validate("inactive") == "inactive"      # للإشعار: مسموحة


def test_unknown_segment_raises():
    with pytest.raises(aud.AudienceError):
        aud.validate("g9_ultra")


# ══════════════════════════════════════════════════
# 📈 ٣ — التحليلات: أرقامٌ صادقة أو فراغٌ صريح
# ══════════════════════════════════════════════════

def test_analytics_counts_real_users_and_activity(client, db):
    user(db, "a", asks={TODAY: 5, YESTERDAY: 2})
    user(db, "b", asks={YESTERDAY: 3})
    user(db, "c")
    d = client.get("/admin/analytics?days=7", headers=HDR).json()

    assert d["users"]["total"] == 3
    assert d["users"]["dau"] == 1                    # «a» وحده سأل اليوم
    assert d["users"]["wau"] == 2                    # «a» و«b»
    assert d["asks"]["today"] == 5
    assert d["asks"]["in_period"] == 10
    assert len(d["asks"]["series"]) == 7             # بلا فجوات
    assert d["asks"]["series"][-1] == {"day": TODAY, "asks": 5}


def test_analytics_segment_filters_everything(client, db):
    user(db, "sci", grade=3, track="علمي", asks={TODAY: 7})
    user(db, "lit", grade=3, track="أدبي", asks={TODAY: 4})
    user(db, "first", grade=1, track="عام", asks={TODAY: 9})

    d = client.get("/admin/analytics?segment=g3_sci", headers=HDR).json()
    assert d["segment"]["users"] == 1
    # ⭐ الأسئلة تتبع الشريحة أيضاً — لا رقمٌ عامٌّ تحت عنوانٍ خاص
    assert d["asks"]["today"] == 7
    assert d["users"]["total_platform"] == 3


def test_analytics_never_leaks_other_students_results(client, db):
    """نتيجةُ ثالثٍ أدبي لا تدخل أرقام ثالثٍ علمي — الفلتر بصاحب المستند."""
    user(db, "sci", grade=3, track="علمي")
    user(db, "lit", grade=3, track="أدبي")
    result(db, "sci", "r1", subject="احياء", score=9, total=10)
    result(db, "lit", "r2", subject="تاريخ", score=2, total=10)

    d = client.get("/admin/analytics?segment=g3_sci", headers=HDR).json()
    assert d["quiz"]["count"] == 1
    assert [x["subject"] for x in d["quiz"]["by_subject"]] == ["احياء"]
    assert d["quiz"]["avg_percent"] == 90.0


def test_quiz_metrics_rank_weak_lessons_by_rate_not_count(client, db):
    """⭐ تسعةُ أخطاء من مئة سؤال أهون من خطأين من ثلاثة — النسبة لا العدد."""
    user(db, "s")
    result(db, "s", "r1", subject="فيزياء",
           lessons=["كثير"], asked_per_lesson={"كثير": 100}, total=100, score=91,
           wrong=[{"lesson": "كثير"}] * 9)
    result(db, "s", "r2", subject="فيزياء",
           lessons=["قليل"], asked_per_lesson={"قليل": 12}, total=12, score=4,
           wrong=[{"lesson": "قليل"}] * 8)

    weak = client.get("/admin/analytics", headers=HDR).json()["quiz"]["weak_lessons"]
    assert weak[0]["lesson"] == "قليل"               # ٦٦٪ خطأ
    assert weak[0]["wrong"] < weak[1]["wrong"]       # ومع ذلك أخطاؤه أقل عدداً


def test_weak_lessons_ignore_tiny_samples(client, db):
    """درسٌ بثلاثة أسئلة لا يتصدّر «الأصعب» — الصدفة ليست ضعفاً."""
    user(db, "s")
    result(db, "s", "r1", lessons=["نادر"], asked_per_lesson={"نادر": 3},
           total=3, score=0, wrong=[{"lesson": "نادر"}] * 3)
    d = client.get("/admin/analytics", headers=HDR).json()["quiz"]
    assert d["weak_lessons"] == []
    assert d["count"] == 1                            # الاختبار نفسه محسوب


def test_best_worst_subjects_need_enough_quizzes(client, db):
    """اختبارٌ واحدٌ بدرجةٍ كاملة ليس «أفضل مادة»."""
    user(db, "s")
    result(db, "s", "solo", subject="جغرافيا", score=10, total=10)
    for i in range(3):
        result(db, "s", f"m{i}", subject="رياضيات", score=5, total=10)
    d = client.get("/admin/analytics", headers=HDR).json()["quiz"]
    named = [x["subject"] for x in d["best_subjects"] + d["worst_subjects"]]
    assert "جغرافيا" not in named
    assert "رياضيات" in named


def test_no_quiz_data_says_so_instead_of_zeros(client, db):
    """🔴 لا صفرَ هادئ: «قُرئت فوُجدت فارغة» تُقال بنصّها."""
    user(db, "s", asks={TODAY: 1})
    d = client.get("/admin/analytics", headers=HDR).json()["quiz"]
    assert d["available"] is True                      # لا عطل
    assert d["count"] == 0
    assert d["note"].startswith("ℹ️")                  # وحالةٌ مقروءة


def test_unreadable_group_reports_failure_not_emptiness(client, db):
    """⭐ الفرق الذي يمنع مطاردةَ عطلٍ وهميّ: تعذُّرُ القراءة ≠ لا بيانات."""
    user(db, "s")
    db.broken_groups.add("results")
    d = client.get("/admin/analytics", headers=HDR).json()
    assert d["quiz"]["available"] is False
    assert "⚠️" in d["quiz"]["note"]
    # وبقيّة الصفحة تبقى معروضة — قسمٌ يتعذّر لا يُفرّغ الباقي
    assert d["users"]["total"] == 1


def test_analytics_requires_firestore(client, monkeypatch):
    monkeypatch.setattr(q, "_firestore", lambda: None)
    r = client.get("/admin/analytics", headers=HDR)
    assert r.status_code == 400
    assert "Firestore" in r.json()["error"]


def test_growth_series_is_cumulative_and_gapless(client, db):
    user(db, "old", created_at="2020-01-01T00:00:00")
    user(db, "new", created_at=TODAY + "T09:00:00")
    g = client.get("/admin/analytics?days=7", headers=HDR).json()["users"]["growth"]
    assert len(g) == 7
    assert g[0]["total"] == 1                          # القديم محسوبٌ قبل المدّة
    assert g[-1]["total"] == 2
    assert g[-1]["new"] == 1


def test_quota_metrics_respect_personal_override(client, db):
    user(db, "capped", asks={TODAY: 3}, quota_override=3)
    user(db, "free", asks={TODAY: 3})
    d = client.get("/admin/analytics", headers=HDR).json()["quota"]
    assert d["at_limit_today"] == 1                    # صاحب الحدّ الخاص وحده
    assert d["overrides"] == 1


# ══════════════════════════════════════════════════
# 👥 ٤ — جدول المستخدمين: الشريحة والترتيب
# ══════════════════════════════════════════════════

def test_users_filter_by_segment(client, db):
    user(db, "sci", grade=3, track="علمي")
    user(db, "lit", grade=3, track="أدبي")
    user(db, "one", grade=1, track="عام")
    rows = client.get("/admin/users?segment=g3_lit", headers=HDR).json()["users"]
    assert [r["uid"] for r in rows] == ["lit"]


def test_users_banned_and_admin_segments(client, db):
    user(db, "bad", banned=True)
    user(db, "boss", role="admin")
    user(db, "ok")
    assert [r["uid"] for r in
            client.get("/admin/users?segment=banned", headers=HDR).json()["users"]] == ["bad"]
    assert [r["uid"] for r in
            client.get("/admin/users?segment=admins", headers=HDR).json()["users"]] == ["boss"]


def test_users_expose_last_active(client, db):
    """حسابٌ جديدٌ وحسابٌ مهجورٌ كلاهما بلا أسئلة اليوم — يفرّقهما آخرُ نشاط."""
    user(db, "stale", asks={"2020-01-01": 4})
    user(db, "fresh")
    rows = {r["uid"]: r for r in client.get("/admin/users", headers=HDR).json()["users"]}
    assert rows["stale"]["last_active"] == "2020-01-01"
    assert rows["fresh"]["last_active"] == ""


def test_users_sort_by_name(client, db):
    user(db, "u1", name="ياسر")
    user(db, "u2", name="أحمد")
    rows = client.get("/admin/users?sort=name", headers=HDR).json()["users"]
    assert rows[0]["name"] == "أحمد"


def test_users_bad_segment_is_rejected(client, db):
    user(db, "u1")
    r = client.get("/admin/users?segment=nonsense", headers=HDR)
    assert r.status_code == 400


# ══════════════════════════════════════════════════
# 🔐 ٥ — الوصول: الأولوية المعلنة تسري حرفياً
# ══════════════════════════════════════════════════

def test_default_is_everything_open(db):
    state = acc.resolve(3, "علمي")
    assert all(v["usable"] for v in state.values())


def test_global_off_beats_every_rule(db):
    acc.set_rules("scholarships", [{"segment": "g3_sci", "mode": "on"}])
    acc.set_section("scholarships", "off")
    v = acc.state_of("scholarships", 3, "علمي")
    assert v["mode"] == "off" and v["reason"] == "عام"


def test_more_specific_segment_wins(db):
    """«ثالث علمي» تغلب «الصف الثالث» — وإلا لم يكن للتخصيص معنى."""
    acc.set_rules("quiz", [
        {"segment": "g3", "mode": "off"},
        {"segment": "g3_sci", "mode": "on"},
    ])
    assert acc.state_of("quiz", 3, "علمي")["usable"] is True
    assert acc.state_of("quiz", 3, "أدبي")["usable"] is False


def test_broad_rule_still_applies_to_unmatched(db):
    acc.set_rules("services", [{"segment": "students", "mode": "soon"}])
    v = acc.state_of("services", 1, "عام")
    assert v["mode"] == "soon"
    assert v["visible"] is True and v["usable"] is False


def test_duplicate_segment_is_refused(db):
    """قاعدتان لشريحةٍ واحدة تجعلان النتيجة تابعةً للترتيب — وهو غموض."""
    with pytest.raises(acc.AccessError):
        acc.set_rules("quiz", [{"segment": "g1", "mode": "off"},
                               {"segment": "g1", "mode": "on"}])


def test_activity_segment_refused_as_access_rule(db):
    with pytest.raises(acc.AccessError):
        acc.set_rules("quiz", [{"segment": "inactive", "mode": "off"}])


def test_unknown_section_or_mode_refused(db):
    with pytest.raises(acc.AccessError):
        acc.set_section("ghost_section", "off")
    with pytest.raises(acc.AccessError):
        acc.set_section("quiz", "maybe")


def test_admin_is_never_blocked(db):
    """المدير يعاين ما أخفاه — وإلا عطّل على نفسه الفحص."""
    acc.set_section("quiz", "off")
    acc.require("quiz", 3, "علمي", "admin")           # لا يرمي
    with pytest.raises(acc.SectionBlocked):
        acc.require("quiz", 3, "علمي", "student")


def test_default_messages_are_filled(db):
    acc.set_section("services", "soon")
    assert acc.DEFAULT_SOON in acc.state_of("services", 3, "علمي")["message"]
    acc.set_section("services", "off", "مغلق للصيانة")
    assert acc.state_of("services", 3, "علمي")["message"] == "مغلق للصيانة"


def test_access_fails_open_without_firestore(monkeypatch):
    """🛟 عطلُ القواعد يعطّل الإخفاء لا الدراسة."""
    monkeypatch.setattr(q, "_firestore", lambda: None)
    acc.invalidate()
    assert all(v["usable"] for v in acc.resolve(3, "علمي").values())
    acc.require("quiz", 3, "علمي")                    # لا يرمي


def test_preview_translates_rules_per_grade(client, db):
    acc.set_rules("scholarships", [{"segment": "g1", "mode": "off"},
                                   {"segment": "g2", "mode": "soon"}])
    d = client.get("/admin/access", headers=HDR).json()
    sec = next(s for s in d["sections"] if s["key"] == "scholarships")
    modes = {p["label"]: p["mode"] for p in sec["preview"]}
    assert modes["الأول"] == "off"
    assert modes["ثاني علمي"] == "soon"
    assert modes["ثالث علمي"] == "on"


def test_access_rules_saved_through_route(client, db):
    r = client.post("/admin/access/analysis/rules", headers=HDR,
                    json={"rules": [{"segment": "g1", "mode": "off", "message": "للثالث فقط"}]})
    assert r.status_code == 200
    acc.invalidate()
    v = acc.state_of("analysis", 1, "عام")
    assert v["usable"] is False and v["message"] == "للثالث فقط"


def test_teacher_is_not_a_controllable_section(client, db):
    """👨‍🏫 «مساعد المعلم» خرج من قواعد الوصول — صار تطبيق المعلّم كلَّه.

    🔴 **وكان فخّاً قبل الخروج:** «أخفِ مساعد المعلم» تُفرغ تطبيق كل معلّمٍ
       من محتواه ولا تترك له شاشةً واحدة — فالقسم هو كلُّ ما يراه.
    """
    assert "teacher" not in acc.SECTIONS
    # ولا يظهر في اللوحة ولا فيما يقرؤه التطبيق.
    assert "teacher" not in client.get("/app/access").json()["sections"]
    keys = {s["key"] for s in client.get("/admin/access", headers=HDR).json()["sections"]}
    assert "teacher" not in keys and "education" in keys

    # 🛟 وقسمٌ غير معروف يُقرأ **مفتوحاً** — فلا ينقفل شيءٌ بحذفه.
    assert acc.state_of("teacher", 3, "علمي")["usable"] is True
    acc.require("teacher", 3, "علمي")   # لا يرمي


def test_app_access_is_public_and_shaped_for_the_app(client, db):
    acc.set_rules("scholarships", [{"segment": "g1", "mode": "off"}])
    d = client.get("/app/access?grade=1&track=عام").json()["sections"]
    assert d["scholarships"]["visible"] is False
    assert d["quiz"]["usable"] is True
    assert set(d) == set(acc.SECTIONS)


def test_app_access_honours_role(client, db):
    """🎭 قاعدةٌ على «المعلمون» تُخفي القسم عنهم وحدهم."""
    acc.set_rules("scholarships", [{"segment": "teachers", "mode": "off"}])

    teacher = client.get("/app/access?grade=3&track=علمي&role=teacher").json()["sections"]
    student = client.get("/app/access?grade=3&track=علمي&role=student").json()["sections"]

    assert teacher["scholarships"]["visible"] is False
    assert student["scholarships"]["visible"] is True


def test_app_access_defaults_to_student_for_bogus_role(client, db):
    """⚠️ `role=admin` في الرابط لا يفتح شيئاً — القائمة مغلقة والباقي «طالب»."""
    acc.set_rules("scholarships", [{"segment": "students", "mode": "off"}])

    for bogus in ("admin", "", "TEACHER", "superuser"):
        d = client.get(f"/app/access?grade=3&track=علمي&role={bogus}").json()["sections"]
        assert d["scholarships"]["visible"] is False, bogus


def test_overview_counts_teachers_separately(client, db):
    """👨‍🏫 المعلّم لا يُعدّ طالباً ولا يدخل جدول الصفوف — ويظهر بعدّاده."""
    user(db, "s1", grade=3, track="علمي", role="student")
    user(db, "s2", grade=3, track="علمي", role="student")
    user(db, "t1", grade=3, track="علمي", role="teacher")
    user(db, "a1", grade=3, track="علمي", role="admin")

    u = client.get("/admin/analytics?days=7", headers=HDR).json()["users"]
    assert u["students"] == 2
    assert u["teachers"] == 1
    assert u["admins"] == 1

    # 🎓 وجدول الصفوف يعدّ الطالبين وحدهما — لا المعلّم ولا المدير.
    by_grade = {(g["grade"], g["track"]): g["count"] for g in u["by_grade"]}
    assert by_grade[(3, "علمي")] == 2


def test_users_table_exposes_role(client, db):
    """اللوحة ترى الدور فعلاً — وإلا رُسم المعلّم طالباً في الصف الثالث."""
    user(db, "t1", grade=2, track="أدبي", role="teacher", name="أستاذ خالد")
    rows = client.get("/admin/users", headers=HDR).json()["users"]
    row = next(r for r in rows if r["uid"] == "t1")
    assert row["role"] == "teacher"
    assert row["grade"] == 2 and row["track"] == "أدبي"


def test_users_can_be_filtered_by_teachers_segment(client, db):
    user(db, "s1", role="student")
    user(db, "t1", role="teacher")
    rows = client.get("/admin/users?segment=teachers", headers=HDR).json()["users"]
    assert [r["uid"] for r in rows] == ["t1"]


# ══════════════════════════════════════════════════
# 💬 ٥٫٤ — لا حوارات متصفّحٍ أصلية في اللوحة
# ══════════════════════════════════════════════════

def test_dashboard_uses_no_native_dialogs():
    """🔴 **العلّة التي أوقفت نصف اللوحة (2026-09-07).**

    `confirm()` و`prompt()` الأصليان **مكبوتان في المتصفحات المدمجة** —
    والمكبوت يرجع `false` فوراً بلا أي إشارة، فيقرؤه الكود «ألغى الأدمن»
    ويمضي بصمت. العَرَض حرفياً: يُملأ الإشعار ويُضغط «إرسال» فلا يحدث
    **شيء إطلاقاً** — لا رسالة ولا خطأ ولا طلب شبكة.

    وكانت تصيب ثمانية إجراءات: الإرسال · حذف الإشعار · حظر المستخدم ·
    حدّه اليومي · حذف البانر · حذف المنحة · إعادة البرومبت · وضع القسم.

    ⚠️ ولا يكفي إصلاحها مرّة: أيُّ `confirm` يُضاف لاحقاً يعيد العطل صامتاً
       في متصفح المالك وحده — ولا اختبار واجهةٍ يكشفه. فيُحرس هنا نصّياً.
    """
    import os, re
    path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "admin.html")
    with open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()

    offenders = []
    for i, line in enumerate(lines, 1):
        code = line.split("//", 1)[0]          # التعليقات تشرح العلّة فتُستثنى
        if re.search(r"(?<![\w.])(confirm|prompt)\s*\(", code):
            offenders.append(f"{i}: {line.strip()[:90]}")

    assert not offenders, (
        "استُعمل حوارٌ أصلي في admin.html — استعمل ask()/askText() بدله:\n"
        + "\n".join(offenders))


def test_dashboard_ships_the_in_page_dialog():
    """والبديل موجودٌ فعلاً — وإلا كسر الاختبار أعلاه بلا حلٍّ يقدّمه."""
    import os
    path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "admin.html")
    html = open(path, encoding="utf-8").read()
    assert "function ask(" in html and "function askText(" in html
    assert 'id="ovl"' in html and 'id="dlgOk"' in html


# ══════════════════════════════════════════════════
# 🔄 ٥٫٥ — التحويل يسري فوراً لا بعد دقيقتين
# ══════════════════════════════════════════════════

def test_profile_change_takes_effect_immediately(client, db, monkeypatch):
    """🎭 من حوّل نفسه معلّماً يجب ألا يبقى الخادمُ يعامله طالباً.

    🔴 **هذه العلّة كانت حيّة:** `forget_profile` موجودة ولا يناديها أحد،
       فكاش الملف الشخصي (دقيقتان) يُبقي الدور القديم — فيفتح المعلّم قسمه
       فيُمنع، ويظنّ أن التحويل لم يعمل.
    """
    user(db, "u1", grade=3, track="علمي", role="student")
    _as_student(monkeypatch, "u1")

    # قسمٌ مخفيّ عن الطلاب ومفتوح لغيرهم.
    acc.set_rules("analysis", [{"segment": "students", "mode": "off",
                                "message": "للمعلمين فقط"}])
    acc.invalidate()
    acc.forget_profile()

    assert acc.state_of("analysis", **acc.profile_for("u1"))["usable"] is False

    # يحوّل نفسه معلّماً في Firestore (كما يفعل التطبيق).
    db.cols["users"]["u1"]["role"] = "teacher"

    # بلا إسقاط الكاش يبقى الجواب القديم…
    assert acc.profile_for("u1")["role"] == "student"

    # …ونداء التطبيق يُسقطه فيسري التحويل فوراً.
    r = client.post("/me/profile-changed", headers={"Authorization": "Bearer x"})
    assert r.status_code == 200 and r.json()["refreshed"] is True
    assert acc.profile_for("u1")["role"] == "teacher"
    assert acc.state_of("analysis", **acc.profile_for("u1"))["usable"] is True


def test_profile_change_requires_a_token(client, db):
    """🔒 بلا توكن لا إسقاط: وإلا أجبر أيُّ أحدٍ الخادمَ على قراءةٍ لكل طلب."""
    assert client.post("/me/profile-changed").status_code == 401


# ══════════════════════════════════════════════════
# 🛡️ ٦ — الفرض الحقيقي: القاعدة تسري على المسار لا على الزرّ
# ══════════════════════════════════════════════════

def _as_student(monkeypatch, uid="stu"):
    monkeypatch.setattr(fa, "verify", lambda t: {
        "uid": uid, "email": f"{uid}@t.c", "email_verified": True,
        "provider": "password", "is_guest": False})


def _quiz_body(**over):
    body = {"grade": 1, "track": "عام", "subject": "احياء", "unit": "و1",
            "lessons": ["د1"], "count": 3, "user_id": "stu", "code": "",
            "device_id": "d1"}
    body.update(over)
    return body


def test_blocked_section_refuses_the_endpoint_itself(client, db, monkeypatch):
    """⭐ إخفاء الزرّ ليس حماية: المسار نفسه يرفض."""
    user(db, "stu", grade=1, track="عام")
    acc.set_rules("quiz", [{"segment": "g1", "mode": "off", "message": "لاحقاً"}])
    _as_student(monkeypatch)
    r = client.post("/quiz/generate", json=_quiz_body(),
                    headers={"Authorization": "Bearer x"})
    assert r.status_code == 403
    assert r.json()["section_blocked"] is True
    assert r.json()["answer"] == "لاحقاً"


def test_blocked_section_does_not_consume_quota(client, db, monkeypatch):
    """القسم المقفل لا يخصم سؤالاً — الحارس قبل الحصة لا بعدها."""
    user(db, "stu", grade=1, track="عام")
    acc.set_section("quiz", "off")
    _as_student(monkeypatch)
    client.post("/quiz/generate", json=_quiz_body(), headers={"Authorization": "Bearer x"})
    assert db.cols.get("usage", {}) == {}


def test_lying_about_grade_does_not_bypass_the_rule(client, db, monkeypatch):
    """🔴 الصفّ من `users/{uid}` لا من جسد الطلب — وإلا كفى تغييرُ رقم."""
    user(db, "stu", grade=1, track="عام")
    acc.set_rules("quiz", [{"segment": "g1", "mode": "off"}])
    _as_student(monkeypatch)
    r = client.post("/quiz/generate", json=_quiz_body(grade=3, track="علمي"),
                    headers={"Authorization": "Bearer x"})
    assert r.status_code == 403


def test_open_section_passes_through(client, db, monkeypatch):
    user(db, "stu", grade=3, track="علمي")
    acc.set_rules("quiz", [{"segment": "g1", "mode": "off"}])
    _as_student(monkeypatch)
    r = client.post("/quiz/generate", json=_quiz_body(grade=3, track="علمي"),
                    headers={"Authorization": "Bearer x"})
    assert r.status_code != 403


# ══════════════════════════════════════════════════
# 🔔 ٧ — الإشعارات: جمهورٌ محسوب ولا إرسالَ موهوم
# ══════════════════════════════════════════════════

def test_preview_counts_real_recipients(client, db):
    user(db, "a", grade=3, track="علمي")
    user(db, "b", grade=3, track="أدبي")
    user(db, "c", grade=1, track="عام")
    d = client.post("/admin/notifications/preview", headers=HDR,
                    json={"segment": "g3"}).json()
    assert d["recipients"] == 2
    assert sum(x["count"] for x in d["by_grade"]) == 2


def test_preview_excludes_banned(client, db):
    """⛔ إشعارُ من منعناه دخولَ المنصّة تناقض."""
    user(db, "ok")
    user(db, "bad", banned=True)
    d = client.post("/admin/notifications/preview", headers=HDR,
                    json={"segment": "students"}).json()
    assert d["recipients"] == 1
    assert d["excluded_banned"] == 1


def test_preview_excludes_muted_when_asked(client, db):
    user(db, "on")
    user(db, "off", settings={"notifications": False})
    body = {"segment": "students", "notifications_only": True}
    assert client.post("/admin/notifications/preview", headers=HDR,
                       json=body).json()["recipients"] == 1
    body["notifications_only"] = False
    assert client.post("/admin/notifications/preview", headers=HDR,
                       json=body).json()["recipients"] == 2


def test_preview_declares_no_delivery_transport(client, db):
    """🔴 القدرة تُقال قبل الضغط لا بعده."""
    user(db, "a")
    d = client.post("/admin/notifications/preview", headers=HDR,
                    json={"segment": "all"}).json()
    assert d["delivery"] is False
    assert "لن يرنّ" in d["delivery_note"]


def test_create_stores_pending_not_sent(client, db):
    """لا ناقلَ ⇒ الحالة «بانتظار الإرسال»، ولا تُسمّى «أُرسل»."""
    user(db, "a", grade=3, track="علمي")
    r = client.post("/admin/notifications", headers=HDR,
                    json={"title": "نتائج", "body": "ظهرت النتائج", "segment": "g3_sci"})
    assert r.status_code == 200
    out = r.json()
    assert out["status"] == "pending"
    assert out["recipient_count"] == 1
    assert db.cols["notifications"][out["id"]]["recipients"] == ["a"]


def test_create_refuses_empty_audience(client, db):
    """جمهورٌ فارغ خطأٌ يُقال، لا إرسالٌ صامتٌ لأحد."""
    user(db, "a", grade=1, track="عام")
    r = client.post("/admin/notifications", headers=HDR,
                    json={"title": "ت", "body": "ن", "segment": "g3_lit"})
    assert r.status_code == 400
    assert "لا مستلم" in r.json()["error"]


def test_create_requires_title_and_body(client, db):
    user(db, "a")
    for payload in ({"title": "", "body": "ن"}, {"title": "ت", "body": ""}):
        r = client.post("/admin/notifications", headers=HDR, json=payload)
        assert r.status_code == 400


def test_create_refuses_unknown_link(client, db):
    user(db, "a")
    r = client.post("/admin/notifications", headers=HDR,
                    json={"title": "ت", "body": "ن", "link": "evil"})
    assert r.status_code == 400


def test_snapshot_freezes_the_audience(client, db):
    """⭐ من سجّل بعد الإعلان ليس مقصوداً به — اللقطة لا الشريحة."""
    user(db, "a", grade=3, track="علمي")
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن", "segment": "g3_sci"}).json()
    user(db, "late", grade=3, track="علمي")
    assert notif.inbox("late") == []
    assert [x["id"] for x in notif.inbox("a")] == [out["id"]]


def test_inbox_requires_a_token(client, db):
    assert client.get("/notifications/inbox").status_code == 401


def test_inbox_is_scoped_to_the_token_owner(client, db, monkeypatch):
    """🔴 الصندوق من التوكن لا من مُعامل — وإلا قرأ كلٌّ صندوقَ غيره."""
    user(db, "a")
    user(db, "b")
    client.post("/admin/notifications", headers=HDR,
                json={"title": "ت", "body": "ن", "uids": ["a"]})
    _as_student(monkeypatch, "b")
    items = client.get("/notifications/inbox",
                       headers={"Authorization": "Bearer x"}).json()["items"]
    assert items == []
    _as_student(monkeypatch, "a")
    items = client.get("/notifications/inbox",
                       headers={"Authorization": "Bearer x"}).json()["items"]
    assert len(items) == 1


def test_delete_removes_from_inbox(client, db):
    user(db, "a")
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن"}).json()
    assert client.delete(f"/admin/notifications/{out['id']}", headers=HDR).status_code == 200
    assert notif.inbox("a") == []


def test_delete_missing_notification_is_a_clear_error(client, db):
    user(db, "a")
    r = client.delete("/admin/notifications/nope", headers=HDR)
    assert r.status_code == 400
    assert "لا يوجد" in r.json()["error"]


def test_notifications_need_firestore(client, monkeypatch):
    monkeypatch.setattr(q, "_firestore", lambda: None)
    r = client.post("/admin/notifications/preview", headers=HDR, json={"segment": "all"})
    assert r.status_code == 400
    assert "Firestore" in r.json()["error"]


def test_inbox_is_empty_not_broken_without_firestore(monkeypatch):
    """🛟 الإشعار ليس جوهر التطبيق — عطله صندوقٌ فارغ لا شاشةٌ ساقطة."""
    monkeypatch.setattr(q, "_firestore", lambda: None)
    assert notif.inbox("a") == []


# ══════════════════════════════════════════════════
# 📲 ٨ — ناقل الدفع: أرقامٌ من الرد لا من الأمل
# ══════════════════════════════════════════════════
# ⚠️ **الفخّ الذي يجب ألّا يقع:** حالةٌ تقول «أُرسل» ولا شيء أُرسل. المالك
#    يقرؤها فيظن ألف طالبٍ رأى إعلاناً لم يصل أحداً — وهو الخطأ الوحيد
#    الذي لا يُكتشف إلا بعد فوات موعد المنحة.

class _FakeResponse:
    def __init__(self, successes, exceptions=None):
        exceptions = exceptions or {}
        self.responses = []
        for i, ok in enumerate(successes):
            self.responses.append(type("R", (), {
                "success": ok, "exception": exceptions.get(i)})())


class _FakeMessaging:
    """يحاكي `firebase_admin.messaging` بما يستعمله [push] لا أكثر."""

    def __init__(self, plan=None):
        self.plan = plan or {}
        self.sent_messages = []

    # القوالب — نحتفظ بما مُرِّر كي نتحقق منه
    def Notification(self, title=None, body=None):
        return {"title": title, "body": body}

    def AndroidNotification(self, **kw):
        return kw

    def AndroidConfig(self, **kw):
        return kw

    def Aps(self, **kw):
        return kw

    def APNSPayload(self, **kw):
        return kw

    def APNSConfig(self, **kw):
        return kw

    def MulticastMessage(self, notification=None, data=None, tokens=None, **kw):
        return {"notification": notification, "data": data, "tokens": tokens, **kw}

    def send_each_for_multicast(self, message):
        self.sent_messages.append(message)
        tokens = message["tokens"]
        successes, exceptions = [], {}
        for i, t in enumerate(tokens):
            verdict = self.plan.get(t, "ok")
            successes.append(verdict == "ok")
            if verdict == "dead":
                exceptions[i] = type("E", (), {"code": "UNREGISTERED", "cause": None})()
            elif verdict == "flaky":
                exceptions[i] = type("E", (), {"code": "UNAVAILABLE", "cause": None})()
        return _FakeResponse(successes, exceptions)


@pytest.fixture()
def fcm(monkeypatch):
    """يشغّل ناقل الدفع بوهميٍّ — ويرجع الوهمي للفحص."""
    from core import push as pu
    fake = _FakeMessaging()
    monkeypatch.setattr(pu, "_messaging", lambda: fake)
    return fake


def _with_device(db, uid, tokens, **kw):
    user(db, uid, **kw)
    db.cols["users"][uid]["fcm_tokens"] = list(tokens)


# ── القدرة تُقرأ لا تُفترض ──

def test_delivery_unavailable_without_messaging(db, monkeypatch):
    from core import push as pu
    monkeypatch.setattr(pu, "_messaging", lambda: None)
    assert notif.delivery_available() is False


def test_delivery_available_when_transport_and_store_ready(db, fcm):
    assert notif.delivery_available() is True


def test_panel_reads_capability_from_the_server(client, db, fcm):
    """⭐ اللوحة لا تُحدَّث يوم يصل FCM — تقرأ القدرة من الرد."""
    _with_device(db, "a", ["tok"])
    d = client.post("/admin/notifications/preview", headers=HDR,
                    json={"segment": "all"}).json()
    assert d["delivery"] is True
    assert "لن يرنّ" not in d["delivery_note"]


# ── الإرسال الحقيقي ──

def test_notification_is_pushed_to_registered_devices(client, db, fcm):
    _with_device(db, "a", ["tok-a1", "tok-a2"], grade=3, track="علمي")
    _with_device(db, "b", ["tok-b1"], grade=3, track="علمي")
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "نتائج", "body": "ظهرت", "segment": "g3_sci"}).json()

    assert out["status"] == "sent"
    assert out["sent"] == 3                      # ثلاثة أجهزة
    assert out["users_reached"] == 2             # طالبان
    assert db.cols["notifications"][out["id"]]["status"] == "sent"


def test_message_carries_the_link_for_deep_linking(client, db, fcm):
    """الوجهة تصل في `data` — بدونها يفتح الإشعار الرئيسية دائماً."""
    _with_device(db, "a", ["tok"])
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن", "link": "scholarships"}).json()
    payload = fcm.sent_messages[0]["data"]
    assert payload["link"] == "scholarships"
    assert payload["notification_id"] == out["id"]
    # 🔤 كل القيم نصوص — FCM يرفض غيرها فتسقط الدفعة كلها
    assert all(isinstance(v, str) for v in payload.values())


def test_android_channel_matches_the_manifest(client, db, fcm):
    """⚠️ اختلافه عن المانيفست = إشعارٌ يصل بلا صوتٍ ولا ظهور."""
    _with_device(db, "a", ["tok"])
    client.post("/admin/notifications", headers=HDR, json={"title": "ت", "body": "ن"})
    android = fcm.sent_messages[0]["android"]
    assert android["notification"]["channel_id"] == "masar_general"


def test_recipient_without_device_still_gets_the_record(client, db, fcm):
    """من لا جهازَ له يبقى في الصندوق — لا يُحذف من الجمهور."""
    _with_device(db, "has", ["tok"], grade=3, track="علمي")
    user(db, "none", grade=3, track="علمي")
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن", "segment": "g3_sci"}).json()
    assert out["recipient_count"] == 2
    assert out["users_reached"] == 1
    assert len(notif.inbox("none")) == 1          # وصله في الصندوق


def test_preview_counts_devices_and_warns_about_missing_ones(client, db, fcm):
    _with_device(db, "has", ["t1", "t2"])
    user(db, "none")
    d = client.post("/admin/notifications/preview", headers=HDR,
                    json={"segment": "students"}).json()
    assert d["devices"] == 2
    assert d["without_device"] == 1
    assert "بلا جهاز مسجَّل" in d["delivery_note"]


# ── تنظيف الرموز: الميت يُحذف والعابر يبقى ──

def test_dead_tokens_are_pruned(client, db, monkeypatch):
    """جهازٌ حُذف منه التطبيق يُرفض رمزُه نهائياً ⇒ يُحذف."""
    from core import push as pu
    monkeypatch.setattr(pu, "_messaging",
                        lambda: _FakeMessaging({"dead-tok": "dead", "live-tok": "ok"}))
    _with_device(db, "a", ["dead-tok", "live-tok"])
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن"}).json()
    assert out["pruned_tokens"] == 1
    assert db.cols["users"]["a"]["fcm_tokens"] == ["live-tok"]


def test_transient_failure_never_deletes_a_token(client, db, monkeypatch):
    """🔴 الأهمّ: رمزٌ فشل لانقطاعِ شبكةٍ **لا يُحذف** — وإلا فقد الطالب
    إشعاراته للأبد بلا أن يعرف أحدٌ لماذا."""
    from core import push as pu
    monkeypatch.setattr(pu, "_messaging", lambda: _FakeMessaging({"tok": "flaky"}))
    _with_device(db, "a", ["tok"])
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن"}).json()
    assert out["failed"] == 1
    assert out["pruned_tokens"] == 0
    assert db.cols["users"]["a"]["fcm_tokens"] == ["tok"]


def test_transport_error_is_reported_as_failed_not_sent(client, db, monkeypatch):
    """🛟 اعتمادٌ خاطئ ⇒ «فشل» صراحةً — ولا يبتلع الإشعارَ ولا يسمّيه ناجحاً."""
    from core import push as pu

    class _Boom(_FakeMessaging):
        def send_each_for_multicast(self, message):
            raise RuntimeError("اعتماد خاطئ")

    monkeypatch.setattr(pu, "_messaging", lambda: _Boom())
    _with_device(db, "a", ["tok"])
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن"}).json()
    assert out["status"] == "failed"
    assert out["sent"] == 0 and out["failed"] == 1
    # ⭐ والأهمّ: الرسالة لم تضِع — تصل الطالب في صندوقه عند فتح التطبيق.
    assert len(notif.inbox("a")) == 1
    assert db.cols["users"]["a"]["fcm_tokens"] == ["tok"]   # ولا رمزَ اتُّهم


def test_push_crash_keeps_the_record_pending_not_lost(client, db, monkeypatch):
    """انهيارٌ خارج الدفعة (قراءة أو ناقل مفقود) ⇒ `pending` لا ضياع."""
    from core import push as pu
    monkeypatch.setattr(pu, "send",
                        lambda *a, **k: (_ for _ in ()).throw(RuntimeError("انهيار")))
    monkeypatch.setattr(pu, "_messaging", lambda: _FakeMessaging())
    _with_device(db, "a", ["tok"])
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن"}).json()
    assert out["status"] == "pending"
    assert len(notif.inbox("a")) == 1


def test_record_is_saved_before_it_is_pushed(client, db, monkeypatch):
    """⭐ لو دُفع قبل الحفظ لوصل جيوب الطلاب بلا أثرٍ عند الأدمن فأرسله ثانيةً."""
    from core import push as pu
    seen = {}

    class _Watcher(_FakeMessaging):
        def send_each_for_multicast(self, message):
            seen["stored"] = list(db.cols.get("notifications", {}))
            return super().send_each_for_multicast(message)

    monkeypatch.setattr(pu, "_messaging", lambda: _Watcher())
    _with_device(db, "a", ["tok"])
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن"}).json()
    assert seen["stored"] == [out["id"]]          # كان محفوظاً وقت الدفع


# ── تسجيل الأجهزة ──

def test_device_registration_requires_a_token(client, db):
    assert client.post("/me/device", json={"token": "x"}).status_code == 401


def test_device_is_bound_to_the_token_owner_only(client, db, monkeypatch):
    """🔴 الجهاز يُربط بصاحب التوكن — لا بـ`uid` يأتي في الجسم."""
    user(db, "me")
    user(db, "victim")
    _as_student(monkeypatch, "me")
    r = client.post("/me/device", headers={"Authorization": "Bearer x"},
                    json={"token": "tok", "platform": "android", "uid": "victim"})
    assert r.status_code == 200
    assert db.cols["users"]["me"]["fcm_tokens"] == ["tok"]
    assert "fcm_tokens" not in db.cols["users"]["victim"]


def test_repeated_registration_writes_nothing_new(client, db, monkeypatch):
    """كل إقلاعٍ يناديه — فلا كتابةَ بلا تغيير."""
    user(db, "me")
    _as_student(monkeypatch, "me")
    hdr = {"Authorization": "Bearer x"}
    first = client.post("/me/device", headers=hdr, json={"token": "tok"}).json()
    second = client.post("/me/device", headers=hdr, json={"token": "tok"}).json()
    assert first["changed"] is True and second["changed"] is False
    assert db.cols["users"]["me"]["fcm_tokens"] == ["tok"]


def test_device_list_is_capped(client, db, monkeypatch):
    """سقفٌ مفروضٌ فعلاً: `arrayUnion` من العميل لا يمكن تحديدها بسقف."""
    from core import push as pu
    user(db, "me")
    _as_student(monkeypatch, "me")
    for i in range(pu.MAX_TOKENS_PER_USER + 4):
        client.post("/me/device", headers={"Authorization": "Bearer x"},
                    json={"token": f"tok{i}"})
    tokens = db.cols["users"]["me"]["fcm_tokens"]
    assert len(tokens) == pu.MAX_TOKENS_PER_USER
    assert tokens[-1] == f"tok{pu.MAX_TOKENS_PER_USER + 3}"   # الأحدث باقٍ


def test_guest_device_is_not_registered(client, db, monkeypatch):
    """حساب الزائر مؤقت ويُرقّى — ربطُ جهازه به يتركه على حسابٍ مهجور."""
    monkeypatch.setattr(fa, "verify", lambda t: {
        "uid": "g1", "email": "", "is_guest": True, "email_verified": True})
    r = client.post("/me/device", headers={"Authorization": "Bearer x"},
                    json={"token": "tok"})
    assert r.json()["registered"] is False


def test_signing_out_unbinds_the_device(client, db, monkeypatch):
    """⚠️ جوّالٌ يتشاركه أخوان: بلا فصلٍ تصل إشعارات الأول ليد الثاني."""
    user(db, "me")
    _as_student(monkeypatch, "me")
    hdr = {"Authorization": "Bearer x"}
    client.post("/me/device", headers=hdr, json={"token": "tok"})
    r = client.delete("/me/device?token=tok", headers=hdr)
    assert r.json()["unregistered"] is True
    assert db.cols["users"]["me"]["fcm_tokens"] == []


# ── مفتاحا الإشعارات في التطبيق يُحترمان ──

def test_muting_scholarships_excludes_only_scholarship_notices(client, db, fcm):
    """⭐ المفتاح من شاشة الإعدادات نفسها — من أطفأ إشعارات المنح يخرج من
    جمهور إشعار المنح **وحده** ويبقى في العام."""
    user(db, "a", settings={"notif_scholarships": False, "notif_general": True})
    user(db, "b", settings={"notif_scholarships": True, "notif_general": True})

    sch_audience = client.post("/admin/notifications/preview", headers=HDR,
                               json={"segment": "students", "link": "scholarships"}).json()
    gen_audience = client.post("/admin/notifications/preview", headers=HDR,
                               json={"segment": "students", "link": "none"}).json()
    assert sch_audience["recipients"] == 1
    assert gen_audience["recipients"] == 2


def test_missing_flag_means_not_yet_chosen_not_refused(client, db, fcm):
    """حسابٌ سجّل قبل وصول الإشعارات لا يُقصى لأن مفتاحاً لم يكن موجوداً."""
    user(db, "old")
    d = client.post("/admin/notifications/preview", headers=HDR,
                    json={"segment": "students"}).json()
    assert d["recipients"] == 1
    assert d["excluded_muted"] == 0


# ══════════════════════════════════════════════════
# ⚰️ ٩ — تمييز الرمز الميت: بالنوع لا بالنصّ
# ══════════════════════════════════════════════════
# 🔴 **الخطأ الذي كُشف بفحصٍ حقيقي على FCM لا بالقراءة:** الـSDK يرمي
#    `UnregisteredError` نصُّها «NotRegistered» — و«notregistered» **لا
#    تحوي** «unregistered». فكانت المطابقة النصّية تعتبر الرمز الميت حيّاً
#    فلا يُحذف أبداً: أجهزةٌ ميتة تتراكم، وكل إرسالٍ يُظهر «فشل» لا يزول.

class _SdkUnregistered(Exception):
    """يحاكي `firebase_admin.messaging.UnregisteredError` شكلاً واسماً."""
    code = "NOT_FOUND"
    cause = None

    def __str__(self):
        return "NotRegistered"


_SdkUnregistered.__name__ = "UnregisteredError"


class _SdkSenderMismatch(Exception):
    code = "SENDER_ID_MISMATCH"
    cause = None

    def __str__(self):
        return "SenderIdMismatch"


_SdkSenderMismatch.__name__ = "SenderIdMismatchError"


def test_sdk_unregistered_error_is_recognised_as_dead():
    """⚠️ نصُّها «NotRegistered» — والمطابقة النصّية وحدها تُخطئها."""
    from core import push as pu
    assert pu._is_dead(_SdkUnregistered()) is True


def test_sender_mismatch_is_dead_too():
    from core import push as pu
    assert pu._is_dead(_SdkSenderMismatch()) is True


@pytest.mark.parametrize("code,text", [
    ("UNAVAILABLE", "backend unavailable"),
    ("INTERNAL", "internal error"),
    ("QUOTA_EXCEEDED", "too many"),
    ("DEADLINE_EXCEEDED", "timeout"),
])
def test_transient_codes_are_never_dead(code, text):
    """🔴 الأهمّ: عطلٌ عابر لا يُفقد طالباً إشعاراتِه للأبد."""
    from core import push as pu

    class _E(Exception):
        cause = None

        def __str__(self):
            return text

    _E.code = code
    assert pu._is_dead(_E()) is False


def test_none_exception_is_not_dead():
    from core import push as pu
    assert pu._is_dead(None) is False


def test_sdk_shaped_failure_prunes_the_token(client, db, monkeypatch):
    """وبالشكل الحقيقي للاستثناء — لا بالوهميّ وحده — يُحذف الرمز فعلاً."""
    from core import push as pu

    class _RealShaped(_FakeMessaging):
        def send_each_for_multicast(self, message):
            self.sent_messages.append(message)
            return _FakeResponse([False], {0: _SdkUnregistered()})

    monkeypatch.setattr(pu, "_messaging", lambda: _RealShaped())
    _with_device(db, "a", ["ghost-tok"])
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن"}).json()
    assert out["pruned_tokens"] == 1
    assert db.cols["users"]["a"]["fcm_tokens"] == []


def test_registration_survives_the_profile_race(client, db, monkeypatch):
    """🔴 أول دخولٍ على جهاز جديد: الرمز يسبق إنشاء مستند المستخدم.

    اشتراطُ وجود المستند كان يرفضه بـ400 ولا يُعاد إرساله إلا في الإقلاع
    التالي — فوقع فعلاً في أول فحصٍ على جهازٍ حقيقي. و`uid` من توكنٍ
    موثَّق، فالكتابة بالدمج آمنة وتُصلح نفسها.
    """
    _as_student(monkeypatch, "brand-new")          # لا مستند له بعد
    r = client.post("/me/device", headers={"Authorization": "Bearer x"},
                    json={"token": "tok", "platform": "ios"})
    assert r.status_code == 200
    assert r.json()["registered"] is True
    assert db.cols["users"]["brand-new"]["fcm_tokens"] == ["tok"]


def test_registration_still_rejects_an_empty_token(client, db, monkeypatch):
    """وإسقاطُ شرطِ المستند لا يُسقط التحقق من المدخل نفسه."""
    user(db, "me")
    _as_student(monkeypatch, "me")
    r = client.post("/me/device", headers={"Authorization": "Bearer x"},
                    json={"token": "   "})
    assert r.status_code == 400


# ══════════════════════════════════════════════════
# 🎯 ١٠ — استهداف طالبٍ بعينه
# ══════════════════════════════════════════════════
# 🔴 **الفخّ الذي يجعل الخطأ كارثياً وصامتاً:** `[]` قيمةٌ كاذبة في بايثون.
#    فـ`if uids:` كانت تعامل «لم تختر أحداً» كـ«استعمل الشريحة» — أدمنٌ
#    يفتح وضع «طلاب محدّدون» ولا يختار أحداً فيصل إعلانُه **الشريحةَ كلها**.

def test_specific_student_receives_and_others_do_not(client, db, fcm):
    _with_device(db, "target", ["tok-t"], grade=3, track="علمي")
    _with_device(db, "other", ["tok-o"], grade=3, track="علمي")
    out = client.post("/admin/notifications", headers=HDR, json={
        "title": "خاص", "body": "لك وحدك", "uids": ["target"]}).json()

    assert out["recipient_count"] == 1
    assert out["users_reached"] == 1
    assert db.cols["notifications"][out["id"]]["recipients"] == ["target"]
    assert [x["id"] for x in notif.inbox("target")] == [out["id"]]
    assert notif.inbox("other") == []


def test_empty_uid_list_never_falls_back_to_the_segment(client, db, fcm):
    """🔴 «لم تختر أحداً» ≠ «أرسل للجميع» — وهذا ما كان يحدث."""
    _with_device(db, "a", ["t1"])
    _with_device(db, "b", ["t2"])
    r = client.post("/admin/notifications", headers=HDR, json={
        "title": "ت", "body": "ن", "segment": "all", "uids": []})
    assert r.status_code == 400
    assert "لا مستلم" in r.json()["error"]
    assert db.cols.get("notifications", {}) == {}     # ولم يُنشأ شيء


def test_null_uids_still_means_use_the_segment(client, db, fcm):
    """والغياب يبقى على معناه — وإلا انكسر كل إرسالٍ بشريحة."""
    user(db, "a", grade=3, track="علمي")
    user(db, "b", grade=3, track="أدبي")
    out = client.post("/admin/notifications", headers=HDR, json={
        "title": "ت", "body": "ن", "segment": "g3_sci", "uids": None}).json()
    assert out["recipient_count"] == 1


def test_preview_reports_unknown_uids(client, db):
    """معرّفٌ لا حساب له يُقال صراحةً بدل أن يُبتلع فيظنّه الأدمن مستلماً."""
    user(db, "real")
    d = client.post("/admin/notifications/preview", headers=HDR,
                    json={"uids": ["real", "ghost"]}).json()
    assert d["recipients"] == 1
    assert d["unknown_uids"] == ["ghost"]


def test_picked_students_ignore_the_segment_entirely(client, db):
    """اختيارُ الأعيان يعلو على الشريحة — وإلا تقاطعا بلا معنى."""
    user(db, "first", grade=1, track="عام")
    d = client.post("/admin/notifications/preview", headers=HDR,
                    json={"segment": "g3_sci", "uids": ["first"]}).json()
    assert d["recipients"] == 1
    assert "مجموعة محدّدة" in d["segment_label"]


def test_picked_banned_student_is_still_excluded(client, db):
    """⛔ الاختيار الصريح لا يتخطّى الحظر — إشعارُ من منعناه تناقض."""
    user(db, "bad", banned=True)
    d = client.post("/admin/notifications/preview", headers=HDR,
                    json={"uids": ["bad"]}).json()
    assert d["recipients"] == 0
    assert d["excluded_banned"] == 1


def test_picked_muted_student_can_be_included_deliberately(client, db):
    """ومن أطفأ الإشعارات يُستثنى افتراضياً، ويُشمل بقرارٍ صريح."""
    user(db, "muted", settings={"notif_general": False})
    body = {"uids": ["muted"], "notifications_only": True}
    assert client.post("/admin/notifications/preview", headers=HDR,
                       json=body).json()["recipients"] == 0
    body["notifications_only"] = False
    assert client.post("/admin/notifications/preview", headers=HDR,
                       json=body).json()["recipients"] == 1


# ══════════════════════════════════════════════════
# 🧭 ١١ — وجهة النقر تصل الجهاز
# ══════════════════════════════════════════════════

def test_link_travels_in_the_data_payload(client, db, fcm):
    """بلا `link` في `data` يفتح الإشعارُ الرئيسيةَ دائماً مهما اخترتَ."""
    _with_device(db, "a", ["tok"])
    out = client.post("/admin/notifications", headers=HDR, json={
        "title": "ت", "body": "ن", "link": "quiz"}).json()
    data = fcm.sent_messages[0]["data"]
    assert data["link"] == "quiz"
    assert data["notification_id"] == out["id"]


@pytest.mark.parametrize("link", ["education", "quiz", "analysis",
                                  "scholarships", "teacher", "services", "none"])
def test_every_offered_link_is_accepted(client, db, fcm, link):
    """كل وجهةٍ تعرضها اللوحة يجب أن يقبلها الخادم — وإلا خيارٌ يفشل عند الضغط."""
    _with_device(db, "a", ["tok"])
    r = client.post("/admin/notifications", headers=HDR,
                    json={"title": "ت", "body": "ن", "link": link})
    assert r.status_code == 200
    assert r.json()["link"] == link


def test_inbox_carries_the_link_for_a_cold_open(client, db, fcm):
    """التطبيق يقرأ الصندوق عند الإقلاع — فالوجهة تلزمه هناك أيضاً."""
    user(db, "a")
    client.post("/admin/notifications", headers=HDR,
                json={"title": "ت", "body": "ن", "link": "analysis"})
    assert notif.inbox("a")[0]["link"] == "analysis"


# ══════════════════════════════════════════════════
# 🗄️ ١٢ — اللوحة تُعلن مخزنها
# ══════════════════════════════════════════════════
# 🔴 عطلٌ حقيقيٌّ وقع: المالك يسجّل دخوله من التطبيق فيُكتب حسابه في
#    Firestore، واللوحة أمامه يقدّمها خادمٌ على مخزنٍ محليٍّ للتطوير. فبحث
#    عن حسابه بين حساباتٍ مبذورة فلم يجده، واستنتج أن اللوحة معطوبة — وهي
#    تعمل بلا خطأ واحد، لكن على بياناتٍ أخرى. صفحةٌ لا تُعلن مخزنها تجعل
#    كل رقمٍ فيها قابلاً لتفسيرين.

def test_store_info_says_none_without_firestore(monkeypatch):
    monkeypatch.setattr(q, "_firestore", lambda: None)
    st = adm.store_info()
    assert st["kind"] == "none" and st["live"] is False and st["warning"]


def test_store_info_names_the_live_project(db):
    db.project = "masar-prod"
    st = adm.store_info()
    assert st["kind"] == "firestore" and st["live"] is True
    assert "masar-prod" in st["label"] and not st["warning"]


def test_store_info_flags_a_development_store(db):
    """⚠️ المخزن يُعرّف نفسه — ولا يُستنتج بغياب سمةٍ في مكتبة جوجل."""
    db.masar_store_kind = "dev-local"
    st = adm.store_info()
    assert st["kind"] == "dev" and st["live"] is False
    assert "ليست" in st["warning"]


def test_overview_declares_its_store(client, db):
    user(db, "a")
    st = client.get("/admin/overview", headers=HDR).json()["store"]
    assert st["kind"] == "firestore"


def test_notifications_tab_declares_its_store(client, db):
    """التبويب يُفتح مباشرةً من `#notif` بلا المرور بالأرقام — فيحمل الوسم بنفسه."""
    user(db, "a")
    assert client.get("/admin/notifications", headers=HDR).json()["store"]["kind"]


# ══════════════════════════════════════════════════
# 📭 ١٣ — «بانتظار الإرسال» لا تُقال لما لا ينتظر
# ══════════════════════════════════════════════════
# 🔴 وقع فعلاً: أُرسل إلى «ثالث علمي» فبقي «⏳ بانتظار الإرسال» أبداً، فظُنّ
#    الإرسالُ معطوباً. ولم يكن فيه عطل: لم يكن في الشريحة كلها جهازٌ واحد.
#    وحالتان لا رابط بينهما تحت اسمٍ واحد تجعلان الأدمن ينتظر ما لا يأتي.

def test_segment_without_devices_is_not_left_waiting(client, db, fcm):
    user(db, "a", grade=3, track="علمي")
    user(db, "b", grade=3, track="علمي")
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن", "segment": "g3_sci"}).json()

    assert out["status"] == "no_devices"          # ⛔ ليست "pending"
    assert out["recipient_count"] == 2            # الاستهداف نفسه سليم
    assert out["devices"] == 0
    assert "لا شيء ينتظر" in out["delivered_note"]


def test_missing_transport_stays_pending(client, db, monkeypatch):
    """الحالة الأخرى تبقى متمايزة: هنا ينتظر شيءٌ فعلاً — إعدادُ ناقل."""
    from core import push as pu
    monkeypatch.setattr(pu, "_messaging", lambda: None)
    user(db, "a", grade=3, track="علمي")
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن", "segment": "g3_sci"}).json()
    assert out["status"] == "pending"
    assert "ناقل" in out["delivered_note"]


def test_reason_is_stored_with_the_record_not_recomputed(client, db, fcm):
    """⚠️ حالةُ اليوم تُقرأ بعد شهر — وقد تغيّر الناقل والأجهزة بينهما."""
    user(db, "a", grade=3, track="علمي")
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن", "segment": "g3_sci"}).json()
    assert db.cols["notifications"][out["id"]]["reason"]
    row = client.get("/admin/notifications", headers=HDR).json()["items"][0]
    assert row["status"] == "no_devices" and row["reason"]


def test_a_reached_send_is_still_called_sent(client, db, fcm):
    """الحالة الجديدة لا تبتلع القديمة: جهازٌ واحدٌ وصله ⇒ «أُرسل»."""
    _with_device(db, "a", ["tok"], grade=3, track="علمي")
    user(db, "b", grade=3, track="علمي")
    out = client.post("/admin/notifications", headers=HDR,
                      json={"title": "ت", "body": "ن", "segment": "g3_sci"}).json()
    assert out["status"] == "sent" and out["users_reached"] == 1


# ══════════════════════════════════════════════════
# 🕳️ ١٤ — مستندٌ بلا ملفٍّ شخصي يُقال عنه ذلك
# ══════════════════════════════════════════════════
# `POST /me/device` يُنشئ `users/{uid}` حين يسبق تسجيلُ الجهاز كتابةَ الملف
# عند أول دخول (سباقٌ وقع فعلاً). والنتيجة صفٌّ بلا اسمٍ ولا صفّ: جهازٌ
# مسجَّلٌ لا يصله إعلانُ «ثالث علمي» أبداً، والخانة الفارغة لا تقول لماذا.

def test_profileless_document_is_flagged_in_the_table(client, db):
    db.cols.setdefault("users", {})["ghost"] = {"fcm_tokens": ["tok"]}
    user(db, "real", grade=3, track="علمي")
    rows = client.get("/admin/users", headers=HDR).json()["users"]
    ghost = next(r for r in rows if r["uid"] == "ghost")
    real = next(r for r in rows if r["uid"] == "real")
    assert ghost["profile_incomplete"] is True and ghost["devices"] == 1
    assert real["profile_incomplete"] is False


def test_profileless_document_matches_no_grade_segment(client, db, fcm):
    """⭐ الوسم ليس تجميلاً: هذا الحساب سببُ صمتٍ كامل لا تفصيلٌ في الجدول."""
    db.cols.setdefault("users", {})["ghost"] = {"fcm_tokens": ["tok"]}
    d = client.post("/admin/notifications/preview", headers=HDR,
                    json={"segment": "g3_sci"}).json()
    assert d["recipients"] == 0 and d["devices"] == 0
