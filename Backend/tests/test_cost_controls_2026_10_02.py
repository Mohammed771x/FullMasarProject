# -*- coding: utf-8 -*-
"""💰 ضوابط التكلفة (٢٠٢٦-١٠-٠٢) — أربعة إصلاحاتٍ من فحص التكلفة:

١. التوكنات الفعلية والتكلفة لكل نداء ([core/ai_usage])
٢. ميزانيةُ الزوّار المشتركة — صنعُ حساباتٍ مجهولة لا يفتح الفاتورة ([core/guest_pool])
٣. سقفٌ يومي لتنظيف الصوت ([core/ratelimit] · [apiparts/study])
٤. قراءةُ `usage` في لوحة التحكم: مسحٌ واحد ثم الجديد وحده ([core/usage_index])
"""
import asyncio
from datetime import datetime, timezone

import pytest
from fastapi.testclient import TestClient

import api
from core import ai_usage, billing, guest_pool, quota, ratelimit, streaming, usage_index


# ══════════════ ١. التوكنات والتكلفة ══════════════

DEEPSEEK_USAGE = {"prompt_tokens": 10_000, "completion_tokens": 1_000, "total_tokens": 11_000,
                  "prompt_cache_hit_tokens": 4_000, "prompt_cache_miss_tokens": 6_000,
                  "completion_tokens_details": {"reasoning_tokens": 300}}
PEAK = datetime(2026, 10, 5, 7, 0, tzinfo=timezone.utc)       # إثنين ٠٧:٠٠ UTC
OFF_PEAK = datetime(2026, 10, 5, 15, 0, tzinfo=timezone.utc)
WEEKEND = datetime(2026, 10, 4, 7, 0, tzinfo=timezone.utc)    # أحد


def test_deepseek_tokens_read_cache_hits_and_reasoning():
    tok = ai_usage.tokens_of(DEEPSEEK_USAGE)
    assert tok == {"input": 10_000, "cached": 4_000, "output": 1_000, "reasoning": 300}


def test_gemini_thinking_outside_completion_is_still_billed():
    """إن حسب المزوّد التفكيرَ خارج `completion_tokens` فهو في `total` — ولا يضيع."""
    tok = ai_usage.tokens_of({"prompt_tokens": 100, "completion_tokens": 50,
                              "total_tokens": 230})
    assert tok["output"] == 130 and tok["reasoning"] == 80


def test_deepseek_cost_peak_vs_off_peak():
    tok = ai_usage.tokens_of(DEEPSEEK_USAGE)
    peak = ai_usage.cost_usd("deepseek-flash", tok, PEAK)
    # 6000×0.30 + 4000×0.006 + 1000×1.20 (لكل مليون)
    assert peak == pytest.approx((6000 * 0.30 + 4000 * 0.006 + 1000 * 1.20) / 1e6)
    assert ai_usage.cost_usd("deepseek-flash", tok, OFF_PEAK) == pytest.approx(peak / 2)
    assert not ai_usage.is_deepseek_peak(WEEKEND)


def test_gemini_flash_price_doubles_after_2026():
    tok = {"input": 1_000_000, "cached": 0, "output": 0, "reasoning": 0}
    assert ai_usage.cost_usd("gemini-3.8-flash", tok, PEAK) == pytest.approx(0.75)
    jan = datetime(2027, 1, 2, tzinfo=timezone.utc)
    assert ai_usage.cost_usd("gemini-3.8-flash", tok, jan) == pytest.approx(1.50)


def test_unknown_model_is_unpriced_not_invented():
    tok = {"input": 10, "cached": 0, "output": 10, "reasoning": 0}
    assert ai_usage.cost_usd("some-new-model", tok) is None


def test_record_fills_the_request_meter_and_summary():
    ai_usage.reset()
    meter = billing.start("u-1", "ask")
    entry = ai_usage.record("deepseek-flash", DEEPSEEK_USAGE)
    assert entry["purpose"] == "ask" and entry["uid"] == "u-1"
    assert meter["usd"] > 0 and meter["tok_input"] == 10_000
    s = ai_usage.summary(days=1)
    assert s["total"]["calls"] == 1
    assert s["total"]["input"] == 10_000 and s["total"]["cached"] == 4_000
    assert s["models"]["deepseek-flash"]["calls"] == 1
    assert s["purposes"]["ask"]["calls"] == 1
    assert s["recent"][0]["model"] == "deepseek-flash"
    billing.clear()
    ai_usage.reset()


