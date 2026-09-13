# ==================================================
# 🛡️ core/admin.py — بيانات لوحة التحكم وصلاحياتها
# ==================================================
# اللوحة تقرأ من نفس مصدر الحقيقة الذي يكتب فيه التطبيق ([27]):
#   • `users/{uid}`          ← الحسابات (الاسم · البريد · الصف · المسار · الدور)
#   • `usage/{uid}_{تاريخ}`  ← عدّاد الأسئلة اليومي لكل طالب
#   • `usage/guest_{uid}`    ← عدّاد الزائر (تراكمي لا يومي)
# فلا جدول إحصاءات موازٍ يحتاج مزامنة — الرقم واحد لا رقمان.
#
# 🔒 **الصلاحية طبقتان**، ولا ثالثة لهما:
#   1. توكن Firebase لحسابٍ دوره `admin` في `users/{uid}` ← المعتمد
#   2. مفتاح `ADMIN_KEY` من البيئة ← للتشغيل المحلي وأدوات المالك
#   وإن لم يُضبط أيٌّ منهما فاللوحة **مغلقة تماماً** — لا وضع مفتوح افتراضياً.

import os
import re
from collections import defaultdict
from datetime import datetime, timedelta, timezone

from . import quota

ADMIN_KEY = os.getenv("ADMIN_KEY", "").strip()

# بريد إلكتروني واحد أو أكثر يُمنح صلاحية الإدارة بلا مستند Firestore.
ADMIN_EMAILS = {
    e.strip().lower()
    for e in os.getenv("ADMIN_EMAILS", "").split(",")
    if e.strip()
}

# مفاتيح `usage`: «{uid}_{yyyy-mm-dd}» للطالب و«guest_{uid}» للزائر.
_DAILY_KEY = re.compile(r"^(?P<uid>.+)_(?P<day>\d{4}-\d{2}-\d{2})$")


class AdminError(Exception):
    """خطأ برسالة عربية جاهزة للعرض في اللوحة."""


# ══════════════ الصلاحية ══════════════

def is_admin_identity(identity: dict) -> bool:
    """هل هذا الحساب مدير؟ (بريد في القائمة أو دور `admin` في Firestore)"""
    if not identity:
        return False
    email = (identity.get("email") or "").strip().lower()
    if email and email in ADMIN_EMAILS:
        return True

    db = quota._firestore()
    if db is None:
        return False
    try:
        snap = db.collection("users").document(identity.get("uid", "")).get()
        return (snap.to_dict() or {}).get("role") == "admin" if snap.exists else False
    except Exception:
        return False


def key_matches(provided: str) -> bool:
    """مقارنة ثابتة الزمن — لا تُسرّب طول المفتاح ولا موضع الاختلاف."""
    if not ADMIN_KEY or not provided:
        return False
    import hmac
    return hmac.compare_digest(ADMIN_KEY, provided.strip())


def gate_open() -> bool:
    """هل للوحة أي طريق دخول مضبوط أصلاً؟"""
    return bool(ADMIN_KEY or ADMIN_EMAILS)


# ══════════════ قراءة الاستخدام ══════════════

def _db():
    db = quota._firestore()
    if db is None:
        raise AdminError(
            "⚠️ Firestore غير متاح على الخادم — اللوحة تحتاج "
            "FIREBASE_SERVICE_ACCOUNT_JSON لقراءة المستخدمين والاستخدام.")
    return db


