import os
import json
import re
from typing import List, Dict, Any, Tuple, Optional
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer
import asyncio
import hashlib
import time
# من config
# ⚠️ **مصدر واحد للحدود.** كانت هذه الثوابت تُستورد من config ثم **يُعاد
#    تعريفها هنا فوراً** — فتغيير القيمة في `config.py` لا يفعل شيئاً إطلاقاً.
#    نفس فخّ `normalize_arabic` المكرّرة ونفس فخّ الرقم 6 المبعثر.
from config import (
    BASE_SUBJECTS_DIR, QA_TOP_K, EXAMS_BATCH_SIZE,
    MAX_PAGES_EXPLAIN_SUMMARY, MAX_PAGES_EXAMS, UNIT_BATCH_PAGES,
)

# المتغيرات
embed_model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")



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




def extract_relevant_book_texts(book_data, query, top_k=5):
    """
    تبحث في الكتاب أولاً (FAISS + كلمات)
    وترجع نصوص الصفحات المرتبطة فعلياً بالموضوع
    """
    texts, metas = extract_all_texts_and_metas(book_data)

    # بحث دلالي
    sem_results, _ = faiss_search(texts, query, top_k=top_k)

    # بحث مباشر بالكلمات
    keywords = re.findall(r'[\u0600-\u06FF]{3,}', query)
    direct_hits = []

    for txt in texts:
        if any(k in txt for k in keywords):
            direct_hits.append(txt)

    # دمج بدون تكرار
    final_texts = []
    for t in direct_hits + sem_results:
        if t not in final_texts:
            final_texts.append(t)

    return final_texts[:top_k]

def extract_all_texts_and_metas(book_data: List[dict], subject=None):
    texts = []
    metas = []
    for unit in book_data:
        for page in unit.get("الصفحات", []):
            # 🧮 الكسور تُرمَّز قبل أن يراها الموديل — فنقلُه الحرفيّ ينقلها مرسومة
            texts.append(_chem_for_subject(to_frac(page.get("نص_الصفحة", "")), subject))
            metas.append({
                "unit": unit.get("اسم_الوحدة"),
                "page": page.get("رقم_الصفحة")
            })
    return texts, metas

import threading

from core import index_store
from core.fractions import to_frac
from core.chem import for_subject as _chem_for_subject

_build_semaphore = None

def get_build_semaphore():
    global _build_semaphore
    if _build_semaphore is None:
        _build_semaphore = asyncio.Semaphore(2)
    return _build_semaphore


def _normalize_for_search(text: str) -> str:
    """توحيد النص العربي للبحث فقط"""
    if not text:
        return text
    text = re.sub(r'[أإآٱ]', 'ا', text)        # توحيد الألفات
    text = re.sub(r'ة', 'ه', text)              # ة → ه
    text = re.sub(r'ى', 'ي', text)              # ى → ي
    text = re.sub(r'[\u064B-\u065F]', '', text) # إزالة التشكيل
    return text


def build_index_sync(texts: List[str]):
    """بناء فهرس FAISS من نصوص — متزامن كي يُستدعى من الإحماء ومن الخيط معاً."""
    index_store.mark_build()
    emb = embed_model.encode(texts, convert_to_numpy=True, batch_size=32, show_progress_bar=False)
    faiss.normalize_L2(emb)
    index = faiss.IndexFlatIP(emb.shape[1])
    index.add(emb)
    return index


async def faiss_search(texts: List[str], query: str, top_k: int = QA_TOP_K, meta: Optional[dict] = None):
    """بحث دلالي. `meta` وصف اختياري (مادة/صف/وحدة) يُسجَّل في سجلّ الفهارس."""
    if not texts:
        return [], []
    
    try:
        # 🗂️ ثلاث طبقات: ذاكرة → قرص → بناء (راجع core/index_store.py).
        #    الإحماء عند الإقلاع يجعل هذه الدالة **لا تبني شيئاً** أثناء طلب طالب.
        fp = index_store.fingerprint(texts)

        index = index_store.get_mem(fp)
        if index is None:
            index = index_store.load_disk(fp)
            if index is not None:
                index_store.put_mem(fp, index)

        if index is None:
            async with get_build_semaphore():
                index = index_store.get_mem(fp)      # فحص ثانٍ بعد الانتظار
                if index is None:
                    index = await asyncio.wait_for(
                        asyncio.to_thread(build_index_sync, texts), timeout=90.0)
                    index_store.put_mem(fp, index)
                    index_store.save_disk(fp, index, meta)

        def _search_only():
            q_emb = embed_model.encode(
                [query],
                convert_to_numpy=True,
                show_progress_bar=False
            )
            faiss.normalize_L2(q_emb)
            D, I = index.search(q_emb, k=min(top_k, index.ntotal))
            return I[0]

        I_indices = await asyncio.wait_for(
            asyncio.to_thread(_search_only),
            timeout=15.0
        )

        results = []
        idxs = []
        for i in I_indices:
            if 0 <= i < len(texts):
                results.append(texts[i])
                idxs.append(int(i))
        return results, idxs

    except asyncio.TimeoutError:
        print("⚠️ FAISS timeout")
        return [], []
    except Exception as e:
        print(f"⚠️ FAISS error: {e}")
        return [], []


async def enhanced_qa_search(book_data, query, top_k=5):
    texts, metas = extract_all_texts_and_metas(book_data)
    
    # البحث الدلالي
    sem_results, sem_idxs = await faiss_search(texts, query, top_k=top_k)
    
    # البحث المباشر مع توحيد الحروف
    norm_query = _normalize_for_search(query)
    keywords = re.findall(r'[\u0600-\u06FF\w]{3,}', norm_query)
    
    direct_hits = []
    direct_idxs = []
    
    if keywords:
        for i, txt in enumerate(texts):
            norm_txt = _normalize_for_search(txt)
            if any(k in norm_txt for k in keywords):
                direct_hits.append(txt)  # النص الأصلي للموديل
                direct_idxs.append(i)
    
    # الدمج: المباشر أولاً لأنه أدق، ثم FAISS
    final_texts = []
    final_idxs = []
    
    for t, i in zip(direct_hits, direct_idxs):
        if i not in final_idxs:
            final_texts.append(t)
            final_idxs.append(i)
    
    for t, i in zip(sem_results, sem_idxs):
        if i not in final_idxs:
            final_texts.append(t)
            final_idxs.append(i)
    
    return final_texts[:top_k], final_idxs[:top_k]





def normalize_arabic(text: str) -> str:
    if not text:
        return ""

    text = text.lower()

    # إزالة التشكيل
    text = re.sub(r'[ًٌٍَُِّْـ]', '', text)

    # توحيد الحروف
    replacements = {
        "أ": "ا",
        "إ": "ا",
        "آ": "ا",
        "ى": "ي",
        "ة": "ه",
        "ؤ": "و",
        "ئ": "ي",
    }

    for k, v in replacements.items():
        text = text.replace(k, v)

    # إزالة أل التعريف
    text = re.sub(r'\bال', '', text)

    # إزالة أي شيء غير حروف عربية
    text = re.sub(r'[^\u0600-\u06FF\s]', ' ', text)

    # إزالة المسافات الزائدة
    text = re.sub(r'\s+', ' ', text).strip()

    return text
def extract_keywords(query: str):
    normalized = normalize_arabic(query)
    words = normalized.split()

    # تجاهل الكلمات القصيرة جداً
    return [w for w in words if len(w) >= 3]