class _Chunk:
    def __init__(self, text=None, usage=None):
        delta = type("D", (), {"content": text})()
        self.choices = [type("C", (), {"delta": delta})()] if text else []
        self.usage = usage


class _StreamClient:
    """مزوّدٌ يبثّ قطعتين ثم قطعة `usage` بلا `choices` — كما يفعل ديب سيك وجيميناي."""
    def __init__(self):
        self.kwargs = None
        outer = self

        class _Completions:
            async def create(self, **kw):
                outer.kwargs = kw

                async def gen():
                    # جيميناي يرسل usage تراكمياً مع كل قطعة — يُسجَّل الأخير مرّةً
                    yield _Chunk("أهلاً ", usage={"prompt_tokens": 10_000, "completion_tokens": 1,
                                                  "total_tokens": 10_001})
                    yield _Chunk("بك")
                    yield _Chunk(usage=DEEPSEEK_USAGE)
                return gen()

        self.chat = type("Chat", (), {"completions": _Completions()})()


def test_streaming_asks_for_usage_and_records_it():
    ai_usage.reset()
    client = _StreamClient()
    meter = billing.start("u-2", "ask")

    async def run():
        sink = streaming.StreamSink()
        return await streaming.complete(client, model="deepseek-flash",
                                        messages=[], sink=sink)

    assert asyncio.run(run()) == "أهلاً بك"
    assert client.kwargs["stream_options"] == {"include_usage": True}
    assert meter["tok_input"] == 10_000 and meter["usd"] > 0
    assert ai_usage.summary(1)["total"]["calls"] == 1          # نداءٌ واحد = سطرٌ واحد
    billing.clear()
    ai_usage.reset()


# ══════════════ ٢. ميزانية الزوّار ══════════════

@pytest.fixture()
def pool_of_three(monkeypatch):
    quota.reset_memory()
    guest_pool.reset()
    monkeypatch.setattr(guest_pool, "limit", lambda: 3)
    yield
    quota.reset_memory()
    guest_pool.reset()


def test_new_anonymous_accounts_cannot_exceed_the_shared_pool(pool_of_three):
    """كلُّ حسابٍ جديدٍ بخمسة أسئلة — لكن الزوّار جميعاً لا يتجاوزون الميزانية."""
    results = [quota.check_and_consume(f"anon-{i}", is_guest=True)[0] for i in range(6)]
    assert results == [True, True, True, False, False, False]
    assert quota.message_for(True) == guest_pool.POOL_MESSAGE


def test_registered_students_are_untouched_by_the_guest_pool(pool_of_three):
    for i in range(3):
        quota.check_and_consume(f"anon-{i}", is_guest=True)
    assert quota.check_and_consume("student-1", is_guest=False)[0] is True
    assert "منتصف الليل" in quota.message_for(False)


def test_refund_returns_the_question_to_the_pool(pool_of_three):
    for i in range(3):
        quota.check_and_consume(f"anon-{i}", is_guest=True)
    assert quota.check_and_consume("anon-x", is_guest=True)[0] is False
    quota.refund("anon-0", is_guest=True)
    assert quota.check_and_consume("anon-x", is_guest=True)[0] is True


def test_a_guest_out_of_their_own_trial_does_not_eat_the_pool(monkeypatch, pool_of_three):
    monkeypatch.setattr(quota, "_general_limit", lambda is_guest: 1)
    assert quota.check_and_consume("anon-a", is_guest=True)[0] is True
    assert quota.check_and_consume("anon-a", is_guest=True)[0] is False   # تجربتُه نفدت
    assert guest_pool.status()["used"] == 1


def test_pool_zero_blocks_guests(monkeypatch):
    guest_pool.reset()
    monkeypatch.setattr(guest_pool, "limit", lambda: 0)
    assert quota.check_and_consume("anon-z", is_guest=True)[0] is False
    guest_pool.reset()


def test_guest_ask_gets_the_pool_message(monkeypatch, pool_of_three):
    from core import firebase_auth as fa
    guest = {"uid": "anon-last", "email": "", "email_verified": False,
             "provider": "anonymous", "is_guest": True, "name": ""}
    monkeypatch.setattr(fa, "verify", lambda token: dict(guest))
    for i in range(3):
        quota.check_and_consume(f"anon-{i}", is_guest=True)
    r = TestClient(api.app).post("/ask", json={
        "subject": "فيزياء", "mode": "سؤال", "input_type": "برومت",
        "content": "ما هو الزخم؟", "grade": 3, "track": "علمي"})
    assert r.status_code == 429
    assert r.json()["answer"] == guest_pool.POOL_MESSAGE


