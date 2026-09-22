# ==================================================
# 🎯 core/quiz_bank.py — بنكُ أسئلة الدرس، واختيارُ ما يُعرض منه
# ==================================================
#
# ⚖️ **قرار المالك (2026-09-16):** «لكل درسٍ أسئلةٌ مخزونة — مبتدئة ومتوسطة
#    وصعبة، **ومع كل سؤالٍ وزنُ أهمية**. فإذا اختار الطالبُ ثلاثةَ دروسٍ في
#    خمسةَ عشرَ سؤالاً تشيل المهمّات، وإذا اختار درساً واحداً بعشرة تشيل
#    المهمَّ وغيرَ المهمّ والمبتدئَ والصعبَ وكلَّ شيء.»
#
# 🎯 **والأهميةُ ليست الصعوبة** — وهذا لبُّ طلبه: سؤالُ تعريفٍ **سهلٌ**
#    ووزنُه ٥ لأنه عمودُ الدرس، وسؤالُ تطبيقٍ **صعبٌ** ووزنُه ٢ لأنه فرع.
#    فالمحوران مستقلّان، والاختيارُ يوازن بينهما لا يخلطهما.
#
# ══════════════ المعمار: لماذا ملفات، وكيف لا تُبطئ ══════════════
#
# ① **ملفٌّ لكل مادة** `data/quizzes/{صف}/{مسار}/{مادة}.json` — نفسُ نمط
#    [core/lesson_cache] بقرار المالك: صفرُ قراءاتٍ من Firestore · يعمل
#    بلا شبكة · يدخل git فيُراجَع الفرقُ ويُرجَع عنه.
# ② **قراءةٌ واحدةٌ ثم ذاكرة**: `_load` يكيّش المحتوى بمفتاح `mtime`، فالطلبُ
#    الثاني بحثٌ في قاموسٍ لا فتحُ ملف. (قِيس: أوّلُ قراءةٍ مللي ثوانٍ،
#    وما بعدها ميكروثوانٍ.)
# ③ **ولا مسحَ للمقرَّر أبداً** (شرطُ المالك: «ما يروح يبحث في الكورس
#    كامل»): المفتاحُ «الوحدة › الدرس» **مباشر** — `O(1)` مهما كبر البنك.
# ④ **إحماءٌ عند الإقلاع** ([core/warmup]) فلا يدفع أوّلُ طالبٍ ثمنَ التحليل.
# ⑤ **والخادمُ بلا حالة**: ذاكرةُ «ما سُئل قريباً» تأتي **من التطبيق** في
#    الطلب (`seen_ids`)، فلا جلسةَ ولا التصاقَ بخادمٍ بعينه ⇒ يتوسّع أفقياً
#    بنسخٍ متطابقة بلا تنسيقٍ بينها.
# ⑥ **والاتّساق ببصمة نصّ الدرس**: تعديلُ الكتاب يُسقط بنكَه من تلقائه
#    ويعود الطلبُ إلى الموديل — فلا يُسأل طالبٌ عن نصٍّ لم يعد موجوداً.
# ⑦ **وتدهورٌ لطيف**: بنكٌ ناقصٌ أو غائب ⇒ يُكمَّل حيّاً من الموديل
#    ([core/quiz]) — الميزةُ تسريعٌ وجودة، لا شرطُ عمل.

from __future__ import annotations

import hashlib
import json
import math
import os
import random
import re
import threading
import time
from collections import Counter
from pathlib import Path
from typing import Optional

BASE_DIR = Path(__file__).resolve().parent.parent
QUIZZES_DIR = BASE_DIR / "data" / "quizzes"

LEVELS = ("مبتدئ", "متوسط", "صعب")
MAX_WEIGHT = 5

_lock = threading.Lock()
_cache: dict = {}          # path -> (mtime, data)


# ══════════════════════════════════════════════════
# 🗄️ التخزين
# ══════════════════════════════════════════════════

def _file(grade, track, subject: str) -> Path:
    track = (track or "عام").strip() or "عام"
    return QUIZZES_DIR / str(grade) / track / f"{(subject or '').strip()}.json"


def key_of(unit: str, lesson: str) -> str:
    return f"{(unit or '').strip()} › {(lesson or '').strip()}".strip(" ›")


def fingerprint(lesson_text: str) -> str:
    """بصمةُ نصّ الدرس — تُسقط البنكَ إن تغيّر الكتاب."""
    return hashlib.sha1((lesson_text or "").encode("utf-8")).hexdigest()[:16]


