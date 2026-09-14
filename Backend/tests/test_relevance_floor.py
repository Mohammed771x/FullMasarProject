# -*- coding: utf-8 -*-
"""🎯 عتبةُ الصلة — «أفضل أربع» لا تعني «ذات صلة».

🔴 **ما رآه المالك (2026-09-14):** «الطالب يسأل: ما هو قانون نيوتن الثاني؟
   بينما الوحدة عن الغدد. البحث سيقول: أفضل ٤ نتائج ٥١ ٤٦ ٥٠ ٥٣. لكن أفضل
   ٤ لا يعني أنها ذات صلة فعلاً. وهنا ممكن الموديل يستنتج: بما أن هذه
   الصفحات هي التي أُرسلت لي، فلا بد أن أجيب منها. فالعتبة تمنع هذا.»

📏 **وقال أيضاً: «لا تختاروا رقم العتبة بالتخمين.»** فلم نُخمّن — قِسنا
   ٦٣٠ سؤالاً على تسعة كتب:

     ٣٧٨ سؤالاً داخل الوحدة (منها متابعاتٌ وقصيرةٌ وبأخطاءٍ إملائية
         وبضمائر) · ١٦٨ من وحدةٍ أخرى في الكتاب نفسه · ٨٤ خارج المادة.

     العتبة   يرفض داخلَ الوحدة   يمسك خارجَ المادة   يمسك خارجَ الوحدة
     ٠٫٣٥          ١٫١٪                ٧٨٫٦٪              ١٢٫٥٪
     ٠٫٤٠          ١٫٦٪                ٩١٫٧٪              ١٩٫٠٪   ← الأرضية
     ٠٫٤٥          ٢٫١٪                ٩٥٫٢٪              ٢٥٫٠٪
     ٠٫٦٠          ٧٫٤٪               ١٠٠٫٠٪              ٤٧٫٠٪   ← فوقها لا دخيل

   والرفضُ الخاطئ عند الأرضية (٦ من ٣٧٨) كلُّه أسئلةٌ بأخطاءٍ إملائيةٍ فادحة
   («ما هو التقانه الحييه؟») وعناوينُ فهرسةٍ لا أسئلةَ طلاب.

⚠️ **والفصلُ على المجموع الهجين لا على التشابه الدلاليّ وحده.** عتبةٌ على
   الدلاليّ عند ٠٫٤٠ كانت ترفض **٢٦٫٩٪** من أسئلة الوحدة — الجيبُ وحده
   لا يفصل، والمطابقةُ اللفظية هي التي تفصل.
"""
import asyncio

import pytest

from config import RELEVANCE_FLOOR, RELEVANCE_SURE, QA_TOP_K
from subjects.common import (
    Ranked, off_topic, book_context, WEAK_MATCH_NOTE, NO_MATCH_NOTE,
    hybrid_rank, extract_all_texts_and_metas,
)
from core.content_store import get_pages_book

UNIT = "التنظيم الهرموني"


def _unit_pages():
    book = get_pages_book(3, "علمي", "احياء")
    target = [u for u in book if (u.get("اسم_الوحدة") or "").strip() == UNIT]
    assert target, "وحدةُ التنظيم الهرموني غير موجودة — تغيّر المحتوى؟"
    return extract_all_texts_and_metas(target)


def _rank(query, top_k=QA_TOP_K):
    texts, _metas = _unit_pages()
    return asyncio.run(hybrid_rank(texts, query, top_k))


# ══════════════ ① الرقمان أنفسُهما ══════════════

def test_the_two_bands_are_ordered_and_sane():
    assert 0 < RELEVANCE_FLOOR < RELEVANCE_SURE < 1.5


# ══════════════ ② الدرجةُ تسافر مع النتيجة بلا كسرِ أحد ══════════════

def test_the_result_still_unpacks_like_the_plain_tuple_it_was():
    """⚖️ اثنا عشر موضعاً تكتب `results, idxs = await ...`.

    لهذا وُرِّثت `Ranked` من `tuple` بدل تمريرِ قيمةٍ ثالثة: أيُّ موضعٍ
    يُنسى عند تغيير التوقيع كان سيبقى بلا حارس.
    """
    found = Ranked(["ص أولى", "ص ثانية"], [0, 1], best=0.9)
    results, idxs = found
    assert results == ["ص أولى", "ص ثانية"] and idxs == [0, 1]
    assert found == (["ص أولى", "ص ثانية"], [0, 1])
    assert found.best == pytest.approx(0.9)


def test_an_empty_search_is_off_topic_not_confident():
    """🕳️ ولا نتيجةَ أصلاً = لا صلة — لا «مطابقةٌ واثقة» بحكمٍ افتراضي."""
    empty = asyncio.run(hybrid_rank([], "أي سؤال", 3))
    assert empty == ([], [])
    assert empty.verdict == "off" and off_topic(empty)


