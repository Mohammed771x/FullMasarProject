from core.curriculum import normalize_grade_track, is_valid_subject, subjects_for, model_route

def test_grade1_forces_common_track():
    assert normalize_grade_track(1, "علمي") == (1, "عام")
    assert normalize_grade_track(1, None) == (1, "عام")

def test_invalid_inputs_fall_back_safely():
    assert normalize_grade_track("خبيث", "../../etc") == (3, "علمي")
    assert normalize_grade_track(99, "أدبي") == (3, "أدبي")

def test_subject_whitelist():
    assert is_valid_subject(3, "علمي", "احياء")
    assert not is_valid_subject(3, "علمي", "../../../etc/passwd")
    assert not is_valid_subject(3, "علمي", "تاريخ")          # تاريخ ليست في الثالث العلمي
    assert is_valid_subject(3, "أدبي", "تاريخ")

def test_owner_subject_lists():
    assert len(subjects_for(1, "عام")) == 9
    assert "علم الاقتصاد" in subjects_for(2, "أدبي")
    assert "مبادئ علم الخرائط" in subjects_for(3, "أدبي")
    # الفلسفة والمنطق مادتان منفصلتان بقرار المالك — لا مادة واحدة مركّبة
    assert "فلسفة" in subjects_for(3, "أدبي")
    assert "منطق" in subjects_for(3, "أدبي")

def test_model_routing():
    # 🧪 الفيزياءُ والكيمياءُ والرياضيات ⇐ موديلٌ **مفكّر** (2026-09-22):
    #    قياسٌ على عشرين مسألةً محسوبةٍ باليد بثلاث إعادات أعطى
    #    `deepseek-flash` ١٠٠٪ و`gpt-4o-mini` ٦٢٪ في الفيزياء و٢٠٪ في
    #    الرياضيات — والإخفاقاتُ تكرّرت بعينها، فهي قدرةٌ لا صدفة.
    assert model_route("فيزياء") == ("deepseek", "deepseek-flash")
    assert model_route("كيمياء") == ("deepseek", "deepseek-flash")
    assert model_route("رياضيات") == ("deepseek", "deepseek-flash")
    assert model_route("تاريخ") == ("gemini", "gemini-3.1-flash-lite")  # الافتراضي للمواد الجديدة


# ══════ شدّةُ التفكير تتبع الغرض ══════
#
# 🔴 **علّةُ المالك (2026-09-22):** «قلت له ممكن توضح موضوع الحرارة أكثر…
#    ووقف عند في النص… أنا ما بغيته reasoning». والشرحُ كان يُقطع فعلاً
#    (`finish_reason="length"`) لأن التفكيرَ يلتهم السقف.
#
# 📏 وقِيس: نقاشاً بلا تفكيرٍ ٨٫٥ث بلا قطع، وبأدنى تفكيرٍ ٢٠ث ومع قطع.
#    وحساباً بلا تفكيرٍ ٩٠٪، وبأدنى تفكيرٍ ١٠٠٪ بفارق ٠٫٦ ثانية.

def test_chat_does_not_think_but_calculation_does():
    from core.curriculum import reasoning_kwargs
    assert reasoning_kwargs("deepseek-flash", "chat") == {"reasoning_effort": "none"}
    assert reasoning_kwargs("deepseek-flash", "quiz") == {"reasoning_effort": "minimal"}
    # ومن لا يفكّر أصلاً لا يُرسَل له وسيطٌ لا يفهمه
    assert reasoning_kwargs("gemini-3.1-flash-lite", "chat") == {}
    assert reasoning_kwargs("gpt-4o-mini", "quiz") == {}


def test_chat_keeps_a_short_leash_while_calculation_gets_room():
    """⏱️ مهلةُ ٢٤٠ث على مسار الشرح تعني أن الطالبَ ينتظر أربعَ دقائق
    قبل أن يرى خطأً — ولا يحتاج أكثر من عشرٍ وقد أُطفئ تفكيرُه."""
    from core.curriculum import call_budget
    assert call_budget("deepseek-flash", 4000, 60, "chat") == (4000, 60)
    cap, wait = call_budget("deepseek-flash", 4000, 60, "quiz")
    assert cap >= 12000 and wait >= 240


