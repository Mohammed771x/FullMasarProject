# ==================================================
# 🗂️ core/index_store.py — فهارس FAISS دائمة على القرص
# ==================================================
# **المشكلة التي يحلّها ([ADR-012]):** كان كل فهرس يُبنى **عند أول سؤال**
# يلمس تلك النصوص، ولا يُحفظ أبداً. فكل إقلاع للخادم = بناء من الصفر،
# والطالب الأول في كل وحدة يدفع ثمن الانتظار.
#
# الحل ثلاث طبقات:
#   1. 💾 **القرص**  — `indexes/{بصمة}.faiss` يُقرأ في أجزاء من الثانية
#   2. 🧠 **الذاكرة** — كاش LRU محدود (كان قاموساً بلا سقف = تسريب)
#   3. 🔥 **الإحماء** — عند إقلاع الخادم تُبنى/تُحمَّل كل الفهارس مسبقاً،
#      فأول سؤال للطالب لا يبني شيئاً
#
# البصمة = SHA-1 على **كل** النصوص + اسم الموديل:
#   • تغيّر حرف واحد في المحتوى ⇒ بصمة جديدة ⇒ إعادة بناء تلقائية
#   • تبديل موديل التضمين ⇒ إبطال كل الفهارس تلقائياً
#   (البصمة القديمة كانت «الطول + أول 80 حرفاً + آخر 80» — عرضة للتصادم
#    بين شرائح مختلفة لها نفس البداية والنهاية.)

import os
import json
from typing import Optional
import hashlib
import threading
import time
from collections import OrderedDict

import faiss

INDEX_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "indexes")
MANIFEST = os.path.join(INDEX_DIR, "manifest.json")

EMBED_MODEL_NAME = "paraphrase-multilingual-MiniLM-L12-v2"

# سقف الذاكرة: كل فهرس ≈ عدد النصوص × 384 × 4 بايت.
# كل محتوى المنصة اليوم ≈ 3 ميغابايت، فالسقف كرمٌ متعمَّد وليس ضيقاً.
MAX_MEM_INDEXES = 128

_mem = OrderedDict()          # {fingerprint: faiss.Index} — LRU
_lock = threading.Lock()

_stats = {"builds": 0, "disk_hits": 0, "mem_hits": 0, "saved": 0, "warm_done": False,
          "warm_started_at": None, "warm_seconds": None, "warm_errors": []}


def fingerprint(texts) -> str:
    """بصمة مستقرة عبر التشغيلات — تعتمد على المحتوى كاملاً واسم الموديل."""
    h = hashlib.sha1()
    h.update(EMBED_MODEL_NAME.encode("utf-8"))
    h.update(str(len(texts)).encode())
    for t in texts:
        h.update(b"\x00")
        h.update((t or "").encode("utf-8", "ignore"))
    return h.hexdigest()[:20]


def _path(fp: str) -> str:
    return os.path.join(INDEX_DIR, f"{fp}.faiss")


# ══════════════ ذاكرة ══════════════

def get_mem(fp: str):
    with _lock:
        idx = _mem.get(fp)
        if idx is not None:
            _mem.move_to_end(fp)          # LRU: الأحدث استعمالاً في النهاية
            _stats["mem_hits"] += 1
        return idx


def put_mem(fp: str, index):
    with _lock:
        _mem[fp] = index
        _mem.move_to_end(fp)
        while len(_mem) > MAX_MEM_INDEXES:
            _mem.popitem(last=False)      # أقدم استعمالاً يخرج أولاً


# ══════════════ قرص ══════════════

def load_disk(fp: str):
    """يقرأ الفهرس من القرص إن وُجد — أسرع بمراتب من إعادة التضمين."""
    p = _path(fp)
    if not os.path.isfile(p):
        return None
    try:
        index = faiss.read_index(p)
        _stats["disk_hits"] += 1
        return index
    except Exception as e:
        print(f"⚠️ فهرس تالف على القرص ({fp}): {e} — سيُعاد بناؤه.")
        try:
            os.remove(p)
        except OSError:
            pass
        return None


def save_disk(fp: str, index, meta: Optional[dict] = None):
    try:
        os.makedirs(INDEX_DIR, exist_ok=True)
        faiss.write_index(index, _path(fp))
        _stats["saved"] += 1
        _update_manifest(fp, meta or {}, index.ntotal)
    except Exception as e:
        print(f"⚠️ تعذّر حفظ الفهرس {fp}: {e}")


def _update_manifest(fp: str, meta: dict, ntotal: int):
    """سجلّ بشري القراءة: أي فهرس يخصّ أي مادة/صف/وحدة."""
    try:
        data = {}
        if os.path.isfile(MANIFEST):
            with open(MANIFEST, "r", encoding="utf-8") as f:
                data = json.load(f)
        data[fp] = {**meta, "vectors": ntotal, "model": EMBED_MODEL_NAME,
                    "built_at": time.strftime("%Y-%m-%d %H:%M:%S")}
        with open(MANIFEST, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=1)
    except Exception:
        pass          # السجلّ للتوثيق فقط — فشله لا يعطّل شيئاً


def count_disk_indexes() -> int:
    if not os.path.isdir(INDEX_DIR):
        return 0
    return len([f for f in os.listdir(INDEX_DIR) if f.endswith(".faiss")])


def mark_build():
    _stats["builds"] += 1


def stats() -> dict:
    with _lock:
        mem = len(_mem)
    return {**_stats, "in_memory": mem, "on_disk": count_disk_indexes(),
            "dir": INDEX_DIR, "model": EMBED_MODEL_NAME}


def clear_memory():
    """للاختبارات."""
    with _lock:
        _mem.clear()
