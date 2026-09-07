# ==================================================
# 📄 core/pages_mode.py — وضع الوحدات/الصفحات (نمط الأحياء لكل المواد)
# ==================================================
# نفس منطق معالج الأحياء الحالي حرفياً — مُعمَّم لأي مادة:
#   • input_type == "صفحة": أرقام صفحات → نصوصها → الموديل
#   • input_type == "برومت": وحدة (أو الكل) + سؤال → بحث دلالي (embeddings) → الموديل
# يعيد استخدام دوال subjects/common.py نفسها (fetch_pages_by_numbers،
# pages_with_headers، enhanced_qa_search، system prompts) — صفر منطق مكرر.

import re
import asyncio

from config import MAX_PAGES_EXPLAIN_SUMMARY, QA_TOP_K
from subjects.common import (
    fetch_pages_by_numbers, pages_with_headers, enhanced_qa_search,
    system_prompt_strict_explain, system_prompt_strict_summary,
    system_prompt_strict_qa_improved,
    strip_stray_latex,
)
from .content_store import get_pages_book
from .curriculum import model_route

_AI_TIMEOUT = 50
_MAX_TOKENS = 4000
from config import HISTORY_LAST_N as _HISTORY_LAST_N   # مصدر واحد للرقم


def _system_prompt(mode, subject, summary_level, prompts=None):
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
    return system_prompt_strict_explain(subject)


async def _call_model(subject, messages, clients):
    client_key, model_name = model_route(subject)
    client = clients.get(client_key) or clients["gemini"]
    try:
        response = await asyncio.wait_for(
            client.chat.completions.create(
                model=model_name, messages=messages,
                max_tokens=_MAX_TOKENS, temperature=0.1,
            ),
            timeout=_AI_TIMEOUT,
        )
        return response.choices[0].message.content
    except asyncio.TimeoutError:
        return "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."
    except Exception as e:
        return f"خطأ في التوليد: {str(e)}"


async def handle(req, clients: dict, prompts=None) -> dict:
    """معالج وضع الوحدات/الصفحات العام.
    `prompts`: وحدة المادة لتخصيص البرومبتات (اختياري)."""
    subject = req.subject.strip()
    book = get_pages_book(req.grade, req.track, subject)
    if book is None:
        return {"answer": f"📁 محتوى وضع الوحدات لمادة «{subject}» قيد الإضافة 🚧\nجرّب وضع الدروس، أو عد لاحقاً.",
                "references": [], "session_active": False}

    # فلترة الوحدة (نفس منطق الأحياء الحالي)
    unit_name = (req.unit_name or "").strip()
    if unit_name and unit_name != "الكل":
        target = [u for u in book if (u.get("اسم_الوحدة") or "").strip() == unit_name]
        if not target:
            return {"answer": f"لم أجد الوحدة '{unit_name}'", "references": [], "session_active": False}
    else:
        target = book

    history = []
    if req.chat_history:
        history = [m for m in req.chat_history if m.get("role") in ("user", "assistant")][-_HISTORY_LAST_N:]

    # ══ أ) بالصفحات ══
    if req.input_type == "صفحة":
        numbers = re.findall(r"\d+", req.page_source)
        if not numbers:
            return {"answer": "صيغة غير صحيحة. الرجاء كتابة أرقام الصفحات.", "references": [], "session_active": False}
        page_nums = [int(n) for n in numbers]
        if len(page_nums) > MAX_PAGES_EXPLAIN_SUMMARY:
            return {"answer": f"الحد الأقصى {MAX_PAGES_EXPLAIN_SUMMARY} صفحات.", "references": [], "session_active": False}
        found_pages, missing = fetch_pages_by_numbers(target, page_nums)
        if not found_pages:
            return {"answer": "الصفحات غير موجودة في النطاق المحدد.", "references": [], "session_active": False}

        context_text = pages_with_headers(found_pages, subject)
        verb = {"تلخيص": "لخص", "سؤال": "أجب عن سؤالي من"}.get(req.mode, "اشرح")
        messages = [{"role": "system", "content": _system_prompt(req.mode, subject, req.summary_level, prompts)}]
        messages.extend(history)
        messages.append({"role": "user",
                         "content": f"نص الكتاب:\n{context_text}\n\nطلب الطالب: {verb} المحتوى أعلاه."})
        answer = await _call_model(subject, messages, clients)
        if missing:
            answer += f"\n\n(ملاحظة: الصفحات {missing} لم يتم العثور عليها)"
        refs = [f"ص {p.get('رقم_الصفحة')}" for p in found_pages]
        return {"answer": strip_stray_latex(answer), "references": refs,
            "session_active": False}

    # ══ ب) بالبرومت (بحث دلالي — embeddings) ══
    query = req.search_query
    if not query:
        return {"answer": "✍️ اكتب سؤالك أو الموضوع الذي تريد شرحه.", "references": [], "session_active": False}

    results, idxs = await enhanced_qa_search(target, query, top_k=QA_TOP_K)
    context_text = "\n\n".join(results) if results else "لا توجد نصوص مطابقة من الكتاب."

    messages = [{"role": "system", "content": _system_prompt(req.mode, subject, req.summary_level, prompts)}]
    messages.extend(history)
    messages.append({"role": "user",
                     "content": f"نص الكتاب:\n{context_text}\n\nسؤال الطالب: {query}"})
    answer = await _call_model(subject, messages, clients)

    # المراجع: أسماء الوحدات وأرقام الصفحات المطابقة
    refs = []
    flat = [(u.get("اسم_الوحدة", ""), p) for u in target for p in u.get("الصفحات", [])]
    for i in idxs:
        if 0 <= i < len(flat):
            uname, page = flat[i]
            refs.append(f"{uname} - ص{page.get('رقم_الصفحة')}")
    return {"answer": strip_stray_latex(answer), "references": refs,
            "session_active": False}
