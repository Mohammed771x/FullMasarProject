"""اختبارات تكامل عبر TestClient — الموديلات تُستبدل بمحاكيات (لا نداء خارجي)."""
import json
import pytest
from fastapi.testclient import TestClient

import api
from core import ratelimit as rl


# العملاء الوهميون يُحقنون تلقائياً من conftest — لا نداءات خارجية.


@pytest.fixture()
def client(no_real_api_calls):
    rl._buckets.clear()
    return TestClient(api.app)


def _ask_body(**over):
    body = {
                "subject": "فيزياء", "mode": "شرح", "input_type": "برومت",
        "summary_level": 3, "content": "", "unit_name": "", "lesson_name": "",
        "chat_history": [], "grade": 3, "track": "علمي",
    }
    body.update(over)
    return body


# ══════════ /content/subjects ══════════
def test_subjects_grade3_scientific(client):
    r = client.get("/content/subjects", params={"grade": 3, "track": "علمي"})
    assert r.status_code == 200
    assert "احياء" in r.json()["subjects"]

def test_subjects_grade1_forced_common(client):
    r = client.get("/content/subjects", params={"grade": 1, "track": "علمي"})
    assert r.json()["track"] == "عام"
    assert len(r.json()["subjects"]) == 9


# ══════════ /content/capabilities ══════════
def test_caps_physics_has_lessons_tree(client):
    """الفيزياء مرجع وضع الدروس — شجرتها تصل كاملةً مع القدرات.
    (لا نؤكّد غياب الصفحات: المالك يملأ الوضعين معاً، وقد فعل.)"""
    r = client.get("/content/capabilities", params={"subject": "فيزياء"})
    d = r.json()
    assert d["lessons"]["available"] is True
    assert d["lessons"]["units"] and d["lessons"]["units"][0]["lessons"]

def test_caps_biology_has_pages(client):
    """الأحياء مرجع وضع الوحدات — وحداتها تصل مع القدرات.
    (لا نؤكّد هنا غياب الدروس: المالك يملأ الوضعين معاً، وقد فعل.)"""
    d = client.get("/content/capabilities", params={"subject": "احياء"}).json()
    assert d["pages"]["available"] is True
    assert d["pages"]["units"]

def test_caps_math_lessons_only_by_decision(client):
    d = client.get("/content/capabilities", params={"subject": "رياضيات"}).json()
    assert d["lessons"]["available"] is True
    assert d["pages"]["available"] is False    # قرار المالك: الرياضيات دروس فقط

def test_caps_unknown_subject_404(client):
    r = client.get("/content/capabilities", params={"subject": "تاريخ", "grade": 3, "track": "علمي"})
    assert r.status_code == 404

def test_caps_path_traversal_rejected(client):
    r = client.get("/content/capabilities", params={"subject": "../../etc/passwd"})
    assert r.status_code == 404


# ══════════ /ask — وضع الدروس ══════════
def test_ask_lessons_mode_injects_full_lesson(client):
    caps = client.get("/content/capabilities", params={"subject": "فيزياء"}).json()
    unit = caps["lessons"]["units"][0]["unit"]
    lesson = caps["lessons"]["units"][0]["lessons"][0]
    r = client.post("/ask", json=_ask_body(content_mode="lessons", unit_name=unit,
                                           lesson_name=lesson, content="اشرح لي"))
    assert r.status_code == 200
    d = r.json()
    assert "::" in d["answer"]
    assert "نص الدرس" in d["answer"]           # السياق حُقن فعلاً
    assert d["references"]

def test_ask_lessons_mode_missing_content_friendly(client, empty_lessons_target):
    grade, track, subject = empty_lessons_target
    r = client.post("/ask", json=_ask_body(subject=subject, grade=grade, track=track,
                                           content_mode="lessons", lesson_name="أي درس"))
    assert r.status_code == 200
    assert "قيد الإضافة" in r.json()["answer"]  # لا ملف دروس لهذه المادة بعد

def test_ask_lessons_mode_lesson_not_found(client):
    r = client.post("/ask", json=_ask_body(content_mode="lessons", lesson_name="درس وهمي"))
    assert "لم أجد" in r.json()["answer"]


