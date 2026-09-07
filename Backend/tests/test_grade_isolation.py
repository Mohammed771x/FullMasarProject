"""عزل الصفوف: لا يرث صفٌّ محتوى صفٍّ آخر — لا في القوائم ولا في /ask.

الخلل المُصلَح: طالب الصف الأول يفتح «انجليزي» فيرى محتوى الثالث الثانوي العلمي،
لأن كل مسارات المحتوى القديمة كانت تفترض (3، علمي) عند غياب الصف.
"""
import pytest
from fastapi.testclient import TestClient

import api
from core import ratelimit as rl
from subjects.common import subject_book_path, math_branch_dir, subject_exams_dir


@pytest.fixture()
def client(no_real_api_calls):
    rl._buckets.clear()
    return TestClient(api.app)


def _ask_body(**over):
    body = {
        "user_id": "test-user", "code": "SUPER_USER", "device_id": "test-dev",
        "subject": "انجليزي", "mode": "شرح", "input_type": "برومت",
        "summary_level": 3, "content": "hello", "unit_name": "", "lesson_name": "",
        "chat_history": [], "grade": 1, "track": "عام",
    }
    body.update(over)
    return body


# ══════════ حلّ المسارات ══════════
def test_book_path_never_leaks_across_grades():
    """ملف الثالث العلمي لا يُرجع أبداً لصف آخر."""
    g3 = subject_book_path("انجليزي", 3, "علمي")
    for grade, track in ((1, "عام"), (2, "علمي"), (2, "أدبي"), (3, "أدبي")):
        assert subject_book_path("انجليزي", grade, track) != g3


def test_math_branch_dir_scoped():
    g3 = math_branch_dir("تفاضل", 3, "علمي")
    assert math_branch_dir("تفاضل", 1, "عام") != g3


def test_exams_dir_flat_bank_is_grade3_only():
    """بنك الوزاري المسطّح `{المادة}/exams/` للثالث العلمي وحده."""
    flat = subject_exams_dir("انجليزي", 3, "علمي")
    assert flat.endswith("exams")
    assert subject_exams_dir("انجليزي", 1, "عام") != flat
    assert subject_exams_dir("انجليزي", 2, "علمي") != flat


# ══════════ قوائم المحتوى ══════════
def test_units_empty_for_grade1(client):
    assert client.get("/subjects/units", params={"subject": "انجليزي"}).json()  # الثالث العلمي فيه محتوى
    assert client.get("/subjects/units",
                      params={"subject": "انجليزي", "grade": 1, "track": "عام"}).json() == []


def test_lessons_empty_for_grade1(client):
    units = client.get("/subjects/units", params={"subject": "انجليزي"}).json()
    assert client.get("/subjects/lessons",
                      params={"subject": "انجليزي", "unit": units[0],
                              "grade": 1, "track": "عام"}).json() == []


def test_units_empty_for_subject_not_in_track(client):
    """احياء غير مقررة على الأدبي ⇒ لا وحدات مهما كان الملف موجوداً."""
    assert client.get("/subjects/units",
                      params={"subject": "احياء", "grade": 3, "track": "أدبي"}).json() == []


def test_exam_years_grade3_only(client):
    assert client.get("/exams/years", params={"subject": "انجليزي"}).json()
    assert client.get("/exams/years",
                      params={"subject": "انجليزي", "grade": 1, "track": "عام"}).json() == []


def test_math_lessons_grade_scoped(client):
    assert client.get("/math/lessons", params={"branch": "تفاضل"}).json()
    assert client.get("/math/lessons",
                      params={"branch": "تفاضل", "grade": 1, "track": "عام"}).json() == []


def test_math_exam_years_grade_scoped(client):
    assert client.get("/math/exams/years",
                      params={"branch": "تفاضل", "grade": 1, "track": "عام"}).json() == []


# ══════════ /ask ══════════
def test_ask_grade1_gets_pending_message_not_grade3_content(client):
    r = client.post("/ask", json=_ask_body())
    assert r.status_code == 200
    assert "لم يُضف بعد" in r.json()["answer"]


def test_ask_wazari_grade1_blocked(client):
    r = client.post("/ask", json=_ask_body(mode="وزاري"))
    assert "لم يُضف بعد" in r.json()["answer"]


def test_ask_math_grade2_blocked(client):
    r = client.post("/ask", json=_ask_body(subject="رياضيات", grade=2, track="علمي"))
    assert "لم يُضف بعد" in r.json()["answer"]


def test_ask_subject_not_in_curriculum_rejected(client):
    r = client.post("/ask", json=_ask_body(subject="احياء", grade=3, track="أدبي"))
    assert r.status_code == 400
    assert "غير مقررة" in r.json()["answer"]


def test_ask_grade3_scientific_still_works(client):
    """التوافق الرجعي: النطاق القديم يمضي في معالجه الأصلي كما كان."""
    r = client.post("/ask", json=_ask_body(subject="فيزياء", grade=3, track="علمي",
                                           content="اشرح الفيزياء الذرية"))
    assert r.status_code == 200
    assert "لم يُضف بعد" not in r.json()["answer"]


# ══════════ القدرات تقود الأوضاع في الواجهة ([31§3]) ══════════
def test_capabilities_report_exam_bank_for_grade3_only(client):
    """الوزاري امتحان وطني للثالث — فلا تظهر شريحته للأول والثاني."""
    g3 = client.get("/content/capabilities",
                    params={"subject": "فيزياء", "grade": 3, "track": "علمي"}).json()
    assert g3["exams"]["available"] is True

    g1 = client.get("/content/capabilities",
                    params={"subject": "فيزياء", "grade": 1, "track": "عام"}).json()
    assert g1["exams"]["available"] is False


def test_capabilities_report_quiz_follows_lessons(client, empty_lessons_target):
    """«اختبر نفسك» يُبنى من الدروس — لكل المواد بنفس القاعدة بلا استثناء."""
    physics = client.get("/content/capabilities",
                         params={"subject": "فيزياء", "grade": 3, "track": "علمي"}).json()
    assert physics["quiz"]["available"] is True
    assert physics["quiz"]["available"] == physics["lessons"]["available"]

    # ومادةٌ بلا دروس بعد ⇒ لا اختبارات، وتعمل فور إضافة دروسها بلا تعديل كود.
    grade, track, subject = empty_lessons_target
    empty = client.get("/content/capabilities",
                       params={"subject": subject, "grade": grade, "track": track}).json()
    assert empty["quiz"]["available"] == empty["lessons"]["available"] is False
