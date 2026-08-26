# main.py
"""
الملف الرئيسي - نقطة الدخول الأساسية
استدعاءات فقط - بدون logic
"""

from fastapi import FastAPI, Response, Request, BackgroundTasks
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
import json
import os
from typing import Dict, Any
import asyncio
import concurrent.futures

# =====================
# الاستيرادات
# =====================

# من الإعدادات والنماذج
from config import GROQ_API_KEY, BASE_SUBJECTS_DIR, SUBJECT_NAMES, DEEPSEEK_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY
from models import AskRequest, VerificationRequest
from auth import load_codes, save_codes, verify_code

# من المواد
from subjects.biology import handle_biology_request
from subjects.chemistry import handle_chemistry_request
from subjects.physics import handle_physics_request
from subjects.math import handle_math_request
from subjects.chemistry import handle_chemistry_request
from subjects.arabic import handle_arabic_request
from subjects.english import handle_english_request
# من common (للـ helper functions)
from subjects.common import (
    subject_book_path, load_json_safe,
    get_math_exam_years, get_math_exam_lessons
)
from subjects.math import handle_math_request, cleanup_old_sessions

# من المكتبات الخارجية
from openai import AsyncOpenAI  # التعديل هنا مهم جداً
from groq import AsyncGroq      # التعديل هنا مهم جداً
from dotenv import load_dotenv

# =====================
# تحميل الإعدادات
# =====================
load_dotenv(override=True)






# =====================
# زيادة مسارات المعالجة (Threads) لمنع التجمد
# =====================
executor = concurrent.futures.ThreadPoolExecutor(
    max_workers=8,
    thread_name_prefix="worker"
)
loop = asyncio.get_event_loop()
loop.set_default_executor(executor)



# =====================
# إنشاء التطبيق
# =====================
app = FastAPI(title="YE - Pro Student Tutor v2")

@app.api_route("/", methods=["GET", "HEAD"])
async def root():
    return {"status": "ok", "message": "Masar Server is alive and running!"}



app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# =====================
# إعداد Clients
# =====================


groq_client = AsyncGroq(api_key=GROQ_API_KEY)

# 👇 أضف عميل ديب سيك هنا
deepseek_client = AsyncOpenAI(
    base_url="https://api.deepseek.com",
    api_key=DEEPSEEK_API_KEY,
    timeout=60.0
)


gemini_client = AsyncOpenAI(
    api_key=GEMINI_API_KEY,
    base_url="https://generativelanguage.googleapis.com/v1beta/openai/",
    timeout=60.0
)

openai_client = AsyncOpenAI(
    api_key=OPENAI_API_KEY,
    timeout=60.0
)

