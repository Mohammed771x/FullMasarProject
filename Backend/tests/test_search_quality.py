# -*- coding: utf-8 -*-
"""🔎 بحثُ وضع الوحدات — **الترتيب**، ولماذا كان يأتي بالهرمونات النباتية.

🔴 **ما قاسه المالكُ معنا (2026-09-14):** سأل «كيف يبحث؟ هل آليته صحيحة؟»
   فقِسناها، فإذا هي مكسورة قياساً لا ظنّاً:

   سؤال «ما الفرق بين الغدة النخامية والغدة الدرقية» في وحدة التنظيم
   الهرموني (١٩ صفحة) كان يصل الموديلَ بالصفحات (٤١ · ٤٣ · ٤٥) — وفيها
   **صفحتان عن الهرمونات النباتية** (الإيثيلين والجبريلينات). بينما
   البحثُ الدلاليّ نفسُه كان يريد (٤٦ · ٥٠ · ٥٥).

   السبب: الدمجُ كان «كلُّ صفحةٍ فيها **أيُّ** كلمةٍ من ثلاثة أحرف تُقدَّم،
   **بترتيب الكتاب**، ثم يُقصّ عند ٣». وكلمة «بين» في ٩ صفحاتٍ من ١٩ —
   فتملأ أوّلُ ثلاثٍ منها المقاعدَ وتطرد الدلاليَّ كلَّه.

⚖️ والعلاج: المطابقةُ اللفظية **وزنٌ يُضاف** لا أسبقيةٌ تطرد، وكلماتُ
   السؤال والربط تُسقَط، والكلمةُ الشائعة جداً لا وزن لها.
"""
import asyncio

import pytest

from subjects.common import (
    extract_all_texts_and_metas, hybrid_rank, query_terms, term_weights,
    _normalize_for_search, unit_missing, unit_required_response,
)
from core.content_store import get_pages_book

UNIT = "التنظيم الهرموني"


def _unit_pages():
    book = get_pages_book(3, "علمي", "احياء")
    target = [u for u in book if (u.get("اسم_الوحدة") or "").strip() == UNIT]
    assert target, "وحدةُ التنظيم الهرموني غير موجودة — تغيّر المحتوى؟"
    return extract_all_texts_and_metas(target)


def _pages_for(query, top_k=3):
    texts, metas = _unit_pages()
    _t, idxs = asyncio.run(hybrid_rank(texts, query, top_k))
    return [metas[i]["page"] for i in idxs], [texts[i] for i in idxs]


# ══════════════ ① كلماتُ الموضوع تُفصل عن كلمات السؤال ══════════════

def test_question_words_are_not_topic_words():
    """«اشرح» و«الفرق» و«بين» لا تدلّ على موضوع فلا تُرجّح صفحة."""
    terms = query_terms("ما الفرق بين الغدة النخامية والغدة الدرقية")
    assert "الفرق" not in terms and "بين" not in terms
    assert "النخاميه" in terms and "الدرقيه" in terms


def test_the_topic_words_survive_arabic_normalisation():
    """والتوحيد يجمع «الغدة» و«الغده» — وإلا ضاعت المطابقة على تاءٍ مربوطة."""
    assert "النخاميه" in query_terms("اشرح لي عن الغدة النخامية")


def test_a_term_in_most_pages_gets_no_weight():
    """🔇 كلمةٌ في أكثر من ٤٠٪ من الصفحات كلمةُ سياقٍ لا موضوع."""
    texts, _ = _unit_pages()
    norm = [_normalize_for_search(t) for t in texts]
    weights = term_weights(["الغده", "النخاميه"], norm)
    assert "الغده" not in weights, "«الغدة» في ١١ من ١٩ صفحة — لا تميّز شيئاً"
    assert weights.get("النخاميه", 0) > 0


# ══════════════ ② الترتيب يأتي بالصفحة الصحيحة ══════════════

def test_the_pituitary_page_comes_first():
    """⭐ «اشرح لي عن الغدة النخامية» ⇐ صفحةُ «١- الغدة النخامية» أولاً.

    وكانت هذه الصفحةُ **لا تصل الموديلَ إطلاقاً** قبل الإصلاح.
    """
    pages, texts = _pages_for("اشرح لي عن الغدة النخامية")
    assert "الغدة النخامية" in texts[0], f"الأولى ليست صفحة النخامية: ص{pages[0]}"


