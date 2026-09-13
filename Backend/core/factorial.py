# ==================================================
# ⌋ core/factorial.py — المضروب بالرمز العربي لا بعلامة !
# ==================================================
# 🔴 **ما رآه المالك (2026-09-10):** «المضروب في اللغة العربية يكون على شكل
#    حرف L بس بالمقلوب ويكون فوقه الرقم… إنت حاطه الآن بالإنجليزي».
#
# ⭐ فالرمز العربي زاويةٌ قائمة: ضلعٌ عن يمين العدد وقاعدةٌ تمتدّ يساراً
#    تحته — «⌋ن» —
#    والتطبيق يرسمها من ترميز `\fact{…}`، نظير `\frac` و`\sqrt` تماماً.
#
# 🔴🔴 **وخطرُ هذا الملفّ في علامة التعجّب.** مسحُ بيانات المواد الرياضية:
#      • بعد **رقم** ٦٩ · بعد **قوس مغلق** ٢٤  ⇦ مضروبٌ يقيناً
#      • بعد **مسافة** ٨ و«؟» ٢  ⇦ تعجّبٌ نثريّ: «هل رأيت التوأم !»
#      • وبعد حرفٍ عربي ١٦ — أكثرُها «ن!» و«ر1!» لكن فيها **«مستحيل!»**
#    فالتمييز على **الكلمة كاملةً** لا على الحرف الذي قبل العلامة.

import re

from .roots import ROOT_SUBJECTS, is_root_subject   # نفس نطاق الجذر

__all__ = ["to_factorial", "ROOT_SUBJECTS"]

_DIGITS = set("0123456789٠١٢٣٤٥٦٧٨٩")
_BREAK = set(" +-−=×*/(),،؛;:[]{}\n\t|!؟")

# «مضروب(ن)» · «مضروب ن» · «المضروب (٥)»
# ⚠️ `(ال)?` لا `ال?` — الثانية تجعل الألف **إلزامية** فتفوت «مضروب ن»
#    كلَّها ولا تلتقط إلا «المضروب». علّةٌ صامتة: النمط يعمل ويُخطئ.
_WORD = re.compile(r"(?:ال)?مضروب\s*")

# 📖 «المضروب (Factorial)» تعريفٌ يذكر المصطلح الإنجليزي — لا مقدارَ فيه.
_LATIN = re.compile(r"[A-Za-z]")


def _is_operand(tok: str) -> bool:
    """أمقدارٌ حقيقي هو؟ — رقمٌ، أو حرفٌ عربيٌّ **مفرد** رمزيّ.

    🔴 **علّتان وقعتا فعلاً:**
      ١. «نلاحظ تناوب الإشارة وظهور المضروب.» — النقطة ليست في `_BREAK`
         فصارت هي «المقدار» وخرج للطالب `\\fact{.}`.
      ٢. «المضروب **هو** رمزٌ يعني…» — «هو» حرفان عربيان، فابتلعتها
         الزاوية وصار الكلامُ رياضياتٍ. ورآها المالك في جواب الموديل:
         «لما يظهر مع الكلام، الكلمة اللي بعده بتدخل داخل المضروب».

    ⭐ فالحدّ **حرفٌ واحد** لا حرفان: «ن» و«ر1» و«هـ» مقادير،
       و«هو» و«ما» و«في» و«لا» كلامٌ. وكلُّ متغيّرات الكتاب مفردة.
    """
    if not tok:
        return False
    if all(c in _DIGITS for c in tok):
        return True
    letters = [c for c in tok if c not in _DIGITS]
    if not all("\u0621" <= c <= "\u064a" or c == "\u0640" for c in letters):
        return False
    # «هـ» حرفٌ واحد بتطويل، وما عداه فحرفٌ مفرد يتبعه رقمٌ اختياريّ.
    core = "".join(c for c in letters if c != "\u0640")
    return len(core) == 1


