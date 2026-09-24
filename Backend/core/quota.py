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
from dataclasses import dataclass, field
from datetime import datetime, timezone

# ── الحدود ──
STUDENT_DAILY_ASKS = int(os.getenv("QUOTA_ASK", "50"))   # طالب مسجَّل/يوم
GUEST_TOTAL_ASKS = int(os.getenv("QUOTA_GUEST", "5"))    # الزائر: تجربة كاملة لا يومية

# ══════════════ 🧪 حسابات الفحص — بلا حصّة ══════════════
# 🔴 **العلّة التي حلّها هذا** (تكرّرت في كل جلسة فحص): المحاكي مسجَّلٌ
#    **زائراً**، وحصّةُ الزائر **تراكمية لا يومية** وتُخزَّن في Firestore
#    الحقيقيّ — فتنفد بعد خمسة أسئلة ولا تُصفَّر بإعادة تشغيل الخادم.
#    فيتوقّف فحصُ قسمٍ كاملٍ في منتصفه، أو يُصفَّر العدّادُ يدوياً كل مرة.
#
# ⚠️ **ولمَ لا تُرفع `quota_guest` من اللوحة؟** تلك تمسّ **كل زائرٍ حقيقيّ**
#    — أي تفتح الفاتورة على الإنترنت كلّه لأجل جهازٍ واحد.
#
# ✅ فالاستثناء **بالهوية لا بالحدّ**: قائمةٌ صريحةٌ من المعرّفات في البيئة
#    (`QUOTA_UNLIMITED_UIDS=uid1,uid2`). وهي **فارغةٌ افتراضاً** فلا أثر لها
#    في الإنتاج إطلاقاً ما لم يضعها المالك بنفسه في `.env` جهازِه.
UNLIMITED_ASKS = 1_000_000_000


def _unlimited_uids() -> set:
    """تُقرأ في كل نداء لا مرّةً عند الاستيراد — فالاختبار يضبط البيئة ويرى أثرها."""
    raw = os.getenv("QUOTA_UNLIMITED_UIDS", "")
    return {u.strip() for u in raw.split(",") if u.strip()}

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


@dataclass
class Reservation:
    """خصمٌ يخص طلباً واحداً، وتسويته idempotent.

    ربط الردّ بهذا الكائن يمنع `refund()` مكرراً من إنقاص عدّاد طلب آخر.
    """
    uid: str
    is_guest: bool
    allowed: bool
    remaining: int
    _settled: bool = False
    _lock: threading.Lock = field(default_factory=threading.Lock, repr=False)

    def begin_settlement(self) -> bool:
        with self._lock:
            if self._settled:
                return False
            self._settled = True
            return True


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
    # 🧪 حسابُ فحصٍ معلَنٌ في البيئة — قبل كل شيء، وللزائر كما للمسجَّل.
    if uid and uid in _unlimited_uids():
        return UNLIMITED_ASKS
    if is_guest:
        return _general_limit(True)
    override = _override_for(uid)
    return override if override is not None else _general_limit(False)