def store_info() -> dict:
    """🏷️ **أيَّ مخزنٍ تقرأ هذه اللوحة؟** — السؤال الذي بلا جوابٍ يُهدر يوماً.

    🔴 عطلٌ حقيقيٌّ وقع (2026-08-31): المالك يسجّل دخوله من التطبيق فيُكتب
       حسابه في Firestore الحقيقي، بينما اللوحة أمامه يقدّمها خادمٌ مُشغَّل
       بـ`tools/dev_local_store.py` — أي **مخزنٍ آخر تماماً**. فيبحث عن
       حسابه بين ٤٤ حساباً مبذوراً فلا يجده، ويستنتج أن اللوحة معطوبة
       وهي تعمل بلا خطأ واحد على البيانات التي تراها.

    ⭐ والعلاج ليس رقماً أدقّ بل **جملةً تقول أين نحن**: صفحةٌ لا تُعلن
       مخزنها تجعل كلَّ رقمٍ فيها قابلاً لتفسيرين، ولا سبيل للأدمن أن
       يفرّق. فتُقال الحقيقة في الأعلى قبل أن يُقرأ أول رقم.
    """
    db = quota._firestore()
    if db is None:
        return {
            "kind": "none",
            "label": "لا مخزن",
            "project": "",
            "live": False,
            "warning": "⚠️ لا Firestore على هذا الخادم — لا مستخدمين ولا أرقام.",
        }
    # المخزن المحلي يُعرّف نفسه صراحةً؛ ولا نستنتجه بغياب سمةٍ ما، فغيابها
    # في إصدارٍ قادم من مكتبة جوجل كان سيقلب التصنيف بلا أن يلاحظ أحد.
    kind = str(getattr(db, "masar_store_kind", "") or "")
    if kind == "dev-local":
        return {
            "kind": "dev",
            "label": "مخزن تطوير محلي (.dev_store.json)",
            "project": "",
            "live": False,
            "warning": (
                # ⚠️ نصٌّ مجرّد لا Markdown — اللوحة تعرضه كنصّ، فنجماتُ
                #    التوكيد تظهر كما هي فتبدو خطأً في الرسالة نفسها.
                "⛔ هذه ليست بيانات الإنتاج: الخادم مُشغَّل بـ"
                "tools/dev_local_store.py، والمستخدمون هنا مبذورون للفحص. "
                "حسابك الحقيقي لن يظهر، والإشعار لن يصل طلاباً حقيقيين. "
                "للبيانات الحقيقية شغّل: python -m uvicorn api:app"),
        }
    project = str(getattr(db, "project", "") or "")
    return {
        "kind": "firestore",
        "label": f"Firestore — مشروع {project}" if project else "Firestore",
        "project": project,
        "live": True,
        "warning": "",
    }


def _today() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _day_str(d: datetime) -> str:
    return d.strftime("%Y-%m-%d")


def _read_usage(db):
    """يقرأ مجموعة `usage` مرّة واحدة ويفكّ مفاتيحها.

    يعيد (يومي, زوّار) حيث:
      يومي  = {uid: {يوم: عدد}}
      زوّار = {uid: عدد تراكمي}
    """
    daily = defaultdict(dict)
    guests = {}
    for doc in db.collection("usage").stream():
        asks = int((doc.to_dict() or {}).get("asks", 0) or 0)
        key = doc.id
        if key.startswith("guest_"):
            guests[key[len("guest_"):]] = asks
            continue
        m = _DAILY_KEY.match(key)
        if m:
            daily[m.group("uid")][m.group("day")] = asks
    return daily, guests


def _series(daily, days: int, uid: str | None = None):
    """سلسلة آخر [days] يوماً: [{day, asks}] — الأقدم أولاً، بلا فجوات."""
    today = datetime.now(timezone.utc)
    out = []
    for i in range(days - 1, -1, -1):
        day = _day_str(today - timedelta(days=i))
        if uid is None:
            total = sum(per.get(day, 0) for per in daily.values())
        else:
            total = daily.get(uid, {}).get(day, 0)
        out.append({"day": day, "asks": total})
    return out


# ══════════════ الواجهات التي تستهلكها اللوحة ══════════════

def overview(days: int = 30) -> dict:
    """أرقام الصفحة الرئيسية: مستخدمون · أسئلة · سلسلة يومية."""
    db = _db()
    daily, guests = _read_usage(db)

    users = list(db.collection("users").stream())
    banned = sum(1 for u in users if (u.to_dict() or {}).get("banned") is True)

    today = _today()
    asks_today = sum(per.get(today, 0) for per in daily.values())
    asks_total = sum(sum(per.values()) for per in daily.values())
    guest_total = sum(guests.values())

    return {
        # 🏷️ يُقال في كل ردٍّ لا مرّةً عند الدخول: الأدمن قد يُبقي اللوحة
        #    مفتوحةً بينما يُعاد تشغيل الخادم على مخزنٍ آخر.
        "store": store_info(),
        "users": len(users),
        "banned": banned,
        "active_today": sum(1 for per in daily.values() if per.get(today, 0) > 0),
        "guests": len(guests),
        "asks_today": asks_today,
        "asks_total": asks_total,
        "guest_asks_total": guest_total,
        "requests_total": asks_total + guest_total,
        "series": _series(daily, days),
        "limits": {
            "student_daily": quota.STUDENT_DAILY_ASKS,
            "guest_total": quota.GUEST_TOTAL_ASKS,
        },
    }