def _left_token(src: str, end: int):
    """المقدار الملاصق يسارَ العلامة — أو `None` إن لم يكن مقداراً.

    ⚠️ **الفحص على الكلمة كاملة**: «مستحيل!» آخرُها حرفٌ عربي كـ«ن!»،
       والفرقُ طولُ الكلمة لا حرفُها الأخير.
    """
    if end <= 0:
        return None

    # قوسٌ مغلق ⇒ نأخذ المجموعة كلها: «(ن-1)!»
    if src[end - 1] == ")":
        depth = 0
        for k in range(end - 1, -1, -1):
            if src[k] == ")":
                depth += 1
            elif src[k] == "(":
                depth -= 1
                if depth == 0:
                    return src[k + 1:end - 1], k
        return None

    i = end
    while i > 0 and src[i - 1] not in _BREAK:
        i -= 1
    tok = src[i:end]
    if not tok:
        return None
    # رمزٌ قصير («ن» · «ر1» · «س») لا كلمةٌ عربية («مستحيل») ولا علامةَ ترقيم
    return (tok, i) if _is_operand(tok) else None


# 📖 **الرمز مجرّداً في التعريف**: «مضروب العدد ( ! ):» — تعريفٌ يُري
#    الطالبَ العلامةَ نفسها، فيجب أن يراها **عربيةً** لا إنجليزية.
#    مشروطٌ بذكر «مضروب» في السطر، وإلا فكل «( ! )» تعجّبٌ بين قوسين.
#    ⚖️ ونظيرتُها «( √ )» في بقية المواد علامةُ صحٍّ في الامتحانات (٣٤ موضعاً)
#       — ولذلك لا يُعمَّم هذا أبداً على غير المضروب.
_SYMBOL_ONLY = re.compile(r"\(\s*!\s*\)")


def to_factorial(text: str, subject: str = "") -> str:
    """يحوّل «ن!» و«مضروب(ن)» إلى `\\fact{ن}` — في المواد الرياضية وحدها."""
    if not text or not is_root_subject(subject):
        return text
    if "!" not in text and "مضروب" not in text:
        return text

    # ٠) الرمز مجرّداً داخل تعريفٍ يذكر «مضروب» ⇒ زاويةٌ فارغة.
    if "مضروب" in text:
        # ⚠️ لامدا لا نصّاً: `\\f` في قالب `re.sub` محرفُ تغذيةِ صفحة
        #    لا شرطةٌ مائلة — فخرجت «act{}» في أول تجربة.
        text = _SYMBOL_ONLY.sub(lambda _: "\\fact{}", text)

    # ١) الصيغة الكلامية: «مضروب (ن-1)» · «مضروب ن»
    out = []
    i = 0
    while i < len(text):
        m = _WORD.match(text, i)
        if not m:
            out.append(text[i])
            i += 1
            continue
        j = m.end()
        if j < len(text) and text[j] == "(":
            depth = 0
            for k in range(j, len(text)):
                if text[k] == "(":
                    depth += 1
                elif text[k] == ")":
                    depth -= 1
                    if depth == 0:
                        body = text[j + 1:k].strip()
                        if body and not _LATIN.search(body):
                            out.append("\\fact{%s}" % body)
                        else:
                            out.append(text[i:k + 1])
                        i = k + 1
                        break
            else:
                out.append(text[i:j])
                i = j
            continue
        k = j
        while k < len(text) and text[k] not in _BREAK:
            k += 1
        tok = text[j:k]
        if _is_operand(tok):
            out.append("\\fact{%s}" % tok)
            i = k
        else:
            # ⚠️ «مضروب العدد» و«المضروب وتناوب الإشارات» كلامٌ لا رمز.
            out.append(text[i:j])
            i = j
    text = "".join(out)

    # ٢) علامة التعجّب — بعد مقدارٍ وحده.
    res = []
    i = 0
    while i < len(text):
        if text[i] != "!":
            res.append(text[i])
            i += 1
            continue
        got = _left_token("".join(res), len("".join(res)))
        if got is None:
            res.append("!")
            i += 1
            continue
        body, start = got
        joined = "".join(res)
        res = [joined[:start], "\\fact{%s}" % body]
        i += 1
    return "".join(res)
