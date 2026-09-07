# ==================================================
# 📈 core/analytics.py — التحليلات من البيانات الموجودة فعلاً
# ==================================================
# 🔴 **القاعدة الأولى وما عداها تفصيل: لا رقمَ مُختلَق.**
#    كل رقمٍ هنا مشتقٌّ من مستندٍ يكتبه التطبيق أو الخادم بالفعل. وما لا
#    مصدر له **يُقال إنه غير متاح ويُقال سببه** — لا يُملأ بصفرٍ ولا بتقدير.
#    صفرٌ كاذب أسوأ من فراغٍ صادق: الفراغ يدفع الأدمن للسؤال، والصفر يطمئنه
#    على ما لا يعرفه.
#
# المصادر — كلها موجودة قبل هذا الملف، لم يُنشأ منها شيء لأجل التحليلات:
#   • `users/{uid}`                      ← الحساب: الصف · المسار · الدور · التسجيل
#   • `usage/{uid}_{يوم}`                ← عدّاد الأسئلة اليومي ([27])
#   • `usage/guest_{uid}`                ← تجربة الزائر (تراكمية)
#   • `users/{uid}/results/{id}`         ← نتائج «اختبر نفسك» ([quiz_models.dart])
#   • `users/{uid}/conversations/{id}`   ← محادثات التعليم
#   • `users/{uid}/scholarship_chats/{id}` ← محادثات مساعد المنح
#
# ⚠️ **الفروع تُقرأ بـ`collection_group`** لا بمرورٍ على المستخدمين واحداً
#    واحداً: ألف طالبٍ = ألف رحلةِ شبكة. وإن رفضت Firestore الاستعلامَ
#    (فهرسٌ ناقص عادةً) فالقسم يعود `available:false` **برسالة السبب** ولا
#    يُسقط بقيّة الصفحة — الأرقام التي نجحت تبقى معروضة.
#
# 💰 والكاش ليس ترفاً: مسحُ الفروع يُقرأ بالمستند، والأدمن يفتح اللوحة ويغيّر
#    الفلاتر عشرات المرّات في الدقيقة. ٦٠ ثانية تكفي لألّا يشعر بقِدَمٍ ولا
#    تكلّف قراءةً مكرّرة.

import threading
import time
from collections import defaultdict
from datetime import datetime, timedelta, timezone

from . import audience
from . import quota

CACHE_TTL = 60

# سقفُ ما يُقرأ من كل فرع في المسحة الواحدة. تجاوزه يُعلَن (`truncated`)
# ولا يُخفى — «أرقامٌ من عيّنة» تُقال، ولا تُقدَّم كأنها الكل.
SCAN_LIMIT = 20_000

_lock = threading.Lock()
_cache: dict = {}


class AnalyticsError(Exception):
    """خطأ برسالة عربية جاهزة للعرض في اللوحة."""


def _db():
    db = quota._firestore()
    if db is None:
        raise AnalyticsError(
            "⚠️ Firestore غير متاح على الخادم — التحليلات تحتاج "
            "FIREBASE_SERVICE_ACCOUNT_JSON لقراءة المستخدمين ونتائجهم.")
    return db


def _today() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%d")


def _day_of(offset: int) -> str:
    return (datetime.now(timezone.utc) - timedelta(days=offset)).strftime("%Y-%m-%d")


def _day_list(days: int) -> list:
    """أيام المدّة الأقدم أولاً — بلا فجوات حتى في الأيام الصفرية."""
    return [_day_of(i) for i in range(days - 1, -1, -1)]


def _iso_day(value) -> str:
    """يوم `created_at` أياً كان شكله: نصّ ISO من التطبيق أو طابع Firestore."""
    if not value:
        return ""
    try:                                 # طابع Firestore
        return value.strftime("%Y-%m-%d")
    except AttributeError:
        pass
    text = str(value)
    return text[:10] if len(text) >= 10 and text[4] == "-" else ""


def _num(value, default=0):
    return value if isinstance(value, (int, float)) and not isinstance(value, bool) else default


def _pct(part: int, whole: int) -> float:
    return round(part * 100.0 / whole, 1) if whole else 0.0


