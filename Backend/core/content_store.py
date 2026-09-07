# ==================================================
# 📦 core/content_store.py — مخزن المحتوى الآمن
# ==================================================
# المسؤوليات:
#   1. حلّ مسار ملف المحتوى: (صف، مسار، مادة، وضع) → ملف JSON
#   2. حماية صارمة من Path Traversal — المسار النهائي يجب أن يبقى داخل data/
#   3. كاش في الذاكرة مع إبطال تلقائي عند تغيّر الملف (mtime)
#   4. توافق رجعي كامل: الصف الثالث العلمي يقرأ الملفات القديمة كما هي
#
# بنية الملفات — الصف والمسار داخل كل مادة:
#
#   data/subjects/{المادة}/
#   ├── grade1/                            ← الأول موحّد (بلا مجلد مسار)
#   │   ├── lessons_mode/
#   │   └── unit_mode/
#   ├── grade2/{علمي|أدبي}/{lessons_mode|unit_mode}/
#   ├── grade3/{علمي|أدبي}/{lessons_mode|unit_mode}/
#   └── exams/                             ← بنك الوزاري (لم يُمَس)
#
# داخل lessons_mode خياران متكافئان:
#   (أ) ملف واحد يحوي الوحدات والدروس     — صيغة الفيزياء
#   (ب) مجلد لكل وحدة وملف لكل درس        — صيغة الرياضيات
# داخل unit_mode: ملف واحد بالصفحات        — صيغة الأحياء
#
# تُنشأ مجلدات (الصف، المسار) فقط حيث تكون المادة مقررة فعلاً.
# الملفات/المجلدات التي تبدأ بـ "_" أو "." تُتجاهل (القوالب والملاحظات).
#
# التوافق الرجعي (الصف الثالث العلمي فقط):
#   احياء  → pages  : data/subjects/احياء/احياء.json          (قائمة وحدات فيها الصفحات)
#   غيرها → lessons: data/subjects/{المادة}/{المادة}.json      (dict فيه الوحدات→الدروس)
#   رياضيات→ lessons: data/subjects/رياضيات/{فرع}/{درس}.json   (الفرع = وحدة)

import os
import json
import time
import threading

from config import BASE_SUBJECTS_DIR
from .curriculum import normalize_grade_track, is_valid_subject

_DATA_ROOT = os.path.realpath(BASE_SUBJECTS_DIR)

MATH_SUBJECT = "رياضيات"
MATH_BRANCHES = ["تفاضل", "تكامل", "جبر", "هندسة", "احتمالات"]

LESSONS_DIR = "lessons_mode"
UNIT_DIR = "unit_mode"
LESSONS_FILE = "lessons.json"
BOOK_FILE = "book.json"


def _is_ignored(name: str) -> bool:
    """ملفات/مجلدات الخدمة: القوالب والملاحظات والملفات المخفية."""
    return name.startswith("_") or name.startswith(".")

# ── كاش: {مفتاح: (mtime, data)} ──
_cache = {}
_cache_lock = threading.Lock()
_CACHE_MAX_ENTRIES = 256   # حد أعلى صارم — يمنع تضخم الذاكرة


class ContentNotFound(Exception):
    """يُرمى عندما لا يوجد ملف محتوى للوضع المطلوب — رسالة ودّية للطالب."""
    def __init__(self, subject, mode_label):
        self.subject = subject
        self.mode_label = mode_label
        super().__init__(f"لا يوجد محتوى {mode_label} لمادة {subject}")


def _safe_join(*parts) -> str:
    """يبني مساراً ويتحقق أنه بقي داخل جذر البيانات — درع Path Traversal."""
    path = os.path.realpath(os.path.join(_DATA_ROOT, *parts))
    if not (path == _DATA_ROOT or path.startswith(_DATA_ROOT + os.sep)):
        raise PermissionError("مسار غير مسموح")
    return path


def _load_cached(path: str):
    """قراءة JSON بكاش mtime — الملف يُعاد تحميله فقط إذا تغيّر على القرص."""
    try:
        mtime = os.path.getmtime(path)
    except OSError:
        return None
    with _cache_lock:
        hit = _cache.get(path)
        if hit and hit[0] == mtime:
            return hit[1]
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return None
    with _cache_lock:
        if len(_cache) >= _CACHE_MAX_ENTRIES:
            _cache.clear()  # تفريغ بسيط وآمن — الملفات صغيرة وإعادة التحميل رخيصة
        _cache[path] = (mtime, data)
    return data


# ══════════════ حلّ المسارات ══════════════

_GRADE_DIRS = {1: "grade1", 2: "grade2", 3: "grade3"}


def _mode_path(subject: str, grade: int, track: str, mode: str) -> str:
    """مجلد وضعٍ لمادة في صف/مسار — عبر _safe_join (درع Path Traversal)."""
    gdir = _GRADE_DIRS.get(grade, "grade3")
    if grade == 1:
        return _safe_join(subject, gdir, mode)
    return _safe_join(subject, gdir, track, mode)


def mode_dir(subject: str, grade, track, mode: str) -> str:
    """واجهة عامة لمجلد الوضع — تستعملها أداة الإدخال (core/ingest.py).
    تمرّ بـ `_safe_join` نفسه، فدرع Path Traversal يبقى واحداً لا اثنين."""
    grade, track = normalize_grade_track(grade, track)
    return _mode_path(subject, grade, track, mode)


def invalidate_cache():
    """تفريغ الكاش بعد كتابة ملف محتوى جديد — الكاش يعتمد mtime فيلتقط
    التغيير وحده، لكن الكتابة والقراءة في نفس الثانية قد تتساويان."""
    with _cache_lock:
        _cache.clear()


