# models.py
"""
Pydantic Models للتحقق من البيانات
"""

from pydantic import BaseModel, Field, field_validator
from typing import List, Optional, Dict, Any

from config import HISTORY_MAX_MESSAGES, HISTORY_MAX_CHARS

# 📷 أقصى عدد صور في الطلب الواحد (قرار المالك)
MAX_IMAGES = 2

# 🧠 أقصى عدد دروس في اختبار واحد (قرار المالك)
MAX_QUIZ_LESSONS = 3

# ══════════════════════════════════════════════════
# 🧵 سجلُّ المحادثة — تطبيعٌ واحدٌ عند الباب
# ══════════════════════════════════════════════════
#
# 🔴 **أخطرُ عطبٍ في المشروع، ولم يظهر إلا اليوم (2026-09-14):** التطبيق
#    يخزّن ردَّ المساعد بالدور **"ai"** (`chat_controller.dart`: `"role": "ai"`)
#    ويُرسله في `chat_history` كما هو. و**كلُّ** مستهلكٍ في الخادم يُصفّي
#    `role in ("user", "assistant")` — فكانت ردودُ المساعد **تُحذف كلُّها**
#    قبل أن تصل الموديل.
#
#    والنتيجةُ هي كلُّ ما شكا منه المالك مجتمعاً:
#      • الموديلُ يرى **ستّ رسائلَ من الطالب بلا جوابٍ واحد** بينها، فيقرؤها
#        قائمةَ أسئلةٍ معلّقة ويحاول الإجابة عنها كلِّها («يحسب إن الرسائل
#        الست اللي جبناها للمدل ضروري تنشرح»).
#      • و«أعطني مثالاً» بلا موضوع: جوابُه السابق ليس أمامه أصلاً فيعتذر
#        بـ«هذه المعلومة غير متوفرة في الكتاب».
#      • و[common.has_prior_answer] — الحارسُ الذي بنيناه ليمنع الرفضَ في
#        المتابعة — كانت **تعود False دائماً** في التطبيق الحقيقي: تعمل في
#        اختباراتنا (نرسل "assistant") وتسقط عند الطالب.
#
# ⚖️ **ولماذا هنا لا في المستهلكين؟** لأنهم أكثرُ من عشرة، وأيُّ معالجٍ
#    يُكتب غداً سينسى التطبيع. والبابُ واحد: ما يدخل النموذج يخرج بأدوارٍ
#    قياسية، فلا يعرف أحدٌ بعده أن "ai" كانت موجودة.
#
# ⚠️ **والعلاجُ في الخادم لا في التطبيق وحده**: النسخُ المثبّتة على أجهزة
#    الطلاب ستبقى ترسل "ai" شهوراً بعد إصلاح الواجهة.

_ROLE_ALIASES = {
    "ai": "assistant", "bot": "assistant", "model": "assistant",
    "assistant": "assistant",
    "user": "user", "human": "user", "student": "user", "me": "user",
}


def normalize_history(v):
    """سقفٌ دفاعيّ على الحجم + **تطبيعُ الأدوار** — مصدرٌ واحد لكل النماذج.

    والدورُ غيرُ المعروف يبقى كما هو فيُسقطه المستهلكون كما كانوا: لا نخمّن
    أن رسالةً مجهولةَ المصدر جوابُ مساعدٍ فنضعها في فم الموديل.
    """
    if not v:
        return v
    trimmed = []
    for m in v[-HISTORY_MAX_MESSAGES:]:
        raw = str(m.get("role", ""))[:16].strip().lower()
        text = str(m.get("content", m.get("text", "")))[:HISTORY_MAX_CHARS]
        trimmed.append({"role": _ROLE_ALIASES.get(raw, raw), "content": text})
    return trimmed


