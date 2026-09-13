# ==================================================
# 🔐 core/access.py — التحكم بظهور الأقسام (قواعدُ لا كود)
# ==================================================
# «أخفِ المنح عن الأول والثاني» · «عطّل التعليم مؤقتاً» · «أظهر الخدمات
# برسالة قريباً» — كلها قواعد تُكتب من اللوحة وتسري **بلا إصدار تطبيق**.
#
# ⭐ **الحماية في الخادم لا في إخفاء الزر.** إخفاء القسم في التطبيق راحةٌ
#    للطالب، لا حاجز. من يعرف الرابط يتخطّى واجهةً مخفيّة في ثانية. لذلك
#    القاعدة تُفرض هنا على **المسار نفسه** (`require`)، والتطبيق يقرأ
#    `/app/access` ليُخفي ما لن يعمل أصلاً — فلا يرى الطالبُ زرّاً يفشل.
#
# 🥇 **الأولوية معلنة وواحدة، فلا تعارض ولا سلوكٌ غامض:**
#      ١) تعطيلٌ عامّ للقسم        ← يعلو على كل شيء، بلا استثناء
#      ٢) قاعدةُ الشريحة الأخصّ    ← «ثالث علمي» تغلب «الصف الثالث»
#         تغلب «الطلاب» تغلب «الجميع»
#      ٣) وعند تساوي الخصوصية      ← الأشدّ يغلب (off > soon > on)
#      ٤) وإن لم تُطابق قاعدة      ← مسموح
#    ⚠️ القاعدة (٣) ليست تفصيلاً: بدونها تصير النتيجة تابعةً لترتيب القواعد
#       في المستند — فيغيّر الأدمن ترتيباً لا معنى له عنده فينقلب السلوك.
#
# 🛟 **ويفشل مفتوحاً**: تعذُّرُ قراءة القواعد لا يجوز أن يُغلق المنصّة على
#    الطلاب. عطلُ Firestore يعطّل *الإخفاء*، لا *الخدمة*.

import threading
import time

from . import audience
from . import quota

CACHE_TTL = 300
DOC = "access_rules"

# الأقسام القابلة للتحكم — نفس مفاتيح البانرات ([banners.SECTIONS]) بلا
# «الرئيسية»: إخفاؤها إخفاءٌ للتطبيق نفسه، وهو ما لا يريده أحد.
#
# 👨‍🏫 **و«مساعد المعلم» خرج من هنا (2026-09-07 — قرار المالك):** لم يعد
#    قسماً *داخل* تطبيق الطالب بل صار **تطبيق المعلّم كلَّه** ([35§3]):
#    الطالب لا يراه أصلاً، والمعلّم لا يرى غيره. فقاعدةُ إخفاءٍ عليه
#    ليست عديمة المعنى فحسب — بل **فخٌّ**: «أخفِ مساعد المعلم» كانت
#    تُفرغ تطبيق كل معلّمٍ من محتواه ولا تترك له شاشةً واحدة يفتحها.
#
# ⚠️ وحذفه من هنا **آمنٌ بالبناء**: `_merge` يتجاهل المفاتيح المخزَّنة التي
#    لا يعرفها الكود، و`state_of` تُرجع «مفتوح» لأي قسمٍ غير معروف.
SECTIONS = {
    "education":    "📚 التعليم",
    "quiz":         "🧠 اختبر نفسك",
    "analysis":     "📊 تحليل مستواي",
    "scholarships": "🎓 المنح",
    "services":     "🛠️ الخدمات",
}

MODES = {
    "on":   "مفتوح",
    "soon": "يظهر مع «قريباً»",
    "off":  "مُخفى تماماً",
}

DEFAULT_SOON = "🚧 هذا القسم قيد التجهيز — سيفتح قريباً بإذن الله."
DEFAULT_OFF = "🔒 هذا القسم غير متاح لحسابك حالياً."
MAX_MESSAGE = 160
MAX_RULES = 12          # لكل قسم — أكثر من ذلك لوحةٌ لا يفهمها أحد

