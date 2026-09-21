# -*- coding: utf-8 -*-
"""🛟 إنقاذُ الدروس التي لم تُخزَّن — **بنموذجٍ أقوى، ومحاولةٍ واحدةٍ لكلٍّ**.

    python -m tools.rescue_explanations --provider openai --model gpt-5.4
    python -m tools.rescue_explanations --provider gemini --model gemini-3.1-pro-preview --only فيزياء

⚖️ **قرار المالك (2026-09-16):** «مرّ على الباقية واحداً واحداً بأقلّ
   الخسائر — ضروري تكون مخزونة. وتقدر تغيّر الموديل للدرس: من فلاش إلى برو،
   أو تستعمل أوبن إيه آي مكان ديب سيك. **بس مرّة واحدة لا أكثر** عشان ما
   تخسّرنا كثير.»

🎯 فهذه الأداة:
   • تقرأ **الناقصَ وحده** من المخزون (لا تلمس ما بُني).
   • تنادي **مرّةً واحدةً لكل درس** — `retries = 0` مثبّتةٌ في الكود لا خياراً.
   • تحكم بنفس الفحص ([tools.build_explanations.verify])، فلا يدخل المخزونَ
     شرحٌ أضعفُ ممّا فيه.
   • وتطبع كلفةَ ما أنفقت: عددَ النداءات بالضبط.

⚠️ **ولا تُغيَّر توجيهاتُ المواد في المنتج**: النموذجُ الأقوى للبناء وحده،
   والطالبُ يبقى على `model_route` كما هي — أسرعَ وأرخص.
"""
from __future__ import annotations

import argparse
import asyncio
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import api                                       # noqa: E402
from core import curriculum as C                 # noqa: E402
from core import lesson_cache as LC              # noqa: E402
from core import lesson_mode as LM               # noqa: E402
from core import streaming                       # noqa: E402
from core.content_store import get_lessons_book  # noqa: E402
from core.curriculum import SUBJECTS_BY_GRADE_TRACK  # noqa: E402
from core.serializer import serialize_lesson     # noqa: E402
from subjects.common import load_math_lesson     # noqa: E402
from tools.build_explanations import (           # noqa: E402
    BUILD_MAX_TOKENS, _install_build_prompt, explain, lessons_of, verify,
)

# 🔢 **عدّادُ النداءات** — المالك يدفع بالنداء، فيراه بالضبط لا تقديراً.
CALLS = {"n": 0}


def missing_lessons():
    """كلُّ درسٍ في المنهج بلا شرحٍ مخزون — مرتّباً بالمادة."""
    out = []
    for (g, t) in sorted(SUBJECTS_BY_GRADE_TRACK):
        for s in SUBJECTS_BY_GRADE_TRACK[(g, t)]:
            book = get_lessons_book(g, t, s)
            if not book:
                continue
            for unit, name, lesson in lessons_of(book):
                src = serialize_lesson(lesson, unit, subject=s)
                fp = src
                if s == "رياضيات":
                    m = load_math_lesson(unit, name)
                    if m is None:
                        continue
                    fp = LC.math_source(m)
                if LC.get(g, t, s, unit, name, fp) is None:
                    out.append((g, t, s, unit, name, lesson, src, fp))
    return out


def install_model(provider: str, model: str, subjects: set):
    """يوجّه المواد المقصودة إلى النموذج الأقوى — **في هذه العملية وحدها**.

    ⚠️ و`max_tokens` تُترجم إلى `max_completion_tokens` لعائلة GPT-5:
       المزوّد يرفض الاسم القديم بـ400، وكشفَه نداءُ تجربةٍ واحد قبل البدء.
       (نفسُ درسِ ديب سيك: **لا يُخمَّن شكلُ الواجهة، يُسأل عنها.**)
    """
    orig_route = C.model_route

    def route(subject):
        if subject in subjects:
            return (provider, model)
        return orig_route(subject)

    C.model_route = route
    LM.model_route = route
    try:
        from core import pages_mode as PM
        PM.model_route = route
    except Exception:
        pass

    orig_complete = streaming.complete

    async def wrapped(client, *, model, messages, sink=None, timeout=50.0, **kw):
        CALLS["n"] += 1
        if model.startswith(("gpt-5", "o1", "o3", "o4")):
            if "max_tokens" in kw:
                kw["max_completion_tokens"] = kw.pop("max_tokens")
            kw.pop("temperature", None)          # غيرُ مدعومةٍ في هذه العائلة
            timeout = max(timeout, 240)
        elif "pro" in model:
            timeout = max(timeout, 240)          # برو أبطأ بكثير (قِيس ٣٦ث+)
        return await orig_complete(client, model=model, messages=messages,
                                   sink=sink, timeout=timeout, **kw)

    streaming.complete = wrapped


async def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--provider", required=True, choices=("gemini", "openai", "deepseek"))
    ap.add_argument("--model", required=True)
    ap.add_argument("--only", default="", help="مادةٌ واحدة (اختياري)")
    ap.add_argument("--limit", type=int, default=0)
    args = ap.parse_args()

    items = missing_lessons()
    if args.only:
        items = [i for i in items if i[2] == args.only]
    if args.limit:
        items = items[:args.limit]
    if not items:
        print("✅ لا دروسَ ناقصة.")
        return

    subjects = {i[2] for i in items}
    print(f"🛟 الناقص: {len(items)} درساً في {len(subjects)} مادة"
          f" — بنموذج {args.model} ({args.provider})، **نداءٌ واحدٌ لكلٍّ**\n")

    LM._MAX_TOKENS = BUILD_MAX_TOKENS
    _install_build_prompt()
    install_model(args.provider, args.model, subjects)

    saved = []
    for n, (g, t, s, unit, name, lesson, src, fp) in enumerate(items, 1):
        t0 = time.time()
        try:
            answer = await explain(s, g, t, unit, name)
        except Exception as e:
            answer = f"EXC {type(e).__name__}: {e}"
        bad = verify(s, lesson, src, answer, name)
        secs = time.time() - t0
        if not bad:
            LC.put(g, t, s, unit, name, fp, answer, args.model)
            saved.append((s, name))
            print(f"  ✅ [{n}/{len(items)}] صف{g} {s} › {name[:38]:<40}"
                  f"{len(answer):>6} حرفاً {secs:>6.1f}ث")
        else:
            print(f"  ❌ [{n}/{len(items)}] صف{g} {s} › {name[:38]:<40}"
                  f"{secs:>6.1f}ث  ← {' ؛ '.join(bad)[:90]}")

    print(f"\n{'='*66}")
    print(f"أُنقذ: {len(saved)} من {len(items)} · النداءات: {CALLS['n']}"
          f" (نداءٌ واحدٌ لكل درس كما طُلب)")
    by = {}
    for s, _ in saved:
        by[s] = by.get(s, 0) + 1
    for s, c in sorted(by.items(), key=lambda x: -x[1]):
        print(f"   • {s}: +{c}")

if __name__ == "__main__":
    asyncio.run(main())
