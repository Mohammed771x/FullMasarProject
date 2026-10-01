# -*- coding: utf-8 -*-
"""🆓 جلبُ الوزاري لا يمرّ بمعاملتَي الحصة (٢٠٢٦-١٠-٠١).

شكوى المالك: «الوزاري كان سريع جداً، الآن يتأخر». القياسُ في المحاكي:
الأسئلةُ من الملف في ٤ مللي ثانية، ثم حجزُ الحصة (~٢ث) وردُّها (~٢٫٧ث) في
Firestore لطلبٍ لم يكلّف شيئاً — والجوابُ محبوسٌ حتى يعود الردّ.
"""
import asyncio
from types import SimpleNamespace

import pytest

import api
from core import free_requests
from core import billing, quota


@pytest.fixture(autouse=True)
def _clean(monkeypatch):
    monkeypatch.setattr(quota, "_firestore", lambda: None)
    monkeypatch.delenv("QUOTA_UNLIMITED_UIDS", raising=False)
    quota.reset_memory()
    billing.clear()
    yield
    quota.reset_memory()
    billing.clear()


def _req(content, mode="وزاري", subject="رياضيات", grade=3, track="علمي", images=()):
    return SimpleNamespace(content=content, mode=mode, subject=subject,
                           grade=grade, track=track,
                           all_images=lambda: list(images))


@pytest.mark.parametrize("req", [
    _req("2024|نهايات الدوال المثلثية|10"),              # جلبُ الرياضيات
    _req("كمل"), _req("وقف"),                            # أوامرُ الجلسة
    _req("2024|أولاً: القراءة|قطعة|3", subject="عربي"),   # زرُّ الجلب في بقية المواد
    _req("2019,الحركة", subject="فيزياء"),
])
def test_data_only_requests_are_recognised(req):
    assert free_requests.data_only(req)


@pytest.mark.parametrize("req", [
    # ⚠️ سؤالٌ حرّ عن الأسئلة المعروضة — يُنادي موديلاً ([subjects/math] §٤).
    _req("اشرح لي حل السؤال الثالث"),
    _req("2024|درس|10", mode="شرح"),
    _req("كمل", images=["x"]),                           # قراءةُ الصورة مدفوعة
])
def test_model_requests_are_not(req):
    assert not free_requests.data_only(req)


def _identity(deferred):
    ident = {"uid": "u1", "is_guest": False, "_quota_reservation": None}
    if deferred:
        ident["_quota_deferred"] = True
    return ident


def _remaining():
    return quota.peek("u1", False)


def test_a_data_only_answer_costs_nothing_and_says_so(monkeypatch):
    async def fake_dispatch(req):
        return {"answer": "✅ وجدت ٦ أسئلة"}

    monkeypatch.setattr(api, "_dispatch_ask", fake_dispatch)
    before = _remaining()
    billing.start()
    result = asyncio.run(api._dispatch_and_settle(_req("كمل"), _identity(True)))
    assert _remaining() == before
    # والعميلُ لا يُنقص عدّاده ([chat_controller] يقرأ quota_refunded).
    assert result["quota_refunded"] is True


def test_an_unexpected_model_call_is_still_charged(monkeypatch):
    """⚖️ خطأُ التصنيف لا يفتح الفاتورة: ما نادى موديلاً يُخصم بعده."""
    async def fake_dispatch(req):
        billing.charge()
        return {"answer": "جوابُ موديل"}

    monkeypatch.setattr(api, "_dispatch_ask", fake_dispatch)
    before = _remaining()

    async def run():
        billing.start()
        return await api._dispatch_and_settle(_req("كمل"), _identity(True))

    result = asyncio.run(run())
    assert _remaining() == before - 1
    assert "quota_refunded" not in result
