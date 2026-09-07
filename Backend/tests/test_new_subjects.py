"""اختبارات المواد الجديدة — كل مادة لها ملف معالج مستقل ببرومبتاته."""
import importlib
import pytest

MODULES = {
    "history": "تاريخ",
    "geography": "جغرافيا",
    "society": "مجتمع",
    "economics": "علم الاقتصاد",
    "sociology": "علم الاجتماع",
    "philosophy": "فلسفة",
    "logic": "منطق",
    "cartography": "مبادئ علم الخرائط",
}


@pytest.mark.parametrize("module,subject", MODULES.items())
def test_module_exists_and_names_match(module, subject):
    m = importlib.import_module(f"subjects.{module}")
    assert m.SUBJECT == subject
    assert callable(getattr(m, f"handle_{module}_request"))


@pytest.mark.parametrize("module,subject", MODULES.items())
def test_each_has_own_three_prompts(module, subject):
    m = importlib.import_module(f"subjects.{module}")
    explain, summary, qa = m.prompt_explain(), m.prompt_summary(3), m.prompt_qa()
    for p in (explain, summary, qa):
        assert isinstance(p, str) and len(p) > 50
        assert subject in p, f"اسم المادة يجب أن يظهر في برومبت {module}"


def test_prompts_are_independent_per_subject():
    """تعديل برومبت مادة لا يؤثر على غيرها (نصوص منفصلة لا مرجع مشترك)."""
    h = importlib.import_module("subjects.history")
    g = importlib.import_module("subjects.geography")
    assert h.prompt_explain() != g.prompt_explain()
    assert "تاريخ" in h.prompt_explain() and "تاريخ" not in g.prompt_explain()


def test_explain_prompt_mirrors_biology_structure():
    """البرومبت منسوخ من الأحياء: نفس العلامات المميزة."""
    m = importlib.import_module("subjects.history")
    p = m.prompt_explain()
    for marker in ["آلية التفكير", "ذكاء المحادثة", "أسلوب الشرح", "هدفك"]:
        assert marker in p


def test_summary_levels_differ():
    m = importlib.import_module("subjects.history")
    assert m.prompt_summary(1) != m.prompt_summary(5)
    assert "مفصل جداً" in m.prompt_summary(1)
    assert "مختصر جداً" in m.prompt_summary(5)


def test_model_routing_for_new_subjects():
    from core.curriculum import model_route
    for subject in MODULES.values():
        client, model = model_route(subject)
        assert client == "gemini" and "gemini" in model


def test_all_registered_in_api():
    import api
    for subject in MODULES.values():
        assert subject in api.NEW_SUBJECT_HANDLERS
