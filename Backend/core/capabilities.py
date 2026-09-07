# ==================================================
# 🔍 core/capabilities.py — كشف الأوضاع المتاحة من البيانات
# ==================================================
# «الكود لا يعرف أسماء المواد» — القدرات تُكتشف من وجود الملفات وشكلها.
# أضف lessons.json → يظهر وضع الدروس تلقائياً. أضف pages.json → وضع الوحدات.

from .content_store import (
    get_lessons_book, get_pages_book,
    lessons_units, lessons_in_unit, pages_units,
    MATH_SUBJECT,
)


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

    lessons_tree = []
    if lessons_book is not None:
        for uname in lessons_units(lessons_book):
            lessons_tree.append({"unit": uname, "lessons": lessons_in_unit(lessons_book, uname)})

    return {
        "subject": subject,
        "lessons": {"available": lessons_book is not None, "units": lessons_tree},
        "pages": {"available": pages_book is not None,
                  "units": pages_units(pages_book) if pages_book is not None else []},
        # 📝 الوزاري: بنك أسئلة هذا الصف/المسار
        "exams": {"available": _has_exam_bank(grade, track, subject)},
        # 🧠 اختبر نفسك: يُبنى من الدروس حصراً (لكل المواد بلا استثناء)
        "quiz": {"available": lessons_book is not None},
    }
