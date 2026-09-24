# -*- coding: utf-8 -*-
"""🇬🇧 عدسةُ الإنجليزية في مواصفة البنك — جزءٌ من [tools/quiz_spec.py].

   فُصلت 2026-09-24 حين أضاف طلبُ المالك («أمثلةٌ من خارج الكتاب») قسماً
   جديداً فتجاوز الملفُّ ميزانيةَ الستّمئة سطر. **منقولةٌ حرفاً بحرف**،
   و`quiz_spec` يعيد تصديرَ كلِّ اسمٍ فيها كما كان.
"""
import re


# ══════════════════════════════════════════════════
# 🇬🇧 عدسةُ الإنجليزية — **تمرينٌ لا تعريف**
# ══════════════════════════════════════════════════
# 🔴 **ما رآه المالك (2026-09-17):** «الإنجليزي عبارة عن أمثلة… أوجد
#    الـ passive لهذا، أوجد لهذا. حتى القطعة أعطه قطعة خفيفة وأعطه أمثلة.
#    مو تقول له إيش كيف نختار القطعة — هذا ممتاز بس قلّل منه».
#
# 📏 **والقياسُ صدّقه**: بنكُ ٣ علمي (٢٩٧ سؤالاً) كان **كلُّه تعريفاتٍ
#    بالعربية عن الإنجليزية**: «ما تعريف المبني للمجهول؟» · «ما الفرق بين
#    was وwere؟» · «متى نستخدم is؟». ولا سؤالَ واحدٌ يطلب من الطالب أن
#    **يفعل** شيئاً بالإنجليزية — وهي مادّةُ أداءٍ لا مادّةُ حفظ.
#
# ⚖️ **ولماذا حصّةٌ بالعدد لا قاعدةٌ في النظام؟** لأن هذا هو الدرسُ
#    المتكرّر في المشروع ([[prompt-spine]]): النماذجُ الصغيرة تطيع ما
#    يُعَدّ في رسالة المستخدم وتطوي ما يُوصَف في برومبت النظام — كما وقع
#    في الأوزان والصعوبة وحصّة الترميز.
ENGLISH_SUBJECTS = frozenset({"انجليزي", "إنجليزي", "english"})


def is_english(subject: str) -> bool:
    return (subject or "").strip().lower() in ENGLISH_SUBJECTS


# 📖 **والقطعةُ لدرسها وحدَه** — وهذا حدٌّ صحّحتُه بعد أن طلبتُها من كل
#    درس: «Match to make compound words» تمرينُ مفرداتٍ، وحشوُ قطعةٍ فيه
#    تكلّفٌ لا تعليم. وأمرُ المالك كان عن **درس القطعة**: «حتى القطعة
#    أعطه قطعة خفيفة وأعطه أمثلة».
_PASSAGE_LESSON = re.compile(
    r"القطعة|قطعة|paragraph|Reading|read the|comprehension", re.I)


def wants_passage(lesson: str) -> bool:
    return bool(_PASSAGE_LESSON.search(lesson or ""))


def english_quota(count: int, lesson: str = "") -> tuple:
    """(تطبيقيّ، قطعة، تعريفيّ) — البنكُ كلُّه تمرينٌ إلا أربعةً.

    ⚖️ **والطلبُ فوق العتبة عمداً، وهذا مقصودٌ لا تناقض.** العتبةُ في
       [build_quizzes.english_defects] ستّون بالمئة — وهي **أرضيةُ رفض**؛
       وهذا الرقمُ **هدفٌ** يُكتب في رسالة المستخدم. وقِيس (2026-09-18):
       حين طلبتُ ٦٥٪ عاد الموديلُ بـ٥٠–٥٥٪ فسقطت عشرةُ دروس، وحين طُلب
       «كلُّها إلا أربعة» استقرّ فوق الأرضية. والمالكُ يريد الأكثر:
       «الإنجليزي عبارة عن أمثلة… كثّر من الأمثلة».
    """
    applied = max(2, count - 4)
    passage = (1 if count < 10 else 2) if wants_passage(lesson) else 0
    return applied, passage, min(2, count - applied)


