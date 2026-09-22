# subjects/math.py
"""
قسم الرياضيات - بدون أخطاء
"""

from core import lesson_cache
# 🎯 اسمُ نموذج الرياضيات من مصدرٍ واحد — كان مكتوباً بيده في أربعة مواضع،
#    فتغييرُه عند سحب المزوّد للنموذج كان يحتاج تعديلَ أربعة أسطر وتذكُّرَها.
from core.curriculum import model_route as _route, subject_thinking
MATH_MODEL, MATH_THINK = _route("رياضيات")[1], subject_thinking("رياضيات", "quiz")

# ☢️ **`deepseek-v4-pro` نموذجُ تفكير — وسقفُ ٤٠٠٠ كان يقتله صامتاً.**
#
# 🔴 قِيس (2026-09-15): بسقف ٤٠٠٠ ينفق **٤٠٠٠ توكن كلَّها على التفكير**
#    ويعيد **صفرَ حروف** و`finish_reason="length"` — أي جواباً فارغاً بلا
#    خطأٍ ولا سجلّ. وبسقف ١٢٠٠٠ يفكّر ٤٣٢٨ ثم يكتب ٣٢٦٠ حرفاً من شرحٍ سليم.
#
# ⚖️ فالسقفُ هنا **ليس طولَ الجواب** بل «تفكيرٌ + جواب»، ولذلك يفارق
#    ٤٠٠٠ المعتمدة في بقية المواد (نماذجُها بلا تفكير). والمهلةُ معه ١٢٠
#    لا ٥٠: القياسُ أعطى ٤٧ث لدرسٍ متوسّط، وخمسون كانت على حافّة السقوط.
MATH_MAX_TOKENS = 12000
MATH_TIMEOUT = 120.0
from .common import (
    turn_note,
    FOLLOWUP_RULES, CONVERSATION_RULES, CONTINUITY_RULES, subject_lens,
    ANSWER_SHAPE_RULES,
    SUPPORT_EXAMPLE_RULES,
    subject_book_path, load_json_safe, extract_all_texts_and_metas,
    enhanced_qa_search, faiss_search, filter_and_rank_exams,
    collect_exam_questions_by_years, normalize_text_match,
    normalize_lesson_name, get_math_exam_years, get_math_exam_lessons,
    get_math_exam_questions, load_math_lesson,format_arabic_math
)
from config import BASE_SUBJECTS_DIR, QA_TOP_K, EXAMS_BATCH_SIZE, HISTORY_LAST_N
from models import AskRequest
from typing import Dict, Any, List, Optional
import json
import os
import re
import asyncio

from core import streaming
from core.fractions import to_frac
from core import latex_guard as _latex_guard
from core import latex_guard
from core.roots import to_sqrt
from core.factorial import to_factorial
from core import arabic_digits
from core import steps_format
import time





# =====================
# ثوابت المادة
# =====================
SUBJECT = "رياضيات"
sessions_math = {}


_session_timestamps = {}

# ══════════════════════════════════════════════════════════════════
# 📐 تعليماتُ الترميز — **نصٌّ واحد يُنادى من كل برومبت**
# ══════════════════════════════════════════════════════════════════
# 🔴 كانت هذه الفقرة **مكرّرةً خمس مرات** ولا تذكر إلا الكسور، فبقي
#    الموديل يكتب «ن!» و«ل(ن، ر)» بالإنجليزية ويُصلحها الخادمُ بعدَه.
#    والمالك طلب أن **يعرف الموديلُ الآليةَ نفسها** — فوُحّدت هنا، وكلُّ
#    رمزٍ جديد يُضاف في مكانٍ واحد ويصل البرومبتات الخمسة معاً.
#
# ⚖️ والخادم يبقى يحوّل نصَّ الكتاب على كل حال (`core/*.py`)، فالتعليمة
#    تحسينٌ لا اعتمادٌ: إن أخطأ الموديل صحّحه `_finish`.
MARKUP_RULES = (
    "- ✅ استثناء وحيد من منع الرموز الإنجليزية: **ترميز الرسم**. اكتبه كما يلي حرفياً:\n"
    "  • الكسر: \\frac{البسط}{المقام} — لا «/» ولا «÷». مثال: \\frac{لو أ}{لو ب}\n"
    "  • الجذر: \\sqrt{المقدار} والتكعيبي \\sqrt[3]{المقدار} — لا كلمة «جذر» ولا «√».\n"
    "  • المضروب: \\fact{المقدار} — لا «!». مثال: \\fact{ن} و\\fact{ن-١}.\n"
    "  • التباديل: \\perm{ن}{ر} — لا «ل(ن، ر)» ولا «ن ل ر».\n"
    "  • التوافيق: \\comb{ن}{ر} — لا «(ن ق ر)».\n"
    # ⁿ ₙ **والأُسُّ ودليلُه**: الخادم يردّ «^» و«_» إليهما بعد الجواب
    #    (`to_power` و`to_sub`)، وذكرُهما هنا يوفّر الردَّ ويوحّد الشكل.
    "  • الأُسّ: \\sup{المقدار} — لا «^». مثال: س\\sup{٢} و١٠\\sup{-٣}.\n"
    "  • الدليل المنخفض: \\sub{المقدار} — لا «_». مثال: م\\sub{ط} وع\\sub{١}.\n"
    "  ولا تكتب أيَّ أمرٍ آخر يبدأ بشرطةٍ مائلة.\n"
)

def cleanup_old_sessions():
    now = time.time()
    expired = [
        uid for uid, ts in _session_timestamps.items()
        if now - ts > 1800
    ]
    for uid in expired:
        sessions_math.pop(uid, None)
        _session_timestamps.pop(uid, None)
    if expired:
        print(f"🧹 حذفت {len(expired)} session منتهية")
        
        
        
