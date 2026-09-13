"""📄 اختيار الصفحات — بنيةٌ لا أرقامٌ تُلتقط من كلام الطالب.

🔴 **ما طلبه المالك (2026-09-09):** «ماشي داعي إننا نكتب 13 فاصلة 14 فاصلة
   15، خلاص تطلع الصفحات اللي موجودة… أختار صفحة، أسوي لها إضافة».

⚖️ **ولماذا حقلٌ مستقل لا نصّ؟** استخراجُ الأرقام من كلام الطالب يخلط النيّة
   بالمحتوى: «اشرح قانون نيوتن 2» طلبُ قانونٍ لا صفحة، ومن اختار صفحةً ثم
   سأل سؤالاً تبعياً بلا رقمٍ فَقَد صفحته. والحقل المستقل يبقى مع المحادثة.
"""
import pytest

from core import pages_mode
from core.capabilities import describe
from models import AskRequest
from subjects.common import requested_pages


def _req(**kw):
    base = dict(subject="احياء", mode="شرح", input_type="صفحة",
                content="اشرح لي", grade=3, track="علمي", content_mode="pages")
    base.update(kw)
    return AskRequest(**base)


# ══════════════════════════════════════════════════
# 🔀 مصدرُ الأرقام
# ══════════════════════════════════════════════════

def test_structured_choice_wins_over_digits_in_the_text():
    """⭐ الجوهر: رقمٌ عابر في السؤال لا يزاحم اختياراً صريحاً."""
    r = _req(content="اشرح لي قانون نيوتن 2 من فضلك", selected_pages=[41, 42])
    assert requested_pages(r) == [41, 42]


def test_typed_digits_still_work_for_older_clients():
    """⚠️ الحذفُ كان سيكسر كل تطبيقٍ لم يُحدَّث بعد."""
    assert requested_pages(_req(content="اشرح الصفحات 13، 14")) == [13, 14]


def test_duplicates_are_dropped_but_nothing_is_silently_cut():
    """⚠️ القصُّ الصامت يبتلع رسالة «الصفحات زائدة» فيضيع الشرح بلا سبب."""
    r = _req(selected_pages=[41, 41, 42, 43, 44, 45])
    assert r.selected_pages == [41, 42, 43, 44, 45]


def test_impossible_page_numbers_are_refused():
    assert _req(selected_pages=[-1, 0, 99999]).selected_pages is None


# ══════════════════════════════════════════════════
# 💬 الرسائل التي طلبها المالك بنصّها
# ══════════════════════════════════════════════════

def _answer(req):
    import asyncio
    return asyncio.run(pages_mode.handle(req, {"gemini": None}))["answer"]


def test_no_pages_selected_says_so_plainly():
    """🔴 «إذا ما اخترت صفحات يقول له والله شوفك غلطان ما اخترت شي صفحات»."""
    out = _answer(_req(content="اشرح لي"))
    assert "لم تختر أي صفحة" in out
    assert "إعدادات الجلسة" in out          # ويدلّه على مكان الاختيار


def test_too_many_pages_says_it_is_over_the_limit():
    """🔴 «لو زاد أكثر من ثلاث صفحات خلاص يقول له الصفحات زايدة»."""
    out = _answer(_req(selected_pages=[41, 42, 43, 44]))
    assert "زائدة" in out and "٣" in out.replace("3", "٣")


def test_unknown_pages_name_the_scope_searched():
    """⚠️ «الصفحات غير موجودة» وحدها لا تُرشد: في الوحدة أم في المنهج كلّه؟"""
    out = _answer(_req(selected_pages=[9001], unit_name="التكاثر"))
    assert "التكاثر" in out


# ══════════════════════════════════════════════════
# 📋 القائمة تصل مع القدرات — بلا رحلةٍ ثانية
# ══════════════════════════════════════════════════

def test_capabilities_carry_the_page_numbers():
    pages = describe(3, "علمي", "احياء")["pages"]
    assert pages["available"] and pages["units"]
    for unit in pages["units"]:
        assert pages["unit_pages"][unit] == sorted(set(pages["unit_pages"][unit]))
    assert pages["max_selectable"] == 3


