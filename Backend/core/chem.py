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

# ⚗️ ومعادلاتُ التفاعل أوسع قليلاً: البناءُ الضوئي والتنفّسُ الخلوي في
#    الأحياء معادلاتٌ حقيقية تستحقّ الرسم.
#
# 🔒 **وهذه المجموعة تطابق `chemSubjects` في `masar_markdown.dart` عمداً**:
#    لا معنى لأن نأمر الموديلَ بصيغةٍ في مادةٍ لا يرسمها التطبيق. فإن
#    تغيّرت إحداهما فلتتغيّر الأخرى معها.
REACTION_SUBJECTS = frozenset({"كيمياء", "احياء"})


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
# يمثل بروبان حلقي»)، أو **يسمّيها** («هكسين حلقي»). فيُستبدل الوصف بترميزه
# ويُلحق بالاسم ترميزُه، كي ينقله الموديل مرمَّزاً فيرسمه التطبيق.
#
# 🔴 **ما كشفه المالك (2026-09-13) وأصلحته هذه الجولة:**
#    «الهكسان الحلقي والهكسين الحلقي — يقول لي بدون رابطة ثنائية وبها
#     رابطة ثنائية، **وطيب نفس الرسمة**؟»
#    وكان محقّاً، وأوسع ممّا رأى:
#      • الرابطة الثنائية لم تكن في الترميز أصلاً ⇒ كلُّ حلقةٍ غير عطرية
#        مضلّعٌ أصمّ: الهكسان والهكسين والبروبين سواء.
#      • «ثنائية» في أي موضع كانت تُقرأ **عطرية** ⇒ «بدون روابط ثنائية»
#        تُخرج بنزيناً! والنفيُ يُقرأ إثباتاً.
#      • «ثلاثي» شكلٌ ⇒ «ثلاثي نيتروتولوين» مثلّث، و«سداسي كلورو» سداسي.
#      • «بنزين» شكلٌ بلا قيد ⇒ **مضخة البنزين** في محطة الوقود حلقةٌ عطرية.
#      • النفثالين والأنثراسين (حلقتان وثلاث ملتحمة) حلقةٌ واحدة.
#      • الموقع مهمَل ⇒ أورثو وميتا وبارا **رسمةٌ واحدة**، والشكل يكذّب
#        الاسمَ المكتوب تحته في درسٍ موضوعُه المواقع.
#
# ⚖️ **والقاعدة المستفادة: الاسمُ مصدرٌ يقينيّ والوصفُ ظنّيّ.** «هكسين حلقي»
#    تحدّد البنية تحديداً تامّاً، أما «شكل سداسي» فتصف ستةَ أضلاعٍ لا غير.
#    فجدولُ الأسماء أولاً، والوصفُ احتياطٌ بعده. (نفس درس الأميدات في
#    `chem_from_name` — راجع [organic-chem-drawing] في الذاكرة.)

# رموزُ المجموعات بأسمائها العربية كما يكتبها الكتاب.
_ARABIC_GROUPS = {
    "بروم": "Br", "كلور": "Cl", "فلور": "F", "يود": "I", "أيود": "I",
    "ميثيل": "CH3", "إيثيل": "CH2CH3", "بروبيل": "CH2CH2CH3",
    "أمين": "NH2", "أمينو": "NH2", "نيترو": "NO2", "هيدروكسيل": "OH",
}

