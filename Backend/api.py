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
    get_math_exam_years, get_math_exam_lessons
)
from subjects.math import handle_math_request, cleanup_old_sessions

# ── طبقة النسخة الثالثة (تُضاف بجانب القديم — لا تبدله) ──
from core import curriculum as v3_curriculum
from core import capabilities as v3_capabilities
from core import lesson_mode as v3_lesson_mode
from core import pages_mode as v3_pages_mode
from core import ratelimit as v3_ratelimit
from core import voice_clean as v3_voice_clean
from core import image_guard as v3_image_guard
from core import vision as v3_vision
from core import firebase_auth as v3_auth
from core import quota as v3_quota
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

@app.get("/subjects/units")
async def get_subject_units(subject: str, grade: int = 3, track: str = "علمي"):
    """
    جلب الوحدات بشكل ذكي وموحد يدعم جميع صيغ ملفات JSON
    بدون أخطاء AttributeError
    """
    units = []

    # 🎓 المادة يجب أن تكون مقررة على هذا الصف/المسار — وإلا فلا وحدات.
    g, t = v3_curriculum.normalize_grade_track(grade, track)
    subject = subject.strip()
    if not v3_curriculum.is_valid_subject(g, t, subject):
        return units

    # 📐 الرياضيات (حالة خاصة لأن وحداتها ثابتة)
    if subject == "رياضيات":
        return ["تفاضل", "تكامل", "جبر", "هندسة", "احتمالات"]

    # تحميل كتاب هذا الصف/المسار تحديداً
    book = load_json_safe(subject_book_path(subject, g, t))
    if not book:
        return units

    # ==========================================
    # 🧠 المنطق الذكي لاستخراج الوحدات لجميع المواد
    # ==========================================
    
    # 1. تحديد مكان قائمة الوحدات بناءً على صيغة الملف
    units_list = []
    if isinstance(book, list):
        # صيغة الأحياء (قائمة مباشرة)
        units_list = book
    elif isinstance(book, dict):
        # صيغة الإنجليزي والفيزياء والكيمياء (قاموس يحتوي على مفتاح "الوحدات")
        units_list = book.get("الوحدات", [])

    # 2. المرور على الوحدات واستخراج الأسماء بأمان تام
    if isinstance(units_list, list):
        for unit in units_list:
            # ✅ الفلتر الأهم: التأكد أن العنصر قاموس (dict) وليس نصاً (str)
            # هذا السطر هو الذي يمنع ظهور خطأ AttributeError تماماً
            if isinstance(unit, dict):
                unit_name = unit.get("اسم_الوحدة", "").strip()
                if unit_name and unit_name not in units:
                    units.append(unit_name)

    return units

@app.get("/subjects/lessons")
async def get_subject_lessons(subject: str, unit: str, grade: int = 3, track: str = "علمي"):
    """
    🎯 جلب قائمة الدروس من وحدة معينة لجميع المواد
    متوافقة تماماً مع كافة هياكل JSON
    """
    
    # 1. استثناء الرياضيات (لأن لها Endpoint خاص بها /math/lessons)
    if subject == "رياضيات":
        return []

    g, t = v3_curriculum.normalize_grade_track(grade, track)
    subject = subject.strip()
    if not v3_curriculum.is_valid_subject(g, t, subject):
        return []

    book = load_json_safe(subject_book_path(subject, g, t))
    if not book:
        return []
    
    # 2. توحيد الهيكلة (استخراج قائمة الوحدات بأمان)
    units_list = []
    if isinstance(book, list):
        units_list = book
    elif isinstance(book, dict):
        units_list = book.get("الوحدات", [])
    
    # تنظيف اسم الوحدة المطلوب البحث عنها من المسافات الزائدة
    clean_target_unit = unit.strip()

    # 3. البحث عن الوحدة المطلوبة واستخراج الدروس
    for u in units_list:
        if isinstance(u, dict):
            # تنظيف اسم الوحدة في الجيسون قبل المقارنة
            current_unit_name = u.get("اسم_الوحدة", "").strip()
            
            if current_unit_name == clean_target_unit:
                lessons = []
                # إذا كانت المادة ليس لها دروس (مثل الأحياء)، ستتجاوز هذا اللوب بأمان
                for lesson in u.get("الدروس", []):
                    if isinstance(lesson, dict):
                        lesson_name = lesson.get("اسم_الدرس", "").strip()
                        if lesson_name and lesson_name not in lessons:
                            lessons.append(lesson_name)
                return lessons
                
    return []

@app.get("/exams/years")
async def get_exam_years(subject: str, grade: int = 3, track: str = "علمي"):
    """
    🎯 جلب قائمة السنوات الوزارية المتاحة لصف/مسار
    
    مثال: /exams/years?subject=احياء&grade=3&track=علمي
    ⚠️ بنك الوزاري الحالي كله للثالث العلمي — الصفوف الأخرى ترجع فارغاً
       حتى يُضاف بنكها في `{المادة}/exams/grade{N}/…` (راجع subject_exams_dir).
    """
    from subjects.common import subject_exams_dir

    g, t = v3_curriculum.normalize_grade_track(grade, track)
    subject = subject.strip()
    if not v3_curriculum.is_valid_subject(g, t, subject):
        return []

    exams_dir = subject_exams_dir(subject, g, t)
    
    if not os.path.isdir(exams_dir):
        return []
    
    years = []
    for f in os.listdir(exams_dir):
        if f.lower().endswith(".json"):
            year = os.path.splitext(f)[0].strip()
            if year and year not in years:
                years.append(year)
    
    years.sort(reverse=True)
    return years



@app.get("/exams/sections")
async def get_exam_sections(subject: str, year: str, grade: int = 3, track: str = "علمي"):
    """
    جلب أنواع الأسئلة ديناميكياً من ملفات الـ JSON
    يدعم جلب أسئلة سنة محددة، أو تجميع كل صيغ الأسئلة إذا اختار الطالب "الكل"
    """
    from subjects.common import subject_exams_dir

    g, t = v3_curriculum.normalize_grade_track(grade, track)
    subject = subject.strip()
    if not v3_curriculum.is_valid_subject(g, t, subject):
        return []

    exams_dir = subject_exams_dir(subject, g, t)
    if not os.path.exists(exams_dir):
        return []
        
    files_to_read = []
    if year == "الكل":
        # إذا اختار "الكل"، نقرأ كل ملفات الـ JSON لنجمع كل الصيغ
        files_to_read = [f for f in os.listdir(exams_dir) if f.endswith(".json")]
    else:
        # إذا اختار سنة معينة، نقرأ ملفها فقط
        files_to_read = [f"{year}.json"]
        
    sections = []
    for file_name in files_to_read:
        file_path = os.path.join(exams_dir, file_name)
        if not os.path.exists(file_path):
            continue
            
        data = load_json_safe(file_path)
        if not data: continue
        
        if isinstance(data, dict):
            data = [data]
            
        for exam in data:
            # خاص بقراءة صيغ أسئلة اللغة الإنجليزية
            for sec in exam.get("أقسام_الأسئلة", []):
                name = sec.get("نوع_السؤال", "").strip()
                if name and name not in sections:
                    sections.append(name)
            
            # خاص بقراءة أقسام العربي (تحسباً لو أردت جعله ديناميكياً مستقبلاً)
            for sec in exam.get("الأقسام", []):
                name = sec.get("اسم_القسم", "").strip()
                if name and name not in sections:
                    sections.append(name)
                    
    return sections


# =====================
# API Endpoints - الرياضيات
# =====================

@app.get("/math/lessons")
async def get_math_lessons(branch: str, grade: int = 3, track: str = "علمي"):
    """
    🎯 دروس فرع رياضيات — **بالأسماء نفسها التي ترجعها `/content/capabilities`**

    مثال: /math/lessons?branch=تفاضل

    ⚠️ كانت هذه الدالة تسرد **أسماء الملفات**، والقدرات تسرد `اسم_الدرس`
       **الداخلي**. والاسمان يختلفان فعلاً في البيانات:

         ملف «القطع الزائد.json»  ←  اسم داخلي «القطع الزائد (الهذلول - Hyperbola)»

       فالاختبار يُبنى من القدرات، ثم «اشرح لي هذا الدرس» يبحث في هذه القائمة
       فلا يجد — **ينكسر في «هندسة» و«جبر» ويعمل في «تفاضل»**، وهي علّة تخفّت
       لأن ثلاثة فروع من خمسة سليمة. وزاد الطين أن ملفاً واحداً بلا امتداد
       `.json` («مبدأ العد») كان يسقط من هنا ويظهر في القدرات.

       الآن كلاهما يقرأ من `content_store` — **مصدرٌ واحد فلا تباعد ممكن**.
    """
    from core.content_store import get_lessons_book, lessons_in_unit

    g, t = v3_curriculum.normalize_grade_track(grade, track)
    book = get_lessons_book(g, t, "رياضيات")
    if not book:
        return []

    # ملفّان باسمٍ داخليٍّ واحد يظهران صفّين متطابقين في القائمة — نُبقي الأول.
    seen, out = set(), []
    for name in lessons_in_unit(book, branch):
        if name and name not in seen:
            seen.add(name)
            out.append(name)
    return out


