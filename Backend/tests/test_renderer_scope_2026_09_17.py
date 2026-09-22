# ==================================================
# 🧪 جولةُ الرسّام 2026-09-17 — «لكلِّ مادةٍ رسّامُها، ولا تخلط»
# ==================================================
# عقدٌ مكتوبٌ لأربعة أعطالٍ رآها المالكُ أو كشفها مسحُ المخزون:
#   ١. «مضروبة في» صارت زاويةَ مضروبٍ في الفيزياء (٢٩ موضعاً).
#   ٢. «^{س-ص} ل_٢» تباديلُ قاعدتُها مقوّسة — بقيت شرطةً عارية (٧).
#   ٣. «د ق\nف» عبرت سطراً فصارت توافيق — وأتلفت تكاملَ التجزئة.
#   ٤. «م_ط» دليلٌ لا رسّامَ له أصلاً (١٠٠١ في المنهج · ٣٩٠ في المخزون).
import sys, os
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from core.factorial import to_factorial
from core.counting import to_counting
from core.overline import to_overline
from core.subscript import to_sub
from core.powers import to_power


# ───────────────── ١) «مضروبة» اسمُ مفعولٍ لا مضروب ─────────────────

def test_participle_is_not_factorial():
    """«الكتلة مضروبة في التسارع» ضربٌ نثريّ — لا زاويةَ فيه."""
    for form in ("مضروبة", "مضروباً", "مضروبا", "المضروبة"):
        text = "الكتلة %s في التسارع" % form
        assert to_factorial(text, "فيزياء") == text, form


def test_noun_still_becomes_factorial():
    """ولا يُفقدنا الحدُّ المضروبَ الحقيقيّ."""
    assert to_factorial("مضروب ن", "رياضيات") == "\\fact{ن}"
    assert to_factorial("مضروب (ن-1)", "رياضيات") == "\\fact{ن-1}"
    assert to_factorial("احسب 5!", "رياضيات") == "احسب \\fact{5}"


def test_factorial_outside_its_subjects():
    text = "الكتلة مضروب ن"
    assert to_factorial(text, "تاريخ") == text


# ───────────────── ٢) قاعدةُ التباديل تُقوَّس كما يُقوَّس دليلُها ─────────────────

def test_braced_base_counting():
    assert to_counting("^{س-ص} ل_2 = 72", "منطق") == "\\perm{س-ص}{2} = 72"
    assert to_counting("^{ن-1} ل_{ن-3}", "منطق") == "\\perm{ن-1}{ن-3}"


def test_bare_base_still_works():
    assert to_counting("^ن ل_3", "منطق") == "\\perm{ن}{3}"
    assert to_counting("^6 ق_2", "رياضيات") == "\\comb{6}{2}"


def test_counting_never_crosses_a_newline():
    """🔴 «اختيار ف و د ق\\nف = س+١» في تكامل التجزئة."""
    text = "اختيار ف و د ق\nف = س + ١"
    assert to_counting(text, "رياضيات") == text


def test_counting_outside_its_subjects():
    text = "^{س-ص} ل_2"
    assert to_counting(text, "فيزياء") == text     # «ل» و«ق» حرفا كلام


# ───────────────── ٣) المنطق يسلك رسّامَ الرياضيات ─────────────────

def test_logic_mean_is_an_overline():
    """قرارُ المالك: المنطقُ ٣ أدبي مادّةٌ رياضية — و«سَ» متوسّطٌ حسابيّ."""
    out = to_overline("الانحدار: إذا كانت سَ = ٣٢ ، صَ = ٢٧", "منطق")
    assert "\\ovl{س}" in out and "\\ovl{ص}" in out


def test_logic_fatha_needs_a_statistics_context():
    """⚠️ والفتحةُ حركةٌ عربية — فبلا سياقٍ لا تُمسّ."""
    text = "قَال المعلّم فَذهب"
    assert to_overline(text, "منطق") == text


def test_overline_still_math_only_elsewhere():
    text = "الانحدار سَ = ٣٢"
    assert to_overline(text, "تاريخ") == text