# ══════════════ جدول المركبات الحلقية في المنهج ══════════════
# 🔒 **قائمة مغلقة عمداً**: ما ليس فيها لا يُرسم من معرفةٍ عامة — تبقى
#    كلمةُ الكتاب كما هي. (وهي قاعدةُ المصدر التي لا تُخرقها قاعدةُ الشكل.)
RING_COMPOUNDS: dict[str, str] = {
    # — ألكانات حلقية —
    "بروبان حلقي": "3", "سيكلوبروبان": "3", "سيكلو بروبان": "3",
    "بيوتان حلقي": "4", "سيكلوبيوتان": "4", "سيكلو بيوتان": "4",
    "بنتان حلقي": "5", "سيكلوبنتان": "5", "سيكلو بنتان": "5",
    "سايكلو بنتان": "5", "سيكلوبنتيل": "5", "سايكلو بنتيل": "5",
    "هكسان حلقي": "6", "هيكسان حلقي": "6", "سيكلوهكسان": "6",
    "سيكلوهيكسان": "6", "سيكلو هكسان": "6", "سيكلو هيكسان": "6",
    "هبتان حلقي": "7", "سيكلوهبتان": "7",
    # — ألكينات حلقية: الرابطة الثنائية هي الفرق كلُّه —
    "بروبين حلقي": "3|=1", "سيكلوبروبين": "3|=1",
    "بيوتين حلقي": "4|=1", "سيكلوبيوتين": "4|=1",
    "بنتين حلقي": "5|=1", "سيكلوبنتين": "5|=1",
    "هكسين حلقي": "6|=1", "هيكسين حلقي": "6|=1",
    "سيكلوهكسين": "6|=1", "سيكلوهيكسين": "6|=1",
    # — أروماتية: حلقة واحدة —
    "بنزين": "6|ar", "بنزن": "6|ar",
    "تولوين": "6|ar|+CH3",
    "فينول": "6|ar|+OH",
    "أنيلين": "6|ar|+NH2", "انيلين": "6|ar|+NH2",
    "بنزالدهيد": "6|ar|+CHO",
    "حمض البنزويك": "6|ar|+COOH", "حمض بنزويك": "6|ar|+COOH",
    "أسيتوفينون": "6|ar|+COCH3",
    "ستايرين": "6|ar|+CH=CH2", "ستایرین": "6|ar|+CH=CH2",
    "نيترو بنزين": "6|ar|+NO2", "نيتروبنزين": "6|ar|+NO2",
    "كلورو بنزين": "6|ar|+Cl", "كلوروبنزين": "6|ar|+Cl",
    "برومو بنزين": "6|ar|+Br", "بروموبنزين": "6|ar|+Br",
    "فلورو بنزين": "6|ar|+F", "فلوروبنزين": "6|ar|+F",
    "إيثيل بنزين": "6|ar|+CH2CH3", "بروبيل بنزين": "6|ar|+CH2CH2CH3",
    "بنزوات الصوديوم": "6|ar|+COONa",
    # — أروماتية: حلقات ملتحمة —
    "نفثالين": "6|ar|fuse2", "النفثالين": "6|ar|fuse2",
    "أنثراسين": "6|ar|fuse3", "انثراسين": "6|ar|fuse3",
    # — حلقات غير متجانسة —
    "بيريدين": "6|ar|N", "البيريدين": "6|ar|N",
    "بيبريدين": "6|NH", "البيبريدين": "6|NH", "بيبيريدين": "6|NH",
    # — مشتقات بمجموعتين فأكثر (المواقع من الكتاب) —
    "بارا زايلين": "6|ar|+CH3@1|+CH3@4", "بارا - زايلين": "6|ar|+CH3@1|+CH3@4",
    "أورثو زايلين": "6|ar|+CH3@1|+CH3@2",
    "ميتا زايلين": "6|ar|+CH3@1|+CH3@3",
    "ثلاثي نيتروتولوين": "6|ar|+CH3@1|+NO2@2|+NO2@4|+NO2@6",
    "أسبرين": "6|ar|+COOH@1|+OCOCH3@2", "اسبرين": "6|ar|+COOH@1|+OCOCH3@2",
    "سداسي كلورو هكسان حلقي":
        "6|+Cl@1|+Cl@2|+Cl@3|+Cl@4|+Cl@5|+Cl@6",
    "سداسي كلوروهكسان حلقي":
        "6|+Cl@1|+Cl@2|+Cl@3|+Cl@4|+Cl@5|+Cl@6",
}

# ⚠️ **«بنزين» كلمةٌ مشتركة**: وقودُ السيارات في العربية اسمُه البنزين،
#    والكتاب نفسه يفرّق: «البنزين العطري يختلف تماماً عن البنزين الناتج من
#    تقطير البترول». فكانت صفحةُ **محطة الوقود** تُرسم حلقةً عطرية.
#    فلا يُقرأ اسماً لمركّبٍ إلا في جوارٍ كيميائيّ يصدّقه.
_AMBIGUOUS = {"بنزين", "بنزن"}
_AROMATIC_CONTEXT = re.compile(
    "حلق|أروم|اروم|عطري|مركب|صيغة|مشتق|C6H6|رابطة|"
    "نفثال|أنثراسين|انثراسين|تولوين|فينول|أنيلين|بيريدين")

# الأطول أولاً: «نيترو بنزين» قبل «بنزين»، و«هكسين حلقي» قبل «هكسان حلقي».
_COMPOUND_RE = re.compile(
    "(?<![ا-ي])(?:" +
    "|".join(re.escape(k) for k in sorted(RING_COMPOUNDS, key=len, reverse=True)) +
    r")(?![ا-ي])")

# ══════════════ الوصف: شكلٌ موصوفٌ بالكلمات ══════════════
# 🔤 **جذورٌ لا كلمات**، واللاحقة العربية تُبتلع معها: «حلقتان سداسيتان»
#    كانت تُطابق «سداسي» وتترك «تان» معلّقةً في النصّ —
#    «\ring{6|ar|fuse2}تان متصلتان» على شاشة الطالب. (نفس فخّ «ة» القديم
#    في النيكوتيناميد، بصيغةٍ جديدة.)
_SHAPES = {
    "مثلث": 3, "ثلاثي": 3,
    "مربع": 4, "رباعي": 4,
    "خماسي": 5, "مخمس": 5,
    "سداسي": 6, "مسدس": 6,
    "سباعي": 7, "ثماني": 8,
}
_SUFFIX = r"(?:تان|تين|ات|ة|ان|ين)?"

