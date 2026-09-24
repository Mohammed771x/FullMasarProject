# -*- coding: utf-8 -*-
"""📄 مساعد المعلّم

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    AI_CLIENTS, JSONResponse, Request, TeacherAskRequest,
    _attach_image_text, _authenticate, _json_response, _remember, app,
    v3_billing, v3_idem, v3_image_guard, v3_quota, v3_ratelimit, v3_teacher,
    v3_teacher_prompts, v3_vision,
)


# ══════════════════════════════════════════════════
# 👨‍🏫 مساعد المعلم
# ══════════════════════════════════════════════════
# قسمٌ **مطابق لقسم التعليم في تجربته** ومختلفٌ عنه في الإعدادات والبرومبتات
# وحدهما (قرار المالك). المصدر: **نصّ الدرس من الكتاب** لا الوحدات ولا الصفحات.

@app.get("/teacher/tools")
async def teacher_tools(request: Request):
    """أدوات المعلم المتاحة — كي تُبنى الواجهة من الخادم لا من ثوابت مكرّرة."""
    if not v3_ratelimit.check(request, "teacher_tools",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})
    return _json_response({
        "tools": [
            {"tool": t, "label": m["label"], "emoji": m["emoji"],
             "has_generate": m["has_generate"], "extras": list(m["extras"])}
            for t, m in v3_teacher_prompts.TOOLS.items()
        ],
        "difficulties": list(v3_teacher_prompts.DIFFICULTIES),
        "counts": list(v3_teacher_prompts.COUNTS),
    })


@app.post("/teacher/ask")
async def teacher_ask(req: TeacherAskRequest, request: Request):
    """👨‍🏫 أداة المعلم أو متابعتها → نصّ الدرس + برومبت الأداة → الموديل.

    🎟️ نداء موديل ⇒ يُحتسب من الحصة كسؤال واحد — تماماً كـ`/ask`
       و`/quiz/generate` و`/scholarship/ask`. وإلا صار بابَاً خلفياً للفاتورة.
    """
    identity, auth_error = await _authenticate(request, req)
    if auth_error is not None:
        return auth_error

    if not v3_ratelimit.check(request, identity["uid"]):
        return JSONResponse(status_code=429,
                            content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})

    # 👨‍🏫 **لا حارس أقسامٍ هنا بعد اليوم** ([35§7]): «مساعد المعلم» خرج من
    #    `access.SECTIONS` لأنه صار تطبيق المعلّم كلَّه لا قسماً فيه. وحارسٌ
    #    يُنادى ولا يمنع شيئاً أسوأ من غيابه: يوهم قارئ الكود بحمايةٍ لا وجود لها.
    #
    # 🔓 ولا حارس دورٍ كذلك — **عن قصد**: الزائر يجرّب أدوات المعلم قبل أن
    #    يسجّل ([35§3])، ولا مستند له يُقرأ منه دور. والفاتورة تحرسها الحصةُ
    #    أدناه وتحديدُ المعدل أعلاه، وهما ما يهمّ فعلاً.

    state, cached = v3_idem.begin(identity["uid"], req.request_id)
    if state == v3_idem.DONE and cached is not None:
        return _json_response(cached)
    if state == v3_idem.RUNNING:
        return _json_response(
            {"answer": v3_idem.IN_FLIGHT_MESSAGE, "references": [],
             "session_active": False, "in_flight": True}, 202)

    reservation = await v3_quota.areserve(identity["uid"], identity["is_guest"])
    if not reservation.allowed:
        v3_idem.abandon(identity["uid"], req.request_id)
        return _json_response(
            {"answer": v3_quota.message_for(identity["is_guest"]), "references": [],
             "session_active": False, "quota_exceeded": True,
             "is_guest": identity["is_guest"]}, 429)
    identity["_quota_reservation"] = reservation
    v3_billing.start()

    # 📷 الصورة → نص: نفس مسار `/ask` وحارسه بلا ازدواج. الاستعمال الحقيقي
    #    هنا: صفحة كتاب مصوّرة · ورقة إجابة طالب · سؤال مكتوب بخط اليد.
    #    والصورة **لا تُحفظ ولا تُسجَّل** ولا تمضي أبعد من هذه النقطة.
    image_text = ""
    images = req.all_images()
    if images:
        try:
            extracted = []
            for img in images:
                clean, mime = v3_image_guard.validate(img)
                extracted.append(await v3_vision.image_to_text(clean, mime, AI_CLIENTS))
        except (v3_image_guard.ImageRejected, v3_vision.VisionFailed) as e:
            await v3_billing.settle_quota(v3_quota, identity)
            v3_idem.abandon(identity["uid"], req.request_id)
            return _json_response({"answer": str(e), "references": [],
                                   "session_active": False}, 200)
        req.content = v3_vision.merge_into_question(extracted, req.content)
        image_text = v3_vision.history_text(extracted)
        req.images_base64 = None
        req.image_base64 = None

    try:
        result = await v3_teacher.ask(req, AI_CLIENTS)
    except v3_teacher.TeacherError as e:
        # رسالة عربية جاهزة — تُعرض في الفقاعة كردٍّ لا كعطل شبكة.
        await v3_billing.settle_quota(v3_quota, identity)
        v3_idem.abandon(identity["uid"], req.request_id)
        return _json_response({"answer": str(e), "references": [],
                               "session_active": False}, 200)
    except Exception:
        await v3_billing.settle_quota(v3_quota, identity)
        v3_idem.abandon(identity["uid"], req.request_id)
        raise

    payload = _attach_image_text(result, image_text)
    await v3_billing.settle_quota(v3_quota, identity, payload)
    _remember(identity["uid"], req.request_id, payload)
    return _json_response(payload)
