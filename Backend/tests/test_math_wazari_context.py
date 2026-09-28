# -*- coding: utf-8 -*-
"""📝 وزاري الرياضيات — المتابعةُ من سياق **المحادثة** لا من ذاكرة الخادم.

🎯 **أمرُ المالك (٢٠٢٦-٠٩-٢٧):** بعد وصول الأسئلة يسأل الطالب «السؤال رقم
   ثلاثة وضّحه لي» — فيذهب للموديل آخرُ ست رسائل، والدرسُ الذي خرجت منه
   الأسئلة، والسؤال. «ولو رجع بعدين على المحادثة يوجد نفس الدرس».

☢️ **ما كان:** الأسئلةُ المعروضة في `sessions_math[user_id]` وحده — لكل
   طالبٍ لا لكل محادثة، تموت بعد نصف ساعة ومع كل إعادة تشغيل. فالعائدُ
   إلى محادثته يُقال له «يرجى جلب الأسئلة أولاً»، أو يُشرح له سؤالٌ من
   محادثةٍ أخرى جلب فيها درساً آخر.
"""
import asyncio

import pytest
from pydantic import ValidationError

import subjects.math as m
from models import AskRequest
from subjects.shared.lens import calc_check_rules, teaching_core
from subjects.shared.rules import CALC_CHECK_RULES

BRANCH, YEAR = "تفاضل", "2024"
LESSON_A = "مشتقة الدوال المثلثية الدائرية"      # ١٠ أسئلة
LESSON_B = "مبرهنة رول"                           # ٣ أسئلة


def _req(content, *, lesson=LESSON_A, year=YEAR, shown=None, history=None, uid="u1"):
    return AskRequest(
        user_id=uid, subject="رياضيات", mode="وزاري", input_type="برومت",
        content=content, unit_name=BRANCH, lesson_name=lesson,
        chat_history=history, exam_year=year, exam_shown=shown,
    )


@pytest.fixture
def captured(monkeypatch):
    """يلتقط ما يُرسل للموديل بدل النداء الحقيقي."""
    box = {}

    async def fake_complete(client, **kw):
        box.update(kw)
        return "الجواب"

    monkeypatch.setattr(m.streaming, "complete", fake_complete)
    return box


def _run(req, sessions):
    return asyncio.run(m.handle_math_exams(req, sessions, None, None))


def _questions(lesson, n):
    return m.get_math_exam_questions(BRANCH, YEAR, lesson, n)["questions"]


# ── ١. الرجوعُ إلى المحادثة بعد موت الجلسة ──────────────────────────

def test_follow_up_survives_empty_server_memory(captured):
    """🔴 العلّة: خادمٌ أُعيد تشغيله (جلساتٌ فارغة) ⇒ «يرجى جلب الأسئلة»."""
    out = _run(_req("وضح لي السؤال رقم ٣", shown=5), sessions={})
    assert out["answer"] == "الجواب"
    msgs = captured["messages"]
    context = msgs[1]["content"]
    q3 = _questions(LESSON_A, 3)[2]["نص_السؤال"].split("\n")[0]
    assert "📌 السؤال 3:" in context and q3 in context
    assert "📌 السؤال 6:" not in context, "يُعاد ما عُرض وحده لا الدرسُ كلُّه"
    assert out["session_active"] is True, "بقيت ٥ من ١٠ — «كمل» تظهر"


def test_follow_up_sends_lesson_question_and_last_six(captured):
    history = [
        {"role": "user" if i % 2 == 0 else "assistant", "content": f"رسالة {i}"}
        for i in range(10)
    ]
    _run(_req("وضح السؤال ٢", shown=3, history=history), sessions={})
    msgs = captured["messages"]
    # نظامٌ ثم الأسئلةُ ثم آخرُ ستٍّ ثم سؤالُ الطالب.
    assert [x["content"] for x in msgs[2:8]] == [f"رسالة {i}" for i in range(4, 10)]
    last = msgs[-1]["content"]
    assert "بيانات الدرس" in last and "سؤال الطالب: وضح السؤال ٢" in last
    lesson_text = m.format_lesson_safely(m.load_math_lesson(BRANCH, LESSON_A))
    assert lesson_text and lesson_text[:80] in last, "الدرسُ الذي خرجت منه الأسئلة"


# ── ٢. عزلُ المحادثات ─────────────────────────────────────────────────

def test_other_conversation_session_never_leaks(captured):
    """☢️ جلسةُ الطالب تحمل درساً آخر (محادثةٌ ثانية) — لا تُقرأ أبداً."""
    sessions = {"u1": {
        "mode": "وزاري", "branch": BRANCH, "year": YEAR, "lesson": LESSON_B,
        "displayed_questions": _questions(LESSON_B, 3), "shown_count": 3,
        "has_more": False,
    }}
    _run(_req("وضح السؤال ١", lesson=LESSON_A, shown=2), sessions)
    context = captured["messages"][1]["content"]
    assert LESSON_A in context and LESSON_B not in context


