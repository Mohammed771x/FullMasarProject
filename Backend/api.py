# main.py
"""
الملف الرئيسي - نقطة الدخول الأساسية
استدعاءات فقط - بدون logic
"""

from contextlib import asynccontextmanager

from fastapi import FastAPI, Response, Request, BackgroundTasks, UploadFile, File, Form
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse, HTMLResponse, StreamingResponse
from fastapi.middleware.cors import CORSMiddleware
import base64
import json
import os
from typing import Dict, Any
import asyncio
import concurrent.futures

# =====================
# الاستيرادات
# =====================

# من الإعدادات والنماذج
from config import GROQ_API_KEY, BASE_SUBJECTS_DIR, SUBJECT_NAMES, DEEPSEEK_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY
from models import (AskRequest, VoiceCleanRequest, QuizRequest,
                    AdminBanRequest, AdminQuotaRequest,
                    ScholarshipAskRequest, ScholarshipUpsertRequest,
                    ScholarshipEnabledRequest, ScholarshipReorderRequest,
                    ScholarshipPromptRequest, ScholarshipTryRequest,
                    ScholarshipCoverRequest, AdminSettingsRequest, AvatarRequest,
                    BannerRequest, BannerTemplatesRequest,
                    TeacherAskRequest, TeacherPromptRequest, TeacherTryRequest,
                    AccessSectionRequest, AccessRulesRequest,
                    NotificationPreviewRequest, NotificationCreateRequest,
                    DeviceTokenRequest)

# من المواد
from subjects.biology import handle_biology_request
from subjects.chemistry import handle_chemistry_request
from subjects.physics import handle_physics_request
from subjects.math import handle_math_request
from subjects.chemistry import handle_chemistry_request
from subjects.arabic import handle_arabic_request
from subjects.english import handle_english_request
# من common (للـ helper functions)
from subjects.common import (
    subject_book_path, load_json_safe,
    get_math_exam_years, get_math_exam_lessons,
    strip_stray_latex as _polish_text,
)
from subjects import common as v3_common
from subjects.math import handle_math_request, cleanup_old_sessions

# ── طبقة النسخة الثالثة (تُضاف بجانب القديم — لا تبدله) ──
from core import curriculum as v3_curriculum
from core import capabilities as v3_capabilities
from core import lesson_cache as v3_lesson_cache
from core import lesson_mode as v3_lesson_mode
from core import pages_mode as v3_pages_mode
from core import ratelimit as v3_ratelimit
from core import voice_clean as v3_voice_clean
from core import image_guard as v3_image_guard
from core import vision as v3_vision
from core import firebase_auth as v3_auth
from core import quota as v3_quota
from core import billing as v3_billing
from core import smalltalk as v3_smalltalk
from core import user_state as v3_user_state
from core import idempotency as v3_idem
from core import streaming as v3_stream
from core import admin as v3_admin
from core import audience as v3_audience
from core import analytics as v3_analytics
from core import access as v3_access
from core import notifications as v3_notify
from core import push as v3_push
from core import ingest as v3_ingest
from core import index_store as v3_index_store
from core import warmup as v3_warmup
from core import quiz as v3_quiz
from core import media_store as v3_media
from core import banners as v3_banners
from core import scholarships as v3_scholarships
from core import scholarship_assistant as v3_sch_assistant
from core import scholarship_facts as v3_sch_facts
from core import teacher_assistant as v3_teacher
from core import teacher_prompts as v3_teacher_prompts

# ── معالجات المواد الجديدة (ملف مستقل لكل مادة ببرومبتاته الخاصة) ──
from subjects.history import handle_history_request
from subjects.geography import handle_geography_request
from subjects.society import handle_society_request
from subjects.economics import handle_economics_request
from subjects.sociology import handle_sociology_request
from subjects.philosophy import handle_philosophy_request
from subjects.logic import handle_logic_request
from subjects.cartography import handle_cartography_request

# خريطة: اسم المادة → معالجها المستقل
NEW_SUBJECT_HANDLERS = {
    "تاريخ": handle_history_request,
    "جغرافيا": handle_geography_request,
    "مجتمع": handle_society_request,
    "علم الاقتصاد": handle_economics_request,
    "علم الاجتماع": handle_sociology_request,
    "فلسفة": handle_philosophy_request,
    "منطق": handle_logic_request,
    "مبادئ علم الخرائط": handle_cartography_request,
}

# من المكتبات الخارجية
from openai import AsyncOpenAI  # التعديل هنا مهم جداً
from groq import AsyncGroq      # التعديل هنا مهم جداً
from dotenv import load_dotenv

# =====================
# تحميل الإعدادات
# =====================
load_dotenv(override=True)






# =====================
# زيادة مسارات المعالجة (Threads) لمنع التجمد
# =====================
executor = concurrent.futures.ThreadPoolExecutor(
    max_workers=8,
    thread_name_prefix="worker"
)
loop = asyncio.get_event_loop()
loop.set_default_executor(executor)



