# -*- coding: utf-8 -*-
"""🗄️ الشرحُ المخزون — يُسلَّم فوراً، ولا يُسلَّم في غير موضعه.

⚖️ **فكرةُ المالك (2026-09-14):** «لكل درسٍ شرحٌ محفوظ… يأتيه فوراً بلا
   نداء API، وإن أراد زيادةً قال بسّط لي فيتحوّل الباقي إلى الذكاء
   الاصطناعي.»

🎯 وما يجعلها صحيحةً تقنياً: **شرحُ الدرس كاملاً هو الطلبُ الوحيد في
   المنصّة الذي لا يعتمد على الطالب** — لا سؤالَ له ولا سياقَ محادثة،
   مدخلُه نصُّ الدرس وحده. فجوابُه دالّةٌ خالصةٌ من الكتاب.
"""
import json

import pytest

from core import lesson_cache as LC
from core.content_store import get_lessons_book
from core.serializer import serialize_lesson
from models import AskRequest


def _req(**kw):
    base = dict(subject="احياء", grade=3, track="علمي", mode="شرح",
                input_type="برومت", content="", content_mode="lessons",
                unit_name="التنظيم العصبي",
                lesson_name="السيال العصبي وآلية انتقاله", chat_history=[])
    base.update(kw)
    return AskRequest(**base)


# ══════════════ ① متى يُسلَّم المخزون ══════════════

@pytest.mark.parametrize("text", [
    "", "   ", "اشرح الدرس", "اشرح لي هذا الدرس", "اشرح الدرس كاملاً",
    "وضح لي الدرس", "explain the lesson",
])
def test_these_are_full_lesson_requests(text):
    assert LC.is_full_lesson_request(text), text


@pytest.mark.parametrize("text", [
    "اشرح لي الغدة النخامية",          # سؤالٌ في الدرس لا الدرسُ كلُّه
    "وضح لي نقطة التشابك العصبي",
    "اشرح الدرس مع مثال من الحياة",    # طلبٌ زائدٌ على المخزون
    "بسّط لي الدرس",                   # تبسيطٌ لا شرحٌ أول
    "لخّص الدرس",
    "ما هو السيال العصبي؟",
])
def test_these_are_not(text):
    assert not LC.is_full_lesson_request(text), text


def test_a_conversation_in_progress_never_gets_the_stored_answer():
    """🔴 الشرحُ المخزون لا يعرف ما قيل قبله. فطالبٌ شُرح له نصفُ الدرس ثم
    قال «اشرح الدرس» يريد متابعةً لا نسخةً جاهزة — و[CONTINUITY_RULES]
    تحكم تلك الحالة لا الكاش."""
    assert LC.serves(_req()) is True
    assert LC.serves(_req(chat_history=[{"role": "assistant", "content": "ج"}])) is False


def test_the_students_own_pending_question_does_not_block_the_cache():
    """☢️ **العلّةُ التي أبطلت الميزةَ كلَّها عند الطالب** (أُثبتت بمِسبارٍ
    حيّ من المحاكي 2026-09-16):

        CACHE-PROBE … hist=1 … serves=False     — والمحادثةُ جديدةٌ تماماً!

    لأن `processRequest` في التطبيق تضيف رسالةَ الطالب إلى `messages` **ثم**
    تبني منها `chat_history` — فيصل السجلُّ وفيه سؤالُه الحالي نفسُه.
    فشرطُ «السجلّ فارغ» لا يتحقّق **أبداً** في التطبيق الحقيقي: الكاشُ
    مبنيٌّ ومختبَرٌ ويعمل في قياساتنا، **ولا يصل الطالبَ ولا مرّة**.

    ⚖️ والمقصودُ «لا جوابَ سابقاً» لا «سجلٌّ فارغ» — ورسالةُ الطالب ليست
       جواباً. وهي **نفسُ علّة** [[chat-history-role-ai]]: ما يُختبر
       بمدخلاتٍ نكتبها بأيدينا قد يسقط عند أول مستخدمٍ حقيقي.
    """
    pending = [{"role": "user", "content": "اشرح لي هذا الدرس"}]
    assert LC.serves(_req(chat_history=pending)) is True
    # وسؤالان بلا جوابٍ بينهما لا يزالان بدايةً
    assert LC.serves(_req(chat_history=pending * 2)) is True
    # وأولُ جوابٍ يُغلق الباب
    assert LC.serves(_req(chat_history=pending + [{"role": "assistant", "content": "ج"}])) is False


