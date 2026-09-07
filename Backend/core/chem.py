# ==================================================
# ⚗️ core/chem.py — ترميز الصيغ البنائية قبل أن يراها الموديل
# ==================================================
# نظير `core/fractions.py` تماماً، وللسبب نفسه:
#
#   البرومبت يأمر الموديل بنقل ما في الدرس **حرفياً**، ونصّ الدرس في ملفات
#   البيانات يكتب الصيغة سطراً مسطّحاً (`CH3 CH2 CH2 NH2`). فالموديل ينقلها
#   بأمانة — **يطيعنا فعلاً** — والطالب يرى سطراً لا صيغة بنائية.
#
# الحل: نصلح نصّ الكتاب **قبل** أن يراه الموديل، فالنقل الحرفي ينقل
# الصيغة **مرمَّزة** (`\chem{...}`) والتطبيق يرسمها كما في الكتاب.
#
# ⚠️ **الخطر هنا ليس النقص بل الإفراط.** نصّ الكيمياء مليء برموز تشبه
#    الصيغ وليست صيغاً: «CH4 - H = CH3» معادلة اشتقاق، و«C n H 2n+2» قانون
#    عام، و«N» وحدها حرف. فالقواعد أدناه **حارسة لا كاشفة**: ما لم نجزم
#    أنه صيغة بنائية يُترك كما هو.

import re

# ══════════════════════════════════════════════════════════
# 🔒 نطاق التطبيق: الكيمياء وحدها
# ══════════════════════════════════════════════════════════
# الصيغ البنائية شأنٌ كيميائي. وتشغيلُ التحويل على كل المواد يفتح باباً
# لخطأ لا لزوم له: نصّ الأحياء والفيزياء والعربي فيه رموزٌ لاتينية كثيرة،
# وحارسُ `_is_structure` صارم لكنه ليس برهاناً. فالقاعدة هنا **قائمة بيضاء**:
# ما لم تُذكر المادة صراحةً، يمرّ نصّها كما هو حرفياً بلا لمسة.
ORGANIC_SUBJECTS = frozenset({"كيمياء"})


def is_organic_subject(subject) -> bool:
    return (subject or "").strip() in ORGANIC_SUBJECTS


def for_subject(text: str, subject) -> str:
    """يطبّق ترميزَي الصيغة والحلقة **إن كانت المادة كيميائية فقط**."""
    if not is_organic_subject(subject):
        return text
    return to_ring(to_chem(text))



# مجموعات عضوية معروفة — القائمة مغلقة عمداً.
_GROUPS = {
    "CH3", "CH2", "CH", "C", "N", "NH", "NH2", "NH3", "O", "OH", "S", "SH",
    "COOH", "CHO", "CO", "CN", "NO2", "OCH3", "R", "R'", "Ar", "H", "H2",
}

# رابطة بين مجموعتين: شرطة أو مساواة أو ثلاثية — أو فراغ (صيغة الكتاب).
_BOND = r"(?:\s*[-–—=#≡]\s*|\s+)"
# المجموعة = رموز عناصر متتابعة بأرقامها: «CH3» = C ثم H3 — لا رمزٌ واحد.
_ATOM = r"[A-Z][a-z]?[0-9]{0,2}"
_GROUP_RE = rf"(?:\((?:{_ATOM})+\)|(?:{_ATOM})+)'?"

# مرشّح: سلسلتان فأكثر تفصلهما روابط.
_CANDIDATE = re.compile(rf"(?<![A-Za-z0-9]){_GROUP_RE}(?:{_BOND}{_GROUP_RE}){{1,20}}(?![A-Za-z0-9])")

# 🚫 سياقات تمنع التحويل حتى لو طابق الشكل.
_EQUATION_HINT = re.compile(r"[=←→⇌]|-->|->|<=>")


def _tokens(fragment: str):
    """يفكّك المرشّح إلى (مجموعات، روابط) — أو None إن لم يكن صيغة."""
    parts = re.split(r"(\s*[-–—=#≡]\s*|\s+)", fragment)
    groups, bonds = [], []
    for i, part in enumerate(parts):
        if i % 2 == 0:
            groups.append(part.strip())
        else:
            bonds.append(part.strip())
    return groups, bonds


