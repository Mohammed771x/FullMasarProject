# -*- coding: utf-8 -*-
"""🗣️ **العمودُ الفقري للمحادثة — في كل مادةٍ وكل وضع**.

طلبُ المالك (2026-09-14): «البرومبتات اللي موجودة حالياً في كل المواد، اللوجك
حقها نفسه… نفس الكلام. وبرضه في قسم المعلم نفس الشي، عشان يكون كله نفسه ويكون
التتابع ونفس اللي بنيناه هذا.»

🔴 **وما وجده الفحص:** ثمانيةُ ملفاتٍ أدبية (تاريخ · جغرافيا · مجتمع · علم
   الاجتماع · علم الاقتصاد · فلسفة · منطق · خرائط) كانت تحمل **برومبتاتٍ
   منسوخةً بيدها** تحلّ محلّ المشترك في [pages_mode._system_prompt]، وفيها
   صفرُ قواعدِ مصدرٍ ومتابعةٍ ومحادثةٍ وشكل. ومثلُها: شرحُ العربي، وأوضاعُ
   الإنجليزي الثلاثة، وبرومبتا الرياضيات.

⚠️ **وجردي السابق أعلنها خضراء** لأنه قاس `system_prompt_strict_qa_improved` —
   وهو برومبتٌ **لا يصل هذه المواد أصلاً**. فهذه الاختبارات تقيس البرومبت
   **من المدخل الذي يسلكه الطلب فعلاً** (`_system_prompt`)، لا من دالّةٍ
   نرجو أن تكون هي المستعملة.
"""
import importlib
import inspect
import re

import pytest

from core import lesson_mode, pages_mode, teacher_assistant, teacher_prompts
from subjects.common import (
    CONTINUITY_RULES, CONVERSATION_RULES, FOLLOWUP_RULES, ANSWER_SHAPE_RULES,
    render_rules_once, source_rules, subject_lens, teaching_core, turn_note,
)

# البرومبتُ الذي يصل الموديلَ فعلاً = مدخلُ الوضع، لا دالّةٌ نختارها نحن.
BUILDERS = (lesson_mode._system_prompt, pages_mode._system_prompt)
MODES = ("شرح", "سؤال", "تلخيص")

# المواد ذاتُ الملفات المستقلّة — وهي التي كانت تتخلّف عن المشترك.
OWN_MODULES = ("history", "geography", "society", "sociology",
               "economics", "philosophy", "logic", "cartography")

# العلاماتُ الخمسُ للعمود الفقري + عدسةُ المادة.
SPINE = {
    "مصدر": "مصدرُ الإجابة",
    "متابعة": "طلبُ متابعة",
    "محادثة": "طبيعةُ المحادثة",
    "اتّصال": "موضعُك من الحصة",
    "شكل": "شكلُ الجواب",
    "عدسة": "عدسةُ المادة",
}

ALL_SUBJECTS = ["عربي", "انجليزي", "رياضيات", "فيزياء", "كيمياء", "احياء",
                "تاريخ", "جغرافيا", "مجتمع", "علم الاجتماع", "علم الاقتصاد",
                "فلسفة", "منطق", "مبادئ علم الخرائط"]


# ══════════════ ١️⃣ العمود الفقري في كل مادةٍ وكل وضع ══════════════

@pytest.mark.parametrize("module_name", OWN_MODULES)
@pytest.mark.parametrize("mode", MODES)
@pytest.mark.parametrize("builder", BUILDERS, ids=("دروس", "وحدات"))
def test_own_module_prompts_carry_the_spine(module_name, mode, builder):
    """مادةٌ بملفٍ مستقل تُبنى من نفس العمود — في الأوضاع الثلاثة والوضعين."""
    mod = importlib.import_module(f"subjects.{module_name}")
    prompt = builder(mode, mod.SUBJECT, 3, mod)
    missing = [name for name, mark in SPINE.items() if mark not in prompt]
    assert not missing, f"{mod.SUBJECT} · {mode}: ناقصٌ {missing}"


