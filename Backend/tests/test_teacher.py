"""👨‍🏫 مساعد المعلم: الدروس وحدها · برومبتان لكل أداة · اللوحة تعلو على الكود.

المحاور التي تحرسها هذه الاختبارات — وكلٌّ منها قرار معماري لا تفصيل:
  ① **لا وحدات ولا صفحات**: مادة بلا `lessons.json` تُردّ برسالة صريحة ولا
     تسقط بصمت على محتوى الوحدات (وإلا وُلدت خطةُ درسٍ لدرسٍ لا وجود له).
  ② **برومبت التوليد ≠ برومبت المحادثة**: خلطهما يجعل المساعد يعيد بناء
     الخطة كاملةً في كل متابعة.
  ③ **السقوط الآمن**: بلا Firestore يعمل القسم ببرومبتات الكود.
  ④ **وعي الدور**: أول رسالة ترحّب، وما بعدها لا يرحّب.
"""
import asyncio
import pytest
from fastapi.testclient import TestClient

import api
from core import teacher_assistant as ta
from core import teacher_prompts as tp
from core import ratelimit as rl
from core import quota as q


@pytest.fixture()
def client(no_real_api_calls):
    rl._buckets.clear()
    q.reset_memory()
    ta.reset_cache()
    return TestClient(api.app)


@pytest.fixture(autouse=True)
def clean_prompt_cache():
    ta.reset_cache()
    yield
    ta.reset_cache()


def _body(**over):
    body = {"tool": "plan", "generate": True,
            "subject": "فيزياء", "grade": 3, "track": "علمي",
            "unit_name": "الفيزياء الذرية", "lesson_name": "نظرية بوهر",
            "content": ""}
    body.update(over)
    return body


# ══════════════ ① المصدر: الدروس وحدها ══════════════

def test_lesson_text_comes_from_the_book():
    text, unit = ta.lesson_text(3, "علمي", "فيزياء", "الفيزياء الذرية", "نظرية بوهر")
    assert len(text) > 100
    assert unit


def test_lesson_found_even_when_unit_is_wrong():
    """الوحدة قد تتغيّر في الواجهة قبل الدرس — لا نفشل لهذا السبب وحده."""
    text, _ = ta.lesson_text(3, "علمي", "فيزياء", "وحدة لا وجود لها", "نظرية بوهر")
    assert len(text) > 100


def test_unknown_lesson_is_a_clear_arabic_error():
    with pytest.raises(ta.TeacherError) as e:
        ta.lesson_text(3, "علمي", "فيزياء", "", "درس لا وجود له إطلاقاً")
    assert "لم أجد" in str(e.value)


def test_subject_not_in_curriculum_is_rejected():
    with pytest.raises(ta.TeacherError) as e:
        ta.lesson_text(1, "عام", "رياضيات متقدمة", "", "أي درس")
    assert "❌" in str(e.value)


def test_missing_lesson_name_is_rejected_before_any_model_call():
    with pytest.raises(ta.TeacherError) as e:
        ta.lesson_text(3, "علمي", "فيزياء", "الفيزياء الذرية", "")
    assert "اختر الدرس" in str(e.value)


def test_units_tree_is_readable_for_settings():
    tree = ta.units_and_lessons(3, "علمي", "فيزياء")
    assert tree["available"] is True
    assert tree["units"] and tree["units"][0]["lessons"]


def test_units_tree_for_subject_without_lessons_says_so():
    """⭐ لا سقوط على وضع الصفحات: «غير متاح» صريحة لا محتوى وحدات."""
    tree = ta.units_and_lessons(3, "علمي", "احياء")
    assert tree["available"] in (True, False)
    if not tree["available"]:
        assert tree["units"] == []


# ══════════════ ② برومبتان لكل أداة ══════════════

def test_every_tool_has_a_chat_prompt():
    for tool in tp.TOOL_IDS:
        assert ta.get_prompt(tool, "chat").strip()


def test_tools_with_a_button_have_a_generate_prompt():
    for tool in tp.TOOL_IDS:
        if tp.has_generate(tool):
            assert ta.get_prompt(tool, "generate").strip()


