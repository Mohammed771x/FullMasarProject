# -*- coding: utf-8 -*-
"""📄 الإنقاذُ وإعادةُ المسح وسطرُ الأوامر

    جزءٌ من [build_explanations.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في ملفٍ لحاله»
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.
"""
from __future__ import annotations
from .boot import (LC, LM, SUBJECTS_BY_GRADE_TRACK, TA, argparse, get_lessons_book, json, os, serialize_lesson)
from .consts import BUILD_MAX_TOKENS
from .verify import verify
from .generate import (REJECTED_DIR, _install_build_prompt, _reroute_math, _tidy, build_subject, lessons_of)


_MARKER_ONLY = ("بلا تشبيهٍ", "من أين نبدأ", "علاماتُ التدريس")


async def salvage_marker_only() -> None:
    """يُرقّي المحجوزَ الذي عيبُه العلامات — **بصفر نداءات**."""
    from core.content_store import get_lessons_book
    from core.serializer import serialize_lesson
    up = 0
    for path in sorted(REJECTED_DIR.rglob("*.json")):
        track, grade, subject = path.parent.name, path.parent.parent.name, path.stem
        book = get_lessons_book(int(grade), track, subject)
        index = {LC.key_of(u, n): (u, n, l) for u, n, l in lessons_of(book or {})}
        data = json.loads(path.read_text(encoding="utf-8"))
        keep = {}
        for key, e in data.items():
            defects = e.get("defects") or []
            marker_only = defects and all(
                any(m in d for m in _MARKER_ONLY) for d in defects)
            hit = index.get(key)
            if not (marker_only and hit):
                keep[key] = e
                continue
            unit, name, lesson = hit
            fp = serialize_lesson(lesson, unit, subject=subject)
            if subject == "رياضيات":
                from subjects.common import load_math_lesson
                m = load_math_lesson(unit, name)
                if m is None:
                    keep[key] = e
                    continue
                fp = LC.math_source(m)
            LC.put(int(grade), track, subject, unit, name, fp,
                   e["answer"], e.get("model", ""), TA.VERSION)
            up += 1
        if keep:
            path.write_text(json.dumps(keep, ensure_ascii=False, indent=1),
                            encoding="utf-8")
        else:
            path.unlink()
    print(f"✅ رُقِّي {up} شرحاً محلَّ نسخِ الكتاب — بلا أيّ نداء")


async def rescan_all() -> None:
    """♻️ يُعيد الحكمَ على المحجوز بالمقياس الحاليّ — **بصفر نداءات**."""
    from core.content_store import get_lessons_book
    from core.serializer import serialize_lesson
    saved = still = 0
    for path in sorted(REJECTED_DIR.rglob("*.json")):
        track, grade = path.parent.name, path.parent.parent.name
        subject = path.stem
        book = get_lessons_book(int(grade), track, subject)
        index = {LC.key_of(u, n): (u, n, l) for u, n, l in lessons_of(book or {})}
        data = json.loads(path.read_text(encoding="utf-8"))
        keep = {}
        for key, e in data.items():
            hit = index.get(key)
            if not hit:
                keep[key] = e
                continue
            unit, name, lesson = hit
            source = serialize_lesson(lesson, unit, subject=subject)
            bad = verify(subject, lesson, source, e.get("answer") or "", name)
            if bad:
                e["defects"] = bad
                keep[key] = e
                still += 1
                continue
            fp = source
            if subject == "رياضيات":
                from subjects.common import load_math_lesson
                m = load_math_lesson(unit, name)
                if m is None:
                    keep[key] = e
                    continue
                fp = LC.math_source(m)
            LC.put(int(grade), track, subject, unit, name, fp,
                   e["answer"], e.get("model", ""), TA.VERSION)
            saved += 1
            print(f"  ♻️ {subject} › {name[:40]}")
        if keep:
            path.write_text(json.dumps(keep, ensure_ascii=False, indent=1),
                            encoding="utf-8")
        else:
            path.unlink()
    print(f"\n✅ أُنقذ {saved} شرحاً بلا أيّ نداء · وبقي محجوزاً {still}")


