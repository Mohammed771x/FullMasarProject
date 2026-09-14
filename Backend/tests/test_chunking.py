# -*- coding: utf-8 -*-
"""✂️ التقطيع — **لأن الموديل لم يكن يقرأ الصفحة كاملةً أصلاً**.

🔴 **أخطرُ ما قِيس في جولة البحث كلِّها (2026-09-14):**
   `paraphrase-multilingual-MiniLM-L12-v2` نافذتُه **١٢٨ رمزاً**، وصفحةُ
   كتابٍ عربيٍّ وسطها **٤٥٤ رمزاً**. فقِيس على ٩٤٤ صفحة من تسعة كتب:

     • **٩٨٫٥٪** من الصفحات تتجاوز النافذة.
     • ولا يدخل الموديلَ منها إلا **٣١٫٦٪** في المتوسط.

   أي أن **ثلثي كل كتابٍ لم يكن مفهرساً دلالياً قطّ**، ولا يُعثر عليه إلا
   بالمطابقة اللفظية صدفةً. والمالك لاحظ العَرَض («الصفحة قد تغطّي
   موضوعين فيُخفَّف متجهها») والواقعُ أقسى: الموضوع الثاني لم يكن يدخل
   المتجه من أصله.

📏 **وأثرُ العلاج مقيس** — إصابةُ الصفحة الصحيحة ضمن أفضل أربع:

     عيّنة                         صفحةً كاملة   بالمقاطع
     ٣٣١ سؤالاً من عناوين الدروس      ٨٧٫٩٪       **٩٤٫٩٪**
     ٢٦٠ سؤالاً من متن الكتب نفسِها   ٩٧٫٧٪       **٩٩٫٢٪**

   وفي الأولى: ربحت المقاطع ٢٨ سؤالاً وخسرت ٥. وفي المركز الأول:
   ٦٠٫١٪ ⇐ **٧١٫٦٪**.

⚖️ **والتقطيع للبحث وحده — ويُسلَّم للموديل صفحاتٌ كاملة.** المقطعُ يكفي
   ليُعثر عليه ولا يكفي ليُشرح منه.
"""
import pytest

from subjects.common import (
    split_for_embedding, embedding_corpus, embed_model, page_title,
    _token_len, _CHUNK_TOKENS,
)
from core.content_store import get_pages_book

WINDOW = 128           # نافذة الموديل بالرموز، شاملةً الرمزين الخاصّين


def _unit_texts(subject="احياء", unit="التنظيم الهرموني"):
    book = get_pages_book(3, "علمي", subject)
    target = [u for u in book if (u.get("اسم_الوحدة") or "").strip() == unit]
    assert target, "الوحدة غير موجودة — تغيّر المحتوى؟"
    return [p.get("نص_الصفحة") or "" for p in target[0].get("الصفحات", [])]


# ══════════════ ① الحقيقةُ التي بُني عليها كلُّ شيء ══════════════

def test_the_model_window_is_still_the_reason_we_chunk():
    """إن اتّسعت نافذةُ الموديل يوماً فأعِد النظر في التقطيع كلِّه."""
    assert embed_model.max_seq_length == WINDOW
    assert _CHUNK_TOKENS < WINDOW - 2, "لا هامشَ للرمزين الخاصّين"


def test_a_real_page_really_does_overflow_the_window():
    """🔴 وهذه ليست نظرية: صفحاتُ المنهج الحقيقية تفيض فعلاً."""
    texts = _unit_texts()
    overflowing = [t for t in texts if _token_len(t) > WINDOW]
    assert len(overflowing) > len(texts) * 0.8, \
        "لم تعد الصفحات تفيض — هل تغيّر المحتوى أو الموديل؟"


# ══════════════ ② لا مقطعَ يُقصّ بصمت ══════════════

def test_no_chunk_overflows_the_window():
    """✂️ وإلا كنّا نقطّع ثم نُسقط الذيل كما كنّا نفعل بالصفحة."""
    for page in _unit_texts():
        for chunk in split_for_embedding(page):
            assert _token_len(chunk) <= WINDOW - 2, chunk[:60]


