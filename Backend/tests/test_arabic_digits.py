"""٠١٢ الأرقام بالعربية — الرياضيات والمنطق والفيزياء.

🔴 **ما رآه المالك (2026-09-09):** «خليه يعطي الأرقام باللغة العربية.
   الآن هو يعطي أرقام باللغة الإنجليزية» — في الرياضيات وفي المنطق.

⚖️ وبرومبت المنطق كان **يطلبها فعلاً** بعبارة «اكتب الأرقام بشكل نصي نظيف
   ومقروء» — وهي عبارةٌ لا تُلزم شيئاً، فخرجت لاتينية. فالفلتر يضمن،
   والبرومبت صار أمراً صريحاً بالرموز نفسها.
"""
import glob
import json
import re

import pytest

from core.arabic_digits import (
    ARABIC_DIGIT_SUBJECTS, for_subject, to_arabic,
)
from core.steps_format import space_steps
from subjects.common import _finish, arabic_digits_rules, pages_with_headers
from subjects.math import _finalize, system_prompt_math_explain


# ══════════════════════════════════════════════════
# ٠١٢ التحويل
# ══════════════════════════════════════════════════

def test_plain_numbers_become_arabic():
    assert to_arabic("ص = 2س² + 1") == "ص = ٢س² + ١"


def test_numbers_inside_fractions_convert_too():
    assert to_arabic(r"\frac{2س}{س - 1}") == r"\frac{٢س}{س - ١}"


def test_chemical_formulas_are_untouched():
    """🛡️ **الحدّ الذي يمنع الكارثة:** «H2O» ليست عدداً بل رمزٌ مركّب،
    وتحويلها يُخرج «H٢O» — رمزاً لا يعرفه أحد ولا يرسمه الرسّام."""
    assert to_arabic("H2O و CO2 مع 5 جزيئات") == "H2O و CO2 مع ٥ جزيئات"
    assert to_arabic(r"\chem{H2O} و 12 مول") == r"\chem{H2O} و ١٢ مول"


def test_text_without_digits_is_returned_as_is():
    plain = "المستقيم المقارب الرأسي"
    assert to_arabic(plain) is plain          # 🚀 خروجٌ مبكر بلا عمل


def test_no_latin_digit_survives_the_math_pipeline():
    """⭐ الضمانة على المسار كاملاً لا على الدالّة وحدها."""
    out = _finalize("الحل: ص = 2س + 1 عند س = 3")
    assert not re.search(r"[0-9]", out), out


def test_the_prompt_no_longer_contradicts_the_rule():
    """⚠️ كان البرومبت يأمر بالعربية ثم يضرب المثال بـ«ص = 2س² + 1» —
    ومثالٌ مخالفٌ أقوى أثراً في الموديل من قاعدةٍ مجرّدة."""
    p = system_prompt_math_explain()
    assert "٠١٢٣٤٥٦٧٨٩" in p
    assert not re.search(r"ص = [0-9]", p)


# ══════════════════════════════════════════════════
# 📐 تباعد الخطوات
# ══════════════════════════════════════════════════

def test_a_blank_line_separates_numbered_steps():
    """🔴 شكوى المالك: «فيه نقطة قبل الكلام وينحسب من ضمن المعادلة»."""
    out = space_steps("١. **المجال:** س ≠ ١.\n٢. **المشتقة:** د'(س) = ٢س")
    assert "\n\n٢." in out


def test_bullets_of_one_list_stay_together():
    """⚠️ التباعد الأعمى يبعثر القائمة الواحدة على كتلٍ متفرّقة —
    وهو أسوأ من الالتصاق لأنه يُفقد الترابط."""
    out = space_steps("- الرأسي: س = ١\n- الأفقي: لا يوجد\n- المائل: موجود")
    assert "\n\n-" not in out


def test_fenced_blocks_are_left_alone():
    src = "```\n١. سطر\n٢. سطر\n```"
    assert space_steps(src) == src


def test_spacing_adds_nothing_but_whitespace():
    """🛡️ حارسٌ صارم: المنسّق **شكليّ بحت** — لا يُضيف ولا يحذف حرفاً."""
    src = "١. **المجال:** س ≠ ١.\n- بند\n- بند آخر\n٢. **النهاية:** ∞"
    strip = lambda t: re.sub(r"\s+", "", t)
    assert strip(space_steps(src)) == strip(src)


@pytest.mark.parametrize("src", ["", "سطر واحد", "\n\n\n"])
def test_spacing_survives_degenerate_input(src):
    assert space_steps(src) is not None

