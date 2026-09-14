"""🔒 حارس النطاق والمصدر لميزة رسم الكيمياء العضوية.

هذا الملف لا يختبر «هل يرسم؟» — ذاك في `test_chem.py`. يختبر أمرين يخشاهما
المالك أكثر من غياب الرسم نفسه:

  1️⃣ **ألّا تتسرّب الميزة لمادة أخرى.** الكيمياء وحدها، وما عداها يمرّ نصُّها
     وبرومبتها كما كانا حرفياً.
  2️⃣ **ألّا تُضعِف قاعدةَ «المصدر هو الكتاب وحده».** الترميز طريقةُ كتابة،
     ولا يجوز أن يصير باباً لرسم مركّبٍ من معرفة الموديل.
"""
import pytest

from core.chem import (
    ORGANIC_SUBJECTS, REACTION_SUBJECTS, is_organic_subject, for_subject,
    to_chem, to_ring,
)
from core.curriculum import SUBJECTS_BY_GRADE_TRACK
from subjects.common import (
    organic_structure_rules,
    reaction_equation_rules,
    system_prompt_strict_explain,
    system_prompt_strict_summary,
    system_prompt_strict_qa_improved,
    strip_stray_latex,
)

ALL_SUBJECTS = sorted({s for lst in SUBJECTS_BY_GRADE_TRACK.values() for s in lst})
OTHER_SUBJECTS = [s for s in ALL_SUBJECTS if s not in ORGANIC_SUBJECTS]


# ══════════════ 1️⃣ النطاق: الكيمياء وحدها ══════════════

def test_scope_is_chemistry_only():
    assert ORGANIC_SUBJECTS == frozenset({"كيمياء"})
    assert is_organic_subject("كيمياء")
    assert is_organic_subject("  كيمياء  ")


@pytest.mark.parametrize("subject", OTHER_SUBJECTS)
def test_no_rule_leaks_into_other_subjects(subject):
    """برومبتات بقية المواد خالية من أي ذكرٍ للترميز."""
    assert organic_structure_rules(subject) == ""
    for prompt in (system_prompt_strict_explain(subject),
                   system_prompt_strict_qa_improved(subject),
                   system_prompt_strict_summary(subject, 3)):
        assert "\\chem" not in prompt
        assert "\\ring" not in prompt
        assert "الصيغ البنائية" not in prompt


@pytest.mark.parametrize("subject", OTHER_SUBJECTS)
def test_no_text_conversion_for_other_subjects(subject):
    """نصٌّ يحوي صيغةً وشكلاً معاً يمرّ **حرفياً** لغير الكيمياء."""
    text = ("CH3-NH-CH3 : ثنائي ميثيل أمين\n"
            "رسمة المثلث : تمثل بروبان حلقي\n"
            "CH3 CH2 CH2 NH2 : بروبيل أمين")
    assert for_subject(text, subject) == text


def test_conversion_happens_for_chemistry():
    text = "CH3-NH-CH3 : ثنائي ميثيل أمين\nرسمة المثلث : تمثل بروبان حلقي"
    out = for_subject(text, "كيمياء")
    assert r"\chem{CH3-NH-CH3}" in out
    assert r"\ring{3}" in out


@pytest.mark.parametrize("subject", [None, "", "   ", "مادة وهمية"])
def test_unknown_subject_is_never_converted(subject):
    """المادة المجهولة تُعامل معاملة غير الكيميائية — قائمة بيضاء لا سوداء."""
    text = "CH3-NH-CH3 : ثنائي ميثيل أمين"
    assert for_subject(text, subject) == text


# ══════════════ 2️⃣ المصدر: الكتاب وحده ══════════════

def test_rule_states_it_is_about_form_not_source():
    rule = organic_structure_rules("كيمياء")
    assert "شكلِ الكتابة" in rule
    assert "مصدرِ المعلومة" in rule


def test_rule_forbids_drawing_compounds_absent_from_the_lesson():
    """🔴 الصياغة الأولى قالت «كلّما ذكرتَ مركّباً عضوياً أرفِق ترميزه» —
    وهي دعوةٌ مفتوحة للرسم من معرفة الموديل. يجب ألّا تعود."""
    rule = organic_structure_rules("كيمياء")
    assert "لا ترسم مركّباً لم يرد في الدرس" in rule
    assert "لا تخترعها" in rule
    assert "كلّما ذكرتَ مركّباً عضوياً" not in rule


def test_rule_overrides_wording_only_never_the_source():
    """«تسبق قاعدة انقل حرفياً» مقيَّدة بالشكل صراحةً."""
    rule = organic_structure_rules("كيمياء")
    assert "في الشكل وحده" in rule
    assert "والمحتوى كما في الكتاب حرفياً" in rule


