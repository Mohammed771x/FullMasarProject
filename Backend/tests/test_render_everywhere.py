# -*- coding: utf-8 -*-
"""🖌️ **الرسّام في كل مكان** — كل مادة، وكل وضع، ولا استثناء.

🔴 **ما طلبه المالك (2026-09-13):**
   «التطبيقات اللي تسويها — مو في قسم الشرح بس. خلّها في الشرح والتلخيص
    والسؤال، وحتى الوزاري. وفي كل مادة مادة، حتى الرياضيات حقّها الرسّام
    اللي لوحدها. شيك لي مادة مادة وخلّه يظهر في كل مكان.»

   والمسحُ كشف أن الرسّام كان **ميزةَ وضعٍ لا ميزةَ مادة**:

   ① **وضعُ السؤال بلا قاعدة كسورٍ أصلاً**: الطالب يسأل «ما قانون السرعة؟»
     فيأتيه «المسافة / الزمن» سطراً مسطّحاً، ويسأل «اشرح» فيراه كسراً.
   ② **الوزاريُّ كلُّه خامٌ**: أسئلةُ الامتحانات تُقرأ من ملفّاتها وتُعرض
     **كما هي بلا أي تحويل** — ٥٥٥ سؤالاً في الرياضيات وحدها فيها كسور.
   ③ **موادّ المسار الأدبي كلُّها بلا قواعد**: برومبتُ المادة المستقلّة كان
     يحلّ **محلّ** العام لا فوقه، والمنطق فيه «(ن ق ٣) / (ن-١ ق ٣) = ٨/٥».
   ④ **الأحياء (الثالث العلمي)** تخرج بلا فلترٍ نهائيّ إطلاقاً: «H2O» لا
     «H₂O»، وأيُّ لاتيكٍ شاردٍ يصل الشاشة.
   ⑤ **قسمُ المعلّم و«اختبر نفسك»** يعرضان نصَّ المنهج نفسه بلا رسّام.
"""
import re
import subprocess
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

import api
from core import lesson_mode, pages_mode, ratelimit as rl
from subjects import common

_ROOT = Path(__file__).resolve().parent.parent

# المواد كلُّها — بما فيها موادّ المسار الأدبي ذات المعالجات المستقلّة.
_SUBJECT_MODULES = {
    "تاريخ": "history", "جغرافيا": "geography", "مجتمع": "society",
    "علم الاقتصاد": "economics", "علم الاجتماع": "sociology",
    "فلسفة": "philosophy", "منطق": "logic", "مبادئ علم الخرائط": "cartography",
}
_ALL_SUBJECTS = ["كيمياء", "فيزياء", "احياء", "رياضيات", "عربي", "انجليزي",
                 *_SUBJECT_MODULES]
_MODES = ["شرح", "تلخيص", "سؤال"]


@pytest.fixture()
def client(no_real_api_calls):
    rl._buckets.clear()
    return TestClient(api.app)


def _prompts_module(subject):
    if subject not in _SUBJECT_MODULES:
        return None
    import importlib
    return importlib.import_module(f"subjects.{_SUBJECT_MODULES[subject]}")


def _built_prompt(builder, subject, mode):
    """البرومبت كما يبنيه المسارُ الحيّ فعلاً — لا كما نظنّه."""
    return builder(mode, subject, 3, _prompts_module(subject))


# ══════════════════ ① قاعدة الكسور في كل مادة وكل وضع ══════════════════

@pytest.mark.parametrize("subject", _ALL_SUBJECTS)
@pytest.mark.parametrize("mode", _MODES)
@pytest.mark.parametrize("builder", [lesson_mode._system_prompt,
                                     pages_mode._system_prompt],
                         ids=["دروس", "وحدات"])
def test_fraction_rule_reaches_every_subject_and_mode(subject, mode, builder):
    """🧮 الكسرُ يُرسم في الأوضاع الثلاثة لكل مادة — لا في الشرح وحده."""
    prompt = _built_prompt(builder, subject, mode)
    assert r"\frac" in prompt, f"{subject} · {mode}: بلا قاعدة كسور"


@pytest.mark.parametrize("subject", ["رياضيات", "فيزياء", "منطق"])
@pytest.mark.parametrize("mode", _MODES)
def test_arabic_digits_rule_reaches_its_subjects_in_every_mode(subject, mode):
    """٠١٢ ومواد الأرقام العربية كذلك — في الأوضاع الثلاثة."""
    assert "٠١٢" in _built_prompt(lesson_mode._system_prompt, subject, mode)


