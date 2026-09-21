# -*- coding: utf-8 -*-
"""📄 التوليدُ وكتابةُ الحَجْر

    جزءٌ من [build_explanations.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في ملفٍ لحاله»
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.
"""
from __future__ import annotations
from .boot import (AskRequest, LC, LM, TA, api, asyncio, get_lessons_book, json, model_route, os, re, serialize_lesson, time)
from .consts import ASK, BUILD_MODEL, DRAW, HINT_CODES
from .verify import verify


# ══════════════════════════════════════════════════
# 🤖 التوليد
# ══════════════════════════════════════════════════

def _install_build_prompt() -> None:
    """يلفّ بناةَ البرومبت فيُلحق [teaching_addendum] — **في هذه العملية فقط**.

    ⚖️ لفٌّ لا تعديلٌ في المصدر: لا يمسّ ما يراه الطالبُ في المحادثة، ولا
       يترك أثراً إن سقط البناء في منتصفه. والمواد التي لها معالجٌ خاص
       (الرياضيات) تُلفّ من بابها هي الأخرى.

    🔬 **والمواصفةُ بحسب المادة**: حسُّ تدريسِ الفيزياء ليس حسَّ تدريس
       التاريخ — و`_system_prompt` يعرف المادةَ، فتُمرَّر إليه.
    """
    _orig = LM._system_prompt

    def wrapped(mode, subject, summary_level, prompts=None):
        return _orig(mode, subject, summary_level, prompts) + TA.addendum(subject)
    LM._system_prompt = wrapped

    try:
        import subjects.math as _M
        _om = _M.system_prompt_math_explain
        _M.system_prompt_math_explain = lambda: _om() + TA.addendum("رياضيات")
    except Exception:
        pass


# ✂️ **الخطُّ الأفقيُّ يُنزع لا يُرفض.**
#    تنهى [teaching_addendum] عن `---` بين الأقسام لأنه يقطع خيطَ الدرس
#    ويجعله جزراً. ولو رفضنا الشرحَ لأجله لدفعنا نداءً كاملاً ثمنَ سطرٍ
#    زخرفيّ — والنزعُ لا يُفقد الطالبَ حرفاً. أما جملةُ الوصل فيصنعها
#    البرومبتُ لا المقصّ.
_RULE_LINE = re.compile(r"^[ \t]*(?:-{3,}|\*{3,}|_{3,})[ \t]*$", re.M)

# 🔠 **سطرٌ كلُّه عريضٌ هو عنوانٌ في نيّة الكاتب — وماركداون لا يراه كذلك.**
#
# 🔴 قِيس في المحاكي (2026-09-16): كتب الموديل
#        **مفاهيم أساسية في السيال العصبي**
#        نبدأ بتعريف بطل درسنا…
#    وسطرٌ واحدٌ فاصلٌ **لا يُنشئ فقرةً** في ماركداون، فظهرا للطالب ملتصقين:
#    «مفاهيم أساسية في السيال العصبي نبدأ بتعريف…» — عنوانٌ ابتلعته فقرتُه.
#    ولم يره أيُّ فحصٍ نصّيّ لأن النصَّ سليمٌ تماماً؛ **رآه الشكلُ وحده.**
#
# ⚖️ والتحويلُ آمنٌ لأنه مشروطٌ بأن يكون السطرُ عريضاً **كلَّه**: أما
#    `🌍 **قرّبها:** …` و`1. **الاستقطاب:** …` ففيهما نصٌّ خارج العريض
#    فلا يُمسّان.
_BOLD_ONLY_LINE = re.compile(r"^[ \t]*\*\*(?!\s)([^*\n]{2,90}?)\*\*[ \t]*:?[ \t]*$", re.M)


# 🏷️ **وتسمياتُ المُسلسِل تتسرّب إلى العناوين.** يُقدَّم نصُّ الدرس للموديل
#    موسوماً بنوع كل جزء («نوع: نقاط_مهمة» · «تعريف» · «جدول» · «شرح»)،
#    فينسخ الموديلُ الوسمَ مع العنوان: «### نقاط مهمة: أسباب الفقر».
#    وهي **لغتُنا الداخلية لا لغةُ الكتاب**، ويراها الطالبُ في وجه الشرح.
#    رُصد بالعين (2026-09-16) في ٦٨ عنواناً من ٢٩ درساً، أكثرُها جغرافيا.
_LEAKED_LABEL = re.compile(
    r"^(###\s+)(?:نقاط مهمة|تعريف|جدول|شرح|مقدمة|نشاط|أسئلة|تقويم|معلومة|"
    r"ملاحظة|قاعدة|مثال|أمثلة|تمارين|صورة|شكل)\s*[:：]\s*(?=\S)", re.M)
