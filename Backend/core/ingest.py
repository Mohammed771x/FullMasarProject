# ==================================================
# 📥 core/ingest.py — تحويل صور الدرس إلى JSON بالقالب
# ==================================================
# ثلاث مراحل، وفصلها هو كل السرّ:
#
#   ١) النقل    (رؤية)  : الصور → نص خام حرفي. لا تلخيص ولا حساب.
#   ٢) الهيكلة  (نص→نص) : النص الخام → JSON بالقالب. الصور **لا تُمرَّر**
#                          هنا إطلاقاً، فلا يستطيع الموديل أن «يتخيّل».
#   ٣) الفحص            : (أ) مقارنة الكتل المحمية بالنص الخام — كودٌ حتمي
#                          (ب) تدقيق الصحة الرياضية — موديل مختلف
#
# ⚠️ **لا يُطلب من الموديل أن يحسب أبداً.** الحل مكتوب في الملخّص أصلاً؛
#    وظيفته النسخ. كل خبيص الرياضيات السابق كان من طلب «رتّب» مع «انقل»
#    في نداءٍ واحد — فيعيد اشتقاق المعادلة بدل نسخها.

import os
import json
import time
import base64
import asyncio
import shutil

from openai import AsyncOpenAI

from config import (BASE_SUBJECTS_DIR, GEMINI_API_KEY, DEEPSEEK_API_KEY)
from .curriculum import normalize_grade_track, is_valid_subject, subjects_for
from . import content_store as cs
from . import textnorm


class IngestError(Exception):
    """خطأ برسالة عربية جاهزة للعرض في الواجهة."""


# ══════════════ إعدادات ══════════════

GEMINI_BASE = "https://generativelanguage.googleapis.com/v1beta/openai/"

# تُضبط من .env عند تغيّر أسماء الموديلات — لا حاجة لتعديل الكود.
VISION_MODEL = os.getenv("INGEST_VISION_MODEL", "gemini-3.1-pro-preview")
STRUCT_MODEL = os.getenv("INGEST_STRUCT_MODEL", "gemini-3.1-pro-preview")
# ☢️ ونفسُ النموذج المسحوب كان هنا أيضاً ([core/curriculum]) — وأداةُ
#    الاستيعاب تتعلّق مثلَها بلا خطأ.
MATH_MODEL = os.getenv("INGEST_MATH_MODEL", "deepseek-v4-pro")

# المواد ذات الرموز وخط اليد: صور أقل في النداء الواحد.
# دقة نقل خط اليد تنهار مع كثرة الصفحات في نداء واحد — وهذا أرخص إصلاح.
HARD_SUBJECTS = {"رياضيات", "فيزياء", "كيمياء"}
BATCH_HARD = 2
BATCH_EASY = 5

MAX_IMAGES = 40
MAX_IMAGE_BYTES = 8 * 1024 * 1024

WORK_ROOT = os.path.join(os.path.dirname(BASE_SUBJECTS_DIR), "_ingest")

_clients = {}


def _client(kind: str) -> AsyncOpenAI:
    """عميل كسول — لا يُبنى إلا عند أول استعمال (يبقى الاستيراد رخيصاً)."""
    if kind in _clients:
        return _clients[kind]
    if kind == "gemini":
        if not GEMINI_API_KEY:
            raise IngestError("🔑 مفتاح GEMINI_API_KEY غير مضبوط في .env")
        c = AsyncOpenAI(api_key=GEMINI_API_KEY, base_url=GEMINI_BASE, timeout=300.0)
    elif kind == "deepseek":
        if not DEEPSEEK_API_KEY:
            raise IngestError("🔑 مفتاح DEEPSEEK_API_KEY غير مضبوط في .env")
        c = AsyncOpenAI(api_key=DEEPSEEK_API_KEY, base_url="https://api.deepseek.com", timeout=300.0)
    else:
        raise IngestError(f"مزوّد غير معروف: {kind}")
    _clients[kind] = c
    return c