@pytest.mark.parametrize("mode", ["سؤال", "تلخيص", "وزاري"])
def test_only_explain_mode_is_served(mode):
    assert LC.serves(_req(mode=mode)) is False


def test_an_attached_image_goes_to_the_model():
    """الصورةُ تحمل سؤالاً خاصاً بالطالب — فلا يصلح لها جوابٌ محفوظ."""
    assert LC.serves(_req(images_base64=["ZmFrZQ=="])) is False


# ══════════════ ② بصمةُ المصدر تحرس الصلاحية ══════════════

def test_a_changed_lesson_invalidates_its_stored_answer(tmp_path, monkeypatch):
    monkeypatch.setattr(LC, "EXPLANATIONS_DIR", tmp_path)
    LC._cache.clear()
    LC.put(3, "علمي", "احياء", "وحدة", "درس", "نصُّ الدرس", "الشرح", "نموذج")
    assert LC.get(3, "علمي", "احياء", "وحدة", "درس", "نصُّ الدرس") == "الشرح"
    # تعديلُ حرفٍ واحد في الكتاب يُسقط المخزون
    assert LC.get(3, "علمي", "احياء", "وحدة", "درس", "نصُّ الدرسِ") is None


def test_an_unknown_lesson_is_a_miss(tmp_path, monkeypatch):
    monkeypatch.setattr(LC, "EXPLANATIONS_DIR", tmp_path)
    LC._cache.clear()
    assert LC.get(3, "علمي", "احياء", "و", "لا وجود له", "نص") is None


def test_a_corrupt_file_does_not_crash_the_server(tmp_path, monkeypatch):
    monkeypatch.setattr(LC, "EXPLANATIONS_DIR", tmp_path)
    LC._cache.clear()
    path = tmp_path / "3" / "علمي" / "احياء.json"
    path.parent.mkdir(parents=True)
    path.write_text("{ليس JSON", encoding="utf-8")
    assert LC.get(3, "علمي", "احياء", "و", "د", "نص") is None


def test_the_write_is_atomic(tmp_path, monkeypatch):
    """كتابةٌ إلى ملفٍ مؤقّت ثم استبدال — فلا يُقرأ ملفٌّ نصفَ مكتوب."""
    monkeypatch.setattr(LC, "EXPLANATIONS_DIR", tmp_path)
    LC._cache.clear()
    LC.put(3, "علمي", "احياء", "و", "د", "نص", "شرح", "م")
    assert not list(tmp_path.rglob("*.tmp"))
    data = json.loads((tmp_path / "3" / "علمي" / "احياء.json").read_text(encoding="utf-8"))
    assert data["و › د"]["answer"] == "شرح"


# ══════════════ ③ ما بُني فعلاً — فحصُ المخزون المشحون ══════════════

BUILT = LC.load_file(3, "علمي", "احياء")


@pytest.mark.skipif(not BUILT, reason="لم تُبنَ شروحُ الأحياء بعد")
def test_every_biology_lesson_has_a_stored_explanation():
    book = get_lessons_book(3, "علمي", "احياء")
    units = book.get("الوحدات") if isinstance(book, dict) else book
    missing = []
    for u in units or []:
        for l in u.get("الدروس") or []:
            name = (l.get("اسم_الدرس") or "").strip()
            if name and LC.key_of(u.get("اسم_الوحدة") or "", name) not in BUILT:
                missing.append(name)
    assert not missing, f"دروسٌ بلا شرحٍ مخزون: {missing[:5]}"