# =====================
# برومبتات خاصة بالرياضيات
# =====================
def format_lesson_safely(data, level=0):
    """
    هذه الدالة تفكك أي درس مهما كان معقداً إلى نص عربي نقي
    بدون ضياع أي معلومة، مما يخفف التوكنز بنسبة 40% ويسرع الموديل.

    🔴 **ثغرة كشفها مسحٌ لكل دروس الرياضيات (2026-09-09):** ٢٤ درساً من ٦٤
       كان شرحُها يخرج بشرطة القسمة لا بالكسر المرسوم — «دص/دس» · «س² / أ²» ·
       «س³ / ٣». والسبب ليس البرومبت: البرومبت يأمر بالنقل **حرفياً من
       الدرس**، ونصُّ الكتاب مكتوب بالشرطة، فالموديل ينقلها بأمانة — أي أنه
       **يطيعنا**، ولا ينفع تشديد الأمر.

    ⭐ والعلاج أن نُصلح نصّ الكتاب **قبل أن يراه الموديل** ([core/fractions.py]).
       وكانت `fractions.to_frac` موصولةً بأربعة منافذ ([arabic-math-fractions])
       — و**هذا المنفذ ليس أحدها**، مع أنه مسار «ابدأ الشرح الذكي» وهو أكثر
       ما يُستعمل في الرياضيات.
    """
    text = _build_lesson_text(data, level)
    if level != 0:
        return text

    # 🛡️ حارس اللاتيك على **نصّ الكتاب** لا على جواب الموديل وحده.
    #
    # 🔴 كان مسار عرض الدرس («وضع الوحدات» و«ابدأ الشرح الذكي») يخرج بلا
    #    حارس، فوصل الطالبَ حرفٌ لاتينيّ مكانَ رمزٍ رياضيّ من الملفّ نفسه:
    #    «]-∞، ٢[ U ]٢، ∞[» و«التركيب (ق o د)» — ١١ درساً من ٦٤.
    #
    # ⭐ وموضعُه هنا يحرس **كل درسٍ يُضاف لاحقاً** بلا مراجعةٍ يدوية، ويحرس
    #    الموديل معه: البرومبت يأمره بالنقل حرفياً، فما نُصلحه قبل أن يراه
    #    يُنقل مصلَحاً ([adding-subject-content]).
    text = latex_guard.clean(text)

    # √ والجذر يُرسم لا يُكتب كلمةً — **قبل أن يراه الموديل** فينقله مرسوماً.
    text = to_sqrt(text, "رياضيات")
    text = to_factorial(text, "رياضيات")

    # ٠١٢ وأرقام الكتاب عربية — **قبل أن يراها الموديل**، فالبرومبت يأمره
    #     بالنقل حرفياً فينقلها عربيةً من تلقائه، ولا يبقى للفلتر إلا الشوارد.
    text = arabic_digits.to_arabic(text)

    # 🔢 التحويل مرة واحدة على النصّ المكتمل لا على كل ورقة: `to_frac` تقرأ
    #    ما حول الشرطة لتميّز الكسر من الوحدة ومن «أو» العربية، فتقطيعُ
    #    النصّ يحرمها ذلك السياق.
    return to_frac(text)


def _build_lesson_text(data, level=0):
    """التفكيك الخام — بلا تحويل كسور (يقع مرةً واحدة في الأعلى)."""
    text = ""
    indent = "  " * level
    if isinstance(data, dict):
        for k, v in data.items():
            if isinstance(v, (dict, list)):
                text += f"{indent}▪️ {k}:\n" + _build_lesson_text(v, level + 1)
            else:
                text += f"{indent}▪️ {k}: {v}\n"
    elif isinstance(data, list):
        for item in data:
            if isinstance(item, (dict, list)):
                text += _build_lesson_text(item, level + 1) + "\n"
            else:
                text += f"{indent}- {item}\n"
    else:
        text += f"{indent}{data}\n"
    return text.strip()


def _finalize(text: str) -> str:
    """آخر ما يمرّ به جوابُ الرياضيات قبل الطالب.

    🔴 **والأرقام بالعربية قرارُ المالك (2026-09-09):** الكتاب اليمني يكتب
       ٠١٢٣، فخروجُ الجواب بـ0123 يجعله غريباً عن الصفحة التي بين يدَي
       الطالب. وهي [ضمانة] لا رجاء — راجع [core/arabic_digits.py].
    """
    return steps_format.space_steps(
        arabic_digits.to_arabic(format_arabic_math(text, "رياضيات")))


