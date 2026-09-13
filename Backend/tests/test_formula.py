"""⚗️ دليلُ الصيغة ينخفض: H2SO4 ⇐ H₂SO₄.

🔴 **طلبُ المالك (2026-09-12):** «الاثنان بعد الـH تكون صغيرة وتحته
   بشوية… ولا تخلط بينها والأرقام اللي قبل: في 2H2O الأولى كبيرة».

📊 **ومسحُ المادّتين قبل الكتابة:** ٤٢٥٩ موضعاً فيه رمزٌ يليه رقم، منها
   ٦١ ليست صيغةً كيميائية — وأخطرُها التوزيعُ الإلكتروني والشحنات.
"""
import glob
import json
import re

from core.formula import FORMULA_SUBJECTS, to_subscript
from subjects.common import _finish

SUB = "₀₁₂₃₄₅₆₇₈₉"
SUP = "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻"
BACK = str.maketrans(SUB + SUP, "0123456789" * 2 + "+-")


# ══════════════ ما ينخفض ══════════════

def test_the_index_goes_down():
    assert to_subscript("H2SO4", "كيمياء") == "H₂SO₄"
    assert to_subscript("H2O", "كيمياء") == "H₂O"
    assert to_subscript("Fe2O3", "كيمياء") == "Fe₂O₃"
    assert to_subscript("C12H22O11", "كيمياء") == "C₁₂H₂₂O₁₁"
    assert to_subscript("C6H5-CHO", "كيمياء") == "C₆H₅-CHO"
    assert to_subscript("CH3-CH2-OH", "كيمياء") == "CH₃-CH₂-OH"


def test_the_coefficient_stays_up():
    """⭐ «في 2H2O الأولى كبيرة والثانية تحت» — نصُّ المالك."""
    assert to_subscript("2H2O", "كيمياء") == "2H₂O"
    assert to_subscript("2NaCl + MnO2", "كيمياء") == "2NaCl + MnO₂"
    assert to_subscript("3Mg + N2", "كيمياء") == "3Mg + N₂"


def test_after_a_closing_bracket_is_an_index():
    assert to_subscript("Ca(OH)2", "كيمياء") == "Ca(OH)₂"
    assert to_subscript("(CH3COO)2Ca", "كيمياء") == "(CH₃COO)₂Ca"


# ══════════════ ما لا يُمسّ ══════════════

def test_a_charge_is_not_an_index():
    """⚡ «Zn2+» شحنةٌ لا دليل — فلا **تنزل** بل تُرفع (انظر أسفل الملف).

    ⚖️ والفارقُ عن رابطة السلسلة: الشرطةُ في «CH3-CH2» يليها **حرف**،
       وفي «2e-» يليها فراغٌ أو نهاية.
    """
    assert "₂" not in to_subscript("Zn → Zn2+ + 2e-", "كيمياء")
    assert to_subscript("CH3-CH2-OH", "كيمياء") == "CH₃-CH₂-OH"


def test_an_electron_configuration_is_not_an_index():
    """🔬 «ns2 np4» رقمُها عددُ إلكترونات يُكتب **مرفوعاً** — فلا يُنزَّل."""
    assert to_subscript("ns2 np4", "كيمياء") == "ns2 np4"
    assert to_subscript("(ns2 np1)", "كيمياء") == "(ns2 np1)"
    assert to_subscript("dx2-y2, dz2", "كيمياء") == "dx2-y2, dz2"


def test_markup_arguments_are_shielded():
    assert (to_subscript(r"\nuc{235}{92}{U} + H2O", "كيمياء")
            == r"\nuc{235}{92}{U} + H₂O")
    assert to_subscript(r"\frac{1}{2} O2", "كيمياء") == r"\frac{1}{2} O₂"


def test_other_patterns_are_untouched():
    for src in ("10^23", "200-300 م", "U-235", "ms = +1/2", "Physics 101"):
        assert to_subscript(src, "كيمياء") == src


# ══════════════ النطاق ══════════════

def test_scope_is_chemistry_and_biology():
    assert FORMULA_SUBJECTS == frozenset({"كيمياء", "احياء"})
    for subject in ("فيزياء", "رياضيات", "منطق", "عربي", ""):
        assert to_subscript("H2SO4", subject) == "H2SO4"


def test_physics_units_are_safe():
    """⚠️ «m/s2» وحدةٌ أُسُّها مرفوع — والفيزياءُ خارج النطاق أصلاً."""
    assert to_subscript("السرعة m/s2", "فيزياء") == "السرعة m/s2"


# ══════════════ المنهج نفسه ══════════════

def test_nothing_but_the_index_changes_across_the_curriculum():
    """🔒 شرطُ المالك الدائم: «المحتوى ضروري يكون نفسه».

    فإرجاعُ الأرقام المنخفضة إلى اللاتينية يجب أن يعيد النصّ **حرفاً
    بحرف** إلى ما كان عليه قبل الإنزال.
    """
    touched = 0
    for subject in sorted(FORMULA_SUBJECTS):
        for path in glob.glob(f"data/subjects/{subject}/**/*.json",
                              recursive=True):
            with open(path, encoding="utf-8") as fh:
                data = json.load(fh)

            def walk(node):
                nonlocal touched
                if isinstance(node, str):
                    for line in node.split("\n"):
                        line = line.strip()
                        if not line or len(line) > 400:
                            continue
                        out = to_subscript(line, subject)
                        if out == line:
                            continue
                        touched += 1
                        # ⚖️ **والمقياسُ أن لا محرفَ يُزاد ولا يُفقد.**
                        #    فقلبُ ترتيب الشحنة («-2» ⇐ «²⁻») وسقوطُ
                        #    فراغِ «SO4 2-» تغييرانِ في **الشكل** أُقرّا
                        #    ووُثّقا، أمّا زيادةُ محرفٍ أو ضياعُه فعطل.
                        back = out.translate(BACK).replace(" ", "")
                        assert (sorted(back) == sorted(line.replace(" ", ""))), (
                            f"{line[:100]} ⇒ {out[:100]}")
                elif isinstance(node, dict):
                    for value in node.values():
                        walk(value)
                elif isinstance(node, list):
                    for value in node:
                        walk(value)

            walk(data)
    # 📊 المسحُ نزّل دليلَ ٢١٦٣ سطراً في المادّتين.
    assert touched > 800, f"عددٌ مريب من الأسطر: {touched}"


