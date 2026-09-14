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



USAGE_HELP = {
    "صفحة": (
        "أنت في وضع الصفحات. اكتب أرقام الصفحات مفصولة بفواصل.\n"
        f"مثال: 45 أو 45,47\n"
        f"ملاحظة: الحد الأقصى للصفحات هنا هو {MAX_PAGES_EXPLAIN_SUMMARY} صفحات للشرح/تلخيص."
    ),
    "وحدة": (
        "أنت في وضع الوحدة. اكتب اسم الوحدة أو رقمها كما هو مكتوب في محتوى الكتاب.\n"
        f"سيتم شرح {UNIT_BATCH_PAGES} صفحة في كل مرة. اكتب 'كمل' للاستمرار أو 'وقف' لإنهاء الجلسة."
    ),
    "برومت": (
        "أنت في وضع البرومت. اكتب موضوعًا أو سؤالاً نصياً. يمكنك تحديد وحدة معينة لتسريع البحث ودقته."
    ),
    "سؤال": (
        "أنت في وضع السؤال. اكتب سؤالاً نصياً مفهوماً. يفضل تحديد الوحدة المختصة بالسؤال لنتائج أدق."
    ),
    "وزاري": (
        "أنت في وضع الأسئلة الوزارية.\n"
        "الصيغ المقبولة:\n"
        "- بحث بالوحدة: <سنة>,<اسم الوحدة>  مثال: 2018,الغدد الصماء\n"
        f"- بحث بالصفحات: <سنة>,<صفحة1>,<صفحة2>  (الحد الأقصى للصفحات هنا {MAX_PAGES_EXAMS})\n"
        "- بحث بالبرومت: <سنة>,<موضوع>  مثال: 2019,التنفس\n"
        "يمكنك كتابة 'الكل' بدلاً من السنة للبحث عبر كل السنوات."
    )
}





_subject_session_timestamps = {}

def cleanup_subject_sessions(sessions_dict: dict, session_timestamps: dict):
    """تنظيف الجلسات المنتهية لأي مادة"""
    now = time.time()
    expired = [
        uid for uid, ts in session_timestamps.items()
        if now - ts > 1800  # 30 دقيقة
    ]
    for uid in expired:
        sessions_dict.pop(uid, None)
        session_timestamps.pop(uid, None)
        
        
        



def help_for_mode(mode: str, input_type: str = None) -> str:
    if mode == "شرح":
        if input_type == "صفحة": return USAGE_HELP["صفحة"]
        if input_type == "وحدة": return USAGE_HELP["وحدة"]
        return USAGE_HELP["برومت"]
    if mode == "تلخيص":
        return USAGE_HELP["برومت"] + "\nاختر درجة التلخيص من 1 إلى 5."
    if mode == "سؤال": return USAGE_HELP["سؤال"]
    if mode == "وزاري": return USAGE_HELP["وزاري"]
    return "استخدم التطبيق لشرح أو تلخيص أو سؤال أو أسئلة وزارية."





# ── البنية: data/subjects/{المادة}/{gradeN}/[{المسار}]/{الوضع}/ ──
#    الصف الأول موحّد (بلا مجلد مسار). الثاني والثالث: علمي | أدبي.
LESSONS_DIR = "lessons_mode"
UNIT_DIR = "unit_mode"
_GRADE_DIRS = {1: "grade1", 2: "grade2", 3: "grade3"}


def mode_dir(subject: str, mode: str, grade: int = 3, track: str = "علمي") -> str:
    """مجلد وضعٍ لمادة في صف/مسار. الافتراضي الثالث العلمي — وهو ما
    تعتمد عليه المعالجات القديمة التي تستدعي بلا صف."""
    gdir = _GRADE_DIRS.get(grade, "grade3")
    base = os.path.join(BASE_SUBJECTS_DIR, subject, gdir)
    if grade == 1:
        return os.path.join(base, mode)
    return os.path.join(base, track or "علمي", mode)


def _first_real_json(dirpath: str):
    """أول ملف JSON فعلي في المجلد (تجاهل ما يبدأ بـ _ أو .)."""
    if not os.path.isdir(dirpath):
        return None
    for fname in sorted(os.listdir(dirpath)):
        if fname.startswith(("_", ".")):
            continue
        fpath = os.path.join(dirpath, fname)
        if os.path.isfile(fpath) and fname.lower().endswith(".json"):
            return fpath
    return None


# النطاق الذي كُتبت له الملفات القديمة (قبل إعادة الهيكلة إلى صفوف).
# ⚠️ التوافق الرجعي مسموح **لهذا النطاق وحده**: أي صف/مسار آخر يقرأ
#    مجلده هو فقط، وإن كان فارغاً فالجواب «لا يوجد محتوى» — لا محتوى صفٍّ آخر.
LEGACY_GRADE, LEGACY_TRACK = 3, "علمي"


def _is_legacy_scope(grade, track) -> bool:
    try:
        grade = int(grade)
    except (TypeError, ValueError):
        return False
    return grade == LEGACY_GRADE and (track or LEGACY_TRACK) == LEGACY_TRACK


def subject_book_path(subject: str, grade: int = 3, track: str = "علمي",
                      prefer: str = UNIT_DIR) -> str:
    """مسار كتاب المادة لصف/مسار محدد: الوضع المفضَّل أولاً ثم الآخر.

    المواقع القديمة تُجرَّب **للثالث العلمي فقط** — فلا يرث صفٌّ محتوى صفٍّ آخر.

    🔴 **لماذا `prefer`؟ (علّة حقيقية وقعت 2026-09-03)** المعالجات القديمة
       لكلٍّ منها شكلٌ تتوقّعه: الأحياء **قائمة صفحات**، وغيرها **قاموس وحدات
       ودروس**. وكان الترتيب `unit_mode` ثم `lessons_mode` **دائماً** — فبقي
       سليماً بالصدفة وحدها: لأن الفيزياء والكيمياء لم يكن لهما ملف صفحات.
       يوم أضاف المالك `unit_mode/فيزياء.json` انهار معالج الفيزياء فوراً
       بـ`AttributeError: 'list' object has no attribute 'get'` — أي أن
       **إضافة محتوى صحيح كسرت الكود**. فليقل كلُّ نداءٍ أيَّ شكلٍ يريد.
    """
    order = (UNIT_DIR, LESSONS_DIR) if prefer == UNIT_DIR else (LESSONS_DIR, UNIT_DIR)
    for mode in order:
        d = mode_dir(subject, mode, grade, track)
        named = os.path.join(d, f"{subject}.json")
        if os.path.isfile(named):
            return named
        found = _first_real_json(d)
        if found:
            return found

    legacy_base = os.path.join(BASE_SUBJECTS_DIR, subject)
    if not _is_legacy_scope(grade, track):
        # مسار غير موجود عمداً ⇒ load_json_safe ترجع None ⇒ «قيد الإضافة 🚧»
        return os.path.join(mode_dir(subject, order[0], grade, track), f"{subject}.json")

    # مواقع قديمة (قبل إعادة الهيكلة) — الثالث العلمي وحده
    for candidate in (
        os.path.join(legacy_base, order[0], f"{subject}.json"),
        os.path.join(legacy_base, order[1], f"{subject}.json"),
        os.path.join(legacy_base, f"{subject}.json"),
    ):
        if os.path.isfile(candidate):
            return candidate
    return os.path.join(legacy_base, f"{subject}.json")


def math_branch_dir(branch: str, grade: int = 3, track: str = "علمي") -> str:
    """مجلد فرع الرياضيات (الفرع = وحدة) — الجديد أولاً، والقديم للثالث العلمي فقط."""
    new = os.path.join(mode_dir("رياضيات", LESSONS_DIR, grade, track), branch)
    if os.path.isdir(new):
        return new
    if not _is_legacy_scope(grade, track):
        return new  # غير موجود ⇒ قائمة فارغة ⇒ رسالة «قيد الإضافة»
    legacy = os.path.join(BASE_SUBJECTS_DIR, "رياضيات", LESSONS_DIR, branch)
    if os.path.isdir(legacy):
        return legacy
    return os.path.join(BASE_SUBJECTS_DIR, "رياضيات", branch)


def subject_exams_dir(subject: str, grade: int = 3, track: str = "علمي") -> str:
    """مجلد بنك الوزاري لصف/مسار.

    بنك الوزاري الحالي كله **للثالث العلمي** ومخزَّن مسطّحاً في `{المادة}/exams/`.
    لإضافة وزاري صف آخر لاحقاً: أنشئ `{المادة}/exams/grade{N}/` (وللصف 2/3
    مجلد المسار بداخله) — يُقرأ تلقائياً دون تعديل كود.
    """
    base = os.path.join(BASE_SUBJECTS_DIR, subject, "exams")
    gdir = _GRADE_DIRS.get(grade, "grade3")
    scoped = os.path.join(base, gdir) if grade == 1 else os.path.join(base, gdir, track or "علمي")
    if os.path.isdir(scoped):
        return scoped
    return base if _is_legacy_scope(grade, track) else scoped