# ══════════════ القراءة الخام ══════════════

def _read_users(db) -> list:
    out = []
    for doc in db.collection("users").stream():
        d = doc.to_dict() or {}
        out.append({
            "uid": doc.id,
            "name": str(d.get("name", "")),
            "email": str(d.get("email", "")),
            "grade": d.get("grade"),
            "track": str(d.get("track") or ""),
            "role": d.get("role", "student"),
            "banned": d.get("banned") is True,
            "quota_override": d.get("quota_override"),
            "is_anonymous": d.get("is_anonymous") is True,
            "created_day": _iso_day(d.get("created_at")),
            "updated_day": _iso_day(d.get("updated_at")),
            "notifications": _notif_on(d),
            "notif_general": _notif_on(d, "general"),
            "notif_scholarships": _notif_on(d, "scholarships"),
            "devices": len(d.get("fcm_tokens") or []),
            # ⚠️ الرموز نفسها لا عددها فقط: [push.tokens_for] يقرأ من هذه
            #    الخريطة لا من Firestore ثانيةً — وإسقاطها هنا يعني إشعاراً
            #    «نجح» بلا جهازٍ واحد وصله.
            "fcm_tokens": [t for t in (d.get("fcm_tokens") or [])
                           if isinstance(t, str) and t.strip()],
        })
    return out


def _notif_on(d: dict, kind: str = "any") -> bool:
    """هل يقبل هذا المستخدم إشعاراً من هذا النوع؟

    ⭐ **المفتاحان من شاشة إعدادات التطبيق نفسها** (`إشعارات المنح` ·
       `إشعارات عامة`) — لا مفتاحٌ ثالثٌ اخترعناه في الخادم. فمن يُطفئ
       إشعارات المنح في جواله يخرج من جمهور إشعار المنح **هو بعينه**.

    ⚠️ وغيابُ الحقل يعني «لم يختر بعد» لا «رفض»: حسابٌ سجّل قبل وصول
       الإشعارات لا يُقصى من أول إعلانٍ لأن مفتاحاً لم يكن موجوداً يوم سجّل.
    """
    settings = d.get("settings") if isinstance(d.get("settings"), dict) else {}
    general = settings.get("notif_general", settings.get("notifications"))
    scholarships = settings.get("notif_scholarships", settings.get("notifications"))
    if kind == "general":
        return general is not False
    if kind == "scholarships":
        return scholarships is not False
    # «any» = لم يُطفئ كل شيء — وهو المستعمل في عدّاد التحليلات.
    return general is not False or scholarships is not False


def _read_usage(db):
    """`{uid: {يوم: عدد}}` للطلاب، و`{uid: عدد}` للزوّار."""
    from .admin import _DAILY_KEY
    daily = defaultdict(dict)
    guests = {}
    for doc in db.collection("usage").stream():
        asks = int(_num((doc.to_dict() or {}).get("asks", 0)))
        key = doc.id
        if key.startswith("guest_"):
            guests[key[len("guest_"):]] = asks
            continue
        m = _DAILY_KEY.match(key)
        if m:
            daily[m.group("uid")][m.group("day")] = asks
    return daily, guests


def _owner_uid(doc) -> str:
    """صاحب المستند الفرعي — `users/{uid}/results/{id}` ⇒ `{uid}`.

    ⭐ بدونه لا معنى لأيّ فلترٍ بالصف أو المسار: النتيجة تحمل صفَّها لكنها
       لا تحمل صاحبها، فلا نعرف أهو ضمن الشريحة المطلوبة أم لا.
    """
    try:
        return doc.reference.parent.parent.id
    except Exception:
        return ""