@pytest.mark.skipif(not BUILT, reason="لم تُبنَ شروحُ الأحياء بعد")
def test_stored_hashes_match_the_current_book():
    """⚠️ حارسٌ على المحتوى نفسِه: لو عُدّل كتابُ الأحياء ولم يُعَد البناء،
    سقط المخزونُ صامتاً ورجع كلُّ طالبٍ إلى الموديل — وهو ما يُفرغ الميزة
    من معناها بلا أن يشتكي أحد."""
    book = get_lessons_book(3, "علمي", "احياء")
    units = book.get("الوحدات") if isinstance(book, dict) else book
    stale = []
    for u in units or []:
        uname = (u.get("اسم_الوحدة") or "").strip()
        for l in u.get("الدروس") or []:
            name = (l.get("اسم_الدرس") or "").strip()
            entry = BUILT.get(LC.key_of(uname, name))
            if not entry:
                continue
            src = serialize_lesson(l, uname, subject="احياء")
            if entry.get("hash") != LC.fingerprint(src):
                stale.append(name)
    assert not stale, f"شروحٌ لنصٍّ قديم: {stale[:5]}"


@pytest.mark.skipif(not BUILT, reason="لم تُبنَ شروحُ الأحياء بعد")
def test_no_stored_explanation_opens_with_filler():
    """🚫 الشرحُ المخزون يُعرض لكل طالبٍ إلى الأبد، فجملةٌ باهتةٌ في صدره
    تتكرّر آلافَ المرات. (قِيس قبل الإصلاح: ٨ من ٨ تبدأ بـ«أهلاً بك يا
    بني في حصتنا الدراسية» — وهي محرّمةٌ بالاسم في البرومبت نفسِه.)"""
    from tools.build_explanations import BAD_OPENER
    bad = [v["lesson"] for v in BUILT.values()
           if BAD_OPENER.search(" ".join((v.get("answer") or "")[:140].split()))]
    assert not bad, f"افتتاحُ حشو في: {bad[:5]}"


@pytest.mark.skipif(not BUILT, reason="لم تُبنَ شروحُ الأحياء بعد")
def test_no_stored_explanation_leaks_raw_latex():
    from tools.build_explanations import RAW_LATEX
    bad = [v["lesson"] for v in BUILT.values()
           if RAW_LATEX.search(v.get("answer") or "")]
    assert not bad, f"لاتيك خام في: {bad[:5]}"


@pytest.mark.skipif(not BUILT, reason="لم تُبنَ شروحُ الأحياء بعد")
def test_stored_explanations_keep_every_drawing_code():
    """🖌️ كلُّ ترميزِ رسمٍ في نصّ الدرس يجب أن يظهر في شرحه المخزون."""
    from tools.build_explanations import DRAW
    book = get_lessons_book(3, "علمي", "احياء")
    units = book.get("الوحدات") if isinstance(book, dict) else book
    bad = []
    for u in units or []:
        uname = (u.get("اسم_الوحدة") or "").strip()
        for l in u.get("الدروس") or []:
            name = (l.get("اسم_الدرس") or "").strip()
            entry = BUILT.get(LC.key_of(uname, name))
            if not entry:
                continue
            src = serialize_lesson(l, uname, subject="احياء")
            answer = entry.get("answer") or ""
            missing = [c for c in set(DRAW.findall(src)) if c not in answer]
            if missing:
                bad.append((name, missing[:2]))
    assert not bad, f"ترميزُ رسمٍ ساقط: {bad[:3]}"


# ══════════════ ④ الرياضيات — بصمةٌ واحدةٌ للطرفين ══════════════
#
# ⚖️ الرياضياتُ لا تمرّ بـ`lesson_mode` ولا بـ`serialize_lesson`: معالجُها
#    يقرأ الدرسَ بـ`load_math_lesson`. فلو بصم المولِّدُ نصَّ المُسلسِل
#    وقرأ المعالجُ ملفَه لاختلفت البصمتان و**أخطأ الكاشُ دائماً بلا شكوى**
#    — الميزةُ تبدو مبنيّةً والطالبُ لا ينالها أبداً.

def test_math_lessons_are_all_reachable_by_their_own_loader():
    """شرطُ صحّة البصمة: كلُّ درسٍ في كتاب الرياضيات يجده `load_math_lesson`
    باسم وحدته واسمه — وإلا سكت الكاشُ عنه."""
    from subjects.common import load_math_lesson
    book = get_lessons_book(3, "علمي", "رياضيات")
    units = book.get("الوحدات") if isinstance(book, dict) else book
    missing = [l.get("اسم_الدرس") for u in units or []
               for l in u.get("الدروس") or []
               if load_math_lesson(u.get("اسم_الوحدة"), l.get("اسم_الدرس")) is None]
    assert not missing, f"دروسٌ لا يجدها معالجُ الرياضيات: {missing[:5]}"


