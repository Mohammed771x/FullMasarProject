"""«/» في الإنجليزي تعني «أو» لا «قسمة» — فلا يُحوَّل كسراً قبل الموديل."""
from core.serializer import serialize_lesson


def _lesson(line: str) -> dict:
    return {"اسم_الدرس": "x", "المحتوى": line}


def test_english_slash_stays_a_slash():
    out = serialize_lesson(_lesson("Must I ...? / Do I have to ...?"), subject="انجليزي")
    assert "\\frac" not in out
    assert "Must I ...? / Do I have to ...?" in out


def test_english_alternatives_with_arabic_gloss_stay_readable():
    line = "I love ... (أحب جداً) / I enjoy ... (أستمتع بـ)"
    out = serialize_lesson(_lesson(line), subject="انجليزي")
    assert "\\frac" not in out and line in out


def test_science_fraction_still_converted():
    out = serialize_lesson(_lesson("ك = و / ج"), subject="فيزياء")
    assert "\\frac{و}{ج}" in out
