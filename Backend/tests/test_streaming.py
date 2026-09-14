"""🌊 بثّ الإجابة — الحرّاس أولاً، ثم الأجزاء، ثم الحدث الختامي.

⚠️ الاختبارات غير المتزامنة تُشغَّل بـ`asyncio.run` لا بـ`pytest-asyncio`:
   ثلاثةُ اختباراتٍ لا تُبرّر اعتماداً جديداً في بيئة الإنتاج.
"""
import asyncio
import json

import pytest
from fastapi.testclient import TestClient

import api
from core import idempotency as idem
from core import quota as q
from core import ratelimit as rl
from core import streaming as st
from core import user_state as us


@pytest.fixture()
def client(no_real_api_calls):
    rl._buckets.clear()
    q.reset_memory()
    idem.reset()
    us.reset()
    return TestClient(api.app)


HDR = {"Authorization": "Bearer t"}


def _body(**over):
    body = {"subject": "فيزياء", "mode": "شرح", "input_type": "برومت",
    # 🎟️ **وحدةٌ حقيقية وسؤالٌ من داخلها عمداً.**
    #    منذ أن صار الرفضُ لا يخصم من الحصة ([core/billing.py]) لم يعد
    #    طلبٌ بلا وحدة يصلح لاختبار الحصة: يُرفض مجاناً فلا يُخصم شيء.
    #    فاختبارُ الحصة يحتاج طلباً **يكلّف** فعلاً.
            "summary_level": 3, "content": "اشرح لي نظرية بوهر", "unit_name": "الفيزياء الذرية", "lesson_name": "",
            "chat_history": [], "grade": 3, "track": "علمي"}
    body.update(over)
    return body


def _events(response):
    """يفكّ أحداث SSE من الرد — متجاهلاً النبضات (تعليقات `:`)."""
    out = []
    for line in response.text.splitlines():
        if line.startswith("data: "):
            out.append(json.loads(line[6:]))
    return out


# ══════════════════════════════════════════════════
# 🛂 الحرّاس — قبل أي بثّ
# ══════════════════════════════════════════════════

def test_stream_requires_a_token(client, anonymous):
    """⚠️ الرفض يجب أن يصل **برمز حالةٍ صحيح** لا داخل تدفّق.

    العميل لا يستطيع قراءة رمز الحالة بعد أن يبدأ البثّ، فحارسٌ يردّ داخل
    التدفّق يجعل «سجّل الدخول» تبدو إجابةً من المعلّم.
    """
    r = client.post("/ask/stream", json=_body())
    assert r.status_code == 401
    assert "text/event-stream" not in r.headers.get("content-type", "")


def test_stream_enforces_quota_before_streaming(client, monkeypatch):
    """🎟️ الحصة تُفرض على مسار البثّ كما على المسار العادي — لا باب خلفي."""
    monkeypatch.setattr(q, "_general_limit", lambda guest: 1)
    q.reset_memory()

    first = client.post("/ask/stream", json=_body(), headers=HDR)
    assert first.status_code == 200

    second = client.post("/ask/stream", json=_body(), headers=HDR)
    assert second.status_code == 429
    assert second.json()["quota_exceeded"] is True


def test_stream_respects_idempotency(client):
    """🧾 إعادةٌ بنفس المعرّف لا تخصم مرتين ولا تنادي الموديل ثانيةً."""
    q.reset_memory()
    body = _body(request_id="same-attempt")

    client.post("/ask/stream", json=body, headers=HDR)
    after_first = q.peek("test-uid")

    again = client.post("/ask/stream", json=body, headers=HDR)
    assert q.peek("test-uid") == after_first
    assert again.status_code == 200


def test_stream_enforces_section_gate(client, monkeypatch):
    """🔐 قسمٌ مقفل يُرفض قبل البثّ وقبل خصم الحصة."""
    from core import access

    def blocked(section, grade, track, role):
        raise access.SectionBlocked("🔒 التعليم مغلق مؤقتاً.", mode="off")

    monkeypatch.setattr(access, "require", blocked)
    q.reset_memory()
    before = q.peek("test-uid")

    r = client.post("/ask/stream", json=_body(), headers=HDR)
    assert r.status_code == 403
    assert q.peek("test-uid") == before, "خُصمت حصة على قسمٍ مقفل"