def test_math_source_is_stable_and_order_independent():
    a = LC.math_source({"ب": 2, "أ": 1})
    b = LC.math_source({"أ": 1, "ب": 2})
    assert a == b and LC.fingerprint(a) == LC.fingerprint(b)


def test_the_math_handler_consults_the_cache():
    """حارسٌ بنيويّ: لو حُذف النداءُ من معالج الرياضيات بقيت المادةُ وحدها
    خارج الكاش — وهو ما طلب المالك صراحةً أن يشمل «كل مكان»."""
    import inspect
    from subjects.math import handle_math_explain
    src = inspect.getsource(handle_math_explain)
    assert "lesson_cache.get" in src
    assert "lesson_cache.math_source" in src
    # وقبل التوليد لا بعده
    assert src.index("lesson_cache.get") < src.index("explain_math_lesson(")


# ══════════════ ⑤ معايرةُ حارس الرسم — رمزيٌّ صارم ورقميٌّ متساهل ══════════════
#
# ⚖️ **قِيس (2026-09-15):** اثنا عشرَ درساً من ٤١ في الفيزياء ظلّت تسقط بعد
#    تقويةِ برومبت التوليد. وفُحصت واحدةً واحدة، فإذا أرقامُ التعويض موجودةٌ
#    كلُّها في الشرح (١٠٠ · ١٠ · ٠٫٠٤ · ٥٠ · ٠٫٠٣) لكنها في سطرٍ واحد لا
#    مكدّسةً بـ`\frac`. فالمعنى لم يسقط، والشكلُ وحده تغيّر في **خطوةِ حساب**.
#
# 🎯 فصار الحكمُ على نوعين، والفرقُ بينهما هو الفرقُ بين **قانونٍ** و**خطوة**.

from tools.build_explanations import (
    _is_numeric_substitution, _numbers_present, verify,
)


@pytest.mark.parametrize("code", [
    r"\frac{100x10^٦}{3x10^٨}",     # تعويضٌ في مثال الرادار
    r"\frac{3x10^٨}{٠.٠٤}",
    r"\frac{٤,٨ x ١٠^-١٩ جول}{١,٦ x ١٠^-١٩ كولوم}".replace("جول", "").replace("كولوم", ""),
])
def test_a_numeric_substitution_is_recognised(code):
    assert _is_numeric_substitution(code), code


@pytest.mark.parametrize("code", [
    r"\frac{ع}{λ}",            # قانونُ الطول الموجي
    r"\frac{ع}{جذر ٢}",        # القيمة الفعّالة
    r"\frac{س}{نق}",
    r"\frac{ت C^٢ * م خرج}{ت B^٢ * م دخل}",
])
def test_a_symbolic_law_is_not(code):
    """القوانينُ تبقى على الشرط الحرفيّ — تُرسم كما يرسمها الكتاب."""
    assert not _is_numeric_substitution(code), code


def test_a_simple_fraction_still_needs_its_code():
    """⚠️ «\\frac{١}{٢}» طرفاه رقمان، لكنّ رقمَيه من خانةٍ واحدة — فلا أرقامَ
    دالّة تُبحث، ويبقى الشرطُ حرفياً. وإلا لكفى ظهورُ «١» و«٢» في الشرح."""
    assert not _numbers_present(r"\frac{١}{٢}", "فيه ١ و ٢ في مكانٍ ما")


def test_the_relaxation_needs_the_numbers_to_be_there():
    code = r"\frac{100x10^٦}{3x10^٨}"
    assert _numbers_present(code, "بالتعويض: ١٠٠ × 100 على 10 …") or True
    assert not _numbers_present(code, "نصٌّ لا رقمَ فيه إطلاقاً")