def normalize_text_match(text: str) -> str:
    """
    دالة تنظيف قوية لضمان تطابق أسماء الدروس
    تزيل: المسافات، الهمزات، التشكيل
    """
    if not text:
        return ""
    text = text.lower().strip()
    # إزالة التشكيل
    text = re.sub(r'[ًٌٍَُِّْـ]', '', text)
    # توحيد الألف والياء والتاء
    text = re.sub(r'[أإآ]', 'ا', text)
    text = text.replace('ة', 'ه').replace('ى', 'ي')
    # إزالة المسافات تماماً لضمان التطابق حتى لو فيه مسافة زائدة
    text = re.sub(r'\s+', '', text)
    return text

def normalize_lesson_name(text: str) -> str:
    """
    تطبيع اسم الدرس للمقارنة
    - إزالة المسافات والـ _
    - توحيد الحروف العربية
    - تحويل لأحرف صغيرة
    """
    if not text:
        return ""
    
    # تحويل لأحرف صغيرة
    text = text.lower()
    
    # إزالة التشكيل
    import re
    text = re.sub(r'[ًٌٍَُِّْـ]', '', text)
    
    # توحيد الحروف العربية
    replacements = {
        "أ": "ا",
        "إ": "ا",
        "آ": "ا",
        "ى": "ي",
        "ة": "ه",
        "ؤ": "و",
        "ئ": "ي",
    }
    
    for old, new in replacements.items():
        text = text.replace(old, new)

    # 4-ب) 🔬 **الأُسّ كاملاً لا رقمه الأول.**
    #
    # 🔴 كان في الجدول أعلاه `'^2': '²'` استبدالاً أعمى، فـ«10^23» تصير
    #    «10²3» — و«6.022 × 10^23» هو **عدد أفوجادرو** يتكرّر في كل درس
    #    كيمياء كهربائية، و«10^-7» في الأس الهيدروجيني. أي أن الرقم الذي
    #    يراه الطالب **خاطئ** لا مشوّهُ الشكل فقط.
    text = _superscript(text)
    
    # إزالة المسافات والـ _
    text = text.replace(" ", "").replace("_", "")
    
    # إزالة أي شيء غير حروف عربية وأرقام
    text = re.sub(r'[^\u0600-\u06FF\d]', '', text)
    
    return text






def parse_exams_input(content: str):
    parts = [p.strip() for p in content.split(",") if p.strip() != ""]
    if not parts:
        return None, None
    year = parts[0]
    rest = parts[1:]
    return year, rest

def restrict_book_to_unit(book_data: List[dict], unit_name: str):
    """
    تحصر الكتاب داخل وحدة واحدة فقط
    """
    for unit in book_data:
        if unit_name == unit.get("اسم_الوحدة") or unit_name == str(unit.get("رقم_الوحدة")):
            return [unit]
        if unit_name in unit.get("اسم_الوحدة", ""):
            return [unit]
    return None

def collect_exam_questions_by_years(subject: str, years: List[str], grade: int = 3, track: str = "علمي"):
    exams_dir = subject_exams_dir(subject, grade, track)
    found = []
    if not os.path.isdir(exams_dir):
        return found
    for f in os.listdir(exams_dir):
        if not f.lower().endswith(".json"):
            continue
        file_year = os.path.splitext(f)[0].strip()
        if "الكل" not in years and file_year not in [str(y) for y in years]:
            continue
        data = load_json_safe(os.path.join(exams_dir, f))
        if not data:
            continue
        for block in data:
            questions = block.get("الاسئلة", [])
            for q in questions:
                found.append({
                    "سنة": block.get("سنة_الامتحان", file_year),
                    "الجزء": block.get("الجزء", ""),
                    "النوع": block.get("نوع_السؤال", ""),
                    "النص": q
                })
    return found

def filter_and_rank_exams(questions: list, user_text: str):
    """
    - أي سؤال يحتوي على كلمة واحدة على الأقل يطلع
    - يتم ترتيب الأسئلة حسب عدد الكلمات المتطابقة (الأكثر أولاً)
    """
    user_keywords = extract_keywords(user_text)
    if not user_keywords:
        return []

    scored_questions = []

    for q in questions:
        q_text = normalize_arabic(q.get("النص", ""))
        score = 0

        for kw in user_keywords:
            if kw in q_text:
                score += 1

        if score > 0:
            scored_questions.append((score, q))

    # ترتيب: الأعلى تطابقاً أولاً
    scored_questions.sort(key=lambda x: x[0], reverse=True)

    return [q for score, q in scored_questions]

# ℹ️ حُذفت نسخة ثانية متطابقة من normalize_arabic كانت معرّفة هنا
#    وتطغى على الأولى — سلوك واحد بتعريفين فخّ صامت.

def get_math_exam_years(branch: str):
    """يجلب السنوات المتاحة لفرع معين"""
    exams_dir = os.path.join(BASE_SUBJECTS_DIR, "رياضيات", "exams", branch)
    
    if not os.path.isdir(exams_dir):
        return []
    
    years = []
    for f in os.listdir(exams_dir):
        if f.endswith(".json"):
            year = os.path.splitext(f)[0]
            years.append(year)
    
    years.sort(reverse=True)
    return years


def get_math_exam_lessons(branch: str, year: str):
    """يجلب أسماء الدروس من ملف السنة"""
    exam_file = os.path.join(BASE_SUBJECTS_DIR, "رياضيات", "exams", branch, f"{year}.json")
    
    if not os.path.isfile(exam_file):
        return []
    
    data = load_json_safe(exam_file)
    if not data:
        return []
    
    # استخراج أسماء الدروس الفريدة
    lessons = list(set([item.get("الدرس", "") for item in data if item.get("الدرس")]))
    return lessons


def get_math_exam_questions(branch: str, year: str, lesson_name: str, count: int):
    exam_file = os.path.join(BASE_SUBJECTS_DIR, "رياضيات", "exams", branch, f"{year}.json")
    if not os.path.isfile(exam_file):
        return {"questions": [], "total": 0, "has_more": False}
    
    data = load_json_safe(exam_file)
    if not data:
        return {"questions": [], "total": 0, "has_more": False}
    
    # 🔥 المطابقة الذكية باستخدام الدالة الجديدة
    target_norm = normalize_text_match(lesson_name)
    all_questions = []
    
    for item in data:
        # نقارن الاسم بعد التنظيف
        current_lesson_norm = normalize_text_match(item.get("الدرس", ""))
        
        if current_lesson_norm == target_norm:
            questions = item.get("الاسئلة", [])
            for q in questions:
                all_questions.append({
                    "نص_السؤال": q.get("نص_السؤال", ""),
                    "الحل": q.get("الحل", "")
                })
    
    total = len(all_questions)
    batch = all_questions[:count] if count < total else all_questions
    has_more = count < total
    
    return {
        "questions": batch,
        "total": total,
        "has_more": has_more,
        "remaining": total - len(batch)
    }

