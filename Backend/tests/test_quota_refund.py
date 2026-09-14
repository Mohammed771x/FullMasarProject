# -*- coding: utf-8 -*-
"""🧾 «خلّ الرفض ما يخصم من الحصة» (نصّ المالك 2026-09-14).

الحصة تُخصم **قبل** المعالج — وهذا صحيح: الخصمُ بعد الجواب يفتح السباق
الذي أُغلق بمعاملةٍ في [core/quota.py]. لكن بعض الردود لا تُنادي موديلاً
أصلاً، فالطالب كان يدفع ثمن لا شيء.

⚖️ والقاعدة عدّادٌ لا وسم: **ما لم يُنادَ موديلٌ، لا يُخصم**. لأن مسارات
   المواد فيها عشراتُ الخروجات المبكّرة، ووسمُها واحدةً واحدة يعني موضعاً
   يُنسى اليوم وموضعاً يُضاف غداً بلا وسم.
"""
import asyncio

import pytest

from core import billing, quota


@pytest.fixture(autouse=True)
def _clean():
    quota.reset_memory()
    billing.clear()
    yield
    quota.reset_memory()
    billing.clear()


# ══════════════ ① العدّاد نفسُه ══════════════

def test_a_request_that_called_no_model_is_free():
    meter = billing.start()
    assert billing.was_free(meter)


def test_one_model_call_makes_it_billable():
    meter = billing.start()
    billing.charge()
    assert not billing.was_free(meter)


def test_reading_an_image_counts_even_if_the_answer_is_refused():
    """📷 قراءةُ الصورة نداءٌ مدفوع — والرفضُ بعدها لا يجعل الطلب مجانياً."""
    meter = billing.start()
    billing.charge("vision")
    assert not billing.was_free(meter)
    assert meter["vision_calls"] == 1


def test_no_meter_means_no_refund():
    """خارج مسار السؤال لا عدّاد — ولا نردّ حصةً بالصدفة."""
    billing.clear()
    assert not billing.was_free(billing.current())


def test_the_meter_survives_the_child_task_of_the_streaming_path():
    """🧵 **العلّةُ التي جعلت العدّاد كائناً لا رقماً.**

    مسارُ البثّ ينفّذ المعالج في `asyncio.create_task`، والمهمةُ الوليدة
    ترث **نسخةً** من السياق: أيُّ `set()` بداخلها لا يراه الأب. وتعديلُ
    كائنٍ ورثت الوليدةُ إشارتَه يراه الطرفان.
    """
    async def _scenario():
        meter = billing.start()
        await asyncio.create_task(_child())
        return meter

    async def _child():
        billing.charge()

    meter = asyncio.run(_scenario())
    assert not billing.was_free(meter), "الشحنُ داخل المهمة الوليدة لم يصل الأب"


# ══════════════ ② الردّ نفسُه ══════════════

UID = "student-refund-test"


def test_a_refund_gives_the_question_back():
    before = quota.peek(UID)
    allowed, _r = quota.check_and_consume(UID)
    assert allowed and quota.peek(UID) == before - 1
    quota.refund(UID)
    assert quota.peek(UID) == before


def test_a_refund_never_pushes_the_counter_below_zero():
    """🛡️ نداءٌ مكرَّر أو ردٌّ بلا خصمٍ سابق لا يمنح الطالب رصيداً."""
    limit = quota.limit_for(False, UID)
    for _ in range(5):
        quota.refund(UID)
    assert quota.peek(UID) == limit


def test_a_refunded_question_can_be_asked_again():
    """والرصيدُ المردود صالحٌ فعلاً لا رقمٌ في الواجهة."""
    limit = quota.limit_for(False, UID)
    for _ in range(limit):
        assert quota.check_and_consume(UID)[0]
    assert not quota.check_and_consume(UID)[0], "الجدار لم يقم أصلاً"
    quota.refund(UID)
    assert quota.check_and_consume(UID)[0], "الردُّ لم يفتح سؤالاً حقيقياً"