class AskRequest(BaseModel):
    """نموذج طلب المستخدم الرئيسي.

    🔐 **الهوية من التوكن وحده.** `user_id` يُستبدل في `_authenticate` بالـuid
       المتحقَّق منه قبل أن يمسّه أيُّ معالج مادة. وسبب بقاء الحقل أصلاً أن
       معالجات المواد تُمفتِح جلساتها به (`sessions_math[req.user_id]`)؛ ولو
       بقي قادماً من الجسم لقرأ كلُّ طالبٍ جلسة غيره بتغيير حرف.
       فما يرسله العميل هنا **يُتجاهل ويُكتب فوقه** — لا يُقرأ أبداً.
    """
    user_id: str = Field(default="", max_length=128)
    subject: str = Field(max_length=64)
    logic_type: int = 1
    mode: str = Field(max_length=32)    # شرح، تلخيص، سؤال، وزاري
    input_type: str = Field(max_length=32)  # صفحة، وحدة، برومت
    content: str = Field(max_length=8000)   # ⛑️ سقف حجم الإدخال
    summary_level: int = 3              # 1-5 (للتلخيص)
    unit_name: Optional[str] = Field(default=None, max_length=256)
    lesson_name: Optional[str] = Field(default=None, max_length=256)
    chat_history: Optional[List[Dict[str, str]]] = None

    # 🧾 مُعرّف المحاولة — الحماية من الخصم المزدوج عند انتهاء المهلة.
    #    العميل يعيد **نفس** المعرّف عند إعادة المحاولة، فيرجع الردّ المخزّن
    #    بلا نداء موديل ولا خصم حصة ([core/idempotency.py]).
    request_id: str = Field(default="", max_length=64)

    # ── حقول النسخة الثالثة (اختيارية — العملاء القدامى لا يرسلونها) ──
    grade: int = 3                      # 1 | 2 | 3
    track: str = Field(default="علمي", max_length=16)   # عام | علمي | أدبي
    content_mode: Optional[str] = Field(default=None, max_length=16)  # lessons | pages

    # 📄 **الصفحات المختارة — بنيةٌ لا نصّ** (قرار المالك 2026-09-09).
    #
    # 🔴 كانت أرقام الصفحات تُستخرج بـ`re.findall(r"\d+")` من **كلام الطالب
    #    نفسه**، فكان عليه أن يكتب «13، 14، 15» بيده. وذلك يخلط النية
    #    بالمحتوى: من كتب «اشرح لي قانون نيوتن 2» طلب قانوناً لا صفحة،
    #    ومن كتب «الصفحة 40» ثم سأل سؤالاً تبعياً فقد صفحته.
    #
    # ⭐ والآن يختارها من قائمةٍ حقيقية فتصل **مفصولةً عن نصّه**، فتبقى
    #    معلّقةً مع الرسائل التالية ولا يلتقطها العدّاد من رقمٍ عابر.
    selected_pages: Optional[List[int]] = Field(default=None)

    @field_validator("selected_pages")
    @classmethod
    def _clean_pages(cls, v):
        """تنقيةٌ من التكرار والقيم المستحيلة — **بلا قصٍّ إلى الحدّ**.

        ⚠️ القصُّ الصامت هنا كان يبتلع رسالة «الصفحات زائدة»: من أرسل خمساً
           يأخذ ثلاثاً ولا يدري لماذا ضاعت اثنتان. فالحدّ يُفرض في المعالج
           برسالةٍ يراها الطالب، وهذا السقف حارسُ إساءةٍ لا حدُّ منتج.
        """
        if not v:
            return v
        seen, out = set(), []
        for n in v:
            if isinstance(n, int) and 0 < n < 10_000 and n not in seen:
                seen.add(n)
                out.append(n)
        return out[:50] or None

    # ── حقول يملؤها الخادم بعد قراءة الصور (لا تُقرأ من العميل) ──
    # `content` بعد الدمج يحمل ترويسة درع الحقن — ممتازة **للموديل**، لكنها
    # ضوضاء في **البحث الدلالي**. لذلك نفصل:
    #   search_text  = النص النظيف للبحث (سؤال الطالب + نص الصور بلا ترويسة)
    #   student_text = ما كتبه الطالب فقط (لاستخراج أرقام الصفحات)
    search_text: Optional[str] = None
    student_text: Optional[str] = None

    # 📷 صور اختيارية (base64) — حتى صورتين. Gemini يحوّلها نصاً ثم يمضي النص
    #    لموديل المادة المعتاد — فتعمل حتى مع DeepSeek الذي لا يدعم الرؤية.
    #    السقوف هنا حدّ أعلى خام؛ image_guard يتحقق بدقة (حجم + بصمة سحرية).
    images_base64: Optional[List[str]] = None
    # حقل مفرد للتوافق مع نسخ التطبيق الأقدم
    image_base64: Optional[str] = Field(default=None, max_length=2_100_000)

    @field_validator("images_base64")
    @classmethod
    def _cap_images(cls, v):
        if not v:
            return v
        # ⛑️ سقف صارم: صورتان كحد أقصى، وكل واحدة ضمن الحد الخام
        return [img for img in v[:MAX_IMAGES] if img and len(img) <= 2_100_000]

    @property
    def search_query(self) -> str:
        """ما يُرسل لمحرك البحث الدلالي — نظيفاً من ترويسة الصور."""
        return (self.search_text or self.content or "").strip()

    @property
    def page_source(self) -> str:
        """ما تُستخرج منه أرقام الصفحات — كتابة الطالب وحدها.
        وإلا التُقطت أرقام من داخل الصورة (120 · 8 · 100) كأنها صفحات."""
        return (self.student_text if self.student_text is not None else self.content) or ""

    def all_images(self) -> List[str]:
        """يوحّد الحقلين: القائمة الجديدة + الحقل المفرد القديم."""
        out = list(self.images_base64 or [])
        if self.image_base64:
            out.append(self.image_base64)
        return out[:MAX_IMAGES]

    @field_validator("summary_level")
    @classmethod
    def _clamp_level(cls, v):
        return min(5, max(1, v))        # قصّ بدل رفض — لا نكسر عميلاً قديماً

    @field_validator("grade")
    @classmethod
    def _clamp_grade(cls, v):
        return v if v in (1, 2, 3) else 3

    @field_validator("content_mode")
    @classmethod
    def _check_cmode(cls, v):
        return v if v in (None, "lessons", "pages") else None

    @field_validator("chat_history")
    @classmethod
    def _cap_history(cls, v):
        # ⛑️ سقفٌ دفاعيّ **وتطبيعُ الأدوار** — [normalize_history] أعلاه.
        return normalize_history(v)

