# -*- coding: utf-8 -*-
"""🎯 «اختبر نفسك» من البنك المخزون — بلا نداءِ موديل ولا خصمِ حصة.

⚖️ **قرار المالك (2026-09-16):** «سوِّ كاشنج لاختبر نفسك… وأعطِني تصميماً
   معمارياً بحيث ما يحصل لودنج لو دخل طلابٌ كثير، وما يروح يبحث في الكورس
   كامل لما يبغى درساً معيّناً.»
"""
import json

import pytest

from core import quiz, quiz_bank as QB

pytestmark = pytest.mark.quiz_bank


def _fake_bank(n=24, seed=0):
    import random
    r = random.Random(seed)
    ws = ([5] * 5 + [4] * 6 + [3] * 7 + [2] * 4 + [1] * 2)
    ws = (ws + [3] * n)[:n]
    out = []
    for i, w in enumerate(ws):
        q = f"سؤالٌ رقم {i} عن نقطةٍ من الدرس؟"
        opts = [f"خيار {i}أ", f"خيار {i}ب", f"خيار {i}ج", f"خيار {i}د"]
        out.append({"id": QB.question_id(q, opts), "q": q, "options": opts,
                    "correct_index": 0, "topic": f"نقطة {i % 12}",
                    "lesson": "درسٌ ما", "level": r.choice(QB.LEVELS),
                    "weight": w, "kind": "تعريف",
                    "why": "لأن الدرس نصّ على ذلك."})
    return out


# ══════════════ ① لا يُنادى موديلٌ حين يكفي البنك ══════════════

@pytest.mark.anyio
async def test_the_bank_answers_without_touching_a_model(monkeypatch):
    """💳 وعليه يقوم ردُّ الحصة: نداءٌ لم يقع لا يُدفع ثمنُه."""
    monkeypatch.setattr(quiz, "serve_from_bank",
                        lambda *a, **k: {"questions": [1] * 10, "cached": True,
                                         "generated": 10, "requested": 10,
                                         "subject": "س", "unit": "",
                                         "lessons": ["د"]})

    async def _boom(*a, **k):
        raise AssertionError("☢️ نودي الموديلُ والبنكُ كافٍ")

    monkeypatch.setattr(quiz, "_call_model", _boom)
    out = await quiz.generate(3, "علمي", "احياء", "و", ["د"], 10, {})
    assert out["cached"] is True


def test_selection_is_pure_and_fast():
    """⚡ الاختيارُ حسابٌ خالص: لا قرصَ ولا شبكةَ ولا قاعدةَ بيانات.

    ⚖️ وعليه يقوم جوابُ المالك عن «لو دخل طلابٌ كثير»: ما لا يلمس شبكةً
       يتوسّع بعدد النوى لا بعدد الاتصالات.
    """
    import time
    banks = [("أ", _fake_bank(30, 1)), ("ب", _fake_bank(22, 2))]
    t0 = time.perf_counter()
    for i in range(200):
        got = QB.select(banks, 15, seed=i)
        assert len(got) == 15
    per = (time.perf_counter() - t0) / 200 * 1000
    assert per < 5, f"الاختيارُ بطيء: {per:.2f} م.ث"


# ══════════════ ② البصمة والتدهور اللطيف ══════════════

def test_a_changed_lesson_drops_its_bank(tmp_path, monkeypatch):
    """🔑 تعديلُ الكتاب يُسقط البنكَ من تلقائه — فلا يُسأل عن نصٍّ زال."""
    monkeypatch.setattr(QB, "QUIZZES_DIR", tmp_path)
    QB._cache.clear()
    QB.put(3, "علمي", "مادة", "و", "د", "النصُّ الأصلي", _fake_bank(20))
    assert QB.stored_for(3, "علمي", "مادة", "و", "د", "النصُّ الأصلي")
    assert QB.stored_for(3, "علمي", "مادة", "و", "د", "نصٌّ معدَّل") is None


def test_a_missing_lesson_falls_back_to_the_model():
    """🛟 درسٌ بلا بنك ⇒ الطلبُ كلُّه إلى الموديل كما كان — لا اختبارَ ناقص."""
    assert quiz.serve_from_bank(3, "علمي", "احياء", "و",
                                ["درسٌ لا وجود له"], 10) is None


def test_a_short_bank_does_not_serve_a_short_quiz():
    """🔒 كلٌّ أو لا شيء: عشرةُ أسئلةٍ مطلوبة لا تُسلَّم سبعة."""
    banks = [("أ", _fake_bank(6, 3))]
    assert len(QB.select(banks, 10)) < 10


# ══════════════ ③ التخزين لا يمسح ما حوله ══════════════

def test_writing_one_lesson_keeps_its_neighbours(tmp_path, monkeypatch):
    monkeypatch.setattr(QB, "QUIZZES_DIR", tmp_path)
    QB._cache.clear()
    QB.put(3, "علمي", "مادة", "و", "د١", "نص١", _fake_bank(20, 1))
    QB.put(3, "علمي", "مادة", "و", "د٢", "نص٢", _fake_bank(20, 2))
    assert QB.stored_for(3, "علمي", "مادة", "و", "د١", "نص١")
    assert QB.stored_for(3, "علمي", "مادة", "و", "د٢", "نص٢")
    assert QB.drop(3, "علمي", "مادة", "و", "د١")
    assert QB.stored_for(3, "علمي", "مادة", "و", "د١", "نص١") is None
    assert QB.stored_for(3, "علمي", "مادة", "و", "د٢", "نص٢")


def test_the_file_cache_follows_mtime(tmp_path, monkeypatch):
    """⚡ قراءةٌ واحدةٌ ثم ذاكرة — والكتابةُ تُبطلها فلا يُقدَّم قديمٌ."""
    monkeypatch.setattr(QB, "QUIZZES_DIR", tmp_path)
    QB._cache.clear()
    QB.put(3, "علمي", "مادة", "و", "د", "نص", _fake_bank(20))
    first = QB.load_file(3, "علمي", "مادة")
    assert QB.load_file(3, "علمي", "مادة") is first     # نفسُ الكائن ⇒ ذاكرة
    QB.put(3, "علمي", "مادة", "و", "د٢", "نص٢", _fake_bank(20, 9))
    assert len(QB.load_file(3, "علمي", "مادة")) == 2


def test_the_index_is_light_and_scoped():
    """🧭 «هل لهذا الدرس بنك؟» بلا فتح أسئلته."""
    idx = QB.index()
    assert isinstance(idx, dict)
    for key, lessons in idx.items():
        assert key.count("/") == 2                      # صف/مسار/مادة
        assert all(isinstance(v, int) for v in lessons.values())


# ══════════════ ④ ما يصل التطبيقَ من كل سؤال ══════════════

def test_the_served_question_carries_all_the_app_consumes():
    """📋 السؤالُ وخياراتُه وصوابُه **وسببُه** ونقطتُه ودرسُه.

    ⚖️ و`why` أكبرُ ما يضيفه البنك: شاشةُ المراجعة كانت تُري الطالبَ الصوابَ
       **بلا سبب** — واختبارٌ لا يُشرح تقييمٌ لا تعليم.
    """
    from core import quiz_bank
    banks = [("درسٌ ما", _fake_bank(24, 5))]
    picked = quiz_bank.select(banks, 10, seed=1)
    for q in picked:
        for field in ("q", "options", "correct_index", "topic", "lesson",
                      "level", "weight", "why", "id"):
            assert field in q, field
        assert len(q["options"]) == 4
        assert 0 <= q["correct_index"] <= 3