def _is_structure(fragment: str) -> bool:
    """هل هذا المقطع صيغة بنائية فعلاً؟ ثلاث بوّابات، كلها ضرورية."""
    groups, _ = _tokens(fragment)
    if len(groups) < 2:
        return False

    # 1️⃣ كل مجموعة يجب أن تكون معروفة. «C n H 2n+2» يسقط هنا (n ليست مجموعة).
    clean = [g.strip("()") for g in groups]
    if not all(g in _GROUPS for g in clean):
        return False

    # 2️⃣ صيغة من كربونٍ واحد فقط ليست «بنائية» — «CH4» تُكتب نصاً كما هي.
    #    نطلب أن تحوي السلسلة مجموعتين كربونيتين أو مجموعةً وظيفية.
    carbons = sum(1 for g in clean if g.startswith("C") and g != "COOH")
    functional = any(g in {"NH2", "NH", "OH", "COOH", "CHO", "CN", "NO2"}
                     for g in clean)
    if carbons < 2 and not functional:
        return False

    # 3️⃣ الهيدروجين المفرد طرفاً = معادلة اشتقاق لا صيغة («CH4 - H = CH3»).
    if "H" in clean or "H2" in clean:
        return False

    return True


def _wrap(fragment: str) -> str:
    """يحوّل مقطعاً مؤكَّداً إلى `\\chem{...}` بعد توحيد فواصله."""
    groups, bonds = _tokens(fragment)
    out = groups[0]
    for g, b in zip(groups[1:], bonds):
        out += (b if b else "-") + g
    return "\\chem{" + out + "}"


def to_chem(text: str) -> str:
    """يرمّز الصيغ البنائية في نصّ الكتاب. يعيد النصّ كما هو إن لم يجد شيئاً.

    ⚠️ السطر الذي فيه علامة معادلة (`=` · `->` · `→`) **يُترك كاملاً**:
       «CH4 - H = CH3» اشتقاقٌ لا صيغة، و«A + B -> C» معادلة تفاعل.
    """
    if not text or "\\chem" in text:
        return text

    out_lines = []
    for line in text.split("\n"):
        if _EQUATION_HINT.search(line):
            out_lines.append(line)
            continue
        out_lines.append(_CANDIDATE.sub(
            lambda m: _wrap(m.group(0)) if _is_structure(m.group(0)) else m.group(0),
            line))
    return "\n".join(out_lines)


# ══════════════════ الحلقات من وصف الكتاب ══════════════════
# الكتاب لا يرسم الحلقة في البيانات بل **يصفها بالكلمات** («رسم لمثلث
# يمثل بروبان حلقي»). فالوصف يُرفق به ترميزه كي ينقله الموديل مرمَّزاً.

_SHAPES = {
    "مثلث": 3, "ثلاثي": 3,
    "مربع": 4, "رباعي": 4,
    "خماسي": 5, "مخمس": 5,
    "سداسي": 6, "مسدس": 6,
    "سباعي": 7, "خماسية": 5, "سداسية": 6,
    # الكتاب يقول «حلقة بنزين» بلا ذكر شكلها — وهي سداسية عطرية بالتعريف.
    "بنزين": 6,
}

# ⚠️ **الأطول أولاً.** بدائل `re` تُجرَّب بالترتيب، فلو سبقت «سداسي»
#    أختَها «سداسية» طابقت جزءها الأول وتركت «ة» معلّقة في النص:
#    «حلقة سداسية تحتوي…» ⇒ «\\ring{6|N|+CONH2}ة تحتوي…» — نصٌّ مشوّه
#    على شاشة الطالب. (وقع فعلاً في درس النيكوتيناميد.)
_RING_HINT = re.compile("|".join(sorted(_SHAPES, key=len, reverse=True)))

# 🔒 بوّابة السياق: اسم الشكل وحده لا يكفي.
#    «البنزين هو الأساس في المركبات الأروماتية» جملةُ تعريف لا رسم، بينما
#    «رسمة البنزين : شكل سداسي بداخله دائرة» رسمٌ يُطلب. فنشترط كلمةً تدلّ
#    على الرسم أو الحلقة — وبها ينضبط الكشف بلا إفراط.
_RING_CONTEXT = re.compile("رسم|شكل|حلق")

