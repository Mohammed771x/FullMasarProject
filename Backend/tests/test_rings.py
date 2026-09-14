# -*- coding: utf-8 -*-
"""⚗️ المركبات الحلقية — لكلِّ مركّبٍ رسمُه هو، لا رسمٌ عامّ لكلِّها.

🔴 **ما رآه المالك (2026-09-13):**
   «الهكسان الحلقي والهكسين الحلقي — يقول لي بدون رابطة ثنائية وبها رابطة
    ثنائية، **وطيب نفس الرسمة**؟ وهل البروبان والبيوتان نفس الرسمات؟»

   وكان محقّاً، والعطل أوسع ممّا رأى — يحرس هذا الملفّ كلَّ وجهٍ منه:

   ① الرابطة الثنائية **لم تكن في الترميز أصلاً**: كلُّ حلقةٍ غير عطرية
     مضلّعٌ أصمّ، فالهكسان والهكسين والبروبين سواء.
   ② **النفيُ يُقرأ إثباتاً**: «بدون روابط ثنائية» فيها كلمة «ثنائية»،
     وكان مجرّدُ وجودها يجعلها عطرية ⇒ الهكسان الحلقي يخرج **بنزيناً**.
   ③ «ثلاثي» شكلٌ ⇒ **ثلاثي نيتروتولوين** (TNT) يُرسم مثلثاً.
   ④ «بنزين» شكلٌ بلا قيد ⇒ **مضخة البنزين** في محطة الوقود حلقةٌ عطرية.
   ⑤ «مربع يمثل عنصر الكالسيوم» (خلية الجدول الدوري) حلقةٌ رباعية،
     و«طبقات سداسية» في الجرافيت حلقةٌ سداسية.
   ⑥ النفثالين (حلقتان ملتحمتان) والأنثراسين (ثلاث) حلقةٌ واحدة.
   ⑦ **الموقع مهمَل** ⇒ أورثو وميتا وبارا رسمةٌ واحدة، في درسٍ موضوعُه
     المواقع — فالشكلُ يكذّب الاسمَ المكتوب تحته.
"""
import json
import re
from pathlib import Path

import pytest

from core.chem import RING_COMPOUNDS, ring_code, ring_codes, to_ring


def codes_in(text: str) -> list[str]:
    return re.findall(r"\\ring\{[^}]*\}", to_ring(text))


# ══════════════════ ① العطل الأصلي: ثلاثة مركبات ثلاثُ رسمات ══════════════════

def test_the_owners_bug_three_compounds_three_drawings():
    """نصُّ الكتاب حرفياً — هكسان حلقي · هكسين حلقي · بنزين."""
    book = (
        "[رسم: ثلاث أشكال هندسية سداسية لمركبات حلقية.\n"
        "الوصف: الشكل الأول من اليمين حلقة سداسية بدون روابط ثنائية، "
        "الثاني حلقة سداسية بها رابطة ثنائية واحدة، "
        "الثالث حلقة سداسية بها ثلاث روابط ثنائية متبادلة.\n"
        "البيانات المكتوبة على الرسم: من اليمين إلى اليسار: "
        "هكسان حلقي، هكسين حلقي، بنزين.]"
    )
    out = to_ring(book)
    assert r"\ring{6}" in out        # هكسان حلقي: مضلّع أصمّ
    assert r"\ring{6|=1}" in out     # هكسين حلقي: رابطة ثنائية واحدة
    assert r"\ring{6|ar}" in out     # بنزين: عطري

    # ⭐ **والثلاثة مختلفة** — وهذا نصُّ الشكوى حرفياً.
    assert len(set(codes_in(book))) >= 3


def test_saturated_ring_is_never_aromatic():
    """🔴 «بدون روابط ثنائية» كانت تُقرأ عطريةً لأن فيها كلمة «ثنائية»."""
    assert ring_code("حلقة سداسية بدون روابط ثنائية") == r"\ring{6}"
    assert ring_code("حلقة خماسية لا تحتوي على روابط ثنائية") == r"\ring{5}"


def test_one_double_bond_is_not_aromatic():
    assert ring_code("حلقة سداسية بها رابطة ثنائية واحدة") == r"\ring{6|=1}"
    assert "ar" not in (ring_code("حلقة خماسية بها رابطة ثنائية") or "")