# 🔒 **الشكلُ لا يُقرأ عارياً** — وهذا ما كان يُنتج الأخطاء الفاضحة:
#    «علامة التسخين (مثلث Δ)» حلقةٌ ثلاثية، و«سداسي كلورو» حلقةٌ سداسية،
#    و«ثلاثي نيتروتولوين» مثلّث. فالكلمة تُقبل شكلاً في موضعين اثنين فقط:
#      ① مسبوقةً بما يجعلها شكلاً: «حلقة سداسية» · «شكل مثلث» · «رسمة مربع»
#      ② متبوعةً بفعل التمثيل: «مثلث يمثل سيكلوبروبان»
# ⚠️ **التبديلُ يُغلَّف قبل أن تُلحق به اللاحقة**: `(أ|ب|ج suffix)` تُلصق
#    اللاحقة بالبديل الأخير وحده — فتبقى «ة» معلّقةً بعد «سداسي» كما كانت.
_SHAPE_WORDS = "(?:" + "|".join(sorted(_SHAPES, key=len, reverse=True)) + ")"
_SHAPE_PHRASE = re.compile(
    rf"(?:(?:حلق(?:ة|تان|تين|ات|تا)|شكل|أشكال|رسمة|رسم|مضلع)\s*"
    rf"(?:هندسي(?:ة)?\s*)?(?:ال)?({_SHAPE_WORDS}{_SUFFIX})"
    rf"|({_SHAPE_WORDS}{_SUFFIX})\s*(?:ال)?(?:يمثل|تمثل|يمثّل|تمثّل|يُمثل|تُمثل))"
    r"(?!\s*الأبعاد)")

# 🔒 **وبوّابةٌ ثانية على السطر كلّه: أثرٌ عضويّ.** وإلا صار كلُّ مربّعٍ
#    ومسدّسٍ في الكتاب حلقةً: **خليةُ الكالسيوم** في الجدول الدوري («مربع
#    يمثل عنصر الكالسيوم») و**طبقاتُ الجرافيت** السداسية كانتا تُرسمان
#    حلقتين عضويتين. والشكلُ الهندسيّ في كتاب الكيمياء أعمُّ من الحلقة.
_ORGANIC_HINT = re.compile(
    "حلق|سيكلو|سايكلو|أروم|اروم|عطري|بنزين|ألكان|الكان|ألكين|الكين|فينول|"
    "أنيلين|تولوين|بيريدين|نفثال|أنثراسين")

# 🔒 بوّابة السياق: اسم الشكل وحده لا يكفي.
_RING_CONTEXT = re.compile("رسم|شكل|حلق")

# 🔴 **اسمُ الرسم يُبتلع مع الشكل — وهذا ما حسم الامتثال.**
#    كان السطر يصير «رسمة \ring{3} : تمثل بروبان حلقي»، فيقرأ الموديل كلمة
#    «رسمة» على أنها وصفٌ مطلوبٌ منه فيترجم الترميز إلى «يتم تمثيله برسم
#    مثلث» — ٠ من ٣ محاولات متتالية، بلا عشوائية. حين لم يبقَ في السطر إلا
#    الترميز صار النقلُ الحرفيّ نقلاً للرسم. (والنصُّ الشارح بعد «:» يبقى
#    كما في الكتاب — نحذف اسمَ الرسم لا محتواه.)
_DRAW_WORD = re.compile(
    r"(?:ال)?(?:رسمة|رسوم|رسم|أشكال|شكل|حلقات|حلقة)\s*(?:هندسية?\s*)?"
    r"(?:ل)?\s*(?:ال)?\s*$")

# عدد الحلقات الملتحمة — «حلقتان متلاصقتان» · «ثلاث حلقات ملتحمة».
_FUSED2 = re.compile(r"حلقت(?:ان|ين|ي)\s*(?:بنزين\s*)?(?:متلاصقت|ملتحمت|متصلت|سداسيت)")
_FUSED3 = re.compile(r"ثلاث\s*(?:أشكال\s*)?حلقات\s*(?:سداسية\s*)?(?:متلاصقة|ملتحمة|متصلة)")

