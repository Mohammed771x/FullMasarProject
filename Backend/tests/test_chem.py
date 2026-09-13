"""ترميز الصيغ البنائية — أسطر منقولة حرفياً من `كيمياء.json`.

القاعدة التي تحرسها هذه الاختبارات: **الإفراط أخطر من النقص**. تحويلُ
معادلةٍ أو قانونٍ عام إلى «صيغة بنائية» يعطي الطالب كيمياء خاطئة، بينما
فواتُ صيغةٍ يعطيه سطراً عادياً كما كان.
"""
from core.chem import to_chem, ring_code


# ══════════ ما يجب أن يُحوَّل ══════════

def test_chain_with_spaces_from_book():
    # «CH3 CH2 CH2 NH2 : يسمى بروبيل أمين أو أمينو بروبان.»
    out = to_chem("CH3 CH2 CH2 NH2 : يسمى بروبيل أمين")
    assert r"\chem{CH3 CH2 CH2 NH2}" in out or r"\chem{CH3-CH2-CH2-NH2}" in out
    assert "بروبيل أمين" in out


def test_chain_with_dashes_from_book():
    # «CH3-NH-CH3 : ثنائي ميثيل أمين»
    out = to_chem("CH3-NH-CH3 : ثنائي ميثيل أمين")
    assert r"\chem{CH3-NH-CH3}" in out


def test_secondary_amine_from_book():
    out = to_chem("CH3 CH2 CH2 - NH - CH2 CH3 : إيثيل بروبيل أمين")
    assert r"\chem" in out
    assert "إيثيل بروبيل أمين" in out


def test_generic_amine_symbols():
    assert r"\chem" in to_chem("الأمين الأولي يُكتب R-NH2 والثانوي R-NH-R")


# ══════════ ما يجب ألّا يُمسّ — وهو الأهم ══════════

def test_derivation_equation_untouched():
    # «CH4 - H = CH3» اشتقاقٌ لا صيغة بنائية.
    line = "أمثلة : ميثان - ذرة هيدروجين = ميثيل . CH4 - H = CH3."
    assert to_chem(line) == line


def test_general_formula_untouched():
    # «C n H 2n+2» قانون عام، حروفه ليست مجموعات.
    line = "القانون العام للألكانات : C n H 2n+2."
    assert to_chem(line) == line


def test_reaction_arrow_untouched():
    line = "R-NH2 + HCl -> R-NH3Cl"
    assert to_chem(line) == line


def test_single_carbon_formula_untouched():
    # «جزيء الميثان CH4» صيغة جزيئية لا بنائية.
    line = "جزيء الميثان CH4 فيه أربع روابط أحادية."
    assert to_chem(line) == line


def test_plain_arabic_untouched():
    line = "الأمينات مركبات تحتوي على مجموعة الأمين المرتبطة بذرات الكربون."
    assert to_chem(line) == line


def test_idempotent():
    once = to_chem("CH3-NH-CH3 : ثنائي ميثيل أمين")
    assert to_chem(once) == once


def test_empty_and_none_safe():
    assert to_chem("") == ""
    assert to_chem("   ") == "   "


# ══════════ الحلقات من وصف الكتاب ══════════

def test_ring_triangle():
    # «مثلث يمثل بروبان حلقي (سيكلوبروبان)»
    assert ring_code("رسم لمثلث يمثل بروبان حلقي") == r"\ring{3}"


def test_ring_square():
    assert ring_code("مربع يمثل بيوتان حلقي") == r"\ring{4}"


def test_ring_benzene():
    code = ring_code("حلقة بنزين مرتبطة بمجموعة NH2")
    assert code is not None and "ar" in code and "+NH2" in code


def test_ring_pyridine():
    # «شكل سداسي غير مشبع (به روابط ثنائية) ... ذرة نيتروجين N»
    code = ring_code("شكل سداسي غير مشبع به روابط ثنائية وذرة نيتروجين N")
    assert code is not None
    assert code.startswith(r"\ring{6") and "ar" in code and "N" in code


def test_ring_piperidine_has_nh():
    code = ring_code("شكل سداسي مشبع يحتوي على ذرة نيتروجين N مرتبطة بهيدروجين H")
    assert code is not None and "NH" in code


def test_ring_none_when_no_shape():
    assert ring_code("الأمينات مركبات نيتروجينية") is None
    assert ring_code("") is None


def test_ring_hydrogen_is_not_a_substituent():
    """«نيتروجين N مرتبطة بهيدروجين H» ⇒ حلقة NH بلا مجموعة معلّقة."""
    code = ring_code("شكل سداسي مشبع يحتوي على ذرة نيتروجين N مرتبطة بهيدروجين H")
    assert code == r"\ring{6|NH}"