class QuizRequest(BaseModel):
    """🧠 طلب توليد اختبار — من دروس الطالب وحدها ([31])."""
    user_id: str = Field(default="", max_length=128)   # يملؤه الخادم من التوكن
    request_id: str = Field(default="", max_length=64)
    subject: str = Field(max_length=64)
    grade: int = 3
    track: str = Field(default="علمي", max_length=16)
    unit: str = Field(default="", max_length=256)
    lessons: List[str] = Field(default_factory=list)
    count: int = 10

    @field_validator("grade")
    @classmethod
    def _clamp_grade_quiz(cls, v):
        return v if v in (1, 2, 3) else 3

    @field_validator("lessons")
    @classmethod
    def _cap_lessons(cls, v):
        # سقف المالك: ثلاثة دروس. القصّ بدل الرفض كي لا يُكسر عميل قديم.
        return [str(x)[:256] for x in (v or [])][:MAX_QUIZ_LESSONS]

    @field_validator("count")
    @classmethod
    def _check_count(cls, v):
        return v if v in (5, 10, 15) else 10


class VoiceCleanRequest(BaseModel):
    """🎤 طلب تنظيف نص صوتي — نص قصير فقط، بلا تاريخ محادثة."""
    user_id: str = Field(default="", max_length=128)   # يملؤه الخادم من التوكن
    text: str = Field(max_length=1600)   # أعلى قليلاً من سقف المعالجة (1200) ليُقص هناك
    # 📚 المادة قرينةٌ ترجّح المصطلح عند الالتباس الصوتي («الخميرة» ⇒ «النخامية»).
    subject: str = Field(default="", max_length=64)

class ChatMessage(BaseModel):
    """رسالة في الشات"""
    role: str
    text: str
    refs: List[str] = []

class ChatConversation(BaseModel):
    """محادثة كاملة"""
    id: str
    title: str
    subject: str
    mode: str
    messages: List[ChatMessage]

# ══════════════ لوحة التحكم ══════════════

class AdminBanRequest(BaseModel):
    """حظر مستخدم أو رفع حظره."""
    banned: bool


class AdminQuotaRequest(BaseModel):
    """حدّ يومي خاص بمستخدم — `None` يعيده للحدّ العام."""
    limit: Optional[int] = Field(default=None, ge=0, le=100000)


# ══════════════ 🎓 المنح ══════════════

