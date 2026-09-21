import re
# ==================================================
# 🎯 tools/quiz_spec.py — مواصفةُ بناء بنك الأسئلة
# ==================================================
#
# ⚖️ **قرار المالك (2026-09-16):** «لكل درسٍ أسئلة — مبتدئة ومتوسطة وصعبة،
#    ومع كل سؤالٍ وزنُ أهمية. **لكل نقطةٍ سؤال**، فدرسٌ طويلٌ يختلف عن قصير.
#    وجودةُ المحتوى أهمُّ شيء لأننا نبنيه مرّةً واحدة.»
#
# 🏗️ **وهذه المواصفةُ للبناء وحده** — لا تمسّ برومبت [core/quiz_prompt]
#    الذي يخدم التوليدَ الحيَّ حين لا يوجد بنك. فصلٌ مقصود: ما يُبنى مرّةً
#    ويُقرأ مئاتِ الآلاف يستحقّ تعليماتٍ أطولَ وأدقَّ مما يُولَّد في ثانية.
#
# ☢️ **وكلُّ بندٍ هنا ثمنُه عطلٌ وقعَ فعلاً** — لا احتياطٌ نظريّ. راجع
#    [[lesson-explanation-cache]]: بناءُ الشروح علّمنا أن الموديل **يطيع
#    التعليمةَ حرفاً بحرف، بما في ذلك آثارُها التي لم نقصدها**.

VERSION = "q1"
# 🏷️ تاريخُ النسخ:
#   q1 = الأولى: مستوى + وزن + نوع + تعليلُ الإجابة، وأوزانٌ معايَرة.


# ══════════════════════════════════════════════════
# ⚖️ مرساةُ الأهمية — من بنية الكتاب لا من ذوق الموديل
# ══════════════════════════════════════════════════
#
# 🔴 **لو تُرك الوزنُ لتقدير الموديل لأعطى الجميعَ ٥.** فالمرساةُ من
#    المُسلسِل نفسِه: كلُّ جزءٍ في الدرس يحمل `نوع:` — ومسحُ منهج الثالث
#    أعطى هذه الأنواع بالترتيب: نقاط_مهمة (٥٨٣) · شرح (٣٥٥) · رسم (٢٢٤) ·
#    تعريفات (١٣٢) · معادلات (١٠١) · تقويم (٨٦) · نشاط (٦٣) …
#
# 🎯 و«تقويم» أثمنُها: **أسئلةُ الكتاب عن نفسه** — أي ما يعدّه المنهجُ
#    جديراً بالسؤال. فما جاء منها يأخذ أعلى وزن.
IMPORTANCE_ANCHOR = """
⚖️ **وزنُ الأهمية (١..٥) — يُشتقّ من موضع المعلومة في الدرس لا من ذوقك:**

| الوزن | يأتي من |
|---|---|
| **٥** | ما سأل عنه الكتابُ نفسُه في «تقويم» أو «أسئلة» · التعريفُ الجوهريّ الذي يقوم عليه الدرس · القانونُ أو القاعدةُ الأساسية |
| **٤** | «تعريفات» و«قواعد» و«معادلات» و«نقاط_مهمة» المحورية · ما يتكرّر ذكرُه في الدرس أكثر من مرّة |
| **٣** | تفصيلٌ في «شرح» · مقارنةٌ في «جدول» · مثالٌ محلول |
| **٢** | تفصيلٌ ثانويّ · حالةٌ خاصّةٌ ذُكرت عرضاً |
| **١** | «معلومة_إثرائية» · «نشاط» · «مقدمة» · رقمٌ أو اسمٌ هامشيّ |

🔒 **والمعايرةُ إلزامية داخل الدرس الواحد** — الوزنُ مقارنةٌ لا حكمٌ مطلق:
   قرابةَ **خُمسِ الأسئلة وزنُها ٥**، وربعُها ٤، وثلثُها ٣، والباقي ١–٢.
   ⚠️ بنكٌ أوزانُه كلُّها ٤ و٥ **يُرفض كاملاً** ويُعاد — لأنه يعني أنك لم
      تميّز، وعلى هذا الوزن يقوم اختيارُ ما يُعرض للطالب.

🎚️ **والوزنُ مستقلٌّ عن الصعوبة استقلالاً تامّاً.** هذا نصُّ المالك:
   «سؤال تعريف… رغم إنه سهل، بس هذا يعتبر مهم». فـ:
   • تعريفٌ يُسأل مباشرةً  ⇒ `level: مبتدئ` و`weight: 5`  ✅ صحيحٌ ومطلوب
   • تطبيقٌ على حالةٍ هامشية ⇒ `level: صعب` و`weight: 2`  ✅ صحيحٌ ومطلوب
   ولا تجعل الوزنَ يتبع الصعوبة — فتضيع الفائدةُ كلُّها.
"""


