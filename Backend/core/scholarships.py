# ==================================================
# 🎓 core/scholarships.py — مخزن المنح (Firestore) وبروتوكول النسخة
# ==================================================
# ⭐ **القاعدة الذهبية للمشروع:** المنح محتوى متغيّر يُدار من اللوحة ويصل
#    للطلاب فوراً **بلا تحديث للتطبيق** ([v3 §0]). لذلك لا قائمة منح في
#    الكود إطلاقاً — المصدر الوحيد مجموعتان في Firestore:
#
#      scholarships/{id}          ← بيانات المنحة (يقرؤها الطالب)
#      scholarship_prompts/{id} 🔒 ← برومبت مساعد المنحة (الباك وحده)
#
# 🔒 **لماذا مجموعتان لا واحدة؟** البرومبت هو «عقل» المساعد: بمعرفته يستطيع
#    الطالب التحايل عليه أو نسخه. وقواعد الأمان تمنع العميل من قراءة
#    `scholarship_prompts/` نهائياً، بينما تفتح `scholarships/` للقراءة.
#    الباك اند يقرأ الاثنين بـ Admin SDK الذي يتجاوز القواعد ([v3 §2]).
#
# 📉 **بروتوكول النسخة (config/meta.version):** أي كتابة من اللوحة على المنح
#    تزيد الرقم. التطبيق يرسل نسخته مع الطلب؛ إن لم تتغيّر رجع رد فارغ صغير
#    (`changed: false`) بلا نقل أي منحة — فطالبٌ يفتح التطبيق عشر مرات يومياً
#    ينقل القائمة **مرة واحدة** يوم تتغيّر فقط ([v3 §12]).
#
# 🗄️ **الكاش هنا (لا في العميل وحده):** قراءة Firestore واحدة كل 5 دقائق
#    مهما بلغ عدد الطلاب — فلا تتأثر الفاتورة بعدد المستخدمين أصلاً.

import re
import threading
import time
from datetime import date, datetime, timezone

from . import quota

# مدة كاش القراءة على الخادم (ثوانٍ) — نفس كاش البرومبتات في [v3 §3.3].
CACHE_TTL = 300

# سقوف دفاعية على ما يُكتب من اللوحة (تحمي مستند Firestore وشاشة الطالب معاً)
MAX_NAME = 120
MAX_SHORT_DESC = 200
MAX_ABOUT = 6000
MAX_LIST_ITEMS = 30
MAX_ITEM_CHARS = 500
MAX_PROMPT_CHARS = 8000
MAX_URL = 500

# 🖼️ سقف الغلاف. اللوحة تقصّه إلى 1200×675 وتضغطه، فالناتج عادةً
#    60–110 كيلوبايت. السقف هنا حارسٌ أخير لا هدف.
MAX_COVER_BYTES = 600_000
# 🏷️ الشعار مربّع صغير (512×512) — سقفه أقل بكثير من الغلاف.
MAX_LOGO_BYTES = 200_000

FUNDING_TYPES = ("full", "partial")
DEGREE_LEVELS = ("دبلوم", "بكالوريوس", "ماجستير", "دكتوراه")

# معرّف المستند: لاتيني وأرقام وشرطات فقط — يدخل في مسار Firestore.
_ID_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{1,63}$")
_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_HEX_RE = re.compile(r"^#[0-9A-Fa-f]{6}$")


class ScholarshipError(Exception):
    """خطأ برسالة عربية جاهزة للعرض في اللوحة أو التطبيق."""


# ══════════════ الوصول إلى Firestore ══════════════

def _db():
    db = quota._firestore()
    if db is None:
        raise ScholarshipError(
            "⚠️ Firestore غير متاح على الخادم — قسم المنح يحتاج "
            "FIREBASE_SERVICE_ACCOUNT_JSON للقراءة والكتابة.")
    return db


def available() -> bool:
    """هل يمكن خدمة المنح أصلاً؟ (تُستعمل لرد ودّي بدل خطأ 500)"""
    return quota._firestore() is not None


# ══════════════ التطبيع والتحقق ══════════════

def _text(value, limit: int) -> str:
    return str(value or "").strip()[:limit]