def test_math_derivative_unchanged():
    """ولا يُفسد المنطقُ قاعدةَ الرياضيات: الفتحةُ بلا احتمالٍ مشتقة."""
    assert to_overline("مشتقة الدالة صَ", "رياضيات") == "مشتقة الدالة ص′"


# ───────────────── ٤) الدليلُ المنخفض — النصفُ الغائب ─────────────────

def test_subscript_basic():
    assert to_sub("م_ط = ٠.٠٠٢", "فيزياء") == "م\\sub{ط} = ٠.٠٠٢"
    assert to_sub("T_1", "فيزياء") == "T\\sub{1}"
    assert to_sub("لو_هـ (س)", "رياضيات") == "لو\\sub{هـ} (س)"
    assert to_sub("σ_S", "منطق") == "σ\\sub{S}"


def test_subscript_chains_in_one_pass():
    """🔗 «م_فراغ_وسط» معاملُ انكسارٍ نسبيّ — ولا يبقى نصفُها خاماً."""
    once = to_sub("م_فراغ_وسط", "فيزياء")
    assert once == "م\\sub{فراغ}\\sub{وسط}"
    assert to_sub(once, "فيزياء") == once          # ثابتٌ عند التكرار


def test_fill_in_the_blank_is_not_a_subscript():
    """«لـ ________» تمرينُ ملءٍ، و«___ is used» سؤالُ إنجليزية."""
    for text in ("البيعة أول نواة لـ ________", "___ is used for many tasks"):
        assert to_sub(text, "فيزياء") == text


def test_code_identifier_is_not_a_subscript():
    for text in ("snake_case_name", "lesson_mode.py"):
        assert to_sub(text, "فيزياء") == text


def test_chemical_formula_is_shielded():
    """داخل `\\chem{}` الشرطةُ دليلُ ذرّاتٍ يرسمه الرسّامُ الكيميائي."""
    text = "\\chem{CO_2} و \\chem{K_2O}"
    assert to_sub(text, "فيزياء") == text


def test_chemistry_is_outside_the_subscript_scope():
    """🔴 «C_nH_{2n+2}» صيغةٌ عامّة — ولمّا شملتُها خرجت «C\\sub{nH}_{2n+2}»
       فقُطعت نصفين. ٣٨ موضعاً، ولا واحدَ منها دليلٌ رياضيّ."""
    for text in ("C_nH_{2n+2}", "NH_4NO_2 ⟶ N_2 + 2H_2O", "R_H"):
        assert to_sub(text, "كيمياء") == text
        assert to_sub(text, "احياء") == text


def test_subscript_outside_its_subjects():
    text = "م_ط = ٠.٠٠٢"
    assert to_sub(text, "تاريخ") == text
    assert to_sub(text, "انجليزي") == text


# ───────────────── ٥) السالبُ اليونيكوديّ في الأُسّ ─────────────────

def test_unicode_minus_exponent():
    """الكتاب يكتب «س^−٣» بـ«−» (U+2212) لا بشرطة ASCII."""
    assert to_power("س^−٣ لو س", "رياضيات") == "س\\sup{−٣} لو س"


# ───────────────── ٦) لا شيءَ خامٌ في المخزون ─────────────────

def test_no_raw_script_left_in_stored_content():
    """🎯 مسحٌ شاملٌ: لا «_» ولا «^» في سطرٍ لا يبلغه الرسّام."""
    import json, re
    TOK = ("\\frac", "\\sqrt", "\\chem", "\\ring", "\\fact",
           "\\perm", "\\comb", "\\sup", "\\sub", "\\ovl", "\\nuc")
    blank = re.compile(r"_{2,}")
    sub = re.compile(r"(?<![\\a-zA-Z{_])_(?!_)")
    root = os.path.join(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))), "data")
    bad = []
    for kind in ("quizzes", "explanations"):
        base = os.path.join(root, kind)
        if not os.path.isdir(base):
            return                                  # لا بياناتٍ ⇒ لا دعوى
        for dp, _dn, fn in os.walk(base):
            # 🗄️ `_rejected` حجرٌ صحيّ لا يُخدم منه سؤالٌ واحد.
            if "_rejected" in dp:
                continue
            for f in fn:
                if not f.endswith(".json"):
                    continue
                data = json.load(open(os.path.join(dp, f), encoding="utf-8"))
                for key, entry in data.items():
                    texts = ([entry.get("answer", "")] if kind == "explanations"
                             else [v for q in entry.get("questions", [])
                                   for v in [q.get("q", ""), q.get("why", ""),
                                             q.get("topic", "")]
                                   + list(q.get("options", []))])
                    for t in texts:
                        for line in (t or "").split("\n"):
                            if any(tok in line for tok in TOK):
                                continue
                            if sub.search(blank.sub(" ", line)) or "^" in line:
                                bad.append("%s · %s" % (f, line.strip()[:80]))
    assert not bad, "خامٌ أمام الطالب:\n" + "\n".join(bad[:10])


