# -*- coding: utf-8 -*-
"""👋 الرسائل التي ليست أسئلةَ منهج — تحيةٌ وشكرٌ وسؤالٌ عن الأداة.

🔴 **شكوى المالك (2026-09-14):** «لما قلت له السلام عليكم، يقول لي:
   ماشي، لم أجد هذه المعلومة.»

   وهي نتيجةٌ **منطقية** لعتبة الصلة: «السلام عليكم» ليست في كتاب
   الأحياء، فتُقاس صلتُها بالوحدة وتُرفض. لكنّ السؤال الصحيح لم يكن «هل
   هذا في الوحدة؟» بل **«هل هذا سؤالُ منهجٍ أصلاً؟»** — وهذه طبقةٌ قبل
   البحث لا عتبةٌ أشدّ ولا أرخى.

⭐ وردٌّ جاهزٌ بلا نداءِ موديل: التحيةُ جوابُها معروفٌ سلفاً، ونداءُ موديلٍ
   لها يكلّف الطالبَ سؤالاً من حصّته وينتظر ثوانيَ بلا سبب.
"""
import pytest

from core import smalltalk
from models import AskRequest


def _req(content, subject="احياء", grade=3, track="علمي", unit="التنظيم الهرموني"):
    return AskRequest(subject=subject, grade=grade, track=track, mode="سؤال",
                      input_type="برومت", content=content, unit_name=unit,
                      chat_history=[])


# ══════════════ ① ما يُعدّ رسالةً اجتماعية ══════════════

@pytest.mark.parametrize("text, intent", [
    ("السلام عليكم", "salam"),
    ("السلام عليكم ورحمة الله وبركاته", "salam"),
    ("سلام", "salam"),
    ("صباح الخير", "morning"),
    ("مساء الخير", "evening"),
    ("مرحبا", "greet"), ("هلا", "greet"), ("hello", "greet"),
    ("كيف حالك؟", "how_are_you"),
    ("شكرا", "thanks"), ("مشكور يا استاذ", "thanks"), ("thanks", "thanks"),
    ("تمام", "ack"), ("اوك", "ack"), ("ok", "ack"), ("ماشي", "ack"),
    ("مع السلامة", "bye"),
    ("من أنت؟", "identity"), ("ما اسمك؟", "identity"),
    ("ايش تقدر تسوي؟", "help"), ("وش تسوي؟", "help"),
])
def test_a_social_message_is_recognised(text, intent):
    assert smalltalk.intent_of(text) == intent, text


@pytest.mark.parametrize("text", [
    "السلام عليكم، ما هي الغدة النخامية؟",   # تحيةٌ **ثم سؤال**
    "ما هي الغدة النخامية؟",
    "من هو المتنبي؟",                        # «من» ليست «من أنت»
    "من أين تفرز الهرمونات؟",
    "من المسؤول عن التنسيق بين الأجهزة؟",
    "بسّطها لي",                              # متابعةٌ لا تحية
    "اشرح الدرس",
    "",
])
def test_a_curriculum_message_passes_through(text):
    assert smalltalk.intent_of(text) is None, text


def test_arabic_punctuation_does_not_hide_the_intent():
    """🔴 نفسُ علّة «؟» داخل نطاق الحروف `؀-ۿ` التي كلّفت نصفَ المطابقة.

    «من أنت؟» كانت تُنظَّف إلى «من انت؟» فلا تطابق «من انت».
    """
    assert smalltalk.intent_of("من أنت؟") == "identity"
    assert smalltalk.intent_of("شكراً!") == "thanks"
    assert smalltalk.intent_of("تمام.") == "ack"


# ══════════════ ② الردّ نفسُه ══════════════

def test_the_greeting_is_mirrored_not_generic():
    """⭐ «السلام عليكم» تُردّ بمثلها — لا بـ«أهلاً» عامة."""
    assert "وعليكم السلام ورحمة الله وبركاته" in \
        smalltalk.reply_for(_req("السلام عليكم"))["answer"]
    assert "صباح النور" in smalltalk.reply_for(_req("صباح الخير"))["answer"]
    assert "مساء النور" in smalltalk.reply_for(_req("مساء الخير"))["answer"]


def test_the_reply_names_where_the_student_is():
    out = smalltalk.reply_for(_req("السلام عليكم"))["answer"]
    assert "احياء" in out and "التنظيم الهرموني" in out


def test_a_unit_of_all_is_not_shown_as_a_unit_name():
    out = smalltalk.reply_for(_req("مرحبا", unit="الكل"))["answer"]
    assert "«الكل»" not in out


def test_the_reply_carries_no_references_and_leaves_no_session():
    out = smalltalk.reply_for(_req("شكرا"))
    assert out["references"] == [] and out["session_active"] is False


def test_the_greeting_stays_out_of_the_history_sent_to_the_model():
    """🗣️ تحيةٌ وردُّها ليسا درساً — ووجودُهما في السياق يشغل مكاناً بلا فائدة."""
    assert smalltalk.reply_for(_req("مرحبا"))["off_topic"] is True


def test_a_subject_with_no_content_is_not_welcomed():
    """⚖️ ولا نرحّب بطالبٍ في حصةٍ فارغة ثم نصدمه بـ«قيد الإضافة»."""
    assert smalltalk.reply_for(
        _req("مرحبا", subject="رياضيات", grade=2, track="علمي", unit="")) is None


# ══════════════ ③ وموضعُ الحارس واحد ══════════════

def test_the_gate_sits_after_the_curriculum_check_and_before_the_handlers():
    """🔒 موضعٌ واحد يغطّي المواد الستّ والأوضاع الأربعة.

    ⚖️ و**بعد** بوابة المنهج لا قبلها: مادةٌ غير مقرّرة على الصف لا
       تُرحَّب بالطالب فيها.
    """
    import os
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src = open(os.path.join(root, "api.py"), encoding="utf-8").read()
    assert src.count("v3_smalltalk.reply_for(") == 1, "أكثرُ من موضع — أحدُهما يُنسى"
    body = src.split("async def _dispatch_subject")[1]
    assert body.index("is_valid_subject") < body.index("v3_smalltalk.reply_for"), \
        "التحيةُ تسبق بوابة المنهج"


def test_a_greeting_costs_no_model_call():
    """💰 ردٌّ جاهز ⇒ العدّاد صفر ⇒ تُردّ الحصة ([core/billing.py])."""
    from core import billing
    meter = billing.start()
    assert smalltalk.reply_for(_req("السلام عليكم")) is not None
    assert billing.was_free(meter)
    billing.clear()
