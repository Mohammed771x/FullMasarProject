#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""🚪 مولِّدُ بنوك «اختبر نفسك» — البابُ، لا الغرفة.

⚖️ **أمرُ المالك (2026-09-20):** «نفس الشيء باختبر نفسك… كل قسمٍ في ملفٍ
   لحاله، فالتعديلُ على نطاقٍ أقلّ، واللي يحصل خطأ بيحصل على ملفٍ قصير».

   وكان هذا الملفُّ **١٣٥٠ سطراً**. صار الجسدُ في [tools/quizbuild/] أحدَ
   عشرَ ملفاً، أطولُها ٣١٢ سطراً — **منقولاً حرفاً بحرف**، بلا تغيير سطرٍ
   واحد، وبرهانُ النقل حسابيّ: مجموعُ سطور الأجزاء = سطورُ الأصل.

🔒 ولم يتغيّر شيءٌ للمستعمِل: سطرُ الأوامر كما هو، و`from tools.build_quizzes
   import X` تعمل لكلِّ اسمٍ كما كانت.

الاستعمال:
    .venv/bin/python tools/build_quizzes.py --grade 3 --track علمي
    .venv/bin/python tools/build_quizzes.py --grade 2 --all --jobs 4
    .venv/bin/python tools/build_quizzes.py --rescan          # بصفر نداءات
    .venv/bin/python tools/build_quizzes.py --report

📝 **وأين تُعدِّل؟** في ملفِّ الجزء لا هنا:
#    · quizbuild/boot.py — المكتبات والمداخل
#    · quizbuild/consts.py — الثوابتُ والأنماطُ وحدودُ البنك
#    · quizbuild/sizing.py — حجمُ البنك وتقسيمُ المصدر إلى دفعات
#    · quizbuild/weights.py — معايرةُ الأوزان — الترتيبُ من الموديل والتوزيعُ منّا
#    · quizbuild/checks.py — الفحصُ العامّ — على مستويين
#    · quizbuild/english.py — فحصُ الإنجليزية — أقيسُ ما أطلب
#    · quizbuild/models.py — النداء — العميلُ والتوجيهُ وعدّادُ النداءات
#    · quizbuild/repair.py — الإصلاحُ الذاتي — ما أقدر عليه لا أشتريه بنداء
#    · quizbuild/lesson.py — بناءُ درسٍ واحد
#    · quizbuild/quarantine.py — الحَجْرُ والإنقاذ — لا تُتلف بنكاً رفضه مقياسُك
#    · quizbuild/run.py — البناءُ والتقريرُ وسطرُ الأوامر
"""

# ⚠️ **قبل كلِّ استيراد**: هذا الملفُّ يُشغَّل مباشرةً (`python tools/…`)،
#    وحينها لا يكون عضواً في حزمة `tools` فتسقط الاستيراداتُ النسبية.
#    فالجذرُ يُضاف أوّلاً، ثم تُستورد الأجزاءُ بمسارها الكامل.
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

# ── المكتبات والمداخل ──
from tools.quizbuild.boot import (  # noqa: F401,E402
    argparse, asyncio, json, os, re, st, sys, time, Counter, Path, QB,
    get_lessons_book, lessons_units, lessons_in_unit, find_lesson,
    subjects_for, normalize_grade_track, extract_json, repair_escapes,
    serialize_lesson, quiz_spec, _norm_codes, DRAW,
    _is_numeric_substitution, ARABIC_DIGIT_SUBJECTS,
)

# ── الثوابتُ والأنماطُ وحدودُ البنك ──
from tools.quizbuild.consts import (  # noqa: F401,E402
    CHARS_PER_QUESTION, MIN_QUESTIONS, MAX_QUESTIONS, BATCH_TARGET,
    MAX_CALLS_PER_LESSON, _TIMEOUT, _MAX_TOKENS, _MAX_SOURCE, OPENAI_MODEL,
    MATH_SUBJECT, CALC_SUBJECTS, SCI_SUBJECTS, REJECTED_DIR, _LEVEL_FIX, _KIND_BY_LEVEL,
    PERSIAN_DIGITS, WESTERN_DIGITS, BANNED_OPTION, FIGURE_REF, RAW_LATEX,
    APPLIED, _NUMBER, DEFINITION_OPENER, KINDS, EXERCISE_LESSON,
    is_exercise,
)

# ── حجمُ البنك وتقسيمُ المصدر إلى دفعات ──
from tools.quizbuild.sizing import (  # noqa: F401,E402
    bank_size, _PART, batches_for, split_source,
)

# ── معايرةُ الأوزان — الترتيبُ من الموديل والتوزيعُ منّا ──
from tools.quizbuild.weights import (  # noqa: F401,E402
    _HIGH_PARTS, _LOW_PARTS, _PART_HEAD, _WORD, _parts_text, _anchor_bonus,
    _WEIGHT_SHAPE, calibrate_weights,
)

# ── الفحصُ العامّ — على مستويين ──
from tools.quizbuild.checks import (  # noqa: F401,E402
    check_question, _shape_defects, draw_defects, check_batch, _bank_floor,
)

# ── فحصُ الإنجليزية — أقيسُ ما أطلب ──
from tools.quizbuild.english import (  # noqa: F401,E402
    _EN_LATIN, _EN_WORD, _ARABIC_LETTER, _EN_TASK, _EN_DEFINITION,
    _EN_MATERIAL, _is_drill, _EN_PICK, _UNDERLINE_REF, _MARKED_WORD,
    _is_word_drill, english_defects, check_bank,
    _EN_STOP, _material, _content, _rule_words, fresh_stats,
    english_fresh_defects,
)

# ── النداء — العميلُ والتوجيهُ وعدّادُ النداءات ──
from tools.quizbuild.models import (  # noqa: F401,E402
    _CLIENTS, clients, route, CALLS, ask_model,
)

# ── الإصلاحُ الذاتي — ما أقدر عليه لا أشتريه بنداء ──
from tools.quizbuild.repair import (  # noqa: F401,E402
    _PERSIAN_TO_ARABIC, arabize_digits, tidy_question,
)

# ── بناءُ درسٍ واحد ──
from tools.quizbuild.lesson import (  # noqa: F401,E402
    build_lesson,
)

# ── الحَجْرُ والإنقاذ — لا تُتلف بنكاً رفضه مقياسُك ──
from tools.quizbuild.quarantine import (  # noqa: F401,E402
    _rej_file, quarantine, _SALVAGEABLE, salvage_narrow, rescan_all,
    topup_notation, topup_count, retry_rejected, _rejected_entry,
    _unquarantine,
)

# ── البناءُ والتقريرُ وسطرُ الأوامر ──
from tools.quizbuild.run import (  # noqa: F401,E402
    lessons_of, build_subject, build_all, report, main, MINISTRY_MODEL,
)



if __name__ == "__main__":
    asyncio.run(main())
