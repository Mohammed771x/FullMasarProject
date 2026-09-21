#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""🏗️ مولِّدُ بنوك الأسئلة — يبني ما يُخزَّن في [core/quiz_bank].

⚖️ **قرار المالك (2026-09-16):** «سوِّ كاشنج لاختبر نفسك، ابدأ بالثالث
   الثانوي كاملاً. OpenAI لكل المواد وديب سيك للرياضيات، ولا جيميناي.
   والشيء اللي يرجع غلط أنت تعدّله، أو تعطيه طلبين أو ثلاثة كحدٍّ أقصى.
   **وجودةُ المحتوى أهمُّ شيء — إحنا بنسوّيه مرّةً واحدة.**»

الاستعمال:
    .venv/bin/python tools/build_quizzes.py --grade 3 --track علمي
    .venv/bin/python tools/build_quizzes.py --grade 2 --all --jobs 4
    .venv/bin/python tools/build_quizzes.py --rescan          # بصفر نداءات
    .venv/bin/python tools/build_quizzes.py --report
"""
from __future__ import annotations

import argparse
import asyncio
import json
import os
import re
import statistics as st
import sys
import time
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from core import quiz_bank as QB                                # noqa: E402
from core.content_store import (get_lessons_book, lessons_units,  # noqa: E402
                                lessons_in_unit, find_lesson)
from core.curriculum import subjects_for, normalize_grade_track  # noqa: E402
from core.quiz import extract_json, repair_escapes              # noqa: E402
from core.serializer import serialize_lesson                    # noqa: E402
from tools import quiz_spec                                     # noqa: E402
from tools.build_explanations import (_norm_codes, DRAW,        # noqa: E402
                                      _is_numeric_substitution,
                                      ARABIC_DIGIT_SUBJECTS)