class ScholarshipAskRequest(BaseModel):
    """💬 سؤال لمساعد منحة.

    📷 الصور مدعومة بنفس مسار `/ask`: Gemini يستخرج النص ثم يُدمج مع السؤال،
       والصورة لا تُحفظ ولا تُسجَّل — تبقى على جوال الطالب وحده ([27§3]).
       والاستعمال الحقيقي هنا: لقطة من موقع المنحة، أو كشف درجات، أو وثيقة.
    """
    user_id: str = Field(default="", max_length=128)   # يملؤه الخادم من التوكن
    request_id: str = Field(default="", max_length=64)
    scholarship_id: str = Field(max_length=64)
    question: str = Field(default="", max_length=1200)
    chat_history: Optional[List[Dict[str, str]]] = None

    # 📷 حتى صورتين — نفس سقف `/ask` وحارسه (`image_guard`).
    images_base64: Optional[List[str]] = None
    image_base64: Optional[str] = Field(default=None, max_length=2_100_000)

    @field_validator("images_base64")
    @classmethod
    def _cap_sch_images(cls, v):
        if not v:
            return v
        return [img for img in v[:MAX_IMAGES] if img and len(img) <= 2_100_000]

    def all_images(self) -> List[str]:
        """يوحّد الحقلين — كما في AskRequest تماماً."""
        out = list(self.images_base64 or [])
        if self.image_base64:
            out.append(self.image_base64)
        return out[:MAX_IMAGES]

    @field_validator("chat_history")
    @classmethod
    def _cap_sch_history(cls, v):
        # نفس سقف /ask الدفاعي — مصدر الرقم واحد في config.py.
        return normalize_history(v)


class ScholarshipUpsertRequest(BaseModel):
    """نموذج اللوحة: إنشاء/تحديث منحة.

    ⚠️ التحقق التفصيلي في `core/scholarships.validate` لا هنا — كي تكون
       الرسالة عربية موجّهة للأدمن بدل خطأ 422 الخام من Pydantic.
    """
    id: Optional[str] = Field(default=None, max_length=64)
    name: str = Field(default="", max_length=200)
    country: str = Field(default="", max_length=100)
    flag: str = Field(default="", max_length=8)
    cover_url: str = Field(default="", max_length=500)
    logo_url: str = Field(default="", max_length=500)
    website: str = Field(default="", max_length=500)
    short_desc: str = Field(default="", max_length=300)
    about: str = Field(default="", max_length=8000)
    requirements: List[str] = Field(default_factory=list)
    how_to_apply: List[str] = Field(default_factory=list)
    benefits: List[str] = Field(default_factory=list)
    documents: List[str] = Field(default_factory=list)
    fields: List[str] = Field(default_factory=list)
    degree_levels: List[str] = Field(default_factory=list)
    open_date: str = Field(default="", max_length=10)
    close_date: str = Field(default="", max_length=10)
    funding_type: str = Field(default="full", max_length=16)
    gradient: List[str] = Field(default_factory=list)
    enabled: bool = True
    order: int = 0
    assistant_prompt: Optional[str] = Field(default=None, max_length=8000)

    @field_validator("requirements", "how_to_apply", "benefits",
                     "documents", "fields", "degree_levels", mode="before")
    @classmethod
    def _split_text_block(cls, v):
        """اللوحة تحرّر هذه القوائم في مربّع نص (سطر لكل عنصر).

        فنقبل النصّ كما نقبل المصفوفة: أداةُ أدمن ترسل نصاً خاماً لا يجوز
        أن ترتدّ بخطأ 422 غامض بدل رسالة عربية.
        """
        return v.splitlines() if isinstance(v, str) else v


class ScholarshipEnabledRequest(BaseModel):
    """مفتاح الإظهار/الإخفاء الفوري."""
    enabled: bool


class ScholarshipReorderRequest(BaseModel):
    """ترتيب العرض — أول معرّف أعلى القائمة."""
    ids: List[str] = Field(default_factory=list)


class ScholarshipPromptRequest(BaseModel):
    """🔒 برومبت مساعد المنحة — يُحفظ في مجموعة موازية لا في مستند المنحة."""
    assistant_prompt: str = Field(default="", max_length=8000)


class ScholarshipTryRequest(BaseModel):
    """🧪 «جرّب البرومبت» من اللوحة — قبل النشر، بلا حصة ولا حساب طالب."""
    question: str = Field(default="", max_length=1200)
    assistant_prompt: Optional[str] = Field(default=None, max_length=8000)
    chat_history: Optional[List[Dict[str, str]]] = None

    # ⚠️ وكان هذا النموذج **بلا مُحقِّقٍ أصلاً**: تجربةُ البرومبت من اللوحة
    #    لا تُطبّع الأدوار ولا تحدّ الحجم، فتُري المشرفَ سلوكاً غير الذي
    #    يراه الطالب — وهي بالضبط الشاشةُ التي يُفترض أن تحاكيه.
    @field_validator("chat_history")
    @classmethod
    def _cap_try_history(cls, v):
        return normalize_history(v)


