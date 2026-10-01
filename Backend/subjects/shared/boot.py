import os
import json
import re
from typing import List, Dict, Any, Tuple, Optional
import numpy as np
import faiss
from sentence_transformers import SentenceTransformer
import asyncio
import hashlib
import math
import threading
import time
from concurrent.futures import ThreadPoolExecutor
# من config
# ⚠️ **مصدر واحد للحدود.** كانت هذه الثوابت تُستورد من config ثم **يُعاد
#    تعريفها هنا فوراً** — فتغيير القيمة في `config.py` لا يفعل شيئاً إطلاقاً.
#    نفس فخّ `normalize_arabic` المكرّرة ونفس فخّ الرقم 6 المبعثر.
from config import (
    BASE_SUBJECTS_DIR, QA_TOP_K, EXAMS_BATCH_SIZE,
    MAX_PAGES_EXPLAIN_SUMMARY, MAX_PAGES_EXAMS, UNIT_BATCH_PAGES,
    RELEVANCE_FLOOR, RELEVANCE_SURE,
)

# المتغيرات
embed_model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")


# ══════════════════════════════════════════════════
# 🔒 المُقطِّع لا يحتمل خيطين — قفلٌ واحدٌ لكل استعمالٍ له
# ══════════════════════════════════════════════════
# 🔴 **علّةٌ قِيست تحت الحمل (2026-10-02):** مُقطِّع HuggingFace السريع
#    (Rust) يرمي `RuntimeError: Already borrowed` إن لمسه خيطان معاً. وكان
#    يلمسه ثلاثة: `_token_len` على حلقة الأحداث، و`encode` في خيوط البركة،
#    وخيطُ الإحماء عند الإقلاع. فعند ٥٠ سؤالاً متزامناً:
#      • جهةُ `_token_len` لا يمسكها شيء ⇒ الطالب يرى «تعذّر توليد الإجابة»
#        (٢ من ٥٠، و١١ من ٥٠٠).
#      • وجهةُ `encode` يبتلعها `faiss_scores` ⇒ بحثٌ لفظيٌّ وحده **بصمت**
#        (٦٨٣ من ١٩٣٦ سؤالاً) — صفحاتٌ أضعف أو «ليس في وحدتك» كاذبة.
#
# ⚖️ والقفلُ لا يُبطئ شيئاً يُذكر: ترميزُ سؤالٍ ~٨ms، والتوازي فيه لم يكن
#    حقيقياً أصلاً (torch يوزّع الحساب على أنويته بنفسه).
#
# 🔁 `RLock` لا `Lock`: `encode` قد يمرّ بالمُقطِّع داخله، ومن يمسك القفل
#    لا يجوز أن ينتظر نفسه.
embed_lock = threading.RLock()


def encode(texts, **kwargs):
    """`embed_model.encode` تحت القفل — **لا يُنادى الموديلُ إلا من هنا**."""
    with embed_lock:
        return embed_model.encode(texts, **kwargs)


def token_ids(text: str, **kwargs):
    """`embed_model.tokenizer.encode` تحت القفل نفسِه."""
    with embed_lock:
        return embed_model.tokenizer.encode(text, **kwargs)


# 🧵 **خيوطُ التضمين منفصلةٌ عن بركة Firestore** ([api.py] · `executor`).
#    لو تقاسمتا بركةً واحدة لوقف خيوطُها كلُّها على القفل أعلاه تنتظر دورها
#    في الترميز، فيقف معها كلُّ نداء Firestore (التوثيق · الحصة) خلفها.
#    واثنان لا واحد: بناءُ فهرسٍ نادرٌ أثناء الطلب يشغل خيطاً، والثاني
#    يبقى لما سواه.
EMBED_EXECUTOR = ThreadPoolExecutor(max_workers=2, thread_name_prefix="embed")


async def run_embedding(fn, *args):
    """ينفّذ عمل تضمينٍ متزامن في خيوط التضمين — لا على حلقة الأحداث."""
    return await asyncio.get_running_loop().run_in_executor(EMBED_EXECUTOR, fn, *args)



