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
    """برومبتُ كل مادةٍ يخصّها — **بعمودٍ مشترك وعدسةٍ خاصّة** (2026-09-14).

    🔄 **انقلب معنى «مستقل» هنا، وعن قصد.** كانت القاعدة «نصوصٌ منفصلة لا
       مرجعٌ مشترك»، فكان في المشروع أربعةَ عشرَ برومبتاً منسوخاً — وثمانيةٌ
       منها بلا قاعدةِ مصدرٍ ولا متابعةٍ ولا محادثة، لأن الإصلاح كان يصيب
       ملفين ويُخطئ الباقي. فصار العمودُ الفقري مصدراً واحداً
       ([common.teaching_core])، و**الاستقلالُ في العدسة** ([subject_lens]).

    ⚠️ والفحصُ صار على **ترويسة المادة** لا على ورود اسمها في أي موضع:
       نصُّ «التقريب المسموح» يذكر «ولا تاريخاً» في سياق منع الأرقام
       والتواريخ، فكان الفحصُ القديم يراها «تاريخاً» في برومبت الجغرافيا.
    """
    h = importlib.import_module("subjects.history")
    g = importlib.import_module("subjects.geography")
    assert h.prompt_explain() != g.prompt_explain()

    head_h, head_g = h.prompt_explain()[:120], g.prompt_explain()[:120]
    assert "تاريخ" in head_h and "تاريخ" not in head_g
    assert "جغرافيا" in head_g

    from subjects.common import subject_lens
    assert subject_lens("تاريخ") in h.prompt_explain()
    assert subject_lens("تاريخ") not in g.prompt_explain()


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
    # 🧮 **والمنطقُ استُثني (2026-09-22)**: مادّةٌ رياضيةٌ بتباديلَ
    #    وتوافيقَ ومضروب، فأُلحق بديب سيك بأمر المالك «وأيضًا المنطق».
    #    وبنكُه مبنيٌّ بديب سيك منذ ١٧/٩، فكان التوجيهُ الحيُّ يخالفه.
    CALC = {"منطق"}
    for subject in MODULES.values():
        client, model = model_route(subject)
        if subject in CALC:
            assert client == "deepseek", subject
        else:
            assert client == "gemini" and "gemini" in model, subject


def test_all_registered_in_api():
    import api
    for subject in MODULES.values():
        assert subject in api.NEW_SUBJECT_HANDLERS
