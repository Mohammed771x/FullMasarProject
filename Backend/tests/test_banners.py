"""🎏 البانرات: البوابة، التحقق، النافذة الزمنية، والتوليد التلقائي من المنح.

الترتيب يعكس المخاطر:
  1. **البوابة** — مسار كتابة مفتوح يعني إعلاناً يكتبه أي أحد لكل الطلاب.
  2. **التوقيع** — عليه تقوم كلفة القراءة (طلبٌ يومي واحد بدل كل فتحة).
  3. **التوليد التلقائي** — بانر «تقفل بعد ٣ أيام» خاطئ يُضيّع منحة.
"""
import pytest
from fastapi.testclient import TestClient

import api
from core import admin as adm
from core import banners as bn
from core import quota as q
from core import ratelimit as rl
from core import scholarships as sch

from test_scholarships import _DB, _FakeFS  # noqa: E402


@pytest.fixture()
def db(monkeypatch):
    fake = _DB()
    fake.cols.setdefault("banners", {})
    monkeypatch.setattr(q, "_firestore", lambda: fake)
    import sys
    import types
    module = types.ModuleType("firebase_admin.firestore")
    module.SERVER_TIMESTAMP = _FakeFS.SERVER_TIMESTAMP
    module.Increment = _FakeFS.Increment
    parent = sys.modules.get("firebase_admin")
    monkeypatch.setitem(sys.modules, "firebase_admin.firestore", module)
    if parent is not None:
        monkeypatch.setattr(parent, "firestore", module, raising=False)
    bn.reset_cache()
    yield fake
    bn.reset_cache()


@pytest.fixture()
def client(no_real_api_calls, monkeypatch):
    rl._buckets.clear()
    q.reset_memory()
    monkeypatch.setattr(adm, "ADMIN_KEY", "s3cret-key")
    monkeypatch.setattr(adm, "ADMIN_EMAILS", set())
    return TestClient(api.app)


HDR = {"X-Admin-Key": "s3cret-key"}


# ══════════ ١) البوابة ══════════

@pytest.mark.parametrize("method,path", [
    ("get", "/admin/banners"),
    ("post", "/admin/banners"),
    ("put", "/admin/banners/x"),
    ("delete", "/admin/banners/x"),
    ("post", "/admin/banner-templates"),
])
def test_admin_routes_closed_without_key(client, db, method, path):
    kwargs = {"json": {}} if method in ("post", "put") else {}
    res = getattr(client, method)(path, **kwargs)
    assert res.status_code in (401, 403), f"{path} مفتوح بلا مفتاح!"


# ══════════ ٢) التحقق ══════════

def test_title_required(db):
    with pytest.raises(bn.BannerError):
        bn.validate({"section": "home", "title": "  "})


def test_unknown_section_rejected(db):
    with pytest.raises(bn.BannerError):
        bn.validate({"section": "المطبخ", "title": "أهلاً"})


def test_unknown_icon_falls_back_not_crashes(db):
    """أيقونة مجهولة ⇒ نجمة. الرفض هنا يمنع حفظ بانر صحيح لسبب تافه."""
    assert bn.validate({"section": "home", "title": "ت", "icon": "🍕"})["icon"] == "star"


def test_bad_color_replaced_by_identity(db):
    out = bn.validate({"section": "home", "title": "ت", "colors": ["أزرق", "#112233"]})
    assert out["colors"] == ["#112233", "#112233"]


def test_bad_date_rejected(db):
    with pytest.raises(bn.BannerError):
        bn.validate({"section": "home", "title": "ت", "start_date": "2026/01/01"})


# ══════════ ٣) النافذة الزمنية ══════════

def test_banner_outside_window_hidden(db):
    bn.create({"section": "home", "title": "عيد سعيد",
               "start_date": "2026-01-01", "end_date": "2026-01-05"})
    out = bn.list_public(today="2026-06-01")
    assert out["sections"]["home"] == []
    out = bn.list_public(today="2026-01-03")
    assert [b["title"] for b in out["sections"]["home"]] == ["عيد سعيد"]


def test_disabled_banner_hidden(db):
    made = bn.create({"section": "quiz", "title": "اختبر نفسك"})
    bn.set_enabled(made["id"], False)
    assert bn.list_public(today="2026-06-01")["sections"]["quiz"] == []


# ══════════ ٤) التوقيع ══════════

