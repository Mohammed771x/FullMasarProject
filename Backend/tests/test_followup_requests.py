# -*- coding: utf-8 -*-
"""🗣️ طلبُ المتابعة — تعليمٌ على الجواب السابق لا سؤالٌ جديد.

🔴 **شكوى المالك (2026-09-14):** «قلت له أعطيني مثال — ما أعطاني، قال مش
   موجود في وحدة التنظيم الهرموني. وقلت له اشرح لي كأنك تشرح للحمار — ما
   أعطاني شي.»

   وقِيس، فإذا **خمسةٌ من تسع صيغِ متابعةٍ عادية تُرفض** بعتبة الصلة:

     «اشرح لي زي كأنك تشرح للحمار» ٠٫٣٥٨ · «كأنك تشرح لطفل صغير» ٠٫٤٨٧ ·
     «بسّطها لي» ٠٫٢٥٣ · «لخّص لي الكلام» ٠٫٢٧٦ · «أعد الشرح بطريقة
     أسهل» ٠٫٣٣٣ — كلُّها تحت أرضية ٠٫٥٠.

⚖️ **والعلّة في المفهوم لا في الرقم.** العتبةُ تسأل «هل موضوعُ هذا السؤال
   في الوحدة؟» — وطلبُ المتابعة **لا موضوعَ له أصلاً**؛ موضوعُه الجوابُ
   السابق، وذاك اجتاز العتبة حين طُلب. والحكمُ عليه بألفاظه خطأُ تصنيف:
   «للحمار» و«لطفل» و«الكلام» صارت كلماتِ موضوعٍ تُبحث في كتاب الأحياء.
"""
import asyncio

import pytest

from models import AskRequest
from subjects.common import (
    is_followup, has_anaphora, contextual_search_text, off_topic,
    is_continuation_request, book_context, Ranked, WEAK_MATCH_NOTE,
    qa_core, FOLLOWUP_RULES,
    system_prompt_strict_qa, system_prompt_strict_qa_improved,
    system_prompt_strict_explain,
)
from config import RELEVANCE_FLOOR, RELEVANCE_SURE

HISTORY = [{"role": "user", "content": "عرف الغدة النخامية"},
           {"role": "assistant", "content": "الغدة النخامية هي ملكة الغدد..."}]


def _req(content, history=None):
    return AskRequest(subject="احياء", grade=3, track="علمي", mode="سؤال",
                      input_type="برومت", content=content, search_query=content,
                      unit_name="التنظيم الهرموني",
                      chat_history=HISTORY if history is None else history)


# ══════════════ ① ما الذي يُعدّ متابعة ══════════════

@pytest.mark.parametrize("text", [
    "أعطيني مثال", "أعطني مثالاً", "ممكن أمثلة؟",
    "اشرح لي زي كأنك تشرح للحمار",      # نصّ المالك حرفياً
    "اشرح لي كأنك تشرح لطفل صغير",
    "بسّطها لي", "وضّح أكثر", "ليش؟",
    "لخّص لي الكلام", "أعد الشرح بطريقة أسهل",
    "اختصرها", "كمّل", "المزيد",
])
def test_these_are_follow_ups(text):
    assert is_followup(text), text


@pytest.mark.parametrize("text", [
    "ما هي الغدة النخامية؟",
    "اشرح لي الغدة النخامية",           # فعلُ متابعةٍ **ومعه موضوع** ⇒ سؤال
    "اشرح لي وظيفة هرمون الثيروكسين",
    "ما هو الأنسولين؟",
    "قارن بين الغدة النخامية والدرقية",
    "لخّص لي درس الهرمونات النباتية",
])
def test_these_are_real_questions(text):
    assert not is_followup(text), text


@pytest.mark.parametrize("text, terms", [
    ("ما هو النص الأدبي؟", "النص"),          # عربي
    ("ما هو علم الكلام؟", "الكلام"),          # فلسفة
    ("ما هو الدماغ الصغير؟", "الصغير"),       # أحياء
])
def test_a_style_word_in_one_subject_is_a_topic_word_in_another(text, terms):
    """⚠️ **ولا نُسقط كلمةً لأنها تصلح للأسلوب** — «النص» موضوعٌ في العربية،
    و«الكلام» في الفلسفة، و«الصغير» في الأحياء.

    فجملُ الأسلوب تُنزع بنمطٍ سياقيّ ([_STYLE_CLAUSE]) لا بإسقاط الكلمة
    من قائمة المواضيع في كل المواد.
    """
    from subjects.common import query_terms, _normalize_for_search
    assert _normalize_for_search(terms) in query_terms(text)
    assert not is_followup(text)