# =====================
# إنشاء التطبيق
# =====================
@asynccontextmanager
async def lifespan(app: FastAPI):
    """🔥 عند الإقلاع: تُبنى/تُحمَّل كل فهارس FAISS مسبقاً في خيط خلفي،
    فلا يبني طالبٌ فهرساً أثناء سؤاله ([ADR-012] · core/warmup.py).
    الخادم يستقبل الطلبات فوراً — الإحماء لا يحجبه."""
    v3_warmup.start_background()
    yield


app = FastAPI(title="YE - Pro Student Tutor v2", lifespan=lifespan)

@app.api_route("/", methods=["GET", "HEAD"])
async def root():
    return {"status": "ok", "message": "Masar Server is alive and running!"}



# ══════════════════════════════════════════════════
# 🌐 CORS — قائمةُ سماحٍ لا نجمة
# ══════════════════════════════════════════════════
# 🔴 كان `allow_origins=["*"]` مع `allow_credentials=True`، وهو **تركيبٌ
#    غير صالح أصلاً** (المتصفحات ترفض الاعتماد مع النجمة) وفوق ذلك يفتح
#    الـAPI لأي موقعٍ في العالم ينادينا من متصفح الطالب.
#
# 📱 وتضييقه **لا يمسّ التطبيق إطلاقاً**: CORS سياسةُ متصفحاتٍ وحدها،
#    وطلبات أندرويد/iOS لا تمرّ بها. المتأثر هو نسخة الويب فقط.
#
# ⚙️ للإضافة بلا لمس كود: `CORS_ORIGINS=https://a.com,https://b.com`
_DEFAULT_ORIGINS = [
    "http://localhost:8000", "http://127.0.0.1:8000",
    "http://localhost:5000", "http://127.0.0.1:5000",
]
_env_origins = [o.strip() for o in os.getenv("CORS_ORIGINS", "").split(",") if o.strip()]

app.add_middleware(
    CORSMiddleware,
    allow_origins=_env_origins or _DEFAULT_ORIGINS,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allow_headers=["Content-Type", "Authorization", "X-Admin-Key",
                   "ngrok-skip-browser-warning"],
)

# =====================
# إعداد Clients
# =====================


groq_client = AsyncGroq(api_key=GROQ_API_KEY)

# 👇 أضف عميل ديب سيك هنا
deepseek_client = AsyncOpenAI(
    base_url="https://api.deepseek.com",
    api_key=DEEPSEEK_API_KEY,
    timeout=60.0
)


gemini_client = AsyncOpenAI(
    api_key=GEMINI_API_KEY,
    base_url="https://generativelanguage.googleapis.com/v1beta/openai/",
    timeout=60.0
)

openai_client = AsyncOpenAI(
    api_key=OPENAI_API_KEY,
    timeout=60.0
)

# سجل العملاء لمعالجات النسخة الثالثة (توجيه الموديل حسب المادة)
AI_CLIENTS = {"gemini": gemini_client, "openai": openai_client, "deepseek": deepseek_client}

# ══════════════════════════════════════════════════
# 📋 أخطاء التحقق (422) → رسالة عربية تسمّي الحقل
# ══════════════════════════════════════════════════
# ⚠️ **علّة واجهة حقيقية:** FastAPI يرد على خطأ التحقق بـ
#    `{"detail":[{"loc":[...],"msg":"..."}]}`، واللوحة تقرأ `error` وحده،
#    فكان الأدمن يرى «خطأ 422» بلا أي دلالة على الحقل المعطوب — ويبقى
#    يخمّن. التحويل هنا يفيد **كل** عميل لا اللوحة وحدها.

_FIELD_LABELS = {
    "id": "المعرّف", "name": "اسم المنحة", "country": "الدولة",
    "flag": "علم الدولة", "cover_url": "رابط صورة الغلاف",
    "logo_url": "رابط الشعار", "website": "الموقع الرسمي",
    "short_desc": "الوصف القصير", "about": "نبذة عن المنحة",
    "requirements": "الشروط والمتطلبات", "how_to_apply": "خطوات التقديم",
    "benefits": "المزايا", "documents": "الوثائق المطلوبة",
    "fields": "المجالات", "degree_levels": "المراحل الدراسية",
    "open_date": "فتح التقديم", "close_date": "إغلاق التقديم",
    "funding_type": "نوع التمويل", "gradient": "ألوان التدرّج",
    "enabled": "الظهور", "order": "ترتيب العرض",
    "assistant_prompt": "تعليمات المنحة", "question": "السؤال",
    "scholarship_id": "معرّف المنحة",
}