# ونفسُ الوسم وحدَه عنواناً: «### أمثلة:» ⇐ «### أمثلة».
_LABEL_ONLY = re.compile(r"^(###\s+[^\n:：]+)[:：]\s*$", re.M)


def _tidy(answer: str) -> str:
    out = _RULE_LINE.sub("", answer or "")
    out = _BOLD_ONLY_LINE.sub(r"### \1", out)
    out = _LEAKED_LABEL.sub(r"\1", out)
    out = _LABEL_ONLY.sub(r"\1", out)
    return re.sub(r"\n{3,}", "\n\n", out).strip()


# 📐 **قائمةُ الترميزات في النداء الأوّل** — لا بعد السقوط.
#
# ⚖️ ثلاثُ جولاتٍ تصحيحية أوصلتنا إلى ٩٨٫٥٪، وما بقي يسقط دائماً في
#    **ترميزِ رسمٍ لم يُنقل**. والتصحيحُ يأتي بعد أن يكون الموديلُ قد بنى
#    شرحَه كلَّه، فيُقحم الرمزَ إقحاماً أو ينساه ثانية. فإعطاؤه **قائمةَ
#    الصيغ المطلوبة قبل أن يكتب** يجعلها جزءاً من خطّته لا رقعةً عليها.
def codes_hint(source: str) -> str:
    codes = list(dict.fromkeys(DRAW.findall(source or "")))
    if not codes:
        return ""
    return ("\n\n📐 **وهذه صيغُ الدرس، يجب أن تظهر في شرحك بترميزها هذا "
            "حرفاً بحرف، كلٌّ في موضعها من الشرح:**\n"
            + "\n".join(f"• {c}" for c in codes[:40]))


async def explain(subject, grade, track, unit, lesson_name, extra: str = "") -> str:
    req = AskRequest(subject=subject, grade=grade, track=track, mode="شرح",
                     input_type="برومت", content=ASK + extra, search_query=ASK,
                     content_mode="lessons", unit_name=unit,
                     lesson_name=lesson_name, chat_history=[])
    out = await api._dispatch_subject(req)
    return _tidy((out.get("answer") if isinstance(out, dict) else "") or "")


def lessons_of(book):
    units = book.get("الوحدات") if isinstance(book, dict) else book
    for u in units or []:
        if not isinstance(u, dict):
            continue
        uname = (u.get("اسم_الوحدة") or "").strip()
        for l in u.get("الدروس") or []:
            name = (l.get("اسم_الدرس") or "").strip()
            if name:
                yield uname, name, l