def system_prompt_math_explain():
    """برومبت شرح الرياضيات"""
    return (
        "أنت مدرس رياضيات تشرح من ملخص الطالب فقط.\n"
        # 🗣️ **قواعدُ المتابعة والمحادثة والاتّصال من مصدرها الواحد**
        #    (2026-09-14). كان هنا أربعةُ أسطرٍ تقول «إذا سألك عن نقطة في
        #    الشرح السابق استخدم السياق» — وهي لا تمنع إعادةَ شرح ما شُرح،
        #    ولا تُعرّف طلبَ المتابعة، ولا تمنع التحيةَ المكرّرة. وهي نفسُ
        #    العلّة التي عولجت في بقية المواد، فلا تُكتب هنا مرّةً خامسة.
        #
        # ⚠️ **ولا `source_rules` هنا عمداً**: تمنع «مثالاً ليس في النص»،
        #    والرياضياتُ تُحلّ فيها المسألةُ المشابهة بأرقامٍ أخرى بنفس خطوات
        #    الدرس — وهذا مطلوبٌ صراحةً في هذا البرومبت أدناه. فقيدُ المصدر
        #    في الرياضيات هو **طريقةُ الحل وقوانينُ الدرس**، لا نصُّه حرفاً.
        + FOLLOWUP_RULES
        + CONVERSATION_RULES
        + CONTINUITY_RULES
        # 🪄 والتقريبُ المسموح يُلحق صراحةً هنا: الرياضياتُ لا تمرّ بـ
        #    `source_rules` (انظر أعلاه)، فكان استثناءُ التشبيه يسقط عنها
        #    وحدها بينما طلبه المالك **في كل المواد**.
        + SUPPORT_EXAMPLE_RULES
        # 🚫 **وشكلُ الجواب معها** — ومنه ضبطُ الافتتاح: الرياضياتُ كانت
        #    المادةَ الوحيدة خارج `ANSWER_SHAPE_RULES`، فعادت تفتح بـ«أهلاً
        #    بك، سأشرح لك…» بعد أن نُظّف الافتتاحُ في المواد كلِّها.
        #    وقواعدُ التنسيق الخاصّة بالرياضيات تأتي بعدها فتعلو عليها.
        + ANSWER_SHAPE_RULES
        + subject_lens("رياضيات")
        + "القواعد:\n"
        "1) الشرح يكون بنفس أسلوب الملخص.\n"
        "2) تأكد من صحة القوانين وبعدها اشرح.\n"
        "3) الشرح يكون تدريجي وبسيط.\n"
        "4) عند الأمثلة: اشرح خطوة خطوة كما هي.\n"
        "5) اشرح باللغة العربية فقط.\n\n"
        "🔴 اللغة (قاعدة قاطعة تعلو على كل ما سواها):\n"
        "- اكتب **بالعربية وحدها**. لا كلمة إنجليزية ولا من أي لغة أخرى\n"
        "  إطلاقاً — لا في الشرح ولا في المعادلات ولا بين قوسين.\n"
        "- الاستثناء الوحيد: مصطلحٌ إنجليزي **منقولٌ حرفياً من نصّ الدرس**\n"
        "  بين قوسين (مثل: القطع الزائد (Hyperbola)).\n"
        "- ورمز تركيب الدوال يُكتب ∘ لا حرف o.\n\n"
        "📐 التنسيق (ما يراه الطالب على شاشة صغيرة):\n"
        "- **كل خطوة سطرٌ مستقل**، وبين كل خطوة وأختها **سطر فارغ**.\n"
        "- لا تبدأ خطوةً برقمٍ عارٍ («2.») — الرقم يلتصق بالمعادلة فيُقرأ\n"
        "  جزءاً منها. اجعل العنوان **عريضاً بكلمة**: «**المجال:**» ·\n"
        "  «**النهايات والمقاربات:**» · «**المشتقة:**».\n"
        "- **كل معادلة على سطرها وحدها**، لا في وسط جملة.\n"
        "- الأرقام بالعربية: ٠١٢٣٤٥٦٧٨٩ لا 0123456789 — في الشرح\n"
        "  والمعادلات وأرقام الخطوات جميعاً.\n"
        "- لا تُسرف في التعداد المتشعّب؛ مستوىً واحد يكفي.\n\n"
        "الرموز:\n"
        "- استخدم (جا، جتا، ظا) و (س، ص)\n"
        "- او اي صيغ اخرى  LaTeX او int اكتب الرموز والمعادلات باللغة العربية بالرموز و الطرق المكتوبة بالدرس لاتستخدم\n"
        + MARKUP_RULES +
        "- اكتب المعادلات كنص عادي: ص = ٢س² + ١"
    )

# =====================
# دوال مساعدة
# =====================

async def explain_math_lesson(lesson: dict, groq_client, deepseek_client, sink=None):
    """شرح درس رياضيات"""
    content = format_lesson_safely(lesson)
    
    prompt = f"""
هذا ملخص درس رياضيات:

{content}

المطلوب:
اشرح هذا الدرس شرحًا تعليميًا واضحًا للطالب.
- اكتب باللغة العربية فقط
- استخدم الرموز العربية مثل (جا، جتا، ظا) و (س، ص،أ،ب،ج وغيرها )
- لا تستخدم LaTeX أو \\text
{MARKUP_RULES}
- اكتب المعادلات كنص عادي
مثال: ص = ٢س² + ١
"""
    
    try:
        # 🌊 **هذه هي «ابدأ الشرح الذكي»** — أكثر مسارٍ يُستعمل في الرياضيات.
        #
        # 🔴 وكانت مستثناةً من البثّ بتعليلٍ **خاطئ**: ظننتُ أن
        #    `handle_math_explain` تبثّ ردَّها بنفسها، والحقيقة أن فرع «درس
        #    جديد» **يفوّضها كاملاً** ولا ينادي الموديل إطلاقاً. فكان الطالب
        #    يضغط «ابدأ الشرح» وينتظر صامتاً حتى يهبط الشرح دفعةً واحدة.
        #
        # ✅ والمصرف يصل كمعاملٍ صريح لأن الدالة بلا `req`.
        raw_answer = await streaming.complete(
            deepseek_client,
            sink=sink,
            timeout=MATH_TIMEOUT,
            model=MATH_MODEL, **MATH_THINK,
            temperature=0.2,
            max_tokens=MATH_MAX_TOKENS,
            messages=[
                {"role": "system", "content": system_prompt_math_explain()},
                {"role": "user", "content": prompt}
            ],
        )
        clean_answer = _finalize(raw_answer)
        return clean_answer  # 👈 نرجع النص النظيف الخالي من المربعات

    # 2. اصطياد خطأ الوقت (التايم آوت)
    except asyncio.TimeoutError:
        return "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية."

        
    # 3. اصطياد أي خطأ برمجي آخر
    except Exception as e:
        return f"⚠️ عذراً، حدث خطأ أثناء تجهيز الشرح: {str(e)}"

# =====================
# الدوال الرئيسية
# =====================

