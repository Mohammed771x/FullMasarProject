# -*- coding: utf-8 -*-
"""📄 الحصة ونسخة التطبيق

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    Request, _json_response, app, v3_quota, v3_ratelimit, v3_scholarships,
)
from .identity import _identity_or_401  # noqa: E402


# ══════════════════════════════════════════════════
# 🎟️ حصّة الطالب — رقمٌ يراه قبل أن يصطدم به
# ══════════════════════════════════════════════════
# 🔴 **ما كان يحدث:** `quota.peek()` موجودة في الخادم منذ البداية ولا
#    مسارَ يعرضها. فالطالب يذاكر ثم يُمنع **فجأةً** في منتصف درسه بلا أي
#    إنذار سابق. الرقم كان عندنا — إخفاؤه لم يكن قراراً، كان سهواً.

@app.get("/me/quota")
async def my_quota(request: Request):
    """المتبقي من أسئلة اليوم لصاحب التوكن — قراءةٌ لا تخصم شيئاً."""
    ident, denied = _identity_or_401(request)
    if denied is not None:
        return denied
    if not v3_ratelimit.check(request, ident.get("uid", ""),
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return _json_response({"error": "⏳ محاولات كثيرة. انتظر قليلاً."}, 429)
    return _json_response(
        await v3_quota.astatus(ident.get("uid", ""), ident.get("is_guest", False)))


# ══════════════════════════════════════════════════
# 📦 أدنى إصدارٍ مقبول — بوابةُ الإنقاذ الوحيدة بعد النشر
# ══════════════════════════════════════════════════
# ⭐ **تُضاف قبل أول نشر أو لا تُضاف أبداً.** يوم يتغيّر عقد الـAPI، النسخُ
#    القديمة في جيوب الطلاب تنكسر صامتةً ولا وسيلة لمخاطبتها — إلا أن تكون
#    قد علّمتها **من قبل** أن تسأل. وبعد النشر لا يمكن تعليمها.
#
# 🔓 عامٌّ بلا توثيق عمداً: يُنادى **قبل** تسجيل الدخول، وطلبُ توكنٍ له يعني
#    أن النسخة المكسورة لا تستطيع حتى أن تعرف أنها مكسورة.
# 🛟 ويفشل مفتوحاً: أي عطلٍ يعني «لا تحديث مطلوب» — قاعدةُ تحديثٍ معطوبة
#    لا يجوز أن تحجب التطبيق عن الطلاب.

@app.get("/app/version")
async def app_version(request: Request, platform: str = "", build: int = 0):
    """أدنى بناءٍ مدعوم + الأحدث المتاح، مع رسالةٍ ووجهةٍ للتحديث."""
    if not v3_ratelimit.check(request, "version",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return _json_response({"update_required": False}, 200)
    try:
        settings = v3_scholarships.get_settings()
    except Exception:
        settings = {}

    def _int(key, fallback=0):
        value = settings.get(key)
        return int(value) if isinstance(value, (int, float)) else fallback

    min_build = _int("min_build", 0)
    latest_build = _int("latest_build", 0)
    store_url = str(settings.get("store_url") or "")
    message = str(settings.get("update_message") or
                  "📦 صدر تحديثٌ مهم لمسار — حدّث التطبيق لتتابع بلا مشاكل.")

    return _json_response({
        "min_build": min_build,
        "latest_build": latest_build,
        # الإلزام يُحسَب في الخادم لا في التطبيق: نسخةٌ قديمة قد تحسبه خطأً،
        # وهي بالضبط النسخة التي نريد إلزامها.
        "update_required": bool(build and min_build and build < min_build),
        "update_available": bool(build and latest_build and build < latest_build),
        "message": message,
        "store_url": store_url,
        "platform": (platform or "")[:16],
    })


