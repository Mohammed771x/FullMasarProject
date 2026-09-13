"""ⁿ الأُسّ — آليةٌ واحدة لكل صيغه، وحدٌّ صريح يمنع ابتلاع ما بعده."""

import pytest

from core.powers import to_power
from core.symbols import to_symbols
from subjects.common import strip_stray_latex


@pytest.mark.parametrize("src,want", [
    ("س^2", r"س\sup{2}"),                       # رقم — ١١٣٦ في المنهج
    ("س^-12", r"س\sup{-12}"),                   # سالب — ٥٠٣
    ("ص^(ن-1)", r"ص\sup{ن-1}"),                 # متغيّر بين قوسين — ١٢١
    ("[ر ، هـ]^ن", r"[ر ، هـ]\sup{ن}"),         # متغيّر — ١٣٥
    ("P^{15}", r"P\sup{15}"),                   # معقوف — ٢٧٨
    ("ع^(1/ن)", r"ع\sup{1/ن}"),
])
def test_every_form_becomes_one_markup(src, want):
    assert to_power(src, "رياضيات") == want


def test_a_sign_keeps_the_parentheses():
    """🔴 «^-(ن+١)» ليست «^-ن+١» — إسقاطُ القوسين خطأٌ رياضيّ لا شكليّ."""
    assert to_power("(س-أ)^-(ن+1)", "رياضيات") == r"(س-أ)\sup{-(ن+1)}"
    # وبلا عاملٍ داخليّ لا حاجة لهما
    assert to_power("س^-(٢)", "رياضيات") == r"س\sup{-٢}"


def test_the_exponent_cannot_swallow_what_follows():
    """🔴 «١٠^٢٣ × ٥» — حدُّ الأُسّ صريحٌ فلا تدخل الخمسةُ معه.

    العلّة الأصلية كانت `'^2': '²'` استبدالاً أعمى جعل «10^23» تصير
    «10²3» — أي **عدد أفوجادرو خاطئاً** في كل درس كيمياء كهربائية.
    """
    assert to_power("10^23 × 5", "كيمياء") == r"10\sup{23} × 5"
    assert to_power("س^2 ص", "رياضيات") == r"س\sup{2} ص"


def test_unicode_superscripts_join_the_same_mechanism():
    """⚖️ ١٧٤٨ أُسّاً بيونيكود و٢١٧٣ بـ«^» — المظهر يجب أن يتّحد."""
    assert to_power("س² + ٣س⁻⁵", "رياضيات") == r"س\sup{2} + ٣س\sup{-5}"


def test_chemistry_drawings_are_shielded():
    """⚠️ داخل `\\chem{}` رسّامٌ خاصّ — لا يُمسّ."""
    src = r"المركب \chem{CH3-CH2^2} باقٍ"
    assert to_power(src, "كيمياء") == src


@pytest.mark.parametrize("subject", ["جغرافيا", "احياء", "تاريخ", "عربي"])
def test_outside_the_math_subjects_nothing_changes(subject):
    """⚖️ «كم²» في الجغرافيا وحدةُ مساحةٍ في نصٍّ عادي بلا رسّام."""
    assert to_power("مساحتها 300 كم²", subject) == "مساحتها 300 كم²"


# ══════════════════════════════════════════════════
# π الرموز التي تُكتب كلاماً
# ══════════════════════════════════════════════════

def test_pi_written_in_letters_becomes_the_symbol():
    assert to_symbols("د(باي/4) = 3", "رياضيات") == "د(π/4) = 3"
    assert to_symbols("رابطة باي", "كيمياء") == "رابطة π"


def test_pi_does_not_touch_a_persons_name():
    """🔴 «طومان باي» سلطانُ المماليك — والمادةُ هي الحدّ."""
    src = "دولة المماليك وآخرهم الأشرف طومان باي"
    assert to_symbols(src, "تاريخ") == src


@pytest.mark.parametrize("src", ["تباين ومتباين بين المناطق",
                                 "لم يتجانس سكان الريف ويتباين سكان الحضر"])
def test_pi_is_a_whole_word_not_three_letters(src):
    """⚠️ «تـباين» تحوي الحروف الثلاثة — ٥٤ موضعاً في الجغرافيا وحدها."""
    assert to_symbols(src, "رياضيات") == src


def test_the_live_path_carries_both():
    out = strip_stray_latex("د(باي/4) و س^(ن-1)", "رياضيات")
    # ٠١٢ والأرقام عربية في هذا المسار أيضاً منذ 2026-09-12: كانت تُعرَّب
    #     في `subjects/math` وحدها، فصارت في [_finish] المشتركة.
    assert "π" in out and r"\sup{ن-١}" in out and "باي" not in out