async def handle_math_request(req: AskRequest, deepseek_client, groq_client):
    """معالج الطلب الرئيسي للرياضيات"""
    
    cleanup_old_sessions()
    _session_timestamps[req.user_id] = time.time()
    
    user_id = req.user_id
    mode = req.mode.strip()
    branch = req.unit_name  # الفرع: تفاضل، تكامل، إلخ
    user_text = req.content.strip()
    lesson_name = req.lesson_name
    
    # =====================
    # 1️⃣ علمني
    # =====================
    if user_text == "علمني":
        return {
           "answer": (
                "📘 أنت في قسم الرياضيات:\n\n"
                "🟢 شرح الدرس:\n"
                "- اختر الفرع\n"
                "- اختر الدرس\n"
                "- اضغط (شرح الدرس)\n"
                "- بعد الشرح يمكنك السؤال عن أي نقطة في الشرح\n\n"
                "🔵 سؤال:\n"
                "- اختر الدرس\n"
                "- اكتب المسألة\n"
                "- سيحلها الذكاء الاصطناعي بنفس أسلوب الملخص\n"
            ),
            "session_active": False
        }
    
    # =====================
    # تحقق من الفرع
    # =====================
    if not branch:
        return {"answer": "⚠️ اختر فرع الرياضيات أولاً."}
    
    # =====================
    # 2️⃣ وضع الوزاري
    # =====================
    if mode == "وزاري":
        return await handle_math_exams(req, sessions_math, deepseek_client, groq_client)
    
    # =====================
    # 3️⃣ وضع الشرح
    # =====================
    elif mode == "شرح":
        return await handle_math_explain(req, sessions_math, deepseek_client, groq_client)
    
    # =====================
    # 4️⃣ وضع السؤال
    # =====================
    elif mode == "سؤال":
        return await handle_math_question(req, sessions_math, deepseek_client)
    
    return {"answer": "وضع غير معروف"}


def _last_assistant_text(history) -> str:
    """آخرُ ردٍّ للمساعد في المحادثة — أو فراغ. ([handle_math_explain] الحالة ٢)"""
    for msg in reversed(list(history or [])):
        if not isinstance(msg, dict):
            continue
        if msg.get("role") == "assistant":
            return (msg.get("content") or "").strip()
    return ""


