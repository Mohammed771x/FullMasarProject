import os
import pytest
from core import content_store as cs

def test_path_traversal_blocked():
    with pytest.raises(PermissionError):
        cs._safe_join("..", "..", "etc", "passwd")
    with pytest.raises(PermissionError):
        cs._safe_join("احياء", "..", "..", "config.py")

def test_biology_book_in_unit_mode():
    book = cs.get_pages_book(3, "علمي", "احياء")
    assert book is not None
    assert cs.pages_units(book), "وحدات الأحياء يجب أن تظهر"

def test_physics_book_in_lessons_mode():
    book = cs.get_lessons_book(3, "علمي", "فيزياء")
    assert book is not None
    units = cs.lessons_units(book)
    assert units
    lessons = cs.lessons_in_unit(book, units[0])
    assert lessons

def test_missing_pages_book_is_none_not_crash(empty_pages_target):
    """مادة بلا محتوى وحدات ⇒ None صريحة — عليها تُبنى رسالة «قيد الإضافة»."""
    grade, track, subject = empty_pages_target
    assert cs.get_pages_book(grade, track, subject) is None

def test_missing_lessons_book_is_none_not_crash(empty_lessons_target):
    """مادة بلا محتوى دروس ⇒ None صريحة — عليها تُبنى رسالة «قيد الإضافة»."""
    grade, track, subject = empty_lessons_target
    assert cs.get_lessons_book(grade, track, subject) is None

def test_math_branches_as_units():
    book = cs.get_lessons_book(3, "علمي", "رياضيات")
    assert book is not None
    units = cs.lessons_units(book)
    assert set(units) <= set(cs.MATH_BRANCHES)
    # الملف بلا امتداد (مبدأ العد) يجب أن يظهر الآن
    all_lessons = [l for u in units for l in cs.lessons_in_unit(book, u)]
    assert any("العد" in l for l in all_lessons), "الدرس بلا امتداد .json يجب أن يُرى"

def test_subject_without_files_returns_none():
    # مواد لم يُضف لها محتوى بعد → None بلا انفجار (لا استثناء، لا مسار خاطئ)
    assert cs.get_lessons_book(2, "أدبي", "علم الاجتماع") is None
    assert cs.get_pages_book(2, "أدبي", "جغرافيا") is None
    assert cs.get_lessons_book(3, "أدبي", "فلسفة") is None
    assert cs.get_lessons_book(3, "أدبي", "منطق") is None


def test_each_grade_track_is_isolated():
    """كل (صف، مسار) له مجلده — محتوى الثالث العلمي لا يتسرّب لغيره."""
    assert cs.get_lessons_book(3, "علمي", "رياضيات") is not None   # فيه محتوى
    assert cs.get_lessons_book(1, "عام", "رياضيات") is None        # قالب فقط
    assert cs.get_lessons_book(2, "أدبي", "رياضيات") is None
    assert cs.get_lessons_book(3, "أدبي", "رياضيات") is None


def test_grade1_has_no_track_folder():
    """الصف الأول موحّد: المسار يُهمَل ولا يغيّر المسار على القرص."""
    a = cs._mode_path("انجليزي", 1, "علمي", cs.LESSONS_DIR)
    b = cs._mode_path("انجليزي", 1, "أدبي", cs.LESSONS_DIR)
    assert a == b and a.endswith(os.path.join("grade1", cs.LESSONS_DIR))


def test_grade_track_in_path():
    p2 = cs._mode_path("عربي", 2, "أدبي", cs.UNIT_DIR)
    assert os.path.join("grade2", "أدبي", cs.UNIT_DIR) in p2


def test_subject_not_in_grade_returns_none():
    """المادة غير المقررة على الصف لا تُقرأ حتى لو ملفها موجود."""
    assert cs.get_lessons_book(3, "علمي", "تاريخ") is None
    assert cs.get_pages_book(3, "علمي", "مجتمع") is None


def test_templates_not_read_as_content():
    """ملفات _TEMPLATE.json في المجلدات الفارغة لا تُقرأ كمحتوى."""
    assert cs.get_lessons_book(1, "عام", "تاريخ") is None


def test_templates_folder_is_ignored():
    # مجلد _TEMPLATES يبدأ بـ "_" فلا يُقرأ كوحدة/درس في أي مادة
    assert cs._is_ignored("_TEMPLATES")
    assert cs._is_ignored(".gitkeep")
    assert not cs._is_ignored("تضاريس اليمن")

def test_find_lesson_with_stripped_names():
    book = cs.get_lessons_book(3, "علمي", "فيزياء")
    units = cs.lessons_units(book)
    lessons = cs.lessons_in_unit(book, units[0])
    u, l = cs.find_lesson(book, "  " + units[0] + " ", lessons[0])
    assert l is not None and l.get("اسم_الدرس", "").strip() == lessons[0]
