# -*- coding: utf-8 -*-
"""📄 البناءُ والتقريرُ وسطرُ الأوامر

    جزءٌ من [build_quizzes.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في ملفٍ لحاله»
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.
"""
from __future__ import annotations
from .boot import (Counter, QB, argparse, asyncio, find_lesson, get_lessons_book, json, lessons_in_unit, lessons_units, normalize_grade_track, quiz_spec, serialize_lesson, subjects_for, time)
from .consts import MAX_CALLS_PER_LESSON
from .sizing import bank_size
from .english import check_bank
from .models import CALLS, route
from .lesson import build_lesson
from .quarantine import quarantine, rescan_all, retry_rejected, salvage_narrow


# ══════════════════════════════════════════════════
# 🚚 البناء
# ══════════════════════════════════════════════════

def lessons_of(grade, track, subject):
    book = get_lessons_book(grade, track, subject)
    if book is None:
        return []
    out = []
    for unit in lessons_units(book):
        for name in lessons_in_unit(book, unit):
            _u, doc = find_lesson(book, unit, name)
            if doc is not None:
                out.append((unit, name, doc))
    return out


async def build_subject(grade, track, subject, *, limit=0, skip_existing=True,
                        retries=1, jobs=2, dry=False):
    items = lessons_of(grade, track, subject)
    if limit:
        items = items[:limit]
    if not items:
        print(f"  — {subject}: لا دروس")
        return (0, 0, 0)

    _key, model = route(subject)
    sem = asyncio.Semaphore(max(1, jobs))
    done = failed = calls_used = 0
    lock = asyncio.Lock()

    async def one(i, unit, name, doc):
        nonlocal done, failed, calls_used
        source = serialize_lesson(doc, unit, subject=subject)
        want = bank_size(source)

        if skip_existing and QB.entry_spec(grade, track, subject, unit, name,
                                           source) == quiz_spec.VERSION:
            return
        if dry:
            print(f"  [{i}] {name[:44]:44s} ⇒ {want} سؤالاً")
            return

        async with sem:
            qs, defects, calls = await build_lesson(
                subject, name, source, want, retries=retries,
                budget=MAX_CALLS_PER_LESSON)

        bad = check_bank(qs, want, source, subject, name) if qs else ["لا أسئلة"]
        async with lock:
            calls_used += calls
            if bad:
                failed += 1
                QB.drop(grade, track, subject, unit, name)
                quarantine(grade, track, subject, unit, name, source, qs,
                           sorted(set(bad + defects)), model)
                print(f"  ❌ [{i}] {name[:38]:38s} {len(qs):2d}/{want} · "
                      f"{bad[0][:60]}")
            else:
                QB.put(grade, track, subject, unit, name, source, qs,
                       model=model, spec=quiz_spec.VERSION)
                done += 1
                ws = Counter(q["weight"] for q in qs)
                print(f"  ✅ [{i}] {name[:38]:38s} {len(qs):2d} سؤالاً · "
                      f"أوزان {dict(sorted(ws.items()))}")

    await asyncio.gather(*[one(i + 1, u, n, d)
                           for i, (u, n, d) in enumerate(items)])
    # 🧾 كلفةُ هذا البناء بالأرقام — لا بالتقدير ([CALLS]).
    if CALLS:
        total = sum(CALLS.values())
        per = total / max(1, len(items))
        detail = " · ".join(f"{k}: {v}" for k, v in sorted(CALLS.items()))
        print(f"  🧾 {len(items)} درساً · {total} نداءً "
              f"({per:.1f} للدرس) — {detail}")
        CALLS.clear()
    return (done, failed, calls_used)


async def build_all(grade, tracks, **kw):
    t0 = time.time()
    total = Counter()
    for track in tracks:
        for subject in subjects_for(grade, track):
            if not lessons_of(grade, track, subject):
                continue
            key, model = route(subject)
            print(f"\n📚 {subject} ({grade}/{track}) → {key}/{model}")
            d, f, c = await build_subject(grade, track, subject, **kw)
            total["done"] += d
            total["failed"] += f
            total["calls"] += c
    print(f"\n{'='*60}\n✅✅✅ اكتمل: {total['done']} بنكاً · "
          f"❌ {total['failed']} · نداءات {total['calls']} · "
          f"{(time.time()-t0)/60:.1f} دقيقة")


def report():
    s = QB.stats()
    print(f"🎯 البنوك: {s['subjects']} ملفاً · {s['lessons']} درساً · "
          f"{s['questions']} سؤالاً")
    for path in sorted(QB.QUIZZES_DIR.rglob("*.json")):
        if "_rejected" in path.parts:
            continue
        data = json.loads(path.read_text(encoding="utf-8")) or {}
        if not data:
            continue
        qs = [q for v in data.values() for q in (v.get("questions") or [])]
        if not qs:
            continue
        lv = Counter(q.get("level") for q in qs)
        ws = Counter(q.get("weight") for q in qs)
        rel = path.relative_to(QB.QUIZZES_DIR)
        print(f"  {str(rel):34s} {len(data):3d} درساً · {len(qs):4d} سؤالاً · "
              f"مستويات {dict(lv)} · أوزان {dict(sorted(ws.items()))}")


async def main():
    p = argparse.ArgumentParser()
    p.add_argument("--grade", type=int, default=3)
    p.add_argument("--track", default="")
    p.add_argument("--subject", default="")
    p.add_argument("--all-grade3", action="store_true",
                   help="مرادفُ «--grade 3 --all» (بقيَ للتوافق)")
    p.add_argument("--all", action="store_true",
                   help="مسارا الصف معاً: علمي وأدبي")
    p.add_argument("--limit", type=int, default=0)
    p.add_argument("--jobs", type=int, default=2)
    p.add_argument("--retries", type=int, default=1)
    p.add_argument("--rebuild", action="store_true", help="لا تتخطَّ المبنيّ")
    p.add_argument("--dry", action="store_true")
    p.add_argument("--rescan", action="store_true")
    p.add_argument("--salvage", action="store_true")
    p.add_argument("--retry-rejected", action="store_true",
                   help="نداءٌ جديدٌ للمحجور وحدَه")
    p.add_argument("--report", action="store_true")
    a = p.parse_args()

    if a.report:
        report()
        return
    if a.rescan:
        await rescan_all()
        return
    if a.salvage:
        await salvage_narrow()
        return
    if a.retry_rejected:
        await retry_rejected(retries=a.retries, jobs=a.jobs)
        return

    kw = dict(limit=a.limit, skip_existing=not a.rebuild,
              retries=a.retries, jobs=a.jobs, dry=a.dry)
    if a.all_grade3 or (a.all and a.grade == 3):
        await build_all(3, ("علمي", "أدبي"), **kw)
        return
    grade, track = normalize_grade_track(a.grade, a.track or "علمي")
    if a.all:
        # 🎓 الأولُ صفٌّ موحّدٌ بلا مسار، والثاني والثالث مساران.
        await build_all(grade, ("عام",) if grade == 1 else ("علمي", "أدبي"),
                        **kw)
        return
    if a.subject:
        key, model = route(a.subject)
        print(f"📚 {a.subject} ({grade}/{track}) → {key}/{model}")
        await build_subject(grade, track, a.subject, **kw)
    else:
        await build_all(grade, (track,), **kw)


