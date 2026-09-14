# -*- coding: utf-8 -*-
"""👨‍🏫🖌️ قسم المعلّم — **نفس رسّام المحادثة بالضبط**، لكل مادة ولكل درس.

🔴 **ما طلبه المالك (2026-09-13):**
   «شيك على قسم المعلم كامل — ضروري يكون نفسه بالضبط، نفس المحادثة بالضبط،
    نفس الرسام لكل درس، كل مادة، كل شيء.»

   والمعلّمُ يقرأ **نفس ملفات دروس الطالب**، فلا يجوز أن تُرسم الحلقةُ في
   شرح الطالب وتأتي خطةُ درس الأستاذ عنها اسماً مجرّداً.

🔴 **وما كان العطل:** `SYSTEM_CORE` فيه قاعدةُ كسورٍ **مكتوبةٌ بيدها لا
   تعرف المادة** — فلا حلقات ولا صيغ بنائية ولا معادلات تفاعل ولا أرقام
   عربية. قيسَ حيّاً: خطةُ درس «قواعد تسمية مشتقات البنزين» ونصُّه فيه ٤٧
   ترميزَ حلقة عادت بلا رسمةٍ واحدة (وبالقواعد والتذكير: ١١ رسمة).

⚖️ والفحصُ على أربع طبقات، لأن أيَّ واحدةٍ تكفي لإفساد الشاشة:
   ① البرومبت: هل عرف الموديلُ ترميزَ مادته؟
   ② الطلب: هل ذُكِّر بعدد رسوم هذا الدرس؟
   ③ الخروج: هل مرّ الجوابُ بلمسات الرسّام بلا سحقِ بنيته؟
   ④ اللوحة: هل ترى تجربةُ الأدمن **ما سيراه المعلّم حرفياً**؟
"""
import asyncio
import re

import pytest

from core import teacher_assistant as ta
from core import teacher_prompts as tp
from core.content_store import get_lessons_book, lessons_units, lessons_in_unit
from core.curriculum import subjects_for

_ALL = ["كيمياء", "فيزياء", "احياء", "رياضيات", "عربي", "انجليزي",
        "منطق", "تاريخ", "جغرافيا", "فلسفة", "مجتمع",
        "علم الاقتصاد", "علم الاجتماع", "مبادئ علم الخرائط"]


def _system(subject, tool="plan", text="", generate=True):
    return ta.build_system(tool, generate, subject, 3, "علمي",
                           "وحدة", "درس", text)


# ══════════════════ ① البرومبت: لكل مادةٍ رسّامُها ══════════════════

@pytest.mark.parametrize("subject", _ALL)
@pytest.mark.parametrize("tool", tp.TOOL_IDS)
def test_every_tool_of_every_subject_carries_the_fraction_rule(subject, tool):
    """🧮 الكسرُ يُرسم في **كل أداة** ولكل مادة — لا في خطة الدرس وحدها."""
    assert r"\frac" in _system(subject, tool)


@pytest.mark.parametrize("tool", tp.TOOL_IDS)
def test_chat_turns_carry_the_rules_too_not_only_generation(tool):
    """💬 والمتابعةُ مثلُ التوليد: «اجعله أصعب» تُنتج نصّاً يُعرض كما يُعرض الأول."""
    assert r"\frac" in _system("كيمياء", tool, generate=False)
    assert r"\ring{6|ar}" in _system("كيمياء", tool, generate=False)


@pytest.mark.parametrize("subject", ["رياضيات", "فيزياء", "منطق"])
def test_arabic_digits_rule_reaches_the_teacher_of_its_subjects(subject):
    """٠١٢ وأرقامُ المعلّم عربيةٌ في موادّها — كما في شرح الطالب تماماً."""
    assert "٠١٢" in _system(subject)


@pytest.mark.parametrize("subject", ["تاريخ", "عربي", "احياء"])
def test_arabic_digits_rule_stays_out_of_other_subjects(subject):
    """🔒 والتعميمُ ممنوع: تواريخُ التاريخ وأرقامُ الأحياء تبقى كما في كتابها."""
    assert "٠١٢" not in _system(subject)


def test_organic_rules_reach_the_chemistry_teacher():
    """⚗️ وحلقاتُ الكيمياء وسلاسلُها تصل برومبتَ المعلّم."""
    prompt = _system("كيمياء")
    assert r"\ring{6|ar}" in prompt and r"\chem{" in prompt
    assert "لا ترسم مركّباً لم يرد في الدرس" in prompt


