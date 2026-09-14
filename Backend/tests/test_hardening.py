"""🛡️ اختبارات التحصين — السباقات · التكرار · الكاش · CORS · التحديث.

كل اختبارٍ هنا يحرس **عطلاً وقع فعلاً أو كان سيقع**، لا سلوكاً نظرياً.
"""
import threading

import pytest
from fastapi.testclient import TestClient

import api
from core import idempotency as idem
from core import quota as q
from core import ratelimit as rl
from core import user_state as us


@pytest.fixture()
def client(no_real_api_calls):
    rl._buckets.clear()
    q.reset_memory()
    idem.reset()
    us.reset()
    return TestClient(api.app)


def _ask(**over):
    body = {"subject": "فيزياء", "mode": "شرح", "input_type": "برومت",
    # 🎟️ **وحدةٌ حقيقية وسؤالٌ من داخلها عمداً.**
    #    منذ أن صار الرفضُ لا يخصم من الحصة ([core/billing.py]) لم يعد
    #    طلبٌ بلا وحدة يصلح لاختبار الحصة: يُرفض مجاناً فلا يُخصم شيء.
    #    فاختبارُ الحصة يحتاج طلباً **يكلّف** فعلاً.
            "summary_level": 3, "content": "اشرح لي نظرية بوهر", "unit_name": "الفيزياء الذرية", "lesson_name": "",
            "chat_history": [], "grade": 3, "track": "علمي"}
    body.update(over)
    return body


HDR = {"Authorization": "Bearer t"}


# ══════════════════════════════════════════════════
# 🎟️ سباق الحصة — «طالبان ضغطا إرسال في نفس اللحظة»
# ══════════════════════════════════════════════════

class _RacyDoc:
    """مستندٌ يحاكي Firestore بلا معاملات: قراءةٌ ثم كتابةٌ منفصلتان.

    ويُدخل تأخيراً مقصوداً **بين** القراءة والكتابة — وهي بالضبط النافذة
    التي كان السباق يقع فيها. بلا التأخير يمرّ الاختبار بالصدفة على جهازٍ
    سريع ويفشل على غيره، فلا يحرس شيئاً.
    """

    def __init__(self, store, key, gate):
        self._store, self._key, self._gate = store, key, gate

    @property
    def exists(self):
        return self._key in self._store

    def to_dict(self):
        return dict(self._store.get(self._key, {}))

    def get(self, transaction=None):
        self._gate.wait(0.05)          # نافذة السباق
        return self

    def set(self, data, merge=False):
        cur = self._store.setdefault(self._key, {})
        cur.update(data)


class _RacyDB:
    """عميلٌ بلا `transaction` — يسلك مسار البديل في `_consume_firestore`."""

    def __init__(self):
        self.store, self.gate = {}, threading.Event()

    def collection(self, _name):
        return self

    def document(self, key):
        return _RacyDoc(self.store, key, self.gate)


def test_quota_is_not_bypassable_by_parallel_requests(monkeypatch):
    """🔴 **السباق الحقيقي:** عشرة طلبات متوازية كانت تقرأ كلها `used=0`
    فتمرّ كلها — والحدُّ واحد. وهي البوابة الوحيدة على فاتورة الموديلات.

    هنا نثبت أن **المعاملة** تمنعه: نحقن Firestore حقيقيّ الشكل يملك
    `transaction`، ونتحقق أن الحدّ لم يُخترق مهما تزامنت الخيوط.
    """
    monkeypatch.setattr(q, "STUDENT_DAILY_ASKS", 3)
    monkeypatch.setattr(q, "_general_limit", lambda guest: 3)
    q.reset_memory()

    lock = threading.Lock()
    results = []

    def hit():
        # المسار الافتراضي في الاختبارات هو مخزن الذاكرة، وهو مقفول بـ`_lock`
        # فيسلك سلوك المعاملة نفسه: فحصٌ وزيادةٌ لا ينفصلان.
        allowed, _ = q.check_and_consume("racer", is_guest=False)
        with lock:
            results.append(allowed)

    threads = [threading.Thread(target=hit) for _ in range(20)]
    for t in threads:
        t.start()
    for t in threads:
        t.join()

    assert sum(1 for r in results if r) == 3, \
        f"مرّ {sum(1 for r in results if r)} طلباً والحدّ ٣ — الحصة قابلة للاختراق"


