# -*- coding: utf-8 -*-
"""📄 مواضعُ الكتب وقراءتُها — مسارُ كل مادةٍ وصفّ

    جزءٌ من [subjects/common] — فُصل 2026-09-20 بأمر المالك:
    «كل مادة/قسم في ملفٍ لحاله، فالتعديلُ على نطاقٍ أقلّ».
    والنصُّ هنا **منقولٌ حرفاً بحرف** من الملف الأصل بلا تغيير سطر.
"""
import asyncio
import json
import os
import re
import time
from typing import List
from config import BASE_SUBJECTS_DIR, MAX_PAGES_EXAMS, MAX_PAGES_EXPLAIN_SUMMARY, UNIT_BATCH_PAGES


USAGE_HELP = {
    "صفحة": (
        "أنت في وضع الصفحات. اكتب أرقام الصفحات مفصولة بفواصل.\n"
        f"مثال: 45 أو 45,47\n"
        f"ملاحظة: الحد الأقصى للصفحات هنا هو {MAX_PAGES_EXPLAIN_SUMMARY} صفحات للشرح/تلخيص."
    ),
    "وحدة": (
        "أنت في وضع الوحدة. اكتب اسم الوحدة أو رقمها كما هو مكتوب في محتوى الكتاب.\n"
        f"سيتم شرح {UNIT_BATCH_PAGES} صفحة في كل مرة. اكتب 'كمل' للاستمرار أو 'وقف' لإنهاء الجلسة."
    ),
    "برومت": (
        "أنت في وضع البرومت. اكتب موضوعًا أو سؤالاً نصياً. يمكنك تحديد وحدة معينة لتسريع البحث ودقته."
    ),
    "سؤال": (
        "أنت في وضع السؤال. اكتب سؤالاً نصياً مفهوماً. يفضل تحديد الوحدة المختصة بالسؤال لنتائج أدق."
    ),
    "وزاري": (
        "أنت في وضع الأسئلة الوزارية.\n"
        "الصيغ المقبولة:\n"
        "- بحث بالوحدة: <سنة>,<اسم الوحدة>  مثال: 2018,الغدد الصماء\n"
        f"- بحث بالصفحات: <سنة>,<صفحة1>,<صفحة2>  (الحد الأقصى للصفحات هنا {MAX_PAGES_EXAMS})\n"
        "- بحث بالبرومت: <سنة>,<موضوع>  مثال: 2019,التنفس\n"
        "يمكنك كتابة 'الكل' بدلاً من السنة للبحث عبر كل السنوات."
    )
}





_subject_session_timestamps = {}

def cleanup_subject_sessions(sessions_dict: dict, session_timestamps: dict):
    """تنظيف الجلسات المنتهية لأي مادة"""
    now = time.time()
    expired = [
        uid for uid, ts in session_timestamps.items()
        if now - ts > 1800  # 30 دقيقة
    ]
    for uid in expired:
        sessions_dict.pop(uid, None)
        session_timestamps.pop(uid, None)
        
        
        



def help_for_mode(mode: str, input_type: str = None) -> str:
    if mode == "شرح":
        if input_type == "صفحة": return USAGE_HELP["صفحة"]
        if input_type == "وحدة": return USAGE_HELP["وحدة"]
        return USAGE_HELP["برومت"]
    if mode == "تلخيص":
        return USAGE_HELP["برومت"] + "\nاختر درجة التلخيص من 1 إلى 5."
    if mode == "سؤال": return USAGE_HELP["سؤال"]
    if mode == "وزاري": return USAGE_HELP["وزاري"]
    return "استخدم التطبيق لشرح أو تلخيص أو سؤال أو أسئلة وزارية."





# ── البنية: data/subjects/{المادة}/{gradeN}/[{المسار}]/{الوضع}/ ──
#    الصف الأول موحّد (بلا مجلد مسار). الثاني والثالث: علمي | أدبي.
LESSONS_DIR = "lessons_mode"
UNIT_DIR = "unit_mode"
_GRADE_DIRS = {1: "grade1", 2: "grade2", 3: "grade3"}


def mode_dir(subject: str, mode: str, grade: int = 3, track: str = "علمي") -> str:
    """مجلد وضعٍ لمادة في صف/مسار. الافتراضي الثالث العلمي — وهو ما
    تعتمد عليه المعالجات القديمة التي تستدعي بلا صف."""
    gdir = _GRADE_DIRS.get(grade, "grade3")
    base = os.path.join(BASE_SUBJECTS_DIR, subject, gdir)
    if grade == 1:
        return os.path.join(base, mode)
    return os.path.join(base, track or "علمي", mode)