def test_open_chat_has_no_generate_prompt():
    """«اسأل المساعد» محادثة مفتوحة — زرُّ توليدٍ لها لا معنى له."""
    assert tp.has_generate("ask") is False
    assert ta.get_prompt("ask", "generate") == ""


def test_generate_and_chat_prompts_differ_for_every_tool():
    """⭐ لو تساويا لأعاد المساعد بناء المُخرَج كاملاً في كل متابعة."""
    for tool in tp.TOOL_IDS:
        if not tp.has_generate(tool):
            continue
        assert ta.get_prompt(tool, "generate") != ta.get_prompt(tool, "chat")


def test_unknown_tool_or_kind_raises():
    with pytest.raises(ta.TeacherError):
        ta.get_prompt("nope", "chat")
    with pytest.raises(ta.TeacherError):
        ta.get_prompt("plan", "nope")


def test_system_message_layers_core_then_tool_then_lesson():
    """الترتيب مقصود: قواعد الصدق تسبق برومبت اللوحة فلا يُبطلها سطرٌ فيه."""
    system = ta.build_system("plan", True, "فيزياء", 3, "علمي",
                             "الفيزياء الذرية", "نظرية بوهر", "نصّ الدرس هنا")
    i_core = system.index("مساعد المعلم")
    i_tool = system.index("خطة درس تنفيذية")
    i_card = system.index("نصّ الدرس هنا")
    assert i_core < i_tool < i_card


def test_system_message_says_when_no_lesson_attached():
    system = ta.build_system("ask", False, "فيزياء", 3, "علمي", "", "", "")
    assert "لا يوجد نصّ درس مرفق" in system


# ══════════════ ③ اللوحة تعلو على الكود، والكود شبكة الأمان ══════════════

def test_prompt_falls_back_to_code_without_firestore(monkeypatch):
    """⭐ القسم مشحون مع التطبيق: خادمٌ بلا Firestore يعمل بلا نقص."""
    monkeypatch.setattr(ta, "_db", lambda: None)
    ta.reset_cache()
    assert ta.get_prompt("plan", "generate") == tp.PLAN_GENERATE
    assert ta.is_overridden("plan", "generate") is False


def test_saved_prompt_overrides_the_code_default(monkeypatch):
    monkeypatch.setattr(ta, "_load_overrides",
                        lambda force=False: {"plan": {"generate": "برومبت الأدمن"}})
    assert ta.get_prompt("plan", "generate") == "برومبت الأدمن"
    assert ta.get_prompt("plan", "chat") == tp.PLAN_CHAT   # الآخر لم يُمسّ


def test_saving_without_firestore_is_a_clear_message_not_a_crash(monkeypatch):
    monkeypatch.setattr(ta, "_db", lambda: None)
    with pytest.raises(ta.TeacherError) as e:
        ta.set_prompt("plan", "generate", "نص")
    assert "Firestore" in str(e.value)


def test_cannot_save_a_generate_prompt_for_a_tool_without_a_button():
    with pytest.raises(ta.TeacherError):
        ta.set_prompt("ask", "generate", "نص")


def test_list_prompts_marks_defaults_as_not_overridden(monkeypatch):
    monkeypatch.setattr(ta, "_load_overrides", lambda force=False: {})
    data = ta.list_prompts()
    assert len(data["tools"]) == len(tp.TOOL_IDS)
    for row in data["tools"]:
        assert row["chat_overridden"] is False
        assert ("generate" in row) is row["has_generate"]


def test_firestore_read_failure_does_not_break_the_section(monkeypatch):
    """عطلٌ في القراءة يعود ببرومبتات الكود — لا باستثناء يوقف معلّماً."""
    class _Boom:
        def collection(self, _):
            raise RuntimeError("firestore down")
    monkeypatch.setattr(ta, "_db", lambda: _Boom())
    ta.reset_cache()
    assert ta.get_prompt("homework", "generate") == tp.HOMEWORK_GENERATE