@app.get("/math/exams/years")
async def get_math_exam_years_api(branch: str, grade: int = 3, track: str = "علمي"):
    """
    🎯 جلب السنوات الوزارية للرياضيات
    
    مثال: /math/exams/years?branch=تفاضل
    ⚠️ بنك وزاري الرياضيات كله للثالث العلمي — غيره يرجع فارغاً.
    """
    if not _is_legacy_content_scope(grade, track):
        return []
    return get_math_exam_years(branch)


@app.get("/math/exams/lessons")
async def get_math_exam_lessons_api(branch: str, year: str, grade: int = 3, track: str = "علمي"):
    """
    🎯 جلب الدروس الوزارية للرياضيات
    
    مثال: /math/exams/lessons?branch=تفاضل&year=2023
    """
    if not _is_legacy_content_scope(grade, track):
        return []
    return get_math_exam_lessons(branch, year)


# =====================
# API Endpoint الرئيسي - المعالجة
# =====================

# ==================================================
# 🆕 مسارات النسخة الثالثة — المحتوى بالصفوف والمسارات
# ==================================================

@app.get("/health/indexes")
async def health_indexes():
    """حالة الفهارس: كم في الذاكرة، كم على القرص، وهل اكتمل الإحماء."""
    return {**v3_index_store.stats(), "warming": v3_warmup.is_running()}


@app.get("/content/subjects")
async def v3_subjects(grade: int = 3, track: str = "علمي"):
    """قائمة مواد الصف/المسار."""
    g, t = v3_curriculum.normalize_grade_track(grade, track)
    return {"grade": g, "track": t, "subjects": v3_curriculum.subjects_for(g, t)}


@app.get("/content/capabilities")
async def v3_caps(request: Request, subject: str, grade: int = 3, track: str = "علمي"):
    """الأوضاع المتاحة لمادة + شجرة الوحدات/الدروس — استدعاء واحد للواجهة."""
    if not v3_ratelimit.check(request, "content", v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})
    g, t = v3_curriculum.normalize_grade_track(grade, track)
    subject = subject.strip()
    if not v3_curriculum.is_valid_subject(g, t, subject):
        return JSONResponse(status_code=404, content={"answer": "❌ مادة غير معروفة لهذا الصف"})
    return v3_capabilities.describe(g, t, subject)


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
            req.grade, req.track, req.subject, req.unit, req.lessons, req.count, AI_CLIENTS)
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


# ══════════════════════════════════════════════════
# 🧭 التوجيه حسب المادة — **دالةٌ واحدة للمسارين**
# ══════════════════════════════════════════════════
# كانت داخلية في `/ask`؛ أُخرجت كي يستعملها `/ask/stream` بنفس المنطق
# حرفياً. ونسخُها كان سيعني مادةً تُضاف لمسارٍ وتُنسى في الآخر.
async def _dispatch_ask(req):
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
        return await handle_physics_request(req, openai_client)

    # 🇬🇧 الإنجليزي
    elif subject == "انجليزي":
        return await handle_english_request(req, gemini_client)

    # ⚛️ الكيمياء
    elif subject == "كيمياء":
        return await handle_chemistry_request(req, openai_client)
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
    allowed, _remaining = await v3_quota.acheck_and_consume(
        identity["uid"], identity["is_guest"])
    if not allowed:
        v3_idem.abandon(identity["uid"], req.request_id)
        return identity, "", _json_response(
            {"answer": v3_quota.message_for(identity["is_guest"]),
             "references": [], "session_active": False,
             "quota_exceeded": True, "is_guest": identity["is_guest"]}, 429)

    # 📷 الصورة → نص (Gemini لكل المواد) قبل أي توجيه.
    image_text = ""
    if req.all_images():
        try:
            extracted = []
            for img in req.all_images():
                clean, mime = v3_image_guard.validate(img)
                extracted.append(await v3_vision.image_to_text(clean, mime, AI_CLIENTS))
        except (v3_image_guard.ImageRejected, v3_vision.VisionFailed) as e:
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
        result = _attach_image_text(await _dispatch_ask(req), _image_text)
    except Exception:
        v3_idem.abandon(identity["uid"], req.request_id)
        raise
    _remember(identity["uid"], req.request_id, result)
    return result




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
    """يعيد `(identity, scholarship, error_response)`."""
    identity, auth_error = await _authenticate(request, req)
    if auth_error is not None:
        return None, None, auth_error

    if not v3_ratelimit.check(request, identity["uid"],
                              v3_ratelimit.VOICE_LIMIT, v3_ratelimit.VOICE_WINDOW):
        return None, None, _json_response(
            {"answer": v3_ratelimit.RATE_LIMIT_MESSAGE}, 429)

    blocked = await _section_gate("scholarships", identity)
    if blocked is not None:
        return identity, None, blocked

    try:
        sch = v3_scholarships.get_public(req.scholarship_id)
    except v3_scholarships.ScholarshipError as e:
        return identity, None, _json_response({"answer": str(e), "ok": False}, 404)

    state, cached = v3_idem.begin(identity["uid"], req.request_id)
    if state == v3_idem.DONE and cached is not None:
        return identity, sch, _json_response(cached)
    if state == v3_idem.RUNNING:
        return identity, sch, _json_response(
            {"answer": v3_idem.IN_FLIGHT_MESSAGE, "ok": False}, 202)

    allowed, _ = await v3_quota.acheck_and_consume(identity["uid"], identity["is_guest"])
    if not allowed:
        v3_idem.abandon(identity["uid"], req.request_id)
        return identity, sch, _json_response(
            {"answer": v3_quota.message_for(identity["is_guest"]),
             "quota_exceeded": True, "is_guest": identity["is_guest"], "ok": False}, 429)

    return identity, sch, None


# ══════════════════════════════════════════════════
# 🌊 مولّد أحداث البثّ — **مصدرٌ واحد لكل المسارات**
# ══════════════════════════════════════════════════
# ⚠️ ثلاثة مسارات تبثّ الآن (تعليم · معلّم · منح)، ونسخُ منطق النبضة
#    والإغلاق والحدث الختامي في كلٍّ منها يعني ثلاثةَ أماكن يُنسى في
#    أحدها إصلاح. الفروق الحقيقية بينها ثلاثة معاملات لا أكثر.