async def _one(i, total, grade, track, subject, unit, name, lesson, model,
               dry, retries, skip_existing, sem):
    """درسٌ واحد: توليدٌ ⇐ فحصٌ ⇐ إعادةٌ بتوجيهٍ ⇐ تخزين."""
    source = serialize_lesson(lesson, unit, subject=subject)
    if subject == "رياضيات":
        # ⚖️ مصدرُ بصمةٍ واحدٌ مع المعالج، وإلا أخطأ الكاشُ دائماً.
        from subjects.common import load_math_lesson
        _m = load_math_lesson(unit, name)
        if _m is None:
            print(f"  ⏭️  [{i}/{total}] {name[:44]} — لم يجده معالجُ الرياضيات")
            return None
        fp_source = LC.math_source(_m)
    else:
        fp_source = source
    # ⏭️ **إعادةُ التشغيل رخيصة**: ما بُني وبصمتُه مطابقةٌ يُتخطّى، فلا
    #    يُعاد توليدُ مئاتِ الدروس كلَّما شُغّل البناء من جديد. وهذا ما
    #    يجعل تحسينَ البرومبت ثم إعادةَ المحاولة على المخفقِ وحده ممكناً.
    # ⏭️ **ويُتخطّى ما بُني بالمواصفة الحالية وحدَه.** وأوّلُ صياغةٍ نظرت
    #    إلى وجود الشرح لا إلى مواصفته، فتخطّت الدروسَ السبعةَ والأربعين
    #    كلَّها في أوّل تشغيلٍ لإعادة البناء — لأن بصمةَ الدرس لم تتغيّر،
    #    وإنما تغيّرت **طريقةُ شرحه**.
    if skip_existing and LC.entry_spec(grade, track, subject, unit,
                                       name, fp_source) == TA.VERSION:
        print(f"  ⏭️  [{i}/{total}] {name[:44]:<46} مبنيٌّ بالمواصفة الحالية")
        return None

    async with sem:
        t0 = time.time()
        extra = codes_hint(source) if HINT_CODES else ""
        bad, answer = [], ""
        for _ in range(retries + 1):
            answer = await explain(subject, grade, track, unit, name, extra)
            bad = verify(subject, lesson, source, answer, name)
            if not bad:
                break
            extra = ("\n\n⚠️ وانتبه لما نقص في محاولةٍ سابقة: " + " ؛ ".join(bad)
                     + ". أعد الشرحَ كاملاً مستوفياً ذلك.")
        secs = time.time() - t0

    ok = not bad
    if not dry:
        if ok:
            LC.put(grade, track, subject, unit, name, fp_source, answer,
                   model, TA.VERSION)
        else:
            # 🗑️ وما سقط اليوم لا يبقى مخزوناً من بناءٍ سابق — وإلا
            #    سُلّم للطالب جوابٌ لا يجتاز معاييرَنا ([lesson_cache.drop]).
            LC.drop(grade, track, subject, unit, name)
            # 🏥 لكنه **يُحفظ في الحَجْر** لا يُرمى: إن كان العيبُ في
            #    مقياسنا أنقذه `--rescan` لاحقاً بلا نداءٍ جديد.
            quarantine(grade, track, subject, unit, name, fp_source,
                       answer, model, bad)
    flag = "✅" if ok else "❌"
    print(f"  {flag} [{i}/{total}] {name[:44]:<46}"
          f"{len(answer):>7} حرفاً {secs:>6.1f}ث"
          + ("" if ok else "  ← " + " ؛ ".join(bad)[:110]))
    return (subject, unit, name, len(source), len(answer), secs, bad)


async def build_subject(grade, track, subject, limit=0, dry=False, retries=1,
                        skip_existing=False, jobs=1):
    """كلُّ دروس المادة — **متوازيةً بقدر `jobs`**.

    ⚖️ **والتوازي صار ضرورة** حين انتقل البناءُ إلى نموذجٍ أقوى: ٤٠ ثانية
       للدرس × ٨٣١ درساً = تسعُ ساعاتٍ متسلسلة. والبوّابةُ سيمافور لا
       أكثر — و[lesson_cache.put] آمنٌ بينها لأنه لا ينتظر شيئاً في
       أثنائه، فلا تتداخل كتابتان في حلقةِ أحداثٍ واحدة.
    """
    book = get_lessons_book(grade, track, subject)
    if not book:
        print(f"⏭️  {subject}: لا دروسَ لهذا الصف")
        return []
    items = list(lessons_of(book))
    if limit:
        items = items[:limit]
    # 🏷️ **واسمُ النموذج يُؤخذ من التحويل إن وُجد.** `model_route` مستوردةٌ
    #    بالاسم هنا، فتحويلُها في `core.curriculum` لا يغيّر هذا المرجع —
    #    فكان المخزونُ يُختم باسم النموذج الافتراضي بينما النداءُ يذهب إلى
    #    نموذجٍ آخر. ختمٌ يكذب أسوأُ من ختمٍ لا يوجد.
    model = BUILD_MODEL or model_route(subject)[1]
    sem = asyncio.Semaphore(max(1, jobs))
    tasks = [_one(i, len(items), grade, track, subject, unit, name, lesson,
                  model, dry, retries, skip_existing, sem)
             for i, (unit, name, lesson) in enumerate(items, 1)]
    return [r for r in await asyncio.gather(*tasks) if r]