_ERROR_HINTS = {
    "string_too_long": "أطول من المسموح",
    "string_too_short": "أقصر من المسموح",
    "missing": "مطلوب ولم يصل",
    "int_parsing": "يجب أن يكون رقماً",
    "bool_parsing": "يجب أن يكون نعم/لا",
    "list_type": "يجب أن يكون قائمة",
    "string_type": "يجب أن يكون نصاً",
}


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    parts = []
    for err in exc.errors()[:4]:            # أربعة تكفي؛ الباقي ضوضاء
        loc = [str(x) for x in err.get("loc", []) if x not in ("body", "query")]
        field = loc[0] if loc else ""
        label = _FIELD_LABELS.get(field, field or "أحد الحقول")
        hint = _ERROR_HINTS.get(err.get("type", ""), err.get("msg", ""))
        limit = (err.get("ctx") or {}).get("max_length")
        parts.append(f"«{label}» {hint}" + (f" (الحد {limit} حرفاً)" if limit else ""))

    message = "❌ " + " · ".join(parts) if parts else "❌ بيانات غير صالحة."
    return _json_response({"error": message, "answer": message}, 422)


@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    """
    هذا الدرع يضمن أنه مهما حدث خطأ برمجي أو انهيار في أي ملف،
    السيرفر لن يرسل HTML للتطبيق، بل سيرسل JSON نظيف ومحترم.
    """
    # هنا يمكنك إضافة مكتبة Sentry لاحقاً لتسجيل الأخطاء لك كمدير
    print(f"🔥 FATAL ERROR: {exc}") 
    return JSONResponse(
        status_code=500,
        content={
            "answer": "⚠️ عذراً، حدث ضغط مفاجئ أو خطأ في خوادم الذكاء الاصطناعي. جاري العمل على حل المشكلة، حاول مجدداً بعد قليل.",
            "session_active": False
        }
    )
    
    
# ==================================================
# 🔐 بوابة التوثيق — توكن Firebase وحده
# ==================================================
# 🗑️ **نظام أكواد التفعيل حُذف بالكامل** (قرار المالك · 2026-09-08). وما كان
#    يبدو «مساراً انتقالياً» كان في الحقيقة أخطر ثغرة في المنصّة:
#      • `SUPER_USER` كان مدفوناً في التطبيق ويُرسل مع كل طلب، ونوعه
#        `master` ⇒ بلا ربط جهاز ⇒ يعمل على أي عدد من الأجهزة.
#      • ومَن دخل به كان `legacy: True`، وكل مسارٍ يستهلك موديلاً كان
#        مكتوباً فيه `if not identity.get("legacy")` ⇒ **بلا حصة، بلا حظر،
#        بلا تحقق بريد، بلا Firebase أصلاً.**
#      • واستخراجه لا يحتاج أكثر من `strings` على الـAPK — والتشويش
#        (`--obfuscate`) لا يخفي النصوص الثابتة.
#    فلم يكن الباب موارباً بل مفتوحاً على فاتورة الموديلات كلها.
#
# ⚖️ والآن: **لا هوية إلا من توكن موقَّع من جوجل.** لا بديل ولا استثناء ولا
#    مفتاح بيئةٍ يعيد فتحه — الطريق الوحيد للعودة هو كتابة كودٍ جديد عن قصد،
#    لا نسيانُ متغيّرٍ مضبوطٍ على "1".


def _attach_image_text(result, image_text: str):
    """يُرفق نص الصورة المستخرج بأي رد — قاموساً كان أو Response جاهزاً.

    ⭐ **لماذا:** تاريخ المحادثة نصٌّ لا صور. فإن لم يعرف العميل ما قرأه
       الخادم في الصورة، ضاع محتواها من السؤال التالي وصار المساعد يجيب
       عن سؤال متابعة بلا سياق. وهذا أيضاً ما يُبقي المحادثة مفهومة على
       جهاز جديد حيث لم تعد الصورة موجودة أصلاً ([27§3]).
    """
    if not image_text:
        return result
    if isinstance(result, dict):
        result["extracted_text"] = image_text
        return result
    # Response جاهز: نفك JSON ونعيد بناءه (نادر — المسارات القديمة فقط)
    body = getattr(result, "body", None)
    if body:
        try:
            payload = json.loads(body)
            if isinstance(payload, dict):
                payload["extracted_text"] = image_text
                return _json_response(payload, result.status_code)
        except (ValueError, TypeError):
            pass
    return result


def _json_response(payload: dict, status: int = 200):
    return Response(content=json.dumps(payload, ensure_ascii=False),
                    status_code=status, media_type="application/json")


def _remember(uid: str, request_id: str, result):
    """يحفظ الجواب للإعادة — أو يُحرِّر الحجز إن تعذّر تحويله لقاموس.

    ⚠️ تخزينُ `None` كان سيحبس الطالب على «امهل لحظات» حتى تنقضي المهلة؛
       والتحرير يعيده إلى السلوك القديم (نداءٌ جديد) وهو الأسوأ المقبول.
    """
    payload = _as_payload(result)
    if payload is None:
        v3_idem.abandon(uid, request_id)
        return
    v3_idem.finish(uid, request_id, payload)


