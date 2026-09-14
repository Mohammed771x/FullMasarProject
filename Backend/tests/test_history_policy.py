"""سياسة سياق المحادثة: سقف دفاعي على ما يصل من العميل + رقم واحد لما يراه الموديل."""
from config import HISTORY_LAST_N, HISTORY_MAX_MESSAGES, HISTORY_MAX_CHARS
from models import AskRequest


def _req(history):
    return AskRequest(
        user_id="u", code="c", subject="فيزياء", mode="شرح", input_type="برومت",
        content="س", chat_history=history,
    )


def test_caps_number_of_messages():
    r = _req([{"role": "user", "content": f"م{i}"} for i in range(40)])
    assert len(r.chat_history) == HISTORY_MAX_MESSAGES
    assert r.chat_history[-1]["content"] == "م39"      # الأحدث يبقى


def test_a_real_answer_is_never_cut():
    """⭐ **انقلبت هذه القاعدة (قرار المالك 2026-09-14).**

    كانت: «رسالةٌ من ٩٠٠٠ حرف تُقصّ عند السقف». وصارت: تمرّ كما هي.
    والسببُ أن ردَّ شرحٍ كامل يبلغ ٨ آلاف حرف، فالقصُّ كان يُسلّم الموديلَ
    **مقدّمة الشرح وحدها** — يسأل الطالب «وضّح الخطوة السابعة» وهو لم
    يرَ إلا الأولى والثانية.
    """
    r = _req([{"role": "assistant", "content": "ب" * 9000}])
    assert len(r.chat_history[0]["content"]) == 9000


def test_the_owner_s_own_number_passes_whole():
    """«حتى كانت ٢٠ ألف حرف» — نصُّ المالك، فليكن اختباراً."""
    r = _req([{"role": "assistant", "content": "ج" * 20000}])
    assert len(r.chat_history[0]["content"]) == 20000


def test_the_wall_still_stands_against_abuse():
    """🛡️ والسقفُ الباقي جدارُ إساءةٍ لا حدُّ محتوى — عشرةُ ميغابايت تُقصّ."""
    r = _req([{"role": "user", "content": "x" * 10_000_000}])
    assert len(r.chat_history[0]["content"]) == HISTORY_MAX_CHARS
    assert HISTORY_MAX_CHARS >= 24000, "الجدارُ نزل حتى صار يقصّ محتوىً حقيقياً"


def test_accepts_both_content_and_text_keys():
    """عملاء أقدم يرسلون المفتاح `text` — يُوحَّد إلى `content`."""
    r = _req([{"role": "user", "text": "بالمفتاح القديم"}])
    assert r.chat_history[0]["content"] == "بالمفتاح القديم"


def test_defensive_cap_is_above_what_model_sees():
    """السقف الدفاعي أوسع من الرقم المستعمل — كي لا يُكسر عميل قديم."""
    assert HISTORY_MAX_MESSAGES >= HISTORY_LAST_N


def test_empty_history_stays_empty():
    assert _req([]).chat_history in ([], None)


def test_single_source_for_the_number():
    """لا رقم مبعثر: كل المعالجات تستورد HISTORY_LAST_N من config."""
    import os, re
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    offenders = []
    for folder in ("subjects", "core"):
        d = os.path.join(root, folder)
        for fname in os.listdir(d):
            if not fname.endswith(".py"):
                continue
            src = open(os.path.join(d, fname), encoding="utf-8").read()
            if re.search(r"history\w*\[-\d+:\]", src, re.I):
                offenders.append(f"{folder}/{fname}")
    assert not offenders, f"رقم مبعثر في: {offenders}"
