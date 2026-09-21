# -*- coding: utf-8 -*-
"""📄 حرّاس المعلّم والمنح

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    Request, _authenticate, _json_response, _section_gate, v3_idem,
    v3_quota, v3_ratelimit, v3_sch_facts, v3_scholarships,
)


# ══════════════════════════════════════════════════
# 🛂 حرّاس المعلّم والمنح — **مصدرٌ واحد لمساري كلٍّ منهما**
# ══════════════════════════════════════════════════
# ⚠️ نفس سبب `_ask_guards`: صار لكلٍّ منهما مساران (عادي وبثّ)، ونسخُ
#    سلسلة الحرّاس بينهما يعني حارساً يُنسى في أحدهما فيصير باباً خلفياً.

async def _teacher_guards(req, request: Request):
    """يعيد `(identity, error_response)`."""
    identity, auth_error = await _authenticate(request, req)
    if auth_error is not None:
        return None, auth_error

    if not v3_ratelimit.check(request, identity["uid"]):
        return None, _json_response(
            {"answer": v3_ratelimit.RATE_LIMIT_MESSAGE}, 429)

    # 👨‍🏫 **لا حارس أقسامٍ ولا حارس دور** ([35§3][35§7]): «مساعد المعلم» صار
    #    تطبيق المعلّم كلَّه لا قسماً فيه، والزائر يجرّب أدواته قبل أن يسجّل.
    #    والفاتورة تحرسها الحصةُ أدناه وتحديدُ المعدل أعلاه.

    state, cached = v3_idem.begin(identity["uid"], req.request_id)
    if state == v3_idem.DONE and cached is not None:
        return identity, _json_response(cached)
    if state == v3_idem.RUNNING:
        return identity, _json_response(
            {"answer": v3_idem.IN_FLIGHT_MESSAGE, "references": [],
             "session_active": False, "in_flight": True}, 202)

    allowed, _ = await v3_quota.acheck_and_consume(identity["uid"], identity["is_guest"])
    if not allowed:
        v3_idem.abandon(identity["uid"], req.request_id)
        return identity, _json_response(
            {"answer": v3_quota.message_for(identity["is_guest"]), "references": [],
             "session_active": False, "quota_exceeded": True,
             "is_guest": identity["is_guest"]}, 429)

    return identity, None


async def _scholarship_guards(req, request: Request):
    """يعيد `(identity, scholarship, error_response, canned_answer)`.

    ⚡ و`canned_answer` جوابٌ من بطاقة المنحة بلا موديلٍ ولا حصة — العلّةُ
       والحدودُ في [core/scholarship_facts]. وهو هنا لا في نقطتَي النهاية
       لأنهما تتقاسمان هذا الحارس، فالقرارُ موضعٌ واحدٌ لا يُنسى في أحدهما.
    """
    identity, auth_error = await _authenticate(request, req)
    if auth_error is not None:
        return None, None, auth_error, None

    if not v3_ratelimit.check(request, identity["uid"],
                              v3_ratelimit.VOICE_LIMIT, v3_ratelimit.VOICE_WINDOW):
        return None, None, _json_response(
            {"answer": v3_ratelimit.RATE_LIMIT_MESSAGE}, 429), None

    blocked = await _section_gate("scholarships", identity)
    if blocked is not None:
        return identity, None, blocked, None

    try:
        sch = v3_scholarships.get_public(req.scholarship_id)
    except v3_scholarships.ScholarshipError as e:
        return identity, None, _json_response(
            {"answer": str(e), "ok": False}, 404), None

    # ⚡ هل يجيبه ملفُّ المنحة نفسُه؟ يُحسب **قبل** الحجز والحصة.
    canned = v3_sch_facts.answer_for(
        sch, getattr(req, "question", "") or "", has_image=bool(req.all_images()))

    state, cached = v3_idem.begin(identity["uid"], req.request_id)
    if state == v3_idem.DONE and cached is not None:
        return identity, sch, _json_response(cached), None
    if state == v3_idem.RUNNING:
        return identity, sch, _json_response(
            {"answer": v3_idem.IN_FLIGHT_MESSAGE, "ok": False}, 202), None

    if canned is None:
        allowed, _ = await v3_quota.acheck_and_consume(identity["uid"],
                                                       identity["is_guest"])
        if not allowed:
            v3_idem.abandon(identity["uid"], req.request_id)
            return identity, sch, _json_response(
                {"answer": v3_quota.message_for(identity["is_guest"]),
                 "quota_exceeded": True, "is_guest": identity["is_guest"],
                 "ok": False}, 429), None

    return identity, sch, None, canned


