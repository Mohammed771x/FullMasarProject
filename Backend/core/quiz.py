# ==================================================
# 🧠 core/quiz.py — توليد اختبار من دروس الطالب
# ==================================================
# «اختبر نفسك»: الطالب يختار وحدة ثم حتى ثلاثة دروس، فتُولَّد أسئلة **من نصّ
# تلك الدروس وحدها** ([31](../../docs/31-quiz-plan.md)).
#
# قرارات المالك المطبَّقة هنا:
#   • **نظام الدروس لكل المواد بلا استثناء** — لا حالة خاصة للأحياء. المادة
#     التي لا دروس لها اليوم تعمل تلقائياً فور إضافة دروسها، بلا لمس كود.
#   • الأسئلة **لا تُخزَّن أبداً** — تُولَّد وتُستهلك ([03§5]).
#   • الصعوبة متدرّجة داخل الاختبار، والبرومبت في `quiz_prompt.py` منفصلاً.
#
# التحقق صارم عمداً: سؤال مشوّه في اختبار = ثقة مفقودة عند الطالب.

import json
import re
import random
import asyncio

from .content_store import (get_lessons_book, lessons_units,
                            lessons_in_unit, find_lesson, _clean)
from . import quiz_bank
from .curriculum import (model_route, normalize_grade_track,
                         is_valid_subject, call_budget, reasoning_kwargs)
from .serializer import serialize_lesson
from . import quiz_prompt

MAX_LESSONS = 3                 # سقف اختيار الطالب (قرار المالك)
ALLOWED_COUNTS = (5, 10, 15)
DEFAULT_COUNT = 10
_AI_TIMEOUT = 60
_MAX_TOKENS = 4000
_MAX_CHARS_PER_LESSON = 6000    # حارس حجم البرومبت مع ثلاثة دروس


class QuizError(Exception):
    """خطأ برسالة عربية جاهزة للعرض للطالب."""


# ══════════════ تجهيز النص ══════════════

def _clip(text: str, limit: int) -> str:
    r"""يقصّ نصّ الدرس عند السقف **بلا شطرِ ترميزِ رسمٍ نصفين**.

    🔴 درس «قواعد تسمية مشتقات البنزين» ٦٠٤٢ حرفاً والسقف ٦٠٠٠: القصُّ الأعمى
       قد يقف داخل `\ring{6|ar|+Br@1` فيصل الموديلَ ترميزٌ مبتور، فينقله كما
       أُمر — ويقرؤه الطالبُ **خاماً** على شاشة اختباره. فنرجع إلى ما قبل
       بداية الترميز الناقص: خسارةُ أسطرٍ أهونُ من رسمةٍ مكسورة.
    """
    if len(text) <= limit:
        return text
    cut = text[:limit]
    start = cut.rfind("\\")
    if start != -1 and "{" in cut[start:] and "}" not in cut[start:]:
        return cut[:start].rstrip()
    return cut


def collect_lessons_text(grade, track, subject, unit, lessons):
    """يجمع نصوص الدروس المطلوبة. يرمي QuizError برسالة واضحة عند التعذّر."""
    grade, track = normalize_grade_track(grade, track)
    if not is_valid_subject(grade, track, subject):
        raise QuizError("❌ هذه المادة غير مقررة على صفك.")

    book = get_lessons_book(grade, track, subject)
    if book is None:
        raise QuizError(
            f"📁 دروس «{subject}» لهذا الصف لم تُضف بعد 🚧\n"
            "الاختبارات تُبنى من الدروس — عد إلينا قريباً.")

    units = lessons_units(book)
    if unit and unit not in units:
        raise QuizError(f"❌ لم أجد الوحدة «{unit}» في هذه المادة.")

    wanted = [l for l in (lessons or []) if str(l).strip()][:MAX_LESSONS]
    if not wanted:
        # بلا تحديد ⇒ كل دروس الوحدة (بحد MAX_LESSONS كي لا ينتفخ البرومبت)
        wanted = lessons_in_unit(book, unit)[:MAX_LESSONS] if unit else []
    if not wanted:
        raise QuizError("📖 اختر درساً واحداً على الأقل لبناء الاختبار.")

    blocks, used = [], []
    for name in wanted:
        _u, lesson = find_lesson(book, unit or "", name)
        if lesson is None:
            _u, lesson = find_lesson(book, "", name)
        if lesson is None:
            continue
        text = _clip(serialize_lesson(lesson, unit or "", subject=subject),
                     _MAX_CHARS_PER_LESSON)
        blocks.append(f"━━━ الدرس: {name} ━━━\n{text}")
        used.append(name)

    if not blocks:
        raise QuizError("❌ لم أجد نصّ الدروس المختارة. جرّب دروساً أخرى.")
    return "\n\n".join(blocks), used


