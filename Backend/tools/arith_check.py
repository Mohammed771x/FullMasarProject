# ==================================================
# 🧮 tools/arith_check.py — الحسابُ يُصحَّح أو يُخطَّأ، ولا يُستحسن
# ==================================================
# 🔴🔴 **ما رآه المالك (2026-09-17):** «ما هي نتيجة ⌋(٣+٣)؟» وجوابُها
#      الموسوم «٩»، وتعليلُها يقول بنفسه «= ⌋٦ = ٧٢٠» — سؤالٌ يناقض
#      نفسَه، **مخزونٌ يراه كلُّ طالب**.
#
# 📏 **وليست شاذّة**: بنكُ المنطق (`gpt-4o-mini`) فيه ١٠٤ أسئلةٍ خياراتُها
#    أعدادٌ صِرف، وفحصُ خمسةِ دروسٍ بيدي أعطى **≈٤٤ خطأً حسابياً** — نحوَ
#    النصف. وبنكُ الرياضيات (DeepSeek): **٢١١ ادّعاءً بصفر خطأ**.
#
# ⭐ **والعلاجُ الدائم ليس تبديلَ الموديل وحدَه**: ما لا يُقاس لا يُمتثَل.
#    فالحسابُ **يُحسب هنا**، ويُردّ البنكُ الذي يخالفه، ويعود العيبُ باسمه
#    في `retry_prompt` — نظيرَ حصّة الترميز وحصّة الإنجليزية.
#
# ⚠️ **والمبدأ: ما لا يُفهم يقيناً يُسكت عنه.** أوّلُ صيغةٍ قرأت
#    «٧ × ٦ × ٥ × ٤ × ٣ × ٢ × ١» عدداً (٧٦٥٤٣٢١)، والثانيةُ قارنت طرفين
#    يفصل بينهما كلامٌ («٢ + ٣ = ٥ **والمقام** = ٣») فوسمت ١٧ سؤالاً
#    سليماً في الرياضيات. **المقياسُ الخاطئ أسوأُ من لا مقياس.**

import json, os, re, math, warnings, collections
from fractions import Fraction
import json, os, re, math, warnings, collections
from fractions import Fraction

AR = "٠١٢٣٤٥٦٧٨٩"
TO_LAT = str.maketrans(AR, "0123456789")

def lat(s): return (s or "").translate(TO_LAT)

def perm(n, r): return math.perm(n, r) if 0 <= r <= n else None
def comb(n, r): return math.comb(n, r) if 0 <= r <= n else None

_TOK = re.compile(r"\\(fact|perm|comb|frac|sqrt)\{")

def _group(s, i):
    """يقرأ {...} متوازناً من الموضع i (حيث s[i]=='{')."""
    depth, j = 0, i
    while j < len(s):
        if s[j] == "{": depth += 1
        elif s[j] == "}":
            depth -= 1
            if depth == 0: return s[i+1:j], j+1
        j += 1
    return None, len(s)

def to_py(expr):
    """يحوّل ترميزَ الرسّام إلى تعبيرِ بايثون — أو None إن لم يُفهم."""
    s = lat(expr)
    out, i = [], 0
    while i < len(s):
        m = _TOK.match(s, i)
        if not m:
            out.append(s[i]); i += 1; continue
        name = m.group(1); j = m.end() - 1
        a, j = _group(s, j)
        if a is None: return None
        if name in ("frac", "perm", "comb"):
            if j >= len(s) or s[j] != "{": return None
            b, j = _group(s, j)
            if b is None: return None
            pa, pb = to_py(a), to_py(b)
            if pa is None or pb is None: return None
            out.append({"frac": "((%s)/(%s))", "perm": "P(%s,%s)",
                        "comb": "C(%s,%s)"}[name] % (pa, pb))
        else:
            pa = to_py(a)
            if pa is None: return None
            out.append(("F(%s)" if name == "fact" else "R(%s)") % pa)
        i = j
    return "".join(out)

_CLEAN = re.compile(r"[^0-9+\-*/().,PCFR\s]")