def load_math_lesson(branch: str, lesson_name: str):
    """
    branch: تفاضل / تكامل / هندسة / جبر
    lesson_name: اسم الدرس — **باسم الملف أو بالاسم الداخلي `اسم_الدرس`**

    ⚠️ الاسمان يختلفان فعلاً في البيانات (ملف «القطع الزائد» واسمه الداخلي
       «القطع الزائد (الهذلول - Hyperbola)»)، وقائمةُ الدروس صارت ترجع الاسم
       الداخلي ليطابق `/content/capabilities`. فيلزم قبول الاثنين: الداخلي
       لما يأتي من الاختبار والقائمة الجديدة، والملفّي لمحادثاتٍ محفوظة
       قديماً ولأي نداءٍ لم يُحدَّث.

       ويُقبل الملف **بلا امتداد `.json`** كما يفعل بناء كتاب الدروس —
       ملف «مبدأ العد (طرائق العد )» بلا امتداد وكان يسقط هنا وحده.
    """
    base = math_branch_dir(branch)
    if not os.path.isdir(base):
        return None

    target = normalize_lesson_name(lesson_name)
    files = [f for f in sorted(os.listdir(base))
             if not f.startswith((".", "_")) and os.path.isfile(os.path.join(base, f))]

    # ١) مطابقة اسم الملف — الأرخص، بلا قراءة قرص
    for f in files:
        stem = f[:-5] if f.endswith(".json") else f
        if normalize_lesson_name(stem) == target:
            return load_json_safe(os.path.join(base, f))

    # ٢) مطابقة الاسم الداخلي — لا تُدفع كلفتها إلا عند فشل الأولى
    for f in files:
        data = load_json_safe(os.path.join(base, f))
        if not isinstance(data, dict):
            continue
        inner = data.get("اسم_الدرس") or data.get("اسم_درس") or ""
        if inner and normalize_lesson_name(inner) == target:
            return data

    return None




# ══════════════════════════════════════════════════════════
# ⚗️ قاعدة الصيغ البنائية — تُضاف لمواد الكيمياء العضوية وحدها
# ══════════════════════════════════════════════════════════
# 🔴 **لماذا هنا لا في `subjects/chemistry.py`؟** لأن وضعَي الدروس والوحدات
#    (المسار الحيّ اليوم) يمرّان بـ`core/lesson_mode.py` و`core/pages_mode.py`
#    وهما يستعملان **هذه البرومبتات المشتركة**؛ وبرومبتات `chemistry.py`
#    لا تُقرأ إلا في المسار القديم. تعديلُ ذاك وحده لا يغيّر شيئاً للطالب.
#
# والقاعدة قسمٌ مستقلٌّ بارز، وتنصّ صراحةً على أولويتها على «انقل حرفياً» —
# فالاستثناء المدسوس داخل جملة منع طويلة يُتجاهَل (درسٌ من تجربة الكسور).

# 🔒 **الكيمياء وحدها.** مصدرٌ واحد للنطاق مع `core/chem.py` — فما يُرمَّز
#    في نصّ الكتاب هو نفسه ما تُطلب كتابته في الرد، ولا تتفرّق الكلمة.
from core.chem import ORGANIC_SUBJECTS as _ORGANIC_SUBJECTS
from core.chem import REACTION_SUBJECTS as _REACTION_SUBJECTS
from core.nuclide import NUCLIDE_SUBJECTS as _NUCLIDE_SUBJECTS


def organic_structure_rules(subject: str) -> str:
    """تعليمة الترميز البنائي — نصٌّ فارغ للمواد التي لا صيغ فيها.

    ⚠️ **حدود هذه القاعدة (مقصودة وصريحة):** هي قاعدة **كتابةٍ وشكل** لا
       قاعدة **مصدر**. لا تبيح ذرّة معلومة من خارج الدرس، ولا تسمح برسم
       مركّبٍ لم يرد فيه. قواعد «المصدر الوحيد هو الكتاب» تبقى فوقها كلها.
       (الصياغة الأولى قالت «كلّما ذكرتَ مركّباً عضوياً أرفِق ترميزه» —
        وهي دعوةٌ مفتوحة للرسم من معرفة الموديل، فأُزيلت.)
    """
    if (subject or "").strip() not in _ORGANIC_SUBJECTS:
        return ""
    return (
        "\n════════════════════════════════════════════════════\n"
        "⚗️ **الصيغ البنائية والحلقات — طريقة الكتابة**\n"
        "════════════════════════════════════════════════════\n"
        "🔒 **أولاً وقبل كل شيء:** هذه قاعدةُ **شكلِ الكتابة** لا قاعدةَ "
        "**مصدرِ المعلومة**. المصدر يبقى نصَّ الدرس وحده كما تقول القواعد "
        "أعلاه. **لا ترسم مركّباً لم يرد في الدرس**، ولا تُكمل صيغةً ناقصة "
        "من معرفتك. إن لم يذكر الدرسُ الصيغة فلا تخترعها.\n\n"
        "🚫 وحين **يذكر الدرسُ** صيغةً أو شكلاً: **يُمنع رسمه بالرموز أو "
        "الشرطات أو داخل ```**، ولا تقل «لا أستطيع الرسم». أنت **تكتب "
        "ترميزاً** والتطبيق **يرسمه** للطالب.\n\n"
        "📌 السلسلة المفتوحة ⇐ \\chem{...}\n"
        "   • المجموعات موصولةً بشرطة: \\chem{CH3-CH2-CH2-NH2}\n"
        "   • الفرع بين قوسين بعد أصله مباشرةً: \\chem{CH3-CH(CH3)-CH3}\n"
        "   • الثنائية = والثلاثية #: \\chem{CH3-CH=O} · \\chem{CH3-C#N}\n\n"
        "📌 الحلقة ⇐ \\ring{...} — الأجزاء يفصلها | :\n"
        "   • العدد أولاً: \\ring{3} مثلث · \\ring{4} مربع · \\ring{6} سداسي\n"
        "   • ar للعطرية: \\ring{6|ar} بنزين\n"
        "   • رمز الذرّة داخل الحلقة: \\ring{6|ar|N} بيريدين · \\ring{6|NH} بيبيريدين\n"
        "   • +المجموعة المعلّقة: \\ring{6|ar|+NH2} أنيلين\n\n"
        "⚠️ **وهي تسبق قاعدة «انقل بلغة الدرس حرفياً» في الشكل وحده**: إن "
        "كتب الكتابُ الصيغةَ سطراً مسطّحاً فاكتبها أنت بالترميز — المعنى "
        "والمحتوى كما في الكتاب حرفياً، والشكلُ وحده هو ما يتغيّر.\n"
        "🚫 **وممنوعٌ وصفُ الشكل بالكلمات**: لا «شكل سداسي» ولا «حلقة "
        "مثلثة» ولا «يُمثل برسم مربع» — اكتب \\ring{...} مكانها.\n\n"
        "📥 **ونصُّ الدرس يصلك بالترميز جاهزاً — انقله كما هو.** أمثلة على "
        "النقل المطلوب:\n"
        "   نصّ الدرس : «1) رسمة \\ring{3} : تمثل بروبان حلقي (سيكلوبروبان)»\n"
        "   ✅ ردُّك    : «سيكلوبروبان \\ring{3} وصيغته C3H6.»\n"
        "   ❌ لا تكتب : «سيكلوبروبان يُمثل برسم مثلث».\n\n"
        "   نصّ الدرس : «2) رسمة \\ring{4} : تمثل سيكلوبيوتان.»\n"
        "   ✅ ردُّك    : «سيكلوبيوتان \\ring{4}.»\n"
        "   ❌ لا تكتب : «سيكلوبيوتان يتم تمثيله برسم مربع».\n\n"
        "   نصّ الدرس : «رسمة \\ring{6|ar} : شكل سداسي بداخله دائرة»\n"
        "   ✅ ردُّك    : «البنزين \\ring{6|ar}.»\n"
        "   ❌ لا تكتب : «البنزين شكل سداسي بداخله دائرة».\n\n"
        "🧪 **وأمثلةُ التسمية تُعرض رسماً ثم اسماً تحته**، ولا تُحكى بالكلمات:\n"
        "   نصّ الدرس : «الرسم: \\chem{CH3-CH2-CH2-C(=O)-NH-CH2-CH2-CH3}»\n"
        "              «التسمية: N-بروبيل بيوتاناميد.»\n"
        "   ✅ ردُّك    : «المثال الأول:\n"
        "                \\chem{CH3-CH2-CH2-C(=O)-NH-CH2-CH2-CH3}\n"
        "                التسمية: N-بروبيل بيوتاناميد.»\n"
        "   ❌ لا تكتب : «الرسم: لدينا سلسلة من أربع كربونات مرتبطة "
        "بذرة نيتروجين…» — هذا حكايةُ الرسم لا الرسم.\n\n"
        "🔁 **القاعدة باختصار:** كلُّ \\ring{...} أو \\chem{...} تراه في نصّ "
        "الدرس **يجب أن يظهر في ردّك كما هو**. عدُّها قبل الإرسال: إن كان "
        "في الدرس ثلاثة ترميزات فلا يصحّ أن يخلو ردُّك منها.\n"
    )