@pytest.mark.parametrize("text", [
    "Give me an example. In Arabic.",      # ما كُتب في المحاكي حرفياً
    "Simplify it", "Summarize it", "Can you clarify?",
    "Explain again in simple words", "Explain like I am five",
    "Explain it for a kid", "More examples please", "Shorten it please",
    "Explain it like I am a donkey. In Arabic.",   # نصّ المالك مترجَماً
    "Simplify it in simple arabic",
    "اشرح لي كأنك تشرح لطفل صغير. بالعربي",
    "بسّطها بالعربي",
])
def test_the_english_side_counts_too(text):
    """🇬🇧 والطالب يكتب بالإنجليزية — في مادة الإنجليزي وفي غيرها.

    🔴 «Give me an example» رُفضت في المحاكي بعد إصلاح الجانب العربي:
       كلمةُ موضوعها «example»، و«Simplify it» موضوعُها «it».
    """
    assert is_followup(text), text


@pytest.mark.parametrize("text", [
    "What is the pituitary gland?",
    "Explain the pituitary gland in Arabic",
    "What is the past simple tense?",
    "Can you explain photosynthesis?",
])
def test_an_english_question_is_still_a_question(text):
    assert not is_followup(text), text


def test_a_style_clause_stops_at_the_full_stop():
    """⚠️ **علّةٌ قِيست في المحاكي**: «like i am a donkey. in arabic»

    أولُ صيغةٍ للنمط ابتلعت ثلاثَ كلماتٍ بعد «like» فأكلت «in» عابرةً
    النقطة، وتركت «arabic» وحدها — فصارت كلمةَ موضوعٍ ورُفض الطلب.
    فكلُّ نمطِ أسلوبٍ يقف عند علامة الوقف.
    """
    from subjects.common import _STYLE_CLAUSE, _normalize_for_search
    norm = _normalize_for_search("Explain it like I am a donkey. In Arabic.")
    assert "arabic" not in _STYLE_CLAUSE.sub(" ", norm)


@pytest.mark.parametrize("text", [
    "ما هي اللغة العربية؟", "ما هو النحو العربي؟", "ما هو علم الكلام؟",
])
def test_a_language_instruction_is_not_the_language_itself(text):
    """«بالعربي» ظرفٌ، و«اللغة العربية» موضوع — ولا نُسقط الثاني بالأول."""
    assert not is_followup(text), text


def test_a_verb_of_continuation_with_a_topic_is_not_a_follow_up():
    """🎯 الفارقُ الحاسم: «اشرح» ليست متابعةً، «اشرحها» هي."""
    assert not is_followup("اشرح الغدة النخامية")
    assert is_followup("اشرحها")


# ══════════════ ② الاستعارة: شرطان لا واحد ══════════════

def test_a_follow_up_borrows_the_topic():
    built = contextual_search_text("بسّطها لي", HISTORY)
    assert "النخاميه" in built


def test_a_pronoun_question_still_borrows_even_though_it_has_a_topic():
    """⚠️ ولا نستبدل الشرطَ بالآخر — هذا ما أصلحناه في الجولة السابقة.

    «ما الفرق بينها وبين الدرقية» ليست متابعةً (لها موضوع: الدرقية)،
    لكنّ طرفَها الأول ضميرٌ — فتضيع النخامية كلُّها بلا استعارة.
    """
    text = "ما الفرق بينها وبين الغدة الدرقية"
    assert not is_followup(text) and has_anaphora(text)
    assert "النخاميه" in contextual_search_text(text, HISTORY)


def test_a_brand_new_topic_is_not_polluted():
    assert "النخاميه" not in contextual_search_text("ما هو الأنسولين؟", HISTORY)


# ══════════════ ③ المتابعةُ لا تُرفض ══════════════

@pytest.mark.parametrize("text", [
    "أعطيني مثال", "اشرح لي زي كأنك تشرح للحمار", "بسّطها لي",
    "لخّص لي الكلام", "أعد الشرح بطريقة أسهل",
])
def test_a_follow_up_is_never_refused_when_an_answer_precedes_it(text):
    """🚫 مهما انخفضت درجتُه — موضوعُه الجوابُ السابق لا ألفاظُه."""
    below = Ranked(["نص"], [0], best=RELEVANCE_FLOOR - 0.2)
    assert below.verdict == "off"
    assert not off_topic(below, _req(text)), text