async def handle_math_explain(req: AskRequest, sessions: Dict, deepseek_client, groq_client):
    """شرح درس رياضيات - النسخة الصحيحة"""
    
    user_id = req.user_id
    branch = req.unit_name
    lesson_name = req.lesson_name
    user_text = req.content.strip()
    
    if not lesson_name:
        return {"answer": "⚠️ يجب اختيار الدرس أولاً."}
    
    sess = sessions.get(user_id)
    norm_lesson_name = normalize_text_match(lesson_name)
    sess_lesson_name = normalize_text_match(sess.get("lesson_name", "")) if sess else ""
    
    # ============================================
    # ✅ الحالة 1: الطالب طلب شرح الدرس كاملاً
    # ============================================
    # 🔴 **وكان الشرطُ نصفَ شرط** (علّةُ المالك 2026-09-16): الرياضياتُ وحدها
    #    تعرف «الحقل الفارغ» طلباً للشرح، لأن زرَّها القديم «🚀 ابدأ الشرح
    #    الذكي» كان يُرسل فراغاً. فلمّا صار زرُّ «اشرح لي» واحداً لكل المواد
    #    وهو يُرسل **نصّاً** («اشرح لي هذا الدرس») وقعت ضغطتُه في الرياضيات
    #    على الحالة ٢ — «سؤالٌ عن الشرح» — فذهبت إلى الموديل بلا شرحٍ سابقٍ
    #    تسأل عنه، وتخطّت المخزونَ كلَّه.
    #
    # ⚖️ و`is_full_lesson_request` هي **نفسُ المقياس** الذي تُسلَّم به شروحُ
    #    بقية المواد ([lesson_cache.serves]) — فالرياضياتُ تدخل الميزةَ من
    #    بابها لا من باب استثناءٍ خاصٍّ بها.
    if (user_text == "" or user_text.startswith("شرح درس:")
            or lesson_cache.is_full_lesson_request(user_text)):
        # إذا فيه جلسة نشطة للدرس نفسه → رجع الشرح السابق
        if sess and sess_lesson_name == norm_lesson_name:
            return {
                "answer": sess.get("last_explanation", ""),
                "session_active": False
            }
        
        # إذا درس جديد → اشرح الدرس
        sessions.pop(user_id, None)
        lesson = load_math_lesson(branch, lesson_name)
        if not lesson: 
            return {"answer": f"❌ لم أجد درس '{lesson_name}'."}

        # 🗄️ **والشرحُ المخزون هنا أيضاً** ([core/lesson_cache]): الرياضياتُ
        #    لا تمرّ بـ`lesson_mode`، فكانت ستبقى وحدها خارج الكاش بينما
        #    طلبُ المالك «في الأحياء والكيمياء والفيزياء والرياضيات، في كل
        #    مكان». وبصمتُها من ملف الدرس نفسِه لا من المُسلسِل.
        # 🔴 **و`serves` لا «السجلّ فارغ»**: التطبيق يضيف رسالةَ الطالب إلى
        #    `messages` ثم يبني منها `chat_history`، فالسجلُّ يصل وفيه سؤالُه
        #    الحالي — وكان شرطُ الفراغ لا يتحقّق أبداً فلا يُسلَّم مخزونٌ في
        #    الرياضيات ولا مرّة. وهي **نفسُ العلّة** التي أُصلحت لبقية المواد
        #    بمِسبارٍ حيّ من المحاكي ([lesson_cache.serves]).
        if lesson_cache.serves(req):
            _stored = lesson_cache.get(req.grade, req.track, "رياضيات", branch,
                                       lesson_name, lesson_cache.math_source(lesson))
            if _stored:
                sessions[user_id] = {
                    "subject": "رياضيات", "mode": "math_explain",
                    "lesson": lesson, "lesson_name": lesson_name,
                    "last_explanation": _stored,
                }
                _session_timestamps[user_id] = time.time()
                return {"answer": _stored, "cached": True, "session_active": False}
        
        explanation = await explain_math_lesson(
        lesson, groq_client, deepseek_client, sink=streaming.sink_of(req))
        
        sessions[user_id] = {
            "subject": "رياضيات",
            "mode": "math_explain",
            "lesson": lesson,
            "lesson_name": lesson_name,
            "last_explanation": explanation
        }
        _session_timestamps[user_id] = time.time()  # ← أضف هذا
        return {"answer": explanation, "session_active": False}
    
    # ============================================
    # ✅ الحالة 2: الطالب كتب سؤال عن الشرح
    # ============================================
    # 🧵 **والشرحُ يُستعاد من المحادثة إن غابت الجلسة.**
    #
    # 🔴 جلسةُ الخادم ذاكرةٌ هشّة: تموت بإعادة تشغيلٍ أو بعامِلٍ آخر يستقبل
    #    الطلب، و**لا تُنشأ أصلاً** حين يُعرض الشرحُ من سحب التطبيق المسبق
    #    ([/lesson/explanation]) — وهو المسارُ الغالب اليوم. فبلا هذا
    #    الاسترداد يسقط سؤالُ الطالب إلى «الحالة ٣» فيُعاد شرحُ الدرس من
    #    أوّله بدل أن يُجاب سؤالُه.
    #
    # ⚖️ والمصدرُ البديل في يده أصلاً: `chat_history` يحمل آخرَ ردٍّ للمساعد
    #    — وهو الشرحُ نفسُه. فطلبُ المالك «ولما يسأل الطالب يسأل مع الشرح
    #    حقه» يتحقّق بالجلسة **أو** بالمحادثة، أيُّهما وُجد.
    if not (sess and sess.get("mode") == "math_explain"
            and sess_lesson_name == norm_lesson_name):
        recovered = _last_assistant_text(req.chat_history)
        if recovered:
            _doc = load_math_lesson(branch, lesson_name)
            if _doc:
                sess = {"subject": "رياضيات", "mode": "math_explain",
                        "lesson": _doc, "lesson_name": lesson_name,
                        "last_explanation": recovered}
                sess_lesson_name = norm_lesson_name

    if sess and sess.get("mode") == "math_explain" and sess_lesson_name == norm_lesson_name:
        lesson = sess["lesson"]
        last_explanation = sess["last_explanation"]
        
        messages_for_ai = [
            {"role": "system", "content": system_prompt_math_explain()}
        ]
        
        messages_for_ai.append({
            "role": "assistant",
            "content": f"هذا شرح الدرس الذي نتحدث عنه:\n{last_explanation}"
        })
        
        if req.chat_history:
            valid_history = [msg for msg in req.chat_history if msg.get('role') in ['user', 'assistant']]
            messages_for_ai.extend(valid_history[-HISTORY_LAST_N:])
        
        messages_for_ai.append({
            "role": "user",
            "content": (f"سؤال الطالب حول الشرح: {user_text}\n(  المطلوب )\n"
            """- أجب على السؤال بالاعتماد على نفس الدرس فقط.
لاتكتب اي كلمة انجليزية او كلمة غير عربية اثناء الشرح
- وضّح الفكرة بأسلوب تعليمي مرتبط بالشرح السابق.
- اكتب الشرح باللغة العربية فقط
- لا تستخدم LaTeX
- لا تستخدم \\text
"""
            + MARKUP_RULES
            + """- اكتب المعادلات كنص عادي
مثال: ص = ٢س² + ١""" + turn_note(req))
        })
        
        try:
            # 🌊 يبثّ حرفاً حرفاً على مسار البثّ، وإلا نداءٌ عادي حرفياً.
            raw_answer = await streaming.complete(
                deepseek_client,
                sink=streaming.sink_of(req),
                timeout=MATH_TIMEOUT,
                model=MATH_MODEL, **MATH_THINK,
                temperature=0.2,
                messages=messages_for_ai,
                max_tokens=MATH_MAX_TOKENS,
            )
            clean_answer = _finalize(raw_answer)
            full_answer = clean_answer # نمرر الإجابة النظيفة للتطبيق
            clean_answer = re.sub(r'<think>.*?</think>', '', full_answer, flags=re.DOTALL | re.IGNORECASE).strip()
            
            return {"answer": clean_answer, "session_active": False}
        
        except asyncio.TimeoutError:
            return {"answer": "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية.", "session_active": False}
        
        
        except Exception as e:
            return {"answer": f"خطأ: {str(e)}", "session_active": False}
    
    # ============================================
    # ✅ الحالة 3: درس جديد → اشرح من الصفر
    # ============================================
    sessions.pop(user_id, None)
    lesson = load_math_lesson(branch, lesson_name)
    if not lesson: 
        return {"answer": f"❌ لم أجد درس '{lesson_name}'."}
    
    explanation = await explain_math_lesson(
        lesson, groq_client, deepseek_client, sink=streaming.sink_of(req))
    
    sessions[user_id] = {
        "subject": "رياضيات",
        "mode": "math_explain",
        "lesson": lesson,
        "lesson_name": lesson_name,
        "last_explanation": explanation
    }
    _session_timestamps[user_id] = time.time()  # ← أضف هذا
    return {"answer": explanation, "session_active": False}