# ══════════════════════════════════════════════════
# 🌊 شكل التدفّق
# ══════════════════════════════════════════════════

def test_stream_ends_with_a_done_event_carrying_the_full_answer(client):
    """الحدث الختامي يحمل النص النهائي والمراجع — وعليه يعتمد العميل."""
    r = client.post("/ask/stream", json=_body(), headers=HDR)
    assert r.status_code == 200
    assert "text/event-stream" in r.headers["content-type"]

    events = _events(r)
    assert events, "لم يصل أي حدث"
    last = events[-1]
    assert last["t"] == "done"
    assert isinstance(last.get("answer"), str) and last["answer"]
    assert "references" in last


def test_non_streaming_handler_still_delivers_through_the_same_channel(client):
    """🔁 معالجٌ لا يعرف البثّ ⇒ جوابه يصل في `done` — والعميل واحدٌ للجميع.

    ⭐ هذا ما يجعل التحويل تدريجياً بلا مخاطرة: المواد غير المحوَّلة تعمل
       عبر نفس المسار بلا سطرٍ واحد في العميل.
    """
    events = _events(client.post("/ask/stream", json=_body(), headers=HDR))
    assert events[-1]["t"] == "done"
    assert events[-1]["answer"]


def test_streaming_handler_emits_deltas(client, monkeypatch):
    """معالجٌ يبثّ ⇒ أجزاءٌ متتابعة ثم `done` بالنص المجمّع."""
    async def fake_dispatch(req):
        sink = st.sink_of(req)
        for piece in ("الأكسدة ", "هي فقدان ", "الإلكترونات."):
            await sink.push(piece)
        return {"answer": sink.text, "references": ["الوحدة الأولى"],
                "session_active": False}

    monkeypatch.setattr(api, "_dispatch_ask", fake_dispatch)
    events = _events(client.post("/ask/stream", json=_body(), headers=HDR))

    deltas = [e["v"] for e in events if e["t"] == "delta"]
    assert deltas == ["الأكسدة ", "هي فقدان ", "الإلكترونات."]
    assert events[-1]["answer"] == "الأكسدة هي فقدان الإلكترونات."
    assert events[-1]["references"] == ["الوحدة الأولى"]


def test_final_answer_wins_over_streamed_text(client, monkeypatch):
    """⚠️ العميل **يستبدل** المبثوث بالنهائي لا يُلحقه.

    المعالجات تُنقّي الناتج بعد التوليد وقد تُلحق ملاحظة، فالمبثوث تقريبٌ
    والنهائيُّ هو الحقيقة. ولو ألحق العميلُ لظهر الجواب مرتين.
    """
    async def fake_dispatch(req):
        sink = st.sink_of(req)
        await sink.push("نصٌّ خام \\(x\\)")
        return {"answer": "نصٌّ منقّى", "references": [], "session_active": False}

    monkeypatch.setattr(api, "_dispatch_ask", fake_dispatch)
    events = _events(client.post("/ask/stream", json=_body(), headers=HDR))
    assert events[-1]["answer"] == "نصٌّ منقّى"


def test_handler_failure_becomes_an_error_event_not_a_crash(client, monkeypatch):
    """💥 انفجارٌ في المعالج ⇒ حدث خطأ برسالة عربية، والحجز يُحرَّر."""
    async def boom(req):
        raise RuntimeError("انفجار")

    monkeypatch.setattr(api, "_dispatch_ask", boom)
    events = _events(client.post(
        "/ask/stream", json=_body(request_id="doomed"), headers=HDR))

    assert events[-1]["t"] == "error"
    assert "حاول" in events[-1]["v"]
    state, _ = idem.begin("test-uid", "doomed")
    assert state == idem.FRESH, "بقي الحجز عالقاً بعد فشل البثّ"


def test_sse_headers_disable_proxy_buffering(client):
    """🔴 بلا `X-Accel-Buffering` يجمّع nginx البثّ كله في دفعةٍ واحدة —
    فتعمل الميزة محلياً وتختفي في الإنتاج بلا أي خطأ يُنبّه."""
    r = client.post("/ask/stream", json=_body(), headers=HDR)
    assert r.headers.get("x-accel-buffering") == "no"
    assert "no-cache" in r.headers.get("cache-control", "")


# ══════════════════════════════════════════════════
# 🧩 المصرف نفسه
# ══════════════════════════════════════════════════