def question_id(q: str, options) -> str:
    """بصمةٌ ثابتةٌ للسؤال — عليها تقوم ذاكرةُ «لا تُعده عليّ»."""
    raw = (q or "") + "|" + "|".join(sorted(str(o) for o in (options or [])))
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()[:12]


def load_file(grade, track, subject: str) -> dict:
    """بنكُ المادة كاملاً — يُقرأ مرّةً ويبقى في الذاكرة حتى يتغيّر الملف."""
    path = _file(grade, track, subject)
    try:
        mtime = path.stat().st_mtime
    except OSError:
        return {}
    with _lock:
        hit = _cache.get(str(path))
        if hit and hit[0] == mtime:
            return hit[1]
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(data, dict):
            data = {}
    except Exception as e:                    # ملفٌ معطوب لا يُسقط الخادم
        print(f"⚠️ تعذّرت قراءة بنك «{subject}»: {e}")
        data = {}
    with _lock:
        _cache[str(path)] = (mtime, data)
    return data


def entry(grade, track, subject: str, unit: str, lesson: str) -> Optional[dict]:
    """مدخلُ الدرس كما هو (بمعلوماته) — أو `None`."""
    item = load_file(grade, track, subject).get(key_of(unit, lesson))
    return item if isinstance(item, dict) else None


def entry_spec(grade, track, subject: str, unit: str, lesson: str,
               lesson_text: str) -> Optional[str]:
    """نسخةُ المواصفة التي بُني بها البنك — إن طابقت بصمةُ الدرس.

    ⚖️ بها وحدها صار البناءُ **قابلاً للاستئناف**: بصمةُ الدرس لا تتغيّر حين
       نغيّر طريقةَ وضع الأسئلة، فلولا هذا الحقل لتخطّى `--skip-existing`
       كلَّ بنكٍ قديمٍ ولم يُعَد بناءُ شيء ([lesson_cache.entry_spec]).
    """
    item = entry(grade, track, subject, unit, lesson)
    if item is None or item.get("hash") != fingerprint(lesson_text):
        return None
    return item.get("spec") or ""


def stored_for(grade, track, subject: str, unit: str, lesson: str,
               lesson_text: str) -> Optional[list]:
    """أسئلةُ الدرس المخزونة **إن طابقت بصمةُ نصّه**، وإلا `None`."""
    item = entry(grade, track, subject, unit, lesson)
    if item is None or item.get("hash") != fingerprint(lesson_text):
        return None                            # الدرسُ تغيّر ⇒ البنكُ لاغٍ
    questions = item.get("questions")
    if not isinstance(questions, list) or not questions:
        return None
    return questions


def put(grade, track, subject: str, unit: str, lesson: str, lesson_text: str,
        questions: list, model: str = "", spec: str = "") -> None:
    """يكتب بنكَ درسٍ. **للمولِّد وحده** — لا يُنادى من الخادم."""
    path = _file(grade, track, subject)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {}
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8")) or {}
        except Exception:
            data = {}
    data[key_of(unit, lesson)] = {
        "unit": (unit or "").strip(),
        "lesson": (lesson or "").strip(),
        "hash": fingerprint(lesson_text),
        "spec": spec,
        "model": model,
        "count": len(questions),
        "built_at": time.strftime("%Y-%m-%d"),
        "questions": questions,
    }
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    os.replace(tmp, path)                      # كتابةٌ ذرّية: لا ملفَّ نصفَ مكتوب
    with _lock:
        _cache.pop(str(path), None)


def drop(grade, track, subject: str, unit: str, lesson: str) -> bool:
    """يحذف بنكَ درسٍ — للمولِّد عند سقوط الفحص ([lesson_cache.drop])."""
    path = _file(grade, track, subject)
    if not path.exists():
        return False
    try:
        data = json.loads(path.read_text(encoding="utf-8")) or {}
    except Exception:
        return False
    if data.pop(key_of(unit, lesson), None) is None:
        return False
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    os.replace(tmp, path)
    with _lock:
        _cache.pop(str(path), None)
    return True