# 🥇 الخصوصية: الأكبر يغلب. القيم متباعدة عمداً كي يبقى للإدراج مكان.
_SPECIFICITY = {
    "g2_sci": 40, "g2_lit": 40, "g3_sci": 40, "g3_lit": 40,
    "g1": 30, "g2": 30, "g3": 30,
    # 🎭 «المعلمون» و«الطلاب» في مرتبةٍ واحدة: شريحتان متنافيتان لا تتقاطعان،
    #    فلا يقع بينهما تنازعٌ يحتاج ترجيحاً — والدرجة تفصلهما عن «الجميع» فقط.
    "students": 20, "teachers": 20,
    "all": 10,
}
_SEVERITY = {"off": 3, "soon": 2, "on": 1}

_lock = threading.Lock()
_cache = {"data": None, "ts": 0.0}


class AccessError(Exception):
    """خطأ برسالة عربية جاهزة للعرض في اللوحة."""


class SectionBlocked(Exception):
    """القسم مقفل على هذا المستخدم — الرسالة جاهزة للعرض للطالب."""

    def __init__(self, message: str, mode: str = "off"):
        super().__init__(message)
        self.mode = mode


def _db():
    db = quota._firestore()
    if db is None:
        raise AccessError("⚠️ Firestore غير متاح على الخادم — لا يمكن حفظ قواعد الوصول.")
    return db


# ══════════════ التخزين ══════════════

def _blank() -> dict:
    return {key: {"mode": "on", "message": "", "rules": []} for key in SECTIONS}


def load(force: bool = False) -> dict:
    """القواعد المخزَّنة — أو الافتراضي (كل شيء مفتوح) عند أي تعذُّر."""
    now = time.time()
    with _lock:
        if not force and _cache["data"] is not None and now - _cache["ts"] < CACHE_TTL:
            return _copy(_cache["data"])
    try:
        snap = quota._firestore().collection("config").document(DOC).get()
        stored = (snap.to_dict() or {}).get("sections", {}) if snap.exists else {}
    except Exception:
        return _blank()          # 🛟 فشلٌ مفتوح: لا قواعد ⇒ لا إخفاء
    data = _merge(stored)
    with _lock:
        _cache["data"] = _copy(data)
        _cache["ts"] = time.time()
    return data


def _copy(data: dict) -> dict:
    return {k: {"mode": v["mode"], "message": v["message"],
                "rules": [dict(r) for r in v["rules"]]} for k, v in data.items()}


def _merge(stored: dict) -> dict:
    """يدمج المخزَّن على الافتراضي — فقسمٌ أُضيف للكود يظهر مفتوحاً بلا هجرة."""
    out = _blank()
    for key, value in (stored or {}).items():
        if key not in out or not isinstance(value, dict):
            continue          # مفتاحٌ قديمٌ حُذف من الكود يُتجاهل بصمت
        out[key] = {
            "mode": value.get("mode") if value.get("mode") in MODES else "on",
            "message": str(value.get("message") or "")[:MAX_MESSAGE],
            "rules": [r for r in (_clean_rule(x) for x in (value.get("rules") or [])) if r],
        }
    return out


def _clean_rule(raw):
    if not isinstance(raw, dict):
        return None
    seg = str(raw.get("segment") or "")
    if seg not in audience.ACCESS_SEGMENTS:
        return None
    mode = raw.get("mode") if raw.get("mode") in MODES else "off"
    return {"segment": seg, "mode": mode,
            "message": str(raw.get("message") or "")[:MAX_MESSAGE]}


def invalidate():
    with _lock:
        _cache["data"] = None
        _cache["ts"] = 0.0


# ══════════════ الحلّ ══════════════

def _decide(section: dict, grade, track, role: str) -> dict:
    """قرارُ قسمٍ واحدٍ لملفٍّ واحد — بالأولوية المعلنة أعلاه حرفياً."""
    # ١) التعطيل العام يعلو على كل قاعدة.
    if section["mode"] != "on":
        return _verdict(section["mode"], section["message"], "عام")

    # ٢) و٣) الأخصّ ثم الأشدّ.
    best = None
    for rule in section["rules"]:
        if not audience.matches_profile(rule["segment"], grade, track, role):
            continue
        rank = (_SPECIFICITY.get(rule["segment"], 0), _SEVERITY.get(rule["mode"], 0))
        if best is None or rank > best[0]:
            best = (rank, rule)

    if best is None:
        return _verdict("on", "", "")
    rule = best[1]
    return _verdict(rule["mode"], rule["message"], audience.label(rule["segment"]))