def test_signature_short_circuits(db):
    bn.create({"section": "home", "title": "ت"})
    sig = bn.signature("2026-06-01")
    out = bn.list_public(sig, today="2026-06-01")
    assert out["changed"] is False and out["sections"] == {}


def test_signature_changes_with_day(db):
    """⭐ اليوم جزء من التوقيع: «تقفل بعد ٥ أيام» تصير «٤» بلا كتابة أحد."""
    assert bn.signature("2026-06-01") != bn.signature("2026-06-02")


def test_signature_changes_after_write(db):
    before = bn.signature("2026-06-01")
    bn.create({"section": "home", "title": "جديد"})
    assert bn.signature("2026-06-01") != before


# ══════════ ٥) التوليد التلقائي من المنح ══════════

def _add_scholarship(open_date, close_date, name="منحة الهند", sid="india"):
    sch.create(sid, {
        "name": name, "country": "الهند", "short_desc": "وصف",
        "open_date": open_date, "close_date": close_date, "enabled": True,
    })
    sch.reset_cache()


def test_auto_banner_for_closing_soon(db):
    _add_scholarship("2026-01-01", "2026-06-10")
    out = bn.auto_banners(today="2026-06-01")
    assert len(out) == 1
    assert "تقفل بعد 9 يوم" in out[0]["title"]
    assert out[0]["action"] == "scholarship" and out[0]["action_value"] == "india"


def test_closing_wins_over_open(db):
    """منحة مفتوحة وتقفل بعد أيام ⇒ رسالة واحدة عاجلة لا رسالتان متنافستان."""
    _add_scholarship("2026-01-01", "2026-06-05")
    out = bn.auto_banners(today="2026-06-01")
    assert len(out) == 1 and "تقفل" in out[0]["title"]


def test_auto_banner_for_open_far_from_closing(db):
    _add_scholarship("2026-01-01", "2026-12-31")
    out = bn.auto_banners(today="2026-06-01")
    assert len(out) == 1 and "فتحت أبوابها" in out[0]["title"]


def test_auto_banner_for_upcoming(db):
    _add_scholarship("2026-06-20", "2026-09-01")
    out = bn.auto_banners(today="2026-06-01")
    assert len(out) == 1
    assert out[0]["title"].startswith("قريباً")
    assert "19 يوم" in out[0]["subtitle"]


def test_no_auto_banner_for_distant_scholarship(db):
    """تفتح بعد سنة ⇒ لا بانر. البانر البعيد ضوضاء تُفقد البقية قيمتها."""
    _add_scholarship("2027-06-20", "2027-09-01")
    assert bn.auto_banners(today="2026-06-01") == []


def test_closed_scholarship_has_no_banner(db):
    _add_scholarship("2025-01-01", "2025-03-01")
    assert bn.auto_banners(today="2026-06-01") == []


def test_disabled_scholarship_has_no_banner(db):
    _add_scholarship("2026-01-01", "2026-12-31")
    sch.set_enabled("india", False)
    sch.reset_cache()
    assert bn.auto_banners(today="2026-06-01") == []


def test_template_can_be_disabled(db):
    _add_scholarship("2026-01-01", "2026-12-31")
    bn.set_templates({"sch_open": {"enabled": False, "title": "x", "subtitle": ""}})
    assert bn.auto_banners(today="2026-06-01") == []


def test_template_text_is_editable(db):
    _add_scholarship("2026-01-01", "2026-12-31")
    bn.set_templates({"sch_open": {
        "enabled": True, "title": "🔥 {name} متاحة", "subtitle": "قدّم", "icon": "fire",
        "colors": ["#FF0000", "#990000"]}})
    out = bn.auto_banners(today="2026-06-01")
    assert out[0]["title"] == "🔥 منحة الهند متاحة"
    assert out[0]["icon"] == "fire"


def test_auto_banners_come_after_manual(db):
    """ما كتبه الأدمن بيده أولى بالصدارة من المولَّد."""
    _add_scholarship("2026-01-01", "2026-12-31")
    bn.create({"section": "home", "title": "إعلان يدوي", "order": 5})
    home = bn.list_public(today="2026-06-01")["sections"]["home"]
    assert [b["title"] for b in home][0] == "إعلان يدوي"
    assert home[-1]["auto"] is True


# ══════════ ٦) واجهة الطالب ══════════

def test_public_view_hides_admin_fields(db):
    bn.create({"section": "home", "title": "ت",
               "start_date": "2020-01-01", "end_date": "2030-01-01"})
    item = bn.list_public(today="2026-06-01")["sections"]["home"][0]
    assert "start_date" not in item and "enabled" not in item


