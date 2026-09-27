# ==================================================
# 🚦 core/ratelimit.py — تحديد المعدل (نافذة منزلقة بالذاكرة)
# ==================================================
# حماية من الاستنزاف والسكربتات: طالب واحد لا يستطيع إغراق السيرفر
# أو تفجير فاتورة الذكاء الاصطناعي.
#
# التصميم:
#   - المسارات ذات الهوية: المفتاح = `uid` الموثَّق وحده ([check_user]).
#   - المسارات بلا هوية: المفتاح = IP (أول قيمة في X-Forwarded-For) + وسم ([check]).
#   - نافذة منزلقة: قائمة طوابع زمنية لكل مفتاح، تُشذَّب عند كل فحص.
#   - سقف صارم لعدد المفاتيح المتتبعة — الذاكرة محدودة مهما حدث.
#   - stateless تجاه الأخطاء: أي عطل داخلي → السماح بالمرور (fail-open)
#     كي لا يعطّل نظام الحماية الخدمةَ نفسها.

import time
import threading

# الحدود (قابلة للضبط): /ask يستدعي موديلات مدفوعة → أشد صرامة
ASK_LIMIT = 20          # طلب
ASK_WINDOW = 60.0       # ثانية
CONTENT_LIMIT = 120     # طلبات المحتوى (GET) أخف كلفة
CONTENT_WINDOW = 60.0
VOICE_LIMIT = 15        # تنظيف الصوت: نداء Flash-Lite قصير — أرخص من /ask وأغلى من GET
VOICE_WINDOW = 60.0
# 🏷️ اسمُ المحادثة: نداءٌ واحدٌ لكل محادثة، بلا حصة — فحدّان: الدقيقةُ للسكربت
#    السريع، والساعةُ لمن يتّخذه موديلاً مجانياً ببطء ([core/chat_title]).
TITLE_LIMIT = 10
TITLE_WINDOW = 60.0
TITLE_HOURLY = 60
TITLE_HOUR = 3600.0

_MAX_KEYS = 10_000      # سقف الذاكرة — لكل مخزنٍ على حدة
_buckets: dict = {}     # دلاء الـIP  (مسارات بلا هوية)  {key: [timestamps]}
_user_buckets: dict = {}  # دلاء الهوية الموثَّقة (المسارات المدفوعة)
_lock = threading.Lock()
_last_sweep = 0.0

# ══════════════════════════════════════════════════
# 🔐 المسارات المدفوعة تُعدّ **بالهوية الموثَّقة وحدها** — لا بالـIP
# ══════════════════════════════════════════════════
# 🔴 **الثغرة (فحص 2026-09-24):** المفتاح كان `IP|uid`، والـIP يُؤخذ من أول
#    قيمة في `X-Forwarded-For` — **وهذه يكتبها العميل نفسه**. فتغييرُها في
#    كل طلب يصنع دلواً جديداً كل مرة: قيسَ ٤٠ طلباً مرّت من ٤٠ والحدُّ ٢٠.
#    فجمعُ الـIP مع الهوية لم يكن «تجاوزُ أحدهما لا يكفي» بل العكس تماماً:
#    **تجاوزُ أيٍّ منهما يكفي**، لأن المفتاح يتغيّر بتغيّر أيٍّ منهما.
#
# ⭐ والـ`uid` يأتي من توكنٍ وقّعته جوجل فلا يُزوَّر، والحدُّ المقصود أصلاً
#    «لكل طالب». أما طلاب مدرسةٍ خلف بوابةٍ واحدة فلكلٍّ منهم هويته ودلوه.
#
# ⚠️ ومسارات بلا هوية (قراءاتٌ رخيصة) تبقى بالـIP كما كانت — تزويرُه هناك
#    يتخطّى حدَّ قراءةٍ رخيصة لا فاتورة موديل. ولا نأخذ «آخر قفزة» بدل الأولى:
#    لا نعرف عدد بروكسيات المنصّة، وخطأُ ذلك يضع **كل الطلاب في دلوٍ واحد**.
#
# 🧱 **ومخزنان منفصلان عمداً:** كان امتلاءُ المخزن (١٠ آلاف مفتاح) يُفرغه كلَّه
#    — فمن يرسل عشرة آلاف IP مزوّر **يصفّر حدود كل الطلاب**. الآن الـIPs
#    المزوّرة لا تلمس دلاء الهوية، والامتلاء يُسقط الأقدم لا الكل.


