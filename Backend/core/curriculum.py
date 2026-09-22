# ==================================================
# 🎓 core/curriculum.py — الصفوف والمسارات والمواد
# ==================================================
# المصدر الوحيد لقوائم المواد وتوجيه الموديلات.
# ⚠️ أسماء المواد هنا هي "القائمة البيضاء" الأمنية أيضاً:
#    أي subject لا يطابقها يُرفض قبل أن يلمس نظام الملفات.

import os

GRADES = {1: "grade1", 2: "grade2", 3: "grade3"}
TRACKS = {"عام", "علمي", "أدبي"}

# قوائم المواد (من المالك — 2026-08-26)
SUBJECTS_BY_GRADE_TRACK = {
    (1, "عام"):   ["عربي", "انجليزي", "رياضيات", "فيزياء", "كيمياء", "احياء", "تاريخ", "جغرافيا", "مجتمع"],
    (2, "علمي"):  ["عربي", "انجليزي", "فيزياء", "كيمياء", "احياء", "رياضيات"],
    (2, "أدبي"):  ["عربي", "انجليزي", "رياضيات", "تاريخ", "جغرافيا", "علم الاقتصاد", "علم الاجتماع"],
    (3, "علمي"):  ["احياء", "فيزياء", "كيمياء", "عربي", "انجليزي", "رياضيات"],
    (3, "أدبي"):  ["عربي", "انجليزي", "رياضيات", "تاريخ", "جغرافيا", "مبادئ علم الخرائط", "فلسفة", "منطق"],
}

# كل الأسماء المسموحة (اتحاد كل القوائم) — للتحقق السريع
ALL_SUBJECTS = sorted({s for lst in SUBJECTS_BY_GRADE_TRACK.values() for s in lst})


def normalize_grade_track(grade, track):
    """يصحّح (الصف، المسار) إلى قيم صالحة — الصف الأول موحّد بلا مسار."""
    try:
        grade = int(grade)
    except (TypeError, ValueError):
        grade = 3
    if grade not in GRADES:
        grade = 3
    track = (track or "").strip()
    if grade == 1:
        track = "عام"
    elif track not in ("علمي", "أدبي"):
        track = "علمي"
    return grade, track


def is_valid_subject(grade, track, subject):
    grade, track = normalize_grade_track(grade, track)
    return subject in SUBJECTS_BY_GRADE_TRACK.get((grade, track), [])


def subjects_for(grade, track):
    grade, track = normalize_grade_track(grade, track)
    return list(SUBJECTS_BY_GRADE_TRACK.get((grade, track), []))