_ORBITAL_LINE = re.compile(r"\bns[₀-₉]|\bnp[₀-₉]")


def test_no_electron_configuration_slipped_down():
    """⚠️ حارسٌ مباشر: لا «ns₂» في المنهج كلِّه بعد المعالجة."""
    for subject in sorted(FORMULA_SUBJECTS):
        for path in glob.glob(f"data/subjects/{subject}/**/*.json",
                              recursive=True):
            with open(path, encoding="utf-8") as fh:
                raw = fh.read().replace("\\n", "\n")
            for line in raw.split("\n"):
                if "ns2" not in line and "np" not in line:
                    continue
                out = _finish(line.strip()[:400], subject)
                assert not _ORBITAL_LINE.search(out), out[:120]


# ══════════════ ⚡ الشحنةُ تُرفع (سؤالُ المالك 2026-09-12) ══════════════
# 🔴 «SO4 سالب 2 — إيش دخله؟ هل هو بق أو من أصل المعادلة؟»
#    **الجواب: من الكتاب** (١٠ مواضع) — وأيونُ الكبريتات شحنتُه ٢−.
#    لكن عرضَها مسطّحةً يُقرأ **طرحاً**، فرُفعت إلى صورتها القياسية.

def test_the_charge_is_raised():
    assert to_subscript("SO4-2", "كيمياء") == "SO₄²⁻"
    assert to_subscript("Cu2+(aq)", "كيمياء") == "Cu²⁺(aq)"
    assert to_subscript("Zn+2", "كيمياء") == "Zn²⁺"
    assert to_subscript("Na+ + Cl-", "كيمياء") == "Na⁺ + Cl⁻"
    assert to_subscript("2Cl- -> Cl2 + 2e-", "كيمياء") == "2Cl⁻ -> Cl₂ + 2e⁻"
    assert (to_subscript("H2SO4 -> 2H+ + SO4-2", "كيمياء")
            == "H₂SO₄ -> 2H⁺ + SO₄²⁻")


def test_an_isotope_name_is_not_a_charge():
    """⚠️ «He-4» و«H-2» أسماءُ نظائر — والسالبُ قبل الرقم يلتبس بها.

    فلا يُرفع إلا إذا سبق الإشارةَ **رقم** («SO4-2»)، أو كانت الإشارةُ
    موجبةً بعد رمزٍ كامل («Zn+2») فهي لا تلتبس بنظير.
    """
    for src in ("He-4", "H-2", "H-3", "U-235", "C-14"):
        assert to_subscript(src, "كيمياء") == src


def test_a_general_formula_is_not_a_charge():
    """🔴 «CnH2n+2» الصيغةُ العامة للألكانات — كانت تخرج «CnH₂n²⁺».

    فيُشترط قبل «+الرقم» **رمزُ عنصرٍ كامل** لا حرفٌ في وسط تعبير.
    ومثلُها «2l+1» في أعداد الكمّ.
    """
    assert to_subscript("CnH2n+2", "كيمياء") == "CnH₂n+2"
    assert to_subscript("2l+1", "كيمياء") == "2l+1"
    assert to_subscript("(CnH2n+2)", "كيمياء") == "(CnH₂n+2)"


def test_a_range_is_not_a_charge():
    for src in ("200-300 م", "10-2 سم", "370-428 هـ"):
        assert to_subscript(src, "كيمياء") == src


def test_the_notation_table_is_left_alone():
    """📖 «Mg2+ = Mg++ = Mg+2 = MgII» سطرٌ **يعلّم** أن الصيغ سواء.

    فتوحيدُ صورتين منه إلى واحدة يُلغي الدرس: «Mg²⁺ = Mg++ = Mg²⁺».
    وهما سطران في المنهج كلِّه.
    """
    for src in ("Mg2+ = Mg++ = Mg+2 = MgII", "O2- = O-- = O-2 = O-II"):
        assert to_subscript(src, "كيمياء") == src
    # ⚖️ ومعادلةٌ فيها «=» ليست جدولَ مترادفات.
    assert (to_subscript("Cu+2 + 2Cl- = CuCl2", "كيمياء")
            == "Cu²⁺ + 2Cl⁻ = CuCl₂")


def test_the_compressed_charge_form():
    """🔴 «SO42-» كتابةٌ مضغوطة في جدول الجهود: دليلُها ٤ وشحنتُها ٢−.

    فيُقرأ **آخرُ رقمٍ** شحنةً والباقي دليلاً — وهي القراءةُ القياسية.
    كشفها المسحُ في صفحة ٥٢ من كيمياء الثالث.
    """
    assert to_subscript("SO42-", "كيمياء") == "SO₄²⁻"
    assert to_subscript("PO43-", "كيمياء") == "PO₄³⁻"
    assert to_subscript("CO32-", "كيمياء") == "CO₃²⁻"
    assert (to_subscript("PbO2 + 4H+ + SO42- + 2e-", "كيمياء")
            == "PbO₂ + 4H⁺ + SO₄²⁻ + 2e⁻")