def test_complete_without_sink_behaves_exactly_as_before():
    """بلا مصرف: نداءٌ عادي — المعالجات غير المحوَّلة لا تتأثر إطلاقاً."""
    class _Msg:
        content = "جواب كامل"

    class _Choice:
        message = _Msg()

    class _Resp:
        choices = [_Choice()]

    class _Client:
        class chat:
            class completions:
                @staticmethod
                async def create(**kwargs):
                    assert "stream" not in kwargs, "طلب بثّاً بلا مصرف"
                    return _Resp()

    text = asyncio.run(st.complete(_Client(), model="m", messages=[], sink=None))
    assert text == "جواب كامل"


def test_sink_falls_back_when_provider_refuses_to_stream():
    """🛟 مزوّدٌ لا يدعم البثّ ⇒ نداءٌ عادي مرةً واحدة، والطالب يرى تأخيراً
    لا خطأً."""
    calls = {"stream": 0, "plain": 0}

    class _Msg:
        content = "جواب بديل"

    class _Choice:
        message = _Msg()

    class _Resp:
        choices = [_Choice()]

    class _Client:
        class chat:
            class completions:
                @staticmethod
                async def create(**kwargs):
                    if kwargs.get("stream"):
                        calls["stream"] += 1
                        raise RuntimeError("البثّ غير مدعوم")
                    calls["plain"] += 1
                    return _Resp()

    async def _run():
        sink = st.StreamSink()
        return sink, await st.complete(_Client(), model="m", messages=[], sink=sink)

    sink, text = asyncio.run(_run())
    assert text == "جواب بديل"
    assert calls == {"stream": 1, "plain": 1}
    assert sink.text == "جواب بديل", "الجواب البديل لم يصل الطالب"


def test_partial_stream_failure_does_not_duplicate_the_answer():
    """⚠️ انقطاعٌ **بعد** بدء البثّ لا يُعاد: وإلا رأى الطالب الشرح مرتين
    متداخلين."""
    class _Client:
        class chat:
            class completions:
                @staticmethod
                async def create(**kwargs):
                    async def _gen():
                        class _D:
                            content = "بداية "

                        class _C:
                            delta = _D()

                        class _Chunk:
                            choices = [_C()]

                        yield _Chunk()
                        raise RuntimeError("انقطع")
                    return _gen()

    async def _run():
        sink = st.StreamSink()
        with pytest.raises(RuntimeError):
            await st.complete(_Client(), model="m", messages=[], sink=sink)
        return sink

    assert asyncio.run(_run()).text == "بداية "


# ══════════════════════════════════════════════════
# 🌊 البثّ في كل مكان — معلّم · منح · كل المواد
# ══════════════════════════════════════════════════
# ⭐ قرار المالك (2026-09-09): الشاشة واحدة في التطبيق، فلا سبب لأن يبثّ
#    قسمُ الطالب ويتجمّد قسما المعلّم والمنح.

def _teacher_body(**over):
    body = {"tool": "plan", "generate": True, "subject": "فيزياء",
            "grade": 3, "track": "علمي", "unit_name": "", "lesson_name": "",
            "content": "", "chat_history": []}
    body.update(over)
    return body


def test_teacher_stream_exists_and_ends_with_done(client):
    r = client.post("/teacher/ask/stream", json=_teacher_body(), headers=HDR)
    assert r.status_code == 200
    assert "text/event-stream" in r.headers["content-type"]
    assert _events(r)[-1]["t"] == "done"


def test_teacher_stream_requires_a_token(client, anonymous):
    """الرفض برمز حالةٍ صحيح لا داخل التدفّق — كما في `/ask/stream`."""
    r = client.post("/teacher/ask/stream", json=_teacher_body())
    assert r.status_code == 401
    assert "text/event-stream" not in r.headers.get("content-type", "")


def test_teacher_stream_consumes_quota(client, monkeypatch):
    """🎟️ لا باب خلفي: مسار البثّ يخصم كنظيره العادي تماماً."""
    monkeypatch.setattr(q, "_general_limit", lambda guest: 1)
    q.reset_memory()
    assert client.post("/teacher/ask/stream", json=_teacher_body(),
                       headers=HDR).status_code == 200
    second = client.post("/teacher/ask/stream", json=_teacher_body(), headers=HDR)
    assert second.status_code == 429