# ── توجيه الموديلات (نفس توزيع الكود الحالي حرفياً + افتراضي للمواد الجديدة) ──
# client_key يُحوَّل إلى عميل فعلي في api.py
MODEL_ROUTING = {
    "احياء":   ("gemini",   "gemini-3.1-flash-lite"),
    "عربي":    ("gemini",   "gemini-3.1-flash-lite"),
    "انجليزي": ("gemini",   "gemini-3.1-flash-lite"),
    # 🧪 **والفيزياءُ والكيمياءُ حُوّلتا إلى `deepseek-flash`** (قياسٌ مباشرٌ
    #    2026-09-22، بأمر المالك: «خلي ديب سيك فلاش يتعامل مع الفيزياء
    #    والكيمياء»). والسببُ رقمٌ لا رأي — عشرون مسألةً محسوبةً باليد،
    #    ثلاثُ إعاداتٍ بحرارةِ صفر، والإخفاقاتُ تكرّرت بعينها في الثلاث:
    #
    #      الموديل                  الكلّ  فيزياء  كيمياء  رياضيات
    #      gpt-4o-mini               ٦٠٪    ٦٢٪     ٨٦٪     ٢٠٪
    #      gemini-3.1-flash-lite     ٩٥٪   ١٠٠٪    ١٠٠٪     ٨٠٪
    #      deepseek-chat             ٨٥٪    ٨٨٪     ٨٦٪     ٨٠٪
    #      deepseek-flash           ١٠٠٪   ١٠٠٪    ١٠٠٪    ١٠٠٪
    #
    # 💡 **والفرقُ أنه يفكّر**: `reasoning_tokens` صفرٌ في `deepseek-chat`
    #    و٥٧ في `deepseek-flash` — وهو ما يفعله تطبيقُ ديب سيك في الجوال
    #    حين يُشغَّل DeepThink. فالعائلةُ نفسُها، والتفكيرُ هو الفارق.
    #
    # 💵 **وهو أرخصُ لا أغلى**: خرجُه $٠٫٤٢ للمليون مقابل $٠٫٦٠ لـ gpt-4o-mini.
    "فيزياء":  ("deepseek", os.getenv("SCI_MODEL", "deepseek-flash")),
    "كيمياء":  ("deepseek", os.getenv("SCI_MODEL", "deepseek-flash")),
    # ☢️ **`deepseek-chat` سُحب من المزوّد** (رُصد 2026-09-15): نداؤه لا يعود
    #    بخطأٍ بل **يتعلّق حتى المهلة**، فكلُّ طلبِ رياضياتٍ في التطبيق —
    #    شرحاً وسؤالاً ووزارياً — كان يردّ «⚠️ خوادم الذكاء الاصطناعي مشغولة».
    #    عطلٌ صامتٌ تامّ في مادةٍ كاملة، ولا سجلَّ خطأٍ يدلّ عليه.
    #
    #    والقياسُ المباشر (curl، 2026-09-15):
    #      • deepseek-chat   ⇐ HTTP 000 بعد ٤٥ث (لا ردَّ أصلاً، ولا رسالةَ خطأ)
    #      • deepseek-flash  ⇐ HTTP 000 كذلك — **وهو مُدرَجٌ في /v1/models**
    #      • deepseek-v4-pro ⇐ HTTP 200 في ٠٫٦٧ث
    #    والحسابُ سليم: `is_available: true` ورصيدٌ ٥٠٫٤٥$.
    #
    # 🤔 **ولسنا نجزم أنه أُلغي**: لو أُلغي لردّ المزوّد بـ«Model Not Exist»
    #    لا بصمتٍ حتى المهلة — و`deepseek-flash` المُدرَجُ يتعلّق مثلَه.
    #    فالأرجحُ عطلٌ عندهم يشمل نموذجين، وقد يعود.
    #
    # ⚖️ **وقرار المالك: ننتظر** ولا نغيّر النموذج. فالاسمُ من البيئة
    #    (`DEEPSEEK_MODEL`) وافتراضُه الأصل — فمتى عاد عمل بلا تعديلِ كود،
    #    ومتى أردتَ التحويل فسطرٌ واحد في `.env` لا نشرةُ كود.
    #
    # ⚠️ **ولا يُخمَّن اسمُ النموذج**: اسأل `/v1/models` قبل تغييره.
    # ☢️ **وافتراضُه صار `deepseek-flash`** (2026-09-22): `deepseek-chat`
    #    لم يعد مُدرَجاً في `/v1/models` عند المزوّد — يردُّ اليوم وقد
    #    يُسحب غداً بلا إنذار، كما حدث في ١٥/٩. والبديلُ أدقُّ منه
    #    قياساً (١٠٠٪ مقابل ٨٠٪ في الرياضيات) — فلا حجّةَ للبقاء.
    "رياضيات": ("deepseek", os.getenv("DEEPSEEK_MODEL", "deepseek-flash")),
    # ── المواد النظرية الجديدة (لكلٍّ ملف معالج مستقل في subjects/) ──
    "تاريخ":               ("gemini", "gemini-3.1-flash-lite"),
    "جغرافيا":             ("gemini", "gemini-3.1-flash-lite"),
    "مجتمع":               ("gemini", "gemini-3.1-flash-lite"),
    "علم الاقتصاد":        ("gemini", "gemini-3.1-flash-lite"),
    "علم الاجتماع":        ("gemini", "gemini-3.1-flash-lite"),
    "فلسفة":               ("gemini", "gemini-3.1-flash-lite"),
    "منطق":                ("gemini", "gemini-3.1-flash-lite"),
    "مبادئ علم الخرائط":   ("gemini", "gemini-3.1-flash-lite"),
}
DEFAULT_ROUTE = ("gemini", "gemini-3.1-flash-lite")


