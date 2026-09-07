# ==================================================
# 🧪 tests/test_ingest.py — تطبيع النص ومقارنة الكتل وحلّ الوجهة
# ==================================================
# لا شبكة هنا إطلاقاً: مراحل النقل والهيكلة تُنادي مزوّدين، وهذه الاختبارات
# تغطّي ما حولها — التطبيع والمقارنة والمسارات، وهي حيث تقع الأخطاء الصامتة.

import os
import pytest

from core import ingest, textnorm
from core.textnorm import normalize, audit, is_math_bearing


# ══════════════ التطبيع ══════════════

@pytest.mark.parametrize("a,b", [
    ("س²", "س^2"),                    # رمز مرتفع = صيغة ^
    ("٣س + ٤", "3س + 4"),             # أرقام عربية-هندية = لاتينية
    ("2 × 3 ÷ 4", "2 * 3 / 4"),       # رموز العمليات المتكافئة
    ("د′(س)", "د'(س)"),               # علامة المشتقة بأشكالها
    ("س‏ + ص", "س + ص"),         # محارف ثنائية الاتجاه غير مرئية
    ("س   +\n ص", "س + ص"),           # المسافات المتعددة
])
def test_normalize_equivalences(a, b):
    assert normalize(a) == normalize(b)


def test_superscript_run_stays_one_number():
    """«س¹²» أسّها ١٢ لا ١ ثم ٢ — الخلط هنا يقلب معنى المعادلة."""
    assert normalize("س¹²") == normalize("س^12")
    assert normalize("س¹²") != normalize("س^1^2")


def test_normalize_never_hides_a_digit_change():
    """⚠️ حجر الأساس: التطبيع يوحّد الشكل ولا يوحّد القيمة أبداً."""
    assert normalize("س + ص = 10") != normalize("س + ص = 100")


def test_is_math_bearing():
    assert is_math_bearing("س + ص = 10")
    assert is_math_bearing("نها جا 2س / س")
    assert not is_math_bearing("الهرمونات مواد كيميائية تفرزها الغدد")


# ══════════════ مقارنة الكتل ══════════════

RAW = """--- صفحة 3 ---
التعريف: المتتابعة الحسابية هي متتابعة يكون الفرق بين
كل حدين متتاليين فيها ثابتاً.
--- صفحة 4 ---
س + ص = 10
الحد العام: ح(ن) = أ + (ن - 1) × د
"""


def test_exact_copy_passes_despite_notation():
    """نقلٌ أمين بترميز مختلف يجب ألا يُطلق إنذاراً — وإلا صار التقرير ضجيجاً."""
    data = {"تعريفات": [{"النص": "س + ص = ١٠"}]}
    res = audit(RAW, data)
    assert res["issues"] == []
    assert res["exact"] == 1


def test_digit_change_is_high_severity():
    """الحالة التي يمرّرها فحص «وجود كل رمز»: 10 → 100."""
    data = {"تعريفات": [{"النص": "س + ص = 100"}]}
    issues = audit(RAW, data)["issues"]
    assert len(issues) == 1
    assert issues[0]["level"] == "high"
    assert issues[0]["kind"] == "أرقام مختلفة"
    assert issues[0]["expected"] == "س + ص = 10"
    assert issues[0]["page"] == 4


def test_invented_equation_has_no_source():
    data = {"أمثلة_محلولة": [{"النتيجة": "مجموع الحدود = 5 × ع^3 - 17"}]}
    issues = audit(RAW, data)["issues"]
    assert issues and issues[0]["kind"] == "بلا أصل في النص الخام"
    assert issues[0]["level"] == "high"


def test_definition_split_over_two_raw_lines_matches():
    """الملخّص يكسر التعريف سطرين والموديل يدمجه — نقلٌ أمين لا اختلاف."""
    data = {"تعريفات": [{"النص": "التعريف: المتتابعة الحسابية هي متتابعة يكون "
                                  "الفرق بين كل حدين متتاليين فيها ثابتاً."}]}
    assert audit(RAW, data)["issues"] == []


def test_free_field_prose_is_not_compared():
    """الحقول الحرّة للموديل أن يصوغها — نثرها لا يُقارَن."""
    data = {"ملخص_قصير": "درسٌ لطيف يمهّد لمفهوم المتتابعات ويربطه بالحياة."}
    assert audit(RAW, data)["issues"] == []


def test_free_field_equation_is_still_compared():
    """لكن معادلةً مخترعة داخل حقلٍ حرّ خطرها كخطرها في المحمي."""
    data = {"الشرح": "ونستنتج أن س + ص = 999 وهذا هو المطلوب."}
    issues = audit(RAW, data)["issues"]
    assert issues and issues[0]["level"] == "high"


# ══════════════ حلّ الوجهة ══════════════

def test_math_goes_to_its_own_lesson_file():
    d = ingest.resolve(3, "علمي", "رياضيات", "lessons_mode", "جبر", "درس اختبار")
    assert d["layout"] == "per_lesson"
    assert d["path"].endswith(os.path.join("جبر", "درس اختبار.json"))


def test_subject_with_single_book_file_writes_into_it():
    """⚠️ وجود ملفٍ واحد في المجلد يُعمي content_store عن أي مجلدات بجانبه،
    فالإضافة داخله إلزامية — وإلا حُفظ الدرس ولم يظهر للطالب أبداً."""
    d = ingest.resolve(3, "علمي", "كيمياء", "lessons_mode", "الكيمياء الحرارية", "درس")
    assert d["layout"] == "single_file"
    assert d["path"].endswith("كيمياء.json")


def test_subject_not_in_grade_is_rejected():
    with pytest.raises(ingest.IngestError):
        ingest.resolve(3, "علمي", "تاريخ", "lessons_mode", "وحدة", "درس")


def test_lesson_name_may_not_start_with_underscore():
    """اسم يبدأ بـ `_` يتجاهله content_store — يُنظَّف لا يُقبل كما هو."""
    assert ingest._safe_name("_درس") == "درس"
    assert "/" not in ingest._safe_name("جبر/درس")
    with pytest.raises(ingest.IngestError):
        ingest._safe_name("__")


def test_upsert_replaces_lesson_with_same_name():
    book = {"الوحدات": [{"اسم_الوحدة": "و1", "الدروس": [{"اسم_الدرس": "د", "x": 1}]}]}
    ingest._upsert_lesson(book, "و1", {"اسم_الدرس": "د", "x": 2})
    lessons = book["الوحدات"][0]["الدروس"]
    assert len(lessons) == 1 and lessons[0]["x"] == 2