def value(expr):
    """قيمةُ التعبير عدداً — أو None."""
    py = to_py(expr)
    if py is None: return None
    py = py.replace("×", "*").replace("÷", "/").replace("−", "-").replace("٫", ".")
    py = py.replace(",", ",")
    if _CLEAN.search(py.replace("×","").replace("÷","")): return None
    if not re.search(r"\d", py): return None
    env = {"P": perm, "C": comb,
           "F": lambda n: math.factorial(int(n)) if 0 <= n <= 170 and float(n).is_integer() else None,
           "R": lambda n: Fraction(n).limit_denominator() ** Fraction(1, 2) if n >= 0 else None,
           "__builtins__": {}}
    # 🔇 «٢(٣جـ+٢)» ضربٌ ضمنيّ في الكتاب وخطأُ نحوٍ في بايثون — يسقط
    #    التقييمُ بلا ضرر، لكنه يطبع تحذيراً في كل اختبار. فيُكتم.
    try:
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", SyntaxWarning)
            v = eval(py, env)                   # noqa: S307 — تعبيرٌ مُنقّى
    except Exception:
        return None
    if v is None or isinstance(v, bool): return None
    try: return Fraction(v).limit_denominator(10**6)
    except Exception: return None

_NUM = re.compile(r"-?\d+(?:[.,]\d+)?")

def as_number(text):
    """الخيارُ عددٌ صِرف؟ (يقبل «٧٢٠» و«٧٢٠ طريقة» و«١٠٬٠٠٠»)."""
    t = lat(text).replace("٬", "").replace(" ", "")
    t = re.sub(r"[^\d.,\-/]", "", t)
    if not t: return None
    if "/" in t:
        try:
            a, b = t.split("/")
            return Fraction(int(a), int(b))
        except Exception: return None
    t = t.replace(",", ".")
    try: return Fraction(t)
    except Exception: return None


# ══════════════════════════════════════════════════
# 🧪 الفحص — تعبيرٌ صريحٌ في السؤال، وسلسلةٌ متّصلةٌ في التعليل
# ══════════════════════════════════════════════════
ARABIC = re.compile(r"[\u0621-\u064a]")
ASK = re.compile(r"^\s*(?:ما\s+(?:هي\s+|هو\s+)?(?:نتيجة|قيمة|حاصل|ناتج)"
                 r"|احسب|أوجد\s+(?:قيمة|ناتج)|كم\s+يساوي)\s*")


def is_pure_expr(s: str) -> bool:
    """تعبيرٌ حسابيٌّ خالص — لا كلمةَ عربيةً فيه خارج أسماء الترميز."""
    if not s or not s.strip():
        return False
    bare = re.sub(r"\\(?:fact|perm|comb|frac|sqrt|sup|sub)", " ", s)
    return not ARABIC.search(bare) and bool(re.search(r"\d", s))


def _same(a, b) -> bool:
    """مساواةٌ **تحتمل التقريب** — وهو شرطُ إنصافٍ لا تساهُل.

    🔴 **التقريبُ لغةُ الشرح لا خطأٌ فيه:** الشرحُ يكتب «\\frac{٨}{٦} =
       ١.٣٣٣» و«\\frac{٠.٦}{٠.٩} = ٠.٦٧»، وهما صوابٌ يُقرّبه المعلّم.
       وبمقارنةٍ صارمةٍ (١e-٩) رُدَّ بنكانِ سليمانِ في أوّل تشغيل.
    ⭐ فالحدُّ: الأعدادُ **الصحيحة** تُقارَن تماماً (١٨٩ ≠ ٦٣ خطأٌ قطعاً)،
       وما فيه كسرٌ عشريٌّ يُقارَن بنسبةِ ٢ في الألف — تكفي «١.٣٣٣» عن
       أربعةِ أثلاث، ولا تكفي «٤٧.٢٥» عن «٧٢.٧٥».
    """
    if a == b:
        return True
    try:
        fa, fb = float(a), float(b)
    except Exception:
        return False
    if float(a).is_integer() and float(b).is_integer():
        return abs(fa - fb) <= 1e-9          # صحيحان ⇒ لا عذرَ في التقريب
    # 📐 والكسرُ العشريّ يُكتب بمنزلتين عادةً («٠.٦٧» عن ثلثين)، فالسماحُ
    #    نصفُ المنزلة الأخيرة (٠.٠٠٥) مع نسبةٍ للأعداد الكبيرة.
    return abs(fa - fb) <= 0.005 + 2e-3 * max(1.0, abs(fa), abs(fb))


