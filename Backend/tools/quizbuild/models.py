# -*- coding: utf-8 -*-
"""📄 النداء — العميلُ والتوجيهُ وعدّادُ النداءات

    جزءٌ من [build_quizzes.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في ملفٍ لحاله»
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.
"""
from __future__ import annotations
from .boot import Counter, asyncio, quiz_spec
from .consts import CALC_SUBJECTS, OPENAI_MODEL, _MAX_TOKENS, _TIMEOUT


# ══════════════════════════════════════════════════
# 🤖 النداء
# ══════════════════════════════════════════════════

_CLIENTS = {}


def clients():
    if _CLIENTS:
        return _CLIENTS
    from api import AI_CLIENTS
    _CLIENTS.update(AI_CLIENTS)
    return _CLIENTS


def route(subject: str):
    """OpenAI لكل المواد · **ديب سيك للرياضيات والمنطق والإنجليزية** ·
    **ولا جيميناي** (قرار المالك: «جيميناي لا تستخدمه لأنه ماشي معي فلوس
    فيه»).

    📏 **ولماذا انضمّت الإنجليزية (2026-09-18)؟** لأن حصّةَ التمرين قِيست
       على `gpt-4o-mini` خمسَ مرّاتٍ متتالية — ومع أربعِ إعاداتٍ موجَّهةٍ
       تقول له العيبَ بعينه ورقمَه — فاستقرّ عند **٥٠–٥٥٪** وسقفُه ١٢ من
       ٢١. وهو سقفُ امتثالٍ لا سقفُ محاولة. والمالكُ أذن: «بإمكانك تستخدم
       DPC في الحالات اللي شيء كبير»، وهذا أكبرُها: بنكُ مادّةٍ كامل.
    """
    if subject in CALC_SUBJECTS or quiz_spec.is_english(subject):
        from subjects.math import MATH_MODEL
        return "deepseek", MATH_MODEL
    return "openai", OPENAI_MODEL


# 🧾 **والنداءاتُ تُعَدّ وتُعلَن** — سؤالُ المالك (2026-09-18): «قال لك كم
#    دروس هن؟ لا تسوي لي كل درس خمس نداءات، ندايين يكفي. أنت بنفسك عدد».
#    وكان لا عدّادَ في الأداة، فالكلفةُ تُقدَّر تقديراً. فصارت تُحصى هنا
#    وتُطبع في آخر كل بناء — رقماً لا تخميناً.
CALLS = Counter()


async def ask_model(subject: str, messages: list) -> str:
    key, model = route(subject)
    CALLS[f"{key}/{model}"] += 1
    client = clients().get(key)
    if client is None:
        raise RuntimeError(f"مزوّد «{key}» غير مهيّأ — راجع .env")
    kw = {}
    cap, wait = _MAX_TOKENS, _TIMEOUT
    # 🧾 **وOpenAI يضمن JSON صالحاً بالعقد لا بالرجاء** — فيسقط مسارُ فشلِ
    #    التحليل كلُّه، وهو أكثرُ ما أهدر نداءاتٍ في بناء الشروح.
    if key == "openai":
        kw["response_format"] = {"type": "json_object"}
    else:
        # ☢️ **ونموذجُ التفكير يحتاج سقفاً يتّسع لتفكيره** — درسٌ مدفوعُ
        #    الثمن: `deepseek-v4-pro` بسقف ٤٠٠٠ ينفقها **كلَّها على
        #    التفكير** ويعيد **صفرَ حروف** و`finish_reason="length"` —
        #    جوابٌ فارغٌ بلا خطأ ولا سجلّ. فالسقفُ ثلاثةُ أضعاف والمهلةُ معه.
        cap, wait = 12000, 240
    res = await asyncio.wait_for(
        client.chat.completions.create(
            model=model, messages=messages,
            max_tokens=cap, temperature=0.4, **kw),
        timeout=wait)
    return res.choices[0].message.content or ""


