"""📐 كل درس رياضيات — كما يراه الطالب على الشاشة.

🔴 **لماذا على الدروس لا على جواب الموديل؟** الحارس السابق
   ([test_latex_guard]) يفحص مخرجاتٍ حيّة من الموديل، وهي عيّنةٌ تتغيّر.
   أمّا ملفّات الدروس فهي **المصدر**: منها يقرأ الطالب في «وضع الوحدات»،
   ومنها ينقل الموديل حرفياً في «ابدأ الشرح الذكي». فما فسد فيها يظهر
   في المسارين معاً.

📊 وكشفَ هذا المسح ما لم تكشفه العيّنة (2026-09-09):
   • «]-∞، ٢[ U ]٢، ∞[» — حرفٌ لاتيني مكان رمز الاتحاد ∪ (٥ مواضع)
   • «(ق o د)» — التركيب بحرف o (٦ مواضع)
   • «14(ن-2)(ن-3)(n-4)» و«١ / x²» — رمزان لاتينيان وسط معادلةٍ عربية
   • «جا \\frac{س}{س}» — اسم الدالّة **خارج** الكسر ووسيطُه داخله (٤٦ موضعاً)

⚠️ والمسح شاملٌ عمداً: عيّنةُ درسٍ واحد لا تكفي حكماً على ٦٤
   ([sweep-siblings-before-reporting]).
"""
import os
import re

import pytest

from subjects.common import LESSONS_DIR, load_json_safe, mode_dir
from subjects.math import format_lesson_safely
from core.latex_guard import audit

_GRADES = [(1, "عام"), (2, "علمي"), (2, "أدبي"), (3, "علمي"), (3, "أدبي")]


def _lessons():
    seen, out = set(), []
    for grade, track in _GRADES:
        root = mode_dir("رياضيات", LESSONS_DIR, grade, track)
        if not os.path.isdir(root):
            continue
        for branch in sorted(os.listdir(root)):
            bdir = os.path.join(root, branch)
            if not os.path.isdir(bdir):
                continue
            for name in sorted(os.listdir(bdir)):
                path = os.path.join(bdir, name)
                if name.startswith((".", "_")) or not os.path.isfile(path) \
                        or path in seen:
                    continue
                seen.add(path)
                data = load_json_safe(path)
                if isinstance(data, dict):
                    out.append((f"{branch}/{name}", data))
    return out


_LESSONS = _lessons()

# 📖 مصطلحاتٌ إنجليزية **في نصّ الكتاب نفسه** بين قوسين — تبقى عمداً،
#    كما في [test_latex_guard]: «(Hyperbola)» و«(Factorial)» تظهر في
#    الامتحانات والمراجع، وحذفُها إتلافٌ للمحتوى لا تنظيف.
_BOOK_TERMS = {"hyperbola", "parabola", "ellipse", "factorial",
               "dummy", "variable"}


def test_the_sweep_actually_covers_the_curriculum():
    """🛡️ حارسُ الحارس: مسحٌ على قائمةٍ فارغة يمرّ وهو لا يفحص شيئاً."""
    assert len(_LESSONS) >= 60, f"لم يُقرأ إلا {len(_LESSONS)} درساً"


@pytest.mark.parametrize("name,data", _LESSONS, ids=[n for n, _ in _LESSONS])
def test_no_english_reaches_the_student(name, data):
    """⭐ **قرار المالك:** «ما أبغى ولا واحد بالمية يطلع كلام إنجليزي»."""
    # ⚠️ ترميزُ الرسّام ليس «لاتينياً شارداً»: `\\frac` و`\\fact` أسماءُ
    #    أوامرٍ يرسمها التطبيق ولا يراها الطالب — راجع [core/latex_guard.KEPT].
    body = re.sub(r"\\(frac|sqrt|chem|ring|fact)", "",
                  format_lesson_safely(data))
    stray = [w for w in re.findall(r"[A-Za-z]+", body)
             if w.lower() not in _BOOK_TERMS]
    assert not stray, f"لاتينيّ شارد: {stray[:8]}"


@pytest.mark.parametrize("name,data", _LESSONS, ids=[n for n, _ in _LESSONS])
def test_no_latex_command_reaches_the_student(name, data):
    left = audit(format_lesson_safely(data))
    assert not left, f"أوامر ناجية: {sorted(set(left))[:6]}"


@pytest.mark.parametrize("name,data", _LESSONS, ids=[n for n, _ in _LESSONS])
def test_no_malformed_fraction(name, data):
    """💔 كسرٌ فارغ أو بسطُه شرطة — تلفٌ **مرئيّ** على الشاشة."""
    text = format_lesson_safely(data)
    bad = re.findall(r"\\frac\{\s*\}|\\frac\{[^}]*\}\{\s*\}|\\frac\{\s*/", text)
    assert not bad, f"كسورٌ مشوّهة: {bad[:4]}"


@pytest.mark.parametrize("name,data", _LESSONS, ids=[n for n, _ in _LESSONS])
def test_no_name_is_torn_off_its_fraction(name, data):
    """🔴 **٤٦ موضعاً** كان اسم الدالّة يبقى خارج الكسر ووسيطُه داخله:
    «جا \\frac{س}{س}» بدل «\\frac{جا س}{س}» — أي جا(س/س)=جا(١) وهي
    **قيمةٌ أخرى**، لا خطأً شكلياً. وهذا أخطر ما كشفه المسح.
    """
    glued = re.findall(r"[\u0600-\u06FF]\\frac", format_lesson_safely(data))
    assert not glued, f"اسمٌ ملتصقٌ بكسر: {len(glued)} موضعاً"


def test_the_curriculum_is_mostly_drawn_not_slashed():
    """📊 مقياسٌ إجمالي: الكسور المرسومة تفوق الشرطات الباقية بأضعاف.

    ⚠️ والشرطات الباقية ليست عيباً بالضرورة — «الأفقية/المائلة» نثرٌ
       بمعنى «أو»، و«ل1 // ل2» توازٍ. فالحدّ رقابيٌّ لا صفريّ.
    """
    drawn = slashes = 0
    for _, data in _LESSONS:
        text = format_lesson_safely(data)
        drawn += text.count(r"\frac")
        slashes += text.count("/")
    assert drawn > 1000 and slashes < drawn // 10, f"{drawn} كسر · {slashes} شرطة"
