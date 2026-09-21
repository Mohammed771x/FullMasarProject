# -*- coding: utf-8 -*-
"""📄 الحَجْرُ والإنقاذ — لا تُتلف بنكاً رفضه مقياسُك

    جزءٌ من [build_quizzes.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في ملفٍ لحاله»
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.
"""
from __future__ import annotations
from .boot import (DRAW, Path, QB, _norm_codes, asyncio, extract_json, find_lesson, get_lessons_book, json, os, quiz_spec, serialize_lesson, time)
from .consts import MAX_CALLS_PER_LESSON, REJECTED_DIR, _MAX_SOURCE
from .sizing import bank_size
from .weights import calibrate_weights
from .checks import _bank_floor, check_question
from .english import check_bank
from .models import ask_model, route
from .repair import tidy_question
from .lesson import build_lesson


# ══════════════════════════════════════════════════
# 🏥 الحَجْر — لا تُتلف بنكاً رفضه مقياسُك
# ══════════════════════════════════════════════════
# ☢️ درسٌ مدفوعُ الثمن ([[lesson-explanation-cache]]): ستُّ مرّاتٍ كان المقياسُ
#    هو المخطئ، وفي كلٍّ منها كان الجوابُ الصحيحُ قد أُتلف فلم يبقَ إلا
#    إعادةُ شرائه. فالمرفوضُ يُحفظ، و`--rescan` يعيد الحكمَ بصفر نداءات.

def _rej_file(grade, track, subject: str) -> Path:
    return REJECTED_DIR / str(grade) / (track or "عام") / f"{subject}.json"


def quarantine(grade, track, subject, unit, lesson, source, questions,
               defects, model) -> None:
    path = _rej_file(grade, track, subject)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {}
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8")) or {}
        except Exception:
            data = {}
    data[QB.key_of(unit, lesson)] = {
        "unit": unit, "lesson": lesson, "hash": QB.fingerprint(source),
        "spec": quiz_spec.VERSION, "model": model, "defects": defects,
        "count": len(questions), "built_at": time.strftime("%Y-%m-%d"),
        "questions": questions,
    }
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    os.replace(tmp, path)


# 🤝 **الترقيةُ حين يكون البديلُ أسوأ**
#
# ☢️ درسٌ مدفوعُ الثمن من بناء الشروح: **القرارُ ليس بين الكامل والناقص بل
#    بين هذا وذاك.** بنكٌ من عشرين سؤالاً صحيحاً معايَرِ الأوزان، عيبُه أن
#    نقاطه ستٌّ لا تسع — البديلُ عنه **توليدٌ حيٌّ بلا حارسِ تغطيةٍ أصلاً**،
#    يكلّف نداءً في كل اختبار ويأتي بنقاطٍ أخشن. فرفضُه يضرّ الطالبَ مرّتين.
#
# 🔒 **وحدُّها صارم**: العيبُ في الاتّساع وحده. أما نقصُ العدد أو غيابُ
#    مستوىً أو سقوطُ ترميزِ رسمٍ فلا يُرقّى معه شيء — تلك عيوبٌ يراها الطالب.
_SALVAGEABLE = ("التغطيةُ ضيّقة", "تبدأ بـ«ما هو")