def test_plant_hormones_no_longer_answer_a_gland_question():
    """🌱 ولا تصل صفحاتُ الهرمونات النباتية في سؤالٍ عن غدد الإنسان."""
    _pages, texts = _pages_for("ما الفرق بين الغدة النخامية والغدة الدرقية")
    joined = " ".join(texts)
    for intruder in ("الجبريلينات", "الأوكسينات", "الإيثيلين"):
        assert intruder not in joined, f"«{intruder}» تسلّلت إلى سؤالٍ عن الغدد"


def test_a_comparison_reaches_both_sides():
    """⚖️ وسؤالُ المقارنة يصل ومعه طرفاه — لا طرفٌ واحد."""
    _pages, texts = _pages_for("ما الفرق بين الغدة النخامية والغدة الدرقية")
    joined = _normalize_for_search(" ".join(texts))
    assert "النخاميه" in joined and "الدرقيه" in joined


def test_ranking_is_stable_for_the_same_query():
    """🔁 ونفسُ السؤال يعطي نفسَ الصفحات — لا عشوائية في الترتيب."""
    a, _ = _pages_for("الغدة النخامية")
    b, _ = _pages_for("الغدة النخامية")
    assert a == b


def test_an_off_topic_question_does_not_crash():
    """🛟 وسؤالٌ لا صلة له بالوحدة يعيد شيئاً بلا انهيار.

    ⚠️ ولا نثبّت العدد: `QA_TOP_K` صار ٤، وقد تُضمّ جارةُ صفحةٍ مبتورة.
    """
    pages, _ = _pages_for("متى قامت الثورة الفرنسية")
    assert 3 <= len(pages) <= 6


def test_empty_corpus_is_safe():
    assert asyncio.run(hybrid_rank([], "أي سؤال", 3)) == ([], [])


# ══════════════ ③ الوحدة إلزامية على مسار البحث ══════════════

class _Req:
    def __init__(self, unit):
        self.unit_name = unit


@pytest.mark.parametrize("unit", ["الكل", "", "   ", None])
def test_no_unit_means_no_search(unit):
    """📚 «الكل ماشي الكل — ضروري يختار وحدة» (نصّ المالك)."""
    assert unit_missing(_Req(unit))


def test_a_named_unit_passes():
    assert not unit_missing(_Req(UNIT))


def test_the_refusal_tells_the_student_what_to_do():
    """⚖️ ورسالةُ المنع تقول **ماذا يفعل**، لا «خطأ» وحدها."""
    msg = unit_required_response()["answer"]
    assert "اختر الوحدة" in msg
    assert len(msg) > 40, "رسالةٌ مقتضبة لا تُرشد أحداً"


# أسماءُ دوالّ البحث في المعالجات — **كلُّها**، لا التي تبدأ بـ`enhanced_`.
# 🔴 أولُ صيغةٍ لهذا المسح ذكرت ثلاثةَ أسماءٍ فقط، فأفلتت منه
#    `enhanced_search_with_context` (فيزياء وكيمياء وعربي) و
#    `enhanced_search_english` — أربعةُ مساراتٍ بقيت بلا حارسِ وحدةٍ شهراً.
#    ومسحٌ لا يرى إلا ما يعرف اسمَه ليس مسحاً.
_SEARCH_CALLS = (r"await (enhanced_qa_search|enhanced_search_physics"
                 r"|enhanced_search_with_context|enhanced_search_english"
                 r"|faiss_search|hybrid_rank)\(")

_HANDLER_FILES = (("subjects", ("biology", "physics", "chemistry", "arabic", "english")),
                  ("core", ("pages_mode",)))


def _search_call_sites():
    """كلُّ نداءِ بحثٍ في معالجات المواد — بموقعه ونافذتيه قبلَه وبعدَه."""
    import os, re
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    for folder, names in _HANDLER_FILES:
        for name in names:
            path = os.path.join(root, folder, f"{name}.py")
            lines = open(path, encoding="utf-8").read().split("\n")
            for i, line in enumerate(lines):
                if not re.search(_SEARCH_CALLS, line):
                    continue
                if line.lstrip().startswith(("return", "#")):
                    continue            # دالّةُ مساعدةٍ لا موضعَ قرار
                yield (f"{folder}/{name}.py:{i + 1}",
                       "\n".join(lines[max(0, i - 16):i]),
                       "\n".join(lines[i:i + 18]))