def _as_payload(result):
    """يحوّل ناتج أي معالج إلى قاموسٍ صالحٍ للتخزين في `idempotency`.

    ⚠️ لازمٌ لأن المعالجات ترجع خليطاً: بعضها قاموساً وبعضها `Response`
       مبنيّاً. وتخزينُ كائن `Response` كان سيُعيد **نفس الجسم المستهلَك**
       في المحاولة الثانية.
    """
    if isinstance(result, dict):
        return result
    body = getattr(result, "body", None)
    if body:
        try:
            parsed = json.loads(body)
            if isinstance(parsed, dict):
                return parsed
        except (ValueError, TypeError):
            pass
    return None


async def _authenticate(request, req=None):
    """يعيد `(identity, error_response)` — **التوكن هو المصدر الوحيد للهوية**.

    `identity = {uid, email, provider, is_guest, name, email_verified}`

    🔐 وقبل الخروج تُكتب الهويةُ **فوق** `req.user_id` إن وُجد الحقل. وهذه
       ليست تفصيلة: معالجات المواد تُمفتِح جلساتها به
       (`sessions_math[req.user_id]` وأخواتها في فيزياء/كيمياء/أحياء/عربي/
       إنجليزي)، وكان يصل **من جسم الطلب**. فمن عرف `user_id` طالبٍ آخر
       قرأ جلسته وكتب فيها — أسئلةَ وزاريّه وحالةَ شرحه. الكتابة هنا تُغلق
       ذلك في نقطةٍ واحدة بدل تعديل ستة ملفات، ولا يمكن نسيانها في مسار.

    ⚡ وكلُّ قراءةٍ شبكية هنا في خيطٍ جانبي (`aget`) — لا تحجب حلقة الأحداث.
    """
    token = v3_auth.bearer_token(request)
    if not token:
        return None, _json_response(
            {"answer": "⛔ الرجاء تسجيل الدخول أولاً.", "session_active": False}, 401)

    try:
        ident = v3_auth.verify(token)
    except v3_auth.AuthError as e:
        return None, _json_response({"answer": str(e), "session_active": False}, 401)

    if v3_auth.requires_verified_email(ident):
        return None, _json_response(
            {"answer": "📧 فعّل بريدك أولاً: افتح رابط التحقق المُرسل إليك ثم أعد المحاولة.",
             "session_active": False}, 403)

    uid = ident.get("uid", "")

    # 🚫 الحظر يُفرض هنا — عند أول طلب، لا في اللوحة وحدها.
    state = await v3_user_state.aget(uid)
    if state.get("banned"):
        return None, _json_response(
            {"answer": "⛔ حسابك موقوف. راسل الدعم إن كنت ترى هذا خطأً.",
             "session_active": False}, 403)

    if req is not None and hasattr(req, "user_id"):
        req.user_id = uid

    return ident, None


# ==================================================
# 🔐 حارس الأقسام — قاعدة اللوحة تُفرض هنا لا في الواجهة
# ==================================================
# ⭐ إخفاء الزرّ في التطبيق راحةٌ للطالب لا حاجزٌ أمامه: من يعرف الرابط
#    يتخطّاه. فالقاعدة تُفرض على **المسار العامل** — وهذه هي الطبقة الوحيدة
#    التي تُحتسب حمايةً.
# ⚠️ والصفّ يُؤخذ من `users/{uid}` لا من جسد الطلب: لو صُدِّق الطلبُ لكفى
#    الطالبَ أن يكتب صفّاً آخر ليتخطّى الإخفاء.
# 🛟 ويفشل مفتوحاً: أي عطلٍ في القراءة يعني «مسموح» — نظام الإخفاء لا يجوز
#    أن يصير سبباً في تعطيل الدراسة.

async def _section_gate(section: str, identity: dict, grade=None, track: str = ""):
    """يعيد None عند السماح، أو ردَّ منعٍ جاهزاً برسالة اللوحة.

    ⚡ القراءة عبر `user_state.aget` — الإصابةُ في الكاش بلا خيطٍ أصلاً،
       والقراءةُ الفعلية في خيطٍ جانبي فلا تُجمّد الخادم لبقية الطلاب.
    """
    try:
        uid = (identity or {}).get("uid", "")
        state = await v3_user_state.aget(uid)
        prof = ({"grade": state["grade"], "track": state["track"], "role": state["role"]}
                if state.get("exists") else None)
        if prof:
            grade = prof["grade"] if prof["grade"] is not None else grade
            track = prof["track"] or track
        role = (prof or {}).get("role", "student")
        v3_access.require(section, grade, track, role)
    except v3_access.SectionBlocked as e:
        return _json_response(
            {"answer": str(e), "references": [], "session_active": False,
             "section_blocked": True, "section": section, "mode": e.mode}, 403)
    except Exception as e:
        print(f"⚠️ حارس الأقسام ({section}) — سُمح بالمرور: {e}")
    return None


