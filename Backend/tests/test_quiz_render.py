# -*- coding: utf-8 -*-
"""🧠🖌️ «اختبر نفسك» — رسّامُ كل مادةٍ في سؤالها وخياراتها.

🔴 **ما طلبه المالك (2026-09-13):**
   «شوف اختبر نفسك — كل مادة وكل فرع. كل الأشياء اللي طبقناها في موضوع
    الرسّام تتطبّق عليه: الكيمياء وأشياؤها الحلقية والمعادلات، الفيزياء
    والأرقام العربية، الرياضيات كل شيء. عشان لما تطلع الأسئلة والإجابات
    للطالب تطلع بشكل دقيق.»

   والاختبارُ يسأل عن **نفس الدروس** التي يشرحها القسم التعليمي، فلا يجوز
   أن تُرسم الحلقةُ في الشرح ويأتي سؤالُ الاختبار عنها اسماً مجرّداً، ولا
   أن تكون أرقامُ الفيزياء عربيةً هناك ولاتينيةً هنا.

⚖️ والفحصُ على **ثلاث طبقات**، لأن أيَّ واحدةٍ تكفي لإفساد الشاشة:
   ① البرومبت: هل عرف الموديلُ ترميزَ مادته؟
   ② التحقق: هل مرّ السؤالُ والخيارات والموضوع بلمسات الرسّام؟
   ③ المسار الكامل: هل وصل ذلك كلُّه عبر HTTP إلى الواجهة؟
"""
import json

import pytest
from fastapi.testclient import TestClient

import api
from core import quiz, quiz_prompt
from core import quota as q
from core import ratelimit as rl


@pytest.fixture()
def client(no_real_api_calls):
    rl._buckets.clear()
    q.reset_memory()
    return TestClient(api.app)


# ══════════════════ ① البرومبت: لكل مادةٍ رسّامُها ══════════════════

_ALL = ["كيمياء", "فيزياء", "احياء", "رياضيات", "عربي", "انجليزي",
        "منطق", "تاريخ", "جغرافيا", "فلسفة", "مجتمع",
        "علم الاقتصاد", "علم الاجتماع", "مبادئ علم الخرائط"]


@pytest.mark.parametrize("subject", _ALL)
def test_every_subject_quiz_prompt_has_the_fraction_rule(subject):
    """🧮 الكسرُ يُرسم في اختبار كل مادة — لا في الشرح وحده."""
    assert r"\frac" in quiz_prompt.system_prompt(subject, 10)


@pytest.mark.parametrize("subject", ["رياضيات", "فيزياء", "منطق"])
def test_arabic_digits_rule_reaches_the_quiz_of_its_subjects(subject):
    """٠١٢ وأرقامُ الاختبار عربيةٌ في موادّها — كما في الشرح تماماً."""
    assert "٠١٢" in quiz_prompt.system_prompt(subject, 10)


@pytest.mark.parametrize("subject", ["كيمياء"])
def test_organic_rules_reach_the_chemistry_quiz(subject):
    """⚗️ وحلقاتُ الكيمياء وسلاسلُها تصل برومبتَ الاختبار."""
    prompt = quiz_prompt.system_prompt(subject, 10)
    assert r"\ring{6|ar}" in prompt and r"\chem{" in prompt
    assert "لا ترسم مركّباً لم يرد في الدرس" in prompt


@pytest.mark.parametrize("subject", ["فيزياء", "احياء", "عربي", "تاريخ"])
def test_chemistry_only_rules_stay_in_chemistry(subject):
    """🔒 والقاعدةُ العضوية تبقى في مادتها — التوسيعُ ليس تعميماً."""
    assert "لا ترسم مركّباً لم يرد في الدرس" not in \
        quiz_prompt.system_prompt(subject, 10)


def test_quiz_prompt_warns_about_json_escaping():
    """⚠️ الشرطةُ المفردة داخل JSON تُفسد السؤال أو تُسقط الاختبار."""
    assert "مضاعفة" in quiz_prompt.system_prompt("رياضيات", 10)


# ══════════════════ ② التحقق: السؤال والخيارات والموضوع ══════════════════

def _payload(q_text, options=None, topic="مفهوم"):
    return {"questions": [{
        "q": q_text,
        "options": options or ["أ", "ب", "ج", "د"],
        "correct_index": 0, "topic": topic, "lesson": "درس",
    }]}


def test_chemistry_quiz_lowers_formula_indices():
    """⚗️ «H2SO4» تصل الطالبَ «H₂SO₄» — كما يراها في شرحه."""
    out = quiz.validate(_payload("ما تركيز H2SO4؟"), 1, [], "كيمياء")
    assert out and "H₂SO₄" in out[0]["q"]


def test_chemistry_quiz_keeps_ring_codes_intact():
    """⭕ وترميزُ الحلقة يمرّ كما هو — لا يُمسّ ولا يُفكّ."""
    out = quiz.validate(_payload(r"ما اسم \ring{6|ar}؟"), 1, [], "كيمياء")
    assert out and r"\ring{6|ar}" in out[0]["q"]


