# -*- coding: utf-8 -*-
"""📄 مسارات البثّ الثلاثة

    جزءٌ من [api.py] — فُصل 2026-09-20 بأمر المالك: «كل قسمٍ في
    ملفٍ لحاله… أهمُّ شيء يكون نفس اللوجيك نفس كل شيء».
    والنصُّ أدناه **منقولٌ حرفاً بحرف** بلا تغيير سطرٍ واحد.

    ⚠️ يُستورد من `api.py` **في موضعه من الترتيب** لا في آخره:
       تسجيلُ المسارات يتبع ترتيبَ التنفيذ، والمسارُ المتداخل
       يُطابَق بالأسبقية. فنقلُ الاستيراد ينقل المسار.
"""
from __future__ import annotations

from api import (  # noqa: E402
    AI_CLIENTS, AskRequest, BackgroundTasks, Request, ScholarshipAskRequest,
    TeacherAskRequest, _ask_guards, _dispatch_and_settle, _json_response,
    app, cleanup_old_sessions, v3_billing, v3_idem, v3_image_guard,
    v3_quota, v3_sch_assistant, v3_stream, v3_teacher, v3_vision,
)
from .guards import _scholarship_guards, _teacher_guards  # noqa: E402
from .sse import _canned_payload, _sse_stream  # noqa: E402


# ══════════════════════════════════════════════════
# 🌊 `/ask/stream` — الجواب حرفاً بحرف
# ══════════════════════════════════════════════════
# 🔴 **ما يعالجه:** الطالب كان يحدّق في مؤشّر تحميل حتى ٦٠ ثانية ثم يظهر
#    النص دفعةً واحدة. وشرحُ درسٍ كامل يستغرق ٢٠–٤٠ ثانية، فالانتظار
#    الصامت هو التجربة الغالبة لا الاستثناء.
#
# ⚖️ **ونفس الحرّاس تماماً** (`_ask_guards`) — البثّ طريقةُ تسليمٍ لا بابٌ
#    جانبي. والأخطاء تُرجَع **قبل** بدء البثّ برموز HTTP الصحيحة (401 · 429
#    · 403)، لأن العميل لا يستطيع قراءة رمز الحالة بعد أن يبدأ التدفق.
#
# 🔁 **ومعالجٌ لا يعرف البثّ يعمل كما هو**: جوابه يُرسَل دفعةً واحدة في
#    حدث `done`. فالعميل واحدٌ للجميع ولا يحتاج أن يعرف أيّ مادةٍ محوَّلة.

@app.post("/ask/stream")
async def ask_stream(req: AskRequest, background_tasks: BackgroundTasks,
                     request: Request):
    background_tasks.add_task(cleanup_old_sessions)

    identity, image_text, denied = await _ask_guards(req, request)
    if denied is not None:
        return denied          # ← ردٌّ عاديّ برمز حالةٍ صحيح، لا بثّ

    sink = v3_stream.StreamSink()
    v3_stream.attach(req, sink)
    return _sse_stream(
        uid=identity["uid"], request_id=req.request_id, sink=sink,
        image_text=image_text,
        runner=lambda: _dispatch_and_settle(req, identity),
        fallback={"references": [], "session_active": False},
    )


# ══════════════════════════════════════════════════
# 🌊 `/teacher/ask/stream` · `/scholarship/ask/stream`
# ══════════════════════════════════════════════════
# ⭐ **البثّ في كل مكان** (قرار المالك 2026-09-09): الشاشة واحدة في التطبيق،
#    فلا سبب لأن يبثّ قسمُ الطالب ويتجمّد قسما المعلّم والمنح. والمعالجان
#    كانا يقرآن المصرف أصلاً — الناقص كان المسارَين وحدهما.

@app.post("/teacher/ask/stream")
async def teacher_ask_stream(req: TeacherAskRequest, request: Request):
    identity, denied = await _teacher_guards(req, request)
    if denied is not None:
        return denied

    image_text = ""
    if req.all_images():
        try:
            extracted = []
            for img in req.all_images():
                clean, mime = v3_image_guard.validate(img)
                extracted.append(await v3_vision.image_to_text(clean, mime, AI_CLIENTS))
        except (v3_image_guard.ImageRejected, v3_vision.VisionFailed) as e:
            await v3_billing.settle_quota(v3_quota, identity)
            v3_idem.abandon(identity["uid"], req.request_id)
            return _json_response({"answer": str(e), "references": [],
                                   "session_active": False}, 200)
        req.content = v3_vision.merge_into_question(extracted, req.content)
        image_text = v3_vision.history_text(extracted)
        req.images_base64 = None
        req.image_base64 = None

    sink = v3_stream.StreamSink()
    v3_stream.attach(req, sink)

    async def _run():
        result = None
        try:
            result = await v3_teacher.ask(req, AI_CLIENTS)
        except v3_teacher.TeacherError as e:
            # رسالة عربية جاهزة — تُعرض في الفقاعة كردٍّ لا كعطل شبكة.
            result = {"answer": str(e), "references": [], "session_active": False}
        finally:
            await v3_billing.settle_quota(v3_quota, identity, result)
        return result

    return _sse_stream(
        uid=identity["uid"], request_id=req.request_id, sink=sink,
        image_text=image_text, runner=_run,
        fallback={"references": [], "session_active": False},
    )


@app.post("/scholarship/ask/stream")
async def scholarship_ask_stream(req: ScholarshipAskRequest, request: Request):
    identity, sch, denied, canned = await _scholarship_guards(req, request)
    if denied is not None:
        return denied

    # ⚡ ويمرّ بقناة البثّ لا بردٍّ عاديّ: العميل لا يقرأ JSON هنا إلا عند
    #    خطأ، فردٌّ بحالة 200 كان سيصله فارغاً.
    if canned is not None:
        sink = v3_stream.StreamSink()
        return _sse_stream(
            uid=identity["uid"], request_id=req.request_id, sink=sink,
            runner=lambda: _canned_payload(canned), fallback={"ok": True})

    question = req.question
    image_text = ""
    if req.all_images():
        try:
            extracted = []
            for img in req.all_images():
                clean, mime = v3_image_guard.validate(img)
                extracted.append(await v3_vision.image_to_text(clean, mime, AI_CLIENTS))
        except (v3_image_guard.ImageRejected, v3_vision.VisionFailed) as e:
            v3_idem.abandon(identity["uid"], req.request_id)
            return _json_response({"answer": str(e), "ok": False}, 200)
        question = v3_vision.merge_into_question(extracted, req.question)
        image_text = v3_vision.history_text(extracted)
        req.images_base64 = None
        req.image_base64 = None

    if not (question or "").strip():
        v3_idem.abandon(identity["uid"], req.request_id)
        return _json_response(
            {"answer": "اكتب سؤالك عن المنحة أو أرفق صورة 😊", "ok": False}, 200)

    sink = v3_stream.StreamSink()
    return _sse_stream(
        uid=identity["uid"], request_id=req.request_id, sink=sink,
        image_text=image_text,
        runner=lambda: v3_sch_assistant.ask(
            sch, question, req.chat_history, AI_CLIENTS, sink=sink),
        fallback={"ok": True},
    )