# ══════════════════════════════════════════════════
# 🎯 البنكُ المخزون — قبل أي نداءِ موديل
# ══════════════════════════════════════════════════
#
# ⚖️ **قرار المالك (2026-09-16):** «سوِّ كاشنج لاختبر نفسك — لكل درسٍ أسئلةٌ
#    مخزونة بمستوياتٍ وأوزانِ أهمية، وخوارزميةُ اختيارٍ تشيل المهمّ حسب
#    كم درساً اختار الطالبُ وكم سؤالاً طلب.»
#
# 🛟 **وتدهورٌ لطيف**: درسٌ بلا بنك، أو بنكٌ أصغرُ من الطلب ⇒ يمضي الطلبُ
#    كلُّه إلى الموديل كما كان حرفاً بحرف. الميزةُ تسريعٌ وجودة لا شرطُ عمل،
#    فلا ينكسر الاختبارُ يوماً لأن البناءَ لم يبلغ درساً بعد.
#
# 💳 **وبلا نداءِ موديل ⇒ لا خصمَ من الحصة** — يردّها `/quiz/generate` حين
#    يرى `cached`، كما يفعل الشرحُ المخزون ([core/lesson_cache]).

def collect_banks(grade, track, subject, unit, lessons):
    """يعيد `(بنوكٌ حاضرة، دروسٌ بلا بنك)` — وبصمةُ كل درسٍ تُتحقَّق.

    ⚠️ **واسمُ الوحدة يُحلّ من الكتاب لا من الطلب**: المولِّد يبصم النصَّ
       باسم وحدةِ الدرس الحقيقية، فلو بصمنا هنا بـ`unit` الفارغة القادمة
       من التطبيق لاختلفت البصمتان و**لأخطأ البنكُ دائماً بلا شكوى**
       — وهي نفسُ علّة [lesson_cache.math_source] بعينها.
    """
    grade, track = normalize_grade_track(grade, track)
    book = get_lessons_book(grade, track, subject)
    if book is None:
        return [], list(lessons or [])

    banks, missing = [], []
    for name in (lessons or []):
        _u, doc = find_lesson(book, unit or "", name)
        if doc is None:
            _u, doc = find_lesson(book, "", name)
        if doc is None:
            missing.append(name)
            continue
        unit_name = _clean((_u or {}).get("اسم_الوحدة"))
        source = serialize_lesson(doc, unit_name, subject=subject)
        stored = quiz_bank.stored_for(grade, track, subject, unit_name,
                                      name, source)
        if stored:
            banks.append((name, stored))
        else:
            missing.append(name)
    return banks, missing


