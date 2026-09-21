# -*- coding: utf-8 -*-
"""📄 الإصلاحُ الذاتي — ما أقدر عليه لا أشتريه بنداء

    جزءٌ من [build_quizzes.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في ملفٍ لحاله»
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.
"""
from __future__ import annotations
from .boot import QB, quiz_spec, repair_escapes
from .consts import APPLIED, _KIND_BY_LEVEL, _LEVEL_FIX, _NUMBER
from .english import _is_drill


# ══════════════════════════════════════════════════
# 🔧 الإصلاحُ الذاتي — ما أقدر عليه لا أشتريه بنداء
# ══════════════════════════════════════════════════
# 🎯 نصُّ المالك: «الشيء اللي يرجع غلط **أنت تعدّله**… إذا فيها أشياء
#    واحدة وتقدر تعدّلها، عدّلها أنت، إيش وظيفتك؟»

# 🔢 **ثلاثُ أبجدياتِ أرقامٍ في كتبنا، لا اثنتان**: لاتينية `7` · عربية
#    `٧` · **وفارسية `۷`** (U+06F7). ومسحُ الصفوف الثلاثة (2026-09-17):
#    **٨٤٨٣ محرفاً فارسياً في ٣١٥ درساً** — أكثرُها جغرافيا وتاريخ وأحياء،
#    ويُعرض الجدولُ الواحد فيه «٦٠» و«۱۰۰» جنباً إلى جنب بخطّين مختلفين.
#
# ⚖️ **والموديلُ كان يُعاقَب على أمانته**: ينقل رقمَ الكتاب كما هو فيسقط
#    بنكُه بعيب «أرقامٌ فارسية». فالعيبُ في المصدر لا في نقله —
#    **ويُصلَح لا يُرفض** («إذا فيها أشياء تقدر تعدلها، عدّلها أنت»).
_PERSIAN_TO_ARABIC = str.maketrans("۰۱۲۳۴۵۶۷۸۹", "٠١٢٣٤٥٦٧٨٩")


def arabize_digits(text: str) -> str:
    return (text or "").translate(_PERSIAN_TO_ARABIC)


def tidy_question(item, lesson_name: str, subject: str):
    """يصلح ما يُصلَح ويعيد `None` لما لا يُصلَح."""
    from subjects.common import render_finish
    if not isinstance(item, dict):
        return None

    q = arabize_digits(
        render_finish(repair_escapes(str(item.get("q", ""))), subject)).strip()
    options = item.get("options")
    if not q or not isinstance(options, list) or len(options) != 4:
        return None
    options = [arabize_digits(
        render_finish(repair_escapes(str(o)), subject)).strip()
        for o in options]
    if any(not o for o in options) or len(set(options)) != 4:
        return None

    idx = item.get("correct_index")
    if isinstance(idx, str) and idx.isdigit():
        idx = int(idx)                      # 🔧 «0» نصّاً — يُصلَح لا يُرمى
    if not isinstance(idx, int) or not (0 <= idx <= 3):
        return None

    level = str(item.get("level", "")).strip()
    level = _LEVEL_FIX.get(level, level)
    if level not in QB.LEVELS:
        level = "متوسط"                     # 🔧 افتراضٌ معلَن لا رفض
    # 🎚️ **و«صعب» بلا أثرِ تطبيقٍ تُخفَّض ولا تُرفض** — العيبُ في الوسم
    #    لا في السؤال، والسؤالُ نفسُه سليمٌ يخدم مستواه الحقيقي.
    # 🇬🇧 **وفعلُ الأمر الإنجليزيُّ تطبيقٌ كالعربيّ**: «Change into the
    #    passive: …» تمرينٌ صعبٌ حقيقيّ، ولو قيس بـ«احسب/أوجد» وحدَها
    #    لهبط كلُّ صعبٍ في الإنجليزية إلى «متوسط» فسقط البنكُ بعيب
    #    «مستوى صعب شبه غائب» — وهو عيبٌ في المقياس لا في السؤال.
    applied_en = quiz_spec.is_english(subject) and _is_drill(q)
    if level == "صعب" and not (APPLIED.search(q) or _NUMBER.search(q)
                               or applied_en):
        level = "متوسط"

    try:
        weight = int(round(float(item.get("weight", 3))))
    except (TypeError, ValueError):
        weight = 3
    weight = max(1, min(QB.MAX_WEIGHT, weight))

    topic = arabize_digits(
        render_finish(str(item.get("topic", "")), subject)).strip()
    # 🏷️ **واسمُ الدرس ليس موضوعاً**: عليه يقوم «تحليل مستواي» الذي يقول
    #    «ضعفُك في هذه النقطة» — فاسمُ الدرس مكانه يُفرغ التحليلَ من معناه.
    if not topic or topic == lesson_name:
        topic = ""

    why = arabize_digits(
        render_finish(str(item.get("why", "")), subject)).strip()
    kind = str(item.get("kind", "")).strip() or _KIND_BY_LEVEL[level]

    return {
        "id": QB.question_id(q, options),
        "q": q, "options": options, "correct_index": idx,
        "topic": topic, "lesson": lesson_name,
        "level": level, "weight": weight, "kind": kind, "why": why,
    }