# نفيُ الرابطة الثنائية — «بدون روابط ثنائية» · «لا تحتوي روابط ثنائية».
_NO_DOUBLE = re.compile(r"(?:بدون|بلا|دون|لا\s+تحتوي\s+(?:على\s+)?|غير\s+محتوية)\s*(?:على\s*)?روابط\s*ثنائية")
# ثلاث روابط متبادلة ⇒ عطرية (بنزين) لا رابطةً واحدة.
_ALTERNATING = re.compile(r"(?:ثلاث|3)\s*روابط\s*ثنائية|روابط\s*ثنائية\s*متبادلة|متبادلة\s*مع\s*الروابط")
_ONE_DOUBLE = re.compile(r"رابطة\s*(?:ثنائية|مزدوجة)\s*(?:واحدة)?|(?:ثنائية|مزدوجة)\s*واحدة")
# ⚗️ **صيغةُ كيكولي**: الكتاب يرسم (أ) و(ب) بروابطَ متبادلة **مرسومة**،
#    و(جـ) بالدائرة. فالثلاثةُ في صفحةٍ واحدة، ورسمُها كلِّها بالدائرة
#    يمحو الدرسَ نفسه (تاريخُ اكتشاف بنية البنزين).
_KEKULE = re.compile(r"تبادل\s*(?:مواقع\s*)?الروابط|الأحادية\s*فيها\s*متبادلة")

_GROUP_TOKEN = r"[A-Z][A-Za-z0-9]*(?:[=-][A-Z][A-Za-z0-9]*)*"


def _positions(text: str) -> list[int]:
    return [int(d) for d in re.findall(r"[1-8]", text)]


_ARABIC_ALT = "|".join(sorted(_ARABIC_GROUPS, key=len, reverse=True))


def _symbol(token: str) -> str | None:
    """رمزُ المجموعة: لاتينيةً كما هي، وعربيةً من الجدول."""
    token = token.strip()
    if token in _ARABIC_GROUPS:
        return _ARABIC_GROUPS[token]
    if re.fullmatch(_GROUP_TOKEN, token) and token not in {"N", "H", "C", "O", "R", "Ar"}:
        return token
    return None


# ① مجموعةٌ ثم موقعها: «Br في الموقع 1» · «Cl على المواقع 1، 2، 4» ·
#    «مجموعتا Br متصلتان بالموقعين 1 و 4» · «ذرتي بروم في الموقعين 1 و 3».
_SUB_AT = re.compile(
    rf"({_GROUP_TOKEN}|{_ARABIC_ALT})"
    r"[^A-Za-z0-9\n]{0,30}?"
    r"(?:المواقع|الموقعين|الموقع|موقع)\s*"
    r"((?:[1-8]\s*(?:،|,|و|\x00|\x01)?\s*)+)")

# ② أو «على 1 و Cl على 2» — الرقم بلا كلمة «موقع».
_SUB_ON = re.compile(
    rf"({_GROUP_TOKEN}|{_ARABIC_ALT})\s*(?:في|على)\s*((?:[1-8]\s*(?:،|,|و|\x00|\x01)?\s*)+)")

# ③ مجموعةٌ بلا موقع: «متصلة بمجموعة OH» · «مرتبطة بـ NH2» · «تفرع Cl».
_SUB_PLAIN = re.compile(
    r"(?:مجموع(?:ة|تا|تي|ات)|متصل\S*|مرتبط\S*|تفرع|بديلة)"
    rf"(?:\s+[؀-ۿ]+){{0,2}}\s*(?:بـ)?\s*({_GROUP_TOKEN}|{_ARABIC_ALT})")


def _substituents(part: str) -> list[str]:
    """المجموعات المعلّقة على الحلقة — بمواقعها إن ذكرها الكتاب.

    📍 والموقعُ ليس تفصيلاً: درسُ «أورثو · ميتا · بارا» كلُّه مواقع، ورسمُ
       المجموعتين على رأسين متجاورين بدل متقابلين يجعل الشكلَ يكذّب الاسمَ
       المكتوب تحته.
    """
    found: list[str] = []
    seen: set[str] = set()

    for pattern in (_SUB_AT, _SUB_ON):
        for m in pattern.finditer(part):
            symbol = _symbol(m.group(1))
            if not symbol:
                continue
            for pos in _positions(m.group(2)):
                key = f"{symbol}@{pos}"
                if key in seen:
                    continue
                seen.add(key)
                found.append("+" + key)
        if found:
            return found

    for m in _SUB_PLAIN.finditer(part):
        symbol = _symbol(m.group(1))
        if symbol and symbol not in seen:
            seen.add(symbol)
            found.append("+" + symbol)
    return found


def _hetero(part: str) -> str | None:
    if "نيتروجين" in part or re.search(r"\bN\b", part):
        return "NH" if "مرتبطة بهيدروجين" in part else "N"
    if "أكسجين" in part or "اكسجين" in part:
        return "O"
    if "كبريت" in part:
        return "S"
    return None


