# ==================================================
# 🎓 core/curriculum.py — الصفوف والمسارات والمواد
# ==================================================
# المصدر الوحيد لقوائم المواد وتوجيه الموديلات.
# ⚠️ أسماء المواد هنا هي "القائمة البيضاء" الأمنية أيضاً:
#    أي subject لا يطابقها يُرفض قبل أن يلمس نظام الملفات.

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
    "فيزياء":  ("openai",   "gpt-4o-mini"),
    "كيمياء":  ("openai",   "gpt-4o-mini"),
    "رياضيات": ("deepseek", "deepseek-chat"),
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
