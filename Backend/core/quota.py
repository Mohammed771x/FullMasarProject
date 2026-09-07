# ==================================================
# 🎟️ core/quota.py — الحصة اليومية (حماية فاتورة الذكاء الاصطناعي)
# ==================================================
# 🔴 لماذا هذا الملف موجود أصلاً:
#    البوابة القديمة للـAI كانت «كود التفعيل». بحذفه تصير كل طلبات
#    الموديلات مفتوحة لمن يعرف الرابط. الحصة هي البديل — ولذلك تنزل
#    في **نفس شريحة التوثيق** لا بعدها ([ADR-008] · [27§4]).
#
# التخزين (بالترتيب):
#   1. Firestore عبر Admin SDK إن وُجدت بيانات اعتماد الخدمة  ← المعتمد
#   2. الذاكرة (fallback) مع تحذير في اللوج                    ← لا ينجو من إعادة تشغيل HF
#
# لماذا لا الذاكرة وحدها؟ حاوية HF Spaces **تنام وتُعاد كثيراً**،
# فالعداد يُصفَّر مع كل إقلاع ⇒ الحصة بلا معنى.
#
# شكل المستندات:
#   usage/{uid}_{yyyy-mm-dd}  { asks: 12, updated_at }   ← الطالب المسجَّل: يومي
#   usage/guest_{uid}         { asks: 3,  updated_at }   ← الزائر: تجربة تراكمية

import os
import json
import threading
from datetime import datetime, timezone

# ── الحدود ──
STUDENT_DAILY_ASKS = int(os.getenv("QUOTA_ASK", "50"))   # طالب مسجَّل/يوم
GUEST_TOTAL_ASKS = int(os.getenv("QUOTA_GUEST", "5"))    # الزائر: تجربة كاملة لا يومية

QUOTA_MESSAGE_STUDENT = (
    "🎟️ وصلت حدّك اليومي من الأسئلة ({limit} سؤالاً).\n"
    "يتجدّد تلقائياً بعد منتصف الليل — نراك غداً 🌙"
)
QUOTA_MESSAGE_GUEST = (
    "🎁 انتهت أسئلتك التجريبية ({limit} أسئلة).\n"
    "سجّل حساباً مجانياً وتابع بلا انقطاع — محادثاتك تنتقل معك ✨"
)

_lock = threading.Lock()
_memory: dict = {}          # {doc_id: asks} — بديل الطوارئ
_MAX_MEMORY_KEYS = 20_000

_db = None
_db_ready = False


def _today() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def doc_id(uid: str, is_guest: bool) -> str:
    """الزائر عدّاده تراكمي (بلا تاريخ)، والطالب يومي."""
    uid = (uid or "?")[:128]
    return f"guest_{uid}" if is_guest else f"{uid}_{_today()}"


def _general_limit(is_guest: bool) -> int:
    """الحدّ العام: من لوحة التحكم إن ضُبط، وإلا من البيئة.

    ⭐ هذا ما يجعل المالك يرفع الحصة أو يخفضها **بلا إعادة نشر** — والقراءة
       بكاش خمس دقائق فلا تلمس الفاتورة.
    ⚠️ ويفشل مفتوحاً على قيمة البيئة: عطلٌ في القراءة لا يمنع طالباً.
    """
    fallback = GUEST_TOTAL_ASKS if is_guest else STUDENT_DAILY_ASKS
    try:
        from . import scholarships
        value = scholarships.get_settings().get(
            "quota_guest" if is_guest else "quota_ask")
        return int(value) if isinstance(value, (int, float)) else fallback
    except Exception:
        return fallback


def limit_for(is_guest: bool, uid: str = "") -> int:
    """الحدّ الفعّال: حدُّ هذا المستخدم إن ضُبط، وإلا الحدّ العام.

    ⚠️ يفشل مفتوحاً: عطلٌ في القراءة لا يجوز أن يمنع طالباً.
    """
    if is_guest:
        return _general_limit(True)
    override = _override_for(uid)
    return override if override is not None else _general_limit(False)


