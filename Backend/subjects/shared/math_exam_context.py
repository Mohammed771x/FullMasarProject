# -*- coding: utf-8 -*-
"""📄 سياقُ وزاري الرياضيات — ما عُرض في **هذه المحادثة** وبرومبتُ متابعته

    🎯 **أمرُ المالك (٢٠٢٦-٠٩-٢٧):** بعد وصول الأسئلة يسأل الطالب «السؤال
       رقم ثلاثة وضّحه لي» — فيذهب للموديل آخرُ ست رسائل، والدرسُ الذي خرجت
       منه الأسئلة، والسؤال. «ولو رجع بعدين على المحادثة يوجد نفس الدرس».

    ☢️ **ما كان:** الأسئلةُ المعروضة في `sessions_math[user_id]` وحده —
       ذاكرةٌ **لكل طالبٍ لا لكل محادثة**، تموت بعد نصف ساعة ومع كل إعادة
       تشغيل. فالعائدُ إلى محادثته يُقال له «يرجى جلب الأسئلة أولاً»، أو
       يُشرح له سؤالٌ من **محادثةٍ أخرى** جلب فيها درساً آخر.

    ملفٌّ مستقلّ لا في `subjects/math.py` — سقّاطةُ الطول ([[file-scope-ratchet]]).
"""
from typing import Any, Dict, Optional

from .exams import get_math_exam_questions
from .lens import subject_lens
from .rules import (
    ANSWER_SHAPE_RULES, CALC_CHECK_RULES, CONTINUITY_RULES,
    CONVERSATION_RULES, FOLLOWUP_RULES,
)

# 📏 سقفُ الأسئلة التي تُعاد للموديل سياقاً — الجلبةُ الواحدة ≤ ٢٠
#    ([clamp_count]) و«كمل» تضيف ١٠، فمئةٌ تتّسع لكل ما يعرضه درسٌ في سنة.
EXAM_CONTEXT_CAP = 100


def conversation_exam(req, sessions: Dict) -> Optional[Dict[str, Any]]:
    """📝 **ما عُرض في هذه المحادثة** — السنةُ والدرسُ والأسئلةُ بترتيبها.

    ✅ **العميلُ الجديد يرسل سياقَ محادثته** (`exam_year` · `lesson_name` ·
       `exam_shown`) فيُعاد بناءُ المعروض من الملف: الجلبُ بادئةُ القائمة،
       فالسؤالُ ٣ هنا هو السؤالُ ٣ الذي رآه — ولو بعد إعادة تشغيل الخادم.

    ☢️ **ولا يُرجَع إلى جلسة الطالب إن أرسل سياقَه**: تلك ذاكرةُ **آخر جلبٍ
       له في أيّ محادثة** — والرجوعُ إليها هو بعينه العلّةُ التي تشرح له
       سؤالاً من محادثةٍ أخرى. فالجلسةُ للعميل القديم وحده (`exam_shown=None`).
    """
    if req.exam_shown is None:
        sess = sessions.get(req.user_id)
        if not (sess and sess.get("mode") == "وزاري"):
            return None
        return {
            "year": sess.get("year"),
            "lesson": sess.get("lesson"),
            "branch": sess.get("branch"),
            "questions": sess.get("displayed_questions", []),
            "shown": sess.get("shown_count", 0),
            "has_more": sess.get("has_more", False),
        }

    year = (req.exam_year or "").strip()
    lesson = (req.lesson_name or "").strip()
    branch = (req.unit_name or "").strip()
    shown = req.exam_shown
    if not (year and lesson and branch and shown > 0):
        return None
    # 🛡️ السنةُ والفرعُ يمرّان بـ`safe_segment` داخل الجلب — لا مسارَ خارج البنك.
    result = get_math_exam_questions(branch, year, lesson, min(shown, EXAM_CONTEXT_CAP),
                                     req.grade, req.track)
    if not result["questions"]:
        return None
    total = result.get("total", shown)
    return {
        "year": year,
        "lesson": lesson,
        "branch": branch,
        "questions": result["questions"],
        "shown": min(shown, total),
        "has_more": total > shown,
    }


