# -*- coding: utf-8 -*-
"""📄 الفحصُ العامّ — على مستويين

    جزءٌ من [build_quizzes.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في ملفٍ لحاله»
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.
"""
from __future__ import annotations
from .boot import (ARABIC_DIGIT_SUBJECTS, Counter, DRAW, QB, _norm_codes, quiz_spec, st)
from .consts import (BANNED_OPTION, DEFINITION_OPENER, FIGURE_REF, PERSIAN_DIGITS, RAW_LATEX, WESTERN_DIGITS, is_exercise)


# ══════════════════════════════════════════════════
# 🔎 الفحص — على مستويين
# ══════════════════════════════════════════════════

def check_question(item, subject: str) -> list:
    """عيوبُ سؤالٍ واحد — قائمةٌ فارغةٌ تعني سليماً."""
    bad = []
    q, options = item["q"], item["options"]
    blob = q + " " + " ".join(options)

    if len(q) < 12:
        bad.append("سؤالٌ أقصرُ من أن يكون سؤالاً")
    if not item["topic"]:
        bad.append("`topic` فارغٌ أو هو اسمُ الدرس — يُفرغ تحليلَ المستوى")
    if not item["why"]:
        bad.append("`why` ناقص — الطالبُ يرى الصوابَ ولا يعرف لماذا")
    elif len(item["why"]) > 260:
        bad.append("`why` فقرةٌ لا سطر")
    # ⛔ **«كل ما سبق» عيبُها أن تكون هي الصواب** — لا أن تُذكر.
    #
    # ☢️ قِيس على المحجور (2026-09-17): أسقط هذا الحارسُ **٣٩ سؤالاً**
    #    أكثرُها كانت فيه مشتّتاً لا جواباً. ومشتّتٌ كسولٌ لا يُفسد سؤالاً
    #    صحيحاً؛ الذي يُفسده أن يكون الجوابُ نفسُه «كل ما سبق»، فيصير
    #    الاختيارُ تخميناً بلا فهم.
    if BANNED_OPTION.search(q) or BANNED_OPTION.search(options[item["correct_index"]]):
        bad.append("«كل ما سبق» أو «لا شيء مما ذُكر» هي الإجابة الصحيحة")
    if FIGURE_REF.search(blob):
        bad.append("سؤالٌ يحيل إلى شكلٍ أو صفحةٍ لا يراها الطالب")
    if RAW_LATEX.search(blob):
        bad.append("لاتيك خام في نصّ السؤال أو خياراته")
    if PERSIAN_DIGITS.search(blob):
        bad.append("أرقامٌ فارسية (۰۱۲) مكان العربية")
    if subject in ARABIC_DIGIT_SUBJECTS and WESTERN_DIGITS.search(blob):
        bad.append("أرقامٌ لاتينية في مادةٍ أرقامُها عربية")

    # 📏 **الخيارُ الصحيحُ الأطولُ يُكشف بلا فهم** — والخادمُ يخلط المواقعَ
    #    ولا يخلط الأطوال. (عيبٌ معروفٌ في كل الموديلات بلا استثناء.)
    # 📐 **والعتبةُ مقيسةٌ لا مُخمَّنة**: على ٦١٨ سؤالاً اجتازت، كان وسيطُ
    #    نسبةِ طول الصحيح إلى غيره **١٫٠٦** وأقصاها ٢٫٣٣. فالعتبةُ القديمة
    #    (طول>١٢ ونسبة>١٫٩) أسقطت **٧٩ سؤالاً**، أكثرُها في التاريخ
    #    والجغرافيا حيث الجوابُ الصحيح عبارةٌ وصفيةٌ بطبعها لا كلمة.
    lens = [len(o) for o in options]
    right = lens[item["correct_index"]]
    others = [l for i, l in enumerate(lens) if i != item["correct_index"]]
    if right > 40 and right > 2.2 * max(1, st.median(others)):
        bad.append("الخيارُ الصحيح أطولُ من إخوته بكثير فيُكشف بلا فهم")
    return bad