def _bonds(part: str) -> str | None:
    """حالةُ الروابط داخل الحلقة: عطرية · رابطةٌ ثنائية · لا شيء.

    🔴 **والنفيُ كان يُقرأ إثباتاً**: «حلقة سداسية **بدون** روابط ثنائية»
       فيها كلمة «ثنائية» — وكان مجرّدُ وجودها يجعلها عطرية، فيخرج
       الهكسانُ الحلقي **بنزيناً**. وهما في الكتاب رسمان متجاوران للتفريق.
    """
    if _NO_DOUBLE.search(part):
        return None
    if _KEKULE.search(part):
        return "kekule"
    if _ALTERNATING.search(part) or "غير مشبع" in part or "عطري" in part \
            or "أروماتي" in part or "بداخلها دائرة" in part or "بداخله دائرة" in part:
        return "ar"
    if _ONE_DOUBLE.search(part):
        return "=1"
    return None


def _fused(part: str) -> int:
    if _FUSED3.search(part):
        return 3
    if _FUSED2.search(part):
        return 2
    return 1


# 📍 **أورثو · ميتا · بارا — هي الدرسُ نفسه لا زينةً فيه.**
#    «بارا - ثنائي برومو بنزين» و«أورثو - ثنائي برومو بنزين» اسمان مختلفان
#    لمجموعتين في موضعين مختلفين — ورسمُهما واحداً يجعل الشكلَ يكذّب الاسمَ
#    المكتوب تحته في درسٍ **موضوعُه المواقع**.
_ORTHO_META_PARA = {
    "أورثو": (1, 2), "اورثو": (1, 2), "ortho": (1, 2),
    "ميتا": (1, 3), "meta": (1, 3),
    "بارا": (1, 4), "para": (1, 4),
}
_NUMBERED_PREFIX = re.compile(
    r"((?:[1-6]\s*[،,\x00\x01]\s*)+[1-6])\s*-?\s*(?:ثنائي|ثلاثي|رباعي)")

# 🔒 **ولا توزيعَ بلا كلمةِ تعدّد.** «ميتا ميثيل أنيلين» فيها «ميتا» — لكنها
#    مجموعتان **مختلفتان** (NH2 و CH3) لا مجموعةٌ مكرّرة، فتوزيعُ الأمين
#    على الموقعين أخرج مركّباً لا وجود له. «ثنائي/ثلاثي» وحدها تعني التكرار.
_MULTIPLIER_WORD = re.compile(r"ثنائي|ثلاثي|رباعي")


def _multiplied(code: str, part: str) -> str:
    """يوزّع المجموعةَ الواحدة على مواقعها حين يسمّيها الكتاب مضاعَفة.

    «1 ، 4 - ثنائي برومو بنزين» يطابق اسمَ «برومو بنزين» (بروم **واحد**)،
    والكتاب يقول أين البرومان — فالنصّ أدقّ من الجدول هنا.
    """
    singles = [p for p in code.split("|") if p.startswith("+") and "@" not in p]
    if len(singles) != 1 or not _MULTIPLIER_WORD.search(part):
        return code

    positions: tuple[int, ...] | list[int] = ()
    numbered = _NUMBERED_PREFIX.search(part)
    if numbered:
        positions = _positions(numbered.group(1))
    else:
        for word, pair in _ORTHO_META_PARA.items():
            if word in part:
                positions = pair
                break
    if len(positions) < 2:
        return code

    group = singles[0]
    base = [p for p in code.split("|") if not p.startswith("+")]
    return "|".join(base + [f"{group}@{p}" for p in positions])


# 🏷️ **الاسمُ النظاميّ يحمل مواقعَه بنفسه**: «2 - كلورو - 5 - نيترو أنيلين»
#    تقول أين كلُّ مجموعة. وهذه أسماءُ الدرس نفسِه (قواعد تسمية مشتقات
#    البنزين)، فقراءتُها تعني أن يرى الطالبُ **الاسمَ ورسمَه المطابق**.
_IUPAC_POS = re.compile(rf"([1-6])\s*-\s*({_ARABIC_ALT})")


def _from_iupac(code: str, part: str) -> str:
    """يضيف مواقعَ الاسم النظاميّ إلى ترميز المركّب الأصل."""
    hits = _IUPAC_POS.findall(part)
    if not hits:
        return code
    base = [p for p in code.split("|") if not p.startswith("+")]
    named = [(f"+{_ARABIC_GROUPS[w]}@{p}", _ARABIC_GROUPS[w], p) for p, w in hits]
    taken_symbols = {sym for _, sym, _ in named}
    taken_positions = {pos for _, _, pos in named}

    subs = []
    # مجموعةُ المركّب الأصل تجلس في الموقع 1 (أنيلين · تولوين · فينول) —
    # ⚠️ **إلا أن يكون الاسمُ النظاميّ قد ذكرها بنفسه**: «1-برومو-2-كلوروبنزين»
    #    يطابق «كلوروبنزين» فيأتي بكلورٍ ضمنيّ، والاسمُ يقول أين الكلور
    #    فعلاً — فالضمنيُّ يُسقط وإلا خرج المركّب بكلورين.
    for p in code.split("|"):
        if not p.startswith("+"):
            continue
        if "@" in p:
            subs.append(p)
        elif p[1:] not in taken_symbols and "1" not in taken_positions:
            subs.append(p + "@1")
    subs.extend(entry for entry, _, _ in named if entry not in subs)
    return "|".join(base + subs)