def _string_list(value, max_items=MAX_LIST_ITEMS, max_chars=MAX_ITEM_CHARS):
    """قائمة نصوص نظيفة: تُقصّ ولا تُرفض — سطر زائد لا يُفشل حفظ منحة."""
    if isinstance(value, str):
        value = [ln for ln in value.splitlines()]
    if not isinstance(value, (list, tuple)):
        return []
    out = []
    for item in value:
        text = str(item or "").strip()[:max_chars]
        if text:
            out.append(text)
        if len(out) >= max_items:
            break
    return out


def _date_or_empty(value) -> str:
    """التواريخ تُخزَّن نصاً `YYYY-MM-DD` — قابلة للفرز والمقارنة والعرض بلا مناطق زمنية."""
    text = str(value or "").strip()[:10]
    if not text:
        return ""
    if not _DATE_RE.match(text):
        raise ScholarshipError("❌ صيغة التاريخ يجب أن تكون YYYY-MM-DD.")
    try:
        datetime.strptime(text, "%Y-%m-%d")
    except ValueError:
        raise ScholarshipError(f"❌ تاريخ غير موجود: «{text}».")
    return text


def _gradient(value):
    """تدرّج لوني من لونين — يُستعمل في كرت المنحة وشاشتها."""
    colors = [c for c in (value or []) if isinstance(c, str) and _HEX_RE.match(c.strip())]
    return [c.strip().upper() for c in colors[:2]] if len(colors) >= 2 else []


def normalize_id(raw: str) -> str:
    """معرّف المنحة — يدخل في مسار Firestore، فيُفحص بصرامة."""
    value = str(raw or "").strip().lower()
    if not _ID_RE.match(value):
        raise ScholarshipError(
            "❌ معرّف المنحة يجب أن يكون حروفاً لاتينية صغيرة وأرقاماً "
            "وشرطات (2–64 حرفاً) — مثل «turkey» أو «qu-qatar».")
    return value


def validate(payload: dict) -> dict:
    """يحوّل ما تُرسله اللوحة إلى مستند Firestore صالح — أو يرمي برسالة عربية."""
    if not isinstance(payload, dict):
        raise ScholarshipError("❌ بيانات المنحة غير صالحة.")

    name = _text(payload.get("name"), MAX_NAME)
    if not name:
        raise ScholarshipError("❌ اسم المنحة مطلوب.")

    country = _text(payload.get("country"), 80)
    if not country:
        raise ScholarshipError("❌ الدولة مطلوبة.")

    funding = str(payload.get("funding_type") or "full").strip()
    if funding not in FUNDING_TYPES:
        raise ScholarshipError("❌ نوع التمويل يجب أن يكون «full» أو «partial».")

    open_date = _date_or_empty(payload.get("open_date"))
    close_date = _date_or_empty(payload.get("close_date"))
    # ⚠️ فحص الترتيب: تواريخ مقلوبة تجعل المنحة «مغلقة ويفتح قريباً» معاً،
    #    والطالب يرى شارة متناقضة لا يفهمها.
    if open_date and close_date and close_date < open_date:
        raise ScholarshipError("❌ تاريخ الإغلاق قبل تاريخ الفتح.")

    levels = [l for l in _string_list(payload.get("degree_levels"), 8, 40) if l in DEGREE_LEVELS]

    try:
        order = int(payload.get("order", 0) or 0)
    except (TypeError, ValueError):
        order = 0

    return {
        "name": name,
        "country": country,
        "flag": _text(payload.get("flag"), 8),
        "cover_url": _text(payload.get("cover_url"), MAX_URL),
        "logo_url": _text(payload.get("logo_url"), MAX_URL),
        "website": _text(payload.get("website"), MAX_URL),
        "short_desc": _text(payload.get("short_desc"), MAX_SHORT_DESC),
        "about": _text(payload.get("about"), MAX_ABOUT),
        "requirements": _string_list(payload.get("requirements")),
        "how_to_apply": _string_list(payload.get("how_to_apply")),
        "benefits": _string_list(payload.get("benefits")),
        "documents": _string_list(payload.get("documents")),
        "fields": _string_list(payload.get("fields"), 12, 60),
        "degree_levels": levels,
        "open_date": open_date,
        "close_date": close_date,
        "funding_type": funding,
        "gradient": _gradient(payload.get("gradient")),
        "enabled": payload.get("enabled") is not False,
        "order": max(0, min(order, 9999)),
    }