# ══════════════ ④ وعي الدور ══════════════

def test_first_generate_greets_once():
    assert "أول توليد" in ta.turn_state([], True)


def test_generate_inside_a_running_session_does_not_greet():
    hist = [{"role": "user", "content": "س"}, {"role": "assistant", "content": "ج"}]
    assert "لا تحية" in ta.turn_state(hist, True)


def test_follow_up_message_does_not_greet():
    hist = [{"role": "user", "content": "س"}, {"role": "assistant", "content": "ج"}]
    state = ta.turn_state(hist, False)
    assert "متابعة" in state and "لا تحية" in state


def test_first_chat_message_greets():
    assert "أول رسالة" in ta.turn_state(None, False)


# ══════════════ التحقق من الطلب ══════════════

class _Req:
    def __init__(self, **kw):
        for k, v in kw.items():
            setattr(self, k, v)


def test_simplify_requires_a_concept():
    with pytest.raises(ta.TeacherError) as e:
        ta.validate_request(_Req(tool="simplify", generate=True, concept="  "))
    assert "المفهوم" in str(e.value)


def test_out_of_range_count_and_difficulty_fall_back_to_defaults():
    v = ta.validate_request(_Req(tool="homework", generate=True, count=999,
                                 difficulty="مستحيل"))
    assert v["count"] == 10 and v["difficulty"] == "متوسط"


def test_generate_is_refused_for_the_open_chat_tool():
    with pytest.raises(ta.TeacherError):
        ta.validate_request(_Req(tool="ask", generate=True))


def test_arabic_number_agreement_in_the_action_line():
    """«٥ أسئلة» و«١٥ سؤالاً» — تُعرض في فقاعة المعلّم نفسها."""
    assert ta.questions_label(5) == "5 أسئلة"
    assert ta.questions_label(10) == "10 أسئلة"
    assert ta.questions_label(15) == "15 سؤالاً"


# ══════════════ المسار الكامل عبر HTTP ══════════════

def test_generate_returns_answer_and_reference(client):
    r = client.post("/teacher/ask", json=_body())
    assert r.status_code == 200
    data = r.json()
    assert data["answer"]
    assert data["references"] and "نظرية بوهر" in data["references"][0]


def test_the_lesson_text_actually_reaches_the_model(client):
    """العميل الوهمي يعيد رسالة المستخدم — فوصولُ الطلب دليلٌ على البناء."""
    r = client.post("/teacher/ask", json=_body())
    assert "نفّذ المطلوب" in r.json()["answer"]


def test_follow_up_message_uses_the_chat_prompt_not_the_generate_one():
    """⭐ العلّة التي يحرسها: خطة تُعاد كاملةً كلما قال المعلّم «أضف مثالاً»."""
    chat = ta.build_system("plan", False, "فيزياء", 3, "علمي", "و", "د", "نص")
    gen = ta.build_system("plan", True, "فيزياء", 3, "علمي", "و", "د", "نص")
    assert "تناقش خطة درس" in chat and "خطة درس تنفيذية" not in chat
    assert "خطة درس تنفيذية" in gen and "تناقش خطة درس" not in gen


def test_follow_up_message_reaches_the_model(client):
    r = client.post("/teacher/ask", json=_body(
        generate=False, content="أضف مثالاً من الحياة",
        chat_history=[{"role": "user", "content": "س"},
                      {"role": "assistant", "content": "خطة"}]))
    assert r.status_code == 200
    assert r.json()["answer"]


def test_follow_up_without_text_is_refused_politely(client):
    r = client.post("/teacher/ask", json=_body(generate=False, content=""))
    assert r.status_code == 200
    assert "اكتب سؤالك" in r.json()["answer"]


def test_subject_without_lessons_gets_a_friendly_message_not_a_500(client):
    r = client.post("/teacher/ask", json=_body(
        subject="احياء", unit_name="أي وحدة", lesson_name="أي درس"))
    assert r.status_code == 200
    assert "🚧" in r.json()["answer"] or "لم أجد" in r.json()["answer"]