async def list_models() -> list:
    """أسماء موديلات جيميناي المتاحة لهذا المفتاح — تملأ قائمة الواجهة.
    نسردها بدل تخمين الاسم في الكود: أسماء الموديلات تتغيّر، والمفتاح
    وحده يعرف ما هو متاح له فعلاً."""
    try:
        res = await _client("gemini").models.list()
    except Exception as e:
        raise IngestError(f"⚠️ تعذّر سرد الموديلات: {e}")
    names = []
    for m in getattr(res, "data", []) or []:
        mid = (getattr(m, "id", "") or "").replace("models/", "")
        if mid:
            names.append(mid)
    return sorted(set(names))


# ══════════════ المرحلة ١ — النقل الحرفي ══════════════

TRANSCRIBE_SYSTEM = """أنت ناسخ نصوص محترف. لست شارحاً ولا مدرّساً ولا مصححاً.
مهمتك الوحيدة: نقل كل ما في الصور حرفياً كما هو.

قواعد ملزمة لا تُخالَف:
١. لا تلخّص، لا تختصر، لا تعيد الصياغة، لا ترتّب، لا تضف أي كلمة من عندك.
٢. لا تحسب شيئاً إطلاقاً. لا تبسّط معادلة. لا تصحّح خطأً — إن كان في الصورة
   خطأ رياضي فانقله كما هو بالضبط، وتصحيحه ليس شغلك.
٣. المعادلات بالترميز العربي كما في الصورة (س، ص، ع، ن، جا، جتا، ظا، نها، ق).
٤. الأسس بعلامة ^ لا برموز مرتفعة: اكتب س^2 ولا تكتب س².
   الكسور خطّية: (البسط)/(المقام). الجذر: √(المقدار).
٥. ابدأ كل صفحة بسطر مستقل: --- صفحة N ---
٦. ما تعجز عن قراءته اكتبه هكذا: [غير واضح: أقرب تخمين]
٧. لا مقدمة ولا خاتمة ولا تعليق منك. النص المنقول فقط."""


def _data_url(raw: bytes, mime: str) -> str:
    return f"data:{mime or 'image/jpeg'};base64,{base64.b64encode(raw).decode()}"


async def _transcribe_batch(client, model, images, first_page):
    last_page = first_page + len(images) - 1
    parts = [{
        "type": "text",
        "text": (f"هذه الصفحات من {first_page} إلى {last_page} بالترتيب. "
                 f"انقل كل صفحة كاملة، وابدأ كل واحدة بسطر «--- صفحة N ---» "
                 f"بالرقم الصحيح."),
    }]
    for raw, mime in images:
        parts.append({"type": "image_url", "image_url": {"url": _data_url(raw, mime)}})

    res = await client.chat.completions.create(
        model=model,
        messages=[{"role": "system", "content": TRANSCRIBE_SYSTEM},
                  {"role": "user", "content": parts}],
        temperature=0,
    )
    return (res.choices[0].message.content or "").strip(), res.usage


async def transcribe(images, subject: str, model: str = "") -> tuple:
    """الصور → نص خام حرفي. يرجع (النص، إحصاء التوكنات).

    الدفعات تُنفَّذ **بالتوازي** لأن كل دفعة مستقلة تماماً — وهذا ما يحلّ
    شكوى الوقت: ترفع الوحدة كاملة وتنصرف."""
    model = model or VISION_MODEL
    client = _client("gemini")
    size = BATCH_HARD if subject in HARD_SUBJECTS else BATCH_EASY

    batches, page = [], 1
    for i in range(0, len(images), size):
        chunk = images[i:i + size]
        batches.append((chunk, page))
        page += len(chunk)

    results = await asyncio.gather(
        *[_transcribe_batch(client, model, ch, p) for ch, p in batches],
        return_exceptions=True,
    )

    texts, usage = [], {"in": 0, "out": 0}
    for idx, r in enumerate(results):
        if isinstance(r, Exception):
            raise IngestError(f"⚠️ فشل نقل الدفعة {idx + 1}: {r}")
        text, u = r
        texts.append(text)
        if u:
            usage["in"] += getattr(u, "prompt_tokens", 0) or 0
            usage["out"] += getattr(u, "completion_tokens", 0) or 0
    return "\n\n".join(texts), usage


