# -*- coding: utf-8 -*-
"""📄 سياقُ الكتاب — ما يُقتطف ويُسلَّم للموديل

    جزءٌ من [subjects/common] — فُصل 2026-09-20 بأمر المالك:
    «كل مادة/قسم في ملفٍ لحاله، فالتعديلُ على نطاقٍ أقلّ».
    والنصُّ هنا **منقولٌ حرفاً بحرف** من الملف الأصل بلا تغيير سطر.
"""
import asyncio
import re
import faiss
from typing import List, Optional
from .boot import embed_model
from .boot import embed_model
from .content import _normalize_for_search, extract_all_texts_and_metas
from .indexing import embedding_corpus, get_index
from .retrieval import NO_MATCH_NOTE, Ranked, WEAK_MATCH_NOTE, _KEYWORD_WEIGHT, expand_truncated_neighbours, is_continuation_request, lexical_denominator, query_terms, term_weights
from .render_rules import draw_reminder


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
