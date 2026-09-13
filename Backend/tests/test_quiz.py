"""«اختبر نفسك»: التوليد من نصّ الدروس، والتحقق الصارم من كل سؤال."""
import asyncio
import json
import pytest
from fastapi.testclient import TestClient

import api
from core import quiz
from core import ratelimit as rl
from core import quota as q


@pytest.fixture()
def client(no_real_api_calls):
    rl._buckets.clear()
    q.reset_memory()
    return TestClient(api.app)


def _body(**over):
    body = {"subject": "فيزياء", "grade": 3, "track": "علمي",
            "unit": "الفيزياء الذرية", "lessons": ["نظرية بوهر"], "count": 5}
    body.update(over)
    return body


VALID = {"questions": [
    {"q": "ما تعريف نظرية بوهر؟", "options": ["أ", "ب", "ج", "د"],
     "correct_index": 0, "topic": "نظرية بوهر", "lesson": "نظرية بوهر"}]}


# ══════════ قراءة رد الموديل ══════════
def test_extract_json_plain():
    assert quiz.extract_json(json.dumps(VALID))["questions"]


def test_extract_json_inside_code_fence():
    """الموديلات تغلّف JSON بعلامات ``` كثيراً."""
    raw = "```json\n" + json.dumps(VALID) + "\n```"
    assert quiz.extract_json(raw)["questions"]


def test_extract_json_with_surrounding_text():
    raw = "تفضل الأسئلة:\n" + json.dumps(VALID) + "\nبالتوفيق!"
    assert quiz.extract_json(raw)["questions"]


def test_extract_json_garbage_returns_none():
    assert quiz.extract_json("لا يوجد جيسون هنا") is None
    assert quiz.extract_json("") is None


# ══════════ التحقق من الأسئلة ══════════
def _q(**over):
    base = {"q": "سؤال", "options": ["١", "٢", "٣", "٤"], "correct_index": 1,
            "topic": "مفهوم", "lesson": "نظرية بوهر"}
    base.update(over)
    return base


def test_rejects_wrong_option_count():
    data = {"questions": [_q(options=["١", "٢", "٣"])]}
    assert quiz.validate(data, 5, ["نظرية بوهر"]) == []


def test_rejects_duplicate_options():
    """خياران متطابقان ⇒ سؤال فاسد لا يُعرض على طالب."""
    data = {"questions": [_q(options=["١", "١", "٣", "٤"])]}
    assert quiz.validate(data, 5, ["نظرية بوهر"]) == []


def test_rejects_out_of_range_correct_index():
    for bad in (-1, 4, "1", None):
        data = {"questions": [_q(correct_index=bad)]}
        assert quiz.validate(data, 5, ["نظرية بوهر"]) == [], bad


def test_rejects_empty_question_or_option():
    assert quiz.validate({"questions": [_q(q="  ")]}, 5, []) == []
    assert quiz.validate({"questions": [_q(options=["١", "", "٣", "٤"])]}, 5, []) == []


def test_drops_duplicate_questions():
    data = {"questions": [_q(q="نفس السؤال"), _q(q="نفس   السؤال")]}
    assert len(quiz.validate(data, 5, [])) == 1


def test_caps_at_requested_count():
    data = {"questions": [_q(q=f"سؤال {i}") for i in range(20)]}
    assert len(quiz.validate(data, 5, [])) == 5


def test_lesson_outside_selection_is_corrected_not_dropped():
    """الموديل قد يخطئ في اسم الدرس — ننسبه لأول درس مطلوب بدل رمي السؤال."""
    data = {"questions": [_q(lesson="درس غريب")]}
    out = quiz.validate(data, 5, ["نظرية بوهر"])
    assert out and out[0]["lesson"] == "نظرية بوهر"


def test_topic_falls_back_when_missing():
    out = quiz.validate({"questions": [_q(topic="")]}, 5, ["نظرية بوهر"])
    assert out[0]["topic"] == "نظرية بوهر"


def test_validate_handles_malformed_payloads():
    for bad in (None, [], {"questions": "نص"}, {"questions": [None, 5]}):
        assert quiz.validate(bad, 5, []) == []


