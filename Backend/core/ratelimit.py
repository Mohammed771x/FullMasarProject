# ==================================================
# 🚦 core/ratelimit.py — تحديد المعدل (نافذة منزلقة بالذاكرة)
# ==================================================
# حماية من الاستنزاف والسكربتات: طالب واحد لا يستطيع إغراق السيرفر
# أو تفجير فاتورة الذكاء الاصطناعي.
#
# التصميم:
#   - المفتاح = (IP الحقيقي خلف البروكسي + user_id) — تجاوز أحدهما لا يكفي.
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

_MAX_KEYS = 10_000      # سقف الذاكرة
_buckets: dict = {}     # {key: [timestamps]}
_lock = threading.Lock()
_last_sweep = 0.0


def _client_key(request, user_id: str, scope: str = "") -> str:
    """مفتاح الدلو: IP + هوية + **نطاق**.

    🔴 **علّة حقيقية أوجبت النطاق (2026-09-09):** كان المفتاح `ip|uid` وحده،
       فيتشارك **كل** مسارٍ يُمفتِح بالهوية دلواً واحداً — و`check` تُنادى
       بحدودٍ مختلفة على نفس الدلو. فصار `/me/quota` (قراءةٌ رخيصة، حدّها
       ١٢٠) يملأ الدلو الذي يقرأه `/ask` بحدّ ٢٠، فيُرفض سؤال الطالب بـ429
       **بسبب أن التطبيق قرأ عدّاد حصته**.

       والأثر مضاعف: كل إرسالٍ ناجح يتبعه تحديثٌ للعدّاد، فكلما استعمل
       الطالب التطبيق **اقترب من حظر نفسه**.

    ⚠️ ولا يجوز إسقاط الهوية من المفتاح: الـIP وحده يخلط طلاب مدرسةٍ خلف
       بوابةٍ واحدة.
    """
    # خلف بروكسي HF/Render يصل IP الحقيقي في X-Forwarded-For (أول قيمة)
    fwd = request.headers.get("x-forwarded-for", "")
    ip = fwd.split(",")[0].strip() if fwd else (request.client.host if request.client else "?")
    return f"{ip}|{(user_id or '')[:64]}|{scope}"


def _sweep(now: float, window: float):
    """تنظيف دوري للمفاتيح الخاملة — يمنع تضخم القاموس."""
    global _last_sweep
    if now - _last_sweep < 120:
        return
    _last_sweep = now
    dead = [k for k, ts in _buckets.items() if not ts or now - ts[-1] > window * 2]
    for k in dead:
        _buckets.pop(k, None)


def check(request, user_id: str, limit: int = ASK_LIMIT, window: float = ASK_WINDOW,
          scope: str = "") -> bool:
    """True = مسموح، False = تجاوز الحد.

    [scope] يفصل دلاء المسارات المختلفة — راجع [_client_key]. وحين يُترك
    فارغاً يُشتقّ من الحدّ نفسه، فمسارٌ بحدٍّ مختلف يحصل على دلوٍ مختلف
    تلقائياً ولو نسي المُنادي تمريره.
    """
    try:
        now = time.time()
        key = _client_key(request, user_id, scope or f"L{limit}")
        with _lock:
            _sweep(now, window)
            if key not in _buckets and len(_buckets) >= _MAX_KEYS:
                _buckets.clear()  # حالة قصوى (هجوم مفاتيح) — تفريغ آمن
            ts = _buckets.setdefault(key, [])
            cutoff = now - window
            while ts and ts[0] < cutoff:
                ts.pop(0)
            if len(ts) >= limit:
                return False
            ts.append(now)
            return True
    except Exception:
        return True  # fail-open: الحماية لا تعطّل الخدمة


RATE_LIMIT_MESSAGE = "🌙 طلبات كثيرة خلال وقت قصير! خذ نفَساً وحاول بعد دقيقة 😊"
