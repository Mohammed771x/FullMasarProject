# ==================================================
# 💰 core/ai_usage.py — التوكنات الفعلية والتكلفة الحقيقية لكل نداء موديل
# ==================================================
# 🔴 **لماذا (٢٠٢٦-١٠-٠١):** لم يكن الخادم يعرف كم أنفق. `billing` يعدّ
#    النداءات لا التوكنات، والبثّ لا يطلب `usage` من المزوّد أصلاً — وعدّادٌ
#    محليٌّ سابق قال $6 والفاتورة $12 ([api-cost-ledger-underestimates]).
#
# ✅ **المصدر هو المزوّد نفسه**: `usage` في ردّ كل نداء (وفي آخر قطعة بثّ
#    مع `stream_options={"include_usage": True}`). نحن لا نعدّ شيئاً بأيدينا —
#    نضرب ما قاله المزوّد في جدول الأسعار أدناه، وهو الجزء الوحيد المقدَّر.
#
# أين يذهب كل نداء:
#   ١. سطرٌ في اللوج: `💰 AI …` (المسار · الموديل · التوكنات · الدولار · uid)
#   ٢. عدّادُ الطلب في `billing` (usd + توكنات) — فيُعرف ثمنُ الطلب كاملاً
#   ٣. آخر ٢٠٠ نداء في الذاكرة — للوحة التحكم
#   ٤. مجموعُ اليوم في Firestore: `ai_usage/{YYYY-MM-DD}` بزياداتٍ ذرّية،
#      تُدفع كل ٣٠ ثانية لا مع كل نداء (كتابةٌ واحدة لكل دفعة).
#
# ⚠️ **لا يُسقط طلباً أبداً**: كلُّ عطلٍ هنا يُبتلع — التسجيل خدمةٌ للمالك
#    لا شرطٌ لجواب الطالب.

from __future__ import annotations

import threading
import time
from collections import deque
from datetime import datetime, timezone

# ══════════════ الأسعار — دولار لكل مليون توكن ══════════════
# 📌 من الصفحات الرسمية في ٢٠٢٦-١٠-٠١ — حدّثها هنا وحدها إن تغيّرت:
#    https://api-docs.deepseek.com/quick_start/pricing
#    https://ai.google.dev/gemini-api/docs/pricing
#    `in` = إدخالٌ غير مخزَّن · `hit` = إدخالٌ أصاب الكاش · `out` = إخراج (والتفكيرُ منه)
#
# ⏰ ديب سيك بسعرين: **الذروة** أيام الإثنين–الجمعة 01–04 و06–10 UTC،
#    وما سواها **نصف السعر**. والأرقام أدناه أسعار الذروة.
_DEEPSEEK_FLASH = {"in": 0.30, "hit": 0.006, "out": 1.20, "offpeak_half": True}
_DEEPSEEK_PRO = {"in": 1.32, "hit": 0.044, "out": 3.96, "offpeak_half": True}

PRICES = {
    "deepseek-flash": _DEEPSEEK_FLASH,
    "deepseek-v4-flash": _DEEPSEEK_FLASH,      # اسمٌ قديم يُوجَّه لـFlash بسعره
    "deepseek-v4-pro": _DEEPSEEK_PRO,
    "gemini-3.1-flash-lite": {"in": 0.25, "hit": 0.025, "out": 1.50},
    # 🗓️ سعرُ 3.8-flash مخفَّضٌ حتى نهاية ٢٠٢٦ ثم يتضاعف
    "gemini-3.8-flash": {"in": 0.75, "hit": 0.075, "out": 3.75,
                         "until": "2026-12-31",
                         "after": {"in": 1.50, "hit": 0.15, "out": 7.50}},
}
# ما ليس في الجدول (موديلات أدوات الإدخال مثلاً) تُسجَّل توكناته ويُعدّ
# «بلا سعر» — لا نخترع رقماً.

_PEAK_HOURS_UTC = ((1, 4), (6, 10))

FLUSH_SECONDS = 30.0
RECENT_MAX = 200


def is_deepseek_peak(now: datetime | None = None) -> bool:
    now = now or datetime.now(timezone.utc)
    if now.weekday() >= 5:                      # السبت والأحد خارج الذروة
        return False
    return any(lo <= now.hour < hi for lo, hi in _PEAK_HOURS_UTC)


def price_for(model: str, now: datetime | None = None) -> dict | None:
    """أسعار الموديل الفعّالة الآن — أو None إن لم يكن في الجدول."""
    p = PRICES.get((model or "").strip())
    if p is None:
        return None
    now = now or datetime.now(timezone.utc)
    if p.get("until") and now.strftime("%Y-%m-%d") > p["until"]:
        p = {**p, **p["after"]}
    rates = {k: p[k] for k in ("in", "hit", "out")}
    if p.get("offpeak_half") and not is_deepseek_peak(now):
        rates = {k: v / 2 for k, v in rates.items()}
    return rates


