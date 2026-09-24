# -*- coding: utf-8 -*-
"""📄 فحصُ الإنجليزية — أقيسُ ما أطلب

    جزءٌ من [build_quizzes.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في ملفٍ لحاله»
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.
"""
from __future__ import annotations
from .boot import Counter, quiz_spec, re
from .consts import CALC_SUBJECTS
from .checks import _bank_floor, _shape_defects, draw_defects


# ══════════════════════════════════════════════════
# 🇬🇧 فحصُ الإنجليزية — **أقيسُ ما أطلب**
# ══════════════════════════════════════════════════
# ☢️ **تاسعُ مرّةٍ يكون الطلبُ بلا مقياس.** أضفتُ حصّةَ التطبيق في
#    [quiz_spec.english_clause] فارتفع التطبيقُ من ~صفر إلى ٧٦٪ — **لكنّ
#    حصّةَ القطعة (⑤) عادت بـ٣ من ٣٢٠**. والموديلُ لا يُلام: ما لا يُقاس
#    لا يُحاسَب عليه، وهو الدرسُ الذي تكرّر في الأوزان والصعوبة والترميز.
# ⇐ فما دخل رسالةَ المستخدم عدداً يدخل `check_bank` عدداً، ويعود في
#   `retry_prompt` عيباً باسمه.
_EN_LATIN = re.compile(r"[A-Za-z]")
_EN_WORD = re.compile(r"[A-Za-z][A-Za-z'\-]*")

# 🔴 **أمرُ المالك (2026-09-18):** «حقّ الإنجليزي كله كامل بالإنجليزي يكون…
#    تقوله إيش هي البادئة، تعطيه تعريفه بالعربي — ماشي بالعربي. الأسئلة
#    بالإنجليزي، كل شيء بالإنجليزي، اختبر نفسك ثالثة كامل بالإنجليزي».
#
# 📏 **والقياسُ صدّقه**: ٣١٦ سؤالاً في ١٧ درساً — **٣١٦ منها نصُّها عربيّ
#    و٣١٦ تعليلُها عربيّ**. أي أن البنكَ كلَّه كان درسَ نحوٍ **عن**
#    الإنجليزية بالعربية، لا اختباراً **بالإنجليزية**.
#
# ☢️ **وعلّتُه أن مقياسي السابق قاس الخياراتِ وحدَها.** طلبتُ «خياراتُها
#    جملٌ إنجليزية» فامتثل الموديل — وترك النصَّ والتعليلَ عربيَّين، وهما
#    ما يقرؤه الطالبُ أوّلاً وآخِراً. عاشرُ مرّةٍ يُقاس نصفُ المطلوب.
_ARABIC_LETTER = re.compile(r"[ء-ي]")

# 📝 التمرينُ يُعرف بفعلِ أمرٍ إنجليزيٍّ في صدره أو بجملةٍ مقتبسةٍ داخله.
_EN_TASK = re.compile(
    r"\b(choose|change|complete|correct|re-?order|rewrite|make|form|fill|"
    r"match|identify|put|use|select|find the|underline|turn the|join|"
    r"which word|which sentence|what is the correct|read the)\b", re.I)
# 📖 والتعريفُ يُعرف بافتتاحه — بالإنجليزية الآن لا بالعربية.
_EN_DEFINITION = re.compile(
    r"^\s*(what\s+is\s+(a\s+|an\s+|the\s+)?(definition|meaning)?|"
    r"what\s+does\s+.{1,30}\s+mean|what\s+are\s+|"
    r"what\s+is\s+the\s+difference\s+between|which\s+of\s+the\s+following\s+"
    r"(best\s+)?(defines|describes))", re.I)