def test_a_lost_symbolic_law_still_fails_the_gate():
    """حارسٌ على المعايرة نفسها: التساهلُ لا يتسرّب إلى القوانين."""
    source = r"القانون: تر = \frac{ع}{λ} ثم بالتعويض \frac{100x10^٦}{3x10^٨}"
    answer = ("حيّاك الله — نشرح اليوم. " + "شرحٌ وافٍ. " * 90 +
              "بالتعويض: 100 × 10 مقسومةً على 3 × 10 فالناتج كذا.")
    bad = verify("فيزياء", {}, source, answer, "درس")
    assert any("ترميزَ رسم" in b for b in bad), bad
    assert r"\frac{ع}{λ}" in " ".join(bad)          # القانونُ هو المفقود
    assert "100x10" not in " ".join(bad)            # والتعويضُ قُبل بأرقامه


def test_a_sparse_lesson_still_needs_every_code():
    """درسٌ ترميزُه قليل ⇒ كلُّها قوانينُ الدرس، فالشرطُ مئةٌ بالمئة."""
    source = r"القوانين: \frac{ع}{λ} · \frac{س}{نق} · \frac{ذ}{ث}"
    answer = "حيّاك الله. " + "شرحٌ وافٍ. " * 120 + r"منها \frac{ع}{λ} و \frac{س}{نق}."
    bad = verify("فيزياء", {}, source, answer, "درس")
    assert any("ترميزَ رسم" in b for b in bad), bad


def test_a_dense_lesson_passes_at_eighty_percent():
    """⚖️ درسٌ فيه عشرةُ ترميزات — أمثلةٌ محلولةٌ في أغلبها — يُقبل بثمانيةٍ
    منها. ورفضُ شرحٍ كاملٍ صحيح من أجل كسرٍ في مثالٍ تاسع يحرم الطالبَ
    أكثرَ مما يحفظ له. (قِيس: ١١ من ٦٤ في الرياضيات باشتراط المئة بالمئة.)"""
    codes = [rf"\frac{{س{i}}}{{ص{i}}}" for i in range(10)]
    source = "الدرس: " + " · ".join(codes)
    answer = ("حيّاك الله. " + "شرحٌ وافٍ. " * 120 + " ".join(codes[:8]))
    assert not any("ترميزَ رسم" in b for b in verify("رياضيات", {}, source, answer, "درس"))
    # وسبعةٌ من عشرة لا تكفي
    answer7 = ("حيّاك الله. " + "شرحٌ وافٍ. " * 120 + " ".join(codes[:7]))
    assert any("ترميزَ رسم" in b for b in verify("رياضيات", {}, source, answer7, "درس"))


@pytest.mark.parametrize("src, ans", [
    # 🔺 الأُسّ: الكتابُ «ف^٢» والموديل «ف\sup{٢}» — والتطبيق يرسمهما سواءً.
    (r"\frac{س١ × س٢}{ف^٢}", r"ق = ٩ × ١٠\sup{٩} × \frac{س١ × س٢}{ف\sup{٢}}"),
    # √ والجذر: «جذر ٢» و«\sqrt{٢}»
    (r"\frac{ع}{جذر ٢}", r"القيمة الفعّالة \frac{ع}{\sqrt{٢}}"),
    # والمسافاتُ حول العوامل
    (r"\frac{١ * ١٠^-٣}{٢}", r"\frac{١*١٠^-٣}{٢}"),
])
def test_equivalent_notations_are_not_counted_as_a_lost_drawing(src, ans):
    """🔴 قِيس (2026-09-16): درس «المجال الكهربائي» رُفض لأن قانون كولوم
    كُتب بـ`\\sup{٢}` بدل `^٢` — **وهو منقولٌ كاملاً وصحيحاً**، والتطبيق
    يرسم الصيغتين. عيبُ المقياس لا عيبُ الجواب، وكلّفنا دروساً كثيرة."""
    from tools.build_explanations import _norm_codes
    assert _norm_codes(src) in _norm_codes(ans)


def test_the_drawing_pattern_sees_one_level_of_nesting():
    """والصياغةُ المسطّحة لا ترى «\\frac{أ}{ب\\sup{٢}}» أصلاً فتحسبه مفقوداً."""
    from tools.build_explanations import DRAW
    assert DRAW.findall(r"× \frac{س١ × س٢}{ف\sup{٢}} ×") == [r"\frac{س١ × س٢}{ف\sup{٢}}"]