def _scan_group(db, name: str, fields: list):
    """مسحُ فرعٍ بـ`collection_group` — يعيد (سطور, مقطوعة, سبب الفشل).

    الفشل هنا **ليس استثناءً يُرمى**: قسمٌ واحدٌ يتعذّر لا يجوز أن يُفرّغ
    الصفحة كلها من أرقامٍ نجحت قراءتها.
    """
    rows, truncated = [], False
    try:
        query = db.collection_group(name)
        try:                              # مشروعٌ للحقول — يوفّر نقلاً كبيراً
            query = query.select(fields)
        except Exception:
            pass
        try:
            # ⚠️ السقف يُفرض على **الخادم** لا بكسرِ الحلقة وحده: بدونه
            #    يُقرأ (ويُحاسَب على) كلُّ مستندٍ في المجموعة ثم نرمي الزائد.
            query = query.limit(SCAN_LIMIT + 1)
        except Exception:
            pass
        for i, doc in enumerate(query.stream()):
            if i >= SCAN_LIMIT:
                truncated = True
                break
            data = doc.to_dict() or {}
            data["_uid"] = _owner_uid(doc)
            rows.append(data)
    except Exception as e:
        return [], False, f"تعذّر قراءة «{name}»: {e}"
    return rows, truncated, ""


# ══════════════ التحليلات ══════════════

def overview_v2(days: int = 30, segment: str = "all", subject: str = "",
                force: bool = False) -> dict:
    """كل أرقام تبويب التحليلات في نداءٍ واحد — مفلترةً بالشريحة والمدّة."""
    segment = audience.validate(segment)
    days = max(7, min(int(days or 30), 90))
    subject = str(subject or "").strip()

    ckey = (days, segment, subject)
    if not force:
        with _lock:
            hit = _cache.get(ckey)
            if hit and time.time() - hit["ts"] < CACHE_TTL:
                return dict(hit["data"], cached=True)

    data = _compute(days, segment, subject)
    with _lock:
        _cache[ckey] = {"ts": time.time(), "data": data}
        if len(_cache) > 64:              # الفلاتر كثيرة والذاكرة ليست مخزناً
            _cache.pop(next(iter(_cache)))
    return dict(data, cached=False)


def invalidate():
    """يُنادى بعد أي كتابة تغيّر الأرقام (حظر · حدّ) كي لا يرى الأدمن قديماً."""
    with _lock:
        _cache.clear()


def _compute(days: int, segment: str, subject: str) -> dict:
    db = _db()
    users = _read_users(db)
    daily, guests = _read_usage(db)
    ctx = audience.build_context(daily)

    in_segment = audience.filter_users(users, segment, ctx)
    uids = {u["uid"] for u in in_segment}
    period = _day_list(days)
    day_set = set(period)
    today = _today()

    return {
        "period": {"days": days, "from": period[0], "to": period[-1]},
        "segment": {
            "key": segment,
            "label": audience.label(segment),
            "users": len(in_segment),
            "share": _pct(len(in_segment), len(users)),
        },
        "subject_filter": subject,
        "users": _user_metrics(users, in_segment, daily, guests, period, today),
        "asks": _ask_metrics(in_segment, daily, period, today),
        "quota": _quota_metrics(in_segment, daily, today),
        "quiz": _quiz_metrics(db, uids, day_set, subject),
        "assistant": _assistant_metrics(db, uids, day_set, subject),
        "scholarships": _scholarship_metrics(db, uids, day_set),
    }


# ── 👥 المستخدمون ──