@pytest.mark.parametrize("mode", _MODES)
def test_organic_rules_reach_chemistry_in_every_mode(mode):
    """⚗️ وحلقاتُ الكيمياء وسلاسلُها — في الشرح والتلخيص والسؤال معاً."""
    prompt = _built_prompt(lesson_mode._system_prompt, "كيمياء", mode)
    assert r"\ring" in prompt and r"\chem" in prompt


@pytest.mark.parametrize("subject", ["فيزياء", "احياء", "عربي", "تاريخ"])
def test_organic_rules_stay_out_of_other_subjects(subject):
    """🔒 وتبقى الحلقاتُ في الكيمياء وحدها — التوسيعُ ليس تعميماً."""
    for mode in _MODES:
        assert r"\ring" not in _built_prompt(
            lesson_mode._system_prompt, subject, mode)


# ══════════════════ ② الوزاري: نصُّ الامتحان يُرسم كنصّ الدرس ══════════════════

def test_ministry_math_questions_carry_drawn_fractions():
    """🧮 **٥٥٥ سؤالاً** كانت تصل الطالبَ «١/٦» بدل كسرٍ مرسوم."""
    from subjects.common import (get_math_exam_years, get_math_exam_lessons,
                                 get_math_exam_questions)
    found = False
    for branch in ("هندسة", "تفاضل", "تكامل", "جبر"):
        for year in get_math_exam_years(branch):
            for lesson in get_math_exam_lessons(branch, year):
                bundle = get_math_exam_questions(branch, year, lesson, 50)
                for q in bundle["questions"]:
                    if r"\frac" in q["نص_السؤال"] or r"\frac" in q["الحل"]:
                        found = True
                        break
                if found:
                    break
            if found:
                break
        if found:
            break
    assert found, "لم يصل الرسّام إلى أسئلة الوزاري في الرياضيات"


def test_ministry_questions_of_other_subjects_pass_through_the_preparer():
    """وأسئلةُ بقية المواد تمرّ بالمُجهِّز نفسه (ولو لم تتغيّر)."""
    from subjects.common import collect_exam_questions_by_years
    questions = collect_exam_questions_by_years("كيمياء", ["الكل"])
    assert questions, "لا أسئلة وزارية للكيمياء — تحقّق من المسار"
    # لا ترميزَ مشوّه ولا استثناء: المرور نفسه هو المطلوب.
    for q in questions[:50]:
        assert isinstance(q["النص"], str)


def test_true_false_mark_is_not_a_fraction():
    """🔴 «(✓/X)» في وزاري العربي خيارٌ بين إجابتين لا كسر.

    ظهر في ٢٦ سؤالاً أول ما مرّت الأسئلة بالرسّام — «\\frac{✓}{X}».
    """
    from core.fractions import to_frac
    assert r"\frac" not in to_frac("ضع علامة (✓/X) أمام العبارة")
    # ⚠️ و«×» ليست علامةَ خطأ بل ضرباً — الكسرُ الحقيقيّ يبقى.
    assert r"\frac" in to_frac("[ (-1)^ن × ن! ] / (س - أ)^(ن+1)")


# ══════════════════ ③ المخرج الواحد: كل جوابٍ يمرّ باللمسات ══════════════════

def test_every_answer_passes_the_finisher(client, monkeypatch):
    """🖌️ جوابٌ فيه «H2SO4» يصل الطالبَ «H₂SO₄» مهما كان المعالج.

    ⚠️ **والاختبار على مسار HTTP** لا على الدالّة: العطل كان أن معالجاً
       لا ينادي الفلتر أصلاً، وفحصُ الدالّة وحدها يمرّ بينما الشاشة تكذّبه.
    """
    from fakes import FakeResp

    async def _create(**kw):
        return FakeResp("الحمض H2SO4 والكسر 1 على 2 والنص \\quad الشارد")

    for c in api.AI_CLIENTS.values():
        monkeypatch.setattr(c.chat.completions, "create", _create, raising=False)

    # 📚 وحدةٌ مسمّاة: بحثُ وضع الوحدات صار يشترطها (قرار المالك 2026-09-14).
    from core.content_store import get_pages_book
    _unit = (get_pages_book(3, "علمي", "كيمياء") or [{}])[0].get("اسم_الوحدة", "")
    body = {"subject": "كيمياء", "mode": "شرح", "input_type": "برومت",
            "summary_level": 3, "content": "اشرح", "unit_name": _unit,
            "lesson_name": "",
            "chat_history": [], "grade": 3, "track": "علمي"}
    answer = client.post("/ask", json=body).json()["answer"]
    assert "H₂SO₄" in answer, "دليلُ الصيغة لم يُخفض — الفلتر لم يُنادَ"
    assert "\\quad" not in answer