# ⚠️ «و» بعد اسم المجموعة من صيغتها العربية («برومو» · «كلورو») لا فاصلاً.
_OMP_PAIR = re.compile(
    rf"({_ARABIC_ALT})و?\s*[-–]?\s*({_ARABIC_ALT})و?\s*(?:بنزين|بنزن)")


def _omp_pair(code: str, part: str) -> str:
    """«أورثو - برومو كلورو بنزين» ⇒ بروم في 1 وكلور في 2.

    مجموعتان **مختلفتان** فلا يصلح لهما التوزيع (`_multiplied`)، والبادئة
    وحدها تقول موضعَهما — وهي درسُ الصفحة.
    """
    positions = next((p for w, p in _ORTHO_META_PARA.items() if w in part), None)
    if not positions:
        return code
    pair = _OMP_PAIR.search(part)
    if not pair:
        return code
    first, second = _ARABIC_GROUPS[pair.group(1)], _ARABIC_GROUPS[pair.group(2)]
    if first == second:
        return code                      # مكرّرة ⇒ شأنُ `_multiplied`
    base = [p for p in code.split("|") if not p.startswith("+")]
    return "|".join(base + [f"+{first}@{positions[0]}", f"+{second}@{positions[1]}"])


def _from_name(part: str, context: str):
    """يطابق اسمَ مركّبٍ معروف. يعيد `(الترميز، نهايةُ الاسم)` أو None."""
    match = _COMPOUND_RE.search(part)
    if not match:
        return None
    name = match.group(0)
    if name in _AMBIGUOUS and not _AROMATIC_CONTEXT.search(context):
        return None            # «مضخة البنزين» وقودٌ لا مركّب
    code = RING_COMPOUNDS[name]
    extra = _substituents(part)
    if "+" not in code:
        # مجموعاتٌ يذكرها الكتاب بجوار الاسم («حلقة بنزين متصلة بمجموعة OH»).
        if extra:
            code += "|" + "|".join(extra)
    elif any("@" in e for e in extra):
        # 📍 **والمواقعُ المذكورة تسبق ما في الجدول.**
        base = "|".join(p for p in code.split("|") if not p.startswith("+"))
        code = base + "|" + "|".join(extra)
    named_positions = _from_iupac(code, part)
    if named_positions != code:
        code = named_positions
    else:
        paired = _omp_pair(code, part)
        code = paired if paired != code else _multiplied(code, part)
    fused = _fused(part)
    if fused > 1 and "fuse" not in code:
        code += f"|fuse{fused}"
    return "\\ring{" + code + "}", match.end()


def _from_shape(part: str, context: str = ""):
    """يطابق وصفَ الشكل. يعيد `(الترميز، بدايةُ الشكل، نهايتُه)` أو None."""
    match = _SHAPE_PHRASE.search(part)
    if not match:
        return None

    # 🔒 صيغةُ «<شكل> يمثل …» وحدها تحتاج أثراً عضوياً على السطر: هي التي
    #    التقطت **خليةَ الكالسيوم** في الجدول الدوري («مربع يمثل عنصر
    #    الكالسيوم») و**طبقاتِ الجرافيت** السداسية فرسمتهما حلقتين عضويتين.
    #    أما «حلقة سداسية» و«شكل سداسي» فالكلمة قبلهما تكفي.
    if match.group(2) and not _ORGANIC_HINT.search(context or part):
        return None

    word = match.group(1) or match.group(2)
    size = _SHAPES[re.match(_SHAPE_WORDS, word).group(0)]
    parts = [str(size)]

    bonds = _bonds(part)
    if bonds == "kekule":
        # الروابطُ المتبادلة تُرسم في السداسي وحده؛ وفي غيره تكفي العطرية.
        bonds = "=1,3,5" if size == 6 else "ar"
    if bonds:
        parts.append(bonds)

    hetero = _hetero(part)
    if hetero:
        parts.append(hetero)

    parts.extend(_substituents(part))

    fused = _fused(part)
    if fused > 1:
        parts.append(f"fuse{fused}")

    span = match.span(1) if match.group(1) else match.span(2)
    return "\\ring{" + "|".join(parts) + "}", span[0], span[1]


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
    out, seen = [], set()
    for part in re.split(r"[،,.]\s*", description):
        code = _code_for(part, description)
        if code and code not in seen:
            seen.add(code)
            out.append(code)
    if not out:
        code = _code_for(description, description)
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
    return _code_for(description, description)


def _code_for(part: str, context: str) -> str | None:
    """الترميز من جزءٍ واحد — **بالاسم أولاً** ثم بالوصف."""
    if not part:
        return None
    named = _from_name(part, context)
    if named:
        return named[0]
    shaped = _from_shape(part, context)
    return shaped[0] if shaped else None


