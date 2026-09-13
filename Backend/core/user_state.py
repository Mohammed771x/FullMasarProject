# ==================================================
# 👤 core/user_state.py — مستند المستخدم: قراءة واحدة مُكاشة
# ==================================================
# 🔴 **لماذا وُجد هذا الملف:** كان الطلب الواحد على `/ask` يقرأ Firestore
#    **ثلاث مرات من نفس المستند** ثم يكتب مرة رابعة:
#       ١) `admin.is_banned(uid)`      ← `users/{uid}.banned`      (بلا كاش)
#       ٢) `quota._override_for(uid)`  ← `users/{uid}.quota_override` (بلا كاش)
#       ٣) `access.profile_for(uid)`   ← `users/{uid}.grade/track/role`
#       ٤) عدّاد الحصة في `usage/…`
#    وكلها نداءات **متزامنة تحجب حلقة الأحداث**: ٥٠–١٥٠ms لكل واحد، فيتجمّد
#    الخادمُ لكل الطلاب نصفَ ثانية مع كل سؤال. والثلاثة الأولى **مستندٌ واحد**.
#
# ⭐ فالحل ليس تسريع القراءة بل **حذفها**: قراءة واحدة تُغذّي الثلاثة، بكاش
#    قصير في الذاكرة، وتُنفَّذ في خيطٍ جانبي فلا تحجب أحداً.
#
# ⏱️ **عمر الكاش ٦٠ ثانية** — مقايضة معلنة: الحظر يسري خلال دقيقة لا فوراً.
#    وهذا مقبول لأن الحظر إجراءٌ إداريّ لا لحظيّ؛ ومن أراد الفورية فـ
#    `forget()` يُنادى من اللوحة عند الحظر ومن `/me/profile-changed`.
#
# 🛟 **ويفشل مفتوحاً**: أي عطلٍ في القراءة يعني «غير محظور · بلا استثناء ·
#    بلا ملف» — عطلُ Firestore يعطّل *الامتيازات*، لا *الدراسة*.

import asyncio
import threading
import time

from . import quota

CACHE_TTL = 60.0
_MAX_KEYS = 20_000

_lock = threading.Lock()
_cache: dict = {}          # {uid: (ts, data|None)}

# القيمة التي تُرجَع حين لا مستند ولا Firestore — كلها «لا قيد».
EMPTY = {
    "exists": False,
    "banned": False,
    "quota_override": None,
    "grade": None,
    "track": "",
    "role": "student",
    "name": "",
}


def _shape(raw: dict | None) -> dict:
    """يحوّل مستند Firestore الخام إلى الشكل الذي يعتمد عليه بقية الكود."""
    if not raw:
        return dict(EMPTY)
    grade = raw.get("grade")
    role = raw.get("role")
    return {
        "exists": True,
        "banned": raw.get("banned") is True,
        "quota_override": (int(raw["quota_override"])
                           if isinstance(raw.get("quota_override"), (int, float))
                           else None),
        "grade": grade if grade in (1, 2, 3) else None,
        "track": str(raw.get("track") or ""),
        "role": role if role in ("student", "teacher", "admin") else "student",
        "name": str(raw.get("name") or ""),
    }


def _read_now(uid: str) -> dict:
    """قراءة حيّة بلا كاش — تفشل مفتوحةً."""
    try:
        db = quota._firestore()
        if db is None:
            return dict(EMPTY)
        snap = db.collection("users").document(uid).get()
        return _shape(snap.to_dict() if snap.exists else None)
    except Exception as e:                       # noqa: BLE001 — الفشل مفتوح عمداً
        print(f"⚠️ تعذّرت قراءة users/{uid} ({e}) — مُرّ بلا قيد.")
        return dict(EMPTY)


def get(uid: str) -> dict:
    """حالة المستخدم من الكاش أو من Firestore. **متزامنة** — للاختبارات
    وللمسارات التي تعمل أصلاً في خيط جانبي."""
    if not uid:
        return dict(EMPTY)
    now = time.time()
    with _lock:
        hit = _cache.get(uid)
        if hit and now - hit[0] < CACHE_TTL:
            return dict(hit[1])

    data = _read_now(uid)

    with _lock:
        if len(_cache) >= _MAX_KEYS:
            # 🧹 نُسقط الأقدم لا الجدول كله: تفريغٌ شامل يعني موجةَ قراءات
            #    فورية من كل مستخدم نشط — وهو أسوأ ما يحدث تحت الضغط.
            for dead in sorted(_cache, key=lambda k: _cache[k][0])[: _MAX_KEYS // 4]:
                _cache.pop(dead, None)
        _cache[uid] = (time.time(), dict(data))
    return dict(data)


async def aget(uid: str) -> dict:
    """نسخة لا تحجب حلقة الأحداث — **هذه هي التي تُنادى من المسارات**.

    الإصابة في الكاش ترجع فوراً بلا خيط أصلاً (وهي الحالة الغالبة)، ولا
    نستعمل الخيط إلا عند القراءة الفعلية.
    """
    if not uid:
        return dict(EMPTY)
    now = time.time()
    with _lock:
        hit = _cache.get(uid)
        if hit and now - hit[0] < CACHE_TTL:
            return dict(hit[1])
    return await asyncio.to_thread(get, uid)


def forget(uid: str) -> None:
    """يُسقط كاش مستخدم واحد — يُنادى بعد الحظر أو تبديل الصف/الدور."""
    with _lock:
        _cache.pop(uid, None)


def reset() -> None:
    """للاختبارات فقط."""
    with _lock:
        _cache.clear()