def test_the_finisher_is_stable_when_repeated():
    """⚖️ **ثباتٌ عند التكرار** — وعليه يقوم المخرجُ المركزيّ.

    المعالجُ ينادي فلترَه، ثم ينادي المخرجُ المركزيّ الفلترَ نفسه. فلو لم
    تكن الدالّة ثابتة لتضاعف كلُّ تحويلٍ مرّتين على كل جواب.
    """
    samples = [
        ("رياضيات", "الحل \\frac{٢}{٣} + جذر ١٦ = س^٢ و ٥!"),
        ("كيمياء", "البنزين \\ring{6|ar} والصيغة \\chem{CH3-OH} و H2SO4"),
        ("فيزياء", "ع = \\frac{ف}{ز} و 10^23 ذرة"),
        ("احياء", "6CO2 + 6H2O --> C6H12O6"),
        ("منطق", "(ن ق ٣) / (ن-١ ق ٣) = ٨ / ٥"),
    ]
    for subject, text in samples:
        once = common.strip_stray_latex(text, subject)
        assert common.strip_stray_latex(once, subject) == once, subject


# ══════════════════ ④ الأقسام الأخرى: المعلّم والاختبار ══════════════════

def test_teacher_output_gets_the_same_drawer():
    """👨‍🏫 قسمُ المعلّم يقرأ دروسَ الطالب نفسها — فليرَ رسمَها نفسه."""
    from core.teacher_assistant import clean_math
    out = clean_math("الصيغة \\( \\frac{1}{2} \\) و H2SO4 والجذر جذر 16", "كيمياء")
    assert "H₂SO₄" in out and "\\(" not in out


def test_teacher_output_keeps_its_structure():
    """📐 ومع ذلك **لا تُسحق المسافات**: خطةُ الدرس قوائمُ متداخلة."""
    from core.teacher_assistant import clean_math
    out = clean_math("  - خطوة\n    - فرعية\n      - أعمق", "رياضيات")
    assert "    - فرعية" in out and "      - أعمق" in out


def test_quiz_questions_get_the_same_drawer():
    """🧠 «اختبر نفسك» يسأل عن نفس الدروس — فلا يصل سؤالُه خاماً."""
    from core.quiz import validate
    data = {"questions": [{
        "q": "ما تركيز H2SO4 في المحلول؟",
        "options": ["1 على 2", "ثلث", "ربع", "خمس"],
        "correct_index": 0, "topic": "التركيز", "lesson": "درس",
    }]}
    out = validate(data, 1, [], "كيمياء")
    assert out and "H₂SO₄" in out[0]["q"]


def test_quiz_json_survives_drawing_codes():
    """🔴 **الشرطةُ المفردة داخل JSON فخٌّ مزدوج** بعد أن صار الدرس يحمل ترميزاً:

    `\\chem` هروبٌ غير صالح ⇒ يسقط الاختبار كلُّه، و`\\ring` هروبٌ صالح
    (`\\r`) ⇒ **يُقبل ويصل مشوّهاً**: محرفُ تحكّمٍ ثم «ing{6|ar}».
    """
    from core.quiz import extract_json
    for code in (r"\ring{6|ar}", r"\chem{CH3-OH}", r"\sqrt{9}", r"\nuc{235}{92}{U}"):
        raw = '{"questions":[{"q":"ما هذا ' + code + '؟","options":["أ","ب","ج","د"],"correct_index":0}]}'
        data = extract_json(raw)
        assert data is not None, f"سقط الاختبار عند {code}"
        assert code in data["questions"][0]["q"], f"وصل مشوّهاً: {code}"


# ══════════════════ ⑤ حارسٌ مصدريّ: لا قارئَ كتابٍ بلا مادة ══════════════════

