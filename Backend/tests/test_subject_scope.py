"""🗺️ **خريطةُ الرسّام: أيُّ محوِّلٍ يدخل أيَّ مادة.**

🔴 **ما طلبه المالك (2026-09-10):** «شوف كل المواد، ضبط ماشي دخولات
   الرسّام كل مادة لوحده عشان ما يخبّط».

⚖️ وهذا الملفّ **عقدٌ مكتوب** لا وصفٌ: كلُّ خانةٍ في الجدول أدناه
   مُثبتةٌ بمثالٍ من الكتاب. فإن وسّع أحدٌ نطاقَ محوِّلٍ يوماً، سقط
   الاختبار وأخبره **بأي درسٍ سيتلف**.

المصفوفة:

| المحوِّل | المواد | لماذا لا يُعمَّم |
|---|---|---|
| كسر `\\frac`   | **الكل** | «/» بين عددين قسمةٌ في كل لغة |
| جذر `\\sqrt`   | رياضيات · فيزياء · كيمياء · منطق | «جذر» في الأحياء جذرُ نبات (١١٦) |
| مضروب `\\fact` | ↑ نفسها | «!» تعجّبٌ في النثر |
| أُسّ `\\sup`    | ↑ نفسها | «كم²» في الجغرافيا نصٌّ عاديّ |
| باي `π`        | ↑ نفسها | «طومان باي» في التاريخ |
| عدّ `\\perm`/`\\comb` | **رياضيات · منطق** | «ق_ج» قوةُ الجاذبية (٨٥) |
| «ط» ⇒ `π`      | **رياضيات وحدها** | «ط = ك × ع²» الطاقةُ في الكيمياء |
| كيمياء `\\chem`| كيمياء · احياء | سلاسلُ الكربون |
"""

import pytest

from core.counting import to_counting
from core.factorial import to_factorial
from core.powers import to_power
from core.roots import to_sqrt
from core.symbols import to_symbols

ALL_SUBJECTS = ["رياضيات", "فيزياء", "كيمياء", "منطق", "احياء", "جغرافيا",
                "تاريخ", "عربي", "انجليزي", "فلسفة", "علم الاجتماع",
                "علم الاقتصاد", "مجتمع", "مبادئ علم الخرائط"]

MATHY = {"رياضيات", "فيزياء", "كيمياء", "منطق"}
COUNTING = {"رياضيات", "منطق"}
PI_LETTER = {"رياضيات"}


@pytest.mark.parametrize("subject", ALL_SUBJECTS)
def test_roots_factorials_powers_share_one_scope(subject):
    inside = subject in MATHY
    assert (r"\sqrt" in to_sqrt("جذر ٣ يساوي", subject)) is inside
    assert (r"\fact" in to_factorial("احسب ٥!", subject)) is inside
    assert (r"\sup" in to_power("س^2", subject)) is inside
    assert ("π" in to_symbols("د(باي/4)", subject)) is inside


@pytest.mark.parametrize("subject", ALL_SUBJECTS)
def test_counting_is_narrower_than_the_rest(subject):
    """⚖️ الفيزياء **خارج** العدّ وإن كانت رياضيةً — بسبب «ق_ج»."""
    out = to_counting("ل(ن، ر) و (ن ق ر)", subject)
    assert (r"\perm" in out) is (subject in COUNTING)


@pytest.mark.parametrize("subject", ALL_SUBJECTS)
def test_ta_as_pi_is_the_narrowest(subject):
    """⚖️ «ط» = π في الرياضيات وحدها — وفي الكيمياء هي الطاقة."""
    out = to_symbols("جا(ط/4)", subject)
    assert ("π" in out) is (subject in PI_LETTER)


# ══════════════════════════════════════════════════
# 🛑 وما كان سيتلف لو عُمّم — سطورٌ من الكتاب حرفياً
# ══════════════════════════════════════════════════

@pytest.mark.parametrize("src,subject,must_keep", [
    ("ق_ج = ك . د", "فيزياء", "ق_ج"),                       # قوة الجاذبية
    ("ط م = ١/٢ سع × جـ٢", "فيزياء", "ط م"),                # طاقة الوضع
    ("بحبل يتدلى منه سطل ( ط ) به رمل", "فيزياء", "( ط )"),  # اسمٌ في رسم
    ("عوض في قانون أينشتاين ط = ك × ع^٢", "كيمياء", "ط ="),  # الطاقة
    ("م ط = مرونة الطلب .", "علم الاقتصاد", "م ط"),
    ("حيث ن، ر ∋ ط :", "منطق", "∋ ط"),                      # مجموعة
    ("جذور النبات تمتص الماء", "احياء", "جذور النبات"),
    ("مساحتها 300 كم²", "جغرافيا", "كم²"),
    ("دولة المماليك وآخرهم طومان باي", "تاريخ", "طومان باي"),
    ("ل(ن، ر) للدالة", "فيزياء", "ل(ن، ر)"),
])
def test_the_hazard_in_each_line_survives(src, subject, must_keep):
    """⚖️ الفحصُ على **موضع الخطر** لا على السطر كلِّه.

    فـ«ع^٢» في معادلة أينشتاين **يجب** أن يصير أُسّاً مرسوماً؛ الممنوعُ
    وحده أن تصير «ط» رمزَ π. ومساواةُ السطر بنفسه تخلط الأمرين.
    """
    out = src
    for fn in (to_sqrt, to_factorial, to_counting, to_power, to_symbols):
        out = fn(out, subject)
    assert must_keep in out, f"تلف موضعُ الخطر في {subject}: {out}"
    assert "π" not in out
