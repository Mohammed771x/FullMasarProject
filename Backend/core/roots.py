# ==================================================
# √ core/roots.py — الجذر يُرسم لا يُكتب كلمةً
# ==================================================
# 🔴 **ما رآه المالك (2026-09-10):** «ليش تكتبه *الجذر*؟ اكتب جذر يعني
#    ارسمه». فالكتاب والموديل يكتبان «جذر(٧)» و«جذر ٢» نصّاً، والتطبيق
#    يرسم `\sqrt{...}` — ولا أحد يترجم بينهما.
#
# ⭐ ونفس معمار [core/fractions.py] بالضبط: نستبدل **صيغة الكتاب** بترميز
#    الرسّام قبل أن يراه الموديل وبعد أن يجيب، فلا نطلب منه أن يرسم.
#
# 🔴🔴 **وأخطرُ ما في هذا الملف حدُّ نطاقه.** مسحُ كل بيانات المنهج:
#      • «جذر س» ٢٤٢ مرة — **١١٦ منها في الأحياء** وهي جذرُ النبات:
#        «جذر وتدي» · «جذر ليفي» · «امتصاص الماء في الجذر».
#      • «√» ٢٠٣ مرات — أكثرها **علامةُ صحّ**: «ضع العلامة ( √ )».
#      فالتحويل الأعمى يقلب دروس الأحياء والتاريخ إلى طلاسم.
#
# ⚖️ فالحدّ طبقتان: **مادةٌ رياضية** ثم **سياقٌ رياضيّ للمقدار**.

import re

# المواد التي للجذر فيها معنىً رياضيّ — نظير `chem.ORGANIC_SUBJECTS`.
ROOT_SUBJECTS = frozenset({"رياضيات", "فيزياء", "كيمياء", "منطق"})


def is_root_subject(subject: str) -> bool:
    return (subject or "").strip() in ROOT_SUBJECTS


_DIGITS = set("0123456789٠١٢٣٤٥٦٧٨٩")
_BREAK = set(" +-−=×*/(),،؛;:[]{}\n\t|")

# رموز المقادير في المنهج اليمني — قائمةٌ مغلقة كقائمة الوحدات.
_SYMBOLS = frozenset({
    "س", "ص", "ع", "ن", "ر", "أ", "ب", "جـ", "ج", "د", "هـ", "ق", "ل", "م",
    "ك", "ط", "و", "ز", "ح", "خ", "π", "λ", "Δ", "x", "y", "z", "a", "b",
    "c", "n", "r", "R", "T", "V", "E", "F", "L", "C",
})

# «الجذر التربيعي لـ س» · «جذر تكعيبي (٨)» · «الجذر_التكعيبي»
#
# 🔴 **`ال?جذر` تجعل الألف إلزامية** — فتلتقط «الجذر» وتفوت «جذر تكعيبي»
#    و«جذر_تكعيبي» و«جذر تربيعي» (٨ مواضع). نفسُ فخِّ `ال?مضروب` حرفياً:
#    نمطٌ يعمل ويُخطئ. والصواب `(?:ال)?` على المقطع كلِّه — في **الموضعين**.
_AL = r"(?:ال)?"
_NAMED = re.compile(_AL + r"جذر[\s_]+" + _AL + r"تربيعي\s*(?:ل\s*ـ?\s*)?")
_NAMED_CUBE = re.compile(_AL + r"جذر[\s_]+" + _AL + r"تكعيبي\s*(?:ل\s*ـ?\s*)?")



# 🔴 **حرفٌ عربيّ بعد «جذر» يعني كلمةً أخرى لا جذراً.**
#
#    «أحد **جذري** معادلة» و«مجموع ال**جذرين**» و«**جذرها**» — كلُّها تبدأ
#    بـ«جذر». وتحويلُها أخرج «أحد √ي معادلة» على شاشة الطالب: كلمةٌ عربية
#    مُزّقت نصفين. رُصد في المحاكي (2026-09-10).
_ARABIC_LETTER = re.compile(r"[\u0621-\u064A]")


def _continues_word(src: str, i: int) -> bool:
    return i < len(src) and bool(_ARABIC_LETTER.match(src[i]))


def _balanced(src: str, i: int):
    """يعيد (المحتوى، الفهرس بعد القوس) إن كان عند `i` قوسٌ متوازن."""
    if i >= len(src) or src[i] != "(":
        return None
    depth = 0
    for k in range(i, len(src)):
        if src[k] == "(":
            depth += 1
        elif src[k] == ")":
            depth -= 1
            if depth == 0:
                return src[i + 1:k], k + 1
    return None


def _atom(src: str, i: int):
    """المقدار الذي يلي كلمة «جذر» بلا أقواس — إن كان رياضياً.

    ⚠️ **وهنا يُحسم أمرُ الأحياء**: «جذر وتدي» طرفُه كلمةٌ عربية طويلة،
       فلا يُقبل. أمّا «جذر ٢» و«جذر س» فمقدارٌ قصير أو رقم.
    """
    while i < len(src) and src[i] == " ":
        i += 1
    if i >= len(src):
        return None
    j = i
    while j < len(src) and src[j] not in _BREAK:
        j += 1
    tok = src[i:j]
    if not tok:
        return None
    # أُسٌّ ملاصق يبقى مع المقدار: «جذر س²»
    if any(c in _DIGITS for c in tok):
        return tok, j
    # ⚠️ ورمزٌ معروفٌ في المنهج لا أيُّ حرفٍ عربي: «جذر ي» ليست جذراً،
    #    و«ي» في العربية ضميرٌ لا مقدار.
    return (tok, j) if tok.lstrip("+-") in _SYMBOLS else None


def to_sqrt(text: str, subject: str = "") -> str:
    """يحوّل «جذر …» و«√ …» إلى `\\sqrt{…}` — في المواد الرياضية وحدها."""
    if not text or not is_root_subject(subject):
        return text
    if "جذر" not in text and "√" not in text:
        return text

    # ١) بالاسم الصريح: «الجذر التربيعي (١٩٦)» — والتكعيبي بدليله.
    text = _NAMED_CUBE.sub("∛", text)
    text = _NAMED.sub("جذر ", text)

    out, i = [], 0
    while i < len(text):
        # «جذر» كلمةً · «√» رمزاً · «∛» للتكعيبي
        if text.startswith("جذر", i) and not _continues_word(text, i + 3):
            head, skip = "\\sqrt", 3
        elif text[i] == "√":
            head, skip = "\\sqrt", 1
        elif text[i] == "∛":
            head, skip = "\\sqrt[3]", 1
        else:
            out.append(text[i])
            i += 1
            continue

        j = i + skip
        while j < len(text) and text[j] == " ":
            j += 1
        got = _balanced(text, j)
        if got is None:
            got = _atom(text, i + skip)
        if got is None:
            # ⚠️ «( √ )» علامةُ صحّ · «الجذر» وحدها اسمٌ — تبقى كما هي.
            out.append(text[i:i + skip])
            i += skip
            continue
        body, end = got
        out.append("%s{%s}" % (head, to_sqrt(body, subject)))
        i = end
    return "".join(out)