# 🔴 **والتمرينُ يحمل مادّتَه معه.** قِيس في أوّل إعادةِ بناء (2026-09-18):
#    الموديلُ كتب كلَّ شيءٍ بالإنجليزية — ثم أعطى «?What are they teaching»
#    بلا جملةٍ يعمل عليها الطالب. فصار المقياسُ يطلب **المادّة**: جملةٌ
#    بين نجمتين أو اقتباسٍ، أو فراغٌ `____` داخل جملة.
# 📐 **والمادّةُ أربعةُ أشكال** — وكلُّها رُصدت في مخرَجٍ حقيقيّ: جملةٌ بين
#    نجمتين · جملةٌ بين اقتباسين · فراغٌ `____` أو `.......` · وقائمةُ
#    كلماتٍ مفصولةٌ بشرطاتٍ مائلة («wool / metal / fur / skin») وهي شكلُ
#    تمرين «Circle the different word» كلِّه.
_EN_MATERIAL = re.compile(
    r"\*[^*]{10,}\*"
    r"|[\"'“‘][A-Za-z][^\"'”’]{9,}[\"'”’]"
    r"|_{3,}|\.{4,}"
    r"|(?:[A-Za-z][A-Za-z'\-]*\s*[/|]\s*){2,}[A-Za-z]")


def _is_drill(q: str) -> bool:
    if _EN_MATERIAL.search(q or ""):
        return True
    return bool(_EN_TASK.search(q or "")
                and len(_EN_WORD.findall(q or "")) >= 9)


# 🔤 **والمادّةُ قد تكون في الخيارات لا في النصّ.** «?Which word does NOT
#    belong» خياراتُها أربعُ كلماتٍ إنجليزية — وهي **تمرينُ الشذوذ** بعينه،
#    ومثلُها «?Which suffix means 'full of'». فقياسُ النصّ وحدَه يرفض
#    تمريناً حقيقياً — والمادّةُ تُقاس حيث هي، نصّاً كانت أو خيارات.
# ⚖️ ويبقى «?What is a prefix» تعريفاً: لا فعلَ اختيارٍ في صدره.
_EN_PICK = re.compile(r"^\s*(which|choose|identify|select|find|pick)\b", re.I)

# ✏️ سؤالٌ يحيل إلى كلمةٍ «تحتها خطّ» — والخطُّ `__كلمة__` ([masar_markdown]).
_UNDERLINE_REF = re.compile(r"underlined|part of speech", re.I)
_MARKED_WORD = re.compile(r"(?<!_)__[^_\n]{1,40}__(?!_)")


def _is_word_drill(q: dict) -> bool:
    if not _EN_PICK.match(q.get("q", "")):
        return False
    opts = q.get("options") or []
    return all(len(_EN_WORD.findall(o)) <= 3 and _EN_LATIN.search(o)
               for o in opts)


