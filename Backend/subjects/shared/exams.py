# -*- coding: utf-8 -*-
"""📄 الامتحاناتُ ودروسُ الرياضيات

    جزءٌ من [subjects/common] — فُصل 2026-09-20 بأمر المالك:
    «كل مادة/قسم في ملفٍ لحاله، فالتعديلُ على نطاقٍ أقلّ».
    والنصُّ هنا **منقولٌ حرفاً بحرف** من الملف الأصل بلا تغيير سطر.
"""
import os
import re
from typing import List
from config import BASE_SUBJECTS_DIR
from .content import load_json_safe, math_branch_dir, prepare_source, subject_exams_dir
from .mathfmt import _superscript
from .context import normalize_arabic


# ══════════════════════════════════════════════════════════
# 🛡️ مقطعُ مسارٍ من الطالب — لا يخرج من مجلّده
# ══════════════════════════════════════════════════════════
# ☢️ **وُجد ٢٠٢٦-٠٩-٢٣:** السنةُ والفرعُ يصلان من جسم الطلب ويُركَّبان في
#    مسار ملفٍّ مباشرةً (`f"{year}.json"`). فـ`year = "../../../x"` يقرأ أيَّ
#    ملفّ JSON على الخادم بصلاحيات العملية — وبينها ملفّاتُ الإعدادات.
#    والمعالجُ يُحلّل ما قرأه ويعيد منه نصوصاً إلى الطالب.
#
# ✅ الحارسُ هنا **قائمةٌ بيضاء لا سوداء**: مقطعٌ واحدٌ بلا فاصلٍ ولا نقطتين
#    ولا محرفِ تحكّم، وبطولٍ معقول. أسماءُ السنوات («2019» · «2022 الدور
#    الأول») والفروع («تفاضل») كلُّها تمرّ.
_SAFE_SEGMENT = re.compile(r"[\w\u0600-\u06FF][\w\u0600-\u06FF \-()]{0,63}")


def safe_segment(value) -> bool:
    """هل يصلح [value] اسمَ ملفٍّ أو مجلّدٍ واحدٍ داخل مجلّد البيانات؟"""
    if not isinstance(value, str) or ".." in value:
        return False
    return bool(_SAFE_SEGMENT.fullmatch(value.strip()))


def clamp_count(raw, default: int, lo: int = 1, hi: int = 20) -> int:
    """عددُ أسئلةٍ/قطعٍ من الطالب — بين [lo] و[hi] دائماً.

    📏 كان يُقبل كما هو: «١٠٠٠٠ قطعة» تُجمّع وتُنسَّق وتُرسل ردّاً واحداً.
    والتطبيقُ يقيّده بمِعدادٍ من ١ إلى ٢٠، وهذا جدارُ من لا يمرّ به.
    """
    try:
        n = int(str(raw).strip())
    except (TypeError, ValueError):
        return default
    return max(lo, min(hi, n))


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
                    # 🖌️ **والوزاريُّ نصُّ كتابٍ كغيره**: كسورُه تُرسم
                    #    وصيغُه العضوية تُرمَّز، فلا يكون الرسّام ميزةَ
                    #    وضعٍ دون وضع.
                    "النص": prepare_source(q if isinstance(q, str) else str(q),
                                           subject),
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
    if not safe_segment(branch):
        return []
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
    if not (safe_segment(branch) and safe_segment(year)):
        return []
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
    if not (safe_segment(branch) and safe_segment(year)):
        return {"questions": [], "total": 0, "has_more": False}
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
                # 🧮 **والوزاريُّ الرياضيّ أحوجُ ما يكون للرسّام**: أسئلتُه
                #    كسورٌ وأُسُسٌ وجذور، وكانت تُعرض نصّاً مسطّحاً بينما
                #    يراها الطالبُ مرسومةً في الشرح من الدرس نفسه.
                all_questions.append({
                    "نص_السؤال": prepare_source(q.get("نص_السؤال", ""), "رياضيات"),
                    "الحل": prepare_source(q.get("الحل", ""), "رياضيات"),
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