def test_all_sections_present_even_when_empty(db):
    """التطبيق يقرأ `sections[القسم]` مباشرةً — الغياب يعني انهياراً هناك."""
    out = bn.list_public(today="2026-06-01")
    assert set(out["sections"].keys()) == set(bn.SECTIONS)


def test_public_endpoint_survives_without_firestore(client, monkeypatch):
    """🛡️ البانر تزيينٌ — غيابه لا يُسقط الشاشة الرئيسية."""
    monkeypatch.setattr(q, "_firestore", lambda: None)
    res = client.get("/banners")
    assert res.status_code == 200 and res.json()["sections"] == {}


def test_max_banners_enforced(db, monkeypatch):
    monkeypatch.setattr(bn, "MAX_BANNERS", 2)
    bn.create({"section": "home", "title": "١"})
    bn.create({"section": "home", "title": "٢"})
    with pytest.raises(bn.BannerError):
        bn.create({"section": "home", "title": "٣"})


# ══════════ ٧) 🎯 الفئة المستهدفة ══════════
# ⚠️ **الفخّ الذي يجب ألّا يقع:** استهدافٌ يكسر التطبيقات القديمة. النسخة
#    التي لا ترسل صفّها يجب أن ترى كل شيء كما كانت — وإلا صار تحسينٌ في
#    اللوحة انقطاعاً في جيوب الطلاب الذين لم يُحدّثوا.

def test_segment_defaults_to_everyone(db):
    bn.create({"section": "home", "title": "للجميع"})
    item = bn.list_public(today="2026-06-01", grade=1, track="عام")["sections"]["home"][0]
    assert item["segment"] == "all"


def test_targeted_banner_reaches_only_its_segment(db):
    bn.create({"section": "home", "title": "لثالث علمي", "segment": "g3_sci"})
    seen = lambda g, t: [b["title"] for b in
                         bn.list_public(today="2026-06-01", grade=g, track=t)["sections"]["home"]]
    assert seen(3, "علمي") == ["لثالث علمي"]
    assert seen(3, "أدبي") == []
    assert seen(1, "عام") == []


def test_old_client_without_grade_still_sees_everything(db):
    """🛟 نسخةٌ لم تُحدَّث لا تُحرَم — وتصلها `segment` لتصفّي بنفسها."""
    bn.create({"section": "home", "title": "لثالث علمي", "segment": "g3_sci"})
    items = bn.list_public(today="2026-06-01")["sections"]["home"]
    assert [b["title"] for b in items] == ["لثالث علمي"]
    assert items[0]["segment"] == "g3_sci"


def test_signature_separates_grades(db):
    """طالبٌ يصحّح صفّه لا تبقى بصمتُه فيظلّ يرى بانرات صفٍّ تركه."""
    assert bn.signature("2026-06-01", 1, "عام") != bn.signature("2026-06-01", 3, "علمي")
    assert bn.signature("2026-06-01", 3, "علمي") == bn.signature("2026-06-01", 3, "علمي")


def test_activity_segment_refused_for_banners(db):
    """بانرٌ يظهر ويختفي بنشاط الطالب اليومي ضوضاءٌ لا رسالة."""
    with pytest.raises(bn.BannerError):
        bn.create({"section": "home", "title": "ت", "segment": "inactive"})


def test_unknown_segment_refused(db):
    with pytest.raises(bn.BannerError):
        bn.create({"section": "home", "title": "ت", "segment": "g9"})


def test_endpoint_filters_by_grade(client, db):
    bn.create({"section": "home", "title": "لأول", "segment": "g1"})
    out = client.get("/banners?grade=3&track=علمي").json()
    assert out["sections"]["home"] == []
    out = client.get("/banners?grade=1&track=عام").json()
    assert [b["title"] for b in out["sections"]["home"]] == ["لأول"]


def test_auto_banners_are_never_hidden_by_targeting(db):
    """التلقائي من المنح للجميع — لا فئة له فلا يُصفّى بها."""
    _add_scholarship("2026-01-01", "2026-12-31")
    # التلقائي يُعرض في الرئيسية (`home`) لا في قسم المنح — انظر [auto_banners].
    autos = bn.list_public(today="2026-06-01", grade=1,
                           track="عام")["sections"]["home"]
    assert any(b.get("auto") for b in autos)
