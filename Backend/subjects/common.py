# -*- coding: utf-8 -*-
# ══════════════════════════════════════════════════
# 🚪 subjects/common.py — البابُ، لا الغرفة
# ══════════════════════════════════════════════════
#
# ⚖️ **أمرُ المالك (2026-09-20):** «كل مادة/قسم تخليها في ملف لحاله… لأن
#    التعديلَ يصير على نطاقٍ أقلّ، فاللي يحصل خطأ بيحصل على ملفٍ قصير».
#    وسببُه حادثةٌ حقيقية: تعديلٌ بحدودٍ واسعة على ملفٍ من ٩٣٢ سطراً حذف
#    منه ٥٦١ سطراً. وهذا الملفُّ كان **٢٦٩٩ سطراً** — ثلاثةَ أضعافِه.
#
# 🎯 **فصار بابـاً**: الجسدُ كلُّه انتقل إلى [subjects/shared/] — ثلاثةَ عشرَ
#    ملفاً، أطولُها ٥٠٢ سطراً وأكثرُها دون ٢٥٠ — **منقولاً حرفاً بحرف**،
#    وأُثبت النقلُ حسابياً: مجموعُ سطور الأجزاء = سطورُ الأصل بلا فجوةٍ ولا
#    تكرار، ثم قِيست ٧٢٥ نقطةً (كلُّ اسمٍ عامّ · كلُّ برومبتٍ لكل مادة ·
#    كلُّ دالّةِ نصٍّ على عيّنات) فتطابقت بصمتُها قبلَ وبعد.
#
# 🔒 **ولم يتغيّر شيءٌ للمستورد**: `from subjects.common import X` تعمل كما
#    كانت لكلِّ اسم — والعشرون موضعاً التي تستوردُ منه لم تُمسّ.
#
# ⚠️ **وترتيبُ إعادة التصدير هو ترتيبُ سطور الأصل عمداً**: في الأصل اسمانِ
#    معرَّفانِ مرّتين (`fetch_pages_by_numbers` · `NO_MATCH_NOTE`) والأخيرُ
#    يحجب الأوّل. فلو أعدنا التصديرَ بترتيبٍ آخر لانقلب الحاجبُ محجوباً
#    وتغيّر السلوكُ صامتاً. **لا تُعِد ترتيبَ السطور أدناه.**
#
# 📝 **وأين تُعدِّل؟** في ملفِّ الجزء لا هنا:
#    · shared/boot.py — المكتبات والحدود ونموذجُ التضمين
#    · shared/content.py — مواضعُ الكتب وقراءتُها
#    · shared/indexing.py — التقطيعُ والفهرسة
#    · shared/retrieval.py — الترتيبُ الهجين
#    · shared/context.py — سياقُ الكتاب المسلَّم للموديل
#    · shared/guards.py — حرّاسُ المدخل
#    · shared/exams.py — الامتحاناتُ ودروسُ الرياضيات
#    · shared/render_rules.py — قواعدُ الرسّام في البرومبت
#    · shared/rules.py — قواعدُ الجواب المشتركة
#    · shared/lens.py — عدسةُ المادة
#    · shared/prompts.py — برومبتاتُ النظام
#    · shared/pages.py — الصفحاتُ المطلوبة
#    · shared/mathfmt.py — تنسيقُ المخرَج

# ── المكتبات والحدود ونموذجُ التضمين ──
from .shared.boot import (  # noqa: F401
    os, json, re, List, Dict, Any, Tuple, Optional, np, faiss,
    SentenceTransformer, asyncio, hashlib, math, time, BASE_SUBJECTS_DIR,
    QA_TOP_K, EXAMS_BATCH_SIZE, MAX_PAGES_EXPLAIN_SUMMARY, MAX_PAGES_EXAMS,
    UNIT_BATCH_PAGES, RELEVANCE_FLOOR, RELEVANCE_SURE, embed_model,
)

# ── مواضعُ الكتب وقراءتُها ──
from .shared.content import (  # noqa: F401
    USAGE_HELP, _subject_session_timestamps, cleanup_subject_sessions,
    help_for_mode, LESSONS_DIR, UNIT_DIR, _GRADE_DIRS, mode_dir,
    _first_real_json, LEGACY_GRADE, LEGACY_TRACK, _is_legacy_scope,
    subject_book_path, math_branch_dir, subject_exams_dir, load_json_safe,
    find_unit, fetch_pages_by_numbers, extract_all_texts_and_metas,
    threading, index_store, to_frac, _chem_for_subject, prepare_source,
    _build_semaphore, get_build_semaphore, _normalize_for_search,
)