def stats() -> dict:
    """جردٌ سريع — تقرؤه لوحةُ التحكم."""
    out = {"subjects": 0, "lessons": 0, "questions": 0}
    if not QUIZZES_DIR.exists():
        return out
    for path in QUIZZES_DIR.rglob("*.json"):
        # 🏥 **والمحجورُ ليس مخزوناً**: عدُّه في الجرد يجعل التقريرَ يقول
        #    «٣٨٢ درساً» والمخدومُ منها ٢٨١ — رقمٌ يطمئن ولا يصدق.
        if "_rejected" in path.parts:
            continue
        try:
            data = json.loads(path.read_text(encoding="utf-8")) or {}
        except Exception:
            continue
        out["subjects"] += 1
        out["lessons"] += len(data)
        out["questions"] += sum(int(v.get("count") or 0) for v in data.values()
                                if isinstance(v, dict))
    return out


def warm() -> int:
    """يُحمّل البنوكَ كلَّها إلى الذاكرة عند الإقلاع.

    ⚡ فلا يدفع **أوّلُ طالب** ثمنَ تحليل JSON. والتكلفةُ مرّةٌ واحدة عند
       الإقلاع، والربحُ في كل طلبٍ بعدها ([core/warmup]).
    """
    n = 0
    if not QUIZZES_DIR.exists():
        return 0
    for path in QUIZZES_DIR.rglob("*.json"):
        if path.name.endswith(".json.tmp"):
            continue
        parts = path.relative_to(QUIZZES_DIR).parts
        if len(parts) != 3:
            continue
        grade, track, subject = parts[0], parts[1], parts[2][:-5]
        n += len(load_file(grade, track, subject))
    return n


# ══════════════════════════════════════════════════
# 🎯 خوارزميةُ الاختيار
# ══════════════════════════════════════════════════
#
# خمسُ خطوات، وكلُّها نقيّةٌ (بلا شبكةٍ ولا قرص) فتُختبر وتُحاكى:
#
# ① **حصّةُ كل درس** — نصفٌ بالتساوي ونصفٌ بحجم بنكه، ثم «أكبر البواقي».
#    فالدرسُ الطويل يأخذ أكثر، والدرسُ القصير لا يُهمَل.
# ② **ضغطُ العمق** — `العمق = حصّتُه ÷ بنكه`، وهو مفتاحُ الخوارزمية كلِّها
#    وترجمةُ كلام المالك حرفياً: كلّما قلَّ ما نأخذه اشتدَّ تركيزُنا على
#    الأهمّ، وكلّما استهلكنا البنكَ اتّسع المدى فنزلنا إلى الأقلّ أهمية.
# ③ **طبقاتُ الصعوبة** — هدفٌ معلَن لكل عدد، يُملأ ثم يُكمَّل عند النقص.
# ④ **سحبٌ مرجَّحٌ بلا إعادة** (سباقٌ أُسّيّ) — لا «أعلى ك» جامدةٌ تعيد نفسَ
#    الاختبار كلَّ مرّة، بل احتمالٌ يتناسب مع `الوزن^α`.
# ⑤ **حرّاسُ التنويع** — لا ثلاثةُ أسئلةٍ عن مفهومٍ واحد، ثم ترتيبٌ من
#    الأسهل إلى الأصعب كما كان ([quiz_prompt] البند ٤).

# 🎚️ الخلطةُ المستهدفة (مبتدئ · متوسط · صعب) لكل عددٍ يسمح به التطبيق.
MIX = {5: (2, 2, 1), 10: (4, 4, 2), 15: (5, 6, 4)}

# 🔁 وزنُ من سُئل قريباً يُضرب في هذا — يتأخّر ولا يُمنع.
#    (المنعُ المطلق يُفرغ البنكَ الصغير فيسقط الاختبار.)
SEEN_PENALTY = 0.15

_MAX_PER_TOPIC = 2


def target_mix(count: int) -> tuple:
    """الخلطةُ المستهدفة — ولأي عددٍ خارج المعتاد نسبةٌ ٤٠/٤٠/٢٠."""
    if count in MIX:
        return MIX[count]
    easy = round(count * 0.4)
    mid = round(count * 0.4)
    return (easy, mid, max(0, count - easy - mid))