def test_new_client_without_questions_does_not_fall_back(captured):
    """عميلٌ جديد بلا أسئلةٍ في محادثته ⇒ «اجلب أولاً»، لا جلسةُ غيرها."""
    sessions = {"u1": {
        "mode": "وزاري", "branch": BRANCH, "year": YEAR, "lesson": LESSON_B,
        "displayed_questions": _questions(LESSON_B, 3), "shown_count": 3,
    }}
    out = _run(_req("وضح السؤال ١", shown=0), sessions)
    assert "يرجى جلب الأسئلة" in out["answer"]
    assert not captured, "لا نداءَ للموديل"


def test_old_client_keeps_session_behaviour(captured):
    """🕸️ عميلٌ قديم لا يرسل السياق (`exam_shown=None`) ⇒ الجلسةُ كما كانت."""
    sessions = {"u1": {
        "mode": "وزاري", "branch": BRANCH, "year": YEAR, "lesson": LESSON_B,
        "displayed_questions": _questions(LESSON_B, 3), "shown_count": 3,
        "has_more": False,
    }}
    _run(_req("وضح السؤال ١", lesson="", year="", shown=None), sessions)
    assert LESSON_B in captured["messages"][1]["content"]


# ── ٣. «كمل» بلا ذاكرة ────────────────────────────────────────────────

def test_continue_is_stateless_and_numbers_continue():
    out = _run(_req("كمل", shown=4), sessions={})
    assert "📌 السؤال 5:" in out["answer"] and "📌 السؤال 4:" not in out["answer"]
    assert "📌 السؤال 10:" in out["answer"]
    assert out["session_active"] is False, "عُرضت العشرةُ كلُّها"


def test_unknown_year_is_rejected_safely(captured):
    out = _run(_req("وضح السؤال ١", year="../../etc", shown=3), sessions={})
    assert "يرجى جلب الأسئلة" in out["answer"] and not captured


# ── ٤. الحدود ─────────────────────────────────────────────────────────

@pytest.mark.parametrize("bad", [-1, 501])
def test_exam_shown_is_bounded(bad):
    with pytest.raises(ValidationError):
        _req("x", shown=bad)


# ── ٥. «يشيك على الحسابات» ────────────────────────────────────────────

def test_wazari_prompt_checks_arithmetic(captured):
    _run(_req("وضح السؤال ١", shown=2), sessions={})
    assert CALC_CHECK_RULES in captured["messages"][0]["content"]
    assert "راجع كلَّ ناتجٍ حسابيٍّ" in captured["messages"][-1]["content"]


@pytest.mark.parametrize("subject", ["رياضيات", "فيزياء", "كيمياء", "منطق"])
def test_deepseek_subjects_carry_the_check(subject):
    assert CALC_CHECK_RULES in teaching_core(subject)


@pytest.mark.parametrize("subject", ["تاريخ", "عربي", "احياء"])
def test_narrative_subjects_stay_lean(subject):
    assert calc_check_rules(subject) == ""
    assert CALC_CHECK_RULES not in teaching_core(subject)


def test_math_explain_and_question_prompts_carry_the_check():
    assert CALC_CHECK_RULES in m.system_prompt_math_explain()
    import inspect
    assert "CALC_CHECK_RULES" in inspect.getsource(m.handle_math_question)


@pytest.mark.parametrize("subject,expected", [
    ("فيزياء", 1), ("كيمياء", 1), ("منطق", 1), ("رياضيات", 1),
    ("تاريخ", 0), ("عربي", 0),
])
@pytest.mark.parametrize("mode", ["شرح", "سؤال", "تلخيص"])
def test_rule_reaches_every_sent_prompt_exactly_once(subject, expected, mode):
    """⚠️ **يقيس البرومبتَ المُرسَل لا المكتوب** ([[prompt-spine]]): الشرحُ
    والتلخيصُ لا يمرّان بـ`teaching_core`، فالإلحاقُ هناك وحده كان يترك
    الشرحَ — أكثرَ ما يُطلب — بلا مراجعة. ومرّةً واحدة: لا تكرار."""
    from core import lesson_mode, pages_mode
    from subjects.shared import prompts as P
    sent = [
        lesson_mode._system_prompt(mode, subject, 3, None),
        pages_mode._system_prompt(mode, subject, 3, None),
    ]
    if mode == "شرح":
        sent.append(P.system_prompt_strict_explain(subject))   # physics/chemistry
    for p in sent:
        assert p.count(CALC_CHECK_RULES) == expected