# 🔒 نطاقُ الأرقام العربية — **مصدرٌ واحد** مع الفلتر الذي يضمنها.
from core.arabic_digits import ARABIC_DIGIT_SUBJECTS as _ARABIC_DIGIT_SUBJECTS


def arabic_digits_rules(subject: str) -> str:
    """٠١٢ تعليمةُ شكل الأرقام — نصٌّ فارغ لما عدا مواد الأرقام العربية.

    🔴 **طلبُ المالك للفيزياء (2026-09-12):** «حوّل الأرقام كلها عربية،
       والسالب يكون من جهة يمين الرقم». وللرياضيات والمنطق قرارٌ أقدم
       (2026-09-09) — والكتاب اليمنيّ يكتبها ٠١٢٣ في الثلاثة.

    ⚖️ **والبرومبت يُقلّل، و[core/arabic_digits.py] يضمن.** لكن المتنَ
       العامّ كان يقول «والارقام العربيه» **لكل المواد** — عبارةٌ مجرّدة
       بلا مثال، ومسحُ ٨٠ سطراً من أجوبة الكيمياء الحقيقية وجد فيها
       **صفرَ** رقمٍ عربي. فالتعليمةُ المُلزمة مثالٌ ونطاق.

    ➖ **والإشارةُ تُكتب قبل عددها كالمعتاد** ولا تُقلب في النصّ: قلبُها
       يقع في الرسم وحده (الرقمُ العربي صنفُه AN فتقع إشارتُه يمينَه)،
       فلو كتبها الموديل بعد الرقم لانقلبت مرّتين.
    """
    if (subject or "").strip() not in _ARABIC_DIGIT_SUBJECTS:
        return ""
    return (
        "\n════════════════════════════════════════════════════\n"
        "٠١٢ **الأرقام بالعربية (٠١٢٣٤٥٦٧٨٩) لا باللاتينية (0123456789)**\n"
        "════════════════════════════════════════════════════\n"
        "• كل عددٍ في الشرح وفي المعادلة: «٥ نيوتن» لا «5 نيوتن» · "
        "«٢٩٨ كلفن» لا «298 كلفن» · «\\frac{١}{٢}» لا «\\frac{1}{2}».\n"
        "• والأُسُّ كذلك: «١٠^٨» لا «10^8».\n"
        "• ⚠️ **إلا رمزاً لاتينياً ملاصقاً رقمَه** فهو رمزٌ لا عدد ويُنقل "
        "كما في الكتاب: T1 · T2 · W0 · f0 · 500mA.\n"
        "• ➖ والسالبُ يُكتب **قبل** عدده كالمعتاد («-٥»)، ويظهر للطالب "
        "يمينَ العدد من نفسه — فلا تكتبه بعده.\n"
    )


def reaction_equation_rules(subject: str) -> str:
    """تعليمةُ كتابة معادلة التفاعل — نصٌّ فارغ لما عدا الكيمياء والأحياء.

    🔴 **ما رآه المالك (2026-09-12):** معادلتا انشطارٍ نوويّ تصلان الطالب
       مبعثرتين — «Al-27 + :قذيفة ألفا» و«3n <- (سريع)». والسببُ أن
       الموديل كتب العنوانَ العربيّ والمعادلةَ اللاتينية **في سطرٍ واحد**،
       فخلطهما الاتجاهُ الثنائي؛ وكتب السهمَ بشرطةٍ واحدة `->`.

    ⚖️ **والبرومبت يُقلّل والفلتر يضمن** ([latex_guard]): الرسّام في التطبيق
       صار يفهم `->` ويفصل العنوان بنفسه، وهذه التعليمة تُقلّل الحالات
       الشاذّة من أصلها. فلا يُعتمد عليها وحدها ولا يُستغنى عنها.
    """
    if (subject or "").strip() not in _REACTION_SUBJECTS:
        return ""
    return (
        "\n════════════════════════════════════════════════════\n"
        "⚗️ **معادلة التفاعل — سطرٌ مستقلّ وسهمٌ واحد**\n"
        "════════════════════════════════════════════════════\n"
        "📌 **كلُّ معادلةٍ في سطرٍ وحدَها**: لا عنوانَ معها في السطر نفسه "
        "ولا شرحَ بعدها. اكتب العنوان في سطر، والمعادلة في السطر التالي.\n"
        "   ✅ **معادلة انشطار اليورانيوم:**\n"
        "      U-235 + n --> Ba-141 + Kr-92 + 3n + طاقة\n"
        "   ❌ **معادلة انشطار اليورانيوم:** U-235 + n --> Ba-141 …\n\n"
        "📌 **السهم يُكتب `-->` دائماً** — لا «←» ولا «->» ولا كلمة «ينتج».\n"
        "📌 **الاتزان يُكتب `<=>`**.\n"
        "📌 **شرطُ التفاعل فوق السهم** بين قوسين معقوفين داخله:\n"
        "      CH3-CH2-OH --[حفاز نحاس / 200 م]--> CH3-CHO + H2\n"
        "📌 **ولا تضع نجوماً (`**`) حول المعادلة** — التطبيق يرسمها في "
        "إطارها، والنجومُ تظهر للطالب حروفاً.\n"
        # ☢️ ورمزُ النواة في الكيمياء وحدها — `to_nuclide` لا تعمل في
        #    غيرها، فلا يُؤمر بصيغةٍ لا تُرسم (`NUCLIDE_SUBJECTS`).
        + ("☢️ **ورمزُ النواة كما في الدرس حرفياً**: `^235_92U` — العددُ "
           "الكتلي بعد `^` والذرّيُّ بعد `_` ثم الرمز، والتطبيق يرسمهما "
           "مرصوفين فوق بعضهما كما في الكتاب.\n"
           "   ✅ ^235_92U + ^1_0n --> ^141_56Ba + ^92_36Kr + طاقة\n"
           "   ✅ ^27_13Al + ^4_2He --> ^30_15P + ^1_0n\n"
           "   ✅ وللإشارة موضعُها: ^0_+1β · ^0_-1e\n"
           "   ❌ Al-27 + He-4 --> P-30 + n-1\n"
           "   ❌ U-235 + n --> Ba-141\n"
           "🚫 **وصيغةُ الشرطة `Al-27` ممنوعة في المعادلات**: تُسقط العددَ "
           "الذرّي (١٣) فلا يستطيع التطبيقُ ولا الطالبُ استرجاعَه، ولا "
           "تتّزن المعادلةُ بدونه. انقل رمزَ الكتاب كما هو.\n"
           if (subject or "").strip() in _NUCLIDE_SUBJECTS else "")
        + "🔒 **والمحتوى كما في الدرس حرفياً**: هذه قاعدةُ شكلٍ لا قاعدةُ "
        "مصدر — لا تُكمل معادلةً ناقصة ولا تخترع متفاعلاً لم يُذكر.\n"
    )