def quotas(sizes, count: int) -> list:
    """حصّةُ كل درس من العدد المطلوب — «أكبرُ البواقي» بلا ضياعِ سؤال.

    ⚖️ **ولماذا ليست بالتساوي ولا بالحجم وحده؟** بالتساوي يظلم الدرسَ
       الطويل (نقاطُه أكثر)، وبالحجم وحده قد يبتلع درسٌ ضخمٌ الاختبارَ
       فيخرج درسٌ اختاره الطالبُ بسؤالٍ واحد. فالنصفُ بالنصف.
    """
    n = len(sizes)
    if n == 0 or count <= 0:
        return []
    total = sum(sizes) or 1
    share = [0.5 / n + 0.5 * (s / total) for s in sizes]
    raw = [count * s for s in share]
    q = [max(1, math.floor(x)) if count >= n else 0 for x in raw]
    # ولا تتجاوز حصّةُ درسٍ ما في بنكه
    q = [min(q[i], sizes[i]) for i in range(n)]
    guard = 0
    while sum(q) < count and guard < 1000:
        guard += 1
        room = [i for i in range(n) if q[i] < sizes[i]]
        if not room:
            break
        i = max(room, key=lambda i: raw[i] - q[i])
        q[i] += 1
    while sum(q) > count and guard < 2000:
        guard += 1
        big = [i for i in range(n) if q[i] > 1]
        if not big:
            break
        i = max(big, key=lambda i: q[i] - raw[i])
        q[i] -= 1
    return q


def alpha_for(depth: float) -> float:
    """حدّةُ الاختيار من عمق السحب — قلبُ قرار المالك مترجَماً رقماً."""
    if depth <= 0.30:
        return 3.0          # نأخذ قليلاً من كثير ⇒ الأهمُّ وحده
    if depth <= 0.60:
        return 1.8
    return 1.0              # نستهلك البنكَ أصلاً ⇒ التنويعُ أولى


def _weight_of(q) -> float:
    try:
        w = float(q.get("weight", 3))
    except (TypeError, ValueError):
        w = 3.0
    return min(MAX_WEIGHT, max(1.0, w))


def _level_of(q) -> str:
    lv = str(q.get("level", "")).strip()
    return lv if lv in LEVELS else "متوسط"


def pick_from_lesson(bank: list, count: int, seen: set, rng) -> list:
    """يختار `count` سؤالاً من بنكِ درسٍ واحد."""
    if count <= 0 or not bank:
        return []
    if count >= len(bank):
        return list(bank)

    alpha = alpha_for(count / len(bank))
    want = dict(zip(LEVELS, target_mix(count)))

    def race(q):
        """سباقٌ أُسّيّ: الأصغرُ أوّلاً، واحتمالُ الفوز ∝ الوزن^α.

        ⚖️ وهي الطريقةُ الصحيحة للسحب المرجَّح **بلا إعادة** — والبديلُ
           الساذج (اختر الأعلى) يعطي الطالبَ نفسَ الاختبار في كل محاولة.
        """
        w = _weight_of(q) ** alpha
        if q.get("id") in seen:
            w *= SEEN_PENALTY
        return rng.expovariate(1.0) / max(w, 1e-9)

    chosen, topics = [], Counter()

    def take(q):
        chosen.append(q)
        topics[str(q.get("topic") or "")] += 1

    # ① املأ طبقاتِ الصعوبة
    for lv in LEVELS:
        pool = sorted([q for q in bank if _level_of(q) == lv], key=race)
        have = 0
        for q in pool:
            if have >= want.get(lv, 0):
                break
            if topics[str(q.get("topic") or "")] >= _MAX_PER_TOPIC:
                continue
            take(q)
            have += 1

    # ② أكمل النقصَ من أي مستوى (طبقةٌ فقيرةٌ لا تُسقط الاختبار)
    picked = {id(q) for q in chosen}
    rest = sorted([q for q in bank if id(q) not in picked], key=race)
    for q in rest:
        if len(chosen) >= count:
            break
        if topics[str(q.get("topic") or "")] >= _MAX_PER_TOPIC:
            continue
        take(q)

    # ③ آخرُ ملاذ: تجاهلُ حرسِ التنويع خيرٌ من اختبارٍ ناقص
    picked = {id(q) for q in chosen}
    for q in rest:
        if len(chosen) >= count:
            break
        if id(q) not in picked:
            chosen.append(q)
    return chosen[:count]


# 🔑 **مفتاحُ النصّ** — لتمييز المكرَّر الذي اختلف معرّفُه لاختلافِ
#    خيارٍ أو تشكيلٍ أو رسمِ همزة. يُطبَّع ثم يُبصم، فلا تُخزَّن نصوصٌ طويلة.
_TEXT_TRIM = re.compile(r"[^\w\u0600-\u06FF]+")
_TEXT_FOLD = str.maketrans("أإآىة", "اااية")


