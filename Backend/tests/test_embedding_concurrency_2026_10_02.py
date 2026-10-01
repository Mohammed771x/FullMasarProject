"""🔒 التضمينُ تحت التزامن — المُقطِّع الآمن، وكاشُ المقاطع، وفصلُ البركتين.

🔴 **ما قِيس قبل الإصلاح (2026-10-02):** مُقطِّع HuggingFace السريع يرمي
   `Already borrowed` إن لمسه خيطان معاً. عند ٥٠ سؤالاً متزامناً سقط سؤالان
   بـ«تعذّر توليد الإجابة»، و٦٨٣ من ١٩٣٦ سؤالاً فقدت بحثها الدلاليّ بصمت.
   ونفسُ الحِمل على المُقطِّع الخام يسقط في كل تجربة (٢–٥ أخطاء من ٧٢ نداءً).

⚠️ الاختبارات غير المتزامنة تُشغَّل بـ`asyncio.run` لا بـ`pytest-asyncio`
   — نفسُ قاعدة [test_streaming.py].
"""
import asyncio
import os
import re
import threading

import pytest

from core import blocking_pool
from subjects import common
from subjects.shared import boot, context, indexing
from subjects.shared.content import extract_all_texts_and_metas

BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


@pytest.fixture(scope="module")
def unit_texts():
    """صفحاتُ كتابٍ حقيقيّ — المقاطعُ وأطوالُها هي ما يُقاس لا نصٌّ مصنوع."""
    book = common.load_json_safe(common.subject_book_path("فيزياء", 3, "علمي"))
    texts, _ = extract_all_texts_and_metas(book)
    texts = [t for t in texts if t]
    assert len(texts) >= 40, "كتابُ الفيزياء غاب — الاختبار يحتاج نصاً حقيقياً"
    return texts[:40]


@pytest.fixture(autouse=True)
def fresh_corpus_cache():
    indexing.clear_corpus_cache()
    yield
    indexing.clear_corpus_cache()


# ══════════════════════════════════════════════════
# 🔒 المُقطِّع — خيوطٌ كثيرة ولا خطأٌ واحد
# ══════════════════════════════════════════════════

