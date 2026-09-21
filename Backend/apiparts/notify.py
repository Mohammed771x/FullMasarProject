# -*- coding: utf-8 -*-
"""📄 الأجهزة والإشعارات

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    DeviceTokenRequest, NotificationCreateRequest,
    NotificationPreviewRequest, Request, _json_response, app, v3_access,
    v3_auth, v3_notify, v3_push,
)
from .admin import _admin_run  # noqa: E402
from .identity import _identity_or_401  # noqa: E402


@app.post("/me/device")
async def register_device(request: Request, body: DeviceTokenRequest):
    """يربط رمز هذا الجهاز بحساب صاحب التوكن."""
    ident, denied = _identity_or_401(request)
    if denied is not None:
        return denied
    # 🧪 الزائر لا يُسجَّل: حسابه مؤقت ويُرقّى، فرمزُه يُربط بحسابه الدائم
    #    عند التسجيل لا قبله — وإلا بقي مربوطاً بحسابٍ مجهولٍ مهجور.
    if ident.get("is_guest"):
        return _json_response({"registered": False, "reason": "guest"}, 200)
    try:
        return _json_response(v3_push.register(
            ident.get("uid", ""), body.token, body.platform))
    except v3_push.PushError as e:
        return _json_response({"error": str(e)}, 400)
    except Exception as e:
        print(f"⚠️ تسجيل جهاز: {e}")
        return _json_response({"error": "⚠️ تعذّر تسجيل الجهاز."}, 500)


@app.post("/me/profile-changed")
async def profile_changed(request: Request):
    """🔄 يُنادى بعد تبديل **الدور أو الصف أو المسار** من التطبيق.

    ⭐ **لماذا يلزم نداءٌ صريح؟** حارس الأقسام يقرأ `users/{uid}` بكاشٍ
       عمرُه دقيقتان ([core/access.py]) — قراءةٌ لكل طلبٍ ثمنٌ لا يُدفع
       لأجل قاعدة إخفاء. لكن معنى ذلك أن من حوّل نفسه إلى «معلّم» يبقى
       الخادمُ يعامله طالباً حتى تنقضي المهلة: يفتح قسمه فيُمنع، فيظن
       التحويل لم يعمل. هذا المسار يُسقط كاشَه وحده فيسري التحويل **فوراً**.

    🔒 ولا يقبل `uid` من الطلب: التوكن وحده يحدّد صاحبَ الكاش المُسقَط،
       وإلا أسقط أيُّ أحدٍ كاشَ غيره وأجبر الخادمَ على قراءةٍ لكل طلب.
    """
    ident, denied = _identity_or_401(request)
    if denied is not None:
        return denied
    uid = ident.get("uid", "")
    v3_access.forget_profile(uid)
    return _json_response({"refreshed": True})


@app.delete("/me/device")
async def unregister_device(request: Request, token: str = ""):
    """يفصل رمز الجهاز عن الحساب — يُنادى عند الخروج.

    ⚠️ لازمٌ لا تحسين: جوّالٌ يتشاركه أخوان يبقى رمزُه مربوطاً بالأول،
       فتصل إشعاراتُه إلى جهازٍ يستعمله الثاني.
    """
    ident, denied = _identity_or_401(request)
    if denied is not None:
        return denied
    return _json_response(v3_push.unregister(ident.get("uid", ""), token))


@app.get("/notifications/inbox")
async def notifications_inbox(request: Request, limit: int = 20):
    """📬 إشعارات هذا المستخدم — يقرأها التطبيق عند الإقلاع.

    ⚠️ **التوكن وحده يحدّد صاحب الصندوق**، ولا يقبل المسار `uid` من الطلب:
       لو قبله لقرأ كلُّ طالبٍ صندوقَ غيره بتغيير حرف.
    """
    token = v3_auth.bearer_token(request)
    if not token:
        return _json_response({"error": "⛔ تسجيل الدخول مطلوب.", "items": []}, 401)
    try:
        ident = v3_auth.verify(token)
    except v3_auth.AuthError as e:
        return _json_response({"error": str(e), "items": []}, 401)
    return _json_response({"items": v3_notify.inbox(ident.get("uid", ""), limit)})


@app.get("/admin/notifications")
async def admin_notifications(request: Request, limit: int = 50):
    """سجل الإشعارات + هل يوجد ناقل دفع أصلاً."""
    return _admin_run(request, lambda: v3_notify.list_admin(limit))


@app.post("/admin/notifications/preview")
async def admin_notifications_preview(request: Request,
                                      body: NotificationPreviewRequest):
    """👁️ عدد المستلمين وتفصيلهم — **قبل** الإرسال ولا يكتب شيئاً."""
    return _admin_run(request, lambda: v3_notify.preview(
        body.segment, body.notifications_only, body.uids, body.link))


@app.post("/admin/notifications")
async def admin_notification_create(request: Request,
                                    body: NotificationCreateRequest):
    """ينشئ الإشعار ويثبّت لقطة مستلميه."""
    return _admin_run(request, lambda: v3_notify.create(body.model_dump()))


@app.delete("/admin/notifications/{notif_id}")
async def admin_notification_delete(request: Request, notif_id: str):
    """حذف إشعار — يزيله من صناديق من لم يقرأه."""
    return _admin_run(request, lambda: v3_notify.delete(notif_id))