# ───────────────── ٧) عدسةُ الإنجليزية — تمرينٌ لا تعريف ─────────────────

def test_english_clause_only_for_english():
    from tools import quiz_spec
    assert quiz_spec.is_english("انجليزي")
    assert not quiz_spec.is_english("فيزياء")
    en = quiz_spec.user_prompt("THE PASSIVE VOICE", "نصّ", 12, subject="انجليزي")
    ph = quiz_spec.user_prompt("درس", "نصّ", 12, subject="فيزياء")
    assert "④ **Practice, not talk about practice" in en
    assert "④ **Practice, not talk about practice" not in ph
    # 🇬🇧 وأمرُ المالك (2026-09-18): «كله كامل بالإنجليزي يكون».
    assert "WRITTEN ENTIRELY IN ENGLISH" in en
    assert "NOT ONE ARABIC WORD" in en


def test_passage_quota_is_for_its_own_lesson():
    """📖 «Match to make compound words» تمرينُ مفرداتٍ — لا قطعةَ فيه."""
    from tools import quiz_spec
    assert quiz_spec.wants_passage("فهم القطعة والإجابة على الأسئلة")
    assert quiz_spec.wants_passage("Complete the paragraph")
    assert not quiz_spec.wants_passage("Match to make compound words")
    reading = quiz_spec.user_prompt("فهم القطعة", "نصّ", 12, subject="انجليزي")
    words = quiz_spec.user_prompt("Match to make compound words", "نصّ", 12,
                                  subject="انجليزي")
    assert "⑤ **Reading**" in reading
    assert "⑤ **Reading**" not in words


def test_english_bank_is_exercises_not_definitions():
    """🎯 عقدُ المالك: «الإنجليزي عبارة عن أمثلة… قلّل من التعريف»."""
    import json, re
    p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                     "data", "quizzes", "3", "علمي", "انجليزي.json")
    if not os.path.exists(p):
        return
    from tools.build_quizzes import english_defects
    data = json.load(open(p, encoding="utf-8"))
    latin = re.compile(r"[A-Za-z]")
    qs = [q for e in data.values() for q in e["questions"]]
    from tools.build_quizzes import _is_drill, _is_word_drill
    applied = sum(1 for q in qs if _is_drill(q["q"]) or _is_word_drill(q))
    assert applied / len(qs) >= 0.60, "التطبيقُ %d من %d" % (applied, len(qs))
    for key, entry in data.items():
        assert not english_defects(entry["questions"], key), key

    # ☢️ **ولا حرفَ عربيٍّ فيما يقرؤه طالبُ الإنجليزية** — وهذا كان
    #    العيبَ كلَّه: ٣١٦ سؤالاً من ٣١٦ نصُّها عربيّ (2026-09-18).
    arabic = re.compile(r"[\u0621-\u064a]")
    for q in qs:
        assert not arabic.search(q["q"]), q["q"]
        assert not any(arabic.search(o) for o in q["options"]), q["q"]
        assert not arabic.search(q.get("why", "")), q["q"]
        assert latin.search(q["q"]), q["q"]


