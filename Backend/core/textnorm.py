# ==================================================
# 🔬 core/textnorm.py — تطبيع النص ومقارنة الكتل المحمية
# ==================================================
# وحدة نقيّة بلا شبكة ولا ملفات — تُختبر وحدها (tests/test_ingest.py).
#
# لماذا التطبيع قبل المقارنة؟
#   الموديل يكتب «س⁴» ونحن كتبنا «س^4»، ويكتب «×» ونحن «*»، ويكتب أرقاماً
#   عربية «٤» ونحن «4». مقارنة حرفية بلا تطبيع تُطلق إنذاراً على كل سطر
#   تقريباً — فيصير التقرير ضجيجاً يتجاهله المراجع، وهذا أسوأ من غيابه.
#
# ⚠️ **الأرقام لا تُطبَّع إلى شيء يُخفي اختلافها.** التطبيع يوحّد الشكل
#    (٤ → 4) ولا يوحّد القيمة أبداً: «10» و«100» يبقيان مختلفَين، وهذه
#    بالضبط الحالة التي تُسقط فحص «وجود كل رمز» ويمسكها فحص الكتلة.

import re
import unicodedata
from difflib import SequenceMatcher

# ── محارف التحكم ثنائية الاتجاه: غير مرئية وتُفسد أي مقارنة ──
_BIDI_CHARS = "‎‏‪‫‬‭‮⁦⁧⁨⁩؜​‌‍﻿"
_BIDI_RE = re.compile(f"[{_BIDI_CHARS}]")

# ── الأرقام: العربية-الهندية والفارسية → لاتينية ──
_DIGIT_MAP = {}
for _i, _ch in enumerate("٠١٢٣٤٥٦٧٨٩"):
    _DIGIT_MAP[_ch] = str(_i)
for _i, _ch in enumerate("۰۱۲۳۴۵۶۷۸۹"):
    _DIGIT_MAP[_ch] = str(_i)

# ── الأسس والدلائل ككتلة واحدة: «س⁴⁵» → «س^45» لا «س^4^5» ──
_SUPERS = "⁰¹²³⁴⁵⁶⁷⁸⁹"
_SUBS = "₀₁₂₃₄₅₆₇₈₉"
_SUPER_RUN = re.compile(f"[{_SUPERS}⁺⁻]+")
_SUB_RUN = re.compile(f"[{_SUBS}]+")
_SUPER_MAP = {c: str(i) for i, c in enumerate(_SUPERS)}
_SUPER_MAP.update({"⁺": "+", "⁻": "-"})
_SUB_MAP = {c: str(i) for i, c in enumerate(_SUBS)}

# ── الرموز المتكافئة شكلاً ──
_SYMBOL_MAP = {
    "×": "*", "∙": "*", "·": "*", "⋅": "*",
    "÷": "/", "∕": "/", "⁄": "/",
    "−": "-", "–": "-", "—": "-", "ـ": "",      # آخرها التطويل
    "٫": ".", "،": ",", "؛": ";", "؟": "?",
    "≡": "=", "﹦": "=",
    "٪": "%", "−": "-",
    "“": '"', "”": '"', "‘": "'", "’": "'",
    "𝜋": "π", "ℼ": "π",
    "\u2032": "'", "\u00b4": "'", "\u0060": "'",   # ′ ´ ` → علامة مشتقة واحدة
}
_SYMBOL_RE = re.compile("|".join(re.escape(k) for k in _SYMBOL_MAP))

_WS_RE = re.compile(r"\s+")

# ── ما يجعل السطر «رياضياً»: عامل أو علاقة أو دالة مثلثية ──
# ⚠️ **لا تُطابَق كسلاسل فرعية أبداً.** «لو» داخل «الوسط»، و«قا» داخل
# «قانون» و«نقاط»، و«لو» داخل «محلولة» — فالمطابقة الساذجة تجعل كل نثر
# الدرس «رياضياً» فيمتلئ التقرير بإنذارات كاذبة ويتوقف المراجع عن قراءته.
_MATH_FUNC_RE = re.compile(
    r"(?<![\u0621-\u064A])(جتا|جا|ظتا|ظا|قتا|قا|نها|لوغ|لتا|لو)(?![\u0621-\u064A])")
_MATH_SYMS = ("√", "∫", "∑")
_REL_RE = re.compile(r"[=≠≤≥<>≈]")
_OP_RE = re.compile(r"[\^√∫∑+*/]|(?<=\d)-|-(?=\d)")
_DIGIT_RE = re.compile(r"\d")
_VAR_RE = re.compile(r"(?<![ء-ي])[سصعنرهـقلد](?![ء-ي])|[a-zA-Z](?![a-zA-Z])")


