"""🌊 صمتُ الموديل لا يقتل البثّ (شكوى المالك 2026-09-24: «شوف كيف وقف»).

🔴 كان انتظارُ الجزء التالي `wait_for(drain.__anext__(), 15)`، و`wait_for`
   تُلغي ما تنتظره عند المهلة — فيموت مولّدُ المصرف عند أول نبضة. الموديل
   يُكمل، والطالب يرى النصَّ متجمّداً في منتصف كلمة حتى يصل الجواب كاملاً.
"""
import asyncio
import json

import api  # noqa: F401 — يُحمّل المسارات
from apiparts import sse
from core import idempotency
from core import streaming as st


def _collect(resp):
    async def run():
        out = []
        async for chunk in resp.body_iterator:
            out.append(chunk if isinstance(chunk, str) else chunk.decode())
        return out
    return asyncio.run(run())


def _deltas(chunks):
    got = []
    for c in chunks:
        if c.startswith("data: "):
            ev = json.loads(c[6:])
            if ev["t"] == "delta":
                got.append(ev["v"])
    return got


def test_pieces_after_a_long_model_pause_still_reach_the_student(monkeypatch):
    monkeypatch.setattr(st, "HEARTBEAT_SECONDS", 0.05)
    sink = st.StreamSink()

    async def runner():
        await sink.push("أولاً ")
        await asyncio.sleep(0.3)             # صمتٌ أطول من ست نبضات
        await sink.push("**الانتحاء** ")
        await sink.push("انتهى")
        return {"answer": "أولاً **الانتحاء** انتهى"}

    chunks = _collect(sse._sse_stream(uid="u", request_id="", sink=sink, runner=runner))

    assert _deltas(chunks) == ["أولاً ", "**الانتحاء** ", "انتهى"], "البثّ مات بعد الصمت"
    assert chunks.count(st.HEARTBEAT) >= 2, "لا نبضات أثناء الصمت — قد يقطعه البروكسي"
    assert json.loads(chunks[-1][6:])["t"] == "done"


def test_several_pauses_in_one_answer():
    sink = st.StreamSink()
    orig = st.HEARTBEAT_SECONDS
    st.HEARTBEAT_SECONDS = 0.03
    try:
        async def runner():
            for i in range(4):
                await sink.push(f"ج{i} ")
                await asyncio.sleep(0.1)
            return {"answer": "x"}
        chunks = _collect(sse._sse_stream(uid="u", request_id="", sink=sink, runner=runner))
    finally:
        st.HEARTBEAT_SECONDS = orig
    assert _deltas(chunks) == ["ج0 ", "ج1 ", "ج2 ", "ج3 "]


def test_client_leaving_during_a_pause_cancels_generation(monkeypatch):
    """🚪 إلغاءُ الجزء المنتظر والتوليد معاً — لا مهمّةٌ يتيمة تعمل بلا قارئ."""
    monkeypatch.setattr(st, "HEARTBEAT_SECONDS", 0.05)
    sink = st.StreamSink()
    state = {"cancelled": False}

    async def runner():
        await sink.push("بداية ")
        try:
            await asyncio.sleep(10)
        except asyncio.CancelledError:
            state["cancelled"] = True
            raise
        return {"answer": "x"}

    idempotency.reset()
    idempotency.begin("u", "rid-1")

    async def scenario():
        resp = sse._sse_stream(uid="u", request_id="rid-1", sink=sink, runner=runner)
        gen = resp.body_iterator
        first = await gen.__anext__()
        assert "بداية" in first
        consumer = asyncio.ensure_future(gen.__anext__())
        await asyncio.sleep(0.12)            # نبضةٌ أو اثنتان ثم يغادر
        consumer.cancel()
        try:
            await consumer
        except (asyncio.CancelledError, StopAsyncIteration):
            pass
        await asyncio.sleep(0.05)

    asyncio.run(scenario())
    assert state["cancelled"], "التوليد استمرّ بلا قارئ"
    assert idempotency.begin("u", "rid-1")[0] == idempotency.FRESH, "الحجز لم يُحرَّر"
