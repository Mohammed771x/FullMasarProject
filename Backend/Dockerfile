# ==================================================
# 🐳 صورة خادم مسار — Hugging Face Space (Docker)
# ==================================================
# ☢️ (فحص الأمان 2026-10-01) كانت `FROM python:3.9`، والمتطلّبات تثبّت
#    numpy 2.3 وscipy 1.16 اللتين تحتاجان 3.11 فأعلى — فالبناء الجديد يسقط،
#    وبقي الـSpace العام على نسخةٍ من يونيو فيها `codes.json` ونظامُ الأكواد.
#    3.12 هي نسخة بيئة التطوير (`.venv`) التي تمرّ عليها الاختبارات كلها.
#
# 🔒 الأسرار **لا تُنسخ**: `.dockerignore` يستبعد `.env` وأخواته، والمفاتيح
#    تُضبط في Settings ← Variables and secrets في الـSpace.
#    والمطلوب هناك: GEMINI_API_KEY · OPENAI_API_KEY · DEEPSEEK_API_KEY ·
#    GROQ_API_KEY · ADMIN_KEY · FIREBASE_SERVICE_ACCOUNT_JSON
#    (واختياري: APP_CHECK_MODE · QUOTA_GUEST_POOL · CORS_ORIGINS).
#    ولا يُضبط INGEST_ENABLED هناك أبداً — أداة الإدخال للجهاز المحلي.
FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# المكتبات أولاً (طبقةٌ تُكاش ما لم تتغيّر المتطلّبات)
COPY requirements.txt requirements.txt
RUN pip install --upgrade -r requirements.txt

# مستخدمٌ بلا صلاحيات جذر (يشترطه Hugging Face أيضاً)
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH \
    INGEST_ENABLED=0

# الكود والمناهج — وما يستبعده `.dockerignore` لا يدخل أبداً
COPY --chown=user . /app

# المنصّة تطلب المنفذ 7860 حصراً. و`--no-server-header` لا يُعلن إصدار uvicorn.
CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "7860", "--no-server-header"]