def test_no_question_is_refused_once_a_conversation_has_started():
    """🔄 **انقلبت القاعدة (قرار المالك 2026-09-14، بعد ثلاث شكاوى):**
    «دائماً السؤال يروح للمودل. يشوف سياق المحادثة والدرس ويجاوب.»

    والحادثةُ التي حسمته: شرح الموديلُ أن «الأنسولين ينظّم **عمليات
    البناء**»، فسأل الطالب «إيش معنى عمليات البناء؟» — والعبارةُ من
    **جواب الموديل** لا من نصّ الكتاب، فقِيست ٠٫٤٦٦ ورُفضت. والطالب
    يسأل عن كلامٍ قيل له قبل سطرين.

    ⚖️ فالعتبةُ تحرس **البداية** لا المحادثة: أول رسالةٍ لا يُفسّرها
       غيرُ الكتاب، وما بعدها قد يُفسّره الجوابُ السابق.
    """
    below = Ranked(["نص"], [0], best=RELEVANCE_FLOOR - 0.2)
    assert not off_topic(below, _req("ما هو قانون نيوتن الثاني؟"))
    assert not off_topic(below, _req("إيش معنى عمليات البناء؟"))


def test_a_confident_match_still_travels_bare():
    """⚖️ ولا تحفّظَ حيث لا شكّ — وإلا صار التحفّظُ ضجيجاً يُتجاهَل."""
    from subjects.common import WEAK_MATCH_NOTE, NO_MATCH_NOTE
    sure = Ranked(["نص"], [0], best=1.2)
    ctx = book_context(sure, req=_req("ما هي الغدة النخامية؟", history=[]))
    assert WEAK_MATCH_NOTE not in ctx and NO_MATCH_NOTE not in ctx


def test_a_question_about_a_phrase_from_the_previous_answer_reaches_the_model():
    """🧵 الحالةُ بعينها — «عمليات البناء» ليست في الكتاب وهي في الجواب."""
    from subjects import biology
    history = [
        {"role": "user", "content": "اشرح لي عن الأنسولين"},
        {"role": "assistant",
         "content": "الأنسولين هرمونٌ يفرزه البنكرياس وينظّم عمليات البناء في الخلايا."},
    ]
    out = asyncio.run(biology.handle_biology_question(
        _req("إيش معنى عمليات البناء؟", history=history), None))
    assert not (out.get("answer") or "").startswith("🔍")


def test_the_caveat_sends_the_model_to_the_conversation_first():
    """⚠️ ولا يكفي أن يصل الموديل — يجب أن يُقال له **أين يبحث**."""
    from subjects.common import WEAK_MATCH_NOTE
    assert "وردا في جوابك السابق" in WEAK_MATCH_NOTE
    assert "لا تجب من معرفتك العامة" in WEAK_MATCH_NOTE
    # 🔴 والاعتذارُ آخرُ سطرٍ لا أولُه — قِيس أنه كان مخرجاً سهلاً:
    #    «اكتب قانون المقاومة الحثية والسعوية» في وحدتها رُدّ بـ«ليس في
    #    وحدتك»، و«الحثية» و«السعوية» في الوحدة نصّاً.
    assert "اقرأ الصفحات أعلاه كاملةً قبل أن تحكم" in WEAK_MATCH_NOTE
    assert "هي جملةٌ أخيرة لا مخرجٌ سهل" in WEAK_MATCH_NOTE
    assert WEAK_MATCH_NOTE.index("اقرأ الصفحات") < WEAK_MATCH_NOTE.index("ليس في وحدتك")


def test_a_follow_up_with_no_previous_answer_is_not_exempt():
    """🕳️ «بسّطها لي» أولَ رسالةٍ في محادثةٍ فارغة: لا شيء تُبنى عليه."""
    assert not is_continuation_request(_req("بسّطها لي", history=[]))
    below = Ranked(["نص"], [0], best=RELEVANCE_FLOOR - 0.2)
    assert off_topic(below, _req("بسّطها لي", history=[]))


def test_a_follow_up_carries_no_hedge_note():
    """🟡 «قل إن سؤاله ليس ضمن الوحدة» جوابٌ أحمق لمن طلب تبسيطَ ما شُرح له."""
    weak = Ranked(["نص"], [0], best=(RELEVANCE_FLOOR + RELEVANCE_SURE) / 2)
    assert weak.verdict == "weak"
    assert WEAK_MATCH_NOTE not in book_context(weak, req=_req("بسّطها لي"))
    assert WEAK_MATCH_NOTE in book_context(weak, req=_req("ما هو الأنسولين؟"))


