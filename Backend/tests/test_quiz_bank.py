# -*- coding: utf-8 -*-
"""🎯 بنكُ الأسئلة وخوارزميةُ الاختيار.

⚖️ **قرار المالك (2026-09-16):** «لكل درسٍ أسئلةٌ مخزونة — مبتدئة ومتوسطة
   وصعبة، ومع كل سؤالٍ **وزنُ أهمية**. فإذا اختار ثلاثةَ دروسٍ في خمسةَ عشرَ
   سؤالاً تشيل المهمّات، وإذا اختار درساً واحداً بعشرة تشيل المهمَّ وغيرَ
   المهمّ والمبتدئَ والصعبَ وكلَّ شيء.»

🎯 **والأهميةُ ليست الصعوبة**: تعريفٌ سهلٌ وزنُه ٥، وتطبيقٌ صعبٌ وزنُه ٢.
   فما يُقاس هنا شيئان لا شيء.
"""
import random
import statistics as st
from collections import Counter

import pytest

from core import quiz_bank as QB


def _bank(n, seed=0, weights=None):
    """بنكُ درسٍ بتوزيعٍ معايَرٍ كالذي يفرضه الفاحص على المولِّد."""
    r = random.Random(seed)
    ws = weights or ([5] * round(n * .20) + [4] * round(n * .25) +
                     [3] * round(n * .30) + [2] * round(n * .15) +
                     [1] * round(n * .10))
    ws = (list(ws) + [3] * n)[:n]
    r.shuffle(ws)
    return [{"id": f"{seed}-{i}", "weight": w,
             "level": r.choices(QB.LEVELS, weights=(.40, .38, .22))[0],
             "topic": f"t{i % max(3, n // 3)}",
             "q": f"سؤال {i}", "options": ["أ", "ب", "ج", "د"],
             "correct_index": 0} for i, w in enumerate(ws)]


def _avg_weight(banks, count, trials=120):
    return st.mean(
        st.mean(q["weight"] for q in QB.select(banks, count, seed=t))
        for t in range(trials))


# ══════════════ ① الحصص ══════════════

def test_quota_splits_between_equal_share_and_bank_size():
    """الدرسُ الطويل يأخذ أكثر، والقصيرُ لا يُهمَل."""
    assert QB.quotas([30, 22, 20], 15) == [6, 5, 4]
    assert QB.quotas([20, 20, 20], 15) == [5, 5, 5]
    assert sum(QB.quotas([40, 20], 10)) == 10


def test_quota_never_exceeds_a_lesson_bank():
    """☢️ حصّةٌ أكبرُ من البنك تعني اختباراً ناقصاً بلا أن يشتكي أحد."""
    q = QB.quotas([3, 40], 15)
    assert q[0] <= 3 and sum(q) == 15


def test_quota_gives_every_chosen_lesson_at_least_one():
    """من اختار ثلاثةَ دروسٍ يريد أن يرى ثلاثتها."""
    assert all(x >= 1 for x in QB.quotas([50, 6, 6], 5))


# ══════════════ ② ضغطُ العمق — لبُّ قرار المالك ══════════════

def test_three_lessons_take_the_important_ones():
    """🎯 «لما تسوي كومبينيشن مع ثلاثة دروس، بتشيل المهمّات.»"""
    banks = [("أ", _bank(30, 1)), ("ب", _bank(22, 2)), ("ج", _bank(20, 3))]
    assert _avg_weight(banks, 15) > 3.9, "لم يرتفع الوزنُ عن متوسط البنك"


def test_one_lesson_deeply_reaches_the_less_important():
    """🎯 «لما تسوي عشرة أسئلة للدرس لحاله، بتشيل المهم واللي مش مهم.»

    ⚖️ وهذا ليس تراخياً بل **اضطرارٌ محسوب**: خمسةَ عشرَ سؤالاً من بنكِ
       أربعةٍ وعشرين تستهلك ثلثيه، فلا يبقى إلا النزولُ إلى الأقلّ أهمية.
    """
    one = [("أ", _bank(24, 1))]
    three = [("أ", _bank(30, 1)), ("ب", _bank(22, 2)), ("ج", _bank(20, 3))]
    assert _avg_weight(one, 15) < _avg_weight(three, 15) - 0.3


def test_the_same_bank_gets_sharper_as_the_request_shrinks():
    """خمسةُ أسئلةٍ من بنكٍ واحد أهمُّ من خمسةَ عشرَ منه."""
    one = [("أ", _bank(24, 1))]
    assert _avg_weight(one, 5) > _avg_weight(one, 15) + 0.25