def test_a_sentence_longer_than_the_window_is_split_by_words():
    """جدولٌ أو فقرةٌ بلا علامة وقف لا تُترك لتُقصّ."""
    giant = "الهرمون " * 400                     # جملةٌ واحدة بلا وقف
    chunks = split_for_embedding(giant)
    assert len(chunks) > 1
    assert all(_token_len(c) <= WINDOW - 2 for c in chunks)


def test_a_short_page_is_left_whole():
    """💤 ولا نقطّع ما لا يحتاج تقطيعاً."""
    short = "الغدة النخامية تقع في قاع الجمجمة."
    assert split_for_embedding(short) == [short]


@pytest.mark.parametrize("text", ["", "   ", "\n\n"])
def test_empty_text_yields_nothing(text):
    assert split_for_embedding(text) == []


# ══════════════ ③ لا يضيع حرفٌ ولا تضيع صفحة ══════════════

def test_every_word_of_the_page_survives_somewhere():
    """🧷 التقطيعُ يُعيد التوزيع ولا يحذف — وإلا عاد العطلُ من بابٍ آخر."""
    for page in _unit_texts():
        seen = " ".join(split_for_embedding(page))
        missing = [w for w in page.split() if w not in seen]
        assert not missing, f"ضاعت كلمات: {missing[:5]}"


def test_consecutive_chunks_overlap():
    """🔗 والتداخل كي لا تُقطع فكرةٌ بين مقطعين."""
    page = max(_unit_texts(), key=len)
    chunks = split_for_embedding(page)
    assert len(chunks) > 1
    shared = set(chunks[0].split()) & set(chunks[1].split())
    assert shared, "لا تداخل بين مقطعين متتاليين"


def test_every_page_owns_at_least_one_chunk():
    """📄 وكلُّ صفحةٍ ممثَّلة — فهرسُ الصفحة هو ما يُعاد للمعالجات."""
    texts = _unit_texts()
    chunks, owners = embedding_corpus(texts)
    assert len(chunks) == len(owners)
    assert set(owners) == set(range(len(texts)))
    assert len(chunks) > len(texts), "لم يقع تقطيعٌ أصلاً"


def test_an_empty_page_still_keeps_its_slot():
    """🕳️ صفحةٌ فارغة لا تُزيح ترقيم ما بعدها — المراجع تُبنى على الفهرس."""
    chunks, owners = embedding_corpus(["نص أول", "", "نص ثالث"])
    assert owners == [0, 1, 2] and len(chunks) == 3


# ══════════════ ④ والمعالجات لا ترى المقاطع ══════════════

def test_the_search_still_returns_page_indices():
    """⚖️ ستة عشر معالجاً تقرأ `idxs` كفهارسِ صفحات وتبني منها المراجع.

    فلو عادت فهارسُ مقاطع لانهارت أرقامُ الصفحات التي يراها الطالب.
    """
    import asyncio
    from subjects.common import hybrid_rank
    texts = _unit_texts()
    results, idxs = asyncio.run(hybrid_rank(texts, "ما هي الغدة النخامية؟", 4))
    assert all(0 <= i < len(texts) for i in idxs), idxs
    assert len(set(idxs)) == len(idxs), "صفحةٌ تكرّرت — لم تُجمع مقاطعُها"
    assert all(results[k] == texts[i] for k, i in enumerate(idxs)), \
        "المُعاد مقاطعُ لا صفحاتٌ كاملة — الموديل سيشرح من جملتين مبتورتين"


def test_the_warmup_indexes_exactly_what_the_search_reads():
    """🔥 وإلا بنى كلُّ سؤالٍ أولَ فهرسِه أثناء انتظار الطالب.

    بصمةُ الفهرس تُحسب من النصوص، فإحماءُ فهرسِ الصفحات مع البحث في فهرس
    المقاطع يجعل الإحماء كلَّه بلا فائدة — بصمتٍ تام.
    """
    import os
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    src = open(os.path.join(root, "core", "warmup.py"), encoding="utf-8").read()
    assert "embedding_corpus" in src, "الإحماء ما زال على الصفحات"
    assert src.index("embedding_corpus(texts)") < src.index("fingerprint(texts)"), \
        "الإحماء يبصم الصفحات قبل أن يقطّعها"


