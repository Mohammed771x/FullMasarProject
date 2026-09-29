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


def test_history_date_is_not_a_fraction():
    out = serialize_lesson(_lesson("انضمام اليمن في ١٩٥٦/٤/٢١م"), subject="تاريخ")
    assert "\\frac" not in out and "١٩٥٦/٤/٢١م" in out


def test_geography_has_no_fraction_renderer():
    out = serialize_lesson(_lesson("في ١ / ١ / ۱۹۹۸م"), subject="جغرافيا")
    assert "\\frac" not in out


def test_cartography_scale_still_drawn():
    out = serialize_lesson(_lesson("المقياس = ٤ / ٢٠٠٠"), subject="مبادئ علم الخرائط")
    assert "\\frac" in out


def test_no_fraction_rule_in_narrative_prompts():
    from subjects.shared.render_rules import fraction_rules
    assert fraction_rules("تاريخ") == "" and fraction_rules("عربي") == ""
    assert "\\frac" in fraction_rules("فيزياء")