# ══════════════ المرحلة ٢ — الهيكلة ══════════════

STRUCTURE_SYSTEM = """أنت محرّر مناهج. أمامك نصٌّ خام منقول حرفياً من ملخّص طالب،
ومهمتك تحويله إلى JSON بالقالب المعطى.

━━ القاعدة الذهبية ━━
تضيف صياغةً، ولا تضيف معلومة.
يجوز لك تحسين العرض والترتيب والربط. ولا يجوز لك بحالٍ أن تأتي بقانون أو
تعريف أو حالة أو مثال ليس في النص الخام.

━━ حقول محمية: تُنسخ من النص الخام حرفاً بحرف ━━
النص · التعريف · المصطلح · القانون · المعادلة · الصيغة ·
خطوات_الحل · النتيجة · الحل · السؤال · نص_السؤال
فيها: لا تعيد صياغة، لا تصحّح، لا تحسب، لا تبسّط، لا تغيّر رقماً ولا رمزاً.
إن رأيت خطأً رياضياً في النص الخام فانقله كما هو — هناك مدقّق لاحق مهمته هذه.

━━ حقول حرّة: اكتبها بأسلوبك ━━
ملخص_قصير · مقدمة · خاتمة · الشرح · العنوان · اسم_الجزء
هنا رتّب، اربط، اشرح بوضوح، واكتب مقدمةً تمهّد للدرس وخاتمةً تجمع خيوطه —
لكن من معطيات النص الخام وحدها.

━━ قواعد الترميز ━━
· الأسس بعلامة ^ (س^2) لا برموز مرتفعة (س²).
· الأرقام لاتينية (2) لا عربية-هندية (٢).
· الكسور خطّية: (البسط)/(المقام).
· الرموز العربية كما هي: س ص ع ن ر جا جتا ظا نها.

أخرج JSON صالحاً فقط، بلا أي نص خارجه، وبنفس مفاتيح القالب العربية."""


def _template_for(mode: str) -> dict:
    """قالب المخرجات — مطابق لما يقرأه content_store فعلاً."""
    if mode == cs.UNIT_DIR:
        return {
            "اسم_الوحدة": "اسم الوحدة",
            "الصفحات": [{"رقم_الصفحة": 1, "نص_الصفحة": "نص الصفحة كاملاً"}],
        }
    return {
        "اسم_الدرس": "اسم الدرس",
        "ملخص_قصير": "سطر أو سطران يمهّدان للدرس",
        "الأجزاء": [
            {"نوع": "مقدمة", "اسم_الجزء": "تمهيد",
             "المحتوى": ["فقرة تمهيدية من معطيات النص الخام"]},
            {"نوع": "تعريفات", "اسم_الجزء": "المصطلحات الأساسية",
             "المحتوى": [{"المصطلح": "...", "التعريف": "منقول حرفياً", "ملاحظة": "اختياري"}]},
            {"نوع": "قوانين", "اسم_الجزء": "القوانين",
             "المحتوى": [{"القانون": "منقول حرفياً", "الشرح": "بأسلوبك"}]},
            {"نوع": "أمثلة_محلولة", "اسم_الجزء": "أمثلة محلولة",
             "المحتوى": [{"السؤال": "حرفياً", "خطوات_الحل": ["حرفياً"], "النتيجة": "حرفياً"}]},
            {"نوع": "نقاط_مهمة", "اسم_الجزء": "خلاصة",
             "المحتوى": ["نقاط ختامية بأسلوبك"]},
        ],
    }