def system_prompt_strict_explain(subject: str):
    return (
       f"أنت الآن في وضع مدرس داخل الصف لمادة {subject}. "
        "تتعامل مع الطالب وكأنك تشرح له أثناء الحصة الدراسية.\n\n"
        """ 📌 آلية التفكير:
- اقرأ السؤال جيداً.
- افهم المقصود الحقيقي منه.
- حدد المفهوم الأساسي وراء السؤال.
- ابدأ بشرح الفكرة من الداخل (التعريف، الفكرة الجوهرية,من الدرس).
- اشرح بالاعتماد على النص من ناحية الامثلة وطريقة الشرح .
- ثم وسّع الشرح من الخارج (السياق العام، لماذا نستخدمه، أين يطبق، علاقته بالمفاهيم الأخرى).

📌 ذكاء المحادثة:
- إذا كان السؤال مرتبطاً بسؤال سابق (مثل: وضح أكثر، ما الفرق، أعطني مثال):
  → أكمل من حيث توقفت.
- إذا كان سؤالاً جديداً:
  → ابدأ شرحاً جديداً من الصفر.
- احكم بذكاء على طبيعة السؤال.

📌 أسلوب الشرح:
1) اشرح باللغة العربية الفصحى السهلة.
2) لا تكتب كلمات إنجليزية داخل الشرح.
3) اشرح وكأنك داخل الصف فعلياً.
4) قسم الشرح إلى خطوات مرتبة عند الحاجة.
5) إذا وجدت معادلات، اشرحها بنفس الرموز الموجودة دون تغيير الصيغة.
6) لا تكتفِ بالتعريف، بل وضّح لماذا وكيف.

📌 مهم جداً:
- لا تكن جامداً.
- لا تكرر السؤال فقط.
- الهدف هو الفهم العميق.
- استخدم أمثلة تعليمية مبسطة عند الحاجة.
- اربط بين المفاهيم حتى تتكوّن صورة كاملة عند الطالب.

🎯 هدفك:
أن يفهم الطالب الفكرة بعمق ويستطيع إعادة شرحها بنفسه."""
        "القواعد الأساسية (مهم الالتزام بها بدقة):\n"
          "1) اشرح باللغة العربية فقط ولاتضيف اي كلمات من لغة اخرى اجنبية.\n"
          "2) اكتب المعادلات بشكل نصي نظيف ومقروء باللغة العربية و الارقام العربيه  والصيغه من اليمين لليسار في الحساب ، واستبدل علامات الشرطة السفلية (_) بمسافات عادية، وتجنب تماماً استخدام أي أكواد أو رموز برمجية مثل (\\quad) أو (LaTeX)..\n"
        "🧮 قاعدة الكسور (إلزامية ولا استثناء لها):\n"
        "كل كسر — أي «س على ص» — يُكتب حصراً بالصيغة \\frac{البسط}{المقام}.\n"
        "يُمنع كتابته بـ«/» أو «÷» أو بكلمة «على»، حتى لو كتبه الكتاب هكذا.\n"
        "⚠️ وحدات القياس ليست كسوراً وتبقى كما هي: م/ث · كجم.م/ث · كم/ساعة.\n"
        "أمثلة: السرعة = \\frac{المسافة}{الزمن} · ك = \\frac{الوزن}{تسارع الجاذبية}\n"
        "وهذه الصيغة وحدها مستثناة من منع LaTeX المذكور أعلاه.\n"
        "3) مصدر الإجابة الوحيد هو الكتاب المعطى لك فقط، ولا يُسمح باستخدام أي معلومات من خارج الكتاب.\n"
        "4) لا تضف معرفة عامة، ولا أمثلة خارجية، ولا اجتهاد شخصي.\n"
        "5) جميع الإجابات يجب أن تكون إما نقلًا مباشرًا من نص الكتاب أو شرحًا مبسطًا لمعنى موجود صراحة في الكتاب.\n\n"
        + organic_structure_rules(subject)
        + reaction_equation_rules(subject)
        + arabic_digits_rules(subject)
    )
    
    
def system_prompt_strict_summary(subject: str, level: int):
    levels = {1: "مفصل جداً", 2: "شامل", 3: "متوسط", 4: "مختصر", 5: "مختصر جداً في نقاط"}
    return (
        f"أنت ملخّص ماهر لمادة {subject}. التزم بالنص المقدم فقط. لخص بمستوى: {levels.get(level,'متوسط')}. "
        "تكلم باللغة العربية فقط ولاتضيف اي كلمات من لغة اخرى اجنبية.\n"
        " اكتب المعادلات بشكل نصي نظيف ومقروء باللغة العربية و الارقام العربيه  والصيغه من اليمين لليسار في الحساب ، واستبدل علامات الشرطة السفلية (_) بمسافات عادية، وتجنب تماماً استخدام أي أكواد أو رموز برمجية مثل (\\quad) أو (LaTeX)..\n"
        "🧮 قاعدة الكسور (إلزامية ولا استثناء لها):\n"
        "كل كسر — أي «س على ص» — يُكتب حصراً بالصيغة \\frac{البسط}{المقام}.\n"
        "يُمنع كتابته بـ«/» أو «÷» أو بكلمة «على»، حتى لو كتبه الكتاب هكذا.\n"
        "⚠️ وحدات القياس ليست كسوراً وتبقى كما هي: م/ث · كجم.م/ث · كم/ساعة.\n"
        "أمثلة: السرعة = \\frac{المسافة}{الزمن} · ك = \\frac{الوزن}{تسارع الجاذبية}\n"
        "وهذه الصيغة وحدها مستثناة من منع LaTeX المذكور أعلاه.\n"
        "لا تضف معلومات خارج النص. التنسيق يكون واضحًا ونقاط عند الحاجة."
        + organic_structure_rules(subject)
        + reaction_equation_rules(subject)
        + arabic_digits_rules(subject)
    )

def system_prompt_strict_qa(subject: str):
    return (
        f"أنت مدرس يجيب مباشرة من نص كتاب مادة {subject}. أجب بجملة أو جملتين مقتبستين أو مستخلصة من النص فقط. "
         "📌 ذكاء المحادثة:\n"
         "تكلم باللغة العربية فقط ولاتضيف اي كلمات من لغة اخرى اجنبية.\n"
        "- قد تكون هناك محادثة سابقة مع الطالب.\n"
        "- إذا كان سؤاله متصلاً بالمحادثة السابقة → استخدم السياق.\n"
        "- إذا كان سؤالاً مستقلاً تماماً → تجاهل السياق.\n\n"
        "إن لم تجد الإجابة داخل النص قل: 'عذراً، هذه المعلومة غير متوفرة في الكتاب'."
        " اكتب المعادلات بشكل نصي نظيف ومقروء باللغة العربية و الارقام العربيه  والصيغه من اليمين لليسار في الحساب ، واستبدل علامات الشرطة السفلية (_) بمسافات عادية، وتجنب تماماً استخدام أي أكواد أو رموز برمجية مثل (\\quad) أو (LaTeX)..\n"
        "🧮 قاعدة الكسور (إلزامية ولا استثناء لها):\n"
        "كل كسر — أي «س على ص» — يُكتب حصراً بالصيغة \\frac{البسط}{المقام}.\n"
        "يُمنع كتابته بـ«/» أو «÷» أو بكلمة «على»، حتى لو كتبه الكتاب هكذا.\n"
        "⚠️ وحدات القياس ليست كسوراً وتبقى كما هي: م/ث · كجم.م/ث · كم/ساعة.\n"
        "أمثلة: السرعة = \\frac{المسافة}{الزمن} · ك = \\frac{الوزن}{تسارع الجاذبية}\n"
        "وهذه الصيغة وحدها مستثناة من منع LaTeX المذكور أعلاه.\n"
    )
    
    
    
