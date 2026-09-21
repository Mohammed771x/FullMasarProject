# -*- coding: utf-8 -*-
"""📄 بناءُ درسٍ واحد

    جزءٌ من [build_quizzes.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في ملفٍ لحاله»
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.
"""
from __future__ import annotations
from .boot import asyncio, extract_json, quiz_spec
from .consts import _MAX_SOURCE
from .sizing import batches_for, split_source
from .weights import calibrate_weights
from .checks import check_batch, check_question
from .models import ask_model
from .repair import tidy_question


# ══════════════════════════════════════════════════
# 🏗️ بناءُ درسٍ واحد
# ══════════════════════════════════════════════════

async def build_lesson(subject, lesson_name, source, want, retries=1,
                       budget=None):
    """يعيد `(أسئلة، عيوب، نداءات)`. لا يكتب شيئاً — القرارُ لمن ناداه."""
    chunks = split_source(source, batches_for(want))
    per = [want // len(chunks)] * len(chunks)
    per[0] += want - sum(per)

    calls = 0
    collected, defects = [], []
    for chunk, k in zip(chunks, per):
        # ✂️ **ويُقتطع مرّةً واحدة**: ما يراه الموديلُ هو ما يُقاس عليه —
        #    فلا يُطلب ترميزٌ من نصٍّ لم يصله.
        chunk = chunk[:_MAX_SOURCE]
        messages = [
            {"role": "system", "content": quiz_spec.system_prompt(subject, k)},
            {"role": "user",
             # 🎯 **ويُطلب بمقياس البنك (٨) ويُقاس بمقياس الدفعة (١٢)** —
             #    هامشُ امتثال، لا مخادعة. قِيس (2026-09-17): الطلبُ بمقياس
             #    الدفعة أعطى ٢ من ٣ في «توازن جسمٍ صلب» و١ من ٢ في «الحركة
             #    الاهتزازية» — يقصّر بواحدٍ دائماً. والحصّةُ محسوبةٌ على
             #    **القطعة** نفسِها، فقطعةٌ بلا ترميزٍ لا يُطلب منها شيء.
             "content": quiz_spec.user_prompt(lesson_name, chunk, k,
                                              subject=subject)},
        ]
        got, bad = [], []
        best, best_bad = [], None
        for attempt in range(retries + 1):
            if budget is not None and calls >= budget:
                break
            calls += 1
            try:
                raw = await ask_model(subject, messages)
            except asyncio.TimeoutError:
                bad = ["انتهت المهلة"]
                continue
            except Exception as e:                       # noqa: BLE001
                bad = [f"خطأ نداء: {e}"]
                continue

            data = extract_json(raw)
            if not isinstance(data, dict) or not isinstance(
                    data.get("questions"), list):
                bad = ["الردُّ ليس JSON صالحاً"]
                messages += [{"role": "assistant", "content": (raw or "")[:400]},
                             {"role": "user", "content": quiz_spec.JSON_HINT}]
                continue

            got, bad = [], []
            for item in data["questions"]:
                fixed = tidy_question(item, lesson_name, subject)
                if fixed is None:
                    continue                             # 🔧 يُطرح لا يُصلَّح
                faults = check_question(fixed, subject)
                if faults:
                    bad.extend(faults)
                    continue
                got.append(fixed)

            # 🔁 ونُزيل ما تكرّر داخل الدفعة نفسِها قبل الحكم
            seen, uniq = set(), []
            for q in got:
                if q["id"] in seen:
                    continue
                seen.add(q["id"])
                uniq.append(q)
            got = uniq

            # 🎯 **وعيوبُ الشكل تُضمّ إلى عيوب الأسئلة** — فيصل الموديلَ
            #    في النداء التصحيحي **كلُّ** ما أسقط دفعتَه، لا نصفُه.
            bad = sorted(set(bad + check_batch(got, k, subject,
                                               lesson_name, chunk)))
            # 🏆 **ويُحتفظ بأفضل محاولةٍ لا بآخرِها.**
            #    ☢️ قِيس: النداءُ التصحيحي قد يعود بعددٍ **أقلّ** (١٧ ثم ١٣)،
            #    فأخذُ الأخيرة يعني أن التصحيحَ أفسدَ ما كان أصلحَ منه.
            if best_bad is None or (len(bad), -len(got)) < best_bad:
                best, best_bad = got, (len(bad), -len(got))
            if not bad:
                break
            if attempt < retries:
                messages += [
                    {"role": "assistant", "content": (raw or "")[:400]},
                    {"role": "user", "content": quiz_spec.retry_prompt(bad, k)},
                ]
        got = best
        collected.extend(got)
        defects.extend(bad)

    # 🔁 وإزالةُ التكرار بين الدفعات
    seen, uniq = set(), []
    for q in collected:
        if q["id"] in seen:
            continue
        seen.add(q["id"])
        uniq.append(q)

    # ⚖️ ثم تُعاير الأوزانُ على **البنك كلِّه** — لا على دفعةٍ منه، فالأهميةُ
    #    مقارنةٌ داخل الدرس لا داخل نصفه.
    calibrate_weights(uniq, source)
    return uniq, sorted(set(defects)), calls