def serve_from_bank(grade, track, subject, unit, lessons, count, seen=None):
    """اختبارٌ من المخزون — أو `None` إن لم يكتمل العدد.

    🔒 **وكلٌّ أو لا شيء**: اختبارٌ نصفُه من البنك ونصفُه من الموديل يخلط
       أسلوبين ويكلّف نداءً على كل حال، فلا يوفّر شيئاً ولا يُجوّد.
    """
    wanted = [l for l in (lessons or []) if str(l).strip()][:MAX_LESSONS]
    if not wanted:
        return None
    banks, missing = collect_banks(grade, track, subject, unit, wanted)
    if missing or not banks:
        return None

    picked = quiz_bank.select(banks, count, seen=seen)
    if len(picked) < count:
        return None

    questions = [{"q": q["q"], "options": list(q["options"]),
                  "correct_index": q["correct_index"],
                  "topic": q.get("topic") or q.get("lesson") or "عام",
                  "lesson": q.get("lesson", ""),
                  # 📋 وما يزيده البنكُ على التوليد الحيّ — يقرؤه الطالبُ
                  #    في المراجعة، ويحكم به الاختيارُ قبل العرض.
                  "why": q.get("why", ""),
                  "level": q.get("level", ""),
                  "weight": q.get("weight", 3),
                  "id": q.get("id", "")}
                 for q in picked]
    spread_answers(questions)
    return {
        "questions": questions,
        "model": "", "provider": "bank", "cached": True,
        "generated": len(questions), "requested": count,
        "subject": subject, "unit": unit or "",
        "lessons": [name for name, _ in banks],
    }


# ══════════════ قراءة رد الموديل ══════════════

# 🔴 **الشرطةُ المفردة داخل JSON فخٌّ مزدوج** — وخطرُه ازداد بعد أن صار
#    نصُّ الدرس نفسه يحمل `\ring{...}` و`\chem{...}` (2026-09-13):
#      • `\chem` و`\sqrt` **هروبٌ غير صالح** ⇒ `json.loads` يرفض الردّ
#        كلَّه ⇒ «تعذّر توليد الاختبار» في الكيمياء والرياضيات.
#      • `\ring` و`\frac` و`\nuc` **هروبٌ صالح** (`\r` `\f` `\n`) ⇒
#        يُقبل الردُّ **ويصل مشوّهاً**: مِحرفُ تحكّمٍ ثم «ing{6|ar}».
#    فنُضاعف الشرطة لكل أمرٍ نعرفه **قبل** التحليل، فيَسلم الاثنان.
_LONE_CMD = re.compile(
    r"(?<!\\)\\(frac|ring|chem|sqrt|nuc|fact|perm|comb|sup|vec)\b")


def extract_json(raw: str):
    """يستخرج JSON من رد الموديل ولو غلّفه بعلامات أو نصّ مجاور."""
    if not raw:
        return None
    text = _LONE_CMD.sub(r"\\\\\1", raw.strip())
    fence = re.search(r"```(?:json)?\s*(.+?)```", text, re.S)
    if fence:
        text = fence.group(1).strip()
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass
    start, end = text.find("{"), text.rfind("}")
    if start != -1 and end > start:
        try:
            return json.loads(text[start:end + 1])
        except json.JSONDecodeError:
            return None
    return None


# ⚠️ فخّ JSON (الإصلاح يسبق strip: Form-Feed فراغ تحذفه): `\frac` المفردة هي الهروب `\f` (Form-Feed)،
#    فيصل النصّ «\x0crac{...}» — كسرٌ مشوّه على شاشة الطالب. البرومبت يطلب
#    المضاعفة، وهذه شبكة الأمان إن سها الموديل.
_BROKEN_FRAC = {
    "\x0crac": "\\frac",   # \f + rac
    "\x0bec": "\\vec",     # \v + ec  (احتياطاً لرموز أخرى شائعة)
}


def repair_escapes(text: str) -> str:
    """يعيد أوامر LaTeX التي ابتلعها هروب JSON إلى صورتها."""
    for broken, fixed in _BROKEN_FRAC.items():
        if broken in text:
            text = text.replace(broken, fixed)
    return text