# ==================================================
# 🎓 نطاق المحتوى القديم — الثالث الثانوي العلمي
# ==================================================
# المعالجات القديمة (احياء/فيزياء/كيمياء/عربي/انجليزي/رياضيات في subjects/)
# مكتوبة لهذا النطاق وحده: كتابها كاش عام بلا صف، وبنك وزاريها مسطّح.
# لذلك **لا تُستدعى أبداً لصف آخر** — يمضي الطلب في طبقة v3 المحكومة بالصف،
# وإن لم يوجد ملف لذلك الصف رد الخادم «قيد الإضافة 🚧» بدل محتوى صفٍّ آخر.
LEGACY_CONTENT_SCOPE = (3, "علمي")


def _is_legacy_content_scope(grade, track) -> bool:
    return v3_curriculum.normalize_grade_track(grade, track) == LEGACY_CONTENT_SCOPE


def _content_pending_response(subject: str, grade, track):
    """رد ودّي موحّد: لا محتوى لهذه المادة في هذا الصف بعد."""
    g, t = v3_curriculum.normalize_grade_track(grade, track)
    scope = f"الصف {'الأول' if g == 1 else 'الثاني' if g == 2 else 'الثالث'} الثانوي"
    if g != 1:
        scope += f" {t}"
    return Response(
        content=json.dumps({
            "answer": f"📁 محتوى «{subject}» لـ{scope} لم يُضف بعد 🚧\n"
                      f"جرّب مادة أخرى أو عد لاحقاً — نحن نضيف المحتوى تباعاً.",
            "references": [], "session_active": False,
        }, ensure_ascii=False),
        status_code=200, media_type="application/json")


# =====================
# API Endpoints - التحقق والأمان
# =====================

# =====================
# API Endpoints - جلب البيانات
# =====================

# ── محتوى الكتب — وحدات ودروس وامتحانات → [apiparts/content.py] ──
from apiparts.content import (  # noqa: F401,E402
    get_subject_units, get_subject_lessons, get_exam_years,
    get_exam_sections, get_math_lessons, get_math_exam_years_api,
    get_math_exam_lessons_api, health_indexes, v3_subjects, v3_caps,
)

# ── الدرس المخزون واختبر نفسك والصوت → [apiparts/study.py] ──
from apiparts.study import (  # noqa: F401,E402
    lesson_explanation, quiz_generate, voice_clean,
)

# ══════════════════════════════════════════════════
# 🧭 التوجيه حسب المادة — **دالةٌ واحدة للمسارين**
# ══════════════════════════════════════════════════
# كانت داخلية في `/ask`؛ أُخرجت كي يستعملها `/ask/stream` بنفس المنطق
# حرفياً. ونسخُها كان سيعني مادةً تُضاف لمسارٍ وتُنسى في الآخر.
async def _dispatch_ask(req):
    """يوجّه الطلب لمعالجه، ثم **يمرّ الجوابُ بلمسات الرسم مهما كان مساره**.

    🔴 **ولماذا هنا لا في كل معالج؟** لأن المعالجات ستٌّ وأوضاعُها أربعة،
       وقد أُضيف الفلتر إلى بعضها ونُسي في بعض: الأحياء (الثالث العلمي)
       تخرج بلا فلترٍ نهائيّ أصلاً، وأوضاعُ **الوزاري** كلُّها تُعيد نصّ
       الأسئلة خاماً — فكسورُ الرياضيات وصيغُ الكيمياء في الامتحانات
       الوزارية تصل الطالبَ سطوراً مسطّحة بينما يراها مرسومةً في الشرح.
       (شكوى المالك 2026-09-13: «خله في كل مكان — الشرح والتلخيص والسؤال
        وحتى الوزاري، وفي كل مادة».)

    ⚖️ والدالّة **ثابتةٌ عند التكرار** (`strip_stray_latex` تُنادى مرّتين
       فتُعطي النتيجة نفسها حرفاً بحرف — يحرسه اختبار)، فلا يضرّ أن يكون
       المعالجُ قد نادى فلترَه بنفسه.
    """
    result = await _dispatch_subject(req)
    return _polish_answer(result, req.subject)


def _polish_answer(result, subject: str):
    """يمرّر `answer` بلمسات الرسم — ويترك ما ليس قاموساً كما هو."""
    if isinstance(result, dict):
        answer = result.get("answer")
        if isinstance(answer, str) and answer:
            result["answer"] = _polish_text(answer, subject)
    return result


