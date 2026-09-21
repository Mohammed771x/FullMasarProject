# ==================================================
# 🗄️ core/lesson_cache.py — شرحُ الدرس مخزوناً، لا مُولَّداً في كل مرة
# ==================================================
#
# ⚖️ **فكرةُ المالك (2026-09-14):** «لكل درسٍ شرحٌ محفوظ. الطالبُ يدخل فيجد
#    اقتراحاتٍ — اشرح الدرس · بسّطه · اشرح بمثالٍ من الحياة — وأكثرُهم
#    يضغط *اشرح الدرس*. فيأتيه الجوابُ فوراً بلا نداء API، وإن أراد زيادةً
#    قال بسّط لي فيتحوّل الباقي إلى الذكاء الاصطناعي.»
#
# 🎯 وهو قرارٌ صحيح، لسببٍ أدقّ من الكلفة: **شرحُ الدرس كاملاً هو الطلبُ
#    الوحيدُ في المنصّة الذي لا يعتمد على الطالب إطلاقاً.** لا سؤالَ له،
#    ولا سياقَ محادثة، ولا صفحاتٍ مختارة — مدخلُه نصُّ الدرس وحده. فجوابُه
#    دالّةٌ خالصةٌ من محتوى الكتاب، وما كان كذلك يُحسب مرّةً ويُخزَّن.
#    (وما عداه — السؤالُ والمتابعةُ والتبسيط — يبقى حيّاً كما هو.)
#
# ══════════════ لماذا ملفاتٌ لا Firestore؟ ══════════════
#
# ① **الكلفة**: كلُّ فتحِ درسٍ = قراءةُ مستندٍ من Firestore. والملفُّ يُقرأ
#    مرّةً عند الإقلاع ويبقى في الذاكرة — صفرُ قراءاتٍ وصفرُ زمنِ شبكة.
# ② **المتانة**: مبدأٌ قائمٌ في المشروع — «القسم يعمل كاملاً على خادمٍ بلا
#    Firestore» ([core/teacher_assistant]). وشرحُ الدرس أساسيٌّ لا كمالي.
# ③ **المراجعة**: الشروحُ تدخل git، فيُقرأ الفرقُ ويُراجَع ويُرجَع عنه.
#    والمالك اشترط «تتحقّق من كل شيء منه» — وهذا لا يكون في قاعدةٍ صامتة.
#
# ⚠️ **وثمنُه المعروف**: التحديثُ يحتاج نشراً. ولهذا تُركت طبقةُ تجاوزٍ من
#    Firestore (`_overrides`) بنفس نمط برومبتات المعلّم: إن وُجد مستندٌ
#    للدرس علا على الملف، وإن لم يوجد — أو تعذّر Firestore — فالملفُّ.
#
# 🔑 **وبصمةُ المصدر تحرس الصلاحية**: يُخزَّن مع الشرح `sha1` لنصّ الدرس.
#    فإن عُدّل الدرسُ في الكتاب اختلفت البصمةُ و**سقط الشرحُ المخزون من
#    تلقائه** ورجع الطلبُ إلى الموديل — فلا يُشرح درسٌ بنصٍّ قديم.

from __future__ import annotations

import hashlib
import json
import re
import os
import threading
import time
from pathlib import Path
from typing import Optional

BASE_DIR = Path(__file__).resolve().parent.parent
EXPLANATIONS_DIR = BASE_DIR / "data" / "explanations"

# بنيةُ الملف: data/explanations/{grade}/{track}/{subject}.json
#   { "درسٌ ما": {"unit":…, "lesson":…, "hash":…, "answer":…,
#                 "model":…, "chars":…, "built_at":…} }

_lock = threading.Lock()
_cache: dict = {}       # path -> (mtime, data)
_CACHE_TTL = 60.0       # ثانيةً — للتطوير المحلي؛ الإنتاجُ يقرأ مرّةً


def _file(grade, track, subject: str) -> Path:
    track = (track or "عام").strip() or "عام"
    return EXPLANATIONS_DIR / str(grade) / track / f"{(subject or '').strip()}.json"


def fingerprint(lesson_text: str) -> str:
    """بصمةُ نصّ الدرس — ١٦ رمزاً تكفي لكشف أي تعديل."""
    return hashlib.sha1((lesson_text or "").encode("utf-8")).hexdigest()[:16]