# ══════════════ ④ المسارُ كاملاً على محتوًى حقيقي ══════════════

@pytest.mark.parametrize("text", [
    "أعطيني مثال", "اشرح لي زي كأنك تشرح للحمار", "بسّطها لي",
    "لخّص لي الكلام", "أعد الشرح بطريقة أسهل", "وضّح أكثر",
])
def test_the_handler_lets_the_follow_up_through(text):
    """📡 والمعالجُ نفسُه — لا الدوالّ وحدها. (`gemini_client=None` يكفي:
    الرفضُ يقع قبل أي نداء، فبلوغُ الموديل هو الدليل.)"""
    from subjects import biology
    out = asyncio.run(biology.handle_biology_question(_req(text), None))
    assert not (out.get("answer") or "").startswith("🔍"), text


def test_the_intruder_now_reaches_the_model_with_a_sharper_caveat():
    """🔄 **سقط الردُّ الجاهز نهائياً (قرار المالك 2026-09-14، مكرّراً):**
    «يروح يشوف إيش الصفحات، ما حصل شي، يطلع للمودل بدون صفحات ويقول له:
    هذا سيستم برومبت، وهذي الصفحات، وهذا سياق المحادثة.»

    ⚖️ فالعتبةُ لم تعد تردّ أحداً — صارت **تختار ما يُقال للموديل**.
       والثمنُ معلوم: سؤالٌ دخيل يكلّف نداءَ موديل. والمقابلُ أن الطالب
       لا يُصدّ عن سؤالٍ عن كلامٍ قيل له، ولا عن صفحةٍ فاتها البحث.
    """
    from subjects.common import NO_MATCH_NOTE
    far = Ranked(["نص"], [0], best=RELEVANCE_FLOOR - 0.2)
    assert far.verdict == "off"
    ctx = book_context(far, req=_req("ما هو قانون نيوتن الثاني؟", history=[]))
    assert NO_MATCH_NOTE in ctx, "لا تحفّظ — سيؤلّف الموديل"
    assert "لا تجب من معرفتك العامة" in ctx
    assert "المحادثة أعلاه أولاً" in ctx


# ══════════════ ⑤ البرومبت ══════════════

@pytest.mark.parametrize("prompt_of", [
    system_prompt_strict_qa, system_prompt_strict_qa_improved,
    system_prompt_strict_explain,
])
def test_every_answering_prompt_states_the_source_and_the_follow_up_rule(prompt_of):
    """🎓 **أهمُّ نقطة**: الإجابة من المنهج المرفق — ونصُّه ومصطلحاتُه.

    🔴 `system_prompt_strict_qa_improved` لم يكن فيه حرفٌ واحد عن مصدر
       الإجابة، و`system_prompt_strict_qa` كان يأمر بـ«جملة أو جملتين».
    """
    p = prompt_of("احياء")
    assert "نص الكتاب" in p or "الكتاب المعطى" in p, "لا قاعدةَ مصدر"
    assert "طلبُ متابعة" in p, "لا قاعدةَ متابعة"
    assert "جملة أو جملتين" not in p, "عاد سقفُ السطرين"


def test_the_two_question_prompts_share_one_core():
    """⚖️ برومبتان لنيّةٍ واحدة يفترقان — فأيُّ إصلاحٍ يترك أحدَهما."""
    core = qa_core("احياء")
    head = core.split("\n")[0]
    assert head and head in system_prompt_strict_qa("احياء")
    assert head in system_prompt_strict_qa_improved("احياء")


def test_the_prompt_forbids_the_wrong_refusal_on_a_follow_up():
    """⛔ «هذه المعلومة غير متوفرة» ردٌّ خاطئ على «أعطني مثالاً»."""
    assert "لا تقل «هذه المعلومة غير متوفرة»" in FOLLOWUP_RULES
    assert "المعلومة بين يديك" in FOLLOWUP_RULES


def test_the_prompt_keeps_the_book_s_own_terms():
    """📚 «الطالب سيُمتحن بمصطلح كتابه لا بمصطلحك»."""
    p = system_prompt_strict_qa("احياء")
    assert "كما وردت في الكتاب" in p
    assert "لا تُضِف من معرفتك العامة محتوىً جديداً" in p


