# -*- coding: utf-8 -*-
"""🌍 بنكُ الإنجليزية: مقياسُ «أمثلة الكتاب» للتوليد — والمخزونُ وزاريٌّ باليد.

🔴 شكوى المالك (2026-09-24): «كل ١٥ سؤالاً متمحورةٌ على ثلاثة أمثلة —
   banana… newspaper، smartphone. قُل له يجيب نسبةً كبيرةً من خارج الدرس».
"""
import json
import os

LESSON = """الوحدة: القواعد
اسم_الدرس: Circle the different word
【القواعد】
  اسم_القاعدة: Food vs Drink
  الصيغة: Find the common category
  【أمثلة】
    الفعل_الإيجابي: bananas / milk / tea / soda
【تمارين_تطبيقية】
  السؤال: 1. wool / metal / fur / skin
  السؤال: 2. plastic / square / glass / wood
"""


def _odd(words, i=0):
    return {"q": f"Which word is the odd one out? *{' / '.join(words)}*",
            "options": list(words), "correct_index": i, "why": "x"}


def test_prompt_asks_for_new_examples_and_lists_the_seen_ones():
    from tools import quiz_spec
    p = quiz_spec.user_prompt("Circle the different word", LESSON, 20,
                              subject="انجليزي")
    assert "⑦ **NEW EXAMPLES" in p
    assert "⑧ **ACCURACY FIRST" in p
    assert "bananas / milk / tea / soda" in p          # ما رآه الطالبُ من قبل
    book, fresh = quiz_spec.fresh_quota(20)
    assert (book, fresh) == (5, 15)
    assert f"**At most {book}**" in p
    # 🧪 ولا تمسّ غيرَ الإنجليزية
    assert "NEW EXAMPLES" not in quiz_spec.user_prompt("درس", "نصّ", 20,
                                                       subject="فيزياء")
    # 🔓 والإذنُ يغلب «من داخل النصّ وحده» صراحةً
    assert "Take the sentences from the" not in p


def test_a_bank_of_book_examples_is_rejected():
    from tools.build_quizzes import english_fresh_defects
    book = [_odd(["bananas", "milk", "tea", "soda"]),
            _odd(["wool", "metal", "fur", "skin"], 1),
            _odd(["plastic", "square", "glass", "wood"], 1)] * 3
    bad = english_fresh_defects(book, LESSON)
    assert any("أمثلةُ الكتاب" in d for d in bad), bad
    assert any("«bananas» في 3" in d for d in bad), bad


def test_a_bank_of_new_examples_passes():
    from tools.build_quizzes import english_fresh_defects
    fresh = [_odd(w) for w in (
        ["hospital", "teacher", "nurse", "driver"],
        ["potato", "apple", "grape", "orange"],
        ["chair", "camel", "sheep", "cow"],
        ["ladder", "bus", "airplane", "train"],
        ["glove", "hand", "foot", "eye"],
        ["rice", "coffee", "juice", "water"],
        ["oxygen", "iron", "copper", "gold"],
        ["bananas", "milk", "tea", "soda"],       # ربعٌ من الكتاب مسموح
    )]
    assert english_fresh_defects(fresh, LESSON) == []


def test_rule_words_may_repeat():
    """⚖️ سؤالان عن «wish» يحملانها بالضرورة — ليست مثالاً مكرّراً."""
    from tools.build_quizzes import english_fresh_defects
    src = "اسم_القاعدة: Wish\n  الصيغة: after wish -> could\n"
    qs = [{"q": f"Choose: *I wish I ____ {v}.*", "options": ["can", "could",
           "will", "am"], "correct_index": 1, "why": "x"}
          for v in ("fly", "swim faster", "speak Chinese", "drive a car")]
    assert english_fresh_defects(qs, src) == []


def test_stored_english_bank_is_ministry_exams_only():
    """🏛️ أمرُ المالك (2026-09-24، الثاني): «شيل الأسئلة من الامتحانات
    الوزارية… هذول اللي موجودات احذفها». فالبنكُ كلُّه وزاريٌّ باليد،
    لكلِّ درسٍ ما يكفي أكبرَ اختبار (١٥) وهامشاً — ولا يُولَّد فوقه."""
    p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                     "data", "quizzes", "3", "علمي", "انجليزي.json")
    if not os.path.exists(p):
        return
    from tools.build_quizzes import MINISTRY_MODEL, lessons_of
    data = json.load(open(p, encoding="utf-8"))
    assert len(data) == len(lessons_of(3, "علمي", "انجليزي")) == 17
    for key, entry in data.items():
        assert entry["model"] == MINISTRY_MODEL, key
        assert len(entry["questions"]) >= 16, key