@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    هذا الدرع يضمن أنه مهما حدث خطأ برمجي أو انهيار في أي ملف،
    السيرفر لن يرسل HTML للتطبيق، بل سيرسل JSON نظيف ومحترم.
    """
    # هنا يمكنك إضافة مكتبة Sentry لاحقاً لتسجيل الأخطاء لك كمدير
    print(f"🔥 FATAL ERROR: {exc}") 
    return JSONResponse(
        status_code=500,
        content={
            "answer": "⚠️ عذراً، حدث ضغط مفاجئ أو خطأ في خوادم الذكاء الاصطناعي. جاري العمل على حل المشكلة، حاول مجدداً بعد قليل.",
            "session_active": False
        }
    )
    
    
# =====================
# API Endpoints - التحقق والأمان
# =====================

@app.post("/verify-access")
async def verify_access(req: VerificationRequest):
    """
    التحقق من صحة الكود والجهاز
    """
    result = verify_code(req.code, req.device_id)
    
    if result["status"] == "error":
        return Response(
            content=json.dumps(result),
            status_code=401,
            media_type="application/json"
        )
    
    return result

# =====================
# API Endpoints - جلب البيانات
# =====================

@app.get("/subjects/units")
async def get_subject_units(subject: str):
    """
    جلب الوحدات بشكل ذكي وموحد يدعم جميع صيغ ملفات JSON
    بدون أخطاء AttributeError
    """
    units = []  
    
    # 📐 الرياضيات (حالة خاصة لأن وحداتها ثابتة)
    if subject == "رياضيات":
        return ["تفاضل", "تكامل", "جبر", "هندسة", "احتمالات"]

    # تحميل الكتاب لباقي المواد
    book = load_json_safe(subject_book_path(subject))
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
async def get_subject_lessons(subject: str, unit: str):
    """
    🎯 جلب قائمة الدروس من وحدة معينة لجميع المواد
    متوافقة تماماً مع كافة هياكل JSON
    """
    
    # 1. استثناء الرياضيات (لأن لها Endpoint خاص بها /math/lessons)
    if subject == "رياضيات":
        return []

    book = load_json_safe(subject_book_path(subject))
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
async def get_exam_years(subject: str):
    """
    🎯 جلب قائمة السنوات الوزارية المتاحة
    
    مثال: /exams/years?subject=احياء
    """
    
    exams_dir = os.path.join(BASE_SUBJECTS_DIR, subject, "exams")
    
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
async def get_exam_sections(subject: str, year: str):
    """
    جلب أنواع الأسئلة ديناميكياً من ملفات الـ JSON
    يدعم جلب أسئلة سنة محددة، أو تجميع كل صيغ الأسئلة إذا اختار الطالب "الكل"
    """
    exams_dir = os.path.join(BASE_SUBJECTS_DIR, subject, "exams")
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
async def get_math_lessons(branch: str):
    """
    🎯 جلب قائمة الدروس من فرع رياضيات معين
    
    مثال: /math/lessons?branch=تفاضل
    """
    
    math_root = os.path.join(BASE_SUBJECTS_DIR, "رياضيات")
    branch_path = os.path.join(math_root, branch)
    
    if not os.path.isdir(branch_path):
        return []
    
    lessons = []
    for fname in os.listdir(branch_path):
        if not fname.endswith(".json"):
            continue
        
        lesson_name = os.path.splitext(fname)[0]
        lessons.append(lesson_name)
    
    return lessons


@app.get("/math/exams/years")
async def get_math_exam_years_api(branch: str):
    """
    🎯 جلب السنوات الوزارية للرياضيات
    
    مثال: /math/exams/years?branch=تفاضل
    """
    return get_math_exam_years(branch)


@app.get("/math/exams/lessons")
async def get_math_exam_lessons_api(branch: str, year: str):
    """
    🎯 جلب الدروس الوزارية للرياضيات
    
    مثال: /math/exams/lessons?branch=تفاضل&year=2023
    """
    return get_math_exam_lessons(branch, year)


# =====================
# API Endpoint الرئيسي - المعالجة
# =====================

@app.post("/ask")
async def ask(req: AskRequest, background_tasks: BackgroundTasks):
    background_tasks.add_task(cleanup_old_sessions)
    """
    🔥 الـ Endpoint الرئيسي
    
    استقبال طلب المستخدم ومعالجته حسب المادة والوضع
    """
    
    # =====================
    # 1️⃣ التحقق من الأكواد والأمان
    # =====================
    codes_data = load_codes()
    active_codes = codes_data.get("active_codes", {})
    
    if req.code not in active_codes:
        return Response(
            content=json.dumps({"answer": "⛔ كود التفعيل غير صالح."}),
            status_code=401,
            media_type="application/json"
        )
    
    # الجديد - يستخدم verify_code الموجود في auth.py مباشرة
    device_check = verify_code(req.code, req.device_id or "")

    if device_check["status"] == "error":
      return Response(
        content=json.dumps({"answer": device_check["message"]}),
        status_code=401,
        media_type="application/json"
    )
    
    # =====================
    # 2️⃣ معالجة الطلب حسب المادة
    # =====================
    subject = req.subject.strip()
    
    # 🧬 الأحياء
    if subject == "احياء":
        return await handle_biology_request(req, gemini_client)
    
    # 🔬 الفيزياء
    elif subject == "فيزياء":
        return await handle_physics_request(req, openai_client)
    
    # 🇬🇧 الإنجليزي
    elif subject == "انجليزي":
        return await handle_english_request(req, gemini_client)
    
    # ⚛️ الكيمياء
    elif subject == "كيمياء":
        return await handle_chemistry_request(req, openai_client)
    # 📚 العربي
    elif subject == "عربي":
        return await handle_arabic_request(req, gemini_client)
    
    # 📐 الرياضيات
    elif subject == "رياضيات":
        return await handle_math_request(req, deepseek_client, groq_client)
    
    # ❌ مادة غير معروفة
    else:
        return Response(
            content=json.dumps({"answer": "❌ مادة غير معروفة"}),
            status_code=400,
            media_type="application/json"
        )


# =====================
# تشغيل التطبيق
# =====================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)