def test_chemistry_explain_prompt_keeps_its_source_clauses():
    """قاعدةُ المصدر باقيةٌ في وضع الشرح — **وبصياغةٍ أقوى** (2026-09-14).

    ⚖️ كانت ثلاثةَ أسطرٍ مكتوبةً بيدها هنا: «مصدر الإجابة الوحيد هو الكتاب
       المعطى لك فقط · لا تضف معرفة عامة…». وصارت [common.source_rules] —
       نفسُ النصّ الذي يقرؤه وضعُ السؤال ووضعُ التلخيص — وفيه ما كان ناقصاً:
       **«التعاريف والمصطلحات والأرقام كما وردت في الكتاب»** (فالطالب يُمتحن
       بمصطلح كتابه لا بمصطلحٍ أدقّ يختاره الموديل)، و**استثناءُ المتابعة**
       الذي كان غيابُه يردّ «بسّطها لي» بـ«ليست في الكتاب».
       فنفحص القاعدة بمعناها لا بحروف صياغتها القديمة.
    """
    prompt = system_prompt_strict_explain("كيمياء")
    assert "كلُّ **محتوى** تقوله يجب أن يكون موجوداً في «نص الكتاب» المرفق" in prompt
    assert "لا تُضِف من معرفتك العامة محتوىً جديداً" in prompt
    assert "كما وردت في الكتاب" in prompt


def test_chemistry_summary_and_qa_keep_their_source_clauses():
    """⚖️ الصياغةُ تغيّرت (2026-09-14) والقاعدةُ اشتدّت.

    كان برومبت السؤال يقول «لا تضف معلومات إضافية لم يطلبها» — وهي قاعدةُ
    **طولٍ** لا قاعدةُ **مصدر**: لم يكن فيه حرفٌ واحد يأمر بالإجابة من نصّ
    الكتاب. فصار على [common.qa_core]، ونفحص القاعدتين معاً.
    """
    assert "التزم بالنص المقدم فقط" in system_prompt_strict_summary("كيمياء", 3)
    assert "لا تضف معلومات خارج النص" in system_prompt_strict_summary("كيمياء", 3)

    qa = system_prompt_strict_qa_improved("كيمياء")
    assert "لا تُضِف من معرفتك العامة محتوىً جديداً" in qa, "قاعدةُ المصدر سقطت"
    assert "ولا تسرد الدرس كلَّه" in qa, "قاعدةُ الطول سقطت"


def test_source_clauses_identical_between_chemistry_and_physics():
    """القاعدة أُضيفت **ذيلاً** ولم تُعدّل حرفاً في المتن المشترك."""
    chem = system_prompt_strict_explain("كيمياء")
    phys = system_prompt_strict_explain("فيزياء")
    # ⚠️ والذيولُ **ثلاثة** منذ 2026-09-12: الترميزُ البنائي، ثم معادلةُ
    #    التفاعل، ثم شكلُ الأرقام — يُطرح كلٌّ من مادّته بترتيب إلحاقه.
    #
    # ⚖️ وذيلُ الأرقام **معكوسُ النطاق**: فارغٌ في الكيمياء (أرقامها
    #    لاتينية بنصّ المالك) وموجودٌ في الفيزياء — فيُطرح من الفيزياء.
    from subjects.common import arabic_digits_rules, subject_lens
    assert arabic_digits_rules("كيمياء") == ""
    tails = len(organic_structure_rules("كيمياء")) + \
        len(reaction_equation_rules("كيمياء"))
    body = chem[: len(chem) - tails]
    phys_tail = len(arabic_digits_rules("فيزياء"))
    # ⚠️ وتُطرح عدسةُ الفيزياء **قبل** استبدال اسم المادة، وإلا صار نصُّها
    #    يحمل كلمة «كيمياء» فلا يطابق `subject_lens("فيزياء")` ولا يُطرح.
    body_phys = phys[: len(phys) - phys_tail].replace(subject_lens("فيزياء"), "")
    body_phys = body_phys.replace("فيزياء", "كيمياء")

    # 🔬 **وعدسةُ المادة تُطرح أيضاً منذ 2026-09-14**: صار لكل مادةٍ فقرةٌ
    #    تصف ترتيبَ التفكير فيها — الكيمياءُ من البنية إلى السلوك، والفيزياءُ
    #    من الظاهرة إلى القانون — وهو **اختلافٌ مقصود** طلبه المالك صراحةً
    #    («لكل مادة اللوجك اللي فيها يختلف»). فما يجب أن يبقى متطابقاً هو
    #    **العمودُ الفقري**: المصدرُ والمتابعةُ والمحادثةُ والاتّصالُ والشكل.
    body = body.replace(subject_lens("كيمياء"), "")
    assert body == body_phys
    assert subject_lens("كيمياء") != subject_lens("فيزياء")