def list_users(search: str = "", limit: int = 200, segment: str = "all",
               sort: str = "active") -> list:
    """كل المستخدمين مع استخدامهم — مصفّىً بالشريحة ومرتّباً كما يطلب الأدمن.

    ⭐ **الشريحة من [audience] لا من شرطٍ هنا**: «ثالث علمي» في هذا الجدول
       هو **بعينه** «ثالث علمي» في التحليلات وفي الإشعارات وفي قواعد الوصول.
       تعريفٌ ثانٍ هنا يعني جدولاً يعرض ٢٠٠ طالب وإشعاراً يصل ١٩٠ — بلا أن
       يعرف أحدٌ أيُّهما الصادق.
    """
    from . import audience as aud

    db = _db()
    daily, _ = _read_usage(db)
    ctx = aud.build_context(daily)
    today = _today()
    needle = (search or "").strip().lower()
    segment = aud.validate(segment or "all")

    rows = []
    for doc in db.collection("users").stream():
        d = doc.to_dict() or {}
        uid = doc.id
        name = str(d.get("name", ""))
        email = str(d.get("email", ""))
        if needle and needle not in name.lower() \
                and needle not in email.lower() and needle not in uid.lower():
            continue
        per = daily.get(uid, {})
        active_days = sorted(per.keys())
        rows.append({
            "uid": uid,
            "name": name or "—",
            "email": email,
            "grade": d.get("grade"),
            "track": d.get("track", ""),
            "role": d.get("role", "student"),
            "banned": d.get("banned") is True,
            "quota_override": d.get("quota_override"),
            "asks_today": per.get(today, 0),
            "asks_total": sum(per.values()),
            "active_days": len(per),
            # 🕒 «آخر نشاط» يفصل الحساب الجديد عن المهجور — وكلاهما بلا
            #    أسئلة اليوم، فعمود «اليوم» وحده يساويهما ظلماً.
            "last_active": active_days[-1] if active_days else "",
            "asks_7d": ctx["recent_asks"].get(uid, 0),
            "created_at": _iso(d.get("created_at")),
            "devices": len(d.get("fcm_tokens") or []),
            # 🕳️ **مستندٌ بلا ملفٍّ شخصي** — يُصنعه `POST /me/device` حين
            #    يسبق تسجيلُ الجهاز كتابةَ الملف عند أول دخول. بلا `grade`
            #    لا تُطابقه شريحةُ صفٍّ واحدة: جهازٌ مسجَّل لا يصله إعلانُ
            #    «ثالث علمي» أبداً، والصفُّ الفارغ في الجدول لا يقول لماذا.
            "profile_incomplete": not (name or email) or d.get("grade") is None,
        })

    rows = aud.filter_users(rows, segment, ctx)

    keys = {
        "active": lambda r: (r["asks_today"], r["asks_total"]),
        "total": lambda r: (r["asks_total"], r["asks_today"]),
        "recent": lambda r: (r["last_active"], r["asks_total"]),
        "new": lambda r: (r["created_at"], r["asks_total"]),
    }
    if sort == "name":      # الاسم تصاعدياً — الوحيد الذي لا يُعكس
        rows.sort(key=lambda r: r["name"])
    else:
        rows.sort(key=keys.get(sort, keys["active"]), reverse=True)
    return rows[:max(1, min(limit, 1000))]


def segments() -> list:
    """الشرائح الجاهزة للوحة — تُبنى الأزرار منها لا من قائمةٍ مكرّرة فيها."""
    from . import audience as aud
    return aud.describe_all()