@pytest.mark.parametrize("subject", ALL_SUBJECTS)
@pytest.mark.parametrize("mode", MODES)
def test_generic_prompts_carry_the_spine(subject, mode):
    """والمسارُ العام (`prompts=None`) — وهو ما يسلكه أكثرُ المواد فعلاً."""
    prompt = lesson_mode._system_prompt(mode, subject, 3, None)
    missing = [name for name, mark in SPINE.items() if mark not in prompt]
    assert not missing, f"{subject} · {mode}: ناقصٌ {missing}"


@pytest.mark.parametrize("module_name", OWN_MODULES)
def test_old_hand_written_qa_prompt_is_gone(module_name):
    """🔴 «الجواب يجب أن يكون مختصراً… لا تعطِ الدرس كاملاً» — الجملةُ التي
    كانت تردّ طلبَ الشرح بسطرين في ثماني مواد."""
    mod = importlib.import_module(f"subjects.{module_name}")
    # البرومبتُ المبنيّ لا نصُّ الملف: التعليقُ فوق الدالّة يقتبس الجملةَ
    # القديمة عمداً ليبقى سببُ الحذف مقروءاً لمن يقرأ الملف بعدنا.
    prompt = mod.prompt_qa()
    assert "الجواب يجب أن يكون مختصراً وواضحاً" not in prompt
    assert "لا تعطِ الدرس كاملاً" not in prompt
    assert "لا تضف معلومات إضافية لم يطلبها" not in prompt


def test_every_subject_has_its_own_lens():
    """«لكل مادة اللوجك اللي فيها يختلف» — عدسةٌ لكل مادةٍ في المنهج،
    ولا عدستين متطابقتين."""
    lenses = {s: subject_lens(s) for s in ALL_SUBJECTS}
    missing = [s for s, v in lenses.items() if not v.strip()]
    assert not missing, f"بلا عدسة: {missing}"
    bodies = list(lenses.values())
    assert len(set(bodies)) == len(bodies), "عدستان متطابقتان — نسخٌ لا تخصيص"


def test_spine_is_one_source_not_fourteen():
    """`teaching_core` تجمع الخمسةَ فعلاً — فإصلاحُ أيٍّ منها يصل الجميع."""
    core = teaching_core("احياء")
    for part in (source_rules("احياء"), FOLLOWUP_RULES, CONVERSATION_RULES,
                 CONTINUITY_RULES, ANSWER_SHAPE_RULES, subject_lens("احياء")):
        assert part in core


# ══════════════ ٢️⃣ «الرسائل السابقة سياقٌ لا قائمةُ مهامّ» ══════════════

def test_continuity_rule_names_the_owner_case():
    """حالةُ المالك نفسُها مكتوبةٌ في القاعدة — لأن المثالَ الملموس يُمتثَل
    له أكثرُ من قاعدةٍ مجرّدة (نفس درس [draw_reminder])."""
    assert "ترجيح المعية" in CONTINUITY_RULES
    assert "آخرَ طلبٍ وحده" in CONTINUITY_RULES
    assert "ما شرحتَه لا يُعاد" in CONTINUITY_RULES


def test_teacher_core_carries_the_same_rule():
    """وقسمُ المعلّم يقولها بلغته — الحالةُ التي شكا منها المالك كانت فيه."""
    core = teacher_prompts.SYSTEM_CORE
    assert "لا قائمةُ مهامّ تُنفَّذ" in core
    assert "ترجيح المعية" in core
    assert "آخرَ طلبٍ للأستاذ وحده" in core


def test_teacher_turn_state_repeats_it_at_the_last_message():
    """وتُكرَّر في حالة الدور — آخرُ ما يقرؤه الموديل."""
    note = teacher_assistant.turn_state(
        [{"role": "user"}, {"role": "assistant"}], is_generate=False)
    assert "آخر طلبٍ للأستاذ وحده" in note
    first = teacher_assistant.turn_state([], is_generate=False)
    assert "أول رسالة" in first and "آخر طلبٍ" not in first


@pytest.mark.parametrize("n,expected", [(2, "تبادلٌ واحد"), (4, "تبادلان"),
                                        (6, "٣ تبادلات"), (26, "١٣ تبادلاً")])
def test_teacher_turn_label_is_arabic(n, expected):
    """«سبقها نحو 2 تبادلاً» كان رقماً لاتينياً وتمييزاً خاطئاً — والموديلُ
    يقلّد لغةَ ما يقرؤه."""
    assert expected in teacher_assistant.turn_state([{"role": "user"}] * n, False)