async def _dispatch_subject(req):
    # =====================
    # 2️⃣ معالجة الطلب حسب المادة
    # =====================
    subject = req.subject.strip()

    # 🎓 بوابة المنهج لكل المواد: مادة غير مقررة على الصف/المسار تُرفض هنا،
    #    قبل أن تلمس نظام الملفات.
    if not v3_curriculum.is_valid_subject(req.grade, req.track, subject):
        return Response(
            content=json.dumps({"answer": "❌ هذه المادة غير مقررة على صفك.", "session_active": False},
                               ensure_ascii=False),
            status_code=400, media_type="application/json")

    # 👋 **التحيةُ ليست سؤالَ منهج** — تُجاب هنا قبل أي بحثٍ أو نداء.
    #
    # 🔴 شكوى المالك (2026-09-14): «لما قلت له السلام عليكم يقول لي: لم
    #    أجد هذه المعلومة» — نتيجةٌ منطقية لعتبة الصلة، لأن السؤال المطروح
    #    كان «هل هذا في الوحدة؟» بدل «هل هذا سؤالُ منهجٍ أصلاً؟».
    #
    # ⚖️ **وبعد بوابة المنهج لا قبلها**: مادةٌ غير مقرّرة على الصف لا
    #    تُرحَّب بالطالب فيها. وهنا موضعٌ واحد يغطّي المواد الستّ والأوضاع
    #    الأربعة — ووضعُه في كل معالجٍ كان يعني معالجاً يُنسى.
    #    وبلا نداءِ موديل ⇒ لا يُخصم من الحصة ([core/billing.py]).
    # ❓ **وضعُ السؤال يحتاج سؤالاً** (قرار المالك 2026-09-14): ضغطةُ إرسالٍ
    #    بحقلٍ فارغة كانت تُولّد طلباً من عندنا فيخرج شرحُ درسٍ كامل من وضع
    #    السؤال — ويُخصم من الحصة. وهنا **موضعٌ واحد يغطّي المواد كلَّها
    #    والمسارين** (`/ask` و`/ask/stream`)، وبعد دمج نصّ الصورة في المحتوى
    #    فالسؤالُ المصوَّر يمرّ ([common.question_needs_text]).
    if v3_common.question_needs_text(req):
        return v3_common.question_required_response()

    social = v3_smalltalk.reply_for(req)
    if social is not None:
        return social

    # ── 🆕 المواد الجديدة: لكل واحدة ملف معالج مستقل ببرومبتاته ──
    if subject in NEW_SUBJECT_HANDLERS:
        return await NEW_SUBJECT_HANDLERS[subject](req, AI_CLIENTS)

    # ── 🆕 مسارا النسخة الثالثة (اختياريان — لا يمسّان التدفق القديم) ──
    # الرياضيات تبقى على معالجها الأصلي دائماً (هي وضع دروس بطبيعتها)
    if req.content_mode == "lessons" and subject != "رياضيات" and req.mode != "وزاري":
        return await v3_lesson_mode.handle(req, AI_CLIENTS)
    if req.content_mode == "pages" and subject != "رياضيات" and req.mode != "وزاري":
        # الأحياء (الثالث العلمي) لها معالجها الأصلي المجرّب — نبقيه كما هو
        if not (subject == "احياء" and req.grade == 3 and req.track == "علمي"):
            return await v3_pages_mode.handle(req, AI_CLIENTS)

    # ══════════════════════════════════════════════════════════
    # 🚧 حارس الصفوف: ما دون الثالث العلمي لا يُسلَّم للمعالجات القديمة
    # ══════════════════════════════════════════════════════════
    # (راجع LEGACY_CONTENT_SCOPE أعلاه). نحاول خدمته من طبقة v3 المحكومة
    # بالصف — وإن لم يوجد ملف لصفّه، رسالة «قيد الإضافة» لا محتوى غيره.
    if not _is_legacy_content_scope(req.grade, req.track):
        if req.mode != "وزاري":
            _g, _t = v3_curriculum.normalize_grade_track(req.grade, req.track)
            _caps = v3_capabilities.describe(_g, _t, subject)
            if _caps["lessons"]["available"]:
                return await v3_lesson_mode.handle(req, AI_CLIENTS)
            if _caps["pages"]["available"]:
                return await v3_pages_mode.handle(req, AI_CLIENTS)
        return _content_pending_response(subject, req.grade, req.track)

    # 🧬 الأحياء
    if subject == "احياء":
        return await handle_biology_request(req, gemini_client)

    # 🔬 الفيزياء
    elif subject == "فيزياء":
        return await handle_physics_request(req, v3_curriculum.client_for("فيزياء", AI_CLIENTS))

    # 🇬🇧 الإنجليزي
    elif subject == "انجليزي":
        return await handle_english_request(req, gemini_client)

    # ⚛️ الكيمياء
    elif subject == "كيمياء":
        return await handle_chemistry_request(req, v3_curriculum.client_for("كيمياء", AI_CLIENTS))
    # 📚 العربي
    elif subject == "عربي":
        return await handle_arabic_request(req, gemini_client)

    # 📐 الرياضيات
    elif subject == "رياضيات":
        return await handle_math_request(req, deepseek_client, groq_client)

    # ❌ مادة غير معروفة
    else:
        return Response(
            content=json.dumps({"answer": "❌ مادة غير معروفة"}),
            status_code=400,
            media_type="application/json"
        )