def test_every_subject_handler_can_stream():
    """🌊 **كل المواد** تمرّ عبر `streaming.complete` لا نداءٍ مباشر.

    ⚠️ اختبارٌ بنيويّ لا سلوكيّ عمداً: تشغيل ست مواد بموديلات حقيقية غير
       وارد، لكن **بقاء نداءٍ مباشر واحد** يعني مادةً تتجمّد بينما أخواتها
       تبثّ — والطالب لا يعرف لماذا. فنحرس الشرط الذي يمكن حراسته.
    """
    import pathlib
    root = pathlib.Path(__file__).resolve().parent.parent
    offenders = []
    for name in ("biology", "physics", "chemistry", "arabic", "english", "math"):
        src = (root / "subjects" / f"{name}.py").read_text(encoding="utf-8")
        assert "streaming.complete" in src, f"{name} لا يبثّ إطلاقاً"
        # النداء المباشر الوحيد المسموح: `explain_math_lesson` (بلا `req`).
        direct = src.count("chat.completions.create")
        allowed = 1 if name == "math" else 0
        if direct > allowed:
            offenders.append(f"{name}: {direct} نداءً مباشراً")
    assert not offenders, "مواد لم تُحوَّل للبثّ: " + " · ".join(offenders)


def test_core_handlers_stream_too():
    """وضعا الدروس والوحدات ومساعدا المعلّم والمنح كذلك."""
    import pathlib
    root = pathlib.Path(__file__).resolve().parent.parent
    for name in ("lesson_mode", "pages_mode", "teacher_assistant",
                 "scholarship_assistant"):
        src = (root / "core" / f"{name}.py").read_text(encoding="utf-8")
        assert "streaming.complete" in src, f"core/{name}.py لا يبثّ"


# ══════════════════════════════════════════════════
# 📐 «ابدأ الشرح الذكي» — أكثر مسارٍ يُستعمل في الرياضيات
# ══════════════════════════════════════════════════

def test_math_smart_explain_streams(client, monkeypatch):
    """🔴 **العطل الذي شكا منه المالك:** «ابدأ الشرح الذكي» كان ينتظر صامتاً
    ثم يهبط الشرح دفعةً واحدة.

    والسبب أن `explain_math_lesson` استُثنيت من البثّ بتعليلٍ خاطئ: ظُنَّ أن
    `handle_math_explain` تبثّ ردَّها بنفسها، والحقيقة أن فرع «درس جديد»
    **يفوّضها كاملاً** ولا ينادي الموديل إطلاقاً.
    """
    from subjects import math as M

    captured = {}

    async def fake_explain(lesson, groq, deepseek, sink=None):
        captured["sink"] = sink
        if sink is not None:
            for piece in ("المستقيم ", "المقارب ", "هو…"):
                await sink.push(piece)
            return sink.text
        return "شرح بلا بثّ"

    monkeypatch.setattr(M, "explain_math_lesson", fake_explain)
    monkeypatch.setattr(M, "load_math_lesson", lambda b, n: {"اسم_الدرس": n})

    events = _events(client.post("/ask/stream", headers=HDR, json=_body(
        subject="رياضيات", mode="شرح", unit_name="تفاضل",
        lesson_name="المستقيمات المقاربة ودراسة الدوال الكسرية")))

    assert captured.get("sink") is not None, "وصل المصرف `None` — لا بثّ"
    deltas = [e["v"] for e in events if e["t"] == "delta"]
    assert deltas == ["المستقيم ", "المقارب ", "هو…"]
    assert events[-1]["t"] == "done"


def test_math_explain_is_not_excluded_from_streaming_anymore():
    """🛡️ حارسٌ بنيويّ: لا نداءَ مباشراً في `subjects/math.py` إطلاقاً.

    ⚠️ كان الاستثناء موثَّقاً في تعليق («لا تبثّ عمداً») — وهو ما جعله
       يبدو مقصوداً فلا يُراجَع. فنحرسه بالكود لا بالتعليق.
    """
    import pathlib
    src = (pathlib.Path(__file__).resolve().parent.parent /
           "subjects" / "math.py").read_text(encoding="utf-8")
    assert "chat.completions.create" not in src, \
        "بقي نداءٌ مباشر في math.py — مسارٌ لا يبثّ"
    assert src.count("streaming.complete") >= 4
