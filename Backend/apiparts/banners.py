# -*- coding: utf-8 -*-
"""📄 اللافتات وبرومبتات المعلّم والإعدادات

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    AI_CLIENTS, AdminSettingsRequest, BannerRequest, BannerTemplatesRequest,
    Request, ScholarshipEnabledRequest, TeacherPromptRequest,
    TeacherTryRequest, _json_response, app, v3_banners, v3_curriculum,
    v3_quota, v3_ratelimit, v3_scholarships, v3_teacher, v3_teacher_prompts,
)
from .admin import _admin_gate, _admin_run  # noqa: E402


# ══════════════ 👨‍🏫 برومبتات المعلم في اللوحة ══════════════
# ⭐ الفرق الجوهري عن تبويب المنح: **لا شيء يُنشأ هنا ولا يُحذف.** الأدوات
#    الأربع مشحونة مع التطبيق، واللوحة تُحسّن سلوكها فقط. ولذلك:
#      • القسم يعمل كاملاً بلا Firestore (برومبتات الكود هي الأساس).
#      • تفريغ الحقل ⇒ **عودةٌ للافتراضي** لا تعطيلٌ للأداة.

# ==================================================
# 🎏 البانرات
# ==================================================
@app.get("/banners")
async def banners_list(request: Request, signature: str = "",
                       grade: int = 0, track: str = ""):
    """بانرات كل الأقسام في رد واحد — أو `changed:false` إن لم يتغيّر شيء.

    🎯 `grade`/`track` اختياريان: بهما يصفّي الخادمُ البانرات المستهدَفة،
       وبدونهما يعود كلُّ شيء ومعه حقل `segment` ليصفّي التطبيقُ بنفسه —
       فالنسخة القديمة لا تنكسر ولا تُحرَم.
    """
    if not v3_ratelimit.check(request, "banners",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return _json_response({"error": "⏳ محاولات كثيرة. انتظر قليلاً."}, 429)
    if not v3_banners.available():
        # 🛡️ لا نُسقط الشاشة الرئيسية لأن البانرات غير متاحة: قسمٌ تزييني.
        return _json_response({"changed": True, "signature": "", "sections": {}})
    try:
        return _json_response(v3_banners.list_public(
            signature, grade=grade if grade in (1, 2, 3) else None, track=track))
    except Exception as e:
        print(f"⚠️ قراءة البانرات: {e}")
        return _json_response({"changed": True, "signature": "", "sections": {}})


@app.get("/admin/banners")
async def admin_banners(request: Request):
    return _admin_run(request, lambda: v3_banners.list_admin())


@app.post("/admin/banners")
async def admin_banner_create(request: Request, body: BannerRequest):
    return _admin_run(request, lambda: v3_banners.create(body.model_dump()))


@app.put("/admin/banners/{banner_id}")
async def admin_banner_update(request: Request, banner_id: str, body: BannerRequest):
    return _admin_run(request, lambda: v3_banners.update(banner_id, body.model_dump()))


@app.post("/admin/banners/{banner_id}/enabled")
async def admin_banner_enabled(request: Request, banner_id: str, body: ScholarshipEnabledRequest):
    return _admin_run(request, lambda: v3_banners.set_enabled(banner_id, body.enabled))


@app.delete("/admin/banners/{banner_id}")
async def admin_banner_delete(request: Request, banner_id: str):
    return _admin_run(request, lambda: v3_banners.delete(banner_id))


@app.get("/admin/banner-templates")
async def admin_banner_templates(request: Request):
    return _admin_run(request, lambda: {"templates": v3_banners.get_templates()})


@app.post("/admin/banner-templates")
async def admin_banner_templates_save(request: Request, body: BannerTemplatesRequest):
    return _admin_run(
        request, lambda: {"templates": v3_banners.set_templates(body.templates)})


@app.get("/admin/teacher/prompts")
async def admin_teacher_prompts(request: Request):
    """كل الأدوات ببرومبتاتها الفعّالة + هل هي مخصَّصة أم افتراضية."""
    return _admin_run(request, v3_teacher.list_prompts)


@app.get("/admin/teacher/core")
async def admin_teacher_core(request: Request):
    """👁️ البرومبت المشترك — **للقراءة فقط**، يُعدَّل من الكود لا من اللوحة.
    عرضُه يمنع الأدمن من إعادة كتابة ما هو مغطّى سلفاً في كل أداة."""
    return _admin_run(request, lambda: {"core": v3_teacher_prompts.SYSTEM_CORE})


@app.get("/admin/teacher/lessons")
async def admin_teacher_lessons(request: Request, subject: str = "",
                                grade: int = 3, track: str = "علمي"):
    """مواد الصف/المسار + شجرة وحدات المادة ودروسها — كي يجرّب الأدمن البرومبت
    على **درسٍ حقيقي**. والمواد تأتي من `curriculum` لا من قائمة في اللوحة:
    مصدرٌ واحد للحقيقة، فلا تنحرف اللوحة عن التطبيق عند تغيّر المنهج."""
    def _read():
        g, t = v3_curriculum.normalize_grade_track(grade, track)
        subjects = v3_curriculum.subjects_for(g, t)
        chosen = subject if subject in subjects else (subjects[0] if subjects else "")
        data = v3_teacher.units_and_lessons(g, t, chosen) if chosen else \
            {"subject": "", "available": False, "units": []}
        data["subjects"] = subjects
        data["grade"] = g
        data["track"] = t
        return data
    return _admin_run(request, _read)


@app.post("/admin/teacher/prompts/{tool}")
async def admin_teacher_prompt_set(tool: str, req: TeacherPromptRequest,
                                   request: Request):
    """حفظ برومبت أداة. الفراغ = العودة للمكتوب في الكود."""
    return _admin_run(
        request, lambda: v3_teacher.set_prompt(tool, req.kind, req.prompt))


@app.post("/admin/teacher/prompts/{tool}/try")
async def admin_teacher_prompt_try(tool: str, req: TeacherTryRequest,
                                   request: Request):
    """🧪 يجرّب **المسودّة غير المحفوظة** — هذا ما يمنع نشر برومبتٍ يهذي."""
    denied = _admin_gate(request)
    if denied is not None:
        return denied
    try:
        return _json_response(await v3_teacher.try_prompt(
            tool, req.kind, req.prompt or "", req.question, AI_CLIENTS,
            subject=req.subject, grade=req.grade, track=req.track,
            unit=req.unit_name, lesson=req.lesson_name))
    except v3_teacher.TeacherError as e:
        return _json_response({"error": str(e)}, 400)
    except Exception as e:
        print(f"⚠️ خطأ في تجربة برومبت المعلم: {e}")
        return _json_response({"error": "⚠️ تعذّرت التجربة."}, 500)


@app.get("/admin/settings")
async def admin_settings_get(request: Request):
    """⚙️ الإعدادات العامة + القيم الفعّالة الآن (بعد احتساب البيئة)."""
    def _read():
        stored = v3_scholarships.get_settings(force=True)
        return {
            "stored": stored,
            "effective": {
                "quota_ask": v3_quota.limit_for(False),
                "quota_guest": v3_quota.limit_for(True),
            },
            "ranges": {k: list(v) for k, v in v3_scholarships.SETTINGS_FIELDS.items()},
            "text_fields": dict(v3_scholarships.SETTINGS_TEXT_FIELDS),
        }
    return _admin_run(request, _read)


@app.post("/admin/settings")
async def admin_settings_set(request: Request, body: AdminSettingsRequest):
    """حفظ الإعدادات العامة — تصل الخادم خلال ≤ ٥ دقائق (كاش الإعدادات)."""
    return _admin_run(
        request,
        lambda: v3_scholarships.set_settings(body.model_dump(exclude_none=True)))


