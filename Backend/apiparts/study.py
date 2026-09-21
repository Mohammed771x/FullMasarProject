# -*- coding: utf-8 -*-
"""📄 الدرس المخزون واختبر نفسك والصوت

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    AI_CLIENTS, JSONResponse, QuizRequest, Request, VoiceCleanRequest,
    _authenticate, _json_response, _section_gate, app, v3_curriculum,
    v3_idem, v3_lesson_cache, v3_quiz, v3_quota, v3_ratelimit,
    v3_voice_clean,
)


# ══════════════════════════════════════════════════
# ⚡ `/lesson/explanation` — الشرحُ المخزون وحده، بلا موديل
# ══════════════════════════════════════════════════
#
# 🔴 **علّةُ المالك (2026-09-16):** «لما أضغط شرح المفروض على طول يطلع لي
#    الشرح، ما ينتظر ثانيتين ولا ثلاثة — كما قسم الوزارة.»
#
# ⚖️ والشرحُ يُقرأ من القرص في **مللي ثانيةٍ واحدة** (قياسٌ مباشر). الانتظارُ
#    كان في الطريق لا في الجواب: رحلةُ شبكةٍ من الجهاز، ثم حرّاسُ `/ask`،
#    ثم **خصمُ الحصة من Firestore ثم ردُّها** — معاملتان عبر الشبكة لطلبٍ
#    لم يكلّف شيئاً أصلاً (تسويةُ الحصة في مسار `/ask`).
#
# 🎯 **فليُسحب قبل أن يُطلب**: التطبيق ينادي هذه النقطة لحظةَ اختيار الدرس،
#    فتصير ضغطةُ «اشرح لي» عرضاً فورياً بلا رحلةِ شبكةٍ أصلاً.
#
# 🔒 **ولا موديلَ فيها بحال**: مخزونٌ أو `found: false`. فلا حصةَ تُخصم ولا
#    فاتورةَ تُصرف مهما تكرّر النداء — ولهذا يصحّ سحبُها مسبقاً.
#    ومن لا شرحَ مخزونَ لدرسه يمضي في `/ask` إلى الموديل كما كان تماماً
#    (نصُّ المالك: «أي مادة ما شي شرح فيها، الشرح يروح للموديل ويرجع»).

@app.get("/lesson/explanation")
async def lesson_explanation(request: Request, subject: str, lesson: str,
                             unit: str = "", grade: int = 3, track: str = "علمي"):
    if not v3_ratelimit.check(request, "content", v3_ratelimit.CONTENT_LIMIT,
                              v3_ratelimit.CONTENT_WINDOW):
        return JSONResponse(status_code=429,
                            content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})
    g, t = v3_curriculum.normalize_grade_track(grade, track)
    subject = subject.strip()
    if not v3_curriculum.is_valid_subject(g, t, subject):
        return JSONResponse(status_code=404,
                            content={"answer": "❌ مادة غير معروفة لهذا الصف"})
    answer = v3_lesson_cache.stored_for(g, t, subject, unit, lesson)
    return {"found": bool(answer), "answer": answer or "",
            "subject": subject, "unit": unit.strip(), "lesson": lesson.strip()}


@app.post("/quiz/generate")
async def quiz_generate(req: QuizRequest, request: Request):
    """🧠 «اختبر نفسك»: أسئلة اختيار من متعدد **من نصّ دروس الطالب وحدها**.

    الأسئلة لا تُخزَّن — تُولَّد وتُستهلك ([03§5]). المحفوظ هو النتيجة فقط.
    """
    identity, auth_error = await _authenticate(request, req)
    if auth_error is not None:
        return auth_error

    if not v3_ratelimit.check(request, identity["uid"],
                              v3_ratelimit.VOICE_LIMIT, v3_ratelimit.VOICE_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})

    blocked = await _section_gate("quiz", identity, req.grade, req.track)
    if blocked is not None:
        return blocked

    # 🧾 إعادةُ المحاولة بعد مهلةٍ لا تولّد اختباراً ثانياً ولا تخصم مرتين.
    state, cached = v3_idem.begin(identity["uid"], req.request_id)
    if state == v3_idem.DONE and cached is not None:
        return cached
    if state == v3_idem.RUNNING:
        return _json_response({"answer": v3_idem.IN_FLIGHT_MESSAGE, "questions": []}, 202)

    # 🎟️ الاختبار نداء واحد للموديل ⇒ يُحتسب من الحصة كسؤال واحد.
    #    الزائر يجرّبه ضمن أسئلته الخمس (قرار المالك) — وهو أقوى دعوة للتسجيل.
    allowed, _ = await v3_quota.acheck_and_consume(identity["uid"], identity["is_guest"])
    if not allowed:
        v3_idem.abandon(identity["uid"], req.request_id)
        return _json_response(
            {"answer": v3_quota.message_for(identity["is_guest"]),
             "quota_exceeded": True, "is_guest": identity["is_guest"]}, 429)

    try:
        result = await v3_quiz.generate(
            req.grade, req.track, req.subject, req.unit, req.lessons,
            req.count, AI_CLIENTS, seen=req.seen_ids)
        # 💳 **واختبارٌ من البنك لا يكلّف نداءً ⇒ تُردّ حصّتُه** — نفسُ قاعدةِ
        #    الشرح المخزون ([core/billing.py] · قرار المالك 2026-09-14:
        #    «خلّ الرفض ما يخصم من الحصة»). والعميلُ يُخبَر ليصحّح عدّاده.
        if isinstance(result, dict) and result.get("cached"):
            await v3_quota.arefund(identity["uid"], identity["is_guest"])
            result["quota_refunded"] = True
    except v3_quiz.QuizError as e:
        v3_idem.abandon(identity["uid"], req.request_id)
        return _json_response({"answer": str(e), "questions": []}, 200)
    except Exception:
        v3_idem.abandon(identity["uid"], req.request_id)
        raise

    v3_idem.finish(identity["uid"], req.request_id, result)
    return result


@app.post("/voice/clean")
async def voice_clean(req: VoiceCleanRequest, request: Request):
    """🎤 تنظيف نص التسجيل الصوتي (إملاء + ترتيب) قبل عرضه للطالب.
    لا يجيب على الأسئلة — تصحيح نص فقط، والفشل يرجع النص الخام."""
    # نفس بوابة /ask: توكن Firebase أولاً ثم الكود (مرحلة انتقالية)
    identity, auth_error = await _authenticate(request, req)
    if auth_error is not None:
        return auth_error

    if not v3_ratelimit.check(request, identity["uid"],
                              v3_ratelimit.VOICE_LIMIT, v3_ratelimit.VOICE_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})

    return await v3_voice_clean.clean(req.text, AI_CLIENTS, req.subject)