def test_math_quiz_arabizes_digits_and_draws_symbols():
    """🧮 أرقامُ الرياضيات عربية، وجذرُها ومضروبُها يُرسمان."""
    out = quiz.validate(_payload("احسب جذر 16 ثم 5!"), 1, [], "رياضيات")
    assert out
    assert r"\sqrt{١٦}" in out[0]["q"]
    assert r"\fact{٥}" in out[0]["q"]


def test_physics_quiz_arabizes_digits():
    """٠١٢ والفيزياء كذلك (قرار المالك 2026-09-12)."""
    out = quiz.validate(_payload("سرعة الضوء 300000 كم/ث"), 1, [], "فيزياء")
    assert out and "٣٠٠٠٠٠" in out[0]["q"]


def test_biology_quiz_keeps_its_root_a_root():
    """🌱 **و«جذر وتدي» في الأحياء نباتٌ لا جذرٌ رياضيّ** — كلُّ رسّامٍ في مادته."""
    out = quiz.validate(_payload("ما وظيفة الجذر الوتدي؟"), 1, [], "احياء")
    assert out and r"\sqrt" not in out[0]["q"]
    assert "الجذر الوتدي" in out[0]["q"]


def test_options_are_drawn_too_not_just_the_question():
    """📋 والخياراتُ الأربعة مثلُ السؤال — الطالب يقرؤها كلَّها."""
    out = quiz.validate(
        _payload("أيها صحيح؟", options=["H2O", "CO2", "NH3", "CH4"]),
        1, [], "كيمياء")
    assert out
    assert out[0]["options"] == ["H₂O", "CO₂", "NH₃", "CH₄"]


def test_topic_is_drawn_as_well():
    """🏷️ والموضوعُ كذلك — عليه تُبنى شاشةُ «تحتاج تركيزاً في»."""
    out = quiz.validate(_payload("سؤال", topic="تركيز H2SO4"), 1, [], "كيمياء")
    assert out and "H₂SO₄" in out[0]["topic"]


def test_a_subjectless_validate_still_works():
    """🛟 وبلا مادة لا ينهار شيء — يمرّ النصّ كما هو."""
    out = quiz.validate(_payload("سؤال عادي"), 1, [])
    assert out and out[0]["q"] == "سؤال عادي"


# ══════════════════ ③ JSON: الترميز يعبر الهروب سالماً ══════════════════

@pytest.mark.parametrize("code", [
    r"\ring{6|ar}", r"\chem{CH3-CH2-OH}", r"\sqrt{9}",
    r"\frac{١}{٢}", r"\nuc{235}{92}{U}", r"\fact{٥}",
])
def test_drawing_codes_survive_json_parsing(code):
    """🔴 فخٌّ مزدوج: `\\chem` يُسقط الاختبار، و`\\ring` يمرّ **مشوّهاً**."""
    raw = ('{"questions":[{"q":"ما هذا ' + code + '؟",'
           '"options":["أ","ب","ج","د"],"correct_index":0}]}')
    data = quiz.extract_json(raw)
    assert data is not None, f"سقط التحليل عند {code}"
    assert code in data["questions"][0]["q"], f"وصل مشوّهاً: {code}"


def test_already_doubled_codes_are_untouched():
    """والمضاعفُ سليمٌ أصلاً — لا نضاعفه مرّتين."""
    raw = r'{"questions":[{"q":"الكسر \\frac{١}{٢}","options":["أ","ب","ج","د"],"correct_index":0}]}'
    data = quiz.extract_json(raw)
    assert data and r"\frac{١}{٢}" in data["questions"][0]["q"]


# ══════════════════ ④ المسار الكامل عبر HTTP ══════════════════

def _quiz_reply(q_text, options):
    return json.dumps({"questions": [{
        "q": q_text, "options": options, "correct_index": 0,
        "topic": "مفهوم", "lesson": "نظرية بوهر"}]}, ensure_ascii=False)


def test_chemistry_quiz_over_http_arrives_drawn(client, monkeypatch):
    """⚗️ المسار الحقيقي: من ردّ الموديل إلى ما تعرضه الشاشة."""
    from fakes import FakeResp

    async def _create(**kw):
        return FakeResp(_quiz_reply("ما صيغة حمض الكبريتيك H2SO4؟",
                                    ["H2O", "CO2", "NH3", "CH4"]))

    for c in api.AI_CLIENTS.values():
        monkeypatch.setattr(c.chat.completions, "create", _create, raising=False)

    caps = client.get("/content/capabilities",
                      params={"subject": "كيمياء", "grade": 2, "track": "علمي"}).json()
    unit = caps["lessons"]["units"][0]
    body = {"subject": "كيمياء", "grade": 2, "track": "علمي",
            "unit": unit["unit"], "lessons": unit["lessons"][:1], "count": 5}
    data = client.post("/quiz/generate", json=body).json()

    assert data.get("questions"), data
    assert "H₂SO₄" in data["questions"][0]["q"]
    assert "H₂O" in data["questions"][0]["options"]


