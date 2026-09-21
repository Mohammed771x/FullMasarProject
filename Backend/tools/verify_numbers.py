# -*- coding: utf-8 -*-
# ==================================================
# 🔢 tools/verify_numbers.py — مراجعةُ كلِّ سؤالٍ فوقه أرقام
# ==================================================
# 🎯 **أمرُ المالك (2026-09-17):** «أيُّ شيءٍ فوقه أرقام تأكّد منه — مش في
#    الرياضيات بس، الكيمياء والفيزياء وأيُّ مكانٍ فيه حسابات. وبإمكانك
#    تستخدم DeepSeek في الأشياء الكبيرة».
#
# 📏 المسحُ أعطى **٢١١١ سؤالاً حسابياً** في ١٤ مادّة — أكثرُ من أن يُراجَع
#    سؤالاً سؤالاً بيدي، وأقلُّ من أن يُترك.
#
# ⚖️ **وحدُّ هذه الأداة أنها تُرشِّح لا تحكم.** ما يقوله الموديلُ **دعوى
#    لا حكم**: يُراجَع بيدي، ويُطبَّق ما ثبت. وهذا عينُ ما تعلّمناه من أن
#    المقياسَ الخاطئ أسوأُ من لا مقياس ([tools/arith_check.py]).
#
# 🔒 والموديل **DeepSeek** — وهو موديلُ الحساب عندنا، والوحيدُ الذي لم
#    يُخطئ في ٢١١ ادّعاءً حسابياً قيسَ عليه.

import asyncio, json, os, re, sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

DIG = re.compile(r"[٠-٩\d]")
CALC = re.compile(r"احسب|أوجد|ما قيمة|ما هي قيمة|كم يساوي|كم عدد|ما ناتج|"
                  r"ما مقدار|ما مجموع|بكم طريقة|ما عدد|فما عدد|فما قيمة|فكم|"
                  r"إذا كان.*(?:فما|فكم|فأوجد|فاحسب)")

SYSTEM = """أنت مدقّقٌ حسابيٌّ صارم. تُعطى أسئلةَ اختيارٍ من متعدد فيها أرقام،
ومعها الجوابُ المعتمَد وتعليلُه.

مهمتك **واحدة**: هل الجوابُ المعتمَد صحيحٌ حسابياً وعلمياً؟

⛔ لا تُعلّق على الصياغة ولا على جودة السؤال ولا على الخيارات المشتِّتة.
⛔ ولا تعترض على تقريبٍ معقول (٤/٣ ≈ ١.٣٣) ولا على اختلاف صيغة الكتابة.
✅ اعترض **فقط** إذا كان الجوابُ المعتمَد خطأً بيّناً: حسابٌ غلط، أو
   قانونٌ طُبِّق مقلوباً، أو حقيقةٌ علميةٌ مخالفة.

أخرِج JSON فقط بهذا الشكل:
{"bad": [{"i": رقم_السؤال, "right": "نصُّ الخيار الصحيح حرفياً كما ورد",
          "why": "سطرٌ واحد يشرح الحساب الصحيح"}]}
وإن كانت كلُّها سليمة فأخرِج {"bad": []}."""


def batch_prompt(items):
    lines = []
    for i, q in items:
        opts = " | ".join("[%d] %s" % (j, o) for j, o in enumerate(q["options"]))
        lines.append(
            "### سؤال %d\n%s\nالخيارات: %s\nالمعتمَد: [%d] %s\nالتعليل: %s"
            % (i, q["q"], opts, q["correct_index"],
               q["options"][q["correct_index"]], q.get("why", "—")))
    return ("راجع هذه الأسئلة:\n\n" + "\n\n".join(lines)
            + "\n\nأخرِج JSON فقط.")


def numeric_questions(entry):
    out = []
    for i, q in enumerate(entry.get("questions", [])):
        if not isinstance(q.get("correct_index"), int):
            continue
        if not DIG.search(" ".join(q.get("options", []))):
            continue
        if not CALC.search(q.get("q", "")):
            continue
        out.append((i, q))
    return out


async def review(items, size=8):
    """يُرجع دعاوى الخطأ — **دعاوى تُراجَع لا أحكامٌ تُطبَّق**."""
    from tools.build_quizzes import clients, _MAX_TOKENS, _TIMEOUT
    from subjects.math import MATH_MODEL
    client = clients().get("deepseek")
    if client is None:
        raise RuntimeError("DeepSeek غير مهيّأ — راجع .env")
    claims, calls = [], 0
    for s in range(0, len(items), size):
        chunk = items[s:s + size]
        try:
            r = await asyncio.wait_for(client.chat.completions.create(
                model=MATH_MODEL, temperature=0,
                max_tokens=_MAX_TOKENS,
                messages=[{"role": "system", "content": SYSTEM},
                          {"role": "user", "content": batch_prompt(chunk)}]),
                timeout=_TIMEOUT)
            calls += 1
            txt = r.choices[0].message.content
            m = re.search(r"\{.*\}", txt, re.S)
            if not m:
                continue
            for b in json.loads(m.group(0)).get("bad", []):
                claims.append(b)
        except Exception as e:                     # نداءٌ سقط ⇒ يُسجَّل ويُمضى
            print("   ⚠️ نداءٌ سقط:", type(e).__name__, str(e)[:70])
    return claims, calls