async def salvage_narrow() -> None:
    """يرقّي المحجورَ الذي عيبُه الاتّساعُ وحده — بصفر نداءات."""
    if not REJECTED_DIR.exists():
        print("لا محجورَ بعد.")
        return
    saved = 0
    for path in sorted(REJECTED_DIR.rglob("*.json")):
        parts = path.relative_to(REJECTED_DIR).parts
        if len(parts) != 3:
            continue
        grade, track, subject = int(parts[0]), parts[1], parts[2][:-5]
        data = json.loads(path.read_text(encoding="utf-8")) or {}
        keep = {}
        book = get_lessons_book(grade, track, subject)
        for key, item in data.items():
            qs = item.get("questions") or []
            _u, doc = find_lesson(book, item.get("unit", ""),
                                  item.get("lesson", "")) if book else (None, None)
            if doc is None or not qs:
                keep[key] = item
                continue
            src = serialize_lesson(doc, item.get("unit", ""), subject=subject)
            bad = check_bank(qs, bank_size(src), src, subject, item.get("lesson", ""))
            narrow = bad and all(any(w in d for w in _SALVAGEABLE) for d in bad)
            if not bad or (narrow and len(qs) >= 16):
                QB.put(grade, track, subject, item["unit"], item["lesson"], src,
                       qs, model=item.get("model", ""), spec=quiz_spec.VERSION)
                saved += 1
                mark = "✅" if not bad else "🤝"
                print(f"  {mark} {subject} › {item['lesson'][:38]} ({len(qs)})")
            else:
                keep[key] = item
        tmp = path.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(keep, ensure_ascii=False, indent=1), encoding="utf-8")
        os.replace(tmp, path)
    print(f"\n🤝 رُقّي {saved} بنكاً بصفر نداءات.")


async def rescan_all() -> None:
    """يعيد الحكمَ على المحجور بالمقياس الحالي — **بصفر نداءات**."""
    if not REJECTED_DIR.exists():
        print("لا محجورَ بعد.")
        return
    saved = 0
    for path in sorted(REJECTED_DIR.rglob("*.json")):
        parts = path.relative_to(REJECTED_DIR).parts
        if len(parts) != 3:
            continue
        grade, track, subject = parts[0], parts[1], parts[2][:-5]
        data = json.loads(path.read_text(encoding="utf-8")) or {}
        keep = {}
        for key, item in data.items():
            qs = item.get("questions") or []
            book = get_lessons_book(int(grade), track, subject)
            src = ""
            if book is not None:
                _u, doc = find_lesson(book, item.get("unit", ""), item.get("lesson", ""))
                if doc is not None:
                    src = serialize_lesson(doc, item.get("unit", ""), subject=subject)
            bad = check_bank(qs, len(qs), src, subject) if qs else ["فارغ"]
            if not bad:
                QB.put(int(grade), track, subject, item["unit"], item["lesson"],
                       src, qs, model=item.get("model", ""), spec=quiz_spec.VERSION)
                saved += 1
                print(f"  ✅ أُنقذ: {subject} › {item['lesson'][:40]}")
            else:
                keep[key] = item
        tmp = path.with_suffix(".json.tmp")
        tmp.write_text(json.dumps(keep, ensure_ascii=False, indent=1), encoding="utf-8")
        os.replace(tmp, path)
    print(f"\n🏥 أُنقذ {saved} بنكاً بصفر نداءات.")



# ➕ **سدُّ نقص الترميز بنداءٍ واحد** — لا إعادةَ بناءٍ لبنكٍ مكتمل.
async def topup_notation(subject, lesson, source, questions):
    """يطلب الأسئلةَ الناقصةَ وحدَها ويضمُّها. يعيد `(أسئلة، نداءات)`."""
    from tools.build_explanations import DRAW, _norm_codes
    need, _s = quiz_spec.notation_quota(source)
    have = sum(1 for q in questions
               if DRAW.search(_norm_codes(q["q"] + " ".join(q["options"]))))
    gap = need - have
    if gap <= 0:
        return questions, 0
    msgs = [
        {"role": "system", "content": quiz_spec.system_prompt(subject, gap)},
        {"role": "user",
         "content": quiz_spec.topup_prompt(lesson, source[:_MAX_SOURCE], gap,
                                           [q["q"] for q in questions], source)},
    ]
    try:
        raw = await ask_model(subject, msgs)
    except Exception:                                    # noqa: BLE001
        return questions, 1
    data = extract_json(raw)
    if not isinstance(data, dict) or not isinstance(data.get("questions"), list):
        return questions, 1

    seen = {q["id"] for q in questions}
    added = []
    for item in data["questions"]:
        fixed = tidy_question(item, lesson, subject)
        if fixed is None or fixed["id"] in seen or check_question(fixed, subject):
            continue
        # ☢️ **ولا يُقبل إلا ما حمل الترميزَ فعلاً** — وإلا كان النداءُ هباءً
        #    وصار البنكُ أطولَ بلا أن يُصلَح عيبُه.
        if not DRAW.search(_norm_codes(fixed["q"] + " ".join(fixed["options"]))):
            continue
        seen.add(fixed["id"])
        added.append(fixed)
        if len(added) >= gap:
            break
    if not added:
        return questions, 1
    out = questions + added
    calibrate_weights(out, source)
    return out, 1