def _client_ip(request) -> str:
    # خلف بروكسي HF/Render يصل IP الحقيقي في X-Forwarded-For (أول قيمة).
    # ⚠️ قابلٌ للتزوير — لذلك لا يُستعمل إلا في مسارات بلا هوية.
    fwd = request.headers.get("x-forwarded-for", "")
    return fwd.split(",")[0].strip() if fwd else (request.client.host if request.client else "?")


def _client_key(request, user_id: str, scope: str = "") -> str:
    """مفتاح دلو المسارات **بلا هوية**: IP + وسم المسار + **نطاق**.

    🔴 **علّة حقيقية أوجبت النطاق (2026-09-09):** كان المفتاح `ip|uid` وحده،
       فيتشارك **كل** مسارٍ يُمفتِح بالهوية دلواً واحداً — و`check` تُنادى
       بحدودٍ مختلفة على نفس الدلو. فصار `/me/quota` (قراءةٌ رخيصة، حدّها
       ١٢٠) يملأ الدلو الذي يقرأه `/ask` بحدّ ٢٠، فيُرفض سؤال الطالب بـ429
       **بسبب أن التطبيق قرأ عدّاد حصته**.
    """
    return f"{_client_ip(request)}|{(user_id or '')[:64]}|{scope}"


def _sweep(now: float, window: float):
    """تنظيف دوري للمفاتيح الخاملة — يمنع تضخم القاموس."""
    global _last_sweep
    if now - _last_sweep < 120:
        return
    _last_sweep = now
    for st in (_buckets, _user_buckets):
        dead = [k for k, ts in st.items() if not ts or now - ts[-1] > window * 2]
        for k in dead:
            st.pop(k, None)


def _evict_oldest(store: dict) -> None:
    """امتلاءٌ (هجوم مفاتيح): يُسقط ربعَ الأقدم نشاطاً — لا المخزن كلَّه."""
    victims = sorted(store, key=lambda k: store[k][-1] if store[k] else 0.0)
    for k in victims[: max(1, _MAX_KEYS // 4)]:
        store.pop(k, None)


def _hit(store: dict, key: str, limit: int, window: float) -> bool:
    now = time.time()
    with _lock:
        _sweep(now, window)
        if key not in store and len(store) >= _MAX_KEYS:
            _evict_oldest(store)
        ts = store.setdefault(key, [])
        cutoff = now - window
        while ts and ts[0] < cutoff:
            ts.pop(0)
        if len(ts) >= limit:
            return False
        ts.append(now)
        return True


def check(request, user_id: str, limit: int = ASK_LIMIT, window: float = ASK_WINDOW,
          scope: str = "") -> bool:
    """للمسارات **بلا هوية موثَّقة**: True = مسموح، False = تجاوز الحد.

    ⚠️ المسارات التي معها `uid` من التوكن تنادي [check_user] لا هذه —
       المفتاح هنا فيه IP قابلٌ للتزوير.

    [scope] يفصل دلاء المسارات المختلفة — راجع [_client_key]. وحين يُترك
    فارغاً يُشتقّ من الحدّ نفسه، فمسارٌ بحدٍّ مختلف يحصل على دلوٍ مختلف
    تلقائياً ولو نسي المُنادي تمريره.
    """
    try:
        return _hit(_buckets, _client_key(request, user_id, scope or f"L{limit}"),
                    limit, window)
    except Exception:
        return True  # fail-open: الحماية لا تعطّل الخدمة


def check_user(uid: str, limit: int = ASK_LIMIT, window: float = ASK_WINDOW,
               scope: str = "") -> bool:
    """للمسارات **ذات الهوية الموثَّقة** — المفتاح `uid` من التوكن وحده.

    لا يقرأ ترويسةً واحدة من الطلب، فلا شيء فيه يملك العميلُ تغييره.
    """
    try:
        key = f"{(uid or '?')[:128]}|{scope or f'L{limit}'}"
        return _hit(_user_buckets, key, limit, window)
    except Exception:
        return True  # fail-open: الحماية لا تعطّل الخدمة


RATE_LIMIT_MESSAGE = "🌙 طلبات كثيرة خلال وقت قصير! خذ نفَساً وحاول بعد دقيقة 😊"


def reset() -> None:
    """للاختبارات فقط — يُفرغ المخزنين معاً (الـIP والهوية)."""
    with _lock:
        _buckets.clear()
        _user_buckets.clear()