def _get(obj, name, default=None):
    if obj is None:
        return default
    if isinstance(obj, dict):
        return obj.get(name, default)
    return getattr(obj, name, default)


def tokens_of(usage) -> dict | None:
    """يوحّد `usage` المزوّدين: {input, cached, output, reasoning}.

    • ديب سيك: `prompt_cache_hit_tokens` (وتفكيرُه داخل `completion_tokens`).
    • جيميناي: `prompt_tokens_details.cached_tokens` إن وُجد، وتفكيرُه قد يقع
      خارج `completion_tokens` — فالإخراجُ المدفوع = الأكبرُ من
      `completion_tokens` و`total - prompt`. لا نُسقط توكناً يُحاسَب عليه.
    """
    if usage is None:
        return None
    prompt = int(_get(usage, "prompt_tokens", 0) or 0)
    completion = int(_get(usage, "completion_tokens", 0) or 0)
    total = int(_get(usage, "total_tokens", 0) or 0)
    cached = _get(usage, "prompt_cache_hit_tokens")
    if cached is None:
        cached = _get(_get(usage, "prompt_tokens_details"), "cached_tokens", 0)
    cached = min(int(cached or 0), prompt)
    output = max(completion, total - prompt) if total else completion
    reasoning = int(_get(_get(usage, "completion_tokens_details"),
                         "reasoning_tokens", 0) or 0)
    reasoning = max(reasoning, output - completion)
    return {"input": prompt, "cached": cached, "output": output,
            "reasoning": reasoning}


def cost_usd(model: str, tok: dict, now: datetime | None = None) -> float | None:
    rates = price_for(model, now)
    if rates is None or tok is None:
        return None
    fresh = tok["input"] - tok["cached"]
    return (fresh * rates["in"] + tok["cached"] * rates["hit"]
            + tok["output"] * rates["out"]) / 1_000_000


# ══════════════ التجميع ══════════════

_lock = threading.Lock()
_recent: deque = deque(maxlen=RECENT_MAX)
_pending: dict = {}          # {day: {totals…, "models": {…}, "purposes": {…}}}
_last_flush = time.time()
_flushing = False


def _field(name: str) -> str:
    """مفتاحٌ آمن لمسار Firestore: النقطة فيه تعني «حقلاً متداخلاً»."""
    return "".join(c if c.isalnum() or c in "-_" else "_" for c in (name or "?"))[:64]


def _empty() -> dict:
    return {"calls": 0, "input": 0, "cached": 0, "output": 0, "reasoning": 0,
            "usd": 0.0, "unpriced_calls": 0}


def _add(bucket: dict, tok: dict, usd: float | None) -> None:
    bucket["calls"] += 1
    for k in ("input", "cached", "output", "reasoning"):
        bucket[k] += tok[k]
    if usd is None:
        bucket["unpriced_calls"] += 1
    else:
        bucket["usd"] += usd


def record(model: str, usage, purpose: str = "") -> dict | None:
    """يسجّل نداءً واحداً من `usage` الذي أعاده المزوّد. لا يرمي أبداً."""
    try:
        tok = tokens_of(usage)
        if tok is None:
            print(f"💰 AI {purpose or '?'} {model}: لم يُعِد المزوّد usage")
            return None
        from . import billing
        meter = billing.current()
        purpose = purpose or (meter or {}).get("route") or "other"
        uid = (meter or {}).get("uid", "")
        now = datetime.now(timezone.utc)
        usd = cost_usd(model, tok, now)
        if meter is not None:
            meter["usd"] = meter.get("usd", 0.0) + (usd or 0.0)
            for k in ("input", "cached", "output"):
                meter[f"tok_{k}"] = meter.get(f"tok_{k}", 0) + tok[k]

        entry = {"at": now.isoformat(timespec="seconds"), "purpose": purpose,
                 "model": model, "uid": uid, **tok,
                 "usd": None if usd is None else round(usd, 6)}
        price = "بلا سعر" if usd is None else f"${usd:.5f}"
        print(f"💰 AI {purpose} {model} in={tok['input']} cached={tok['cached']} "
              f"out={tok['output']} think={tok['reasoning']} {price} uid={uid[:12]}")

        day = now.strftime("%Y-%m-%d")
        with _lock:
            _recent.append(entry)
            agg = _pending.setdefault(day, {"total": _empty(), "models": {}, "purposes": {}})
            _add(agg["total"], tok, usd)
            _add(agg["models"].setdefault(_field(model), _empty()), tok, usd)
            _add(agg["purposes"].setdefault(_field(purpose), _empty()), tok, usd)
        _maybe_flush()
        return entry
    except Exception as e:                      # التسجيل لا يُسقط جواباً
        print(f"⚠️ تعذّر تسجيل تكلفة النداء: {e}")
        return None


def record_response(response, model: str, purpose: str = ""):
    """لنداءٍ عاديّ (بلا بثّ): يسجّل ثم يعيد الردّ كما هو."""
    record(model, getattr(response, "usage", None), purpose)
    return response