# ══════════════ ٣️⃣ موضعُ الطلب من الحصة يصل الموديل ══════════════

class _Req:
    def __init__(self, history=None):
        self.chat_history = history or []


def test_turn_note_first_turn_asks_for_a_full_explanation():
    note = turn_note(_Req())
    assert "أوّلُ طلبٍ" in note and "وافياً" in note


def test_turn_note_followup_forbids_repeating():
    note = turn_note(_Req([{"role": "user", "content": "س"},
                           {"role": "assistant", "content": "ج"}]))
    assert "متابعة" in note
    assert "هذا الطلب وحده" in note
    assert "ردٌّ واحد" in note          # تمييزُ العدد بالعربية


def test_turn_note_counts_answers_not_messages():
    """العبرةُ بعدد ردودك لا بعدد الرسائل — رسالةُ طالبٍ بلا ردٍّ بعدُ ليست
    دوراً سابقاً."""
    assert "أوّلُ طلبٍ" in turn_note(_Req([{"role": "user", "content": "س"}]))


def test_turn_note_ignores_malformed_history():
    """سجلٌّ فيه عناصرُ ليست قواميس أو بأدوارٍ غريبة لا يُسقط النداء."""
    assert turn_note(_Req(["نص", {"role": "system"}, None]))
    assert turn_note(None if False else _Req(None))


@pytest.mark.parametrize("mode", MODES)
def test_lesson_mode_user_message_carries_the_turn_note(mode):
    msg = lesson_mode._user_message(mode, "نصُّ الدرس", "اشرح", _Req())
    assert "أوّلُ طلبٍ" in msg
    follow = lesson_mode._user_message(
        mode, "نصُّ الدرس", "بسّطها",
        _Req([{"role": "assistant", "content": "ج"}]))
    assert "هذا الطلب وحده" in follow


def test_pages_mode_appends_the_turn_note_on_both_paths():
    """مسارُ الصفحات ومسارُ البحث كلاهما — لا أحدُهما ([sweep-siblings])."""
    src = inspect.getsource(pages_mode.handle)
    assert src.count("turn_note(req)") == 2


@pytest.mark.parametrize("module_name,expected", [
    ("arabic", 3), ("biology", 5), ("chemistry", 3),
    ("physics", 3), ("english", 3), ("math", 2),
])
def test_legacy_handlers_append_the_turn_note(module_name, expected):
    """ومعالجاتُ المواد القديمة تبني رسائلها بالحرف — فنعدُّ المواضع.

    ⚠️ عدٌّ لا `in`: كان يكفي موضعٌ واحدٌ لتخضرّ المادة كلُّها، بينما
       للأحياء وحدها خمسةُ مواضع في ثلاثة أوضاع.
    """
    src = inspect.getsource(importlib.import_module(f"subjects.{module_name}"))
    assert src.count("turn_note(req)") == expected


# ══════════════ ٤️⃣ التلخيصُ محادثةٌ أيضاً ══════════════

@pytest.mark.parametrize("module_name,func", [
    ("biology", "handle_biology_summary"),
    ("english", "handle_english_summary"),
])
def test_summary_handlers_send_the_history(module_name, func):
    """🔴 مسارا تلخيصٍ كانا يبنيان الرسائل بلا سجلّ، فـ«اختصره أكثر» تلخيصٌ
    من الصفر لا اختصارٌ لما سبق."""
    mod = importlib.import_module(f"subjects.{module_name}")
    src = inspect.getsource(getattr(mod, func))
    assert "chat_history" in src or "_recent_history" in src


# ══════════════ ٥️⃣ لا تكرارَ لقواعد الرسّام ══════════════

@pytest.mark.parametrize("subject", ["كيمياء", "منطق", "رياضيات", "فيزياء"])
def test_render_rules_are_not_appended_twice(subject):
    """برومبتُ المادة صار يحمل قواعدَ الرسّام في ذيله، فالإلحاقُ الأعمى كان
    يكرّرها — آلافَ حروفٍ مكرّرة في كل نداء."""
    from subjects.common import system_prompt_strict_explain, organic_structure_rules
    base = system_prompt_strict_explain(subject)
    assert render_rules_once(base, subject) == "", "أُلحقت مرّتين"
    organic = organic_structure_rules(subject)
    if organic:
        assert base.count(organic) == 1


