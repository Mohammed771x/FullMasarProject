# ==================================================
# 🧮 core/fractions.py — تحويل كسور نصّ الكتاب إلى ترميز \frac
# ==================================================
# **المشكلة التي يحلّها هذا الملف** (لاحظها المالك):
#   البرومبت يأمر الموديل بنقل القوانين **حرفياً كما في الدرس**، ونصّ الدرس
#   في ملفات البيانات مكتوب بالشرطة المائلة. فالموديل ينقل الشرطة بأمانة،
#   ويبقى القانون على سطر واحد مهما شدّدنا في البرومبت — لأنه يطيعنا فعلاً.
#
# **الحل:** نصلح النصّ **قبل** أن يراه الموديل. فحين ينقل حرفياً، ينقل
#   الكسر مرسوماً. لا تعارض مع «انقل من الكتاب» — الكتاب نفسه صار مضبوطاً.
#
# ⚠️ **التمييز دلالي لا شكلي:** في نصّ الفيزياء الحقيقي:
#       ١/λ  كسر          ·  ١/m   وحدة (مقلوب المتر)
#       و / ج  كسر         ·  م / ث  وحدة (متر لكل ثانية)
#   لا قاعدة شكلية تفرّقهما. لكن **قائمة الوحدات مغلقة ومعروفة**، فنعتمدها:
#   إن كان أحد طرفَي الشرطة وحدةَ قياس ⇒ لا نلمسها. وإلا ⇒ كسر.

import re

# ── وحدات القياس في منهج الثانوية اليمنية (قائمة مغلقة) ──
#    اللاتينية حسّاسة لحالة الأحرف: c سرعة الضوء بينما C كولوم.
_ARABIC_UNITS = {
    "م", "سم", "مم", "كم", "مليمتر", "سنتيمتر", "متر", "كيلومتر",
    "ث", "ثا", "ثانية", "د", "دقيقة", "ساعة", "يوم", "سنة",
    "كجم", "كغم", "جم", "غم", "مجم", "طن", "كيلوجرام", "جرام",
    "نيوتن", "جول", "واط", "وات", "فولت", "أمبير", "امبير", "أوم", "اوم",
    "كولوم", "فاراد", "هنري", "هرتز", "تسلا", "ويبر", "باسكال",
    "لتر", "مل", "مول", "كلفن", "سلزيوس", "سيلزيوس", "درجة",
    "راديان", "راد", "دورة", "ذرة", "جسيم",
}
_LATIN_UNITS = {
    "m", "cm", "mm", "km", "s", "sec", "h", "min", "hr",
    "kg", "g", "mg", "N", "J", "W", "V", "A", "C", "F", "H",
    "Hz", "T", "Wb", "Pa", "L", "mL", "mol", "mole", "K", "eV", "Ω",
    "KJ", "kJ", "kj", "kcal", "cal", "atm", "ppm", "M", "rpm",
}

# ما يُلحق بالوحدة فيُهمل عند المقارنة: أُسّ · نقطة · مسافة
_STRIP = re.compile(r"[\^].*$|[.،,]+$|^[.،,]+")


def _bare(token: str) -> str:
    return _STRIP.sub("", token.strip()).strip()


# ⚠️ حروف عربية مفردة هي وحدات **وهي أيضاً رموز شائعة**: «م» متر وهي كذلك
#    أول «مفاعلة»، و«ث» ثانية وهي كذلك ثابت التكامل. فهذه **وحدات ضعيفة**:
#    لا تمنع التحويل إلا إذا كان الطرف الآخر وحدةً أيضاً («م/ث» تبقى، بينما
#    «1 / م سع» تصير كسراً). أمّا «كم» و«كولوم» و«m» فتمنع وحدها.
_WEAK_UNITS = {"م", "ث", "د", "ثا"}


def is_weak_unit(token: str) -> bool:
    return _bare(token) in _WEAK_UNITS


def is_unit(token: str) -> bool:
    """هل هذا المقدار وحدة قياس؟ (تُهمل الأُسس والنقاط)"""
    t = _bare(token)
    if not t:
        return False
    return t in _ARABIC_UNITS or t in _LATIN_UNITS


# ⚠️ **الشرطة النثرية**: العربية تستعمل «/» بمعنى «أو» — «انطلاق / انبعاث»
#    و«الأفقية/المائلة». هذه ليست كسوراً، وتحويلها يشوّه نصّ الدرس.
#    الفارق: طرفا الكسر **مقادير رياضية** (رقم · رمز قصير · قوس)، أما النثر
#    فطرفاه **كلمتان**. فنشترط أن يكون الطرفان رياضيَّين معاً.
_DIGITS = set("0123456789٠١٢٣٤٥٦٧٨٩")


def is_mathy(token: str, parenthesized: bool = False) -> bool:
    """هل هذا المقدار رياضي؟ (قوس · رقم · رمز قصير) لا كلمةً في جملة."""
    if parenthesized:
        return True
    t = _bare(token)
    if not t:
        return False
    if any(c in _DIGITS for c in t):
        return True
    # الرموز في المنهج حرف أو حرفان («س» · «ع» · «نق» · «λ»)، والكلمات أطول
    return len(t.replace(" ", "")) <= 2


# ما يقطع المقدار حول الشرطة. الأُسّ `^` لا يقطع كي تبقى `ن^2` مقداراً واحداً.
_BREAK = set(" +-−=×*(),،؛;:[]{}\n\t")