# ➕ **ودعوى الحساب تحتاج عمليةً** — «عدد = عدد» عاريةً ليست ادّعاءً.
#    🔴 «الزوجيُّ من رقم واحد: ٢**،** ٤ = ٢» — الفاصلةُ تعدادٌ لا معادلة،
#       فقرأها الفحصُ «٤ = ٢» ورفض بنكاً سليماً. فيُشترط في أحد الطرفين
#       **عمليةٌ صريحة**: + − × ÷ أو ترميزُ رسّام.
_HAS_OP = re.compile(r"[+\-−×÷/]|\\(?:fact|perm|comb|frac|sqrt)")


def bare_question_expr(q: str):
    """«ما نتيجة ⌋٣؟» ⇒ التعبير؛ وما سواه None (لئلا يُلتقط معطى)."""
    t = (q or "").strip().rstrip("؟?").strip()
    m = ASK.match(t)
    if not m:
        return None
    rest = t[m.end():].strip()
    return rest if is_pure_expr(rest) else None


def _chain(text: str):
    """عيوبُ سلاسل «أ = ب = جـ» — **داخل الشوط المتّصل وحدَه**.

    🔴 العربيةُ بين الطرفين **تقطع السلسلة**: «و» و«ومن» و«إذن» و«⇒»
       تبدأ معادلةً جديدة، ولا معنى لمساواة طرفٍ من هذه بطرفٍ من تلك.
    """
    out = []
    for line in re.split(r"[\n،؛]", text or ""):
        parts = [x.strip().rstrip(".") for x in line.split("=")]
        if len(parts) < 2:
            continue
        run = []
        for x in parts + [None]:
            v = value(x) if (x is not None and is_pure_expr(x)) else None
            if v is None:
                if len(run) >= 2:
                    bt, bv = run[0]
                    for t, val in run[1:]:
                        if not _same(bv, val):
                            out.append((bt, t, bv, val))
                            break
                run = []
            else:
                run.append((x, v))
    return [r for r in out if _HAS_OP.search(r[0]) or _HAS_OP.search(r[1])]


def question_defects(q: dict) -> list:
    """عيوبُ سؤالٍ واحد حسابياً — بالعربية كما يقرؤها الموديلُ في التصحيح."""
    bad = []
    qt, opts, idx = q.get("q", ""), q.get("options", []), q.get("correct_index")
    e = bare_question_expr(qt)
    if e is not None and isinstance(idx, int) and 0 <= idx < len(opts):
        v = value(e)
        if v is not None:
            marked = as_number(opts[idx])
            if marked is not None and not _same(v, marked):
                bad.append(f"«{qt[:60]}» جوابُه الصحيح {v} لا {marked}")
    for a, b, va, vb in _chain(q.get("why", "")):
        bad.append(f"تعليلٌ يناقض نفسَه: «{a} = {b}» — وأوّلُهما {va} والآخرُ {vb}")
    return bad