def test_every_search_path_is_guarded():
    """🔒 **ولا مسارَ بحثٍ بلا حارس** — كانت المواد الخمس تنسخ نفس الكود.

    الحارسُ يسبق كلَّ نداءِ بحثٍ في معالجات المواد وفي وضع الوحدات العام.
    """
    sites = list(_search_call_sites())
    assert len(sites) >= 16, f"المسحُ لم يرَ إلا {len(sites)} موضعاً — تغيّرت الأسماء؟"
    offenders = [where for where, before, _after in sites
                 if "unit_missing" not in before]
    assert not offenders, f"نداءُ بحثٍ بلا حارس وحدة: {offenders}"


def test_every_search_path_carries_the_relevance_verdict():
    """🎯 **ولا نتيجةَ بحثٍ تُصدَّق بلا حكمِ صلة** ([config.RELEVANCE_FLOOR]).

    🔄 **تغيّر شكلُ الحارس (قرار المالك 2026-09-14):** كان يردّ الطالبَ
       بلا نداءِ موديل؛ وصار **السؤالُ يذهب للموديل دائماً** وحكمُ الصلة
       يُرافق الصفحات تحفّظاً: واثقةٌ بلا تحفّظ · ضعيفةٌ بتحفّظ · ولا
       مطابقةَ بتحفّظٍ أشدّ. و[common.book_context] هي التي تُلحقه —
       فمن بنى نصَّ الكتاب بيده أسقط الحكمَ بصمت.
    """
    offenders = [where for where, _before, after in _search_call_sites()
                 if "book_context(" not in after or "req=req" not in after]
    assert not offenders, f"نتيجةُ بحثٍ بلا حكمِ صلة: {offenders}"


def test_no_handler_joins_the_pages_by_hand():
    """🧷 ونصُّ الكتاب يُبنى من [common.book_context] وحدها.

    من يكتب `"\\n".join(results)` بيده يُسقط تحفّظَ الحزام الأوسط بصمت.
    """
    import os
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    offenders = []
    for folder, names in _HANDLER_FILES:
        for name in names:
            path = os.path.join(root, folder, f"{name}.py")
            for i, line in enumerate(open(path, encoding="utf-8").read().split("\n")):
                if "join(results)" in line:
                    offenders.append(f"{folder}/{name}.py:{i + 1}")
    assert not offenders, f"نصُّ كتابٍ يُبنى يدوياً بلا تحفّظ: {offenders}"


# ══════════════ ④ سؤالُ المتابعة يستعير موضوعَه ══════════════
#
# 🔴 **ما قيسَ (2026-09-14):** الطالب يسأل «عرّف الغدة النخامية» فتصله
#    الصفحات الصحيحة، ثم يقول «ممكن توضح لي أكثر؟» فتصله (٥٩ · ٤٧ · ٥١ ·
#    ٥٨) — عشوائية، لأن نصَّ البحث لا موضوع فيه. و«ما الفرق بينها وبين
#    الدرقية» كانت تُسقط صفحةَ النخامية كلَّها لأن موضوعها ضميرٌ لا اسم.

from subjects.common import (                                   # noqa: E402
    contextual_search_text, conversation_topic, has_anaphora,
    looks_truncated, expand_truncated_neighbours, query_terms as _qt,
)

_HISTORY = [
    {"role": "user", "content": "عرف الغدة النخامية"},
    {"role": "assistant", "content": "الغدة النخامية هي المايسترو..."},
]


def _follow(question):
    texts, metas = _unit_pages()
    built = contextual_search_text(question, _HISTORY)
    _t, idxs = asyncio.run(hybrid_rank(texts, built, 4))
    return built, [metas[i]["page"] for i in idxs], [texts[i] for i in idxs]


def test_punctuation_no_longer_clings_to_a_term():
    """🔴 «النخامية؟» كانت لا تطابق «النخامية» — وأكثرُ الأسئلة تنتهي بـ«؟».

    نطاقُ الحروف العربية `؀-ۿ` يشمل علامة الاستفهام نفسها، فكانت تُستخرج
    ملتصقةً بالكلمة وتُسقط نصفَ المطابقة اللفظية بصمت.
    """
    assert "النخاميه" in _qt("ما هي الغدة النخامية؟")
    assert "النخاميه" in _qt("الغدة النخامية، ووظائفها")


def test_a_pure_follow_up_has_no_topic_of_its_own():
    """«ممكن توضح لي أكثر؟» ليس فيها كلمةُ موضوعٍ واحدة."""
    assert _qt("ممكن توضح لي أكثر؟") == []
    assert has_anaphora("ممكن توضح لي أكثر؟")


def test_a_follow_up_borrows_the_conversation_topic():
    """🧵 فتستعير موضوعَها من أحدث رسالةِ طالبٍ تحمل موضوعاً."""
    built, _pages, _t = _follow("ممكن توضح لي أكثر؟")
    assert "النخاميه" in built