# ══════════════ 3️⃣ منظّف اللاتيك لا يأكل ترميزاً ولا عربية ══════════════

def test_cleaner_keeps_the_three_render_codes():
    src = r"\chem{CH3-CH3} \quad \ring{6|ar} و \frac{1}{2} و \[ x \]"
    out = strip_stray_latex(src)
    assert r"\chem{CH3-CH3}" in out
    assert r"\ring{6|ar}" in out
    assert r"\frac{1}{2}" in out
    assert r"\quad" not in out
    assert r"\[" not in out


def test_cleaner_leaves_plain_arabic_untouched():
    line = "الأمينات مركبات تحتوي على مجموعة الأمين المرتبطة بذرات الكربون."
    assert strip_stray_latex(line) == line


def test_cleaner_is_safe_on_empty():
    assert strip_stray_latex("") == ""
    assert strip_stray_latex(None) is None


# ══════════════ 4️⃣ لا أثر جانبي على نصوص المواد الأخرى ══════════════

def test_arabic_literature_text_is_never_mistaken_for_a_formula():
    """نصّ العربي فيه رموز لاتينية أحياناً — ولا يجوز أن يُحوَّل."""
    line = "قال الشاعر: العلم نور — انظر الصفحة A ثم B."
    assert for_subject(line, "عربي") == line
    # وحتى لو مُرّر للكيمياء: ليست صيغةً بنائية أصلاً.
    assert to_chem(line) == line


def test_physics_units_are_not_structures():
    line = "السرعة تُقاس بـ م/ث والقوة بالنيوتن N."
    assert for_subject(line, "فيزياء") == line
    assert to_chem(line) == line


def test_biology_ring_words_are_untouched_now():
    """الأحياء خرجت من النطاق عمداً — «حلقة كريبس» ليست رسماً كيميائياً."""
    line = "حلقة كريبس : سلسلة تفاعلات داخل الميتوكندريا."
    assert for_subject(line, "احياء") == line


def test_to_ring_alone_still_pure_for_direct_use():
    """الدوال الخام تبقى قابلة للاستدعاء المباشر في الاختبارات."""
    assert r"\ring{3}" in to_ring("رسمة المثلث : سيكلوبروبان")


# ══════════════ 4️⃣ معادلة التفاعل: الكيمياء والأحياء ══════════════
# 🔴 علّةُ المالك (2026-09-12): «ادخل على الكيمياء في المعادلات… ما طاع
#    يضبط». والموديل كان يكتب العنوان والمعادلة في سطرٍ واحد فيخلطهما
#    الاتجاهُ الثنائي، ويكتب السهم بشرطةٍ واحدة.

REACTION_OTHERS = [s for s in ALL_SUBJECTS if s not in REACTION_SUBJECTS]


def test_reaction_scope_matches_the_renderer():
    """🔒 نطاقُ التعليمة يطابق `chemSubjects` في التطبيق حرفياً."""
    assert REACTION_SUBJECTS == frozenset({"كيمياء", "احياء"})


@pytest.mark.parametrize("subject", sorted(REACTION_SUBJECTS))
def test_reaction_rule_reaches_all_three_prompts(subject):
    rule = reaction_equation_rules(subject)
    assert "-->" in rule and "<=>" in rule
    # ⭐ «سطرٌ مستقلّ» هو جوهرُ الإصلاح: خلطُ العنوان بالمعادلة هو العطل.
    assert "سطرٍ وحدَها" in rule
    for prompt in (system_prompt_strict_explain(subject),
                   system_prompt_strict_qa_improved(subject),
                   system_prompt_strict_summary(subject, 3)):
        assert "معادلة التفاعل" in prompt


@pytest.mark.parametrize("subject", REACTION_OTHERS)
def test_reaction_rule_does_not_leak(subject):
    """⚠️ الفيزياء فيها معادلاتٌ نووية — والرسّام لا يرسمها، فلا تُؤمر بها."""
    assert reaction_equation_rules(subject) == ""
    for prompt in (system_prompt_strict_explain(subject),
                   system_prompt_strict_qa_improved(subject),
                   system_prompt_strict_summary(subject, 3)):
        assert "معادلة التفاعل" not in prompt