@pytest.mark.parametrize("subject", ["فيزياء", "احياء", "عربي", "تاريخ"])
def test_organic_rules_stay_in_chemistry(subject):
    """🔒 والقاعدةُ العضوية تبقى في مادتها — التوسيعُ ليس تعميماً."""
    assert "لا ترسم مركّباً لم يرد في الدرس" not in _system(subject)


def test_the_shared_core_still_comes_first():
    """⚖️ ترتيبُ الطبقات لم ينكسر: الصدقُ والتقيّدُ بالدرس قبل كل شيء."""
    prompt = _system("كيمياء")
    assert prompt.index("لا تخترع") < prompt.index(r"\ring{6|ar}")


# ══════════════════ ② الطلب: تذكيرٌ بعددِ رسوم هذا الدرس ══════════════════

def test_the_reminder_counts_the_drawings_of_the_lesson():
    """🖌️ العددُ الملموس — وهو ما حرّك الموديل فعلاً (صفر ⇐ ١١)."""
    from subjects.common import draw_reminder
    text = r"البنزين \ring{6|ar} والتولوين \ring{6|ar|+CH3} \chem{CH3-OH}"
    assert "3 ترميزَ رسمٍ" in draw_reminder(text)


def test_a_lesson_without_drawings_gets_no_reminder():
    """🛟 ودرسُ التاريخ لا يُؤمر بنقل رسومٍ لا وجود لها."""
    from subjects.common import draw_reminder
    assert draw_reminder("نصّ درسٍ بلا أي ترميز") == ""


def test_the_reminder_has_one_body_for_all_four_sections():
    """⚖️ مصدرٌ واحد: الدروس · الصفحات · الاختبار · المعلّم."""
    from subjects.common import draw_reminder
    from core import lesson_mode, pages_mode
    assert lesson_mode._draw_reminder is draw_reminder
    assert pages_mode._draw_reminder is draw_reminder


def test_the_lesson_drawings_reach_the_model_in_the_request(monkeypatch):
    """📖 من نصّ الكتاب إلى رسالة الموديل — بالعدد الصحيح."""
    from models import TeacherAskRequest
    seen = {}

    async def _complete(client, **kw):
        seen["messages"] = kw["messages"]
        return "تمّ"

    monkeypatch.setattr(ta.streaming, "complete", _complete)
    req = TeacherAskRequest(
        tool="plan", generate=True, subject="كيمياء", grade=2, track="علمي",
        unit_name="الوحدة التاسعة: الهيدروكربونات الأروماتية",
        lesson_name="قواعد تسمية مشتقات البنزين")
    asyncio.run(ta.ask(req, {"openai": object(), "gemini": object()}))

    system = seen["messages"][0]["content"]
    user = seen["messages"][-1]["content"]
    assert r"\ring{" in system, "نصُّ الدرس وصل بلا ترميز حلقات"
    assert r"\ring{6|ar}" in system, "برومبتُ المادة بلا قاعدة الحلقات"
    assert "ترميزَ رسمٍ" in user, "الطلبُ بلا تذكيرٍ بعدد الرسوم"


# ══════════════════ ③ الخروج: الرسّام بلا سحقِ البنية ══════════════════

def test_chemistry_teacher_output_lowers_formula_indices():
    """⚗️ «H2SO4» تصل الأستاذَ «H₂SO₄» — كما يراها طلابُه."""
    assert "H₂SO₄" in ta.clean_math("تركيز H2SO4", "كيمياء")


def test_chemistry_ring_codes_pass_through_untouched():
    """⭕ وترميزُ الحلقة يمرّ كما هو — لا يُمسّ ولا يُفكّ."""
    assert r"\ring{6|ar}" in ta.clean_math(r"البنزين \ring{6|ar}", "كيمياء")


def test_math_teacher_output_draws_roots_and_factorials():
    """🧮 جذرُ الرياضيات ومضروبُها يُرسمان في خطة الأستاذ كذلك."""
    out = ta.clean_math("احسب جذر 16 ثم 5!", "رياضيات")
    assert r"\sqrt{١٦}" in out and r"\fact{٥}" in out


def test_physics_teacher_output_arabizes_digits():
    """٠١٢ والفيزياء كذلك (قرار المالك 2026-09-12)."""
    assert "٣٠٠" in ta.clean_math("سرعة 300 م/ث", "فيزياء")