# ══════════════════════════════════════════════════
# 🎯 هل يدعم التعليلُ جوابَه؟ — ما لا تراه سلسلةُ المساواة
# ══════════════════════════════════════════════════
# 🔴 **العطلُ في وسم الجواب لا في الحساب:** درسُ الانحدار اشتقّ في تعليله
#    «ص = ٢٧ - ٢٤ = ٣» — حسابٌ سليمٌ تمامَ السلامة — ثم وسم الجوابَ «٥».
#    فسلسلةُ المساواة تمرّ، والطالبُ يُخطَّأ وهو مصيب.
# ⭐ فالإشارة: **الجوابُ الموسومُ عددٌ صريح، ولا يذكره التعليلُ أصلاً**،
#    وأقوى منها أن يذكر التعليلُ **خياراً آخر**.
# ⚠️ ولا تُطبَّق إلا حين تكون **الخياراتُ الأربعةُ كلُّها أعداداً صريحة**:
#    أوّلُ صيغةٍ قرأت «\frac{١}{٢}» عدداً (١٢) و«ل(س) = -\frac{٣}{س}»
#    عدداً (٣)، فوسمت ٣٠٣ من ٦٣٦ — ونسبةٌ كهذه تُدين المقياسَ لا البنك.
# 📏 **والوحدةُ جزءٌ من الخيار لا مانعٌ من قراءته**: «٢٢٥٠ مل» و«٢٨ كجم»
#    و«٠.٥ جرام» أعدادٌ صريحةٌ لابسةُ وحدة. وحصرُها أوّلاً في ستّ كلماتٍ
#    أسقط الفحصَ عن الأحياء والفيزياء والكيمياء كلِّها — وهناك كان أكثرُ
#    الخطأ. فالمقبولُ: عددٌ يتبعه **كلمتان قصيرتان** على الأكثر، ولا رمزَ
#    رسّامٍ فيه ولا متغيّر.
_UNIT = r"(?:[\u0621-\u064aA-Za-z%°/²³]{1,12}\s*){0,2}"
_PLAIN = re.compile(r"^\s*(?:[أ-د]\s*[.\-]\s*)?"          # «أ. ٠.١ لتر»
                    r"(-?[\u0660-\u0669\d]+(?:[.,٫][\u0660-\u0669\d]+)?)"
                    r"\s*" + _UNIT + r"$")
_SIGNED = re.compile(r"-?\d+(?:[.,]\d+)?")


def _plain(opt: str):
    m = _PLAIN.match(opt or "")
    if not m:
        return None
    try:
        return float(_norm_digits(m.group(1)).replace(",", ".").replace("٫", "."))
    except Exception:
        return None


def _norm_digits(s: str) -> str:
    """🔴 **والفاصلةُ العشرية العربية «٫» (U+066B) تُوحَّد أيضاً** — وإلا
       قُرئت «٢٤٫٥» عددين (٢٤ و٥) فوُسم سؤالٌ سليم. و«٬» فاصلةُ الآلاف
       تُحذف («١٠٬٠٠٠»)."""
    return (s or "").translate(str.maketrans("٠١٢٣٤٥٦٧٨٩٫", "0123456789.")).replace("٬", "")


def answer_defects(q: dict) -> list:
    """هل يذكر التعليلُ الجوابَ الموسوم؟"""
    opts, idx = q.get("options", []), q.get("correct_index")
    if not isinstance(idx, int) or not (0 <= idx < len(opts)):
        return []
    nums = [_plain(o) for o in opts]
    if sum(n is not None for n in nums) < 4:
        return []                                  # خيارٌ غيرُ عدديّ ⇒ نسكت
    marked = nums[idx]
    got = {float(x.replace(",", ".")) for x in _SIGNED.findall(_norm_digits(q.get("why", "")))}
    if not got or any(_same(x, marked) for x in got):
        return []
    other = [opts[i] for i, n in enumerate(nums)
             if i != idx and any(_same(x, n) for x in got)]
    head = q.get("q", "")[:55]
    if other:
        return [f"«{head}» تعليلُك يفضي إلى «{other[0]}» وجوابُك الموسوم «{opts[idx]}»"]
    return [f"«{head}» تعليلُك لا يذكر جوابَه «{opts[idx]}» — احسبه فيه صراحةً"]


def bank_defects(questions: list) -> list:
    """عيوبُ البنك حسابياً — ثلاثةٌ على الأكثر كي لا تطول رسالةُ التصحيح."""
    bad = []
    for q in questions or []:
        bad += question_defects(q) + answer_defects(q)
    return bad[:3]