def _text_key(q: dict) -> str:
    body = _TEXT_TRIM.sub(" ", str(q.get("q") or "").translate(_TEXT_FOLD))
    return "t:" + hashlib.blake2s(" ".join(body.split()).encode("utf-8"),
                                  digest_size=8).hexdigest()


_LEVEL_ORDER = {"مبتدئ": 0, "متوسط": 1, "صعب": 2}


def select(banks: list, count: int, seen=None, seed=None) -> list:
    """يختار اختباراً من بنوكِ الدروس المطلوبة.

    `banks` قائمةُ `(اسم الدرس، أسئلته)` بترتيب اختيار الطالب.
    `seen` مجموعةُ معرّفاتِ ما سُئل عنه قريباً — **تصل من التطبيق**، فيبقى
    الخادمُ بلا حالةٍ ويتوسّع أفقياً.
    """
    banks = [(name, qs) for name, qs in banks if qs]
    if not banks or count <= 0:
        return []
    rng = random.Random(seed)
    seen = set(seen or ())

    sizes = [len(qs) for _, qs in banks]
    share = quotas(sizes, count)

    # 🔁 **ولا يُسأل الطالبُ عن شيءٍ مرّتين في اختبارٍ واحد.** السؤالُ
    #    الموجودُ في درسين كان يُسحب من كليهما ويُعرض مرّتين. وأخبثُ منه
    #    المكرَّرُ **بصياغةٍ مغايرةٍ قليلاً**: معرّفُه مختلفٌ فيمرّ كسؤالين،
    #    وقد يحمل **جوابين متناقضين** — وهو ما رآه المالكُ بعينه (2026-09-22).
    #
    # ⚖️ و`seen` تبقى **عقوبةً ناعمة** كما صُمّمت — منعُها المطلق يُفرغ
    #    البنكَ الصغير. فالمنعُ القاطعُ لتكرارِ **هذا الاختبار** وحدَه،
    #    ومعه تعويضٌ فلا ينقص العدد.
    out, taken = [], set()

    def admit(q, name):
        k = (q.get("id"), _text_key(q))
        if k[0] in taken or k[1] in taken:
            return False
        taken.update(k)
        item = dict(q)
        item.setdefault("lesson", name)
        out.append(item)
        return True

    for (name, qs), k in zip(banks, share):
        for q in pick_from_lesson(qs, k, seen, rng):
            admit(q, name)

    # 🛟 وتعويضُ ما أسقطه المنع — دورةٌ على البنوك بالترتيب نفسِه
    if len(out) < count:
        for name, qs in banks:
            for q in sorted(qs, key=lambda x: rng.random()):
                if len(out) >= count:
                    break
                admit(q, name)
            if len(out) >= count:
                break

    # 🎚️ **ويُقدَّم الأسهلُ** — القاعدةُ التربوية القائمة منذ اليوم الأول:
    #    اختبارٌ يبدأ بأصعب سؤالٍ يُحبط الطالبَ قبل أن يقيس مستواه.
    out.sort(key=lambda q: _LEVEL_ORDER.get(_level_of(q), 1))
    return out[:count]


# ══════════════════════════════════════════════════
# 🧭 الفهرس — «هل لهذا الدرس بنك؟» بلا فتح البنك
# ══════════════════════════════════════════════════
# ⚖️ يحتاجه ثلاثةٌ: التطبيق ليَعِد الطالبَ بأسئلةٍ فورية، ولوحةُ التحكم
#    لتُري التغطية، والمولِّد ليعرف ما بقي. وكلُّهم لا يحتاج نصَّ سؤال.

def index() -> dict:
    """{«صف/مسار/مادة»: {«الوحدة › الدرس»: عدد الأسئلة}} — خفيفٌ ومحسوب."""
    out: dict = {}
    if not QUIZZES_DIR.exists():
        return out
    for path in sorted(QUIZZES_DIR.rglob("*.json")):
        parts = path.relative_to(QUIZZES_DIR).parts
        if len(parts) != 3:
            continue
        grade, track, subject = parts[0], parts[1], parts[2][:-5]
        data = load_file(grade, track, subject)
        out[f"{grade}/{track}/{subject}"] = {
            k: int(v.get("count") or 0)
            for k, v in data.items() if isinstance(v, dict)
        }
    return out