def test_a_pronoun_question_keeps_both_sides():
    """⭐ «ما الفرق **بينها** وبين الدرقية» — والضميرُ يعود إلى النخامية."""
    built, _pages, texts = _follow("ما الفرق بينها وبين الغدة الدرقية")
    assert "النخاميه" in built, "الضميرُ لم يُفسَّر — ضاع طرفُ المقارنة الأول"
    joined = _normalize_for_search(" ".join(texts))
    assert "النخاميه" in joined and "الدرقيه" in joined


@pytest.mark.parametrize("question", ["ممكن توضح لي أكثر؟", "ليش؟",
                                      "أعطني مثالاً", "وضح أكثر"])
def test_every_follow_up_lands_on_the_same_topic(question):
    """🎯 وكلُّ صيغِ المتابعة تعود إلى صفحة الموضوع نفسها لا إلى غيرها."""
    _b, _pages, texts = _follow(question)
    assert any("الغدة النخامية" in t for t in texts), \
        f"«{question}» ضاعت عن موضوعها"


def test_a_new_topic_does_not_borrow_the_old_one():
    """🔒 **والاستعارةُ مشروطة**: سؤالٌ جديد بموضوعٍ واضح لا يُلوَّث بالسابق."""
    built = contextual_search_text("ما هو الأنسولين؟", _HISTORY)
    assert "النخاميه" not in built
    assert built == "ما هو الأنسولين؟"


def test_the_topic_is_taken_from_the_last_message_that_has_one():
    """🔎 ونمشي إلى الوراء: سلسلةُ متابعاتٍ موضوعُها في أوّلها."""
    chain = _HISTORY + [
        {"role": "user", "content": "وضح أكثر"},
        {"role": "assistant", "content": "..."},
    ]
    assert "النخاميه" in conversation_topic(chain)


def test_borrowing_is_safe_without_history():
    assert contextual_search_text("ليش؟", None) == "ليش؟"
    assert contextual_search_text("", []) == ""


# ══════════════ ⑤ الصفحةُ المبتورة تجرّ جارتها ══════════════

def test_a_page_cut_mid_sentence_is_detected():
    """✂️ ص٥١ تنتهي «...ينظم التوازن المائي للجسم» بلا نقطة."""
    assert looks_truncated("الهرمون الذي ينظم التوازن المائي للجسم")
    assert not looks_truncated("وهذا يتم في الكلية.")
    assert not looks_truncated("")


def test_the_neighbour_of_a_truncated_page_is_pulled_in():
    """🔗 فتُضمّ الصفحةُ التالية — وإلا شُرح للطالب نصفُ الجملة."""
    texts = ["مقدمة.", "الفازوبرسين ينظم التوازن المائي للجسم",
             "عن طريق إعادة امتصاص الماء.", "موضوع آخر."]
    assert expand_truncated_neighbours(texts, [1]) == [1, 2]


def test_the_page_before_a_truncated_one_is_pulled_in_too():
    """↔️ وإن كانت السابقةُ هي المبتورة فبدايةُ الجملة فيها."""
    texts = ["الفازوبرسين ينظم التوازن", "عن طريق امتصاص الماء.", "غيره."]
    assert 0 in expand_truncated_neighbours(texts, [1])


def test_the_expansion_is_capped():
    """⚖️ ولا تنتفخ: حدٌّ أقصى صفحتان مضمومتان."""
    texts = ["أ بلا نقطة", "ب بلا نقطة", "ج بلا نقطة", "د بلا نقطة",
             "هـ بلا نقطة", "و بلا نقطة"]
    out = expand_truncated_neighbours(texts, [0, 2, 4], limit=2)
    assert len(out) <= 5


def test_a_complete_page_pulls_nothing():
    texts = ["صفحةٌ كاملة.", "أخرى."]
    assert expand_truncated_neighbours(texts, [0]) == [0]


def test_the_real_pituitary_page_brings_its_continuation():
    """⭐ الحالةُ الحقيقية: ص٥١ تجرّ ص٥٢ فتكتمل جملةُ الفازوبرسين."""
    _b, pages, _t = _follow("عرف الغدة النخامية")
    assert 51 in pages and 52 in pages, f"التكملةُ لم تصل: {pages}"


def test_latin_case_does_not_smuggle_a_stop_word_through():
    """🔡 «Explain» كانت تنجو من قائمة الإيقاف بحرفٍ كبيرٍ واحد."""
    assert _qt("Explain more about it") == []
    assert "النخاميه" in contextual_search_text("Explain more about it", _HISTORY)