# ══════════════════════════════════════════════════
# 🌍 أمثلةٌ جديدة — القاعدةُ من الدرس والمثالُ من خارجه
# ══════════════════════════════════════════════════
# 🔴 **شكوى المالك (2026-09-24):** «كل ١٥ سؤالاً على الدرس متمحورةٌ على
#    ثلاثة أمثلة — banana ومدري إيش، وnewspaper وsmartphone… قُل له لا يقتصر
#    على أمثلة الكتاب، يجيب نسبةً كبيرةً من خارج الدرس — لأنه أصلاً يتدرّب
#    على اللي في الدرس».
#
# 📏 **والقياسُ صدّقه**: «Circle the different word» — ١٩ سؤالاً على **ستّ
#    مجموعاتٍ هي تمارينُ الكتاب نفسُها** (bananas / milk / tea / soda ثلاثَ
#    مرّات)، و«compound words» كلُّها newspaper وclassroom وfootball.
#    وكان البرومبت نفسُه يأمر بذلك: «Take the sentences from the lesson
#    itself» — **فأطاع**. ولا مقياسَ يَعُدّ المكرَّر.
#
# ⚖️ **والحدُّ: القاعدةُ من الدرس، والكلماتُ والجملُ جديدة** — إلا ربعاً
#    يبقى من أمثلة الكتاب (الامتحانُ الوزاريّ يعيد بعضَها). ويُقاس بـ
#    [english.english_fresh_defects] بنفس الأرقام.
_EN_EXAMPLE = re.compile(r"[A-Za-z][A-Za-z'’\-]*(?:[ \t/+,.?!:=]+[A-Za-z0-9][A-Za-z0-9'’\-]*){1,}")


def book_examples(source: str, limit: int = 14) -> list:
    """أمثلةُ الكتاب — ما تدرّب عليه الطالبُ من قبل (جملٌ وقوائمُ كلمات)."""
    out, seen = [], set()
    for line in (source or "").splitlines():
        if not re.search(r"الفعل_|السؤال|الإجابة|مثال|Example|[/+]", line):
            continue
        for m in _EN_EXAMPLE.findall(line):
            m = m.strip(" .,:")
            if len(m) < 8 or m.lower() in seen:
                continue
            seen.add(m.lower())
            out.append(m)
            if len(out) >= limit:
                return out
    return out


def fresh_quota(count: int) -> tuple:
    """(أقصى ما يُعاد من أمثلة الكتاب، أقلُّ ما يكون جديداً)."""
    book = max(2, round(count * 0.25))
    return book, max(0, count - book)


