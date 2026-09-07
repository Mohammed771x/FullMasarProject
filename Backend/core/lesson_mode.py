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

from subjects.common import (
    system_prompt_strict_explain,
    system_prompt_strict_summary,
    system_prompt_strict_qa_improved,
    strip_stray_latex,
)
from .content_store import get_lessons_book, find_lesson
from .serializer import serialize_lesson
from .curriculum import model_route

_AI_TIMEOUT = 50      # نفس مهلة المعالجات الحالية
_MAX_TOKENS = 4000
from config import HISTORY_LAST_N as _HISTORY_LAST_N   # مصدر واحد للرقم


def _system_prompt(mode: str, subject: str, summary_level: int, prompts=None) -> str:
    """برومبتات المادة. `prompts` = وحدة المادة (subjects/*.py) إن وُجدت،
    فتُستخدم دوالها الخاصة؛ وإلا تُستخدم البرومبتات العامة."""
    if prompts is not None:
        if mode == "تلخيص" and hasattr(prompts, "prompt_summary"):
            return prompts.prompt_summary(summary_level)
        if mode == "سؤال" and hasattr(prompts, "prompt_qa"):
            return prompts.prompt_qa()
        if hasattr(prompts, "prompt_explain"):
            return prompts.prompt_explain()
    if mode == "تلخيص":
        return system_prompt_strict_summary(subject, summary_level)
    if mode == "سؤال":
        return system_prompt_strict_qa_improved(subject)
    return system_prompt_strict_explain(subject)   # شرح (الافتراضي)


def _user_message(mode: str, lesson_text: str, student_text: str) -> str:
    student_text = (student_text or "").strip()
    if mode == "تلخيص":
        ask = student_text or "لخص الدرس أعلاه."
    elif mode == "سؤال":
        ask = student_text or "اطرح ملخصاً سريعاً لأهم نقاط الدرس."
    else:
        ask = student_text or "اشرح الدرس أعلاه كاملاً."
    return f"نص الدرس من الكتاب:\n{lesson_text}\n\nطلب الطالب: {ask}"


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

    client_key, model_name = model_route(subject)
    client = clients.get(client_key) or clients["gemini"]

    messages = [{"role": "system", "content": _system_prompt(req.mode, subject, req.summary_level, prompts)}]
    if req.chat_history:
        valid = [m for m in req.chat_history if m.get("role") in ("user", "assistant")]
        messages.extend(valid[-_HISTORY_LAST_N:])
    messages.append({"role": "user", "content": _user_message(req.mode, lesson_text, req.content)})

    try:
        response = await asyncio.wait_for(
            client.chat.completions.create(
                model=model_name, messages=messages,
                max_tokens=_MAX_TOKENS, temperature=0.1,
            ),
            timeout=_AI_TIMEOUT,
        )
        answer = response.choices[0].message.content
    except asyncio.TimeoutError:
        answer = "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
    except Exception as e:
        answer = f"خطأ في التوليد: {str(e)}"

    refs = [f"{unit_name} › {req.lesson_name}".strip(" ›")]
    return {"answer": strip_stray_latex(answer), "references": refs,
            "session_active": False}