# ══════════════ ٣. السقف اليومي لتنظيف الصوت ══════════════

def test_voice_daily_cap_returns_raw_text_without_a_model_call(monkeypatch):
    ratelimit.reset()
    monkeypatch.setattr(ratelimit, "VOICE_DAILY", 2)
    client = TestClient(api.app)
    first = [client.post("/voice/clean", json={"text": f"نص {i}"}).json() for i in range(2)]
    assert all(d["cleaned"] for d in first)
    capped = client.post("/voice/clean", json={"text": "نصٌّ خام"})
    assert capped.status_code == 200
    assert capped.json() == {"text": "نصٌّ خام", "cleaned": False, "daily_limit": True}
    ratelimit.reset()


def test_sweep_does_not_forget_a_daily_bucket(monkeypatch):
    """☢️ التنظيف كان يكنس كلَّ دلوٍ خامل دقيقتين — فيُصفَّر الحدّ اليومي لمن ينتظر."""
    ratelimit.reset()
    clock = [1_000_000.0]
    monkeypatch.setattr(ratelimit.time, "time", lambda: clock[0])
    assert ratelimit.check_user("u", 1, 86400.0, scope="voice_day")
    clock[0] += 600                                     # عشر دقائق
    ratelimit._last_sweep = 0.0
    assert ratelimit.check_user("other", 20, 60.0)      # نداءٌ بنافذة دقيقة يُشغّل التنظيف
    assert not ratelimit.check_user("u", 1, 86400.0, scope="voice_day")
    ratelimit.reset()


# ══════════════ ٤. قراءة usage للوحة ══════════════

class _Snap:
    def __init__(self, doc_id, data):
        self.id, self._d = doc_id, data

    def to_dict(self):
        return dict(self._d)


class _UsageCol:
    def __init__(self, store):
        self.store = store

    def select(self, fields):
        self.store.selects += 1
        return self

    def stream(self):
        self.store.full_reads += len(self.store.docs)
        return [_Snap(k, v) for k, v in self.store.docs.items()]

    def where(self, *args, **kwargs):
        f = kwargs.get("filter")
        since = f.value if f is not None else args[2]
        hits = [_Snap(k, v) for k, v in self.store.docs.items() if v["updated_at"] >= since]
        self.store.partial_reads += len(hits)
        return type("Q", (), {"stream": lambda _self: hits})()


class _UsageDB:
    def __init__(self, docs):
        self.docs, self.full_reads, self.partial_reads, self.selects = docs, 0, 0, 0

    def collection(self, name):
        assert name == "usage"
        return _UsageCol(self)


def _old(asks):
    return {"asks": asks, "updated_at": datetime(2026, 1, 1, tzinfo=timezone.utc)}


def test_index_scans_once_then_reads_only_what_changed():
    usage_index.reset()
    docs = {f"u{i}_2026-01-01": _old(1) for i in range(500)}
    docs["guest_g1"] = _old(3)
    docs["img_u1_2026-01-01"] = _old(7)
    db = _UsageDB(docs)

    daily, guests = usage_index.read(db)
    assert db.full_reads == 502 and len(daily) == 500 and guests == {"g1": 3}
    assert "img_u1" not in daily                       # حصةُ الصور ليست مستخدماً

    today = datetime.now(timezone.utc)
    docs["u7_2026-10-02"] = {"asks": 4, "updated_at": today}
    daily, _ = usage_index.read(db)
    assert db.full_reads == 502                        # لا مسحَ ثانياً
    assert db.partial_reads == 1                       # المستندُ الذي تغيّر وحده
    assert daily["u7"] == {"2026-01-01": 1, "2026-10-02": 4}
    usage_index.reset()


def test_index_falls_back_to_a_full_scan_if_the_query_fails():
    usage_index.reset()
    db = _UsageDB({"u1_2026-01-01": _old(2)})
    usage_index.read(db)

    def boom(*a, **k):
        raise RuntimeError("index missing")
    _UsageCol.where, saved = boom, _UsageCol.where
    try:
        daily, _ = usage_index.read(db)
    finally:
        _UsageCol.where = saved
    assert daily["u1"] == {"2026-01-01": 2}
    usage_index.reset()


def test_returned_data_is_a_copy():
    usage_index.reset()
    db = _UsageDB({"u1_2026-01-01": _old(2)})
    daily, _ = usage_index.read(db)
    daily["u1"]["2026-01-01"] = 999
    assert usage_index.read(db)[0]["u1"]["2026-01-01"] == 2
    usage_index.reset()