def user_detail(uid: str, days: int = 30) -> dict:
    """تفصيل مستخدم واحد: بياناته وسلسلته اليومية."""
    db = _db()
    snap = db.collection("users").document(uid).get()
    if not snap.exists:
        raise AdminError(f"❌ لا يوجد مستخدم بالمعرّف «{uid}».")

    d = snap.to_dict() or {}
    daily, _ = _read_usage(db)
    per = daily.get(uid, {})

    return {
        "uid": uid,
        "name": d.get("name", ""),
        "email": d.get("email", ""),
        "grade": d.get("grade"),
        "track": d.get("track", ""),
        "role": d.get("role", "student"),
        "banned": d.get("banned") is True,
        "quota_override": d.get("quota_override"),
        "created_at": _iso(d.get("created_at")),
        "asks_total": sum(per.values()),
        "active_days": len(per),
        "series": _series(daily, days, uid=uid),
    }


def _iso(value) -> str:
    """طوابع Firestore تعود ككائنات وقت — نوحّدها نصاً ISO أو فراغاً."""
    if value is None:
        return ""
    try:
        return value.isoformat()
    except AttributeError:
        return str(value)


# ══════════════ الإجراءات ══════════════

def _refresh_analytics():
    """أيّ إجراءٍ يغيّر الأرقام يُبطل كاش التحليلات — وإلا رأى الأدمن أثر
    ضغطته بعد دقيقة وظنّها لم تُنفَّذ فكرّرها."""
    try:
        from . import analytics
        analytics.invalidate()
    except Exception:
        pass


def _forget_cached(uid: str) -> None:
    """يُسقط كاش هذا المستخدم في كل الطبقات بعد تعديلٍ إداري."""
    try:
        from . import user_state, access
        user_state.forget(uid)
        access.forget_profile(uid)
    except Exception:
        pass


def set_banned(uid: str, banned: bool) -> dict:
    """حظر مستخدم أو رفع الحظر.

    ⚠️ الحظر يُكتب في `users/{uid}.banned`، و`api._authenticate` يمنعه
    عند أول طلب — فلا يكفي أن يظهر في اللوحة وحدها.
    """
    db = _db()
    ref = db.collection("users").document(uid)
    if not ref.get().exists:
        raise AdminError(f"❌ لا يوجد مستخدم بالمعرّف «{uid}».")
    ref.set({"banned": bool(banned)}, merge=True)
    # ⚡ يسري **فوراً** لا بعد دقيقة: الأدمن يحظر ثم يتحقق في ثوانٍ، وكاشٌ
    #    لا يُسقَط هنا يجعله يظن الحظر لم يعمل فيضغط الزر مراراً.
    _forget_cached(uid)
    _refresh_analytics()
    return {"uid": uid, "banned": bool(banned)}


def set_quota(uid: str, limit) -> dict:
    """حدّ يومي خاص بمستخدم. `None` يعيده للحدّ العام."""
    db = _db()
    ref = db.collection("users").document(uid)
    if not ref.get().exists:
        raise AdminError(f"❌ لا يوجد مستخدم بالمعرّف «{uid}».")

    if limit is None:
        ref.set({"quota_override": None}, merge=True)
        _forget_cached(uid)
        _refresh_analytics()
        return {"uid": uid, "quota_override": None}

    try:
        value = int(limit)
    except (TypeError, ValueError):
        raise AdminError("❌ الحدّ يجب أن يكون رقماً صحيحاً.")
    if not (0 <= value <= 100000):
        raise AdminError("❌ الحدّ خارج المدى المسموح (0 إلى 100000).")

    ref.set({"quota_override": value}, merge=True)
    _forget_cached(uid)
    _refresh_analytics()
    return {"uid": uid, "quota_override": value}


def is_banned(uid: str) -> bool:
    """يستدعيها التوثيق عند كل طلب — تفشل مفتوحةً كي لا يعطّل عطلٌ الخدمةَ.

    ⚡ **كانت قراءة Firestore بلا كاش في كل طلب** — نداءٌ شبكيّ حاجب على
       مستندٍ يُقرأ في نفس الطلب مرتين أخريين. صارت من `user_state`.
    """
    if not uid:
        return False
    from . import user_state
    return user_state.get(uid).get("banned") is True