# ══════════════════════════════════════════════════
# 🛂 سلسلة حرّاس `/ask` — **مصدرٌ واحد للمسارين**
# ══════════════════════════════════════════════════
# ⚠️ `/ask` و`/ask/stream` يجب أن يمرّا بنفس الحرّاس **حرفياً**: توثيق ثم
#    معدّل ثم قسم ثم تكرار ثم حصة ثم صور. ونسخُها في مسارين كان أخطر ما
#    يمكن فعله هنا — كلُّ حارسٍ يُنسى في أحدهما يصير باباً خلفياً كاملاً
#    (وهو بالضبط ما فعله `legacy` سابقاً).
#
# تعيد `(identity, image_text, error_response)`؛ وجودُ `error_response`
# يعني توقّف — يُرجعه المسار كما هو.

async def _ask_guards(req, request: Request):
    identity, auth_error = await _authenticate(request, req)
    if auth_error is not None:
        return None, "", auth_error

    # 🚦 المفتاح = IP الحقيقي (خلف البروكسي) + هوية المستخدم.
    if not v3_ratelimit.check(request, identity["uid"]):
        return None, "", _json_response(
            {"answer": v3_ratelimit.RATE_LIMIT_MESSAGE, "session_active": False}, 429)

    # 🔐 قاعدة الوصول قبل الحصة: لا يُخصم سؤالٌ من قسمٍ مقفل أصلاً.
    blocked = await _section_gate("education", identity, req.grade, req.track)
    if blocked is not None:
        return None, "", blocked

    # 🧾 المحاولة المكرَّرة — قبل الحصة وقبل أي نداء موديل.
    #
    # 🔴 **العطل:** مهلة العميل والخادم قد لا تتطابقان، فالحصة تُخصم والجواب
    #    يضيع والطالب يعيد السؤال ⇒ خصمٌ ثانٍ وفاتورة موديلٍ ثانية عن نفس
    #    السؤال. وشبكات الطلاب متقطّعة فهذا يوميّ.
    state, cached = v3_idem.begin(identity["uid"], req.request_id)
    if state == v3_idem.DONE and cached is not None:
        return identity, "", _json_response(cached)
    if state == v3_idem.RUNNING:
        return identity, "", _json_response(
            {"answer": v3_idem.IN_FLIGHT_MESSAGE, "references": [],
             "session_active": False, "in_flight": True}, 202)

    # 🎟️ الحصة — البوابة الوحيدة على فاتورة الـAI بعد حذف الأكواد.
    reservation = await v3_quota.areserve(identity["uid"], identity["is_guest"])
    if not reservation.allowed:
        v3_idem.abandon(identity["uid"], req.request_id)
        return identity, "", _json_response(
            {"answer": v3_quota.message_for(identity["is_guest"]),
             "references": [], "session_active": False,
             "quota_exceeded": True, "is_guest": identity["is_guest"]}, 429)
    identity["_quota_reservation"] = reservation

    # 🧾 عدّادُ نداءات الموديل لهذا الطلب — عليه يقوم ردُّ الحصة إن لم
    #    يُنادَ موديلٌ أصلاً ([core/billing.py] · قرار المالك 2026-09-14).
    v3_billing.start()

    # 📷 الصورة → نص (Gemini لكل المواد) قبل أي توجيه.
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
            return identity, "", _json_response(
                {"answer": str(e), "references": [], "session_active": False}, 200)
        # النص المستخرج يحل محل محتوى الطلب، ثم يمضي المسار كالمعتاد.
        # ونحتفظ بنسختين إضافيتين: نظيفة للبحث، وأصلية لأرقام الصفحات.
        req.student_text = req.content or ""
        req.search_text = v3_vision.search_text(extracted, req.content)
        req.content = v3_vision.merge_into_question(extracted, req.content)
        # ⭐ ويعود للعميل كي **يخزّنه مع رسالة الطالب**: بدونه تُنسى الصورة
        #    في السؤال التالي، لأن التاريخ نصٌّ لا صور ([32§5]).
        image_text = v3_vision.history_text(extracted)
        # لا نمرر الصور أبعد من هنا (ذاكرة + خصوصية)
        req.image_base64 = None
        req.images_base64 = None

    return identity, image_text, None


async def _dispatch_and_settle(req, identity):
    """يوزّع الطلب، ثم **يردّ الحصة إن لم يكلّف نداءَ موديل**.

    ⚖️ موضعٌ واحد لمساري السؤال (عاديّ وبثّ): وضعُ الردّ في كلٍّ منهما
       على حدة كان يعني مساراً يُنسى — وهو بالضبط ما وقع في حرّاس الوحدة.
    """
    meter = v3_billing.current()
    result = None
    try:
        result = await _dispatch_ask(req)
        return result
    finally:
        # 📣 يوسم القاموس إن رُدّت الحصة، والاستثناء قبل أي model call يُسوّى
        # هنا أيضاً بدل أن يترك خصماً يتيمًا.
        await v3_billing.settle_quota(v3_quota, identity, result, meter)