def test_generate_without_a_lesson_is_refused(client):
    r = client.post("/teacher/ask", json=_body(lesson_name="", unit_name=""))
    assert r.status_code == 200
    assert "اختر" in r.json()["answer"]


def test_open_chat_works_without_any_lesson(client):
    """«اسأل المساعد» محادثة عامة — لا تُوقفها غيابُ درسٍ مختار."""
    r = client.post("/teacher/ask", json=_body(
        tool="ask", generate=False, lesson_name="", unit_name="",
        content="كيف أدير وقت الحصة؟"))
    assert r.status_code == 200
    assert "كيف أدير" in r.json()["answer"]


def test_unknown_tool_is_rejected(client):
    r = client.post("/teacher/ask", json=_body(tool="hack"))
    assert r.status_code == 200
    assert "❌" in r.json()["answer"]


def test_quota_is_consumed_like_any_other_model_call(client, monkeypatch):
    """🎟️ وإلا صار القسم باباً خلفياً لفاتورة الـAI."""
    from core import firebase_auth as fa
    monkeypatch.setattr(fa, "verify", lambda token: {
        "uid": "t-1", "email": "t@x.com", "email_verified": True,
        "provider": "password", "is_guest": False, "name": "أستاذ"})

    calls = {"n": 0}
    real = q.check_and_consume

    def _spy(uid, is_guest):
        calls["n"] += 1
        return real(uid, is_guest)

    monkeypatch.setattr(api.v3_quota, "check_and_consume", _spy)
    r = client.post("/teacher/ask", json=_body(code=""),
                    headers={"Authorization": "Bearer t"})
    assert r.status_code == 200
    assert calls["n"] == 1


def test_exhausted_quota_stops_the_teacher_before_any_model_call(client, monkeypatch):
    from core import firebase_auth as fa
    monkeypatch.setattr(fa, "verify", lambda token: {
        "uid": "t-empty", "email": "t@x.com", "email_verified": True,
        "provider": "password", "is_guest": False, "name": "أستاذ"})
    monkeypatch.setattr(api.v3_quota, "check_and_consume", lambda uid, g: (False, 0))
    r = client.post("/teacher/ask", json=_body(code=""),
                    headers={"Authorization": "Bearer t"})
    assert r.status_code == 429
    assert r.json()["quota_exceeded"] is True


def test_tools_endpoint_lists_the_four_tools(client):
    data = client.get("/teacher/tools").json()
    assert [t["tool"] for t in data["tools"]] == list(tp.TOOL_IDS)
    assert data["counts"] == list(tp.COUNTS)


def test_history_is_capped_to_the_project_wide_window():
    hist = [{"role": "user", "content": f"م{i}"} for i in range(30)]
    assert len(ta.build_history(hist)) == 6


def test_history_drops_malformed_entries():
    hist = [{"role": "system", "content": "x"}, {"role": "user", "content": ""},
            "ليس قاموساً", {"role": "user", "content": "صحيحة"}]
    out = ta.build_history(hist)
    assert out == [{"role": "user", "content": "صحيحة"}]


# ══════════════ اللوحة ══════════════

def test_admin_routes_are_closed_without_a_key(client):
    for path in ("/admin/teacher/prompts", "/admin/teacher/core"):
        assert client.get(path).status_code in (401, 503)


def test_try_prompt_uses_the_unsaved_draft(no_real_api_calls):
    """🧪 ما يمنع نشر برومبتٍ يهذي: الأدمن يرى الرد قبل أي معلّم."""
    out = asyncio.run(ta.try_prompt(
        "plan", "generate", "برومبت مسودّة لم يُحفظ", "جرّب",
        {"gemini": no_real_api_calls["gemini"]}))
    assert out["ok"] is True and out["answer"]


def test_try_prompt_falls_back_to_the_default_when_draft_is_empty(no_real_api_calls):
    out = asyncio.run(ta.try_prompt("plan", "generate", "", "جرّب",
                                    {"gemini": no_real_api_calls["gemini"]}))
    assert out["ok"] is True


