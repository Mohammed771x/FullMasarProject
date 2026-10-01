# ==================================================
# 📇 core/usage_index.py — قراءة `usage` للوحة التحكم: مرّةً، ثم الجديد وحده
# ==================================================
# 🔴 **ما كان (فحص التكلفة ٢٠٢٦-١٠-٠١):** كل صفحةٍ في اللوحة — النظرة العامة،
#    جدول المستخدمين، **تفصيلُ طالبٍ واحد**، التحليلات، جمهورُ الإشعارات —
#    تمسح مجموعة `usage` **كلَّها**. والمجموعة تنمو مستنداً لكل طالبٍ في كل
#    يوم ولا تُحذف: ١٠ آلاف طالب يومياً × ٩٠ يوماً ≈ ٩٠٠ ألف قراءة **لكل نقرة**
#    (~$0.27)، وتطول مع الزمن لا مع الحركة وحدها.
#
# ✅ **الملاحظة التي تحلّها:** مستندُ يومٍ مضى لا يتغيّر أبداً — العدّاد يكتب
#    في مستند اليوم وحده (`{uid}_{اليوم}`)، والزائر في مستندٍ واحدٍ تراكمي.
#    وكلُّ كتابةٍ تضع `updated_at`. فالفهرس:
#      ١. يمسح المجموعة **مرّةً واحدة** في عمر الخادم (بحقل `asks` وحده).
#      ٢. بعدها يقرأ **ما تغيّر منذ آخر مزامنة** فقط (`updated_at >= …`)،
#         — أي بعدد من نشط منذ آخر نظرة، لا بعدد الأيام كلها.
#    والأرقام المعروضة (الإجمالي التاريخي، أيام النشاط، آخر نشاط) **كما هي**.
#
# 🧹 ومستنداتُ حصة الصور (`img_{uid}_{يوم}`) تعيش في المجموعة نفسها، وكانت
#    تُقرأ كمستخدمٍ وهميّ اسمه `img_…` فتنفخ «أسئلة اليوم» و«نشط اليوم».
#    تُستبعد هنا — لا في كل قارئ.

from __future__ import annotations

import re
import threading
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone

# ⏱️ صفر = كل قراءةٍ تزامن ما تغيّر — فالأرقام **حيّةٌ كما كانت**، وثمنُ
#    المزامنة قراءةٌ لكل مستندٍ تغيّر في الدقائق الأخيرة لا للمجموعة كلها.
TTL = 0.0
MARGIN = timedelta(seconds=120)     # هامشُ اختلاف الساعات بين الخادم وFirestore

_DAILY_KEY = re.compile(r"^(?P<uid>.+)_(?P<day>\d{4}-\d{2}-\d{2})$")

_lock = threading.Lock()
_state = {"daily": defaultdict(dict), "guests": {}, "synced_at": None,
          "checked": 0.0, "db": None, "stats": {"full_scans": 0,
                                                   "incremental": 0, "docs_read": 0}}


def _num(v) -> int:
    try:
        return int(float(v or 0))
    except (TypeError, ValueError):
        return 0


def _apply(doc) -> None:
    key = doc.id
    if key.startswith("img_"):
        return                              # حصةُ الصور ليست أسئلة ولا مستخدماً
    asks = _num((doc.to_dict() or {}).get("asks", 0))
    if key.startswith("guest_"):
        _state["guests"][key[len("guest_"):]] = asks
        return
    m = _DAILY_KEY.match(key)
    if m:
        _state["daily"][m.group("uid")][m.group("day")] = asks


def _full_scan(db) -> int:
    col = db.collection("usage")
    try:
        query = col.select(["asks"])        # إسقاطٌ: أقلّ نقلاً، والقراءة نفسها
    except Exception:
        query = col
    _state["daily"] = defaultdict(dict)
    _state["guests"] = {}
    n = 0
    for doc in query.stream():
        _apply(doc)
        n += 1
    _state["stats"]["full_scans"] += 1
    return n


def _changed_since(db, since: datetime) -> int:
    col = db.collection("usage")
    try:
        from google.cloud.firestore_v1.base_query import FieldFilter
        query = col.where(filter=FieldFilter("updated_at", ">=", since))
    except Exception:
        query = col.where("updated_at", ">=", since)
    n = 0
    for doc in query.stream():
        _apply(doc)
        n += 1
    _state["stats"]["incremental"] += 1
    return n


def read(db, force: bool = False):
    """يعيد `(يومي, زوّار)` — يومي = {uid: {يوم: عدد}}، زوّار = {uid: عدد}.

    نسخٌ لا مراجع: القارئ يملك ما يُعاد إليه ولا يُفسد الفهرس.
    """
    with _lock:
        if _state["db"] is not db:          # مخزنٌ آخر (اختبار · تطوير) ⇒ من الصفر
            _state.update(daily=defaultdict(dict), guests={}, synced_at=None,
                          checked=0.0, db=db)
        now = time.time()
        if force or not _state["checked"] or now - _state["checked"] >= TTL:
            started = datetime.now(timezone.utc)
            if _state["synced_at"] is None:
                n = _full_scan(db)
            else:
                try:
                    n = _changed_since(db, _state["synced_at"] - MARGIN)
                except Exception as e:      # ⚠️ استعلامٌ تعذّر ⇒ مسحٌ كامل، لا صفحةٌ معطوبة
                    print(f"⚠️ مزامنة الاستخدام الجزئية تعذّرت ({e}) — مسحٌ كامل.")
                    n = _full_scan(db)
            _state["stats"]["docs_read"] += n
            _state["synced_at"] = started
            _state["checked"] = time.time()
        daily = {uid: dict(days) for uid, days in _state["daily"].items()}
        guests = dict(_state["guests"])
    return defaultdict(dict, daily), guests


def stats() -> dict:
    with _lock:
        return dict(_state["stats"])


def reset() -> None:
    """للاختبارات."""
    with _lock:
        _state.update(daily=defaultdict(dict), guests={}, synced_at=None,
                      checked=0.0, db=None,
                      stats={"full_scans": 0, "incremental": 0, "docs_read": 0})