def test_alternating_bonds_are_aromatic():
    assert ring_code("حلقة سداسية بها ثلاث روابط ثنائية متبادلة") == r"\ring{6|ar}"
    assert ring_code("حلقة سداسية بداخلها دائرة") == r"\ring{6|ar}"


# ══════════════════ ② جدول الأسماء — المصدرُ اليقينيّ ══════════════════

@pytest.mark.parametrize("name, code", [
    ("بروبان حلقي", "3"), ("سيكلوبروبان", "3"),
    ("بيوتان حلقي", "4"), ("سيكلوبيوتان", "4"),
    ("بنتان حلقي", "5"),
    ("هكسان حلقي", "6"), ("سيكلوهيكسان", "6"),
    ("بروبين حلقي", "3|=1"), ("بيوتين حلقي", "4|=1"),
    ("هكسين حلقي", "6|=1"), ("سيكلوهيكسين", "6|=1"),
    ("بنزين", "6|ar"),
    ("تولوين", "6|ar|+CH3"), ("فينول", "6|ar|+OH"), ("أنيلين", "6|ar|+NH2"),
    ("بنزالدهيد", "6|ar|+CHO"), ("أسيتوفينون", "6|ar|+COCH3"),
    ("نفثالين", "6|ar|fuse2"), ("أنثراسين", "6|ar|fuse3"),
    ("بيريدين", "6|ar|N"), ("بيبريدين", "6|NH"),
])
def test_every_curriculum_compound_has_its_own_code(name, code):
    assert RING_COMPOUNDS[name] == code


def test_each_ring_size_is_distinct():
    """البروبان والبيوتان والبنتان والهكسان: أربعةُ أشكالٍ لا شكلٌ واحد."""
    sizes = {RING_COMPOUNDS[n] for n in
             ("بروبان حلقي", "بيوتان حلقي", "بنتان حلقي", "هكسان حلقي")}
    assert sizes == {"3", "4", "5", "6"}


def test_name_wins_over_shape_description():
    """«رسمة المثلث : تمثل بروبان حلقي» ⇒ الاسم يحكم والوصف يُستبدل."""
    out = to_ring("1) رسمة المثلث : تمثل بروبان حلقي (سيكلوبروبان).")
    assert r"\ring{3}" in out
    assert "المثلث" not in out


def test_name_keeps_its_place_and_gains_a_drawing():
    """الاسمُ عنوانُ الرسم لا منافسُه — فيبقى ويُلحق به الترميز."""
    out = to_ring("البيانات المكتوبة على الرسم: هكسين حلقي، بنزين.")
    assert "هكسين حلقي" in out and r"\ring{6|=1}" in out


# ══════════════════ ③ ما **لا** يُرسم — الحرّاس ══════════════════

def test_petrol_station_is_not_a_benzene_ring():
    """🔴 «مضخة البنزين» وقودُ سيارات — وكان يُرسم حلقةً عطرية.

    والكتاب نفسه يفرّق: «البنزين العطري يختلف تماماً عن البنزين الناتج من
    تقطير البترول». فلا تُقرأ الكلمةُ مركّباً إلا في جوارٍ كيميائيّ.
    """
    block = ("[رسم: صورة فوتوغرافية لمحطة تعبئة وقود السيارات.\n"
             "الوصف: رجل يقوم بتعبئة سيارة بالوقود من مضخة البنزين.\n"
             "البيانات المكتوبة على الرسم: شكل (3) محطة وقود.]")
    assert codes_in(block) == []


def test_periodic_table_cell_is_not_a_ring():
    """«مربع يمثل عنصر الكالسيوم» خليةُ جدولٍ دوريّ لا حلقةً رباعية."""
    block = ("[رسم: مربع يمثل عنصر الكالسيوم\n"
             "الوصف: خلية من الجدول الدوري توضح بيانات عنصر الكالسيوم.]")
    assert codes_in(block) == []


def test_graphite_layers_are_not_a_ring():
    block = ("[رسم: شكل بلوري للماس والجرافيت\n"
             "الوصف: رسمان تخطيطيان يوضحان الترابط الذري؛ الأول شبكي قوي، "
             "والثاني مسطح على شكل طبقات سداسية يمثل التركيب البلوري للجرافيت.]")
    assert codes_in(block) == []


def test_heat_symbol_triangle_is_not_a_ring():
    """«علامة التسخين (مثلث Δ)» رمزُ حرارة لا حلقةً ثلاثية."""
    line = "وعلى السهم علامة التسخين (مثلث Δ) في رسم المعادلة."
    assert r"\ring{3}" not in to_ring(line)


