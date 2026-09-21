# -*- coding: utf-8 -*-
"""🏗️ مولِّدُ شروح الدروس — يبني ما يُخزَّن في [core/lesson_cache].

    python -m tools.build_explanations --grade 3 --track علمي --subject احياء
    python -m tools.build_explanations --grade 3 --track علمي --subject احياء --limit 3 --dry

⚖️ **يمرّ بالمسار الحقيقي** (`api._dispatch_subject`) لا ببرومبتٍ خاص: فما
   يُخزَّن هو **نفسُ ما كان الطالب سيراه** — نفس البرومبتات ونفس قواعد
   الرسّام ونفس الفلاتر النهائية. وأيُّ تحسينٍ في البرومبت غداً يصل هذا
   المولِّد بلا لمسه.

🔎 **ولا يُخزَّن شرحٌ لم يجتز الفحص**: لكل درسٍ فحصٌ آليّ (ترميزُ الرسم ·
   تغطيةُ الأقسام · لا لاتيك خام · الطول)، وما سقط يُعاد توليدُه مرّةً
   بتوجيهٍ يسمّي ما نقص، وما سقط مرّتين يُسجَّل في تقريرٍ ولا يُكتب.
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import api                                    # noqa: E402
from models import AskRequest                 # noqa: E402
from core import lesson_cache as LC           # noqa: E402
from core import lesson_mode as LM            # noqa: E402
from core.content_store import get_lessons_book  # noqa: E402
from core.curriculum import SUBJECTS_BY_GRADE_TRACK, model_route  # noqa: E402
from core.serializer import serialize_lesson  # noqa: E402
from tools import teaching_addendum as TA   # noqa: E402