# ══════════════ ③ المسارُ كاملاً ══════════════

def test_the_dispatch_settles_the_quota_in_one_place():
    """🔒 مسارا السؤال (عاديّ وبثّ) يمرّان من `_dispatch_and_settle` وحدها.

    نسخُ الردّ في كلٍّ منهما كان يعني مساراً يُنسى — وهو بالضبط ما وقع
    بحرّاس الوحدة في أربعة مسارات.
    """
    import os, re
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src = open(os.path.join(root, "api.py"), encoding="utf-8").read()
    direct = [line.strip() for line in src.split("\n")
              if re.search(r"await _dispatch_ask\(req\)", line)
              and "_dispatch_and_settle" not in line
              and not line.lstrip().startswith("#")]
    assert len(direct) == 1, \
        f"نداءُ توزيعٍ خارج التسوية: {direct}"
    assert "await _dispatch_ask(req)" in src.split("_dispatch_and_settle")[1]


def test_every_model_call_on_the_ask_path_passes_the_meter():
    """🧾 ولا نداءَ موديلٍ يفوت العدّاد — وإلا رُدَّت حصةٌ عن طلبٍ كلّفنا.

    كلُّ معالجات المواد تنادي [core/streaming.complete]، وهي وحدها التي
    تشحن. من ينادي المزوّد مباشرةً يلتفّ على المحاسبة.
    """
    import os, re
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    offenders = []
    for folder in ("subjects", "core"):
        base = os.path.join(root, folder)
        for name in sorted(os.listdir(base)):
            if not name.endswith(".py") or name in ("streaming.py", "vision.py"):
                continue
            path = os.path.join(base, name)
            for i, line in enumerate(open(path, encoding="utf-8").read().split("\n")):
                if line.lstrip().startswith("#"):
                    continue
                if re.search(r"\bclient\.chat\.completions\.create\(", line):
                    offenders.append(f"{folder}/{name}:{i + 1}")
    # مساراتٌ أخرى لها حصّتُها الخاصة (اختبر نفسك · المعلّم · تنظيف الصوت
    # · الاستيعاب) — تُستثنى صراحةً كي لا يمرّ جديدٌ بصمت.
    known = {"core/quiz.py", "core/teacher_assistant.py", "core/voice_clean.py",
             "core/ingest.py"}
    surprises = [o for o in offenders if o.rsplit(":", 1)[0] not in known]
    assert not surprises, f"نداءُ موديلٍ يلتفّ على العدّاد: {surprises}"


def test_the_client_is_told_when_the_question_was_given_back():
    """📣 التطبيق يُنقص عدّاده محلياً فور نجاح السؤال.

    فبلا رايةٍ في الردّ يرى الطالب رقماً **أقلّ من الحقيقة** حتى يُعيد فتح
    التطبيق — وقد رُئي حرفياً في المحاكي: الخادم ردَّ السؤال وبقي الشريط
    يعرض ٥٠ حتى الإقلاع التالي فعاد ٥١.
    """
    import os, re
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src = open(os.path.join(root, "api.py"), encoding="utf-8").read()
    settle = src.split("async def _dispatch_and_settle")[1].split("\n@app")[0]
    assert "arefund" in settle
    assert '"quota_refunded"' in settle, "الردُّ يقع ولا يُخبر العميل"

    app_root = os.path.join(os.path.dirname(root), "frontendappversion")
    ctrl = os.path.join(app_root, "lib", "features", "chat", "presentation",
                        "controllers", "chat_controller.dart")
    if not os.path.isfile(ctrl):
        pytest.skip("مجلد التطبيق غير موجود بجوار الخادم")
    dart = open(ctrl, encoding="utf-8").read()
    assert "quotaRefunded" in dart, "التطبيق لا يقرأ الراية فيُنقص عدّاده خطأً"