async def handle_math_question(req: AskRequest, sessions: Dict, deepseek_client):
    """حل مسألة رياضيات"""
    
    user_id = req.user_id
    branch = req.unit_name
    lesson_name = req.lesson_name
    user_text = req.content.strip()
    
    if not lesson_name:
        return {"answer": "⚠️ اختر الدرس أولاً."}
    
    lesson = load_math_lesson(branch, lesson_name)
    if not lesson:
        return {"answer": f"⚠️ لم أجد ملف الدرس: {lesson_name}"}
    
    lesson_text = format_lesson_safely(lesson)
    
    system_prompt = (
        "أنت مدرس رياضيات محترف في تطبيق \"مسار\". التزم بالقواعد التالية:\n\n"
        # 🗣️ **قواعدُ المتابعة والمحادثة والاتّصال من مصدرها الواحد**
        #    (2026-09-14). كان هنا أربعةُ أسطرٍ تقول «إذا سألك عن نقطة في
        #    الشرح السابق استخدم السياق» — وهي لا تمنع إعادةَ شرح ما شُرح،
        #    ولا تُعرّف طلبَ المتابعة، ولا تمنع التحيةَ المكرّرة. وهي نفسُ
        #    العلّة التي عولجت في بقية المواد، فلا تُكتب هنا مرّةً خامسة.
        #
        # ⚠️ **ولا `source_rules` هنا عمداً**: تمنع «مثالاً ليس في النص»،
        #    والرياضياتُ تُحلّ فيها المسألةُ المشابهة بأرقامٍ أخرى بنفس خطوات
        #    الدرس — وهذا مطلوبٌ صراحةً في هذا البرومبت أدناه. فقيدُ المصدر
        #    في الرياضيات هو **طريقةُ الحل وقوانينُ الدرس**، لا نصُّه حرفاً.
        + FOLLOWUP_RULES
        + CONVERSATION_RULES
        + CONTINUITY_RULES
        # 🪄 والتقريبُ المسموح يُلحق صراحةً هنا: الرياضياتُ لا تمرّ بـ
        #    `source_rules` (انظر أعلاه)، فكان استثناءُ التشبيه يسقط عنها
        #    وحدها بينما طلبه المالك **في كل المواد**.
        + SUPPORT_EXAMPLE_RULES
        # 🚫 **وشكلُ الجواب معها** — ومنه ضبطُ الافتتاح: الرياضياتُ كانت
        #    المادةَ الوحيدة خارج `ANSWER_SHAPE_RULES`، فعادت تفتح بـ«أهلاً
        #    بك، سأشرح لك…» بعد أن نُظّف الافتتاحُ في المواد كلِّها.
        #    وقواعدُ التنسيق الخاصّة بالرياضيات تأتي بعدها فتعلو عليها.
        + ANSWER_SHAPE_RULES
        + subject_lens("رياضيات")
            + "📖 التعامل مع الأسئلة:\n"
             "- اشرح الدرس أو السؤال كما لو كنت تشرحه للطلاب في الفصل.\n"
            "- استخدم طريقة تعليمية مبسطة وواضحة.\n"
            "- حل المسائل خطوة بخطوة حتى يفهم الطالب كل مرحلة.\n"
            "- ابحث أولاً في أمثلة الدرس الموجودة.\n"
            "- إذا كان السؤال مطابقاً لمثال → اعرض الحل النموذجي.\n"
            "- إذا كان مشابهاً (اختلاف أرقام أو رموز) → حلّه بنفس الخطوات والمنهج تماماً.\n\n"
            "- في نهاية الحل، اذكر القوانين المستخدمة.\n\n"
            "📝 اللغة:\n"
            "- استخدم العربية الفصحى فقط.\n"
            "- يمنع استخدام الإنجليزية أو أي لغة أخرى.\n\n"
            "🔢 الرموز الرياضية:\n"
            "- استخدم فقط: (جا، جتا، ظا) و (س، ص)\n\n"
            "-  لا تستخدم \\text او اي رموز اخرى مشابه لها , اكتب بنفس الصيغه الموجودة في الدرس \n"
            + MARKUP_RULES +
            "✏️ مثال للكتابة الصحيحة:\nص = ٢س² + ١\n\n"
            "⚠️ مهم جداً: اكتب الحل مرة واحدة فقط، بدون تكرار."
    )
    
    try:
        messages_for_ai = [{"role": "system", "content": system_prompt}]
        
        if req.chat_history:
            valid_history = [msg for msg in req.chat_history 
                            if msg.get('role') in ['user', 'assistant']]
            messages_for_ai.extend(valid_history[-HISTORY_LAST_N:])
        
        messages_for_ai.append({
            "role": "user",
            "content": (f"سياق الدرس:\n{lesson_text}\n\nسؤال الطالب: {user_text}" + turn_note(req))
        })
        
        # 🌊 يبثّ حرفاً حرفاً على مسار البثّ، وإلا نداءٌ عادي حرفياً.
        raw_answer = await streaming.complete(
            deepseek_client,
            sink=streaming.sink_of(req),
            timeout=MATH_TIMEOUT,
            model=MATH_MODEL, **MATH_THINK,
            messages=messages_for_ai, max_tokens=MATH_MAX_TOKENS,
            temperature=0.2,
        )
        clean_answer = _finalize(raw_answer)
        full_answer = clean_answer # نمرر الإجابة النظيفة للتطبيق
        
        # تنظيف النص
        clean_answer = re.sub(r'<think>.*?</think>', '', full_answer, flags=re.DOTALL).strip()
        clean_answer = clean_answer.replace("sin", "جا").replace("cos", "جتا").replace("tan", "ظا")
        clean_answer = clean_answer.replace("x", "س").replace("y", "ص")
        
        return {"answer": clean_answer, "session_active": False}
    except asyncio.TimeoutError:
        return {"answer": "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية.", "session_active": False}
        
    except Exception as e:
        return {"answer": f"عذراً، حدث خطأ: {str(e)}", "session_active": False}