# الأقواس الثلاثة تُستعمل للتجميع في نصّ الكتاب: ( ) و [ ] و { }
_OPEN = {")": "(", "]": "[", "}": "{"}


def _extend_power(src: str, end: int) -> int:
    """يضمّ الأُسّ الملاصق للمقدار: «(س - أ)^(ن+1)» مقدار واحد لا مقدارٌ وأُسّ."""
    if end >= len(src) or src[end] != "^":
        return end
    k = end + 1
    if k < len(src) and src[k] == "(":
        depth = 0
        for j in range(k, len(src)):
            if src[j] == "(":
                depth += 1
            elif src[j] == ")":
                depth -= 1
                if depth == 0:
                    return j + 1
        return end
    while k < len(src) and src[k] not in _BREAK and src[k] != "/":
        k += 1
    return k


def _left_atom(sofar: str):
    """آخر مقدار قبل الشرطة: قوس كامل أو رمز واحد. يعيد (النص، بداية، أقوس)."""
    end = len(sofar)
    while end > 0 and sofar[end - 1] == " ":
        end -= 1
    if end == 0:
        return None

    if sofar[end - 1] in _OPEN:
        close = sofar[end - 1]
        opn = _OPEN[close]
        depth = 0
        for k in range(end - 1, -1, -1):
            if sofar[k] == close:
                depth += 1
            elif sofar[k] == opn:
                depth -= 1
                if depth == 0:
                    return sofar[k + 1:end - 1], k, True
        return None

    start = end
    while start > 0 and sofar[start - 1] not in _BREAK:
        start -= 1
    if start == end:
        return None

    # «(س+1)^2» — المقدار ملاصق لقوسٍ مغلق قبله، فنضمّ القوس كله معه
    if start >= 1 and sofar[start - 1] in _OPEN:
        close = sofar[start - 1]
        opn = _OPEN[close]
        depth = 0
        for k in range(start - 1, -1, -1):
            if sofar[k] == close:
                depth += 1
            elif sofar[k] == opn:
                depth -= 1
                if depth == 0:
                    return sofar[k:end], k, True
    return sofar[start:end], start, False


def _right_atom(src: str, frm: int):
    """أول مقدار بعد الشرطة. يعيد (النص، النهاية)."""
    start = frm
    while start < len(src) and src[start] == " ":
        start += 1
    if start >= len(src):
        return None

    for opn, close in (("(", ")"), ("[", "]"), ("{", "}")):
        if src[start] == opn:
            depth = 0
            for k in range(start, len(src)):
                if src[k] == opn:
                    depth += 1
                elif src[k] == close:
                    depth -= 1
                    if depth == 0:
                        stop = _extend_power(src, k + 1)
                        body = src[start + 1:k] if stop == k + 1 else src[start:stop]
                        return body, stop, True
            return None

    end = start
    while end < len(src) and src[end] not in _BREAK and src[end] != "/":
        end += 1
    if end == start:
        return None

    # 📐 دالّة بأقواس: «جذر(2)» و«جا(س)» مقدار واحد لا رمز مبتور
    if end < len(src) and src[end] == "(":
        depth = 0
        for k in range(end, len(src)):
            if src[k] == "(":
                depth += 1
            elif src[k] == ")":
                depth -= 1
                if depth == 0:
                    return src[start:k + 1], k + 1, True
    return src[start:end], end, False


def to_frac(text: str) -> str:
    """يحوّل كسور النصّ إلى `\\frac{بسط}{مقام}` ويترك وحدات القياس كما هي."""
    if not text or "/" not in text:
        return text

    # ⚠️ المخزن نصٌّ لا قائمة: كنّا نحذف بفهرس نصّي من قائمةِ عناصر
    #    متعددة الأحرف بعد إدراج `\\frac{...}`، فتتزحزح الفهارس ويتكرر
    #    المقدار («20 / 10» تخرج «20 \\frac{20}{10}»).
    out = ""
    i = 0
    while i < len(text):
        ch = text[i]
        if ch != "/":
            out += ch
            i += 1
            continue

        left = _left_atom(out)
        right = _right_atom(text, i + 1)

        if left is None or right is None:
            out += ch
            i += 1
            continue

        left_text, left_start, left_paren = left
        right_text, right_end, right_paren = right

        # 🛡️ قاعدة الوحدات:
        #    • الطرفان وحدتان        ⇒ وحدة مركّبة («م/ث») فلا تُمسّ
        #    • طرف وحدة **قوية**     ⇒ وحدة («1/m» · «72 كم/ساعة») فلا تُمسّ
        #    • طرف وحدة **ضعيفة** فقط ⇒ رمزٌ لا وحدة («1 / م سع») ⇒ كسر
        # ✍️ شرطة نثرية بين كلمتين ⇒ ليست كسراً
        if not (is_mathy(left_text, left_paren) and
                is_mathy(right_text, right_paren)):
            out += ch
            i += 1
            continue

        left_u, right_u = is_unit(left_text), is_unit(right_text)
        both = left_u and right_u
        strong = (left_u and not is_weak_unit(left_text)) or \
                 (right_u and not is_weak_unit(right_text))
        if both or strong:
            out += ch
            i += 1
            continue

        out = out[:left_start] + "\\frac{%s}{%s}" % (
            to_frac(left_text.strip()), to_frac(right_text.strip()))
        i = right_end

    return out
