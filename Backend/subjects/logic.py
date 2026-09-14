# ==================================================
# 📘 subjects/logic.py — مادة المنطق
# ==================================================
# الصفوف: الثالث الأدبي
#
# هذا الملف **مستقل تماماً**: عدّل برومبتاته أدناه بحرية دون أن تتأثر أي مادة أخرى.
# البرومبتات منسوخة حرفياً من برومبت الأحياء (الثالث الثانوي) مع تغيير اسم المادة فقط.
#
# الوضعان يعملان تلقائياً حسب الملفات الموجودة:
#   📖 وضع الدروس  → data/subjects/{الصف}/{المسار}/منطق/lessons_mode/
#   📄 وضع الوحدات → data/subjects/{الصف}/{المسار}/منطق/unit_mode/book.json

from core import lesson_mode, pages_mode
from subjects.common import (
    system_prompt_strict_explain,
    system_prompt_strict_summary,
    system_prompt_strict_qa_improved,
)
from core import arabic_digits, steps_format

SUBJECT = "منطق"


# ══════════════════════════════════════════════════
# 🎓 برومبتات هذه المادة — **عمودٌ فقريٌّ واحد + عدسةُ المادة**
# ══════════════════════════════════════════════════
#
# 🔴 **ما كان هنا حتى 2026-09-14:** ثلاثةُ برومبتاتٍ منسوخةٍ بيدها في هذا
#    الملف — وفي سبعةِ ملفاتٍ أدبيةٍ أخرى مثله — **بلا قاعدةِ مصدرٍ واحدة،
#    وبلا قاعدةِ متابعة، وبلا قاعدةِ محادثة، وبلا شكلِ جواب**. وبرومبتُ
#    السؤال كان نصُّه: «الجواب يجب أن يكون مختصراً… لا تعطِ الدرس كاملاً».
#    فكان طالبُ التاريخ والجغرافيا والفلسفة والمنطق يُجاب بسطرين على طلبِ
#    شرح، و«أعطني مثالاً» يُعامَل سؤالاً جديداً فيُردّ بـ«غير موجود في
#    الكتاب»، و«أهلاً بك في حصتنا» تتكرّر في كل ردّ — بينما كانت الأحياءُ
#    والكيمياءُ والفيزياء قد عولجت كلُّها.
#
# ⚠️ **وقد خدعني جردي السابق** (2026-09-14): افترض أن مادةً بلا معالجٍ خاص
#    تأخذ `system_prompt_strict_qa_improved`، فقاس برومبتاً **لا يُرسَل لهذه
#    المادة أصلاً** وأعلنها خضراء. والحقيقةُ أن `prompt_qa()` هنا كان يحلّ
#    **محلّه** في [core/pages_mode._system_prompt].
#
# ⚖️ **والعلاج ليس نسخَه ثمانِ مرّاتٍ أخرى**: العمودُ الفقري في
#    [subjects/common.teaching_core] مصدرٌ واحد (مصدرٌ · متابعةٌ · محادثةٌ ·
#    اتّصالٌ · شكل)، و**اختلافُ المادة** يسكن في [common.subject_lens]:
#    فقرةٌ تصف كيف تُشرح هذه المادة تحديداً — التاريخُ من السبب إلى النتيجة،
#    والمنطقُ من الصورة قبل المادة، والعربيُّ من الشاهد إلى القاعدة.
#
# 📝 **وتريد تخصيصاً يخصّ هذه المادة وحدها؟** أضِفه هنا فوق المشترك:
#        return system_prompt_strict_explain(SUBJECT) + "\n📌 ولهذه المادة…"
#    أو — وهو الأنظف — أضِف سطرك في `_SUBJECT_LENS` فيصل الأوضاعَ الثلاثة معاً.

def prompt_explain() -> str:
    return system_prompt_strict_explain(SUBJECT)


def prompt_summary(level: int) -> str:
    return system_prompt_strict_summary(SUBJECT, level)


def prompt_qa() -> str:
    return system_prompt_strict_qa_improved(SUBJECT)


# ══════════════════════════════════════════════════
# 🚦 المعالج الرئيسي
# ══════════════════════════════════════════════════
async def handle_logic_request(req, clients: dict) -> dict:
    """يوجّه الطلب للوضع المطلوب مع برومبتات هذه المادة."""
    mode = req.content_mode

    # افتراض ذكي عند غياب content_mode (عملاء قدامى): جرّب الدروس ثم الوحدات
    if mode not in ("lessons", "pages"):
        from core.content_store import get_lessons_book
        mode = "lessons" if get_lessons_book(req.grade, req.track, SUBJECT) is not None else "pages"

    result = await (lesson_mode if mode == "lessons" else pages_mode).handle(
        req, clients, prompts=_self())

    # ٠١٢ **أرقام المنطق بالعربية** (قرار المالك 2026-09-09): كتاب المنطق
    #     يكتب ٠١٢٣، والبرومبت كان يقول «اكتب الأرقام بشكل نصي نظيف» —
    #     وهي عبارةٌ لا تُلزم شيئاً، فخرجت الأرقام لاتينية. والضمانة فلتر.
    if isinstance(result, dict) and result.get("answer"):
        result["answer"] = steps_format.space_steps(
            arabic_digits.to_arabic(result["answer"]))
    return result


def _self():
    """وحدة هذا الملف — تُمرَّر كمزوّد برومبتات."""
    import sys
    return sys.modules[__name__]
