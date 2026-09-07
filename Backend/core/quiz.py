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

from .content_store import get_lessons_book, lessons_units, lessons_in_unit, find_lesson
from .curriculum import model_route, normalize_grade_track, is_valid_subject
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
        text = serialize_lesson(lesson, unit or "",
                                subject=subject)[:_MAX_CHARS_PER_LESSON]
        blocks.append(f"━━━ الدرس: {name} ━━━\n{text}")
        used.append(name)

    if not blocks:
        raise QuizError("❌ لم أجد نصّ الدروس المختارة. جرّب دروساً أخرى.")
    return "\n\n".join(blocks), used


# ══════════════ قراءة رد الموديل ══════════════

def extract_json(raw: str):
    """يستخرج JSON من رد الموديل ولو غلّفه بعلامات أو نصّ مجاور."""
    if not raw:
        return None
    text = raw.strip()
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


def validate(data, count, allowed_lessons):
    """يُبقي الأسئلة السليمة فقط. سؤال مشوّه يُطرح لا يُصلَّح."""
    if not isinstance(data, dict):
        return []
    raw = data.get("questions")
    if not isinstance(raw, list):
        return []

    clean, seen = [], set()
    for item in raw:
        if not isinstance(item, dict):
            continue
        q = repair_escapes(str(item.get("q", ""))).strip()
        options = item.get("options")
        idx = item.get("correct_index")

        if not q or not isinstance(options, list) or len(options) != 4:
            continue
        options = [repair_escapes(str(o)).strip() for o in options]
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

        lesson = str(item.get("lesson", "")).strip()
        if allowed_lessons and lesson not in allowed_lessons:
            lesson = allowed_lessons[0]               # تصحيح نسبة لا رفض
        clean.append({
            "q": q,
            "options": options,
            "correct_index": idx,
            "topic": str(item.get("topic", "")).strip() or lesson or "عام",
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
    response = await asyncio.wait_for(
        client.chat.completions.create(
            model=model_name, messages=messages,
            max_tokens=_MAX_TOKENS, temperature=0.4,   # تنويع محدود بلا هذيان
        ),
        timeout=_AI_TIMEOUT,
    )
    return response.choices[0].message.content


async def generate(grade, track, subject, unit, lessons, count, clients):
    """يولّد اختباراً. يعيد dict جاهزاً للواجهة، أو يرمي QuizError."""
    subject = (subject or "").strip()
    count = count if count in ALLOWED_COUNTS else DEFAULT_COUNT
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

        questions = validate(extract_json(raw), count, used)
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