# 🔴 **اسمُ الرسم يُبتلع مع الشكل — وهذا ما حسم الامتثال.**
#    كان السطر يصير «رسمة \ring{3} : تمثل بروبان حلقي»، فيقرأ الموديل كلمة
#    «رسمة» على أنها وصفٌ مطلوبٌ منه فيترجم الترميز إلى «يتم تمثيله برسم
#    مثلث» — ٠ من ٣ محاولات متتالية، بلا عشوائية. حين لم يبقَ في السطر إلا
#    الترميز صار النقلُ الحرفيّ نقلاً للرسم. (والنصُّ الشارح بعد «:» يبقى
#    كما في الكتاب — نحذف اسمَ الرسم لا محتواه.)
_DRAW_WORD = re.compile(r"(?:ال)?(?:رسمة|رسوم|رسم|شكل|حلقة)\s*(?:ل)?\s*(?:ال)?\s*$")


def ring_codes(description: str) -> list[str]:
    """كل الأشكال في وصفٍ واحد.

    ⚠️ الكتاب يجمع ثلاثة رسوم في وصفٍ واحد: «مثلث يمثل سيكلوبروبان ، مربع
       يمثل سيكلوبيوتان ، وشكل سداسي يمثل سيكلوهيكسان». فإرجاع أوّلها وحده
       يُضيّع اثنين — وهذا ما حدث فعلاً في أول تجربة.
    """
    # 🔑 بوّابة السياق تُفحص على **الوصف كاملاً** لا على كل جزء: الجملة
    #    «مثلث يمثل سيكلوبروبان ، مربع يمثل سيكلوبيوتان» سياقُها في أوّلها،
    #    وأجزاؤها التالية بلا كلمة «رسم» فتسقط لو فُحص كلُّ جزء وحده.
    if not description or not _RING_CONTEXT.search(description):
        return []
    parts = re.split(r"[،,.]\s*", description)
    out, seen = [], set()
    for part in parts:
        code = _ring_from(part)
        if code and code not in seen:
            seen.add(code)
            out.append(code)
    if not out:
        code = _ring_from(description)
        if code:
            out.append(code)
    return out


def ring_code(description: str) -> str | None:
    """يستنتج ترميز `\\ring{...}` من وصفٍ عربي — أو None إن لم يتّضح.

    مثال: «شكل سداسي غير مشبع به روابط ثنائية فيه ذرة نيتروجين N»
          ⇒ `\\ring{6|ar|N}`
    """
    if not description or not _RING_CONTEXT.search(description):
        return None
    return _ring_from(description)


def _ring_from(description: str) -> str | None:
    """استخراج الترميز بلا بوّابة سياق — للاستعمال الداخلي بعد فحصها."""
    if not description:
        return None
    m = _RING_HINT.search(description)
    if not m:
        return None
    size = _SHAPES[m.group(0)]

    aromatic = ("غير مشبع" in description or "بنزين" in description
                or "ثنائية" in description or "عطري" in description)
    parts = [str(size)]
    if aromatic:
        parts.append("ar")

    # ذرّة غريبة داخل الحلقة.
    if "نيتروجين" in description or re.search(r"\bN\b", description):
        parts.append("NH" if "مرتبطة بهيدروجين" in description else "N")
    elif "أكسجين" in description:
        parts.append("O")
    elif "كبريت" in description:
        parts.append("S")

    # مجموعة معلّقة على الحلقة.
    # ⚠️ الكتاب يكتبها بصيغ شتّى: «مرتبط به NH2» · «مرتبطة بمجموعة NH2» ·
    #    «مرتبط بـ NH-CH3». فالمرساة كلمة «مجموعة» أو فعل الارتباط ثم أول رمز.
    sub = re.search(
        # الكلمات المتخطّاة **عربية حصراً**، وإلا ابتلع `\S+` رمزَ المجموعة
        # نفسه فخرج «+H2» بدل «+NH2» (وقع فعلاً).
        r"(?:مجموعة|مرتبط\S*(?:\s+[؀-ۿ]+){0,2})\s*ـ?\s*"
        r"([A-Z][A-Za-z0-9-]*)",
        description)
    # «N» و«H» ليستا مجموعتين معلّقتين: الأولى ذرّة الحلقة نفسها، والثانية
    # هيدروجينها («نيتروجين N مرتبطة بهيدروجين H») — فأنتجت «+H» زائفة.
    if sub and sub.group(1) not in {"N", "H"}:
        parts.append("+" + sub.group(1))

    return "\\ring{" + "|".join(parts) + "}"