def test_multiplier_prefixes_are_not_shapes():
    """«ثلاثي نيتروتولوين» و«سداسي كلورو» أعدادُ مجموعاتٍ لا أشكال."""
    out = to_ring("رسم: ثلاثي نيتروتولوين (TNT) على حلقة بنزين")
    assert r"\ring{3}" not in out
    assert r"\ring{6" in out


def test_three_dimensional_is_not_a_triangle():
    assert r"\ring{3}" not in to_ring("رسم لشكل ثلاثي الأبعاد لحلقة.")


def test_other_subjects_are_untouched():
    """🔒 الترميز للكيمياء وحدها — نصُّ بقية المواد يمرّ حرفياً."""
    from core.chem import for_subject
    line = "رسم لحلقة سداسية في خلية نباتية."
    assert for_subject(line, "احياء") == line
    assert for_subject(line, "فيزياء") == line
    assert for_subject(line, "كيمياء") != line


# ══════════════════ ④ المواقع — أورثو · ميتا · بارا ══════════════════

def test_ortho_meta_para_are_three_different_drawings():
    """📍 درسٌ موضوعُه المواقع: رسمةٌ واحدة للثلاثة تكذّب الاسم المكتوب تحتها."""
    ortho = to_ring("في حلقة: يسمى أورثو - ثنائي برومو بنزين")
    meta = to_ring("في حلقة: يسمى ميتا - ثنائي برومو بنزين")
    para = to_ring("في حلقة: يسمى بارا - ثنائي برومو بنزين")
    assert r"+Br@1|+Br@2" in ortho
    assert r"+Br@1|+Br@3" in meta
    assert r"+Br@1|+Br@4" in para
    assert len({codes_in(t)[0] for t in (ortho, meta, para)}) == 3


def test_iupac_name_carries_its_positions():
    """«2 - كلورو - 5 - نيترو أنيلين» — الاسمُ نفسه يقول أين كلُّ مجموعة."""
    out = to_ring("في حلقة: يسمى 2 - كلورو - 5 - نيترو أنيلين.")
    assert r"\ring{6|ar|+NH2@1|+Cl@2|+NO2@5}" in out


def test_numbered_positions_from_the_drawing_text():
    out = to_ring("[رسم: حلقة بنزين متصلة بذرتي بروم في الموقعين 1 و 2.]")
    assert "+Br@1" in out and "+Br@2" in out


def test_positions_spread_across_commas_stay_on_one_ring():
    """🔴 «به NH2 في 1، و Cl في 2، و NO2 في 5» مركّبٌ واحد لا ثلاثة."""
    block = ("[رسم: شكلان لحلقتي بنزين.\n"
             "الوصف: الأيمن به NH2 في 1، و Cl في 2، و NO2 في 5.]")
    out = to_ring(block)
    assert r"\ring{6|ar|+NH2@1|+Cl@2|+NO2@5}" in out


def test_different_groups_are_not_multiplied():
    """🔴 «ميتا ميثيل أنيلين» مجموعتان مختلفتان — لا أمينان في موقعين."""
    out = to_ring("في حلقة: 3-ميثيل أنيلين ( ميتاميثيل أنيلين ).")
    assert "+NH2@1" in out and "+CH3@3" in out
    assert "+NH2@3" not in out


# ══════════════════ ⑤ الحلقات الملتحمة ══════════════════

def test_fused_rings_are_not_a_single_ring():
    """النفثالين حلقتان والأنثراسين ثلاث — ورسمُهما واحداً يُضيّع الدرس."""
    out = to_ring("[رسم: البيانات المكتوبة على الرسم: بنزين، نفثالين، أنثراسين.]")
    assert r"\ring{6|ar}" in out
    assert r"\ring{6|ar|fuse2}" in out
    assert r"\ring{6|ar|fuse3}" in out


def test_fused_from_description_without_name():
    assert ring_code("حلقتان سداسيتان متلاصقتان") == r"\ring{6|fuse2}"


def test_shape_suffix_is_swallowed_not_left_dangling():
    """🔴 «حلقتان سداسيتان» كانت تُقطع فتترك «تان» بعد الترميز."""
    out = to_ring("رسم: حلقتان سداسيتان متلاصقتان وبداخلهما دوائر.")
    assert "}تان" not in out
    assert "}ة" not in out