@pytest.mark.parametrize("best, expected", [
    (0.0, "off"), (RELEVANCE_FLOOR - 0.01, "off"),
    (RELEVANCE_FLOOR, "weak"), (RELEVANCE_SURE - 0.01, "weak"),
    (RELEVANCE_SURE, "ok"), (1.4, "ok"),
])
def test_the_three_verdicts_split_exactly_at_the_two_numbers(best, expected):
    assert Ranked(["ص"], [0], best=best).verdict == expected


# ══════════════ ③ ماذا يصل الموديلَ في كل حزام ══════════════

def test_a_confident_match_travels_without_a_caveat():
    assert WEAK_MATCH_NOTE not in book_context(Ranked(["نص"], [0], best=1.0))


def test_a_weak_match_carries_an_order_not_to_invent():
    """🟡 الحزامُ الأوسط: الصفحاتُ تُرسل ومعها أمرٌ بقول الحقيقة.

    ولا نداءَ موديلٍ ثانياً — «افحص هل الجواب فيها ثم أجب» كان سيضاعف
    الفاتورة على كل سؤال.
    """
    ctx = book_context(Ranked(["نص"], [0], best=(RELEVANCE_FLOOR + RELEVANCE_SURE) / 2))
    assert ctx.startswith("نص")
    assert WEAK_MATCH_NOTE in ctx
    assert "لا تجب من معرفتك العامة" in ctx


def test_the_separator_of_each_subject_is_preserved():
    """بعضُ المعالجات تفصل الصفحات بسطر وبعضها بسطرين — لا نغيّر برومبتاً بلا قصد."""
    found = Ranked(["أ", "ب"], [0, 1], best=1.0)
    assert book_context(found, sep="\n") == "أ\nب"
    assert book_context(found) == "أ\n\nب"


def test_no_match_tells_the_model_what_to_do_instead_of_refusing():
    """🔄 **سقط الردُّ الجاهز (قرار المالك 2026-09-14):** السؤالُ يذهب
    للموديل دائماً، والعتبةُ صارت تختار **ما يُقال له** لا مَن يُردّ.

    وبقي الإرشادان اللذان كانا في رسالة الرفض: غيّر الوحدة، أو أعد
    الصياغة بمصطلح الكتاب — لكن بلسان الموديل لا برسالةٍ آلية.
    """
    assert "يغيّر الوحدة" in NO_MATCH_NOTE
    assert "بمصطلحٍ من الكتاب" in NO_MATCH_NOTE
    assert "لا تجب من معرفتك العامة" in NO_MATCH_NOTE


def test_the_three_bands_attach_three_different_caveats():
    """🎯 واثقةٌ بلا تحفّظ · ضعيفةٌ بتحفّظ · ولا مطابقةَ بتحفّظٍ أشدّ."""
    sure = book_context(Ranked(["ص"], [0], best=RELEVANCE_SURE + 0.1))
    weak = book_context(Ranked(["ص"], [0], best=RELEVANCE_FLOOR + 0.01))
    none = book_context(Ranked(["ص"], [0], best=RELEVANCE_FLOOR - 0.1))
    assert WEAK_MATCH_NOTE not in sure and NO_MATCH_NOTE not in sure
    assert WEAK_MATCH_NOTE in weak and NO_MATCH_NOTE not in weak
    assert NO_MATCH_NOTE in none and WEAK_MATCH_NOTE not in none


# ══════════════ ④ على محتوًى حقيقيّ — لا على أمثلةٍ مصنوعة ══════════════

@pytest.mark.parametrize("question", [
    "ما هو قانون نيوتن الثاني؟",          # نصُّ المالك حرفياً
    "من هو المتنبي؟",
    "ما هي بحور الشعر العربي؟",
    "كيف أتعلم البرمجة؟",
])
def test_a_question_from_another_world_scores_below_the_floor(question):
    """🚫 في وحدة التنظيم الهرموني — هذه تصل الموديلَ **بتحفّظٍ أشدّ**.

    (لم تعد تُردّ بلا نداء؛ لكنّ الحكمَ عليها يجب أن يبقى «لا مطابقة»،
     وإلا وصلت بلا تحفّظٍ فأجاب الموديلُ من معرفته العامة.)
    """
    found = _rank(question)
    assert found.best < RELEVANCE_FLOOR, f"{question} ← {found.best:.3f}"
    assert found.verdict == "off"
    assert NO_MATCH_NOTE in book_context(found)