def test_ring_codes_finds_every_shape_in_one_description():
    """وصفٌ واحد يجمع ثلاثة رسوم ⇒ ثلاثة ترميزات لا واحداً."""
    from core.chem import ring_codes
    codes = ring_codes(
        "رسم لثلاثة أشكال : مثلث يمثل سيكلوبروبان ، مربع يمثل سيكلوبيوتان ،"
        " وشكل سداسي يمثل سيكلوهيكسان")
    assert codes == [r"\ring{3}", r"\ring{4}", r"\ring{6}"]


def test_ring_substituent_not_swallowed():
    """🔴 «مرتبطة بمجموعة NH2» كانت تُنتج «+H2» — الكلمات المتخطّاة عربية حصراً."""
    from core.chem import ring_codes
    assert ring_codes("حلقة بنزين مرتبطة بمجموعة NH2") == [r"\ring{6|ar|+NH2}"]


def test_ring_needs_drawing_context_not_just_a_shape_word():
    """🔒 اسم الشكل وحده لا يكفي — وإلا صار كلُّ ذكرٍ للبنزين رسماً."""
    assert ring_code("البنزين هو الأساس في المركبات الأروماتية وصيغته C6H6") is None
    assert ring_code("رسمة البنزين : شكل سداسي بداخله دائرة") == r"\ring{6|ar}"


def test_ring_found_in_plain_content_line():
    """الشكل قد يرد في نصٍّ عادي لا تحت مفتاح «الوصف» — منقول من كيمياء.json."""
    from core.chem import ring_codes
    assert ring_codes("1) رسمة المثلث : تمثل بروبان حلقي (سيكلوبروبان) وصيغته C3H6.") \
        == [r"\ring{3}"]
    assert ring_codes("2) رسمة المربع : تمثل سيكلوبيوتان.") == [r"\ring{4}"]


def test_to_ring_replaces_in_place_not_appends():
    """🔴 الدرس المستفاد من الكسور: الاستبدال ينجح والإضافة تفشل.

    حين بقي الوصف النثري بجوار الترميز اختار الموديل النثر وأعاد صياغته
    («يتم تمثيله برسم مثلث») — فلم ير الطالبُ رسماً.
    """
    from core.chem import to_ring
    out = to_ring("1) رسمة المثلث : تمثل بروبان حلقي (سيكلوبروبان).")
    assert r"\ring{3}" in out
    assert "المثلث" not in out          # لم يبقَ تمثيلٌ نثريّ ينافس الترميز
    assert "بروبان حلقي" in out         # وبقي باقي النصّ سليماً


def test_to_ring_leaves_non_drawing_lines_alone():
    from core.chem import to_ring
    line = "البنزين : هو الأساس في المركبات الأروماتية وصيغته C6H6."
    assert to_ring(line) == line


def test_to_ring_is_idempotent():
    from core.chem import to_ring
    once = to_ring("رسمة المربع : تمثل سيكلوبيوتان.")
    assert to_ring(once) == once


def test_to_ring_absorbs_the_drawing_noun():
    """🔴 **هذا ما حسم امتثال الموديل.**

    «رسمة \\ring{3} : ...» ⇒ يقرأ الموديل «رسمة» على أنها وصفٌ مطلوبٌ منه
    فيترجم الترميز إلى «يتم تمثيله برسم مثلث» — صفر من ست محاولات متتالية.
    وحين صار السطر يبدأ بالترميز وحده صار النقل الحرفيّ نقلاً للرسم (٦/٦).
    """
    from core.chem import to_ring
    assert to_ring("1) رسمة المثلث : تمثل بروبان حلقي.") \
        == r"1) \ring{3} : تمثل بروبان حلقي."
    assert to_ring("2) رسمة المربع : تمثل سيكلوبيوتان.") \
        == r"2) \ring{4} : تمثل سيكلوبيوتان."
    assert to_ring("3) رسمة الشكل السداسي : تمثل سيكلوهيكسان.") \
        == r"3) \ring{6} : تمثل سيكلوهيكسان."


def test_to_ring_keeps_the_book_explanation_after_the_colon():
    """🔒 نحذف **اسم الرسم** لا **محتوى الكتاب**: ما بعد «:» يبقى حرفياً."""
    from core.chem import to_ring
    out = to_ring("رسمة البنزين : شكل سداسي بداخله دائرة أو ثلاث روابط ثنائية.")
    assert out.startswith(r"\ring{6|ar} : ")
    assert "شكل سداسي بداخله دائرة أو ثلاث روابط ثنائية." in out


def test_to_ring_does_not_eat_unrelated_arabic():
    from core.chem import to_ring
    line = "المركبات الحلقية غير المتجانسة : حلقات تحتوي على ذرة غير الكربون."
    assert to_ring(line) == line


# ══════════ الاسم ⇐ الصيغة (أمثلة الكتاب الاثنا عشر) ══════════

