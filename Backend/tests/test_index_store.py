"""فهارس FAISS الدائمة: بصمة مستقرة · كاش محدود · قرص · إحماء."""
import os
import pytest

from core import index_store as st


@pytest.fixture(autouse=True)
def clean():
    st.clear_memory()
    yield
    st.clear_memory()


def test_fingerprint_is_stable_across_runs():
    """نفس النصوص ⇒ نفس البصمة دائماً — وإلا لم يُستفَد من القرص أبداً."""
    texts = ["الجهاز العصبي", "التكاثر", "الوراثة"]
    assert st.fingerprint(texts) == st.fingerprint(list(texts))


def test_fingerprint_detects_any_content_change():
    base = ["أ", "ب", "ج"]
    assert st.fingerprint(base) != st.fingerprint(["أ", "ب", "د"])      # تغيّر حرف
    assert st.fingerprint(base) != st.fingerprint(["أ", "ب"])           # نقص نص
    assert st.fingerprint(base) != st.fingerprint(["ب", "أ", "ج"])      # تغيّر ترتيب


def test_fingerprint_distinguishes_slices_with_same_edges():
    """الفخّ الذي وقعت فيه البصمة القديمة (الطول + الأول + الأخير):
    شريحتان مختلفتان بنفس الطول والحافتين كانتا تتشاركان فهرساً واحداً!"""
    a = ["بداية", "وسط مختلف تماماً", "نهاية"]
    b = ["بداية", "وسط آخر مغاير", "نهاية"]
    assert len(a) == len(b) and a[0] == b[0] and a[-1] == b[-1]
    assert st.fingerprint(a) != st.fingerprint(b)


def test_fingerprint_changes_with_model():
    texts = ["نص"]
    fp = st.fingerprint(texts)
    original = st.EMBED_MODEL_NAME
    try:
        st.EMBED_MODEL_NAME = "another-model"
        assert st.fingerprint(texts) != fp     # تبديل الموديل يُبطل الفهارس
    finally:
        st.EMBED_MODEL_NAME = original


def test_memory_cache_is_bounded_lru():
    """الكاش القديم كان قاموساً بلا سقف = تسريب ذاكرة مع كل شريحة جديدة."""
    for i in range(st.MAX_MEM_INDEXES + 10):
        st.put_mem(f"fp{i}", object())
    assert st.stats()["in_memory"] == st.MAX_MEM_INDEXES
    assert st.get_mem("fp0") is None                      # الأقدم خرج
    assert st.get_mem(f"fp{st.MAX_MEM_INDEXES + 9}") is not None


def test_lru_keeps_recently_used():
    for i in range(st.MAX_MEM_INDEXES):
        st.put_mem(f"k{i}", object())
    st.get_mem("k0")                                       # استُعمل ⇒ يصعد
    st.put_mem("new", object())                            # يُخرج التالي لا k0
    assert st.get_mem("k0") is not None
    assert st.get_mem("k1") is None


def test_missing_disk_index_returns_none():
    assert st.load_disk("لا-يوجد-هذا-الفهرس") is None


def test_stats_shape():
    s = st.stats()
    for key in ("builds", "disk_hits", "mem_hits", "in_memory", "on_disk", "model"):
        assert key in s


def test_warmup_module_lists_providers():
    """كل مادة لها محتوى يجب أن يكون لها مستخرج نصوص، وإلا لن تُحمَّى."""
    from core import warmup
    provs = warmup._providers()
    for subject in ("احياء", "فيزياء", "كيمياء", "عربي", "انجليزي"):
        assert subject in provs, subject


def test_index_dir_is_inside_backend():
    assert st.INDEX_DIR.endswith("indexes")
    assert os.path.basename(os.path.dirname(st.INDEX_DIR)) == "Backend"