def retidy_all(stamp_model: str = "") -> None:
    r"""✂️ **يُعيد تهذيبَ ما خُزّن سلفاً** — بلا نداءِ موديلٍ واحد.

    ⚖️ حين يُكتشف عيبٌ **شكليّ** في المخزون (خطٌّ أفقيٌّ يقطع الخيط · عنوانٌ
       عريضٌ يلتصق بفقرته) فالخيارُ بين إعادة بناءٍ تكلّف مئاتِ النداءات
       وتحويلٍ نصّيٍّ يكلّف صفراً. وما دام العيبُ في **الشكل لا المعنى**
       فالتحويلُ هو الصواب.

    🏷️ ويصحّح كذلك ختمَ النموذج متى مُرِّر — فالشروحُ التي بُنيت قبل إصلاح
       الختم تحمل اسمَ النموذج الافتراضي لا الذي نادى فعلاً.
    """
    changed = files = 0
    for path in sorted(LC.EXPLANATIONS_DIR.rglob("*.json")):
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"⚠️ تعذّرت قراءة {path.name}: {e}")
            continue
        hit = 0
        for entry in data.values():
            if not isinstance(entry, dict):
                continue
            fixed = _tidy(entry.get("answer") or "")
            if fixed != (entry.get("answer") or ""):
                entry["answer"] = fixed
                entry["chars"] = len(fixed)
                hit += 1
            if stamp_model and entry.get("spec") == TA.VERSION \
                    and entry.get("model") != stamp_model:
                entry["model"] = stamp_model
                hit += 1
        if hit:
            tmp = path.with_suffix(".json.tmp")
            tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1),
                           encoding="utf-8")
            os.replace(tmp, path)
            files += 1
            changed += hit
            print(f"  ✂️ {path.parent.parent.name}/{path.parent.name}/"
                  f"{path.stem}: {hit}")
    print(f"\n✅ هُذّب {changed} موضعاً في {files} ملفاً — بلا أيّ نداء")


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--grade", type=int, required=True)
    ap.add_argument("--track", default="عام")
    ap.add_argument("--subject", default="")
    ap.add_argument("--limit", type=int, default=0)
    ap.add_argument("--dry", action="store_true")
    ap.add_argument("--skip-existing", action="store_true",
                    help="تخطَّ ما بُني وبصمتُه مطابقة")
    ap.add_argument("--retries", type=int, default=2)
    # 🧠 **ونموذجٌ أقوى للبناء وحده**: المخزونُ يُكتب مرّةً ويُقرأ دائماً،
    #    فجودتُه تُشترى مرّةً — والطالبُ يبقى على `model_route` كما هي.
    ap.add_argument("--codes-hint", action="store_true",
                    help="أعطِ الموديلَ صيغَ الدرس في النداء الأوّل")
    ap.add_argument("--salvage", action="store_true",
                    help="رقِّ المحجوزَ الذي عيبُه العلامات وحدها — بلا نداء")
    ap.add_argument("--rescan", action="store_true",
                    help="أعد الحكمَ على المحجوز بالمقياس الحاليّ — بلا نداء")
    ap.add_argument("--retidy", action="store_true",
                    help="أعد تهذيبَ المخزون الموجود بلا أيّ نداء")
    ap.add_argument("--jobs", type=int, default=1,
                    help="كم درساً يُبنى معاً (التوازي)")
    ap.add_argument("--provider", default="")
    ap.add_argument("--model", default="")
    args = ap.parse_args()

    if args.codes_hint:
        globals()["HINT_CODES"] = True

    if args.salvage:
        await salvage_marker_only()
        return

    if args.rescan:
        await rescan_all()
        return

    if args.retidy:
        retidy_all(args.model)
        return

    LM._MAX_TOKENS = BUILD_MAX_TOKENS       # 📏 سقفُ التوليد وحده
    _install_build_prompt()                 # 🏗️ ومواصفةُ التوليد وحدها
    subjects = ([args.subject] if args.subject
                else list(SUBJECTS_BY_GRADE_TRACK.get((args.grade, args.track), [])))
    if args.provider and args.model:
        from tools.rescue_explanations import install_model
        globals()["BUILD_MODEL"] = args.model
        install_model(args.provider, args.model, set(subjects))
        _reroute_math(args.provider, args.model)
        print(f"🧠 نموذجُ البناء: {args.model} ({args.provider})")
    all_rows = []
    for s in subjects:
        print(f"\n📘 {s} — الصف {args.grade} {args.track}")
        all_rows += await build_subject(args.grade, args.track, s,
                                        args.limit, args.dry, args.retries,
                                        args.skip_existing, args.jobs)
    if not all_rows:
        return
    ok = [r for r in all_rows if not r[6]]
    print(f"\n{'='*68}")
    print(f"الدروس: {len(all_rows)} · اجتازت: {len(ok)} · أخفقت: {len(all_rows)-len(ok)}")
    if ok:
        print(f"متوسّطُ الشرح: {sum(r[4] for r in ok)//len(ok):,} حرفاً "
              f"(المصدر {sum(r[3] for r in ok)//len(ok):,}) · "
              f"متوسّطُ الزمن {sum(r[5] for r in ok)/len(ok):.1f}ث")
        print(f"حجمٌ تقديري على القرص: {sum(r[4] for r in ok)*2/1024:,.0f} ك.ب")
    for r in all_rows:
        if r[6]:
            print(f"  ❌ {r[0]} › {r[2][:40]}: {' ؛ '.join(r[6])[:130]}")

