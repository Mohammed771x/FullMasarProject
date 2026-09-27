# ==================================================
# 📦 core/body_limit.py — سقفٌ لحجم جسم الطلب قبل قراءته
# ==================================================
# 🔴 **الثغرة (فحص 2026-09-24):** لا سقف لحجم الطلب، وFastAPI يقرأ الجسم
#    ويحلّله **قبل** أن يصل المسارَ فيتحقق من التوكن. قيسَ: جسمٌ من ٨٣MB بلا
#    توكن ⇒ **+٢٩٠MB في الذاكرة** ثم 401. وبضعةُ طلباتٍ كهذه معاً تُسقط الحاوية
#    بنفاد الذاكرة — بلا حسابٍ ولا حصة، فلا حارسَ آخر يراها.
#
# ⭐ فالسقف هنا، في أول طبقة، **قبل أن يُقرأ بايتٌ واحد** حين يعلن العميل
#    الطول (`Content-Length` — وتطبيقُ فلاتر يعلنه دائماً)، وأثناء القراءة
#    حين لا يعلنه (`chunked`) فيُقطع عند تجاوز السقف لا بعد اكتمال الجسم.
#
# 📏 **لماذا ٨MB:** أكبرُ طلبٍ مشروع = صورتان × ٢٫١MB (base64) + سجلٌّ من ٨
#    رسائل + السؤال ≈ ٥MB. ولا يمسّ السقفُ رفعَ الغلاف (٨٠٠KB) ولا الصورة
#    الشخصية (٤٠٠KB). وأداةُ الإدخال للأدمن (٤٠ صفحة × ٨MB، تُكتب على القرص
#    لا في الذاكرة) لها سقفٌ أعلى باسم مسارها.

import os

from starlette.exceptions import HTTPException

MAX_BODY_BYTES = int(os.getenv("MAX_BODY_BYTES", str(8 * 1024 * 1024)))

# مساراتٌ بسقفٍ مختلف: (بادئة المسار، السقف).
PATH_LIMITS = (
    ("/ingest/", 40 * 8 * 1024 * 1024 + 4 * 1024 * 1024),
)

TOO_LARGE_MESSAGE = "📦 الطلب أكبر من المسموح. صغّر الصورة أو اختصر الرسالة وحاول مجدداً."


def limit_for(path: str) -> int:
    for prefix, cap in PATH_LIMITS:
        if path.startswith(prefix):
            return cap
    return MAX_BODY_BYTES


class BodyLimitMiddleware:
    """وسيطٌ ASGI خام — لا `BaseHTTPMiddleware` لأن تلك تكسر البثّ (SSE)."""

    def __init__(self, app):
        self.app = app

    async def __call__(self, scope, receive, send):
        if scope.get("type") != "http":
            return await self.app(scope, receive, send)

        cap = limit_for(scope.get("path", ""))

        # ① الطول المُعلَن: رفضٌ فوري قبل قراءة أي بايت.
        for name, value in scope.get("headers") or []:
            if name == b"content-length":
                try:
                    declared = int(value)
                except ValueError:
                    declared = -1
                if declared < 0 or declared > cap:
                    return await _reject(send)
                break

        # ② بلا طولٍ مُعلَن (chunked): عدٌّ أثناء القراءة وقطعٌ عند التجاوز.
        #    الاستثناء يصل قارئَ الجسم في FastAPI فيُعيد رفعه كما هو ⇒ 413.
        seen = 0

        async def limited_receive():
            nonlocal seen
            message = await receive()
            if message.get("type") == "http.request":
                seen += len(message.get("body", b""))
                if seen > cap:
                    raise HTTPException(status_code=413, detail=TOO_LARGE_MESSAGE)
            return message

        return await self.app(scope, limited_receive, send)


async def _reject(send):
    import json
    body = json.dumps({"answer": TOO_LARGE_MESSAGE, "session_active": False},
                      ensure_ascii=False).encode("utf-8")
    await send({"type": "http.response.start", "status": 413,
                "headers": [(b"content-type", b"application/json"),
                            (b"content-length", str(len(body)).encode()),
                            (b"connection", b"close")]})
    await send({"type": "http.response.body", "body": body})