def test_non_numeric_pages_are_not_offered():
    """🛡️ في فيزياء الثاني صفحةٌ اسمها «غلاف» — بياناتٌ صحيحة، لكن عرضَها
    في المُنتقي يعطي الطالب زراً لا يجلب شيئاً."""
    pages = describe(2, "علمي", "فيزياء")["pages"]
    for nums in pages["unit_pages"].values():
        assert all(isinstance(n, int) for n in nums)


def test_math_offers_no_pages_at_all():
    """📐 الرياضيات وضعُ دروسٍ بطبيعتها (قرار المالك) — فلا مُنتقي لها."""
    assert describe(3, "علمي", "رياضيات")["pages"]["available"] is False


# ══════════════════════════════════════════════════
# 🧬 الشقيق الذي كاد يُنسى
# ══════════════════════════════════════════════════

def test_no_subject_parses_page_numbers_on_its_own():
    """🔴 **الأحياء كان لها مسارُ صفحاتٍ مستقل** — وهي أكثر المواد استعمالاً
    لوضع الوحدات. فلو وُصل الاختيار المُبنيَن بـ`pages_mode` وحده لظلّ
    المُنتقي بلا أثرٍ فيها، ولبدا العطل «عشوائياً» حسب المادة.

    ⚖️ وحارسٌ بنيويّ أصدقُ من اختبارٍ لمادةٍ واحدة: يمنع المسار الرابع
       يوم يُكتب ([sweep-siblings-before-reporting]).
    """
    import ast
    import pathlib
    root = pathlib.Path(__file__).resolve().parent.parent
    offenders = []
    for path in list((root / "subjects").glob("*.py")) + list((root / "core").glob("*.py")):
        src = path.read_text(encoding="utf-8")
        if "page_source" not in src:
            continue
        tree = ast.parse(src)
        for node in ast.walk(tree):
            if not isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                continue
            if node.name == "requested_pages":
                continue                      # 🏠 الموطن الشرعيّ الوحيد
            body = ast.get_source_segment(src, node) or ""
            if "page_source" in body and "findall" in body:
                offenders.append(f"{path.name}:{node.lineno} · {node.name}()")
    assert not offenders, "استخراجٌ محليّ للصفحات بدل `requested_pages`:\n  " + \
                          "\n  ".join(offenders)


# ══════════════════════════════════════════════════
# 🚦 لا يختلط وضعٌ بوضع — ولو أرسل العميل الاثنين
# ══════════════════════════════════════════════════

def test_lessons_mode_ignores_selected_pages():
    """🔴 **شكوى المالك:** «لو أرسلت بترسل الصفحات وبيرسل الدرس».

    ⚖️ أُصلح في التطبيق ببوّابةٍ واحدة، **ويُحرس هنا أيضاً**: عميلٌ قديم لم
       يُحدَّث، أو طلبٌ مُلفَّق، قد يحمل الحقلين معاً. والخادم لا يبني على
       حسن نيّة العميل.
    """
    import asyncio

    from core import lesson_mode

    req = AskRequest(
        subject="احياء", mode="شرح", input_type="صفحة", content="اشرح",
        grade=3, track="علمي", content_mode="lessons",
        unit_name="الجهاز العصبي", lesson_name="لا وجود له",
        selected_pages=[9, 11],
    )
    out = asyncio.run(lesson_mode.handle(req, {"gemini": None}))
    refs = " ".join(out.get("references") or [])
    assert "ص 9" not in refs and "ص 11" not in refs, \
        "وضعُ الدروس أرجع مراجعَ صفحات — اختلط الوضعان"


def test_pages_are_only_read_where_pages_are_served():
    """🛡️ حارسٌ بنيويّ: لا يقرأ `selected_pages` إلا معالجُ الصفحات."""
    import ast
    import pathlib

    root = pathlib.Path(__file__).resolve().parent.parent
    readers = []
    for path in list((root / "subjects").glob("*.py")) + \
               list((root / "core").glob("*.py")):
        src = path.read_text(encoding="utf-8")
        if "selected_pages" not in src:
            continue
        for node in ast.walk(ast.parse(src)):
            if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)):
                body = ast.get_source_segment(src, node) or ""
                if "selected_pages" in body:
                    readers.append(f"{path.name}:{node.name}")
    assert readers == ["common.py:requested_pages"], \
        f"قرّاءٌ غير متوقّعين للصفحات: {readers}"