def _sse_stream(*, uid: str, request_id: str, sink, runner, image_text: str = "",
                fallback: dict | None = None):
    """يعيد `StreamingResponse` تبثّ ما يكتبه `runner` في `sink`."""

    async def _run():
        try:
            return await runner()
        finally:
            await sink.close()

    async def _events():
        task = asyncio.create_task(_run())
        streamed_any = False
        try:
            # 1️⃣ الأجزاء أولاً بأول، مع نبضةٍ تمنع البروكسيات من قطع الصمت.
            drain = sink.drain().__aiter__()
            while True:
                try:
                    piece = await asyncio.wait_for(
                        drain.__anext__(), timeout=v3_stream.HEARTBEAT_SECONDS)
                except StopAsyncIteration:
                    break
                except asyncio.TimeoutError:
                    yield v3_stream.HEARTBEAT
                    continue
                streamed_any = True
                yield v3_stream.delta_event(piece)

            # 2️⃣ الحدث الختامي: النص **النهائي** بعد التنظيف + المراجع.
            #    ⚠️ والعميل يستبدل ما بثّه به لا يُلحقه: المعالجات تُنقّي
            #       الناتج بعد التوليد وقد تُلحق ملاحظة، فالمبثوث تقريبٌ
            #       والنهائيُّ هو الحقيقة.
            result = _attach_image_text(await task, image_text)
            payload = _as_payload(result) or {
                **(fallback or {}), "answer": sink.text}
            _remember(uid, request_id, payload)
            yield v3_stream.done_event(payload)

        except asyncio.CancelledError:
            # 🚪 الطالب أغلق الشاشة: نُلغي التوليد بدل أن يُكمل بلا قارئ.
            task.cancel()
            v3_idem.abandon(uid, request_id)
            raise
        except Exception as e:                       # noqa: BLE001
            print(f"🔥 خطأ أثناء البثّ: {e}")
            v3_idem.abandon(uid, request_id)
            # ⚠️ ما وصل الطالبَ يبقى معروضاً؛ نُخبره بالانقطاع ولا نمسحه.
            yield v3_stream.error_event(
                "⚠️ انقطع الاتصال أثناء الإجابة. حاول مرة أخرى."
                if streamed_any else
                "⚠️ تعذّر توليد الإجابة الآن. حاول بعد قليل.")

    return StreamingResponse(_events(), media_type="text/event-stream",
                             headers=v3_stream.SSE_HEADERS)


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
        runner=lambda: _dispatch_ask(req),
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
        try:
            return await v3_teacher.ask(req, AI_CLIENTS)
        except v3_teacher.TeacherError as e:
            # رسالة عربية جاهزة — تُعرض في الفقاعة كردٍّ لا كعطل شبكة.
            return {"answer": str(e), "references": [], "session_active": False}

    return _sse_stream(
        uid=identity["uid"], request_id=req.request_id, sink=sink,
        image_text=image_text, runner=_run,
        fallback={"references": [], "session_active": False},
    )


@app.post("/scholarship/ask/stream")
async def scholarship_ask_stream(req: ScholarshipAskRequest, request: Request):
    identity, sch, denied = await _scholarship_guards(req, request)
    if denied is not None:
        return denied

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



# ══════════════════════════════════════════════════
# 🎓 قسم المنح — مسارات الطالب
# ══════════════════════════════════════════════════
# المنح **محتوى متغيّر يُدار من اللوحة** ولا يُشحن مع التطبيق ([32]).
# والقائمة لا تُنقل إلا يوم تتغيّر: العميل يرسل نسخته، فإن طابقت رجع
# `changed: false` بلا أي منحة — راجع بروتوكول النسخة في core/scholarships.


def _scholarships_unavailable():
    """رد ودّي حين لا Firestore على الخادم — لا خطأ 500 على شاشة طالب."""
    return _json_response({
        "changed": False, "version": 0, "items": [],
        "answer": "🎓 قسم المنح غير مهيّأ على الخادم بعد — عد إلينا قريباً.",
    }, 200)


@app.get("/scholarships")
async def scholarships_list(request: Request, version: int = -1):
    """قائمة المنح المفعّلة — أو `changed: false` إن كانت نسخة العميل محدّثة.

    مفتوح لكل من يفتح التطبيق (بلا حصة): قراءة قائمة لا تنادي أي موديل.
    """
    if not v3_ratelimit.check(request, "scholarships",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})
    if not v3_scholarships.available():
        return _scholarships_unavailable()
    try:
        return _json_response(v3_scholarships.list_public(version))
    except v3_scholarships.ScholarshipError as e:
        return _json_response({"changed": False, "version": 0, "items": [],
                               "answer": str(e)}, 200)


@app.get("/scholarships/{sch_id}")
async def scholarship_detail(request: Request, sch_id: str):
    """منحة واحدة — للروابط العميقة (إشعار «منحة جديدة») وبانر الرئيسية."""
    if not v3_ratelimit.check(request, "scholarships",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})
    try:
        return _json_response(v3_scholarships.get_public(sch_id))
    except v3_scholarships.ScholarshipError as e:
        return _json_response({"answer": str(e)}, 404)


@app.post("/scholarship/ask")
async def scholarship_ask(req: ScholarshipAskRequest, request: Request):
    """💬 مساعد المنحة: برومبت الأدمن 🔒 + بطاقة المنحة → Flash-Lite.

    🎟️ نداء موديل ⇒ يُحتسب من الحصة كسؤال واحد — تماماً كـ`/quiz/generate`.
    """
    identity, auth_error = await _authenticate(request, req)
    if auth_error is not None:
        return auth_error

    if not v3_ratelimit.check(request, identity["uid"],
                              v3_ratelimit.VOICE_LIMIT, v3_ratelimit.VOICE_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})

    blocked = await _section_gate("scholarships", identity)
    if blocked is not None:
        return blocked

    try:
        sch = v3_scholarships.get_public(req.scholarship_id)
    except v3_scholarships.ScholarshipError as e:
        return _json_response({"answer": str(e), "ok": False}, 404)

    state, cached = v3_idem.begin(identity["uid"], req.request_id)
    if state == v3_idem.DONE and cached is not None:
        return _json_response(cached)
    if state == v3_idem.RUNNING:
        return _json_response({"answer": v3_idem.IN_FLIGHT_MESSAGE, "ok": False}, 202)

    allowed, _ = await v3_quota.acheck_and_consume(identity["uid"], identity["is_guest"])
    if not allowed:
        v3_idem.abandon(identity["uid"], req.request_id)
        return _json_response(
            {"answer": v3_quota.message_for(identity["is_guest"]),
             "quota_exceeded": True, "is_guest": identity["is_guest"], "ok": False}, 429)

    # 📷 الصورة → نص (نفس مسار `/ask` وحارسه): لقطة من موقع المنحة أو
    #    كشف درجات أو وثيقة. الصورة **لا تُحفظ ولا تُسجَّل** ولا تمضي أبعد
    #    من هنا — النص المستخرج وحده يصل للمساعد ([27§3]).
    question = req.question
    image_text = ""
    images = req.all_images()
    if images:
        try:
            extracted = []
            for img in images:
                clean, mime = v3_image_guard.validate(img)
                extracted.append(await v3_vision.image_to_text(clean, mime, AI_CLIENTS))
        except (v3_image_guard.ImageRejected, v3_vision.VisionFailed) as e:
            return _json_response({"answer": str(e), "ok": False}, 200)
        question = v3_vision.merge_into_question(extracted, req.question)
        image_text = v3_vision.history_text(extracted)
        req.images_base64 = None
        req.image_base64 = None

    if not (question or "").strip():
        return _json_response(
            {"answer": "اكتب سؤالك عن المنحة أو أرفق صورة 😊", "ok": False}, 200)

    try:
        payload = _attach_image_text(
            await v3_sch_assistant.ask(sch, question, req.chat_history, AI_CLIENTS),
            image_text)
    except Exception:
        v3_idem.abandon(identity["uid"], req.request_id)
        raise
    _remember(identity["uid"], req.request_id, payload)
    return _json_response(payload)


# ══════════════════════════════════════════════════
# 👨‍🏫 مساعد المعلم
# ══════════════════════════════════════════════════
# قسمٌ **مطابق لقسم التعليم في تجربته** ومختلفٌ عنه في الإعدادات والبرومبتات
# وحدهما (قرار المالك). المصدر: **نصّ الدرس من الكتاب** لا الوحدات ولا الصفحات.

@app.get("/teacher/tools")
async def teacher_tools(request: Request):
    """أدوات المعلم المتاحة — كي تُبنى الواجهة من الخادم لا من ثوابت مكرّرة."""
    if not v3_ratelimit.check(request, "teacher_tools",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})
    return _json_response({
        "tools": [
            {"tool": t, "label": m["label"], "emoji": m["emoji"],
             "has_generate": m["has_generate"], "extras": list(m["extras"])}
            for t, m in v3_teacher_prompts.TOOLS.items()
        ],
        "difficulties": list(v3_teacher_prompts.DIFFICULTIES),
        "counts": list(v3_teacher_prompts.COUNTS),
    })