# ➕ **وسدُّ نقص العدد** — نفسُ المبدأ: ما نقص يُطلب وحدَه.
async def topup_count(subject, lesson, source, questions, want):
    """يطلب الأسئلةَ الناقصةَ عدداً ويضمُّها. يعيد `(أسئلة، نداءات)`."""
    floor = _bank_floor(want)
    gap = floor - len(questions)
    if gap <= 0:
        return questions, 0
    msgs = [
        {"role": "system", "content": quiz_spec.system_prompt(subject, gap)},
        {"role": "user",
         "content": quiz_spec.topup_count_prompt(
             lesson, source[:_MAX_SOURCE], gap + 2,
             [q["q"] for q in questions])},
    ]
    try:
        raw = await ask_model(subject, msgs)
    except Exception:                                    # noqa: BLE001
        return questions, 1
    data = extract_json(raw)
    if not isinstance(data, dict) or not isinstance(data.get("questions"), list):
        return questions, 1

    seen = {q["id"] for q in questions}
    out = list(questions)
    for item in data["questions"]:
        fixed = tidy_question(item, lesson, subject)
        if fixed is None or fixed["id"] in seen or check_question(fixed, subject):
            continue
        seen.add(fixed["id"])
        out.append(fixed)
    if len(out) == len(questions):
        return questions, 1
    calibrate_weights(out, source)
    return out, 1