# ══════════════ الحفظ في Firestore ══════════════

def _maybe_flush(force: bool = False) -> None:
    global _last_flush, _flushing
    with _lock:
        due = force or time.time() - _last_flush >= FLUSH_SECONDS
        if not due or _flushing or not _pending:
            return
        batch = dict(_pending)
        _pending.clear()
        _flushing = True
        _last_flush = time.time()
    if force:
        _write(batch)
    else:
        threading.Thread(target=_write, args=(batch,), daemon=True).start()


def _increments(bucket: dict, fs) -> dict:
    return {k: fs.Increment(round(v, 8) if k == "usd" else v)
            for k, v in bucket.items() if v}


def _write(batch: dict) -> None:
    global _flushing
    try:
        from . import quota
        db = quota._firestore()
        if db is None:
            return                              # بلا Firestore: اللوج والذاكرة يكفيان
        from firebase_admin import firestore as fs
        for day, agg in batch.items():
            doc = _increments(agg["total"], fs)
            doc["models"] = {m: _increments(b, fs) for m, b in agg["models"].items()}
            doc["purposes"] = {p: _increments(b, fs) for p, b in agg["purposes"].items()}
            doc["updated_at"] = fs.SERVER_TIMESTAMP
            db.collection("ai_usage").document(day).set(doc, merge=True)
    except Exception as e:
        print(f"⚠️ تعذّر حفظ مجموع التكلفة ({e}) — أُعيد إلى الانتظار.")
        with _lock:                             # لا نفقد ما لم يُحفظ
            for day, agg in batch.items():
                cur = _pending.setdefault(day, {"total": _empty(), "models": {}, "purposes": {}})
                _merge(cur["total"], agg["total"])
                for part in ("models", "purposes"):
                    for k, b in agg[part].items():
                        _merge(cur[part].setdefault(k, _empty()), b)
    finally:
        with _lock:
            _flushing = False


def _merge(into: dict, other: dict) -> None:
    for k, v in other.items():
        into[k] = into.get(k, 0) + v


def flush() -> None:
    """يدفع المعلّق فوراً (للاختبارات وإيقاف الخادم)."""
    _maybe_flush(force=True)


# ══════════════ القراءة — للوحة التحكم ══════════════

def summary(days: int = 7) -> dict:
    """مجاميع آخر [days] يوماً (Firestore + ما لم يُدفع بعد) وآخر النداءات.

    📏 الكلفة: قراءةٌ واحدة لكل يوم — لا مسحٌ لمجموعة.
    """
    from datetime import timedelta
    days = max(1, min(int(days or 7), 90))
    today = datetime.now(timezone.utc)
    names = [(today - timedelta(days=i)).strftime("%Y-%m-%d") for i in range(days)]
    stored = {}
    try:
        from . import quota
        db = quota._firestore()
        if db is not None:
            refs = [db.collection("ai_usage").document(n) for n in names]
            try:                                # رحلةٌ واحدة لكل الأيام
                snaps = list(db.get_all(refs))
            except Exception:                   # مخزنٌ بديل بلا get_all
                snaps = [r.get() for r in refs]
            for snap in snaps:
                if snap.exists:
                    stored[snap.id] = snap.to_dict() or {}
    except Exception as e:
        print(f"⚠️ تعذّرت قراءة مجاميع التكلفة: {e}")

    with _lock:
        pending = {d: {"total": dict(a["total"]),
                       "models": {k: dict(v) for k, v in a["models"].items()},
                       "purposes": {k: dict(v) for k, v in a["purposes"].items()}}
                   for d, a in _pending.items()}
        recent = list(_recent)[::-1]

    series, models, purposes, total = [], {}, {}, _empty()
    for name in reversed(names):
        day = _empty()
        doc = stored.get(name, {})
        _merge(day, {k: doc.get(k, 0) for k in _empty()})
        extra = pending.get(name)
        if extra:
            _merge(day, extra["total"])
        _merge(total, day)
        for part, out in (("models", models), ("purposes", purposes)):
            for k, b in (doc.get(part) or {}).items():
                _merge(out.setdefault(k, _empty()), {x: b.get(x, 0) for x in _empty()})
            for k, b in ((extra or {}).get(part) or {}).items():
                _merge(out.setdefault(k, _empty()), b)
        series.append({"day": name, "usd": round(day["usd"], 4), "calls": day["calls"]})

    per_call = total["usd"] / total["calls"] if total["calls"] else 0.0
    return {"days": days, "total": {**total, "usd": round(total["usd"], 4),
                                    "usd_per_call": round(per_call, 6)},
            "series": series, "models": models, "purposes": purposes,
            "recent": recent[:100],
            "note": "التوكنات من المزوّد نفسه؛ الدولار = التوكنات × جدول الأسعار في core/ai_usage.py"}


def reset() -> None:
    """للاختبارات."""
    global _last_flush
    with _lock:
        _recent.clear()
        _pending.clear()
        _last_flush = time.time()