def english_defects(questions: list, lesson: str = "") -> list:
    """عيوبُ بنكِ الإنجليزية — **كلُّه بالإنجليزية**، وتمرينٌ لا تعريف."""
    if not questions:
        return []
    bad, n = [], len(questions)

    # ⓪ **الحدُّ الأوّل: لا حرفَ عربيٍّ فيما يقرؤه الطالب.**
    def _arabic(q) -> bool:
        return bool(_ARABIC_LETTER.search(q.get("q", ""))
                    or any(_ARABIC_LETTER.search(o) for o in q["options"])
                    or _ARABIC_LETTER.search(q.get("why", "")))

    ar = [q for q in questions if _arabic(q)]
    if ar:
        sample = ar[0].get("q", "")[:60]
        bad.append(f"{len(ar)} من {n} سؤالاً فيها عربيّة — وهذه المادّةُ "
                   f"كلُّها بالإنجليزية: النصُّ والخياراتُ والتعليل. "
                   f"مثالٌ: «{sample}»")

    # ④ التطبيق: جملةٌ إنجليزيةٌ كاملةٌ يُعمل عليها، لا كلامٌ عن القاعدة.
    applied = sum(1 for q in questions
                  if _is_drill(q.get("q", "")) or _is_word_drill(q))
    need = max(2, round(n * 0.60))
    if applied < need:
        bad.append(f"التطبيق {applied} من {n} — والمطلوب {need} سؤالاً "
                   "يعطي جملةً إنجليزيةً كاملةً ويطلب عملاً عليها "
                   "(Change into the passive: … / Correct the mistake: …)")

    # ☢️ **وهذا ثاني موضعٍ أخطأ فيه مقياسي في نفس الجلسة.** أوّلُ صياغةٍ
    #    عدّت «?'What is the passive form of 'He eats meat» تعريفاً لأنها
    #    تبدأ بـ«What is» — فرُفض بنكٌ فيه ١٤ **تمريناً** بتهمة التعريف.
    # ⚖️ **والتعريفُ ما لا مادّةَ معه**: سؤالٌ يحمل جملةً يعمل عليها
    #    الطالبُ تمرينٌ مهما كان افتتاحُه.
    # ✏️ **وما قال «تحته خطّ» فليضع الخطّ.** رآها المالك (2026-09-19):
    #    «تقول له choose the correct part of speech — طيب، وعرّفه بالكلمة
    #    إيش هي الـpart of speech». والسؤالُ كان: «?…the underlined word»
    #    ثم جملةٌ **لا خطَّ تحت أيِّ كلمةٍ فيها** — فلا جوابَ له أصلاً،
    #    و`why` وحده يعرف الكلمةَ المقصودة. سبعةُ أسئلةٍ كانت كذلك.
    # ⚖️ **وقائمةُ الكلمات لا خطَّ فيها** (2026-09-24): «Which word is NOT
    #    the same part of speech? *teacher / driver / writer / easily*» سؤالٌ
    #    تامّ — الكلماتُ نفسُها هي الخيارات، فلا كلمةَ «تحتها خطّ» تُنتظر.
    _word_list = re.compile(r"(?:[A-Za-z][A-Za-z'\-]*\s*/\s*){2,}[A-Za-z]")
    unmarked = [q for q in questions
                if _UNDERLINE_REF.search(q.get("q", ""))
                and not _MARKED_WORD.search(q.get("q", ""))
                and not (_word_list.search(q.get("q", ""))
                         and "underlined" not in q.get("q", "").lower())]
    if unmarked:
        bad.append(f'{len(unmarked)} سؤالاً يقول «the underlined word» ولا خطَّ '
                   f'تحت كلمة — ضع الكلمةَ المقصودة بين شرطتين مزدوجتين: '
                   f'*The __cut__ on his arm.* (مثالٌ: «{unmarked[0]["q"][:52]}»)')

    defs = sum(1 for q in questions
               if _EN_DEFINITION.match(q.get("q", ""))
               and not _is_drill(q.get("q", "")))
    if defs > 3:
        bad.append(f"التعريفاتُ {defs} — سقفُها ٣؛ حوّل الزائدَ إلى تمرينٍ "
                   "بجملةٍ إنجليزيةٍ كاملة")

    # 📖 قطعةٌ حقيقية: ستّون محرفاً لاتينياً في نصّ السؤال = سطران فأكثر.
    # 📖 والقطعةُ تُطلب من درسها وحدَه ([quiz_spec.wants_passage]).
    passage = sum(1 for q in questions
                  if len(_EN_LATIN.findall(q.get("q", ""))) >= 60)
    if quiz_spec.wants_passage(lesson) and passage < 1:
        bad.append("لا سؤالَ مبنيٌّ على قطعةٍ قصيرة — اكتب قطعةً من سطرين "
                   "إلى ثلاثة داخل نصّ السؤال ثم اسأل عنها")
    return bad