def math_source(lesson) -> str:
    """نصُّ بصمةٍ للرياضيات — تمثيلٌ قانونيٌّ لملف الدرس.

    ⚖️ الرياضياتُ لا تمرّ بـ`lesson_mode` ولا بـ`serialize_lesson`: معالجُها
       يقرأ الدرسَ بـ`load_math_lesson`. فلو بصمنا نصَّ المُسلسِل في البناء
       وقرأنا ملفَ المعالج في الخدمة لاختلفت البصمتان و**لأخطأ الكاشُ دائماً
       بلا أن يشتكي أحد**. فالمصدرُ واحدٌ للطرفين: الملفُّ نفسُه مُسلسَلاً.
    """
    return json.dumps(lesson, ensure_ascii=False, sort_keys=True)


def key_of(unit: str, lesson: str) -> str:
    return f"{(unit or '').strip()} › {(lesson or '').strip()}".strip(" ›")


def load_file(grade, track, subject: str) -> dict:
    """محتوى ملف المادة — مع كاشٍ في الذاكرة يتبع زمنَ التعديل."""
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
    except Exception as e:      # ملفٌ معطوب لا يُسقط الخادم
        print(f"⚠️ تعذّرت قراءة شروح «{subject}»: {e}")
        data = {}
    with _lock:
        _cache[str(path)] = (mtime, data)
    return data


def entry_spec(grade, track, subject: str, unit: str, lesson: str,
               lesson_text: str) -> Optional[str]:
    """نسخةُ المواصفة التي كُتب بها الشرحُ المخزون — أو `None` إن لم يوجد.

    ⚖️ يفرّق بين «مبنيٌّ» و«مبنيٌّ **بالمواصفة الحالية**» — وهو الفرق الذي
       يجعل إعادةَ البناء تستأنف من حيث وقفت بدل أن تبدأ من الصفر.
    """
    entry = load_file(grade, track, subject).get(key_of(unit, lesson))
    if not isinstance(entry, dict):
        return None
    if entry.get("hash") != fingerprint(lesson_text):
        return None
    return (entry.get("spec") or "")


def get(grade, track, subject: str, unit: str, lesson: str,
        lesson_text: str) -> Optional[str]:
    """الشرحُ المخزون لهذا الدرس **إن طابقت بصمةُ نصّه**، وإلا `None`."""
    entry = load_file(grade, track, subject).get(key_of(unit, lesson))
    if not isinstance(entry, dict):
        return None
    if entry.get("hash") != fingerprint(lesson_text):
        return None                      # الدرسُ تغيّر ⇒ الشرحُ لاغٍ
    answer = (entry.get("answer") or "").strip()
    return answer or None


def put(grade, track, subject: str, unit: str, lesson: str,
        lesson_text: str, answer: str, model: str = "", spec: str = "") -> None:
    """يكتب الشرحَ في ملف المادة. **للمولِّد وحده** — لا يُنادى من الخادم."""
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
        "model": model,
        # 🏷️ **نسخةُ مواصفةِ الشرح** ([tools/teaching_addendum]) — تُميّز
        #    شرحاً كُتب بالمواصفة الحالية من شرحٍ كُتب بمواصفةٍ سابقة.
        #    وبها وحدها صار البناءُ الطويلُ **قابلاً للاستئناف**: بصمةُ
        #    الدرس لا تتغيّر حين نغيّر طريقةَ الشرح، فلولا هذا الحقلُ
        #    لتخطّى `--skip-existing` كلَّ شرحٍ قديمٍ ولم يُعَد بناءُ شيء.
        "spec": spec,
        "chars": len(answer or ""),
        "built_at": time.strftime("%Y-%m-%d"),
        "answer": answer,
    }
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    os.replace(tmp, path)               # كتابةٌ ذرّية: لا ملفَّ نصفَ مكتوب
    with _lock:
        _cache.pop(str(path), None)