@app.post("/teacher/ask")
async def teacher_ask(req: TeacherAskRequest, request: Request):
    """👨‍🏫 أداة المعلم أو متابعتها → نصّ الدرس + برومبت الأداة → الموديل.

    🎟️ نداء موديل ⇒ يُحتسب من الحصة كسؤال واحد — تماماً كـ`/ask`
       و`/quiz/generate` و`/scholarship/ask`. وإلا صار بابَاً خلفياً للفاتورة.
    """
    identity, auth_error = await _authenticate(request, req)
    if auth_error is not None:
        return auth_error

    if not v3_ratelimit.check(request, identity["uid"]):
        return JSONResponse(status_code=429,
                            content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})

    # 👨‍🏫 **لا حارس أقسامٍ هنا بعد اليوم** ([35§7]): «مساعد المعلم» خرج من
    #    `access.SECTIONS` لأنه صار تطبيق المعلّم كلَّه لا قسماً فيه. وحارسٌ
    #    يُنادى ولا يمنع شيئاً أسوأ من غيابه: يوهم قارئ الكود بحمايةٍ لا وجود لها.
    #
    # 🔓 ولا حارس دورٍ كذلك — **عن قصد**: الزائر يجرّب أدوات المعلم قبل أن
    #    يسجّل ([35§3])، ولا مستند له يُقرأ منه دور. والفاتورة تحرسها الحصةُ
    #    أدناه وتحديدُ المعدل أعلاه، وهما ما يهمّ فعلاً.

    state, cached = v3_idem.begin(identity["uid"], req.request_id)
    if state == v3_idem.DONE and cached is not None:
        return _json_response(cached)
    if state == v3_idem.RUNNING:
        return _json_response(
            {"answer": v3_idem.IN_FLIGHT_MESSAGE, "references": [],
             "session_active": False, "in_flight": True}, 202)

    allowed, _ = await v3_quota.acheck_and_consume(identity["uid"], identity["is_guest"])
    if not allowed:
        v3_idem.abandon(identity["uid"], req.request_id)
        return _json_response(
            {"answer": v3_quota.message_for(identity["is_guest"]), "references": [],
             "session_active": False, "quota_exceeded": True,
             "is_guest": identity["is_guest"]}, 429)

    # 📷 الصورة → نص: نفس مسار `/ask` وحارسه بلا ازدواج. الاستعمال الحقيقي
    #    هنا: صفحة كتاب مصوّرة · ورقة إجابة طالب · سؤال مكتوب بخط اليد.
    #    والصورة **لا تُحفظ ولا تُسجَّل** ولا تمضي أبعد من هذه النقطة.
    image_text = ""
    images = req.all_images()
    if images:
        try:
            extracted = []
            for img in images:
                clean, mime = v3_image_guard.validate(img)
                extracted.append(await v3_vision.image_to_text(clean, mime, AI_CLIENTS))
        except (v3_image_guard.ImageRejected, v3_vision.VisionFailed) as e:
            return _json_response({"answer": str(e), "references": [],
                                   "session_active": False}, 200)
        req.content = v3_vision.merge_into_question(extracted, req.content)
        image_text = v3_vision.history_text(extracted)
        req.images_base64 = None
        req.image_base64 = None

    try:
        result = await v3_teacher.ask(req, AI_CLIENTS)
    except v3_teacher.TeacherError as e:
        # رسالة عربية جاهزة — تُعرض في الفقاعة كردٍّ لا كعطل شبكة.
        v3_idem.abandon(identity["uid"], req.request_id)
        return _json_response({"answer": str(e), "references": [],
                               "session_active": False}, 200)
    except Exception:
        v3_idem.abandon(identity["uid"], req.request_id)
        raise

    payload = _attach_image_text(result, image_text)
    _remember(identity["uid"], req.request_id, payload)
    return _json_response(payload)


# ══════════════════════════════════════════════════
# 🛡️ لوحة التحكم — مسارات الإدارة
# ══════════════════════════════════════════════════
# الصلاحية طبقتان: توكن Firebase لحسابٍ دوره `admin`، أو مفتاح `ADMIN_KEY`.
# وإن لم يُضبط أيٌّ منهما فالمسارات **مغلقة** — لا وضع مفتوح افتراضياً.

def _admin_gate(request: Request):
    """يعيد None عند السماح، أو ردَّ رفضٍ جاهزاً."""
    if not v3_admin.gate_open():
        return _json_response(
            {"error": "🔒 لوحة التحكم غير مفعّلة: اضبط ADMIN_KEY أو ADMIN_EMAILS."}, 503)

    key = request.headers.get("X-Admin-Key", "")
    if v3_admin.key_matches(key):
        return None

    token = v3_auth.bearer_token(request)
    if token:
        try:
            ident = v3_auth.verify(token)
            if v3_admin.is_admin_identity(ident):
                return None
        except v3_auth.AuthError:
            pass

    return _json_response({"error": "⛔ صلاحية الإدارة مطلوبة."}, 401)


def _admin_run(request: Request, fn):
    """بوابة + تنفيذ + تحويل أخطاء اللوحة إلى رسائل عربية."""
    denied = _admin_gate(request)
    if denied is not None:
        return denied
    try:
        return fn()
    except (v3_admin.AdminError, v3_scholarships.ScholarshipError,
            v3_teacher.TeacherError, v3_banners.BannerError,
            v3_analytics.AnalyticsError, v3_access.AccessError,
            v3_notify.NotificationError, v3_audience.AudienceError,
            v3_image_guard.ImageRejected) as e:
        # كلها أخطاء برسائل عربية جاهزة للعرض في اللوحة — لا أخطاء برمجية.
        # ⚠️ `ImageRejected` لازمة هنا لا في المسار: الالتقاط العام أدناه
        #    يسبق أيّ `except` خارج هذه الدالة فيحوّلها إلى 500 غامض.
        return _json_response({"error": str(e)}, 400)
    except Exception as e:
        print(f"⚠️ خطأ في لوحة التحكم: {e}")
        return _json_response({"error": "⚠️ تعذّر تنفيذ الطلب."}, 500)


@app.get("/admin/overview")
async def admin_overview(request: Request, days: int = 30):
    """أرقام الرئيسية: مستخدمون · أسئلة اليوم والإجمالي · سلسلة يومية."""
    days = max(7, min(days, 90))
    return _admin_run(request, lambda: v3_admin.overview(days))


@app.get("/admin/users")
async def admin_users(request: Request, search: str = "", limit: int = 200,
                      segment: str = "all", sort: str = "active"):
    """كل المستخدمين مع استخدامهم — مصفّىً بالشريحة ومرتّباً كما يطلب الأدمن.

    ⚠️ الشريحة **لا تفتح بياناتٍ جديدة**: هي تصفية لما يراه المديرُ أصلاً
       خلف البوابة نفسها، لا مسارٌ جانبيٌّ يتخطّاها.
    """
    return _admin_run(request, lambda: {
        "users": v3_admin.list_users(search, limit, segment, sort),
        "segments": v3_audience.describe_all()})


@app.get("/admin/users/{uid}")
async def admin_user_detail(request: Request, uid: str, days: int = 30):
    """تفصيل مستخدم واحد وسلسلته اليومية."""
    days = max(7, min(days, 90))
    return _admin_run(request, lambda: v3_admin.user_detail(uid, days))


@app.post("/admin/users/{uid}/ban")
async def admin_ban(request: Request, uid: str, body: AdminBanRequest):
    """حظر أو رفع حظر — يسري عند أول طلب للمستخدم."""
    return _admin_run(request, lambda: v3_admin.set_banned(uid, body.banned))


@app.post("/admin/users/{uid}/quota")
async def admin_quota(request: Request, uid: str, body: AdminQuotaRequest):
    """حدّ يومي خاص بهذا المستخدم — أو `null` للعودة للحدّ العام."""
    return _admin_run(request, lambda: v3_admin.set_quota(uid, body.limit))


# ══════════════ 🎓 المنح في اللوحة ══════════════
# مرِن عمداً: المنح تتجدّد كل موسم، فالإضافة والتعديل والترتيب والإخفاء
# كلها من اللوحة بلا نشر تطبيق ولا لمس كود ([32§6]).


@app.get("/admin/scholarships")
async def admin_scholarships(request: Request):
    """كل المنح — بما فيها المخفية — ومعها هل لكل واحدة برومبت مساعد."""
    return _admin_run(request, lambda: v3_scholarships.list_admin())


@app.get("/admin/scholarships/{sch_id}")
async def admin_scholarship_get(request: Request, sch_id: str):
    """منحة واحدة للتحرير + برومبتها 🔒 (اللوحة وحدها تراه)."""
    return _admin_run(request, lambda: v3_scholarships.get_admin(sch_id))


@app.post("/admin/scholarships")
async def admin_scholarship_create(request: Request, body: ScholarshipUpsertRequest):
    """إنشاء منحة جديدة — ويرفع `meta.version` فتصل التطبيقات فوراً."""
    return _admin_run(
        request,
        lambda: v3_scholarships.create(body.id or "", body.model_dump(exclude_none=False)))