def _user_metrics(all_users, seg_users, daily, guests, period, today) -> dict:
    day_set = set(period)
    week = set(period[-7:])
    month = set(period[-30:])

    def active_in(days_set) -> int:
        return sum(1 for u in seg_users
                   if any(daily.get(u["uid"], {}).get(d, 0) > 0 for d in days_set))

    # 📈 النمو: تسجيلات كل يوم + التراكمي. المستخدمون بلا `created_at`
    #    (حسابات قديمة سبقت الحقل) يُعدّون في «بلا تاريخ» ولا يُوزَّعون
    #    على أيامٍ لم يسجّلوا فيها.
    per_day = defaultdict(int)
    undated = 0
    for u in seg_users:
        if u["created_day"]:
            per_day[u["created_day"]] += 1
        else:
            undated += 1

    before = sum(n for day, n in per_day.items() if day < period[0])
    growth, running = [], before + undated
    for day in period:
        running += per_day.get(day, 0)
        growth.append({"day": day, "new": per_day.get(day, 0), "total": running})

    # 🎓 **الصفوف للطلاب وحدهم**: المعلّم له صفٌّ في مستنده أيضاً — الصف
    #    الذي *يُدرّسه* لا الذي يدرس فيه. فعدُّه ضمن «طلاب ثالث علمي» يضخّم
    #    الرقم الذي يبني عليه المالك قراره.
    by_grade = defaultdict(int)
    for u in seg_users:
        if (u.get("role") or "student") != "student":
            continue
        g = u["grade"] if isinstance(u["grade"], int) else "?"
        t = u["track"] or (audience.TRACK_GENERAL if g == 1 else "?")
        by_grade[(g, t)] += 1

    return {
        "total_platform": len(all_users),
        "total": len(seg_users),
        "students": sum(1 for u in seg_users if (u.get("role") or "student") == "student"),
        # 👨‍🏫 **بلا هذا يختفي المعلمون من اللوحة تماماً**: هم خارج «الطلاب»
        #    وخارج جدول الصفوف وخارج «المديرين»، فيصير المجموع أكبر من
        #    مجموع أجزائه بلا تفسير — والمالك لا يعرف كم معلّماً عنده أصلاً.
        "teachers": sum(1 for u in seg_users if u.get("role") == "teacher"),
        "admins": sum(1 for u in seg_users if u["role"] == "admin"),
        "banned": sum(1 for u in seg_users if u["banned"]),
        "guests_platform": len(guests),
        "dau": active_in({today}),
        "wau": active_in(week),
        "mau": active_in(month),
        "new_in_period": sum(per_day.get(d, 0) for d in period),
        "undated": undated,
        "with_notifications": sum(1 for u in seg_users if u["notifications"]),
        "by_grade": sorted(
            [{"grade": g, "track": t, "count": n} for (g, t), n in by_grade.items()],
            key=lambda r: (r["grade"] if isinstance(r["grade"], int) else 99, r["track"])),
        "growth": growth,
    }


# ── 💬 الأسئلة (استهلاك الذكاء الاصطناعي) ──

def _ask_metrics(seg_users, daily, period, today) -> dict:
    uids = [u["uid"] for u in seg_users]
    series = [{"day": d, "asks": sum(daily.get(u, {}).get(d, 0) for u in uids)}
              for d in period]
    in_period = sum(p["asks"] for p in series)
    all_time = sum(sum(daily.get(u, {}).values()) for u in uids)
    askers = sum(1 for u in uids if any(daily.get(u, {}).get(d, 0) > 0 for d in period))

    busiest = max(series, key=lambda p: p["asks"]) if series else {"day": "", "asks": 0}
    return {
        "today": sum(daily.get(u, {}).get(today, 0) for u in uids),
        "in_period": in_period,
        "all_time": all_time,
        "askers_in_period": askers,
        "avg_per_asker": round(in_period / askers, 1) if askers else 0.0,
        "avg_per_day": round(in_period / len(period), 1) if period else 0.0,
        "busiest_day": busiest,
        "series": series,
    }


# ── 🎟️ الحصص ──

def _quota_metrics(seg_users, daily, today) -> dict:
    limit = quota.limit_for(False)
    at_limit, near = 0, 0
    for u in seg_users:
        used = daily.get(u["uid"], {}).get(today, 0)
        cap = u["quota_override"] if isinstance(u["quota_override"], int) else limit
        if cap <= 0:
            continue
        if used >= cap:
            at_limit += 1
        elif used >= cap * 0.8:
            near += 1
    return {
        "student_daily": limit,
        "guest_total": quota.limit_for(True),
        "overrides": sum(1 for u in seg_users if isinstance(u["quota_override"], int)),
        "at_limit_today": at_limit,
        "near_limit_today": near,
    }


# ── 🧠 اختبر نفسك ──