class ScholarshipCoverRequest(BaseModel):
    """🖼️ غلاف المنحة — يصل مقصوصاً ومضغوطاً من اللوحة. الفراغ يحذفه."""
    image_base64: str = Field(default="", max_length=800_000)


class BannerRequest(BaseModel):
    """🎏 بانر قسم — كل حقوله تُطبَّع وتُتحقَّق في `core/banners.validate`."""
    section: str = Field(default="home", max_length=32)
    # 🎯 الفئة المستهدفة — تُتحقَّق مقابل [audience.ACCESS_SEGMENTS] في الوحدة.
    segment: str = Field(default="all", max_length=24)
    title: str = Field(default="", max_length=80)
    subtitle: str = Field(default="", max_length=120)
    icon: str = Field(default="star", max_length=32)
    colors: List[str] = Field(default_factory=list, max_length=4)
    action: str = Field(default="none", max_length=32)
    action_value: str = Field(default="", max_length=500)
    enabled: bool = True
    order: int = Field(default=0, ge=0, le=999)
    start_date: str = Field(default="", max_length=10)
    end_date: str = Field(default="", max_length=10)


class BannerTemplatesRequest(BaseModel):
    """🤖 قوالب البانر التلقائي — قاموس {مفتاح القالب: حقوله}."""
    templates: Dict[str, Dict[str, Any]] = Field(default_factory=dict)


class AvatarRequest(BaseModel):
    """👤 صورة الحساب — تصل من التطبيق مقصوصةً مربّعةً ومضغوطة. الفراغ يحذفها.

    ⚠️ الهويّة **لا تُقرأ من الجسم**: `uid` يُستخرج من توكن Firebase في
       `_authenticate`، وإلا استطاع أيُّ أحد استبدال صورة أيِّ حساب.
    """
    image_base64: str = Field(default="", max_length=400_000)


class AdminSettingsRequest(BaseModel):
    """⚙️ الإعدادات العامة القابلة للتحرير من اللوحة."""
    quota_ask: Optional[int] = Field(default=None, ge=1, le=1000)
    quota_guest: Optional[int] = Field(default=None, ge=0, le=100)

    # 📦 بوابة التحديث الإلزامي — ترفعها اللوحة بلا إصدار تطبيق جديد.
    min_build: Optional[int] = Field(default=None, ge=0, le=100000)
    latest_build: Optional[int] = Field(default=None, ge=0, le=100000)
    store_url: Optional[str] = Field(default=None, max_length=300)
    update_message: Optional[str] = Field(default=None, max_length=300)


# ══════════════════════════════════════════════════
# 👨‍🏫 مساعد المعلم
# ══════════════════════════════════════════════════

class TeacherAskRequest(BaseModel):
    """👨‍🏫 طلب مساعد المعلم — **الدروس وحدها** لا الوحدات ولا الصفحات.

    الحقول متعمَّدة القرب من `AskRequest`: التطبيق يستعمل **نفس شاشة الشات
    ونفس المتحكّم**، ولا يختلف إلا في الوجهة والإعدادات ([33]).

    `generate=True` ⇒ ضغط زر الأداة (خطة/تبسيط/واجب) فيُستعمل برومبت التوليد.
    `generate=False` ⇒ رسالة متابعة عادية فيُستعمل برومبت المحادثة.
    """
    user_id: str = Field(default="", max_length=128)   # يملؤه الخادم من التوكن
    request_id: str = Field(default="", max_length=64)

    tool: str = Field(default="ask", max_length=32)      # plan|simplify|homework|ask
    generate: bool = False

    subject: str = Field(default="", max_length=64)
    grade: int = 3
    track: str = Field(default="علمي", max_length=16)
    unit_name: Optional[str] = Field(default=None, max_length=256)
    lesson_name: Optional[str] = Field(default=None, max_length=256)

    content: str = Field(default="", max_length=8000)    # رسالة المعلّم
    concept: str = Field(default="", max_length=200)     # لأداة التبسيط
    difficulty: str = Field(default="متوسط", max_length=16)
    count: int = 10

    chat_history: Optional[List[Dict[str, str]]] = None

    # 📷 حتى صورتين — نفس مسار `/ask` وحارسه حرفياً.
    images_base64: Optional[List[str]] = None
    image_base64: Optional[str] = Field(default=None, max_length=2_100_000)

    @field_validator("images_base64")
    @classmethod
    def _cap_teacher_images(cls, v):
        if not v:
            return v
        return [img for img in v[:MAX_IMAGES] if img and len(img) <= 2_100_000]

    def all_images(self) -> List[str]:
        out = list(self.images_base64 or [])
        if self.image_base64:
            out.append(self.image_base64)
        return out[:MAX_IMAGES]

    @field_validator("grade")
    @classmethod
    def _clamp_teacher_grade(cls, v):
        return v if v in (1, 2, 3) else 3

    @field_validator("chat_history")
    @classmethod
    def _cap_teacher_history(cls, v):
        # نفس السقف الدفاعي في /ask و/scholarship/ask — مصدر الرقم config.py.
        return normalize_history(v)