def _override_for(uid: str):
    """`users/{uid}.quota_override` — يُضبط من لوحة التحكم فقط.

    ⚡ يقرأ من `user_state` المُكاش لا من Firestore مباشرةً: كان هذا نداءً
       شبكياً **لكل سؤال** على مستندٍ يُقرأ في نفس الطلب مرتين أخريين.
    """
    if not uid:
        return None
    try:
        from . import user_state
        return user_state.get(uid).get("quota_override")
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
    """يخصم سؤالاً **داخل معاملة** — الفحص والزيادة لا ينفصلان.

    🔴 **السباق الذي كان هنا:** الكود السابق كان يقرأ ثم يقارن ثم يكتب في
       ثلاث خطوات منفصلة. فعشرة طلبات متوازية من نفس الحساب تقرأ كلها
       `used = 49` وتمرّ كلها — والحدُّ ٥٠. سكربتٌ يرسل مئة طلب دفعةً
       واحدة كان **يتجاوز الحصة بالكامل**، وهي البوابة الوحيدة على فاتورة
       الموديلات بعد حذف الأكواد.
    ⭐ المعاملة تُعيد المحاولة تلقائياً عند التصادم، فالقارئ الثاني يرى
       الرقم بعد زيادة الأول لا قبلها.
    ⚠️ ولا تُستبدل بـ`Increment` وحدها: الزيادة الذرّية تكتب ولا **تفحص**،
       فتزيد بلا سقف.
    """
    from firebase_admin import firestore as fs

    ref = db.collection("usage").document(key)
    stamp = getattr(fs, "SERVER_TIMESTAMP", None)

    # 🧪 المخازن البديلة (مخزن التطوير المحلي · وهميّ الاختبارات) بلا معاملات.
    #    والفحص **قبل** التزيين لا داخل `try`: `@fs.transactional` يُقيَّم عند
    #    تعريف الدالة، فكان `AttributeError` يقفز فوق كل حراسةٍ داخلية ويصل
    #    إلى `except` العام في `check_and_consume` — أي **فشلٌ مفتوح صامت**:
    #    الحصة تتوقف عن العمل كلياً ولا يظهر إلا سطرٌ في اللوج.
    transactional = getattr(fs, "transactional", None)
    if transactional is None or not hasattr(db, "transaction"):
        snap = ref.get()
        used = (snap.to_dict() or {}).get("asks", 0) if snap.exists else 0
        if not isinstance(used, (int, float)):
            used = 0
        if used >= limit:
            return False, 0
        ref.set({"asks": int(used) + 1, "updated_at": stamp}, merge=True)
        return True, max(0, limit - int(used) - 1)

    @transactional
    def _txn(transaction):
        snap = ref.get(transaction=transaction)
        used = (snap.to_dict() or {}).get("asks", 0) if snap.exists else 0
        if not isinstance(used, (int, float)):
            used = 0
        if used >= limit:
            return False, 0
        transaction.set(ref, {"asks": int(used) + 1, "updated_at": stamp}, merge=True)
        return True, max(0, limit - int(used) - 1)

    return _txn(db.transaction())


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


# ══════════════ ردُّ الحصة ══════════════
#
# 🔴 **قرار المالك (2026-09-14): «خلّ الرفض ما يخصم من الحصة.»**
#    الحصة تُخصم في `_ask_guards` **قبل** المعالج — وهذا صحيح: الفحصُ
#    والخصم يجب أن يسبقا أيَّ نداءِ موديل. لكنّ بعض الردود لا تُنادي
#    موديلاً أصلاً (سؤالٌ خارج الوحدة · لا وحدة · لا صفحات · مادةٌ قيد
#    الإضافة)، فالطالبُ كان يدفع ثمن لا شيء.
#
# ⚖️ **ولا نؤخّر الخصمَ إلى ما بعد الجواب** بدلاً من الردّ: التأخيرُ يفتح
#    السباقَ الذي أُغلق هنا بمعاملة — عشرةُ طلباتٍ متوازية تمرّ كلُّها ثم
#    تُخصم بعد أن تكون الفاتورة قد صُرفت. فالخصمُ أولاً، والردُّ استثناءٌ
#    محسوب يقع **بعد** أن يثبت أن الطلب لم يكلّف شيئاً ([core/billing.py]).