@pytest.mark.parametrize("module_name", OWN_MODULES)
@pytest.mark.parametrize("mode", MODES)
def test_own_module_prompt_has_no_duplicated_render_block(module_name, mode):
    mod = importlib.import_module(f"subjects.{module_name}")
    prompt = pages_mode._system_prompt(mode, mod.SUBJECT, 3, mod)
    from subjects.common import arabic_digits_rules
    digits = arabic_digits_rules(mod.SUBJECT)
    if digits:
        assert prompt.count(digits) == 1, "قاعدةُ الأرقام مكرّرة"


# ══════════════ ٦️⃣ دورُ المساعد يصل الموديل أصلاً ══════════════
#
# ☢️ **أخطرُ ما كشفه هذا الفحص**: التطبيق يرسل ردَّ المساعد بالدور "ai"،
#    والخادمُ يُصفّي `role in ("user","assistant")` في كل معالج — فكانت ردودُ
#    المساعد **تُحذف كلُّها** ولا يرى الموديلُ إلا أسئلةَ الطالب متتاليةً.
#    وهذا سببُ «يحسب إن الرسائل الست ضروري تنشرح» وسببُ اعتذاره عن «أعطني
#    مثالاً»: جوابُه السابق لم يكن أمامه قطّ. واختباراتُنا كانت تمرّ لأننا
#    نرسل "assistant" بأيدينا — ولا يفعل التطبيق.

from models import AskRequest, TeacherAskRequest, normalize_history


def _ask(**kw):
    base = dict(subject="عربي", mode="شرح", input_type="برومت", content="س")
    base.update(kw)
    return AskRequest(**base)


@pytest.mark.parametrize("raw", ["ai", "AI", " Ai ", "bot", "model", "assistant"])
def test_assistant_aliases_become_assistant(raw):
    req = _ask(chat_history=[{"role": raw, "text": "جوابي السابق"}])
    assert req.chat_history[0]["role"] == "assistant"
    assert req.chat_history[0]["content"] == "جوابي السابق"


@pytest.mark.parametrize("raw", ["user", "human", "student", "ME"])
def test_user_aliases_become_user(raw):
    req = _ask(chat_history=[{"role": raw, "content": "سؤالي"}])
    assert req.chat_history[0]["role"] == "user"


def test_unknown_role_is_not_promoted_to_assistant():
    """لا نضع كلاماً مجهولَ المصدر في فم الموديل — يبقى كما هو فيُسقطه
    المستهلكون كما كانوا."""
    req = _ask(chat_history=[{"role": "نظام", "content": "x"}])
    assert req.chat_history[0]["role"] == "نظام"


def test_teacher_request_normalizes_too():
    """وقسمُ المعلّم كان يقع فيه نفسُ العطب — وهو موضعُ شكوى المالك."""
    req = TeacherAskRequest(tool="ask", subject="عربي", content="س",
                            chat_history=[{"role": "ai", "text": "ج"}])
    assert req.chat_history[0]["role"] == "assistant"


def test_prior_answer_guard_now_sees_the_app_history():
    """[common.has_prior_answer] كانت تعود False دائماً في التطبيق الحقيقي
    — فيعمل حارسُ المتابعة عندنا ويسقط عند الطالب."""
    from subjects.common import has_prior_answer
    req = _ask(content="أعطني مثالاً",
               chat_history=[{"role": "user", "text": "ما الغدة النخامية؟"},
                             {"role": "ai", "text": "الغدة النخامية هي…"}])
    assert has_prior_answer(req) is True


def test_turn_note_sees_the_app_history_too():
    """وكذلك موضعُ الطلب من الحصة: كان كلُّ طلبٍ «أوّلَ طلب»."""
    req = _ask(chat_history=[{"role": "user", "text": "س"},
                             {"role": "ai", "text": "ج"}])
    assert "متابعة" in turn_note(req)


def test_normalize_history_tolerates_junk():
    assert normalize_history(None) is None
    assert normalize_history([]) == []
    out = normalize_history([{"role": "ai"}, {"content": "بلا دور"}])
    assert out[0] == {"role": "assistant", "content": ""}
    assert out[1]["role"] == ""