# ══════════════ ⑤ عنوانُ الصفحة مرساةٌ لا يُذيبها الجسد ══════════════
#
# 🔴 **علّةٌ قِيست على شكوى المالك حرفياً (2026-09-14):** سأل الطالب
#    «إيش يخرج من الفص الأمامي؟» فجاءته صفحاتٌ عن الفص **الخلفي**،
#    وصفحةُ «جدول (٣) هرمونات الفص الأمامي للغدة النخامية» — وهي الجواب
#    بعينه — سقطت خارج الأربع.
#
#    والسبب أن المتوسّط الحسابي للمتجهات **يغسل العنوانَ في بحر الجسد**:
#
#      «جدول (٣) هرمونات الفص الأمامي للغدة النخامية» وحده  ⇒ ٠٫٢٤٠
#      + أوّلُ صفٍّ واحدٍ من الجدول                          ⇒ ٠٫٠٣٥
#      وسطرٌ عن الفص **الخلفي**                              ⇒ ٠٫١٦٦
#
#    فصفٌّ واحد أسقط الصفحةَ الصحيحة تحت صفحةٍ عن الفص المعاكس.

def test_a_title_keeps_its_signal_while_a_body_dilutes_it():
    """📏 القياسُ الذي بُني عليه العلاج — بالأرقام لا بالظنّ."""
    import faiss, numpy as np
    query = "إيش يخرج من الفص الأمامي؟"
    title = "جدول ( ٣ ) هرمونات الفص الأمامي للغدة النخامية"
    with_body = (title + " ١- هرمون النمو (STH) : العضو المتأثر بالهرمون: "
                 "عظام الجسم والعضلات . الوظيفة: - ينظم نمو الجسم ببناء "
                 "العظام ونموها . - بناء البروتينات .")
    emb = embed_model.encode([query, title, with_body],
                             convert_to_numpy=True, show_progress_bar=False)
    faiss.normalize_L2(emb)
    alone = float(np.dot(emb[0], emb[1]))
    diluted = float(np.dot(emb[0], emb[2]))
    assert alone > diluted * 2, \
        f"لم يعد الجسدُ يُذيب العنوان ({alone:.3f} مقابل {diluted:.3f}) — أعِد النظر"


def test_every_page_with_a_title_gets_it_as_its_own_anchor():
    """🏷️ متجهٌ واحدٌ إضافيّ لكل صفحة — والصفحةُ تأخذ أعلى درجات مقاطعها،
    فالمرساةُ لا تخفض شيئاً ولا تزاحم أحداً."""
    texts = _unit_texts()
    chunks, owners = embedding_corpus(texts)
    for i, page in enumerate(texts):
        title = page_title(page)
        if not title:
            continue
        mine = [c for c, o in zip(chunks, owners) if o == i]
        assert title in mine, f"صفحة {i}: عنوانها ليس مقطعاً مستقلاً"


@pytest.mark.parametrize("text, expected", [
    ("جدول ( ٣ ) هرمونات الفص الأمامي\nسطرٌ طويلٌ بعده",
     "جدول ( ٣ ) هرمونات الفص الأمامي"),
    ("\n\n  الغدة الدرقية  \nنص", "الغدة الدرقية"),
    ("كلمة\nالغدة النخامية", "الغدة النخامية"),      # كلمةٌ واحدة ليست عنواناً
])
def test_the_title_is_the_first_short_line(text, expected):
    assert page_title(text) == expected


def test_a_long_first_line_is_not_a_title():
    """📏 فقرةٌ طويلة ليست عنواناً — ولو كانت أول سطر."""
    assert page_title("كلمة " * 60) == ""


def test_the_anterior_lobe_question_now_finds_its_table():
    """🎯 **شكوى المالك بعينها** — وهذا الاختبار يسقط لو عادت العلّة."""
    import asyncio
    from subjects.common import hybrid_rank, extract_all_texts_and_metas
    book = get_pages_book(3, "علمي", "احياء")
    target = [u for u in book if (u.get("اسم_الوحدة") or "").strip() == "التنظيم الهرموني"]
    texts, metas = extract_all_texts_and_metas(target)
    for question in ("إيش يخرج من الفص الأمامي؟",
                     "الفص الأمامي إيش يفرز؟",
                     "أعطني هرمونات الفص الأمامي"):
        _t, idxs = asyncio.run(hybrid_rank(texts, question, 4))
        pages = [metas[i]["page"] for i in idxs]
        assert 53 in pages, f"«{question}» ← ص{pages} بلا جدول الفص الأمامي"