def check_bank(questions: list, want: int, source: str, subject: str,
               lesson: str = "") -> list:
    """عيوبُ البنك كلِّه — ما يُصلَح بنداءٍ ثانٍ موجَّه."""
    bad = []
    n = len(questions)
    # 📐 **الأرضيةُ ١٦ لا `MIN_QUESTIONS`**: أكبرُ طلبٍ يسمح به التطبيق ١٥
    #    سؤالاً، فبنكٌ من ١٦ يخدمه ويبقي هامشَ تدوير. ورفضُ بنكٍ من ١٨
    #    لأن التقديرَ قال ٢٠ إتلافٌ لعملٍ سليمٍ لفرقٍ لا يراه الطالب.
    # ⚖️ **والعتبةُ تخدم التطبيقَ لا تقديري.**
    #
    #    `want` تقديرٌ من عدد الحروف (÷٢٤٠) لا عقدٌ مع الدرس. والمطلوبُ
    #    وظيفياً شيئان: **١٦ سؤالاً** على الأقلّ (أكبرُ طلبٍ يسمح به التطبيق
    #    ١٥، فيبقى هامشُ تدوير)، و**٢٤** تكفي أيَّ درسٍ مهما طال — عندها
    #    يصير التدويرُ ضعفَ الطلب ونصفَه.
    #
    # ☢️ وقِيس (2026-09-17): درسُ «الحرب الباردة» أعطى **٢٧ سؤالاً ممتازاً**
    #    فرُفض لأن تقديري قال ٤٠ — إتلافُ عملٍ سليمٍ لفرقٍ **لا يراه الطالب
    #    أبداً**. والنسبةُ تبقى حارساً ضدّ التقصير الفاحش وحده.
    floor = _bank_floor(want)
    if n < floor:
        bad.append(f"العدد {n} وهو أقلُّ من المطلوب {want}")

    bad += _shape_defects(questions, want, strict=False, lesson=lesson)

    bad += draw_defects(questions, source)

    # 🇬🇧 وعدسةُ الإنجليزية — بنفس أرقام [quiz_spec.english_clause].
    if quiz_spec.is_english(subject):
        bad += english_defects(questions, lesson)
        bad += english_fresh_defects(questions, source)

    # 🧮 **والحسابُ يُحسب لا يُستحسن** ([tools/arith_check.py], 2026-09-17):
    #    في الرياضيات والمنطق كلُّ سؤالٍ رقميٍّ **يُصحَّح أو يُخطَّأ**،
    #    وبنكٌ فيه «⌋(٣+٣) = ٩» عيبٌ يراه كلُّ طالبٍ ولا يتغيّر.
    if subject in CALC_SUBJECTS:
        from tools.arith_check import bank_defects
        bad += bank_defects(questions)

    # 🔁 لا سؤالان متطابقان
    ids = [q["id"] for q in questions]
    if len(set(ids)) != len(ids):
        bad.append("أسئلةٌ مكرّرة حرفياً")
    return bad




# ══════════════════════════════════════════════════
# 🌍 أمثلةٌ جديدة — **يُقاس ما طُلب** ([quiz_spec.fresh_clause])
# ══════════════════════════════════════════════════
# 🔴 **شكوى المالك (2026-09-24):** «كل ١٥ سؤالاً متمحورةٌ على ثلاثة أمثلة —
#    banana… newspaper، smartphone». وقِيس: ٤٧٪ من البنك مادّتُه أمثلةُ
#    الكتاب نفسُها، و«Circle the different word» ١٣ من ١٩ على مجموعاته الستّ.
#
# 📐 **المادّةُ** = ما بين النجمتين · قائمةُ الشرطات المائلة · جملةُ الفراغ ·
#    أو الخياراتُ في تمرين الكلمة. ⇒ **كلماتُها المحتوى** (بلا أدوات النحو
#    ولا كلمات الأمر). سؤالٌ **من الكتاب** إن كان ٧٠٪ منها في نصّ الدرس.
# ⚖️ **والتكرارُ لا يُعدّ على كلمات القاعدة نفسِها** (wish · since ·
#    grateful): سؤالان عن «wish» يحملانها بالضرورة. فالمستثنى ما ورد في
#    `اسم_القاعدة` و`الصيغة`. والقطعةُ الطويلة لا يُعدّ تكرارُها — كلُّ سؤالٍ
#    عنها يحملها كاملةً ([quiz_spec.english_clause] ⑤).
_EN_STOP = frozenset("""the a an and or but nor of to in on at for with by from
into onto over under up down out off about after before as than then so if
when while which what who whom whose where why how there here all any some
each every no not do does did done doing has have had having is are was were
be been being am will would can could must should may might shall it its
this that these those he she they we you i his her their our your my me him
them us one two three very too also just only more most less much many
word words sentence sentences choose correct complete answer following change
make question underlined form verb passive use write rewrite fill blank
mistake order reorder join
yesterday now ago already tomorrow today usually always never often sometimes
last next like used new still yet ever""".split())


