"""🧮 توحيد أسماء دروس الرياضيات بين مصدرَيها.

الملف على القرص له **اسمان**: اسم الملف، و`اسم_الدرس` بداخله. وكانا يختلفان:

    ملف «القطع الزائد.json»  ←  اسم داخلي «القطع الزائد (الهذلول - Hyperbola)»

القدرات (يُبنى منها الاختبار) تسرد الاسم الداخلي، و`/math/lessons` (يقرؤها
الشات) كانت تسرد اسم الملف. فـ«اشرح لي هذا الدرس» القادم من التحليل ينكسر في
«هندسة» و«جبر» ويعمل في «تفاضل» — علّةٌ تخفّت لأن ثلاثة فروع من خمسة سليمة.
"""
import pytest

from core import content_store as cs
from core import curriculum as cur
from subjects.common import load_math_lesson

BRANCHES = ["تفاضل", "تكامل", "جبر", "هندسة", "احتمالات"]


def _capability_lessons(branch):
    book = cs.get_lessons_book(3, "علمي", "رياضيات")
    assert book is not None, "كتاب دروس الرياضيات مفقود"
    return cs.lessons_in_unit(book, branch)


@pytest.mark.parametrize("branch", BRANCHES)
def test_every_capability_lesson_is_loadable(branch):
    """★ الحارس الأهم: كل درس يظهر للطالب في الاختبار يجب أن يُفتح للشرح."""
    lessons = _capability_lessons(branch)
    unloadable = [l for l in lessons if load_math_lesson(branch, l) is None]
    assert not unloadable, f"دروس لا تُفتح في «{branch}»: {unloadable}"


def test_internal_name_differs_from_filename_and_both_work():
    """الاسمان مختلفان فعلاً في البيانات — والاثنان يجب أن يُفتحا."""
    internal = "القطع الزائد (الهذلول - Hyperbola)"
    filename = "القطع الزائد"
    assert internal != filename
    assert load_math_lesson("هندسة", internal) is not None
    # اسم الملف يبقى مقبولاً: محادثات محفوظة قديماً تحمله
    assert load_math_lesson("هندسة", filename) is not None


def test_lesson_file_without_json_extension_is_found():
    """«مبدأ العد» ملفٌ بلا امتداد .json — كان يسقط من القائمة وحده."""
    assert load_math_lesson("جبر", "مبدأ العد (طرائق العد)") is not None
    assert "مبدأ العد (طرائق العد)" in _capability_lessons("جبر")


def test_unknown_lesson_returns_none():
    assert load_math_lesson("هندسة", "درس لا وجود له") is None
    assert load_math_lesson("فرع لا وجود له", "أي درس") is None


@pytest.mark.parametrize("branch", BRANCHES)
def test_math_lessons_endpoint_matches_capabilities(branch):
    """المصدران يجب أن يتطابقا — وإلا عاد التباعد من حيث أُصلح."""
    from api import get_math_lessons
    import asyncio

    served = asyncio.run(get_math_lessons(branch=branch, grade=3, track="علمي"))
    caps = _capability_lessons(branch)
    assert set(served) == set(caps), f"تباعدٌ في «{branch}»"
    assert len(served) == len(set(served)), "لا تكرار في القائمة المعروضة"
