"""‾ المرافق والمتمّمة — وثلاثةُ معانٍ لفتحةٍ واحدة."""

import pytest

from core.overline import to_overline
from subjects.common import strip_stray_latex

OVL = "̅"
FATHA = "َ"
TANWEEN = "ً"


# ══════════════════════════════════════════════════
# ✅ المرافق — المحرف المركّب لا يكون إلا مرافقاً
# ══════════════════════════════════════════════════

def test_conjugate_on_a_letter():
    assert to_overline(f"ع + ع{OVL} = 2س", "رياضيات") == r"ع + \ovl{ع} = 2س"


def test_conjugate_keeps_its_index_under_the_bar():
    """⚖️ «ع̅1» مرافقُ «ع١» لا مرافقُ «ع» يتلوه واحد."""
    out = to_overline(f"ع{OVL}1 ± ع{OVL}2", "رياضيات")
    assert out == r"\ovl{ع1} ± \ovl{ع2}"


def test_conjugate_over_a_whole_group():
    """🔴 «(ع1 ± ع2)̅» — العلامة بعد قوسٍ مغلق تعمّ القوسَ كلَّه.

    وهي بالضبط الحالةُ التي لا تظهر في الكتاب: المحرف المركّب يعلو
    حرفاً واحداً، فيلتصق بالقوس نفسِه فلا يُرى.
    """
    out = to_overline(f"(ع1 ± ع2){OVL} = ع{OVL}1", "رياضيات")
    assert out.startswith(r"\ovl{(ع1 ± ع2)}")


# ══════════════════════════════════════════════════
# 🔴 الفتحة: متمّمةٌ أم مشتقة؟ — السياق يحسم
# ══════════════════════════════════════════════════

@pytest.mark.parametrize("src,want", [
    (f"حـا(أ{FATHA}) = ١ - حـا(أ)", r"حـا(\ovl{أ}) = ١ - حـا(أ)"),
    (f"حـا( (أ ∪ ب){FATHA} )", r"حـا( \ovl{(أ ∪ ب)} )"),
    (f"عدم وقوع الحادثة أ{FATHA}", r"عدم وقوع الحادثة \ovl{أ}"),
])
def test_in_probability_the_fatha_is_a_complement(src, want):
    assert to_overline(src, "رياضيات") == want


@pytest.mark.parametrize("src,want", [
    (f"ل {FATHA}(س) = د(س)", "ل′(س) = د(س)"),
    (f"إذا كانت ص{TANWEEN} = ٣س² - ٢", "إذا كانت ص″ = ٣س² - ٢"),
    (f"توجد نقطة ن{FATHA} بحيث", "توجد نقطة ن′ بحيث"),
])
def test_outside_probability_the_fatha_is_a_prime(src, want):
    """🔴 لولا السياق لصارت **مشتقةُ الدالة متمّمتَها**.

    مسحُ وحدات الرياضيات: احتمالات ٤٥ متمّمة · تفاضل وتكامل ١٧ مشتقة ·
    هندسة ٣ صورةُ نقطة. والعلامةُ واحدةٌ في الثلاث.
    """
    assert to_overline(src, "رياضيات") == want


# ══════════════════════════════════════════════════
# ⛔ والفتحة حركةٌ عربية في كل نصٍّ آخر
# ══════════════════════════════════════════════════

@pytest.mark.parametrize("subject", ["تاريخ", "عربي", "احياء", "فيزياء",
                                     "كيمياء", "منطق", "فلسفة"])
def test_no_other_subject_is_touched(subject):
    src = "قال تعالى : ﴿ سُبْحَانَ الَّذِي خَلَقَ الْأَزْوَاجَ ﴾"
    assert to_overline(src, subject) == src


def test_a_diacritic_inside_a_word_is_never_a_symbol():
    """⚠️ الحدّ **حرفٌ مفرد**: «الَّذِي» فتحاتُها داخل كلمة."""
    src = "الحادثة الَّتي وقعت في المجموعة"
    assert to_overline(src, "رياضيات") == src


def test_the_live_path_carries_it():
    out = strip_stray_latex(f"ع × ع{OVL} = ر²", "رياضيات")
    assert r"\ovl{ع}" in out