def test_math_quiz_over_http_arrives_drawn(client, monkeypatch):
    """🧮 والرياضيات: أرقامٌ عربية وجذرٌ مرسوم في السؤال والخيارات."""
    from fakes import FakeResp

    async def _create(**kw):
        return FakeResp(_quiz_reply("ما قيمة جذر 25؟", ["5", "6", "7", "8"]))

    for c in api.AI_CLIENTS.values():
        monkeypatch.setattr(c.chat.completions, "create", _create, raising=False)

    caps = client.get("/content/capabilities",
                      params={"subject": "رياضيات", "grade": 3, "track": "علمي"}).json()
    unit = caps["lessons"]["units"][0]
    body = {"subject": "رياضيات", "grade": 3, "track": "علمي",
            "unit": unit["unit"], "lessons": unit["lessons"][:1], "count": 5}
    data = client.post("/quiz/generate", json=body).json()

    assert data.get("questions"), data
    assert r"\sqrt{٢٥}" in data["questions"][0]["q"]
    assert "٥" in data["questions"][0]["options"]


def test_quiz_lesson_text_reaches_the_model_drawn(monkeypatch):
    """📖 ونصُّ الدرس يصل الموديلَ **مرمَّزاً** كما يصل الشرح.

    (وإلا سأل الموديلُ عن «س / ص» فكتبها كما رآها في المصدر.)
    """
    text, used = quiz.collect_lessons_text(
        2, "علمي", "كيمياء", "الوحدة التاسعة: الهيدروكربونات الأروماتية",
        ["الهيدروكربونات الأروماتية"])
    assert used
    assert r"\ring{" in text, "نصّ درس الكيمياء بلا ترميز حلقات"


# ══════════════ ⑤ التذكير بالرسوم: القاعدةُ وحدها لا تكفي ══════════════
#
# 🔴 **ما رُصد حيّاً في المحاكي (2026-09-13):** اختبارُ «قواعد تسمية مشتقات
#    البنزين» — والدرسُ يصل الموديلَ وفيه ٤٥ ترميزَ رسم — عاد بخمسة أسئلةٍ
#    بلا رسمةٍ واحدة، وفيها: «ذرتا بروم في الموقعين ١ و٤ على حلقة البنزين».
#    وهي عينُ `\ring{6|ar|+Br@1|+Br@4}` مكتوبةً كلاماً.
#
#    والعلاجُ هو الذي أصلح التلخيص: تذكيرٌ **بالعدد** في آخر رسالة الطالب.

def test_user_prompt_counts_the_drawings_in_the_lesson():
    """🖌️ العددُ الملموس في آخر ما يقرؤه الموديل."""
    text = r"البنزين \ring{6|ar} والتولوين \ring{6|ar|+CH3} والفينول \ring{6|ar|+OH}"
    out = quiz_prompt.user_prompt(text, 5)
    assert "3 ترميزَ رسمٍ" in out
    assert out.index("ترميزَ رسمٍ") > out.index("متدرّجة الصعوبة"), \
        "التذكير يجب أن يكون آخر ما يقرؤه الموديل"


def test_the_reminder_repeats_the_json_doubling():
    """⚠️ ولا ينفع تذكيرٌ ينتج شرطةً مفردة تُسقط الاختبار."""
    out = quiz_prompt.user_prompt(r"\ring{6|ar}", 5)
    assert r"\\ring{6|ar}" in out


def test_a_lesson_without_drawings_gets_no_reminder():
    """🛟 ودرسُ التاريخ لا يُؤمر بنقل رسومٍ لا وجود لها."""
    out = quiz_prompt.user_prompt("نصّ درسٍ بلا أي ترميز", 5)
    assert "ترميزَ رسمٍ" not in out


def test_the_real_benzene_lesson_carries_the_reminder():
    """📖 والدرسُ الحقيقي الذي كشف العطل — من طرفٍ إلى طرف."""
    text, _ = quiz.collect_lessons_text(
        2, "علمي", "كيمياء", "الوحدة التاسعة: الهيدروكربونات الأروماتية",
        ["قواعد تسمية مشتقات البنزين"])
    assert "ترميزَ رسمٍ" in quiz_prompt.user_prompt(text, 5)


# ══════════════ ⑥ القصّ لا يشطر رسمةً نصفين ══════════════

def test_clipping_never_cuts_a_drawing_code_in_half():
    r"""✂️ الدرسُ ٦٠٤٢ حرفاً والسقف ٦٠٠٠ — والقصُّ الأعمى يترك `\ring{6|ar` مبتوراً."""
    text = "ا" * 40 + r"\ring{6|ar|+Br@1|+Br@4}"
    out = quiz._clip(text, 50)          # يقع داخل الترميز
    assert "\\ring" not in out, f"ترميزٌ مبتور نجا: {out!r}"
    assert out == "ا" * 40


def test_clipping_keeps_a_complete_code_that_fits():
    """وما اكتمل قبل السقف يبقى."""
    text = r"\ring{6|ar}" + "ا" * 100
    out = quiz._clip(text, 50)
    assert r"\ring{6|ar}" in out


def test_clipping_leaves_short_lessons_untouched():
    """🛟 والدرسُ الأقصر من السقف لا يُمسّ."""
    assert quiz._clip("درس قصير", 6000) == "درس قصير"
