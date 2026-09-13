import os, sys

_HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(_HERE))   # جذر المشروع
sys.path.insert(0, _HERE)                    # ليعمل: from fakes import ...

# ⚠️ إلزامي قبل استيراد api: لا مفاتيح حقيقية داخل الاختبارات إطلاقاً.
for _k in ("GEMINI_API_KEY", "OPENAI_API_KEY", "DEEPSEEK_API_KEY", "GROQ_API_KEY"):
    os.environ[_k] = "test-key-not-real"

import pytest
from fakes import make_fake_client  # noqa: E402


@pytest.fixture(autouse=True)
def no_real_firestore(monkeypatch):
    """🔴 **لا تلمس قاعدة بيانات حقيقية في اختبار — أبداً.**

    يوم ضُبط `GOOGLE_APPLICATION_CREDENTIALS` على جهاز المالك، صار
    `quota._firestore()` يعيد عميلاً حيّاً، فبدأت اختبارات الحصة تكتب في
    مجموعة `usage` **في السحابة** — وفشلت لأن العدّادات هناك ممتلئة أصلاً.
    والأسوأ من فشلها أنها كانت تلوّث بيانات الإنتاج بصمت.

    القاعدة هنا: Firestore **مغلقة افتراضياً** في كل اختبار، فيعمل بديل
    الذاكرة. ومن يحتاج مخزناً يحقن وهمياً بنفسه (`test_admin` ·
    `test_scholarships`) — وحقنه يأتي بعد هذا فيطغى عليه.
    """
    from core import quota
    monkeypatch.setattr(quota, "_firestore", lambda: None)
    monkeypatch.setattr(quota, "_db", None, raising=False)
    monkeypatch.setattr(quota, "_db_ready", True, raising=False)


@pytest.fixture(autouse=True)
def no_real_api_calls(monkeypatch):
    """🛡️ يحقن عملاء وهميين في **كل** المسارات:
    - قاموس AI_CLIENTS (مسارات النسخة الثالثة)
    - متغيرات وحدة api (المسارات القديمة تستقبلها مباشرةً)
    بدون هذا تنادي الاختبارات المزوّدين فعلياً وتُكلّف مالاً."""
    import api

    fakes = {
        "gemini": make_fake_client("GEMINI"),
        "openai": make_fake_client("OPENAI"),
        "deepseek": make_fake_client("DEEPSEEK"),
        "groq": make_fake_client("GROQ"),
    }
    for key, cl in fakes.items():
        monkeypatch.setitem(api.AI_CLIENTS, key, cl)
    monkeypatch.setattr(api, "gemini_client", fakes["gemini"], raising=False)
    monkeypatch.setattr(api, "openai_client", fakes["openai"], raising=False)
    monkeypatch.setattr(api, "deepseek_client", fakes["deepseek"], raising=False)
    monkeypatch.setattr(api, "groq_client", fakes["groq"], raising=False)
    return fakes


# ══════════════════════════════════════════════════════════════
# 📁 هدفٌ بلا محتوى — يُكتشف من البيانات لا يُكتب بالاسم
# ══════════════════════════════════════════════════════════════
# سلوكٌ نختبره كثيراً: «مادة لم يُضف محتواها ⇒ رسالة ودّية لا انهيار».
# وكانت الاختبارات تسمّي الأحياء مثالاً عليه — فلمّا أضاف المالك دروسها
# سقطت ستة اختبارات دفعةً واحدة **بلا أي عطل في الكود**. المحتوى يتغيّر
# كل أسبوع، فالهدف يُكتشف الآن وقت التشغيل، ويُتخطّى الاختبار يوم يمتلئ
# كل شيء (وذلك يومٌ سعيد لا فشل).

def _find_empty(kind: str):
    """أول (صف، مسار، مادة) بلا كتابٍ من هذا النوع — أو None إن امتلأ المنهج."""
    from core import content_store as cs
    from core.curriculum import subjects_for
    getter = cs.get_lessons_book if kind == "lessons" else cs.get_pages_book
    for grade, track in ((1, "عام"), (2, "علمي"), (2, "أدبي"), (3, "علمي"), (3, "أدبي")):
        for subject in subjects_for(grade, track):
            if getter(grade, track, subject) is None:
                return grade, track, subject
    return None


def find_empty_lessons_target():
    """أول (صف، مسار، مادة) بلا كتاب دروس — أو None إن امتلأ المنهج كله."""
    return _find_empty("lessons")


@pytest.fixture
def empty_lessons_target():
    target = find_empty_lessons_target()
    if target is None:
        pytest.skip("كل مواد المنهج صار لها محتوى دروس — لا هدف فارغ للاختبار")
    return target


@pytest.fixture
def empty_pages_target():
    """نظير `empty_lessons_target` لوضع الوحدات — نفس السبب تماماً:
    يوم أضاف المالك `unit_mode/فيزياء.json` سقطت اختبارات كتبت «الفيزياء
    بلا صفحات» بالاسم، بلا أي عطل في الكود."""
    target = _find_empty("pages")
    if target is None:
        pytest.skip("كل مواد المنهج صار لها محتوى وحدات — لا هدف فارغ للاختبار")
    return target


# ══════════════════════════════════════════════════════════════
# 🔐 «طالبٌ مسجَّلٌ» هو الحالة الافتراضية لكل اختبار
# ══════════════════════════════════════════════════════════════
# 🗑️ بعد حذف نظام أكواد التفعيل، **لا مسار يعمل بلا توكن**. وكانت كل
#    اختبارات المسارات تمرّر `code: SUPER_USER` بلا ترويسة — فصارت كلها 401.
#
# ⭐ والعلاج ليس إضافة ترويسة في خمسين موضعاً بل هنا: `bearer_token` تعيد
#    توكناً وهمياً حين لا ترويسة، و`verify` تقبله وتعيد طالباً مسجَّلاً.
#    فتُختبر **سلوك المسار** لا بوابته، ومن أراد اختبار البوابة نفسها
#    يستبدل الاثنتين في اختباره (monkeypatch اللاحق يطغى على السابق).
#
# ⚠️ ولا يُخفي هذا انكساراً حقيقياً: اختبارات البوابة صريحة في
#    `test_auth_quota.py` وتضبط الدالتين بنفسها.

DEFAULT_TEST_IDENTITY = {
    "uid": "test-uid", "email": "student@test.local", "email_verified": True,
    "provider": "password", "is_guest": False, "name": "طالب الاختبار",
}


@pytest.fixture(autouse=True)
def signed_in_by_default(monkeypatch):
    from core import firebase_auth as fa
    from core import user_state, idempotency

    # 🧹 كاشات عابرة للاختبارات: بقاؤها يجعل اختباراً يُفسد تاليه.
    user_state.reset()
    idempotency.reset()

    def _token(request):
        header = (request.headers.get("authorization", "")
                  or request.headers.get("Authorization", ""))
        if header.lower().startswith("bearer "):
            return header[7:].strip()
        return "test-token"

    monkeypatch.setattr(fa, "bearer_token", _token)
    monkeypatch.setattr(fa, "verify", lambda token: dict(DEFAULT_TEST_IDENTITY))
    yield
    user_state.reset()
    idempotency.reset()


@pytest.fixture()
def anonymous(monkeypatch):
    """يُعيد المسارات إلى «بلا توكن» — لاختبار البوابة نفسها."""
    from core import firebase_auth as fa
    monkeypatch.setattr(fa, "bearer_token", lambda request: "")
    return None
