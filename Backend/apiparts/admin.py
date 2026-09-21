# -*- coding: utf-8 -*-
"""📄 لوحة التحكم — مستخدمون ومنحٌ ووسائط

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    AI_CLIENTS, AdminBanRequest, AdminQuotaRequest, AvatarRequest,
    JSONResponse, Request, ScholarshipCoverRequest,
    ScholarshipEnabledRequest, ScholarshipPromptRequest,
    ScholarshipReorderRequest, ScholarshipTryRequest,
    ScholarshipUpsertRequest, _authenticate, _json_response, app, base64,
    v3_access, v3_admin, v3_analytics, v3_audience, v3_auth, v3_banners,
    v3_image_guard, v3_media, v3_notify, v3_ratelimit, v3_sch_assistant,
    v3_scholarships, v3_teacher,
)


# ══════════════════════════════════════════════════
# 🛡️ لوحة التحكم — مسارات الإدارة
# ══════════════════════════════════════════════════
# الصلاحية طبقتان: توكن Firebase لحسابٍ دوره `admin`، أو مفتاح `ADMIN_KEY`.
# وإن لم يُضبط أيٌّ منهما فالمسارات **مغلقة** — لا وضع مفتوح افتراضياً.

def _admin_gate(request: Request):
    """يعيد None عند السماح، أو ردَّ رفضٍ جاهزاً."""
    if not v3_admin.gate_open():
        return _json_response(
            {"error": "🔒 لوحة التحكم غير مفعّلة: اضبط ADMIN_KEY أو ADMIN_EMAILS."}, 503)

    key = request.headers.get("X-Admin-Key", "")
    if v3_admin.key_matches(key):
        return None

    token = v3_auth.bearer_token(request)
    if token:
        try:
            ident = v3_auth.verify(token)
            if v3_admin.is_admin_identity(ident):
                return None
        except v3_auth.AuthError:
            pass

    return _json_response({"error": "⛔ صلاحية الإدارة مطلوبة."}, 401)


def _admin_run(request: Request, fn):
    """بوابة + تنفيذ + تحويل أخطاء اللوحة إلى رسائل عربية."""
    denied = _admin_gate(request)
    if denied is not None:
        return denied
    try:
        return fn()
    except (v3_admin.AdminError, v3_scholarships.ScholarshipError,
            v3_teacher.TeacherError, v3_banners.BannerError,
            v3_analytics.AnalyticsError, v3_access.AccessError,
            v3_notify.NotificationError, v3_audience.AudienceError,
            v3_image_guard.ImageRejected) as e:
        # كلها أخطاء برسائل عربية جاهزة للعرض في اللوحة — لا أخطاء برمجية.
        # ⚠️ `ImageRejected` لازمة هنا لا في المسار: الالتقاط العام أدناه
        #    يسبق أيّ `except` خارج هذه الدالة فيحوّلها إلى 500 غامض.
        return _json_response({"error": str(e)}, 400)
    except Exception as e:
        print(f"⚠️ خطأ في لوحة التحكم: {e}")
        return _json_response({"error": "⚠️ تعذّر تنفيذ الطلب."}, 500)


@app.get("/admin/overview")
async def admin_overview(request: Request, days: int = 30):
    """أرقام الرئيسية: مستخدمون · أسئلة اليوم والإجمالي · سلسلة يومية."""
    days = max(7, min(days, 90))
    return _admin_run(request, lambda: v3_admin.overview(days))


@app.get("/admin/users")
async def admin_users(request: Request, search: str = "", limit: int = 200,
                      segment: str = "all", sort: str = "active"):
    """كل المستخدمين مع استخدامهم — مصفّىً بالشريحة ومرتّباً كما يطلب الأدمن.

    ⚠️ الشريحة **لا تفتح بياناتٍ جديدة**: هي تصفية لما يراه المديرُ أصلاً
       خلف البوابة نفسها، لا مسارٌ جانبيٌّ يتخطّاها.
    """
    return _admin_run(request, lambda: {
        "users": v3_admin.list_users(search, limit, segment, sort),
        "segments": v3_audience.describe_all()})


@app.get("/admin/users/{uid}")
async def admin_user_detail(request: Request, uid: str, days: int = 30):
    """تفصيل مستخدم واحد وسلسلته اليومية."""
    days = max(7, min(days, 90))
    return _admin_run(request, lambda: v3_admin.user_detail(uid, days))


@app.post("/admin/users/{uid}/ban")
async def admin_ban(request: Request, uid: str, body: AdminBanRequest):
    """حظر أو رفع حظر — يسري عند أول طلب للمستخدم."""
    return _admin_run(request, lambda: v3_admin.set_banned(uid, body.banned))


@app.post("/admin/users/{uid}/quota")
async def admin_quota(request: Request, uid: str, body: AdminQuotaRequest):
    """حدّ يومي خاص بهذا المستخدم — أو `null` للعودة للحدّ العام."""
    return _admin_run(request, lambda: v3_admin.set_quota(uid, body.limit))


# ══════════════ 🎓 المنح في اللوحة ══════════════
# مرِن عمداً: المنح تتجدّد كل موسم، فالإضافة والتعديل والترتيب والإخفاء
# كلها من اللوحة بلا نشر تطبيق ولا لمس كود ([32§6]).


@app.get("/admin/scholarships")
async def admin_scholarships(request: Request):
    """كل المنح — بما فيها المخفية — ومعها هل لكل واحدة برومبت مساعد."""
    return _admin_run(request, lambda: v3_scholarships.list_admin())


@app.get("/admin/scholarships/{sch_id}")
async def admin_scholarship_get(request: Request, sch_id: str):
    """منحة واحدة للتحرير + برومبتها 🔒 (اللوحة وحدها تراه)."""
    return _admin_run(request, lambda: v3_scholarships.get_admin(sch_id))


@app.post("/admin/scholarships")
async def admin_scholarship_create(request: Request, body: ScholarshipUpsertRequest):
    """إنشاء منحة جديدة — ويرفع `meta.version` فتصل التطبيقات فوراً."""
    return _admin_run(
        request,
        lambda: v3_scholarships.create(body.id or "", body.model_dump(exclude_none=False)))


@app.put("/admin/scholarships/{sch_id}")
async def admin_scholarship_update(request: Request, sch_id: str,
                                   body: ScholarshipUpsertRequest):
    """تحديث منحة قائمة (النموذج يرسل كل الحقول)."""
    return _admin_run(
        request,
        lambda: v3_scholarships.update(sch_id, body.model_dump(exclude_none=False)))


@app.post("/admin/scholarships/{sch_id}/enabled")
async def admin_scholarship_enabled(request: Request, sch_id: str,
                                    body: ScholarshipEnabledRequest):
    """إظهار/إخفاء فوري بلا حذف — أرخص طريقة لسحب منحة انتهى موسمها."""
    return _admin_run(request, lambda: v3_scholarships.set_enabled(sch_id, body.enabled))


@app.post("/admin/scholarships/reorder")
async def admin_scholarship_reorder(request: Request, body: ScholarshipReorderRequest):
    """ترتيب العرض — أول معرّف أعلى القائمة."""
    return _admin_run(request, lambda: v3_scholarships.reorder(body.ids))


@app.delete("/admin/scholarships/{sch_id}")
async def admin_scholarship_delete(request: Request, sch_id: str):
    """حذف نهائي للمنحة **وبرومبتها معاً** — وإلا بقي برومبت يتيم."""
    return _admin_run(request, lambda: v3_scholarships.delete(sch_id))


@app.get("/admin/scholarships/{sch_id}/prompt")
async def admin_scholarship_prompt_get(request: Request, sch_id: str):
    """🔒 برومبت المساعد + **البرومبت المشترك** الذي يعمل أصلاً لكل المنح.

    ⭐ إرجاع المشترك مقصود: الأدمن يراه في اللوحة للقراءة فقط، فيعرف ما هو
       مغطّى سلفاً (النبرة · طول الرد · منع التكرار · منع الاختراع) ولا يعيد
       كتابته — ويقتصر حقله على **ما يخصّ هذه المنحة وحدها** ([32§5]).
    """
    return _admin_run(request, lambda: {
        "id": sch_id,
        "assistant_prompt": v3_scholarships.get_prompt(sch_id),
        "shared_system": v3_sch_assistant.SYSTEM_CORE,
        "placeholder": v3_sch_assistant.NO_ADMIN_INSTRUCTIONS,
    })


@app.post("/admin/scholarships/{sch_id}/prompt")
async def admin_scholarship_prompt_set(request: Request, sch_id: str,
                                       body: ScholarshipPromptRequest):
    """حفظ البرومبت. **لا يرفع `meta.version`** — الطلاب لا يكيّشونه ([06])."""
    return _admin_run(request,
                      lambda: v3_scholarships.set_prompt(sch_id, body.assistant_prompt))


@app.post("/admin/scholarships/{sch_id}/try")
async def admin_scholarship_try(request: Request, sch_id: str, body: ScholarshipTryRequest):
    """🧪 «جرّب البرومبت» قبل النشر — يجرّب **المسودّة** غير المحفوظة أيضاً.

    ⭐ هذا ما يمنع نشر مساعدٍ يهذي: الأدمن يرى ردّه داخل اللوحة أولاً.
    """
    denied = _admin_gate(request)
    if denied is not None:
        return denied
    try:
        sch = v3_scholarships.get_admin(sch_id)
    except v3_scholarships.ScholarshipError as e:
        return _json_response({"error": str(e)}, 400)

    # مسودّة البرومبت من الحقل المفتوح في اللوحة تسبق المحفوظ.
    draft = body.assistant_prompt
    if draft is not None:
        messages = [{"role": "system",
                     "content": v3_sch_assistant.build_system(sch, draft)}]
        messages += v3_sch_assistant.build_history(body.chat_history)
        messages.append({"role": "user", "content": f"سؤال الطالب:\n{body.question}"})
        try:
            client = AI_CLIENTS.get("gemini")
            response = await client.chat.completions.create(
                model=v3_sch_assistant.MODEL, messages=messages,
                max_tokens=900, temperature=0.4)
            return _json_response(
                {"answer": (response.choices[0].message.content or "").strip(), "ok": True})
        except Exception as e:
            print(f"⚠️ تجربة برومبت المنحة: {e}")
            return _json_response({"error": "⚠️ تعذّرت تجربة البرومبت."}, 500)

    return _json_response(
        await v3_sch_assistant.ask(sch, body.question, body.chat_history, AI_CLIENTS))


# ==================================================
# 👤 صورة الحساب
# ==================================================
_AVATAR_SAFE = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"


def _avatar_key(uid: str) -> str:
    """اسم ملف آمن من المعرّف — تنقيةٌ دفاعية لا تُترك لشكل الـuid.

    ⚠️ uid فايربيس أبجديّ رقميّ اليوم، لكن اسم الملف يُبنى منه ويُكتب على
       القرص: قيدٌ يُفترض ولا يُفرض هو ثغرةُ مسارٍ تنتظر تغييراً في الأعلى.
    """
    return "".join(c if c in _AVATAR_SAFE else "_" for c in uid)[:96]


@app.post("/me/avatar")
async def me_avatar(request: Request, body: AvatarRequest):
    """يرفع صورة حساب الطالب (أو يحذفها بإرسال فراغ) ويعيد رابطها.

    ⭐ **لماذا يمرّ الرفع بالخادم** ولا يذهب من التطبيق إلى Storage مباشرة؟
       لأن التطبيق لا يحمل حزمة `firebase_storage` أصلاً، وإضافتها تعني
       اعتمادية أصلية جديدة وبناءً كاملاً. والخادم يملك Admin SDK جاهزاً.

    🔒 المعرّف من التوكن لا من الجسم — فلا يكتب أحدٌ فوق صورة غيره.
    🚫 والزائر لا صورة له: حسابه مؤقّت ويُلغى، فترفع ملفاً يتيماً بلا مالك.
    """
    if not v3_ratelimit.check(request, "avatar",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return _json_response({"error": "⏳ محاولات كثيرة. انتظر قليلاً."}, 429)

    identity, err = await _authenticate(request, body)
    if err:
        return err
    if identity.get("is_guest"):
        return _json_response(
            {"error": "👤 أنشئ حساباً أولاً لتضع صورتك."}, 403)

    key = _avatar_key(identity.get("uid", ""))
    if not key:
        return _json_response({"error": "⚠️ تعذّر تحديد الحساب."}, 400)

    data = (body.image_base64 or "").strip()
    try:
        if not data:
            v3_media.delete_image("avatar", key)
            return _json_response({"url": ""})
        clean, mime = v3_image_guard.validate(data)
        url = v3_media.upload_image("avatar", key, base64.b64decode(clean), mime)
        return _json_response({"url": url})
    except v3_image_guard.ImageRejected as e:
        return _json_response({"error": str(e)}, 400)
    except v3_media.StorageUnavailable as e:
        return _json_response({"error": str(e)}, 503)
    except Exception as e:
        print(f"⚠️ رفع صورة الحساب: {e}")
        return _json_response({"error": "⚠️ تعذّر رفع الصورة. حاول ثانيةً."}, 500)


@app.post("/admin/scholarships/{sch_id}/cover")
async def admin_scholarship_cover(request: Request, sch_id: str,
                                  body: ScholarshipCoverRequest):
    """🖼️ رفع غلاف المنحة (أو حذفه بإرسال فراغ).

    الصورة تُقصّ وتُضغط **في اللوحة** قبل الوصول — فالخادم يتحقق ويخزّن فقط.
    وتُحفظ في مجموعة موازية لا في مستند المنحة، كي لا تنتفخ قائمة الطلاب.
    """
    def _save():
        data = (body.image_base64 or "").strip()
        if not data:
            return v3_scholarships.set_cover(sch_id)
        # 🛡️ البصمة السحرية لا الامتداد: نصٌّ مُرمَّز باسم صورة يُرفض هنا.
        clean, mime = v3_image_guard.validate(data)
        return v3_scholarships.set_cover(sch_id, base64.b64decode(clean), mime)

    return _admin_run(request, _save)


@app.post("/admin/scholarships/{sch_id}/logo")
async def admin_scholarship_logo(request: Request, sch_id: str,
                                 body: ScholarshipCoverRequest):
    """🏷️ رفع شعار المنحة (أو حذفه بإرسال فراغ) — مربّع 1:1."""
    def _save():
        data = (body.image_base64 or "").strip()
        if not data:
            return v3_scholarships.set_logo(sch_id)
        clean, mime = v3_image_guard.validate(data)
        return v3_scholarships.set_logo(sch_id, base64.b64decode(clean), mime)

    return _admin_run(request, _save)


@app.get("/scholarships/{sch_id}/cover")
async def scholarship_cover(request: Request, sch_id: str):
    """غلاف منحة — يُجلب عند فتح شاشتها وحدها ويُكيَّش على الجهاز."""
    if not v3_ratelimit.check(request, "covers",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})
    try:
        image = v3_scholarships.get_cover(sch_id)
    except v3_scholarships.ScholarshipError:
        image = ""
    return _json_response({"id": sch_id, "image": image})