# ══════════════ ٧️⃣ التقريبُ المسموح — مثالٌ من الحياة بشروطه ══════════════
#
# ⚖️ **قرار المالك (2026-09-14):** «خله الإنجليزي يقدر يضيف أمثلة من برا، وكل
#    المواد برضو — بس محصورة على شي… بحيث إنه يدعم النقطة ذي ويوضحها أكثر،
#    ما تكون علمية كذا. طبعاً في الشرح يلتزم باللي موجود.»
#
# 🎯 والحدُّ الذي تفحصه هذه الاختبارات: **ما يُمتحن فيه الطالب مقفلٌ على
#    الكتاب، وما يُفهَم به قد يأتي من الحياة.**

from subjects.common import SUPPORT_EXAMPLE_RULES


@pytest.mark.parametrize("subject", ALL_SUBJECTS)
@pytest.mark.parametrize("mode", MODES)
def test_support_example_rule_reaches_every_subject_and_mode(subject, mode):
    prompt = lesson_mode._system_prompt(mode, subject, 3, None)
    assert "التقريبُ المسموح" in prompt, f"{subject} · {mode}"


@pytest.mark.parametrize("module_name", OWN_MODULES)
@pytest.mark.parametrize("mode", MODES)
def test_support_example_rule_reaches_own_modules(module_name, mode):
    mod = importlib.import_module(f"subjects.{module_name}")
    prompt = pages_mode._system_prompt(mode, mod.SUBJECT, 3, mod)
    assert "التقريبُ المسموح" in prompt


def test_math_gets_it_even_though_it_skips_source_rules():
    """الرياضياتُ لا تمرّ بـ`source_rules` عمداً، فلو عُلّق الاستثناءُ بها
    وحدها لسقط عن الرياضيات — وقد طلبه المالك **في كل المواد**."""
    from subjects.math import system_prompt_math_explain
    from subjects.common import source_rules
    p = system_prompt_math_explain()
    assert SUPPORT_EXAMPLE_RULES in p
    assert source_rules("رياضيات") not in p


def test_the_four_conditions_are_all_stated():
    """إذنٌ مفتوح جُرِّب وسقط: «بإمكانك اضافة معلومات خارجية تدعم الشرح» في
    برومبت الإنجليزي — جملةٌ بلا سقف. فالشروطُ هي الفرقُ بين تقريبٍ وإضافة."""
    for mark in ("من الحياة لا من العلم",     # ① لا محتوى علمي جديد
                 "يخدم نقطةً في النصّ",        # ② لا يفتح موضوعاً
                 "مُعلَّمٌ صراحةً",             # ③ الطالب يعرف أنه ليس للامتحان
                 "سطرٌ أو سطران",              # ④ قصير
                 "أمثلةُ الكتاب أوّلاً"):       # ⛔ الأولوية للكتاب
        assert mark in SUPPORT_EXAMPLE_RULES, mark


@pytest.mark.parametrize("subject", ALL_SUBJECTS)
def test_the_content_lock_survived_the_exception(subject):
    """⚠️ الاستثناءُ **لم يفتح** المحتوى: التعريفُ والقانونُ والرقمُ
    والمصطلحُ والتصنيف تبقى مقفلةً على النصّ كما كانت."""
    if subject == "رياضيات":
        pytest.skip("الرياضيات بلا `source_rules` عمداً — قيدُها طريقةُ الحل")
    prompt = lesson_mode._system_prompt("سؤال", subject, 3, None)
    assert "لا تُضِف من معرفتك العامة محتوىً جديداً" in prompt
    assert "لا مصطلحَ جديداً" in prompt          # داخل شرط ① نفسِه
    assert "والشرحُ نفسُه يلتزم بالموجود حرفاً" in prompt


def test_followup_example_rule_no_longer_contradicts_it():
    """🔴 كانت `FOLLOWUP_RULES` تقول «المثالُ… لا من خارجهما» — وهو نقيضُ
    الاستثناء الجديد. وقاعدتان متضاربتان في برومبتٍ واحد أسوأُ من غيابهما."""
    assert "لا من خارجهما" not in FOLLOWUP_RULES
    assert "بشروط «التقريب المسموح»" in FOLLOWUP_RULES


