# -*- coding: utf-8 -*-
"""🧮 «اشرح لي» في الرياضيات — زرٌّ واحدٌ لكل المواد.

⚖️ **قرار المالك (2026-09-16):** «في الرياضيات، قسم اشرح لي وموجود أصلاً
   المساعدة حق اشرح. خلّه موجود، احذف الأولية، والثانية تحلّ محلّ الأولية —
   بنفس الوظيفة، نفس ذاك اللي يتخزّن الجلسة، ولما يسأل الطالب يسأل مع
   الشرح حقه.»

🔴 **وما كان معطّلاً**: الرياضياتُ وحدها تعرف «الحقلَ الفارغ» طلباً للشرح،
   لأن زرَّها القديم «🚀 ابدأ الشرح الذكي» كان يُرسل فراغاً. فلمّا صار زرُّ
   «اشرح لي» واحداً للجميع — وهو يُرسل نصّاً — وقعت ضغطتُه في الرياضيات على
   «سؤالٍ عن الشرح» فذهبت إلى الموديل بلا شرحٍ سابقٍ تسأل عنه.
"""
import inspect

import pytest

from core import lesson_cache as LC
from models import AskRequest
from subjects.math import handle_math_explain, _last_assistant_text


SRC = inspect.getsource(handle_math_explain)


# ══════════════ ① الضغطةُ تُقرأ طلبَ شرحٍ كامل ══════════════

@pytest.mark.parametrize("text", [
    "",                       # الزرُّ القديم (يبقى عاملاً)
    "شرح درس: القطع المكافئ",  # فقاعةُ التطبيق القديمة
    "اشرح لي هذا الدرس",       # ⭐ نصُّ زرّ «اشرح لي» الموحّد
    "اشرح الدرس",
    "اشرح لي الدرس كاملاً",
])
def test_these_reach_the_full_lesson_branch(text):
    """كلُّها «اشرح الدرس» — ولا واحدةَ منها سؤالٌ عن شرحٍ سابق."""
    assert (text == "" or text.startswith("شرح درس:")
            or LC.is_full_lesson_request(text)), text


@pytest.mark.parametrize("text", [
    "بسّط لي الشرح", "ما الفرق بين القطع المكافئ والقطع الناقص؟",
    "أعطني مثالاً", "اشرح لي معادلة البؤرة",
])
def test_a_real_question_stays_a_question(text):
    """⚠️ والحدُّ الآخر يهمّ بقدره: «اشرح لي معادلة البؤرة» سؤالٌ في الدرس
    لا طلبٌ للدرس كلِّه — ولو ابتلعه الفرعُ الأول لضاع سؤالُ الطالب."""
    assert not (text == "" or text.startswith("شرح درس:")
                or LC.is_full_lesson_request(text))


def test_the_handler_uses_the_shared_measure():
    """حارسٌ بنيويّ: الرياضياتُ تدخل الميزةَ من الباب نفسه لا باستثناء."""
    assert "lesson_cache.is_full_lesson_request(user_text)" in SRC


# ══════════════ ② المخزونُ يُسلَّم رغم سجلِّ المحادثة ══════════════

def test_the_cache_gate_is_serves_not_an_empty_history():
    """🔴 **العلّةُ التي كلّفت الميزةَ كلَّها — مرّتين.**

    التطبيق يضيف رسالةَ الطالب إلى `messages` **ثم** يبني منها
    `chat_history`، فيصل السجلُّ وفيه سؤالُه الحالي نفسُه. فشرطُ «السجلّ
    فارغ» لا يتحقّق أبداً في التطبيق الحقيقي: الكاشُ مبنيٌّ ومختبَرٌ
    ويعمل في قياساتنا، **ولا يصل الطالبَ ولا مرّة** ([lesson_cache.serves]).
    """
    assert "if not req.chat_history:" not in SRC
    assert "lesson_cache.serves(req)" in SRC


def test_serves_accepts_the_math_button_text():
    """والمقياسُ المشترك يقبل ضغطةَ «اشرح لي» ومعها رسالةُ الطالب نفسُها."""
    req = AskRequest(subject="رياضيات", grade=3, track="علمي", mode="شرح",
                     input_type="برومت", content="اشرح لي هذا الدرس",
                     unit_name="هندسة", lesson_name="القطع المكافئ",
                     chat_history=[{"role": "user", "content": "اشرح لي هذا الدرس"}])
    assert LC.serves(req)


def test_serves_refuses_once_an_answer_exists():
    """ومن شُرح له ثم قال «اشرح الدرس» يريد متابعةً لا نسخةً جاهزة."""
    req = AskRequest(subject="رياضيات", grade=3, track="علمي", mode="شرح",
                     input_type="برومت", content="اشرح لي هذا الدرس",
                     unit_name="هندسة", lesson_name="القطع المكافئ",
                     chat_history=[{"role": "user", "content": "اشرح"},
                                   {"role": "assistant", "content": "شرحٌ سابق"}])
    assert not LC.serves(req)


# ══════════════ ③ السؤالُ يحمل الشرحَ معه ولو ماتت الجلسة ══════════════

def test_the_explanation_is_recovered_from_the_conversation():
    """🧵 «ولما يسأل الطالب يسأل مع الشرح حقه» — بالجلسة **أو** بالمحادثة.

    جلسةُ الخادم ذاكرةٌ هشّة: تموت بإعادة تشغيلٍ أو بعامِلٍ آخر، **ولا
    تُنشأ أصلاً** حين يُعرض الشرحُ من سحب التطبيق المسبق. فبلا الاسترداد
    يسقط سؤالُ الطالب إلى «درسٌ جديد» فيُعاد شرحُ الدرس بدل أن يُجاب.
    """
    history = [
        {"role": "user", "content": "اشرح لي هذا الدرس"},
        {"role": "assistant", "content": "شرحُ القطع المكافئ كاملاً…"},
        {"role": "user", "content": "ما البؤرة؟"},
    ]
    assert _last_assistant_text(history) == "شرحُ القطع المكافئ كاملاً…"


def test_recovery_ignores_anything_that_is_not_an_assistant_turn():
    assert _last_assistant_text([]) == ""
    assert _last_assistant_text(None) == ""
    assert _last_assistant_text([{"role": "user", "content": "س"}]) == ""
    assert _last_assistant_text(["نصٌّ لا قاموس"]) == ""


def test_the_handler_recovers_before_falling_to_a_fresh_lesson():
    """والاستردادُ **قبل** فرع «درسٌ جديد» وإلا لم ينفع في شيء."""
    assert "_last_assistant_text(req.chat_history)" in SRC
    assert (SRC.index("_last_assistant_text(req.chat_history)")
            < SRC.index("الحالة 3"))