def _shape_defects(questions: list, want: int, *, strict: bool,
                   lesson: str = "") -> list:
    """عيوبُ **الشكل** (أوزان · مستويات · تغطية · تنويع) لمجموعةِ أسئلة.

    🔴 **ولماذا تُفحص الدفعةُ لا البنكُ وحده؟** أوّلُ تصميمٍ فحص البنكَ
       **بعد** اكتمال دفعاته، فكانت عيوبُه البنيوية (أوزانٌ غيرُ معايَرة ·
       تغطيةٌ ضيّقة) **لا تصل الموديلَ أبداً**: يُعاد الطلبُ على عيوب
       الأسئلة المفردة وحدها فيعود بنفس الخلل ويُحرق النداءُ هباءً.
       والنموذجُ لا يُصلح ما لا يعرف أنه أخطأ فيه — قِيس هذا في بناء
       الشروح، ووقع هنا ثانيةً.
    ⇐ فصارت تُقاس **داخل الدفعة** حيث يمكن تصحيحُها بنداءٍ واحدٍ موجَّه.
    """
    bad = []
    n = len(questions)
    if n == 0:
        return ["لا أسئلة"]

    # ⚖️ **ولا تُفحص الأوزانُ هنا**: `calibrate_weights` تفرض توزيعَها
    #    بالرتبة بعد اكتمال البنك، فمصارعةُ الموديل عليها تحرق نداءاتٍ
    #    في شيءٍ نملك حسمَه مجّاناً.

    drill = is_exercise(lesson)
    lv = Counter(q["level"] for q in questions)
    floor_lv = 0.12 if strict else 0.09
    if not drill:
        for name in QB.LEVELS:
            if lv[name] / n < floor_lv:
                bad.append(f"مستوى «{name}» شبه غائب ({lv[name]} من {n})")

    topics = Counter(q["topic"] for q in questions if q["topic"])
    want_t = max(4, int(n * (0.55 if strict else 0.45)))
    if drill:
        want_t = 3
    if len(topics) < want_t:
        bad.append(f"التغطيةُ ضيّقة: {len(topics)} نقطةً في {n} سؤالاً — "
                   "اجعل `topic` النقطةَ الدقيقة لا عنوانَ القسم")
    # ⚖️ **وسقفُ تكرار النقطة في الدفعة وحدها.** في البنك المجتمع يكفي
    #    حارسُ الاتّساع أعلاه، و[quiz_bank.select] يسقّف النقطةَ بسؤالين
    #    **عند العرض** — فتكرارُها في المخزون يوسّع الخيارَ ولا يضيّقه.
    if strict and topics:
        t, c = topics.most_common(1)[0]
        if c > 2:
            bad.append(f"«{t}» تكرّرت {c} مرّات — لا أكثر من سؤالين للنقطة")

    defs = sum(1 for q in questions if DEFINITION_OPENER.search(q["q"]))
    if not drill and defs / n > 0.55:
        bad.append(f"٪{defs*100//n} من الأسئلة تبدأ بـ«ما هو…؟» — "
                   "نوّع زاويةَ السؤال لا ألفاظَه")
    return bad


def draw_defects(questions: list, source: str, *, need_factor: int = 8) -> list:
    """عيبُ نقلِ ترميز الرسم — وهو **من عيوب الشكل التي تُقاس لا تُرجى**.

    🔴 وكان يُفحص على البنك المجتمع وحده، فلا يصل الموديلَ في التصحيح:
       يُعاد الطلبُ على عيوبِ الأسئلة ويعود بنفس الخلوّ من الرسوم. وهي عينُ
       علّةِ الأوزان — **النموذجُ لا يُصلح ما لا يعرف أنه أخطأ فيه**.
    """
    # ☢️ **ولا يُعدّ إلا الترميزُ الحقيقيّ** — سابعُ مرّةٍ يكون المقياسُ فيها
    #    هو المخطئ. قِيس (2026-09-17): درس «القطع المكافئ» فيه ١٥ ترميزاً،
    #    **أربعةَ عشرَ منها `\frac{3}{2}` و`\frac{1}{4}`** — خطواتُ حسابٍ
    #    داخل أمثلةٍ محلولة لا قوانينَ تُرسم. ودرسُ الخرائط فيه
    #    `\frac{1}{10,000}` وهو **مقياسُ خريطةٍ** لا كسرٌ أصلاً.
    #    فمطالبةُ الأسئلة بحملها مطالبةٌ بلا معنى، ورفضُ بنكٍ سليمٍ لأجلها
    #    إتلافٌ — ونفسُ التمييز قائمٌ في [build_explanations.verify].
    # ⚖️ **والعددُ من [quiz_spec.notation_quota] لا من هنا** — فالبرومبت
    #    يطلب حصّةً مرقّمة وهذا يقيسها، ولا يصحّ أن يختلف الرقمان.
    need, _ = quiz_spec.notation_quota(source, need_factor)
    codes = len(quiz_spec.real_codes(source))
    if not need or not questions:
        return []
    have = sum(1 for q in questions
               if DRAW.search(_norm_codes(q["q"] + " ".join(q["options"]))))
    if have >= need:
        return []
    return [f"الدرسُ فيه {codes} ترميزَ رسمٍ ولم يحمل منها إلا {have} سؤالاً "
            f"(المطلوب {need} على الأقلّ) — السؤالُ عن مرسومٍ يعرض رسمَه"]


def check_batch(questions: list, want: int, subject: str,
                lesson: str = "", source: str = "") -> list:
    """عيوبُ دفعةٍ واحدة — هي ما يصل الموديلَ في النداء التصحيحي."""
    bad = []
    if len(questions) < max(3, int(want * 0.85)):
        bad.append(f"العدد {len(questions)} وهو أقلُّ من المطلوب {want}")
    bad += draw_defects(questions, source, need_factor=12)
    return bad + _shape_defects(questions, want, strict=True, lesson=lesson)


def _bank_floor(want: int) -> int:
    """أقلُّ ما يخدم التطبيق: ١٦ سؤالاً، وأربعٌ وعشرون تكفي أيَّ درس."""
    return max(16, min(round(want * 0.60), 24))


