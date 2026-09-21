# -*- coding: utf-8 -*-
"""📄 التحليلات وصلاحية الأقسام

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    AccessRulesRequest, AccessSectionRequest, Request, _json_response, app,
    v3_access, v3_analytics, v3_audience, v3_ratelimit,
)
from .admin import _admin_run  # noqa: E402


# ══════════════════════════════════════════════════
# 📈 التحليلات · 👥 الشرائح
# ══════════════════════════════════════════════════
# ⚠️ **الفلتر ليس بابَ تسريب**: كل هذه المسارات خلف `_admin_run` — أي خلف
#    البوابة نفسها. والشريحة تُصفّي ما يراه المديرُ أصلاً، فلا تفتح له بيانات
#    لم تكن مفتوحة بدونها. ولا مسار منها يقبل «uid» من الطالب ليقرأ غيره.


@app.get("/admin/analytics")
async def admin_analytics(request: Request, days: int = 30, segment: str = "all",
                          subject: str = "", refresh: int = 0):
    """كل أرقام تبويب التحليلات — مفلترةً بالشريحة والمدّة والمادة."""
    return _admin_run(request, lambda: v3_analytics.overview_v2(
        days=days, segment=segment, subject=subject, force=bool(refresh)))


@app.get("/admin/segments")
async def admin_segments(request: Request):
    """الشرائح المعرّفة مرّةً واحدة — تبني منها اللوحة كل قوائمها."""
    return _admin_run(request, lambda: {"segments": v3_audience.describe_all()})


# ══════════════════════════════════════════════════
# 🔐 التحكم والوصول
# ══════════════════════════════════════════════════


@app.get("/admin/access")
async def admin_access(request: Request):
    """قواعد الأقسام + أثرها المحسوب لكل صف."""
    return _admin_run(request, v3_access.list_admin)


@app.post("/admin/access/{section}")
async def admin_access_section(request: Request, section: str,
                               body: AccessSectionRequest):
    """الوضع العام لقسم — يعلو على كل قاعدة شريحة."""
    return _admin_run(request, lambda: v3_access.set_section(
        section, body.mode, body.message))


@app.post("/admin/access/{section}/rules")
async def admin_access_rules(request: Request, section: str,
                             body: AccessRulesRequest):
    """قواعد الشرائح لقسم — تُستبدل كاملةً."""
    return _admin_run(request, lambda: v3_access.set_rules(
        section, [r.model_dump() for r in body.rules]))


@app.get("/app/access")
async def app_access(request: Request, grade: int = 3, track: str = "علمي",
                     role: str = "student"):
    """👁️ ما يراه هذا الملفّ من الأقسام — يقرأه التطبيق في كل إقلاع.

    ⚠️ **عامّ عمداً وبلا توثيق**: لا يكشف بياناتِ أحد، بل *شكلَ الواجهة*
       لصفٍّ ومسار. وطلبُ توكنٍ له يعني شاشةً بيضاء للزائر قبل تسجيله.
       والحمايةُ الحقيقية ليست هنا أصلاً بل في `_require_section` على
       المسارات العاملة — فمن يكذب في صفّه هنا لا يربح شيئاً.
    """
    if not v3_ratelimit.check(request, "access",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return _json_response({"error": "⏳ محاولات كثيرة. انتظر قليلاً."}, 429)
    try:
        grade = grade if grade in (1, 2, 3) else 3
        # 🎭 الدور من قائمةٍ مغلقة: `admin` لا يُقبل من العميل هنا إطلاقاً،
        #    وإلا فتح كلُّ من كتبه في الرابط أقساماً أُخفيت عنه. والدور
        #    الحقيقي يقرؤه `_section_gate` من `users/{uid}` على المسارات
        #    العاملة — وهو الحارس الوحيد الذي يُعتدّ به.
        role = role if role in ("student", "teacher") else "student"
        return _json_response({"sections": v3_access.resolve(grade, track, role)})
    except Exception as e:
        print(f"⚠️ قراءة قواعد الوصول: {e}")
        # 🛟 فشلٌ مفتوح: عطلُ القواعد لا يُخفي المنصّة عن الطلاب.
        return _json_response({"sections": v3_access.resolve(None, "")})