async def structure(raw_text: str, subject: str, mode: str, lesson_name: str = "",
                    model: str = "") -> tuple:
    """النص الخام → JSON. **بلا صور** — فلا مصدر للموديل غير النص المنقول."""
    if not (raw_text or "").strip():
        raise IngestError("⚠️ النص الخام فارغ — لا شيء لهيكلته.")
    model = model or STRUCT_MODEL
    tmpl = json.dumps(_template_for(mode), ensure_ascii=False, indent=2)

    hint = f"\nاسم الدرس المطلوب: {lesson_name}" if lesson_name else ""
    prompt = (f"المادة: {subject}{hint}\n\n"
              f"━━ القالب المطلوب ━━\n{tmpl}\n\n"
              f"احذف الأجزاء التي لا مادة لها في النص الخام، ولا تخترع لها محتوى.\n\n"
              f"━━ النص الخام ━━\n{raw_text}")

    res = await _client("gemini").chat.completions.create(
        model=model,
        messages=[{"role": "system", "content": STRUCTURE_SYSTEM},
                  {"role": "user", "content": prompt}],
        temperature=0,
        response_format={"type": "json_object"},
    )
    text = (res.choices[0].message.content or "").strip()
    try:
        data = json.loads(text)
    except json.JSONDecodeError as e:
        raise IngestError(f"⚠️ الموديل أخرج JSON غير صالح: {e}")

    u = res.usage
    usage = {"in": getattr(u, "prompt_tokens", 0) or 0,
             "out": getattr(u, "completion_tokens", 0) or 0}
    return data, usage


# ══════════════ المرحلة ٣ب — تدقيق الصحة الرياضية ══════════════

MATH_AUDIT_SYSTEM = """أنت مدقّق رياضيات صارم. أمامك معادلات وخطوات حلٍّ
منقولة من ملخّص طالب — وقد يكون الخطأ في الملخّص نفسه.

افحص الصحة الرياضية وحدها: هل الخطوة تؤدي فعلاً إلى التالية؟ هل النتيجة
صحيحة؟ هل القانون مكتوب صحيحاً؟ لا تعلّق على الأسلوب ولا الترتيب.

أخرج JSON بهذا الشكل تماماً:
{"أخطاء": [{"البند": "انسخ نص البند كما ورد حرفياً", "الخطأ": "ما العلة", "الصواب": "التصحيح"}]}
وإن كان كل شيء سليماً: {"أخطاء": []}
لا تخترع أخطاءً لتملأ القائمة — القائمة الفارغة نتيجة محترمة."""


def _protected_blocks(data) -> list:
    """كل ما يستحق تدقيقاً رياضياً: الحقول المحمية + أي سطر رياضي."""
    out, seen = [], set()
    for path, value in textnorm._walk_strings(data):
        key = textnorm._last_key(path)
        if key.startswith("_"):
            continue
        candidates = ([value] if key in textnorm.PROTECTED_KEYS
                      else textnorm.split_lines(value))
        for block in candidates:
            if textnorm.is_math_bearing(block) and block not in seen:
                seen.add(block)
                out.append(block)
    return out


async def math_audit(data, model: str = "") -> dict:
    """يمرّ على المعادلات بموديل استدلالي مختلف — يمسك الخطأ الرياضي نفسه،
    لا مجرّد اختلاف النقل. (جيميناي يحكم أحياناً بصحة معادلة خاطئة، فنستعمل
    عائلةً أخرى حتى لا يكون المدقِّق شريكاً في الغلط.)"""
    blocks = _protected_blocks(data)
    if not blocks:
        return {"أخطاء": [], "فُحص": 0, "usage": {"in": 0, "out": 0}}

    numbered = "\n".join(f"{i+1}. {b}" for i, b in enumerate(blocks))
    res = await _client("deepseek").chat.completions.create(
        model=model or MATH_MODEL,
        messages=[{"role": "system", "content": MATH_AUDIT_SYSTEM},
                  {"role": "user", "content": numbered}],
        temperature=0,
        response_format={"type": "json_object"},
    )
    text = (res.choices[0].message.content or "").strip()
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        parsed = {"أخطاء": [], "_تعذّر_التحليل": text[:500]}

    u = res.usage
    parsed["فُحص"] = len(blocks)
    parsed["usage"] = {"in": getattr(u, "prompt_tokens", 0) or 0,
                       "out": getattr(u, "completion_tokens", 0) or 0}
    return parsed


