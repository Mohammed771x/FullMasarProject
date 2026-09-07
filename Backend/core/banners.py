# ==================================================
# 🎏 core/banners.py — بانرات الأقسام (Firestore) وقوالبها التلقائية
# ==================================================
# ⭐ نفس القاعدة الذهبية: البانر محتوى متغيّر يُدار من اللوحة ويصل الطالب
#    **بلا تحديث للتطبيق**. لا قائمة بانرات في كود التطبيق إطلاقاً.
#
# البانرات ثلاثة أنواع، ولكلٍّ سببُ وجوده:
#
#   ١) 📌 **يدوي** (`banners/{id}`) — يكتبه الأدمن حرفاً حرفاً. للإعلانات
#      التي لا يعرفها النظام: خدمة جديدة، إعلان موسمي، تنبيه.
#
#   ٢) 🤖 **تلقائي من المنح** — لا يُخزَّن أبداً، يُولَّد عند القراءة من حالة
#      المنح نفسها (تفتح قريباً · مفتوحة الآن · على وشك الإغلاق). سببه أن
#      حالة المنحة **تتغيّر بالتقويم لا بكتابة أحد**: منحةٌ تقفل غداً يجب أن
#      يظهر بانرها اليوم بلا أن يتذكّر الأدمن شيئاً. نصّه من قوالب في
#      `config/banner_templates` — فيبقى قابلاً للتحرير بلا نشر كود.
#
#   ٣) 🎯 **شخصي** — يُبنى في **التطبيق** لا هنا، لأن نتائج «اختبر نفسك»
#      تعيش في Hive على الجهاز ولا تُرفع. رفعُها للخادم ليصنع بانراً واحداً
#      مقايضةٌ خاسرة: بيانات أكثر، خصوصية أقل، وفائدة صفر.
#
# 📉 **التوقيع بدل النسخة**: المنح تكفيها نسخةٌ تزيد عند الكتابة، أما البانر
#    التلقائي فيتغيّر **بمرور اليوم** بلا كتابة. لذلك التوقيع = النسخة + تاريخ
#    اليوم، فيلتقط الحالتين معاً ويبقى الرد فارغاً بقية الوقت.

import threading
import time
import uuid
from datetime import date, timedelta

from . import audience
from . import quota
from . import scholarships as sch_store

CACHE_TTL = 300

# الأقسام التي تعرض بانراً — أي قيمة أخرى تُرفض.
SECTIONS = (
    "home",          # الرئيسية
    "education",     # قسم التعليم
    "quiz",          # اختبر نفسك
    "scholarships",  # المنح
    "services",      # الخدمات
    "analysis",      # تحليل مستواي
    "teacher",       # مساعد المعلم
)

SECTION_LABELS = {
    "home": "الرئيسية",
    "education": "التعليم",
    "quiz": "اختبر نفسك",
    "scholarships": "المنح",
    "services": "الخدمات",
    "analysis": "تحليل مستواي",
    "teacher": "مساعد المعلم",
}

# ما يفعله النقر. القيمة تُفسَّر في التطبيق — والخادم يتحقق من النوع فقط.
ACTIONS = (
    "none",          # بلا وجهة
    "scholarship",   # value = معرّف المنحة
    "scholarships",  # قائمة المنح
    "education",     # قسم التعليم (value = المادة اختياراً)
    "quiz",          # اختبر نفسك
    "analysis",      # تحليل مستواي
    "teacher",       # مساعد المعلم
    "services",      # الخدمات
    "url",           # value = رابط خارجي
)

# 🎨 أيقونات مسموحة — القائمة نفسها في التطبيق. الحصر مقصود: اسمٌ حرّ يعني
#    أيقونة مفقودة على شاشة الطالب، ولا سبيل لاكتشافها من اللوحة.
ICONS = (
    "flight", "school", "explore", "handshake", "book", "quiz",
    "chart", "teacher", "star", "fire", "gift", "clock", "bell",
    "rocket", "target", "trophy",
)

MAX_TITLE = 60
MAX_SUBTITLE = 90
MAX_VALUE = 500
MAX_BANNERS = 60

_HEX_RE = sch_store._HEX_RE
_DATE_RE = sch_store._DATE_RE


