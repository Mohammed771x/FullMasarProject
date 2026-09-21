# ==================================================
# ⁿ core/powers.py — الأُسّ مرسوماً لا محرفاً
# ==================================================
# 🔴 **ما رآه المالك (2026-09-10):** «الأس خلّه واضح… وإذا كان سالب يطلع
#    ما أدري كيف… وإذا كان متغيّر مثل ن+١ ما أدري كيف يطلع… وإذا كان
#    الأس وبجنبه رقم يدخل الأس مع الرقم اللي بعده».
#
# 🔴🔴 **والعلّة الجذرية: آليتان متوازيتان.**
#      مسحُ المنهج وجد ٣٩٢١ أُسّاً موزّعةً على شكلين:
#        • ١٧٤٨ محرفَ يونيكود جاهزاً («س²») — يظهر جميلاً
#        • ٢١٧٣ بصيغة «^» — منها ١١٣٦ رقمٌ و٥٠٣ سالبٌ و١٢١ بين قوسين
#      وكان المحوِّل القديم يترجم الأرقام وحدها، فيبقى «س^(ن-١)» خاماً
#      على الشاشة بجانب «س²» المرسوم — **فيبدو السطر نصفَه رياضياتٍ
#      ونصفَه شيفرة.** ولذلك تُوحَّد الآلية: كلُّ أُسٍّ يصير `\sup{…}`
#      ويرسمه التطبيق مرفوعاً مصغَّراً، أياً كان محتواه.
#
# ⭐ **والقوسان المعقوفان يحلّان «ابتلاع ما بعده»**: حدُّ الأُسّ صريحٌ،
#    فـ«١٠^٢٣ × ٥» تصير `١٠\sup{٢٣} × ٥` ولا يمكن أن تجرّ الخمسة معها.
#    (وقعت فعلاً: `'^2': '²'` استبدالاً أعمى جعل عدد أفوجادرو «١٠²٣».)

import re

from .roots import ROOT_SUBJECTS, is_root_subject   # نفس نطاق الجذر

__all__ = ["to_power", "ROOT_SUBJECTS"]

_ARABIC = r"ء-ي"

# ➖ **والسالبُ محرفان لا محرف**: «س^−٣» في تكامل القوى السالبة يكتبها
#    الكتابُ بـ«−» (U+2212) لا بشرطة ASCII، فبقيت «^» عاريةً أمام الطالب.

# ⚠️ ما يرسمه التطبيق بنفسه لا يُمسّ: داخل `\chem{}` و`\ring{}` شحناتٌ
#    وأرقامُ ذرّاتٍ لها رسّامُها الخاص ([core/chem.py]).
_SHIELD = re.compile(r"\\(?:chem|ring)\{[^{}]*\}")

_BRACED = re.compile(r"\^\{([^{}]{1,40})\}")
# 🔴 **لا فراغ بعد «^»**: «نصّ فيه ^ وحده» أعطت `\\sup{و}حده` — التقطت
#    واوَ «وحده» أُسّاً. والكتاب لا يكتب الأُسّ إلا ملاصقاً.
_PAREN_HEAD = re.compile(r"\^([+-−]?)\(")
# ⚠️ حرفٌ لاتينيٌّ **مفرد** مقبول: «[A]^a» رتبةُ تفاعلٍ في الكيمياء.
#    والمفردُ وحده — فالكلمة اللاتينية بعد «^» ليست أُسّاً.
_SIMPLE = re.compile(
    r"\^([+-−]?)([0-9٠-٩]+|[" + _ARABIC + r"]ـ?[0-9٠-٩]?|[A-Za-z])"
    r"(?![A-Za-z])")

# ⚖️ **وفراغٌ واحد يُغتفر إن وقف المقدار وحده**: الكتاب يكتب «هـ ^ س»
#    (الدالة الأسّية) بفراغين. والفارقُ عن «نصّ فيه ^ وحده» أن «و» هناك
#    يتبعها «حده» فتصير كلمة — فالشرط: حرفٌ **لا يتلوه حرف**.
# ⚖️ وفراغُ الملء أُسّاً: «هـ ^ ........» في تمرين «أكمل الفراغات».
#    يُرسم صندوقاً مرفوعاً فارغاً، لا «^» عاريةً بجانب نقاطٍ.
_BLANK = re.compile(r"\^\s*(\.{3,}|_{3,}|\[\s*\])")