def normalize(text: str) -> str:
    """يرجع الصورة المعيارية للمقارنة — الشكل يُوحَّد والمعنى لا يُمَس."""
    if not text:
        return ""
    s = str(text)
    s = _BIDI_RE.sub("", s)
    s = re.sub(r"[\u064B-\u0652]", "", s)      # التشكيل — قبل أي شيء آخر
    # ⚠️ الأسس **قبل** NFKC: فهو يحوّل «س²» إلى «س2» فيضيع معنى الأس،
    #    وتصير «س²» و«س2» متطابقتين بينما هما مختلفتان فعلاً.
    s = _SUPER_RUN.sub(lambda m: "^" + "".join(_SUPER_MAP.get(c, c) for c in m.group()), s)
    s = _SUB_RUN.sub(lambda m: "_" + "".join(_SUB_MAP.get(c, c) for c in m.group()), s)
    s = unicodedata.normalize("NFKC", s)
    s = "".join(_DIGIT_MAP.get(c, c) for c in s)
    s = _SYMBOL_RE.sub(lambda m: _SYMBOL_MAP[m.group()], s)
    s = _WS_RE.sub(" ", s)
    return s.strip()


def digits_signature(text: str) -> list:
    """كل الأعداد في النص بترتيبها — بصمة تكشف «10 → 100» فوراً."""
    return re.findall(r"\d+(?:\.\d+)?", normalize(text))


def is_math_bearing(text: str) -> bool:
    """هل السطر يحمل رياضيات تستحق الفحص؟ (نتجنّب إغراق التقرير بالنثر)"""
    n = normalize(text)
    if not n:
        return False
    if _REL_RE.search(n) and (_DIGIT_RE.search(n) or _VAR_RE.search(n)):
        return True
    if _MATH_FUNC_RE.search(n) or any(sym in n for sym in _MATH_SYMS):
        return True
    if _OP_RE.search(n) and _DIGIT_RE.search(n):
        return True
    return False


def split_lines(text: str) -> list:
    """تقسيم إلى سطور ذات معنى — الأسطر الفارغة وعلامات الصفحات تُستبعد."""
    out = []
    for line in str(text or "").split("\n"):
        line = line.strip()
        if line and not PAGE_MARK_RE.match(line):
            out.append(line)
    return out


# ══════════════ فهرس النص الخام ══════════════

PAGE_MARK = "--- صفحة {n} ---"
PAGE_MARK_RE = re.compile(r"^-{2,}\s*صفحة\s*(\d+)\s*-{2,}$")


class RawIndex:
    """سطور النص الخام مع رقم الصفحة، ونوافذ من ١..٣ سطور متتالية.

    النوافذ ضرورية: الملخّص قد يكتب التعريف في سطرين والموديل يدمجهما في
    حقلٍ واحد — بلا نوافذ يُبلَّغ عن «اختلاف» وهو نقلٌ أمين."""

    MAX_WINDOW = 3

    def __init__(self, raw_text: str):
        self.lines = []          # [(page, text)]
        page = 1
        for line in str(raw_text or "").split("\n"):
            line = line.strip()
            if not line:
                continue
            m = PAGE_MARK_RE.match(line)
            if m:
                page = int(m.group(1))
                continue
            self.lines.append((page, line))

        self.windows = []        # [(page, text, normalized)]
        n = len(self.lines)
        for i in range(n):
            for w in range(1, self.MAX_WINDOW + 1):
                if i + w > n:
                    break
                chunk = self.lines[i:i + w]
                joined = " ".join(t for _, t in chunk)
                self.windows.append((chunk[0][0], joined, normalize(joined)))

    def containing(self, block: str):
        """أقصر نافذة **تحتوي** الكتلة حرفياً بعد التطبيع — أو None.

        الاحتواء دليلٌ قاطع على أمانة النقل: لا كلمة أُضيفت ولا رقمٌ تغيّر،
        وإنما أُسقطت لصيقة مثل «تعريف:» أو «مثال محلول:». وبدون هذه القاعدة
        كان كل تعريفٍ نُزعت لصيقته يُبلَّغ عنه — ثلاثة من كل أربعة إنذارات."""
        target = normalize(block)
        if not target:
            return None
        best = None
        for page, text, norm in self.windows:
            if target in norm and (best is None or len(norm) < len(best[2])):
                best = (page, text, norm)
        return best

    def best_match(self, block: str):
        """أقرب نافذة للكتلة: (نسبة التطابق، الصفحة، نص النافذة)."""
        target = normalize(block)
        if not target or not self.windows:
            return 0.0, None, ""
        best = (0.0, None, "")
        matcher = SequenceMatcher(autojunk=False)
        matcher.set_seq2(target)
        for page, text, norm in self.windows:
            # قصّ سريع: فرق طولٍ كبير لا يمكن أن يعطي نسبة عالية
            if abs(len(norm) - len(target)) > max(len(target), 1) * 0.6:
                continue
            matcher.set_seq1(norm)
            if matcher.real_quick_ratio() <= best[0] or matcher.quick_ratio() <= best[0]:
                continue
            r = matcher.ratio()
            if r > best[0]:
                best = (r, page, text)
                if r == 1.0:
                    break
        return best