# ══════════════ الحالة (تُحسب لا تُخزَّن) ══════════════
# ⚠️ **لا يوجد حقل `status` في المستند إطلاقاً.** لو خُزّنت الحالة لاحتاجت
#    مهمة مجدولة تقلبها كل ليلة، ولصار عندنا منحة «مفتوحة» بعد إغلاقها.
#    الحساب من التاريخين هنا وفي التطبيق — نتيجة واحدة بلا مزامنة.

def compute_status(open_date: str, close_date: str, today: str = "") -> str:
    """`open` | `soon` | `closed` — ونصّها العربي في `STATUS_LABELS`."""
    today = today or date.today().isoformat()
    if open_date and today < open_date:
        return "soon"
    if close_date and today > close_date:
        return "closed"
    return "open"


STATUS_LABELS = {
    "open": "🟢 التقديم مفتوح",
    "soon": "🟡 يفتح قريباً",
    "closed": "🔴 مغلق حالياً",
}


def days_left(close_date: str, today: str = "") -> int:
    """الأيام حتى الإغلاق (سالب = مضى). -9999 حين لا تاريخ إغلاق."""
    if not close_date:
        return -9999
    today = today or date.today().isoformat()
    try:
        return (datetime.strptime(close_date, "%Y-%m-%d").date()
                - datetime.strptime(today, "%Y-%m-%d").date()).days
    except ValueError:
        return -9999


def _json_safe(value):
    """يحوّل ما لا يُسلسَل إلى JSON — وأهمّه طوابع Firestore.

    ⚠️ **علّة حقيقية لم يكشفها إلا Firestore الحقيقي:** `SERVER_TIMESTAMP`
       يعود من السحابة كائنَ `DatetimeWithNanoseconds`، و`json.dumps` يرفعه
       `TypeError` فيسقط المسار كله بـ500 — بينما المخزن المحلي في الاختبارات
       كان يخزّن نصاً فيمرّ. لذلك التطبيع هنا لا هناك.
    """
    if isinstance(value, (datetime, date)):
        return value.isoformat()
    if isinstance(value, dict):
        return {k: _json_safe(v) for k, v in value.items()}
    if isinstance(value, (list, tuple)):
        return [_json_safe(v) for v in value]
    # أي كائن وقت آخر يحمل isoformat (طوابع المزوّدين تختلف بالنوع لا بالواجهة)
    if hasattr(value, "isoformat"):
        try:
            return value.isoformat()
        except Exception:
            return str(value)
    return value


def _decorate(doc_id: str, data: dict) -> dict:
    """مستند خام → ما يراه العميل (بالحالة المحسوبة، وقابلاً للتسلسل)."""
    out = {k: _json_safe(v) for k, v in (data or {}).items()}
    out["id"] = doc_id
    out.pop("assistant_prompt", None)   # 🔒 حارس: لو تسرّب الحقل يوماً لمستند عام
    status = compute_status(out.get("open_date", ""), out.get("close_date", ""))
    out["status"] = status
    out["status_label"] = STATUS_LABELS[status]
    out["days_left"] = days_left(out.get("close_date", ""))
    return out


def sort_key(item: dict):
    """ترتيب العرض: `order` ثم المفتوح أولاً ثم الاسم."""
    rank = {"open": 0, "soon": 1, "closed": 2}.get(item.get("status", "open"), 3)
    return (item.get("order", 0), rank, item.get("name", ""))


# ══════════════ بروتوكول النسخة ══════════════

def get_version() -> int:
    """`config/meta.version` — رقم واحد يخبر التطبيق: هل تغيّر المحتوى؟"""
    try:
        snap = _db().collection("config").document("meta").get()
        value = (snap.to_dict() or {}).get("version", 0) if snap.exists else 0
        return int(value or 0)
    except ScholarshipError:
        raise
    except Exception:
        return 0


