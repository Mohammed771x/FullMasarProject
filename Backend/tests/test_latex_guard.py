"""🛡️ حارس اللاتيك — لا يصل الطالبَ رمزٌ إنجليزي في شرحٍ عربي.

🔴 **العطل الذي أوجبه:** شرح درسٍ في التكامل يظهر فيه «int» و«quad» و«left»
   ككلماتٍ إنجليزية. ومسحٌ لكل دروس الرياضيات (٦٤ شرحاً حقيقياً · 2026-09-09)
   أثبت أنه ليس نادراً: `\\int` وحدها ٢٣ مرة.

⚖️ **ولماذا فلترٌ لا برومبت؟** البرومبت يمنع LaTeX منذ البداية، والموديل خالفه
   في ٣ من ٦٤. وامتثالُ الموديل احتماليّ بطبعه فلا يبلغ ١٠٠٪ مهما شُدِّد،
   والمطلوب يقين (قرار المالك: «ما أبغى ولا واحد بالمية»).

📌 وحمولات `fixtures/math_explain_raw.json` **مخرجاتٌ حيّة من ذلك المسح** —
   لا أمثلةٌ مصنوعة. فالاختبار يقيس ما يراه الطالب فعلاً.
"""
import json
import pathlib
import re

import pytest

from core.latex_guard import KEPT, SYMBOLS, audit, clean
from subjects.common import format_arabic_math, strip_stray_latex

_FIXTURE = pathlib.Path(__file__).parent / "fixtures" / "math_explain_raw.json"


def _live():
    if not _FIXTURE.exists():
        pytest.skip("حمولات المسح الحيّ غير مثبّتة")
    return json.loads(_FIXTURE.read_text(encoding="utf-8"))


# ══════════════════════════════════════════════════
# 🔤 التحويل لا الحذف
# ══════════════════════════════════════════════════

def test_int_becomes_the_integral_sign_not_english():
    """🔴 هذا هو العطل بعينه: «int» كانت تصل الطالب."""
    assert clean(r"\int د(س) دس") == "∫ د(س) دس"


def test_deleting_would_lose_the_equation():
    """⚠️ الحذف الأعمى (السلوك القديم) يُخرج معادلةً ناقصة — وهي **أسوأ**
    من كلمةٍ إنجليزية لأنها تبدو صحيحة ولا تُنبّه أحداً."""
    out = clean(r"\int_{٠}^{١} س دس")
    assert "∫" in out and "int" not in out


def test_formatting_commands_vanish_and_content_stays():
    assert clean(r"\left( س + ١ \right)").strip() == "( س + ١ )"
    assert "quad" not in clean(r"أ \quad ب")


def test_text_command_keeps_its_argument():
    assert clean(r"\text{المشتقة} = ٢س") == "المشتقة = ٢س"


def test_longest_command_wins():
    """⚠️ `\\in` كانت ستلتهم بداية `\\infty` فتُخرج «∈fty»."""
    assert clean(r"\infty") == "∞"
    assert clean(r"س \in ص") == "س ∈ ص"


def test_renderer_commands_are_untouched():
    """🛡️ ما يرسمه التطبيق لا يُمسّ — وإلا حُذف ما وُلِّد عمداً."""
    keep = r"\frac{١}{س} و \sqrt{٤} و \chem{H2O} و \ring{بنزين} و \fact{ن}"
    assert clean(keep) == keep
    # 📌 `\fact` أُضيف 2026-09-10: رمزُ المضروب العربيّ ⌋ن — [core/factorial.py]
    # 📌 `\perm` و`\comb` أُضيفتا 2026-09-10: التباديل والتوافيق بالرمز
    #    العربي (ن فوق · ر تحت) — [core/counting.py].
    # 📌 و`\sup` أُضيفت في اليوم نفسه: الأُسّ الموحَّد — [core/powers.py].
    # 📌 و`\nuc` أُضيفت 2026-09-12: رمزُ النواة — [core/nuclide.py].
    assert KEPT == {r"\frac", r"\sqrt", r"\chem", r"\ring", r"\fact",
                    r"\perm", r"\comb", r"\sup", r"\ovl", r"\nuc"}


def test_unknown_command_is_dropped_not_left_in_english():
    """🎯 **الضمانة**: القوائم لا تحيط بكل LaTeX، وموديلٌ قد يخترع أمراً."""
    assert "widehat" not in clean(r"س \widehat{ب}")
    assert "zzzcmd" not in clean(r"س \zzzcmd ص")