def _reroute_math(provider: str, model: str) -> None:
    r"""🧮 **والرياضياتُ وحدَها لا يكفيها تحويلُ `model_route`.**

    كلُّ مادةٍ أخرى تمرّ بـ[lesson_mode.handle] فتختار عميلَها من القاموس
    بحسب ما يقوله `model_route` — فتحويلُ الدالّة يكفيها. أما الرياضيات
    فمعالجُها الخاصّ:
      • يُمسك `MATH_MODEL` **لحظةَ الاستيراد** (`_route("رياضيات")[1]`)،
        فلا يراه تحويلٌ يأتي بعده، و
      • يُنادَى بعميل ديب سيك **صراحةً** من `api._dispatch_subject`.
    فلو حوّلنا الدالّة وحدها لذهب اسمُ نموذجٍ جيميني إلى بوّابة ديب سيك.

    ⚠️ وهذا صنفُ العطب الذي **لا يشتكي**: نداءٌ يخفق أو يهذي، ودرسٌ يسقط،
       ولا شيءَ يقول إن السببَ عميلٌ لا يطابق نموذجَه.
    """
    try:
        import api
        import subjects.math as M
        M.MATH_MODEL = model
        M.MATH_TIMEOUT = max(getattr(M, "MATH_TIMEOUT", 120.0), 300.0)
        client = api.AI_CLIENTS.get(provider)
        if client is not None:
            api.deepseek_client = client     # ما يُمرَّر لمعالج الرياضيات
    except Exception as e:
        print(f"⚠️ تعذّر تحويلُ الرياضيات إلى {model}: {e}")


# ══════════════════════════════════════════════════
# 🏥 الحَجْر — الجوابُ المرفوضُ يُحفظ ولا يُرمى
# ══════════════════════════════════════════════════
#
# ☢️ **الدرسُ الذي كلّفنا أكثرَ من غيره**: كان الجوابُ الساقطُ يُرمى، فإذا
#    اكتشفنا بعده أن **المقياسَ** هو المخطئ (وقع ستَّ مرّات: الجذرُ والأُسّ
#    والصيغةُ الكيميائية و«باي» وعناوينُ الأشكال وسقفُ الرياضيات) لم يكن
#    أمامنا إلا **إعادةُ الشراء** — نداءٌ جديدٌ لكل درسٍ لنستعيد جواباً
#    كان صحيحاً في أيدينا ثم أتلفناه بحكمٍ خاطئ.
#
# ⚖️ فصار يُحفظ في `_rejected/` مع أسباب رفضه. وإصلاحُ المقياس بعدها
#    يُنقذ ما يُنقذ بـ`--rescan` **بصفر نداءات** — وهذا بالضبط ما طلبه
#    المالك: «مرّةً واحدة يعطيك الموديل الردّ، وإذا شفت فيه أخطاء أنت عدّله».
REJECTED_DIR = LC.EXPLANATIONS_DIR / "_rejected"


def _rej_file(grade, track, subject: str):
    return REJECTED_DIR / str(grade) / (track or "عام") / f"{subject}.json"


def quarantine(grade, track, subject, unit, lesson, fp_source, answer, model,
               defects) -> None:
    path = _rej_file(grade, track, subject)
    path.parent.mkdir(parents=True, exist_ok=True)
    data = {}
    if path.exists():
        try:
            data = json.loads(path.read_text(encoding="utf-8")) or {}
        except Exception:
            data = {}
    data[LC.key_of(unit, lesson)] = {
        "unit": unit, "lesson": lesson, "hash": LC.fingerprint(fp_source),
        "model": model, "spec": TA.VERSION, "chars": len(answer or ""),
        "defects": defects, "answer": answer,
    }
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
    os.replace(tmp, path)


# 🤝 **ما عيبُه في العلامات وحدها يُرقَّى** — لأن البديلَ أسوأ منه
#
# ⚖️ **القرارُ ليس بين الكامل والناقص، بل بين هذا وذاك.** درسٌ محجوزٌ عيبُه
#    «بلا 🧩 من أين نبدأ؟» يفتتح بالفكرة الكبرى ويقرّب ويوجز ويختم —
#    والقائمُ مكانه **نسخُ الكتاب حرفاً بحرف** الذي رفضه المالكُ صراحةً.
#    فإبقاءُ الأسوأ حفاظاً على كمال المقياس عبثٌ بالطالب لا حفاظٌ عليه.
#
# 🚧 **وحدُّه صارم**: العيبُ في **العلامات وحدها**. أما نقصُ ترميزِ رسمٍ أو
#    تغطيةٍ أو طولٍ فعيبٌ في **المحتوى** لا يُرقَّى معه شيء — تلك هي التي
#    بُني الحارسُ لأجلها.