def validate(data, count, allowed_lessons, subject: str = ""):
    """يُبقي الأسئلة السليمة فقط. سؤال مشوّه يُطرح لا يُصلَّح.

    🖌️ **ونصُّ السؤال يمرّ بالرسّام كجواب الشرح** (طلب المالك 2026-09-13:
       «في كل مكان»): «اختبر نفسك» يسأل عن **نفس الدروس**، فلا معنى لأن
       يُرسم الكسرُ في الشرح ويصل سؤالُ الاختبار «س/ص» سطراً مسطّحاً،
       ولا أن تُخفض أدلّةُ الصيغ هناك وتبقى «H2SO4» هنا.
    """
    from subjects.common import render_finish
    if not isinstance(data, dict):
        return []
    raw = data.get("questions")
    if not isinstance(raw, list):
        return []

    clean, seen = [], set()
    for item in raw:
        if not isinstance(item, dict):
            continue
        q = render_finish(repair_escapes(str(item.get("q", ""))), subject).strip()
        options = item.get("options")
        idx = item.get("correct_index")

        if not q or not isinstance(options, list) or len(options) != 4:
            continue
        options = [render_finish(repair_escapes(str(o)), subject).strip()
                   for o in options]
        if any(not o for o in options):
            continue
        if len(set(options)) != 4:                    # خيار مكرر ⇒ سؤال فاسد
            continue
        if not isinstance(idx, int) or not (0 <= idx <= 3):
            continue

        key = q.replace(" ", "")
        if key in seen:                               # سؤال مكرر
            continue
        seen.add(key)

        # 🏷️ والموضوعُ يمرّ بالرسّام كذلك: عليه تُبنى شاشةُ «تحتاج تركيزاً في»
        #    وقد يحمل صيغةً أو رمزاً («نصف قطر مدار بوهر» · «\frac{ن}{ر}»).
        topic = render_finish(str(item.get("topic", "")), subject).strip()
        lesson = str(item.get("lesson", "")).strip()
        if allowed_lessons and lesson not in allowed_lessons:
            lesson = allowed_lessons[0]               # تصحيح نسبة لا رفض
        clean.append({
            "q": q,
            "options": options,
            "correct_index": idx,
            "topic": topic or lesson or "عام",
            "lesson": lesson,
        })
        if len(clean) >= count:
            break
    return clean


# ══════════════ توزيع مواقع الإجابات ══════════════
# ⚠️ الموديلات — كلها بلا استثناء — تميل لوضع الإجابة الصحيحة **في الخيار الأول**.
#    طلبُها في البرومبت أن «تنوّع» لا يكفي: الانحياز في أوزان الموديل لا في فهمه،
#    والطالب يكتشف الحيلة من ثالث اختبار فيجيب بلا قراءة.
#    فالتصحيح هنا حسابي لا لغوي: نحن من يقرّر موقع الإجابة، لا الموديل.
#
# التوزيع **متوازن لا عشوائي**: كل أربعة أسئلة تأخذ المواقع (٠،١،٢،٣) مرةً لكلٍّ
# بترتيب مخلوط. العشوائية المجرّدة قد تخرج «أ أ أ أ» صدفةً — وهذا عين ما نهرب منه.
# والتبديل (swap) يحفظ الخيارات الأربعة كما ولّدها الموديل بلا حذف ولا إضافة.

_POSITIONS = (0, 1, 2, 3)


def spread_answers(questions):
    """يوزّع مواقع الإجابات الصحيحة توزيعاً متوازناً. يعدّل القائمة في مكانها."""
    if not questions:
        return questions

    targets = []
    while len(targets) < len(questions):
        block = list(_POSITIONS)
        random.shuffle(block)
        targets.extend(block)

    for item, target in zip(questions, targets):
        current = item["correct_index"]
        if current == target:
            continue
        options = item["options"]
        options[current], options[target] = options[target], options[current]
        item["correct_index"] = target
    return questions


# ══════════════ التوليد ══════════════

