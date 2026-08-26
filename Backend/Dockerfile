# استخدام صورة بايثون رسمية
FROM python:3.9

# تجهيز مجلد العمل
WORKDIR /app

# نسخ ملف المكتبات وتثبيتها
COPY requirements.txt requirements.txt
RUN pip install --no-cache-dir --upgrade -r requirements.txt

# إنشاء مستخدم جديد (مهم جداً في Hugging Face للحماية)
RUN useradd -m -u 1000 user
USER user
ENV HOME=/home/user \
    PATH=/home/user/.local/bin:$PATH

# نسخ باقي ملفات المشروع (الكود والمناهج)
COPY --chown=user . /app

# أمر التشغيل (ملاحظة: المنصة تطلب المنفذ 7860 حصراً)
CMD ["uvicorn", "api:app", "--host", "0.0.0.0", "--port", "7860"]