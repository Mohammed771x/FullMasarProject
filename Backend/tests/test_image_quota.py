"""📷 حدُّ الصور اليومي، وقراءةُ صور الرياضيات بموديلها (٢٠٢٦-١٠-٠١).

قرارُ المالك: «الطالب في اليوم معه عشر صور… من لوحة التحكم… في كل مكان»،
و«3.8-flash للرياضيات وحدها، والباقي كما هو».
"""
import asyncio
import base64
import io

import pytest

from core import quota as q
from core import scholarships
from core import vision as v


def _png() -> str:
    """صورةٌ حقيقية صغيرة يقبلها `image_guard` (يفحص البايتات لا الامتداد)."""
    from PIL import Image
    buf = io.BytesIO()
    Image.new("RGB", (40, 40), "white").save(buf, "PNG")
    return base64.b64encode(buf.getvalue()).decode()


class _FakeClient:
    """يسجّل الموديلَ والبرومبت اللذين طُلبا — بلا شبكة."""

    def __init__(self, reply="نصٌّ مستخرج", fail=False):
        self.calls = []
        self.reply, self.fail = reply, fail
        self.chat = self
        self.completions = self

    async def create(self, **kw):
        self.calls.append(kw)
        if self.fail:
            raise RuntimeError("boom")

        class _M:
            content = self.reply

        class _C:
            message = _M()

        class _R:
            choices = [_C()]

        return _R()


@pytest.fixture(autouse=True)
def _memory_store(monkeypatch):
    """عدّادٌ في الذاكرة، وإعداداتٌ فارغة، ولا حساباتِ فحصٍ معفاة."""
    monkeypatch.setattr(q, "_firestore", lambda: None)
    monkeypatch.setattr(scholarships, "get_settings", lambda force=False: {})
    monkeypatch.delenv("QUOTA_UNLIMITED_UIDS", raising=False)
    q.reset_memory()
    yield
    q.reset_memory()


def _run(coro):
    return asyncio.run(coro)


def test_the_eleventh_image_is_refused_with_a_clear_message():
    client = _FakeClient()
    clients = {"gemini": client}
    for _ in range(q.DAILY_IMAGES):
        _run(v.extract_images([_png()], clients, uid="u1", subject="فيزياء"))
    with pytest.raises(v.ImageQuotaExceeded) as e:
        _run(v.extract_images([_png()], clients, uid="u1", subject="فيزياء"))
    assert "حدّك اليومي من الصور" in str(e.value)
    assert str(q.DAILY_IMAGES) in str(e.value)
    # الرفضُ قبل أي نداء موديل: لا فاتورةَ لصورةٍ مرفوضة.
    assert len(client.calls) == q.DAILY_IMAGES


def test_limit_comes_from_the_dashboard(monkeypatch):
    monkeypatch.setattr(scholarships, "get_settings",
                        lambda force=False: {"quota_images": 2})
    clients = {"gemini": _FakeClient()}
    _run(v.extract_images([_png(), _png()], clients, uid="u2"))
    with pytest.raises(v.ImageQuotaExceeded):
        _run(v.extract_images([_png()], clients, uid="u2"))


def test_zero_turns_images_off(monkeypatch):
    monkeypatch.setattr(scholarships, "get_settings",
                        lambda force=False: {"quota_images": 0})
    with pytest.raises(v.ImageQuotaExceeded):
        _run(v.extract_images([_png()], {"gemini": _FakeClient()}, uid="u3"))


def test_each_user_has_their_own_count(monkeypatch):
    monkeypatch.setattr(scholarships, "get_settings",
                        lambda force=False: {"quota_images": 1})
    clients = {"gemini": _FakeClient()}
    _run(v.extract_images([_png()], clients, uid="a"))
    _run(v.extract_images([_png()], clients, uid="b"))   # لا يتأثر بـ«a»


def test_test_accounts_are_unlimited(monkeypatch):
    monkeypatch.setattr(scholarships, "get_settings",
                        lambda force=False: {"quota_images": 1})
    monkeypatch.setenv("QUOTA_UNLIMITED_UIDS", "sim")
    clients = {"gemini": _FakeClient()}
    for _ in range(5):
        _run(v.extract_images([_png()], clients, uid="sim"))


def test_a_failed_read_does_not_cost_an_image(monkeypatch):
    monkeypatch.setattr(scholarships, "get_settings",
                        lambda force=False: {"quota_images": 1})
    with pytest.raises(v.VisionFailed):
        _run(v.extract_images([_png()], {"gemini": _FakeClient(fail=True)}, uid="u4"))
    # الصورةُ التي لم تُقرأ رُدّت — فالطالب ما زال يملك صورته الوحيدة.
    _run(v.extract_images([_png()], {"gemini": _FakeClient()}, uid="u4"))


def test_math_uses_its_own_model_and_prompt_others_unchanged():
    math, phys = _FakeClient(), _FakeClient()
    _run(v.extract_images([_png()], {"gemini": math}, uid="m", subject="رياضيات"))
    _run(v.extract_images([_png()], {"gemini": phys}, uid="p", subject="فيزياء"))
    assert math.calls[0]["model"] == v.MATH_VISION_MODEL == "gemini-3.8-flash"
    assert r"\frac" in math.calls[0]["messages"][0]["content"]
    assert phys.calls[0]["model"] == v.VISION_MODEL == "gemini-3.1-flash-lite"
    assert phys.calls[0]["messages"][0]["content"] == v._SYSTEM


def test_math_reply_shows_what_was_read_and_asks_to_check():
    merged = v.merge_into_question([r"جا ٣س\sup{٢}"], "حل", "رياضيات")
    assert merged.rstrip().endswith("وأصحّح.»")
    assert "المسألة كما قرأتُها من صورتك" in merged
    # 📄 صفحةُ شرحٍ لا تُعاد نسخاً — يشرحها مباشرةً.
    assert "اشرح مباشرةً بلا إعادة نسخها" in merged
    # وبقيةُ المواد بلا هذه التعليمات.
    assert "تعليمات الرد" not in v.merge_into_question(["نص"], "حل", "فيزياء")


def test_history_never_cuts_markup_in_half():
    body = "أ" * 890 + r"\frac{س\sup{٢}}{٣}"
    out = v.history_text([body])
    assert out.count("{") == out.count("}")
    assert r"\frac" not in out      # الأمرُ الذي لم يكتمل يُحذف كلُّه