# ══════════════ مقارنة الكتل ══════════════

# حقول تُنقل حرفياً — تُقارَن كاملةً حتى لو كانت نثراً
PROTECTED_KEYS = {
    "النص", "التعريف", "المصطلح", "القانون", "المعادلة", "الصيغة",
    "خطوات_الحل", "النتيجة", "الحل", "السؤال", "نص_السؤال", "نص_الصفحة",
}

# حقول حرّة — للموديل أن يصوغها، لكن أي معادلة داخلها تُفحص
FREE_KEYS = {
    "ملخص_قصير", "مقدمة", "خاتمة", "الشرح", "العنوان", "اسم_الجزء",
    "اسم_الدرس", "اسم_الوحدة", "اسم_الجزء", "كتاب", "نوع",
}

# مفاتيح بنيوية: أسماء وعناوين من صنع القالب لا من الملخّص — لا تُقارَن.
SKIP_KEYS = {
    "نوع", "اسم_الجزء", "اسم_الوحدة", "اسم_الدرس", "اسم_درس", "كتاب",
    "العنوان", "رقم_الوحدة", "رقم_الدرس", "رقم_الصفحة", "عدد_الدروس",
}

EXACT = 1.0
CONTAINED_KEEP = 0.8         # اقتطاعٌ يُبقي ٨٠٪ فأكثر = لصيقة وصفية أُسقطت
MISMATCH_FLOOR = 0.55        # تحتها: لا أصل له في النص الخام


def _walk_strings(node, path=""):
    """يمرّ على كل نصٍّ في الـ JSON مع مساره ومفتاحه الأخير."""
    if isinstance(node, dict):
        for k, v in node.items():
            yield from _walk_strings(v, f"{path}.{k}" if path else str(k))
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from _walk_strings(v, f"{path}[{i}]")
    elif isinstance(node, str):
        yield path, node


def _last_key(path: str) -> str:
    seg = path.split(".")[-1]
    return re.sub(r"\[\d+\]$", "", seg)


def audit(raw_text: str, data) -> dict:
    """يقارن الكتل المحمية والمعادلات في `data` بالنص الخام.

    يرجع: {"issues": [...], "checked": n, "exact": n}
    كل مشكلة: {level, kind, path, page, expected, found, ratio}
      · level="high"   الأرقام اختلفت أو الكتلة بلا أصل  → توقّف وراجع
      · level="medium" الصياغة اختلفت والأرقام سليمة     → غالباً إعادة صياغة
    """
    index = RawIndex(raw_text)
    issues, checked, exact = [], 0, 0

    for path, value in _walk_strings(data):
        key = _last_key(path)
        if key.startswith("_") or key in SKIP_KEYS:
            continue
        protected = key in PROTECTED_KEYS

        if protected:
            blocks = [value] if value.strip() else []
        else:
            blocks = [ln for ln in split_lines(value) if is_math_bearing(ln)]

        for block in blocks:
            if len(normalize(block)) < 3:
                continue
            checked += 1

            hit = index.containing(block)
            if hit is not None:
                page, source, norm_source = hit
                kept = len(normalize(block)) / max(len(norm_source), 1)
                if kept >= CONTAINED_KEEP:
                    exact += 1          # لصيقة وصفية أُسقطت — نقلٌ أمين
                    continue
                issues.append({
                    "level": "medium", "kind": "نصٌّ مقتطع من الأصل",
                    "path": path, "page": page,
                    "expected": source, "found": block,
                    "ratio": round(kept, 3),
                })
                continue

            ratio, page, source = index.best_match(block)

            if ratio >= EXACT:
                exact += 1
                continue

            if ratio < MISMATCH_FLOOR:
                issues.append({
                    "level": "high",
                    "kind": "بلا أصل في النص الخام",
                    "path": path, "page": page,
                    "expected": "", "found": block, "ratio": round(ratio, 3),
                })
                continue

            same_digits = digits_signature(block) == digits_signature(source)
            issues.append({
                "level": "medium" if same_digits else "high",
                "kind": "صياغة مختلفة" if same_digits else "أرقام مختلفة",
                "path": path, "page": page,
                "expected": source, "found": block, "ratio": round(ratio, 3),
            })

    issues.sort(key=lambda i: (i["level"] != "high", i.get("page") or 0))
    return {"issues": issues, "checked": checked, "exact": exact}


def format_report(result: dict) -> str:
    """تقرير نصّي مختصر — للطرفية وللسجل."""
    lines = [f"فُحصت {result['checked']} كتلة · مطابِقة تماماً {result['exact']}"]
    for it in result["issues"]:
        mark = "❌" if it["level"] == "high" else "⚠️"
        lines.append(f"{mark} {it['kind']} — صفحة {it['page'] or '?'} · {it['path']}")
        if it["expected"]:
            lines.append(f"   الأصل  : {it['expected']}")
        lines.append(f"   الموجود: {it['found']}")
    return "\n".join(lines)