# 🔁 **وإعادةُ المحجور وحدَه** — بعد أن يتحسّن الطلبُ أو يُصلَح المصدر.
#
# ⚖️ ولماذا أمرٌ مستقلّ؟ لأن `--rebuild` يعيد **المادّة كلَّها** فيحرق مئةَ
#    نداءٍ في بنوكٍ سليمة، و`--rescan` لا ينفع إلا إن كان العيبُ في المقياس.
#    والحالةُ الثالثة — طلبٌ أفضلُ ومصدرٌ أنظف — تحتاج نداءً جديداً
#    **للمحجور وحده**، وهو هنا ١٣ درساً لا ٢٥٢.
async def retry_rejected(*, retries: int = 1, jobs: int = 2) -> None:
    if not REJECTED_DIR.exists():
        print("لا محجورَ بعد.")
        return
    items = []
    for path in sorted(REJECTED_DIR.rglob("*.json")):
        parts = path.relative_to(REJECTED_DIR).parts
        if len(parts) != 3:
            continue
        grade, track, subject = int(parts[0]), parts[1], parts[2][:-5]
        for key, item in (json.loads(path.read_text(encoding="utf-8")) or {}).items():
            items.append((grade, track, subject, item))
    if not items:
        print("لا محجورَ بعد.")
        return

    print(f"🔁 إعادةُ {len(items)} بنكاً محجوراً")
    sem = asyncio.Semaphore(max(1, jobs))
    saved = failed = calls_used = 0
    lock = asyncio.Lock()

    async def one(grade, track, subject, item):
        nonlocal saved, failed, calls_used
        unit, name = item.get("unit", ""), item.get("lesson", "")
        book = get_lessons_book(grade, track, subject)
        _u, doc = find_lesson(book, unit, name) if book is not None else (None, None)
        if doc is None:
            return
        source = serialize_lesson(doc, unit, subject=subject)
        want = bank_size(source)
        _key, model = route(subject)
        async with sem:
            qs, defects, calls = await build_lesson(
                subject, name, source, want, retries=retries,
                budget=MAX_CALLS_PER_LESSON)
        bad = check_bank(qs, want, source, subject, name) if qs else ["لا أسئلة"]
        # ➕ وإن كان العيبُ الباقي هو الترميزَ وحدَه، فالنقصُ يُسدُّ بنداءٍ
        #    واحدٍ لا بإعادةِ بناءٍ رابعة.
        if qs and bad and all("ترميزَ رسمٍ" in d for d in bad):
            async with sem:
                qs, extra = await topup_notation(subject, name, source, qs)
            calls += extra
            bad = check_bank(qs, want, source, subject, name)
        # ➕ ونقصُ العدد كذلك — إن كان هو العيبَ الباقي وحدَه.
        if qs and bad and all("أقلُّ من المطلوب" in d for d in bad):
            async with sem:
                qs, extra = await topup_count(subject, name, source, qs, want)
            calls += extra
            bad = check_bank(qs, want, source, subject, name)
        async with lock:
            calls_used += calls
            if bad:
                failed += 1
                # 🏆 **ولا يُستبدل المحجورُ إلا بأفضلَ منه.** ☢️ وقع فعلاً
                #    (2026-09-17): محاولةٌ ثانيةٌ أعادت «الطلب» ٢٥ سؤالاً
                #    فمحت محاولةً محجورةً فيها ٣٩ — والقاعدةُ مقرّرةٌ أصلاً
                #    داخل [build_lesson]، ونسيتُها عند الحجر. والترتيبُ
                #    نفسُه: أقلُّ عيوباً، ثم أكثرُ أسئلة.
                old = _rejected_entry(grade, track, subject, unit, name)
                score = (len(bad), -len(qs))
                # ⚠️ **ويُقاس القديمُ بالمقياس نفسِه، لا بقائمته المخزونة**:
                #    المخزونةُ تضمّ عيوبَ الأسئلة المطروحة أيضاً، فمقارنتُها
                #    بعيوب البنك وحدها تُظهر الجيّدَ أسوأَ فيُمحى. (وقع
                #    فعلاً: بنكُ «العرض» ذو ٢٥ سؤالاً محاه ذو ٢١.)
                old_qs = (old or {}).get("questions") or []
                kept = None
                if old_qs:
                    old_bad = check_bank(old_qs, want, source, subject, name)
                    kept = (len(old_bad), -len(old_qs))
                if kept is None or score <= kept:
                    quarantine(grade, track, subject, unit, name, source, qs,
                               sorted(set(bad + defects)), model)
                    print(f"  ❌ {name[:38]:38s} {len(qs):2d}/{want} · {bad[0][:60]}")
                else:
                    print(f"  ❌ {name[:38]:38s} {len(qs):2d}/{want} · "
                          f"أُبقيت المحجورةُ الأفضل ({-kept[1]} سؤالاً)")
            else:
                QB.put(grade, track, subject, unit, name, source, qs,
                       model=model, spec=quiz_spec.VERSION)
                _unquarantine(grade, track, subject, unit, name)
                saved += 1
                print(f"  ✅ {name[:38]:38s} {len(qs)} سؤالاً")

    await asyncio.gather(*(one(*it) for it in items))
    print(f"\n🔁 أُنقذ {saved} · بقي {failed} · نداءات {calls_used}")



def _rejected_entry(grade, track, subject, unit, lesson):
    """المدخلُ المحجور إن وُجد — كي يُقارَن بالمحاولة الجديدة قبل استبداله."""
    path = _rej_file(grade, track, subject)
    if not path.exists():
        return None
    data = json.loads(path.read_text(encoding="utf-8")) or {}
    return data.get(f"{unit} › {lesson}")

def _unquarantine(grade, track, subject, unit, lesson) -> None:
    """يحذف المدخلَ من ملف الحجر بعد نجاحه — فلا يُعاد بناؤه مرّتين."""
    path = _rej_file(grade, track, subject)
    if not path.exists():
        return
    data = json.loads(path.read_text(encoding="utf-8")) or {}
    data.pop(f"{unit} › {lesson}", None)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    os.replace(tmp, path)