def test_no_book_reader_forgets_its_subject():
    """🔒 قارئُ نصّ الكتاب يجب أن يعرف مادته — وإلا سقط ترميزُ الكيمياء.

    العطلُ الذي يحرسه: `extract_all_texts_and_metas_physics(book_data)` بلا
    مادة ⇒ `prepare_source(t, None)` ⇒ كسورٌ نعم وحلقاتٌ **لا**.
    """
    readers = ("extract_all_texts_and_metas_physics", "pages_with_headers")
    offenders = []
    for path in sorted((_ROOT / "subjects").rglob("*.py")) + \
            sorted((_ROOT / "core").rglob("*.py")):
        for i, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if line.strip().startswith(("#", "def ", "async def ")):
                continue
            for reader in readers:
                m = re.search(rf"{reader}\(([^)]*)\)", line)
                if m and m.group(1).count(",") == 0 and m.group(1).strip():
                    offenders.append(f"{path.name}:{i}")
    assert not offenders, f"قارئٌ بلا مادة: {offenders}"


# ══════════════ 📜 السجلّ يصل كاملاً — قرار المالك 2026-09-14 ══════════════
#
# 🔴 «موضوع إنه ناخذ أول ١٥٠٠ حرف من الرسائل السابقة أنا لا أؤيد — خلّه
#    ناخذ كل الرسالة، حتى كانت ٢٠ ألف حرف، ناخذ كل الست رسائل اللي قبل.»
#
#    وشرحُ درسٍ كامل يبلغ ٨ آلاف حرف: القصُّ عند ١٥٠٠ كان يُسلّم الموديلَ
#    **مقدّمة الشرح وحدها**، فيسأل الطالب «وضّح الخطوة السابعة» والموديلُ
#    لم يرَ إلا الأولى والثانية.

def test_a_full_lesson_length_answer_survives_the_history_cap():
    """⭐ ردٌّ بطول ٢٠ ألف حرف (رقم المالك) يمرّ كما هو."""
    from models import AskRequest
    long = "أ" * 20000
    req = AskRequest(input_type="text", subject="كيمياء", mode="شرح", content="؟",
                     chat_history=[{"role": "assistant", "content": long}])
    assert len(req.chat_history[0]["content"]) == 20000


def test_the_remaining_cap_is_a_wall_not_a_content_limit():
    """⚖️ والسقفُ الباقي **فوق أطولِ ردٍّ ممكن بمرّتين** — جدارُ إساءةٍ لا قصّ.

    `max_tokens = 4000` ≈ ١٢ ألف حرف عربي في أسوأ الحالات.
    """
    from config import HISTORY_MAX_CHARS
    assert HISTORY_MAX_CHARS >= 24000, "السقف نزل تحت ضعف أطول ردّ ممكن"


def test_an_abusive_payload_is_still_stopped():
    """🛡️ ولا يبقى الباب مفتوحاً: عشرةُ ميغابايت تُقصّ عند الجدار."""
    from models import AskRequest
    from config import HISTORY_MAX_CHARS
    req = AskRequest(input_type="text", subject="كيمياء", mode="شرح", content="؟",
                     chat_history=[{"role": "user", "content": "x" * 10_000_000}])
    assert len(req.chat_history[0]["content"]) == HISTORY_MAX_CHARS


def test_the_teacher_history_is_uncut_too():
    """👨‍🏫 وخطةُ الدرس الكاملة تعود إلى الموديل كما أنتجها — لا مقدّمتها."""
    from core import teacher_assistant as ta
    plan = "خطة " * 3000                      # ~١٥ ألف حرف
    out = ta.build_history([{"role": "assistant", "content": plan}])
    assert out and out[0]["content"] == plan.strip()


def test_only_the_message_count_limits_the_context_now():
    """🔢 العددُ وحده يحدّ السياق: ستٌّ مهما طالت، والأقدم يسقط."""
    from core import teacher_assistant as ta
    from config import HISTORY_LAST_N
    msgs = [{"role": "user", "content": f"رسالة {i} " + "ط" * 9000}
            for i in range(20)]
    out = ta.build_history(msgs)
    assert len(out) == HISTORY_LAST_N
    assert out[0]["content"].startswith("رسالة 14")
    assert all(len(m["content"]) > 9000 for m in out)
