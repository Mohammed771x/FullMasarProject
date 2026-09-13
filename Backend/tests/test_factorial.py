"""⌋ المضروب بالرمز العربي — وخطرُه في علامة التعجّب.

🔴 **طلب المالك (2026-09-10):** «المضروب في اللغة العربية يكون على شكل حرف
   L بس بالمقلوب ويكون فوقه الرقم… إنت حاطه الآن بالإنجليزي».

🔴🔴 **وخطرُه** أن «!» علامةُ تعجّبٍ أيضاً. مسحُ بيانات المواد الرياضية:
     بعد رقم ٦٩ · بعد قوسٍ مغلق ٢٤ ⇦ مضروب. وبعد مسافة ٨ و«؟» ٢ ⇦ نثر:
     «هل رأيت التوأم !». وفيها **«مستحيل!»** بعد حرفٍ عربي — فالتمييز على
     **الكلمة كاملةً** لا على الحرف الذي قبل العلامة.
"""
import pytest

from core.factorial import to_factorial
from subjects.common import strip_stray_latex


@pytest.mark.parametrize("src,want", [
    ("ن!", r"\fact{ن}"),
    ("2!", r"\fact{2}"),
    ("(ن-1)!", r"\fact{ن-1}"),
    ("ر1! × ر2!", r"\fact{ر1} × \fact{ر2}"),
    ("مضروب ن", r"\fact{ن}"),
    ("مضروب (7-1)", r"\fact{7-1}"),
])
def test_factorials_become_drawable(src, want):
    assert to_factorial(src, "رياضيات") == want


def test_the_combinations_law_reads_like_the_book():
    """📖 «ن ق ر = ن! / (ر! × (ن-ر)!)» — قانونُ التوافيق كما في الكتاب."""
    out = to_factorial("(ن ق ر) = ن! / (ر! × (ن-ر)!)", "رياضيات")
    assert out == r"(ن ق ر) = \fact{ن} / (\fact{ر} × \fact{ن-ر})"


# ══════════════════════════════════════════════════
# ⛔ وما لا يجوز أن يُمسّ
# ══════════════════════════════════════════════════

def test_the_bare_symbol_in_a_definition_is_drawn():
    """📖 «مضروب العدد ( ! )» تعريفٌ يُري العلامة — فلتكن **عربية**.

    🔴 قرار المالك (2026-09-10): «ضبط برضو رمز المضروب في التعريف».
       ومشروطٌ بذكر «مضروب»، وإلا فكل «( ! )» تعجّبٌ بين قوسين.
    """
    out = to_factorial("مضروب العدد ( ! ): تعريفه", "رياضيات")
    assert out == "مضروب العدد \\fact{}: تعريفه"


@pytest.mark.parametrize("src", [
    "وضع الطالب ( ! ) بجانب إجابته تعجّباً",   # لا ذكرَ للكلمة ⇒ تعجّب
    "مستحيل! يبدو أن هناك خطأ في نقل السؤال",
    "هل رأيت التوأم ! هل رأيت النجم سهيل ؟",
    "حتى يعرف ؟!!",
    "يظهر المضروب (Factorial) وتناوب الإشارات",
    "مضروب الصفر = 1",
])
def test_prose_exclamations_and_definitions_are_untouched(src):
    """⚠️ «مستحيل!» تنتهي بحرفٍ عربي كـ«ن!» — والفارق **طول الكلمة**."""
    assert to_factorial(src, "رياضيات") == src


def test_out_of_scope_subjects_are_untouched():
    for subj in ("عربي", "احياء", "تاريخ", ""):
        assert to_factorial("رائع! ون!", subj) == "رائع! ون!"


# ══════════════════════════════════════════════════
# 🔗 الوصل
# ══════════════════════════════════════════════════

def test_the_live_path_draws_factorials():
    out = strip_stray_latex("ل(ن، ر) = ن! / (ن-ر)!", "رياضيات")
    # 📌 و«ل(ن، ر)» صارت تُرسم رمزَ تباديل ([core/counting.py]) — فالسطر
    #    كلُّه ترميزٌ الآن: لا «ل(» ولا «!» يصل الطالب.
    assert out == r"\perm{ن}{ر} = \fact{ن} / \fact{ن-ر}"


def test_the_guard_keeps_the_fact_markup():
    """🛡️ `\\fact` ترميزُ رسّامٍ لا أمرُ لاتيك شارد — لو حُذف لضاع المضروب."""
    from core.latex_guard import KEPT, clean
    assert r"\fact" in KEPT
    assert clean(r"\fact{ن}") == r"\fact{ن}"

def test_word_followed_by_punctuation_is_prose():
    """🔴 «وظهور المضروب.» — النقطة ليست مقداراً (خرجت `\\fact{.}` فعلاً)."""
    src = "نلاحظ تناوب الإشارة وظهور المضروب."
    assert to_factorial(src, "رياضيات") == src


@pytest.mark.parametrize("tail", [".", "،", "؛", ":", "»", "…", '"'])
def test_no_punctuation_becomes_an_operand(tail):
    src = f"شرحنا المضروب{tail}"
    assert "\\fact" not in to_factorial(src, "رياضيات")


def test_word_at_end_of_line_stays_prose():
    src = "بقي أن نعرّف المضروب"
    assert to_factorial(src, "رياضيات") == src