def model_route(subject: str):
    return MODEL_ROUTING.get(subject, DEFAULT_ROUTE)


# ══════════════════════════════════════════════════
# ☢️ سقفُ النداء — ونموذجُ التفكير يحتاج ضِعفَه ثلاثاً
# ══════════════════════════════════════════════════
#
# 🔴 **قِيس مباشرةً (2026-09-22)** على `deepseek-flash` ببرومبت «اختبر نفسك»:
#      سقف ٤٠٠٠  ⇐ **صفرُ حروفٍ مُعادة** · تفكير ٤٠٠٠ · finish="length"
#      سقف ١٢٠٠٠ ⇐ ٣٢٠٧ حرفاً · تفكير ٧٥٩١ · finish="stop" · ٣٦ ثانية
#
# ⚠️ **والعطلُ صامتٌ تماماً**: لا خطأَ ولا استثناءَ ولا سجلّ — جوابٌ فارغٌ
#    فحسب. ولولا أن قِيس قبل التسليم لسقطت كلُّ مادةٍ حوّلناها إلى التفكير
#    في كلّ درسٍ لا بنكَ له، ولظهر للطالب «⚠️ خوادم الذكاء مشغولة».
#
# 🎯 فالسقفُ يُشتقّ من **اسم النموذج** لا يُكتب في كل نداء، حتى لا يُنسى
#    موضعٌ عند التحويل القادم. ومن لا يفكّر يبقى على سقفه كما كان تماماً.
THINKING_MODELS = ("deepseek-flash", "deepseek-v4-pro", "deepseek-reasoner")
THINKING_TOKENS, THINKING_TIMEOUT = 12000, 240


def is_thinking_model(model_name: str) -> bool:
    return any(m in (model_name or "") for m in THINKING_MODELS)


# 🎚️ **وشدّةُ التفكير تتبع الغرضَ لا النموذج** (قرار المالك 2026-09-22:
#    «أنا ما بغيته reasoning» — بعد أن رأى شرحاً يقف في منتصف الجملة).
#
#    📏 وقِيس الفرقُ على المقياسين معاً:
#
#      الغرض          الشدّة     الدقّة  زمنُ سؤالٍ  زمنُ شرحٍ طويل
#      ─────────────────────────────────────────────────────────
#      "chat"         none       ٩٠٪     ١٫٠ث      ٨٫٥ث  ✅ بلا قطع
#      —              minimal   ١٠٠٪     ١٫٦ث      ٢٠ث   ⚠️ ٢٧٠٠ رمزِ تفكير
#      —              (كامل)    ١٠٠٪     ١٫٦ث      ١٥ث
#
# ⚖️ **فالنقاشُ والشرحُ بلا تفكير**: الطالبُ ينتظر على الشاشة، والتفكيرُ لا
#    يزيد جودةَ شرحٍ نثريّ — بل يضاعف الزمنَ ويُهدّد بقطعِ الجواب. أمّا
#    **الحساب** فالتفكيرُ فيه يرفع الدقّةَ من ٩٠٪ إلى ١٠٠٪ بكلفةِ ٠٫٦ ثانية.
#
# 📌 و`deepseek-chat` بلا تفكيرٍ = `deepseek-flash` بلا تفكير: ٩٠٪ لكليهما
#    وبالزمن نفسِه. فهما نموذجٌ واحدٌ والفارقُ **التفكيرُ وحده** — وflash
#    أرخصُ خرجاً ($٠٫٤٢ مقابل $١٫١٠) ومُدرَجٌ عند المزوّد.
CHAT_EFFORT = os.getenv("DEEPSEEK_CHAT_EFFORT", "none")
QUIZ_EFFORT = os.getenv("DEEPSEEK_QUIZ_EFFORT", "minimal")
_EFFORT = {"chat": CHAT_EFFORT, "quiz": QUIZ_EFFORT, "build": "full"}