# ══════════════════════════════════════════════════
# 📐 التغطية — «لكل نقطةٍ سؤال»
# ══════════════════════════════════════════════════
COVERAGE = """
📐 **التغطية — سؤالٌ لكل نقطةٍ في الدرس، لا عشرةُ أسئلةٍ عن نقطةٍ واحدة:**

1. **امسح الدرسَ جزءاً جزءاً** واستخرج نقاطَه القابلة للسؤال: كلُّ تعريفٍ ·
   كلُّ قانونٍ · كلُّ مقارنةٍ · كلُّ خطوةٍ في طريقةِ حلّ · كلُّ سببٍ ونتيجة.
2. **ثم وزّع الأسئلةَ على النقاط**، لا تتكدّس في أوّل الدرس ولا في آخره.
   ⚠️ الموديلاتُ تميل لاستنزاف الفقرات الأولى — **افحص نفسَك**: لو كان
      نصفُ أسئلتك من أوّل ثلث الدرس فقد أخطأت.
3. **ولا سؤالان متطابقان بصياغتين.** «ما تعريف كذا؟» و«كذا هو…؟» سؤالٌ
   واحد. نوّع في زاوية السؤال لا في ألفاظه.
4. `topic` = **النقطةُ نفسُها** بدقّةٍ واختصار («نصف قطر مدار بوهر»، لا «فيزياء
   الذرة»). عليه يقوم «تحليل مستواي» الذي يقول للطالب: ضعفُك في هذه النقطة —
   فإن كتبتَ اسمَ الدرس مكانه صار التحليلُ بلا معنى.
"""


# ══════════════════════════════════════════════════
# ☢️ الفخاخ — كلُّها وقعت فعلاً في بناءٍ سابق
# ══════════════════════════════════════════════════
TRAPS = r"""
☢️ **أخطاءٌ وقعت فعلاً في بناءاتٍ سابقة — لا تكرّرها:**

① **الشرطةُ المفردة داخل JSON تُفسد الترميزَ صامتةً.**
   `\frac` هي الهروبُ `\f` (محرف تحكّم) فيصل «␌rac{...}» إلى شاشة الطالب،
   و`\chem` هروبٌ **غير صالح** فيسقط ردُّك كلُّه. **ضاعِف كلَّ شرطة**:
   اكتب `\\frac` و`\\ring` و`\\chem` و`\\sqrt` و`\\sup` و`\\nuc`.

② **طيُّ الرسوم إلى كلام.** رُصد حيّاً: درسٌ فيه ٤٥ ترميزَ رسم فعاد الموديلُ
   بخمسة أسئلةٍ **بلا رسمةٍ واحدة**، كتب «ذرتا بروم في الموقعين ١ و٤ على
   حلقة البنزين» — وهي عينُ `\\ring{6|ar|+Br@1|+Br@4}`. إن كان في الدرس
   ترميزُ رسمٍ فالسؤالُ عنه **يعرض الرسم**، لا اسمَه.

③ **تحويلُ صورةِ القانون.** الكتابُ يكتب `\\frac{ق}{جـ} = ك` فيكتبها
   الموديلُ `ق = ك × جـ`. **مكافئٌ رياضياً وضائعٌ امتحانياً** — الطالبُ
   يُمتحن في صورة كتابه. انقل الصورةَ كما هي.

④ **اختراعُ صيغٍ ليست في الدرس.** رُصد: AlCl · BeF · CaSO — فُحص النصُّ
   فلا وجودَ لها. أي رمزٍ أو رقمٍ أو مصطلحٍ لا تجده في الدرس **لا يُكتب**.

⑤ **أرقامٌ فارسية** (۰۱۲۳۴۵۶۷۸۹) تتسرّب مكانَ العربية (٠١٢٣٤٥٦٧٨٩).
   وكذلك `π` تُكتب «باي» في المواد التي أرقامُها عربية.

⑥ **الخيارُ الصحيح أطولُ من إخوته** فيُكشف بلا فهم. الخادمُ يخلط المواقعَ
   بعدك، **لكنّ تقارُبَ الطول والصياغة والنوع مسؤوليتُك أنت**: أربعةُ
   خياراتٍ كلُّها أرقام، أو كلُّها عبارات، متقاربةُ الطول.

⑦ **المشتّتُ العشوائي** يجعل السؤالَ بلا قيمة. اجعل الخياراتِ الخاطئةَ من
   **داخل الدرس**: مصطلحٌ مجاور · خطوةٌ ناقصةٌ في الحل · خلطٌ شائعٌ بين
   مفهومين وردا في النص.

⑧ **السؤالُ عن شكلٍ أو صورةٍ أو رقم صفحة** — الطالبُ لا يراها في الاختبار.

⑨ **«كل ما سبق» و«لا شيء مما ذُكر»** ممنوعان قطعاً.

⑩ **النقصُ في العدد.** أعطِ العددَ المطلوب بالضبط — لا أقلّ.
"""