def _quiz_metrics(db, uids: set, day_set: set, subject: str) -> dict:
    rows, truncated, err = _scan_group(
        db, "results",
        ["subject", "grade", "track", "unit", "lessons", "score", "total",
         "duration_sec", "wrong", "asked_per_lesson", "created_at"])
    if err:
        return _unavailable(err)
    if not rows:
        return _empty("لا نتائج اختبارات بعد — القسم يعمل، لكن لم يُنهِ أحدٌ اختباراً.")

    kept = [r for r in rows
            if r.get("_uid") in uids
            and _iso_day(r.get("created_at")) in day_set
            and (not subject or str(r.get("subject", "")) == subject)]
    if not kept:
        return _empty("لا اختبارات ضمن هذا الفلتر — جرّب مدّةً أطول أو شريحةً أوسع.",
                      truncated=truncated)

    score = sum(int(_num(r.get("score"))) for r in kept)
    total = sum(int(_num(r.get("total"))) for r in kept)
    duration = [int(_num(r.get("duration_sec"))) for r in kept if _num(r.get("duration_sec")) > 0]

    by_subject = defaultdict(lambda: {"count": 0, "score": 0, "total": 0})
    per_day = defaultdict(int)
    asked = defaultdict(int)          # {(مادة, درس): عدد الأسئلة}
    wrong = defaultdict(int)          # {(مادة, درس): عدد الأخطاء}
    taken = defaultdict(int)          # {(مادة, درس): كم اختباراً شمله}
    students = set()

    for r in kept:
        subj = str(r.get("subject") or "—")
        s = by_subject[subj]
        s["count"] += 1
        s["score"] += int(_num(r.get("score")))
        s["total"] += int(_num(r.get("total")))
        per_day[_iso_day(r.get("created_at"))] += 1
        students.add(r.get("_uid"))

        # كم سؤالاً جاء من كل درس — والقديم بلا `asked_per_lesson` يُوزَّع
        # كما يوزّعه التطبيق نفسه (`askedFor`)، لا بطريقةٍ ثانية تخالفه.
        per_lesson = r.get("asked_per_lesson")
        lessons = [str(x) for x in (r.get("lessons") or []) if str(x).strip()]
        if isinstance(per_lesson, dict) and per_lesson:
            for lesson, n in per_lesson.items():
                asked[(subj, str(lesson))] += int(_num(n))
                taken[(subj, str(lesson))] += 1
        elif lessons:
            share = max(1, round(int(_num(r.get("total"))) / len(lessons)))
            for lesson in lessons:
                asked[(subj, lesson)] += share
                taken[(subj, lesson)] += 1

        for w in (r.get("wrong") or []):
            if not isinstance(w, dict):
                continue
            lesson = str(w.get("lesson") or "").strip()
            if lesson:
                wrong[(subj, lesson)] += 1

    subjects = [{"subject": k, "count": v["count"],
                 "avg_percent": _pct(v["score"], v["total"])}
                for k, v in by_subject.items()]
    subjects.sort(key=lambda r: (-r["count"], r["subject"]))

    # ⚠️ «أفضل وأسوأ مادة» تحتاج عيّنةً تُصدَّق: اختبارٌ واحدٌ بدرجةٍ كاملة
    #    ليس «أفضل مادة». نشترط ثلاثة اختبارات فأكثر ونقول ذلك في اللوحة.
    ranked = sorted([s for s in subjects if s["count"] >= 3],
                    key=lambda r: r["avg_percent"])

    top_lessons = sorted(
        [{"subject": s, "lesson": l, "asked": n, "quizzes": taken[(s, l)]}
         for (s, l), n in asked.items()],
        key=lambda r: -r["asked"])[:12]

    # الأصعب = نسبة الخطأ لا عدده: تسعةُ أخطاء من مئة سؤالٍ أهون من
    # خطأين من ثلاثة. ونشترط عشرة أسئلة فأكثر كي لا تتصدّر الصدفة.
    weak = []
    for (s, l), n in wrong.items():
        total_asked = asked.get((s, l), 0)
        if total_asked >= 10:
            weak.append({"subject": s, "lesson": l, "asked": total_asked,
                         "wrong": n, "error_rate": _pct(n, total_asked)})
    weak.sort(key=lambda r: (-r["error_rate"], -r["wrong"]))

    return {
        "available": True,
        "note": "",
        "truncated": truncated,
        "count": len(kept),
        "students": len(students),
        "avg_percent": _pct(score, total),
        "questions": total,
        "avg_duration_sec": round(sum(duration) / len(duration)) if duration else 0,
        "by_subject": subjects,
        "best_subjects": list(reversed(ranked[-3:])),
        "worst_subjects": ranked[:3],
        "ranked_min_quizzes": 3,
        "top_lessons": top_lessons,
        "weak_lessons": weak[:12],
        "weak_min_asked": 10,
        "series": [{"day": d, "count": n} for d, n in sorted(per_day.items())],
    }