def _override_for(uid: str):
    """`users/{uid}.quota_override` — يُضبط من لوحة التحكم فقط."""
    if not uid:
        return None
    try:
        db = _firestore()
        if db is None:
            return None
        snap = db.collection("users").document(uid).get()
        value = (snap.to_dict() or {}).get("quota_override") if snap.exists else None
        return int(value) if isinstance(value, (int, float)) else None
    except Exception:
        return None


def message_for(is_guest: bool) -> str:
    tpl = QUOTA_MESSAGE_GUEST if is_guest else QUOTA_MESSAGE_STUDENT
    return tpl.format(limit=limit_for(is_guest))


# ══════════════ مخزن Firestore ══════════════

def _firestore():
    """عميل Firestore عبر Admin SDK — أو None إن غابت بيانات الاعتماد."""
    global _db, _db_ready
    if _db_ready:
        return _db
    _db_ready = True
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore

        raw = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
        path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
        if not firebase_admin._apps:
            if raw:
                firebase_admin.initialize_app(credentials.Certificate(json.loads(raw)))
            elif path and os.path.isfile(path):
                firebase_admin.initialize_app(credentials.Certificate(path))
            else:
                print("⚠️ الحصة تعمل بالذاكرة: لا FIREBASE_SERVICE_ACCOUNT_JSON "
                      "— العدّاد يُصفَّر مع كل إعادة تشغيل.")
                _db = None
                return None
        _db = firestore.client()
    except Exception as e:      # مكتبة غائبة أو اعتماد خاطئ ⇒ لا نُسقط الخدمة
        print(f"⚠️ الحصة تعمل بالذاكرة (Firestore غير متاح): {e}")
        _db = None
    return _db


def _consume_firestore(db, key: str, limit: int):
    from firebase_admin import firestore as fs
    ref = db.collection("usage").document(key)
    snap = ref.get()
    used = (snap.to_dict() or {}).get("asks", 0) if snap.exists else 0
    if used >= limit:
        return False, 0
    ref.set({"asks": fs.Increment(1), "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
    return True, max(0, limit - used - 1)


def _consume_memory(key: str, limit: int):
    with _lock:
        if len(_memory) >= _MAX_MEMORY_KEYS:
            _memory.clear()
        used = _memory.get(key, 0)
        if used >= limit:
            return False, 0
        _memory[key] = used + 1
        return True, max(0, limit - used - 1)


def check_and_consume(uid: str, is_guest: bool = False):
    """يستهلك سؤالاً واحداً من حصة المستخدم.

    يعيد `(allowed, remaining)`. عند أي عطل داخلي **يسمح بالمرور**
    (fail-open) كي لا يعطّل نظامُ الحماية الخدمةَ نفسها — تحديد المعدل
    في `ratelimit.py` يبقى خط الدفاع الثاني.
    """
    key = doc_id(uid, is_guest)
    limit = limit_for(is_guest, uid)
    try:
        db = _firestore()
        if db is not None:
            return _consume_firestore(db, key, limit)
        return _consume_memory(key, limit)
    except Exception as e:
        print(f"⚠️ تعذّر احتساب الحصة ({e}) — سُمح بالطلب.")
        return True, -1


def peek(uid: str, is_guest: bool = False) -> int:
    """المتبقي دون استهلاك — لعرضه في الواجهة."""
    key = doc_id(uid, is_guest)
    limit = limit_for(is_guest, uid)
    try:
        db = _firestore()
        if db is not None:
            snap = db.collection("usage").document(key).get()
            used = (snap.to_dict() or {}).get("asks", 0) if snap.exists else 0
        else:
            with _lock:
                used = _memory.get(key, 0)
        return max(0, limit - used)
    except Exception:
        return limit


def reset_memory():
    """للاختبارات فقط."""
    with _lock:
        _memory.clear()