# ══════════════ ⑥ نبرةُ المحادثة ══════════════
#
# 🔴 **شكوى المالك (2026-09-14):** «نرسل له سؤال متابعة، يرجع يقول لي:
#    أهلاً بك يا ابني في حصتنا الدراسية — خلاص، هذه أول مرة بس.»
#    و«قلت له إيش المسبب للسكر، يشرح لي الأنسولين مدري إيش، بعدين يقول
#    لي: آه، إيش مسببات السكر» — يلفّ حول السؤال ثم يعود إليه.

@pytest.mark.parametrize("prompt_of", [
    system_prompt_strict_qa, system_prompt_strict_qa_improved,
    system_prompt_strict_explain,
])
def test_the_prompt_bans_the_repeated_welcome(prompt_of):
    p = prompt_of("احياء")
    assert "لا تُحيِّ ولا تُقدّم نفسك" in p
    assert "أهلاً بك\nفي حصتنا" in p or "في حصتنا الدراسية" in p, \
        "المثالُ المزعج نفسُه غير مذكور فقد يتكرّر"


@pytest.mark.parametrize("prompt_of", [
    system_prompt_strict_qa, system_prompt_strict_qa_improved,
    system_prompt_strict_explain,
])
def test_the_prompt_demands_the_answer_first(prompt_of):
    """«أوّلُ سطرٍ هو الجواب» — لا تمهيدَ ولا لفٌّ ثم عودة."""
    p = prompt_of("احياء")
    assert "أوّلُ سطرٍ هو الجواب" in p
    assert "والآن نجيب على سؤالك" in p, "الصيغةُ المزعجة نفسُها غير ممنوعة"


def test_the_prompt_asks_for_the_student_s_own_register():
    p = system_prompt_strict_qa("احياء")
    assert "بلغة الطالب ولهجته" in p


# ══════════════ ⑦ شكلُ الجواب ══════════════
#
# 🔴 **شكوى المالك (2026-09-14):** «يشرح كذا مداخل مع بعضه — خله يرتّب
#    الشرح. لما نقول له اشرح لي عن الأنسولين، قوله: حياك الله، اليوم
#    بشرح لك عن الأنسولين، الأنسولين هو كذا… ويرتّبه ويضبطه.»

@pytest.mark.parametrize("prompt_of", [
    system_prompt_strict_qa, system_prompt_strict_qa_improved,
    system_prompt_strict_explain,
])
def test_the_prompt_asks_for_a_structured_answer(prompt_of):
    p = prompt_of("احياء")
    assert "سطرٌ فارغ بين كل فقرتين" in p, "لا قاعدةَ فصلٍ بين الفقرات"
    assert "عنوانٌ فرعيٌّ قصيرٌ بالخط العريض" in p
    assert "نقاطٌ مرقّمة" in p


@pytest.mark.parametrize("prompt_of", [
    system_prompt_strict_qa, system_prompt_strict_qa_improved,
    system_prompt_strict_explain,
])
def test_the_opening_depends_on_what_was_asked(prompt_of):
    """⚖️ افتتاحُ الشرح ودودٌ، وجوابُ السؤال مباشر، والمتابعةُ بلا افتتاح.

    ولا تناقضَ مع «أوّلُ سطرٍ هو الجواب» — تلك للسؤال المباشر وحده.

    🔄 **واشتدّ النهيُ عن العبارة بعينها (2026-09-14):** كان «لا ترحيبَ
       بالحصة، ولا يا ابني» — نهياً وصفياً. وقِيس أن **٨ شروحٍ من ٨** تبدأ
       بـ«أهلاً بك يا بني في حصتنا الدراسية» رغمَه. فصار النهيُ يسرد
       العباراتِ الممنوعة حرفاً بحرف ويقابلها بالمسموح، ويقول «**حتى في أول
       ردّ**» — لأن الموديل كان يقرأ النهيَ مقيّداً بالردود التالية.
    """
    p = prompt_of("احياء")
    assert "حيّاك الله — نشرح اليوم الأنسولين" in p, "مثالُ الافتتاح غائب"
    assert "امضِ مباشرة بلا أي افتتاح" in p
    assert "«أهلاً بك يا بني»" in p and "«يا ابني»" in p
    assert "حتى في أول ردّ" in p


def test_the_explanation_has_a_natural_order():
    p = system_prompt_strict_explain("احياء")
    assert "ما هو ⇐ أين يوجد / من يفرزه ⇐ كيف يعمل" in p