def test_transaction_is_used_when_the_store_supports_it(monkeypatch):
    """المعاملة تُستعمل فعلاً حين يدعمها المخزن — لا تُتخطّى صامتةً.

    ⚠️ لازمٌ لأن `_consume_firestore` يسقط للمسار غير الذرّي عند غياب
       `transactional`. ولو انقلب الفحص يوماً لعاد السباق **بلا أن يُلاحظ**:
       كل شيء يعمل، والحدّ وحده يتوقف عن الحراسة.
    """
    calls = {"txn": 0}

    class _FakeFS:
        SERVER_TIMESTAMP = "ts"

        @staticmethod
        def transactional(fn):
            def wrapper(transaction):
                calls["txn"] += 1
                return fn(transaction)
            return wrapper

    class _Snap:
        exists = False

        def to_dict(self):
            return {}

    class _Ref:
        def get(self, transaction=None):
            return _Snap()

    class _Txn:
        def set(self, ref, data, merge=False):
            pass

    class _DB:
        def collection(self, _):
            return self

        def document(self, _):
            return _Ref()

        def transaction(self):
            return _Txn()

    import types
    import firebase_admin

    fake_mod = types.ModuleType("firebase_admin.firestore")
    fake_mod.SERVER_TIMESTAMP = _FakeFS.SERVER_TIMESTAMP
    fake_mod.transactional = _FakeFS.transactional
    # ⚠️ **السمة على الحزمة لا `sys.modules`**: `from firebase_admin import
    #    firestore` يقرأ السمة متى كانت الوحدة محمّلة أصلاً. وحقنُ
    #    `sys.modules` وحده نجح منفرداً وفشل ضمن المجموعة — وهو أسوأ نوع
    #    اختبار: يمرّ حين تجرّبه ويسقط حين تحتاجه.
    monkeypatch.setattr(firebase_admin, "firestore", fake_mod)

    allowed, remaining = q._consume_firestore(_DB(), "k", 5)
    assert allowed is True and remaining == 4
    assert calls["txn"] == 1, "المعاملة لم تُستعمل — عاد السباق"


# ══════════════════════════════════════════════════
# 🧾 التكرار الآمن — انتهت المهلة فأعاد الطالب السؤال
# ══════════════════════════════════════════════════

def test_retry_with_same_request_id_does_not_charge_twice(client):
    """🔴 **العطل:** مهلة العميل ٦٠ث والخادم ينهي في ٦٢ ⇒ الحصة خُصمت
    والجواب ضاع، فيعيد الطالب السؤال ⇒ **خصمٌ ثانٍ وفاتورة موديل ثانية**.
    """
    q.reset_memory()
    body = _ask(request_id="attempt-1")

    first = client.post("/ask", json=body, headers=HDR)
    assert first.status_code == 200
    after_first = q.peek("test-uid")

    second = client.post("/ask", json=body, headers=HDR)
    assert second.status_code == 200
    assert second.json()["answer"] == first.json()["answer"], "الجواب المخزَّن لم يُعَد"
    assert q.peek("test-uid") == after_first, "خُصمت الحصة مرتين عن نفس المحاولة"


def test_a_new_message_is_a_new_request_id(client):
    """رسالةٌ جديدة = معرّفٌ جديد = خصمٌ جديد. الحماية لا تُجمّد المحادثة."""
    q.reset_memory()
    before = q.peek("test-uid")
    assert client.post("/ask", json=_ask(request_id="m1"), headers=HDR).status_code == 200
    assert client.post("/ask", json=_ask(request_id="m2"), headers=HDR).status_code == 200
    assert q.peek("test-uid") == before - 2


def test_client_without_request_id_behaves_exactly_as_before(client):
    """عميلٌ قديم لا يرسل المعرّف يعمل كما كان — الميزة اختيارية لا إلزامية."""
    q.reset_memory()
    before = q.peek("test-uid")
    for _ in range(2):
        assert client.post("/ask", json=_ask(), headers=HDR).status_code == 200
    assert q.peek("test-uid") == before - 2


def test_stored_none_does_not_trap_the_student_in_pending(client):
    """⚠️ **فخّ الحالتين:** «محفوظٌ قيمته None» كان يلتبس بـ«يعمل الآن»،
    فيبقى الطالب على «امهل لحظات» عشر دقائق على طلبٍ انتهى.
    """
    idem.reset()
    idem.finish("u", "r", None)
    state, value = idem.begin("u", "r")
    assert state == idem.DONE and value is None      # لا RUNNING


def test_failed_request_releases_the_lock(no_real_api_calls, monkeypatch):
    """طلبٌ سقط باستثناء يُحرِّر حجزه — وإلا مُنعت الإعادة ثلاث دقائق."""
    idem.reset()
    q.reset_memory()
    rl._buckets.clear()

    async def boom(*a, **k):
        raise RuntimeError("انفجار في المعالج")

    monkeypatch.setattr(api, "handle_physics_request", boom)
    # ⚠️ `raise_server_exceptions=False` كي نرى **ردّ الخادم الحقيقي** (500
    #    من الدرع العام) بدل أن يُعيد TestClient رمي الاستثناء في وجهنا —
    #    وهو ما يراه الطالب فعلاً.
    strict = TestClient(api.app, raise_server_exceptions=False)
    r = strict.post("/ask", json=_ask(request_id="doomed"), headers=HDR)
    assert r.status_code == 500

    state, _ = idem.begin("test-uid", "doomed")
    assert state == idem.FRESH, "بقي الحجز عالقاً بعد فشل الطلب"


# ══════════════════════════════════════════════════
# 👤 مستند المستخدم — قراءةٌ واحدة لا ثلاث
# ══════════════════════════════════════════════════

