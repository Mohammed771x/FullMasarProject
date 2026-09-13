"""☢️ رمزُ النواة — العدد الكتلي فوق الذرّي، والرمزُ بعدهما.

🔴 **ما رآه المالك (2026-09-12):** «Cl7₁³⁵» و«\\sup{235}_92U» في معادلات
   الانشطار النووي. والسببُ أن `^` و`_` عولجا كلٌّ على حدة، فبقي الدليلُ
   خاماً ورتّب الاتجاهُ الثنائي ما شاء.

📊 ومسحُ المنهج: ١٣٢ موضعاً في الكيمياء، وصفرٌ في كل مادةٍ سواها.
"""
import glob
import re

from core.nuclide import NUCLIDE_SUBJECTS, to_nuclide
from core.latex_guard import KEPT, clean
from subjects.common import _finish


# ══════════════ الصور الأربع التي يكتبها الكتاب ══════════════

def test_mass_atomic_and_symbol():
    assert to_nuclide("^235_92U", "كيمياء") == r"\nuc{235}{92}{U}"
    assert to_nuclide("^1_0n", "كيمياء") == r"\nuc{1}{0}{n}"
    assert to_nuclide("^4_2He", "كيمياء") == r"\nuc{4}{2}{He}"


def test_without_a_symbol():
    """«^12_6» في جدول النظائر — عددان بلا رمز."""
    assert to_nuclide("^12_6", "كيمياء") == r"\nuc{12}{6}{}"


def test_symbol_does_not_swallow_the_next_word():
    """⚠️ «^24_11Na يتحلل» رمزُها «Na» لا «Na يتحلل»."""
    assert to_nuclide("^24_11Na يتحلل", "كيمياء") == r"\nuc{24}{11}{Na} يتحلل"
    # وحين لا رمزَ بعده يبقى الفراغ في مكانه.
    assert to_nuclide("^12_6 نظير", "كيمياء") == r"\nuc{12}{6}{} نظير"


def test_a_signed_atomic_number():
    """🔴 جسيمُ بيتا والإلكترون: العدد الذرّي بإشارة — ١٧ موضعاً كانت تسقط."""
    assert to_nuclide("^0_+1β", "كيمياء") == r"\nuc{0}{+1}{β}"
    assert to_nuclide("^0_-1β", "كيمياء") == r"\nuc{0}{-1}{β}"
    assert to_nuclide("^0_-1e", "كيمياء") == r"\nuc{0}{-1}{e}"
    assert (to_nuclide("4 ^1_1H -> ^4_2He + 2 ^0_+1β", "كيمياء")
            == r"4 \nuc{1}{1}{H} -> \nuc{4}{2}{He} + 2 \nuc{0}{+1}{β}")


def test_the_book_writes_it_correctly():
    """⚖️ **سؤالُ المالك: هل الكتاب غلط؟** لا — الكتابُ يكتبها صحيحة.

    📊 مسحُ منهج الكيمياء: ١٤٩ رمزَ نواةٍ بصيغة `^A_Z`، منها ٦ للألمنيوم.
       وصيغةُ الشرطة «Al-27» فيه ٢٢ موضعاً كلُّها **أسماءُ نظائر في النثر**
       («النظير Cl-35» · «نظير الكربون C-14») لا معادلات. فما ظهر على
       شاشة المالك «Al-27 + He-4» **إعادةُ صياغةٍ من الموديل** لا نقلٌ
       عن الكتاب — ولذلك عولج في البرومبت لا في المحتوى.
    """
    src = "^27_13Al + ^4_2He -> ^30_15P + ^1_0n"
    assert _finish(src, "كيمياء") == (
        r"\nuc{27}{13}{Al} + \nuc{4}{2}{He} -> \nuc{30}{15}{P} + \nuc{1}{0}{n}")


def test_the_prompt_forbids_the_dash_form():
    """🚫 «Al-27» تُسقط العددَ الذرّي فلا يُسترجع — فمُنعت صراحةً."""
    from subjects.common import reaction_equation_rules
    rule = reaction_equation_rules("كيمياء")
    assert "^27_13Al" in rule
    assert "Al-27" in rule and "ممنوعة" in rule


