# -*- coding: utf-8 -*-
# ══════════════════════════════════════════════════
# 📏 «ملفٌّ قصير» — قاعدةُ المالك، مكتوبةً بحيث تُخالَف فيسقط الاختبار
# ══════════════════════════════════════════════════
#
# ⚖️ **أمرُ المالك (2026-09-20):** «خلي كل قسمٍ في ملفٍ لحاله… بيكون التعديل
#    على نطاقٍ أقلّ، فاللي يحصل خطأ بيحصل على ملفٍ قصير».
#
# 🔴 **وسببُه حادثةٌ وقعت**: تعديلٌ بحدودٍ واسعة على [masar_markdown.dart]
#    (٩٣٢ سطراً) حذف منه ٥٦١ سطراً. والدرسُ ليس «كن حذراً» — فالحذرُ لا
#    يُقاس — بل **اجعل أكبرَ ما يمكن أن يُتلفه خطأٌ واحدٌ صغيراً**.
#
# 🎯 وهذا الاختبارُ **سقّاطة**: الملفُّ الجديد لا يتجاوز الميزانية، والملفُّ
#    الكبيرُ الموروث **لا يكبر** — يُسمح له بحجمه اليوم ولا شيءَ فوقه.
#    ⛔ **ورفعُ رقمٍ في السجلّ يحتاج سبباً مكتوباً بجانبه.** بلا ذلك تصير
#       القاعدةُ زينةً: كلُّ من ضاق بها رفع الرقم. وقد عملت فعلاً يومَ
#       كُتبت — ردّتني إلى `api.py` فنقلتُ منه أربعةَ عشرَ سطرَ تعليلٍ إلى
#       الوحدة التي تملك القرار، وهو موضعُها الصحيح أصلاً.

import pathlib

import pytest

_ROOT = pathlib.Path(__file__).resolve().parent.parent

# 📏 ميزانيةُ الملفّ الجديد — فوقها يُفكَّك
BUDGET = 600

# 🧾 **السجلّ**: ملفّاتٌ وُلدت كبيرةً قبل القاعدة. الرقمُ سقفُها لا هدفُها.
#    (قِيست 2026-09-20 بعد تفكيك `common` و`build_quizzes` و`build_explanations`
#     من ٢٦٩٩ و١٣٥٠ و١٠١٩ سطراً إلى ٥١٦ و٣١٢ و٣٩١ كحدٍّ أقصى.)
LEDGER = {
    # 🔻 **٢٤٢٨ ⇐ ٨٢١** (2026-09-20): فُكّك إلى [apiparts/] بأمر المالك،
    #    وبقي فيه **الجوهرُ المترابط وحده** — العملاءُ والتوجيهُ و`/ask`:
    #    أسماءٌ تُرقّعها الاختباراتُ من خارجها، ونقلُها كان يقطع الترقيع
    #    بصمت. والبرهان: ٨٣ مساراً بترتيبها وبصمةُ OpenAPI نفسُها.
    "subjects/math.py": 915,
    "core/chem.py": 892,
    "api.py": 821,
    "core/scholarships.py": 730,
    "subjects/english.py": 636,
    "core/fractions.py": 602,
}

# 🙈 ما لا يُقاس: البيئةُ الافتراضية والمولَّد والاختباراتُ نفسُها
_SKIP = ("/.venv/", "/__pycache__/", "/tests/", "/build/", "/node_modules/")


def _sources():
    for path in sorted(_ROOT.rglob("*.py")):
        rel = str(path.relative_to(_ROOT))
        if any(s.strip("/") in path.parts for s in ("venv", ".venv",
                                                    "__pycache__", "tests")):
            continue
        yield rel, len(path.read_text(encoding="utf-8").splitlines())


def test_no_new_file_exceeds_the_budget():
    """🆕 ملفٌّ جديدٌ فوق الميزانية = قسمٌ لم يُفصل."""
    fat = [(rel, n) for rel, n in _sources()
           if n > BUDGET and rel not in LEDGER]
    assert not fat, (
        f"ملفّاتٌ تتجاوز {BUDGET} سطراً وليست في السجلّ — فكّكها، "
        f"ولا ترفع الميزانية:\n  " +
        "\n  ".join(f"{rel}: {n} سطراً" for rel, n in fat))


def test_ledgered_files_never_grow():
    """🔒 السقّاطة: الكبيرُ الموروث لا يكبر — والاتجاهُ واحد."""
    sizes = dict(_sources())
    grown = [(rel, cap, sizes[rel]) for rel, cap in LEDGER.items()
             if rel in sizes and sizes[rel] > cap]
    assert not grown, (
        "ملفٌّ في السجلّ كبر — أضِف الجديدَ في ملفٍّ مستقلّ لا فيه:\n  " +
        "\n  ".join(f"{rel}: {cap} ⇐ {now}" for rel, cap, now in grown))


