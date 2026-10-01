# ==================================================
# 🧪 core/guest_pool.py — ميزانيةُ الزوّار اليومية المشتركة
# ==================================================
# 🔴 **الثغرة (فحص التكلفة ٢٠٢٦-١٠-٠١):** حدُّ الزائر (٥ أسئلة) **لكل حساب**،
#    والحسابُ المجهول يُصنع بنقرة (`signInAnonymously`) — فسكربتٌ يصنع حساباً
#    جديداً كل خمسة أسئلة يحصل على أسئلةٍ بلا نهاية على فاتورتنا. وحدُّ المعدّل
#    بالـuid لا يراه، وحدُّ الـIP لا يُعتمد عليه (X-Forwarded-For يكتبه العميل).
#
# ✅ **سقفٌ واحدٌ لكل الزوّار معاً في اليوم** — لا يُتخطّى بتدوير الحسابات
#    ولا العناوين، لأنه لا يسأل «من أنت» أصلاً. والطالب المسجَّل لا يمسّه.
#    ونفادُه يقول للزائر ما يقوله نفادُ تجربته: سجّل حساباً مجانياً.
#
# ⚖️ **لماذا عدّادٌ في الذاكرة يُحفظ دورياً لا معاملةُ Firestore؟** مستندٌ
#    واحدٌ يكتب فيه كلُّ زائر = نقطةُ تزاحم: تحت الهجوم تفشل المعاملات،
#    و`check_and_consume` يفشل **مفتوحاً** — أي أن الهجوم نفسه كان سيفتح
#    الباب. فالعدُّ هنا في الذاكرة (الخادم نسخةٌ واحدة)، ويُدفع إلى
#    `guest_pool/{يوم}` بزيادةٍ ذرّية كل ١٠ ثوانٍ، ويُقرأ مرّةً عند الإقلاع
#    كي لا تمنح إعادةُ التشغيل ميزانيةً جديدة.

from __future__ import annotations

import os
import threading
import time
from datetime import datetime, timezone

DEFAULT_POOL = int(os.getenv("QUOTA_GUEST_POOL", "300"))   # سؤالُ زائرٍ في اليوم — للجميع
FLUSH_SECONDS = 10.0
COLLECTION = "guest_pool"          # ⚠️ لا `usage`: لوحة التحكم تقرأ تلك كمستخدمين

POOL_MESSAGE = (
    "🌙 انتهت أسئلة التجربة المتاحة للزوّار اليوم.\n"
    "سجّل حساباً مجانياً وتابع فوراً — محادثاتك تنتقل معك ✨"
)

_lock = threading.Lock()
_state = {"day": "", "used": 0, "delta": 0, "loaded": False,
          "last_flush": 0.0, "flushing": False}


def _today() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def limit() -> int:
    """من لوحة التحكم (`quota_guest_pool`)، وإلا من البيئة. ٠ = لا أسئلة للزوّار."""
    try:
        from . import scholarships
        value = scholarships.get_settings().get("quota_guest_pool")
        return int(value) if isinstance(value, (int, float)) else DEFAULT_POOL
    except Exception:
        return DEFAULT_POOL


def _db():
    from . import quota
    return quota._firestore()


def _load(day: str) -> int:
    """ما استُهلك اليوم قبل هذا الإقلاع — قراءةٌ واحدة لكل يوم."""
    try:
        db = _db()
        if db is None:
            return 0
        snap = db.collection(COLLECTION).document(day).get()
        return int((snap.to_dict() or {}).get("asks", 0) or 0) if snap.exists else 0
    except Exception as e:
        print(f"⚠️ تعذّرت قراءة ميزانية الزوّار ({e}) — تبدأ من الذاكرة.")
        return 0


def _roll() -> None:
    """يُنادى داخل القفل: يومٌ جديد ⇒ عدّادٌ جديد (ويُدفع ما بقي من الأمس)."""
    day = _today()
    if _state["day"] != day:
        if _state["delta"] and _state["day"]:
            _spawn_flush(_state["day"], _state["delta"])
        _state.update(day=day, used=0, delta=0, loaded=False)


def _ensure_loaded() -> None:
    with _lock:
        _roll()
        if _state["loaded"]:
            return
        day = _state["day"]
    base = _load(day)                       # خارج القفل: نداءٌ شبكي
    with _lock:
        if _state["day"] == day and not _state["loaded"]:
            _state["used"] += base
            _state["loaded"] = True


def take() -> bool:
    """يحجز سؤالاً من ميزانية اليوم — False إن نفدت."""
    _ensure_loaded()
    cap = limit()
    with _lock:
        _roll()
        if _state["used"] >= cap:
            return False
        _state["used"] += 1
        _state["delta"] += 1
    _maybe_flush()
    return True


def give_back() -> None:
    """يردّ سؤالاً حُجز ثم لم يُصرف (رفضُ الحصة الفردية أو ردُّها)."""
    with _lock:
        _roll()
        if _state["used"] > 0:
            _state["used"] -= 1
            _state["delta"] -= 1
    _maybe_flush()


def exhausted() -> bool:
    """هل نفدت ميزانية اليوم؟ — يختار به [quota.message_for] رسالة الزائر."""
    try:
        with _lock:
            used = _state["used"] if _state["day"] == _today() else 0
        return used >= limit()
    except Exception:
        return False


def status() -> dict:
    with _lock:
        used = _state["used"] if _state["day"] == _today() else 0
    return {"used": used, "limit": limit()}


# ══════════════ الحفظ ══════════════

def _maybe_flush(force: bool = False) -> None:
    with _lock:
        if _state["flushing"] or not _state["delta"]:
            return
        if not force and time.time() - _state["last_flush"] < FLUSH_SECONDS:
            return
        day, delta = _state["day"], _state["delta"]
        _state["delta"] = 0
        _state["last_flush"] = time.time()
    if force:
        _write(day, delta)
    else:
        _spawn_flush(day, delta)


def _spawn_flush(day: str, delta: int) -> None:
    threading.Thread(target=_write, args=(day, delta), daemon=True).start()


def _write(day: str, delta: int) -> None:
    with _lock:
        _state["flushing"] = True
    try:
        db = _db()
        if db is None or not delta:
            return
        from firebase_admin import firestore as fs
        db.collection(COLLECTION).document(day).set(
            {"asks": fs.Increment(delta), "updated_at": fs.SERVER_TIMESTAMP}, merge=True)
    except Exception as e:
        print(f"⚠️ تعذّر حفظ ميزانية الزوّار ({e}) — أُعيدت للانتظار.")
        with _lock:
            if _state["day"] == day:
                _state["delta"] += delta
    finally:
        with _lock:
            _state["flushing"] = False


def flush() -> None:
    _maybe_flush(force=True)


def reset() -> None:
    """للاختبارات."""
    with _lock:
        _state.update(day="", used=0, delta=0, loaded=False,
                      last_flush=0.0, flushing=False)