def test_math_carries_its_thinking_kwargs_to_every_call():
    """🧮 الرياضياتُ تحسب — فتفكّر ولو قليلاً، وفي **كلّ** مواضع ندائها."""
    import pathlib
    from subjects.math import MATH_THINK, MATH_MODEL
    from core.curriculum import is_thinking_model
    if is_thinking_model(MATH_MODEL):
        # 🧮 عاديٌّ كالفيزياء والكيمياء — والزرُّ وحدَه يشعل التفكير
        assert MATH_THINK() == {"reasoning_effort": "none"}
        class _Req:
            thinking = True
        assert MATH_THINK(_Req()) == {"reasoning_effort": "minimal"}
    src = (pathlib.Path(__file__).resolve().parent.parent
           / "subjects" / "math.py").read_text(encoding="utf-8")
    calls = src.count("model=MATH_MODEL")
    wired = (src.count("model=MATH_MODEL, **MATH_THINK(req),")
             + src.count("model=MATH_MODEL, **MATH_THINK(),"))
    assert calls and wired == calls, "موضعُ نداءٍ بلا ضبطِ تفكير"


# ══════ لا اسمَ موديلٍ بخطّ اليد في معالجِ مادة ══════
#
# ☢️ **العطبُ الذي أوجبه (2026-09-22):** حُوّلت الفيزياءُ والكيمياءُ في
#    `MODEL_ROUTING` إلى `deepseek-flash`، ومرّت ٢٤٥٠ اختباراً، وبدا
#    التحويلُ ناجحاً — **ولم يصل الطالبَ**. لأن [subjects/physics.py]
#    و[subjects/chemistry.py] كانا يكتبان `model="gpt-4o-mini"` في ستّة
#    مواضعَ بخطّ اليد، فلا يقرآن الجدولَ أصلاً.
#
# 🎯 وهذا اختبارُ **الطبقة** لا الحالة: أيُّ معالجٍ يكتب اسمَ موديلٍ يسقط،
#    فلا يعود تحويلُ الجدول يكذب على من يقرؤه.

def test_no_subject_handler_hardcodes_a_model_name():
    import pathlib, re
    root = pathlib.Path(__file__).resolve().parent.parent
    # 🎛️ موادُّ ديب سيك — هي التي وقع فيها العطبُ وهي التي تُحرس أولاً.
    #    (جيميناي في [arabic.py] و[biology.py] دَينٌ قديمٌ معلومٌ، يُدرج
    #     هنا يوم يُسدَّد كي لا يتحوّل الحارسُ إلى ضجيجٍ يُتجاهل.)
    guarded = ["subjects/physics.py", "subjects/chemistry.py",
               "subjects/math.py", "subjects/logic.py"]
    pat = re.compile(r'model\s*=\s*["\'](gpt-|gemini-|deepseek-|o[1-9])')
    offenders = []
    for rel in guarded:
        src = (root / rel).read_text(encoding="utf-8")
        for i, line in enumerate(src.splitlines(), 1):
            if pat.search(line):
                offenders.append(f"{rel}:{i}  {line.strip()[:70]}")
    assert not offenders, (
        "اسمُ موديلٍ مكتوبٌ بيدٍ — استعمل [curriculum.subject_call]:\n  "
        + "\n  ".join(offenders))


def test_deepseek_subjects_are_exactly_the_ones_with_a_thinking_button():
    """🧠 «التفكير يظهر بس في الشاتس اللي فيها DPC» — أمرُ المالك حرفياً."""
    from core.curriculum import (MODEL_ROUTING, subject_supports_thinking,
                                 model_route)
    for subject, (key, _m) in MODEL_ROUTING.items():
        assert subject_supports_thinking(subject) == (key == "deepseek"), subject
    for s in ("فيزياء", "كيمياء", "رياضيات", "منطق"):
        assert model_route(s)[0] == "deepseek", s
        assert subject_supports_thinking(s), s
    for s in ("احياء", "عربي", "تاريخ", "جغرافيا"):
        assert not subject_supports_thinking(s), s