def bump_version() -> int:
    """يُستدعى بعد **كل** كتابة على المنح — وهو ما يجعل التطبيقات تعرف بالجديد.

    ⚠️ تعديلات `scholarship_prompts/` **لا تمرّ من هنا**: الطلاب لا يكيّشون
       البرومبتات أصلاً، والباك يلتقطها بكاشه خلال ≤5 دقائق ([06]).
    """
    from firebase_admin import firestore as fs
    db = _db()
    ref = db.collection("config").document("meta")
    ref.set({"version": fs.Increment(1),
             "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
    _invalidate_cache()
    try:
        return int((ref.get().to_dict() or {}).get("version", 0) or 0)
    except Exception:
        return 0


# ══════════════ الكاش ══════════════

_lock = threading.Lock()
_cache = {"items": None, "ts": 0.0, "version": 0}


def _invalidate_cache():
    with _lock:
        _cache["items"] = None
        _cache["ts"] = 0.0


def _load_all(force: bool = False):
    """كل المنح (المفعّلة والمخفية) مع النسخة — بكاش 5 دقائق."""
    now = time.time()
    with _lock:
        if not force and _cache["items"] is not None and now - _cache["ts"] < CACHE_TTL:
            return _cache["items"], _cache["version"]

    db = _db()
    items = [_decorate(d.id, d.to_dict() or {})
             for d in db.collection("scholarships").stream()]
    items.sort(key=sort_key)
    version = get_version()

    with _lock:
        _cache["items"] = items
        _cache["version"] = version
        _cache["ts"] = time.time()
    return items, version


# ══════════════ واجهة الطالب ══════════════

def list_public(client_version: int = -1) -> dict:
    """المنح المفعّلة فقط — أو `changed: false` إن كانت نسخة العميل محدَّثة.

    ⭐ هذا هو ما يجعل الفاتورة ثابتة: القائمة لا تُنقل إلا يوم تتغيّر.
    """
    items, version = _load_all()
    if client_version >= 0 and client_version == version:
        return {"changed": False, "version": version, "items": []}
    return {
        "changed": True,
        "version": version,
        "items": [i for i in items if i.get("enabled") is not False],
    }


def get_public(sch_id: str) -> dict:
    """منحة واحدة للطالب — المخفية غير موجودة بالنسبة له."""
    sch_id = normalize_id(sch_id)
    for item in _load_all()[0]:
        if item["id"] == sch_id and item.get("enabled") is not False:
            return item
    raise ScholarshipError("❌ هذه المنحة غير متاحة.")


# ══════════════ واجهة اللوحة ══════════════

def list_admin() -> dict:
    """كل المنح بما فيها المخفية + هل لكل واحدة برومبت مساعد."""
    items, version = _load_all(force=True)
    with_prompt = prompt_ids()
    for item in items:
        item["has_prompt"] = item["id"] in with_prompt
    return {"version": version, "items": items}


def get_admin(sch_id: str) -> dict:
    """منحة واحدة للتحرير — ومعها برومبتها من المجموعة الموازية."""
    sch_id = normalize_id(sch_id)
    snap = _db().collection("scholarships").document(sch_id).get()
    if not snap.exists:
        raise ScholarshipError(f"❌ لا توجد منحة بالمعرّف «{sch_id}».")
    item = _decorate(sch_id, snap.to_dict() or {})
    item["assistant_prompt"] = get_prompt(sch_id)
    return item


def create(sch_id: str, payload: dict) -> dict:
    """إنشاء منحة جديدة — يرفض الكتابة فوق منحة قائمة."""
    from firebase_admin import firestore as fs
    sch_id = normalize_id(sch_id)
    db = _db()
    ref = db.collection("scholarships").document(sch_id)
    if ref.get().exists:
        raise ScholarshipError(f"❌ توجد منحة بالمعرّف «{sch_id}» — اختر معرّفاً آخر.")

    data = validate(payload)
    stored = dict(data)
    data["created_at"] = fs.SERVER_TIMESTAMP
    data["updated_at"] = fs.SERVER_TIMESTAMP
    ref.set(data)

    prompt = payload.get("assistant_prompt")
    if prompt is not None:
        set_prompt(sch_id, prompt)

    version = bump_version()
    # ⚠️ نعيد `stored` لا `data`: الأخيرة تحمل **بذور** طوابع الخادم
    #    (`SERVER_TIMESTAMP`) وهي كائنات لا تُحسم إلا داخل Firestore ولا
    #    تُسلسَل إلى JSON. الطوابع الحقيقية تصل في أول قراءة تالية.
    return {**_decorate(sch_id, stored), "version": version}


def update(sch_id: str, payload: dict) -> dict:
    """تحديث كامل لمنحة قائمة (النموذج يرسل كل الحقول)."""
    from firebase_admin import firestore as fs
    sch_id = normalize_id(sch_id)
    db = _db()
    ref = db.collection("scholarships").document(sch_id)
    if not ref.get().exists:
        raise ScholarshipError(f"❌ لا توجد منحة بالمعرّف «{sch_id}».")

    data = validate(payload)
    stored = dict(data)
    data["updated_at"] = fs.SERVER_TIMESTAMP
    ref.set(data, merge=True)

    prompt = payload.get("assistant_prompt")
    if prompt is not None:
        set_prompt(sch_id, prompt)

    version = bump_version()
    return {**_decorate(sch_id, stored), "version": version}


def set_enabled(sch_id: str, enabled: bool) -> dict:
    """مفتاح الإظهار/الإخفاء الفوري — أرخص كتابة ممكنة."""
    from firebase_admin import firestore as fs
    sch_id = normalize_id(sch_id)
    ref = _db().collection("scholarships").document(sch_id)
    if not ref.get().exists:
        raise ScholarshipError(f"❌ لا توجد منحة بالمعرّف «{sch_id}».")
    ref.set({"enabled": bool(enabled), "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
    return {"id": sch_id, "enabled": bool(enabled), "version": bump_version()}


def reorder(ids: list) -> dict:
    """ترتيب العرض: أول معرّف = أعلى القائمة."""
    from firebase_admin import firestore as fs
    db = _db()
    clean = [normalize_id(i) for i in (ids or [])][:200]
    batch = db.batch()
    for index, sch_id in enumerate(clean):
        batch.set(db.collection("scholarships").document(sch_id),
                  {"order": index, "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
    batch.commit()
    return {"ordered": clean, "version": bump_version()}


def delete(sch_id: str) -> dict:
    """حذف منحة وبرومبتها معاً — وإلا بقي برومبت يتيم يُسلَّم لمنحة جديدة بنفس المعرّف."""
    sch_id = normalize_id(sch_id)
    db = _db()
    ref = db.collection("scholarships").document(sch_id)
    if not ref.get().exists:
        raise ScholarshipError(f"❌ لا توجد منحة بالمعرّف «{sch_id}».")
    ref.delete()
    try:
        db.collection("scholarship_prompts").document(sch_id).delete()
    except Exception:
        pass
    # 🧹 وصورها في Storage — وإلا بقيت ملفات يتيمة يُدفع ثمنها بلا مالك.
    from . import media_store
    media_store.delete_image("cover", sch_id)
    media_store.delete_image("logo", sch_id)
    _drop_legacy_cover(db, sch_id)
    return {"id": sch_id, "deleted": True, "version": bump_version()}


# ══════════════ 🖼️ أغلفة المنح (مجموعة موازية) ══════════════
# ⭐ **لماذا مجموعة موازية لا حقل في مستند المنحة؟** لأن قائمة المنح تُنزَّل
#    كاملةً على جهاز كل طالب عند تغيّر النسخة. غلافٌ واحد ~100 كيلوبايت ×
#    عشر منح = ميغابايت في كل تحديث، على إنترنت يمني متقطّع — وهذا ينقض
#    بروتوكول النسخة كلَّه ([32§4]).
#
#    الحل: الغلاف في `scholarship_covers/{id}` **يُجلب عند فتح شاشة المنحة
#    وحدها** ويُكيَّش على الجهاز. والقائمة تحمل راية `has_cover` فقط.


def set_cover(sch_id: str, raw: bytes = b"", mime: str = "image/jpeg") -> dict:
    """يرفع غلاف منحة إلى Storage ويحفظ رابطه. البايتات الفارغة تحذفه.

    ⭐ **الرابط لا الصورة** يُخزَّن في مستند المنحة: قائمة المنح تُنزَّل كاملةً
       على جهاز كل طالب عند تغيّر النسخة، ورابطٌ (~100 بايت) لا يُثقلها بينما
       صورة (~50 كيلوبايت) تفعل. والتطبيق يكيّشها بـ`cached_network_image`.
    """
    from firebase_admin import firestore as fs
    from . import media_store

    sch_id = normalize_id(sch_id)
    db = _db()
    ref = db.collection("scholarships").document(sch_id)
    if not ref.get().exists:
        raise ScholarshipError(f"❌ لا توجد منحة بالمعرّف «{sch_id}».")

    if not raw:
        media_store.delete_cover(sch_id)
        _drop_legacy_cover(db, sch_id)
        ref.set({"cover_url": "", "has_cover": False,
                 "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
        return {"id": sch_id, "has_cover": False, "version": bump_version()}

    if len(raw) > MAX_COVER_BYTES:
        raise ScholarshipError(
            "❌ الصورة كبيرة حتى بعد الضغط. اختر صورة أصغر أو أقل تفصيلاً.")

    try:
        url = media_store.upload_cover(sch_id, raw, mime)
    except media_store.StorageUnavailable as e:
        raise ScholarshipError(str(e))

    # ⚠️ ننظّف النسخة القديمة من Firestore: غلافٌ في مكانين يعني نسختين
    #    تفترقان، والقديمة تبقى تُقدَّم لتطبيقات لم تُحدَّث.
    _drop_legacy_cover(db, sch_id)
    ref.set({"cover_url": url, "has_cover": True,
             "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
    return {"id": sch_id, "has_cover": True, "cover_url": url,
            "bytes": len(raw), "version": bump_version()}


def set_logo(sch_id: str, raw: bytes = b"", mime: str = "image/png") -> dict:
    """يرفع شعار منحة إلى Storage ويحفظ رابطه. البايتات الفارغة تحذفه.

    ⭐ الشعار **مربّع** (1:1) لأنه يُعرض في كرت القائمة 58×58 وفي رأس الشاشة
       64×64. وهو أصغر من الغلاف كثيراً، فسقفه أقل.
    """
    from firebase_admin import firestore as fs
    from . import media_store

    sch_id = normalize_id(sch_id)
    ref = _db().collection("scholarships").document(sch_id)
    if not ref.get().exists:
        raise ScholarshipError(f"❌ لا توجد منحة بالمعرّف «{sch_id}».")

    if not raw:
        media_store.delete_image("logo", sch_id)
        ref.set({"logo_url": "", "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
        return {"id": sch_id, "logo_url": "", "version": bump_version()}

    if len(raw) > MAX_LOGO_BYTES:
        raise ScholarshipError("❌ الشعار كبير. اختر صورة أصغر.")

    try:
        url = media_store.upload_image("logo", sch_id, raw, mime)
    except media_store.StorageUnavailable as e:
        raise ScholarshipError(str(e))

    ref.set({"logo_url": url, "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
    return {"id": sch_id, "logo_url": url, "bytes": len(raw),
            "version": bump_version()}


def _drop_legacy_cover(db, sch_id: str) -> None:
    """يحذف الغلاف المخزَّن في Firestore (قبل تفعيل Storage)."""
    try:
        db.collection("scholarship_covers").document(sch_id).delete()
    except Exception:
        pass


def get_cover(sch_id: str) -> str:
    """غلاف منحة كـdata-URI — **مسار قديم** لما رُفع قبل تفعيل Storage.

    الأغلفة الجديدة تعيش في Storage ورابطها في `cover_url`، فهذه تبقى
    لئلا يفقد غلافٌ قديم صورتَه قبل أن يُعاد رفعه.
    """
    sch_id = normalize_id(sch_id)
    try:
        snap = _db().collection("scholarship_covers").document(sch_id).get()
    except ScholarshipError:
        return ""
    return (snap.to_dict() or {}).get("image", "") if snap.exists else ""


# ══════════════ ⚙️ الإعدادات العامة ══════════════
# `config/app_settings` — تُقرأ بكاش ٥ دقائق كبقية المحتوى، وتُحرَّر من اللوحة
# فتصل الخادم بلا إعادة نشر ([v3 §8]).

SETTINGS_FIELDS = {
    "quota_ask": (1, 1000),        # حدّ الطالب المسجَّل يومياً
    "quota_guest": (0, 100),       # تجربة الزائر (تراكمية لا يومية)
    # 📦 بوابة التحديث الإلزامي — يقرؤها `/app/version` ([api.py]).
    #    `min_build` هو **السلاح الوحيد** لإنقاذ نسخةٍ كُسرت بعد النشر،
    #    ورفعُه من اللوحة يعني بلا إصدارٍ جديد ولا انتظار مراجعة متجر.
    "min_build": (0, 100000),      # أدنى بناء مدعوم — دونه تحديثٌ إلزامي
    "latest_build": (0, 100000),   # أحدث بناء منشور — دونه تحديثٌ مقترح
}

# حقولٌ نصّية (لا مدى رقمي لها) — تُحفظ بسقف طول.
SETTINGS_TEXT_FIELDS = {
    "store_url": 300,              # رابط المتجر لزرّ «حدّث الآن»
    "update_message": 300,         # ما يُقال للطالب في شاشة التحديث
}

_settings_cache = {"data": None, "ts": 0.0}


def get_settings(force: bool = False) -> dict:
    """الإعدادات العامة — أو `{}` إن تعذّر (فتُستعمل قيم البيئة)."""
    now = time.time()
    with _lock:
        if not force and _settings_cache["data"] is not None \
                and now - _settings_cache["ts"] < CACHE_TTL:
            return dict(_settings_cache["data"])
    try:
        snap = _db().collection("config").document("app_settings").get()
        data = (snap.to_dict() or {}) if snap.exists else {}
    except Exception:
        return {}
    with _lock:
        _settings_cache["data"] = data
        _settings_cache["ts"] = time.time()
    return dict(data)


def set_settings(values: dict) -> dict:
    """يحدّث الإعدادات المسموحة وحدها — بعد التحقق من مداها."""
    from firebase_admin import firestore as fs
    clean = {}
    for key, (low, high) in SETTINGS_FIELDS.items():
        if key not in (values or {}):
            continue
        try:
            number = int(values[key])
        except (TypeError, ValueError):
            raise ScholarshipError(f"❌ «{key}» يجب أن يكون رقماً صحيحاً.")
        if not (low <= number <= high):
            raise ScholarshipError(f"❌ «{key}» خارج المدى المسموح ({low}–{high}).")
        clean[key] = number

    for key, max_len in SETTINGS_TEXT_FIELDS.items():
        if key not in (values or {}):
            continue
        text = str(values[key] or "").strip()
        if len(text) > max_len:
            raise ScholarshipError(f"❌ «{key}» أطول من {max_len} حرفاً.")
        clean[key] = text

    if not clean:
        raise ScholarshipError("❌ لا شيء لحفظه.")

    _db().collection("config").document("app_settings").set(
        {**clean, "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
    with _lock:
        _settings_cache["data"] = None
        _settings_cache["ts"] = 0.0
    return clean


# ══════════════ 🔒 البرومبتات (مجموعة موازية) ══════════════

_prompt_cache = {"map": None, "ts": 0.0}


def _load_prompts(force: bool = False) -> dict:
    now = time.time()
    with _lock:
        if not force and _prompt_cache["map"] is not None \
                and now - _prompt_cache["ts"] < CACHE_TTL:
            return _prompt_cache["map"]

    data = {}
    for doc in _db().collection("scholarship_prompts").stream():
        text = (doc.to_dict() or {}).get("assistant_prompt", "")
        if str(text or "").strip():
            data[doc.id] = str(text)

    with _lock:
        _prompt_cache["map"] = data
        _prompt_cache["ts"] = time.time()
    return data


def prompt_ids() -> set:
    try:
        return set(_load_prompts().keys())
    except ScholarshipError:
        return set()


def get_prompt(sch_id: str) -> str:
    """برومبت المساعد — يقرؤه الباك وحده. الغياب ليس خطأً (يوجد افتراضي)."""
    try:
        return _load_prompts().get(normalize_id(sch_id), "")
    except ScholarshipError:
        return ""


def set_prompt(sch_id: str, text) -> dict:
    """حفظ البرومبت. **لا يزيد `meta.version`** — الطلاب لا يقرؤونه أصلاً."""
    from firebase_admin import firestore as fs
    sch_id = normalize_id(sch_id)
    body = str(text or "").strip()[:MAX_PROMPT_CHARS]
    ref = _db().collection("scholarship_prompts").document(sch_id)
    if body:
        ref.set({"assistant_prompt": body, "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
    else:
        try:
            ref.delete()   # تفريغ الحقل = العودة للبرومبت الافتراضي
        except Exception:
            pass
    with _lock:
        _prompt_cache["map"] = None
        _prompt_cache["ts"] = 0.0
    return {"id": sch_id, "chars": len(body)}


def reset_cache():
    """للاختبارات وأدوات الصيانة."""
    _invalidate_cache()
    with _lock:
        _prompt_cache["map"] = None
        _prompt_cache["ts"] = 0.0
        _settings_cache["data"] = None
        _settings_cache["ts"] = 0.0


def now_iso() -> str:
    return datetime.now(timezone.utc).isoformat()