# ══════════════════ ⑥ مسحٌ شامل على المنهج كلِّه ══════════════════

_CHEM_DIR = Path(__file__).resolve().parent.parent / "data" / "subjects" / "كيمياء"


def _all_chemistry_strings():
    for path in sorted(_CHEM_DIR.rglob("*.json")):
        data = json.loads(path.read_text(encoding="utf-8"))
        stack = [data]
        while stack:
            node = stack.pop()
            if isinstance(node, dict):
                stack.extend(node.values())
            elif isinstance(node, list):
                stack.extend(node)
            elif isinstance(node, str):
                yield path.name, node


def test_sweep_curriculum_produces_only_valid_codes():
    """⚖️ كلُّ نصّ الكيمياء يمرّ — ولا ترميزَ مشوّه ولا مقاسَ خارج المدى.

    (درسُ «امسح كل الحالات المشابهة»: عيّنةُ المالك ليست القائمة.)
    """
    seen = 0
    for name, text in _all_chemistry_strings():
        out = to_ring(text)
        for code in re.findall(r"\\ring\{([^}]*)\}", out):
            seen += 1
            parts = code.split("|")
            assert parts[0].isdigit(), f"{name}: مقاسٌ غير رقمي في {code}"
            assert 3 <= int(parts[0]) <= 8, f"{name}: مقاسٌ خارج المدى في {code}"
            for p in parts[1:]:
                assert p == "ar" or p.startswith(("=", "+", "fuse")) \
                    or p in {"N", "NH", "O", "S"}, f"{name}: جزءٌ مجهول «{p}»"
    assert seen > 150, "المسح لم يُنتج ترميزات — هل انكسر التحويل؟"


def test_sweep_leaves_no_dangling_arabic_suffix():
    """لا حرفَ عربيّ ملتصقٌ بقوس الإغلاق في كل المنهج."""
    for name, text in _all_chemistry_strings():
        out = to_ring(text)
        assert not re.search(r"\}[ء-ي]", out), f"{name}: لاحقةٌ معلّقة بعد الترميز"


def test_sweep_is_idempotent():
    """نصٌّ مرمَّزٌ لا يُرمَّز مرّتين — وإلا تضاعفت الرسوم في كل تحميل."""
    for name, text in _all_chemistry_strings():
        once = to_ring(text)
        assert to_ring(once) == once, name


# ══════════════════ ⑦ ما أضافته الجولة بعد المسح الأول ══════════════════

def test_kekule_structures_are_drawn_with_bonds_not_a_circle():
    """⚗️ (أ) و(ب) كيكولي بروابطَ مرسومة، و(جـ) بالدائرة — ثلاثتُها صفحةٌ واحدة.

    ورسمُها كلِّها بالدائرة يمحو الدرسَ نفسه: تاريخَ اكتشاف بنية البنزين.
    """
    out = to_ring("رسم: الشكل (أ) يوضح حلقة سداسية مع تبادل مواقع "
                  "الروابط الثنائية والأحادية.")
    assert r"\ring{6|=1,3,5}" in out


def test_ortho_pair_of_two_different_groups():
    """«أورثو - برومو كلورو بنزين»: مجموعتان مختلفتان في 1 و2 — لا توزيعُ واحدة."""
    out = to_ring("في حلقة: تسمى أورثو - برومو كلورو بنزين.")
    assert r"\ring{6|ar|+Br@1|+Cl@2}" in out


def test_parent_group_does_not_duplicate_the_named_one():
    """🔴 «1-برومو-2-كلوروبنزين» كان يخرج بكلورين: ضمنيٍّ ومسمّى."""
    out = to_ring("في حلقة: 1-برومو-2-كلوروبنزين.")
    assert r"\ring{6|ar|+Br@1|+Cl@2}" in out
    assert out.count("+Cl") == 1         # كلورٌ واحد لا اثنان


def test_single_benzene_next_to_fused_ones_stays_single():
    """🔴 «حلقة بنزين مفردة، حلقتان ملتحمتان، ثلاث حلقات ملتحمة» —
    كان البنزينُ المفرد يلتقط «ثلاث حلقات» فيصير أنثراسيناً."""
    out = to_ring("الوصف: حلقة بنزين مفردة، حلقتان ملتحمتان، ثلاث حلقات ملتحمة.")
    assert r"\ring{6|ar}" in out
    assert "fuse3" not in out.split("مفردة")[0]