def fresh_clause(count: int, source: str = "") -> str:
    book, fresh = fresh_quota(count)
    seen = book_examples(source)
    shown = "\n".join(f"      • {s}" for s in seen) or "      • (none listed)"
    return f"""

⑦ **NEW EXAMPLES — the rule from the lesson, the words and sentences from
   OUTSIDE it. {fresh} questions AT LEAST, count them.**
   The student has already practised the lesson's own examples many times.
   A test that repeats them measures memory, not English. So:
   • **At most {book}** questions may reuse an example from the lesson
     (a sentence, a word list or a word pair from the list below).
   • **Every other question uses a NEW sentence or NEW words** that test
     the SAME rule — written by you in correct, natural English at the
     level of a Yemeni Grade 12 (3rd secondary, scientific) student:
     school life, family, health, science, the environment, technology,
     travel, jobs, sport, Yemen and the Arab world.
   • **Never use the same word group, word pair or sentence twice**, and
     do not let one content word (banana, newspaper, smartphone…) appear
     in more than two questions. Twenty questions = twenty different
     examples.
   📚 Already seen in the lesson (reuse at most {book} of these):
{shown}
   ✅ lesson has `news + paper`  ⇒ ask `rain + coat`, `bed + room`,
      `head + ache`, `sun + glasses`, `home + work`…
   ✅ lesson has `bananas / milk / tea / soda` ⇒ ask `carrot / juice /
      coffee / water`, `doctor / nurse / hospital / engineer`…
   ✅ lesson has *I wish I can swim.* ⇒ ask *I wish I ____ speak
      Chinese.* (can / could), *She wishes she ____ taller.* (is / were)
   🤖 A machine compares your examples with the lesson's text and counts
      repeated words — a bank built on the lesson's own examples is
      rejected.

⑧ **ACCURACY FIRST — exactly one correct option, and it must be
   defensible to an English teacher.**
   • Every English sentence you write (in `q` and in the correct option)
     is grammatically correct and natural, except the one error a
     "correct the mistake" item asks about.
   • "Correct the mistake" sentences contain **exactly one** error.
   • "Odd one out": the three belong to ONE clear category and the odd
     word clearly does not — and no other word can be argued to be odd
     (by meaning, part of speech, or form). Avoid words with two common
     meanings.
   • Compound words: only real dictionary compounds, written the way a
     dictionary writes them (`bedroom`, `raincoat`, not `sunflower seed`).
   • Passive: keep the tense and the modal of the active sentence; the
     object becomes the subject; agree `is/are`, `was/were`.
   • Before you write `correct_index`, solve the question yourself once
     more as a student would. If two options could be accepted, rewrite
     the distractor.

⑨ **Target the real weaknesses.** Make the wrong options the mistakes
   Arab students really make on this rule: a missing `be` in the passive,
   `since` with the past simple, `grateful in`, `he don't`, a question
   without inversion (`How I can…?`), the wrong adjective order, `-ful`
   vs `-less`, a linking word with the opposite meaning. A distractor
   nobody would choose teaches nothing."""


