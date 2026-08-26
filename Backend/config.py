# config.py
"""
إعدادات عامة للتطبيق
"""

import os
from dotenv import load_dotenv

load_dotenv(override=True)
# =====================
# API Keys
# =====================

GROQ_API_KEY = os.getenv("GROQ_API_KEY")
DEEPSEEK_API_KEY = os.getenv("DEEPSEEK_API_KEY") # 👈 السطر الجديد
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY") # 👈 السطر الجديد
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY") # 👈 السطر الجديد

# تأكد إنك تضيف شرط التحقق عشان ما يضرب عليك الكود لو نسيته
if not DEEPSEEK_API_KEY:
    print("⚠️ تحذير: مفتاح DeepSeek غير موجود في ملف .env")



# =====================
# المسارات
# =====================
BASE_SUBJECTS_DIR = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), 
    "data", "subjects"
)

# =====================
# حدود وسياسات
# =====================
MAX_PAGES_EXPLAIN_SUMMARY = 3      # أقصى صفحات للشرح/التلخيص
MAX_PAGES_EXAMS = 5                 # أقصى صفحات للوزاري
EXAMS_BATCH_SIZE = 10              # عدد الأسئلة في كل دفعة
UNIT_BATCH_PAGES = 3               # صفحات في كل دفعة للوحدة
QA_TOP_K = 3                       # عدد نتائج البحث

# =====================
# ثوابت المواد والفروع
# =====================
SUBJECT_NAMES = ["احياء", "فيزياء", "كيمياء", "رياضيات"]
MATH_BRANCHES = ["تفاضل", "تكامل", "جبر", "هندسة", "احتمالات"]