# ══════════════════════════════════════════════════
# 🔬 الفيزياء — طلبُ المالك 2026-09-12
# ══════════════════════════════════════════════════
# 🔴 «مادة الفيزياء شيكت عليها، أمورها طيبة. فقط الأرقام حوّلها كامل
#    بالعربية، والسالب يكون من جهة يمين الرقم».
#
# 📊 **ومسحُ الكتاب قبل الكتابة (٢٦٧٣٨ سطراً):** ٣٩٧ موضعاً رقمُه ملاصقٌ
#    لحرفٍ لاتيني — كلُّها رموز (T1 · W0 · 500mA) لا أعداد.

def test_scope_is_the_three_subjects():
    assert ARABIC_DIGIT_SUBJECTS == frozenset({"رياضيات", "منطق", "فيزياء"})
    for subject in ("كيمياء", "احياء", "عربي", "انجليزي", "", None):
        assert for_subject("القوة 5 نيوتن", subject) == "القوة 5 نيوتن"
    for subject in ("رياضيات", "منطق", "فيزياء"):
        assert for_subject("القوة 5 نيوتن", subject) == "القوة ٥ نيوتن"


def test_chemistry_keeps_its_latin_digits():
    """🔒 عقدُ المالك للكيمياء (2026-09-12): «خليها كلها أرقام إنجليزية».

    فهي المادةُ **الوحيدة** التي تُكتب إشارةُ عددها يسارَه، ولا معنى
    لذلك إلا بأرقامٍ لاتينية — راجع `latinSignSubjects` في التطبيق.
    """
    assert for_subject("dH = -25.9 KJ", "كيمياء") == "dH = -25.9 KJ"
    assert arabic_digits_rules("كيمياء") == ""
    assert "٠١٢٣٤٥٦٧٨٩" in arabic_digits_rules("فيزياء")


def test_physics_symbols_keep_their_latin_digits():
    """⚠️ «T1» و«T2» و«W0» و«f0» رموزٌ لا أعداد — ٣٩٧ موضعاً في الكتاب."""
    src = "T1 = 300 كلفن و T2 = 450 كلفن"
    assert _finish(src, "فيزياء") == "T1 = ٣٠٠ كلفن و T2 = ٤٥٠ كلفن"
    assert _finish("E = 6.63 × 10^-34 × f0", "فيزياء") == (
        "E = ٦.٦٣ × ١٠\\sup{-٣٤} × f0")


def test_the_whole_run_is_shielded_not_just_the_adjacent_digit():
    """🔴 «500mA» كان يخرج «٥٠0mA» و«C141» يخرج «C1٤١».

    تحويلٌ نصفيّ **أقبحُ من لا تحويل**: الحدُّ كان يحمي الرقمَ الملاصقَ
    وحده، والرمزُ سلسلةٌ واحدة. (٩ رموزٍ من ٦٦ في كتاب الفيزياء.)
    """
    assert to_arabic("500mA") == "500mA"
    assert to_arabic("C141") == "C141"
    assert to_arabic("180R") == "180R"
    assert to_arabic("مقاومة 50mA و 5 أوم") == "مقاومة 50mA و ٥ أوم"


def test_a_latex_command_name_does_not_shield_its_number():
    """🔴 «\\times10^{14}» كان يخرج «×1٠»: حرفُ الأمر الأخير لاصقَ رقمَ
    **المعادلة**، فظُنّ الـ«1» جزءاً من رمز. (٣ أسطر في الكتاب.)"""
    assert to_arabic(r"\times10^{14}") == r"\times١٠^{١٤}"
    assert to_arabic(r"\frac{1}{2}") == r"\frac{١}{٢}"


def test_the_sign_stays_before_its_number_in_the_text():
    """➖ **والقلبُ في الرسم لا في النصّ.**

    الرقمُ العربي-الهندي صنفُه AN في خوارزمية الاتجاه الثنائي، فتُحلّ
    الإشارةُ المجاورة له محايدةً فتأخذ اتجاهَ السطر (RTL) فتقع **يمينه**
    على الشاشة. فلو قلبناها في النصّ أيضاً لانقلبت مرّتين.
    """
    assert _finish("القوة = -5 نيوتن", "فيزياء") == "القوة = -٥ نيوتن"
    assert "قبل" in arabic_digits_rules("فيزياء")


def test_the_exponent_and_the_root_carry_arabic_digits():
    assert _finish("ع = 3 × 10^8 م/ث", "فيزياء") == "ع = ٣ × ١٠\\sup{٨} م/ث"
    assert _finish("ك = جذر(2ط/ج)", "فيزياء") == "ك = \\sqrt{٢ط/ج}"


def test_the_book_text_reaches_the_model_arabic():
    """⭐ الكتابُ يُصلَح **قبل** الموديل، فينقله مصلَحاً من تلقائه."""
    from core.serializer import serialize_lesson
    lesson = {"الأجزاء": [{"المحتوى": ["القوة = 5 نيوتن"]}]}
    assert "٥ نيوتن" in serialize_lesson(lesson, "وحدة", subject="فيزياء")
    assert "5 نيوتن" in serialize_lesson(lesson, "وحدة", subject="كيمياء")
    pages = [{"رقم_الصفحة": 12, "نص_الصفحة": "الزمن 3 ثوان"}]
    assert "٣ ثوان" in pages_with_headers(pages, "فيزياء")
    assert "الصفحة ١٢" in pages_with_headers(pages, "فيزياء")
    assert "3 ثوان" in pages_with_headers(pages, "كيمياء")


