# ==================================================
# 🎯 core/audience.py — من هو «ثالث علمي»؟ تعريفٌ واحد لا ثلاثة
# ==================================================
# ثلاثة أقسام في اللوحة تسأل السؤال نفسه:
#   • 📈 التحليلات  — «أرِني أرقام ثالث علمي»
#   • 🔔 الإشعارات  — «أرسل لثالث علمي»
#   • 🔐 الوصول     — «أخفِ المنح عن الأول والثاني»
#
# ⭐ **لماذا ملفٌّ ثالثٌ بدل أن يكتب كلٌّ شرطه؟** لأن ثلاث نسخٍ من الشرط
#    تنحرف: تُصلح تعريف «غير نشط» في التحليلات فيبقى الإشعار يرسل لمن
#    أصلحته. والأسوأ في الوصول: قاعدةٌ تُخفي قسماً عن فئة، وعدّادٌ يقول
#    إن الفئة فارغة — فيظن الأدمن أن القاعدة لا تعمل.
#    الأرقام والإرسال والإخفاء تُشتقّ كلها من هذا الملف — فمن يظهر في
#    عدّاد الجمهور هو **بعينه** من يصله الإشعار ومن تسري عليه القاعدة.
#
# ⚠️ والشرائح تُطابَق على مستند المستخدم كما هو في Firestore، لا على نسخةٍ
#    مُثراة: `grade` و`track` و`role` — لا شيء غيرها إلا ما يُمرَّر صراحةً.

from datetime import datetime, timedelta, timezone

# ── المسارات كما يكتبها التطبيق (`curriculum.dart`) ──
TRACK_SCI = "علمي"
TRACK_LIT = "أدبي"
TRACK_GENERAL = "عام"       # الصف الأول موحّد بلا مسار

# 🕒 حدّ «النشِط»: من طرح سؤالاً واحداً على الأقل خلال هذه المدّة.
ACTIVE_WINDOW_DAYS = 7
INACTIVE_WINDOW_DAYS = 14   # «غير نشط» = لم يسأل منذ أسبوعين


class AudienceError(Exception):
    """شريحة غير معروفة — برسالة عربية جاهزة للعرض."""


# ══════════════ الشرائح ══════════════
# كل شريحة: مفتاح ثابت (يُخزَّن في القواعد والإشعارات) + وصف عربي للأدمن
# + دالّة تطابق. والوصف ليس زينة: هو ما يُعرض في «ملخّص الجمهور» قبل الإرسال.

def _is_student(u: dict) -> bool:
    return (u.get("role") or "student") == "student"


def _is_teacher(u: dict) -> bool:
    return (u.get("role") or "student") == "teacher"


def _grade(u: dict):
    g = u.get("grade")
    return g if isinstance(g, int) else None


def _track(u: dict) -> str:
    return str(u.get("track") or "").strip()


SEGMENTS = {
    "all": {
        "label": "جميع المستخدمين",
        "hint": "كل من له حساب — بما فيهم المديرون.",
        "match": lambda u, ctx: True,
    },
    "students": {
        "label": "الطلاب فقط",
        "hint": "كل من دوره طالب — بلا المديرين.",
        "match": lambda u, ctx: _is_student(u),
    },
    "teachers": {
        "label": "المعلمون فقط",
        "hint": "كل من اختار «معلّم» نوعاً لحسابه.",
        "match": lambda u, ctx: _is_teacher(u),
    },
    "g1": {
        "label": "الصف الأول",
        "hint": "الأول الثانوي (موحّد بلا مسار).",
        "match": lambda u, ctx: _is_student(u) and _grade(u) == 1,
    },
    "g2": {
        "label": "الصف الثاني",
        "hint": "الثاني الثانوي بمساريه.",
        "match": lambda u, ctx: _is_student(u) and _grade(u) == 2,
    },
    "g3": {
        "label": "الصف الثالث",
        "hint": "الثالث الثانوي بمساريه.",
        "match": lambda u, ctx: _is_student(u) and _grade(u) == 3,
    },
    "g2_sci": {
        "label": "ثاني علمي",
        "hint": "الصف الثاني — المسار العلمي.",
        "match": lambda u, ctx: _is_student(u) and _grade(u) == 2 and _track(u) == TRACK_SCI,
    },
    "g2_lit": {
        "label": "ثاني أدبي",
        "hint": "الصف الثاني — المسار الأدبي.",
        "match": lambda u, ctx: _is_student(u) and _grade(u) == 2 and _track(u) == TRACK_LIT,
    },
    "g3_sci": {
        "label": "ثالث علمي",
        "hint": "الصف الثالث — المسار العلمي.",
        "match": lambda u, ctx: _is_student(u) and _grade(u) == 3 and _track(u) == TRACK_SCI,
    },
    "g3_lit": {
        "label": "ثالث أدبي",
        "hint": "الصف الثالث — المسار الأدبي.",
        "match": lambda u, ctx: _is_student(u) and _grade(u) == 3 and _track(u) == TRACK_LIT,
    },
    "active": {
        "label": "النشطون",
        "hint": f"سأل خلال آخر {ACTIVE_WINDOW_DAYS} أيام.",
        "match": lambda u, ctx: ctx.get("recent_asks", {}).get(u["uid"], 0) > 0,
    },
    "inactive": {
        "label": "غير النشطين",
        "hint": f"لم يسأل منذ {INACTIVE_WINDOW_DAYS} يوماً أو أكثر.",
        "match": lambda u, ctx: ctx.get("stale_asks", {}).get(u["uid"], 0) == 0,
    },
    "banned": {
        "label": "المحظورون",
        "hint": "الحسابات الموقوفة.",
        "match": lambda u, ctx: u.get("banned") is True,
    },
    "admins": {
        "label": "المديرون",
        "hint": "أصحاب صلاحية الإدارة.",
        "match": lambda u, ctx: u.get("role") == "admin",
    },
}