def system_prompt_strict_qa_improved(subject: str):
    """برومبت محسّن للإجابة على السؤال بدقة"""
    return (
        f"أنت مدرس {subject} محترف.\n\n"
        
        "🎯 مهمتك: الإجابة على سؤال الطالب بدقة وفقط على ما يطلبه.\n\n"
        
        "📌 القواعد الصارمة:\n"
        "1️⃣ اقرأ السؤال بعناية شديدة\n"
        "2️⃣ أجب فقط على ما يطلبه الطالب\n"
        "3️⃣ لا تضف معلومات إضافية لم يطلبها\n"
        "4️⃣ الجواب يجب أن يكون مختصراً وواضحاً\n\n"
        
        "📚 أمثلة:\n"
        "السؤال: 'ما هي المعادلات المهمة؟'\n"
        "الإجابة: (اكتب المعادلات فقط، بدون شرح أو مقدمة)\n\n"
        
        "السؤال: 'اشرح النقطة X من الدرس'\n"
        "الإجابة: (اشرح تلك النقطة فقط من النص)\n\n"
        
        "السؤال: 'ما الفرق بين A و B؟'\n"
        "الإجابة: (الفروقات فقط، بدون معلومات إضافية)\n\n"
        
        "⚠️ تحذير: لا تعطِ الدرس كاملاً! أجب على السؤال فقط."
        + organic_structure_rules(subject)
        + reaction_equation_rules(subject)
        + arabic_digits_rules(subject)
    )

def system_prompt_strict_exams(subject: str):
    return (
        f"أنت مساعد للأمتحانات لشهادة الثانوية في مادة {subject}. استخرج الأسئلة المطابقة من ملفات الأسئلة وفق معايير المستخدم. "
        "لا تضف أسئلة أو تغير في نصوص الأسئلة، فقط اعرض النصوص كما هي مع ذكر السنة والجزء ونوع السؤال."
    )
    
def system_prompt_math_explain():
    return (
        "أنت مدرس رياضيات تشرح من ملخص الطالب فقط.\n"
        # ⬅️ ذكاء السياق للرياضيات
        "📌 ذكاء المحادثة:\n"
        "- قد تكون شرحت درساً سابقاً للطالب.\n"
        "- إذا سألك عن نقطة في الشرح السابق → استخدم السياق وأجب بناءً عليه.\n"
        "- إذا طلب شرح موضوع جديد → ابدأ شرحاً جديداً.\n\n"
        "القواعد:\n"
        "1) الشرح يكون بنفس أسلوب الملخص.\n"
        "2) لا تضف قوانين غير موجودة.\n"
        "3) الشرح يكون تدريجي وبسيط.\n"
        "4) عند الأمثلة: اشرح خطوة خطوة كما هي.\n"
         "5) أشرح باللغة العربية فقط.ذى"
    )
    
    
    
    
def pages_with_headers(pages, subject=None):
    """نصُّ الصفحات للحقن في البرومبت — مُصلَحاً **قبل أن يراه الموديل**.

    ٠١٢ والأرقام تُعرَّب هنا أيضاً لا في المخرَج وحده: البرومبت يأمر
        بالنقل حرفياً، فما وصله عربياً نقله عربياً من تلقائه، ولا يبقى
        لفلتر [_finish] إلا الشوارد ([core/arabic_digits.py]).
    """
    from core.arabic_digits import for_subject as _arabic_digits
    blocks = []
    for p in pages:
        blocks.append(_arabic_digits(
            f"📄 الصفحة {p['رقم_الصفحة']}:\n"
            f"{_chem_for_subject(to_frac(p['نص_الصفحة']), subject)}", subject))
    return "\n\n".join(blocks)



def requested_pages(req) -> List[int]:
    """أرقام الصفحات المطلوبة — **مصدرٌ واحد لكل المواد**.

    🔴 **لماذا دالّة لا سطران؟** كان الاستخراج مكرّراً في ثلاثة مواضع
       (`pages_mode` ومرّتين في الأحياء)، فأيُّ تحسينٍ يصيب بعضَها ويُخطئ
       بعضَها. وقد وقع فعلاً: الاختيار المُبنيَن وُصل بـ`pages_mode` وحده،
       فبقيت الأحياء — وهي أكثر المواد استعمالاً لوضع الصفحات — تتجاهل
       ما يختاره الطالب ([sweep-siblings-before-reporting]).

    ⚖️ والأولوية للاختيار المُبنيَن، ثم استخراجُ الأرقام من الكلام —
       والثاني يبقى للعملاء القدامى ولمن كتبها بيده.
    """
    picked = list(getattr(req, "selected_pages", None) or [])
    if picked:
        return picked
    return [int(n) for n in re.findall(r"\d+", req.page_source or "")]


def fetch_pages_by_numbers(book_data: List[dict], page_nums: List[int]):
    """جلب صفحات محددة برقمها"""
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



def extract_all_texts_and_metas_physics(book_data: List[dict], subject=None):
    """استخراج جميع النصوص من بيانات الفيزياء بذكاء لدعم المعادلات والمسائل"""
    texts = []
    metas = []
    
    for unit in book_data:
        unit_name = unit.get("اسم_الوحدة", "")
        
        for lesson in unit.get("الدروس", []):
            lesson_name = lesson.get("اسم_الدرس", "")
            
            for part in lesson.get("الأجزاء", []):
                part_type = part.get("نوع", "")
                part_name = part.get("اسم_الجزء", "")
                
                content = part.get("المحتوى", [])
                
                if isinstance(content, list):
                    for item in content:
                        # ✅ التعديل السحري هنا: قراءة كل المفاتيح بذكاء
                        if isinstance(item, dict):
                            text_parts = []
                            # 1. إذا كان تعريف
                            if "المصطلح" in item:
                                text_parts.append(f"{item.get('المصطلح')}: {item.get('التعريف', '')}")
                            
                            # 2. إذا كانت معادلة أو مسألة حسابية (هنا كان الخلل)
                            if "الصيغة" in item:
                                text_parts.append(f"السؤال أو القانون: {item.get('الصيغة')}")
                            if "الاستخدام" in item:
                                text_parts.append(f"طريقة الحل: {item.get('الاستخدام')}")
                            if "مثال_رقمي" in item:
                                text_parts.append(f"الحل بالخطوات: {item.get('مثال_رقمي')}")
                                
                            # 3. احتياط لأي مفاتيح جديدة في المستقبل
                            if not text_parts:
                                for k, v in item.items():
                                    text_parts.append(f"{k}: {v}")
                            
                            text = " | ".join(text_parts)
                            
                        # إذا كان نص عادي (نقاط)
                        else:
                            text = str(item)
                        
                        if text.strip():
                            texts.append(text)
                            metas.append({
                                "unit": unit_name,
                                "lesson": lesson_name,
                                "part_type": part_type,
                                "part_name": part_name
                            })
                else:
                    # محتوى نصي مباشر
                    if content:
                        texts.append(str(content))
                        metas.append({
                            "unit": unit_name,
                            "lesson": lesson_name,
                            "part_type": part_type,
                            "part_name": part_name
                        })
    
    # 🧮 نفس القاعدة هنا: نصّ الدرس المهيكل يصل الموديل بكسور مرمَّزة
    return [_chem_for_subject(to_frac(t), subject) for t in texts], metas


