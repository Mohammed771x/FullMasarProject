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