def test_a_whole_fission_equation():
    src = "d) ^235_92U + ^1_0n -> ^141_56Ba + ^92_36Kr + ........"
    out = _finish(src, "كيمياء")
    assert out == (r"d) \nuc{235}{92}{U} + \nuc{1}{0}{n} -> "
                   r"\nuc{141}{56}{Ba} + \nuc{92}{36}{Kr} + ........")
    # ⭐ ولا أثرَ لـ`\sup` هنا: رمزُ النواة يسبق الأُسّ فلا يقتسمانه.
    assert r"\sup" not in out


# ══════════════ النطاق: الكيمياء وحدها ══════════════

def test_scope_is_chemistry_only():
    assert NUCLIDE_SUBJECTS == frozenset({"كيمياء"})
    for subject in ("فيزياء", "احياء", "رياضيات", "منطق", "عربي", ""):
        assert to_nuclide("^235_92U", subject) == "^235_92U"


def test_the_guard_keeps_the_code():
    assert r"\nuc" in KEPT
    assert clean(r"\nuc{235}{92}{U} \quad") .strip() == r"\nuc{235}{92}{U}"


# ══════════════ المنهج نفسه ══════════════

_RAW = re.compile(r"\^\d{1,3}_\d{1,3}")


def test_no_raw_nuclide_survives_the_chemistry_curriculum():
    """⭐ لا يصل الطالبَ `^235_92` خاماً من أي سطرٍ في كتاب الكيمياء."""
    seen = 0
    for path in glob.glob("data/subjects/كيمياء/**/*.json", recursive=True):
        with open(path, encoding="utf-8") as fh:
            raw = fh.read().replace("\\n", "\n")
        for line in raw.split("\n"):
            if not _RAW.search(line):
                continue
            seen += 1
            assert not _RAW.search(_finish(line, "كيمياء")), line[:120]
    # 📊 المسح وجد ١٣٢ موضعاً — والرقم حارسٌ ضد اختفاء البيانات.
    assert seen >= 40, f"عددٌ مريب من رموز النواة: {seen}"


# ══════════════ ⚗️ حارسُ المنهج كلِّه: لا أمرَ لاتيك يصل الطالب ══════════════
# 📊 مسحُ 2026-09-12 على **٩٦٥٠٨ سطراً** من كل المواد والصفوف كشف أربعة
#    أوامرَ كانت تُحذف بصمت فتضيع معها المعلومة: `\longrightarrow` (٣٣)
#    و`\uparrow` (٨) و`\xrightarrow` (٧) و`\rightleftharpoons` (٢).
#    وهذا الاختبار يحرس المادّتين اللتين فيهما المعادلات.

_KEPT_NAMES = {"frac", "sqrt", "chem", "ring", "fact",
               "perm", "comb", "sup", "ovl", "nuc"}
_CMD = re.compile(r"\\([a-zA-Z]+)")


def test_no_latex_command_survives_in_chemistry_and_biology():
    import json
    from core.latex_guard import clean
    checked = 0
    for subject in ("كيمياء", "احياء"):
        for path in glob.glob(f"data/subjects/{subject}/**/*.json",
                              recursive=True):
            with open(path, encoding="utf-8") as fh:
                data = json.load(fh)

            def walk(node):
                nonlocal checked
                if isinstance(node, str):
                    for line in node.split("\n"):
                        line = line.strip()
                        if not line or len(line) > 400:
                            continue
                        if "\\" not in line and "$" not in line:
                            continue
                        checked += 1
                        out = _finish(clean(line), subject)
                        left = [c for c in _CMD.findall(out)
                                if c not in _KEPT_NAMES]
                        assert not left, f"{left} في: {out[:120]}"
                        assert "$" not in out, out[:120]
                elif isinstance(node, dict):
                    for value in node.values():
                        walk(value)
                elif isinstance(node, list):
                    for value in node:
                        walk(value)

            walk(data)
    # 📊 المسحُ وجد ٥٣ سطراً تحمل لاتيك في المادّتين — والرقمُ حارسٌ
    #    ضدّ اختفاء البيانات من تحت الاختبار.
    assert checked >= 40, f"عددٌ مريب من الأسطر: {checked}"
