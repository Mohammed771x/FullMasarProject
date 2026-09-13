# ==================================================
# 🧾 core/idempotency.py — «نفس المحاولة لا تُحتسب مرتين»
# ==================================================
# 🔴 **العطل الذي يعالجه:** مهلة العميل ٦٠ ثانية، والخادم قد ينهي العمل في
#    ٦٢. عندها يقع أسوأ اجتماع ممكن:
#       • الحصة **خُصمت**            (الخادم أتمّ الطلب)
#       • الجواب **ضاع**             (العميل أغلق الاتصال)
#       • الطالب **يعيد السؤال**     (لا يرى شيئاً)
#       • فتُخصم حصةٌ ثانية وتُدفع فاتورةُ موديلٍ ثانية عن **نفس السؤال**
#    وشبكات الطلاب متقطّعة، فهذا ليس حالة نادرة بل يوميّة.
#
# ⭐ **الحل:** العميل يولّد `request_id` لكل *محاولة إرسال* — لا لكل نداء
#    شبكة. فإعادة المحاولة تحمل **نفس** المعرّف، والخادم يردّ بالجواب
#    المخزَّن بلا نداء موديل ولا خصم حصة. ورسالةٌ جديدة تعني معرّفاً جديداً.
#
# 🔑 المفتاح `uid|request_id` — لا `request_id` وحده: وإلا سرق طالبٌ جوابَ
#    غيره بتخمين معرّف. والمعرّف عشوائي أصلاً، لكن الحماية لا تُبنى على ذلك.
#
# 🧠 التخزين بالذاكرة عمداً: نافذته دقائق، وضياعه عند إعادة التشغيل يعيدنا
#    إلى السلوك القديم لا إلى عطلٍ جديد. Firestore هنا كلفةٌ بلا مقابل.
#
# ⏳ ثلاث حالات لكل مفتاح:
#    `RUNNING` ← طلبٌ يعمل الآن   ⇒ الإعادة تنتظره ولا تبدأ ثانياً
#    `DONE`    ← جوابٌ محفوظ      ⇒ يُرجَع فوراً
#    غائب      ← أول مرة          ⇒ يُنفَّذ

import threading
import time

TTL = 600.0             # عمر الجواب المحفوظ (١٠ دقائق) — أطول من أي مهلة عميل
RUNNING_TTL = 180.0     # طلبٌ عالق أكثر من ٣ دقائق يُعتبر ميتاً فيُعاد تنفيذه
_MAX_KEYS = 5_000

_lock = threading.Lock()
_store: dict = {}       # {key: {"state","ts","value"}}


def key_for(uid: str, request_id: str) -> str:
    return f"{(uid or '?')[:128]}|{(request_id or '')[:64]}"


def _sweep(now: float) -> None:
    dead = [k for k, e in _store.items()
            if now - e["ts"] > (RUNNING_TTL if e["state"] == "RUNNING" else TTL)]
    for k in dead:
        _store.pop(k, None)


FRESH = "fresh"       # أول مرة — نفّذ ثم نادِ finish
DONE = "done"         # جوابٌ محفوظ — أرجعه بلا تنفيذ ولا خصم
RUNNING = "running"   # نسخةٌ منه تعمل الآن — أخبر العميل أن يمهل


def begin(uid: str, request_id: str):
    """يحجز المحاولة. يعيد `(state, value)` حيث `state` واحدةٌ من
    [FRESH] · [DONE] · [RUNNING].

    ⚠️ **ثلاث حالات لا اثنتان عمداً:** بقيمةٍ منطقية (`fresh/cached`) كان
       «محفوظٌ قيمته None» يلتبس بـ«يعمل الآن»، فيظلّ الطالب يرى «امهل
       لحظات» عشر دقائق على طلبٍ **انتهى**. والحالةُ ليست نظرية: أي معالجٍ
       يرجع `Response` لا يُفكّ يُخزَّن بـ`None`.

    بلا `request_id` يعود `(FRESH, None)` دائماً — عميلٌ لا يرسله يعمل كما
    كان حرفياً، والحماية تبدأ حين يرسله لا قبله.
    """
    if not request_id:
        return FRESH, None
    now = time.time()
    k = key_for(uid, request_id)
    with _lock:
        _sweep(now)
        entry = _store.get(k)
        if entry is not None:
            if entry["state"] == "DONE":
                return DONE, entry["value"]
            return RUNNING, None
        if len(_store) >= _MAX_KEYS:
            for old in sorted(_store, key=lambda x: _store[x]["ts"])[: _MAX_KEYS // 4]:
                _store.pop(old, None)
        _store[k] = {"state": "RUNNING", "ts": now, "value": None}
    return FRESH, None


def finish(uid: str, request_id: str, value) -> None:
    """يحفظ الجواب لتُرجعه أي إعادة محاولة خلال [TTL]."""
    if not request_id:
        return
    with _lock:
        _store[key_for(uid, request_id)] = {
            "state": "DONE", "ts": time.time(), "value": value}


def abandon(uid: str, request_id: str) -> None:
    """يُلغي الحجز عند فشل التنفيذ — وإلا بقي «يعمل» ثلاث دقائق فمنع الإعادة.

    ⚠️ لازمٌ لا تحسين: طلبٌ سقط باستثناء يترك المفتاح `RUNNING`، فيرى الطالب
       «طلبك قيد المعالجة» ثلاث دقائق على طلبٍ مات فعلاً.
    """
    if not request_id:
        return
    with _lock:
        entry = _store.get(key_for(uid, request_id))
        if entry is not None and entry["state"] == "RUNNING":
            _store.pop(key_for(uid, request_id), None)


IN_FLIGHT_MESSAGE = ("⏳ سؤالك السابق ما زال قيد المعالجة — "
                     "امهله لحظات ولا ترسله مرة أخرى 😊")


def reset() -> None:
    """للاختبارات فقط."""
    with _lock:
        _store.clear()