@app.post("/ask")
async def ask(req: AskRequest, background_tasks: BackgroundTasks, request: Request):
    """🔥 المسار الرئيسي — ردٌّ واحد كامل.

    ⚠️ يبقى قائماً بعد إضافة البثّ: النسخ المنشورة تستعمله، وبوابةُ التحديث
       الإلزامي (`/app/version`) هي ما ينقلها لا حذفُ المسار من تحتها.
    """
    background_tasks.add_task(cleanup_old_sessions)

    identity, _image_text, denied = await _ask_guards(req, request)
    if denied is not None:
        return denied

    # 🧾 الجواب يُحفظ للمحاولة نفسها: إعادةٌ بنفس `request_id` ترجعه بلا
    #    نداء موديل ولا خصم. وأيُّ استثناء يُحرِّر الحجز وإلا بقي «يعمل».
    try:
        result = _attach_image_text(
            await _dispatch_and_settle(req, identity), _image_text)
    except Exception:
        v3_idem.abandon(identity["uid"], req.request_id)
        raise
    _remember(identity["uid"], req.request_id, result)
    return result




# ── حرّاس المعلّم والمنح → [apiparts/guards.py] ──
from apiparts.guards import (  # noqa: F401,E402
    _teacher_guards, _scholarship_guards,
)

# ── مولّد أحداث البثّ → [apiparts/sse.py] ──
from apiparts.sse import (  # noqa: F401,E402
    _canned_payload, _sse_stream,
)

# ── مسارات البثّ الثلاثة → [apiparts/streams.py] ──
from apiparts.streams import (  # noqa: F401,E402
    ask_stream, teacher_ask_stream, scholarship_ask_stream,
)

# ── المنح — مسارات الطالب → [apiparts/scholarship.py] ──
from apiparts.scholarship import (  # noqa: F401,E402
    _scholarships_unavailable, scholarships_list, scholarship_detail,
    scholarship_ask,
)

# ── مساعد المعلّم → [apiparts/teacher.py] ──
from apiparts.teacher import (  # noqa: F401,E402
    teacher_tools, teacher_ask,
)

# ── لوحة التحكم — مستخدمون ومنحٌ ووسائط → [apiparts/admin.py] ──
from apiparts.admin import (  # noqa: F401,E402
    _admin_gate, _admin_run, admin_overview, admin_users, admin_user_detail,
    admin_ban, admin_quota, admin_scholarships, admin_scholarship_get,
    admin_scholarship_create, admin_scholarship_update,
    admin_scholarship_enabled, admin_scholarship_reorder,
    admin_scholarship_delete, admin_scholarship_prompt_get,
    admin_scholarship_prompt_set, admin_scholarship_try, _AVATAR_SAFE,
    _avatar_key, me_avatar, admin_scholarship_cover, admin_scholarship_logo,
    scholarship_cover,
)

# ── اللافتات وبرومبتات المعلّم والإعدادات → [apiparts/banners.py] ──
from apiparts.banners import (  # noqa: F401,E402
    banners_list, admin_banners, admin_banner_create, admin_banner_update,
    admin_banner_enabled, admin_banner_delete, admin_banner_templates,
    admin_banner_templates_save, admin_teacher_prompts, admin_teacher_core,
    admin_teacher_lessons, admin_teacher_prompt_set,
    admin_teacher_prompt_try, admin_settings_get, admin_settings_set,
)

# ── التحليلات وصلاحية الأقسام → [apiparts/analytics.py] ──
from apiparts.analytics import (  # noqa: F401,E402
    admin_analytics, admin_segments, admin_access, admin_access_section,
    admin_access_rules, app_access,
)

# ── هويةُ الطالب أو 401 → [apiparts/identity.py] ──
from apiparts.identity import (  # noqa: F401,E402
    _identity_or_401,
)

# ── الحصة ونسخة التطبيق → [apiparts/quota.py] ──
from apiparts.quota import (  # noqa: F401,E402
    my_quota, app_version,
)

# ── الأجهزة والإشعارات → [apiparts/notify.py] ──
from apiparts.notify import (  # noqa: F401,E402
    register_device, profile_changed, unregister_device,
    notifications_inbox, admin_notifications, admin_notifications_preview,
    admin_notification_create, admin_notification_delete,
)

# ── أداة الإدخال ولوحة التحكم → [apiparts/ingest.py] ──
from apiparts.ingest import (  # noqa: F401,E402
    ingest_page, ingest_targets, ingest_models, ingest_run, ingest_save,
    admin_page,
)
