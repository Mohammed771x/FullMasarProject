# -*- coding: utf-8 -*-
# ==================================================
# 🔧 tools/repair_numeric.py — إصلاحُ السؤال الذي لا يُحَلُّ من معطياته
# ==================================================
# 🎯 **أمرُ المالك:** «أشياءُ بلا معطيات بلا شيء — إنت ضبّطها، وخلّها تكون
#    في سياق الدرس وتكون صحيحة».
#
# ⚖️ والفارقُ عن `verify_numbers`: تلك **تُرشِّح**، وهذه **تُعيد الصياغة**
#    — فتأخذ نصَّ الدرس نفسَه كي يبقى السؤالُ من الكتاب لا من خارجه.
#
# 🔒 **ولا يُقبل بديلٌ حتى يجتاز فحصي**: أربعةُ خيارات متمايزة، وجوابٌ
#    ضمنها، وحسابٌ لا يناقض تعليلَه ([tools/arith_check.py]).

import asyncio, json, re, os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

SYSTEM = """أنت معلّمٌ يُصلح أسئلةَ اختبارٍ معطوبة في كتابٍ مدرسيّ يمنيّ.

يُعطى إليك **نصُّ الدرس** وسؤالٌ فيه عطبٌ حسابيّ: إمّا أن جوابه المعتمَد
خطأ، وإمّا أن السؤال **لا يُحَلُّ من معطياته** أصلاً.

أعد كتابةَ السؤال بحيث:
1. يبقى **من نصّ الدرس المرفق** — لا معلومةَ من خارجه.
2. **يُحَلُّ من معطياته وحدها**، حلاًّ واحداً لا ثاني له.
3. `why` **تُنفّذ الحساب خطوةً خطوة** وتنتهي إلى الجواب بعينه.
4. أربعةُ خيارات متمايزة، والصحيحُ بينها، والمشتّتاتُ أخطاءٌ شائعةٌ محسوبة.
5. أبقِ لغةَ الدرس ومصطلحاته، والأرقامَ بالشكل الذي جاءت به في السؤال.

أخرِج JSON فقط:
{"q": "...", "options": ["...","...","...","..."], "correct_index": 0,
 "why": "...", "topic": "النقطة الدقيقة"}"""


def user_prompt(lesson_text, q, note):
    return (f"━━━ نصُّ الدرس ━━━\n{lesson_text[:5000]}\n━━━━━━━━━━\n\n"
            f"السؤال المعطوب:\n{q['q']}\n"
            f"الخيارات: {q['options']}\n"
            f"المعتمَد: [{q['correct_index']}] {q['options'][q['correct_index']]}\n"
            f"التعليل: {q.get('why','—')}\n\n"
            f"العطبُ المرصود: {note}\n\nأخرِج JSON فقط.")


async def repair(lesson_text, q, note):
    from tools.build_quizzes import clients, _MAX_TOKENS, _TIMEOUT
    from subjects.math import MATH_MODEL
    client = clients()["deepseek"]
    r = await asyncio.wait_for(client.chat.completions.create(
        model=MATH_MODEL, temperature=0.2, max_tokens=_MAX_TOKENS,
        messages=[{"role": "system", "content": SYSTEM},
                  {"role": "user", "content": user_prompt(lesson_text, q, note)}]),
        timeout=_TIMEOUT)
    m = re.search(r"\{.*\}", r.choices[0].message.content, re.S)
    return json.loads(m.group(0)) if m else None


def accept(new, subject):
    """🛡️ لا يُقبل بديلٌ حتى يجتاز الفحص — والمردودُ يُترك كما كان."""
    from tools.build_quizzes import tidy_question
    from tools.arith_check import question_defects, answer_defects
    if not isinstance(new, dict):
        return None, "ليس JSON"
    fixed = tidy_question(new, "", subject)
    if fixed is None:
        return None, "سقط في التنقية"
    bad = question_defects(fixed) + answer_defects(fixed)
    if bad:
        return None, bad[0][:80]
    return fixed, "✅"