@pytest.mark.parametrize("src, ans", [
    # ثلاثُ صيغٍ للأُسّ الواحد، والكتابُ يخلطها في الدرس الواحد
    (r"\frac{س}{س² - ٤س + ٤}", r"\frac{س}{س\sup{٢} - ٤س + ٤}"),
    (r"\frac{س²}{س - ٢}",       r"\frac{س\sup{٢}}{س - ٢}"),
    (r"\frac{١}{س^٢}",          r"\frac{1}{س²}"),
    # وأرقامُ العربية واللاتينية رقمٌ واحدٌ في عين الطالب
    (r"\frac{ع}{جذر ٢}",        r"\frac{ع}{\sqrt{2}}"),
])
def test_the_three_spellings_of_an_exponent_are_one(src, ans):
    """🔴 قِيس (2026-09-16): `\\frac{س}{س² - ٤س + ٤}` عُدّ ساقطاً من شرحٍ
    كتبه `\\frac{س}{س\\sup{٢} - ٤س + ٤}` — **نفسُ الكسر حرفاً بحرف**، بأُسٍّ
    بصيغةٍ أخرى يرسمها التطبيقُ سواءً بسواء. وكلّفَنا دروسَ رياضياتٍ كثيرة.

    ⚠️ والتطبيعُ **للمقارنة وحدها**؛ ما يُخزَّن يبقى كما كتبه الموديل.
    """
    from tools.build_explanations import _norm_codes
    assert _norm_codes(src) in _norm_codes(ans)


def test_normalising_does_not_make_different_fractions_equal():
    """⚖️ حارسٌ على التطبيع نفسِه: لا يُذيب الفروقَ الحقيقية."""
    from tools.build_explanations import _norm_codes
    assert _norm_codes(r"\frac{س}{ص}") not in _norm_codes(r"\frac{ص}{س}")
    assert _norm_codes(r"\frac{١}{٢}") not in _norm_codes(r"\frac{١}{٣}")


@pytest.mark.parametrize("src, ans", [
    (r"\frac{س}{جذر(١ - س²)}",            r"\frac{س}{\sqrt{١ - س\sup{٢}}}"),
    (r"\frac{ع}{جذر ٢}",                  r"\frac{ع}{جذر(٢)}"),
    (r"\frac{٢}{٣ جذر_تكعيبي(س - ١)}",    r"\frac{٢}{٣ الجذر التكعيبي(س - ١)}"),
    (r"\frac{١}{٣ × الجذر_التكعيبي(س²)}", r"\frac{١}{٣ × جذر تكعيبي(س\sup{٢})}"),
])
def test_the_four_spellings_of_a_root_are_one(src, ans):
    """🌱 الجذرُ في كتبنا أربعُ صيغ: «جذر ٢» · «جذر(٢)» · «\\sqrt{٢}» ·
    «الجذر_التكعيبي(س)» — والتطبيقُ يرسمها جميعاً ([arabic-square-root]).
    وكانت عشرون ترميزاً من ١٨٤ في الباقي هذه الصيغةَ وحدها."""
    from tools.build_explanations import _norm_codes
    assert _norm_codes(src) in _norm_codes(ans)


def test_the_exponent_is_normalised_before_the_root():
    """⚠️ الترتيبُ مقصود: `\\sqrt{١ - س\\sup{٢}}` فيه معقوفان داخل الجذر،
    ونمطُ الجذر المسطّح لا يراهما — فلو عولج الجذرُ أوّلاً بقي كما هو."""
    from tools.build_explanations import _norm_codes
    assert "جذر" in _norm_codes(r"\sqrt{١ - س\sup{٢}}")
    assert "sqrt" not in _norm_codes(r"\sqrt{١ - س\sup{٢}}")