# ══════════════ حلّ الوجهة والحفظ ══════════════

def _safe_name(name: str) -> str:
    """اسم ملف آمن. ⚠️ الاسم البادئ بـ `_` أو `.` **يتجاهله** content_store،
    فدرسٌ بهذا الاسم يُحفظ ثم لا يظهر للطالب أبداً — نمنعه هنا."""
    clean = (name or "").strip().replace(os.sep, "-").replace("/", "-").replace("\0", "")
    clean = clean.strip(". ")
    while clean.startswith("_"):
        clean = clean[1:].strip()
    if not clean:
        raise IngestError("⚠️ اسم الدرس فارغ أو غير صالح.")
    return clean[:120]


def _single_content_file(root: str, shape_check):
    """أول ملف في المجلد يطابق الصيغة المطلوبة — أو None.
    وجوده يعني أن التخزين «ملفٌ واحد» لا «مجلد لكل وحدة»."""
    if not os.path.isdir(root):
        return None
    for fname in sorted(os.listdir(root)):
        if cs._is_ignored(fname):
            continue
        fpath = os.path.join(root, fname)
        if not os.path.isfile(fpath):
            continue
        try:
            with open(fpath, "r", encoding="utf-8") as f:
                data = json.load(f)
        except (OSError, json.JSONDecodeError):
            continue
        if shape_check(data):
            return fpath, data
    return None


def resolve(grade, track, subject, mode, unit="", lesson_name=""):
    """أين يُكتب هذا الدرس بالضبط؟ يرجع وصف الوجهة قبل أي كتابة."""
    grade, track = normalize_grade_track(grade, track)
    subject = (subject or "").strip()
    if not is_valid_subject(grade, track, subject):
        raise IngestError(f"⚠️ «{subject}» ليست مقررة على الصف {grade} {track}.")
    if mode not in (cs.LESSONS_DIR, cs.UNIT_DIR):
        raise IngestError("⚠️ وضع غير معروف.")

    root = cs.mode_dir(subject, grade, track, mode)
    shape = cs._shape_is_pages if mode == cs.UNIT_DIR else cs._shape_is_lessons
    found = _single_content_file(root, shape)

    if found:
        # ⚠️ ملفٌ واحد موجود ⇒ content_store يقرؤه ويتجاهل أي مجلدات بجانبه.
        #    فالإضافة **داخله** إلزامية، وإلا حُفظ الدرس ولم يظهر أبداً.
        return {"layout": "single_file", "root": root, "path": found[0],
                "unit": unit, "lesson": lesson_name}

    if mode == cs.UNIT_DIR:
        return {"layout": "single_file", "root": root,
                "path": os.path.join(root, f"{_safe_name(subject)}.json"),
                "unit": unit, "lesson": lesson_name}

    if not (unit or "").strip():
        raise IngestError("⚠️ اسم الوحدة مطلوب في وضع الدروس.")
    return {"layout": "per_lesson", "root": root,
            "path": os.path.join(root, _safe_name(unit),
                                 f"{_safe_name(lesson_name or 'درس')}.json"),
            "unit": unit, "lesson": lesson_name}