# ══════════════════════════════════════════════════
# 🧾 المخرَج
# ══════════════════════════════════════════════════
SCHEMA = r"""
📤 **أخرج JSON فقط** — بلا نصٍّ قبله أو بعده وبلا علامات ``` :

{"questions":[{
  "q":"نصّ السؤال",
  "options":["أ","ب","ج","د"],
  "correct_index":0,
  "topic":"النقطة الدقيقة التي يقيسها السؤال",
  "level":"مبتدئ",
  "weight":5,
  "kind":"تعريف",
  "why":"سطرٌ واحد: لماذا هذا هو الصواب، من الدرس نفسِه."
}]}

• `level` واحدةٌ من: مبتدئ · متوسط · صعب
  – **مبتدئ**: تذكّرٌ مباشر (تعريفٌ · مصطلحٌ · قانونٌ كما ورد).
  – **متوسط**: فهمٌ وربط (مقارنة · تعليل · «ماذا يحدث لو»).
  – **صعب**: تطبيق (مسألةٌ أو موقفٌ يُحلّ بخطوات الدرس).
• `weight` عددٌ صحيح ١..٥ حسب جدول الأهمية أعلاه.
• `kind` واحدةٌ من: تعريف · قانون · مقارنة · تعليل · تطبيق · حساب.
• `why` **سطرٌ واحدٌ قصير** يُري الطالبَ من أين جاء الصواب — لا فقرة.
  ⚠️ وهو ما يقرؤه بعد الاختبار في شاشة المراجعة، فاجعله مفيداً لا مكرّراً
     لنصّ الخيار.
"""


SYSTEM = """أنت معلّم {subject} خبيرٌ في وضع أسئلة الاختبارات للثانوية اليمنية،
وتبني الآن **بنكَ أسئلةٍ دائماً** لدرسٍ واحد — يُكتب مرّةً ويُقرأ آلافَ المرّات.

🎯 مهمتك: تحويلُ نصّ الدرس المرفق إلى **{count} سؤالَ اختيارٍ من متعدد**،
كلُّها **من داخل النصّ وحده**.

⛔ **المحظور قطعاً:**
1. سؤالٌ عن معلومةٍ **ليست في نصّ الدرس** — ولو كنتَ تعرفها وهي صحيحة.
2. اختراعُ أرقامٍ أو معادلاتٍ أو مصطلحاتٍ لم ترد في النص.
3. مخالفةُ لغة الدرس ومصطلحاته — الطالبُ يذاكر من هذا الكتاب حرفياً.
{coverage}
{importance}
{traps}
{schema}
عددُ الأسئلة المطلوب: **{count}** — لا أكثر ولا أقلّ."""


# ══════════════════════════════════════════════════
# 🧾 رسالةُ الطالب — وفيها **الحصصُ بالعدد**
# ══════════════════════════════════════════════════
#
# ☢️ **درسٌ تكرّر مرّتين** ([[prompt-spine]] · `common.turn_note`): النماذجُ
#    الصغيرة تطيع **رسالةَ المستخدم** أضعافَ ما تطيع برومبت النظام. وقِيس
#    هنا حيّاً (2026-09-16، أوّلُ تجربة): المواصفةُ في النظام تطلب خلطةً
#    وأوزاناً معايَرة، فعاد `gpt-4o-mini` بـ**اثني عشر سؤالاً كلُّها مبتدئة
#    وكلُّها بوزن ٥** — تجاهلاً تامّاً.
#
# ⇐ فالحصصُ نزلت إلى هنا **أعداداً تُعدّ** لا نسباً تُفهم، ومعها أمرٌ
#   بالترتيب كي يَعُدَّ الموديلُ نفسَه وهو يكتب.
USER = """نصّ الدرس المطلوب بناءُ بنكه:

━━━ الدرس: {lesson} ━━━
{lesson_text}

━━━━━━━━━━━━━━━━━━━━
اكتب الآن **{count} سؤالاً بالضبط** بصيغة JSON المطلوبة.

🔢 **حصصٌ إلزامية — عُدَّها قبل أن تُخرج:**

① **الصعوبة**: {easy} «مبتدئ» · {mid} «متوسط» · {hard} «صعب».
   واكتبها **بهذا الترتيب**: المبتدئةُ أولاً، ثم المتوسطة، ثم الصعبة.

   ☢️ **ووسمُ المستوى لا يكفي — يجب أن تكون صياغتُه هي صياغتَه:**
   • «مبتدئ»  ⇒ «ما تعريف…؟» · «أيُّ العناصر…؟» · «متى يُستعمل قانون…؟»
   • «متوسط»  ⇒ «ما الفرق بين… و…؟» · «لماذا يحدث…؟» · «أيُّها لا ينتمي…؟»
   • «صعب»    ⇒ **لا بدّ أن تحمل حساباً أو فرضاً أو استنتاجاً**:
     «إذا كان… فما…؟» · «احسب…» · «ماذا يحدث لـ… عند زيادة…؟» ·
     «استنتج من الجدول…» · «بكم يتغيّر… إذا…؟»
   🔴 **سؤالُ تذكّرٍ موسومٌ «صعب» يُرفض** — قِيس هذا فعلاً: «ما هي العناصر
      التي لها طيف خاص؟» جاءت موسومةً صعباً وهي تعريفٌ مباشر.
   ⚠️ وإن لم تجد في الدرس ما يكفي للصعب، فحوّل مثالاً محلولاً إلى مسألةٍ
      بأرقامٍ مشابهة تُحلّ بالطريقة نفسِها — ولا تُخرج بنكاً بلا صعب.

② **الأوزان**: {w5} سؤالاً بوزن ٥ · {w4} بوزن ٤ · {w3} بوزن ٣ ·
   {w12} سؤالاً بوزن ١ أو ٢.
   ⚠️ **الوزنُ مقارنةٌ داخل هذا الدرس لا مجاملة**: لو أعطيتَ الجميعَ ٥ فقد
      قلتَ «كلُّ شيءٍ سواء» — وعلى هذا الوزن يُبنى اختيارُ ما يراه الطالب،
      فيصير الاختيارُ عشوائياً. والدرسُ فيه هوامشُ قطعاً: أعطِها ١ أو ٢.

③ **التغطية**: وزّعها على الدرس من أوّله إلى آخره — لا تتكدّس في أوّله.

   ☢️ **و`topic` هو النقطةُ الدقيقة، لا عنوانُ القسم.** هذا خطأٌ وقع فعلاً:
   ❌ ستّةُ أسئلةٍ مختلفة كلُّها بـ`topic`: «حساب طاقة الكم»
   ✅ والصواب أن لكلٍّ منها نقطتَها:
      «ثابت بلانك» · «العلاقة بين طاقة الكم والتردد» ·
      «العلاقة بين التردد والطول الموجي» · «حساب طاقة كمٍّ من تردد» ·
      «أثر رفع الحرارة على الطاقة المشعّة»
   🎯 اسأل نفسَك: **لو أخطأ الطالبُ في هذا السؤال، ماذا أقول له بالضبط إنه
      ضعيفٌ فيه؟** ذاك هو `topic` — وعليه تُبنى شاشةُ «تحتاج تركيزاً في».
   ⚠️ ولا تكرّر نفسَ `topic` لأكثر من سؤالين.
   • ولا يبدأ أكثرُ من نصفِ أسئلتك بـ«ما هو…؟» — نوّع **زاويةَ** السؤال.

⛔ ولا تكتب «كل ما سبق» ولا «لا شيء مما ذُكر» في أي خيار."""