class BannerError(Exception):
    """خطأ برسالة عربية جاهزة للعرض في اللوحة."""


def _db():
    db = quota._firestore()
    if db is None:
        raise BannerError("⚠️ Firestore غير متاح على الخادم.")
    return db


def available() -> bool:
    return quota._firestore() is not None


# ══════════════ التحقق ══════════════

def _text(value, limit: int) -> str:
    return str(value or "").strip()[:limit]


def _colors(value):
    """لونان يصنعان التدرّج. الناقص يُكمَّل بلون الهوية لا يُرفض الطلب."""
    default = ["#3B82F6", "#1D4ED8"]
    if not isinstance(value, (list, tuple)):
        return default
    out = [c for c in (str(x).strip() for x in value) if _HEX_RE.match(c)]
    if not out:
        return default
    return (out + out)[:2]


def validate(payload: dict) -> dict:
    """يطبّع حقول البانر ويرمي `BannerError` برسالة عربية عند الخطأ."""
    section = str(payload.get("section") or "home").strip()
    if section not in SECTIONS:
        raise BannerError(f"⚠️ قسم غير معروف: {section}")

    title = _text(payload.get("title"), MAX_TITLE)
    if not title:
        raise BannerError("⚠️ عنوان البانر مطلوب.")

    action = str(payload.get("action") or "none").strip()
    if action not in ACTIONS:
        raise BannerError(f"⚠️ إجراء غير معروف: {action}")

    icon = str(payload.get("icon") or "star").strip()
    if icon not in ICONS:
        icon = "star"

    for key in ("start_date", "end_date"):
        raw = _text(payload.get(key), 10)
        if raw and not _DATE_RE.match(raw):
            raise BannerError("⚠️ التاريخ بصيغة YYYY-MM-DD.")

    # 🎯 الفئة المستهدفة — بنفس تعريف [audience] لا بقائمةٍ ثانية هنا.
    #    والشرائح المسموحة هي شرائح **الوصول** وحدها: بانرٌ يظهر ويختفي
    #    بنشاط الطالب اليومي ضوضاءٌ لا رسالة.
    segment = str(payload.get("segment") or "all").strip() or "all"
    if segment not in audience.ACCESS_SEGMENTS:
        raise BannerError(f"⚠️ فئة غير صالحة للاستهداف: {segment}")

    return {
        "section": section,
        "segment": segment,
        "title": title,
        "subtitle": _text(payload.get("subtitle"), MAX_SUBTITLE),
        "icon": icon,
        "colors": _colors(payload.get("colors")),
        "action": action,
        "action_value": _text(payload.get("action_value"), MAX_VALUE),
        "enabled": bool(payload.get("enabled", True)),
        "order": int(payload.get("order") or 0),
        # نافذة العرض — الفراغ يعني «بلا حدّ».
        "start_date": _text(payload.get("start_date"), 10),
        "end_date": _text(payload.get("end_date"), 10),
    }


def _in_window(item: dict, today: str) -> bool:
    """هل البانر داخل نافذته الزمنية اليوم؟"""
    start = item.get("start_date") or ""
    end = item.get("end_date") or ""
    if start and today < start:
        return False
    if end and today > end:
        return False
    return True


# ══════════════ القوالب التلقائية ══════════════
# ⚠️ النصوص هنا **افتراضاتٌ أولى** لا ثوابت: أول فتح للوحة يكتبها في
#    `config/banner_templates` فتصير قابلة للتحرير. الكود لا يفرضها بعدها.
DEFAULT_TEMPLATES = {
    "sch_open": {
        "enabled": True,
        "title": "{name} فتحت أبوابها! 🎉",
        "subtitle": "التقديم مفتوح الآن — لا تفوّت الفرصة",
        "icon": "flight",
        "colors": ["#10B981", "#065F46"],
    },
    "sch_closing": {
        "enabled": True,
        "days_before": 14,
        "title": "⏳ {name} تقفل بعد {days} يوم",
        "subtitle": "قدّم اليوم قبل أن يُغلق الباب",
        "icon": "clock",
        "colors": ["#EF4444", "#991B1B"],
    },
    "sch_soon": {
        "enabled": True,
        "days_before": 30,
        "title": "قريباً: {name}",
        "subtitle": "تفتح بعد {days} يوم — جهّز أوراقك من الآن",
        "icon": "bell",
        "colors": ["#8B5CF6", "#6D28D9"],
    },
}