def _refund_firestore(db, key: str) -> None:
    """ينقص واحداً — ولا ينزل تحت الصفر مهما تكرّر النداء."""
    from firebase_admin import firestore as fs

    ref = db.collection("usage").document(key)
    stamp = getattr(fs, "SERVER_TIMESTAMP", None)

    def _apply(snap):
        used = (snap.to_dict() or {}).get("asks", 0) if snap.exists else 0
        if not isinstance(used, (int, float)) or used <= 0:
            return None
        return max(0, int(used) - 1)

    transactional = getattr(fs, "transactional", None)
    if transactional is None or not hasattr(db, "transaction"):
        new_used = _apply(ref.get())
        if new_used is not None:
            ref.set({"asks": new_used, "updated_at": stamp}, merge=True)
        return

    @transactional
    def _txn(transaction):
        new_used = _apply(ref.get(transaction=transaction))
        if new_used is not None:
            transaction.set(ref, {"asks": new_used, "updated_at": stamp}, merge=True)

    _txn(db.transaction())


def _refund_memory(key: str) -> None:
    with _lock:
        used = _memory.get(key, 0)
        if used > 0:
            _memory[key] = used - 1


def refund(uid: str, is_guest: bool = False) -> None:
    """يردّ سؤالاً خُصم ثم تبيّن أن الطلب لم يُنادِ موديلاً.

    صامتةٌ عند أي عطل: فشلُ الردّ يكلّف الطالبَ سؤالاً، وفشلُ رفعِ
    الاستثناء كان سيكلّفه الجوابَ كلَّه.
    """
    key = doc_id(uid, is_guest)
    try:
        db = _firestore()
        if db is not None:
            _refund_firestore(db, key)
        else:
            _refund_memory(key)
    except Exception as e:
        print(f"⚠️ تعذّر ردّ الحصة ({e}) — بقي الخصم.")


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


# ══════════════ نسخٌ لا تحجب حلقة الأحداث ══════════════
# ⚡ نداءات Firestore متزامنة، ومناداتها من `async def` تُجمّد الخادم لكل
#    الطلاب طوال الرحلة الشبكية. هذه الأغلفة تنقلها لخيطٍ جانبي — وهي ما
#    تُنادى من المسارات دائماً.

async def acheck_and_consume(uid: str, is_guest: bool = False):
    import asyncio
    return await asyncio.to_thread(check_and_consume, uid, is_guest)


async def areserve(uid: str, is_guest: bool = False) -> Reservation:
    """يحجز حصةً واحدة ويعيد تذكرة التسوية الخاصة بهذه المحاولة."""
    allowed, remaining = await acheck_and_consume(uid, is_guest)
    return Reservation(uid, is_guest, allowed, remaining)


async def asettle(reservation: Reservation | None, *, billable: bool) -> bool:
    """يثبّت الخصم أو يردّه مرةً واحدة فقط.

    يعيد `True` فقط حين وقع refund فعلاً، ليضيف المستدعي راية العميل.
    """
    if reservation is None or not reservation.allowed:
        return False
    if not reservation.begin_settlement():
        return False
    if billable:
        return False
    await arefund(reservation.uid, reservation.is_guest)
    return True


async def arefund(uid: str, is_guest: bool = False) -> None:
    import asyncio
    await asyncio.to_thread(refund, uid, is_guest)


def status(uid: str, is_guest: bool = False) -> dict:
    """🎟️ حالة الحصة كاملةً للعرض في التطبيق: الحد · المستهلك · المتبقي.

    ⭐ **لماذا تُعرض أصلاً:** بدونها يصطدم الطالب بالجدار فجأةً في منتصف
       مذاكرته بلا إنذار — والرقم عندنا أصلاً، إخفاؤه كان قراراً لم يُتخذ.
    """
    limit = limit_for(is_guest, uid)
    remaining = peek(uid, is_guest)
    return {
        "limit": limit,
        "used": max(0, limit - remaining),
        "remaining": remaining,
        "is_guest": bool(is_guest),
        # الزائر عدّاده تراكمي لا يومي — والواجهة تحتاج التفريق لتكتب
        # «تتجدّد بعد منتصف الليل» أو «سجّل لتتابع».
        "resets_daily": not is_guest,
    }


async def astatus(uid: str, is_guest: bool = False) -> dict:
    import asyncio
    return await asyncio.to_thread(status, uid, is_guest)