# ══════════════════════════════════════════════════
# 🖌️ حصّةُ الترميز — عدداً، لا رجاءً
# ══════════════════════════════════════════════════
# ☢️ **ثامنُ مرّةٍ يكون المقياسُ فيها أدقَّ من الطلب.** قِيس (2026-09-17)
#    في فيزياء الثاني: درس «الحركة الموجية» فيه ٣١ ترميزاً فعاد الموديلُ
#    بـ٢٦ سؤالاً **بلا ترميزٍ واحد**، ومثلُه «الحركة الاهتزازية» و«توازن
#    جسمٍ صلب». والتذكيرُ موجودٌ أصلاً في [subjects.common.draw_reminder]
#    وفي فخّ ② أعلاه — **لكنه شرطيّ**: «انقلها حيثما ذكرتَ ما تمثّله»،
#    فالموديلُ يمتثل بألّا يذكرها أصلاً.
#
# ⚖️ **وهذا عينُ علّةِ الأوزان والصعوبة، وعلاجُه عينُ علاجها:** ما يُعَدّ
#    في رسالة المستخدم يُمتثَل، وما يُوصَف في البرومبت يُطوى. فتصير
#    حصّةً مرقّمة — **ومن نفس الدالّة التي يقيس بها الفحص**، كي لا أطلب
#    رقماً وأحاسب على غيره.
def real_codes(source: str) -> list:
    """ترميزاتُ الدرس الحقيقية — بلا خطوات التعويض العددية.

    ⚖️ `\\frac{٣}{٢}` خطوةُ حسابٍ في مثالٍ محلول، أما `\\frac{ع^2}{نق}`
       فقانونٌ يُرسم مكدّساً كما في الكتاب ([[markdown-render-traps]]).
    """
    from tools.build_explanations import DRAW, _norm_codes, _is_numeric_substitution
    return [c for c in DRAW.findall(_norm_codes(source or ""))
            if not _is_numeric_substitution(c)]