def test_english_keeps_its_extra_sentences_allowance():
    """السطرُ الذي طلب المالك إعادته — **مضبوطاً** هذه المرة."""
    import subjects.english as E
    p = E.system_prompt_English_explain("انجليزي")
    assert "توسعةُ الأمثلة في الإنجليزي" in p
    assert "القاعدةُ نفسُها لا قاعدةٌ أخرى" in p
    assert "مثالٌ إضافيٌّ من عندي" in p
    assert "تُضاف بعدها" in p
    # والصياغةُ المفتوحة القديمة لا تعود
    assert "بإمكانك اضافة معلومات خارجية" not in p


# ══════════════ ٨️⃣ وضعُ السؤال يحتاج سؤالاً ══════════════
#
# ⚖️ **قرار المالك (2026-09-14):** «في خانة السؤال ضروري الطالب يكتب سؤال.
#    السؤال حطّيته إجابةً لشيءٍ معيّن — عرّف لي الغدة النخامية، يعرّفها
#    بسطرين ثلاثة. السؤالُ ليس الذي يشرح الدرس… في كل المواد.»

from subjects.common import question_needs_text, question_required_response


@pytest.mark.parametrize("content", ["", "   ", "\n\t "])
def test_question_mode_without_text_is_refused(content):
    assert question_needs_text(_ask(mode="سؤال", content=content)) is True


def test_question_mode_with_text_passes():
    assert question_needs_text(_ask(mode="سؤال", content="عرّف الغدة النخامية")) is False


@pytest.mark.parametrize("mode", ["شرح", "تلخيص", "وزاري"])
def test_other_modes_keep_the_empty_send(mode):
    """القيدُ على وضع السؤال وحده: «اضغط إرسال مباشرة لشرح الدرس» وعدٌ قائم."""
    assert question_needs_text(_ask(mode=mode, content="")) is False


def test_the_guard_sits_on_the_single_funnel_for_both_routes():
    """`/ask` و`/ask/stream` يمرّان بـ`_dispatch_subject` — فموضعٌ واحد يكفي.

    ⚠️ ولو وُضع في المعالجات لكانت ستّةَ عشرَ موضعاً، وقد سبق أن نُسي
       واحدٌ منها فعلاً ([sweep-siblings-before-reporting]).
    """
    import api
    src = inspect.getsource(api._dispatch_subject)
    assert "question_needs_text" in src
    # وقبل نداء أي معالج
    assert src.index("question_needs_text") < src.index("NEW_SUBJECT_HANDLERS")


def test_the_refusal_costs_no_quota_and_leaves_no_dangling_question():
    """بلا نداءِ موديل ⇒ لا خصم ([core/billing.was_free])؛ و`off_topic`
    تُسقط الطلبَ من السجلّ فلا يحاول الموديل إكماله في الدور التالي."""
    from core import billing
    out = question_required_response()
    assert out["off_topic"] is True
    assert out["references"] == []
    meter = billing.start()
    assert billing.was_free(meter) is True
    billing.clear()


def test_the_message_tells_the_student_what_to_do():
    body = question_required_response()["answer"]
    assert "اكتب سؤالك" in body
    assert "شرح" in body          # يدلّه على الوضع الآخر
    assert "الغدة النخامية" in body   # مثالٌ ملموس لا وصفٌ مجرّد


def test_image_only_question_still_passes():
    """نصُّ الصورة يُدمج في `content` قبل التوجيه، فالسؤالُ المصوَّر يمرّ."""
    req = _ask(mode="سؤال", content="")
    req.content = "ما الموضّح في الصورة؟ [نصّ الصورة: تركيب الخلية]"
    assert question_needs_text(req) is False


@pytest.mark.parametrize("subject", ALL_SUBJECTS)
def test_question_prompt_asks_for_a_short_answer(subject):
    """«عرّفها تعريف بس بسطرين ثلاثة سطور» — والفرقُ عن وضع الشرح مكتوب."""
    p = lesson_mode._system_prompt("سؤال", subject, 3, None)
    assert "وضع «السؤال» لا وضع «الشرح»" in p
    assert "في سطرين أو ثلاثة" in p
    assert "ولا تسرد الدرس" in p
