# -*- coding: utf-8 -*-
"""📄 أداة الإدخال ولوحة التحكم

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

# 📍 **الجذرُ هو مجلّد الخادم لا مجلّد الأجزاء.**
#
# ☢️ **وهذا أخطرُ ما في نقل الكود، ووقع فعلاً:** السطران أدناه كانا يقرآن
#    `ingest.html` و`admin.html` من `dirname(__file__)` — وهو `Backend/`
#    في الأصل و`Backend/apiparts/` بعد النقل. فصارت `/admin` تردّ 404.
#    والمسارُ مسجَّلٌ صحيحاً وجدولُ المسارات مطابقٌ تماماً — **العطلُ في
#    معنى `__file__` لا في التوجيه**، فلا يكشفه إلا اختبارٌ يطلب الصفحة.
#
# ⚖️ وهو **التغييرُ الوحيد** في نصٍّ منقول في هذا التفكيك كلِّه، ومذكورٌ
#    هنا صراحةً كي لا يُظنّ النقلُ حرفياً في موضعٍ ليس كذلك.
import os  # ⬅️ قبل السطر التالي: ترويسةُ الجزء تستورد من `api` بعده
_SERVER_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

from api import (  # noqa: E402
    File, Form, HTMLResponse, Request, UploadFile, _json_response, app, os,
    v3_ingest,
)
from .admin import _admin_gate, _admin_run  # noqa: E402


# ══════════════════════════════════════════════════
# 📥 أداة الإدخال — صور الدرس ← JSON بالقالب
# ══════════════════════════════════════════════════
# محميّة ببوابة الإدارة نفسها: تكتب في `data/` وتستهلك مفاتيح مدفوعة،
# فلا تُترك مفتوحة ولو محلياً.

@app.get("/ingest", response_class=HTMLResponse)
async def ingest_page():
    """صفحة الأداة — ملف واحد بلا خطوة بناء (مثل لوحة التحكم)."""
    path = os.path.join(_SERVER_DIR, "ingest.html")
    if not os.path.isfile(path):
        return HTMLResponse("<h1>ingest.html غير موجود</h1>", status_code=404)
    with open(path, encoding="utf-8") as f:
        return HTMLResponse(f.read())


@app.get("/ingest/targets")
async def ingest_targets(request: Request, grade: int = 3, track: str = "علمي"):
    """المواد والوحدات الموجودة فعلاً لهذا الصف/المسار."""
    return _admin_run(request, lambda: v3_ingest.targets(grade, track))


@app.get("/ingest/models")
async def ingest_models(request: Request):
    """موديلات جيميناي المتاحة لهذا المفتاح — نسردها ولا نخمّنها."""
    denied = _admin_gate(request)
    if denied is not None:
        return denied
    try:
        return {"models": await v3_ingest.list_models(),
                "default_vision": v3_ingest.VISION_MODEL,
                "default_struct": v3_ingest.STRUCT_MODEL}
    except v3_ingest.IngestError as e:
        return _json_response({"error": str(e)}, 400)


@app.post("/ingest/run")
async def ingest_run(request: Request,
                     images: list[UploadFile] = File(...),
                     grade: int = Form(3),
                     track: str = Form("علمي"),
                     subject: str = Form(...),
                     mode: str = Form("lessons_mode"),
                     unit: str = Form(""),
                     lesson_name: str = Form(""),
                     vision_model: str = Form(""),
                     struct_model: str = Form(""),
                     math_audit: str = Form("")):
    """ينفّذ الخط كاملاً ويرجع التقرير — **بلا كتابة في data/**."""
    denied = _admin_gate(request)
    if denied is not None:
        return denied

    payload = []
    for up in images:
        raw = await up.read()
        if not raw:
            continue
        if len(raw) > v3_ingest.MAX_IMAGE_BYTES:
            return _json_response(
                {"error": f"⚠️ الصورة «{up.filename}» أكبر من الحد المسموح."}, 400)
        payload.append((raw, up.content_type or "image/jpeg"))

    audit_flag = None if math_audit == "" else (math_audit == "1")
    try:
        result = await v3_ingest.run(
            payload, grade, track, subject, mode, unit, lesson_name,
            vision_model, struct_model, audit_flag)
    except v3_ingest.IngestError as e:
        return _json_response({"error": str(e)}, 400)
    except Exception as e:
        print(f"⚠️ خطأ في أداة الإدخال: {e}")
        return _json_response({"error": f"⚠️ تعذّر التنفيذ: {e}"}, 500)
    return result


@app.post("/ingest/save")
async def ingest_save(request: Request, body: dict):
    """يكتب المخرجات في مكانها — بعد أن يراها المالك في التقرير."""
    denied = _admin_gate(request)
    if denied is not None:
        return denied
    try:
        return v3_ingest.save(
            body.get("grade", 3), body.get("track", "علمي"), body.get("subject", ""),
            body.get("mode", "lessons_mode"), body.get("unit", ""),
            body.get("lesson_name", ""), body.get("json"))
    except v3_ingest.IngestError as e:
        return _json_response({"error": str(e)}, 400)
    except Exception as e:
        print(f"⚠️ خطأ في حفظ الإدخال: {e}")
        return _json_response({"error": f"⚠️ تعذّر الحفظ: {e}"}, 500)


@app.get("/admin", response_class=HTMLResponse)
async def admin_page():
    """صفحة اللوحة نفسها — ملف واحد بلا خطوة بناء."""
    path = os.path.join(_SERVER_DIR, "admin.html")
    if not os.path.isfile(path):
        return HTMLResponse("<h1>admin.html غير موجود</h1>", status_code=404)
    with open(path, encoding="utf-8") as f:
        return HTMLResponse(f.read())


# =====================
# تشغيل التطبيق
# =====================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)