def test_biology_teacher_keeps_its_root_a_root():
    """🌱 و«جذر وتدي» في الأحياء نباتٌ لا جذرٌ رياضيّ — كلُّ رسّامٍ في مادته."""
    out = ta.clean_math("ما وظيفة الجذر الوتدي؟", "احياء")
    assert r"\sqrt" not in out and "الجذر الوتدي" in out


def test_structured_output_keeps_its_indentation():
    """📐 وخطةُ الدرس قوائمُ متداخلة — المسافةُ البادئة بنيةٌ لا زينة."""
    src = "1. الهدف\n   - خطوة\n     - تفصيل"
    assert "     - تفصيل" in ta.clean_math(src, "كيمياء")


# ══════════════════ ④ اللوحة ترى ما يراه المعلّم ══════════════════

def test_the_dashboard_preview_uses_the_same_assembler(monkeypatch):
    """🧪 وعدُ «جرّب البرومبت» أن ترى اللوحةُ ما سيراه المعلّم حرفياً.

    🔴 وكان `try_prompt` يجمّع البرومبت **بنسخةٍ ثانية**، فلمّا أُضيفت قواعدُ
       الرسّام وصلت المعلّمَ ولم تصل تجربةَ اللوحة — والأدمن يضبط على ما يرى.
    """
    built = ta.build_system("plan", True, "كيمياء", 3, "علمي", "و", "د",
                            "نصّ", None, prompt_override="مسودّة الأدمن")
    assert "مسودّة الأدمن" in built
    assert r"\ring{6|ar}" in built, "تجربةُ اللوحة بلا رسّام المادة"
    assert tp.SYSTEM_CORE.split("\n")[0] in built


# ══════════════════ ⑤ مسحٌ حقيقي: درسٌ درسٌ لكل مادة ══════════════════

_DRAW = re.compile(r"\\(?:ring|chem|frac|sqrt|nuc|fact|perm|comb)\{")


def _all_books():
    for grade, track in ((1, ""), (2, "علمي"), (2, "أدبي"),
                         (3, "علمي"), (3, "أدبي")):
        for subject in subjects_for(grade, track):
            book = get_lessons_book(grade, track, subject)
            if book is not None:
                yield grade, track, subject, book


def test_every_lesson_of_every_subject_reaches_the_teacher_intact():
    """📚 **درسٌ درسٌ**: كلُّ درسٍ يفتحه المعلّم يُقرأ، ويصل نصُّه مرمَّزاً.

    الحارسُ هنا ليس العددَ بل **السلامة**: لا درسَ يرمي، ولا درسَ يصل فارغاً،
    ولا ترميزَ يصل مبتوراً بعد القصّ عند `_MAX_LESSON_CHARS`.
    """
    broken, empty, checked = [], [], 0
    for grade, track, subject, book in _all_books():
        for unit in lessons_units(book):
            for lesson in lessons_in_unit(book, unit):
                checked += 1
                try:
                    text, _u = ta.lesson_text(grade, track, subject, unit, lesson)
                except Exception as e:                      # pragma: no cover
                    broken.append(f"{subject}/{lesson}: {type(e).__name__} {e}")
                    continue
                if not text.strip():
                    empty.append(f"{subject}/{lesson}")
                # ترميزٌ فُتح ولم يُغلق = قصٌّ شطر رسمةً نصفين
                for m in _DRAW.finditer(text):
                    if "}" not in text[m.start():m.start() + 200]:
                        broken.append(f"{subject}/{lesson}: ترميزٌ مبتور")
                        break
    assert checked > 100, f"المسح لم يقرأ إلا {checked} درساً"
    assert not broken, "\n".join(broken[:10])
    assert not empty, "\n".join(empty[:10])


def test_the_teacher_reads_the_same_books_as_the_student():
    """⚖️ ومصدرُ المعلّم هو مصدرُ الطالب حرفياً — لا نسخةَ محتوى ثانية."""
    from core import quiz
    for grade, track, subject, _book in list(_all_books())[:6]:
        assert ta.units_and_lessons(grade, track, subject)["units"], subject
        # ونفس المُسلسِل: نصُّ الدرس واحدٌ في القسمين
        tree = ta.units_and_lessons(grade, track, subject)["units"][0]
        unit, lesson = tree["unit"], tree["lessons"][0]
        teacher_text, _ = ta.lesson_text(grade, track, subject, unit, lesson)
        student_text, _used = quiz.collect_lessons_text(
            grade, track, subject, unit, [lesson])
        assert teacher_text[:400] in student_text, f"{subject}/{lesson}"