def test_tokenizer_and_encoder_survive_many_threads(unit_texts):
    """الحِملُ نفسُه الذي يُسقط المُقطِّعَ الخام في كل تجربة — عبر المساعدَين.

    ١٢ خيطاً تتناوب بين عدّ الرموز (مسار التقطيع) والترميز (مسار البحث)،
    وهما بالضبط المساران اللذان تصادما تحت الحمل.
    """
    errors = []

    def work(k):
        try:
            for r in range(6):
                text = unit_texts[(k * 3 + r) % len(unit_texts)]
                if (k + r) % 2:
                    boot.token_ids(text, add_special_tokens=False)
                else:
                    boot.encode([text], convert_to_numpy=True, show_progress_bar=False)
        except Exception as e:                    # noqa: BLE001
            errors.append(f"{type(e).__name__}: {e}")

    threads = [threading.Thread(target=work, args=(k,)) for k in range(12)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()
    assert errors == []


def test_the_model_is_only_touched_through_the_lock():
    """🧱 **حارسٌ بنيويّ**: نداءٌ مباشرٌ واحد للموديل أو المُقطِّع خارج `boot.py`
    يُعيد العلّةَ كلَّها — والتصادمُ احتماليٌّ فلن يمسكه اختبارُ حِملٍ دائماً."""
    pattern = re.compile(r"embed_model\.(encode|tokenizer)")
    offenders = []
    for root in ("subjects", "core", "apiparts"):
        for dirpath, _dirs, files in os.walk(os.path.join(BACKEND, root)):
            for name in files:
                if not name.endswith(".py"):
                    continue
                path = os.path.join(dirpath, name)
                if path.endswith(os.path.join("shared", "boot.py")):
                    continue
                with open(path, encoding="utf-8") as f:
                    for n, line in enumerate(f, 1):
                        if pattern.search(line) and not line.lstrip().startswith("#"):
                            offenders.append(f"{os.path.relpath(path, BACKEND)}:{n}")
    for name in ("api.py",):
        with open(os.path.join(BACKEND, name), encoding="utf-8") as f:
            if pattern.search(f.read()):
                offenders.append(name)
    assert offenders == [], f"نداءٌ للموديل بلا قفل: {offenders}"


# ══════════════════════════════════════════════════
# 🗄️ كاشُ المقاطع — نفسُ الناتج حرفاً بحرف، ومرّةً واحدة
# ══════════════════════════════════════════════════

def test_cached_corpus_is_identical_to_a_fresh_split(unit_texts):
    expected = indexing._split_corpus(unit_texts)
    first = indexing.embedding_corpus(unit_texts)
    second = indexing.embedding_corpus(unit_texts)
    assert first == expected
    assert second == expected


def test_corpus_is_split_once_per_content(unit_texts, monkeypatch):
    calls = []
    real = indexing._split_corpus
    monkeypatch.setattr(indexing, "_split_corpus",
                        lambda texts: calls.append(1) or real(texts))
    for _ in range(5):
        indexing.embedding_corpus(unit_texts)
    assert len(calls) == 1

    # ✏️ تعديلُ حرفٍ في الكتاب ⇒ بصمةٌ جديدة ⇒ تقطيعٌ جديد (لا كاشٌ قديم).
    edited = list(unit_texts)
    edited[0] = edited[0] + " ."
    indexing.embedding_corpus(edited)
    assert len(calls) == 2


def test_callers_get_a_copy_not_the_cache(unit_texts):
    """من يُعدّل ما أخذه لا يُفسد سؤالَ غيره."""
    chunks, owners = indexing.embedding_corpus(unit_texts)
    expected = (list(chunks), list(owners))
    chunks.clear()
    owners.append(-1)
    assert indexing.embedding_corpus(unit_texts) == expected


def test_corpus_cache_is_bounded(monkeypatch):
    monkeypatch.setattr(indexing, "MAX_CORPUS_CACHE", 3)
    for i in range(10):
        indexing.embedding_corpus([f"صفحة رقم {i}"])
    assert len(indexing._corpus_cache) == 3


def test_a_cache_miss_is_split_off_the_event_loop(unit_texts, monkeypatch):
    """⚠️ الإخفاقُ يمرّ بالمُقطِّع، والمُقطِّعُ خلف قفلٍ قد يمسكه بناءُ فهرس —
    فانتظارُه على الحلقة يُجمّد الخادمَ كلَّه."""
    seen = []
    real = indexing._split_corpus

    def spy(texts):
        seen.append(threading.current_thread().name)
        return real(texts)

    monkeypatch.setattr(indexing, "_split_corpus", spy)
    result = asyncio.run(indexing.embedding_corpus_async(unit_texts))
    assert result == real(unit_texts)
    assert len(seen) == 1 and seen[0].startswith("embed")


# ══════════════════════════════════════════════════
# 🌊 البحثُ الهجين تحت التزامن — لا خطأ، ونفسُ الجواب
# ══════════════════════════════════════════════════

_QUERIES = ["اشرح لي نظرية بوهر", "ما هو طيف ذرة الهيدروجين",
            "إشعاع الجسم الأسود", "ما معنى التكميم", "الظاهرة الكهروضوئية"]


def test_hybrid_rank_under_concurrency_matches_sequential(unit_texts):
    """١٠٠ سؤالٍ متزامن **ومعها خيطُ إحماءٍ يقطّع نصوصاً أخرى** — وهو التصادم
    الثالث الذي وقع عند الإقلاع. كلُّ نتيجةٍ = نتيجتُه وحده بلا تزامن."""
    async def sequential():
        out = {}
        for q in _QUERIES:
            r = await context.hybrid_rank(unit_texts, q, 4)
            out[q] = (r[1], round(r.best, 6))
        return out

    expected = asyncio.run(sequential())
    indexing.clear_corpus_cache()          # الدفعةُ تبدأ باردة: الإخفاقُ يتزاحم أيضاً

    stop = threading.Event()
    warm_errors = []

    def warmup_like():
        i = 0
        while not stop.is_set():
            try:
                indexing.embedding_corpus([t + f" {i}" for t in unit_texts[:8]])
            except Exception as e:            # noqa: BLE001
                warm_errors.append(repr(e))
            i += 1

    async def burst():
        tasks = [context.hybrid_rank(unit_texts, _QUERIES[i % len(_QUERIES)], 4)
                 for i in range(100)]
        return await asyncio.gather(*tasks, return_exceptions=True)

    warm = threading.Thread(target=warmup_like)
    warm.start()
    try:
        results = asyncio.run(burst())
    finally:
        stop.set()
        warm.join()

    failures = [r for r in results if isinstance(r, BaseException)]
    assert failures == [] and warm_errors == []
    for i, r in enumerate(results):
        q = _QUERIES[i % len(_QUERIES)]
        assert (r[1], round(r.best, 6)) == expected[q], q


def test_semantic_scores_never_silently_vanish_under_concurrency(unit_texts):
    """🔇 العلّةُ الصامتة: `faiss_scores` كانت تبتلع `Already borrowed` وتعيد
    `{}` — فيُجاب الطالب ببحثٍ لفظيٍّ وحده ولا يرى أحدٌ خطأ."""
    chunks, _ = indexing.embedding_corpus(unit_texts)

    async def burst():
        return await asyncio.gather(*(context.faiss_scores(chunks, _QUERIES[i % 5])
                                      for i in range(100)))

    results = asyncio.run(burst())
    assert all(len(r) == len(chunks) for r in results)


def test_query_embedding_runs_in_the_embedding_threads(unit_texts, monkeypatch):
    """التضمينُ في خيوطه — لا في بركة Firestore فيقف خيوطُها على القفل."""
    seen = []
    real = context.encode
    monkeypatch.setattr(context, "encode",
                        lambda *a, **k: seen.append(threading.current_thread().name)
                        or real(*a, **k))
    chunks, _ = indexing.embedding_corpus(unit_texts)
    asyncio.run(context.faiss_scores(chunks, "نظرية بوهر"))
    assert seen and all(name.startswith("embed") for name in seen)


# ══════════════════════════════════════════════════
# 🧵 بركةُ الانتظار الشبكيّ — ٤٨ لا ٨، ومربوطةٌ بحلقة الخادم
# ══════════════════════════════════════════════════

def test_blocking_pool_is_wide_enough():
    async def run():
        return blocking_pool.install()._max_workers

    assert blocking_pool.WORKERS == 48
    assert asyncio.run(run()) == 48


def test_each_loop_gets_a_live_pool():
    """`asyncio.run` يُغلق بركةَ حلقته عند انتهائها — فالحلقةُ التالية تحتاج
    بركةً حيّة لا تلك الميتة (وقع فعلاً أثناء كتابة هذه الاختبارات)."""
    async def run():
        blocking_pool.install()
        return await asyncio.to_thread(lambda: "ok")

    assert asyncio.run(run()) == "ok"
    assert asyncio.run(run()) == "ok"


def test_lifespan_installs_the_pool_on_the_running_loop(monkeypatch):
    import api
    monkeypatch.setattr(api.v3_warmup, "start_background", lambda: None)

    async def run():
        async with api.lifespan(api.app):
            loop = asyncio.get_running_loop()
            installed = loop._default_executor is blocking_pool.executor
            name = await asyncio.to_thread(lambda: threading.current_thread().name)
            return installed, name

    installed, name = asyncio.run(run())
    assert installed
    assert name.startswith("worker")


def test_firestore_style_waits_run_48_at_once():
    """٤٨ انتظاراً شبكياً متزامناً تنتهي معاً لا على ست دفعات كما كانت بثمانية."""
    import time

    async def run():
        blocking_pool.install()
        t = time.perf_counter()
        await asyncio.gather(*(asyncio.to_thread(time.sleep, 0.2) for _ in range(48)))
        return time.perf_counter() - t

    assert asyncio.run(run()) < 0.6