def _backup(path: str):
    """نسخة قبل أي كتابة فوق ملفٍ قائم — خارج data/ حتى لا تلوّث git."""
    if not os.path.isfile(path):
        return None
    rel = os.path.relpath(path, os.path.dirname(BASE_SUBJECTS_DIR)).replace(os.sep, "_")
    dest_dir = os.path.join(WORK_ROOT, "backups")
    os.makedirs(dest_dir, exist_ok=True)
    dest = os.path.join(dest_dir, f"{time.strftime('%Y%m%d-%H%M%S')}_{rel}")
    shutil.copy2(path, dest)
    return dest


def _write_json(path: str, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)          # كتابة ذرّية — لا ملف نصف مكتوب أبداً


def _upsert_lesson(book: dict, unit: str, lesson: dict):
    """يضع الدرس في وحدته داخل كتابٍ ذي ملفٍ واحد — يستبدل المتطابق اسماً."""
    units = book.setdefault("الوحدات", [])
    target = (unit or "").strip()
    name = (lesson.get("اسم_الدرس") or "").strip()
    for u in units:
        if isinstance(u, dict) and (u.get("اسم_الوحدة") or "").strip() == target:
            lessons = u.setdefault("الدروس", [])
            for i, l in enumerate(lessons):
                if isinstance(l, dict) and (l.get("اسم_الدرس") or "").strip() == name:
                    lessons[i] = lesson
                    return "استُبدل درس قائم"
            lessons.append(lesson)
            return "أُضيف إلى وحدة قائمة"
    units.append({"اسم_الوحدة": target, "الدروس": [lesson]})
    return "أُنشئت وحدة جديدة"


def _upsert_pages(book: list, unit: str, incoming: dict):
    """يدمج صفحات في وحدة داخل كتاب صيغة الصفحات (الأحياء)."""
    target = (unit or incoming.get("اسم_الوحدة") or "").strip()
    pages = incoming.get("الصفحات", []) or []
    for u in book:
        if isinstance(u, dict) and (u.get("اسم_الوحدة") or "").strip() == target:
            have = {p.get("رقم_الصفحة") for p in u.get("الصفحات", []) if isinstance(p, dict)}
            added = [p for p in pages if p.get("رقم_الصفحة") not in have]
            u.setdefault("الصفحات", []).extend(added)
            u["الصفحات"].sort(key=lambda p: p.get("رقم_الصفحة") or 0)
            return f"أُضيفت {len(added)} صفحة إلى وحدة قائمة"
    book.append({"اسم_الوحدة": target, "الصفحات": pages})
    return f"أُنشئت وحدة جديدة بـ {len(pages)} صفحة"


def save(grade, track, subject, mode, unit, lesson_name, data) -> dict:
    """يكتب المخرجات في مكانها الصحيح — بنسخة احتياطية وإبطالٍ للكاش."""
    if not isinstance(data, (dict, list)):
        raise IngestError("⚠️ المحتوى المراد حفظه ليس JSON صالحاً.")

    dest = resolve(grade, track, subject, mode, unit, lesson_name)
    path = dest["path"]
    backup = _backup(path)

    if dest["layout"] == "per_lesson":
        payload = dict(data)
        payload["اسم_الدرس"] = (lesson_name or payload.get("اسم_الدرس") or "").strip()
        _write_json(path, payload)
        note = "ملف درسٍ مستقل"
    elif mode == cs.UNIT_DIR:
        book = []
        if os.path.isfile(path):
            with open(path, "r", encoding="utf-8") as f:
                book = json.load(f)
        if not isinstance(book, list):
            raise IngestError("⚠️ ملف وضع الوحدات القائم ليس قائمة — لن أكتب فوقه.")
        note = _upsert_pages(book, unit, data if isinstance(data, dict) else {})
        _write_json(path, book)
    else:
        with open(path, "r", encoding="utf-8") as f:
            book = json.load(f)
        if not isinstance(book, dict):
            raise IngestError("⚠️ ملف وضع الدروس القائم ليس كائناً — لن أكتب فوقه.")
        lesson = dict(data)
        lesson["اسم_الدرس"] = (lesson_name or lesson.get("اسم_الدرس") or "").strip()
        note = _upsert_lesson(book, unit, lesson)
        _write_json(path, book)

    cs.invalidate_cache()
    return {"path": path, "layout": dest["layout"], "note": note, "backup": backup}