def test_ledger_has_no_ghosts():
    """👻 اسمٌ في السجلّ لا ملفَّ له = سجلٌّ يكذب."""
    sizes = dict(_sources())
    missing = sorted(set(LEDGER) - set(sizes))
    assert not missing, f"أسماءٌ في السجلّ بلا ملفّات: {missing}"


# ══════════════════════════════════════════════════
# 🚪 والبابُ يفتح على كلِّ الغرف
# ══════════════════════════════════════════════════
#
# ⚠️ **الفخُّ الذي يحرسه**: جزءٌ جديد يُضاف إلى `shared/` أو `quizbuild/` ثم
#    يُنسى في واجهته ⇒ `from subjects.common import X` تسقط عند أوّل
#    مستوردٍ في الإنتاج لا عندنا. وقد وقع فعلاً يومَ التفكيك: اسمان
#    (`LEGACY_GRADE` · `LEGACY_TRACK`) معرَّفان بإسنادِ صفٍّ
#    (`A, B = 3, "علمي"`) سقطا من أوّل توليدٍ للواجهة — أمسكهما القياسُ
#    لا العين.

import ast   # noqa: E402


def _top_names(path: pathlib.Path):
    out = []
    for nd in ast.parse(path.read_text(encoding="utf-8")).body:
        if isinstance(nd, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            out.append(nd.name)
        elif isinstance(nd, ast.Assign):
            for t in nd.targets:                 # وإسنادُ الصفِّ منها
                out += [l.id for l in ast.walk(t) if isinstance(l, ast.Name)]
    return out


@pytest.mark.parametrize("facade, pkg", [
    ("subjects.common", "subjects/shared"),
    ("tools.build_quizzes", "tools/quizbuild"),
    ("tools.build_explanations", "tools/explbuild"),
])
def test_every_part_name_is_reachable_from_its_door(facade, pkg):
    """🚪 كلُّ اسمٍ في أيِّ جزءٍ يُرى من الواجهة — وإلا فالبابُ ناقص."""
    import importlib
    door = importlib.import_module(facade)
    missing = []
    for part in sorted((_ROOT / pkg).glob("*.py")):
        if part.name == "__init__.py":
            continue
        for name in _top_names(part):
            if not hasattr(door, name):
                missing.append(f"{part.name}:{name}")
    assert not missing, f"أسماءٌ لا يراها {facade}: {missing}"


# ══════════════════════════════════════════════════
# 🛣️ وجدولُ المسارات عقدٌ لا يُنقض
# ══════════════════════════════════════════════════
#
# ⚖️ تفكيكُ `api.py` نقل مساراتٍ إلى ملفّاتٍ أخرى، و**ترتيبُ التسجيل معنىً
#    لا شكل**: مسارٌ متداخلٌ يُطابَق بالأسبقية. فاستيرادُ جزءٍ في غير موضعه
#    يغيّر التوجيهَ بلا خطأٍ ولا تحذير.

def test_every_api_part_is_reached_from_the_door():
    """📦 جزءٌ لا تستورده الواجهةُ = مساراتٌ لا تُسجَّل أبداً."""
    door = (_ROOT / "api.py").read_text(encoding="utf-8")
    for part in sorted((_ROOT / "apiparts").glob("*.py")):
        if part.stem == "__init__":
            continue
        assert f"from apiparts.{part.stem} import" in door, \
            f"جزءٌ منسيّ لا يصله أحد: apiparts/{part.stem}.py"


def test_the_route_table_is_whole():
    """🛣️ كلُّ مسارٍ مسجَّلٌ ومعالجُه موصول — وعددُه لا يتغيّر صدفةً."""
    import api
    paths = {r.path for r in api.app.routes}
    for must in ("/ask", "/ask/stream", "/quiz/generate", "/lesson/explanation",
                 "/scholarships", "/scholarships/{sch_id}", "/scholarship/ask",
                 "/scholarship/ask/stream", "/teacher/ask", "/admin", "/ingest",
                 "/me/quota", "/app/version", "/banners", "/admin/overview"):
        assert must in paths, f"مسارٌ ضاع في التفكيك: {must}"
    assert len(api.app.routes) == 83, (
        f"تغيّر عددُ المسارات: {len(api.app.routes)} — إن كانت إضافةً مقصودةً "
        "فحدّث الرقم، وإلا فجزءٌ لم يُستورد أو استُورد مرّتين")