# فاصلةٌ بين رقمين ليست فاصلةَ جملة: «1 ، 4 - ثنائي برومو بنزين» رقمُ
# موقعٍ لا بندُ قائمة، وقطعُها عندها يُضيّع المواقع التي يُبنى عليها الرسم.
_NUM_COMMA = re.compile(r"(?<=[0-9])(\s*[،,]\s*)(?=[0-9])")
# ⚠️ حرفان لا حرف: الفاصلة تعود **كما كتبها الكتاب** — عربيةً أو لاتينية.
#    (شرطُ المالك في المعادلات: «المحتوى ضروري يكون نفسه».)
_KEEP_AR, _KEEP_EN = "\x00", "\x01"


def _units(sentence: str) -> int:
    """كم رسمةً في هذه الجملة؟ — الأسماءُ أو الأشكال أو الالتحامات.

    ⚠️ والالتحامُ يُعدّ: «حلقة بنزين مفردة، حلقتان ملتحمتان، ثلاث حلقات
       ملتحمة» ثلاثُ رسمات — ولولا عدُّها لصار **البنزينُ المفرد** أنثراسيناً
       (يلتقط «ثلاث حلقات ملتحمة» من آخر الجملة).
    """
    names = len(_COMPOUND_RE.findall(sentence))
    shapes = len(_SHAPE_PHRASE.findall(sentence))
    fused = len(_FUSED2.findall(sentence)) + len(_FUSED3.findall(sentence))
    return max(names, shapes, fused if names <= 1 else 0)


def _encode_part(part: str, line: str) -> str:
    """يُدخل الترميزَ في جزءٍ واحد — استبدالاً للشكل، وإلحاقاً بالاسم."""
    if not part.strip():
        return part

    named = _from_name(part, line)
    shaped = _from_shape(part, line)

    # 🏷️ **الاسمُ يحكم والوصفُ يُستبدل.** فإن اجتمعا في جزءٍ واحد
    #    («رسمة المثلث : تمثل بروبان حلقي») أخذنا ترميزَ الاسم — لأنه
    #    أدقّ — ووضعناه **مكان الوصف** كي لا يبقى تمثيلٌ نثريّ ينافس
    #    الترميز (وهو الدرس الذي حسم الامتثال).
    if not shaped:
        if named:
            code, end = named
            return part[:end] + " " + code + part[end:]
        return part

    code, start, end = shaped
    if named:
        code = named[0]
    # يبتلع «ال» التعريف ثم اسمَ الرسم قبلها، طبقةً طبقة — كي لا يبقى
    # «رسمة ال\ring{3}» ولا «شكل \ring{6}».
    for _ in range(4):
        if part[:start].endswith("ال"):
            start -= 2
            continue
        w = _DRAW_WORD.search(part[:start])
        if not w or w.start() >= start:
            break
        start = w.start()
    return part[:start] + code + part[end:]


def _encode_sentence(sentence: str, line: str, base: str | None) -> str:
    """جملةٌ واحدة: رسمةٌ واحدة تُقرأ كاملةً، وعدّةُ رسومٍ تُقسَّم بالفواصل.

    🔴 **ولماذا لا تُقسَّم دائماً؟** لأن مجموعات المركّب الواحد تُكتب
       مفصولةً بفواصل: «به NH2 في 1، و Cl في 2، و NO2 في 5». فتقسيمُها
       يجعل كلَّ مجموعةٍ رسمةً مستقلّة — أو يُسقطها كلَّها. والقسمة
       إنّما احتيجت لجملةٍ فيها **رسومٌ متعدّدة**: «مثلث يمثل سيكلوبروبان،
       مربع يمثل سيكلوبيوتان».
    """
    units = _units(sentence)
    if units >= 2:
        pieces = re.split(r"([،,]\s*)", sentence)
        for i in range(0, len(pieces), 2):
            pieces[i] = _encode_part(pieces[i], line)
        return "".join(pieces)

    if units == 1:
        return _encode_part(sentence, line)

    # 📍 جملةٌ بلا اسمٍ ولا شكل، لكنها تصف مواقعَ مجموعاتٍ على **حلقة
    #    الرسم نفسه**: «الأيمن به NH2 في 1، و Cl في 2، و NO2 في 5».
    #    الحلقةُ معلومةٌ من أول الرسم، والمواقع هنا — فيُجمعان.
    if base:
        subs = [x for x in _substituents(sentence) if "@" in x]
        if len(subs) >= 2:
            return sentence.rstrip() + " \\ring{" + base + "|" + "|".join(subs) + "}"
    return sentence