@app.put("/admin/scholarships/{sch_id}")
async def admin_scholarship_update(request: Request, sch_id: str,
                                   body: ScholarshipUpsertRequest):
    """تحديث منحة قائمة (النموذج يرسل كل الحقول)."""
    return _admin_run(
        request,
        lambda: v3_scholarships.update(sch_id, body.model_dump(exclude_none=False)))


@app.post("/admin/scholarships/{sch_id}/enabled")
async def admin_scholarship_enabled(request: Request, sch_id: str,
                                    body: ScholarshipEnabledRequest):
    """إظهار/إخفاء فوري بلا حذف — أرخص طريقة لسحب منحة انتهى موسمها."""
    return _admin_run(request, lambda: v3_scholarships.set_enabled(sch_id, body.enabled))


@app.post("/admin/scholarships/reorder")
async def admin_scholarship_reorder(request: Request, body: ScholarshipReorderRequest):
    """ترتيب العرض — أول معرّف أعلى القائمة."""
    return _admin_run(request, lambda: v3_scholarships.reorder(body.ids))


@app.delete("/admin/scholarships/{sch_id}")
async def admin_scholarship_delete(request: Request, sch_id: str):
    """حذف نهائي للمنحة **وبرومبتها معاً** — وإلا بقي برومبت يتيم."""
    return _admin_run(request, lambda: v3_scholarships.delete(sch_id))


@app.get("/admin/scholarships/{sch_id}/prompt")
async def admin_scholarship_prompt_get(request: Request, sch_id: str):
    """🔒 برومبت المساعد + **البرومبت المشترك** الذي يعمل أصلاً لكل المنح.

    ⭐ إرجاع المشترك مقصود: الأدمن يراه في اللوحة للقراءة فقط، فيعرف ما هو
       مغطّى سلفاً (النبرة · طول الرد · منع التكرار · منع الاختراع) ولا يعيد
       كتابته — ويقتصر حقله على **ما يخصّ هذه المنحة وحدها** ([32§5]).
    """
    return _admin_run(request, lambda: {
        "id": sch_id,
        "assistant_prompt": v3_scholarships.get_prompt(sch_id),
        "shared_system": v3_sch_assistant.SYSTEM_CORE,
        "placeholder": v3_sch_assistant.NO_ADMIN_INSTRUCTIONS,
    })


@app.post("/admin/scholarships/{sch_id}/prompt")
async def admin_scholarship_prompt_set(request: Request, sch_id: str,
                                       body: ScholarshipPromptRequest):
    """حفظ البرومبت. **لا يرفع `meta.version`** — الطلاب لا يكيّشونه ([06])."""
    return _admin_run(request,
                      lambda: v3_scholarships.set_prompt(sch_id, body.assistant_prompt))


@app.post("/admin/scholarships/{sch_id}/try")
async def admin_scholarship_try(request: Request, sch_id: str, body: ScholarshipTryRequest):
    """🧪 «جرّب البرومبت» قبل النشر — يجرّب **المسودّة** غير المحفوظة أيضاً.

    ⭐ هذا ما يمنع نشر مساعدٍ يهذي: الأدمن يرى ردّه داخل اللوحة أولاً.
    """
    denied = _admin_gate(request)
    if denied is not None:
        return denied
    try:
        sch = v3_scholarships.get_admin(sch_id)
    except v3_scholarships.ScholarshipError as e:
        return _json_response({"error": str(e)}, 400)

    # مسودّة البرومبت من الحقل المفتوح في اللوحة تسبق المحفوظ.
    draft = body.assistant_prompt
    if draft is not None:
        messages = [{"role": "system",
                     "content": v3_sch_assistant.build_system(sch, draft)}]
        messages += v3_sch_assistant.build_history(body.chat_history)
        messages.append({"role": "user", "content": f"سؤال الطالب:\n{body.question}"})
        try:
            client = AI_CLIENTS.get("gemini")
            response = await client.chat.completions.create(
                model=v3_sch_assistant.MODEL, messages=messages,
                max_tokens=900, temperature=0.4)
            return _json_response(
                {"answer": (response.choices[0].message.content or "").strip(), "ok": True})
        except Exception as e:
            print(f"⚠️ تجربة برومبت المنحة: {e}")
            return _json_response({"error": "⚠️ تعذّرت تجربة البرومبت."}, 500)

    return _json_response(
        await v3_sch_assistant.ask(sch, body.question, body.chat_history, AI_CLIENTS))


# ==================================================
# 👤 صورة الحساب
# ==================================================
_AVATAR_SAFE = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_"


def _avatar_key(uid: str) -> str:
    """اسم ملف آمن من المعرّف — تنقيةٌ دفاعية لا تُترك لشكل الـuid.

    ⚠️ uid فايربيس أبجديّ رقميّ اليوم، لكن اسم الملف يُبنى منه ويُكتب على
       القرص: قيدٌ يُفترض ولا يُفرض هو ثغرةُ مسارٍ تنتظر تغييراً في الأعلى.
    """
    return "".join(c if c in _AVATAR_SAFE else "_" for c in uid)[:96]