def english_clause(count: int, lesson: str = "", source: str = "") -> str:
    applied, passage, defs = english_quota(count, lesson)
    passage_rule = f"""

⑤ **Reading**: **{passage}** question(s) built on a **short passage you write
   yourself inside `q`** — two or three lines in the lesson's own English —
   then ask about its meaning or about one word in it.
   🔴 **Every question stands alone.** The student is shown ONE question at
      a time, so a question that says "According to the passage…" without
      carrying the passage is unanswerable. **Write the passage inside
      `q`, in quotation marks, in every question that asks about it.**
   ✅ q: "Read: *The lungs take in oxygen from the air and pass it to the
          blood. The blood then carries it to every cell in the body.*
          What do the lungs pass to the blood?\"
   ❌ q: "What do we need for breathing?"  ← no passage, nothing to read.""" \
        if passage else ""
    spare = count - applied
    return f"""

━━━━━━━━━━━━━━━━━━━━
🇬🇧 **THIS SUBJECT IS WRITTEN ENTIRELY IN ENGLISH — owner's order (2026-09-18):**

⓪ **`q`, the four `options`, `why` and `topic` are written in ENGLISH.
   NOT ONE ARABIC WORD in any of them.** The student is being tested *in*
   English, not *about* English in Arabic.
   ❌ q: "ما تعريف البادئة (Prefix)؟"
      options: ["مجموعة حروف تُضاف في بداية الكلمة", …]
      why: "البادئة هي مجموعة حروف تُضاف في بداية الكلمة."
   ✅ q: "What is a prefix?"
      options: ["A group of letters added to the beginning of a word to
                 change its meaning",
                "A group of letters added to the end of a word to change
                 its part of speech",
                "A word that joins two sentences together",
                "The base form of a word before any ending is added"]
      why: "A prefix is added at the beginning of a word and changes its
            meaning, as in un- + usual = unusual."
   ⚠️ `level` and `kind` keep their Arabic values — they are system labels
      the student never reads. Everything the student reads is English.

④ **Practice, not talk about practice — {applied} questions AT LEAST,
   count them before you answer.** A practice question has **two parts**:
   an **instruction** and **the material it works on**, written out in full
   inside `q`. A bare question with nothing to work on is NOT practice.
   🔴 ❌ "What are they teaching?"          ← nothing to work on
   🔴 ❌ "How often did they play football?" ← nothing to work on
   ✅ "Make a question for the underlined word: *They are teaching
       **English**.*"
   ✅ "Change into the passive: *They built the school in 1990.*"
       options: ["The school was built in 1990.",
                 "The school is built in 1990.",
                 "The school has built in 1990.",
                 "The school were built in 1990."]
   ✅ "Choose the correct form: He ____ (go) to school every day."
   ✅ "Correct the mistake: *She don't like fish.*"
   ✅ "Re-order to make a sentence: *school / to / walks / he / every /
       day*"
   🤖 **This is checked by a machine, so here is exactly what it looks
      for.** A question counts as practice only if its `q` contains ONE of
      these three, literally:
      • a sentence between asterisks — `*They built the school in 1990.*`
      • a blank made of underscores or dots — `He ____ (go) to school.`
      • a list of words separated by slashes — `wool / metal / fur / skin`
      A question with none of the three does **not** count, however good it
      is. You are allowed **{spare}** such questions in the whole bank; the
      other **{applied}** must each carry one.
      ❌ "Which two words make the compound word 'newspaper'?"  ← none
      ✅ "Which two words make one compound word? *news / paper / quickly*"
      ❌ "What does the prefix 're-' mean?"                      ← none
      ✅ "Complete: *He had to ____ write the letter.* (re- / un- / -ful)"
      ❌ "When do we use 'because'?"                             ← none
      ✅ "Choose the linking word: *He was punished ____ he lied.*"
   ✏️ **When you ask about ONE word, put that word between double
      underscores** so the student can see which word you mean — the app
      draws it underlined.
      ❌ "What is the part of speech of the underlined word?
          *Ali went for a ride on his bicycle.*"   ← nothing is underlined,
          so the question has no answer.
      ✅ "What is the part of speech of the underlined word?
          *Ali went for a __ride__ on his bicycle.*"
      ✅ "Make a question for the underlined words:
          *He comes to school __by bus__.*"
      The same goes for any question whose answer depends on one word or
      phrase inside the sentence.

   🔓 **Permission you need, and it overrides trap ④ and the ⛔ list
      above** ("only from the lesson text"): the *rule, skill or structure*
      you test must come from the lesson — but the **sentences and the
      words you apply it to should mostly be your own** (see ⑦), in correct
      school English, even when the lesson is only a word list.
      Writing "*She was ____ and forgot her keys.* (care + less)" for a
      lesson whose text only lists `careless` is exactly what is wanted.

   📐 **The shape to copy**: `<Instruction>: *<a full English sentence>*`
   — an instruction verb, a colon, then a real sentence between asterisks
   or a blank `____` inside the sentence. The RULE comes from the lesson;
   most of the SENTENCES and WORDS must be new — see ⑦ below.
   ⚠️ Only **{defs} + a few** of your questions may be without material;
   everything else carries its own sentence.
{passage_rule}

③ **What "صعب" means in this subject**: not a calculation — a
   **transformation in more than one step**. Passive with a modal
   ("They must clean the room." → "The room must be cleaned."), a question
   made from a complex sentence, a word changed from one part of speech to
   another, a meaning inferred from a passage. Keep the required number of
   صعب questions, and make each one an exercise of that kind.

❌ **And never ask about the instructions themselves.** These are questions
   about the exercise page, not about English — they teach nothing:
   ❌ "What is the first rule for completing the paragraph?"
   ❌ "What is the formula for creating a compound word?"
   ✅ "Complete: *Fareeda is ____ and gets on well with people.*"
   ✅ "Which two words make one compound word? *class / room / table*"

⑥ **Definitions: at most {defs}** — "What is …?" and "What is the
   difference between … and …?" are useful but few. Even these are written
   **in English**, question and options and `why` alike.

✍️ **Write like an English exam paper**: the instruction line is English
   ("Choose the correct answer", "Complete the sentence"), the example
   sentences are English, and the explanation the student reads after the
   test is English. Use normal Latin digits (1990, not ١٩٩٠).""" + fresh_clause(count, source)