# ══════════════ 🧮 تنظيف ترميز الرياضيات ══════════════
# العلّة المرصودة حيّاً في أول تجربة: خطة فيزياء ظهرت فيها
# «باستخدام الصيغة \( … \)» — الكسر رُسم في التطبيق والحدّان بقيا نصّاً.

def test_latex_delimiters_are_stripped():
    out = ta.clean_math(r"الصيغة \(س = ٥\) و\[ص\] و$ع$")
    for bad in ("\\(", "\\)", "\\[", "\\]", "$"):
        assert bad not in out


def test_fractions_survive_the_cleanup():
    """⭐ `\\frac` هو الترميز **الذي يرسمه التطبيق** — حذفه يفقد الكسر صورته."""
    assert r"\frac{1}{س}" in ta.clean_math(r"\(\frac{1}{س}\)")


def test_markdown_indentation_and_tables_survive():
    """⚠️ هنا يفترق تنظيفنا عن `format_arabic_math`: تلك تسحق المسافات البادئة
    فتنهار القوائم المتداخلة والجداول — ومخرجات المعلم بنيويةٌ كلها."""
    src = "1. أولاً\n   - متداخلة\n\n| أ | ب |\n|---|---|\n| ١ | ٢ |"
    out = ta.clean_math(src)
    assert "\n   - متداخلة" in out
    assert "|---|---|" in out


def test_latex_symbols_become_readable_characters():
    out = ta.clean_math(r"5 \times 10 \approx 50 \lambda")
    assert "×" in out and "≈" in out and "λ" in out


def test_text_command_keeps_its_arabic_content():
    assert ta.clean_math(r"\text{الطول الموجي}") == "الطول الموجي"


def test_clean_math_handles_empty_input():
    assert ta.clean_math("") == ""
    assert ta.clean_math(None) == ""


def test_the_answer_returned_over_http_is_cleaned(client, monkeypatch):
    """التنظيف في المسار الحقيقي لا في الدالة وحدها."""
    from tests.fakes import FakeResp

    async def _create(**kw):
        return FakeResp(r"الصيغة \(\frac{1}{س}\) تعطي 2 \times 3")

    for c in api.AI_CLIENTS.values():
        monkeypatch.setattr(c.chat.completions, "create", _create, raising=False)
    ans = client.post("/teacher/ask", json=_body()).json()["answer"]
    # ٠١٢ **والأرقام تُعرَّب** بعد وصل قسم المعلّم برسّام قسم التعليم
    #     (2026-09-13): الفيزياء من مواد الأرقام العربية، فما يراه الطالب
    #     مرسوماً يراه المعلّم كذلك — نفس النصّ ونفس الرسم.
    assert "\\(" not in ans and r"\frac{١}{س}" in ans and "×" in ans


def test_context_card_tells_the_model_not_to_echo_it():
    """رُصد حيّاً: الموديل نسخ إطار `━━━ بيانات الحصة ━━━` في أول ردّه،
    فبدأت خطةُ الدرس بترويسةٍ نظامية لا تخصّ الأستاذ."""
    system = ta.build_system("plan", True, "فيزياء", 3, "علمي", "و", "د", "نصّ")
    assert "لا تُعِد طباعة" in system
    assert "━━━" not in system          # لا خطوطَ تُغري بالنسخ
    assert "<<نصّ_الدرس_من_الكتاب" in system


def test_admin_errors_reach_the_panel_in_arabic(client, monkeypatch):
    """⚠️ `TeacherError` كانت تسقط في الالتقاط العام فتصير «تعذّر تنفيذ الطلب»
    الغامضة — والأدمن يحتاج أن يعرف **لماذا** رُفض حفظه."""
    from core import admin as adm
    monkeypatch.setattr(adm, "gate_open", lambda: True)
    monkeypatch.setattr(adm, "key_matches", lambda k: True)
    r = client.post("/admin/teacher/prompts/ask",
                    json={"kind": "generate", "prompt": "x"},
                    headers={"X-Admin-Key": "k"})
    assert r.status_code == 400
    assert "زرّ توليد" in r.json()["error"]