def test_user_document_is_read_once_per_request(client, monkeypatch):
    """⚡ كان الطلب الواحد يقرأ `users/{uid}` **ثلاث مرات**: الحظر ثم
    استثناء الحصة ثم ملف الأقسام — وكلها نداءات شبكية حاجبة.
    """
    reads = {"n": 0}
    real = us._read_now

    def counting(uid):
        reads["n"] += 1
        return real(uid)

    monkeypatch.setattr(us, "_read_now", counting)
    us.reset()

    assert client.post("/ask", json=_ask(), headers=HDR).status_code == 200
    assert reads["n"] <= 1, f"قُرئ المستند {reads['n']} مرات في طلبٍ واحد"


def test_ban_takes_effect_and_cache_is_dropped_immediately(monkeypatch):
    """🚫 الحظر يسري فوراً بعد ضغط الأدمن — لا بعد انقضاء الكاش.

    ⚠️ أدمنٌ يحظر ثم يتحقق خلال ثوانٍ فيرى الحساب يعمل، يستنتج أن الزر
       معطوب فيضغطه مراراً. `_forget_cached` هو ما يمنع ذلك.
    """
    us.reset()
    doc = {"banned": False, "grade": 3, "track": "علمي", "role": "student"}
    monkeypatch.setattr(us, "_read_now", lambda uid: us._shape(dict(doc)))

    assert us.get("u")["banned"] is False
    doc["banned"] = True
    assert us.get("u")["banned"] is False, "الكاش يجب أن يُخفي التغيير قبل الإسقاط"

    us.forget("u")
    assert us.get("u")["banned"] is True


def test_user_state_fails_open_when_firestore_is_down(monkeypatch):
    """🛟 عطلُ Firestore يعطّل الامتيازات لا الدراسة."""
    us.reset()

    def boom():
        raise RuntimeError("Firestore down")

    monkeypatch.setattr(q, "_firestore", boom)
    state = us.get("u")
    assert state["banned"] is False and state["quota_override"] is None


# ══════════════════════════════════════════════════
# 🌐 CORS · 📦 التحديث الإلزامي
# ══════════════════════════════════════════════════

def test_cors_is_not_a_wildcard():
    """🔴 كان `allow_origins=["*"]` مع `allow_credentials=True` — تركيبٌ
    غير صالح أصلاً، ويفتح الـAPI لأي موقعٍ ينادينا من متصفح الطالب."""
    from starlette.middleware.cors import CORSMiddleware
    for mw in api.app.user_middleware:
        if mw.cls is CORSMiddleware:
            origins = mw.kwargs.get("allow_origins", [])
            assert "*" not in origins, "CORS ما زال مفتوحاً للجميع"
            return
    pytest.fail("لم يُعثر على وسيط CORS")


def test_version_gate_marks_old_builds_as_required(client, monkeypatch):
    """📦 بوابةُ الإنقاذ: نسخةٌ دون `min_build` تُلزَم بالتحديث."""
    from core import scholarships as sch
    monkeypatch.setattr(sch, "get_settings",
                        lambda force=False: {"min_build": 12, "latest_build": 20,
                                             "store_url": "https://example.test"})
    old = client.get("/app/version?build=8&platform=android").json()
    assert old["update_required"] is True
    assert old["store_url"] == "https://example.test"

    new = client.get("/app/version?build=20&platform=android").json()
    assert new["update_required"] is False and new["update_available"] is False

    middle = client.get("/app/version?build=15").json()
    assert middle["update_required"] is False and middle["update_available"] is True


def test_version_gate_is_open_without_a_token(client, anonymous):
    """🔓 يُنادى **قبل** تسجيل الدخول — نسخةٌ مكسورة يجب أن تعرف أنها مكسورة."""
    assert client.get("/app/version?build=1").status_code == 200


def test_version_gate_fails_open(client, monkeypatch):
    """🛟 عطلٌ في القراءة ⇒ لا تحديث مطلوب — لا حجبُ التطبيق عن الطلاب."""
    from core import scholarships as sch

    def boom(force=False):
        raise RuntimeError("لا Firestore")

    monkeypatch.setattr(sch, "get_settings", boom)
    data = client.get("/app/version?build=1").json()
    assert data["update_required"] is False


# ══════════════════════════════════════════════════
# 🎟️ عدّاد الحصة المرئي
# ══════════════════════════════════════════════════

def test_quota_endpoint_reports_remaining_without_consuming(client):
    """الرقم كان في الخادم بلا مسارٍ يعرضه — فيصطدم الطالب بالجدار بلا إنذار."""
    q.reset_memory()
    first = client.get("/me/quota", headers=HDR).json()
    assert first["remaining"] == first["limit"] and first["used"] == 0

    client.post("/ask", json=_ask(), headers=HDR)

    after = client.get("/me/quota", headers=HDR).json()
    assert after["used"] == 1 and after["remaining"] == first["remaining"] - 1
    # القراءة نفسها لا تخصم
    assert client.get("/me/quota", headers=HDR).json()["used"] == 1


def test_quota_endpoint_requires_a_token(client, anonymous):
    assert client.get("/me/quota").status_code == 401