def _verdict(mode: str, message: str, source: str) -> dict:
    text = message.strip()
    if not text and mode == "soon":
        text = DEFAULT_SOON
    elif not text and mode == "off":
        text = DEFAULT_OFF
    return {
        "mode": mode,
        # 👁️ «ظاهر» يشمل `soon`: القسم يُرى ويُقرأ عنوانه، لكنه لا يُفتح.
        "visible": mode != "off",
        "usable": mode == "on",
        "message": text if mode != "on" else "",
        "reason": source,
    }


def resolve(grade=None, track: str = "", role: str = "student") -> dict:
    """حالةُ كل الأقسام لملفٍّ واحد — هذا ما يقرأه التطبيق في كل إقلاع."""
    rules = load()
    return {key: _decide(rules[key], grade, track, role) for key in SECTIONS}


def state_of(section: str, grade=None, track: str = "", role: str = "student") -> dict:
    """حالةُ قسمٍ بعينه. قسمٌ غير معروف = مفتوح (لا نُقفل ما لا نعرفه)."""
    if section not in SECTIONS:
        return _verdict("on", "", "")
    return _decide(load()[section], grade, track, role)


def require(section: str, grade=None, track: str = "", role: str = "student"):
    """🛡️ الحارس الحقيقي — يُنادى **في المسار** لا في الواجهة.

    ⚠️ ويفشل مفتوحاً بحكم `load()`: عطلٌ في قراءة القواعد يعطّل الإخفاء،
       ولا يجوز أن يعطّل الدراسة.
    """
    if role == "admin":
        return          # المدير يعاين ما أخفاه — وإلا عطّل نفسه عن الفحص
    verdict = state_of(section, grade, track, role)
    if not verdict["usable"]:
        raise SectionBlocked(verdict["message"], verdict["mode"])


# ══════════════ ملفّ المستخدم (للفرض في المسارات) ══════════════
# ⭐ **لماذا لا نصدّق الصفَّ القادم في الطلب؟** لأن إخفاء قسمٍ عن الأول
#    يصير بلا معنى إن كفى الطالبَ أن يكتب `grade: 3` في طلبه. المرجع هو
#    `users/{uid}.grade` الذي كتبه التطبيق عند التسجيل، لا ما يقوله الطلب.
# 💰 وبكاشٍ قصير: قراءةٌ لكل طلبٍ ثمنٌ لا يُدفع لأجل قاعدة إخفاء.

_PROFILE_TTL = 120
_profiles: dict = {}


def profile_for(uid: str):
    """`{grade, track, role}` من مستند المستخدم — أو `None` إن تعذّر.

    ⚡ **مصدرٌ واحد لا ثلاثة:** كان هذا يقرأ `users/{uid}` بنفسه، بينما
       `admin.is_banned` و`quota._override_for` يقرآن **نفس المستند** في
       **نفس الطلب**. صارت الثلاثة تُغذَّى من `user_state` بقراءةٍ واحدة
       مُكاشة — والكاش هناك أقصر (٦٠ث بدل ١٢٠) فالحظر أسرع سرياناً لا أبطأ.
    """
    if not uid:
        return None
    from . import user_state
    state = user_state.get(uid)
    if not state.get("exists"):
        return None
    return {"grade": state["grade"], "track": state["track"], "role": state["role"]}


def forget_profile(uid: str = ""):
    """يُنادى بعد تغيير دور مستخدم أو صفّه — وبلا معرّف يمسح الكل."""
    from . import user_state
    with _lock:
        if uid:
            _profiles.pop(uid, None)
        else:
            _profiles.clear()
    # ⚠️ ولا يكفي مسحُ الكاش المحلي: مصدر الحقيقة صار `user_state`، ونسيانُ
    #    أحدهما دون الآخر يعني تحويلاً لا يسري وطالباً يظنّ الإعداد معطوباً.
    if uid:
        user_state.forget(uid)
    else:
        user_state.reset()


# ══════════════ الكتابة من اللوحة ══════════════

