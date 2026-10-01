# -*- coding: utf-8 -*-
"""🆓 طلباتٌ من البيانات وحدها — لا تمرّ بمعاملتَي الحصة (٢٠٢٦-١٠-٠١).

شكوى المالك: «الوزاري كان سريع جداً، الآن يتأخر». القياسُ في المحاكي: الأسئلةُ
من الملف في ٤ مللي ثانية، ثم **حجزُ الحصة (~٢ث) وردُّها (~٢٫٧ث)** في Firestore
لطلبٍ لم يكلّف شيئاً — والجوابُ محبوسٌ حتى يعود الردّ ([api._dispatch_and_settle]).

⚖️ فيُؤجَّل الحجز لا يُلغى: ما نادى موديلاً على غير المتوقَّع يُخصم بعده
   ([settle_deferred]) — فخطأُ التصنيف هنا لا يفتح الفاتورة.
"""
from __future__ import annotations

from . import billing
from .curriculum import uses_math_branches

# أوامرُ الجلسة في كل وزاري: متابعةٌ أو إيقاف — من الجلسة لا من موديل.
WAZARI_CONTROL = {"كمل", "نعم", "متابعة", "استمر", "وقف", "خلاص", "شكرا", "إلغاء"}


def data_only(req) -> bool:
    """هل يُجاب هذا الطلب من ملفات الوزاري وحدها بلا نداء موديل؟

    🔍 مُتحقَّقٌ في معالجات المواد الستّ: جلبُ الوزاري ومتابعتُه وإيقافُه
       بياناتٌ خالصة. والاستثناءُ الوحيد **سؤالٌ حرّ عن أسئلة الرياضيات
       المعروضة** ([subjects/math.handle_math_exams] §٤) — يُنادي موديلاً.
    """
    if req.mode != "وزاري" or req.all_images():
        return False
    text = (req.content or "").strip()
    if text in WAZARI_CONTROL:
        return True
    if uses_math_branches(req.subject, req.grade, req.track):
        return len(text.split("|")) == 3          # سنة|درس|عدد
    return "|" in text or "," in text             # زرُّ الجلب في بقية المواد


def defer(identity: dict) -> dict:
    """يُعلِّم الطلبَ مؤجَّلَ الحجز ويفتح عدّادَه — بدل `areserve`."""
    identity["_quota_reservation"] = None
    identity["_quota_deferred"] = True
    billing.start(identity.get("uid", ""), "ask")
    return identity


async def settle(quota_module, identity: dict, result, meter) -> None:
    """تسويةُ كل طلب ([api._dispatch_and_settle]) — موضعٌ واحد للمسارين.

    المحجوزُ بـ[billing.settle_quota] كما كان: يوسم القاموس إن رُدّت الحصة،
    والاستثناءُ قبل أي نداء موديل يُسوّى هنا أيضاً بدل أن يترك خصماً يتيماً.
    والمؤجَّلُ: بلا موديل ⇒ لا خصم أصلاً (والعميلُ لا يُنقص عدّاده)، ومع
    موديلٍ على غير المتوقَّع ⇒ يُخصم الآن كأيّ سؤال."""
    if not identity.get("_quota_deferred"):
        await billing.settle_quota(quota_module, identity, result, meter)
    elif billing.was_free(meter):
        if isinstance(result, dict):
            result["quota_refunded"] = True
    else:
        await quota_module.areserve(identity["uid"], identity["is_guest"])