# ══════════════ المنهج نفسه — فحصٌ شامل ══════════════

def _curriculum_lines(subject):
    for path in glob.glob(f"data/subjects/{subject}/**/*.json", recursive=True):
        with open(path, encoding="utf-8") as fh:
            data = json.load(fh)

        def walk(node):
            if isinstance(node, str):
                for line in node.split("\n"):
                    line = line.strip()
                    if line and len(line) <= 400:
                        yield line
            elif isinstance(node, dict):
                for value in node.values():
                    yield from walk(value)
            elif isinstance(node, list):
                for value in node:
                    yield from walk(value)

        yield from walk(data)


_BACK = str.maketrans("٠١٢٣٤٥٦٧٨٩", "0123456789")


# 📊 عددُ الأسطر المتغيّرة في كلّ كتاب — حارسٌ ضدّ اختفاء البيانات من
#    تحت الاختبار (قياسُ 2026-09-12).
_TOUCHED = {"فيزياء": 6375, "رياضيات": 2018, "منطق": 277}


@pytest.mark.parametrize("subject", ["فيزياء", "رياضيات", "منطق"])
def test_nothing_but_the_digit_shape_changes(subject):
    """🔒 شرطُ المالك الدائم: «المحتوى ضروري يكون نفسه… الصيغة فقط».

    فإرجاعُ الأرقام العربية إلى اللاتينية يجب أن يردّ النصَّ **حرفاً
    بحرف** إلى ما كان عليه.
    """
    seen = 0
    for line in _curriculum_lines(subject):
        out = to_arabic(line)
        if out != line:
            seen += 1
        assert out.translate(_BACK) == line.translate(_BACK), line[:120]
    assert seen >= _TOUCHED[subject] * 0.9, (
        f"عددٌ مريب من الأسطر المتغيّرة في {subject}: {seen}")


_BARE_LATIN = re.compile(r"(?<![A-Za-z0-9])[0-9]+(?![A-Za-z0-9])")


def test_no_bare_latin_number_survives_the_physics_curriculum():
    """⭐ **الفحصُ الشامل الذي طلبه المالك**: لا عددٌ لاتينيٌّ واحد يصل
    الطالبَ من كتاب الفيزياء كلِّه — والاستثناءُ الوحيد رمزٌ لاصقَ رقمَه.

    📊 مسحُ 2026-09-12: ١٩٣٥٥ سطراً، تغيّر ٦٥٨٢ منها، والناجي **صفر**.
    """
    checked = 0
    for line in _curriculum_lines("فيزياء"):
        checked += 1
        out = _finish(line, "فيزياء")
        assert not _BARE_LATIN.search(out), out[:140]
    assert checked > 15000, f"عددٌ مريب من الأسطر: {checked}"


_HALF = re.compile(r"[0-9][٠-٩]|[٠-٩][0-9]")


def test_no_half_converted_token_in_the_physics_curriculum():
    """⚠️ حارسُ العلّة التي وقعت فعلاً: «٥٠0mA» — رقمٌ نصفُه عربيّ."""
    for line in _curriculum_lines("فيزياء"):
        out = _finish(line, "فيزياء")
        assert not _HALF.search(out), out[:140]


def test_the_ministerial_questions_are_arabic_too():
    """📝 مسارُ الوزاري **لا يمرّ بـ[_finish]**: نصٌّ يُركَّب من ملف
    الامتحانات لا جوابُ موديل — فكانت أرقامُه تبقى لاتينية وحدها بين
    كل الفيزياء. (كُشف بمراجعة المسارات لا بالشاشة.)"""
    import ast
    import inspect
    import textwrap

    from subjects import physics
    src = inspect.getsource(physics.handle_physics_exams)
    tree = ast.parse(textwrap.dedent(src))
    returns = [n for n in ast.walk(tree) if isinstance(n, ast.Return)]
    # كلُّ ردٍّ يحمل نصّاً مُركَّباً من الملف يجب أن يُعرَّب.
    composed = [n for n in returns
                if isinstance(n.value, ast.Dict)
                and any(isinstance(v, ast.Call) for v in n.value.values)]
    assert composed, "لم يُعثر على ردٍّ مُركَّب — تغيّرت بنية المعالج"
    for node in composed:
        assert any(getattr(v.func, "id", "") == "_arabic_digits"
                   for v in node.value.values if isinstance(v, ast.Call)), (
            ast.unparse(node)[:120])
