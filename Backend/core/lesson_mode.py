# ==================================================
# 📖 core/lesson_mode.py — وضع الدروس (بلا embeddings)
# ==================================================
# الطالب يختار الوحدة ← الدرس، والدرس **كاملاً** يُحقن في البرومبت.
# لا تشفير، لا FAISS، لا استرجاع — أدق وأرخص وأسرع.
#
# يعمل مع أي مادة وأي صيغة ملف بفضل المُسلسِل العام (serializer.to_text).
# نفس أسلوب استدعاء الموديلات الحالي حرفياً:
#   asyncio.wait_for(client.chat.completions.create(...), timeout=50)

import asyncio
import re

from . import streaming

from subjects.common import (
    system_prompt_strict_explain,
    system_prompt_strict_summary,
    system_prompt_strict_qa_improved,
    strip_stray_latex,
    render_rules,
    render_rules_once,
    turn_note,
    draw_reminder,
    DRAW_CODES,
)
from . import lesson_cache
from .content_store import get_lessons_book, find_lesson
from .serializer import serialize_lesson
from .curriculum import model_route, call_budget, reasoning_kwargs

_AI_TIMEOUT = 50      # نفس مهلة المعالجات الحالية
_MAX_TOKENS = 4000
from config import HISTORY_LAST_N as _HISTORY_LAST_N   # مصدر واحد للرقم


def _system_prompt(mode: str, subject: str, summary_level: int, prompts=None) -> str:
    """برومبتات المادة. `prompts` = وحدة المادة (subjects/*.py) إن وُجدت،
    فتُستخدم دوالها الخاصة؛ وإلا تُستخدم البرومبتات العامة.

    🔴 **وقواعدُ الرسّام تُلحق بها في الحالتين** — وهذا ما كان ناقصاً:
       برومبتُ المادة المستقلّة كان يحلّ **محلّ** العام لا فوقه، فخرجت
       مواد المسار الأدبي كلُّها (منطق · خرائط · جغرافيا …) بلا قاعدة
       كسورٍ ولا أرقامٍ عربية — والمنطق فيه «(ن ق ٣) / (ن-١ ق ٣) = ٨/٥».
    """
    # 🖌️ و`render_rules_once` لا `render_rules`: برومبتاتُ المواد صارت تُبنى
    #    من `system_prompt_strict_*` وهي تحمل قواعدَ الرسّام في ذيلها أصلاً،
    #    فالإلحاقُ الأعمى كان يكرّرها مرّتين في كل نداء ([common.render_rules_once]).
    if prompts is not None:
        if mode == "تلخيص" and hasattr(prompts, "prompt_summary"):
            p = prompts.prompt_summary(summary_level)
            return p + render_rules_once(p, subject)
        if mode == "سؤال" and hasattr(prompts, "prompt_qa"):
            p = prompts.prompt_qa()
            return p + render_rules_once(p, subject)
        if hasattr(prompts, "prompt_explain"):
            p = prompts.prompt_explain()
            return p + render_rules_once(p, subject)
    if mode == "تلخيص":
        return system_prompt_strict_summary(subject, summary_level)
    if mode == "سؤال":
        return system_prompt_strict_qa_improved(subject)
    return system_prompt_strict_explain(subject)   # شرح (الافتراضي)


# 🖌️ التذكيرُ بعددِ الرسوم — جسدُه في `subjects/common` لأن أربعة أقسامٍ
#    تستعمله (الدروس · الصفحات · الاختبار · المعلّم)، وكان يسكن هنا فيستورده
#    الجميع من جوف وحدةٍ لا تخصّهم. والاسمُ يبقى لمن استورده من قبل.
_DRAW_CODES = DRAW_CODES
_draw_reminder = draw_reminder


def _user_message(mode: str, lesson_text: str, student_text: str, req=None) -> str:
    """رسالةُ الطالب كما يراها الموديل: نصُّ الدرس ← الطلب ← **موضعُه من
    الحصة** ← تذكيرُ الرسوم.

    🕐 و`turn_note` هنا لا في البرومبت وحده: قسمُ المعلّم يحقن رقم الدور منذ
       يومه الأول (`teacher_assistant.turn_state`) وكان قسمُ الطالب بلا نظيره،
       فبقي الموديل يقرأ الرسائل الستّ كقائمةِ مهامّ ويعيد شرح ما شرحه.
    """
    student_text = (student_text or "").strip()
    if mode == "تلخيص":
        ask = student_text or "لخص الدرس أعلاه."
    elif mode == "سؤال":
        ask = student_text or "اطرح ملخصاً سريعاً لأهم نقاط الدرس."
    else:
        ask = student_text or "اشرح الدرس أعلاه كاملاً."
    return (f"نص الدرس من الكتاب:\n{lesson_text}\n\nطلب الطالب: {ask}"
            + turn_note(req)
            + _draw_reminder(lesson_text))