# 🎚️ وشدّةُ التفكير حين يطلبه الطالبُ صراحةً — «أدنى» لا «كامل»: قِيس أنها
#    تبلغ ١٠٠٪ في الحساب بكلفةِ ٠٫٧ ثانيةٍ فقط، والكاملُ لا يزيد دقّةً.
STUDENT_EFFORT = os.getenv("DEEPSEEK_STUDENT_EFFORT", "minimal")


def reasoning_kwargs(model_name: str, purpose: str = "build",
                     thinking: bool | None = None) -> dict:
    """وسائطُ النداء التي تضبط شدّةَ التفكير — وفارغةٌ لمن لا يفكّر.

    ⚖️ و`thinking` **اختيارُ الطالب ويعلو على الغرض**: زرٌّ عند الإرسال،
       لا إعدادٌ خفيّ. و`None` تعني «لم يختر» فيُعمل بحكم الغرض.
    """
    if not is_thinking_model(model_name):
        return {}
    if thinking is not None:
        effort = STUDENT_EFFORT if thinking else "none"
    else:
        effort = _EFFORT.get(purpose, "full")
    return {} if effort == "full" else {"reasoning_effort": effort}


def subject_thinking(subject: str, purpose: str = "chat",
                     thinking: bool | None = None) -> dict:
    """وسائطُ التفكير لمادّةٍ بعينها — يُعفي المنادي من تتبّع اسم النموذج.

    📏 ووُضع هنا لا في [subjects/math.py]: ذاك في سجلّ الأطوال
       ([tests/test_file_scope_2026_09_20.py]) فلا يكبر، والقاعدةُ
       «أضِف الجديدَ في ملفٍّ مستقلّ لا فيه».
    """
    return reasoning_kwargs(model_route(subject)[1], purpose, thinking)


def request_thinking(subject: str, req=None, purpose: str = "chat") -> dict:
    """وسائطُ التفكير لمادّةٍ **بحسب اختيار الطالب في هذا الطلب**.

    و`req` غائبٌ ⇒ `None` ⇒ حكمُ الغرض. والعميلُ القديم لا يرسل الحقل
    فيصل `False` من [models.AskRequest] — أي سلوكُه اليوم بلا تغيير.
    """
    return subject_thinking(subject, purpose,
                            getattr(req, "thinking", None) if req else None)


def math_thinking(req=None) -> dict:
    """🧮 وللرياضيات مدخلٌ باسمها — لأن [subjects/math.py] في سجلّ الأطوال
    ([tests/test_file_scope_2026_09_20.py]) فلا يحتمل سطراً زائداً."""
    return request_thinking("رياضيات", req, "quiz")


def call_budget(model_name: str, max_tokens: int, timeout: float,
                purpose: str = "build", thinking: bool | None = None):
    """يعيد `(سقف، مهلة)` — موسَّعَين لمن **سيفكّر فعلاً**، وكما هما لغيره.

    ⚠️ ولا يُوسَّع لمن أُطفئ تفكيرُه: مهلةُ ٢٤٠ ثانيةً على مسار الشرح تعني
       أن الطالبَ ينتظر أربعَ دقائقَ قبل أن يرى خطأً — وهو لا يحتاج أكثر
       من عشرٍ أصلاً.
    """
    if not is_thinking_model(model_name):
        return max_tokens, timeout
    effort = (STUDENT_EFFORT if thinking else "none") if thinking is not None \
        else _EFFORT.get(purpose, "full")
    if effort == "none":
        return max_tokens, timeout
    return max(max_tokens, THINKING_TOKENS), max(timeout, THINKING_TIMEOUT)