def _first_real_json(dirpath: str):
    """أول ملف JSON فعلي في المجلد (تجاهل ما يبدأ بـ _ أو .)."""
    if not os.path.isdir(dirpath):
        return None
    for fname in sorted(os.listdir(dirpath)):
        if fname.startswith(("_", ".")):
            continue
        fpath = os.path.join(dirpath, fname)
        if os.path.isfile(fpath) and fname.lower().endswith(".json"):
            return fpath
    return None


# النطاق الذي كُتبت له الملفات القديمة (قبل إعادة الهيكلة إلى صفوف).
# ⚠️ التوافق الرجعي مسموح **لهذا النطاق وحده**: أي صف/مسار آخر يقرأ
#    مجلده هو فقط، وإن كان فارغاً فالجواب «لا يوجد محتوى» — لا محتوى صفٍّ آخر.
LEGACY_GRADE, LEGACY_TRACK = 3, "علمي"


def _is_legacy_scope(grade, track) -> bool:
    try:
        grade = int(grade)
    except (TypeError, ValueError):
        return False
    return grade == LEGACY_GRADE and (track or LEGACY_TRACK) == LEGACY_TRACK


def subject_book_path(subject: str, grade: int = 3, track: str = "علمي",
                      prefer: str = UNIT_DIR) -> str:
    """مسار كتاب المادة لصف/مسار محدد: الوضع المفضَّل أولاً ثم الآخر.

    المواقع القديمة تُجرَّب **للثالث العلمي فقط** — فلا يرث صفٌّ محتوى صفٍّ آخر.

    🔴 **لماذا `prefer`؟ (علّة حقيقية وقعت 2026-09-03)** المعالجات القديمة
       لكلٍّ منها شكلٌ تتوقّعه: الأحياء **قائمة صفحات**، وغيرها **قاموس وحدات
       ودروس**. وكان الترتيب `unit_mode` ثم `lessons_mode` **دائماً** — فبقي
       سليماً بالصدفة وحدها: لأن الفيزياء والكيمياء لم يكن لهما ملف صفحات.
       يوم أضاف المالك `unit_mode/فيزياء.json` انهار معالج الفيزياء فوراً
       بـ`AttributeError: 'list' object has no attribute 'get'` — أي أن
       **إضافة محتوى صحيح كسرت الكود**. فليقل كلُّ نداءٍ أيَّ شكلٍ يريد.
    """
    order = (UNIT_DIR, LESSONS_DIR) if prefer == UNIT_DIR else (LESSONS_DIR, UNIT_DIR)
    for mode in order:
        d = mode_dir(subject, mode, grade, track)
        named = os.path.join(d, f"{subject}.json")
        if os.path.isfile(named):
            return named
        found = _first_real_json(d)
        if found:
            return found

    legacy_base = os.path.join(BASE_SUBJECTS_DIR, subject)
    if not _is_legacy_scope(grade, track):
        # مسار غير موجود عمداً ⇒ load_json_safe ترجع None ⇒ «قيد الإضافة 🚧»
        return os.path.join(mode_dir(subject, order[0], grade, track), f"{subject}.json")

    # مواقع قديمة (قبل إعادة الهيكلة) — الثالث العلمي وحده
    for candidate in (
        os.path.join(legacy_base, order[0], f"{subject}.json"),
        os.path.join(legacy_base, order[1], f"{subject}.json"),
        os.path.join(legacy_base, f"{subject}.json"),
    ):
        if os.path.isfile(candidate):
            return candidate
    return os.path.join(legacy_base, f"{subject}.json")


def math_branch_dir(branch: str, grade: int = 3, track: str = "علمي") -> str:
    """مجلد فرع الرياضيات (الفرع = وحدة) — الجديد أولاً، والقديم للثالث العلمي فقط."""
    new = os.path.join(mode_dir("رياضيات", LESSONS_DIR, grade, track), branch)
    if os.path.isdir(new):
        return new
    if not _is_legacy_scope(grade, track):
        return new  # غير موجود ⇒ قائمة فارغة ⇒ رسالة «قيد الإضافة»
    legacy = os.path.join(BASE_SUBJECTS_DIR, "رياضيات", LESSONS_DIR, branch)
    if os.path.isdir(legacy):
        return legacy
    return os.path.join(BASE_SUBJECTS_DIR, "رياضيات", branch)