_SPACED = re.compile(
    r"\^[ \t]+([+-−]?)([0-9٠-٩]+|[" + _ARABIC + r"]ـ?)(?![" + _ARABIC + r"A-Za-z])")

# محارفُ اليونيكود الجاهزة ⇒ تُردّ إلى الترميز نفسه ليتّحد المظهر.
_UNI = "⁰¹²³⁴⁵⁶⁷⁸⁹⁺⁻ⁿ"
_UNI_BACK = str.maketrans(_UNI, "0123456789+-ن")
_UNI_RUN = re.compile(
    r"(?<=[0-9٠-٩" + _ARABIC + r")\]}])([" + _UNI + r"]+)")


def _wrap(body: str) -> str:
    body = body.strip()
    return "\\sup{%s}" % body if body else ""


_OPS = set("+-−×÷/")


def _body(sign: str, body: str) -> str:
    """🔴 «(س-أ)^-(ن+١)» — القوسان جزءٌ من المعنى لا زينة.

    إسقاطُهما يقلب الأُسّ من −(ن+١) إلى −ن+١، وهذا **خطأٌ رياضيّ**
    يصل الطالبَ في ورقة امتحان. فإن سبقت إشارةٌ مقداراً مركّباً، بقيا.
    """
    if sign and any(c in _OPS for c in body):
        return _wrap("%s(%s)" % (sign, body))
    return _wrap(sign + body)


def _parens(chunk: str) -> str:
    """«هـ^(ل(س))» — قوسٌ داخل قوس، ولا يبلغه تعبيرٌ نمطيّ.

    🔴 سبعةُ أسطرٍ في تكامل الدوال الأسّية بقيت خاماً لأن `[^()]` تتوقّف
       عند أول قوسٍ داخليّ. فالمسحُ متوازنٌ بالعدّ لا بالنمط.
    """
    out, i = [], 0
    while True:
        m = _PAREN_HEAD.search(chunk, i)
        if not m:
            out.append(chunk[i:])
            return "".join(out)
        depth, k = 0, m.end() - 1
        while k < len(chunk):
            if chunk[k] == "(":
                depth += 1
            elif chunk[k] == ")":
                depth -= 1
                if depth == 0:
                    break
            k += 1
        if depth or k - m.end() > 60:      # قوسٌ غير مغلق ⇒ اتركه
            out.append(chunk[i:m.end()])
            i = m.end()
            continue
        out.append(chunk[i:m.start()])
        out.append(_body(m.group(1), chunk[m.end():k].strip()))
        i = k + 1


def _convert(chunk: str) -> str:
    chunk = _BRACED.sub(lambda m: _wrap(m.group(1)), chunk)
    chunk = _parens(chunk)
    chunk = _SIMPLE.sub(lambda m: _wrap(m.group(1) + m.group(2)), chunk)
    chunk = _SPACED.sub(lambda m: _wrap(m.group(1) + m.group(2)), chunk)
    chunk = _BLANK.sub(lambda _: "\\sup{…}", chunk)
    chunk = _UNI_RUN.sub(lambda m: _wrap(m.group(1).translate(_UNI_BACK)), chunk)
    return chunk


def to_power(text: str, subject: str = "") -> str:
    """يوحّد كل صيغ الأُسّ في `\\sup{…}` — في المواد الرياضية وحدها.

    ⚖️ خارجها «م²» في الجغرافيا وحدةُ مساحةٍ في نصٍّ عادي، ولا رسّامَ لها.
    """
    if not text or not is_root_subject(subject):
        return text
    if "^" not in text and not any(c in text for c in _UNI):
        return text

    out, last = [], 0
    for m in _SHIELD.finditer(text):
        out.append(_convert(text[last:m.start()]))
        out.append(m.group(0))          # المحميّ كما هو
        last = m.end()
    out.append(_convert(text[last:]))
    return "".join(out)