async def enhanced_search_physics(book_data, query, top_k=5):
    texts, metas = extract_all_texts_and_metas_physics(book_data)
    if not texts:
        return [], []
    # أضفنا await هنا
    sem_results, idxs = await faiss_search(texts, query, top_k=top_k)
    keywords = extract_keywords(query)
    direct_hits = []
    direct_idxs = []
    for i, txt in enumerate(texts):
        if any(k in txt for k in keywords):
            direct_hits.append(txt)
            direct_idxs.append(i)
    final_texts = []
    final_idxs = []
    for t, i in zip(direct_hits, direct_idxs):
        if i not in final_idxs:
            final_texts.append(t)
            final_idxs.append(i)
    for t, i in zip(sem_results, idxs):
        if i not in final_idxs:
            final_texts.append(t)
            final_idxs.append(i)
    return final_texts[:top_k], final_idxs[:top_k]




# ══════════════════════════════════════════════════
# 🔬 الأُسّ العلويّ — رقماً كاملاً لا رقمه الأول
# ══════════════════════════════════════════════════
_SUP = str.maketrans("0123456789+-", "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻")
# ⚠️ ويشمل الشحنةَ وحدها: «2Cl^{-}» و«Cu^{+2}» — والأيونات لا تُكتب إلا
#    هكذا في كل معادلات الكيمياء الكهربائية.
# ⚠️ **ولا بدّ من أُسٍّ فعليّ**: `\d*` وحدها تطابق الفراغ، فأكلت الرمز `^`
#    من «(س-أ)^(ن+1)» وأضاعت الأُسّ كلَّه — عيبٌ أسوأ ممّا جئنا نُصلحه.
_SUP_RE = re.compile(r"\^\{?([+-]?\d+|[+-])\}?")


def _superscript(text: str) -> str:
    """«10^23» ⇒ «10²³» · «10^-7» ⇒ «10⁻⁷» · «س^2» ⇒ «س²».

    ⚠️ **والأُسّ غير الرقمي يبقى كما هو**: «(س - أ)^(ن+1)» ليس له مقابلٌ
       في يونيكود، ورسّامُ التطبيق يعرف `^` فيرفعه بنفسه. فتحويلُ ما لا
       يُحوَّل يُفسد ما كان سليماً.
    """
    if "^" not in text:
        return text
    return _SUP_RE.sub(lambda m: m.group(1).translate(_SUP), text)


# ══════════════════════════════════════════════════
# 🏁 اللمسات الأخيرة — **مشتركةٌ بين كل المسارات**
# ══════════════════════════════════════════════════
# 🔴 **علّةٌ بنيويّة تكرّرت ثلاث مرات:** كل إصلاحٍ كنت أصله بـ
#    `format_arabic_math` — وهي مسارُ المعالجات القديمة — بينما **المسار
#    الحيّ** لوضعَي الدروس والوحدات هو `core/lesson_mode.py` و
#    `core/pages_mode.py`، وهما يناديان `strip_stray_latex` وحدها.
#    فوصل الإصلاح إلى نصف التطبيق وغاب عن نصفه ([organic-chem-drawing]).
#
# ⭐ فصارت اللمسات الأخيرة **دالّةً واحدة يناديها المساران**، ويحرسها
#    اختبارٌ يقارن ناتجهما حرفاً بحرف على مجموعةٍ من الحالات.

# ⚗️ كسرٌ بسطُه أو مقامُه **سهمٌ أو عاملُ جمع** ليس كسراً:
#    الموديل يكتب «\frac{CuCl2(aq)}{→} \frac{Cu+2}{+}» ظانّاً أن `\frac`
#    تركّب المعادلة رأسياً — فيخرج على الشاشة كسرٌ مقامُه سهم. رُصد في
#    ١٦ موضعاً من ١٦٥ شرحاً حقيقياً (2026-09-10).
_BRACED = r"((?:[^{}]|\{[^{}]*\})*)"
_PSEUDO_FRAC = re.compile(
    r"\\frac\{" + _BRACED + r"\}\{\s*([→←⇌+\-=]|-->|<--)\s*\}")

# ⚠️ و`\frac` **بمجموعةٍ واحدة** ترميزٌ ناقص لا كسر: «\frac{2Cl^{-}(aq)}»
#    يخرج على الشاشة كسراً بلا مقام — أو ترميزاً عارياً. يُفكّ إلى محتواه.
_LONE_FRAC = re.compile(r"\\frac\{" + _BRACED + r"\}(?!\s*\{)")


def _finish(text: str, subject: str = "") -> str:
    """ما يمرّ به **كل** جوابٍ قبل الطالب، أياً كان مساره.

    ⚠️ و`subject` تُمرَّر كي يبقى **رسّامُ كل مادةٍ في مادته**: تحويل «جذر»
       إلى `\\sqrt` كارثةٌ في الأحياء («جذر وتدي») — راجع [core/roots.py].
    """
    if not text:
        return text
    from core.chem import unwrap_equation_chem
    from core.roots import to_sqrt
    from core.factorial import to_factorial
    from core.counting import to_counting
    from core.powers import to_power
    from core.symbols import to_symbols
    from core.overline import to_overline
    from core.nuclide import to_nuclide
    from core.formula import to_subscript
    from core.tex_blocks import strip_broken_tex
    from core.arabic_digits import for_subject as _arabic_digits
    text = strip_broken_tex(text)
    text = unwrap_equation_chem(text)
    text = to_sqrt(text, subject)
    text = to_factorial(text, subject)
    text = to_counting(text, subject)
    text = to_symbols(text, subject)
    text = to_overline(text, subject)
    # ☢️ **قبل `to_power` لا بعدها**: رمزُ النواة `^235_92U` وحدةٌ واحدة،
    #    ولو سبقها الأُسُّ لأخذ العددَ الكتلي وحده وترك الذرّيَّ عارياً —
    #    وهو ما رآه المالك «\sup{235}_92U» على الشاشة.
    text = to_nuclide(text, subject)
    # ⚗️ **ودليلُ الصيغة ينخفض**: «H2SO4» ⇒ «H₂SO₄» (طلب المالك 2026-09-12).
    #    بعد `to_nuclide` كي تكون أرقامُ النواة داخل `\nuc{}` فتُحجب.
    text = to_subscript(text, subject)
    # يُكرَّر لأن الكسور الزائفة متجاورة: «\frac{أ}{→} \frac{ب}{+}»
    for _ in range(4):
        new = _PSEUDO_FRAC.sub(r"\1 \2 ", text)
        if new == text:
            break
        text = new
    text = _LONE_FRAC.sub(r"\1", text)
    # 🔴 **آليةٌ واحدة للأُسّ في المواد الرياضية**: `to_power` تردّ كلَّ
    #    الصيغ إلى `\sup{…}` فيرسمها التطبيق مرفوعةً — بما فيها المتغيّر
    #    والسالب وما بين قوسين، وهي التي كانت تبقى خاماً على الشاشة.
    text = to_power(text, subject)
    # ⚖️ و`_superscript` تبقى **للمواد الأخرى وحدها**: أحياءٌ فيها
    #    «10^23» بلا رسّامٍ رياضيّ، فيونيكود خيرٌ من «^» عارية.
    #    (وفي المواد الرياضية لا يبقى لها ما تعمله.)
    text = _superscript(text)
    # ٠١٢ **والأرقام عربية في مادّتها** (الرياضيات والمنطق والفيزياء):
    #     قرارُ المالك للفيزياء 2026-09-12، وللأوّلَين 2026-09-09.
    #
    # ⚖️ **وموضعُها هنا لا في كل معالجٍ على حدة**: كانت تُنادى في
    #    `subjects/math` و`subjects/logic` وحدهما، فالفيزياء — ومسارُها
    #    الحيّ `lesson_mode`/`pages_mode` — لم تكن لتراها. وهذه الدالّة
    #    يمرّ بها **كل** جواب أياً كان مساره.
    #
    # 📏 **وقُيس أن التقديم لا يُغيّر شيئاً**: `to_arabic` صارت تحجب أسماء
    #    أوامر اللاتيك، فتبادلت مع `latex_guard.clean` و`to_frac` — ٢٥١٦٤
    #    سطراً من الرياضيات والمنطق والفيزياء: **صفرُ اختلاف**.
    text = _arabic_digits(text, subject)
    # فراغاتٌ مضاعفة خلّفها فكُّ الكسور الزائفة
    return re.sub(r"[ \t]{2,}", " ", text)

