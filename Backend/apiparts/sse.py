# -*- coding: utf-8 -*-
"""📄 مولّد أحداث البثّ

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    StreamingResponse, _as_payload, _attach_image_text, _remember, asyncio,
    v3_idem, v3_stream,
)


# ══════════════════════════════════════════════════
# 🌊 مولّد أحداث البثّ — **مصدرٌ واحد لكل المسارات**
# ══════════════════════════════════════════════════
# ⚠️ ثلاثة مسارات تبثّ الآن (تعليم · معلّم · منح)، ونسخُ منطق النبضة
#    والإغلاق والحدث الختامي في كلٍّ منها يعني ثلاثةَ أماكن يُنسى في
#    أحدها إصلاح. الفروق الحقيقية بينها ثلاثة معاملات لا أكثر.

async def _canned_payload(answer: str) -> dict:
    """حمولةُ جوابٍ من بطاقة المنحة — و`from_card` تُميّزه في السجلّات."""
    return {"answer": answer, "ok": True, "from_card": True}


def _sse_stream(*, uid: str, request_id: str, sink, runner, image_text: str = "",
                fallback: dict | None = None):
    """يعيد `StreamingResponse` تبثّ ما يكتبه `runner` في `sink`."""

    async def _run():
        try:
            return await runner()
        finally:
            await sink.close()

    async def _events():
        task = asyncio.create_task(_run())
        streamed_any = False
        try:
            # 1️⃣ الأجزاء أولاً بأول، مع نبضةٍ تمنع البروكسيات من قطع الصمت.
            drain = sink.drain().__aiter__()
            while True:
                try:
                    piece = await asyncio.wait_for(
                        drain.__anext__(), timeout=v3_stream.HEARTBEAT_SECONDS)
                except StopAsyncIteration:
                    break
                except asyncio.TimeoutError:
                    yield v3_stream.HEARTBEAT
                    continue
                streamed_any = True
                yield v3_stream.delta_event(piece)

            # 2️⃣ الحدث الختامي: النص **النهائي** بعد التنظيف + المراجع.
            #    ⚠️ والعميل يستبدل ما بثّه به لا يُلحقه: المعالجات تُنقّي
            #       الناتج بعد التوليد وقد تُلحق ملاحظة، فالمبثوث تقريبٌ
            #       والنهائيُّ هو الحقيقة.
            result = _attach_image_text(await task, image_text)
            payload = _as_payload(result) or {
                **(fallback or {}), "answer": sink.text}
            _remember(uid, request_id, payload)
            yield v3_stream.done_event(payload)

        except asyncio.CancelledError:
            # 🚪 الطالب أغلق الشاشة: نُلغي التوليد بدل أن يُكمل بلا قارئ.
            task.cancel()
            v3_idem.abandon(uid, request_id)
            raise
        except Exception as e:                       # noqa: BLE001
            print(f"🔥 خطأ أثناء البثّ: {e}")
            v3_idem.abandon(uid, request_id)
            # ⚠️ ما وصل الطالبَ يبقى معروضاً؛ نُخبره بالانقطاع ولا نمسحه.
            yield v3_stream.error_event(
                "⚠️ انقطع الاتصال أثناء الإجابة. حاول مرة أخرى."
                if streamed_any else
                "⚠️ تعذّر توليد الإجابة الآن. حاول بعد قليل.")

    return StreamingResponse(_events(), media_type="text/event-stream",
                             headers=v3_stream.SSE_HEADERS)