def test_amide_names_build_correct_structures():
    """كل أميدٍ مفتوح في الكتاب، بصيغته الصحيحة كيميائياً."""
    from core.chem import chem_from_name as f
    assert f("N-بروبيل بيوتاناميد.") == r"\chem{CH3-CH2-CH2-C(=O)-NH-CH2-CH2-CH3}"
    assert f("N-ميثيل N-بنتيل بيوتاناميد.") == \
        r"\chem{CH3-CH2-CH2-C(=O)-N(CH3)-CH2-CH2-CH2-CH2-CH3}"
    assert f("N, N - ثنائي إيثيل إيثاناميد.") == \
        r"\chem{CH3-C(=O)-N(CH2-CH3)-CH2-CH3}"
    assert f("هيبتاناميد.") == r"\chem{CH3-CH2-CH2-CH2-CH2-CH2-C(=O)-NH2}"
    assert f("بيوتاناميد") == r"\chem{CH3-CH2-CH2-C(=O)-NH2}"


def test_carbon_count_matches_the_name():
    """عدّ الكربون يطابق الاسم — الجذع (n-1) كربوناً زائد الكربونيل."""
    from core.chem import chem_from_name as f
    for name, n in [("إيثاناميد", 2), ("بروباناميد", 3),
                    ("بيوتاناميد", 4), ("هيبتاناميد", 7)]:
        code = f(name)
        assert code is not None, name
        acyl = code.split("-C(=O)")[0]
        assert acyl.count("CH") == n - 1, (name, code)


def test_aromatic_names_are_refused_on_purpose():
    """🔒 الرسّام لا يصل حلقةً بسلسلة — ورسمٌ ناقص أسوأ من وصفٍ صادق."""
    from core.chem import chem_from_name as f
    assert f("بنزاميد (الاسم الشائع) أو فينيل ميثاناميد (IUPAC).") is None
    assert f("N-فينيل إيثاناميد (أسيتانيليد).") is None
    assert f("نيكوتيناميد.") is None


def test_non_amide_names_are_refused():
    from core.chem import chem_from_name as f
    assert f("ثنائي ميثيل أمين ( شائع )") is None
    assert f("هيبتانول") is None
    assert f("") is None
    assert f(None) is None


def test_unknown_substituent_is_never_guessed():
    from core.chem import chem_from_name as f
    assert f("N-وهمي بيوتاناميد") is None


def test_shape_alternation_is_longest_first():
    """🔴 «حلقة سداسية» كانت تُقطع فتترك «ة» معلّقة — نصٌّ مشوّه للطالب."""
    from core.chem import to_ring
    out = to_ring("حلقة سداسية تحتوي على ذرة نيتروجين N ومرتبطة بمجموعة CONH2.")
    assert "}ة" not in out
    assert out.startswith(r"\ring{6|N|+CONH2}")


def test_example_pair_is_rendered_as_drawing_then_name():
    """المثال يصل الموديل رسماً ثم اسماً — لا وصفاً نثرياً."""
    from core.serializer import serialize_lesson
    lesson = {"الأجزاء": [{"المحتوى": [{
        "الرسم": "سلسلة من 4 كربونات (بيوتان) مرتبطة بـ NH ثم سلسلة من 3 كربونات.",
        "التسمية": "N-بروبيل بيوتاناميد."}]}]}
    out = serialize_lesson(lesson, "الكيمياء النيتروجينية", subject="كيمياء")
    assert r"الرسم: \chem{CH3-CH2-CH2-C(=O)-NH-CH2-CH2-CH3}" in out
    assert "التسمية: N-بروبيل بيوتاناميد." in out
    assert "سلسلة من 4 كربونات" not in out     # الوصف الناقص لم يبقَ منافساً


def test_example_pair_untouched_for_other_subjects():
    """🔒 النطاق: مادةٌ غير الكيمياء لا يُمسّ مثالها.

    ⚠️ والمادّةُ هنا **أحياء** لا فيزياء: الفيزياء صارت تُعرّب أرقامها
       في المُسلسِل نفسِه (2026-09-12) فيصير «٤ كربونات» — وهو تغييرُ
       شكلٍ مقصود لا مساسٌ بالرسم، لكنه يُشوّش مقصدَ هذا الاختبار.
    """
    from core.serializer import serialize_lesson
    lesson = {"الأجزاء": [{"المحتوى": [{
        "الرسم": "سلسلة من 4 كربونات مرتبطة بـ NH.",
        "التسمية": "N-بروبيل بيوتاناميد."}]}]}
    out = serialize_lesson(lesson, "وحدة", subject="احياء")
    assert "سلسلة من 4 كربونات مرتبطة بـ NH." in out
    assert "\\chem" not in out


def test_example_pair_kept_when_name_cannot_be_parsed():
    """الاسم المجهول ⇒ يبقى وصف الكتاب كما هو، بلا تخمين."""
    from core.serializer import serialize_lesson
    lesson = {"الأجزاء": [{"المحتوى": [{
        "الرسم": "حلقة بنزين مرتبطة بمجموعة كربونيل ثم NH2.",
        "التسمية": "بنزاميد (الاسم الشائع)."}]}]}
    out = serialize_lesson(lesson, "وحدة", subject="كيمياء")
    assert "مرتبطة بمجموعة كربونيل ثم NH2." in out