def subject_exams_dir(subject: str, grade: int = 3, track: str = "علمي") -> str:
    """مجلد بنك الوزاري لصف/مسار.

    بنك الوزاري الحالي كله **للثالث العلمي** ومخزَّن مسطّحاً في `{المادة}/exams/`.
    لإضافة وزاري صف آخر لاحقاً: أنشئ `{المادة}/exams/grade{N}/` (وللصف 2/3
    مجلد المسار بداخله) — يُقرأ تلقائياً دون تعديل كود.
    """
    base = os.path.join(BASE_SUBJECTS_DIR, subject, "exams")
    gdir = _GRADE_DIRS.get(grade, "grade3")
    scoped = os.path.join(base, gdir) if grade == 1 else os.path.join(base, gdir, track or "علمي")
    if os.path.isdir(scoped):
        return scoped
    return base if _is_legacy_scope(grade, track) else scoped

def load_json_safe(path: str):
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def find_unit(book_data: List[dict], query: str):
    """البحث عن الوحدة بالاسم أو بالرقم (مطابقة جزئية)"""
    q = query.strip()
    for unit in book_data:
        if q == unit.get("اسم_الوحدة") or q == str(unit.get("رقم_الوحدة")):
            return unit
    # محاولة مطابقة جزئية
    for unit in book_data:
        if q in unit.get("اسم_الوحدة", ""):
            return unit
    return None

def fetch_pages_by_numbers(book_data: List[dict], page_nums: List[int]):
    found = []
    missing = []
    for p in page_nums:
        found_flag = False
        for unit in book_data:
            for page in unit.get("الصفحات", []):
                if page.get("رقم_الصفحة") == p:
                    found.append(page)
                    found_flag = True
                    break
            if found_flag:
                break
        if not found_flag:
            missing.append(p)
    return found, missing




# 🗑️ **حُذفت `extract_relevant_book_texts`** (2026-09-14): لا مستدعيَ لها
#    في المشروع كلِّه، **وكانت مكسورة** — تنادي `faiss_search` وهي
#    `async` بلا `await`، فأولُ من يستعملها يقع على كوروتين لا نتيجة.
#    وهي نسخةٌ خامسة من دمج «المباشر أولاً» الذي أصلحناه، فبقاؤها دعوةٌ
#    لعودة العطل من بابٍ خلفيّ.

def extract_all_texts_and_metas(book_data: List[dict], subject=None):
    texts = []
    metas = []
    for unit in book_data:
        for page in unit.get("الصفحات", []):
            # 🧮 الكسور تُرمَّز قبل أن يراها الموديل — فنقلُه الحرفيّ ينقلها مرسومة
            texts.append(prepare_source(page.get("نص_الصفحة", ""), subject))
            metas.append({
                "unit": unit.get("اسم_الوحدة"),
                "page": page.get("رقم_الصفحة")
            })
    return texts, metas

import threading

from core import index_store
from core.fractions import to_frac
from core.chem import for_subject as _chem_for_subject


def prepare_source(text: str, subject: str = "") -> str:
    """**نصُّ الكتاب قبل أن يراه الموديل** — كسورُه وصيغُه مرمَّزة.

    ⚖️ الترميز يسبق الموديل لا يتبعه: البرومبت يأمره أن ينقل حرفياً، فإن
       وصله «س / ص» سطراً مسطّحاً نقله كما هو بأمانة — ورأى الطالبُ سطراً
       لا كسراً. فنُصلح المصدر، ويصير النقلُ الحرفيّ نقلاً للرسم.

    🔴 **وكانت منسوخةً في أربعة مواضع وغائبةً عن الخامس**: أسئلةُ الوزاري
       تُقرأ من ملفّاتها وتُعرض **كما هي بلا أي تحويل** — فمعادلاتُ
       الكيمياء وكسورُ الرياضيات في الامتحانات الوزارية كانت تصل الطالبَ
       نصّاً خاماً بينما يراها مرسومةً في الشرح. (شكوى المالك 2026-09-13.)
    """
    return _chem_for_subject(to_frac(text or ""), subject)

_build_semaphore = None

def get_build_semaphore():
    global _build_semaphore
    if _build_semaphore is None:
        _build_semaphore = asyncio.Semaphore(2)
    return _build_semaphore


def _normalize_for_search(text: str) -> str:
    """توحيد النص للبحث فقط — عربيّه ولاتينيّه.

    🔡 **والحروفُ اللاتينية تُخفَّض** (2026-09-14): الطرفان يمرّان بهذه
       الدالّة، فتخفيضُهما معاً يجعل المطابقة غيرَ حسّاسةٍ لحالة الحرف —
       و«Explain» كانت تنجو من قائمة الإيقاف بحرفٍ كبيرٍ واحد.
    """
    if not text:
        return text
    text = text.lower()
    text = re.sub(r'[أإآٱ]', 'ا', text)        # توحيد الألفات
    text = re.sub(r'ة', 'ه', text)              # ة → ه
    text = re.sub(r'ى', 'ي', text)              # ى → ي
    text = re.sub(r'[\u064B-\u065F]', '', text) # إزالة التشكيل
    return text