# ══════════ /ask — وضع الوحدات/الصفحات ══════════
def test_ask_pages_mode_missing_content_friendly(client, empty_pages_target):
    grade, track, subject = empty_pages_target
    r = client.post("/ask", json=_ask_body(subject=subject, grade=grade, track=track,
                                           content_mode="pages",
                                           input_type="صفحة", content="12"))
    assert "قيد الإضافة" in r.json()["answer"]  # لا ملف صفحات لهذه المادة بعد

def test_ask_pages_mode_biology_legacy_kept(client):
    # الأحياء بالثالث العلمي تذهب لمعالجها الأصلي حتى مع content_mode=pages
    r = client.post("/ask", json=_ask_body(subject="احياء", content_mode="pages",
                                           input_type="صفحة", content="41"))
    assert r.status_code == 200
    assert r.json()["references"], "معالج الأحياء الأصلي أرجع مراجع الصفحات"


def test_ask_pages_mode_serves_any_subject_with_unit_mode(client):
    """📄 **جوهر وضع الوحدات:** يُخدَم بوجود ملف `unit_mode` لا باسم المادة.

    كانت الشاشة (لا الخادم) تسأل عن الاسم، فمادةٌ عُبِّئت وحداتها — الكيمياء —
    لا تنال ما نالته الأحياء. نختبر هنا **أي** مادة غير الأحياء لها وحدات:
    وحداتها تصل مع القدرات، وطلبُ صفحةٍ منها يرجع مراجع صفحات فعلية.
    """
    from core.curriculum import subjects_for
    target = None
    for subject in subjects_for(3, "علمي"):
        if subject == "احياء":
            continue                      # لها معالجها الأصلي (اختبارٌ مستقل)
        caps = client.get("/content/capabilities",
                          params={"subject": subject, "grade": 3, "track": "علمي"}).json()
        if caps["pages"]["available"] and caps["pages"]["units"]:
            target = (subject, caps["pages"]["units"][0])
            break
    if target is None:
        pytest.skip("لا مادة أخرى لها وضع وحدات بعد")

    subject, unit = target
    r = client.post("/ask", json=_ask_body(subject=subject, unit_name=unit,
                                           content_mode="pages", input_type="صفحة",
                                           content=_first_page_number(subject, unit)))
    assert r.status_code == 200
    assert r.json()["references"], "طلب الصفحة يجب أن يرجع مراجع صفحات"


def _first_page_number(subject, unit) -> str:
    """رقم صفحة موجود فعلاً في تلك الوحدة — لا رقم مخترع."""
    from core.content_store import get_pages_book
    book = get_pages_book(3, "علمي", subject) or []
    for u in book:
        if (u.get("اسم_الوحدة") or "").strip() == unit:
            return str(u["الصفحات"][0]["رقم_الصفحة"])
    return "1"


# ══════════ /ask — التوافق الرجعي ══════════
def test_ask_legacy_no_content_mode_untouched(client):
    # طلب قديم بلا content_mode → المسار القديم بالضبط (معالج الفيزياء الأصلي)
    r = client.post("/ask", json=_ask_body(content="القوة"))
    assert r.status_code == 200
    assert "answer" in r.json()

def test_ask_without_token_401(client, anonymous):
    """🗑️ بعد حذف الأكواد: التوكن أو 401 — ولا ثالث."""
    r = client.post("/ask", json=_ask_body())
    assert r.status_code == 401

def test_ask_wazari_never_uses_v3(client):
    # الوزاري يبقى على المسار القديم حتى لو أُرسل content_mode
    r = client.post("/ask", json=_ask_body(mode="وزاري", content_mode="lessons",
                                           content="2024,القوة"))
    assert r.status_code == 200


# ══════════ الحدود والأمان ══════════
def test_ask_rate_limited_429(client):
    body = _ask_body(content_mode="lessons", lesson_name="x")
    for _ in range(rl.ASK_LIMIT):
        client.post("/ask", json=body)
    r = client.post("/ask", json=body)
    assert r.status_code == 429

def test_oversized_content_rejected(client):
    r = client.post("/ask", json=_ask_body(content="ن" * 9000))
    assert r.status_code == 422               # Pydantic يرفض قبل أي معالجة

def test_chat_history_capped_not_rejected(client):
    hist = [{"role": "user", "content": "س" * 5000}] * 30
    r = client.post("/ask", json=_ask_body(content_mode="lessons", lesson_name="x",
                                           chat_history=hist))
    assert r.status_code == 200               # يُقصّ بصمت — لا يُرفض
