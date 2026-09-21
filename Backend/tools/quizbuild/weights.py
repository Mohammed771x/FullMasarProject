# -*- coding: utf-8 -*-
"""📄 معايرةُ الأوزان — الترتيبُ من الموديل والتوزيعُ منّا

    جزءٌ من [build_quizzes.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في ملفٍ لحاله»
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.
"""
from __future__ import annotations
from .boot import re


# ══════════════════════════════════════════════════
# ⚖️ معايرةُ الأوزان — الترتيبُ من الموديل، والتوزيعُ منّا
# ══════════════════════════════════════════════════
#
# ☢️ **قِيس ثلاثَ مرّاتٍ متتالية (2026-09-16):** `gpt-4o-mini` يعطي ٧٠–٨٠٪
#    من الأسئلة وزنَ ٤ أو ٥ مهما شُدّد الطلبُ وأُعيد النداء. وهذا ليس عناداً
#    بل **حدُّ النموذج**: الحكمُ المطلق على الأهمية ليس مما يُتقنه.
#
# 🎯 **فما يُتقنه هو الترتيب لا المقياس.** فنأخذ منه الترتيبَ ونفرض نحن
#    التوزيعَ — وهو عينُ ما طلبه المالك: «الوزنُ مقارنةٌ **داخل الدرس**».
#    ⇐ رتّب الأسئلةَ بأهميتها، ثم: الخُمسُ الأعلى ٥ · ثم ربعٌ ٤ · ثم ثلثٌ ٣ ·
#      والباقي ٢ ثم ١. فالتوزيعُ مضمونٌ بالبناء لا بالرجاء، **وبصفر نداءات**.
#
# 🔗 **والترتيبُ يُسنَد بمرساةٍ من الكتاب نفسِه** لا بتقدير الموديل وحده:
#    نقطةٌ وردت في «تقويم» أو «أسئلة» (أي **سأل عنها الكتابُ نفسُه**) أو في
#    «تعريفات» و«قواعد» ⇒ ترتفع. ونقطةٌ يتكرّر ذكرُها في الدرس ⇒ ترتفع.

_HIGH_PARTS = ("تقويم", "أسئلة", "تعريفات", "تعريف", "قواعد", "معادلات",
               "نقاط_مهمة")
_LOW_PARTS = ("معلومة_إثرائية", "نشاط", "مقدمة", "رسوم_توضيحية",
              "رسومات_توضيحية")
_PART_HEAD = re.compile(r"^\s*نوع:\s*(\S+)", re.M)
_WORD = re.compile(r"[\u0621-\u064A]{4,}")


def _parts_text(source: str, names) -> str:
    """نصُّ الأجزاء التي نوعُها من `names` مجموعاً."""
    out, cur, keep = [], [], False
    for line in (source or "").split("\n"):
        m = _PART_HEAD.match(line)
        if m:
            if keep:
                out.append("\n".join(cur))
            cur, keep = [], m.group(1) in names
            continue
        if keep:
            cur.append(line)
    if keep:
        out.append("\n".join(cur))
    return "\n".join(out)


def _anchor_bonus(topic: str, high: str, low: str, source: str) -> float:
    """علاوةُ الأهمية من بنية الكتاب — لا من ذوق الموديل."""
    words = [w for w in _WORD.findall(topic or "") if len(w) >= 4]
    if not words:
        return 0.0
    bonus = 0.0
    if any(w in high for w in words):
        bonus += 1.2           # سأل عنه الكتابُ أو عرّفه صراحةً
    if any(w in low for w in words):
        bonus -= 0.8           # إثراءٌ أو نشاطٌ أو مقدّمة
    hits = sum(source.count(w) for w in words[:3])
    if hits >= 6:
        bonus += 0.6           # يتكرّر في الدرس ⇒ محوريّ
    elif hits <= 1:
        bonus -= 0.3
    return bonus


# 📊 التوزيعُ المفروض: ٢٠٪ خمسة · ٢٥٪ أربعة · ٣٠٪ ثلاثة · ١٥٪ اثنان · ١٠٪ واحد
_WEIGHT_SHAPE = ((5, 0.20), (4, 0.25), (3, 0.30), (2, 0.15), (1, 0.10))


def calibrate_weights(questions: list, source: str) -> list:
    """يعيد كتابة `weight` بالرتبة — ويُبقي ترتيبَ الموديل ومرساةَ الكتاب."""
    if not questions:
        return questions
    high = _parts_text(source, _HIGH_PARTS)
    low = _parts_text(source, _LOW_PARTS)
    scored = []
    for i, q in enumerate(questions):
        score = float(q.get("weight", 3))
        score += _anchor_bonus(q.get("topic", ""), high, low, source)
        # ترجيحٌ خفيفٌ للتعريف والقانون: عمودُ الدرس غالباً
        if q.get("kind") in ("تعريف", "قانون"):
            score += 0.25
        scored.append((-score, i, q))
    scored.sort()

    n = len(scored)
    cuts, start = [], 0
    for value, share in _WEIGHT_SHAPE:
        end = min(n, start + max(1, round(n * share)))
        cuts.append((value, start, end))
        start = end
    if start < n:                       # ما تبقّى بسبب التقريب ⇒ أدنى وزن
        cuts[-1] = (cuts[-1][0], cuts[-1][1], n)

    for value, a, b in cuts:
        for _s, _i, q in scored[a:b]:
            q["weight"] = value
    return questions