@app.post("/me/avatar")
async def me_avatar(request: Request, body: AvatarRequest):
    """يرفع صورة حساب الطالب (أو يحذفها بإرسال فراغ) ويعيد رابطها.

    ⭐ **لماذا يمرّ الرفع بالخادم** ولا يذهب من التطبيق إلى Storage مباشرة؟
       لأن التطبيق لا يحمل حزمة `firebase_storage` أصلاً، وإضافتها تعني
       اعتمادية أصلية جديدة وبناءً كاملاً. والخادم يملك Admin SDK جاهزاً.

    🔒 المعرّف من التوكن لا من الجسم — فلا يكتب أحدٌ فوق صورة غيره.
    🚫 والزائر لا صورة له: حسابه مؤقّت ويُلغى، فترفع ملفاً يتيماً بلا مالك.
    """
    if not v3_ratelimit.check(request, "avatar",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return _json_response({"error": "⏳ محاولات كثيرة. انتظر قليلاً."}, 429)

    identity, err = await _authenticate(request, body)
    if err:
        return err
    if identity.get("is_guest"):
        return _json_response(
            {"error": "👤 أنشئ حساباً أولاً لتضع صورتك."}, 403)

    key = _avatar_key(identity.get("uid", ""))
    if not key:
        return _json_response({"error": "⚠️ تعذّر تحديد الحساب."}, 400)

    data = (body.image_base64 or "").strip()
    try:
        if not data:
            v3_media.delete_image("avatar", key)
            return _json_response({"url": ""})
        clean, mime = v3_image_guard.validate(data)
        url = v3_media.upload_image("avatar", key, base64.b64decode(clean), mime)
        return _json_response({"url": url})
    except v3_image_guard.ImageRejected as e:
        return _json_response({"error": str(e)}, 400)
    except v3_media.StorageUnavailable as e:
        return _json_response({"error": str(e)}, 503)
    except Exception as e:
        print(f"⚠️ رفع صورة الحساب: {e}")
        return _json_response({"error": "⚠️ تعذّر رفع الصورة. حاول ثانيةً."}, 500)


@app.post("/admin/scholarships/{sch_id}/cover")
async def admin_scholarship_cover(request: Request, sch_id: str,
                                  body: ScholarshipCoverRequest):
    """🖼️ رفع غلاف المنحة (أو حذفه بإرسال فراغ).

    الصورة تُقصّ وتُضغط **في اللوحة** قبل الوصول — فالخادم يتحقق ويخزّن فقط.
    وتُحفظ في مجموعة موازية لا في مستند المنحة، كي لا تنتفخ قائمة الطلاب.
    """
    def _save():
        data = (body.image_base64 or "").strip()
        if not data:
            return v3_scholarships.set_cover(sch_id)
        # 🛡️ البصمة السحرية لا الامتداد: نصٌّ مُرمَّز باسم صورة يُرفض هنا.
        clean, mime = v3_image_guard.validate(data)
        return v3_scholarships.set_cover(sch_id, base64.b64decode(clean), mime)

    return _admin_run(request, _save)


@app.post("/admin/scholarships/{sch_id}/logo")
async def admin_scholarship_logo(request: Request, sch_id: str,
                                 body: ScholarshipCoverRequest):
    """🏷️ رفع شعار المنحة (أو حذفه بإرسال فراغ) — مربّع 1:1."""
    def _save():
        data = (body.image_base64 or "").strip()
        if not data:
            return v3_scholarships.set_logo(sch_id)
        clean, mime = v3_image_guard.validate(data)
        return v3_scholarships.set_logo(sch_id, base64.b64decode(clean), mime)

    return _admin_run(request, _save)


@app.get("/scholarships/{sch_id}/cover")
async def scholarship_cover(request: Request, sch_id: str):
    """غلاف منحة — يُجلب عند فتح شاشتها وحدها ويُكيَّش على الجهاز."""
    if not v3_ratelimit.check(request, "covers",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return JSONResponse(status_code=429, content={"answer": v3_ratelimit.RATE_LIMIT_MESSAGE})
    try:
        image = v3_scholarships.get_cover(sch_id)
    except v3_scholarships.ScholarshipError:
        image = ""
    return _json_response({"id": sch_id, "image": image})


# ══════════════ 👨‍🏫 برومبتات المعلم في اللوحة ══════════════
# ⭐ الفرق الجوهري عن تبويب المنح: **لا شيء يُنشأ هنا ولا يُحذف.** الأدوات
#    الأربع مشحونة مع التطبيق، واللوحة تُحسّن سلوكها فقط. ولذلك:
#      • القسم يعمل كاملاً بلا Firestore (برومبتات الكود هي الأساس).
#      • تفريغ الحقل ⇒ **عودةٌ للافتراضي** لا تعطيلٌ للأداة.

# ==================================================
# 🎏 البانرات
# ==================================================
@app.get("/banners")
async def banners_list(request: Request, signature: str = "",
                       grade: int = 0, track: str = ""):
    """بانرات كل الأقسام في رد واحد — أو `changed:false` إن لم يتغيّر شيء.

    🎯 `grade`/`track` اختياريان: بهما يصفّي الخادمُ البانرات المستهدَفة،
       وبدونهما يعود كلُّ شيء ومعه حقل `segment` ليصفّي التطبيقُ بنفسه —
       فالنسخة القديمة لا تنكسر ولا تُحرَم.
    """
    if not v3_ratelimit.check(request, "banners",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return _json_response({"error": "⏳ محاولات كثيرة. انتظر قليلاً."}, 429)
    if not v3_banners.available():
        # 🛡️ لا نُسقط الشاشة الرئيسية لأن البانرات غير متاحة: قسمٌ تزييني.
        return _json_response({"changed": True, "signature": "", "sections": {}})
    try:
        return _json_response(v3_banners.list_public(
            signature, grade=grade if grade in (1, 2, 3) else None, track=track))
    except Exception as e:
        print(f"⚠️ قراءة البانرات: {e}")
        return _json_response({"changed": True, "signature": "", "sections": {}})


@app.get("/admin/banners")
async def admin_banners(request: Request):
    return _admin_run(request, lambda: v3_banners.list_admin())


@app.post("/admin/banners")
async def admin_banner_create(request: Request, body: BannerRequest):
    return _admin_run(request, lambda: v3_banners.create(body.model_dump()))


@app.put("/admin/banners/{banner_id}")
async def admin_banner_update(request: Request, banner_id: str, body: BannerRequest):
    return _admin_run(request, lambda: v3_banners.update(banner_id, body.model_dump()))


@app.post("/admin/banners/{banner_id}/enabled")
async def admin_banner_enabled(request: Request, banner_id: str, body: ScholarshipEnabledRequest):
    return _admin_run(request, lambda: v3_banners.set_enabled(banner_id, body.enabled))


@app.delete("/admin/banners/{banner_id}")
async def admin_banner_delete(request: Request, banner_id: str):
    return _admin_run(request, lambda: v3_banners.delete(banner_id))


@app.get("/admin/banner-templates")
async def admin_banner_templates(request: Request):
    return _admin_run(request, lambda: {"templates": v3_banners.get_templates()})


@app.post("/admin/banner-templates")
async def admin_banner_templates_save(request: Request, body: BannerTemplatesRequest):
    return _admin_run(
        request, lambda: {"templates": v3_banners.set_templates(body.templates)})


@app.get("/admin/teacher/prompts")
async def admin_teacher_prompts(request: Request):
    """كل الأدوات ببرومبتاتها الفعّالة + هل هي مخصَّصة أم افتراضية."""
    return _admin_run(request, v3_teacher.list_prompts)


@app.get("/admin/teacher/core")
async def admin_teacher_core(request: Request):
    """👁️ البرومبت المشترك — **للقراءة فقط**، يُعدَّل من الكود لا من اللوحة.
    عرضُه يمنع الأدمن من إعادة كتابة ما هو مغطّى سلفاً في كل أداة."""
    return _admin_run(request, lambda: {"core": v3_teacher_prompts.SYSTEM_CORE})


@app.get("/admin/teacher/lessons")
async def admin_teacher_lessons(request: Request, subject: str = "",
                                grade: int = 3, track: str = "علمي"):
    """مواد الصف/المسار + شجرة وحدات المادة ودروسها — كي يجرّب الأدمن البرومبت
    على **درسٍ حقيقي**. والمواد تأتي من `curriculum` لا من قائمة في اللوحة:
    مصدرٌ واحد للحقيقة، فلا تنحرف اللوحة عن التطبيق عند تغيّر المنهج."""
    def _read():
        g, t = v3_curriculum.normalize_grade_track(grade, track)
        subjects = v3_curriculum.subjects_for(g, t)
        chosen = subject if subject in subjects else (subjects[0] if subjects else "")
        data = v3_teacher.units_and_lessons(g, t, chosen) if chosen else \
            {"subject": "", "available": False, "units": []}
        data["subjects"] = subjects
        data["grade"] = g
        data["track"] = t
        return data
    return _admin_run(request, _read)


@app.post("/admin/teacher/prompts/{tool}")
async def admin_teacher_prompt_set(tool: str, req: TeacherPromptRequest,
                                   request: Request):
    """حفظ برومبت أداة. الفراغ = العودة للمكتوب في الكود."""
    return _admin_run(
        request, lambda: v3_teacher.set_prompt(tool, req.kind, req.prompt))


@app.post("/admin/teacher/prompts/{tool}/try")
async def admin_teacher_prompt_try(tool: str, req: TeacherTryRequest,
                                   request: Request):
    """🧪 يجرّب **المسودّة غير المحفوظة** — هذا ما يمنع نشر برومبتٍ يهذي."""
    denied = _admin_gate(request)
    if denied is not None:
        return denied
    try:
        return _json_response(await v3_teacher.try_prompt(
            tool, req.kind, req.prompt or "", req.question, AI_CLIENTS,
            subject=req.subject, grade=req.grade, track=req.track,
            unit=req.unit_name, lesson=req.lesson_name))
    except v3_teacher.TeacherError as e:
        return _json_response({"error": str(e)}, 400)
    except Exception as e:
        print(f"⚠️ خطأ في تجربة برومبت المعلم: {e}")
        return _json_response({"error": "⚠️ تعذّرت التجربة."}, 500)


@app.get("/admin/settings")
async def admin_settings_get(request: Request):
    """⚙️ الإعدادات العامة + القيم الفعّالة الآن (بعد احتساب البيئة)."""
    def _read():
        stored = v3_scholarships.get_settings(force=True)
        return {
            "stored": stored,
            "effective": {
                "quota_ask": v3_quota.limit_for(False),
                "quota_guest": v3_quota.limit_for(True),
            },
            "ranges": {k: list(v) for k, v in v3_scholarships.SETTINGS_FIELDS.items()},
            "text_fields": dict(v3_scholarships.SETTINGS_TEXT_FIELDS),
        }
    return _admin_run(request, _read)


@app.post("/admin/settings")
async def admin_settings_set(request: Request, body: AdminSettingsRequest):
    """حفظ الإعدادات العامة — تصل الخادم خلال ≤ ٥ دقائق (كاش الإعدادات)."""
    return _admin_run(
        request,
        lambda: v3_scholarships.set_settings(body.model_dump(exclude_none=True)))


# ══════════════════════════════════════════════════
# 📈 التحليلات · 👥 الشرائح
# ══════════════════════════════════════════════════
# ⚠️ **الفلتر ليس بابَ تسريب**: كل هذه المسارات خلف `_admin_run` — أي خلف
#    البوابة نفسها. والشريحة تُصفّي ما يراه المديرُ أصلاً، فلا تفتح له بيانات
#    لم تكن مفتوحة بدونها. ولا مسار منها يقبل «uid» من الطالب ليقرأ غيره.


@app.get("/admin/analytics")
async def admin_analytics(request: Request, days: int = 30, segment: str = "all",
                          subject: str = "", refresh: int = 0):
    """كل أرقام تبويب التحليلات — مفلترةً بالشريحة والمدّة والمادة."""
    return _admin_run(request, lambda: v3_analytics.overview_v2(
        days=days, segment=segment, subject=subject, force=bool(refresh)))


@app.get("/admin/segments")
async def admin_segments(request: Request):
    """الشرائح المعرّفة مرّةً واحدة — تبني منها اللوحة كل قوائمها."""
    return _admin_run(request, lambda: {"segments": v3_audience.describe_all()})


# ══════════════════════════════════════════════════
# 🔐 التحكم والوصول
# ══════════════════════════════════════════════════


@app.get("/admin/access")
async def admin_access(request: Request):
    """قواعد الأقسام + أثرها المحسوب لكل صف."""
    return _admin_run(request, v3_access.list_admin)


@app.post("/admin/access/{section}")
async def admin_access_section(request: Request, section: str,
                               body: AccessSectionRequest):
    """الوضع العام لقسم — يعلو على كل قاعدة شريحة."""
    return _admin_run(request, lambda: v3_access.set_section(
        section, body.mode, body.message))


@app.post("/admin/access/{section}/rules")
async def admin_access_rules(request: Request, section: str,
                             body: AccessRulesRequest):
    """قواعد الشرائح لقسم — تُستبدل كاملةً."""
    return _admin_run(request, lambda: v3_access.set_rules(
        section, [r.model_dump() for r in body.rules]))


@app.get("/app/access")
async def app_access(request: Request, grade: int = 3, track: str = "علمي",
                     role: str = "student"):
    """👁️ ما يراه هذا الملفّ من الأقسام — يقرأه التطبيق في كل إقلاع.

    ⚠️ **عامّ عمداً وبلا توثيق**: لا يكشف بياناتِ أحد، بل *شكلَ الواجهة*
       لصفٍّ ومسار. وطلبُ توكنٍ له يعني شاشةً بيضاء للزائر قبل تسجيله.
       والحمايةُ الحقيقية ليست هنا أصلاً بل في `_require_section` على
       المسارات العاملة — فمن يكذب في صفّه هنا لا يربح شيئاً.
    """
    if not v3_ratelimit.check(request, "access",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return _json_response({"error": "⏳ محاولات كثيرة. انتظر قليلاً."}, 429)
    try:
        grade = grade if grade in (1, 2, 3) else 3
        # 🎭 الدور من قائمةٍ مغلقة: `admin` لا يُقبل من العميل هنا إطلاقاً،
        #    وإلا فتح كلُّ من كتبه في الرابط أقساماً أُخفيت عنه. والدور
        #    الحقيقي يقرؤه `_section_gate` من `users/{uid}` على المسارات
        #    العاملة — وهو الحارس الوحيد الذي يُعتدّ به.
        role = role if role in ("student", "teacher") else "student"
        return _json_response({"sections": v3_access.resolve(grade, track, role)})
    except Exception as e:
        print(f"⚠️ قراءة قواعد الوصول: {e}")
        # 🛟 فشلٌ مفتوح: عطلُ القواعد لا يُخفي المنصّة عن الطلاب.
        return _json_response({"sections": v3_access.resolve(None, "")})



# ══════════════════════════════════════════════════
# 🎟️ حصّة الطالب — رقمٌ يراه قبل أن يصطدم به
# ══════════════════════════════════════════════════
# 🔴 **ما كان يحدث:** `quota.peek()` موجودة في الخادم منذ البداية ولا
#    مسارَ يعرضها. فالطالب يذاكر ثم يُمنع **فجأةً** في منتصف درسه بلا أي
#    إنذار سابق. الرقم كان عندنا — إخفاؤه لم يكن قراراً، كان سهواً.

@app.get("/me/quota")
async def my_quota(request: Request):
    """المتبقي من أسئلة اليوم لصاحب التوكن — قراءةٌ لا تخصم شيئاً."""
    ident, denied = _identity_or_401(request)
    if denied is not None:
        return denied
    if not v3_ratelimit.check(request, ident.get("uid", ""),
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return _json_response({"error": "⏳ محاولات كثيرة. انتظر قليلاً."}, 429)
    return _json_response(
        await v3_quota.astatus(ident.get("uid", ""), ident.get("is_guest", False)))


# ══════════════════════════════════════════════════
# 📦 أدنى إصدارٍ مقبول — بوابةُ الإنقاذ الوحيدة بعد النشر
# ══════════════════════════════════════════════════
# ⭐ **تُضاف قبل أول نشر أو لا تُضاف أبداً.** يوم يتغيّر عقد الـAPI، النسخُ
#    القديمة في جيوب الطلاب تنكسر صامتةً ولا وسيلة لمخاطبتها — إلا أن تكون
#    قد علّمتها **من قبل** أن تسأل. وبعد النشر لا يمكن تعليمها.
#
# 🔓 عامٌّ بلا توثيق عمداً: يُنادى **قبل** تسجيل الدخول، وطلبُ توكنٍ له يعني
#    أن النسخة المكسورة لا تستطيع حتى أن تعرف أنها مكسورة.
# 🛟 ويفشل مفتوحاً: أي عطلٍ يعني «لا تحديث مطلوب» — قاعدةُ تحديثٍ معطوبة
#    لا يجوز أن تحجب التطبيق عن الطلاب.

@app.get("/app/version")
async def app_version(request: Request, platform: str = "", build: int = 0):
    """أدنى بناءٍ مدعوم + الأحدث المتاح، مع رسالةٍ ووجهةٍ للتحديث."""
    if not v3_ratelimit.check(request, "version",
                              v3_ratelimit.CONTENT_LIMIT, v3_ratelimit.CONTENT_WINDOW):
        return _json_response({"update_required": False}, 200)
    try:
        settings = v3_scholarships.get_settings()
    except Exception:
        settings = {}

    def _int(key, fallback=0):
        value = settings.get(key)
        return int(value) if isinstance(value, (int, float)) else fallback

    min_build = _int("min_build", 0)
    latest_build = _int("latest_build", 0)
    store_url = str(settings.get("store_url") or "")
    message = str(settings.get("update_message") or
                  "📦 صدر تحديثٌ مهم لمسار — حدّث التطبيق لتتابع بلا مشاكل.")

    return _json_response({
        "min_build": min_build,
        "latest_build": latest_build,
        # الإلزام يُحسَب في الخادم لا في التطبيق: نسخةٌ قديمة قد تحسبه خطأً،
        # وهي بالضبط النسخة التي نريد إلزامها.
        "update_required": bool(build and min_build and build < min_build),
        "update_available": bool(build and latest_build and build < latest_build),
        "message": message,
        "store_url": store_url,
        "platform": (platform or "")[:16],
    })


# ══════════════════════════════════════════════════
# 🔔 الإشعارات
# ══════════════════════════════════════════════════


# ══════════════════════════════════════════════════
# 📲 أجهزة الإشعارات
# ══════════════════════════════════════════════════
# 🔒 **الرمز يُكتب بالخادم وحده** — و`fcm_tokens` محظور على العميل في قواعد
#    Firestore. سببان: `arrayUnion` من العميل لا تُحدَّد بسقف، ورمزُ الجهاز
#    مفتاحُ وصولٍ إلى جيب الطالب فلا يُترك لعميلٍ يُعدَّل.


def _identity_or_401(request: Request):
    """يعيد (identity, None) أو (None, ردّ رفض) — للمسارات الشخصية."""
    token = v3_auth.bearer_token(request)
    if not token:
        return None, _json_response({"error": "⛔ تسجيل الدخول مطلوب."}, 401)
    try:
        return v3_auth.verify(token), None
    except v3_auth.AuthError as e:
        return None, _json_response({"error": str(e)}, 401)


@app.post("/me/device")
async def register_device(request: Request, body: DeviceTokenRequest):
    """يربط رمز هذا الجهاز بحساب صاحب التوكن."""
    ident, denied = _identity_or_401(request)
    if denied is not None:
        return denied
    # 🧪 الزائر لا يُسجَّل: حسابه مؤقت ويُرقّى، فرمزُه يُربط بحسابه الدائم
    #    عند التسجيل لا قبله — وإلا بقي مربوطاً بحسابٍ مجهولٍ مهجور.
    if ident.get("is_guest"):
        return _json_response({"registered": False, "reason": "guest"}, 200)
    try:
        return _json_response(v3_push.register(
            ident.get("uid", ""), body.token, body.platform))
    except v3_push.PushError as e:
        return _json_response({"error": str(e)}, 400)
    except Exception as e:
        print(f"⚠️ تسجيل جهاز: {e}")
        return _json_response({"error": "⚠️ تعذّر تسجيل الجهاز."}, 500)


@app.post("/me/profile-changed")
async def profile_changed(request: Request):
    """🔄 يُنادى بعد تبديل **الدور أو الصف أو المسار** من التطبيق.

    ⭐ **لماذا يلزم نداءٌ صريح؟** حارس الأقسام يقرأ `users/{uid}` بكاشٍ
       عمرُه دقيقتان ([core/access.py]) — قراءةٌ لكل طلبٍ ثمنٌ لا يُدفع
       لأجل قاعدة إخفاء. لكن معنى ذلك أن من حوّل نفسه إلى «معلّم» يبقى
       الخادمُ يعامله طالباً حتى تنقضي المهلة: يفتح قسمه فيُمنع، فيظن
       التحويل لم يعمل. هذا المسار يُسقط كاشَه وحده فيسري التحويل **فوراً**.

    🔒 ولا يقبل `uid` من الطلب: التوكن وحده يحدّد صاحبَ الكاش المُسقَط،
       وإلا أسقط أيُّ أحدٍ كاشَ غيره وأجبر الخادمَ على قراءةٍ لكل طلب.
    """
    ident, denied = _identity_or_401(request)
    if denied is not None:
        return denied
    uid = ident.get("uid", "")
    v3_access.forget_profile(uid)
    return _json_response({"refreshed": True})


@app.delete("/me/device")
async def unregister_device(request: Request, token: str = ""):
    """يفصل رمز الجهاز عن الحساب — يُنادى عند الخروج.

    ⚠️ لازمٌ لا تحسين: جوّالٌ يتشاركه أخوان يبقى رمزُه مربوطاً بالأول،
       فتصل إشعاراتُه إلى جهازٍ يستعمله الثاني.
    """
    ident, denied = _identity_or_401(request)
    if denied is not None:
        return denied
    return _json_response(v3_push.unregister(ident.get("uid", ""), token))


@app.get("/notifications/inbox")
async def notifications_inbox(request: Request, limit: int = 20):
    """📬 إشعارات هذا المستخدم — يقرأها التطبيق عند الإقلاع.

    ⚠️ **التوكن وحده يحدّد صاحب الصندوق**، ولا يقبل المسار `uid` من الطلب:
       لو قبله لقرأ كلُّ طالبٍ صندوقَ غيره بتغيير حرف.
    """
    token = v3_auth.bearer_token(request)
    if not token:
        return _json_response({"error": "⛔ تسجيل الدخول مطلوب.", "items": []}, 401)
    try:
        ident = v3_auth.verify(token)
    except v3_auth.AuthError as e:
        return _json_response({"error": str(e), "items": []}, 401)
    return _json_response({"items": v3_notify.inbox(ident.get("uid", ""), limit)})


@app.get("/admin/notifications")
async def admin_notifications(request: Request, limit: int = 50):
    """سجل الإشعارات + هل يوجد ناقل دفع أصلاً."""
    return _admin_run(request, lambda: v3_notify.list_admin(limit))


@app.post("/admin/notifications/preview")
async def admin_notifications_preview(request: Request,
                                      body: NotificationPreviewRequest):
    """👁️ عدد المستلمين وتفصيلهم — **قبل** الإرسال ولا يكتب شيئاً."""
    return _admin_run(request, lambda: v3_notify.preview(
        body.segment, body.notifications_only, body.uids, body.link))


@app.post("/admin/notifications")
async def admin_notification_create(request: Request,
                                    body: NotificationCreateRequest):
    """ينشئ الإشعار ويثبّت لقطة مستلميه."""
    return _admin_run(request, lambda: v3_notify.create(body.model_dump()))


@app.delete("/admin/notifications/{notif_id}")
async def admin_notification_delete(request: Request, notif_id: str):
    """حذف إشعار — يزيله من صناديق من لم يقرأه."""
    return _admin_run(request, lambda: v3_notify.delete(notif_id))


# ══════════════════════════════════════════════════
# 📥 أداة الإدخال — صور الدرس ← JSON بالقالب
# ══════════════════════════════════════════════════
# محميّة ببوابة الإدارة نفسها: تكتب في `data/` وتستهلك مفاتيح مدفوعة،
# فلا تُترك مفتوحة ولو محلياً.

@app.get("/ingest", response_class=HTMLResponse)
async def ingest_page():
    """صفحة الأداة — ملف واحد بلا خطوة بناء (مثل لوحة التحكم)."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ingest.html")
    if not os.path.isfile(path):
        return HTMLResponse("<h1>ingest.html غير موجود</h1>", status_code=404)
    with open(path, encoding="utf-8") as f:
        return HTMLResponse(f.read())


@app.get("/ingest/targets")
async def ingest_targets(request: Request, grade: int = 3, track: str = "علمي"):
    """المواد والوحدات الموجودة فعلاً لهذا الصف/المسار."""
    return _admin_run(request, lambda: v3_ingest.targets(grade, track))


@app.get("/ingest/models")
async def ingest_models(request: Request):
    """موديلات جيميناي المتاحة لهذا المفتاح — نسردها ولا نخمّنها."""
    denied = _admin_gate(request)
    if denied is not None:
        return denied
    try:
        return {"models": await v3_ingest.list_models(),
                "default_vision": v3_ingest.VISION_MODEL,
                "default_struct": v3_ingest.STRUCT_MODEL}
    except v3_ingest.IngestError as e:
        return _json_response({"error": str(e)}, 400)


@app.post("/ingest/run")
async def ingest_run(request: Request,
                     images: list[UploadFile] = File(...),
                     grade: int = Form(3),
                     track: str = Form("علمي"),
                     subject: str = Form(...),
                     mode: str = Form("lessons_mode"),
                     unit: str = Form(""),
                     lesson_name: str = Form(""),
                     vision_model: str = Form(""),
                     struct_model: str = Form(""),
                     math_audit: str = Form("")):
    """ينفّذ الخط كاملاً ويرجع التقرير — **بلا كتابة في data/**."""
    denied = _admin_gate(request)
    if denied is not None:
        return denied

    payload = []
    for up in images:
        raw = await up.read()
        if not raw:
            continue
        if len(raw) > v3_ingest.MAX_IMAGE_BYTES:
            return _json_response(
                {"error": f"⚠️ الصورة «{up.filename}» أكبر من الحد المسموح."}, 400)
        payload.append((raw, up.content_type or "image/jpeg"))

    audit_flag = None if math_audit == "" else (math_audit == "1")
    try:
        result = await v3_ingest.run(
            payload, grade, track, subject, mode, unit, lesson_name,
            vision_model, struct_model, audit_flag)
    except v3_ingest.IngestError as e:
        return _json_response({"error": str(e)}, 400)
    except Exception as e:
        print(f"⚠️ خطأ في أداة الإدخال: {e}")
        return _json_response({"error": f"⚠️ تعذّر التنفيذ: {e}"}, 500)
    return result


@app.post("/ingest/save")
async def ingest_save(request: Request, body: dict):
    """يكتب المخرجات في مكانها — بعد أن يراها المالك في التقرير."""
    denied = _admin_gate(request)
    if denied is not None:
        return denied
    try:
        return v3_ingest.save(
            body.get("grade", 3), body.get("track", "علمي"), body.get("subject", ""),
            body.get("mode", "lessons_mode"), body.get("unit", ""),
            body.get("lesson_name", ""), body.get("json"))
    except v3_ingest.IngestError as e:
        return _json_response({"error": str(e)}, 400)
    except Exception as e:
        print(f"⚠️ خطأ في حفظ الإدخال: {e}")
        return _json_response({"error": f"⚠️ تعذّر الحفظ: {e}"}, 500)


@app.get("/admin", response_class=HTMLResponse)
async def admin_page():
    """صفحة اللوحة نفسها — ملف واحد بلا خطوة بناء."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "admin.html")
    if not os.path.isfile(path):
        return HTMLResponse("<h1>admin.html غير موجود</h1>", status_code=404)
    with open(path, encoding="utf-8") as f:
        return HTMLResponse(f.read())


# =====================
# تشغيل التطبيق
# =====================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)