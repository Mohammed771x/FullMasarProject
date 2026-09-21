# -*- coding: utf-8 -*-
"""⚡ الشرحُ المخزون يصل **على طول** — وبلا موديلٍ بحال.

🔴 **علّةُ المالك (2026-09-16):** «لما أضغط شرح المفروض على طول يطلع لي
   الشرح، ما ينتظر ثانيتين ولا ثلاثة — كما قسم الوزارة.»

⚖️ والقياسُ برّأ الجواب واتّهم الطريق: قراءةُ الشرح من القرص **مللي
   ثانيةٌ واحدة**، بينما المسار كان رحلةَ شبكةٍ + حرّاسَ `/ask` + خصمَ
   الحصة من Firestore **ثم ردَّها**. فصارت له نقطةٌ تُسحب مسبقاً:
   [/lesson/explanation] — مخزونٌ أو لا شيء، ولا موديلَ فيها أبداً.
"""
import json
from pathlib import Path

import pytest

from core import lesson_cache as LC

EXPL = Path(__file__).resolve().parent.parent / "data" / "explanations"


def _any_stored(grade, track, subject):
    """أولُ درسٍ مخزونٍ فعلاً لهذه المادة — أو `None` إن لم يُبنَ بعد."""
    path = EXPL / str(grade) / track / f"{subject}.json"
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    for key in data:
        if " › " in key:
            unit, lesson = key.split(" › ", 1)
            return unit, lesson
    return None


# ══════════════ ① يحلّ مصدرَه بنفسه ══════════════

@pytest.mark.parametrize("grade,track,subject", [
    (3, "علمي", "احياء"), (2, "علمي", "فيزياء"), (1, "عام", "كيمياء"),
    (3, "أدبي", "تاريخ"),
])
def test_stored_for_serves_a_built_lesson(grade, track, subject):
    """`stored_for` تقرأ الدرسَ وتبصمه وتُسلّم — بلا أن يمرّ بها الطلب."""
    found = _any_stored(grade, track, subject)
    if found is None:
        pytest.skip(f"لم يُبنَ شرحُ {subject} لهذا الصف بعد")
    unit, lesson = found
    answer = LC.stored_for(grade, track, subject, unit, lesson)
    assert answer, f"{subject} › {lesson}: مخزونٌ موجودٌ ولم يُسلَّم"
    assert len(answer) > 500


def test_stored_for_serves_mathematics_too():
    """🧮 **والرياضياتُ بصمتُها من ملف الدرس لا من المُسلسِل** ([math_source]).

    خلطُ المصدرين يجعل البصمةَ تُخطئ **صامتةً** فلا يُسلَّم شرحٌ واحد —
    وهو عطلٌ لا يشتكي منه شيءٌ في السجلّ.
    """
    found = _any_stored(3, "علمي", "رياضيات")
    if found is None:
        pytest.skip("لم يُبنَ شرحُ الرياضيات بعد")
    branch, lesson = found
    assert LC.stored_for(3, "علمي", "رياضيات", branch, lesson)


def test_stored_for_returns_none_for_an_unknown_lesson():
    assert LC.stored_for(3, "علمي", "احياء", "وحدةٌ لا وجود لها",
                         "درسٌ لا وجود له") is None


def test_stored_for_survives_a_broken_request():
    """قراءةٌ مساعدة لا تُسقط طلباً — مهما كان المدخل."""
    assert LC.stored_for(3, "علمي", "", "", "") is None
    assert LC.stored_for(None, None, "احياء", None, None) is None


# ══════════════ ② النقطةُ لا تنادي موديلاً ══════════════

def test_the_endpoint_never_reaches_a_model():
    """🔒 **وهذا شرطُ صحّة السحب المسبق كلِّه.**

    التطبيق ينادي هذه النقطة عند **كل اختيار درس**. فلو كان فيها مسارٌ
    إلى الموديل لصار تصفّحُ الدروس فاتورةً — وهو عكسُ ما بُنيت له.
    """
    # 📦 انتقل جسدُ المسار إلى [apiparts/study.py] يوم فُكّك `api.py`
    #    (2026-09-20). والقراءةُ من الواجهة وحدها كانت تُسقط الحارس.
    src = (Path(__file__).resolve().parent.parent
           / "apiparts" / "study.py").read_text(encoding="utf-8")
    body = src.split('@app.get("/lesson/explanation")')[1].split("@app.")[0]
    for forbidden in ("AI_CLIENTS", "streaming", "_dispatch", "completions",
                      "quota", "billing"):
        assert forbidden not in body, f"نقطةُ المخزون تلمس «{forbidden}»"
    assert "stored_for" in body


def test_the_endpoint_is_scoped_by_grade_and_track():
    """🎓 بلا الصفّ والمسار يتسرّب شرحُ صفٍّ إلى صفٍّ آخر."""
    # 📦 انتقل جسدُ المسار إلى [apiparts/study.py] يوم فُكّك `api.py`
    #    (2026-09-20). والقراءةُ من الواجهة وحدها كانت تُسقط الحارس.
    src = (Path(__file__).resolve().parent.parent
           / "apiparts" / "study.py").read_text(encoding="utf-8")
    body = src.split('@app.get("/lesson/explanation")')[1].split("@app.")[0]
    assert "normalize_grade_track" in body
    assert "is_valid_subject" in body
