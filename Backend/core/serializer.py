from .fractions import to_frac
from .chem import (
    for_subject as _chem_for_subject,
    chem_from_name,
    is_organic_subject,
)
# ==================================================
# 📜 core/serializer.py — المُسلسِل العام
# ==================================================
# يحوّل أي بنية درس JSON — مهما كانت صيغتها — إلى نص عربي مقروء للموديل.
# هذا ما يجعل «صيغة كل مادة تختلف عن الثانية» غير مهمة في وضع الدروس:
# الدرس يُرفع كاملاً، والموديل يقرأ نصاً منسقاً.

# مفاتيح تقنية لا تفيد الموديل — تُتجاهل عند التسلسل
_SKIP_KEYS = {"رقم_الدرس", "رقم_الوحدة", "عدد_الدروس", "رقم_الصفحة"}

# ⛑️ حارس الحجم: أكبر درس مقاس حالياً 5,385 حرفاً — الحد أدناه هامش ×5.
# درس أضخم من هذا يُقص بأمان مع تنويه، بدل أن يفجّر سياق الموديل أو الفاتورة.
MAX_LESSON_CHARS = 30_000
_TRUNCATION_NOTE = "\n\n[ملاحظة للنظام: تم اقتصاص بقية الدرس لتجاوزه الحجم الأقصى]"


def to_text(node, depth: int = 0, subject=None) -> str:
    """تحويل تكراري عام: dict → عناوين، list → عناصر، قيم → أسطر.

    [subject] يحدّد هل يُرمَّز الشكلُ الكيميائي — الكيمياء وحدها، وبقية
    المواد يمرّ نصّها حرفياً بلا لمسة.
    """
    pad = "  " * depth
    if node is None:
        return ""
    if isinstance(node, (str, int, float)):
        s = str(node).strip()
        return f"{pad}{_chem_for_subject(s, subject)}\n" if s else ""
    if isinstance(node, list):
        return "".join(to_text(x, depth, subject) for x in node)
    if isinstance(node, dict):
        out = []
        # ⚗️ **مثالُ تسميةٍ = رسمٌ + اسم.** الكتاب يخزّن الرسم وصفاً نثرياً
        #    («سلسلة من 4 كربونات مرتبطة بـ NH») فيحكيه الموديل بدل أن
        #    يرسمه. والوصفُ ناقصٌ لا يصلح مصدراً (لا يذكر الكربونيل)، أما
        #    **الاسمُ المجاور** فيحدّد البنية تحديداً تامّاً — فمنه نُعيد
        #    بناء الرسم الذي ضاع في نسخ الكتاب. وما لم يُجزم بالاسم يبقى
        #    الوصف كما هو حرفياً.
        derived = None
        if is_organic_subject(subject):
            label = node.get("التسمية") or node.get("الاسم")
            if isinstance(label, str) and isinstance(node.get("الرسم"), str):
                derived = chem_from_name(label)
        for k, v in node.items():
            if k in _SKIP_KEYS:
                continue
            if isinstance(v, (str, int, float)):
                s = str(v).strip()
                if s:
                    if k == "الرسم" and derived:
                        # الوصف النثري يُستبدل بالرسم نفسه — لا يبقى بجواره
                        # وإلا اختار الموديل النثر (نفس درس الحلقات).
                        out.append(f"{pad}الرسم: {derived}\n")
                        continue
                    # ⚗️ وما عداه: الشكلُ يُستبدل بترميزه في مكانه.
                    out.append(f"{pad}{k}: {_chem_for_subject(s, subject)}\n")
            else:
                inner = to_text(v, depth + 1, subject)
                if inner.strip():
                    out.append(f"{pad}【{k}】\n{inner}")
        return "".join(out)
    return ""


def serialize_lesson(lesson: dict, unit_name: str = "", subject=None) -> str:
    """نص الدرس الكامل للحقن في البرومبت — مع حارس الحجم."""
    header = f"الوحدة: {unit_name}\n" if unit_name else ""
    # 🧮 الكسور تُرمَّز `\\frac` قبل حقن الدرس في البرومبت — فحين ينقل الموديل
    #    القانون حرفياً (كما يأمره البرومبت) ينقله مرسوماً لا بشرطة.
    # ⚗️ ومعها الصيغ البنائية — نفس المبدأ: الكتاب يُصلَح قبل الموديل.
    text = header + to_frac(to_text(lesson, subject=subject))
    if len(text) > MAX_LESSON_CHARS:
        text = text[:MAX_LESSON_CHARS] + _TRUNCATION_NOTE
    return text
