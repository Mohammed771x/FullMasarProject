"""ترميز كسور نصّ الكتاب — بأسطر مأخوذة حرفياً من كتب المنهج."""
import pytest

from core.fractions import to_frac, is_unit, is_mathy


# ══════════ ما يجب أن يتحوّل — كسور حقيقية من الكتاب ══════════
@pytest.mark.parametrize("src, expected", [
    ("1/λ = RH", r"\frac{1}{λ} = RH"),
    ("ع ن = ع. / ن", r"ع ن = \frac{ع.}{ن}"),
    ("ط ن = ط. / ن^2", r"ط ن = \frac{ط.}{ن^2}"),
    ("طاقة = h (c / λ)", r"طاقة = h (\frac{c}{λ})"),
    ("ك = و / ج", r"ك = \frac{و}{ج}"),
    ("= 20 / 10 =", r"= \frac{20}{10} ="),
    ("نق ن = ( ن^2 h^2 ) / ( 4 π^2 ي ك ش^2 )",
     r"نق ن = \frac{ن^2 h^2}{4 π^2 ي ك ش^2}"),
])
def test_converts_real_formulas(src, expected):
    assert to_frac(src) == expected


# ══════════ ما يجب ألّا يُمسّ — وحدات القياس ══════════
@pytest.mark.parametrize("src", [
    "2.2 × 10^6 م/ث أو 2.2 × 10^8 سم/ث",
    "ج: 10 م/ث^2",
    "9 × 10^9 نيوتن.م^2/كولوم^2",
    "كجم . م / ث / جم . سم / ث (بالنظام الفرنسي)",
    "تتحرك بسرعة 72 كم/ساعة",
    "ويقاس بوحدة 1/m أي مقلوب الطول الموجي",   # m وحدة وإن سبقها رقم
    "التيار 5 A/s",
])
def test_leaves_units_untouched(src):
    assert to_frac(src) == src, "وحدة قياس تحوّلت إلى كسر"


# ══════════ سلامة عامة ══════════
def test_no_duplication_on_repeated_fractions():
    """العلّة التي ظهرت أول مرة: «20 / 10» خرجت «20 \\frac{20}{10}»."""
    out = to_frac("1/2 و 20 / 10 و 3/4")
    assert out.count("20") == 1
    assert out == r"\frac{1}{2} و \frac{20}{10} و \frac{3}{4}"


def test_nested_parentheses_recurse():
    assert to_frac("( 1/س ) / ( 2 )") == r"\frac{\frac{1}{س}}{2}"


def test_idempotent():
    once = to_frac("ك = و / ج")
    assert to_frac(once) == once, "التحويل يجب أن يكون ثابتاً عند التكرار"


@pytest.mark.parametrize("bad", ["", None, "بلا شرطة إطلاقاً", "/", "أ /", "/ ب"])
def test_survives_edge_cases(bad):
    """المدخل غير الصالح يمرّ كما هو — لا استثناء ولا تشويه."""
    assert to_frac(bad) == bad


def test_unit_recognition():
    assert is_unit("م") and is_unit("ث^2") and is_unit("كولوم^2") and is_unit("m")
    assert not is_unit("λ") and not is_unit("ن") and not is_unit("و")


# ══════════ الوحدات الضعيفة: «م» متر أم «مفاعلة»؟ ══════════
def test_weak_unit_letter_used_as_symbol_becomes_fraction():
    """«م سع» = المفاعلة السعوية لا «متر» — سطران من درس التيار المتردد."""
    assert to_frac("1 / م سع كلية") == r"\frac{1}{م} سع كلية"
    assert to_frac("ت ع = جـ ع / م سع") == r"ت ع = جـ \frac{ع}{م} سع"


def test_weak_unit_still_protected_when_both_sides_units():
    for src in ["20 م/ث", "10 م/ث^2", "كجم . م / ث"]:
        assert to_frac(src) == src, f"وحدة مركّبة تحوّلت: {src}"