def notation_quota(source: str, need_factor: int = 8) -> tuple:
    """(كم سؤالاً يجب أن يحمل ترميزاً، وعيّنةٌ منه) — أو (0, []) إن لم يلزم."""
    codes = real_codes(source)
    if len(codes) < 6:
        return 0, []
    seen, sample = set(), []
    for c in codes:
        if c not in seen:
            seen.add(c)
            sample.append(c)
        if len(sample) == 3:
            break
    return min(3, len(codes) // need_factor + 1), sample


def notation_clause(source: str, need_factor: int = 8) -> str:
    need, sample = notation_quota(source, need_factor)
    if not need:
        return ""
    shown = " · ".join("`" + c.replace("\\", "\\\\") + "`" for c in sample)
    return ("\n\n④ **الترميز**: لا يقلُّ عن **" + str(need) + "** من أسئلتك عن "
            "شيءٍ مرموزٍ في الدرس، و**تعرض ترميزَه** في نصّ السؤال أو في "
            "خياراته — لا اسمَه ولا وصفَه.\n"
            "   • مأخوذٌ من هذا الدرس بعينه: " + shown + "\n"
            "   • مثالٌ على الصياغة: «أيُّ العلاقات تمثّل …؟» وخياراتُها "
            "ترميزاتٌ متنافسة، أو «ما الناتج من …؟» ونصُّه يحمل الترميز.\n"
            "   ⚠️ وداخل JSON تُضاعَف كلُّ شرطة.")


def system_prompt(subject: str, count: int) -> str:
    from subjects.common import render_rules
    body = SYSTEM.format(subject=subject, count=count, coverage=COVERAGE,
                         importance=IMPORTANCE_ANCHOR, traps=TRAPS, schema=SCHEMA)
    # 🖌️ قواعدُ رسّام المادة تُلحق كما في الشرح — فلا تُرسم الحلقةُ هناك
    #    ويأتي سؤالُها هنا اسماً مجرّداً ([quiz_prompt]).
    return body + render_rules(subject) + (
        "\n⚠️ **وكلُّ ترميزٍ في القواعد أعلاه يُكتب داخل JSON بشرطةٍ "
        "مضاعفة**: `\\\\frac` و`\\\\ring` و`\\\\sqrt`.\n")


def weight_quota(count: int) -> tuple:
    """حصصُ الأوزان بالعدد — ٢٠٪ خمسة · ٢٥٪ أربعة · ٣٠٪ ثلاثة · الباقي ١–٢."""
    w5 = max(1, round(count * 0.20))
    w4 = max(1, round(count * 0.25))
    w3 = max(1, round(count * 0.30))
    w12 = max(1, count - w5 - w4 - w3)
    return w5, w4, w3, w12


# ══════════════════════════════════════════════════
# 🇬🇧 عدسةُ الإنجليزية — **تمرينٌ لا تعريف**
# ══════════════════════════════════════════════════
# 🔴 **ما رآه المالك (2026-09-17):** «الإنجليزي عبارة عن أمثلة… أوجد
#    الـ passive لهذا، أوجد لهذا. حتى القطعة أعطه قطعة خفيفة وأعطه أمثلة.
#    مو تقول له إيش كيف نختار القطعة — هذا ممتاز بس قلّل منه».
#
# 📏 **والقياسُ صدّقه**: بنكُ ٣ علمي (٢٩٧ سؤالاً) كان **كلُّه تعريفاتٍ
#    بالعربية عن الإنجليزية**: «ما تعريف المبني للمجهول؟» · «ما الفرق بين
#    was وwere؟» · «متى نستخدم is؟». ولا سؤالَ واحدٌ يطلب من الطالب أن
#    **يفعل** شيئاً بالإنجليزية — وهي مادّةُ أداءٍ لا مادّةُ حفظ.
#
# ⚖️ **ولماذا حصّةٌ بالعدد لا قاعدةٌ في النظام؟** لأن هذا هو الدرسُ
#    المتكرّر في المشروع ([[prompt-spine]]): النماذجُ الصغيرة تطيع ما
#    يُعَدّ في رسالة المستخدم وتطوي ما يُوصَف في برومبت النظام — كما وقع
#    في الأوزان والصعوبة وحصّة الترميز.
ENGLISH_SUBJECTS = frozenset({"انجليزي", "إنجليزي", "english"})


def is_english(subject: str) -> bool:
    return (subject or "").strip().lower() in ENGLISH_SUBJECTS


# 📖 **والقطعةُ لدرسها وحدَه** — وهذا حدٌّ صحّحتُه بعد أن طلبتُها من كل
#    درس: «Match to make compound words» تمرينُ مفرداتٍ، وحشوُ قطعةٍ فيه
#    تكلّفٌ لا تعليم. وأمرُ المالك كان عن **درس القطعة**: «حتى القطعة
#    أعطه قطعة خفيفة وأعطه أمثلة».
_PASSAGE_LESSON = re.compile(
    r"القطعة|قطعة|paragraph|Reading|read the|comprehension", re.I)


def wants_passage(lesson: str) -> bool:
    return bool(_PASSAGE_LESSON.search(lesson or ""))


def english_quota(count: int, lesson: str = "") -> tuple:
    """(تطبيقيّ، قطعة، تعريفيّ) — البنكُ كلُّه تمرينٌ إلا أربعةً.

    ⚖️ **والطلبُ فوق العتبة عمداً، وهذا مقصودٌ لا تناقض.** العتبةُ في
       [build_quizzes.english_defects] ستّون بالمئة — وهي **أرضيةُ رفض**؛
       وهذا الرقمُ **هدفٌ** يُكتب في رسالة المستخدم. وقِيس (2026-09-18):
       حين طلبتُ ٦٥٪ عاد الموديلُ بـ٥٠–٥٥٪ فسقطت عشرةُ دروس، وحين طُلب
       «كلُّها إلا أربعة» استقرّ فوق الأرضية. والمالكُ يريد الأكثر:
       «الإنجليزي عبارة عن أمثلة… كثّر من الأمثلة».
    """
    applied = max(2, count - 4)
    passage = (1 if count < 10 else 2) if wants_passage(lesson) else 0
    return applied, passage, min(2, count - applied)


def english_clause(count: int, lesson: str = "") -> str:
    applied, passage, defs = english_quota(count, lesson)
    passage_rule = f"""

⑤ **Reading**: **{passage}** question(s) built on a **short passage you write
   yourself inside `q`** — two or three lines in the lesson's own English —
   then ask about its meaning or about one word in it.
   🔴 **Every question stands alone.** The student is shown ONE question at
      a time, so a question that says "According to the passage…" without
      carrying the passage is unanswerable. **Write the passage inside
      `q`, in quotation marks, in every question that asks about it.**
   ✅ q: "Read: *The lungs take in oxygen from the air and pass it to the
          blood. The blood then carries it to every cell in the body.*
          What do the lungs pass to the blood?\"
   ❌ q: "What do we need for breathing?"  ← no passage, nothing to read.""" \
        if passage else ""
    spare = count - applied
    return f"""

━━━━━━━━━━━━━━━━━━━━
🇬🇧 **THIS SUBJECT IS WRITTEN ENTIRELY IN ENGLISH — owner's order (2026-09-18):**

⓪ **`q`, the four `options`, `why` and `topic` are written in ENGLISH.
   NOT ONE ARABIC WORD in any of them.** The student is being tested *in*
   English, not *about* English in Arabic.
   ❌ q: "ما تعريف البادئة (Prefix)؟"
      options: ["مجموعة حروف تُضاف في بداية الكلمة", …]
      why: "البادئة هي مجموعة حروف تُضاف في بداية الكلمة."
   ✅ q: "What is a prefix?"
      options: ["A group of letters added to the beginning of a word to
                 change its meaning",
                "A group of letters added to the end of a word to change
                 its part of speech",
                "A word that joins two sentences together",
                "The base form of a word before any ending is added"]
      why: "A prefix is added at the beginning of a word and changes its
            meaning, as in un- + usual = unusual."
   ⚠️ `level` and `kind` keep their Arabic values — they are system labels
      the student never reads. Everything the student reads is English.

④ **Practice, not talk about practice — {applied} questions AT LEAST,
   count them before you answer.** A practice question has **two parts**:
   an **instruction** and **the material it works on**, written out in full
   inside `q`. A bare question with nothing to work on is NOT practice.
   🔴 ❌ "What are they teaching?"          ← nothing to work on
   🔴 ❌ "How often did they play football?" ← nothing to work on
   ✅ "Make a question for the underlined word: *They are teaching
       **English**.*"
   ✅ "Change into the passive: *They built the school in 1990.*"
       options: ["The school was built in 1990.",
                 "The school is built in 1990.",
                 "The school has built in 1990.",
                 "The school were built in 1990."]
   ✅ "Choose the correct form: He ____ (go) to school every day."
   ✅ "Correct the mistake: *She don't like fish.*"
   ✅ "Re-order to make a sentence: *school / to / walks / he / every /
       day*"
   🤖 **This is checked by a machine, so here is exactly what it looks
      for.** A question counts as practice only if its `q` contains ONE of
      these three, literally:
      • a sentence between asterisks — `*They built the school in 1990.*`
      • a blank made of underscores or dots — `He ____ (go) to school.`
      • a list of words separated by slashes — `wool / metal / fur / skin`
      A question with none of the three does **not** count, however good it
      is. You are allowed **{spare}** such questions in the whole bank; the
      other **{applied}** must each carry one.
      ❌ "Which two words make the compound word 'newspaper'?"  ← none
      ✅ "Which two words make one compound word? *news / paper / quickly*"
      ❌ "What does the prefix 're-' mean?"                      ← none
      ✅ "Complete: *He had to ____ write the letter.* (re- / un- / -ful)"
      ❌ "When do we use 'because'?"                             ← none
      ✅ "Choose the linking word: *He was punished ____ he lied.*"
   ✏️ **When you ask about ONE word, put that word between double
      underscores** so the student can see which word you mean — the app
      draws it underlined.
      ❌ "What is the part of speech of the underlined word?
          *Ali went for a ride on his bicycle.*"   ← nothing is underlined,
          so the question has no answer.
      ✅ "What is the part of speech of the underlined word?
          *Ali went for a __ride__ on his bicycle.*"
      ✅ "Make a question for the underlined words:
          *He comes to school __by bus__.*"
      The same goes for any question whose answer depends on one word or
      phrase inside the sentence.

   🔓 **Permission you need, and it overrides trap ④ above**: the *word,
      rule or structure* you test must come from the lesson — but the
      **sentence you put it in may be written by you**, in simple school
      English, even when the lesson is only a word list with no sentences.
      Writing "*She was ____ and forgot her keys.* (care + less)" for a
      lesson whose text only lists `careless` is exactly what is wanted.

   📐 **The shape to copy**: `<Instruction>: *<a full English sentence>*`
   — an instruction verb, a colon, then a real sentence between asterisks
   or a blank `____` inside the sentence. Take the sentences from the
   lesson itself, or write ones just like them.
   ⚠️ Only **{defs} + a few** of your questions may be without material;
   everything else carries its own sentence.
{passage_rule}

③ **What "صعب" means in this subject**: not a calculation — a
   **transformation in more than one step**. Passive with a modal
   ("They must clean the room." → "The room must be cleaned."), a question
   made from a complex sentence, a word changed from one part of speech to
   another, a meaning inferred from a passage. Keep the required number of
   صعب questions, and make each one an exercise of that kind.

❌ **And never ask about the instructions themselves.** These are questions
   about the exercise page, not about English — they teach nothing:
   ❌ "What is the first rule for completing the paragraph?"
   ❌ "What is the formula for creating a compound word?"
   ✅ "Complete: *Fareeda is ____ and gets on well with people.*"
   ✅ "Which two words make one compound word? *class / room / table*"

⑥ **Definitions: at most {defs}** — "What is …?" and "What is the
   difference between … and …?" are useful but few. Even these are written
   **in English**, question and options and `why` alike.

✍️ **Write like an English exam paper**: the instruction line is English
   ("Choose the correct answer", "Complete the sentence"), the example
   sentences are English, and the explanation the student reads after the
   test is English. Use normal Latin digits (1990, not ١٩٩٠)."""


# ══════════════════════════════════════════════════
# 🧮 عدسةُ الحساب — **الجوابُ يُحسب قبل أن يُكتب**
# ══════════════════════════════════════════════════
# 📏 قِيس (2026-09-17): بنكُ المنطق فيه ≈٤٤ خطأً حسابياً في ٥ دروس —
#    ومنها «⌋(٣+٣)» جوابُها «٩» وتعليلُها يقول «٧٢٠». والموديلُ يكتب
#    الخياراتِ أوّلاً ثم يختار، فيقع السهو. فالأمرُ: **احسب ثم اكتب**.
CALC_SUBJECTS = frozenset({"رياضيات", "منطق"})


def is_calc(subject: str) -> bool:
    return (subject or "").strip() in CALC_SUBJECTS


CALC_CLAUSE = """

━━━━━━━━━━━━━━━━━━━━
🧮 **وهذه مادّةُ حساب — الجوابُ فيها يُصحَّح أو يُخطَّأ، ولا يُستحسن:**

⑦ **احسب قبل أن تكتب**: لكلِّ سؤالٍ جوابُه عدد، **نفّذ العمليةَ كاملةً
   خطوةً خطوة في `why`** ثم اجعل `correct_index` يشير إلى ناتجها بعينه.
   ✅ «\\comb{٦}{٢} = \\frac{٦ × ٥}{٢ × ١} = ١٥» ⇐ والخيارُ الصحيح «١٥».
   🔴 **ولا يجوز أن يخالف تعليلُك جوابَك** — هذا وقع فعلاً: سؤالٌ تعليلُه
      «\\fact{٦} = ٧٢٠» وجوابُه الموسوم «٩»، ولا ٧٢٠ في خياراته أصلاً.

⑧ **والناتجُ الصحيح يجب أن يكون بين الخيارات الأربعة** — والمشتّتاتُ
   أخطاءٌ شائعةٌ محسوبة (نسيانُ القسمة على \\fact{ر} · استعمالُ التباديل
   مكانَ التوافيق)، لا أعداداً عشوائية.

⑨ **ومدى الأعداد**: \\perm{٧}{٤} = ٨٤٠ و\\fact{٦} = ٧٢٠ — أعدادٌ كبيرة.
   فإن خرجت خياراتُك كلُّها أصغرَ من عشرة وسؤالُك تباديلُ سبعةٍ، فقد أخطأت."""


def user_prompt(lesson: str, lesson_text: str, count: int,
                need_factor: int = 8, subject: str = "") -> str:
    from core.quiz_bank import target_mix
    from subjects.common import draw_reminder
    easy, mid, hard = target_mix(count)
    w5, w4, w3, w12 = weight_quota(count)
    tail = draw_reminder(lesson_text)
    if tail:
        tail += ("\n⚠️ وداخل JSON تُضاعَف الشرطة: اكتب "
                 "`\\\\ring{6|ar}` لا `\\ring{6|ar}`.")
    # 🖌️ والحصّةُ بعدَ التذكير: ذاك يقول «انقلها إن ذكرتَها»، وهذه تقول
    #    «واذكرها كذا مرّة» — وبالعدد الذي يقيسه الفحصُ نفسُه.
    tail += notation_clause(lesson_text, need_factor)
    # 🇬🇧 وعدسةُ الإنجليزية — تمرينٌ لا تعريف (طلبُ المالك 2026-09-17).
    tail += english_clause(count, lesson) if is_english(subject) else ""
    # 🧮 وعدسةُ الحساب — للرياضيات والمنطق.
    tail += CALC_CLAUSE if is_calc(subject) else ""
    return USER.format(lesson=lesson, lesson_text=lesson_text, count=count,
                       easy=easy, mid=mid, hard=hard,
                       w5=w5, w4=w4, w3=w3, w12=w12) + tail


# ══════════════════════════════════════════════════
# 🔁 التصحيح — نداءٌ ثانٍ يعرف ما نقص
# ══════════════════════════════════════════════════
# 🎯 **درسٌ مدفوعُ الثمن** ([[lesson-explanation-cache]]): سبعون نداءً أعطت
#    خمسةَ دروسٍ حين كنتُ أُعيد **نفسَ الطلب** بعد السقوط. والنموذجُ لا
#    يُصلح ما لا يعرف أنه أخطأ فيه — **أخبِره**.
def retry_prompt(defects: list, count: int) -> str:
    lines = "\n".join(f"• {d}" for d in defects[:10])
    return (f"⚠️ بنكُك السابق لم يجتز الفحص. العيوبُ بعينها:\n{lines}\n\n"
            f"أعد كتابة **{count} سؤالاً** كاملةً بصيغة JSON نفسِها، "
            "مُصلِحاً ما ذُكر أعلاه ومُبقياً ما كان سليماً.")


JSON_HINT = ("⚠️ ردُّك لم يكن JSON صالحاً. أعد الإخراج **JSON فقط** بلا أي "
             "شرحٍ ولا علامات ``` ولا نصٍّ خارج الأقواس.")

# ══════════════════════════════════════════════════
# ➕ سدُّ النقص — سؤالٌ واحدٌ لا بنكٌ كامل
# ══════════════════════════════════════════════════
# ⚖️ **بنكٌ من ٣٢ سؤالاً يُرفض لأنه حمل ترميزين لا ثلاثة.** وإعادةُ بنائه
#    كلِّه تحرق أربعةَ نداءات وتعود بأسوأ منه (قِيس أربعَ مرّات في
#    «العدسات الرقيقة» و«الطلب»). والنقصُ **سؤالٌ واحدٌ بعينه** — فيُطلب
#    وحدَه بنداءٍ واحد، ويُضمّ إن صحّ. وهذا عينُ ما أمر به المالك:
#    «إذا فيها أشياء واحدة وتقدر تعدلها، عدّلها أنت».
def topup_prompt(lesson: str, lesson_text: str, need: int,
                 existing: list, source: str) -> str:
    _n, sample = notation_quota(source)
    shown = " · ".join("`" + c.replace("\\", "\\\\") + "`" for c in sample)
    have = "\n".join(f"• {q}" for q in existing[:18])
    return (f"الدرس: «{lesson}»\n\n{lesson_text}\n\n"
            "━━━━━━━━━━━━━━━━━━━━\n"
            f"اكتب **{need} سؤالاً فقط** بصيغة JSON نفسِها، وشرطُها الوحيد "
            "أنّ **نصَّ السؤال أو أحدَ خياراته يعرض ترميزاً منقولاً من "
            "الدرس حرفاً بحرف** — لا اسمَ القانون ولا وصفَه.\n"
            f"   • من ترميزات هذا الدرس: {shown}\n"
            "   • صيغةٌ مقترحة: «أيُّ العلاقات تمثّل …؟» وخياراتُها "
            "ترميزاتٌ متنافسة، أو «ما قيمة … إذا …؟» ونصُّه يحمل الترميز.\n"
            "   ⚠️ وداخل JSON تُضاعَف كلُّ شرطة: `\\\\frac`.\n\n"
            f"🚫 ولا تكرّر أياً من هذه الأسئلة الموجودة:\n{have}")

# ➕ **ونقصُ العدد يُسدُّ كذلك بنداءٍ واحد.** درسُ «تقويم الوحدة» في فيزياء
#    الثاني أعطى ١٤ سؤالاً والأرضيةُ ١٦ — وإعادةُ بنائه كاملاً أربعَ مرّاتٍ
#    عادت بـ١٢ و١٣ و١٤. والمطلوبُ **سؤالان**، فيُطلبان وحدَهما ومعهما
#    قائمةُ ما كُتب كي لا يُكرَّر.
def topup_count_prompt(lesson: str, lesson_text: str, need: int,
                       existing: list) -> str:
    have = "\n".join(f"• {q}" for q in existing[:24])
    return (f"الدرس: «{lesson}»\n\n{lesson_text}\n\n"
            "━━━━━━━━━━━━━━━━━━━━\n"
            f"اكتب **{need} سؤالاً إضافياً فقط** بصيغة JSON نفسِها، عن نقاطٍ "
            "في الدرس **لم تُسأل بعد**.\n"
            "   • نوّع الزاوية: مقارنةٌ · تعليلٌ · تطبيقٌ حسابيّ · «أيُّها لا "
            "ينتمي» — لا «ما هو…؟» وحدَها.\n"
            "   • ولا تُحِل إلى شكلٍ ولا صفحةٍ ولا رقمِ سؤالٍ في الكتاب: "
            "الطالبُ لا يرى الكتابَ أمامه.\n"
            "   • وإن كان الدرسُ تماريناً بفراغات، فحوّل الفراغَ إلى سؤالٍ "
            "قائمٍ بنفسِه بأربعة خيارات.\n\n"
            f"🚫 ولا تكرّر أياً من هذه:\n{have}")