def list_admin() -> dict:
    """كل الأقسام بقواعدها + معجم الشرائح والأوضاع — نداءٌ واحد للوحة."""
    rules = load(force=True)
    out = []
    for key, label in SECTIONS.items():
        section = rules[key]
        out.append({
            "key": key,
            "label": label,
            "mode": section["mode"],
            "message": section["message"],
            "rules": [dict(r, segment_label=audience.label(r["segment"]))
                      for r in _sorted(section["rules"])],
            # 👁️ أثرٌ محسوب لا موصوف: ماذا يرى كلُّ صفٍّ فعلاً الآن؟
            "preview": _preview(section),
        })
    return {
        "sections": out,
        "modes": [{"key": k, "label": v} for k, v in MODES.items()],
        "segments": [s for s in audience.describe_all() if s["access_ok"]],
        "storage": quota._firestore() is not None,
    }


def _sorted(rules: list) -> list:
    """تُعرض بترتيب الأولوية الفعلي — فما يراه الأدمن أولاً هو ما يغلب."""
    return sorted(rules, key=lambda r: (-_SPECIFICITY.get(r["segment"], 0),
                                        -_SEVERITY.get(r["mode"], 0),
                                        r["segment"]))


_PREVIEW_PROFILES = (
    ("الأول", 1, audience.TRACK_GENERAL),
    ("ثاني علمي", 2, audience.TRACK_SCI),
    ("ثاني أدبي", 2, audience.TRACK_LIT),
    ("ثالث علمي", 3, audience.TRACK_SCI),
    ("ثالث أدبي", 3, audience.TRACK_LIT),
)


def _preview(section: dict) -> list:
    """⭐ يترجم القواعد إلى جملةٍ لكل صف — «ثالث علمي: مُخفى».

    بدونه يقرأ الأدمن قواعدَ متداخلةً ويخمّن أثرها، ثم يكتشف الخطأ من شكوى
    طالب. وبه يرى النتيجة قبل الحفظ.
    """
    return [{"label": name, "mode": _decide(section, grade, track, "student")["mode"]}
            for name, grade, track in _PREVIEW_PROFILES]


def set_section(section: str, mode: str, message: str = "") -> dict:
    """الوضع العام لقسم."""
    if section not in SECTIONS:
        raise AccessError(f"❌ قسم غير معروف: «{section}».")
    if mode not in MODES:
        raise AccessError(f"❌ وضع غير معروف: «{mode}».")
    data = load(force=True)
    data[section]["mode"] = mode
    data[section]["message"] = str(message or "").strip()[:MAX_MESSAGE]
    return _save(data, section)


def set_rules(section: str, rules: list) -> dict:
    """قواعد الشرائح لقسم — تُستبدل كاملةً (لا دمج: الدمج يخفي المحذوف)."""
    if section not in SECTIONS:
        raise AccessError(f"❌ قسم غير معروف: «{section}».")
    if len(rules or []) > MAX_RULES:
        raise AccessError(f"❌ أكثر من {MAX_RULES} قاعدة لقسمٍ واحد — بسّطها.")

    clean, seen = [], set()
    for raw in (rules or []):
        # ⚠️ يُعاد رميه بنوع هذا الملف: من ينادي `set_rules` لا يعرف [audience]
        #    ولا يجوز أن يُطالَب بالتقاط خطأِ وحدةٍ لم يستدعِها.
        try:
            seg = audience.validate((raw or {}).get("segment"), for_access=True)
        except audience.AudienceError as e:
            raise AccessError(str(e))
        if seg in seen:
            raise AccessError(
                f"❌ «{audience.label(seg)}» مكرّرة في هذا القسم — "
                "قاعدتان لشريحةٍ واحدة تجعلان السلوك غامضاً.")
        seen.add(seg)
        mode = (raw or {}).get("mode")
        if mode not in MODES:
            raise AccessError(f"❌ وضع غير معروف: «{mode}».")
        clean.append({"segment": seg, "mode": mode,
                      "message": str((raw or {}).get("message") or "").strip()[:MAX_MESSAGE]})

    data = load(force=True)
    data[section]["rules"] = clean
    return _save(data, section)


def _save(data: dict, section: str) -> dict:
    from firebase_admin import firestore as fs
    _db().collection("config").document(DOC).set(
        {"sections": data, "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
    invalidate()
    # ⚠️ ورفعُ نسخة المحتوى مقصود: التطبيق يعرف بالتغيير في الإقلاع التالي
    #    بنفس البروتوكول الذي يعرف به المنح والبانرات — لا بروتوكول ثانٍ.
    try:
        from . import scholarships
        scholarships.bump_version()
    except Exception:
        pass
    return {"section": section, **data[section], "preview": _preview(data[section])}