def test_plain_text_passes_through_untouched():
    plain = "المشتقة الأولى للدالة هي ٢س + ٣."
    assert clean(plain) is plain          # 🚀 خروجٌ مبكر بلا عمل


# ══════════════════════════════════════════════════
# 🔗 الوصل: كل مسار جواب يمرّ بالحارس
# ══════════════════════════════════════════════════

def test_format_arabic_math_applies_the_guard():
    """🔴 مسار «ابدأ الشرح الذكي» يمرّ بهذه **وحدها** (بلا
    `strip_stray_latex`) — وهي لم تكن تعرف `\\int`، فوصل الطالبَ «int»."""
    assert "int" not in format_arabic_math(r"التكامل \int د(س) دس")
    assert "∫" in format_arabic_math(r"التكامل \int د(س) دس")


def test_strip_stray_latex_converts_instead_of_deleting():
    out = strip_stray_latex(r"\int د(س) دس \quad")
    assert "∫" in out and "int" not in out and "quad" not in out


def test_both_paths_agree():
    """المسارَان ينظّفان بنفس القاعدة — لا مادةٌ أنظف من أخرى."""
    src = r"\int \left( س \right) \quad \implies النتيجة \frac{١}{س}"
    a, b = format_arabic_math(src), strip_stray_latex(src)
    assert audit(a) == [] and audit(b) == []
    assert r"\frac" in a and r"\frac" in b


# ══════════════════════════════════════════════════
# 📊 المسح الحيّ — ٦٤ شرحاً حقيقياً
# ══════════════════════════════════════════════════

# 📖 مصطلحات الكتاب الإنجليزية بين قوسين **تبقى** — قرارٌ مقصود.
#
# «القطع الزائد (الهذلول - Hyperbola)» و«البؤرة (F)» موجودة في **نصّ الكتاب
# نفسه**، وهي عرفٌ في الكتب العربية يخدم الطالب: المصطلح الإنجليزي يظهر في
# الامتحانات والمراجع. فحذفُها ليس تنظيفاً بل **إتلافٌ لمحتوى الكتاب**.
#
# ⚠️ والفرق عن `\int`: تلك اسمُ **أمرٍ برمجي** تسرّب، وهذه **مصطلحٌ** مقصود.
_BOOK_TERMS = {
    "hyperbola", "parabola", "ellipse", "directrix", "axis", "vertex",
    "factorial", "f", "n", "x", "y", "o",
}

# 🐛 **هلوسة موديل موثَّقة — لا يُصلحها فلتر.**
#
# في درسٍ من ٦٤ كتب الموديل «ق trước الضرب» — و«trước» كلمة **فيتنامية**
# معناها «قبل». أي أنه أراد «قبل الضرب» فانزلق إلى لغةٍ أخرى.
#
# ⚠️ ولا يجوز أن يُصلحها الحارس: لا سبيل لمعرفة ما أراد يقيناً، وحذفُ
#    الكلمة يترك «ق الضرب» — جملةً مبتورة أسوأ من الأصل. عولجت بتشديد
#    البرومبت («اكتب بالعربية وحدها» قاعدةً قاطعة) — وهو تقليلٌ لا ضمان.
#
# 📌 وتُذكر هنا صراحةً كي **لا تختفي**: إخفاؤها في قائمة المسموح كان
#    سيجعل الاختبار يبدو أخضر على عيبٍ قائم.
_KNOWN_MODEL_GLITCHES = {"tr", "c"}


def test_no_stray_latin_survives_any_live_explanation():
    """⭐ **الاختبار الذي يهمّ**: مخرجاتٌ حقيقية من الموديل، لا أمثلة مصنوعة.

    ولا يشمل مصطلحات الكتاب — راجع [_BOOK_TERMS].
    """
    offenders = []
    for rec in _live():
        body = clean(rec["raw"]).replace(r"\frac", "").replace(r"\sqrt", "")
        stray = [w for w in re.findall(r"[A-Za-z]+", body)
                 if w.lower() not in _BOOK_TERMS
                 and w.lower() not in _KNOWN_MODEL_GLITCHES]
        if stray:
            offenders.append(f"{rec['branch']}/{rec['lesson'][:40]} → {stray[:6]}")
    assert not offenders, "لاتينيّ شارد ناجٍ:\n  " + "\n  ".join(offenders)