def load_json_safe(path: str):
    if not os.path.isfile(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def find_unit(book_data: List[dict], query: str):
    """البحث عن الوحدة بالاسم أو بالرقم (مطابقة جزئية)"""
    q = query.strip()
    for unit in book_data:
        if q == unit.get("اسم_الوحدة") or q == str(unit.get("رقم_الوحدة")):
            return unit
    # محاولة مطابقة جزئية
    for unit in book_data:
        if q in unit.get("اسم_الوحدة", ""):
            return unit
    return None

def fetch_pages_by_numbers(book_data: List[dict], page_nums: List[int]):
    found = []
    missing = []
    for p in page_nums:
        found_flag = False
        for unit in book_data:
            for page in unit.get("الصفحات", []):
                if page.get("رقم_الصفحة") == p:
                    found.append(page)
                    found_flag = True
                    break
            if found_flag:
                break
        if not found_flag:
            missing.append(p)
    return found, missing




# 🗑️ **حُذفت `extract_relevant_book_texts`** (2026-09-14): لا مستدعيَ لها
#    في المشروع كلِّه، **وكانت مكسورة** — تنادي `faiss_search` وهي
#    `async` بلا `await`، فأولُ من يستعملها يقع على كوروتين لا نتيجة.
#    وهي نسخةٌ خامسة من دمج «المباشر أولاً» الذي أصلحناه، فبقاؤها دعوةٌ
#    لعودة العطل من بابٍ خلفيّ.

def extract_all_texts_and_metas(book_data: List[dict], subject=None):
    texts = []
    metas = []
    for unit in book_data:
        for page in unit.get("الصفحات", []):
            # 🧮 الكسور تُرمَّز قبل أن يراها الموديل — فنقلُه الحرفيّ ينقلها مرسومة
            texts.append(prepare_source(page.get("نص_الصفحة", ""), subject))
            metas.append({
                "unit": unit.get("اسم_الوحدة"),
                "page": page.get("رقم_الصفحة")
            })
    return texts, metas

import threading

from core import index_store
from core.fractions import to_frac
from core.chem import for_subject as _chem_for_subject


def prepare_source(text: str, subject: str = "") -> str:
    """**نصُّ الكتاب قبل أن يراه الموديل** — كسورُه وصيغُه مرمَّزة.

    ⚖️ الترميز يسبق الموديل لا يتبعه: البرومبت يأمره أن ينقل حرفياً، فإن
       وصله «س / ص» سطراً مسطّحاً نقله كما هو بأمانة — ورأى الطالبُ سطراً
       لا كسراً. فنُصلح المصدر، ويصير النقلُ الحرفيّ نقلاً للرسم.

    🔴 **وكانت منسوخةً في أربعة مواضع وغائبةً عن الخامس**: أسئلةُ الوزاري
       تُقرأ من ملفّاتها وتُعرض **كما هي بلا أي تحويل** — فمعادلاتُ
       الكيمياء وكسورُ الرياضيات في الامتحانات الوزارية كانت تصل الطالبَ
       نصّاً خاماً بينما يراها مرسومةً في الشرح. (شكوى المالك 2026-09-13.)
    """
    return _chem_for_subject(to_frac(text or ""), subject)

_build_semaphore = None

def get_build_semaphore():
    global _build_semaphore
    if _build_semaphore is None:
        _build_semaphore = asyncio.Semaphore(2)
    return _build_semaphore


def _normalize_for_search(text: str) -> str:
    """توحيد النص للبحث فقط — عربيّه ولاتينيّه.

    🔡 **والحروفُ اللاتينية تُخفَّض** (2026-09-14): الطرفان يمرّان بهذه
       الدالّة، فتخفيضُهما معاً يجعل المطابقة غيرَ حسّاسةٍ لحالة الحرف —
       و«Explain» كانت تنجو من قائمة الإيقاف بحرفٍ كبيرٍ واحد.
    """
    if not text:
        return text
    text = text.lower()
    text = re.sub(r'[أإآٱ]', 'ا', text)        # توحيد الألفات
    text = re.sub(r'ة', 'ه', text)              # ة → ه
    text = re.sub(r'ى', 'ي', text)              # ى → ي
    text = re.sub(r'[\u064B-\u065F]', '', text) # إزالة التشكيل
    return text


# ══════════════════════════════════════════════════
# ✂️ التقطيع — **لأن الموديل لا يقرأ الصفحة كاملةً أصلاً**
# ══════════════════════════════════════════════════
#
# 🔴 **أخطرُ ما قِيس في هذا الملف (2026-09-14):**
#    `paraphrase-multilingual-MiniLM-L12-v2` نافذتُه **١٢٨ رمزاً**، وصفحةُ
#    كتابٍ عربيٍّ وسطها **٤٥٤ رمزاً**. فـ**٩٨٫٥٪ من صفحات المناهج كانت
#    تتجاوز النافذة، ولا يُدخَل منها الموديلَ إلا ٣١٫٦٪ في المتوسط** —
#    والباقي يُقصّ بصمتٍ تام. أي أن ثلثي كل كتابٍ لم يكن مفهرساً دلالياً
#    قطّ، ولا يعثر عليه إلا المطابقةُ اللفظية بالصدفة.
#
#    (وهذا هو السببُ الحقيقي وراء ما لاحظه المالك: «الصفحة قد تغطّي
#     موضوعين فيُخفَّف متجهُها» — والواقع أقسى: الموضوع الثاني لم يكن
#     يدخل المتجه من أصله.)
#
# ⚖️ **والتقطيع للبحث وحده — ويُسلَّم للموديل صفحاتٌ كاملة.** المقطعُ
#    يكفي ليُعثر عليه ولا يكفي ليُشرح منه: جملتان مبتورتان عن سياقهما
#    جوابٌ أسوأ من صفحةٍ كاملة. فالبحثُ على المقاطع، ودرجةُ الصفحة أعلى
#    درجاتِ مقاطعها، والمُعاد **فهارسُ صفحاتٍ كما كان** — فلا يتغيّر شيءٌ
#    في المعالجات الستة عشر ولا في المراجع التي يراها الطالب.

_CHUNK_TOKENS = 110          # دون ١٢٨ بهامشٍ للرموز الخاصة وتفاوت التقطيع
_CHUNK_OVERLAP_TOKENS = 30   # تداخلٌ كي لا تُقطع فكرةٌ بين مقطعين

# نهاياتُ الجمل العربية — والسطرُ الجديد فاصلٌ في كتبٍ مليئةٍ بالقوائم.
_SENTENCE_SPLIT = re.compile(r'(?<=[.؟!:…؛])\s+|\n+')


def _token_len(text: str) -> int:
    """طولُ النصّ بمقياس الموديل نفسِه لا بالحروف — الحرفُ العربي رمزٌ ونصف."""
    return len(embed_model.tokenizer.encode(text, add_special_tokens=False,
                                            verbose=False))


def split_for_embedding(text: str) -> List[str]:
    """يقطّع نصّاً إلى مقاطع تدخل نافذة الموديل كاملةً، بتداخلٍ بينها."""
    text = (text or "").strip()
    if not text:
        return []
    if _token_len(text) <= _CHUNK_TOKENS:
        return [text]

    pieces: List[str] = []
    for part in _SENTENCE_SPLIT.split(text):
        part = part.strip()
        if not part:
            continue
        # ⚠️ جملةٌ واحدة أطولُ من النافذة (جدولٌ أو فقرةٌ بلا وقف) ⇒ تُشقّ
        #    بالكلمات، وإلا خرج مقطعٌ يُقصّ بصمتٍ كما كانت تُقصّ الصفحة.
        if _token_len(part) <= _CHUNK_TOKENS:
            pieces.append(part)
            continue
        words, buf = part.split(), []
        for w in words:
            buf.append(w)
            if _token_len(" ".join(buf)) >= _CHUNK_TOKENS:
                pieces.append(" ".join(buf[:-1]) or w)
                buf = [w]
        if buf:
            pieces.append(" ".join(buf))

    chunks: List[str] = []
    buf: List[str] = []
    for piece in pieces:
        candidate = buf + [piece]
        if buf and _token_len(" ".join(candidate)) > _CHUNK_TOKENS:
            chunks.append(" ".join(buf))
            # التداخل: نُبقي من ذيل المقطع ما يسع ميزانية التداخل
            tail, size = [], 0
            for prev in reversed(buf):
                size += _token_len(prev)
                if size > _CHUNK_OVERLAP_TOKENS:
                    break
                tail.insert(0, prev)
            buf = tail + [piece]
        else:
            buf = candidate
    if buf:
        chunks.append(" ".join(buf))
    return [c for c in chunks if c.strip()]


# أقصى طولٍ لعنوانٍ يُفهرس وحده — أطولُ من ذلك ليس عنواناً بل فقرة.
_TITLE_TOKENS = 28


def page_title(text: str) -> str:
    """عنوانُ الصفحة — أولُ سطرٍ قصيرٍ فيها، أو "" إن لم يكن لها عنوان."""
    for line in (text or "").split("\n"):
        line = line.strip()
        if not line:
            continue
        if len(line.split()) < 2:
            continue                       # كلمةٌ واحدة ليست عنواناً
        return line if _token_len(line) <= _TITLE_TOKENS else ""
    return ""


def embedding_corpus(texts: List[str]):
    """`(مقاطع, صاحبُ كلِّ مقطع)` — مصدرٌ واحد للبحث وللإحماء معاً.

    ⚠️ **والإحماءُ يجب أن يستعمل هذه بعينها**: بصمةُ الفهرس تُحسب من
       النصوص، فلو أحمى الخادمُ فهرسَ الصفحات وبحث في فهرس المقاطع لبنى
       كلُّ سؤالٍ أولَ فهرسِه أثناء انتظار الطالب.
    """
    chunks: List[str] = []
    owners: List[int] = []
    for i, text in enumerate(texts):
        parts = split_for_embedding(text)
        if not parts:                       # صفحةٌ فارغة تبقى لها نائبةٌ
            parts = [text or ""]

        # 🏷️ **عنوانُ الصفحة مقطعٌ مستقلّ** — وهذه أهمُّ علّةٍ قِيست هنا.
        #
        # 🔴 المتوسّطُ الحسابي للمتجهات يغسل العنوانَ في بحر الجسد. قِيس
        #    على مثال المالك حرفياً — سؤال «إيش يخرج من الفص الأمامي؟»:
        #      «جدول (٣) هرمونات الفص الأمامي للغدة النخامية» وحده ⇒ ٠٫٢٤٠
        #      + أوّلُ صفٍّ واحدٍ من الجدول            ⇒ ٠٫٠٣٥ (!)
        #      وسطرٌ عن الفص **الخلفي**                ⇒ ٠٫١٦٦
        #    فصفحةُ الجدول الصحيحة تسقط تحت صفحةٍ عن الفص المعاكس.
        #
        # ⚖️ والعلاجُ متجهٌ واحدٌ إضافيٌّ لكل صفحة: مرساةٌ نظيفةٌ لا يُذيبها
        #    طولُ الجسد. والصفحةُ تأخذ **أعلى** درجات مقاطعها، فوجودُ
        #    المرساة لا يخفض شيئاً ولا يزاحم أحداً.
        title = page_title(text)
        if title and title not in parts:
            chunks.append(title)
            owners.append(i)

        for part in parts:
            chunks.append(part)
            owners.append(i)
    return chunks, owners


def build_index_sync(texts: List[str]):
    """بناء فهرس FAISS من نصوص — متزامن كي يُستدعى من الإحماء ومن الخيط معاً."""
    index_store.mark_build()
    emb = embed_model.encode(texts, convert_to_numpy=True, batch_size=32, show_progress_bar=False)
    faiss.normalize_L2(emb)
    index = faiss.IndexFlatIP(emb.shape[1])
    index.add(emb)
    return index


async def get_index(texts: List[str], meta: Optional[dict] = None):
    """الفهرس من ثلاث طبقات: ذاكرة → قرص → بناء (راجع core/index_store.py).

    ⚖️ **مفصولةٌ عن البحث** كي يتقاسمها `faiss_search` و`faiss_scores`:
       نسخُ هذه الطبقات الثلاث مرّتين كان يعني فهرسين للنصّ نفسه، وبناءً
       ثانياً أثناء طلب طالب. والإحماءُ عند الإقلاع يجعلها لا تبني شيئاً.
    """
    fp = index_store.fingerprint(texts)
    index = index_store.get_mem(fp)
    if index is not None:
        return index
    index = index_store.load_disk(fp)
    if index is not None:
        index_store.put_mem(fp, index)
        return index
    async with get_build_semaphore():
        index = index_store.get_mem(fp)          # فحص ثانٍ بعد الانتظار
        if index is None:
            index = await asyncio.wait_for(
                asyncio.to_thread(build_index_sync, texts), timeout=90.0)
            index_store.put_mem(fp, index)
            index_store.save_disk(fp, index, meta)
    return index


async def faiss_search(texts: List[str], query: str, top_k: int = QA_TOP_K, meta: Optional[dict] = None):
    """بحث دلالي. `meta` وصف اختياري (مادة/صف/وحدة) يُسجَّل في سجلّ الفهارس."""
    if not texts:
        return [], []

    try:
        index = await get_index(texts, meta)

        def _search_only():
            q_emb = embed_model.encode(
                [query],
                convert_to_numpy=True,
                show_progress_bar=False
            )
            faiss.normalize_L2(q_emb)
            D, I = index.search(q_emb, k=min(top_k, index.ntotal))
            return I[0]

        # (`_search_only` يعيد الفهارس وحدها — و`faiss_scores` أدناه تعيد
        #  الدرجات كذلك، لأن الترتيب الهجين يحتاج قيمةً لا رتبة.)

        I_indices = await asyncio.wait_for(
            asyncio.to_thread(_search_only),
            timeout=15.0
        )

        results = []
        idxs = []
        for i in I_indices:
            if 0 <= i < len(texts):
                results.append(texts[i])
                idxs.append(int(i))
        return results, idxs

    except asyncio.TimeoutError:
        print("⚠️ FAISS timeout")
        return [], []
    except Exception as e:
        print(f"⚠️ FAISS error: {e}")
        return [], []


# ══════════════════════════════════════════════════
# 🔎 الترتيب الهجين — الدلاليّ مع المطابقة اللفظية، **بالوزن لا بالأسبقية**
# ══════════════════════════════════════════════════
#
# 🔴 **العطل الذي قيسَ (2026-09-14):** كان الدمجُ يضع «المطابقة المباشرة
#    أولاً» ثم يقصّ عند `top_k`. والمطابقةُ تقبل الصفحة إن حوت **أي** كلمةٍ
#    من ثلاثة أحرف فأكثر، وتمرّ على الصفحات **بترتيب الكتاب**. فسؤال
#    «ما الفرق بين الغدة النخامية والغدة الدرقية» كلماتُه تشمل «بين» —
#    وهي في ٩ صفحاتٍ من ١٩ — فتملأ أولُ ثلاثِ صفحاتٍ فيها «بين» المقاعدَ
#    الثلاثة كلَّها، **ويُطرد الدلاليُّ بالكامل**.
#
#    القياسُ الحيّ: الدلاليُّ أراد الصفحات (٤٦ · ٥٠ · ٥٥)، ووصل الموديلَ
#    (٤١ · ٤٣ · ٤٥) — وفيها صفحتان عن **الهرمونات النباتية** (الإيثيلين
#    والجبريلينات) في سؤالٍ عن الغدة النخامية. لا الموديلُ أخطأ ولا
#    البحثُ الدلاليّ: الدمجُ هو من أفسدهما.
#
# ⚖️ **والعلاج ليس حذف المطابقة اللفظية** — هي التي تُنقذ المصطلحات التي
#    تضعف فيها المتجهات العربية. العلاجُ أن تصير **وزناً يُضاف** لا
#    أسبقيةً تطرد، وأن تُسقَط كلماتُ الربط والسؤال قبل الوزن.

# 🔗 **أدواتُ الإحالة** — وجودُها يعني أن السؤال يتّكئ على ما قبله.
#    «ما الفرق **بينها** وبين الدرقية» موضوعُها الأولُ في الرسالة السابقة
#    لا في هذه، فإن لم نستعره بحثنا عن «بينها» — وهي لا شيء.
_ANAPHORA = {
    "بينها", "بينهما", "بينهم", "عنها", "عنه", "منها", "منه", "فيها",
    "فيه", "عليها", "عليه", "لها", "له", "هذه", "هذا", "ذلك", "تلك",
    "نفسه", "نفسها", "السابق", "السابقة", "الاول", "الأول", "اياها",
    "اكثر", "أكثر", "ايضا", "أيضاً", "كمل", "كملي", "تكملة", "المزيد",
}

# كلماتُ السؤال والربط — لا تدلّ على موضوع، فلا تُرجّح صفحةً على أخرى.
_QUERY_STOPWORDS = {
    "اشرح", "وضح", "وضّح", "بين", "بيّن", "الفرق", "قارن", "المقارنة",
    "مقارنة", "عرف", "عرّف", "اذكر", "احسب", "علل", "علّل", "لماذا",
    # 📝 **أفعالُ الطلب الباقية** — علّةٌ قِيست (2026-09-14): «اكتب قانون
    #    المقاومة الحثية» أعطت **«اكتب» أعلى وزنٍ في السؤال كلِّه** (٥٫٣٥)
    #    لأنها نادرةٌ في الكتاب، فتقدّمت صفحاتٌ فيها «اكتب» على صفحة
    #    «المفاعلة الحثية للملف» التي فيها القانونُ نفسُه.
    "اكتب", "اكتبي", "هات", "أعد", "اعد", "عدد", "عدّد", "صف", "صِف",
    "استنتج", "استنبط", "برهن", "اثبت", "أثبت", "ارسم", "حدد", "حدّد",
    "سم", "سمّ", "ناقش", "فسر", "فسّر", "رتب", "رتّب", "صنف", "صنّف",
    "املأ", "اكمل", "أكمل", "اختر", "ضع", "احسبي", "بالكسور", "بالأرقام",
    "بالنقاط", "بالجدول", "بجدول", "جدول", "بمثال", "بأمثلة",
    "كيف", "ماذا", "متى", "اين", "أين", "هذا", "هذه", "ذلك", "التي",
    "الذي", "الذين", "مع", "عند", "على", "الى", "إلى", "عن", "في",
    "من", "ما", "هو", "هي", "كل", "بعض", "بين", "وبين", "اريد", "أريد",
    "اعطني", "أعطني", "لي", "لك", "هل", "ايه", "إيه", "شرح", "تلخيص",
    "ملخص", "سؤال", "جواب", "الاجابة", "الإجابة", "نص", "درس", "الدرس",
    # 🔴 رُصدت في قياسٍ حيّ (2026-09-14): «ممكن توضح لي أكثر؟» كانت
    #    كلماتُ موضوعها «ممكن · توضح · اكثر» — ضجيجٌ خالص يعيد صفحاتٍ
    #    عشوائية. وكذلك «ليش؟» و«أعطني مثالاً».
    "ممكن", "توضح", "اكثر", "أكثر", "ليش", "مثالا", "مثالاً", "مثال",
    # 🗣️ أدواتُ الاستفهام العامّية — «إيش يخرج من الفص الأمامي؟» كانت
    #    «ايش» فيها كلمةَ موضوعٍ غائبةً عن الكتاب، فتدخل مقامَ المطابقة
    #    وتخفض درجةَ الصفحة الصحيحة إلى النصف. (قِيس 2026-09-14.)
    "ايش", "إيش", "وش", "شو", "شنو", "وين", "كيفاش", "علاش", "ليه",
    # وأفعالُ الخروج/الوجود — الموضوعُ اسمٌ لا فعل، والكتابُ يقول «يفرز»
    #    حيث يقول الطالب «يخرج» أو «يطلع».
    "يخرج", "تخرج", "يطلع", "تطلع", "يعطي", "تعطي", "ينتج", "تنتج",
    "يوجد", "توجد", "يصدر", "تصدر", "يفعل", "تفعل", "يسوي", "تسوي",
    "اعطني", "أعطني", "اعطيني", "أعطيني", "ابغى", "أبغى", "بدي",
    "افهم", "أفهم", "فهمت", "طيب", "وبين", "بينها", "بينهما", "عنها",
    "منها", "فيها", "عليها", "نفسه", "نفسها", "المزيد", "تكملة",
    "زيادة", "بالتفصيل", "تفصيل", "بسط", "بسّط", "اختصر", "لخص",
    # 🇬🇧 وكلماتُ السؤال الإنجليزية — مادةُ الإنجليزي تمرّ بنفس الدالّة،
    #    والطالبُ قد يكتب بالإنجليزية في أي مادة.
    "what", "why", "how", "when", "where", "which", "who", "explain",
    "define", "describe", "tell", "give", "show", "more", "about",
    "please", "the", "and", "for", "with", "this", "that", "these",
    "those", "them", "their", "answer", "question", "lesson", "book",
    # 🔢 **الأعدادُ الترتيبية ليست موضوعاً قطّ** — وهي علّةٌ قِيست على مثال
    #    المالك نفسِه: «ما هو قانون نيوتن الثاني؟» في وحدة التنظيم الهرموني
    #    كانت تُقيَّم ٠٫٧٠٦ — فوق كل عتبة! لأن «قانون» و«نيوتن» غائبتان عن
    #    الوحدة فتُسقطان، وتبقى «الثاني» وحدها (في «الرسول الثاني») فتنال
    #    مطابقةً لفظيةً كاملة. راجع [tests/test_relevance_floor.py].
    "الاول", "الأول", "الاولى", "الأولى", "الثاني", "الثانية", "الثانيه",
    "الثالث", "الثالثة", "الثالثه", "الرابع", "الرابعة", "الرابعه",
    "الخامس", "الخامسة", "الخامسه", "السادس", "السادسة", "السادسه",
    "اولا", "أولاً", "ثانيا", "ثانياً", "ثالثا", "ثالثاً", "رابعا", "رابعاً",
    "الوحدة", "الوحده", "الفصل", "الباب", "الجزء", "الصفحة", "الصفحه",
    "first", "second", "third", "fourth", "unit", "chapter", "page",
    # 🗣️ **ألفاظٌ تشير إلى الردّ السابق لا إلى المنهج** — «لخّص لي الكلام»
    #    كانت كلمةُ موضوعها «الكلام»، فيُبحث عنها في كتاب الأحياء ويُرفض
    #    السؤال. (شكوى المالك 2026-09-14.)
    # ⚠️ **ولا نُسقط ما قد يكون موضوعاً في مادةٍ ما**: «النص» موضوعٌ في
    #    العربية (النص الأدبي)، و«الكلام» في الفلسفة (علم الكلام)، و«صغير»
    #    في الأحياء (الدماغ الصغير). فتبقى كلماتِ موضوع، وجملُ الأسلوب
    #    تُنزع بـ[_STYLE_CLAUSE] عند الحكم على المتابعة لا بإسقاط الكلمة.
    "الجواب", "الرد", "الشرح", "الاجابه", "الإجابة", "الكلمه",
    "مثال", "مثالا", "امثله", "أمثلة", "امثلة", "امثال",
    # 🎨 وألفاظُ **الأسلوب** — طريقةُ العرض لا مادتُه
    "بطريقه", "بطريقة", "باسلوب", "بأسلوب", "بصيغه", "بصيغة", "بلغه",
    "بلغة", "اسهل", "أسهل", "ابسط", "أبسط", "اقصر", "أقصر", "اطول",
    "أطول", "مبسطه", "مبسطة", "سهله", "سهلة", "بسيطه", "بسيطة",
    "كانك", "كأنك", "مثلما", "زي", "وكانك", "وكأنك", "تشرح", "شارح",
    "للمبتدئين",
    # 🗣️ **تعليمُ لغةِ الردّ** — «بالعربي» ظرفٌ لا موضوع. (والموضوع في
    #    مادة العربية يُكتب «اللغة العربية» لا «بالعربية».)
    "بالعربي", "بالعربيه", "بالعربية", "بالانجليزي", "بالانجليزيه",
    "بالانجليزية", "بالفصحى", "بالعاميه", "بالعامية", "عربي", "انجليزي",
    # 🇬🇧 ونظائرُها بالإنجليزية — الطالب يكتب بها في مادة الإنجليزي وفي
    #    غيرها. («Give me an example» رُفضت في المحاكي 2026-09-14.)
    "example", "examples", "instance", "simpler", "easier", "shorter",
    "again", "simply", "briefly", "pretend", "beginner", "beginners",
    # وضمائرُ الإنجليزية وأفعالُها المساعدة — «Simplify **it**» كانت
    #    كلمةُ موضوعها «it» فتُعدّ سؤالاً جديداً.
    "it", "its", "you", "your", "me", "my", "mine", "we", "our", "us",
    "can", "could", "would", "will", "shall", "may", "am", "are", "is",
    "was", "were", "be", "been", "do", "does", "did", "have", "has",
    "had", "again", "some", "any", "one", "ones", "thing", "things",
}

# كلمةٌ حاضرةٌ في أكثر من هذه النسبة من الصفحات = كلمةُ سياقٍ لا موضوع.
_COMMON_TERM_RATIO = 0.40

# وزنُ المطابقة اللفظية مقابل الدلالية. تشابهُ الجيب في [0,1]، فنصفٌ
# يكفي لأن يرفع صفحةً فيها المصطلحُ نصّاً فوق صفحةٍ قريبةٍ دلالياً فقط.
_KEYWORD_WEIGHT = 0.5


# 🔴 **الترقيمُ العربيّ داخل نطاق الحروف** — وهذه علّةٌ صامتة كلّفت
#    نصفَ المطابقة اللفظية: النطاق `؀-ۿ` يشمل «؟» (U+061F) و«،» و«؛»،
#    فكلمةُ «النخامية؟» تُستخرج بعلامتها فلا تطابق «النخامية» في الصفحة.
#    وأكثرُ أسئلة الطلاب تنتهي بعلامة استفهام. (قيسَ حيّاً 2026-09-14.)
_TERM_TRIM = "؟?!.،,؛;:\"'«»()[]{}…-–—"


# 🔗 **واوُ العطف تكسر المطابقة** — علّةٌ قِيست (2026-09-14): سؤال «اكتب
#    قانون المقاومة الحثية **والسعوية**» لم يطابق صفحةً فيها «السعوية»،
#    لأن «والسعويه» ليست جزءاً من «السعويه». وهي صيغةٌ يوميّة في أسئلة
#    الطلاب («الأسباب والنتائج» · «التركيب والوظيفة»).
#
# ⚖️ والتقشيرُ **مقصورٌ على ما تبعته «ال»**: «والسعوية» ⇐ «السعوية» بلا
#    لبس، بينما تقشيرُ كل واوٍ كان سيحوّل «وراثة» إلى «راثة».
_PREFIX_AL = re.compile(r'^[وفبك]+(?=ال)')


def query_terms(query: str) -> List[str]:
    """كلماتُ الموضوع في السؤال — بلا ترقيمٍ ولا ربطٍ ولا أدوات استفهام."""
    norm = _normalize_for_search(query or "")
    out, seen = [], set()
    for raw in re.findall(r'[؀-ۿ\w]+', norm):
        w = raw.strip(_TERM_TRIM)
        w = _PREFIX_AL.sub("", w) or w
        if len(w) < 3 or w in seen or w in _STOP_NORMALIZED:
            continue
        seen.add(w)
        out.append(w)
    return out


def has_anaphora(query: str) -> bool:
    """هل يتّكئ السؤالُ على ما قبله؟ («بينها» · «وضّح أكثر» · «ليش»)"""
    norm = _normalize_for_search(query or "")
    words = {w.strip(_TERM_TRIM) for w in re.findall(r'[؀-ۿ\w]+', norm)}
    return bool(words & _ANAPHORA_NORMALIZED)


_STOP_NORMALIZED = {_normalize_for_search(w) for w in _QUERY_STOPWORDS}
_ANAPHORA_NORMALIZED = {_normalize_for_search(w) for w in _ANAPHORA}


# ══════════════════════════════════════════════════
# 🧵 سؤالُ المتابعة — يستعير موضوعَه ممّا قبله
# ══════════════════════════════════════════════════
#
# 🔴 **ما قيسَ (2026-09-14):** الطالب يسأل «عرّف الغدة النخامية» فتصله
#    الصفحات (٥١ · ٥٠ · ٤٦ · ٥٣) — صحيحة. ثم يقول «ممكن توضح لي أكثر؟»
#    فيصله (٥٩ · ٤٧ · ٥١ · ٥٨) — **عشوائية**، لأن نصَّ البحث صار
#    «ممكن توضح لي أكثر» ولا موضوع فيه. ويقول «ما الفرق بينها وبين
#    الغدة الدرقية» فتضيع صفحةُ النخامية كلَّها لأن موضوعَها الأول
#    ضميرٌ («بينها») لا اسم.
#
# ⚖️ **ولا نستعير دائماً**: «ما الأنسولين؟» سؤالٌ جديد بموضوعٍ واضح،
#    فإلحاقُ «النخامية» به يسحب صفحاتٍ لا يريدها. فالاستعارةُ مشروطة:
#    إمّا أداةُ إحالةٍ صريحة، أو سؤالٌ **بلا أي كلمة موضوع**.


# ══════════════════════════════════════════════════
# 🗣️ طلبُ المتابعة — **تعليمٌ على الجواب السابق لا سؤالٌ جديد**
# ══════════════════════════════════════════════════
#
# 🔴 **شكوى المالك (2026-09-14):** «قلت له أعطيني مثال — ما أعطاني، قال
#    مش موجود في وحدة التنظيم الهرموني. وقلت له اشرح لي كأنك تشرح
#    للحمار — ما أعطاني شي.»
#
#    وقِيس، فإذا خمسةٌ من تسع صيغِ متابعةٍ عادية **تُرفض**:
#      «اشرح لي كأنك تشرح للحمار» ٠٫٣٥٨ · «كأنك تشرح لطفل صغير» ٠٫٤٨٧ ·
#      «بسّطها لي» ٠٫٢٥٣ · «لخّص لي الكلام» ٠٫٢٧٦ · «أعد الشرح بطريقة
#      أسهل» ٠٫٣٣٣ — كلُّها تحت الأرضية.
#
# ⚖️ **والعلّة في المفهوم لا في الرقم:** عتبةُ الصلة تسأل «هل موضوعُ هذا
#    السؤال في الوحدة؟» — وطلبُ المتابعة **لا موضوعَ له أصلاً**. موضوعُه
#    هو الجوابُ السابق، وذاك قد اجتاز العتبة حين طُلب. فالحكمُ عليه بألفاظه
#    خطأُ تصنيف: «للحمار» و«لطفل» و«الكلام» صارت كلماتِ موضوعٍ تُبحث في
#    كتاب الأحياء.
#
# ⭐ فالمتابعةُ: ① تستعير موضوعَ المحادثة، و② **لا تُرفض** ما دام في
#    المحادثة جوابٌ سابق تُبنى عليه.

# أفعالُ المتابعة — تُقبل بضمير متّصل: «بسّطها» · «اشرحه» · «لخّصها لي».
_CONTINUATION_VERBS = {
    "بسط", "لخص", "اشرح", "وضح", "كرر", "اعد", "فسر", "كمل", "تابع",
    "اختصر", "فصل", "سهل", "رتب", "اذكر", "مثل", "قارن", "حلل",
    # 🇬🇧 والإنجليزية معها — ولا ضميرَ متّصلاً فيها، فتُقبل كما هي.
    "explain", "simplify", "summarize", "summarise", "shorten", "repeat",
    "clarify", "elaborate", "rephrase", "expand", "continue",
}
_PRONOUN_TAILS = ("هما", "هم", "هن", "ها", "يها", "يه", "ه", "لي", "لنا", "ني")

# جملُ الأسلوب — تُنزع قبل الحكم كي لا تُحسب كلماتِ موضوع.
_STYLE_CLAUSE = re.compile(
    # ⚠️ **كلُّ نمطٍ يقف عند علامة الوقف** — أولُ صيغةٍ كانت تبتلع ما بعد
    #    النقطة: «like i am a donkey. in arabic» ابتلعت «in» وتركت
    #    «arabic» وحدها، فصارت كلمةَ موضوعٍ ورُفض الطلب (قِيس في المحاكي).
    r"(?:و?ك(?:أ|ا)نك|مثلما|زي\s*ما)\s+[^.؟!،؛\n]{0,40}"      # «كأنك تشرح لطفل صغير»
    r"|ب(?:طريقة|طريقه|أسلوب|اسلوب|صيغة|صيغه|لغة|لغه)\s+[^.؟!،؛\n]{0,20}"
    r"|للمبتدئين|لطفل\s*\S*|لولد\s*\S*|لطالب\s*\S*"
    # «لخّص لي الكلام» — «الكلام» هنا الجوابُ السابق، وتبقى في غير هذا
    # السياق كلمةَ موضوعٍ («علم الكلام» في الفلسفة).
    r"|(?<=لي)\s+الكلام|(?<=لخص)\s+الكلام|(?<=اختصر)\s+الكلام"
    # 🇬🇧 تعليماتُ اللغة والأسلوب بالإنجليزية — «Answer in Arabic» ليست
    #    سؤالاً عن اللغة العربية، و«like I am five» ليست عن الأطفال.
    r"|in\s+(?:simple\s+|plain\s+)?(?:arabic|english|words|terms|language)"
    r"|like\s+(?:i\s*a?m|i'?m|a|an)\s+[^.؟!،؛\n]{0,30}"
    r"|for\s+(?:a\s+)?(?:kid|child|beginner|dummy|five[- ]year[- ]old)s?"
)


def _is_continuation_word(word: str) -> bool:
    """هل الكلمة فعلُ متابعةٍ — وحدَه أو بضميرٍ متّصل؟"""
    if word in _CONTINUATION_VERBS:
        return True
    for tail in _PRONOUN_TAILS:
        if word.endswith(tail) and word[: -len(tail)] in _CONTINUATION_VERBS:
            return True
    return False


def is_followup(text: str) -> bool:
    """هل هذه رسالةُ متابعةٍ على الجواب السابق لا سؤالٌ قائمٌ بذاته؟"""
    norm = _normalize_for_search(text or "")
    norm = _STYLE_CLAUSE.sub(" ", norm)
    words = [w.strip(_TERM_TRIM) for w in re.findall(r'[؀-ۿ\w]+', norm)]
    words = [w for w in words if w]
    if not words:
        return True
    if any(w in _ANAPHORA_NORMALIZED or _is_continuation_word(w) for w in words):
        # 🎯 وفعلُ المتابعة وحده لا يكفي: «اشرح الغدة النخامية» فعلُه
        #    «اشرح» وموضوعُه واضح. المتابعةُ هي التي **لا موضوع لها**.
        rest = [w for w in words if len(w) >= 3
                and w not in _STOP_NORMALIZED and not _is_continuation_word(w)]
        return not rest
    # ولا أداةَ إحالةٍ ولا فعلَ متابعة: متابعةٌ فقط إن خلَت من أي موضوع
    return not [w for w in words if len(w) >= 3 and w not in _STOP_NORMALIZED]


def conversation_topic(chat_history, limit: int = 6) -> List[str]:
    """موضوعُ المحادثة — من أحدث رسالةِ طالبٍ تحمل كلماتِ موضوع.

    ونمشي إلى الوراء: سلسلةُ «عرّف النخامية» ← «وضّح أكثر» ← «ليش؟»
    موضوعُها في أولها، فالرسالةُ السابقة مباشرةً قد تكون هي أيضاً بلا موضوع.
    """
    for message in reversed(list(chat_history or [])[-limit:]):
        if not isinstance(message, dict) or message.get("role") != "user":
            continue
        terms = query_terms(message.get("content") or message.get("text") or "")
        if terms:
            return terms
    return []


def contextual_search_text(text: str, chat_history) -> str:
    """نصُّ البحث بعد استعارة الموضوع عند الحاجة."""
    text = (text or "").strip()
    terms = query_terms(text)
    # ⚖️ **شرطان لا واحد**: طلبُ متابعةٍ بلا موضوع («بسّطها لي»)، **أو**
    #    سؤالٌ له موضوعٌ لكنّ طرفَه الأول ضمير («ما الفرق **بينها** وبين
    #    الدرقية» — تضيع النخامية كلُّها لولا الاستعارة).
    if not (is_followup(text) or has_anaphora(text)):
        return text                       # سؤالٌ قائمٌ بذاته — لا نلمسه
    borrowed = [t for t in conversation_topic(chat_history) if t not in terms]
    return f"{text} {' '.join(borrowed)}".strip() if borrowed else text


def search_text_of(req) -> str:
    """نصُّ بحثِ الطلب — مصدرٌ واحد لكل المعالجات."""
    return contextual_search_text(getattr(req, "search_query", "") or "",
                                  getattr(req, "chat_history", None))


def term_weights(terms: List[str], norm_texts: List[str]) -> dict:
    """وزنُ كل كلمة = ندرتها (idf). والشائعةُ جداً تُسقَط رأساً."""
    n = len(norm_texts) or 1
    weights = {}
    for term in terms:
        df = sum(1 for t in norm_texts if term in t)
        if df == 0 or df > n * _COMMON_TERM_RATIO:
            continue
        weights[term] = math.log(1 + n / df)
    return weights


def lexical_denominator(terms: List[str], norm_texts: List[str],
                        weights: dict) -> float:
    """المقامُ الذي تُقاس عليه المطابقة — **ومعه الكلماتُ الغائبة تماماً**.

    🔴 **علّةٌ صامتة قِيست (2026-09-14):** الكلمةُ التي لا تظهر في أي صفحة
       كانت تُحذف من الحساب رأساً، فيصير مقامُ «قانون نيوتن الثاني» كلمةً
       واحدةً هي «الثاني» — ومطابقتُها كاملة. أي أن **غيابَ موضوع السؤال
       عن الكتاب كان يرفع درجتَه** بدل أن يخفضها.

    ⚖️ والغائبةُ تدخل المقام بوزنِ **كلمةٍ موضوعيةٍ وسطى** لا بأقصى وزن:
       سؤالٌ سليم قد يستعمل مرادفاً لا يذكره الكتاب، فلا نهدم درجتَه.
       والكلمةُ المُسقطة لشيوعها (أكثر من ٤٠٪ من الصفحات) ليست غائبة —
       هي ليست موضوعاً أصلاً، فلا تدخل المقام من الطرفين.
    """
    total = sum(weights.values())
    if total <= 0:
        return 0.0
    missing = sum(1 for t in terms
                  if t not in weights
                  and not any(t in x for x in norm_texts))
    return total + missing * (total / len(weights))


# ══════════════════════════════════════════════════
# 🔗 الصفحةُ المبتورة تجرّ جارتها
# ══════════════════════════════════════════════════
#
# 🔴 **ما رآه المالك (2026-09-14):** «لو الصفحة الرابعة فيها تكملة
#    للصفحة الخامسة، والخامسة مش موجودة — هل يبحث في الاثنين؟»
#
#    وكان محقّاً، والقياسُ حرفيّ: ص٥١ من درس الغدة النخامية تنتهي عند
#    «...هرمون الفازوبرسين الذي ينظم التوازن المائي للجسم» — بلا نقطة —
#    وص٥٢ تبدأ «عن طريق إعادة امتصاص الماء بواسطة الأنابيب الكلوية».
#    **جملةٌ واحدة مقصوصةٌ بين صفحتين.** فمن أخذ ٥١ وحدها شرح للطالب
#    نصفَ وظيفة الهرمون.
#
# ⚖️ **ولا نضمّ الجارةَ دائماً** — ذلك يضاعف السياق بلا سبب. نضمّها حين
#    تدلّ العلامةُ على البتر: صفحةٌ لا تنتهي بعلامة وقف، أو صفحةٌ قبلها
#    كذلك فهي التي تحمل بدايةَ الجملة.

_SENTENCE_END = (".", "؟", "!", ":", "…", "؛", "•", ")")


def looks_truncated(text: str) -> bool:
    """هل تنقطع الصفحة في منتصف جملة؟"""
    tail = (text or "").rstrip()
    return bool(tail) and not tail.endswith(_SENTENCE_END)


def expand_truncated_neighbours(texts: List[str], chosen: List[int],
                                limit: int = 2, look: int = 2) -> List[int]:
    """يضمّ جارةَ الصفحة المبتورة — بحدٍّ أقصى `limit` صفحة.

    `look`: كم صفحةً من أعلى الترتيب نفحص (الأعلى ترتيباً هي بيتُ الموضوع).
    """
    out = list(chosen)
    added = 0
    for i in chosen[:look]:
        if added >= limit:
            break
        # ① هذه الصفحة تنقطع ⇒ تكملتُها في التالية
        if looks_truncated(texts[i]) and i + 1 < len(texts) and i + 1 not in out:
            out.append(i + 1)
            added += 1
        # ② والصفحةُ قبلها تنقطع ⇒ بدايةُ الجملة فيها
        if added < limit and i - 1 >= 0 and i - 1 not in out \
                and looks_truncated(texts[i - 1]):
            out.append(i - 1)
            added += 1
    return out


# ══════════════════════════════════════════════════
# 🎯 عتبةُ الصلة — «أفضل أربع» لا تعني «ذات صلة»
# ══════════════════════════════════════════════════
#
# 🔴 **ما رآه المالك (2026-09-14):** «الطالب يسأل عن قانون نيوتن الثاني
#    والوحدةُ عن الغدد. البحث يقول: أفضل ٤ نتائج. لكن أفضل ٤ لا يعني أنها
#    ذاتُ صلةٍ فعلاً — وهنا ممكن الموديل يستنتج: بما أن هذه الصفحات هي
#    التي أُرسلت لي، فلا بد أن أجيب منها.» وبرومبتُ الإجابة يأمره حرفياً
#    بالإجابة من نصّ الكتاب، فيؤلّف.
#
# 📏 الرقمان في [config.py] **مقيسان** على ٦٣٠ سؤالاً من تسعة كتب.
#
# ⚖️ **ولماذا حزامان لا واحد:** رفضُ سؤالٍ صحيح أقسى من قبول سؤالٍ دخيل،
#    فالأرضيةُ مخفوضةٌ إلى حيث الرفضُ الخاطئ ٠٫٨٪. وما فوقها بقليل يُرسَل
#    **ومعه تحفّظ**: الموديل يرى الصفحات ويحكم بنفسه — بلا نداءٍ ثانٍ ولا
#    ريال زيادة.


class Ranked(tuple):
    """`(نصوص, فهارس)` — وتحمل معها درجةَ أفضلِ مطابقة.

    ⚖️ **ترثُ من `tuple` عمداً**: اثنا عشر موضعاً تكتب
    `results, idxs = await enhanced_qa_search(...)`، وتمريرُ قيمةٍ ثالثة
    كان سيعني تعديلَها كلَّها — وأيُّ موضعٍ يُنسى يبقى بلا حارس.
    """

    # ملاحظة: لا `__slots__` هنا — الوراثةُ من `tuple` تمنعها.
    def __new__(cls, texts, idxs, best: float = 0.0):
        obj = super().__new__(cls, (texts, idxs))
        obj.best = float(best)
        return obj

    @property
    def verdict(self) -> str:
        """`off` لا صلة · `weak` صلةٌ محتملة · `ok` مطابقةٌ واثقة."""
        if not self[0]:
            return "off"
        if self.best < RELEVANCE_FLOOR:
            return "off"
        return "weak" if self.best < RELEVANCE_SURE else "ok"


# ⚠️ **صياغةُ التحفّظ مُقاسة، لا مجرّد نصيحة.**
#
# 🔴 أولُ صيغةٍ رتّبت للموديل: «① المحادثة ② ثم الصفحات ③ وإلا فقل إنه
#    ليس في وحدته» — فاتّخذ ③ **مخرجاً سهلاً**. قِيس حيّاً: سؤال «اكتب
#    قانون المقاومة الحثية والسعوية» في وحدة التيار المتردد (٠٫٦٤٨) ردّ
#    عليه بـ«هذا لا يبدو ضمن وحدتك» — و«الحثية» و«السعوية» في الوحدة
#    نصّاً. فصار الترتيبُ يبدأ بأمرٍ صريح بالقراءة، والاعتذارُ آخرَ سطر.

_READ_FIRST = (
    "① **اقرأ الصفحات أعلاه كاملةً قبل أن تحكم.** فيها جداولُ وقوائم قد "
    "تكون مكتوبةً سطراً متّصلاً، والمصطلحُ قد يرد بصيغةٍ أخرى غير التي "
    "كتبها الطالب (المفاعلة/المقاومة · يفرز/يخرج · التمثيل/البناء).\n"
    "② وانظر في المحادثة أعلاه: قد يسأل عن عبارةٍ أو مصطلحٍ **وردا في "
    "جوابك السابق**، أو يطلب تبسيطَ ما شرحتَه.\n"
    "③ ولا تقل «ليس في وحدتك» إلا بعد أن تتيقّن أنه ليس في الصفحات ولا في "
    "المحادثة — **هي جملةٌ أخيرة لا مخرجٌ سهل**، وإن قلتَها فاقترح عليه "
    "تغيير الوحدة أو إعادة الصياغة بمصطلحٍ من الكتاب.\n"
    "④ ⛔ **ولا تجب من معرفتك العامة مهما عرفت الجواب** — الطالب يُمتحن "
    "بكتابه، وجوابٌ من خارجه يضرّه."
)

WEAK_MATCH_NOTE = (
    "\n\n⚠️ تنبيه للمساعد: الصفحات أعلاه أقربُ ما وُجد في وحدة الطالب، "
    "وقد لا تتناول سؤاله **باللفظ الذي كتبه**.\n" + _READ_FIRST
)

NO_MATCH_NOTE = (
    "\n\n⛔ تنبيه للمساعد: لم يُطابق البحثُ سؤالَ الطالب، وما فوق أقربُ ما "
    "وُجد في وحدته وهو بعيد.\n" + _READ_FIRST
)


def has_prior_answer(req) -> bool:
    """هل في المحادثة جوابٌ سابقٌ يمكن أن يكون السؤالُ عنه؟"""
    if req is None:
        return False
    history = getattr(req, "chat_history", None) or []
    return any(isinstance(m, dict) and m.get("role") in ("assistant", "ai")
               for m in history)


def is_continuation_request(req) -> bool:
    """طلبُ متابعةٍ في محادثةٍ فيها جوابٌ سابق يُبنى عليه."""
    if req is None:
        return False
    if not is_followup(getattr(req, "search_query", "") or ""):
        return False
    return has_prior_answer(req)


NO_MATCH_NOTE = (
    "\n\n⛔ تنبيه للمساعد: **لم يُعثر على صفحاتٍ تطابق سؤال الطالب** في "
    "وحدته — وما فوق أقربُ ما وُجد وهو بعيد. فرتّب نظرك هكذا:\n"
    "① **المحادثة أعلاه أولاً**: قد يسأل عن عبارةٍ أو مصطلحٍ وردا في جوابك "
    "السابق، أو يطلب تبسيطَ ما شرحتَه. إن كان كذلك فأجبه.\n"
    "② فإن لم يكن سؤاله عن المحادثة ولا عن الصفحات أعلاه، **فالأرجح أنه "
    "خارج وحدة الطالب**: قل له ذلك بلطفٍ في سطرٍ أو سطرين، واقترح عليه أن "
    "يغيّر الوحدة من إعدادات الجلسة أو يعيد صياغة سؤاله بمصطلحٍ من الكتاب.\n"
    "③ ⛔ **ولا تجب من معرفتك العامة مهما عرفت الجواب** — الطالب يُمتحن "
    "بكتابه، وجوابٌ من خارجه يضرّه."
)


def off_topic(found, req=None) -> bool:
    """هل يُردّ السؤالُ بلا نداءِ موديل؟ — **وفي أول المحادثة وحدها.**

    🔴 **قرار المالك بعد ثلاث شكاوى (2026-09-14):** «دائماً السؤال يروح
       للمودل. يطلع عنده ويشوف سياق المحادثة والدرس، هل السؤال عن الدرس
       ولا عن سياق المحادثة، ويجاوب.»

       والحادثةُ التي حسمته: شرح الموديلُ أن «الأنسولين ينظّم **عمليات
       البناء**»، فسأل الطالب «إيش معنى عمليات البناء؟» — والعبارةُ من
       **جواب الموديل** لا من نصّ الكتاب، فقِيست ٠٫٤٦٦ ورُفضت. والطالبُ
       يسأل عن كلامٍ قيل له قبل سطرين.

    ⚖️ **فالعتبةُ تحرس البدايةَ لا المحادثة.** سؤالٌ أولُ رسالةٍ لا شيءَ
       يُفسّره غيرُ الكتاب، فإن لم يكن فيه رُدَّ مجاناً («ما قانون نيوتن
       الثاني؟»). أما وفي المحادثة جوابٌ سابق، فالجوابُ قد يكون فيه —
       وتُرسل الصفحاتُ ومعها تحفّظٌ يأمر الموديل أن ينظر في السياق أولاً.
    """
    if has_prior_answer(req):
        return False
    return getattr(found, "verdict", "ok") == "off"


def book_context(found, empty: str = "لا توجد نصوص مطابقة من الكتاب.",
                 sep: str = "\n\n", req=None) -> str:
    """نصُّ الكتاب كما يذهب للموديل — ومعه التحفّظُ إن كانت الصلةُ ضعيفة.

    `sep` يبقى كما كان في كل معالج (بعضها يفصل بسطرٍ وبعضها بسطرين) كي لا
    يتغيّر برومبتُ مادةٍ بلا قصد.
    """
    texts = found[0] if found else []
    body = sep.join(texts) if texts else empty

    # 🗣️ ولا تحفّظَ على طلبِ متابعة: «قل إن سؤاله ليس ضمن الوحدة» جوابٌ
    #    أحمق لمن طلب تبسيطَ ما شُرح له للتوّ.
    if is_continuation_request(req):
        return body

    # 🎯 **السؤالُ يذهب للموديل دائماً** (قرار المالك 2026-09-14، مكرّراً):
    #    «يروح يشوف إيش الصفحات، ما حصل شي، يطلع للمودل بدون صفحات ويقول
    #    له: هذا سيستم برومبت، وهذي الصفحات، وهذا سياق المحادثة.»
    #    فالعتبةُ لم تعد تردّ أحداً — صارت **تختار ما يُقال للموديل**:
    #    مطابقةٌ واثقة بلا تحفّظ · ضعيفةٌ بتحفّظ · ولا مطابقةَ بتحفّظٍ أشدّ.
    verdict = getattr(found, "verdict", "ok")
    if verdict == "off":
        body += NO_MATCH_NOTE
    elif verdict == "weak":
        body += WEAK_MATCH_NOTE

    # 🖌️ **وتذكيرُ الرسّام يُلحق هنا لا في كلِّ معالج.**
    #
    # 🔴 قِيس (2026-09-14): `draw_reminder` كانت في وضع الدروس ووضع الوحدات
    #    العام واختبر-نفسك والمعلّم — **وغائبةً عن معالجات المواد الخمسة**
    #    (أحياء · فيزياء · كيمياء · عربي · إنجليزي)، وهي التي تخدم أكثر
    #    الصفحات رسوماً. ستةَ عشر موضعاً تبني رسالة المستخدم، فإلحاقُه في
    #    كلٍّ منها يعني موضعاً يُنسى — وقد نُسي فعلاً.
    #
    # ⚖️ وموضعُه هنا آخرُ نصِّ الكتاب لا آخرُ الرسالة كلِّها: يبقى قريباً من
    #    النهاية (السؤالُ بعده سطرٌ واحد)، ويستحيل أن يفوت معالجاً.
    return body + draw_reminder(body)


async def hybrid_rank(texts: List[str], query: str, top_k: int,
                      meta: Optional[dict] = None):
    """يعيد `(نصوص, فهارس)` مرتّبةً بمجموع: تشابهٌ دلاليّ + مطابقةٌ موزونة."""
    if not texts:
        return Ranked([], [], best=0.0)

    # ✂️ البحثُ على **مقاطع** لا صفحات — نافذة الموديل ١٢٨ رمزاً والصفحة
    #    وسطها ٤٥٤، فالفهرسةُ على الصفحة كانت تُسقط ثلثيها ([embedding_corpus]).
    chunks, owners = embedding_corpus(texts)

    # ① الدلاليّ لكل المقاطع (الفهرس مسطّح ودقيق بلا تقريب)
    sem = await faiss_scores(chunks, query, meta=meta)

    # ② المطابقة اللفظية الموزونة — على المقاطع نفسِها كي يتطابق المقياسان
    norm_chunks = [_normalize_for_search(t) for t in chunks]
    terms = query_terms(query)
    weights = term_weights(terms, norm_chunks)
    # 🔻 والكلمةُ الغائبة عن الكتاب كلِّه تدخل المقام — غيابُ الموضوع دليلُ
    #    بُعدٍ لا سببُ ترقية ([lexical_denominator]).
    total_weight = lexical_denominator(terms, norm_chunks, weights)

    # ③ درجةُ الصفحة = **أعلى** درجات مقاطعها.
    #    ⚖️ لا معدّلاً: صفحةٌ فيها فقرةٌ تُجيب تماماً وفقرتان عن غيره
    #       يجب أن تفوز، والمعدّلُ كان سيُخفّف ما جئنا نُركّزه.
    page_best: dict = {}
    for i, norm in enumerate(norm_chunks):
        lexical = 0.0
        if total_weight > 0:
            hit = sum(w for term, w in weights.items() if term in norm)
            lexical = hit / total_weight
        score = sem.get(i, 0.0) + _KEYWORD_WEIGHT * lexical
        page = owners[i]
        if score > page_best.get(page, -1e9):
            page_best[page] = score

    scored = [(score, page) for page, score in page_best.items()]
    # ترتيبٌ ثابت: الأعلى درجةً، وعند التساوي الأسبقُ في الكتاب.
    scored.sort(key=lambda p: (-p[0], p[1]))
    chosen = [i for _score, i in scored[:top_k]]
    # 🔗 ثم تُضمّ جارةُ الصفحة المبتورة — جملةٌ مقصوصةٌ بين صفحتين تُشرح نصفها.
    chosen = expand_truncated_neighbours(texts, chosen)
    # 🎯 ودرجةُ الأفضل تسافر مع النتيجة — عليها يقوم حكمُ الصلة.
    return Ranked([texts[i] for i in chosen], chosen, best=scored[0][0])


async def faiss_scores(texts: List[str], query: str,
                       meta: Optional[dict] = None) -> dict:
    """`{فهرس: تشابهُ جيبٍ}` **لكل** الصفحات — لا لأفضل ثلاث.

    ⚖️ الترتيبُ الهجين يحتاج **قيمةً** يجمعها مع وزن المطابقة اللفظية لا
       رتبةً. والفهرس `IndexFlatIP` مسطّحٌ دقيق بلا تقريب، والكتبُ بضعُ
       مئاتٍ من الصفحات — فمسحُها كلِّها أرخصُ من أي تقريب.
    """
    if not texts:
        return {}
    try:
        index = await get_index(texts, meta)

        def _score_all():
            q_emb = embed_model.encode([query], convert_to_numpy=True,
                                       show_progress_bar=False)
            faiss.normalize_L2(q_emb)
            return index.search(q_emb, k=index.ntotal)

        D, I = await asyncio.wait_for(asyncio.to_thread(_score_all), timeout=15.0)
        return {int(i): float(d) for d, i in zip(D[0], I[0]) if 0 <= i < len(texts)}
    except asyncio.TimeoutError:
        print("⚠️ FAISS timeout (scores)")
        return {}
    except Exception as e:
        print(f"⚠️ FAISS error (scores): {e}")
        return {}


async def enhanced_qa_search(book_data, query, top_k=5):
    """بحثُ وضع الوحدات — **ترتيبٌ هجين موزون** لا دمجٌ بالأسبقية.

    🔄 كان: «كلُّ صفحةٍ فيها أيُّ كلمةٍ من السؤال تُقدَّم، بترتيب الكتاب،
       ثم يُقصّ عند `top_k`» — فكلمةُ «بين» وحدها كانت تطرد البحثَ
       الدلاليَّ بالكامل. راجع الشرح فوق [hybrid_rank].
    """
    texts, _metas = extract_all_texts_and_metas(book_data)
    return await hybrid_rank(texts, query, top_k)





def normalize_arabic(text: str) -> str:
    if not text:
        return ""

    text = text.lower()

    # إزالة التشكيل
    text = re.sub(r'[ًٌٍَُِّْـ]', '', text)

    # توحيد الحروف
    replacements = {
        "أ": "ا",
        "إ": "ا",
        "آ": "ا",
        "ى": "ي",
        "ة": "ه",
        "ؤ": "و",
        "ئ": "ي",
    }

    for k, v in replacements.items():
        text = text.replace(k, v)

    # إزالة أل التعريف
    text = re.sub(r'\bال', '', text)

    # إزالة أي شيء غير حروف عربية
    text = re.sub(r'[^\u0600-\u06FF\s]', ' ', text)

    # إزالة المسافات الزائدة
    text = re.sub(r'\s+', ' ', text).strip()

    return text
# ══════════════════════════════════════════════════
# 📚 الوحدة إلزاميةٌ في بحث وضع الوحدات — قرار المالك 2026-09-14
# ══════════════════════════════════════════════════
#
# «الكل ماشي الكل — ضروري يكون في وحدة عشان يقلّل البحث، يكون معصور،
#  بحثٌ أفضل.»
#
# ⚖️ والقياسُ يؤيّده: كتابُ الأحياء ١٦٢ صفحة ووحدةُ التنظيم الهرموني ١٩.
#    البحثُ في ١٩ صفحةً يختار من جيرانٍ متقاربين فيميّز بينهم، وفي ١٦٢
#    يُزاحم الموضوعَ صفحاتٌ من وحداتٍ لا علاقة لها به.
#
# 🔒 **وعلى مسار البحث وحده**: اختيارُ صفحاتٍ بأرقامها لا يحتاج وحدةً —
#    الرقمُ يحدّد الصفحة بنفسه، فاشتراطُ الوحدة هناك منعٌ بلا فائدة.
UNIT_REQUIRED_MESSAGE = (
    "📚 اختر الوحدة أولاً من إعدادات الجلسة.\n\n"
    "البحث في الكتاب كلّه يأتي بصفحاتٍ من وحداتٍ أخرى، "
    "وتحديدُ الوحدة يجعل الإجابة من درسك أنت."
)


def unit_missing(req) -> bool:
    """هل بقي الطالبُ على «الكل» (أو لم يختر شيئاً)؟"""
    name = (getattr(req, "unit_name", "") or "").strip()
    return not name or name == "الكل"


def unit_required_response() -> dict:
    # 📣 `off_topic` هنا أيضاً: طلبٌ بلا وحدة لم يُجَب، فلا يبقى في السجلّ
    #    سؤالاً معلّقاً يحاول الموديل إكماله في الدور التالي.
    return {"answer": UNIT_REQUIRED_MESSAGE, "references": [],
            "session_active": False, "off_topic": True}


# ══════════════════════════════════════════════════
# ❓ وضعُ السؤال يحتاج سؤالاً — لا ضغطةَ زرٍّ فارغة
# ══════════════════════════════════════════════════
#
# ⚖️ **قرار المالك (2026-09-14):** «في خانة السؤال ضروري الطالب يكتب سؤال.
#    السؤال حطّيته إجابةً لشيءٍ معيّن — يقول له عرّف لي الغدة النخامية،
#    يعرّفها بسطرين ثلاثة. السؤالُ ليس الذي يشرح الدرس. فلا تخلّيه يقدر
#    يضغط زرّ الإرسال بلا ما يكتب شي، **في كل المواد**.»
#
# 🔴 **وما كان:** الضغطُ على «إرسال» بحقلٍ فارغ كان يُولّد طلباً من عندنا —
#    «اطرح ملخصاً سريعاً لأهم نقاط الدرس» في وضع الدروس، و«أجب عن سؤالي من
#    المحتوى أعلاه» في وضع الوحدات. فيخرج **شرحُ درسٍ كامل من وضع السؤال**،
#    وهو نقيضُ ما بُني له الوضع، **ويُخصم من حصّة الطالب** على طلبٍ لم يطلبه.
#
# ⚖️ **والصورةُ سؤالٌ مكتوب**: نصُّها يُدمج في `req.content` قبل التوجيه
#    ([api._ask_guards] ← `vision.merge_into_question`)، فالفحصُ على المحتوى
#    بعد الدمج يسمح بسؤالٍ مصوَّرٍ بلا كتابة — وهو مقصود.

QUESTION_REQUIRED_MESSAGE = (
    "❓ اكتب سؤالك أولاً.\n\n"
    "وضعُ **السؤال** للإجابات القصيرة المحدّدة — «عرّف لي الغدة النخامية» · "
    "«ما الفرق بين كذا وكذا؟» · «متى تُستعمل هذه القاعدة؟».\n\n"
    "وإن أردتَ شرحَ الدرس كاملاً فبدّل الوضع إلى **شرح** من إعدادات الجلسة."
)


def question_needs_text(req) -> bool:
    """وضعُ سؤالٍ بلا سؤال. يُفحص **بعد** دمج نصّ الصورة في المحتوى."""
    if (getattr(req, "mode", "") or "").strip() != "سؤال":
        return False
    return not (getattr(req, "content", "") or "").strip()


def question_required_response() -> dict:
    # 📣 `off_topic` كما في [unit_required_response]: طلبٌ لم يُجَب، فلا يبقى
    #    في السجلّ سؤالاً معلّقاً يحاول الموديل إكماله في الدور التالي.
    #    وبلا نداءِ موديل ⇒ لا يُخصم من الحصة ([core/billing.py]).
    return {"answer": QUESTION_REQUIRED_MESSAGE, "references": [],
            "session_active": False, "off_topic": True}


def extract_keywords(query: str):
    normalized = normalize_arabic(query)
    words = normalized.split()

    # تجاهل الكلمات القصيرة جداً
    return [w for w in words if len(w) >= 3]

def normalize_text_match(text: str) -> str:
    """
    دالة تنظيف قوية لضمان تطابق أسماء الدروس
    تزيل: المسافات، الهمزات، التشكيل
    """
    if not text:
        return ""
    text = text.lower().strip()
    # إزالة التشكيل
    text = re.sub(r'[ًٌٍَُِّْـ]', '', text)
    # توحيد الألف والياء والتاء
    text = re.sub(r'[أإآ]', 'ا', text)
    text = text.replace('ة', 'ه').replace('ى', 'ي')
    # إزالة المسافات تماماً لضمان التطابق حتى لو فيه مسافة زائدة
    text = re.sub(r'\s+', '', text)
    return text

def normalize_lesson_name(text: str) -> str:
    """
    تطبيع اسم الدرس للمقارنة
    - إزالة المسافات والـ _
    - توحيد الحروف العربية
    - تحويل لأحرف صغيرة
    """
    if not text:
        return ""
    
    # تحويل لأحرف صغيرة
    text = text.lower()
    
    # إزالة التشكيل
    import re
    text = re.sub(r'[ًٌٍَُِّْـ]', '', text)
    
    # توحيد الحروف العربية
    replacements = {
        "أ": "ا",
        "إ": "ا",
        "آ": "ا",
        "ى": "ي",
        "ة": "ه",
        "ؤ": "و",
        "ئ": "ي",
    }
    
    for old, new in replacements.items():
        text = text.replace(old, new)

    # 4-ب) 🔬 **الأُسّ كاملاً لا رقمه الأول.**
    #
    # 🔴 كان في الجدول أعلاه `'^2': '²'` استبدالاً أعمى، فـ«10^23» تصير
    #    «10²3» — و«6.022 × 10^23» هو **عدد أفوجادرو** يتكرّر في كل درس
    #    كيمياء كهربائية، و«10^-7» في الأس الهيدروجيني. أي أن الرقم الذي
    #    يراه الطالب **خاطئ** لا مشوّهُ الشكل فقط.
    text = _superscript(text)
    
    # إزالة المسافات والـ _
    text = text.replace(" ", "").replace("_", "")
    
    # إزالة أي شيء غير حروف عربية وأرقام
    text = re.sub(r'[^\u0600-\u06FF\d]', '', text)
    
    return text






def parse_exams_input(content: str):
    parts = [p.strip() for p in content.split(",") if p.strip() != ""]
    if not parts:
        return None, None
    year = parts[0]
    rest = parts[1:]
    return year, rest

def restrict_book_to_unit(book_data: List[dict], unit_name: str):
    """
    تحصر الكتاب داخل وحدة واحدة فقط
    """
    for unit in book_data:
        if unit_name == unit.get("اسم_الوحدة") or unit_name == str(unit.get("رقم_الوحدة")):
            return [unit]
        if unit_name in unit.get("اسم_الوحدة", ""):
            return [unit]
    return None

def collect_exam_questions_by_years(subject: str, years: List[str], grade: int = 3, track: str = "علمي"):
    exams_dir = subject_exams_dir(subject, grade, track)
    found = []
    if not os.path.isdir(exams_dir):
        return found
    for f in os.listdir(exams_dir):
        if not f.lower().endswith(".json"):
            continue
        file_year = os.path.splitext(f)[0].strip()
        if "الكل" not in years and file_year not in [str(y) for y in years]:
            continue
        data = load_json_safe(os.path.join(exams_dir, f))
        if not data:
            continue
        for block in data:
            questions = block.get("الاسئلة", [])
            for q in questions:
                found.append({
                    "سنة": block.get("سنة_الامتحان", file_year),
                    "الجزء": block.get("الجزء", ""),
                    "النوع": block.get("نوع_السؤال", ""),
                    # 🖌️ **والوزاريُّ نصُّ كتابٍ كغيره**: كسورُه تُرسم
                    #    وصيغُه العضوية تُرمَّز، فلا يكون الرسّام ميزةَ
                    #    وضعٍ دون وضع.
                    "النص": prepare_source(q if isinstance(q, str) else str(q),
                                           subject),
                })
    return found

def filter_and_rank_exams(questions: list, user_text: str):
    """
    - أي سؤال يحتوي على كلمة واحدة على الأقل يطلع
    - يتم ترتيب الأسئلة حسب عدد الكلمات المتطابقة (الأكثر أولاً)
    """
    user_keywords = extract_keywords(user_text)
    if not user_keywords:
        return []

    scored_questions = []

    for q in questions:
        q_text = normalize_arabic(q.get("النص", ""))
        score = 0

        for kw in user_keywords:
            if kw in q_text:
                score += 1

        if score > 0:
            scored_questions.append((score, q))

    # ترتيب: الأعلى تطابقاً أولاً
    scored_questions.sort(key=lambda x: x[0], reverse=True)

    return [q for score, q in scored_questions]

# ℹ️ حُذفت نسخة ثانية متطابقة من normalize_arabic كانت معرّفة هنا
#    وتطغى على الأولى — سلوك واحد بتعريفين فخّ صامت.

def get_math_exam_years(branch: str):
    """يجلب السنوات المتاحة لفرع معين"""
    exams_dir = os.path.join(BASE_SUBJECTS_DIR, "رياضيات", "exams", branch)
    
    if not os.path.isdir(exams_dir):
        return []
    
    years = []
    for f in os.listdir(exams_dir):
        if f.endswith(".json"):
            year = os.path.splitext(f)[0]
            years.append(year)
    
    years.sort(reverse=True)
    return years


def get_math_exam_lessons(branch: str, year: str):
    """يجلب أسماء الدروس من ملف السنة"""
    exam_file = os.path.join(BASE_SUBJECTS_DIR, "رياضيات", "exams", branch, f"{year}.json")
    
    if not os.path.isfile(exam_file):
        return []
    
    data = load_json_safe(exam_file)
    if not data:
        return []
    
    # استخراج أسماء الدروس الفريدة
    lessons = list(set([item.get("الدرس", "") for item in data if item.get("الدرس")]))
    return lessons


def get_math_exam_questions(branch: str, year: str, lesson_name: str, count: int):
    exam_file = os.path.join(BASE_SUBJECTS_DIR, "رياضيات", "exams", branch, f"{year}.json")
    if not os.path.isfile(exam_file):
        return {"questions": [], "total": 0, "has_more": False}
    
    data = load_json_safe(exam_file)
    if not data:
        return {"questions": [], "total": 0, "has_more": False}
    
    # 🔥 المطابقة الذكية باستخدام الدالة الجديدة
    target_norm = normalize_text_match(lesson_name)
    all_questions = []
    
    for item in data:
        # نقارن الاسم بعد التنظيف
        current_lesson_norm = normalize_text_match(item.get("الدرس", ""))
        
        if current_lesson_norm == target_norm:
            questions = item.get("الاسئلة", [])
            for q in questions:
                # 🧮 **والوزاريُّ الرياضيّ أحوجُ ما يكون للرسّام**: أسئلتُه
                #    كسورٌ وأُسُسٌ وجذور، وكانت تُعرض نصّاً مسطّحاً بينما
                #    يراها الطالبُ مرسومةً في الشرح من الدرس نفسه.
                all_questions.append({
                    "نص_السؤال": prepare_source(q.get("نص_السؤال", ""), "رياضيات"),
                    "الحل": prepare_source(q.get("الحل", ""), "رياضيات"),
                })
    
    total = len(all_questions)
    batch = all_questions[:count] if count < total else all_questions
    has_more = count < total
    
    return {
        "questions": batch,
        "total": total,
        "has_more": has_more,
        "remaining": total - len(batch)
    }

def load_math_lesson(branch: str, lesson_name: str):
    """
    branch: تفاضل / تكامل / هندسة / جبر
    lesson_name: اسم الدرس — **باسم الملف أو بالاسم الداخلي `اسم_الدرس`**

    ⚠️ الاسمان يختلفان فعلاً في البيانات (ملف «القطع الزائد» واسمه الداخلي
       «القطع الزائد (الهذلول - Hyperbola)»)، وقائمةُ الدروس صارت ترجع الاسم
       الداخلي ليطابق `/content/capabilities`. فيلزم قبول الاثنين: الداخلي
       لما يأتي من الاختبار والقائمة الجديدة، والملفّي لمحادثاتٍ محفوظة
       قديماً ولأي نداءٍ لم يُحدَّث.

       ويُقبل الملف **بلا امتداد `.json`** كما يفعل بناء كتاب الدروس —
       ملف «مبدأ العد (طرائق العد )» بلا امتداد وكان يسقط هنا وحده.
    """
    base = math_branch_dir(branch)
    if not os.path.isdir(base):
        return None

    target = normalize_lesson_name(lesson_name)
    files = [f for f in sorted(os.listdir(base))
             if not f.startswith((".", "_")) and os.path.isfile(os.path.join(base, f))]

    # ١) مطابقة اسم الملف — الأرخص، بلا قراءة قرص
    for f in files:
        stem = f[:-5] if f.endswith(".json") else f
        if normalize_lesson_name(stem) == target:
            return load_json_safe(os.path.join(base, f))

    # ٢) مطابقة الاسم الداخلي — لا تُدفع كلفتها إلا عند فشل الأولى
    for f in files:
        data = load_json_safe(os.path.join(base, f))
        if not isinstance(data, dict):
            continue
        inner = data.get("اسم_الدرس") or data.get("اسم_درس") or ""
        if inner and normalize_lesson_name(inner) == target:
            return data

    return None




# ══════════════════════════════════════════════════════════
# ⚗️ قاعدة الصيغ البنائية — تُضاف لمواد الكيمياء العضوية وحدها
# ══════════════════════════════════════════════════════════
# 🔴 **لماذا هنا لا في `subjects/chemistry.py`؟** لأن وضعَي الدروس والوحدات
#    (المسار الحيّ اليوم) يمرّان بـ`core/lesson_mode.py` و`core/pages_mode.py`
#    وهما يستعملان **هذه البرومبتات المشتركة**؛ وبرومبتات `chemistry.py`
#    لا تُقرأ إلا في المسار القديم. تعديلُ ذاك وحده لا يغيّر شيئاً للطالب.
#
# والقاعدة قسمٌ مستقلٌّ بارز، وتنصّ صراحةً على أولويتها على «انقل حرفياً» —
# فالاستثناء المدسوس داخل جملة منع طويلة يُتجاهَل (درسٌ من تجربة الكسور).

# 🔒 **الكيمياء وحدها.** مصدرٌ واحد للنطاق مع `core/chem.py` — فما يُرمَّز
#    في نصّ الكتاب هو نفسه ما تُطلب كتابته في الرد، ولا تتفرّق الكلمة.
from core.chem import ORGANIC_SUBJECTS as _ORGANIC_SUBJECTS
from core.chem import REACTION_SUBJECTS as _REACTION_SUBJECTS
from core.nuclide import NUCLIDE_SUBJECTS as _NUCLIDE_SUBJECTS


def fraction_rules(subject: str = "") -> str:
    """🧮 قاعدة الكسور — **نصٌّ واحد** يُلحق ببرومبت كل وضعٍ وكل مادة.

    🔴 **كانت منسوخةً حرفياً في ثلاثة برومبتات وغائبةً عن الرابع**: وضعُ
       السؤال (`system_prompt_strict_qa_improved`) بلا قاعدة كسورٍ إطلاقاً.
       فالطالب يسأل سؤالاً في الفيزياء فيأتيه «السرعة = المسافة / الزمن»
       سطراً مسطّحاً، بينما يراها كسراً مرسوماً لو طلب **شرح** الدرس نفسه.
       (شكوى المالك 2026-09-13: «التعديلات مو في الشرح بس — في التلخيص
        والسؤال والوزاري كذلك».)
    """
    return (
        "🧮 قاعدة الكسور (إلزامية ولا استثناء لها):\n"
        "كل كسر — أي «س على ص» — يُكتب حصراً بالصيغة \\frac{البسط}{المقام}.\n"
        "يُمنع كتابته بـ«/» أو «÷» أو بكلمة «على»، حتى لو كتبه الكتاب هكذا.\n"
        "⚠️ وحدات القياس ليست كسوراً وتبقى كما هي: م/ث · كجم.م/ث · كم/ساعة.\n"
        "أمثلة: السرعة = \\frac{المسافة}{الزمن} · ك = \\frac{الوزن}{تسارع الجاذبية}\n"
        "وهذه الصيغة وحدها مستثناة من منع LaTeX المذكور أعلاه.\n"
    )


# 🖌️ ترميزاتُ الرسم في نصّ المصدر — تُعدّ ليُذكَّر بها الموديلُ برقمها.
DRAW_CODES = re.compile(r"\\(?:ring|chem|frac|sqrt|nuc|fact|perm|comb)\{")


def draw_reminder(source_text: str) -> str:
    """تذكيرٌ **بعدد** ترميزات الرسم في المصدر — آخرُ ما يقرؤه الموديل.

    🔴 **ولماذا في رسالة المستخدم لا في البرومبت وحده؟** القاعدة موجودةٌ في
       البرومبت أصلاً («انقل كل ترميزٍ تراه»)، ومع ذلك كان **التلخيص** يُسقط
       الحلقات كلَّها، و**الاختبار** يعيد خمسة أسئلةٍ بلا رسمة من درسٍ فيه
       ٤٥ ترميزاً، و**خطةُ درس المعلّم** مثلَهما. السببُ واحد: مَن يستخلص
       المعنى يطوي الرسوم بطبعه. والعددُ الملموس («فيه ٤٥») أقربُ إلى
       الامتثال من قاعدةٍ عامّة بعيدة. (قيسَ حيّاً: صفر ⇐ خمسة.)

    ⚖️ **ومصدرُه واحدٌ هنا** لأن أربعة أقسامٍ تستعمله (الدروس · الصفحات ·
       الاختبار · المعلّم)، وكان يسكن في `lesson_mode` فيستورده الجميع من
       جوف وحدةٍ لا تخصّهم.
    """
    count = len(DRAW_CODES.findall(source_text or ""))
    if not count:
        return ""
    return (f"\n\n⚠️ في النصّ أعلاه {count} ترميزَ رسمٍ "
            "(\\ring{…} · \\chem{…} · \\frac{…}) — انقلها كما هي حرفاً بحرف "
            "حيثما ذكرتَ ما تمثّله، ولا تستبدلها بأسماء المركّبات ولا بوصفها "
            "بالكلمات، مهما بلغ الاختصار.")


def render_rules(subject: str) -> str:
    """**كلُّ قواعد الرسّام في نصٍّ واحد** — تُلحق ببرومبت أي وضعٍ لأي مادة.

    ⚖️ لأن الرسّام ليس ميزةَ وضعٍ بل ميزةُ **مادة**: من يرى الكسرَ مرسوماً
       في الشرح يجب أن يراه في التلخيص والسؤال والوزاري. وكلُّ برومبتٍ
       يُكتب بعد اليوم يُلحق بهذا السطر فلا يسقط منه شيء.
    """
    return (fraction_rules(subject)
            + organic_structure_rules(subject)
            + reaction_equation_rules(subject)
            + arabic_digits_rules(subject))


def organic_structure_rules(subject: str) -> str:
    """تعليمة الترميز البنائي — نصٌّ فارغ للمواد التي لا صيغ فيها.

    ⚠️ **حدود هذه القاعدة (مقصودة وصريحة):** هي قاعدة **كتابةٍ وشكل** لا
       قاعدة **مصدر**. لا تبيح ذرّة معلومة من خارج الدرس، ولا تسمح برسم
       مركّبٍ لم يرد فيه. قواعد «المصدر الوحيد هو الكتاب» تبقى فوقها كلها.
       (الصياغة الأولى قالت «كلّما ذكرتَ مركّباً عضوياً أرفِق ترميزه» —
        وهي دعوةٌ مفتوحة للرسم من معرفة الموديل، فأُزيلت.)
    """
    if (subject or "").strip() not in _ORGANIC_SUBJECTS:
        return ""
    return (
        "\n════════════════════════════════════════════════════\n"
        "⚗️ **الصيغ البنائية والحلقات — طريقة الكتابة**\n"
        "════════════════════════════════════════════════════\n"
        "🔒 **أولاً وقبل كل شيء:** هذه قاعدةُ **شكلِ الكتابة** لا قاعدةَ "
        "**مصدرِ المعلومة**. المصدر يبقى نصَّ الدرس وحده كما تقول القواعد "
        "أعلاه. **لا ترسم مركّباً لم يرد في الدرس**، ولا تُكمل صيغةً ناقصة "
        "من معرفتك. إن لم يذكر الدرسُ الصيغة فلا تخترعها.\n\n"
        "🚫 وحين **يذكر الدرسُ** صيغةً أو شكلاً: **يُمنع رسمه بالرموز أو "
        "الشرطات أو داخل ```**، ولا تقل «لا أستطيع الرسم». أنت **تكتب "
        "ترميزاً** والتطبيق **يرسمه** للطالب.\n\n"
        "📌 السلسلة المفتوحة ⇐ \\chem{...}\n"
        "   • المجموعات موصولةً بشرطة: \\chem{CH3-CH2-CH2-NH2}\n"
        "   • الفرع بين قوسين بعد أصله مباشرةً: \\chem{CH3-CH(CH3)-CH3}\n"
        "   • الثنائية = والثلاثية #: \\chem{CH3-CH=O} · \\chem{CH3-C#N}\n\n"
        "📌 الحلقة ⇐ \\ring{...} — الأجزاء يفصلها | :\n"
        "   • العدد أولاً: \\ring{3} مثلث · \\ring{4} مربع · \\ring{6} سداسي\n"
        "   • ar للعطرية: \\ring{6|ar} بنزين\n"
        "   • =رقم الضلع للرابطة الثنائية: \\ring{6|=1} هكسين حلقي\n"
        "     (والفرقُ بينه وبين \\ring{6} هكسان حلقي هو هذه الرابطة وحدها)\n"
        "   • رمز الذرّة داخل الحلقة: \\ring{6|ar|N} بيريدين · \\ring{6|NH} بيبيريدين\n"
        "   • +المجموعة المعلّقة: \\ring{6|ar|+NH2} أنيلين\n"
        "   • @رقم الرأس لموقعها: \\ring{6|ar|+Br@1|+Br@4} بارا-ثنائي برومو بنزين\n"
        "   • fuse للحلقات الملتحمة: \\ring{6|ar|fuse2} نفثالين · \\ring{6|ar|fuse3} أنثراسين\n\n"
        "⚠️ **وهي تسبق قاعدة «انقل بلغة الدرس حرفياً» في الشكل وحده**: إن "
        "كتب الكتابُ الصيغةَ سطراً مسطّحاً فاكتبها أنت بالترميز — المعنى "
        "والمحتوى كما في الكتاب حرفياً، والشكلُ وحده هو ما يتغيّر.\n"
        "🚫 **وممنوعٌ وصفُ الشكل بالكلمات**: لا «شكل سداسي» ولا «حلقة "
        "مثلثة» ولا «يُمثل برسم مربع» — اكتب \\ring{...} مكانها.\n\n"
        "📥 **ونصُّ الدرس يصلك بالترميز جاهزاً — انقله كما هو.** أمثلة على "
        "النقل المطلوب:\n"
        "   نصّ الدرس : «1) رسمة \\ring{3} : تمثل بروبان حلقي (سيكلوبروبان)»\n"
        "   ✅ ردُّك    : «سيكلوبروبان \\ring{3} وصيغته C3H6.»\n"
        "   ❌ لا تكتب : «سيكلوبروبان يُمثل برسم مثلث».\n\n"
        "   نصّ الدرس : «2) رسمة \\ring{4} : تمثل سيكلوبيوتان.»\n"
        "   ✅ ردُّك    : «سيكلوبيوتان \\ring{4}.»\n"
        "   ❌ لا تكتب : «سيكلوبيوتان يتم تمثيله برسم مربع».\n\n"
        "   نصّ الدرس : «رسمة \\ring{6|ar} : شكل سداسي بداخله دائرة»\n"
        "   ✅ ردُّك    : «البنزين \\ring{6|ar}.»\n"
        "   ❌ لا تكتب : «البنزين شكل سداسي بداخله دائرة».\n\n"
        "🧪 **وأمثلةُ التسمية تُعرض رسماً ثم اسماً تحته**، ولا تُحكى بالكلمات:\n"
        "   نصّ الدرس : «الرسم: \\chem{CH3-CH2-CH2-C(=O)-NH-CH2-CH2-CH3}»\n"
        "              «التسمية: N-بروبيل بيوتاناميد.»\n"
        "   ✅ ردُّك    : «المثال الأول:\n"
        "                \\chem{CH3-CH2-CH2-C(=O)-NH-CH2-CH2-CH3}\n"
        "                التسمية: N-بروبيل بيوتاناميد.»\n"
        "   ❌ لا تكتب : «الرسم: لدينا سلسلة من أربع كربونات مرتبطة "
        "بذرة نيتروجين…» — هذا حكايةُ الرسم لا الرسم.\n\n"
        "🔁 **القاعدة باختصار:** كلُّ \\ring{...} أو \\chem{...} تراه في نصّ "
        "الدرس **يجب أن يظهر في ردّك كما هو**. عدُّها قبل الإرسال: إن كان "
        "في الدرس ثلاثة ترميزات فلا يصحّ أن يخلو ردُّك منها.\n"
        "✂️ **وفي التلخيص خاصةً لا تحذفها اختصاراً**: الترميزُ **أقصرُ** من "
        "اسم المركّب ومن وصفه بالكلمات، وهو أوضحُ منهما. فاكتب "
        "«البنزين \\ring{6|ar}» لا «البنزين» وحدها، مهما بلغ الاختصار.\n"
    )


# 🔒 نطاقُ الأرقام العربية — **مصدرٌ واحد** مع الفلتر الذي يضمنها.
from core.arabic_digits import ARABIC_DIGIT_SUBJECTS as _ARABIC_DIGIT_SUBJECTS


def arabic_digits_rules(subject: str) -> str:
    """٠١٢ تعليمةُ شكل الأرقام — نصٌّ فارغ لما عدا مواد الأرقام العربية.

    🔴 **طلبُ المالك للفيزياء (2026-09-12):** «حوّل الأرقام كلها عربية،
       والسالب يكون من جهة يمين الرقم». وللرياضيات والمنطق قرارٌ أقدم
       (2026-09-09) — والكتاب اليمنيّ يكتبها ٠١٢٣ في الثلاثة.

    ⚖️ **والبرومبت يُقلّل، و[core/arabic_digits.py] يضمن.** لكن المتنَ
       العامّ كان يقول «والارقام العربيه» **لكل المواد** — عبارةٌ مجرّدة
       بلا مثال، ومسحُ ٨٠ سطراً من أجوبة الكيمياء الحقيقية وجد فيها
       **صفرَ** رقمٍ عربي. فالتعليمةُ المُلزمة مثالٌ ونطاق.

    ➖ **والإشارةُ تُكتب قبل عددها كالمعتاد** ولا تُقلب في النصّ: قلبُها
       يقع في الرسم وحده (الرقمُ العربي صنفُه AN فتقع إشارتُه يمينَه)،
       فلو كتبها الموديل بعد الرقم لانقلبت مرّتين.
    """
    if (subject or "").strip() not in _ARABIC_DIGIT_SUBJECTS:
        return ""
    return (
        "\n════════════════════════════════════════════════════\n"
        "٠١٢ **الأرقام بالعربية (٠١٢٣٤٥٦٧٨٩) لا باللاتينية (0123456789)**\n"
        "════════════════════════════════════════════════════\n"
        "• كل عددٍ في الشرح وفي المعادلة: «٥ نيوتن» لا «5 نيوتن» · "
        "«٢٩٨ كلفن» لا «298 كلفن» · «\\frac{١}{٢}» لا «\\frac{1}{2}».\n"
        "• والأُسُّ كذلك: «١٠^٨» لا «10^8».\n"
        "• ⚠️ **إلا رمزاً لاتينياً ملاصقاً رقمَه** فهو رمزٌ لا عدد ويُنقل "
        "كما في الكتاب: T1 · T2 · W0 · f0 · 500mA.\n"
        "• ➖ والسالبُ يُكتب **قبل** عدده كالمعتاد («-٥»)، ويظهر للطالب "
        "يمينَ العدد من نفسه — فلا تكتبه بعده.\n"
    )


def reaction_equation_rules(subject: str) -> str:
    """تعليمةُ كتابة معادلة التفاعل — نصٌّ فارغ لما عدا الكيمياء والأحياء.

    🔴 **ما رآه المالك (2026-09-12):** معادلتا انشطارٍ نوويّ تصلان الطالب
       مبعثرتين — «Al-27 + :قذيفة ألفا» و«3n <- (سريع)». والسببُ أن
       الموديل كتب العنوانَ العربيّ والمعادلةَ اللاتينية **في سطرٍ واحد**،
       فخلطهما الاتجاهُ الثنائي؛ وكتب السهمَ بشرطةٍ واحدة `->`.

    ⚖️ **والبرومبت يُقلّل والفلتر يضمن** ([latex_guard]): الرسّام في التطبيق
       صار يفهم `->` ويفصل العنوان بنفسه، وهذه التعليمة تُقلّل الحالات
       الشاذّة من أصلها. فلا يُعتمد عليها وحدها ولا يُستغنى عنها.
    """
    if (subject or "").strip() not in _REACTION_SUBJECTS:
        return ""
    return (
        "\n════════════════════════════════════════════════════\n"
        "⚗️ **معادلة التفاعل — سطرٌ مستقلّ وسهمٌ واحد**\n"
        "════════════════════════════════════════════════════\n"
        "📌 **كلُّ معادلةٍ في سطرٍ وحدَها**: لا عنوانَ معها في السطر نفسه "
        "ولا شرحَ بعدها. اكتب العنوان في سطر، والمعادلة في السطر التالي.\n"
        "   ✅ **معادلة انشطار اليورانيوم:**\n"
        "      U-235 + n --> Ba-141 + Kr-92 + 3n + طاقة\n"
        "   ❌ **معادلة انشطار اليورانيوم:** U-235 + n --> Ba-141 …\n\n"
        "📌 **السهم يُكتب `-->` دائماً** — لا «←» ولا «->» ولا كلمة «ينتج».\n"
        "📌 **الاتزان يُكتب `<=>`**.\n"
        "📌 **شرطُ التفاعل فوق السهم** بين قوسين معقوفين داخله:\n"
        "      CH3-CH2-OH --[حفاز نحاس / 200 م]--> CH3-CHO + H2\n"
        "📌 **ولا تضع نجوماً (`**`) حول المعادلة** — التطبيق يرسمها في "
        "إطارها، والنجومُ تظهر للطالب حروفاً.\n"
        # ☢️ ورمزُ النواة في الكيمياء وحدها — `to_nuclide` لا تعمل في
        #    غيرها، فلا يُؤمر بصيغةٍ لا تُرسم (`NUCLIDE_SUBJECTS`).
        + ("☢️ **ورمزُ النواة كما في الدرس حرفياً**: `^235_92U` — العددُ "
           "الكتلي بعد `^` والذرّيُّ بعد `_` ثم الرمز، والتطبيق يرسمهما "
           "مرصوفين فوق بعضهما كما في الكتاب.\n"
           "   ✅ ^235_92U + ^1_0n --> ^141_56Ba + ^92_36Kr + طاقة\n"
           "   ✅ ^27_13Al + ^4_2He --> ^30_15P + ^1_0n\n"
           "   ✅ وللإشارة موضعُها: ^0_+1β · ^0_-1e\n"
           "   ❌ Al-27 + He-4 --> P-30 + n-1\n"
           "   ❌ U-235 + n --> Ba-141\n"
           "🚫 **وصيغةُ الشرطة `Al-27` ممنوعة في المعادلات**: تُسقط العددَ "
           "الذرّي (١٣) فلا يستطيع التطبيقُ ولا الطالبُ استرجاعَه، ولا "
           "تتّزن المعادلةُ بدونه. انقل رمزَ الكتاب كما هو.\n"
           if (subject or "").strip() in _NUCLIDE_SUBJECTS else "")
        + "🔒 **والمحتوى كما في الدرس حرفياً**: هذه قاعدةُ شكلٍ لا قاعدةُ "
        "مصدر — لا تُكمل معادلةً ناقصة ولا تخترع متفاعلاً لم يُذكر.\n"
    )


# ══════════════════════════════════════════════════
# 🎓 قلبُ برومبت الإجابة — **مصدرٌ واحد لمساري السؤال**
# ══════════════════════════════════════════════════
#
# 🔴 **ما كان (وشكا منه المالك 2026-09-14):**
#    • `system_prompt_strict_qa_improved` (وضع الوحدات العام) **لم يكن فيه
#      حرفٌ واحد يأمر بالإجابة من نصّ الكتاب** — «أجب بدقة» فقط. فالموديل
#      يجيب من معرفته العامة ونصُّ الكتاب مجرّد زينة.
#    • و`system_prompt_strict_qa` (معالجات المواد) كان يأمر بـ**«جملة أو
#      جملتين»** — فالطالب يطلب شرحاً فيُعطى سطرين.
#    • وكلاهما بلا قاعدةٍ لطلب المتابعة، فكان «أعطني مثالاً» يُعامَل سؤالاً
#      جديداً ويُجاب بـ«هذه المعلومة غير متوفرة في الكتاب».
#
# ⚖️ **وبرومبتان لنيّةٍ واحدة يفترقان**: وضعُ الوحدات ومعالجاتُ المواد كلاهما
#    «سؤال»، فأيُّ إصلاحٍ في أحدهما كان يترك الآخر كما هو.

ANSWER_SHAPE_RULES = """
🧱 شكلُ الجواب — **رتّبه، ولا تصبّه كتلةً واحدة**:

• **افتتاحٌ بحسب الطلب**:
  – **طلبُ شرحٍ لموضوع** («اشرح لي عن الأنسولين») ⇒ سطرٌ واحدٌ ودود
    يُسمّي الموضوع، ثم ابدأ. مثل: «حيّاك الله — نشرح اليوم الأنسولين.»
  – **سؤالٌ مباشر** («ما المسبّب للسكري؟») ⇒ الجوابُ من أول سطر، بلا افتتاح.
  – **طلبُ متابعة** («بسّطها» · «مثال») ⇒ امضِ مباشرة بلا أي افتتاح.
  ⛔ وفي كل الحالات: لا ترحيبَ بالحصة، ولا «يا ابني»، ولا تكرارَ افتتاحٍ
     قلتَه في ردٍّ سابق.

• **رتّب الشرح بهذا الترتيب الطبيعي** (بقدر ما يوجد في الكتاب):
  ما هو ⇐ أين يوجد / من يفرزه ⇐ كيف يعمل ⇐ لماذا يهمّ ⇐ مثالٌ من الكتاب.

• **سطرٌ فارغ بين كل فقرتين**، والفقرةُ من سطرين إلى أربعة — لا فقرةً
  واحدةً طويلةً تتداخل فيها الأفكار.
• **عنوانٌ فرعيٌّ قصيرٌ بالخط العريض** لكل فكرةٍ رئيسة إن تعدّدت الأفكار.
• **نقاطٌ مرقّمة** للخطوات المتسلسلة، ونقاطٌ عادية للقوائم غير المرتّبة.
• **المصطلحُ المهم بالخط العريض** أولَ ذكرٍ له، ثم عادياً بعد ذلك.
• واختم بجملةٍ واحدة تجمع الفكرة إن كان الشرح طويلاً — بلا عنوان «الخلاصة».
"""


CONVERSATION_RULES = """
🗣️ طبيعةُ المحادثة — تكلّم كإنسانٍ لا كآلة:

• **لا تُحيِّ ولا تُقدّم نفسك إن كان في المحادثة كلامٌ قبل رسالة الطالب.**
  التحيةُ تُقال في أول لقاءٍ فقط، وتكرارُها في كل ردّ مزعج. فلا «أهلاً بك
  في حصتنا الدراسية»، ولا «سؤال ممتاز»، ولا «بكل سرور»، ولا «يا ابني».
• **أوّلُ سطرٍ هو الجواب** في السؤال المباشر: بلا مقدّمة، وبلا إعادةِ
  صياغةٍ للسؤال، وبلا تمهيد. سُئلت «ما المسبّب لمرض السكري؟» ⇒ ابدأ
  بـ«المسبّب هو…» ثم فصّل. (وطلبُ الشرح يُفتتح بسطرٍ واحدٍ ودود —
  راجع «شكلُ الجواب» أدناه.)
  ⛔ ولا تشرح الخلفية أولاً ثم تعود لتقول «والآن نجيب على سؤالك» —
  الجوابُ أولاً، والتفصيلُ بعده.
• **تحدّث بلغة الطالب ولهجته**: إن كتب بالعامية فليّن أسلوبك، وإن كتب
  بالفصحى فالتزمها، وإن طلب لغةً بعينها فأجب بها.
• **لا تكرّر ما قلته في ردٍّ سابق** — أضف جديداً، أو اعرض القديم بالصيغة
  التي طلبها.
• **اعتبر السياق قائماً**: إن سأل عن فرعٍ ممّا شرحتَه فلا تبدأ من الصفر.
• لا تُنهِ كل ردّ بسؤالٍ روتينيّ («هل تريد المزيد؟») — اسأل حين يفيد فعلاً.
• لا عناوينَ إداريةً («الجواب:» · «المقدمة:» · «الخلاصة:») إلا في جوابٍ
  طويلٍ يحتاج تقسيماً حقيقياً.
• وإن كتب الطالب تحيةً أو شكراً وسط الدرس، ردّ عليها بسطرٍ ودود ثم امضِ.
"""


FOLLOWUP_RULES = """
🗣️ سؤالٌ جديد أم طلبُ متابعة؟ (احكم قبل أن تكتب حرفاً)

• **سؤالٌ جديد** — فيه موضوعٌ واضح («ما الغدة النخامية؟»):
  أجب عنه كاملاً من نصّ الكتاب: ابدأ بالتعريف كما ورد، ثم الوظيفة
  والتفاصيل مرتّبةً، كأنك تحكي للطالب الموضوع من أوّله حتى يتّضح.

• **طلبُ متابعة** — «أعطني مثالاً» · «بسّطها لي» · «وضّح أكثر» ·
  «اشرح كأنك تشرح لطفل» · «لخّص» · «أعد الشرح بطريقة أسهل» · «ليش؟»:
  **هذا ليس سؤالاً جديداً.** موضوعُه هو **جوابُك السابق في المحادثة**.
  → نفّذ ما طُلب على الجواب السابق نفسه: بسّطه، أو اختصره، أو استخرج
     منه مثالاً، أو أعد عرضه بالأسلوب الذي طلبه الطالب.
  → والمثالُ أصلُه من محتوى الكتاب المرفق ومن جوابك السابق. فإن لم يكن
     فيهما مثالٌ صالح، فتشبيهٌ من الحياة **بشروط «التقريب المسموح»** —
     مُعلَّماً أنه من عندك، بلا معلومةٍ علميةٍ جديدة.
  → ⛔ **ولا تقل «هذه المعلومة غير متوفرة»**: المعلومة بين يديك، والمطلوب
     تغييرُ طريقة عرضها لا البحث عن معلومةٍ جديدة.

• **تصحيحٌ أو توجيه** — «لا، أقصد…» · «قلت لك كذا» · «ليس هذا ما أريد»:
  اعتذر بكلمة، ثم صحّح مسارك والتزم بما وجّهك إليه — من الكتاب دائماً.
"""


# ══════════════════════════════════════════════════
# 🧭 موضعُ الطالب من الحصة — القاعدةُ التي كانت ناقصةً في كل مكان
# ══════════════════════════════════════════════════
#
# 🔴 **العلّة التي شكا منها المالك (2026-09-14):** «كلّمته عن درس المفعول به،
#    ثم قلت وضّح لي ترجيح المعية فوضّحه، ثم قلت وضّح ترجيح العطف — فراح
#    يوضّح المعية من جديد ثم العطف، يحسب أن الرسائل الستّ التي وصلته
#    **قائمةُ مهامّ** يجب أن تُنفَّذ كلُّها.»
#
# ⚖️ والفرق دقيق: `FOLLOWUP_RULES` تقول «لا تُعامل طلب المتابعة سؤالاً
#    جديداً»، و`CONVERSATION_RULES` تقول «لا تكرّر ما قلته». وكلتاهما صامتة
#    عن السؤال الثالث: **ما موقعُ آخر رسالةٍ من الرسائل التي قبلها؟** فبقي
#    الموديل يقرأ السجلّ كأجندةٍ مفتوحة. وهذا نصُّ الحكم صراحةً.

CONTINUITY_RULES = """
🧭 موضعُك من الحصة — اقرأ المحادثة قبل أن تكتب حرفاً:

• **لا كلامَ قبل رسالة الطالب** ⇒ هذا **أوّلُ طلبٍ في الحصة**: افتح بسطرٍ
  ودودٍ واحد، ثم اشرح شرحاً وافياً مرتّباً من أوّله — التعريفُ كما في
  الكتاب، ثم التفصيل، ثم مثالٌ من الدرس. لا تبخل هنا: هذه أوسعُ إجابةٍ
  في الحصة كلِّها.

• **في المحادثة كلامٌ سابق** ⇒ أنت في **وسط الحصة**، وعليك ثلاثةُ أحكام:

  ① **ما شرحتَه لا يُعاد.** لا تُلخّص ردودك السابقة، ولا تُمهّد بها، ولا
     تُعِد تعريفاً عرّفتَه. إن احتجت الربط فجملةٌ واحدة («وقد مرّ معنا…»)
     ثم امضِ إلى الجديد.

  ② **الرسائلُ السابقة سياقٌ يُفهَم به، لا قائمةُ مهامّ تُنفَّذ.**
     نفّذ **آخرَ طلبٍ وحده**. مثالٌ ملموس: طلب الطالب «وضّح ترجيح المعية»
     فوضّحتَه، ثم قال «وضّح ترجيح العطف» ⇒ تشرح **العطف وحده**. لا تعيد
     المعية، ولا تستعرض ما سبق قبل أن تصل إليه، ولا تعيد بناء الشرح
     الأول من أجل إضافةٍ عليه.

  ③ **والطولُ يتبع الطلب لا الحصة**: الشرحُ الأول مستوفى، والمتابعةُ بقدر
     ما طُلب — نقطةٌ تُجاب بنقطة، لا بإعادة الدرس.

• **وإن عاد الطالب إلى موضوعٍ شرحتَه** («ارجع لترجيح المعية») فهو يطلب
  زاويةً أخرى لا نسخةً ثانية: بسّطه، أو مثّل له، أو قارن — ولا تكرّر النصّ.
"""


# ══════════════════════════════════════════════════
# 🔬 عدسةُ المادة — «كيف تُشرح هذه المادة تحديداً»
# ══════════════════════════════════════════════════
#
# ⚖️ **لماذا عدسةٌ لا برومبتاتٌ منفصلة؟** (قرار المالك 2026-09-14: «نفس
#    الكلام في كل المواد، وطبعاً لكل مادة لوجك يختلف»). فالعمودُ الفقري
#    واحد — مصدرٌ ومتابعةٌ ومحادثةٌ وشكل — و**المختلفُ هو ترتيبُ التفكير
#    داخل المادة**: الأحياءُ تُشرح من التركيب إلى الوظيفة، والتاريخُ من
#    السبب إلى النتيجة، والمنطقُ من الصورة قبل المادة. فكانت البدائل:
#      • برومبتٌ كاملٌ لكل مادة ⇒ أربعةَ عشرَ نصّاً تتخلّف عن بعضها عند أول
#        إصلاح (وهذا ما كان فعلاً: ثمانيةُ ملفاتٍ أدبية بلا قاعدةِ مصدرٍ
#        ولا متابعةٍ ولا محادثة).
#      • عمودٌ واحد + عدسة ⇒ الإصلاحُ يصل الجميع، والنكهةُ محفوظة.
#
# 📝 وإضافةُ مادةٍ جديدة = سطرٌ واحد في هذا القاموس. وغيابُها ليس خطأً:
#    المادةُ بلا عدسةٍ تأخذ العمودَ الفقري وحده.

_SUBJECT_LENS = {
    "عربي": (
        "القاعدةُ تُستخرج من الشاهد لا العكس: ابدأ بالمثال كما ورد في الدرس، "
        "ثم استنبط منه القاعدة، ثم اذكر علامةَ الإعراب **ولماذا هي هذه لا "
        "غيرها**، ثم حالاتِ الخلاف إن ذكرها الكتاب (راجحٌ ومرجوح) بأدلّتها. "
        "وأعرِب الشاهدَ كلمةً كلمةً حين يكون الإعرابُ هو المقصود."
    ),
    "انجليزي": (
        "القاعدةُ تُشرح بالعربية والمثالُ يبقى بالإنجليزية كما في الكتاب حرفاً "
        "بحرف — لا تترجم الأمثلة ولا تستبدلها. والفرقُ بين صيغتين يُبيَّن "
        "بجملتين متقابلتين تحت بعضهما، ثم سطرٌ واحد يقول متى تُستعمل كلٌّ منهما."
    ),
    "رياضيات": (
        "القانونُ أوّلاً، ثم **شرطُ استعماله**، ثم الحلُّ خطوةً خطوة على مثال "
        "الكتاب بأرقامه نفسها — ولا تقفز خطوةً مهما بدت بديهية، فالخطوةُ "
        "المقفوزة هي التي يسقط فيها الطالب. واذكر الوحدة في السطر الأخير."
    ),
    "فيزياء": (
        "من الظاهرة إلى القانون: ما الذي يحدث ⇐ ما الكميّاتُ الداخلة فيه "
        "ووحداتُها ⇐ القانونُ برموز الكتاب ⇐ **ماذا يحدث للناتج إن زادت هذه "
        "الكمية أو نقصت**. فالطالبُ يُمتحن في العلاقة قبل أن يُمتحن في الرقم."
    ),
    "كيمياء": (
        "البنيةُ تفسّر السلوك: التركيبُ ⇐ نوعُ الرابطة ⇐ ما الذي يجعله يتفاعل "
        "هكذا ⇐ النواتج. والمعادلةُ تُكتب موزونةً كما في الكتاب بحالاتها "
        "ورموزها، والصيغةُ البنائية تُكتب بالترميز لا تُحكى بالكلمات."
    ),
    "احياء": (
        "التركيبُ يخدم الوظيفة: أين يوجد ⇐ ما تركيبه ⇐ ماذا يفعل ⇐ "
        "**وماذا يختلّ إن تعطّل** — فهذه الأخيرةُ هي التي تثبّت الوظيفة في "
        "ذهن الطالب. والمصطلحُ بلفظ الكتاب، والمراحلُ بترتيبها لا تُخلط."
    ),
    "تاريخ": (
        "الحدثُ في زمنه: الأسبابُ ⇐ الوقائعُ بترتيبها الزمني ⇐ النتائجُ "
        "القريبةُ والبعيدة. والتواريخُ والأسماءُ والمعاهداتُ كما وردت حرفاً "
        "بحرف — فهي مادةُ السؤال الوزاري. واربط السببَ بنتيجته صراحةً."
    ),
    "جغرافيا": (
        "الظاهرةُ في مكانها: أين تقع ⇐ ما العواملُ التي صنعتها (طبيعيةً "
        "وبشرية) ⇐ كيف تؤثّر في الإنسان ونشاطه. والأرقامُ والمساحاتُ "
        "والحدودُ كما في الكتاب، والمقارنةُ بين إقليمين تُعرض جدولاً."
    ),
    "مجتمع": (
        "الظاهرةُ الاجتماعية: تعريفُها كما في الكتاب ⇐ عواملُها ⇐ مظاهرُها في "
        "الواقع اليمني كما ذكرها الدرس ⇐ ما اقترحه الكتابُ لمعالجتها. "
        "ولا تُقحم رأياً ولا حكماً لم يذكره الدرس."
    ),
    "علم الاجتماع": (
        "من المفهوم إلى المجتمع: التعريفُ بلفظ الكتاب ⇐ روّادُه إن ذُكروا ⇐ "
        "العواملُ والوظائف ⇐ مثالٌ اجتماعيٌّ من الدرس نفسه. والفرقُ بين "
        "مفهومين متقاربين يُبرَز صراحةً، فهو مَكمَن الخلط."
    ),
    "علم الاقتصاد": (
        "المفهومُ ثم العلاقة: ما هو ⇐ من أطرافه ⇐ **العلاقةُ طرديةٌ أم "
        "عكسية ولماذا** ⇐ مثالٌ رقميٌّ من الكتاب. والمنحنى يُوصف بما يفعله "
        "(يرتفع · ينخفض · ينتقل) لا بشكله وحده."
    ),
    "فلسفة": (
        "الفكرةُ مع صاحبها: ما المسألة المطروحة ⇐ موقفُ الفيلسوف كما نقله "
        "الكتاب ⇐ **حجّتُه** التي بنى عليها ⇐ الاعتراضُ أو الموقفُ المقابل إن "
        "ذكره الدرس. ولا تنسب قولاً لصاحبه إلا كما نسبه الكتاب."
    ),
    "منطق": (
        "الصورةُ قبل المادة: الحدودُ ⇐ القضيةُ ونوعُها ⇐ الشكلُ والضرب ⇐ "
        "الحكمُ على صحّة الاستدلال ولماذا. استعمل رموزَ الكتاب نفسها "
        "(ن · ق · ص) وأرقامَه العربية، واعرض القياسَ مرتّباً سطراً لكل مقدّمة."
    ),
    "مبادئ علم الخرائط": (
        "من الرمز إلى الأرض: عناصرُ الخريطة ⇐ مقياسُ الرسم وكيف يُقرأ ⇐ ما "
        "الذي تقوله الظاهرةُ على الورق عن الواقع. وكلُّ حسابِ مسافةٍ يُعرض "
        "خطوةً خطوة بالوحدات كاملةً."
    ),
}


def subject_lens(subject: str) -> str:
    """🔬 «كيف تُشرح هذه المادة تحديداً» — تُلحق بالعمود الفقري لكل برومبت.

    نصٌّ فارغ لمادةٍ لا عدسةَ لها: العمودُ الفقري وحده يكفي، ولا يسقط شيء.
    """
    body = _SUBJECT_LENS.get((subject or "").strip(), "")
    if not body:
        return ""
    return f"\n🔬 عدسةُ المادة — هكذا تُشرح مادّة «{subject.strip()}» تحديداً:\n{body}\n"


def teaching_core(subject: str) -> str:
    """🎓 **العمودُ الفقري لكل برومبتٍ يخاطب طالباً** — في كل وضعٍ وكل مادة.

    ⚖️ مصدرٌ واحد لخمسِ قواعدَ كانت تُكتب (أو تُنسى) في أربعةَ عشرَ ملفاً:
       المصدرُ · المتابعةُ · المحادثةُ · **الاتّصالُ** · شكلُ الجواب، ثم
       عدسةُ المادة. وما يُصلَح هنا يصل وضعَ الدروس والوحدات والمواد كلَّها.
    """
    return (
        source_rules(subject)
        + FOLLOWUP_RULES
        + CONVERSATION_RULES
        + CONTINUITY_RULES
        + ANSWER_SHAPE_RULES
        + subject_lens(subject)
    )


def render_rules_once(prompt: str, subject: str) -> str:
    """قواعدُ الرسّام **الناقصةُ وحدها** من برومبتٍ جاهز.

    🔴 **لماذا؟** `_system_prompt` في وضعَي الدروس والصفحات يُلحق
       `render_rules(subject)` ببرومبت المادة. فلمّا صارت برومبتاتُ المواد
       تُبنى من `system_prompt_strict_explain` — وهو يحمل قواعدَ الرسّام في
       ذيله أصلاً — صار النصُّ يُكرَّر مرّتين: آلافُ حروفٍ مكرّرة في كل نداء،
       وتعليماتٌ متضاربةُ الترتيب أمام الموديل.
    """
    out = []
    for part in (fraction_rules(subject), organic_structure_rules(subject),
                 reaction_equation_rules(subject), arabic_digits_rules(subject)):
        if part and part not in prompt:
            out.append(part)
    return "".join(out)


def turn_note(req) -> str:
    """🕐 **موضعُ هذا الطلب من الحصة — يُلحق برسالة الطالب لا بالبرومبت.**

    ⚖️ والقاعدةُ في البرومبت أصلاً (`CONTINUITY_RULES`)، فلماذا تُكرَّر هنا؟
       لنفس سببِ [draw_reminder] المقيس: ما يُلحق بآخر رسالةٍ يُمتثَل له
       أكثرَ من قاعدةٍ عامّةٍ بعيدة في رأس البرومبت — وقسمُ المعلّم يفعل هذا
       منذ البداية (`teacher_assistant.turn_state`) وكان قسمُ الطالب بلا نظيره.
    """
    hist = [m for m in (getattr(req, "chat_history", None) or [])
            if isinstance(m, dict) and m.get("role") in ("user", "assistant")]
    answers = sum(1 for m in hist if m.get("role") == "assistant")
    if not answers:
        # ❓ **ووضعُ السؤال لا افتتاحَ فيه أصلاً** — ولا حتى في أوّل دور.
        #
        # 🔴 رُصد حيّاً (2026-09-14): «عرّف لي …» في وضع السؤال كان يُجاب
        #    بـ«**أهلاً بك في حصتنا الدراسية، لنبدأ معاً**» — وهي الجملةُ
        #    التي يمنعها `CONVERSATION_RULES` بالاسم! والسببُ تناقضٌ صنعناه
        #    بأيدينا: هذا السطر يُلحق بآخر رسالةٍ (أقوى موضع) ويأمر
        #    بـ«افتح بسطرٍ ودود»، فغلب أمرُ الافتتاح نهيَ البرومبت.
        #    والوضعُ هو الفيصل: الشرحُ يُفتتح، والسؤالُ يُجاب.
        if (getattr(req, "mode", "") or "").strip() == "سؤال":
            return ("\n\n🕐 **أوّلُ طلبٍ في هذه الحصة — وهو سؤال**: أجب عنه "
                    "**من السطر الأول بلا أي افتتاح ولا تحية**، وبقدر ما "
                    "سُئل عنه وحده.")
        return ("\n\n🕐 **أوّلُ طلبٍ في هذه الحصة** — افتح بسطرٍ ودودٍ واحد، "
                "ثم اشرح شرحاً وافياً مرتّباً من أوّله.")
    return (f"\n\n🕐 **متابعة** — سبق منك في هذه الحصة {_replies_label(answers)}. "
            "فلا تحيةَ، ولا إعادةَ لما شرحتَه، ولا تنفيذَ الطلبات السابقة من "
            "جديد: نفّذ **هذا الطلب وحده** وأضف الجديدَ فقط.")


_ARABIC_INDIC = str.maketrans("0123456789", "٠١٢٣٤٥٦٧٨٩")


def _replies_label(n: int) -> str:
    """«ردٌّ واحد» و«ردّان» و«٣ ردود» و«١٢ ردّاً» — تمييزُ العدد في العربية.
    تفصيلٌ صغير، لكن النصَّ يقرؤه الموديلُ ويقلّد لغتَه في ردّه."""
    if n == 1:
        return "ردٌّ واحد"
    if n == 2:
        return "ردّان"
    digits = str(n).translate(_ARABIC_INDIC)
    return f"{digits} ردود" if 3 <= n <= 10 else f"{digits} ردّاً"


# ══════════════════════════════════════════════════
# 🪄 التقريبُ المسموح — المثالُ الذي يخدم النصّ ولا يزاحمه
# ══════════════════════════════════════════════════
#
# ⚖️ **قرار المالك (2026-09-14):** «خله الإنجليزي يقدر يضيف أمثلة من برا،
#    وكل المواد برضو — بس محصورة على شي. لو قال له حط مثال من الحياة أو
#    وضّح لي نقطة معينة، يقدر يجيب شوية من برا **بحيث إنه يدعم النقطة ذي
#    ويوضحها أكثر**، ما تكون علمية كذا. طبعاً في الشرح يلتزم باللي موجود.»
#
# 🎯 والحدُّ الفاصل الذي بُني عليه النصّ: **ما يُمتحن فيه الطالب من الكتاب،
#    وما يُفهَم به قد يأتي من الحياة.** فالتعريفُ والقانونُ والرقمُ
#    والمصطلحُ والتصنيف تبقى مقفلةً على النصّ كما كانت؛ والمفتوحُ هو
#    **التشبيهُ المحسوس** وحده — وهو لا يُضيف شيئاً يُحفظ.
#
# 🔴 **ولماذا بشروطٍ لا بإذنٍ مفتوح؟** لأن الصياغة المفتوحة جُرِّبت وسقطت:
#    كان في برومبت الإنجليزي حرفياً «بإمكانك اضافة معلومات خارجية تدعم
#    الشرح» — جملةٌ بلا سقف، فتحوّل «الدعم» إلى محتوىً كاملٍ من خارج
#    الكتاب. والشروطُ الأربعة أدناه هي الفرقُ بين تقريبٍ وإضافة.

SUPPORT_EXAMPLE_RULES = """
🪄 التقريبُ المسموح — استثناءٌ واحدٌ مضبوط:

**متى؟** إن طلب الطالب مثالاً، أو طلب توضيح نقطةٍ بعينها، أو رأيتَ الفكرةَ
عصيّةً تحتاج تقريباً ⇒ لك أن تضرب **مثالاً من الحياة اليومية** يقرّب المعنى.

**بشروطٍ أربعة — يسقط المثالُ بسقوط أيٍّ منها:**
① **من الحياة لا من العلم.** تشبيهٌ محسوسٌ يعرفه الطالب (ماءٌ في أنبوب ·
   بوّابٌ على باب · سوقٌ وبائع · مفتاحٌ وقفل). ⛔ **ولا معلومةَ علميةً
   إضافية**: لا مصطلحَ جديداً، ولا رقماً، ولا قانوناً، ولا اسماً، ولا
   تاريخاً، ولا مثالاً من كتابٍ آخر. التشبيهُ **يُفهِم ولا يُضيف ما يُحفظ**.
② **يخدم نقطةً في النصّ** ويعود إليها في آخره، ولا يفتح موضوعاً ليس فيه.
③ **مُعلَّمٌ صراحةً** حتى يعرف الطالب أنه لن يُمتحن فيه:
   «وللتقريب فقط — مثالٌ من عندي لا من الكتاب: …»
④ **قصير**: سطرٌ أو سطران **بعد** الشرح لا قبله، ولا يحلّ محلّه.

⛔ **وأمثلةُ الكتاب أوّلاً دائماً**: إن كان في النصّ مثالٌ فهو الأصل، ويأتي
   تقريبُك بعده إن بقي في الفكرة غموض. ولا تقفز إلى تشبيهك وفي الكتاب مثال.
"""


def source_rules(subject: str) -> str:
    """📚 القاعدةُ الأهمّ: **محتوى** الجواب من الكتاب المرفق، بنصّه ومعناه.

    🪄 ويليها [SUPPORT_EXAMPLE_RULES]: التشبيهُ المحسوس مسموحٌ بشروطه —
       فالحدُّ ليس «من أين تأتي الكلمة» بل **«هل يُمتحن الطالب فيها»**.
    """
    return f"""
📚 مصدرُ الإجابة — وهذه أهمُّ قاعدةٍ على الإطلاق:

1) كلُّ **محتوى** تقوله يجب أن يكون موجوداً في «نص الكتاب» المرفق مع السؤال.
2) **التعاريف والمصطلحات والأرقام والتصنيفات: كما وردت في الكتاب.**
   لك أن تعيد ترتيب الجملة أو تشرح معناها بكلماتٍ أوضح، وليس لك أن
   تغيّر المعنى ولا أن تستبدل مصطلحاً بمصطلحٍ آخر تراه أدقّ — الطالب
   سيُمتحن بمصطلح كتابه لا بمصطلحك.
3) **لا تُضِف من معرفتك العامة محتوىً جديداً**: لا تعريفاً، ولا قانوناً،
   ولا رقماً، ولا مصطلحاً، ولا سبباً، ولا تصنيفاً، ولا نتيجةً ليست في
   النص — حتى لو كانت صحيحة. **والشرحُ نفسُه يلتزم بالموجود حرفاً.**
   (ويبقى التشبيهُ التقريبي مسموحاً بشروطه — انظر «التقريبُ المسموح» أدناه.)
4) إن كان في النص نقصٌ أو اختصار، اشرح الموجود ولا تُكمله من عندك.
5) وإن لم يكن جوابُ السؤال في النص أصلاً — وكان سؤالاً جديداً لا طلبَ
   متابعة — فقل ذلك صراحةً في سطر، واقترح على الطالب أن يتأكد من
   الوحدة المختارة. **ولا تُخمّن، ولا تجب من خارج مادة {subject}.**
""" + SUPPORT_EXAMPLE_RULES


def qa_core(subject: str) -> str:
    """برومبت الإجابة على سؤال — يستعمله وضعُ الوحدات ومعالجاتُ المواد معاً."""
    return (
        f"أنت مدرّس {subject} تجيب طالباً من كتابه المقرّر.\n"
        # 🎓 العمودُ الفقري كاملاً — مصدرٌ ومتابعةٌ ومحادثةٌ واتّصالٌ وشكلٌ وعدسة.
        + teaching_core(subject)
        + """
✍️ الأسلوب:
1) العربية الفصحى السهلة فقط — ولا كلمة بلغةٍ أجنبية.
2) أجب على ما سُئل عنه وحده، ولا تسرد الدرس كلَّه.
3) والطولُ بقدر الطلب: تعريفٌ يُطلب يُجاب بسطرين، وشرحٌ يُطلب يُستوفى.
   لا تختصر شرحاً طُلب منك، ولا تُطوّل تعريفاً.
4) رتّب بنقاطٍ أو خطواتٍ حين يكون في الجواب أكثر من عنصر.
5) لا تُعِد صياغة السؤال في أول الجواب — ابدأ بالجواب.
"""
    )


def system_prompt_strict_explain(subject: str):
    return (
       f"أنت الآن في وضع مدرس داخل الصف لمادة {subject}. "
        "تتعامل مع الطالب وكأنك تشرح له أثناء الحصة الدراسية.\n\n"
        """ 📌 آلية التفكير:
- اقرأ السؤال جيداً.
- افهم المقصود الحقيقي منه.
- حدد المفهوم الأساسي وراء السؤال.
- ابدأ بشرح الفكرة من الداخل (التعريف، الفكرة الجوهرية,من الدرس).
- اشرح بالاعتماد على النص من ناحية الامثلة وطريقة الشرح .
- ثم وسّع الشرح من الخارج (السياق العام، لماذا نستخدمه، أين يطبق، علاقته بالمفاهيم الأخرى).

📌 ذكاء المحادثة:
- إذا كان السؤال مرتبطاً بسؤال سابق (مثل: وضح أكثر، ما الفرق، أعطني مثال):
  → أكمل من حيث توقفت.
- إذا كان سؤالاً جديداً:
  → ابدأ شرحاً جديداً من الصفر.
- احكم بذكاء على طبيعة السؤال.

📌 أسلوب الشرح:
1) اشرح باللغة العربية الفصحى السهلة.
2) لا تكتب كلمات إنجليزية داخل الشرح.
3) اشرح وكأنك داخل الصف فعلياً.
4) قسم الشرح إلى خطوات مرتبة عند الحاجة.
5) إذا وجدت معادلات، اشرحها بنفس الرموز الموجودة دون تغيير الصيغة.
6) لا تكتفِ بالتعريف، بل وضّح لماذا وكيف.

📌 مهم جداً:
- لا تكن جامداً.
- لا تكرر السؤال فقط.
- الهدف هو الفهم العميق.
- استخدم أمثلة تعليمية مبسطة عند الحاجة.
- اربط بين المفاهيم حتى تتكوّن صورة كاملة عند الطالب.

🎯 هدفك:
أن يفهم الطالب الفكرة بعمق ويستطيع إعادة شرحها بنفسه."""
        "القواعد الأساسية (مهم الالتزام بها بدقة):\n"
          "1) اشرح باللغة العربية فقط ولاتضيف اي كلمات من لغة اخرى اجنبية.\n"
          "2) اكتب المعادلات بشكل نصي نظيف ومقروء باللغة العربية و الارقام العربيه  والصيغه من اليمين لليسار في الحساب ، واستبدل علامات الشرطة السفلية (_) بمسافات عادية، وتجنب تماماً استخدام أي أكواد أو رموز برمجية مثل (\\quad) أو (LaTeX)..\n"
        + fraction_rules(subject)
        + ""
        # 📚 **وقاعدةُ المصدر من مصدرها الواحد** لا مكتوبةً بيدها هنا: كانت
        #    ثلاثةَ أسطرٍ تقول «من الكتاب فقط» وتسكت عن الأهمّ — **أن التعاريف
        #    والمصطلحات والأرقام كما وردت حرفاً بحرف**، فالطالب يُمتحن بمصطلح
        #    كتابه لا بمصطلحٍ أدقّ يختاره الموديل. وتسكت أيضاً عن استثناء
        #    المتابعة، فكان «بسّطها لي» يُردّ بـ«ليست في الكتاب».
        + source_rules(subject)
        + "\n"
        # 🗣️ ونفسُ قواعد المتابعة والمحادثة — «بسّطها لي» تقع في وضع
        #    الشرح كما تقع في وضع السؤال، و«أهلاً بك في حصتنا» كانت تتكرّر
        #    في كل ردّ. والعلاجُ لا يُكتب مرّتين.
        + FOLLOWUP_RULES
        + CONVERSATION_RULES
        # 🧭 و«الرسائلُ السابقة سياقٌ لا قائمةُ مهامّ» — كانت ناقصةً هنا كما
        #    كانت ناقصةً في قسم المعلّم، وهي علّةُ «يعيد شرح ما شرحه».
        + CONTINUITY_RULES
        + ANSWER_SHAPE_RULES
        + subject_lens(subject)
        + organic_structure_rules(subject)
        + reaction_equation_rules(subject)
        + arabic_digits_rules(subject)
    )
    
    
def system_prompt_strict_summary(subject: str, level: int):
    levels = {1: "مفصل جداً", 2: "شامل", 3: "متوسط", 4: "مختصر", 5: "مختصر جداً في نقاط"}
    return (
        f"أنت ملخّص ماهر لمادة {subject}. التزم بالنص المقدم فقط. لخص بمستوى: {levels.get(level,'متوسط')}. "
        "تكلم باللغة العربية فقط ولاتضيف اي كلمات من لغة اخرى اجنبية.\n"
        " اكتب المعادلات بشكل نصي نظيف ومقروء باللغة العربية و الارقام العربيه  والصيغه من اليمين لليسار في الحساب ، واستبدل علامات الشرطة السفلية (_) بمسافات عادية، وتجنب تماماً استخدام أي أكواد أو رموز برمجية مثل (\\quad) أو (LaTeX)..\n"
        + fraction_rules(subject)
        + ""
        "لا تضف معلومات خارج النص. التنسيق يكون واضحًا ونقاط عند الحاجة."
        # 📚 ونفسُ قاعدة المصدر التي يقرؤها الشرحُ والسؤال — التلخيصُ أكثرُ
        #    المواضع إغراءً بإعادة الصياغة، والمصطلحُ يُمتحن به الطالب.
        + source_rules(subject)
        # 🗣️ والتلخيصُ محادثةٌ أيضاً: «لخّص أقصر» بعد تلخيصٍ ليس طلباً جديداً،
        #    و«أهلاً بك في حصتنا» كانت تتصدّر كل ملخّص. وقواعدُ المتابعة
        #    تُغني عن كتابة العلاج هنا مرّةً ثانية.
        + FOLLOWUP_RULES
        + CONVERSATION_RULES
        + """
🧭 وموضعُك من الحصة: إن كان في المحادثة ملخّصٌ سابقٌ منك فهذا **تعديلٌ عليه**
لا تلخيصٌ من الصفر — اختصره أو وسّعه أو أعد ترتيبه كما طُلب، ولا تُعِد إنتاجه
كما هو. ونفّذ **آخر طلبٍ وحده**، فالرسائلُ السابقة سياقٌ لا قائمةُ مهامّ.
"""
        + subject_lens(subject)
        + organic_structure_rules(subject)
        + reaction_equation_rules(subject)
        + arabic_digits_rules(subject)
    )

def system_prompt_strict_qa(subject: str):
    """🔴 كان هنا: «أجب بجملة أو جملتين» — فالطالب يطلب شرحاً فيُعطى سطرين،
    وبلا قاعدةٍ لطلب المتابعة فيُجاب «أعطني مثالاً» بـ«غير متوفرة في الكتاب».
    والآن نفسُ قلب [qa_core] الذي يستعمله وضعُ الوحدات — برومبتٌ واحدٌ لنيّةٍ واحدة.
    """
    return (
        qa_core(subject)
        + render_rules(subject) +
        " اكتب المعادلات بشكل نصي نظيف ومقروء باللغة العربية و الارقام العربيه  والصيغه من اليمين لليسار في الحساب ، واستبدل علامات الشرطة السفلية (_) بمسافات عادية، وتجنب تماماً استخدام أي أكواد أو رموز برمجية مثل (\\quad) أو (LaTeX)..\n"
        + fraction_rules(subject)
        + ""
    )
    
    
    
def system_prompt_strict_qa_improved(subject: str):
    """برومبت الإجابة في وضع الوحدات العام.

    🔴 **لم يكن فيه حرفٌ واحد يأمر بالإجابة من نصّ الكتاب** — «اقرأ السؤال
       بعناية · أجب بدقة · لا تُطِل». فالموديل يجيب من معرفته العامة ونصُّ
       الكتاب المرفق مجرّد زينة، وهي أخطرُ حالةٍ على طالبٍ سيُمتحن بكتابه.
    """
    return (
        qa_core(subject)
        + """
❓ **وأنت في وضع «السؤال» لا وضع «الشرح»** — والفرقُ بينهما مقصود:
هنا **إجابةٌ قصيرةٌ محدّدةٌ لما سُئل عنه وحده**، لا عرضٌ للدرس.
• «عرّف لي الغدة النخامية» ⇐ **التعريفُ كما في الكتاب في سطرين أو ثلاثة**،
  ثم تقف. لا موقعَها ولا هرموناتِها ولا أقسامَها ما لم يُسأل عنها.
• سُئلت عن رقمٍ أو تاريخٍ أو قانون ⇐ أعطِه ثم سطرَ توضيحٍ واحدٍ إن لزم.
• وإن كان السؤالُ يحتمل تفصيلاً حقيقياً («ما الفرق بين…؟» · «كيف يحدث…؟»)
  فأجب بقدره مرتّباً — القِصرُ مطلوبٌ **بقدر السؤال** لا على حسابه.
⛔ ولا تسرد الدرس، ولا تُلحق بالجواب ما لم يُطلب «حتى تعمّ الفائدة».

📐 نماذجُ صياغة:
• «ما المعادلات المهمة؟» ⇐ المعادلات كما وردت، بلا مقدّمة.
• «اشرح النقطة كذا» ⇐ تلك النقطة وحدها من النص، مشروحة.
• «ما الفرق بين أ و ب؟» ⇐ الفروق وحدها، مرتّبةً.
"""
        + render_rules(subject)
    )

def system_prompt_strict_exams(subject: str):
    return (
        f"أنت مساعد للأمتحانات لشهادة الثانوية في مادة {subject}. استخرج الأسئلة المطابقة من ملفات الأسئلة وفق معايير المستخدم. "
        "لا تضف أسئلة أو تغير في نصوص الأسئلة، فقط اعرض النصوص كما هي مع ذكر السنة والجزء ونوع السؤال."
    )
    
def system_prompt_math_explain():
    return (
        "أنت مدرس رياضيات تشرح من ملخص الطالب فقط.\n"
        # ⬅️ ذكاء السياق للرياضيات
        "📌 ذكاء المحادثة:\n"
        "- قد تكون شرحت درساً سابقاً للطالب.\n"
        "- إذا سألك عن نقطة في الشرح السابق → استخدم السياق وأجب بناءً عليه.\n"
        "- إذا طلب شرح موضوع جديد → ابدأ شرحاً جديداً.\n\n"
        "القواعد:\n"
        "1) الشرح يكون بنفس أسلوب الملخص.\n"
        "2) لا تضف قوانين غير موجودة.\n"
        "3) الشرح يكون تدريجي وبسيط.\n"
        "4) عند الأمثلة: اشرح خطوة خطوة كما هي.\n"
         "5) أشرح باللغة العربية فقط.ذى"
    )
    
    
    
    
def pages_with_headers(pages, subject=None):
    """نصُّ الصفحات للحقن في البرومبت — مُصلَحاً **قبل أن يراه الموديل**.

    ٠١٢ والأرقام تُعرَّب هنا أيضاً لا في المخرَج وحده: البرومبت يأمر
        بالنقل حرفياً، فما وصله عربياً نقله عربياً من تلقائه، ولا يبقى
        لفلتر [_finish] إلا الشوارد ([core/arabic_digits.py]).
    """
    from core.arabic_digits import for_subject as _arabic_digits
    blocks = []
    for p in pages:
        blocks.append(_arabic_digits(
            f"📄 الصفحة {p['رقم_الصفحة']}:\n"
            f"{prepare_source(p['نص_الصفحة'], subject)}", subject))
    return "\n\n".join(blocks)



def requested_pages(req) -> List[int]:
    """أرقام الصفحات المطلوبة — **مصدرٌ واحد لكل المواد**.

    🔴 **لماذا دالّة لا سطران؟** كان الاستخراج مكرّراً في ثلاثة مواضع
       (`pages_mode` ومرّتين في الأحياء)، فأيُّ تحسينٍ يصيب بعضَها ويُخطئ
       بعضَها. وقد وقع فعلاً: الاختيار المُبنيَن وُصل بـ`pages_mode` وحده،
       فبقيت الأحياء — وهي أكثر المواد استعمالاً لوضع الصفحات — تتجاهل
       ما يختاره الطالب ([sweep-siblings-before-reporting]).

    ⚖️ والأولوية للاختيار المُبنيَن، ثم استخراجُ الأرقام من الكلام —
       والثاني يبقى للعملاء القدامى ولمن كتبها بيده.
    """
    picked = list(getattr(req, "selected_pages", None) or [])
    if picked:
        return picked
    return [int(n) for n in re.findall(r"\d+", req.page_source or "")]


def fetch_pages_by_numbers(book_data: List[dict], page_nums: List[int]):
    """جلب صفحات محددة برقمها"""
    found = []
    missing = []
    for p in page_nums:
        found_flag = False
        for unit in book_data:
            for page in unit.get("الصفحات", []):
                if page.get("رقم_الصفحة") == p:
                    found.append(page)
                    found_flag = True
                    break
            if found_flag:
                break
        if not found_flag:
            missing.append(p)
    return found, missing



def extract_all_texts_and_metas_physics(book_data: List[dict], subject=None):
    """استخراج جميع النصوص من بيانات الفيزياء بذكاء لدعم المعادلات والمسائل"""
    texts = []
    metas = []
    
    for unit in book_data:
        unit_name = unit.get("اسم_الوحدة", "")
        
        for lesson in unit.get("الدروس", []):
            lesson_name = lesson.get("اسم_الدرس", "")
            
            for part in lesson.get("الأجزاء", []):
                part_type = part.get("نوع", "")
                part_name = part.get("اسم_الجزء", "")
                
                content = part.get("المحتوى", [])
                
                if isinstance(content, list):
                    for item in content:
                        # ✅ التعديل السحري هنا: قراءة كل المفاتيح بذكاء
                        if isinstance(item, dict):
                            text_parts = []
                            # 1. إذا كان تعريف
                            if "المصطلح" in item:
                                text_parts.append(f"{item.get('المصطلح')}: {item.get('التعريف', '')}")
                            
                            # 2. إذا كانت معادلة أو مسألة حسابية (هنا كان الخلل)
                            if "الصيغة" in item:
                                text_parts.append(f"السؤال أو القانون: {item.get('الصيغة')}")
                            if "الاستخدام" in item:
                                text_parts.append(f"طريقة الحل: {item.get('الاستخدام')}")
                            if "مثال_رقمي" in item:
                                text_parts.append(f"الحل بالخطوات: {item.get('مثال_رقمي')}")
                                
                            # 3. احتياط لأي مفاتيح جديدة في المستقبل
                            if not text_parts:
                                for k, v in item.items():
                                    text_parts.append(f"{k}: {v}")
                            
                            text = " | ".join(text_parts)
                            
                        # إذا كان نص عادي (نقاط)
                        else:
                            text = str(item)
                        
                        if text.strip():
                            texts.append(text)
                            metas.append({
                                "unit": unit_name,
                                "lesson": lesson_name,
                                "part_type": part_type,
                                "part_name": part_name
                            })
                else:
                    # محتوى نصي مباشر
                    if content:
                        texts.append(str(content))
                        metas.append({
                            "unit": unit_name,
                            "lesson": lesson_name,
                            "part_type": part_type,
                            "part_name": part_name
                        })
    
    # 🧮 نفس القاعدة هنا: نصّ الدرس المهيكل يصل الموديل بكسور مرمَّزة
    return [prepare_source(t, subject) for t in texts], metas


async def enhanced_search_physics(book_data, query, top_k=5, subject=None):
    # ⚗️ و`subject` يمرّ كي تصل الصيغُ العضوية مرمَّزة في المسار القديم
    #    أيضاً — كان يُستدعى بلا مادة فتسقط الحلقات والسلاسل عن الكيمياء.
    texts, _metas = extract_all_texts_and_metas_physics(book_data, subject)
    if not texts:
        return [], []
    # 🔄 نفس الترتيب الهجين — كان هنا **نفسُ عطل الدمج بالأسبقية** حرفياً،
    #    وهذه الدالّة تخدم الفيزياء والكيمياء والعربي معاً.
    return await hybrid_rank(texts, query, top_k)




# ══════════════════════════════════════════════════
# 🔬 الأُسّ العلويّ — رقماً كاملاً لا رقمه الأول
# ══════════════════════════════════════════════════
_SUP = str.maketrans("0123456789+-", "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻")
# ⚠️ ويشمل الشحنةَ وحدها: «2Cl^{-}» و«Cu^{+2}» — والأيونات لا تُكتب إلا
#    هكذا في كل معادلات الكيمياء الكهربائية.
# ⚠️ **ولا بدّ من أُسٍّ فعليّ**: `\d*` وحدها تطابق الفراغ، فأكلت الرمز `^`
#    من «(س-أ)^(ن+1)» وأضاعت الأُسّ كلَّه — عيبٌ أسوأ ممّا جئنا نُصلحه.
_SUP_RE = re.compile(r"\^\{?([+-]?\d+|[+-])\}?")


def _superscript(text: str) -> str:
    """«10^23» ⇒ «10²³» · «10^-7» ⇒ «10⁻⁷» · «س^2» ⇒ «س²».

    ⚠️ **والأُسّ غير الرقمي يبقى كما هو**: «(س - أ)^(ن+1)» ليس له مقابلٌ
       في يونيكود، ورسّامُ التطبيق يعرف `^` فيرفعه بنفسه. فتحويلُ ما لا
       يُحوَّل يُفسد ما كان سليماً.
    """
    if "^" not in text:
        return text
    return _SUP_RE.sub(lambda m: m.group(1).translate(_SUP), text)


# ══════════════════════════════════════════════════
# 🏁 اللمسات الأخيرة — **مشتركةٌ بين كل المسارات**
# ══════════════════════════════════════════════════
# 🔴 **علّةٌ بنيويّة تكرّرت ثلاث مرات:** كل إصلاحٍ كنت أصله بـ
#    `format_arabic_math` — وهي مسارُ المعالجات القديمة — بينما **المسار
#    الحيّ** لوضعَي الدروس والوحدات هو `core/lesson_mode.py` و
#    `core/pages_mode.py`، وهما يناديان `strip_stray_latex` وحدها.
#    فوصل الإصلاح إلى نصف التطبيق وغاب عن نصفه ([organic-chem-drawing]).
#
# ⭐ فصارت اللمسات الأخيرة **دالّةً واحدة يناديها المساران**، ويحرسها
#    اختبارٌ يقارن ناتجهما حرفاً بحرف على مجموعةٍ من الحالات.

# ⚗️ كسرٌ بسطُه أو مقامُه **سهمٌ أو عاملُ جمع** ليس كسراً:
#    الموديل يكتب «\frac{CuCl2(aq)}{→} \frac{Cu+2}{+}» ظانّاً أن `\frac`
#    تركّب المعادلة رأسياً — فيخرج على الشاشة كسرٌ مقامُه سهم. رُصد في
#    ١٦ موضعاً من ١٦٥ شرحاً حقيقياً (2026-09-10).
_BRACED = r"((?:[^{}]|\{[^{}]*\})*)"
_PSEUDO_FRAC = re.compile(
    r"\\frac\{" + _BRACED + r"\}\{\s*([→←⇌+\-=]|-->|<--)\s*\}")

# ⚠️ و`\frac` **بمجموعةٍ واحدة** ترميزٌ ناقص لا كسر: «\frac{2Cl^{-}(aq)}»
#    يخرج على الشاشة كسراً بلا مقام — أو ترميزاً عارياً. يُفكّ إلى محتواه.
_LONE_FRAC = re.compile(r"\\frac\{" + _BRACED + r"\}(?!\s*\{)")


def _finish(text: str, subject: str = "", collapse_spaces: bool = True) -> str:
    """ما يمرّ به **كل** جوابٍ قبل الطالب، أياً كان مساره.

    ⚠️ و`subject` تُمرَّر كي يبقى **رسّامُ كل مادةٍ في مادته**: تحويل «جذر»
       إلى `\\sqrt` كارثةٌ في الأحياء («جذر وتدي») — راجع [core/roots.py].

    📐 و`collapse_spaces=False` لمخرجاتٍ **بنيوية** تُقرأ بمسافاتها: خطةُ
       الدرس وجدولُ المواصفات في قسم المعلّم قوائمُ متداخلة، وسحقُ المسافات
       البادئة يُسقط تداخلَها. فالرسّامُ يصلها، والبنيةُ تبقى.
    """
    if not text:
        return text
    from core.chem import unwrap_equation_chem
    from core.roots import to_sqrt
    from core.factorial import to_factorial
    from core.counting import to_counting
    from core.powers import to_power
    from core.symbols import to_symbols
    from core.overline import to_overline
    from core.nuclide import to_nuclide
    from core.formula import to_subscript
    from core.tex_blocks import strip_broken_tex
    from core.arabic_digits import for_subject as _arabic_digits
    text = strip_broken_tex(text)
    text = unwrap_equation_chem(text)
    text = to_sqrt(text, subject)
    text = to_factorial(text, subject)
    text = to_counting(text, subject)
    text = to_symbols(text, subject)
    text = to_overline(text, subject)
    # ☢️ **قبل `to_power` لا بعدها**: رمزُ النواة `^235_92U` وحدةٌ واحدة،
    #    ولو سبقها الأُسُّ لأخذ العددَ الكتلي وحده وترك الذرّيَّ عارياً —
    #    وهو ما رآه المالك «\sup{235}_92U» على الشاشة.
    text = to_nuclide(text, subject)
    # ⚗️ **ودليلُ الصيغة ينخفض**: «H2SO4» ⇒ «H₂SO₄» (طلب المالك 2026-09-12).
    #    بعد `to_nuclide` كي تكون أرقامُ النواة داخل `\nuc{}` فتُحجب.
    text = to_subscript(text, subject)
    # يُكرَّر لأن الكسور الزائفة متجاورة: «\frac{أ}{→} \frac{ب}{+}»
    for _ in range(4):
        new = _PSEUDO_FRAC.sub(r"\1 \2 ", text)
        if new == text:
            break
        text = new
    text = _LONE_FRAC.sub(r"\1", text)
    # 🔴 **آليةٌ واحدة للأُسّ في المواد الرياضية**: `to_power` تردّ كلَّ
    #    الصيغ إلى `\sup{…}` فيرسمها التطبيق مرفوعةً — بما فيها المتغيّر
    #    والسالب وما بين قوسين، وهي التي كانت تبقى خاماً على الشاشة.
    text = to_power(text, subject)
    # ⚖️ و`_superscript` تبقى **للمواد الأخرى وحدها**: أحياءٌ فيها
    #    «10^23» بلا رسّامٍ رياضيّ، فيونيكود خيرٌ من «^» عارية.
    #    (وفي المواد الرياضية لا يبقى لها ما تعمله.)
    text = _superscript(text)
    # ٠١٢ **والأرقام عربية في مادّتها** (الرياضيات والمنطق والفيزياء):
    #     قرارُ المالك للفيزياء 2026-09-12، وللأوّلَين 2026-09-09.
    #
    # ⚖️ **وموضعُها هنا لا في كل معالجٍ على حدة**: كانت تُنادى في
    #    `subjects/math` و`subjects/logic` وحدهما، فالفيزياء — ومسارُها
    #    الحيّ `lesson_mode`/`pages_mode` — لم تكن لتراها. وهذه الدالّة
    #    يمرّ بها **كل** جواب أياً كان مساره.
    #
    # 📏 **وقُيس أن التقديم لا يُغيّر شيئاً**: `to_arabic` صارت تحجب أسماء
    #    أوامر اللاتيك، فتبادلت مع `latex_guard.clean` و`to_frac` — ٢٥١٦٤
    #    سطراً من الرياضيات والمنطق والفيزياء: **صفرُ اختلاف**.
    text = _arabic_digits(text, subject)
    if not collapse_spaces:
        return text
    # فراغاتٌ مضاعفة خلّفها فكُّ الكسور الزائفة
    return re.sub(r"[ \t]{2,}", " ", text)

def format_arabic_math(text: str, subject: str = "") -> str:
    """
    فلتر سحري يحول معادلات LaTeX المعقدة إلى نصوص عربية مقروءة بوضوح
    ويحافظ على تنسيق الأسطر (النزول للسطر).
    """
    if not text:
        return ""
    
    # 1. إزالة أقواس LaTeX المزعجة
    text = re.sub(r'\\\[|\\\]', '', text)
    text = re.sub(r'\\\(|\\\)', '', text)
    text = text.replace('$', '')
    
    # 2. استخراج الكلمات العربية من داخل \text{} و \mathrm{}
    text = re.sub(r'\\text\{([^}]+)\}', r'\1', text)
    text = re.sub(r'\\mathrm\{([^}]+)\}', r'\1', text)
    
    # 3. ✅ الكسور تُترك كما هي: `\frac{A}{B}` هو الترميز الذي يرسمه التطبيق
    #    بسطاً فوق مقام. كان هنا تحويلٌ إلى «(A / B)» يُفقد الكسرَ صورتَه
    #    ويجعله ملتبساً على الطالب («أ / ب + ج» لا يُجزم بمعناها).
    #    هذا الفلتر مركزي: تستدعيه كل المواد، فتصحيحه هنا يكفيها جميعاً.
        
    # 4. استبدال الرموز الرياضية اللاتينية برموز عادية
    replacements = {
        r'\times': '×',
        r'\div': '÷',
        r'\cdot': '·',
        r'\approx': '≈',
        r'\neq': '≠',
        r'\leq': '≤',
        r'\geq': '≥',
        r'\pm': '±',
        # 🔴 **حُذف `\sqrt` ⇦ `√`** (2026-09-10): كان يسبق الرسّام، وصار
        #    بعده يُتلف — «\sqrt{٣}» تخرج «√{٣}» بأقواسها على الشاشة.
        #    الرسّام يفهم `\sqrt` ويرسم العلامة والسقف معاً.
        r'\infty': '∞',
        r'\pi': 'π',
        r'\theta': 'θ',
        r'\lambda': 'λ',
        r'\Delta': 'Δ',
        r'\Omega': 'Ω',
        r'\alpha': 'α',
        r'\beta': 'β',
        r'\gamma': 'γ',
        r'\mu': 'μ',
        r'\\': '\n', # تحويل النزول للسطر في اللاتيك إلى نزول سطر عادي
    }
    
    for old, new in replacements.items():
        text = text.replace(old, new)

    # 🏁 اللمسات المشتركة (أُسّ · غلافُ chem · كسرٌ زائف · جذر) — [_finish].
    text = _finish(text, subject)

    # 5. التعديل هنا: استخدام [ \t]+ بدلاً من \s+ عشان ما نمسح النزول للسطر (\n)
    text = re.sub(r'[ \t]+', ' ', text).strip()

    # 6. 🛡️ **الحارس الأخير**: أي أمر LaTeX لم تعرفه القائمة أعلاه يُحوَّل
    #    إلى رمزه أو يُحذف — ولا يصل الطالبَ اسمُه الإنجليزي.
    #
    #    🔴 هذا بالضبط ما كان يقع في «ابدأ الشرح الذكي»: مسارُ الرياضيات
    #       يمرّ بهذه الدالة **وحدها** (بلا `strip_stray_latex`)، والقائمة
    #       أعلاه لا تعرف `\int` — فيصل الطالبَ «int» وسط شرحٍ عربي.
    #       ومسحُ ٦٤ درساً أظهرها ٢٣ مرة، ومعها `quad` و`left` و`right`.
    from core.latex_guard import clean as _guard_clean
    text = _guard_clean(text)

    # 7. 🔢 **شرطةٌ ناجية في مخرَج الموديل** ⇒ كسرٌ مرمَّز.
    #
    #    إصلاح نصّ الكتاب (`format_lesson_safely`) خفض الشرطات من ٤٢ إلى صفر
    #    في أكثر الدروس، لكن الموديل يكتب أحياناً ما ليس في الكتاب —
    #    «ط/2» و«دص/دس» في اشتقاقه هو. فالشبكة الثانية على المخرَج.
    #
    # ⚠️ و`to_frac` تميّز الوحدة من الكسر ومن «أو» العربية ([core/fractions.py])،
    #    فـ«٢٠ م/ث» و«انطلاق / انبعاث» تمرّان بلا مساس.
    from core.fractions import to_frac as _to_frac
    return _to_frac(text)

# ══════════════════════════════════════════════════════════
# 🧹 تنظيف اللاتيك الشارد من رد الموديل
# ══════════════════════════════════════════════════════════
# المسارات القديمة (`subjects/*.py`) تنظّف الرد بنفسها، أما مسارا النسخة
# الثالثة (`core/lesson_mode.py` و`core/pages_mode.py`) — وهما المسار الحيّ
# اليوم — فلا ينظّفان شيئاً. فظهر على شاشة الطالب `\quad` بين صيغتين
# و`\[ ... \]` حول قانون. والترميزات الثلاثة التي **يرسمها التطبيق**
# مستثناة صراحةً، وإلا حُذف ما وُلِّد عمداً (علّة وقعت مع `\frac` من قبل).

# ℹ️ حُذفت من هنا قائمةٌ ثالثة للترميزات المُستثناة (`frac` · `chem` ·
#    `ring`) — كانت **ميتة** (لا يناديها أحد) و**متخلّفة** (ثلاثةٌ من
#    عشرة). والمصدرُ الواحد هو `latex_guard.KEPT` ونظيرُه في التطبيق
#    `kMathTokens`. وهي خامسُ مرّةٍ تتكرر فيها علّةُ القائمة المنسوخة.
_LATEX_DELIMS = re.compile(r"\\[\[\]()]")


def render_finish(text: str, subject: str = "", collapse_spaces: bool = True) -> str:
    """🖌️ **لمساتُ الرسّام لأي نصٍّ يراه الطالب** — خارج مسار `/ask` أيضاً.

    يستعملها قسمُ المعلّم و«اختبر نفسك»: هما يعرضان نصَّ المنهج نفسه،
    فلا معنى لأن يُرسم الكسرُ في الشرح ويبقى «/» في سؤال الاختبار.
    """
    return _finish(text or "", subject, collapse_spaces)


def strip_stray_latex(answer: str, subject: str = "") -> str:
    """ينظّف أوامر اللاتيك عدا ترميزات الرسم — ويترك النصّ العربي كما هو.

    🔄 **صار يُحوّل لا يحذف** (2026-09-09): الحذف الأعمى كان يُفقد المعادلةَ
       رموزها — ``\\int`` تختفي فتصير «تكامل د(س) دس» بلا علامة تكامل، وهي
       **أسوأ من كلمةٍ إنجليزية** لأنها تبدو صحيحة ولا تُنبّه أحداً.
       `latex_guard` يحوّلها إلى «∫» التي يرسمها الخطّ، ولا يحذف إلا ما
       لا مقابل له.
    """
    if not answer:
        return answer
    from core.latex_guard import clean as _guard_clean
    # 💲 كتلُ «$…$» أوّلاً: الصالحةُ يُنزع دولارها ويُسلَّم محتواها
    #    للرسّام، والمشوّهةُ تُحذف كاملةً — [core/tex_blocks.py].
    from core.tex_blocks import strip_broken_tex
    answer = strip_broken_tex(answer)
    return _finish(_guard_clean(_LATEX_DELIMS.sub("", answer)), subject)