def drop(grade, track, subject: str, unit: str, lesson: str) -> bool:
    """يحذف شرحَ درسٍ من المخزون. **للمولِّد عند سقوط الفحص.**

    🔴 وبدونها كان عيبٌ صامت: درسٌ اجتاز الفحصَ في بناءٍ سابق ثم سقط في
       بناءٍ أحدث (لأن الفحص اشتدّ، أو الدرس تغيّر) **يحتفظ بشرحه القديم**
       — فيُسلَّم للطالب جوابٌ لا يجتاز معاييرَنا اليوم، وتقريرُ البناء
       يقول «أخفق» بينما المخزونُ يقول «موجود».
    """
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
    """جردٌ سريع لما بُني — تقرؤه لوحةُ التحكم و`/content/capabilities`."""
    out = {"subjects": 0, "lessons": 0, "chars": 0}
    if not EXPLANATIONS_DIR.exists():
        return out
    for path in EXPLANATIONS_DIR.rglob("*.json"):
        try:
            data = json.loads(path.read_text(encoding="utf-8")) or {}
        except Exception:
            continue
        out["subjects"] += 1
        out["lessons"] += len(data)
        out["chars"] += sum(int(v.get("chars") or 0) for v in data.values()
                            if isinstance(v, dict))
    return out


# ══════════════════════════════════════════════════
# 🎯 متى يُسلَّم المخزون؟ — شرطٌ ضيّقٌ عن عمد
# ══════════════════════════════════════════════════
#
# ⚖️ المخزونُ **شرحُ الدرس كاملاً ولا شيءَ غيره**. فلا يُسلَّم إلا حين يكون
#    الطلبُ هو ذاك بعينه: وضعُ شرح · بلا سؤالٍ خاص · بلا سياقِ محادثةٍ سابق ·
#    بلا صورة. وما عداه — «بسّط لي» · «مثال» · سؤالٌ في الدرس — يمضي إلى
#    الموديل كما كان، وهو بالضبط ما وصفه المالك: «لو أبغى يزيد شرح يقول
#    بسّط لي، فيتحوّل كلُّه مع الذكاء الاصطناعي».
#
# 🔴 **ولماذا «بلا سياقِ محادثة»؟** لأن الشرحَ المخزون لا يعرف ما قيل قبله.
#    فطالبٌ شُرح له نصفُ الدرس ثم قال «اشرح الدرس» يريد متابعةً لا نسخةً
#    جاهزة — و[CONTINUITY_RULES] تحكم تلك الحالة، لا الكاش.

_EXPLAIN_VERB = re.compile(r"^(?:اشرح|إشرح|شرح|وضح|وضّح|فسر|فسّر|ابدأ|"
                           r"explain|start)\b")
_LESSON_WORD = re.compile(r"\b(?:الدرس|درس|الدرسَ|كامل|كاملا|كاملاً|"
                          r"كله|كلَّه|lesson)\b")
# كلُّ ما تبقّى بعد نزع فعلِ الشرح وكلمةِ الدرس — إن بقي موضوعٌ فليس طلبَ
# الدرس كاملاً بل سؤالٌ فيه.
_FILLER = {"لي", "لنا", "هذا", "هذه", "من", "في", "على", "عن", "الذي",
           "please", "me", "the", "this", "for", "us", "it"}


def is_full_lesson_request(text: str) -> bool:
    """هل هذا «اشرح الدرس» لا سؤالاً داخله؟ والفراغُ طلبُ شرحٍ كامل."""
    t = " ".join((text or "").split())
    if not t:
        return True
    t = re.sub(r"[^\w\u0621-\u064A\s]", " ", t).strip()
    if not _EXPLAIN_VERB.match(t) or not _LESSON_WORD.search(t):
        return False
    rest = [w for w in _EXPLAIN_VERB.sub(" ", t).split()
            if not _LESSON_WORD.fullmatch(w) and w not in _FILLER]
    return not rest


def serves(req) -> bool:
    """شروطُ التسليم من المخزون — كلُّها أو لا شيء.

    🔴 **والشرطُ «لا جوابَ سابقاً» لا «سجلٌّ فارغ»** — وهذا فرقٌ كلّفنا
       الميزةَ كلَّها. أُثبت بمِسبارٍ حيّ من المحاكي (2026-09-16):

           CACHE-PROBE … hist=1 … serves=False

       والمحادثةُ **جديدةٌ تماماً**! لأن `processRequest` في التطبيق تضيف
       رسالةَ الطالب إلى `messages` **ثم** تبني منها `chat_history` — فيصل
       السجلُّ وفيه سؤالُ الطالب الحالي نفسُه. فكان شرطُ «السجلّ فارغ» لا
       يتحقّق **أبداً** في التطبيق الحقيقي: الكاشُ مبنيٌّ ومختبَرٌ ويعمل في
       قياساتنا المباشرة، **ولا يصل الطالبَ ولا مرّة**.

    ⚖️ والمقصودُ أصلاً أن لا يكون في المحادثة **جوابٌ سابق** يُبنى عليه —
       ورسالةُ الطالب الحالية ليست جواباً. فالفحصُ على ردود المساعد وحدها،
       وهو نفسُ مقياس [common.turn_note].

    ⚠️ **والدرسُ المتكرّر**: ما يُختبر بمدخلاتٍ نكتبها بأيدينا قد يسقط عند
       أول مستخدمٍ حقيقي ([chat-history-role-ai] — نفسُ العلّة بعينها).
    """
    if (getattr(req, "mode", "") or "").strip() != "شرح":
        return False
    if getattr(req, "images_base64", None):
        return False
    history = [m for m in (getattr(req, "chat_history", None) or [])
               if isinstance(m, dict)]
    if any(m.get("role") == "assistant" for m in history):
        return False
    return is_full_lesson_request(getattr(req, "content", "") or "")