def to_ring(text: str) -> str:
    """يستبدل وصفَ الشكل بترميزه **في مكانه** داخل النصّ.

    🔴 **لماذا استبدالٌ لا إضافة؟** المحاولة الأولى أضافت سطراً موازياً
       («الرسم بالترميز الإلزامي: \\ring{3}») بجوار الوصف النثري، فبقي أمام
       الموديل تمثيلان للشيء نفسه — فاختار النثر وأعاد صياغته: «يتم تمثيله
       برسم مثلث». وهذا بالضبط ما تعلّمناه في الكسور: `to_frac` **تستبدل**
       الشرطة ولا تضيف تلميحاً بجوارها، ولذلك نجحت. فحين لا يبقى في النصّ
       إلا الترميز، يصير النقلُ الحرفيّ نقلاً للرسم.
    """
    if not text or "\\ring" in text:
        return text

    out_lines = []
    for line in text.split("\n"):
        if not _RING_CONTEXT.search(line):
            out_lines.append(line)
            continue
        # كل جزء (بين الفواصل) له شكله وترميزه؛ الاستبدال داخل الجزء نفسه.
        pieces = re.split(r"([،,.]\s*)", line)
        for i in range(0, len(pieces), 2):
            part = pieces[i]
            code = _ring_from(part)
            if not code:
                continue
            m = _RING_HINT.search(part)
            if m:
                # يبتلع «ال» التعريف الملتصقة كي لا يبقى «رسمة ال\\ring{3}».
                start = m.start()
                # يبتلع «ال» التعريف ثم اسمَ الرسم قبلها، طبقةً طبقة.
                for _ in range(4):
                    if part[:start].endswith("ال"):
                        start -= 2
                        continue
                    w = _DRAW_WORD.search(part[:start])
                    if not w or w.start() >= start:
                        break
                    start = w.start()
                pieces[i] = part[:start] + code + part[m.end():]
        out_lines.append("".join(pieces))
    return "\n".join(out_lines)


# ══════════════════════════════════════════════════════════
# 🏷️ الاسم ⇐ الصيغة البنائية (الأميدات المفتوحة وحدها)
# ══════════════════════════════════════════════════════════
# **المشكلة:** درس «أمثلة متقدمة لتسمية الأميدات» يخزّن كلَّ مثال زوجاً:
# `الرسم` وصفاً نثرياً + `التسمية` اسماً. فيقرأ الموديل الوصف ويحكيه:
# «المثال الأول: الرسم لدينا سلسلة من أربع كربونات مرتبطة بذرة نيتروجين» —
# والطالب أراد **الرسم ثم التسمية تحته**.
#
# 🔑 **ولماذا من الاسم لا من الوصف؟** لأن الوصف **ناقصٌ بطبعه**: «سلسلة من
#    4 كربونات مرتبطة بـ NH» لا تذكر الكربونيل، فبناءُ الصيغة منه حرفياً
#    يعطي **أميناً لا أميداً** — كيمياء خاطئة على شاشة الطالب. أما الاسم
#    «N-بروبيل بيوتاناميد» فيحدّد البنية تحديداً تامّاً لا لبس فيه.
#    والاسم **من الكتاب**، والرسم في الكتاب المطبوع يطابق ما نبنيه — فهذا
#    **ترميمُ** رسمٍ ضاع في النسخ، لا اختراعُ معلومة من خارج الكتاب.
#
# 🔒 **وحدوده صارمة:** ما لم يُفهم الاسم بيقين تُرجع `None` ويبقى نصّ الكتاب
#    كما هو. والأسماء العطرية (فينيل · بنزاميد · نيكوتيناميد) **مرفوضة
#    عمداً**: الرسّام لا يصل حلقةً بسلسلة بعد، ورسمٌ ناقص أسوأ من وصفٍ صادق.

_ALKANE_N = {
    "ميثان": 1, "إيثان": 2, "ايثان": 2, "بروبان": 3, "بيوتان": 4, "بنتان": 5,
    "هكسان": 6, "هيكسان": 6, "هيبتان": 7, "أوكتان": 8, "اوكتان": 8,
    "نونان": 9, "ديكان": 10,
}

