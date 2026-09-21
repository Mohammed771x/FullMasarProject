# -*- coding: utf-8 -*-
"""📄 محتوى الكتب — وحدات ودروس وامتحانات

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    JSONResponse, Request, _is_legacy_content_scope, app,
    get_math_exam_lessons, get_math_exam_years, load_json_safe, os,
    subject_book_path, v3_capabilities, v3_curriculum, v3_index_store,
    v3_ratelimit, v3_warmup,
)


@app.get("/subjects/units")
async def get_subject_units(subject: str, grade: int = 3, track: str = "علمي"):
    """
    جلب الوحدات بشكل ذكي وموحد يدعم جميع صيغ ملفات JSON
    بدون أخطاء AttributeError
    """
    units = []

    # 🎓 المادة يجب أن تكون مقررة على هذا الصف/المسار — وإلا فلا وحدات.
    g, t = v3_curriculum.normalize_grade_track(grade, track)
    subject = subject.strip()
    if not v3_curriculum.is_valid_subject(g, t, subject):
        return units

    # 📐 الرياضيات (حالة خاصة لأن وحداتها ثابتة)
    if subject == "رياضيات":
        return ["تفاضل", "تكامل", "جبر", "هندسة", "احتمالات"]

    # تحميل كتاب هذا الصف/المسار تحديداً
    book = load_json_safe(subject_book_path(subject, g, t))
    if not book:
        return units

    # ==========================================
    # 🧠 المنطق الذكي لاستخراج الوحدات لجميع المواد
    # ==========================================
    
    # 1. تحديد مكان قائمة الوحدات بناءً على صيغة الملف
    units_list = []
    if isinstance(book, list):
        # صيغة الأحياء (قائمة مباشرة)
        units_list = book
    elif isinstance(book, dict):
        # صيغة الإنجليزي والفيزياء والكيمياء (قاموس يحتوي على مفتاح "الوحدات")
        units_list = book.get("الوحدات", [])

    # 2. المرور على الوحدات واستخراج الأسماء بأمان تام
    if isinstance(units_list, list):
        for unit in units_list:
            # ✅ الفلتر الأهم: التأكد أن العنصر قاموس (dict) وليس نصاً (str)
            # هذا السطر هو الذي يمنع ظهور خطأ AttributeError تماماً
            if isinstance(unit, dict):
                unit_name = unit.get("اسم_الوحدة", "").strip()
                if unit_name and unit_name not in units:
                    units.append(unit_name)

    return units

@app.get("/subjects/lessons")
async def get_subject_lessons(subject: str, unit: str, grade: int = 3, track: str = "علمي"):
    """
    🎯 جلب قائمة الدروس من وحدة معينة لجميع المواد
    متوافقة تماماً مع كافة هياكل JSON
    """
    
    # 1. استثناء الرياضيات (لأن لها Endpoint خاص بها /math/lessons)
    if subject == "رياضيات":
        return []

    g, t = v3_curriculum.normalize_grade_track(grade, track)
    subject = subject.strip()
    if not v3_curriculum.is_valid_subject(g, t, subject):
        return []

    book = load_json_safe(subject_book_path(subject, g, t))
    if not book:
        return []
    
    # 2. توحيد الهيكلة (استخراج قائمة الوحدات بأمان)
    units_list = []
    if isinstance(book, list):
        units_list = book
    elif isinstance(book, dict):
        units_list = book.get("الوحدات", [])
    
    # تنظيف اسم الوحدة المطلوب البحث عنها من المسافات الزائدة
    clean_target_unit = unit.strip()

    # 3. البحث عن الوحدة المطلوبة واستخراج الدروس
    for u in units_list:
        if isinstance(u, dict):
            # تنظيف اسم الوحدة في الجيسون قبل المقارنة
            current_unit_name = u.get("اسم_الوحدة", "").strip()
            
            if current_unit_name == clean_target_unit:
                lessons = []
                # إذا كانت المادة ليس لها دروس (مثل الأحياء)، ستتجاوز هذا اللوب بأمان
                for lesson in u.get("الدروس", []):
                    if isinstance(lesson, dict):
                        lesson_name = lesson.get("اسم_الدرس", "").strip()
                        if lesson_name and lesson_name not in lessons:
                            lessons.append(lesson_name)
                return lessons
                
    return []

@app.get("/exams/years")
async def get_exam_years(subject: str, grade: int = 3, track: str = "علمي"):
    """
    🎯 جلب قائمة السنوات الوزارية المتاحة لصف/مسار
    
    مثال: /exams/years?subject=احياء&grade=3&track=علمي
    ⚠️ بنك الوزاري الحالي كله للثالث العلمي — الصفوف الأخرى ترجع فارغاً
       حتى يُضاف بنكها في `{المادة}/exams/grade{N}/…` (راجع subject_exams_dir).
    """
    from subjects.common import subject_exams_dir

    g, t = v3_curriculum.normalize_grade_track(grade, track)
    subject = subject.strip()
    if not v3_curriculum.is_valid_subject(g, t, subject):
        return []

    exams_dir = subject_exams_dir(subject, g, t)
    
    if not os.path.isdir(exams_dir):
        return []
    
    years = []
    for f in os.listdir(exams_dir):
        if f.lower().endswith(".json"):
            year = os.path.splitext(f)[0].strip()
            if year and year not in years:
                years.append(year)
    
    years.sort(reverse=True)
    return years



@app.get("/exams/sections")
async def get_exam_sections(subject: str, year: str, grade: int = 3, track: str = "علمي"):
    """
    جلب أنواع الأسئلة ديناميكياً من ملفات الـ JSON
    يدعم جلب أسئلة سنة محددة، أو تجميع كل صيغ الأسئلة إذا اختار الطالب "الكل"
    """
    from subjects.common import subject_exams_dir

    g, t = v3_curriculum.normalize_grade_track(grade, track)
    subject = subject.strip()
    if not v3_curriculum.is_valid_subject(g, t, subject):
        return []

    exams_dir = subject_exams_dir(subject, g, t)
    if not os.path.exists(exams_dir):
        return []
        
    files_to_read = []
    if year == "الكل":
        # إذا اختار "الكل"، نقرأ كل ملفات الـ JSON لنجمع كل الصيغ
        files_to_read = [f for f in os.listdir(exams_dir) if f.endswith(".json")]
    else:
        # إذا اختار سنة معينة، نقرأ ملفها فقط
        files_to_read = [f"{year}.json"]
        
    sections = []
    for file_name in files_to_read:
        file_path = os.path.join(exams_dir, file_name)
        if not os.path.exists(file_path):
            continue
            
        data = load_json_safe(file_path)
        if not data: continue
        
        if isinstance(data, dict):
            data = [data]
            
        for exam in data:
            # خاص بقراءة صيغ أسئلة اللغة الإنجليزية
            for sec in exam.get("أقسام_الأسئلة", []):
                name = sec.get("نوع_السؤال", "").strip()
                if name and name not in sections:
                    sections.append(name)
            
            # خاص بقراءة أقسام العربي (تحسباً لو أردت جعله ديناميكياً مستقبلاً)
            for sec in exam.get("الأقسام", []):
                name = sec.get("اسم_القسم", "").strip()
                if name and name not in sections:
                    sections.append(name)
                    
    return sections


# =====================
# API Endpoints - الرياضيات
# =====================

@app.get("/math/lessons")
async def get_math_lessons(branch: str, grade: int = 3, track: str = "علمي"):
    """
    🎯 دروس فرع رياضيات — **بالأسماء نفسها التي ترجعها `/content/capabilities`**

    مثال: /math/lessons?branch=تفاضل

    ⚠️ كانت هذه الدالة تسرد **أسماء الملفات**، والقدرات تسرد `اسم_الدرس`
       **الداخلي**. والاسمان يختلفان فعلاً في البيانات:

         ملف «القطع الزائد.json»  ←  اسم داخلي «القطع الزائد (الهذلول - Hyperbola)»

       فالاختبار يُبنى من القدرات، ثم «اشرح لي هذا الدرس» يبحث في هذه القائمة
       فلا يجد — **ينكسر في «هندسة» و«جبر» ويعمل في «تفاضل»**، وهي علّة تخفّت
       لأن ثلاثة فروع من خمسة سليمة. وزاد الطين أن ملفاً واحداً بلا امتداد
       `.json` («مبدأ العد») كان يسقط من هنا ويظهر في القدرات.

       الآن كلاهما يقرأ من `content_store` — **مصدرٌ واحد فلا تباعد ممكن**.
    """
    from core.content_store import get_lessons_book, lessons_in_unit

    g, t = v3_curriculum.normalize_grade_track(grade, track)
    book = get_lessons_book(g, t, "رياضيات")
    if not book:
        return []

    # ملفّان باسمٍ داخليٍّ واحد يظهران صفّين متطابقين في القائمة — نُبقي الأول.
    seen, out = set(), []
    for name in lessons_in_unit(book, branch):
        if name and name not in seen:
            seen.add(name)
            out.append(name)
    return out


@app.get("/math/exams/years")
async def get_math_exam_years_api(branch: str, grade: int = 3, track: str = "علمي"):
    """
    🎯 جلب السنوات الوزارية للرياضيات
    
    مثال: /math/exams/years?branch=تفاضل
    ⚠️ بنك وزاري الرياضيات كله للثالث العلمي — غيره يرجع فارغاً.
    """
    if not _is_legacy_content_scope(grade, track):
        return []
    return get_math_exam_years(branch)


@app.get("/math/exams/lessons")
async def get_math_exam_lessons_api(branch: str, year: str, grade: int = 3, track: str = "علمي"):
    """
    🎯 جلب الدروس الوزارية للرياضيات
    
    مثال: /math/exams/lessons?branch=تفاضل&year=2023
    """
    if not _is_legacy_content_scope(grade, track):
        return []
    return get_math_exam_lessons(branch, year)


# =====================
# API Endpoint الرئيسي - المعالجة
# =====================

# ==================================================
# 🆕 مسارات النسخة الثالثة — المحتوى بالصفوف والمسارات
# ==================================================

@app.get("/health/indexes")
async def health_indexes():
    """حالة الفهارس: كم في الذاكرة، كم على القرص، وهل اكتمل الإحماء."""
    return {**v3_index_store.stats(), "warming": v3_warmup.is_running()}


@app.get("/content/subjects")
async def v3_subjects(grade: int = 3, track: str = "علمي"):
    """قائمة مواد الصف/المسار."""
    g, t = v3_curriculum.normalize_grade_track(grade, track)
    return {"grade": g, "track": t, "subjects": v3_curriculum.subjects_for(g, t)}


@app.get("/content/capabilities")
async def v3_caps(request: Request, subject: str, grade: int = 3, track: str = "علمي"):
    """الأوضاع المتاحة لمادة + شجرة الوحدات/الدروس — استدعاء واحد للواجهة."""
    if not v3_ratelimit.check(request, "content", v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})
    g, t = v3_curriculum.normalize_grade_track(grade, track)
    subject = subject.strip()
    if not v3_curriculum.is_valid_subject(g, t, subject):
        return JSONResponse(status_code=404, content={"answer": "❌ مادة غير معروفة لهذا الصف"})
    return v3_capabilities.describe(g, t, subject)