def format_arabic_math(text: str, subject: str = "") -> str:
    """
    فلتر سحري يحول معادلات LaTeX المعقدة إلى نصوص عربية مقروءة بوضوح
    ويحافظ على تنسيق الأسطر (النزول للسطر).
    """
    if not text:
        return ""
    
    # 1. إزالة أقواس LaTeX المزعجة
    text = re.sub(r'\\\[|\\\]', '', text)
    text = re.sub(r'\\\(|\\\)', '', text)
    text = text.replace('$', '')
    
    # 2. استخراج الكلمات العربية من داخل \text{} و \mathrm{}
    text = re.sub(r'\\text\{([^}]+)\}', r'\1', text)
    text = re.sub(r'\\mathrm\{([^}]+)\}', r'\1', text)
    
    # 3. ✅ الكسور تُترك كما هي: `\frac{A}{B}` هو الترميز الذي يرسمه التطبيق
    #    بسطاً فوق مقام. كان هنا تحويلٌ إلى «(A / B)» يُفقد الكسرَ صورتَه
    #    ويجعله ملتبساً على الطالب («أ / ب + ج» لا يُجزم بمعناها).
    #    هذا الفلتر مركزي: تستدعيه كل المواد، فتصحيحه هنا يكفيها جميعاً.
        
    # 4. استبدال الرموز الرياضية اللاتينية برموز عادية
    replacements = {
        r'\times': '×',
        r'\div': '÷',
        r'\cdot': '·',
        r'\approx': '≈',
        r'\neq': '≠',
        r'\leq': '≤',
        r'\geq': '≥',
        r'\pm': '±',
        # 🔴 **حُذف `\sqrt` ⇦ `√`** (2026-09-10): كان يسبق الرسّام، وصار
        #    بعده يُتلف — «\sqrt{٣}» تخرج «√{٣}» بأقواسها على الشاشة.
        #    الرسّام يفهم `\sqrt` ويرسم العلامة والسقف معاً.
        r'\infty': '∞',
        r'\pi': 'π',
        r'\theta': 'θ',
        r'\lambda': 'λ',
        r'\Delta': 'Δ',
        r'\Omega': 'Ω',
        r'\alpha': 'α',
        r'\beta': 'β',
        r'\gamma': 'γ',
        r'\mu': 'μ',
        r'\\': '\n', # تحويل النزول للسطر في اللاتيك إلى نزول سطر عادي
    }
    
    for old, new in replacements.items():
        text = text.replace(old, new)

    # 🏁 اللمسات المشتركة (أُسّ · غلافُ chem · كسرٌ زائف · جذر) — [_finish].
    text = _finish(text, subject)

    # 5. التعديل هنا: استخدام [ \t]+ بدلاً من \s+ عشان ما نمسح النزول للسطر (\n)
    text = re.sub(r'[ \t]+', ' ', text).strip()

    # 6. 🛡️ **الحارس الأخير**: أي أمر LaTeX لم تعرفه القائمة أعلاه يُحوَّل
    #    إلى رمزه أو يُحذف — ولا يصل الطالبَ اسمُه الإنجليزي.
    #
    #    🔴 هذا بالضبط ما كان يقع في «ابدأ الشرح الذكي»: مسارُ الرياضيات
    #       يمرّ بهذه الدالة **وحدها** (بلا `strip_stray_latex`)، والقائمة
    #       أعلاه لا تعرف `\int` — فيصل الطالبَ «int» وسط شرحٍ عربي.
    #       ومسحُ ٦٤ درساً أظهرها ٢٣ مرة، ومعها `quad` و`left` و`right`.
    from core.latex_guard import clean as _guard_clean
    text = _guard_clean(text)

    # 7. 🔢 **شرطةٌ ناجية في مخرَج الموديل** ⇒ كسرٌ مرمَّز.
    #
    #    إصلاح نصّ الكتاب (`format_lesson_safely`) خفض الشرطات من ٤٢ إلى صفر
    #    في أكثر الدروس، لكن الموديل يكتب أحياناً ما ليس في الكتاب —
    #    «ط/2» و«دص/دس» في اشتقاقه هو. فالشبكة الثانية على المخرَج.
    #
    # ⚠️ و`to_frac` تميّز الوحدة من الكسر ومن «أو» العربية ([core/fractions.py])،
    #    فـ«٢٠ م/ث» و«انطلاق / انبعاث» تمرّان بلا مساس.
    from core.fractions import to_frac as _to_frac
    return _to_frac(text)

# ══════════════════════════════════════════════════════════
# 🧹 تنظيف اللاتيك الشارد من رد الموديل
# ══════════════════════════════════════════════════════════
# المسارات القديمة (`subjects/*.py`) تنظّف الرد بنفسها، أما مسارا النسخة
# الثالثة (`core/lesson_mode.py` و`core/pages_mode.py`) — وهما المسار الحيّ
# اليوم — فلا ينظّفان شيئاً. فظهر على شاشة الطالب `\quad` بين صيغتين
# و`\[ ... \]` حول قانون. والترميزات الثلاثة التي **يرسمها التطبيق**
# مستثناة صراحةً، وإلا حُذف ما وُلِّد عمداً (علّة وقعت مع `\frac` من قبل).

# ℹ️ حُذفت من هنا قائمةٌ ثالثة للترميزات المُستثناة (`frac` · `chem` ·
#    `ring`) — كانت **ميتة** (لا يناديها أحد) و**متخلّفة** (ثلاثةٌ من
#    عشرة). والمصدرُ الواحد هو `latex_guard.KEPT` ونظيرُه في التطبيق
#    `kMathTokens`. وهي خامسُ مرّةٍ تتكرر فيها علّةُ القائمة المنسوخة.
_LATEX_DELIMS = re.compile(r"\\[\[\]()]")


def strip_stray_latex(answer: str, subject: str = "") -> str:
    """ينظّف أوامر اللاتيك عدا ترميزات الرسم — ويترك النصّ العربي كما هو.

    🔄 **صار يُحوّل لا يحذف** (2026-09-09): الحذف الأعمى كان يُفقد المعادلةَ
       رموزها — ``\\int`` تختفي فتصير «تكامل د(س) دس» بلا علامة تكامل، وهي
       **أسوأ من كلمةٍ إنجليزية** لأنها تبدو صحيحة ولا تُنبّه أحداً.
       `latex_guard` يحوّلها إلى «∫» التي يرسمها الخطّ، ولا يحذف إلا ما
       لا مقابل له.
    """
    if not answer:
        return answer
    from core.latex_guard import clean as _guard_clean
    # 💲 كتلُ «$…$» أوّلاً: الصالحةُ يُنزع دولارها ويُسلَّم محتواها
    #    للرسّام، والمشوّهةُ تُحذف كاملةً — [core/tex_blocks.py].
    from core.tex_blocks import strip_broken_tex
    answer = strip_broken_tex(answer)
    return _finish(_guard_clean(_LATEX_DELIMS.sub("", answer)), subject)
