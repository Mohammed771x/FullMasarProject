import json, glob
from core.serializer import to_text, serialize_lesson, MAX_LESSON_CHARS

def test_all_five_formats_serialize():
    """مُسلسِل واحد يغطي الصيغ الخمس — بلا أي ترحيل للبيانات."""
    for s in ["فيزياء", "كيمياء", "عربي", "انجليزي"]:
        book = json.load(open(f"data/subjects/{s}/grade3/علمي/lessons_mode/{s}.json"))
        lesson = book["الوحدات"][0]["الدروس"][0]
        assert len(to_text(lesson)) > 100, f"{s}: النص فارغ"
    mf = sorted(glob.glob("data/subjects/رياضيات/grade3/علمي/lessons_mode/تفاضل/*.json"))[0]
    assert len(to_text(json.load(open(mf)))) > 100

def test_skip_technical_keys():
    text = to_text({"رقم_الدرس": 1, "اسم_الدرس": "درس", "محتوى": "نص"})
    assert "رقم_الدرس" not in text
    assert "درس" in text

def test_truncation_guard():
    huge = {"محتوى": "ن" * (MAX_LESSON_CHARS * 2)}
    out = serialize_lesson(huge)
    assert len(out) <= MAX_LESSON_CHARS + 100
    assert "اقتصاص" in out

def test_handles_weird_types():
    assert to_text(None) == ""
    assert to_text([]) == ""
    assert to_text({"a": None, "b": [], "c": {}}) == ""