async def handle(req, clients: dict, prompts=None) -> dict:
    """معالج وضع الدروس العام — أي مادة، أي صيغة ملف.
    `prompts`: وحدة المادة لتخصيص البرومبتات (اختياري)."""
    subject = req.subject.strip()
    book = get_lessons_book(req.grade, req.track, subject)
    if book is None:
        return {"answer": f"📁 محتوى وضع الدروس لمادة «{subject}» قيد الإضافة 🚧\nجرّب وضع الوحدات، أو عد لاحقاً.",
                "references": [], "session_active": False}

    if not (req.lesson_name or "").strip():
        return {"answer": "📖 اختر الدرس أولاً من إعدادات الجلسة.", "references": [], "session_active": False}

    unit, lesson = find_lesson(book, req.unit_name or "", req.lesson_name)
    if lesson is None:
        # محاولة ثانية بلا تقييد الوحدة (قد تتغير الوحدة في الواجهة)
        unit, lesson = find_lesson(book, "", req.lesson_name)
    if lesson is None:
        return {"answer": f"❌ لم أجد درس «{req.lesson_name}». حدّث القائمة وحاول مجدداً.",
                "references": [], "session_active": False}

    unit_name = (unit or {}).get("اسم_الوحدة", "").strip()
    lesson_text = serialize_lesson(lesson, unit_name, subject=subject)

    # 🗄️ **الشرحُ المخزون — قبل أي نداءِ موديل** ([core/lesson_cache]).
    #
    # ⚖️ فكرةُ المالك (2026-09-14): «شرحُ الدرس واحدٌ لكل الطلاب، فلماذا
    #    يُولَّد في كل مرة؟» وهو صحيح لسببٍ أدقّ: **هذا الطلبُ وحده لا يعتمد
    #    على الطالب** — لا سؤالَ له ولا سياقَ محادثة، مدخلُه نصُّ الدرس فقط.
    #    فجوابُه دالّةٌ خالصةٌ من الكتاب، وما كان كذلك يُحسب مرّةً ويُخزَّن.
    #
    # 🔑 و[lesson_cache.get] يتحقّق من **بصمة نصّ الدرس**: تعديلُ الكتاب
    #    يُسقط المخزونَ من تلقائه ويعود الطلبُ إلى الموديل.
    # 💳 وبلا نداءِ موديل ⇒ لا يُخصم من الحصة ([core/billing.py]).
    if lesson_cache.serves(req):
        stored = lesson_cache.get(req.grade, req.track, subject,
                                  unit_name, req.lesson_name, lesson_text)
        if stored:
            return {"answer": stored, "cached": True,
                    "references": [f"{unit_name} › {req.lesson_name}".strip(" ›")],
                    "session_active": False}

    client_key, model_name = model_route(subject)
    client = clients.get(client_key) or clients["gemini"]
    # ☢️ ونموذجُ التفكير يحتاج سقفاً يتّسع لتفكيره وإلا عاد **فارغاً**
    #    بلا خطأٍ ولا سجلّ — قياسٌ في [core/curriculum.call_budget].
    _budget = call_budget(model_name, _MAX_TOKENS, _AI_TIMEOUT, "chat")
    _think = reasoning_kwargs(model_name, "chat")   # 🎚️ نقاشٌ بلا تفكير

    messages = [{"role": "system", "content": _system_prompt(req.mode, subject, req.summary_level, prompts)}]
    if req.chat_history:
        valid = [m for m in req.chat_history if m.get("role") in ("user", "assistant")]
        messages.extend(valid[-_HISTORY_LAST_N:])
    messages.append({"role": "user", "content": _user_message(req.mode, lesson_text, req.content, req)})

    try:
        # 🌊 يبثّ حرفاً حرفاً إن كان الطلب على مسار البثّ، وإلا فنداءٌ عادي
        #    حرفياً كما كان ([core/streaming.py]).
        answer = await streaming.complete(
            client, model=model_name, messages=messages,
            sink=streaming.sink_of(req), timeout=_budget[1],
            max_tokens=_budget[0], temperature=0.1, **_think,
        )
    except asyncio.TimeoutError:
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
    except Exception as e:
        answer = f"خطأ في التوليد: {str(e)}"

    refs = [f"{unit_name} › {req.lesson_name}".strip(" ›")]
    return {"answer": strip_stray_latex(answer, subject), "references": refs,
            "session_active": False}
