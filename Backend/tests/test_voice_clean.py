"""اختبارات مسار تنظيف الصوت /voice/clean."""
import pytest
from fastapi.testclient import TestClient

import api
from core import ratelimit as rl
from core import voice_clean


from fakes import FakeResp


@pytest.fixture()
def client(no_real_api_calls):
    rl._buckets.clear()
    return TestClient(api.app)


def _body(**over):
    b = {"text": "اشرح لي درس الخليه"}
    b.update(over)
    return b


def test_clean_returns_cleaned_text(client):
    r = client.post("/voice/clean", json=_body())
    assert r.status_code == 200
    d = r.json()
    assert d["cleaned"] is True
    assert "GEMINI::" in d["text"]

def test_without_token_401(client, anonymous):
    assert client.post("/voice/clean", json=_body()).status_code == 401

def test_empty_text_ok(client):
    d = client.post("/voice/clean", json=_body(text="   ")).json()
    assert d == {"text": "", "cleaned": False}

def test_too_long_rejected_by_schema(client):
    assert client.post("/voice/clean", json=_body(text="ن" * 2000)).status_code == 422

def test_overlong_gets_truncated_at_processing():
    """النص الأطول من الحد يُقص قبل إرساله للموديل (اختبار الوحدة مباشرةً)."""
    import asyncio
    from fakes import make_fake_client
    captured = {}

    class _Capture:
        class chat:
            class completions:
                @staticmethod
                async def create(**kw):
                    user = next(m for m in kw["messages"] if m["role"] == "user")
                    captured["sent"] = user["content"]
                    return make_fake_client("X").chat.completions.__class__ and FakeResp("ok")

    asyncio.run(voice_clean.clean("ن" * 1500, {"gemini": _Capture()}))
    # الرسالة تحوي الترويسة + النص المقصوص فقط
    assert len(captured["sent"]) <= voice_clean.MAX_VOICE_TEXT + 40

def test_model_failure_returns_raw(client, monkeypatch):
    class _Boom:
        class chat:
            class completions:
                @staticmethod
                async def create(**kw): raise RuntimeError("down")
    monkeypatch.setitem(api.AI_CLIENTS, "gemini", _Boom())
    d = client.post("/voice/clean", json=_body(text="نص خام")).json()
    assert d == {"text": "نص خام", "cleaned": False}   # الفشل صامت — الخام يعود

def test_suspicious_inflation_returns_raw(client, monkeypatch):
    class _Inflate:
        class chat:
            class completions:
                @staticmethod
                async def create(**kw): return FakeResp("هراء " * 500)
    monkeypatch.setitem(api.AI_CLIENTS, "gemini", _Inflate())
    d = client.post("/voice/clean", json=_body(text="قصير")).json()
    assert d["text"] == "قصير" and d["cleaned"] is False

def test_rate_limited_429(client):
    for _ in range(rl.VOICE_LIMIT):
        client.post("/voice/clean", json=_body())
    assert client.post("/voice/clean", json=_body()).status_code == 429