async def handle_math_exams(req: AskRequest, sessions: Dict, deepseek_client, groq_client):
    """وضع الوزاري للرياضيات"""
    
    user_id = req.user_id
    branch = req.unit_name
    user_text = req.content.strip()
    
    # =====================
    # 1️⃣ أوامر التحكم (وقف)
    # =====================
    if user_text in ["وقف", "خلاص", "شكرا", "إلغاء"]:
        sess = sessions.get(user_id)
        if sess:
            sess["pending_exams"] = []
            sess["has_more"] = False  # 🔥 التعديل: إغلاق ظهور الأزرار نهائياً في الجلسة
            sessions[user_id] = sess
        
        return {
            "answer": "✅ تم إيقاف عرض المزيد.",
            "session_active": False
        }
    
    # =====================
    # 2️⃣ كمل (متابعة)
    # =====================
    if user_text in ["كمل", "نعم", "متابعة"]:
        sess = sessions.get(user_id)
        if sess and sess.get("mode") == "وزاري":
            year = sess.get("year")
            lesson = sess.get("lesson")
            shown_count = sess.get("shown_count", 0)
            
            result = get_math_exam_questions(branch, year, lesson, shown_count + 10)
            new_questions = result["questions"][shown_count:]
            
            # ✅ إذا ما فيه أسئلة إضافية
            if not new_questions:
                sess["has_more"] = False
                sessions[user_id] = sess
                return {
                    "answer": "✅ انتهت جميع الأسئلة.",
                    "session_active": False
                }
            
            text = f"📋 الأسئلة الإضافية:\n\n"
            
            for i, q in enumerate(new_questions, shown_count + 1):
                q_text = q['نص_السؤال'].replace('\n', '\n\n')
                text += f"\n📌 السؤال {i}:\n{q_text}\n"
                
                if q.get('الحل'):
                    sol_text = q['الحل'].replace('\n', '\n\n')
                    text += f"💡 الإجابة:\n{sol_text}\n"
                
                text += "━━━━━━━━━━━━━━━\n"
            
            if len(new_questions) < result.get("remaining", 0):
                text += f"\n💡 تبقى {result['remaining']} سؤال. اكتب 'كمل' للمزيد."
            
            # حفظ الأسئلة الجديدة
            all_displayed = sess.get("displayed_questions", []) + new_questions
            
            sessions[user_id] = {
                "subject": "رياضيات",
                "mode": "وزاري",
                "branch": branch,
                "year": year,
                "lesson": lesson,
                "shown_count": shown_count + len(new_questions),
                "displayed_questions": all_displayed,
                "pending_exams": [],
                "has_more": result.get("has_more", False)  # 🔥 التعديل: حفظ حالة الأزرار
            }
            _session_timestamps[user_id] = time.time()  # ← أضف هذا
            
            return {"answer": text, "session_active": result.get("has_more", False)}
        else:
            return {
                "answer": "⚠️ لا توجد جلسة وزاري نشطة.",
                "session_active": False
            }
    
    # =====================
    # 3️⃣ جلب أسئلة جديدة (صيغة: السنة|الدرس|العدد)
    # =====================
    parts = user_text.split("|")
    
    if len(parts) == 3:
        year = parts[0].strip()
        lesson = parts[1].strip()
        try:
            count = int(parts[2].strip())
        except:
            count = 10
        
        result = get_math_exam_questions(branch, year, lesson, count)
        
        if not result["questions"]:
            return {"answer": f"❌ لم أجد أسئلة في '{lesson}' لسنة {year}"}
        
        total = result["total"]
        shown = len(result["questions"])
        
        text = f"✅ وجدت {total} سؤالاً في '{lesson}' - سنة {year}\n"
        text += f"📋 عرض {shown} سؤال:\n\n"
        text += "━━━━━━━━━━━━━━━\n"
        
        for i, q in enumerate(result["questions"], 1):
            q_text = q['نص_السؤال'].replace('\n', '\n\n')
            text += f"\n📌 السؤال {i}:\n{q_text}\n"
            
            if q.get('الحل'):
                sol_text = q['الحل'].replace('\n', '\n\n')
                text += f"💡 الإجابة:\n{sol_text}\n"
            
            text += "━━━━━━━━━━━━━━━\n"
        
        if result["has_more"]:
            text += f"\n💬 يوجد {result['remaining']} سؤالاً إضافياً.\n"
            text += "هل تريد عرضها؟ (اكتب 'كمل')\n"
        
        sessions[user_id] = {
            "subject": "رياضيات",
            "mode": "وزاري",
            "branch": branch,
            "year": year,
            "lesson": lesson,
            "shown_count": shown,
            "displayed_questions": result["questions"],  
            "pending_exams": [],
            "has_more": result["has_more"]  # 🔥 التعديل: حفظ الحالة من البداية
        }
        _session_timestamps[user_id] = time.time()  # ← أضف هذا
        
        return {"answer": text, "session_active": result["has_more"]}
    
    # =====================
    # 4️⃣ 🔥 سؤال عن الأسئلة الوزارية المعروضة 🔥
    # =====================
    sess = sessions.get(user_id)
    
    if sess and sess.get("mode") == "وزاري":
        displayed_questions = sess.get("displayed_questions", [])
        branch_current = sess.get("branch")
        year_current = sess.get("year")
        lesson_current = sess.get("lesson")
        
        if not displayed_questions:
            return {
                "answer": "⚠️ لا توجد أسئلة معروضة.",
                "session_active": False
            }
        
        # ✅ تحميل الدرس للسياق
        lesson_data = load_math_lesson(branch_current, lesson_current)
        lesson_text = format_lesson_safely(lesson_data) if lesson_data else ""
        
        # ✅ بناء نص الأسئلة المعروضة
        questions_context = f"📚 الأسئلة الوزارية المعروضة (سنة {year_current}, درس: {lesson_current}):\n\n"
        for i, q in enumerate(displayed_questions, 1):
            q_text = q.get('نص_السؤال', '').replace('\n', '\n  ')
            sol_text = q.get('الحل', '').replace('\n', '\n  ')
            
            questions_context += f"📌 السؤال {i}:\n{q_text}\n\n"
            if sol_text:
                questions_context += f"💡 الحل:\n{sol_text}\n\n"
            questions_context += "━━━━━━━━━━━━━━━\n\n"
        
        # ✅ برومبت خاص بالإجابة على الأسئلة الوزارية
        system_prompt = (
           "أنت مدرس رياضيات محترف.\n"
                "المطلوب: الإجابة على سؤال الطالب بناءً على الأسئلة الوزارية المعروضة.\n\n"
                "📌 السياق المهم:\n"
                "- الطالب يسأل عن أسئلة وزارية معروضة أمامه\n"
                "- قد يسأل: 'وضح السؤال 3'، 'كيف حلينا الثاني'، 'ما فهمت قيمة س'\n"
                "- أنت تفهم سؤاله وتجيب بناءً على الأسئلة المعروضة\n\n"
                "القواعد:\n"
            "- استخدم العربية الفصحى فقط.\n"
            "- يمنع استخدام الإنجليزية أو أي لغة أخرى.\n\n"
            "يمنع استخدام اي رموز غير عربية .\n\n"
            "- استخدم فقط: (جا، جتا، ظا) و (س، ص)\n\n"
            "- لا تستخدم \\text\n"
            + MARKUP_RULES +
            "✏️ مثال للكتابة الصحيحة:\nص = ٢س² + ١\n\n"
                "- اشرح الحل خطوة بخطوة\n"
                "- اذكر القوانين المستخدمة\n"
                "- إذا ذكر رقم سؤال، ارجع للسؤال المطابق من القائمة المعروضة\n"
                "- إذا كان سؤالاً عاماً، استخدم الأسئلة المعروضة للتوضيح\n"
        )
        
        try:
            # ✅ بناء الرسائل
            messages_for_ai = [{"role": "system", "content": system_prompt}]
            
            # ✅ إضافة السياق: الأسئلة المعروضة
            messages_for_ai.append({
                "role": "assistant",
                "content": f"هذه الأسئلة الوزارية المعروضة أمامك:\n\n{questions_context}"
            })
            
            # ✅ إضافة التاريخ (إن وجد)
            if req.chat_history:
                valid_history = [msg for msg in req.chat_history 
                                if msg.get('role') in ['user', 'assistant']]
                messages_for_ai.extend(valid_history[-HISTORY_LAST_N:])
            
            # ✅ سؤال الطالب الجديد
            messages_for_ai.append({
                "role": "user",
                "content": (
                    f"بيانات الدرس (للمرجعية):\n{lesson_text}\n\n"
                    f"سؤال الطالب: {user_text}"
                )
            })
            
            # ✅ استدعاء الـ AI — 🌊 يبثّ على مسار البثّ، وإلا نداءٌ عادي.
            raw_answer = await streaming.complete(
                deepseek_client,
                sink=streaming.sink_of(req),
                timeout=MATH_TIMEOUT,
                model=MATH_MODEL, **MATH_THINK,
                messages=messages_for_ai, max_tokens=MATH_MAX_TOKENS,
                temperature=0.2,
            )
            clean_answer = _finalize(raw_answer)
            full_answer = clean_answer # نمرر الإجابة النظيفة للتطبيق
            
            # ✅ تنظيف النص
            clean_answer = re.sub(r'<think>.*?</think>', '', full_answer, flags=re.DOTALL).strip()
            clean_answer = clean_answer.replace("sin", "جا").replace("cos", "جتا").replace("tan", "ظا")
            clean_answer = clean_answer.replace("x", "س").replace("y", "ص")
            
            # إزالة أي كود LaTeX متبقي
            clean_answer = re.sub(r'\$.*?\$', '', clean_answer)
            # 🔴🔴 **قائمةُ الاستثناء واحدة: `latex_guard.KEPT`.**
            #    كانت هنا نسخةٌ محلّية `(frac|chem|ring)` فتخلّفت عن الأصل،
            #    فصارت تمسح `\sqrt` و`\fact` بعد أن يحقنهما `_finalize`
            #    — أي أن الجذر والمضروب كانا **يُمحيان في هذا المسار وحده**.
            #    نفسُ العلّة التي وقعت ثلاث مرات: منطقٌ مكرَّرٌ ينحرف.
            clean_answer = _latex_guard.clean(clean_answer)
            
            return {
                "answer": clean_answer,
                "session_active": sess.get("has_more", False)  # 🔥 التعديل الجوهري: الاعتماد على الجلسة وليس True
            }
        except asyncio.TimeoutError:
            return {
                "answer": "⚠️ عذراً، خوادم الذكاء الاصطناعي مشغولة حالياً بسبب الضغط. حاول مرة ثانية.",
                "session_active": sess.get("has_more", False)  # 🔥 لضمان بقاء الأزرار مخفية في حال التأخير
            }
        except Exception as e:
            return {
                "answer": f"❌ خطأ: {str(e)}",
                "session_active": sess.get("has_more", False)  # 🔥 لضمان بقاء الأزرار مخفية في حال الخطأ
            }
    
    # =====================
    # ❌ لا يوجد جلسة وزاري نشطة
    # =====================
    return {
        "answer": (
          "⚠️ يرجى جلب الأسئلة الوزارية أولاً!\n\n"
            "📝 الخطوات:\n"
            "1. اختر السنة من القائمة أعلاه\n"
            "2. اختر الدرس\n"
            "3. حدد عدد الأسئلة\n"
            "4. اضغط 'جلب الأسئلة'\n\n"
            "✨ بعدها يمكنك السؤال عن أي سؤال مباشرة!"
        ),
        "session_active": False
    }