# ══════════ توزيع مواقع الإجابات ══════════
def _questions(n, idx=0):
    """أسئلة كما تخرج من الموديل: الإجابة الصحيحة في الموقع نفسه دائماً."""
    return [{"q": f"سؤال {i}", "options": [f"{i}أ", f"{i}ب", f"{i}ج", f"{i}د"],
             "correct_index": idx, "topic": "ت", "lesson": "د"} for i in range(n)]


def test_spread_moves_answer_off_first_position():
    """العلّة الأصلية: الموديل يضع الإجابة في «أ» دائماً فيحفظها الطالب."""
    out = quiz.spread_answers(_questions(12, idx=0))
    positions = {item["correct_index"] for item in out}
    assert positions == {0, 1, 2, 3}


def test_spread_is_balanced_every_four_questions():
    """كل أربعة أسئلة = المواقع الأربعة مرةً لكلٍّ — فلا تتكتّل الإجابات صدفةً."""
    out = quiz.spread_answers(_questions(12, idx=2))
    for start in (0, 4, 8):
        block = [item["correct_index"] for item in out[start:start + 4]]
        assert sorted(block) == [0, 1, 2, 3]


def test_spread_keeps_correct_option_text():
    """التبديل يحرّك الموقع لا المعنى: الخيار الصحيح يبقى هو هو."""
    questions = _questions(8, idx=0)
    expected = [item["options"][item["correct_index"]] for item in questions]
    out = quiz.spread_answers(questions)
    for item, text in zip(out, expected):
        assert item["options"][item["correct_index"]] == text
        assert len(item["options"]) == 4
        assert len(set(item["options"])) == 4


def test_spread_handles_empty_list():
    assert quiz.spread_answers([]) == []


# ══════════ توجيه الموديل حسب المادة ══════════
def test_each_subject_routes_to_its_own_model():
    """قرار المالك: لكل مادة موديلها — والاختبار يستعمل موديل الشرح نفسه."""
    from core.curriculum import model_route
    assert model_route("رياضيات") == ("deepseek", "deepseek-chat")
    assert model_route("فيزياء")[0] == "openai"
    assert model_route("كيمياء")[0] == "openai"
    assert model_route("احياء")[0] == "gemini"


def test_generate_calls_the_subject_model_not_a_fallback():
    """لا بديل صامت: لو نودي عميل غير عميل المادة لم نعد نعرف من يسأل الطالب."""
    seen = {}

    class _Reply:
        def __init__(self):
            self.choices = [type("C", (), {"message": type(
                "M", (), {"content": json.dumps(VALID)})()})()]

    class _Completions:
        def __init__(self, key):
            self.key = key

        async def create(self, model, **kw):
            seen["client"], seen["model"] = self.key, model
            return _Reply()

    def _client(key):
        return type("X", (), {"chat": type("Y", (), {
            "completions": _Completions(key)})()})()

    clients = {k: _client(k) for k in ("gemini", "openai", "deepseek")}
    out = asyncio.run(quiz.generate(
        3, "علمي", "رياضيات", "تفاضل", ["اتصال الدوال المثلثية"], 5, clients))
    assert seen["client"] == "deepseek"
    assert out["provider"] == "deepseek" and out["model"] == "deepseek-chat"


def test_missing_subject_client_errors_instead_of_switching_silently():
    """بلا بديل صامت: مادةٌ بلا عميلها تتوقف بصوتٍ عالٍ لا تُحوَّل لموديل آخر."""
    with pytest.raises(quiz.QuizError, match="غير مهيّأ"):
        asyncio.run(quiz.generate(3, "علمي", "رياضيات", "تفاضل",
                                  ["اتصال الدوال المثلثية"], 5, {"gemini": object()}))


# ══════════ تجميع نصّ الدروس ══════════
def test_collect_rejects_subject_not_in_curriculum():
    with pytest.raises(quiz.QuizError, match="غير مقررة"):
        quiz.collect_lessons_text(3, "أدبي", "احياء", "", [], )


def test_collect_reports_missing_lessons_content(empty_lessons_target):
    """مادة بلا دروس بعد ⇒ رسالة ودّية لا انهيار — وتعمل تلقائياً فور
    إضافة دروسها بلا تعديل كود."""
    grade, track, subject = empty_lessons_target
    with pytest.raises(quiz.QuizError, match="لم تُضف بعد"):
        quiz.collect_lessons_text(grade, track, subject, "أي وحدة", [])