@pytest.mark.parametrize("question", [
    "ما هي الغدة النخامية؟",
    "اشرح لي وظيفة هرمون الثيروكسين",
    "ما الفرق بين الغدة النخامية والغدة الدرقية",
    "عرّف الهرمونات النباتية",
    "متى يفرز هرمون الأنسولين؟",
])
def test_a_real_question_from_the_unit_is_never_refused(question):
    """✅ والكلفةُ غيرُ متماثلة: رفضُ سؤالٍ صحيح أقسى من قبول دخيل."""
    found = _rank(question)
    assert found.best >= RELEVANCE_FLOOR, f"{question} ← {found.best:.3f}"
    assert not off_topic(found)


def test_a_follow_up_keeps_its_borrowed_topic_above_the_floor():
    """🧵 «وضّح أكثر» بعد سؤالٍ عن النخامية — يستعير موضوعَه فلا يُرفض.

    ولولا الاستعارة لسقط تحت الأرضية: سؤالٌ بلا موضوعٍ لا يطابق شيئاً.
    """
    from subjects.common import contextual_search_text
    history = [{"role": "user", "content": "عرف الغدة النخامية"},
               {"role": "assistant", "content": "الغدة النخامية هي..."}]
    built = contextual_search_text("ممكن توضح لي أكثر؟", history)
    assert not off_topic(_rank(built))
    assert off_topic(_rank("ممكن توضح لي أكثر؟")), \
        "سؤالُ متابعةٍ بلا موضوعٍ يجب أن يسقط — وهو ما يجعل الاستعارة ضرورية"


# ══════════════ ⑤ العلّةُ التي كشفها مثالُ المالك نفسُه ══════════════

def test_the_owner_s_own_example_is_refused_not_answered():
    """🔴 «ما هو قانون نيوتن الثاني؟» في وحدة التنظيم الهرموني.

    أولُ قياسٍ بعد بناء العتبة أعطاها **٠٫٧٠٦** — فوق كل حزام! لأن
    «قانون» و«نيوتن» غائبتان عن الوحدة **فكانتا تُسقطان من الحساب**،
    فتبقى «الثاني» وحدها (من «الرسول الثاني») وتنال مطابقةً كاملة.
    أي أن غيابَ موضوع السؤال عن الكتاب كان **يرفع** درجتَه.
    """
    found = _rank("ما هو قانون نيوتن الثاني؟")
    assert found.best < RELEVANCE_FLOOR, f"عادت العلّة: {found.best:.3f}"


def test_an_absent_word_lowers_the_score_instead_of_raising_it():
    """🔻 المقامُ يحسب الكلمةَ الغائبة — وإلا صارت المطابقةُ الجزئية كاملة."""
    from subjects.common import (query_terms, term_weights,
                                 lexical_denominator, _normalize_for_search)
    pages = ["الرسول الثاني داخل الخلية", "الغدة النخامية والهرمونات"]
    norm = [_normalize_for_search(p) for p in pages]
    terms = query_terms("ما هو قانون نيوتن الثاني؟")
    weights = term_weights(terms, norm)
    assert list(weights) == [], "«الثاني» عادت كلمةَ موضوع — راجع قائمة الإيقاف"

    # وحالةٌ عامة: كلمةٌ حاضرة وأخرى غائبة ⇒ المطابقةُ نصفٌ لا كامل
    terms = ["النخاميه", "كلمهغائبهتماما"]
    weights = term_weights(terms, norm)
    denom = lexical_denominator(terms, norm, weights)
    assert denom == pytest.approx(2 * sum(weights.values()))


@pytest.mark.parametrize("ordinal", ["الثاني", "الأولى", "الفصل", "الوحدة",
                                     "الدرس", "الصفحة", "ثالثاً"])
def test_an_ordinal_is_never_a_topic_word(ordinal):
    """🔢 «الدرس الثاني» ليس موضوعاً — هو موقعٌ في الكتاب."""
    from subjects.common import query_terms
    assert query_terms(f"ما هو {ordinal}؟") == []


def test_the_semantic_score_alone_would_not_have_separated():
    """⚠️ **لماذا العتبةُ على المجموع لا على الجيب وحده.**

    قياسُ العيّنة: عتبةٌ على التشابه الدلاليّ عند ٠٫٤٠ ترفض ٢٦٫٩٪ من
    أسئلة الوحدة. وهذه حالةٌ واحدة تكفي للبرهان: سؤالٌ صحيحٌ من الوحدة
    جيبُه أقلُّ من ٠٫٤٠، ولولا المطابقةُ اللفظية لرُفض.
    """
    from subjects.common import faiss_scores
    texts, _m = _unit_pages()
    q = "ما الفرق بين الغدة النخامية والغدة الدرقية"
    sem = asyncio.run(faiss_scores(texts, q))
    best_sem = max(sem.values())
    best_hybrid = _rank(q).best
    assert best_hybrid > best_sem, "المطابقةُ اللفظية لم تُضف شيئاً — تعطّل الترتيبُ الهجين"