def test_english_drill_is_measured_where_the_material_is():
    """📐 المادّةُ تُقاس نصّاً كانت أو خيارات — ومقياسي أخطأ في الاثنين."""
    from tools.build_quizzes import _is_drill, _is_word_drill
    # ✅ أشكالُ المادّة الأربعة
    assert _is_drill("Change into the passive: *They built the school.*")
    assert _is_drill("Choose the correct form: He ____ (go) to school.")
    assert _is_drill("Choose the different word: wool / metal / fur / skin")
    assert _is_drill("What is the passive form of 'He eats meat every day'?")
    # 🔴 وما لا مادّةَ فيه ليس تمريناً
    assert not _is_drill("What is a prefix?")
    assert not _is_drill("What do we need for breathing?")
    # 🔤 والمادّةُ في الخيارات: تمرينُ الشذوذ واختيارُ اللاحقة
    pick = {"q": "Which word does NOT belong with the others?",
            "options": ["apple", "banana", "chair", "orange"]}
    assert _is_word_drill(pick)
    assert not _is_word_drill({"q": "What is a prefix?",
                               "options": ["A group of letters", "b", "c", "d"]})


def test_english_defects_catch_an_arabic_stem():
    """🎯 عيبُ المالك بعينه: «ما تعريف البادئة (Prefix)؟»."""
    from tools.build_quizzes import english_defects
    bad = english_defects([{
        "q": "ما تعريف البادئة (Prefix)؟",
        "options": ["مجموعة حروف في البداية", "في النهاية", "فعل", "اسم"],
        "why": "البادئة تُضاف في بداية الكلمة."}] * 4)
    assert bad and "عربيّة" in bad[0]


def test_a_question_that_says_underlined_must_underline():
    """✏️ «choose the correct part of speech» بلا كلمةٍ مؤشَّرة = بلا جواب."""
    from tools.build_quizzes import english_defects
    naked = [{"q": "Choose the correct part of speech of the underlined "
                   "word: *Ali went for a ride on his bicycle.*",
              "options": ["Noun", "Verb", "Adjective", "Adverb"],
              "why": "ride is a noun here."}] * 3
    bad = english_defects(naked)
    assert any("خطَّ" in d for d in bad), bad

    marked = [{"q": "Choose the correct part of speech of the underlined "
                    "word: *Ali went for a __ride__ on his bicycle.*",
               "options": ["Noun", "Verb", "Adjective", "Adverb"],
               "why": "ride is a noun here."}] * 3
    assert not any("خطَّ" in d for d in english_defects(marked))


def test_english_bank_marks_every_underlined_word():
    """📏 والمخزونُ نفسُه: سبعةُ أسئلةٍ كانت تقول «تحته خطّ» بلا خطّ."""
    import json, re
    p = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                     "data", "quizzes", "3", "علمي", "انجليزي.json")
    if not os.path.exists(p):
        return
    ref = re.compile(r"underlined|part of speech", re.I)
    mark = re.compile(r"(?<!_)__[^_\n]{1,40}__(?!_)")
    data = json.load(open(p, encoding="utf-8"))
    for entry in data.values():
        for q in entry["questions"]:
            if ref.search(q["q"]):
                assert mark.search(q["q"]), q["q"]


def test_english_is_routed_to_deepseek():
    """📏 `gpt-4o-mini` استقرّ عند ٥٠–٥٥٪ تطبيقاً مع أربعِ إعادات."""
    from tools.build_quizzes import route
    assert route("انجليزي")[0] == "deepseek"
    # 🎛️ والضابطُ مادّةٌ سرديةٌ لا حسابَ فيها — فالكيمياءُ انتقلت هي الأخرى
    #    إلى ديب سيك (2026-09-22)، فلم تعد تصلح ضابطاً.
    assert route("احياء")[0] == "openai"


# ───────────────── ٨) الحسابُ يُصحَّح أو يُخطَّأ ─────────────────

def test_arith_catches_the_owners_defect():
    """🎯 «⌋(٣+٣)» جوابُها ٩ وتعليلُها ٧٢٠ — رآها المالك على الشاشة."""
    from tools.arith_check import bank_defects
    bad = bank_defects([{"q": "ما هي نتيجة \\fact{٣ + ٣}؟",
                         "options": ["٦", "١٢", "١٠", "٩"], "correct_index": 3,
                         "why": "\\fact{٣ + ٣} = \\fact{٦} = ٧٢٠."}])
    assert bad and "720" in bad[0]