# ── 💬 مساعد التعليم ──

def _assistant_metrics(db, uids: set, day_set: set, subject: str) -> dict:
    rows, truncated, err = _scan_group(
        db, "conversations", ["subject", "mode", "grade", "track", "last_updated"])
    if err:
        return _unavailable(err)
    if not rows:
        return _empty("لا محادثات مزامَنة بعد.")

    kept = [r for r in rows
            if r.get("_uid") in uids
            and _iso_day(r.get("last_updated")) in day_set
            and (not subject or str(r.get("subject", "")) == subject)]
    if not kept:
        return _empty("لا محادثات ضمن هذا الفلتر.", truncated=truncated)

    by_subject = defaultdict(int)
    by_mode = defaultdict(int)
    for r in kept:
        by_subject[str(r.get("subject") or "—")] += 1
        by_mode[str(r.get("mode") or "—")] += 1

    return {
        "available": True, "note": "", "truncated": truncated,
        "count": len(kept),
        "students": len({r.get("_uid") for r in kept}),
        "by_subject": sorted([{"subject": k, "count": v} for k, v in by_subject.items()],
                             key=lambda r: -r["count"])[:12],
        "by_mode": sorted([{"mode": k, "count": v} for k, v in by_mode.items()],
                          key=lambda r: -r["count"]),
    }


# ── 🎓 تفاعل المنح ──

def _scholarship_metrics(db, uids: set, day_set: set) -> dict:
    rows, truncated, err = _scan_group(
        db, "scholarship_chats",
        ["scholarship_id", "scholarship_name", "last_updated", "created_at"])
    if err:
        return _unavailable(err)
    if not rows:
        return _empty("لا محادثات منح بعد — لم يفتح أحدٌ مساعد منحة.")

    kept = [r for r in rows
            if r.get("_uid") in uids
            and (_iso_day(r.get("last_updated")) or _iso_day(r.get("created_at"))) in day_set]
    if not kept:
        return _empty("لا تفاعل مع المنح ضمن هذا الفلتر.", truncated=truncated)

    per = defaultdict(lambda: {"chats": 0, "students": set(), "name": ""})
    for r in kept:
        sid = str(r.get("scholarship_id") or "—")
        entry = per[sid]
        entry["chats"] += 1
        entry["students"].add(r.get("_uid"))
        entry["name"] = str(r.get("scholarship_name") or sid)

    items = sorted(
        [{"id": k, "name": v["name"], "chats": v["chats"], "students": len(v["students"])}
         for k, v in per.items()],
        key=lambda r: -r["chats"])
    return {
        "available": True, "note": "", "truncated": truncated,
        "count": len(kept),
        "students": len({r.get("_uid") for r in kept}),
        "by_scholarship": items[:15],
    }


# ── حالات «لا بيانات» ──
# ⭐ الفرق مقصود: `available:false` يعني **تعذّرت القراءة** (عطلٌ يُصلَح)،
#    و`available:true` بعدّادٍ صفرٍ يعني **قُرئت فوجدناها فارغة** (لا عطل).
#    خلطهما يجعل الأدمن يطارد عطلاً لا وجود له، أو يطمئن لعطلٍ قائم.

def _unavailable(reason: str) -> dict:
    return {"available": False, "note": f"⚠️ {reason}", "count": 0}


def _empty(note: str, truncated: bool = False) -> dict:
    return {"available": True, "note": f"ℹ️ {note}", "truncated": truncated, "count": 0}
