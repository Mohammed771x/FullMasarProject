# -*- coding: utf-8 -*-
"""📄 المنح — مسارات الطالب

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    AI_CLIENTS, JSONResponse, Request, ScholarshipAskRequest,
    _attach_image_text, _json_response, _remember, app, v3_idem,
    v3_image_guard, v3_ratelimit, v3_sch_assistant, v3_scholarships,
    v3_vision,
)
from .guards import _scholarship_guards  # noqa: E402


# ══════════════════════════════════════════════════
# 🎓 قسم المنح — مسارات الطالب
# ══════════════════════════════════════════════════
# المنح **محتوى متغيّر يُدار من اللوحة** ولا يُشحن مع التطبيق ([32]).
# والقائمة لا تُنقل إلا يوم تتغيّر: العميل يرسل نسخته، فإن طابقت رجع
# `changed: false` بلا أي منحة — راجع بروتوكول النسخة في core/scholarships.


def _scholarships_unavailable():
    """رد ودّي حين لا Firestore على الخادم — لا خطأ 500 على شاشة طالب."""
    return _json_response({
        "changed": False, "version": 0, "items": [],
        "answer": "🎓 قسم المنح غير مهيّأ على الخادم بعد — عد إلينا قريباً.",
    }, 200)


@app.get("/scholarships")
async def scholarships_list(request: Request, version: int = -1):
    """قائمة المنح المفعّلة — أو `changed: false` إن كانت نسخة العميل محدّثة.

    مفتوح لكل من يفتح التطبيق (بلا حصة): قراءة قائمة لا تنادي أي موديل.
    """
    if not v3_ratelimit.check(request, "scholarships",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})
    if not v3_scholarships.available():
        return _scholarships_unavailable()
    try:
        return _json_response(v3_scholarships.list_public(version))
    except v3_scholarships.ScholarshipError as e:
        return _json_response({"changed": False, "version": 0, "items": [],
                               "answer": str(e)}, 200)


@app.get("/scholarships/{sch_id}")
async def scholarship_detail(request: Request, sch_id: str):
    """منحة واحدة — للروابط العميقة (إشعار «منحة جديدة») وبانر الرئيسية."""
    if not v3_ratelimit.check(request, "scholarships",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})
    try:
        return _json_response(v3_scholarships.get_public(sch_id))
    except v3_scholarships.ScholarshipError as e:
        return _json_response({"answer": str(e)}, 404)


@app.post("/scholarship/ask")
async def scholarship_ask(req: ScholarshipAskRequest, request: Request):
    """💬 مساعد المنحة: برومبت الأدمن 🔒 + بطاقة المنحة → Flash-Lite.

    🎟️ نداء موديل ⇒ يُحتسب من الحصة كسؤال واحد — تماماً كـ`/quiz/generate`.
    """
    # ⚖️ نفسُ حرّاس مسار البثّ — كانتا نسختين متطابقتين سطراً بسطر.
    identity, sch, denied, canned = await _scholarship_guards(req, request)
    if denied is not None:
        return denied

    if canned is not None:
        payload = {"answer": canned, "ok": True, "from_card": True}
        _remember(identity["uid"], req.request_id, payload)
        return _json_response(payload)

    # 📷 الصورة → نص (نفس مسار `/ask` وحارسه): لقطة من موقع المنحة أو
    #    كشف درجات أو وثيقة. الصورة **لا تُحفظ ولا تُسجَّل** ولا تمضي أبعد
    #    من هنا — النص المستخرج وحده يصل للمساعد ([27§3]).
    question = req.question
    image_text = ""
    images = req.all_images()
    if images:
        try:
            extracted = []
            for img in images:
                clean, mime = v3_image_guard.validate(img)
                extracted.append(await v3_vision.image_to_text(clean, mime, AI_CLIENTS))
        except (v3_image_guard.ImageRejected, v3_vision.VisionFailed) as e:
            return _json_response({"answer": str(e), "ok": False}, 200)
        question = v3_vision.merge_into_question(extracted, req.question)
        image_text = v3_vision.history_text(extracted)
        req.images_base64 = None
        req.image_base64 = None

    if not (question or "").strip():
        return _json_response(
            {"answer": "اكتب سؤالك عن المنحة أو أرفق صورة 😊", "ok": False}, 200)

    try:
        payload = _attach_image_text(
            await v3_sch_assistant.ask(sch, question, req.chat_history, AI_CLIENTS),
            image_text)
    except Exception:
        v3_idem.abandon(identity["uid"], req.request_id)
        raise
    _remember(identity["uid"], req.request_id, payload)
    return _json_response(payload)