def test_arith_tolerates_rounding_in_explanations():
    """📐 «\\frac{٨}{٦} = ١.٣٣٣» تقريبُ معلّمٍ لا خطأُ حساب."""
    from tools.arith_check import question_defects
    for why in ("ب = ٠.٧٥ × \\frac{٨}{٦} = ٠.٧٥ × ١.٣٣٣ = ١.",
                "\\frac{٠.٦}{٠.٩} = ٠.٦٧",
                "\\fact{٧} = ٧ × ٦ × ٥ × ٤ × ٣ × ٢ × ١ = ٥٠٤٠."):
        assert not question_defects({"q": "س", "options": [],
                                     "correct_index": None, "why": why}), why


def test_arith_does_not_read_a_list_comma_as_an_equation():
    """🔴 «الزوجيُّ من رقم واحد: ٢**،** ٤ = ٢» تعدادٌ لا معادلة."""
    from tools.arith_check import question_defects
    assert not question_defects(
        {"q": "س", "options": [], "correct_index": None,
         "why": "الزوجي من رقم واحد: ٢، ٤ = ٢، ومن رقمين: ٢×٤ = ٨."})


def test_arith_ignores_non_numeric_options():
    """⚠️ «\\frac{١}{٢}» ليست العدد ١٢ — وقراءتُها كذلك وسمت نصفَ البنك."""
    from tools.arith_check import answer_defects
    assert not answer_defects(
        {"q": "ما قيمة النهاية؟",
         "options": ["\\frac{١}{٢}", "١", "٢", "صفر"], "correct_index": 0,
         "why": "المثال المحلول انتهى إلى \\frac{١}{٢}."})


def test_arith_catches_answer_that_contradicts_its_own_why():
    """🔴 تعليلٌ يشتقّ «٣» ثم يَسِم الجواب «٥» — علّةُ درس الانحدار."""
    from tools.arith_check import answer_defects
    bad = answer_defects({"q": "فما القيمة المتوقعة؟",
                          "options": ["٣", "٥", "٨", "١١"], "correct_index": 1,
                          "why": "ص = ٢٧ - ٢٤ = ٣."})
    assert bad and "٣" in bad[0]


def test_calc_subjects_route_to_deepseek():
    """🧮 قرارُ المالك: المنطقُ مادّةٌ رياضية فيأخذ موديلَها."""
    from tools.build_quizzes import route, CALC_SUBJECTS
    assert "منطق" in CALC_SUBJECTS and "رياضيات" in CALC_SUBJECTS
    assert route("منطق")[0] == "deepseek"
    assert route("رياضيات")[0] == "deepseek"
    # 🧪 والفيزياءُ والكيمياءُ لحقتا بها (2026-09-22) — لكن عبر [SCI_SUBJECTS]
    #    لا عبر `CALC_SUBJECTS`: هذه الأخيرةُ يعلّق عليها [english.py] فاحصَ
    #    الحساب الحتميّ، وهو لا يفهم الوحداتِ الفيزيائية.
    from tools.build_quizzes import SCI_SUBJECTS
    assert route("فيزياء")[0] == "deepseek"
    assert route("كيمياء")[0] == "deepseek"
    assert "فيزياء" not in CALC_SUBJECTS and "فيزياء" in SCI_SUBJECTS


def test_stored_banks_have_no_arithmetic_contradiction():
    """🎯 مسحٌ شامل: لا سؤالَ يناقض حسابُه جوابَه في أي مادة."""
    import json
    from tools.arith_check import question_defects
    root = os.path.join(os.path.dirname(os.path.dirname(
        os.path.abspath(__file__))), "data", "quizzes")
    if not os.path.isdir(root):
        return
    bad = []
    for dp, _dn, fn in os.walk(root):
        if "_rejected" in dp:
            continue
        for f in fn:
            if not f.endswith(".json"):
                continue
            for key, e in json.load(open(os.path.join(dp, f),
                                         encoding="utf-8")).items():
                for q in e.get("questions", []):
                    for d in question_defects(q):
                        bad.append("%s · %s" % (f, d))
    assert not bad, "تناقضٌ حسابيّ:\n" + "\n".join(bad[:8])