def get_templates(force: bool = False) -> dict:
    """قوالب البانر التلقائي — الافتراضات مدموجةً مع ما حرّره الأدمن."""
    merged = {k: dict(v) for k, v in DEFAULT_TEMPLATES.items()}
    try:
        snap = _db().collection("config").document("banner_templates").get()
        saved = (snap.to_dict() or {}) if snap.exists else {}
    except Exception:
        return merged
    for key, value in saved.items():
        if key in merged and isinstance(value, dict):
            merged[key].update(value)
    return merged


def set_templates(payload: dict) -> dict:
    """يحفظ القوالب المحرَّرة. المفاتيح المجهولة تُتجاهل بصمت."""
    clean = {}
    for key, tpl in (payload or {}).items():
        if key not in DEFAULT_TEMPLATES or not isinstance(tpl, dict):
            continue
        entry = {
            "enabled": bool(tpl.get("enabled", True)),
            "title": _text(tpl.get("title"), MAX_TITLE),
            "subtitle": _text(tpl.get("subtitle"), MAX_SUBTITLE),
            "icon": tpl.get("icon") if tpl.get("icon") in ICONS else "star",
            "colors": _colors(tpl.get("colors")),
        }
        if "days_before" in DEFAULT_TEMPLATES[key]:
            entry["days_before"] = max(1, min(120, int(tpl.get("days_before") or 14)))
        clean[key] = entry

    _db().collection("config").document("banner_templates").set(clean, merge=True)
    bump_version()
    return get_templates(force=True)


def _fill(template: dict, **values) -> dict:
    """يملأ `{name}` و`{days}` — ويترك ما لم يُعرَّف كما هو بلا انهيار."""
    def fmt(text: str) -> str:
        out = str(text or "")
        for key, value in values.items():
            out = out.replace("{" + key + "}", str(value))
        return out

    return {"title": fmt(template.get("title")),
            "subtitle": fmt(template.get("subtitle"))}


def auto_banners(today: str = "") -> list:
    """🤖 بانرات مُولَّدة من حالة المنح — تُحسب ولا تُخزَّن.

    ⚠️ ترتيب الفحص مقصود: **الإغلاق الوشيك أولاً**. منحةٌ مفتوحة وتقفل بعد
       ثلاثة أيام رسالتُها العاجلة «تقفل» لا «مفتوحة»، ولو ولّدنا الاثنين
       لتنافسا على انتباه الطالب وأضعف كلٌّ منهما الآخر.
    """
    today = today or date.today().isoformat()
    templates = get_templates()
    out = []

    try:
        items = sch_store.list_public()["items"]
    except Exception:
        return out

    for sch in items:
        name = sch.get("name") or ""
        sch_id = sch.get("id") or ""
        if not name or not sch_id:
            continue

        # ⚠️ نحسب الحالة من التواريخ ولا نأخذ `status` الجاهزة: تلك محسوبة
        #    بتاريخ **اليوم الحقيقي** داخل `_decorate`، فتتجاهل `today`
        #    المُمرَّرة — وهو ما يجعل الاختبار الزمني بلا معنى، وأخطر منه أن
        #    كاش المنح قد يحمل حالة أمسٍ بعد منتصف الليل.
        status = sch_store.compute_status(
            sch.get("open_date", ""), sch.get("close_date", ""), today)

        key, days = None, 0
        if status == "open":
            left = sch_store.days_left(sch.get("close_date", ""), today)
            closing = templates.get("sch_closing", {})
            if left > 0 and left <= int(closing.get("days_before") or 14):
                key, days = "sch_closing", left
            else:
                key = "sch_open"
        elif status == "soon":
            soon = templates.get("sch_soon", {})
            until = _days_until(sch.get("open_date", ""), today)
            if until > 0 and until <= int(soon.get("days_before") or 30):
                key, days = "sch_soon", until

        if not key:
            continue
        tpl = templates.get(key) or {}
        if not tpl.get("enabled", True):
            continue

        filled = _fill(tpl, name=name, days=days)
        out.append({
            "id": f"auto:{key}:{sch_id}",
            "section": "home",
            "title": filled["title"],
            "subtitle": filled["subtitle"],
            "icon": tpl.get("icon") or "star",
            "colors": _colors(tpl.get("colors")),
            "action": "scholarship",
            "action_value": sch_id,
            "enabled": True,
            # 🤖 يلي اليدويّ دائماً: ما كتبه الأدمن بيده أولى بالصدارة.
            "order": 1000 + len(out),
            "auto": True,
        })

    return out