def test_alpha_follows_depth():
    assert QB.alpha_for(0.2) > QB.alpha_for(0.5) > QB.alpha_for(0.9)


# ══════════════ ③ الخلطة ══════════════

@pytest.mark.parametrize("count", [5, 10, 15])
def test_difficulty_mix_is_honoured(count):
    banks = [("أ", _bank(40, 1))]
    got = Counter()
    for t in range(120):
        for q in QB.select(banks, count, seed=t):
            got[q["level"]] += 1
    want = dict(zip(QB.LEVELS, QB.target_mix(count)))
    for lv in QB.LEVELS:
        share = got[lv] / (count * 120)
        assert abs(share - want[lv] / count) < 0.12, (lv, share)


def test_the_easy_questions_come_first():
    """قاعدةٌ تربوية قائمة: اختبارٌ يبدأ بأصعب سؤالٍ يُحبط قبل أن يقيس."""
    picked = QB.select([("أ", _bank(40, 1))], 15, seed=3)
    order = [QB._LEVEL_ORDER[q["level"]] for q in picked]
    assert order == sorted(order)


# ══════════════ ④ التكرار ══════════════

def test_a_second_attempt_brings_new_questions():
    """☢️ بلا هذا يرى الطالبُ **نفسَ الاختبار** في كل محاولة."""
    banks = [("أ", _bank(30, 1)), ("ب", _bank(22, 2)), ("ج", _bank(20, 3))]
    repeats = []
    for t in range(120):
        first = QB.select(banks, 15, seed=t)
        seen = {q["id"] for q in first}
        second = QB.select(banks, 15, seen=seen, seed=1000 + t)
        repeats.append(len({q["id"] for q in second} & seen) / 15)
    assert st.mean(repeats) < 0.30


def test_seen_penalises_but_never_blocks():
    """⚠️ والمنعُ المطلق يُفرغ البنكَ الصغير فيخرج اختبارٌ ناقص."""
    bank = _bank(12, 9)
    got = QB.select([("أ", bank)], 10, seen={q["id"] for q in bank}, seed=1)
    assert len(got) == 10


# ══════════════ ⑤ التنويع والحدود ══════════════

def test_no_more_than_two_questions_per_topic():
    banks = [("أ", _bank(40, 1))]
    for t in range(60):
        got = Counter(q["topic"] for q in QB.select(banks, 10, seed=t))
        assert max(got.values()) <= QB._MAX_PER_TOPIC


def test_a_short_bank_returns_what_it_has_not_a_crash():
    """🛟 والنقصُ يُكمَّل حيّاً من الموديل ([core/quiz]) — لا يسقط الاختبار."""
    got = QB.select([("أ", _bank(3, 1))], 15)
    assert len(got) == 3


def test_empty_input_is_safe():
    assert QB.select([], 10) == []
    assert QB.select([("أ", [])], 10) == []
    assert QB.quotas([], 10) == []


def test_selection_never_repeats_a_question_inside_one_quiz():
    banks = [("أ", _bank(30, 1)), ("ب", _bank(22, 2))]
    for t in range(60):
        got = QB.select(banks, 15, seed=t)
        assert len({q["id"] for q in got}) == len(got)


def test_a_degenerate_bank_still_works():
    """بنكٌ كلُّ أوزانه واحدة (يرفضه الفاحص، لكن الخدمة لا تنهار)."""
    flat = _bank(20, 5, weights=[3] * 20)
    assert len(QB.select([("أ", flat)], 10, seed=1)) == 10


# ══════════════ ⑥ التخزين ══════════════

def test_keys_and_fingerprints_are_stable():
    assert QB.key_of(" الوحدة ", " الدرس ") == "الوحدة › الدرس"
    assert QB.key_of("", "درس") == "درس"
    assert QB.fingerprint("نص") == QB.fingerprint("نص")
    assert QB.fingerprint("نص") != QB.fingerprint("نصّ")


def test_question_id_ignores_option_order():
    """🔁 معرّفُ السؤال أساسُ ذاكرة التكرار — و`spread_answers` تُبدّل
    مواقعَ الخيارات في كل عرض، فلو دخل الترتيبُ في البصمة لتغيّر المعرّف
    في كل اختبار **فلم تعمل الذاكرةُ أبداً**."""
    a = QB.question_id("س", ["أ", "ب", "ج", "د"])
    b = QB.question_id("س", ["د", "ج", "ب", "أ"])
    assert a == b


def test_missing_bank_is_none_not_an_error():
    assert QB.stored_for(9, "لا شيء", "مادة", "و", "د", "نص") is None
