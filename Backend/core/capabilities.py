# ==================================================
# 🔍 core/capabilities.py — كشف الأوضاع المتاحة من البيانات
# ==================================================
# «الكود لا يعرف أسماء المواد» — القدرات تُكتشف من وجود الملفات وشكلها.
# أضف lessons.json → يظهر وضع الدروس تلقائياً. أضف pages.json → وضع الوحدات.

from config import MAX_PAGES_EXPLAIN_SUMMARY
from .content_store import (
    get_lessons_book, get_pages_book,
    lessons_units, lessons_in_unit, pages_units,
    MATH_SUBJECT,
)


def _unit_pages(book, unit_name: str) -> list:
    """أرقام صفحات وحدةٍ بعينها، مرتّبةً وبلا تكرار.

    ⚠️ **وتُهمل الصفحات غير الرقمية**: في فيزياء الثاني صفحةٌ اسمها «غلاف»
       — بيانات صحيحة لا خطأ، لكنها ليست رقماً يُختار ولا يجدها البحث
       بالرقم. فعرضُها في المُنتقي كان سيُعطي زراً لا يعمل.
    """
    for u in (book or []):
        if not isinstance(u, dict):
            continue
        if (u.get("اسم_الوحدة") or "").strip() != unit_name:
            continue
        nums = {p.get("رقم_الصفحة") for p in u.get("الصفحات", [])
                if isinstance(p.get("رقم_الصفحة"), int)}
        return sorted(nums)
    return []


def _has_exam_bank(grade, track, subject) -> bool:
    """هل لهذا الصف/المسار بنك وزاري فعلاً؟

    ⭐ عليه تُبنى الشريحة الرابعة في الواجهة: **الوزاري امتحان وطني للثالث**،
    فلا يظهر وضعه للأول والثاني ([31§3]). والقرار يأتي من وجود الملفات لا من
    شرط مكتوب في الشاشة — فيوم يُضاف بنك لصفٍّ آخر يظهر تلقائياً.
    """
    import os
    from subjects.common import subject_exams_dir
    try:
        d = subject_exams_dir(subject, grade, track)
    except Exception:
        return False
    if not os.path.isdir(d):
        return False
    for name in os.listdir(d):
        if name.startswith((".", "_")):
            continue
        path = os.path.join(d, name)
        if name.lower().endswith(".json") or os.path.isdir(path):
            return True
    return False


def describe(grade, track, subject) -> dict:
    """وصف كامل لقدرات مادة: الأوضاع المتاحة + شجرة الوحدات/الدروس.
    استدعاء واحد يعطي الواجهة كل ما تحتاجه — بدل أربع رحلات شبكة."""
    lessons_book = get_lessons_book(grade, track, subject)
    # الرياضيات: وضع الدروس فقط (قرار المالك)
    pages_book = None if subject == MATH_SUBJECT else get_pages_book(grade, track, subject)

    p_units = pages_units(pages_book) if pages_book is not None else []

    lessons_tree = []
    if lessons_book is not None:
        for uname in lessons_units(lessons_book):
            lessons_tree.append({"unit": uname, "lessons": lessons_in_unit(lessons_book, uname)})

    return {
        "subject": subject,
        "lessons": {"available": lessons_book is not None, "units": lessons_tree},
        # 📄 **وأرقام الصفحات معها في النداء نفسه** (قرار المالك 2026-09-09):
        #    الطالب كان يكتب «13، 14، 15» من ذاكرته أو من الكتاب الورقي —
        #    والآن يختارها من قائمة. ولو جُلبت بنداءٍ ثانٍ لظهر المُنتقي
        #    فارغاً لحظةً ثم امتلأ، وهذه اللحظة هي كل تجربة الطالب.
        "pages": {"available": pages_book is not None,
                  "units": p_units,
                  "unit_pages": {u: _unit_pages(pages_book, u) for u in p_units},
                  "max_selectable": MAX_PAGES_EXPLAIN_SUMMARY},
        # 📝 الوزاري: بنك أسئلة هذا الصف/المسار
        "exams": {"available": _has_exam_bank(grade, track, subject)},
        # 🧠 اختبر نفسك: يُبنى من الدروس حصراً (لكل المواد بلا استثناء)
        "quiz": {"available": lessons_book is not None},
    }