def _first_json_in(dirpath: str):
    """أول ملف JSON صالح في المجلد (مع تجاهل ما يبدأ بـ _ أو .)."""
    if not os.path.isdir(dirpath):
        return None
    for fname in sorted(os.listdir(dirpath)):
        if _is_ignored(fname):
            continue
        fpath = os.path.join(dirpath, fname)
        if not os.path.isfile(fpath):
            continue
        data = _load_cached(fpath)
        if data is not None:
            return data
    return None


def _shape_is_pages(data) -> bool:
    """صيغة الأحياء: قائمة وحدات، كل وحدة فيها 'الصفحات'."""
    return isinstance(data, list) and any(isinstance(u, dict) and u.get("الصفحات") for u in data)


def _shape_is_lessons(data) -> bool:
    """صيغة الفيزياء: dict فيه 'الوحدات'، كل وحدة فيها 'الدروس'."""
    if isinstance(data, dict):
        units = data.get("الوحدات", [])
        return any(isinstance(u, dict) and u.get("الدروس") for u in units)
    return False


def get_pages_book(grade, track, subject):
    """كتاب وضع الوحدات/الصفحات (صيغة الأحياء) أو None.
    grade/track للتحقق أن المادة مقررة فقط — الملفات مشتركة بين الصفوف."""
    grade, track = normalize_grade_track(grade, track)
    if not is_valid_subject(grade, track, subject):
        return None
    try:
        data = _first_json_in(_mode_path(subject, grade, track, UNIT_DIR))
    except PermissionError:
        return None
    return data if (data is not None and _shape_is_pages(data)) else None


def _lessons_book_from_dir(root: str, title: str = ""):
    """يبني كتاب دروس من مجلد: كل مجلد فرعي = وحدة، وكل ملف JSON بداخله = درس.
    الترتيب أبجدي ثابت. يتسامح مع الملفات بلا امتداد .json ومع 'اسم_درس'."""
    if not os.path.isdir(root):
        return None
    units = []
    for uname in sorted(os.listdir(root)):
        if _is_ignored(uname):
            continue
        udir = os.path.join(root, uname)
        if not os.path.isdir(udir):
            continue
        lessons = []
        for fname in sorted(os.listdir(udir)):
            if _is_ignored(fname):
                continue
            fpath = os.path.join(udir, fname)
            if not os.path.isfile(fpath):
                continue
            data = _load_cached(fpath)      # يقبل أي ملف يُحلَّل JSON حتى بلا امتداد
            if not isinstance(data, dict):
                continue
            lesson = dict(data)
            name = data.get("اسم_الدرس") or data.get("اسم_درس") or os.path.splitext(fname)[0]
            lesson["اسم_الدرس"] = str(name).strip()
            lessons.append(lesson)
        if lessons:
            units.append({"اسم_الوحدة": uname.strip(), "الدروس": lessons})
    return {"كتاب": title or os.path.basename(root), "الوحدات": units} if units else None


def get_lessons_book(grade, track, subject):
    """كتاب وضع الدروس (صيغة الفيزياء) أو None.
    grade/track للتحقق أن المادة مقررة فقط — الملفات مشتركة بين الصفوف."""
    grade, track = normalize_grade_track(grade, track)
    if not is_valid_subject(grade, track, subject):
        return None
    try:
        root = _mode_path(subject, grade, track, LESSONS_DIR)
    except PermissionError:
        return None

    # خيار (أ): ملف واحد يحوي الوحدات والدروس
    data = _first_json_in(root)
    if data is not None and _shape_is_lessons(data):
        return data

    # خيار (ب): مجلد لكل وحدة، ملف لكل درس
    built = _lessons_book_from_dir(root, subject)
    if built is not None:
        if subject == MATH_SUBJECT:
            order = {b: i for i, b in enumerate(MATH_BRANCHES)}
            built["الوحدات"].sort(key=lambda u: order.get(u["اسم_الوحدة"], len(order)))
        return built
    return None


# ══════════════ استعلامات التنقّل ══════════════

def _clean(s):  # المسافات البادئة في أسماء الوحدات (مشكلة مرصودة في البيانات)
    return (s or "").strip()


def pages_units(book) -> list:
    return [_clean(u.get("اسم_الوحدة")) for u in (book or []) if isinstance(u, dict) and _clean(u.get("اسم_الوحدة"))]


def lessons_units(book) -> list:
    units = (book or {}).get("الوحدات", [])
    return [_clean(u.get("اسم_الوحدة")) for u in units if isinstance(u, dict) and _clean(u.get("اسم_الوحدة"))]


def lessons_in_unit(book, unit_name: str) -> list:
    target = _clean(unit_name)
    for u in (book or {}).get("الوحدات", []):
        if _clean(u.get("اسم_الوحدة")) == target:
            return [_clean(l.get("اسم_الدرس")) for l in u.get("الدروس", [])
                    if isinstance(l, dict) and _clean(l.get("اسم_الدرس"))]
    return []


def find_lesson(book, unit_name: str, lesson_name: str):
    """يرجع (الوحدة، الدرس) بالمطابقة بعد strip — أو (None, None)."""
    t_unit, t_lesson = _clean(unit_name), _clean(lesson_name)
    for u in (book or {}).get("الوحدات", []):
        if t_unit and _clean(u.get("اسم_الوحدة")) != t_unit:
            continue
        for l in u.get("الدروس", []):
            if isinstance(l, dict) and _clean(l.get("اسم_الدرس")) == t_lesson:
                return u, l
    return None, None
