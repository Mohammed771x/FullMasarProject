import os
import json
import re
from typing import List, Dict, Any, Tuple
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer
import asyncio
import hashlib
import time
# من config
from config import BASE_SUBJECTS_DIR, QA_TOP_K, EXAMS_BATCH_SIZE

# المتغيرات
embed_model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")


MAX_PAGES_EXPLAIN_SUMMARY = 3      # أقصى صفحات لشرح/تلخيص عند الإدخال
MAX_PAGES_EXAMS = 5                # أقصى صفحات لبحث الوزاري عبر الصفحات
EXAMS_BATCH_SIZE = 10              # دفعة عرض أسئلة وزاري
UNIT_BATCH_PAGES = 3               # عدد صفحات في كل دفعة عند شرح/تلخيص الوحدة
QA_TOP_K = 3                       # عدد نتائج FAISS للسؤال



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





def subject_book_path(subject: str) -> str:
    return os.path.join(BASE_SUBJECTS_DIR, subject, f"{subject}.json")

def subject_exams_dir(subject: str) -> str:
    return os.path.join(BASE_SUBJECTS_DIR, subject, "exams")

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

def extract_all_texts_and_metas(book_data: List[dict]):
    texts = []
    metas = []
    for unit in book_data:
        for page in unit.get("الصفحات", []):
            texts.append(page.get("نص_الصفحة", ""))
            metas.append({
                "unit": unit.get("اسم_الوحدة"),
                "page": page.get("رقم_الصفحة")
            })
    return texts, metas

import threading
_faiss_index_cache = {}
_faiss_lock = threading.Lock()
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


async def faiss_search(texts: List[str], query: str, top_k: int = QA_TOP_K):
    if not texts:
        return [], []
    
    try:
        # ✅ بصمة أقوى: طول + أول نص + آخر نص
        fingerprint_data = f"{len(texts)}_{texts[0][:80]}_{texts[-1][:80]}"
        fingerprint = hashlib.md5(fingerprint_data.encode('utf-8')).hexdigest()[:16]

        if fingerprint not in _faiss_index_cache:
            async with get_build_semaphore():
                if fingerprint not in _faiss_index_cache:
                    def _build_index():
                        emb = embed_model.encode(
                            texts,
                            convert_to_numpy=True,
                            batch_size=32,
                            show_progress_bar=False
                        )
                        faiss.normalize_L2(emb)
                        index = faiss.IndexFlatIP(emb.shape[1])
                        index.add(emb)
                        return index
                    
                    built = await asyncio.wait_for(
                        asyncio.to_thread(_build_index),
                        timeout=40.0
                    )
                    with _faiss_lock:
                        _faiss_index_cache[fingerprint] = built

        index = _faiss_index_cache[fingerprint]

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

def collect_exam_questions_by_years(subject: str, years: List[str]):
    exams_dir = subject_exams_dir(subject)
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

def filter_exams_by_keyword(questions: list, keyword: str):
    """
    ترجع كل الأسئلة الوزارية التي تحتوي على الكلمة أو العبارة المطلوبة
    """
    keyword = keyword.strip()
    if not keyword:
        return []

    matched = []
    for q in questions:
        text = q.get("النص", "")
        if keyword in text:
            matched.append(q)

    return matched

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



