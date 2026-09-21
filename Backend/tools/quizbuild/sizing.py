# -*- coding: utf-8 -*-
"""📄 حجمُ البنك وتقسيمُ المصدر إلى دفعات

    جزءٌ من [build_quizzes.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في ملفٍ لحاله»
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.
"""
from __future__ import annotations
from .boot import re
from .consts import (BATCH_TARGET, CHARS_PER_QUESTION, MAX_QUESTIONS, MIN_QUESTIONS)


# ══════════════════════════════════════════════════
# 📐 حجمُ البنك وتقسيمُ المصدر
# ══════════════════════════════════════════════════

def bank_size(source: str) -> int:
    return max(MIN_QUESTIONS, min(MAX_QUESTIONS,
                                  round(len(source) / CHARS_PER_QUESTION)))


_PART = re.compile(r"^\s*نوع:\s*\S+", re.M)


def batches_for(want: int) -> int:
    """كم دفعةً لهذا البنك — وسقفُها ثلاثٌ احتراماً لحدّ المالك."""
    if want <= BATCH_TARGET + 1:
        return 1
    return 2 if want <= 2 * BATCH_TARGET + 2 else 3


def split_source(source: str, parts: int) -> list:
    """يقسم نصَّ الدرس عند **حدود أجزائه** — لا في منتصف جملةٍ ولا ترميز.

    ⚠️ **ولا يُشطر ترميزُ رسمٍ نصفين**: القصُّ عند بداية جزءٍ دائماً، فلا
       يصل الموديلَ `\\ring{6|ar` مبتوراً فينقله كما أُمر ([quiz._clip]).
    🛟 وإن لم تكفِ الأجزاءُ للقسمة رجعنا بالنصّ كاملاً — نصٌّ كاملٌ لدفعةٍ
       واحدة خيرٌ من نصفٍ مبتور.
    """
    if parts <= 1:
        return [source]
    starts = [m.start() for m in _PART.finditer(source)]
    if len(starts) < parts + 2:
        return [source]
    cuts = []
    for i in range(1, parts):
        target = len(source) * i // parts
        cut = min(starts[1:], key=lambda s: abs(s - target))
        if cut not in cuts:
            cuts.append(cut)
    cuts = sorted(set(cuts))
    bounds = [0] + cuts + [len(source)]
    chunks = [source[a:b].strip() for a, b in zip(bounds, bounds[1:])]
    if any(len(c) < 400 for c in chunks):
        return [source]
    return chunks


