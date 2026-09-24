# -*- coding: utf-8 -*-
"""🛡️ مُدخلاتُ الوزاري — السنةُ والفرعُ لا يخرجان من مجلّدهما، والعددُ محدود.

☢️ **وُجد ٢٠٢٦-٠٩-٢٣:** السنةُ تصل من جسم الطلب وتُركَّب في مسار ملفٍّ
   (`f"{year}.json"`) في أربعة مواضع. فـ`"../../x"` كان يقرأ أيَّ ملفّ JSON
   على الخادم. وعددُ القطع/الأسئلة كان يُقبل كما هو (`99999` · `-3`).
"""
import asyncio
import os

import pytest

from config import BASE_SUBJECTS_DIR
from subjects.shared.exams import (
    clamp_count, get_math_exam_lessons, get_math_exam_questions,
    get_math_exam_years, safe_segment,
)

TRAVERSALS = ["../x", "../../etc/passwd", "a/b", "a\\b", "..", "/abs", "\x00x",
              "", " ", "x" * 80, None, 2019]


@pytest.mark.parametrize("bad", TRAVERSALS)
def test_unsafe_segments_are_rejected(bad):
    assert not safe_segment(bad)


@pytest.mark.parametrize("good", ["2019", "2024", "الكل", "عدن",
                                  "2022 الدور الأول", "تفاضل", "دور-ثاني"])
def test_real_names_pass(good):
    assert safe_segment(good)


def test_every_name_on_disk_passes():
    """🧮 **المسحُ لا العيّنة:** كلُّ سنةٍ وفرعٍ في بنك الوزاري يمرّ من الحارس —
    وإلا صار الحارسُ نفسُه عطلاً يُخفي امتحاناً حقيقياً عن الطالب."""
    checked = 0
    for root, dirs, files in os.walk(BASE_SUBJECTS_DIR):
        if "exams" not in root:
            continue
        for d in dirs:
            checked += 1
            assert safe_segment(d), os.path.join(root, d)
        for f in files:
            if f.endswith(".json"):
                checked += 1
                assert safe_segment(f[:-5]), os.path.join(root, f)
    assert checked > 0


@pytest.mark.parametrize("raw,default,want", [
    ("5", 1, 5), (" 7 ", 1, 7), ("99999", 5, 20), ("-3", 5, 1), ("0", 5, 1),
    ("abc", 5, 5), (None, 1, 1), ("", 10, 10), ("3.5", 4, 4),
])
def test_clamp_count(raw, default, want):
    assert clamp_count(raw, default) == want


def test_math_helpers_refuse_traversal():
    assert get_math_exam_years("../..") == []
    assert get_math_exam_lessons("تفاضل", "../../../x") == []
    assert get_math_exam_lessons("../x", "2019") == []
    out = get_math_exam_questions("../..", "x", "y", 5)
    assert out == {"questions": [], "total": 0, "has_more": False}


def test_arabic_exam_handler_refuses_traversal_year():
    from models import AskRequest
    from subjects.arabic import handle_arabic_exams
    req = AskRequest(subject="عربي", mode="وزاري", input_type="برومت",
                     content="../../../config|النحو|قطعة|2")
    req.user_id = "t"
    out = asyncio.run(handle_arabic_exams(req, {}, None))
    assert "غير صالحة" in out["answer"]
    assert out["session_active"] is False