def exam_questions_context(ctx: Dict[str, Any]) -> str:
    """الأسئلةُ المعروضة بأرقامها كما رآها الطالب — ومعها حلولُها."""
    out = f"📚 الأسئلة الوزارية المعروضة (سنة {ctx['year']}, درس: {ctx['lesson']}):\n\n"
    for i, q in enumerate(ctx["questions"], 1):
        q_text = q.get('نص_السؤال', '').replace('\n', '\n  ')
        sol_text = q.get('الحل', '').replace('\n', '\n  ')
        out += f"📌 السؤال {i}:\n{q_text}\n\n"
        if sol_text:
            out += f"💡 الحل:\n{sol_text}\n\n"
        out += "━━━━━━━━━━━━━━━\n\n"
    return out


def exam_followup_prompt(markup_rules: str) -> str:
    """برومبتُ الإجابة عن الأسئلة المعروضة — **والعمودُ الفقري معه**.

    🔴 كان هذا البرومبتُ وحده بلا قواعد المتابعة والاتّصال، فكان «وضّح
       الرابع» بعد «وضّح الثالث» يُعيد الثالثَ من أوّله.
    🧮 و«يشيك على الحسابات» (المالك ٢٠٢٦-٠٩-٢٧): الحلُّ الوزاريُّ مرجعٌ هنا
       كالكتاب — خلافٌ معه يُعاد حسابُه ثم يُذكر، لا يُخفى ولا يُجارى.
    """
    return (
        "أنت مدرس رياضيات محترف.\n"
        "المطلوب: الإجابة على سؤال الطالب بناءً على الأسئلة الوزارية المعروضة.\n\n"
        "📌 السياق المهم:\n"
        "- الطالب يسأل عن أسئلة وزارية معروضة أمامه\n"
        "- قد يسأل: 'وضح السؤال 3'، 'كيف حلينا الثاني'، 'ما فهمت قيمة س'\n"
        "- أنت تفهم سؤاله وتجيب بناءً على الأسئلة المعروضة\n\n"
        + FOLLOWUP_RULES
        + CONVERSATION_RULES
        + CONTINUITY_RULES
        + ANSWER_SHAPE_RULES
        + subject_lens("رياضيات")
        + CALC_CHECK_RULES
        + "القواعد:\n"
        "- استخدم العربية الفصحى فقط.\n"
        "- يمنع استخدام الإنجليزية أو أي لغة أخرى.\n\n"
        "يمنع استخدام اي رموز غير عربية .\n\n"
        "- استخدم فقط: (جا، جتا، ظا) و (س، ص)\n\n"
        "- لا تستخدم \\text\n"
        + markup_rules
        + "✏️ مثال للكتابة الصحيحة:\nص = ٢س² + ١\n\n"
        "- اشرح الحل خطوة بخطوة، **على طريقة الحل الوزاري المعروض**\n"
        "- اذكر القوانين المستخدمة من الدرس\n"
        "- إذا ذكر رقم سؤال، ارجع للسؤال المطابق من القائمة المعروضة\n"
        "- إذا ذكر رقماً لا يوجد في القائمة، قل له ذلك واذكر عدد الأسئلة المعروضة\n"
        "- إذا كان سؤالاً عاماً، استخدم الأسئلة المعروضة للتوضيح\n"
    )


# 🎯 **ما يُلحق بسؤال الطالب نفسه** — ما يُلحق بآخر رسالةٍ يُمتثَل له أكثر
#    من قاعدةٍ في رأس البرومبت ([turn_note] · [[prompt-spine]]).
EXAM_TURN_REMINDER = (
    "تذكير: أجب عن طلب الطالب هذا وحده. إن ذكر رقمَ سؤالٍ فارجع إلى السؤال "
    "بذلك الرقم في القائمة المعروضة حرفاً بحرف، وراجع كلَّ ناتجٍ حسابيٍّ "
    "مرّةً ثانية في ذهنك. ولا تكتب للطالب أيَّ فقرةِ «تحقق» أو «للتأكد» — "
    "ينتهي جوابك بالجواب النهائي ثم القانون المستخدم فقط."
)