# ══════════════════════════════════════════════════
# ⚡ التسليمُ المسبق — المخزونُ بلا مرورٍ بمسار السؤال
# ══════════════════════════════════════════════════
#
# 🔴 **علّةُ المالك (2026-09-16):** «لما أضغط شرح المفروض على طول يطلع لي
#    الشرح، ما ينتظر ثانيتين ولا ثلاثة — كما قسم الوزارة.»
#
# ⚖️ وكان الشرحُ المخزون يُقرأ من القرص في **مللي ثانيةٍ واحدة** (قياسٌ
#    مباشر)، لكنه يسافر في مسار `/ask` كاملاً: رحلةُ شبكةٍ من جهاز الطالب،
#    ثم حارسُ التوثيق، ثم **خصمُ الحصة من Firestore ثم ردُّها** (معاملتان
#    عبر الشبكة لطلبٍ لم يكلّف شيئاً أصلاً). فالانتظارُ كلُّه في الطريق لا
#    في الجواب.
#
# 🎯 **فليُقرأ قبل أن يُطلب**: يسحبه التطبيقُ لحظةَ اختيار الدرس عبر
#    [/lesson/explanation]، فتصير ضغطةُ «اشرح لي» عرضاً فورياً **بلا أي
#    رحلة شبكة**. وهذا ما يفعله قسمُ الوزاري الذي قاس عليه المالك.
#
# 🔒 **ولا تنادي موديلاً أبداً**: مخزونٌ أو لا شيء. فهي آمنةٌ للسحب المسبق
#    عند كل اختيار درس — لا حصةَ تُخصم ولا فاتورةَ تُصرف.

def stored_for(grade, track, subject: str, unit: str, lesson: str) -> Optional[str]:
    """الشرحُ المخزون لدرسٍ بعينه — يحلّ مصدرَه بنفسه ويتحقّق من بصمته.

    ⚠️ **والمصدرُ يختلف باختلاف المادة**: الرياضياتُ تُبصم من ملف الدرس
       (`math_source`) وما عداها من المُسلسِل — وهو نفسُ الفرق الذي يحرسه
       [math_source]. فلو وحّدناهما هنا لأخطأت البصمةُ صامتةً ولَما سُلّم
       شرحٌ واحد.
    """
    subject = (subject or "").strip()
    lesson = (lesson or "").strip()
    if not subject or not lesson:
        return None
    try:
        if subject == "رياضيات":
            from subjects.math import load_math_lesson      # استيرادٌ كسول: دائرة
            doc = load_math_lesson((unit or "").strip(), lesson)
            if not doc:
                return None
            return get(grade, track, subject, unit, lesson, math_source(doc))

        from .content_store import get_lessons_book, find_lesson
        from .serializer import serialize_lesson
        book = get_lessons_book(grade, track, subject)
        if book is None:
            return None
        found_unit, found_lesson = find_lesson(book, (unit or "").strip(), lesson)
        if found_lesson is None:
            found_unit, found_lesson = find_lesson(book, "", lesson)
        if found_lesson is None:
            return None
        unit_name = (found_unit or {}).get("اسم_الوحدة", "").strip()
        text = serialize_lesson(found_lesson, unit_name, subject=subject)
        return get(grade, track, subject, unit_name, lesson, text)
    except Exception as e:                      # قراءةٌ مساعدة لا تُسقط طلباً
        print(f"⚠️ تعذّر سحبُ الشرح المخزون «{subject} › {lesson}»: {e}")
        return None