def test_collect_rejects_unknown_unit():
    with pytest.raises(quiz.QuizError, match="لم أجد الوحدة"):
        quiz.collect_lessons_text(3, "علمي", "فيزياء", "وحدة لا توجد", [])


def test_collect_caps_at_three_lessons():
    text, used = quiz.collect_lessons_text(
        3, "علمي", "فيزياء", "الفيزياء الذرية",
        ["فيزياء الذرة", "نظرية بوهر", "إشعاع الجسم الأسود", "سلاسل طيف ذرة الهيدروجين"])
    assert len(used) == quiz.MAX_LESSONS == 3


def test_collect_falls_back_to_unit_lessons_when_none_chosen():
    text, used = quiz.collect_lessons_text(3, "علمي", "فيزياء", "الفيزياء الذرية", [])
    assert used and len(used) <= quiz.MAX_LESSONS
    assert "━━━ الدرس:" in text


# ══════════ نقطة النهاية ══════════
def test_endpoint_requires_auth(client, anonymous):
    r = client.post("/quiz/generate", json=_body())
    assert r.status_code == 401


def test_activation_code_no_longer_opens_the_endpoint(client, anonymous):
    """🗑️ الكود المدفون في التطبيق كان يفتح توليد الاختبارات بلا حصة."""
    assert client.post("/quiz/generate",
                       json=_body(code="SUPER_USER")).status_code == 401


def test_endpoint_returns_friendly_message_for_empty_content(client, empty_lessons_target):
    grade, track, subject = empty_lessons_target
    r = client.post("/quiz/generate", json=_body(
        subject=subject, unit="أي وحدة", lessons=[], grade=grade, track=track))
    assert r.status_code == 200
    assert "لم تُضف بعد" in r.json()["answer"]
    assert r.json()["questions"] == []


def test_endpoint_handles_model_returning_garbage(client):
    """العميل الوهمي يرد نصاً لا JSON ⇒ رسالة ودّية بعد إعادة المحاولة."""
    r = client.post("/quiz/generate", json=_body())
    assert r.status_code == 200
    assert "questions" in r.json()
    assert r.json()["questions"] == []


def test_request_model_caps_lessons_and_count():
    from models import QuizRequest
    r = QuizRequest(subject="فيزياء", lessons=["أ", "ب", "ج", "د", "هـ"], count=7, grade=9)
    assert len(r.lessons) == 3        # سقف المالك
    assert r.count == 10              # قيمة غير مسموحة ⇒ الافتراضي
    assert r.grade == 3               # صف غير صالح ⇒ الافتراضي


def test_quota_is_consumed_for_quiz(client, monkeypatch):
    """الاختبار نداء موديل ⇒ يُحتسب من الحصة (الزائر يجرّبه ضمن الخمس)."""
    from core import firebase_auth as fa
    monkeypatch.setattr(fa, "verify", lambda t: {
        "uid": "guest-quiz", "email": "", "email_verified": True,
        "provider": "anonymous", "is_guest": True, "name": ""})
    q.reset_memory()
    before = q.peek("guest-quiz", is_guest=True)
    client.post("/quiz/generate", json=_body(), headers={"Authorization": "Bearer t"})
    assert q.peek("guest-quiz", is_guest=True) == before - 1


# ══════════ فخّ هروب JSON ══════════
def test_repairs_frac_swallowed_by_json_escape():
    """`\\frac` بشرطة مفردة داخل JSON = الهروب `\\f`، فيصل «\x0crac».
    بلا هذا الإصلاح يرى الطالب كسراً مشوّهاً."""
    data = {"questions": [_q(q="ما قيمة \x0crac{لو أ}{لو ب}؟",
                             options=["\x0crac{١}{٢}", "٢", "٣", "٤"])]}
    out = quiz.validate(data, 5, [])
    assert out[0]["q"].startswith("ما قيمة \\frac{لو أ}")
    assert out[0]["options"][0] == "\\frac{١}{٢}"


def test_repair_leaves_clean_text_untouched():
    assert quiz.repair_escapes("\\frac{أ}{ب} سليم") == "\\frac{أ}{ب} سليم"