def to_ring(text: str) -> str:
    """يُدخل ترميزَ الحلقة في نصّ الكتاب — استبدالاً للشكل، وإلحاقاً بالاسم.

    🔴 **لماذا استبدالٌ لا إضافة (للشكل)؟** المحاولة الأولى أضافت سطراً
       موازياً («الرسم بالترميز الإلزامي: \ring{3}») بجوار الوصف النثري،
       فبقي أمام الموديل تمثيلان للشيء نفسه — فاختار النثر وأعاد صياغته:
       «يتم تمثيله برسم مثلث». وهذا بالضبط ما تعلّمناه في الكسور: `to_frac`
       **تستبدل** الشرطة ولا تضيف تلميحاً بجوارها.

    ⭐ **ولماذا إلحاقٌ للاسم؟** الاسم ليس تمثيلاً منافساً للرسم بل **عنوانُه**:
       «هكسين حلقي» لا تصف شكلاً كي يُحكى، والطالب يحتاجهما معاً — الاسم
       والرسم تحته. وهو الشكل الذي يطلبه البرومبت أصلاً:
       «سيكلوبروبان \ring{3}».
    """
    if not text or "\\ring" in text:
        return text

    # حلقةُ هذا الرسم — من أول اسمٍ في **النصّ كلّه**، وتخدم جُملَ المواقع.
    base = None
    first = _COMPOUND_RE.search(text)
    if first and not (first.group(0) in _AMBIGUOUS
                      and not _AROMATIC_CONTEXT.search(text)):
        base = "|".join(p for p in RING_COMPOUNDS[first.group(0)].split("|")
                        if not p.startswith("+"))

    out_lines = []
    for line in text.split("\n"):
        # 🔑 والسطرُ الذي لا كلمةَ رسمٍ فيه يُقرأ أيضاً **إن كانت حلقةُ الرسم
        #    معلومة ومواقعُ مجموعاتها فيه**: الكتاب يكتب الرسم على ثلاثة
        #    أسطر — «شكلان لحلقتي بنزين» ثم «الوصف: الأيمن به NH2 في 1، و
        #    Cl في 2» — فالاسمُ في سطر والمواقعُ في سطرٍ بلا كلمة «رسم».
        if not _RING_CONTEXT.search(line) and not (
                base and (_SUB_AT.search(line) or _SUB_ON.search(line))):
            out_lines.append(line)
            continue

        guarded = _NUM_COMMA.sub(
            lambda m: m.group(1).replace("،", _KEEP_AR).replace(",", _KEEP_EN), line)

        pieces = re.split(r"(\.\s*)", guarded)
        for i in range(0, len(pieces), 2):
            pieces[i] = _encode_sentence(pieces[i], guarded, base)
        out_lines.append(
            "".join(pieces).replace(_KEEP_AR, "،").replace(_KEEP_EN, ","))
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

# ══════════════════════════════════════════════════
# 🩹 `\chem{}` للبنية الواحدة — لا للمعادلة كاملة
# ══════════════════════════════════════════════════
# 🔴 **ما رآه المالك (2026-09-09):** شريطٌ أحمر «RIGHT OVERFLOWED BY 140
#    PIXELS» فوق معادلةٍ في درس الإيثرات، ومعه قوسٌ شاردٌ «}» في آخر السطر.
#
# ⚖️ **والسبب أن الموديل غلّف المعادلة كلَّها**:
#       \chem{CH3CH2-O-CH2CH3 + 2HBr --[H2SO4] / 120 م--> 2CH3CH2Br + H2O}
#    و`\chem` تعني «ارسم سلسلةً واحدة»، فيبني الرسّام صفّاً واحداً لا ينكسر
#    عرضُه أضعافُ الشاشة. وهو خطأُ استعمالٍ لا خطأُ رسم.
#
# ⭐ والعلاج **نزعُ الغلاف وإبقاء المحتوى حرفاً بحرف** — فتصير معادلةً
#    يرسمها `ChemEquation` بأسهمها وشروطها، ولا يتغيّر حرفٌ من المحتوى.
_EQUATION_INSIDE = re.compile(r"--+>|<--+|<=+>|⇌|\+")


def unwrap_equation_chem(text: str) -> str:
    r"""يفكّ `\chem{}` إذا كان يغلّف **معادلة** لا بنيةً واحدة."""
    if not text or "\\chem{" not in text:
        return text

    out, i = [], 0
    while True:
        j = text.find("\\chem{", i)
        if j < 0:
            out.append(text[i:])
            break
        out.append(text[i:j])
        k, depth = j + 6, 1
        while k < len(text) and depth:
            if text[k] == "{":
                depth += 1
            elif text[k] == "}":
                depth -= 1
            k += 1
        body = text[j + 6:k - 1] if depth == 0 else text[j + 6:]
        # سهمٌ أو «+» بين متفاعلات ⇒ معادلة، فيُنزع الغلاف.
        out.append(body if _EQUATION_INSIDE.search(body) else text[j:k])
        i = k
        if depth:
            break
    return "".join(out)

