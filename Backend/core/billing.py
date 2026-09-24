# ==================================================
# 🧾 core/billing.py — هل كلّف هذا الطلبُ نداءَ موديلٍ أصلاً؟
# ==================================================
#
# 🔴 **ما رآه المالك (2026-09-14):** بعد بناء عتبة الصلة صار الخادم يردّ
#    «لم أجد في وحدتك ما يخصّ سؤالك» بلا نداء موديل — **ومع ذلك يُخصم
#    السؤال من حصة الطالب**، لأن `acheck_and_consume` في [api.py] تسبق
#    المعالجَ كلَّه. فقال: «خلّ الرفض ما يخصم من الحصة.»
#
# ⚖️ **ولماذا عدّادٌ لا علامةٌ على الردّ:** مسارات المواد فيها عشراتُ
#    الخروجات المبكّرة (لا وحدة · لا صفحات · صفحاتٌ زائدة · مادةٌ قيد
#    الإضافة · سؤالٌ خارج الوحدة …). ووسمُها واحدةً واحدة يعني موضعاً
#    يُنسى اليومَ وموضعاً يُضاف غداً بلا وسم. والقاعدة الصحيحة واحدة:
#    **ما لم يُنادَ موديلٌ، لا يُخصم شيء** — فنعدّ النداءات نفسَها.
#
# 🧵 **والعدّادُ كائنٌ متغيّر داخل `ContextVar` لا رقمٌ فيه.** مسارُ البثّ
#    ينفّذ المعالج في `asyncio.create_task`، والمهمةُ الوليدة ترث **نسخةً**
#    من السياق — فأيُّ `set()` بداخلها لا يراه الأب. أما تعديلُ كائنٍ
#    ورثت الوليدةُ إشارتَه فيراه الطرفان.

import contextvars

_meter = contextvars.ContextVar("masar_model_meter", default=None)


def start() -> dict:
    """يفتح عدّاداً لهذا الطلب ويعيده — يُنادى من الحارس قبل التوزيع."""
    meter = {"model_calls": 0}
    _meter.set(meter)
    return meter


def current():
    """عدّادُ هذا الطلب كما فتحه الحارس — أو `None` خارج مسارِ سؤال.

    ⚠️ **ولا يُعاد `start()` بعد الحارس**: قراءةُ الصورة نداءٌ مدفوع يقع
       **داخل** الحارس، فتصفيرُ العدّاد بعده كان سينسى ثمنَها ويردّ الحصة
       عن طلبٍ كلّفنا فعلاً.
    """
    return _meter.get()


def charge(kind: str = "model") -> None:
    """يُسجّل نداءَ موديلٍ واحداً — يُنادى من [core/streaming.complete] وحدها."""
    meter = _meter.get()
    if meter is not None:
        meter["model_calls"] = meter.get("model_calls", 0) + 1
        meter[f"{kind}_calls"] = meter.get(f"{kind}_calls", 0) + 1


def was_free(meter) -> bool:
    """هل مضى الطلبُ بلا نداءِ موديلٍ واحد؟"""
    return bool(meter) and not meter.get("model_calls")


def clear() -> None:
    """للاختبارات: يُغلق أيَّ عدّادٍ مفتوح في هذا السياق."""
    _meter.set(None)


async def settle_quota(quota_module, identity: dict, result=None, meter=None) -> bool:
    """التسوية الوحيدة لخصم الطلب: تثبيت إن وقع model call، وإلا refund.

    التذكرة داخل `identity` تخص هذا الطلب، و`quota.asettle` تمنع التسوية
    المكررة من ردّ حصة طلب آخر. إن كان الناتج قاموساً نخبر العميل بالردّ.
    """
    active_meter = meter if meter is not None else current()
    refunded = await quota_module.asettle(
        identity.get("_quota_reservation"),
        billable=not was_free(active_meter),
    )
    if refunded and isinstance(result, dict):
        result["quota_refunded"] = True
    return refunded