# 🔐 الشرائح التي تصلح **قاعدةَ وصول**: ثابتةٌ في المستخدم لا متغيّرة بنشاطه.
#    ⚠️ «غير نشط» شريحةٌ متغيّرة كل يوم — إخفاء قسمٍ بها يعني قسماً يظهر
#       ويختفي بلا سببٍ يفهمه الطالب، فهي مسموحة للإشعار لا للإخفاء.
#    🎭 و«المعلمون» منها: الدور ثابتٌ في المستند لا يتقلّب بنشاطٍ يومي،
#       فتستطيع اللوحة أن تقول «أظهر قسم المعلم للمعلمين وحدهم» —
#       وهو الحارس الخادميّ المقابل لفصل الواجهات في التطبيق.
ACCESS_SEGMENTS = ("all", "students", "teachers", "g1", "g2", "g3",
                   "g2_sci", "g2_lit", "g3_sci", "g3_lit")


def label(key: str) -> str:
    seg = SEGMENTS.get(key)
    return seg["label"] if seg else key


def describe_all() -> list:
    """قائمة الشرائح للوحة — مفتاحاً ووصفاً وهل تصلح قاعدةَ وصول."""
    return [{"key": k, "label": v["label"], "hint": v["hint"],
             "access_ok": k in ACCESS_SEGMENTS}
            for k, v in SEGMENTS.items()]


def validate(key: str, *, for_access: bool = False) -> str:
    """يتحقق من الشريحة ويعيدها — أو يرمي خطأً عربياً."""
    key = str(key or "").strip()
    if key not in SEGMENTS:
        raise AudienceError(f"❌ شريحة غير معروفة: «{key}».")
    if for_access and key not in ACCESS_SEGMENTS:
        raise AudienceError(
            f"❌ «{label(key)}» شريحة متغيّرة بالنشاط، ولا تصلح قاعدةَ إخفاء — "
            "القسم سيظهر ويختفي بلا سبب يفهمه الطالب.")
    return key


def matches(key: str, user: dict, ctx: dict | None = None) -> bool:
    """هل ينتمي هذا المستخدم لهذه الشريحة؟"""
    seg = SEGMENTS.get(key)
    if not seg:
        return False
    try:
        return bool(seg["match"](user, ctx or {}))
    except Exception:
        return False


def matches_profile(key: str, grade, track, role: str = "student") -> bool:
    """نسخةٌ خفيفة تكفي **قواعدَ الوصول**: لا تحتاج نشاطاً ولا Firestore.

    ⭐ يستدعيها التطبيق في كل إقلاع عبر `/app/access` — فلا يجوز أن تقرأ
       مجموعةَ الاستخدام كلها لتجيب «هل هذا الطالب ثالث علمي؟».
    """
    if key not in ACCESS_SEGMENTS:
        return False
    user = {"uid": "", "grade": grade if isinstance(grade, int) else None,
            "track": str(track or ""), "role": role or "student"}
    return matches(key, user, {})


# ══════════════ سياق النشاط ══════════════

def _day(offset: int = 0) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=offset)).strftime("%Y-%m-%d")


def build_context(daily: dict) -> dict:
    """يبني ما تحتاجه شرائح النشاط من خريطة الاستخدام `{uid: {يوم: عدد}}`.

    ⚠️ يُحسب **مرّةً واحدةً** ويُمرَّر لكل مطابقة — لا مرّةً لكل مستخدم:
       ألف مستخدمٍ × مسحٍ كاملٍ للاستخدام = ألف مسحٍ لبيانات واحدة.
    """
    recent_cut = _day(ACTIVE_WINDOW_DAYS - 1)
    stale_cut = _day(INACTIVE_WINDOW_DAYS - 1)
    recent, stale = {}, {}
    for uid, per in (daily or {}).items():
        recent[uid] = sum(n for day, n in per.items() if day >= recent_cut)
        stale[uid] = sum(n for day, n in per.items() if day >= stale_cut)
    return {"recent_asks": recent, "stale_asks": stale}


def filter_users(users: list, key: str, ctx: dict | None = None) -> list:
    """يصفّي قائمة مستخدمين بشريحة — لا يرمي على شريحةٍ فارغة (فراغٌ نتيجةٌ)."""
    if key in (None, "", "all"):
        return list(users)
    return [u for u in users if matches(key, u, ctx)]