def _material(q: dict) -> str:
    t = q.get("q", "")
    parts = re.findall(r"\*([^*]+)\*", t)
    parts += re.findall(r"(?:[A-Za-z][A-Za-z'\-]*\s*[/|+]\s*)+[A-Za-z][A-Za-z'\-]*", t)
    if not parts and re.search(r"_{3,}|\.{4,}", t):
        parts = [t]
    if not parts and _is_word_drill(q):
        parts = list(q.get("options") or [])
    return " ".join(parts)


def _content(text: str) -> set:
    return {w.lower().strip("'-") for w in _EN_WORD.findall(text or "")
            if len(w) > 2 and w.lower() not in _EN_STOP}


def _rule_words(source: str) -> set:
    lines = [l for l in (source or "").splitlines()
             if re.search(r"اسم_القاعدة|الصيغة|اسم_الدرس", l)]
    return _content(" ".join(lines))


def fresh_stats(questions: list, source: str) -> tuple:
    """(أسئلةُ الكتاب، {كلمة: عددُ الأسئلة})."""
    vocab, rule = _content(source), _rule_words(source)
    book, count = 0, Counter()
    for q in questions:
        # 🏷️ وعناوينُ الجدول («Material:» · «Found:») قالبُ الدرس لا مثالُه.
        words = _content(re.sub(r"[A-Za-z]+\s*:", " ", _material(q)))
        if not words:
            continue
        if len(words & vocab) / len(words) >= 0.7:
            book += 1
        if len(_EN_LATIN.findall(q.get("q", ""))) < 160:   # لا القطعة
            count.update(words - rule)
    return book, count


def english_fresh_defects(questions: list, source: str) -> list:
    """أمثلةُ الكتاب فوق حصّتها، أو كلمةٌ واحدةٌ تتكرّر في أسئلةٍ كثيرة."""
    if not questions or not source:
        return []
    n = len(questions)
    cap, _fresh = quiz_spec.fresh_quota(n)
    book, count = fresh_stats(questions, source)
    vocab = _content(source)
    bad = []
    # 🎯 **هامشُ واحدٍ فوق الحصّة** — الطلبُ هدفٌ والرفضُ أرضية، كالتطبيق.
    if book > cap + 1:
        bad.append(f"{book} من {n} سؤالاً مادّتُها أمثلةُ الكتاب نفسُها — "
                   f"الحدُّ {cap}. القاعدةُ من الدرس والجملُ والكلماتُ "
                   "جديدةٌ من عندك (⑦)")
    # 🔁 كلمةٌ من الكتاب في ثلاثة أسئلة، أو أيُّ كلمةٍ في أربعة.
    rep = [w for w, c in count.most_common()
           if c >= (3 if w in vocab else 4)]
    if rep:
        bad.append("أمثلةٌ مكرّرة: " + " · ".join(
            f"«{w}» في {count[w]} أسئلة" for w in rep[:5])
            + " — لكلِّ سؤالٍ مثالُه، ولا كلمةَ في أكثر من سؤالين")
    return bad