_ALKYL_N = {
    "ميثيل": 1, "إيثيل": 2, "ايثيل": 2, "بروبيل": 3, "بيوتيل": 4, "بنتيل": 5,
    "هكسيل": 6, "هيكسيل": 6, "هيبتيل": 7, "أوكتيل": 8, "اوكتيل": 8,
}

_MULTIPLIER = {"ثنائي": 2, "ثلاثي": 3, "رباعي": 4}

# 🚫 ما يحوي حلقةً يُرفض — الرسّام لا يصل حلقةً بسلسلة.
_AROMATIC_WORDS = re.compile("فينيل|بنزاميد|بنزين|نيكوتيناميد|أنيلين|انيلين|حلق")


def _alkyl_chain(n: int) -> str:
    """سلسلة ألكيل من n كربوناً كما تُكتب مكثّفةً: CH3 · CH2-CH3 · …"""
    if n <= 0:
        return ""
    return "-".join(["CH2"] * (n - 1) + ["CH3"])


def _acyl_chain(n: int) -> str:
    """جذع الأميد: (n-1) كربوناً ثم كربونيل. بيوتاناميد ⇒ CH3-CH2-CH2-C(=O).

    ⚠️ **الاتجاه يختلف عن `_alkyl_chain`**: الفرع يتّصل من طرفه الأول
       فيُكتب `CH2-CH2-CH3`، أما الجذع فيُقرأ من اليسار وينتهي بالكربونيل
       فيُكتب `CH3-CH2-CH2-C(=O)`. عكسُهما ينتج سلسلةً مقلوبة.
    """
    return "-".join(["CH3"] + ["CH2"] * (n - 2)) + "-C(=O)"


def chem_from_name(name: str):
    """يبني ترميز الصيغة من اسم أميد مفتوح — أو `None` إن لم يُجزَم.

    أمثلة من الكتاب:
      «N-بروبيل بيوتاناميد»          ⇒ CH3-CH2-CH2-C(=O)-NH-CH2-CH2-CH3
      «N-ميثيل N-بنتيل بيوتاناميد»   ⇒ CH3-CH2-CH2-C(=O)-N(CH3)-…-CH3
      «N, N - ثنائي إيثيل إيثاناميد» ⇒ CH3-C(=O)-N(CH2-CH3)-CH2-CH3
      «هيبتاناميد»                   ⇒ CH3-CH2-CH2-CH2-CH2-CH2-C(=O)-NH2
    """
    if not name:
        return None
    text = name.split("(")[0]          # نتجاهل ما بين قوسين («الاسم الشائع»)
    if _AROMATIC_WORDS.search(text):
        return None                     # حلقةٌ موصولة بسلسلة — خارج المقدور

    m = re.search(r"([؀-ۿ]+?)\s*ا?ميد\b", text)
    if not m:
        return None
    root = m.group(1).strip()
    carbons = _ALKANE_N.get(root) or _ALKANE_N.get(root.rstrip("ا"))
    if not carbons or carbons < 2:
        return None

    # بدائل النيتروجين: «N-ألكيل» متكرّرة، أو «N, N - ثنائي ألكيل».
    subs = []
    before_root = text[: m.start(1)]
    mult = re.search(r"(ثنائي|ثلاثي|رباعي)\s+([؀-ۿ]+)", before_root)
    if mult and mult.group(2) in _ALKYL_N:
        subs = [_ALKYL_N[mult.group(2)]] * _MULTIPLIER[mult.group(1)]
    else:
        for token in re.findall(r"N\s*-\s*([؀-ۿ]+)", before_root):
            if token not in _ALKYL_N:
                return None             # بديلٌ مجهول ⇒ لا نخمّن
            subs.append(_ALKYL_N[token])

    if len(subs) > 2:
        return None

    if not subs:
        nitrogen = "NH2"
    elif len(subs) == 1:
        nitrogen = "NH-" + _alkyl_chain(subs[0])
    else:
        nitrogen = "N(" + _alkyl_chain(subs[0]) + ")-" + _alkyl_chain(subs[1])

    return "\\chem{" + _acyl_chain(carbons) + "-" + nitrogen + "}"