async def _call_model(client_key, model_name, messages, clients):
    """ينادي **موديل المادة نفسه** — بلا بديل صامت.

    ⚠️ كان هنا `or clients.get("gemini")`: لو غاب عميل ديب سيك مضت أسئلة
    الرياضيات إلى Gemini **بلا أن يعلم أحد**، فتنكسر قاعدة «لكل مادة موديلها»
    من حيث لا نرى. الخطأ الصريح أرحم من بديل صامت.
    """
    client = clients.get(client_key)
    if client is None:
        raise QuizError(
            f"⚠️ مزوّد «{client_key}» ({model_name}) غير مهيّأ على الخادم — "
            "راجع مفاتيح الـAPI في ملف .env.")
    # ☢️ والسقفُ يتّسع لنموذج التفكير وإلا عاد فارغاً بلا خطأ ([call_budget])
    cap, wait = call_budget(model_name, _MAX_TOKENS, _AI_TIMEOUT, "quiz")
    response = await asyncio.wait_for(
        client.chat.completions.create(
            model=model_name, messages=messages,
            max_tokens=cap, temperature=0.4,           # تنويع محدود بلا هذيان
            # 🎚️ والحسابُ يفكّر قليلاً: ٩٠٪ ⇐ ١٠٠٪ بكلفةِ ٠٫٦ ثانية
            **reasoning_kwargs(model_name, "quiz"),
        ),
        timeout=wait,
    )
    return response.choices[0].message.content


async def generate(grade, track, subject, unit, lessons, count, clients,
                   seen=None):
    """يولّد اختباراً. يعيد dict جاهزاً للواجهة، أو يرمي QuizError."""
    subject = (subject or "").strip()
    count = count if count in ALLOWED_COUNTS else DEFAULT_COUNT

    # 🎯 **المخزونُ أولاً** — وبلا نداءٍ ولا انتظار ([serve_from_bank]).
    served = serve_from_bank(grade, track, subject, unit, lessons, count, seen)
    if served is not None:
        print(f"🎯 quiz: {subject} · {count} أسئلة ← البنك المخزون")
        return served

    lessons_text, used = collect_lessons_text(grade, track, subject, unit, lessons)

    # 🎯 موديل المادة نفسه (رياضيات→DeepSeek · فيزياء وكيمياء→GPT · الباقي→Gemini)
    #    مصدره `curriculum.MODEL_ROUTING` — نفس ما يستعمله الشرح والسؤال، فلا
    #    يختلف مستوى اللغة بين ما يشرحه المعلّم وما يسأل عنه.
    client_key, model_name = model_route(subject)
    print(f"🧠 quiz: {subject} · {count} أسئلة → {client_key}/{model_name}")

    messages = [
        {"role": "system", "content": quiz_prompt.system_prompt(subject, count)},
        {"role": "user", "content": quiz_prompt.user_prompt(lessons_text, count)},
    ]

    questions = []
    for attempt in (1, 2):        # محاولة واحدة إضافية عند فشل الـparsing
        try:
            raw = await _call_model(client_key, model_name, messages, clients)
        except asyncio.TimeoutError:
            raise QuizError("⏱️ تأخّر تجهيز الأسئلة. حاول مرة أخرى.")
        except QuizError:
            raise
        except Exception:
            raise QuizError("⚠️ تعذّر تجهيز الأسئلة الآن. حاول بعد قليل.")

        questions = validate(extract_json(raw), count, used, subject)
        if questions:
            break
        if attempt == 1:
            messages.append({"role": "assistant", "content": (raw or "")[:500]})
            messages.append({"role": "user", "content": quiz_prompt.RETRY_HINT})

    if not questions:
        raise QuizError("⚠️ لم أتمكّن من تجهيز أسئلة سليمة لهذه الدروس. جرّب درساً آخر.")

    spread_answers(questions)      # الإجابة الصحيحة تتنقّل بين المواقع الأربعة

    return {
        "questions": questions,
        "model": model_name,           # 👁️ ليُرى أي موديل ولّد فعلاً — لا تخمين
        "provider": client_key,
        "generated": len(questions),
        "requested": count,
        "subject": subject,
        "unit": unit or "",
        "lessons": used,
    }