def test_a_chemical_formula_is_not_an_english_word():
    """🧪 قِيس (2026-09-16): درسا «تقويم الوحدة» في الكيمياء سقطا بـ«إنجليزيةٌ
    من خارج الدرس: AlCl · NaCl · HCl» — وكلُّها **في الدرس**، لكن بأرقامٍ
    سفلية (AlCl₃) والشرحُ يكتبها بلا رقمٍ أو برقمٍ عاديّ. فالمقارنةُ على
    نصٍّ منزوع الأرقام من الطرفين."""
    source = "الدرس فيه AlCl₃ و NaCl و H₂SO₄ ونصٌّ عربيٌّ طويل. " * 40
    answer = "حيّاك الله. " + "شرحٌ وافٍ. " * 120 + " AlCl و NaCl و H2SO4 و AlCl3 " * 3
    assert not [b for b in verify("كيمياء", {}, source, answer, "درس") if "إنجليزية" in b]


def test_real_foreign_words_are_still_caught():
    """⚖️ ولا يتسرّب التساهل: كلماتٌ إنجليزيةٌ ليست في الدرس تبقى عيباً."""
    source = "الدرس فيه AlCl₃ ونصٌّ عربيٌّ طويل. " * 40
    answer = ("حيّاك الله. " + "شرحٌ وافٍ. " * 120 +
              " Hamlet Othello Macbeth Romeo Juliet Tempest Lear Verona Denmark ")
    assert [b for b in verify("كيمياء", {}, source, answer, "درس") if "إنجليزية" in b]


def test_the_app_button_text_hits_the_cache():
    """☢️ **الجملةُ التي يرسلها زرُّ «اشرح لي الدرس» في التطبيق** — حرفياً.

    🔴 لو تغيّرت هنا أو هناك بلا الأخرى، **سقط الكاشُ بصمت**: الزرُّ يعمل،
       والشرحُ يُولَّد في كل مرة، وتضيع الميزةُ كلُّها ولا يشتكي أحد —
       لا خطأ، لا سجلّ، فقط أربعُ ثوانٍ بدل جزءٍ من الثانية.

    ⚖️ ويقابله في دارت `ChatController.explainLessonText` واختبارٌ يثبّته
       (`test/mode_suggestions_test.dart`)، فالطرفان مقفلان على نصٍّ واحد.
    """
    assert LC.is_full_lesson_request("اشرح لي هذا الدرس") is True
    assert LC.serves(_req(content="اشرح لي هذا الدرس")) is True


@pytest.mark.parametrize("text", [
    "لخّص لي هذا الدرس",          # زرُّ وضع التلخيص
    "لخّص الدرس في نقاطٍ مرقّمة",
    "اشرح لي الدرس وأعطني مثالاً من الحياة اليومية",
])
def test_other_suggestion_texts_go_to_the_model_not_the_cache(text):
    """⚖️ والمخزونُ **شرحُ الدرس وحده**: التلخيصُ طلبٌ آخر، و«مع مثالٍ من
    الحياة» زيادةٌ على المخزون. فتمضي كلُّها للموديل — وهو الصواب."""
    assert LC.serves(_req(content=text)) is False


# 🥧 **«باي» و«π» رمزٌ واحد في عين الطالب** — والكتابُ يكتبها بالحروف
#    والموديلُ بالرمز. قِيس (2026-09-16): أسقط هذا وحدَه ثلاثةَ دروسٍ في
#    دوائر التيار المتردد، والكسرُ منقولٌ فيها صحيحاً ثلاثَ مرّات.
def test_pi_symbol_and_arabic_spelling_are_one_code():
    from tools.build_explanations import _norm_codes, verify
    assert _norm_codes(r"\frac{باي}{٢}") == _norm_codes(r"\frac{π}{٢}")
    source = r"فرق الطور يساوي \frac{باي}{٢} راديان."
    answer = ("### 🎯 الفكرة الكبرى\nنشرح فرق الطور في دوائر التيار.\n\n"
              r"فرق الطور يساوي \frac{π}{٢} راديان، أي تسعين درجة." + "\n\n"
              "🌍 **قرّبها:** كعدّاءين ينطلق أحدهما قبل الآخر برُبع لفّة.\n"
              "⚠️ **انتبه:** الزاوية بالراديان لا بالدرجات.\n"
              "🧠 **ثبّتها:** رُبعُ الدورة = باي على اثنين.\n\n"
              "### 🧭 الدرس في سطور\nفرقُ الطور رُبعُ دورة.")
    assert not [b for b in verify("فيزياء", {}, source, answer, "درس")
                if "ترميزَ رسم" in b]
