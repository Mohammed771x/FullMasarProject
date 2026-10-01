# ==================================================
# 🧵 core/blocking_pool.py — بركةُ الانتظار الشبكيّ
# ==================================================
# كلُّ `asyncio.to_thread` في الخادم يمرّ بها: Firestore (قراءة المستخدم ·
# معاملة الحصة · ردّها) والتوثيق حين يلزم تنزيلُ الشهادات.
#
# 🔴 **كانت ٨ خيوط، وقيست جداراً (2026-10-02):** كلُّ سؤالٍ يحجز خيطاً
#    طوال نداءَي Firestore (~١٢٠–٢٥٠ms لكلٍّ منهما)، فالخادم لا يُدخل أكثر
#    من ٨ ÷ زمنِ Firestore سؤالاً في الثانية (~١٦–٣٣). تحت دفعةٍ متزامنة
#    يقف الباقون في الطابور **قبل أول حرف**: ٢٥٠ طالباً ⇒ ١٠٫٥ث، وألفٌ ⇒ ٣٧ث.
#    وبـ٤٨ قيست: ٢٥٠ ⇒ ٥ث، وألفٌ ⇒ ١٤ث — بلا خطأٍ واحد.
#
# ⚖️ والخيوطُ هنا **تنتظر الشبكة** لا تحسب، فرفعُها لا يُثقل المعالج.
#    والحسابُ (التضمين) له خيوطُه المستقلّة ([subjects/shared/boot.EMBED_EXECUTOR])
#    كي لا يزاحم هذه ولا تزاحمه: خيوطُ التضمين تقف على قفل المُقطِّع، ولو
#    كانت من هذه البركة لوقف معها كلُّ نداء Firestore خلفها.
#
# ⚙️ للضبط بلا لمس كود: `BLOCKING_POOL_WORKERS=…`

import asyncio
import concurrent.futures
import os

WORKERS = int(os.getenv("BLOCKING_POOL_WORKERS", "48"))

# البركةُ المربوطة بالحلقة الجارية — يملؤها [install].
executor: concurrent.futures.ThreadPoolExecutor | None = None


def install() -> concurrent.futures.ThreadPoolExecutor:
    """يربط بركةً **جديدة** بالحلقة **الجارية فعلاً** — يُنادى من `lifespan`.

    ⚠️ كانت تُربط عند استيراد `api.py` بـ`asyncio.get_event_loop()` — وذلك
       لا يصيب حلقةَ الخادم إلا إن صادف أن الاستيرادَ وقع داخلها، وإلا رُبطت
       بحلقةٍ ميتة وعمل الخادم بالبركة الافتراضية بصمت (وبايثون ٣٫١٤ يرفض
       النداءَ خارج حلقةٍ أصلاً).

    🆕 وجديدةٌ لكل حلقة لا واحدةٌ للوحدة: `asyncio.run` **يُغلق** بركةَ
       حلقته عند انتهائها، فبركةٌ مشتركة تموت مع أول حلقةٍ تنتهي ثم يرفض
       كلُّ `to_thread` بعدها (`cannot schedule new futures after shutdown`).
    """
    global executor
    executor = concurrent.futures.ThreadPoolExecutor(
        max_workers=WORKERS,
        thread_name_prefix="worker"
    )
    asyncio.get_running_loop().set_default_executor(executor)
    return executor
