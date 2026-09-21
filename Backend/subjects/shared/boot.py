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
import time
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