def filter_exams_smart(questions: list, query: str, min_hits: int = 2):
    """
    ترجع الأسئلة التي تطابق الموضوع بعدد كافٍ من الكلمات
    """
    keywords = extract_keywords(query)
    if not keywords:
        return []

    matched = []

    for q in questions:
        q_text = normalize_arabic(q.get("النص", ""))
        hits = 0

        for w in keywords:
            if w in q_text:
                hits += 1

        if hits >= min_hits:
            matched.append(q)

    return matched






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
    lesson_name: اسم الدرس
    """
    base = os.path.join(BASE_SUBJECTS_DIR, "رياضيات", branch)
    if not os.path.isdir(base):
        return None

    # ✅ تطبيع اسم الدرس المطلوب
    normalized_lesson = normalize_lesson_name(lesson_name)

    for f in os.listdir(base):
        if not f.endswith(".json"):
            continue
        
        # ✅ تطبيع اسم الملف
        file_name = os.path.splitext(f)[0]
        normalized_file = normalize_lesson_name(file_name)
        
        # ✅ مقارنة بعد التطبيع
        if normalized_lesson == normalized_file:
            return load_json_safe(os.path.join(base, f))

    return None




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
          "2) اكتب المعادلات بشكل نصي نظيف ومقروء باللغة العربية و الارقام العربيه  والصيغه من اليمين لليسار في الحساب ، واستبدل علامات الشرطة السفلية (_) بمسافات عادية، وتجنب تماماً استخدام أي أكواد أو رموز برمجية مثل (\quad) أو (LaTeX)..\n"
        "3) مصدر الإجابة الوحيد هو الكتاب المعطى لك فقط، ولا يُسمح باستخدام أي معلومات من خارج الكتاب.\n"
        "4) لا تضف معرفة عامة، ولا أمثلة خارجية، ولا اجتهاد شخصي.\n"
        "5) جميع الإجابات يجب أن تكون إما نقلًا مباشرًا من نص الكتاب أو شرحًا مبسطًا لمعنى موجود صراحة في الكتاب.\n\n"
       
    )
    
    
def system_prompt_strict_summary(subject: str, level: int):
    levels = {1: "مفصل جداً", 2: "شامل", 3: "متوسط", 4: "مختصر", 5: "مختصر جداً في نقاط"}
    return (
        f"أنت ملخّص ماهر لمادة {subject}. التزم بالنص المقدم فقط. لخص بمستوى: {levels.get(level,'متوسط')}. "
        "تكلم باللغة العربية فقط ولاتضيف اي كلمات من لغة اخرى اجنبية.\n"
        " اكتب المعادلات بشكل نصي نظيف ومقروء باللغة العربية و الارقام العربيه  والصيغه من اليمين لليسار في الحساب ، واستبدل علامات الشرطة السفلية (_) بمسافات عادية، وتجنب تماماً استخدام أي أكواد أو رموز برمجية مثل (\quad) أو (LaTeX)..\n"
        "لا تضف معلومات خارج النص. التنسيق يكون واضحًا ونقاط عند الحاجة."
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
        " اكتب المعادلات بشكل نصي نظيف ومقروء باللغة العربية و الارقام العربيه  والصيغه من اليمين لليسار في الحساب ، واستبدل علامات الشرطة السفلية (_) بمسافات عادية، وتجنب تماماً استخدام أي أكواد أو رموز برمجية مثل (\quad) أو (LaTeX)..\n"
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
    
    
    
    
def pages_with_headers(pages):
    blocks = []
    for p in pages:
        blocks.append(f"📄 الصفحة {p['رقم_الصفحة']}:\n{p['نص_الصفحة']}")
    return "\n\n".join(blocks)



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



def extract_all_texts_and_metas_physics(book_data: List[dict]):
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
    
    return texts, metas


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



def format_arabic_math(text: str) -> str:
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
    
    # 3. تحويل الكسور ( \frac{A}{B} ) إلى شكل مقروء ( A / B )
    while r'\frac' in text:
        text = re.sub(r'\\frac\{([^}]+)\}\{([^}]+)\}', r' (\1 / \2) ', text)
        
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
        r'\sqrt': '√',
        r'^{2}': '²',
        r'^2': '²',
        r'^{3}': '³',
        r'^3': '³',
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
        
    # 5. التعديل هنا: استخدام [ \t]+ بدلاً من \s+ عشان ما نمسح النزول للسطر (\n)
    text = re.sub(r'[ \t]+', ' ', text).strip()
    
    return text