def test_strong_unit_protects_alone():
    for src in ["بوحدة 1/m", "72 كم/ساعة", "5 A/s", "9 × 10^9 نيوتن.م^2/كولوم^2"]:
        assert to_frac(src) == src, f"وحدة قوية تحوّلت: {src}"


# ══════════ الشرطة النثرية: «أو» لا كسر ══════════
@pytest.mark.parametrize("src", [
    "يصاحبها انطلاق / انبعاث مثال",
    "المقاربات (الرأسية والأفقية/المائلة) بخطوط متقطعة",
    "ΔH = +40.7 KJ/mole",
    "معامل س / معامل س",
    "الطول/العرض للمستطيل",
])
def test_prose_slash_is_not_a_fraction(src):
    assert to_frac(src) == src, "شرطة نثرية تحوّلت إلى كسر"


def test_mathy_check():
    assert is_mathy("س") and is_mathy("نق") and is_mathy("4.4") and is_mathy("λ")
    assert is_mathy("2س + 3", parenthesized=True)
    assert not is_mathy("انطلاق") and not is_mathy("معامل") and not is_mathy("mole")


# ══════════ الأقواس والأُسس — من نصّ كتاب الرياضيات ══════════
@pytest.mark.parametrize("src, expected", [
    ("د(س) = (2س + 3) / (1 - س)", r"د(س) = \frac{2س + 3}{1 - س}"),
    ("ص = (س+1)^2 / 3", r"ص = \frac{(س+1)^2}{3}"),
    ("[ (-1)^ن × ن! ] / (س - أ)^(ن+1)", r"\frac{(-1)^ن × ن!}{(س - أ)^(ن+1)}"),
    ("[ن(ن-1)] / 4!", r"\frac{ن(ن-1)}{4!}"),
    ("(جتا س - 1/جذر(2))", r"(جتا س - \frac{1}{جذر(2)})"),
])
def test_groups_and_powers(src, expected):
    """الأُسّ يبقى ملاصقاً لقوسه، والقوس المربّع مجموعةٌ كالمستدير."""
    assert to_frac(src) == expected


# ══════════════════════════════════════════════════
# 🔍 علل كشفها مسح ٦٤ درساً حقيقياً (2026-09-09)
# ══════════════════════════════════════════════════

def test_function_name_stays_inside_the_numerator():
    """🔴 «د(س) / هـ(ص)» كانت تُخرج `د\\frac{س}{هـ(ص)}`.

    اسم الدالة يبقى **خارج** الكسر فينفصل عن قوسه — تلفٌ أسوأ من الشرطة
    نفسها: الشرطة تُقرأ، وهذا **يُغيّر المعنى**.
    """
    assert to_frac("د(س) / هـ(ص)") == r"\frac{د(س)}{هـ(ص)}"
    assert to_frac("جتا(س) / جا(س)") == r"\frac{جتا(س)}{جا(س)}"


def test_a_slash_is_never_a_numerator():
    """🔴 «(ل1 // ل2)» — علامة التوازي — كانت تُخرج `\\frac{/}{ل2}`.

    كسرٌ بسطه شرطة: خرابيط مرئية على شاشة الطالب.
    """
    assert to_frac("(ل1 // ل2)") == "(ل1 // ل2)"
    assert r"\frac{/}" not in to_frac("أ // ب")


def test_model_output_slashes_convert():
    """شرطات يكتبها الموديل من عنده (لا من الكتاب) — الشبكة الثانية."""
    assert to_frac("دص/دس = ٢س") == r"\frac{دص}{دس} = ٢س"
    assert to_frac("النهاية عند ط/2") == r"النهاية عند \frac{ط}{2}"


def test_units_and_prose_still_untouched_after_the_fixes():
    """⚠️ الإصلاحات أعلاه يجب ألّا تكسر التمييز القائم."""
    assert to_frac("السرعة ٢٠ م/ث") == "السرعة ٢٠ م/ث"
    assert to_frac("انطلاق / انبعاث الطاقة") == "انطلاق / انبعاث الطاقة"
    assert to_frac("72 كم/ساعة") == "72 كم/ساعة"