class TeacherPromptRequest(BaseModel):
    """💬 حفظ برومبت أداة من اللوحة. الفراغ = العودة لبرومبت الكود."""
    kind: str = Field(default="chat", max_length=16)      # generate | chat
    prompt: str = Field(default="", max_length=12000)


class TeacherTryRequest(BaseModel):
    """🧪 «جرّب البرومبت» — يجرّب المسودّة غير المحفوظة داخل اللوحة."""
    kind: str = Field(default="chat", max_length=16)
    prompt: Optional[str] = Field(default=None, max_length=12000)
    question: str = Field(default="", max_length=2000)
    subject: str = Field(default="", max_length=64)
    grade: int = 3
    track: str = Field(default="علمي", max_length=16)
    unit_name: str = Field(default="", max_length=256)
    lesson_name: str = Field(default="", max_length=256)


# ══════════════ 📈 التحليلات · 🔐 الوصول · 🔔 الإشعارات ══════════════
# ⚠️ كلها مسارات إدارية: التحقق هنا **طبقةٌ ثانية** فوق تحقق الوحدات نفسها،
#    لا بديلٌ عنه. الواجهة قد تُتجاوَز، والوحدة هي آخر من يرى المدخل.

class AccessSectionRequest(BaseModel):
    """الوضع العام لقسم: مفتوح · قريباً · مُخفى."""
    mode: str = Field(default="on", max_length=8)
    message: str = Field(default="", max_length=160)


class AccessRuleItem(BaseModel):
    """قاعدة شريحة واحدة داخل قسم."""
    segment: str = Field(max_length=24)
    mode: str = Field(default="off", max_length=8)
    message: str = Field(default="", max_length=160)


class AccessRulesRequest(BaseModel):
    """قواعد قسمٍ كاملةً — تُستبدل ولا تُدمج ([access§set_rules])."""
    rules: List[AccessRuleItem] = Field(default_factory=list, max_length=12)


class NotificationPreviewRequest(BaseModel):
    """👁️ ملخّص الجمهور قبل الإرسال — لا يكتب شيئاً.

    ⚠️ `link` جزءٌ من الجمهور لا زينة: مفتاحُ «إشعارات المنح» في التطبيق
       يُقصي صاحبه من إشعار المنح وحده — فمعاينةٌ بلا `link` تعرض عدداً
       يخالف من يصله فعلاً.
    """
    segment: str = Field(default="all", max_length=24)
    notifications_only: bool = True
    link: str = Field(default="none", max_length=24)
    uids: Optional[List[str]] = Field(default=None, max_length=500)


class NotificationCreateRequest(BaseModel):
    """إنشاء إشعار مستهدَف."""
    title: str = Field(default="", max_length=80)
    body: str = Field(default="", max_length=300)
    segment: str = Field(default="all", max_length=24)
    link: str = Field(default="none", max_length=24)
    notifications_only: bool = True
    uids: Optional[List[str]] = Field(default=None, max_length=500)



class DeviceTokenRequest(BaseModel):
    """📲 رمز جهاز للإشعارات — يُسجَّل عند الإقلاع ويُفصَل عند الخروج.

    ⚠️ الهويّة **لا تُقرأ من الجسم**: `uid` من توكن Firebase حصراً، وإلا
       ربط أيُّ أحدٍ جهازَه بحساب غيره فوصلته إشعاراتُه.
    """
    token: str = Field(default="", max_length=4096)
    platform: str = Field(default="", max_length=16)