def test_every_search_path_carries_the_drawing_reminder():
    """🖌️ **ولا معالجَ يفقد تذكيرَ الرسّام** — [common.book_context] تُلحقه.

    🔴 قِيس (2026-09-14): `draw_reminder` كانت في وضع الدروس ووضع الوحدات
       العام و«اختبر نفسك» والمعلّم — **وغائبةً عن معالجات المواد الخمسة**
       (أحياء · فيزياء · كيمياء · عربي · إنجليزي)، وهي التي تخدم أكثر
       الصفحات رسوماً (المعادلات والحلقات والكسور).

    ⚖️ وستةَ عشر موضعاً تبني رسالة المستخدم، فإلحاقُه في كلٍّ منها يعني
       موضعاً يُنسى — وقد نُسي فعلاً. فصار في الدالّة التي يمرّ بها الجميع.
    """
    from subjects.common import book_context, Ranked
    drawn = book_context(Ranked([r"الناتج \frac{أ}{ب} ثم \ring{بنزين}"], [0], best=1.2))
    assert "ترميزَ رسمٍ" in drawn, "نصٌّ فيه رسومٌ خرج بلا تذكير"

    plain = book_context(Ranked(["نصٌّ بلا أي ترميز"], [0], best=1.2))
    assert "ترميزَ رسمٍ" not in plain, "تذكيرٌ بلا سبب يُضعف التذكيرَ حين يلزم"


def test_the_reminder_is_not_appended_twice():
    """🔁 ولا يُلحق مرّتين: وضعُ الوحدات العام كان يُلحقه بنفسه."""
    import os, re
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src = open(os.path.join(root, "core", "pages_mode.py"), encoding="utf-8").read()
    search_half = src.split("ب) بالبرومت")[1]
    assert "_draw_reminder(" not in search_half, "تذكيرٌ مكرّر في مسار البحث"


# ══════════════ ⑤ علّتان قِيستا في الفحص الشامل (2026-09-14) ══════════════

def test_a_request_verb_is_never_the_heaviest_word_in_the_question():
    """📝 **«اكتب» كانت أثقل كلمةٍ في السؤال كلِّه.**

    🔴 قِيس: «اكتب قانون المقاومة الحثية والسعوية» في وحدة التيار المتردد —
       وزنُ «اكتب» ٥٫٣٥ (أعلى من «المقاومة» و«الحثية» معاً!) لأنها نادرةٌ
       في الكتاب فمنحتها الـidf أعلى وزن. فتقدّمت صفحاتٌ فيها «اكتب» على
       صفحة «المفاعلة الحثية للملف» التي فيها القانونُ نفسُه.

    ⚖️ فأفعالُ الطلب كلُّها في قائمة الإيقاف — لا «اشرح» و«عرّف» وحدهما.
    """
    from subjects.common import query_terms
    for verb in ("اكتب", "هات", "عدّد", "استنتج", "برهن", "ارسم", "صنّف",
                 "ناقش", "حدّد", "أكمل", "اختر"):
        assert query_terms(f"{verb} قانون أوم") == _qt("قانون أوم"), verb


def test_the_conjunction_waw_does_not_break_the_match():
    """🔗 **واوُ العطف كانت تكسر المطابقة.**

    🔴 «اكتب قانون المقاومة الحثية **والسعوية**» لم تطابق صفحةً فيها
       «السعوية»، لأن «والسعويه» ليست جزءاً من «السعويه». وهي صيغةٌ
       يوميّة: «الأسباب والنتائج» · «التركيب والوظيفة».

    ⚖️ والتقشيرُ مقصورٌ على ما تبعته «ال» — وإلا صارت «وراثة» «راثة».
    """
    from subjects.common import query_terms
    assert "السعويه" in query_terms("المقاومة الحثية والسعوية")
    assert "الدرقيه" in query_terms("الفرق بين الغدة النخامية والغدة الدرقية")
    assert "الكتله" in query_terms("اشرح الوزن والكتلة")
    # ولا تُقشَّر واوٌ أصليّة
    assert "الوراثه" in query_terms("ما هي الوراثة؟")
    assert "وراثه" in query_terms("علم وراثة")


def test_the_anterior_lobe_case_survives_both_fixes():
    """🎯 وحالةُ المالك الأصلية باقيةٌ خضراء بعد كل تغيير."""
    pages, _texts = _pages_for("إيش يخرج من الفص الأمامي؟", top_k=4)
    assert 53 in pages, f"ص{pages}"