# ── التقطيعُ والفهرسة ──
from .shared.indexing import (  # noqa: F401
    _CHUNK_TOKENS, _CHUNK_OVERLAP_TOKENS, _SENTENCE_SPLIT, _token_len,
    split_for_embedding, _TITLE_TOKENS, page_title, embedding_corpus,
    build_index_sync, get_index, faiss_search,
)

# ── الترتيبُ الهجين ──
from .shared.retrieval import (  # noqa: F401
    _ANAPHORA, _QUERY_STOPWORDS, _COMMON_TERM_RATIO, _KEYWORD_WEIGHT,
    _TERM_TRIM, _PREFIX_AL, query_terms, has_anaphora, _STOP_NORMALIZED,
    _ANAPHORA_NORMALIZED, _CONTINUATION_VERBS, _PRONOUN_TAILS,
    _STYLE_CLAUSE, _is_continuation_word, is_followup, conversation_topic,
    contextual_search_text, search_text_of, term_weights,
    lexical_denominator, _SENTENCE_END, looks_truncated,
    expand_truncated_neighbours, Ranked, _READ_FIRST, WEAK_MATCH_NOTE,
    NO_MATCH_NOTE, has_prior_answer, is_continuation_request, off_topic,
)

# ── سياقُ الكتاب المسلَّم للموديل ──
from .shared.context import (  # noqa: F401
    book_context, hybrid_rank, faiss_scores, enhanced_qa_search,
    normalize_arabic,
)

# ── حرّاسُ المدخل ──
from .shared.guards import (  # noqa: F401
    UNIT_REQUIRED_MESSAGE, unit_missing, unit_required_response,
    QUESTION_REQUIRED_MESSAGE, question_needs_text,
    question_required_response,
)

# ── الامتحاناتُ ودروسُ الرياضيات ──
from .shared.exams import (  # noqa: F401
    extract_keywords, normalize_text_match, normalize_lesson_name,
    parse_exams_input, restrict_book_to_unit,
    collect_exam_questions_by_years, filter_and_rank_exams,
    get_math_exam_years, get_math_exam_lessons, get_math_exam_questions,
    load_math_lesson,
)

# ── قواعدُ الرسّام في البرومبت ──
from .shared.render_rules import (  # noqa: F401
    _ORGANIC_SUBJECTS, _REACTION_SUBJECTS, _NUCLIDE_SUBJECTS,
    fraction_rules, DRAW_CODES, draw_reminder, render_rules,
    organic_structure_rules, _ARABIC_DIGIT_SUBJECTS, arabic_digits_rules,
    reaction_equation_rules,
)

# ── قواعدُ الجواب المشتركة ──
from .shared.rules import (  # noqa: F401
    ANSWER_SHAPE_RULES, CONVERSATION_RULES, FOLLOWUP_RULES,
    CONTINUITY_RULES,
)

# ── عدسةُ المادة ──
from .shared.lens import (  # noqa: F401
    _SUBJECT_LENS, subject_lens, teaching_core, render_rules_once,
    turn_note, _ARABIC_INDIC, _replies_label, SUPPORT_EXAMPLE_RULES,
    source_rules,
)

# ── برومبتاتُ النظام ──
from .shared.prompts import (  # noqa: F401
    qa_core, system_prompt_strict_explain, system_prompt_strict_summary,
    system_prompt_strict_qa, system_prompt_strict_qa_improved,
    system_prompt_strict_exams, system_prompt_math_explain,
)

# ── الصفحاتُ المطلوبة ──
from .shared.pages import (  # noqa: F401
    pages_with_headers, requested_pages, fetch_pages_by_numbers,
    extract_all_texts_and_metas_physics, enhanced_search_physics,
)

# ── تنسيقُ المخرَج ──
from .shared.mathfmt import (  # noqa: F401
    _SUP, _SUP_RE, _superscript, _BRACED, _PSEUDO_FRAC, _LONE_FRAC, _finish,
    format_arabic_math, _LATEX_DELIMS, render_finish, strip_stray_latex,
)