def test_composition_symbol_is_fixed_in_live_payload():
    """🔴 «التركيب (ق o د)» — حرفٌ لاتيني مكان رمز التركيب `∘`."""
    for rec in _live():
        if " o " in rec["raw"]:
            out = clean(rec["raw"])
            assert "∘" in out, f"لم يُحوَّل رمز التركيب في {rec['lesson']}"
            return
    pytest.skip("لا حمولة فيها رمز تركيب")


def test_no_latex_command_survives_any_live_explanation():
    offenders = []
    for rec in _live():
        left = audit(clean(rec["raw"]))
        if left:
            offenders.append(f"{rec['branch']}/{rec['lesson'][:40]} → {sorted(set(left))}")
    assert not offenders, "أوامر ناجية:\n  " + "\n  ".join(offenders)


def test_fractions_survive_the_guard_in_live_payloads():
    """⚠️ الحارس يجب ألّا يبتلع `\\frac` — وإلا انهار الرسم كله."""
    total = sum(rec["raw"].count(r"\frac") for rec in _live())
    kept = sum(clean(rec["raw"]).count(r"\frac") for rec in _live())
    assert total > 0, "الحمولات بلا كسور — الاختبار لا يحرس شيئاً"
    assert kept == total, f"ابتُلعت كسور: {total} → {kept}"


@pytest.mark.parametrize("cmd", sorted(SYMBOLS))
def test_every_mapped_symbol_produces_no_latin(cmd):
    """كل رمزٍ في الخريطة يخرج بلا حرفٍ لاتيني — بلا استثناء."""
    out = clean(f"قبل {cmd} بعد")
    assert not re.search(r"[A-Za-z]", out), f"{cmd} → «{out}»"


# ══════════════ ⚗️ أسهمُ التفاعل — عطلٌ صامت (2026-09-12) ══════════════
# 🔴 **ما كان يحدث:** «NaNO_2 + NH_4Cl \longrightarrow NH_4NO_2 + NaCl»
#    يُحذف اسمُ الأمر فيصل الطالبَ **بلا سهم**: طرفان متجاوران يبدوان
#    صحيحين ولا تفاعل بينهما. وهو أخطرُ من ترميزٍ خام لأنه لا يُرى.
#
# 📊 مسحُ المنهج كلِّه (١٤٧٩٥٢ سطراً): `\longrightarrow` ٣٣ · `\uparrow` ٨ ·
#    `\xrightarrow` ٧ · `\rightleftharpoons` ٢ — كلُّها في الكيمياء والأحياء.

def test_the_reaction_arrow_survives():
    out = clean(r"NaNO_2 + NH_4Cl \longrightarrow NH_4NO_2 + NaCl")
    assert "⟶" in out
    assert "longrightarrow" not in out


def test_equilibrium_survives():
    assert "⇌" in clean(r"N2 + 3H2 \rightleftharpoons 2NH3 + Heat")


def test_gas_and_precipitate_marks_survive():
    """⚗️ «↑» يتصاعد و«↓» يترسّب — معلومةٌ كيميائية لا زخرفة."""
    assert clean(r"2NH3\uparrow") == "2NH3↑"
    assert clean(r"CaCO3\downarrow") == "CaCO3↓"


def test_arrow_with_a_condition_becomes_a_drawn_condition():
    r"""⭐ `\xrightarrow{حرارة}` ⇐ `--[حرارة]-->` فيرسمها التطبيق **فوق** السهم."""
    assert (clean(r"3Mg + N2 \xrightarrow{\text{حرارة شديدة}} Mg3N2")
            == "3Mg + N2 --[حرارة شديدة]--> Mg3N2")
    # وبلا شرط يبقى سهماً عارياً.
    assert clean(r"A \xrightarrow B") == "A --> B"


def test_the_reaction_arrow_is_not_reversed():
    r"""⚠️ «إذاً» كلمةٌ تتبع اتجاه النصّ، أمّا «متفاعلات ⟶ نواتج» فثابت.

    فـ`\rightarrow` تبقى «←» (نثرٌ عربي) و`\longrightarrow` تصير «⟶»
    (معادلةٌ كيميائية) — والفرقُ مقصودٌ لا سهو.
    """
    assert clean(r"\rightarrow") == "←"
    assert clean(r"\longrightarrow") == "⟶"


def test_trig_functions_are_arabic():
    """📐 «جا» لا «sin» — ٦ مواضع في الفيزياء كانت تُحذف فتضيع الدالة."""
    assert clean(r"\sin \theta") == "جا θ"
    assert clean(r"\cos") == "جتا"
    assert clean(r"\tan") == "ظا"
