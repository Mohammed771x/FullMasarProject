#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""🚪 مولِّدُ شروح الدروس — البابُ، لا الغرفة.

⚖️ **أمرُ المالك (2026-09-20):** «موضوع الدروس… خلي كل قسمٍ في ملفٍ لحاله،
   فالتعديلُ على نطاقٍ أقلّ، واللي يحصل خطأ بيحصل على ملفٍ قصير».

   وكان هذا الملفُّ **١٠١٩ سطراً**. صار الجسدُ في [tools/explbuild/] خمسةَ
   ملفات — **منقولاً حرفاً بحرف** بلا تغيير سطرٍ واحد، وبرهانُ النقل
   حسابيّ: مجموعُ سطور الأجزاء = سطورُ الأصل بلا فجوةٍ ولا تكرار.

🔒 ولم يتغيّر شيءٌ للمستعمِل: سطرُ الأوامر كما هو، و`from
   tools.build_explanations import X` تعمل لكلِّ اسمٍ كما كانت.

📝 **وأين تُعدِّل؟** في ملفِّ الجزء لا هنا:
#    · explbuild/boot.py — المكتبات والمداخل
#    · explbuild/consts.py — الثوابتُ والأنماطُ وسقوفُ الطول
#    · explbuild/verify.py — الفحص — ما لا يجتازه لا يُخزَّن
#    · explbuild/generate.py — التوليدُ وكتابةُ الحَجْر
#    · explbuild/rescue.py — الإنقاذُ وإعادةُ المسح وسطرُ الأوامر
"""

# ⚠️ **قبل كلِّ استيراد**: هذا الملفُّ يُشغَّل مباشرةً، وحينها لا يكون عضواً
#    في حزمة `tools` فتسقط الاستيراداتُ النسبية. فالجذرُ يُضاف أوّلاً.
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

# ── المكتبات والمداخل ──
from tools.explbuild.boot import (  # noqa: F401,E402
    argparse, asyncio, json, os, re, sys, time, Path, api, AskRequest, LC,
    LM, get_lessons_book, SUBJECTS_BY_GRADE_TRACK, model_route,
    serialize_lesson, TA,
)

# ── الثوابتُ والأنماطُ وسقوفُ الطول ──
from tools.explbuild.consts import (  # noqa: F401,E402
    BUILD_MAX_TOKENS, BUILD_MODEL, HINT_CODES, ASK, _ARG, DRAW, RAW_LATEX,
    AR_WORD, LATIN, ARABIC_DIGIT_SUBJECTS, BAD_OPENER, EXERCISE_LESSON,
    WESTERN_DIGITS, BRIDGE,
)

# ── الفحص — ما لا يجتازه لا يُخزَّن ──
from tools.explbuild.verify import (  # noqa: F401,E402
    _TEX_CMD, _without_codes, _NUMERIC_PART, _NUM_TOKEN,
    _is_numeric_substitution, _numbers_present, _SQRT_TEX, _SUP_TEX,
    _SUB_TEX, _SUPERSCRIPT, _SUBSCRIPT, _DIGITS_UNIFY, _norm_codes,
    _ANY_DIGIT, _NOT_A_SECTION, part_names, _bridged, _covered, verify,
)

# ── التوليدُ وكتابةُ الحَجْر ──
from tools.explbuild.generate import (  # noqa: F401,E402
    _install_build_prompt, _RULE_LINE, _BOLD_ONLY_LINE, _LEAKED_LABEL,
    _LABEL_ONLY, _tidy, codes_hint, explain, lessons_of, _one,
    build_subject, _reroute_math, REJECTED_DIR, _rej_file, quarantine,
)

# ── الإنقاذُ وإعادةُ المسح وسطرُ الأوامر ──
from tools.explbuild.rescue import (  # noqa: F401,E402
    _MARKER_ONLY, salvage_marker_only, rescan_all, retidy_all, main,
)



if __name__ == "__main__":
    asyncio.run(main())
