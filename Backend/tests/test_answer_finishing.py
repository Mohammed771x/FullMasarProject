"""🏁 اللمسات الأخيرة — **واحدةٌ لكل المسارات**.

🔴 **علّةٌ بنيويّة تكرّرت ثلاث مرات (2026-09-09/10):** كل إصلاحٍ يُوصَل بـ
   `format_arabic_math` — وهي مسارُ المعالجات القديمة — بينما **المسار الحيّ**
   لوضعَي الدروس والوحدات هو `core/lesson_mode.py` و`core/pages_mode.py`،
   وهما يناديان `strip_stray_latex` وحدها. فيصل الإصلاح إلى نصف التطبيق.

⭐ فصارت اللمسات دالّةً واحدة (`_finish`) يناديها المساران، ويحرسها هذا
   الملفّ بمقارنة ناتجهما حرفاً بحرف. راجع [organic-chem-drawing].
"""
import pytest

from subjects.common import format_arabic_math, strip_stray_latex

# 📌 حالاتٌ **مأخوذة من ١٦٥ شرحاً حقيقياً** وُلِّدت لكل دروس الكيمياء.
_CASES = [
    r"\frac{CuCl2(aq)}{→} \frac{Cu^{+2}(aq)}{+} \frac{2Cl^{-}(aq)}",
    r"\frac{Cu^{+2}}{+} \frac{2e^{-}}{→} Cu",
    r"\chem{CH4 + 2O2 -> CO2 + 2H2O}",
    r"\chem{Fe2O3 + 3CO -> 2Fe + 3CO2}",
    "6.022 × 10^23 إلكترون",
    "[H+] = 10^-7 مول/لتر",
    r"الكتلة المكافئة = \frac{63.5}{2} = 31.75",
    "CH3-CH2-OH --[Cu / 200-300 م]--> CH3-CHO + H2",
]


@pytest.mark.parametrize("src", _CASES)
def test_both_paths_finish_identically(src):
    """⭐ **الحارس الذي يمنع تكرار العلّة**: أيُّ إصلاحٍ يُضاف لأحدهما دون
    الآخر يُسقط هذا الاختبار فوراً."""
    assert strip_stray_latex(src) == format_arabic_math(src), \
        "افترق مسارُ الدروس عن مسار المعالجات القديمة"


# ══════════════════════════════════════════════════
# 🔬 الأُسّ العلويّ
# ══════════════════════════════════════════════════

def test_avogadro_keeps_both_digits():
    """🔴 كان `'^2': '²'` استبدالاً أعمى فتخرج «10²3» — أي أن **الرقم**
    الذي يراه الطالب خاطئ، لا شكلُه فقط. وهو عددُ أفوجادرو في كل درس."""
    assert strip_stray_latex("6.022 × 10^23") == "6.022 × 10²³"


def test_negative_exponent_and_ion_charges():
    assert strip_stray_latex("10^-7") == "10⁻⁷"
    assert strip_stray_latex("2Cl^{-}") == "2Cl⁻"
    assert strip_stray_latex("Cu^{+2}") == "Cu⁺²"


@pytest.mark.parametrize("src", ["(س-أ)^(ن+1)", "ح^(ر+1)", "(2س)^(12-6)"])
def test_non_numeric_exponent_is_left_for_the_renderer(src):
    """⚠️ **ولا بدّ من أُسٍّ فعليّ**: نمطٌ يقبل الفراغ أكل الرمز `^` نفسه
    فضاع الأُسّ كلُّه — عيبٌ أسوأ ممّا جئنا نُصلحه. ورسّامُ التطبيق يرفع
    ما لا مقابل له في يونيكود."""
    assert strip_stray_latex(src) == src


# ══════════════════════════════════════════════════
# ⚗️ كسورٌ زائفة يكتبها الموديل
# ══════════════════════════════════════════════════

def test_fraction_with_an_arrow_denominator_is_not_a_fraction():
    """🔴 الموديل يكتب «\\frac{CuCl2}{→}» ظانّاً أن `\\frac` تركّب المعادلة
    رأسياً — فيخرج كسرٌ **مقامُه سهم**. ١٦ موضعاً في ١٦٥ شرحاً."""
    out = strip_stray_latex(r"\frac{CuCl2(aq)}{→} \frac{Cu^{+2}(aq)}{+} \frac{2Cl^{-}(aq)}")
    assert out == "CuCl2(aq) → Cu⁺²(aq) + 2Cl⁻(aq)"
    assert r"\frac" not in out


def test_a_real_fraction_survives():
    """🛡️ حارسُ الحارس: التضييق لا يُطفئ ما جئنا لأجله."""
    assert r"\frac{63.5}{2}" in strip_stray_latex(r"الكتلة = \frac{63.5}{2}")


def test_chem_wrapping_an_equation_is_unwrapped_on_the_lessons_path():
    """🔴 `\\chem` تعني «سلسلةٌ واحدة»؛ وتغليفُها معادلةً يبني صفّاً لا
    ينكسر ⇦ فيضانُ الشاشة. وهذا هو **المسار الحيّ** الذي كان بلا علاج."""
    assert strip_stray_latex(r"\chem{CH4 + 2O2 -> CO2 + 2H2O}") \
        == "CH4 + 2O2 -> CO2 + 2H2O"


def test_a_real_structure_keeps_its_wrapper():
    assert r"\chem{CH3-CH(CH3)-CH3}" in \
        strip_stray_latex(r"البنية \chem{CH3-CH(CH3)-CH3}")
