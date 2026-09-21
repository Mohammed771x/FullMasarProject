# -*- coding: utf-8 -*-
"""📄 التقطيعُ والفهرسة — ما يُعطى للموديل

    جزءٌ من [subjects/common] — فُصل 2026-09-20 بأمر المالك:
    «كل مادة/قسم في ملفٍ لحاله، فالتعديلُ على نطاقٍ أقلّ».
    والنصُّ هنا **منقولٌ حرفاً بحرف** من الملف الأصل بلا تغيير سطر.
"""
import asyncio
import re
import faiss
from typing import List, Optional
from config import QA_TOP_K
from .boot import embed_model
from .boot import embed_model
from .content import get_build_semaphore, index_store


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