def _days_until(target: str, today: str) -> int:
    """كم يوماً حتى تاريخٍ قادم؟ صفر لو مضى أو كان فارغاً/تالفاً."""
    if not target or not _DATE_RE.match(target):
        return 0
    try:
        delta = date.fromisoformat(target) - date.fromisoformat(today)
    except ValueError:
        return 0
    return max(0, delta.days)


# ══════════════ النسخة والكاش ══════════════

def get_version() -> int:
    try:
        snap = _db().collection("config").document("meta").get()
        return int((snap.to_dict() or {}).get("banners_version", 0) or 0)
    except BannerError:
        raise
    except Exception:
        return 0


def bump_version() -> int:
    from firebase_admin import firestore as fs
    ref = _db().collection("config").document("meta")
    ref.set({"banners_version": fs.Increment(1),
             "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
    _invalidate_cache()
    try:
        return int((ref.get().to_dict() or {}).get("banners_version", 0) or 0)
    except Exception:
        return 0


def signature(today: str = "", grade=None, track: str = "") -> str:
    """بصمة ما يراه الطالب: النسخة + اليوم + صفّه ومساره.

    ⭐ اليوم جزءٌ منها لأن البانر التلقائي يتغيّر بالتقويم وحده — «تقفل بعد
       ٥ أيام» تصير «٤» غداً بلا أن يكتب أحد شيئاً. النسخة وحدها تفوّت ذلك.
    ⚠️ والصفّ جزءٌ منها منذ صار الاستهداف بالفئة: طالبٌ يصحّح صفّه من الأول
       إلى الثالث تبقى بصمتُه كما هي، فيظلّ يرى بانرات الأول ولا يفهم لماذا.
    """
    who = f"{grade if grade is not None else '-'}:{track or '-'}"
    return f"{get_version()}:{today or date.today().isoformat()}:{who}"


_lock = threading.Lock()
_cache = {"items": None, "ts": 0.0}


def _invalidate_cache():
    with _lock:
        _cache["items"] = None
        _cache["ts"] = 0.0


def reset_cache():
    """للاختبارات — ومعها كاش المنح، فالبانر التلقائي يقرأ منه."""
    _invalidate_cache()
    sch_store.reset_cache()


def _load_all(force: bool = False) -> list:
    now = time.time()
    with _lock:
        if not force and _cache["items"] is not None and now - _cache["ts"] < CACHE_TTL:
            return _cache["items"]

    items = []
    for doc in _db().collection("banners").stream():
        data = doc.to_dict() or {}
        data["id"] = doc.id
        data.setdefault("auto", False)
        items.append(data)
    items.sort(key=lambda b: (int(b.get("order") or 0), b.get("id") or ""))

    with _lock:
        _cache["items"] = items
        _cache["ts"] = time.time()
    return items


# ══════════════ واجهة الطالب ══════════════

def list_public(client_signature: str = "", today: str = "",
                grade=None, track: str = "") -> dict:
    """بانرات كل الأقسام مجموعةً في رد واحد.

    ⭐ **رد واحد لكل الأقسام** لا طلب لكل شاشة: الحمولة كلها ~٢ كيلوبايت،
       وطلبٌ واحد عند فتح التطبيق أرخص من سبعة عند تنقّل الطالب.

    🎯 و`grade`/`track` **اختياريان عمداً**: التطبيق القديم لا يرسلهما فيصله
       كل شيء كما كان (لا كسر)، والحقل `segment` يرافق كل بانر في الرد
       فيستطيع التطبيق تصفيتَه بنفسه ريثما يُحدَّث نداؤه.
    """
    today = today or date.today().isoformat()
    sig = signature(today, grade, track)
    if client_signature and client_signature == sig:
        return {"changed": False, "signature": sig, "sections": {}}

    items = [b for b in _load_all()
             if b.get("enabled") is not False and _in_window(b, today)
             and _targets(b, grade, track)]
    items += auto_banners(today)

    sections = {name: [] for name in SECTIONS}
    for b in items:
        section = b.get("section")
        if section in sections:
            sections[section].append(_public_view(b))
    for name in sections:
        sections[name].sort(key=lambda b: int(b.get("order") or 0))

    return {"changed": True, "signature": sig, "sections": sections}


def _targets(b: dict, grade, track: str) -> bool:
    """هل هذا البانر موجَّهٌ لهذا الطالب؟

    ⚠️ بلا صفٍّ معروف **يُعرَض** لا يُخفى: التطبيق القديم لا يرسل صفّه،
       وإخفاءُ بانراتٍ عنه لأنه لم يُحدَّث عقوبةٌ لا استهداف.
    """
    segment = b.get("segment") or "all"
    if segment == "all" or grade is None:
        return True
    return audience.matches_profile(segment, grade, track)


def _public_view(b: dict) -> dict:
    """ما يراه الطالب — بلا حقول الإدارة (النافذة الزمنية والتفعيل)."""
    return {
        "id": b.get("id") or "",
        # 🎯 تُرسَل ليصفّي التطبيق بنفسه حين لا يُرسل صفّه في النداء.
        "segment": b.get("segment") or "all",
        "title": b.get("title") or "",
        "subtitle": b.get("subtitle") or "",
        "icon": b.get("icon") or "star",
        "colors": _colors(b.get("colors")),
        "action": b.get("action") or "none",
        "action_value": b.get("action_value") or "",
        "order": int(b.get("order") or 0),
        "auto": bool(b.get("auto")),
    }


# ══════════════ واجهة اللوحة ══════════════

def list_admin() -> dict:
    items = _load_all(force=True)
    return {
        "items": items,
        "auto_preview": auto_banners(),
        "version": get_version(),
        "sections": [{"key": k, "label": SECTION_LABELS[k]} for k in SECTIONS],
        "icons": list(ICONS),
        "actions": list(ACTIONS),
        "segments": [sg for sg in audience.describe_all() if sg["access_ok"]],
        "templates": get_templates(),
    }


def create(payload: dict) -> dict:
    if len(_load_all(force=True)) >= MAX_BANNERS:
        raise BannerError(f"⚠️ بلغتَ الحدّ الأقصى ({MAX_BANNERS} بانراً). "
                          "احذف بانراً قديماً أولاً.")
    clean = validate(payload)
    # ⚠️ نولّد المعرّف بأنفسنا لا بـ`document()` الفارغة: المعرّف عندها يأتي
    #    من مكتبة العميل، ونحن نريده مستقلاً عنها وقابلاً للاختبار.
    banner_id = f"bn_{uuid.uuid4().hex[:12]}"
    _db().collection("banners").document(banner_id).set(clean)
    bump_version()
    return {**clean, "id": banner_id, "auto": False}


def update(banner_id: str, payload: dict) -> dict:
    clean = validate(payload)
    ref = _db().collection("banners").document(banner_id)
    if not ref.get().exists:
        raise BannerError("⚠️ البانر غير موجود — لعلّه حُذف من نافذة أخرى.")
    ref.set(clean)
    bump_version()
    return {**clean, "id": banner_id, "auto": False}


def set_enabled(banner_id: str, enabled: bool) -> dict:
    ref = _db().collection("banners").document(banner_id)
    if not ref.get().exists:
        raise BannerError("⚠️ البانر غير موجود.")
    ref.set({"enabled": bool(enabled)}, merge=True)
    bump_version()
    return {"id": banner_id, "enabled": bool(enabled)}


def delete(banner_id: str) -> dict:
    _db().collection("banners").document(banner_id).delete()
    bump_version()
    return {"deleted": banner_id}