# ══════════════ الوجهات المتاحة للواجهة ══════════════

def targets(grade=3, track="علمي") -> dict:
    """المواد والوحدات الموجودة فعلاً — تملأ قوائم الواجهة."""
    grade, track = normalize_grade_track(grade, track)
    out = {"grade": grade, "track": track, "subjects": []}
    for subject in subjects_for(grade, track):
        entry = {"name": subject, "hard": subject in HARD_SUBJECTS,
                 "lessons_units": [], "unit_units": []}
        book = cs.get_lessons_book(grade, track, subject)
        if book:
            entry["lessons_units"] = cs.lessons_units(book)
        elif subject == cs.MATH_SUBJECT:
            entry["lessons_units"] = list(cs.MATH_BRANCHES)
        pages = cs.get_pages_book(grade, track, subject)
        if pages:
            entry["unit_units"] = cs.pages_units(pages)
        out["subjects"].append(entry)
    return out


# ══════════════ المُشغّل ══════════════

def _job_dir(subject: str, lesson: str) -> str:
    stamp = time.strftime("%Y%m%d-%H%M%S")
    safe = _safe_name(f"{subject}-{lesson or 'درس'}")[:60]
    path = os.path.join(WORK_ROOT, "jobs", f"{stamp}_{safe}")
    os.makedirs(path, exist_ok=True)
    return path


async def run(images, grade, track, subject, mode, unit, lesson_name,
              vision_model="", struct_model="", do_math_audit=None) -> dict:
    """الخط كاملاً: نقل → هيكلة → فحص. لا يكتب في data/ — الحفظ بزرٍّ منفصل
    بعد أن يرى المالك التقرير."""
    if not images:
        raise IngestError("⚠️ لم تُرفع أي صورة.")
    if len(images) > MAX_IMAGES:
        raise IngestError(f"⚠️ أقصى عدد صور {MAX_IMAGES} في المرة الواحدة.")

    dest = resolve(grade, track, subject, mode, unit, lesson_name)
    t0 = time.time()

    raw_text, u1 = await transcribe(images, subject, vision_model)
    data, u2 = await structure(raw_text, subject, mode, lesson_name, struct_model)

    check = textnorm.audit(raw_text, data)

    if do_math_audit is None:
        do_math_audit = subject in HARD_SUBJECTS
    math = {"أخطاء": [], "فُحص": 0, "usage": {"in": 0, "out": 0}}
    math_error = ""
    if do_math_audit:
        try:
            math = await math_audit(data)
        except Exception as e:
            # تدقيق الرياضيات إضافةٌ لا شرط — فشله لا يُسقط الدرس كله.
            math_error = f"تعذّر تدقيق الرياضيات: {e}"

    usage = {
        "in": u1["in"] + u2["in"] + math["usage"]["in"],
        "out": u1["out"] + u2["out"] + math["usage"]["out"],
    }
    unclear = raw_text.count("[غير واضح")

    job = _job_dir(subject, lesson_name)
    with open(os.path.join(job, "raw.txt"), "w", encoding="utf-8") as f:
        f.write(raw_text)
    result = {
        "raw_text": raw_text,
        "json": data,
        "check": check,
        "math": {k: v for k, v in math.items() if k != "usage"},
        "math_error": math_error,
        "unclear": unclear,
        "usage": usage,
        "seconds": round(time.time() - t0, 1),
        "dest": dest,
        "job_dir": job,
        "pages": len(images),
    }
    with open(os.path.join(job, "report.json"), "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)
    return result
