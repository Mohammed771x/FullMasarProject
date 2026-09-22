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


def call_budget(model_name: str, max_tokens: int, timeout: float):
    """يعيد `(سقف، مهلة)` — موسَّعَين لنموذج التفكير، وكما هما لغيره."""
    if is_thinking_model(model_name):
        return max(max_tokens, THINKING_TOKENS), max(timeout, THINKING_TIMEOUT)
    return max_tokens, timeout
