# 🚀 منصة مسار — وثيقة المواصفات التقنية الكاملة (من الألف إلى الياء)

> **الغرض من هذا الملف:** وثيقة تنفيذية شاملة تُعطى للذكاء الاصطناعي/المطور لبناء تحويل تطبيق "مسار" الحالي إلى منصة تعليمية متكاملة للطالب اليمني (من أول ثانوي حتى ما بعد التخرج والمنح).
> **القاعدة الذهبية للمشروع:** كل محتوى متغيّر (برومبتات، منح، خدمات، بانرات، أسئلة مقترحة) يُدار من السيرفر/Firestore ويصل للطلاب فوراً **بدون تحديث للتطبيق**.
> **القاعدة الثانية:** فاتورة Firestore يجب أن تبقى شبه صفرية — كل التصميم أدناه مبني على تقليل القراءات (راجع قسم 12).

> ### 🔧 سجل تعديلات هذه النسخة (v2.1 — مصححة)
> 1. **هيكلة Firestore أُصلحت:** لم يعد هناك مجموعات فرعية غير صالحة تحت `config/` — البرومبتات والمنح والخدمات والبانرات والأسئلة المقترحة أصبحت **مجموعات مستقلة (top-level)**، و`config/` بقيت مستندات مفردة فقط. (المسار القديم `config/prompts/{id}` غير صالح أصلاً في Firestore لأن المسارات تتناوب collection/document.)
> 2. **ثغرة قواعد الأمان أُغلقت:** في rules v2 النمط `{doc=**}` يطابق المستند الأب نفسه، ما كان يسمح للطالب بتعديل حقل `role` وترقية نفسه أدمن. القواعد الجديدة تفصل مستند المستخدم عن فروعه وتمنع تعديل `role` نهائياً.
> 3. **البرومبتات أصبحت سرية:** مجموعة `prompts/` قراءتها وكتابتها للأدمن فقط. الباك اند يقرأها بـ Admin SDK (يتجاوز القواعد)، والطالب لا يستطيع الاطلاع على برومبتات النظام إطلاقاً ولا يكيّشها.
> 4. **سلوك الروبوت تغيّر:** بدل الظهور الدائم في كل الشاشات، الروبوت يظهر **جولة تعريفية لمرة واحدة** عند أول دخول للـ Home ثم يختفي، مع سويتش في الإعدادات يعيده لكل الشاشات لمن يريده (قسم 7).
> 5. **حد يومي لاستخدام الذكاء الاصطناعي (Quota):** كل مستخدم له سقف طلبات يومي في الباك اند (قسم 3.6) — حماية فاتورة الـ AI من الاستخدام المسيء أو السكربتات.
> 6. **سياق المحادثة صار من العميل:** الفرونت يرسل آخر 6 رسائل من المحادثة مع كل طلب `/ask` (قسم 3.7) — المودل يفهم السياق، والباك يصير stateless فلا يتضرر من إعادة تشغيل Hugging Face.

---

# 0. ملخص النظام الحالي (نقطة البداية)

## 0.1 الفرونت (Flutter — موجود ويعمل)
- بنية نظيفة: `core/` + `features/` (chat, onboarding, instructions).
- شات RTL كامل مع Typewriter، وضع داكن، Hive للمحادثات محلياً، خط Cairo.
- المواد: أحياء، فيزياء، كيمياء، عربي، إنجليزي، رياضيات — بأوضاع (شرح/تلخيص/سؤال/وزاري).
- `ChatController` (ChangeNotifier) يحمل كل الحالة، `ChatRepository` للاتصال بـ `/ask`.
- نظام التفعيل بالأكواد **محذوف** حالياً ويُستبدل في هذا المشروع بـ Firebase Auth.

## 0.2 الباك (FastAPI — موجود ويعمل على Hugging Face Spaces)
- `/ask` نقطة رئيسية توجّه حسب المادة إلى handlers (biology/physics/chemistry/arabic/english/math).
- RAG: FAISS + sentence-transformers على ملفات JSON للكتب في `data/subjects/{subject}/`.
- الموديلات الحالية: **Gemini Flash-Lite** (أحياء/عربي/إنجليزي)، **GPT-4o-mini** (فيزياء/كيمياء)، **DeepSeek** (رياضيات). ⚠️ **تبقى كما هي بدون تغيير** — فقط تُنقل نصوص البرومبتات لتُقرأ من Firestore مع كاش.
- جلسات بالذاكرة (sessions dicts) مع تنظيف كل 30 دقيقة.

---

# 1. التقنيات والأدوات المعتمدة

| الطبقة | التقنية | ملاحظات |
|---|---|---|
| تطبيق الطالب | Flutter (Dart) — نفس المشروع الحالي | Android أولاً |
| لوحة التحكم | Flutter Web — مشروع منفصل يشارك حزمة models | نفس اللغة، إعادة استخدام كود |
| التوثيق | Firebase Auth (Email/Password + Anonymous) | مجاني |
| قاعدة البيانات | Cloud Firestore | مع استراتيجية خفض تكلفة صارمة (قسم 12) |
| تخزين الملفات | Firebase Storage | صور المنح/البانرات/صور الطلاب |
| الإشعارات | Firebase Cloud Messaging (FCM) | مجاني |
| المراقبة | Firebase Crashlytics + Analytics | مجاني |
| الباك اند | FastAPI الحالي (Hugging Face) + firebase-admin | يضاف التحقق من التوكن + كاش الإعدادات |
| الذكاء الاصطناعي | كما هو حالياً: Gemini Flash-Lite / GPT-4o-mini / DeepSeek | Flash-Lite أيضاً لروبوت المساعدة وشات المنح واختبار الميول |
| أنيميشن الروبوت | Rive (`rive` package) — روبوت جاهز من مجتمع Rive مبدئياً | State Machine بحالات: idle, talk, point, wave, think |
| الصوت | `speech_to_text` (STT) + `flutter_tts` (TTS) | **مجاني — محركات الجهاز** |
| المحلي | Hive (موجود) + SharedPreferences (موجود) | Hive يبقى المصدر الأول للعرض |

حزم Flutter الجديدة المطلوبة:
`firebase_core, firebase_auth, cloud_firestore, firebase_storage, firebase_messaging, firebase_crashlytics, firebase_analytics, rive, speech_to_text, flutter_tts, image_picker, cached_network_image, carousel_slider, screenshot, share_plus, connectivity_plus`

---

# 2. هيكلة Firestore الكاملة (المصححة)

> ⚠️ **قاعدة بنيوية:** مسارات Firestore تتناوب إلزامياً collection→document→collection. لذلك لا يمكن وضع "مجموعة" مباشرة داخل مجموعة `config`. الحل: `config/` مجموعة تحتوي **مستندات مفردة فقط**، وكل ما هو قائمة مستندات يصبح **مجموعة مستقلة top-level**.

```
firestore/
│
├── config/                              ← مستندات مفردة فقط (singletons)
│   ├── meta                             ← { version: 17, updated_at }  ★ مفتاح خفض التكلفة
│   ├── app_settings                     ← { min_version, maintenance_mode: bool,
│   │                                        maintenance_message, sections_enabled:
│   │                                        {education, scholarships, quiz, services},
│   │                                        quota_ask: 50, quota_light: 30 }  ← حدود 3.6
│   ├── aptitude_test                    ← { questions: [ {id, text, options:[..],
│   │                                        dimension: "scientific"|"literary"|"technical"
│   │                                        |"medical"|"business"} ] × 15 }
│   └── robot_intros                     ← { home: "أهلاً! أنا مساعدك...", ... }
│                                           نصوص جولة الروبوت التعريفية (override اختياري
│                                           للنصوص الثابتة بالكود — قابلة للقراءة من الطالب)
│
├── prompts/{promptId}   🔒 أدمن فقط    ← { id, title, scope: "screen"|"subject"|"scholarship"
│   │                                        |"aptitude"|"quiz_gen", text, updated_at, updated_by }
│   │     أمثلة promptId:
│   │       robot_screen_home, robot_screen_education, robot_screen_scholarship_list,
│   │       robot_screen_quiz, robot_screen_services,
│   │       subject_biology_explain, subject_math_explain, ... (نقل برومبتات الباك الحالية)
│   │       aptitude_test_system, quiz_generator_system
│   │     ★ لا يقرؤها تطبيق الطالب أبداً ولا تدخل كاشه — الباك اند يقرأها بـ Admin SDK
│
├── suggested_questions/{subjectId}      ← { subject, mode, questions: ["اشرح لي الدرس", ...] }
│
├── services/{serviceId}                 ← { title, description, icon: "cv"|"letter"|...,
│                                            color_hex, whatsapp_number, whatsapp_message,
│                                            order, enabled }
│
├── banners/{bannerId}                   ← { image_url, target_type: "scholarship"|"url"|"none",
│                                            target_id, order, enabled }
│
├── scholarships/{schId}                 ← { name, country, cover_url, logo_url,
│                                            short_desc, about, requirements: [..],
│                                            how_to_apply, open_date, close_date,
│                                            funding_type: "full"|"partial",
│                                            assistant_prompt,  ← برومبت مساعد المنحة
│                                            enabled, order, updated_at }
│   ★ ملاحظة: assistant_prompt يقرؤه الباك اند فقط عبر /scholarship/ask. لمنع الطالب من
│     قراءته: يُخزَّن في مجموعة موازية scholarship_prompts/{schId} (أدمن فقط) بدل حقله هنا،
│     وبقية بيانات المنحة تبقى قابلة للقراءة للطلاب.
│
├── scholarship_prompts/{schId} 🔒 أدمن  ← { assistant_prompt, updated_at }
│
├── users/{uid}
│   ├── (المستند نفسه)                   ← { name, email, grade: 1|2|3, photo_url,
│   │                                        role: "student"|"admin", created_at,
│   │                                        fcm_token, is_anonymous, settings:
│   │                                        {dark_mode, font_size, auto_tts} }
│   ├── conversations/{convId}           ← { title, subject, grade, mode, created_at,
│   │                                        last_updated, messages: [                ★ مصفوفة
│   │                                          {role, text, refs:[..], ts} ] }          داخل مستند
│   ├── saved_answers/{saveId}           ← { subject, text, source_conv, created_at }  واحد
│   └── results/{resultId}               ← { type: "quiz"|"aptitude", subject?, unit?,
│                                            score, total, wrong_topics: [..],       ★ خريطة
│                                            report_text?, created_at }                 نقاط الضعف
│
└── stats/                               ← عدادات مجمعة للوحة التحكم (يكتبها الباك اند)
    └── daily/{yyyy-mm-dd}               ← { requests_total, requests_by_subject: {..},
                                             requests_by_grade: {..}, new_users }
```

## 2.1 قواعد الأمان (Firestore Security Rules) — إلزامية (النسخة المصححة)

> ⚠️ **درسان مهمان وراء هذه النسخة:**
> **(أ)** في rules_version 2 النمط `{doc=**}` يطابق **صفر مقاطع أو أكثر**، أي أن `match /users/{uid}/{doc=**}` يطابق مستند `/users/{uid}` نفسه. ولأن القواعد تعمل بمنطق OR (أي قاعدة تسمح = العملية تمر)، كانت النسخة القديمة تسمح للطالب بكتابة `role: "admin"` في مستنده وترقية نفسه. الحل: **فصل قاعدة المستند الأب عن قاعدة الفروع** بنمط لا يطابق الأب (`/{col}/{docId}`).
> **(ب)** البرومبتات سرية: الباك اند يقرأها بـ Admin SDK الذي **يتجاوز هذه القواعد كلياً**، فلا يوجد أي سبب لجعلها قابلة للقراءة من العميل.

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn() {
      return request.auth != null;
    }
    function isAdmin() {
      return isSignedIn() &&
        get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // ── محتوى عام: يقرؤه أي مستخدم موثق (يشمل الزائر anonymous)، يكتبه الأدمن فقط ──
    match /config/{doc} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }
    match /suggested_questions/{doc} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }
    match /services/{doc} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }
    match /banners/{doc} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }
    match /scholarships/{doc} {
      allow read: if isSignedIn();
      allow write: if isAdmin();
    }

    // ── 🔒 البرومبتات: أدمن فقط قراءةً وكتابةً — الطالب لا يراها أبداً ──
    match /prompts/{doc} {
      allow read, write: if isAdmin();
    }
    match /scholarship_prompts/{doc} {
      allow read, write: if isAdmin();
    }

    // ── مستند المستخدم نفسه (الأب) — قاعدة مستقلة تحمي حقل role ──
    match /users/{uid} {
      allow read: if isSignedIn() && request.auth.uid == uid;
      // عند الإنشاء: الدور إجبارياً "student" (الأدمن يُعيَّن يدوياً من الكونسول/Admin SDK)
      allow create: if isSignedIn() && request.auth.uid == uid &&
        request.resource.data.role == 'student';
      // عند التحديث: ممنوع لمس حقل role نهائياً
      allow update: if isSignedIn() && request.auth.uid == uid &&
        !("role" in request.resource.data.diff(resource.data).affectedKeys());
      allow delete: if isSignedIn() && request.auth.uid == uid;
    }

    // ── فروع المستخدم فقط (conversations / saved_answers / results) —
    //    النمط /{col}/{docId} لا يطابق المستند الأب، فلا التفاف على قاعدة role ──
    match /users/{uid}/{col}/{docId} {
      allow read, write: if isSignedIn() && request.auth.uid == uid;
    }

    match /stats/{doc=**} {
      allow read: if isAdmin();
      allow write: if false;   // الكتابة من الباك اند بـ Admin SDK فقط
    }
  }
}
```

**اختبار إلزامي قبل النشر (Rules Playground أو الـ Emulator):** (1) طالب يحاول `update` على مستنده بحقل `role: "admin"` → **يُرفض**. (2) طالب يقرأ `prompts/subject_biology_explain` → **يُرفض**. (3) طالب يقرأ `scholarships/x` ويكتب في `users/{uid}/conversations/y` → **يُسمح**. (4) زائر anonymous يقرأ `config/meta` → **يُسمح**.

---

# 3. الباك اند (FastAPI) — التعديلات المطلوبة

## 3.1 الأمان: استبدال نظام الأكواد بتوكن Firebase
- إضافة `firebase-admin` واعتماد Service Account (متغير بيئة `FIREBASE_CREDENTIALS_JSON`).
- **حذف** كل منطق `codes.json` / `verify_code` / حقلي `code` و`device_id` من `AskRequest`.
- Dependency جديد يُطبق على كل المسارات المحمية:

```python
from fastapi import Header, HTTPException
from firebase_admin import auth as fb_auth

async def get_current_user(authorization: str = Header(...)):
    try:
        token = authorization.replace("Bearer ", "")
        decoded = fb_auth.verify_id_token(token)
        return decoded  # فيه uid, email...
    except Exception:
        raise HTTPException(401, detail={"answer": "⛔ جلسة غير صالحة. سجّل الدخول مجدداً."})
```

- الفرونت يرسل `Authorization: Bearer <idToken>` مع كل طلب (يُجدَّد تلقائياً عبر `user.getIdToken()`).

## 3.2 دعم الصفوف الثلاثة
- هيكلة البيانات تصبح: `data/subjects/{grade}/{subject}/...` حيث grade ∈ {grade1, grade2, grade3}.
  - **ترحيل:** المحتوى الحالي يُنقل كما هو إلى `grade3/`. مجلدا grade1 و grade2 يُنشآن فارغين بنفس البنية (التطبيق يتعامل مع المادة الفارغة برسالة "المحتوى قيد الإضافة 🚧" — تأتي من `app_settings`).
- إضافة حقل `grade: int` إلى `AskRequest` وإلى كل مسارات GET:
  `/subjects/units?grade=3&subject=احياء` ... إلخ. كل دوال المسارات في `common.py` تستقبل grade وتبني المسار به.
- كاش الكتب (`_book_cache`) يتحول إلى قاموس مفتاحه `(grade, subject)`.

## 3.3 البرومبتات من Firestore (مع كاش)
```python
# prompts_store.py
import time
from firebase_admin import firestore

_cache = {}; _cache_ts = 0; CACHE_TTL = 300  # 5 دقائق

def get_prompt(prompt_id: str, fallback: str = "") -> str:
    global _cache, _cache_ts
    if time.time() - _cache_ts > CACHE_TTL:
        db = firestore.client()
        # ★ مجموعة top-level باسم "prompts" — المسار القديم "config/prompts" غير صالح
        _cache = {d.id: d.to_dict().get("text", "") for d in db.collection("prompts").stream()}
        _cache_ts = time.time()
    return _cache.get(prompt_id) or fallback
```
- الباك اند يقرأ بـ Admin SDK فيتجاوز قواعد الأمان — لهذا صار ممكناً جعل `prompts/` أدمن-فقط دون كسر أي شيء.
- كل استدعاء لدوال `system_prompt_strict_explain(...)` وأخواتها يصبح: يجرب `get_prompt("subject_biology_explain")` وإن لم يوجد يستخدم النص الحالي في الكود كـ fallback (لا ينكسر شيء أبداً).
- ⚠️ الكاش 5 دقائق يعني قراءة Firestore واحدة كل 5 دقائق مهما كان عدد الطلبات — لا تلمس الفاتورة.

## 3.4 المسارات الجديدة

| المسار | الطريقة | الوظيفة |
|---|---|---|
| `/ask` | POST | كما هو + grade + توثيق بالتوكن + دعم صورة (3.5) + `chat_history` آخر 6 رسائل (3.7) + فحص Quota أول سطر (3.6) |
| `/robot/ask` | POST | `{screen_id, question, grade}` → برومبت الشاشة من Firestore + سؤال الطالب → Flash-Lite → رد قصير (max_tokens=500) |
| `/scholarship/ask` | POST | `{scholarship_id, question, chat_history}` → يقرأ البرومبت من `scholarship_prompts/{schId}` 🔒 + بيانات المنحة من `scholarships/{schId}` (بكاش 5 دقائق) ويحقنهما كـ system → Flash-Lite |
| `/quiz/generate` | POST | `{grade, subject, unit, count}` → يسحب نصوص الوحدة من JSON → برومبت `quiz_gen` → **إخراج JSON صارم**: `{questions:[{q, options:[4], correct_index, topic}]}` مع إعادة محاولة مرة واحدة عند فشل الـ parsing |
| `/aptitude/analyze` | POST | `{answers:[{question_id, choice_index}]}` → يقرأ الأسئلة والأبعاد من Firestore → برومبت `aptitude_test_system` → تقرير: `{top_fields:[..], report_text, suggested_majors:[..]}` |
| `/stats/log` | داخلي | بعد كل `/ask` ناجح: `db.doc(f"stats/daily/{today}").set({...}, merge=True)` بزيادة `firestore.Increment(1)` — كتابة واحدة لكل طلب |

## 3.5 دعم الصور في `/ask`
- حقل اختياري `image_base64: Optional[str]` في `AskRequest`.
- عند وجوده: تُرسل ضمن رسالة المستخدم بصيغة OpenAI-compatible للـ Gemini:
```python
{"role": "user", "content": [
  {"type": "text", "text": user_prompt},
  {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img}"}}
]}
```
- المواد التي على GPT-4o-mini تدعم نفس الصيغة. للرياضيات (DeepSeek لا يدعم صور): الصورة تُحوَّل أولاً لنص عبر Flash-Lite ("استخرج نص المسألة من الصورة") ثم يُكمل DeepSeek — خطوتان شفافتان للطالب.
- حد أقصى لحجم الصورة من الفرونت: ضغط إلى ≤ 800px عرض، jpeg جودة 70.

## 3.6 الحد اليومي لاستخدام الذكاء الاصطناعي (Quota) — حماية الفاتورة ⭐

**المشكلة:** التوكن يثبت الهوية لكنه لا يمنع الاستنزاف — طالب واحد يكتب سكربت (أو يستخدم بجنون) يقدر يضاعف فاتورة الموديلات. فاتورة Firestore محمية بقسم 12، وهذا القسم يحمي فاتورة الـ AI (وهي الأكبر).

**التصميم (بسيط بالذاكرة — صفر قراءات Firestore):**
```python
# quota.py
from datetime import date
from fastapi import HTTPException

_counters: dict = {}   # { uid: {"day": "2026-07-18", "ask": 0, "light": 0} }

LIMITS = {"ask": 50, "light": 30}   # ask = /ask | light = روبوت + منح + اختبارات مجمعة

def check_quota(uid: str, kind: str):
    today = date.today().isoformat()
    c = _counters.get(uid)
    if not c or c["day"] != today:
        c = {"day": today, "ask": 0, "light": 0}
        _counters[uid] = c
    if c[kind] >= LIMITS[kind]:
        raise HTTPException(429, detail={"answer":
            "🌙 وصلت حدّك اليومي من الأسئلة! ارجع لنا بكرة بنشاط — وراجع محادثاتك المحفوظة بالوقت هذا 📚"})
    c[kind] += 1
```
- يُستدعى `check_quota(uid, "ask")` أول سطر في `/ask`، و`check_quota(uid, "light")` في `/robot/ask` و`/scholarship/ask` و`/quiz/generate` و`/aptitude/analyze`.
- **الأرقام قابلة للضبط من Firestore:** حقلا `quota_ask` و`quota_light` في `config/app_settings` (الباك يقرؤهما بكاش الـ 5 دقائق الموجود) — ترفعهما أو تخفضهما من اللوحة بدون نشر.
- **حدود الزائر anonymous أشد:** 5 على `ask` (تُفحص في الباك بحقل `firebase.sign_in_provider == "anonymous"` من التوكن — أقوى من العداد المحلي في الفرونت الذي يبقى للعرض فقط).
- ⚠️ **قيد مقبول:** العدادات بالذاكرة تتصفر عند إعادة تشغيل Hugging Face — نادر الحدوث، وأسوأ نتيجة أن مستخدماً يكسب حصة إضافية يوماً ما. لا يستحق تعقيد التخزين الدائم في v2.
- تنظيف القاموس من أيام سابقة ضمن دورة تنظيف الجلسات الحالية (كل 30 دقيقة).

**في الفرونت:** رد 429 يُعرض بأسلوب ودّي (نفس نمط `ErrorMessages`) مع إخفاء حقل الإدخال مؤقتاً بدل SnackBar أحمر عدائي — الطالب ما سوّى غلط.

## 3.7 سياق المحادثة: العميل يرسل آخر 6 رسائل مع كل طلب ⭐

**المبدأ:** بدل الاعتماد على جلسات الذاكرة في الباك لفهم سياق المحادثة، **الفرونت يرسل آخر 6 رسائل** (3 تبادلات) من المحادثة الحالية مع كل طلب `/ask`:

- حقل جديد في `AskRequest`:
```python
class HistoryMsg(BaseModel):
    role: str          # "user" | "assistant"
    text: str

# داخل AskRequest:
chat_history: Optional[List[HistoryMsg]] = None   # آخر 6 رسائل كحد أقصى
```
- الباك يبنيها قبل رسالة الطالب الحالية: `messages = [system] + chat_history + [user_current]`، مع **قصّ كل رسالة تاريخية إلى ≤ 1500 حرف** (الردود الطويلة تُقص من النهاية مع "...") — يحفظ السياق ويلجم التوكنات.
- **في الفرونت (`ChatRepository`):** قبل كل إرسال يأخذ آخر 6 رسائل من محادثة Hive الحالية (النصوص فقط بدون refs/صور) ويرفقها. محادثة جديدة = `chat_history` فارغة.
- **المكاسب:** (1) المودل يفهم "اشرحها أكثر" و"أعطني مثال ثاني" وأسئلة المتابعة. (2) الباك يصير **stateless** لسياق الشرح — إعادة تشغيل Hugging Face لا تقطع سياق أي طالب. (3) جلسات الذاكرة تبقى فقط للحالات التي تحتاجها فعلاً (تتبّع خطوات مسائل الرياضيات متعددة الأدوار كما هي حالياً).
- **أثر التكلفة:** ‏6 رسائل مقصوصة ≈ +1500-2500 توكن إدخال للطلب. على Flash-Lite وGPT-4o-mini الزيادة ≈ 15-25% من تكلفة الطلب — محسوبة ضمن هامش تقدير قسم 12.1 ولا تغيّر خلاصته.
- `/scholarship/ask` كان أصلاً يستقبل آخر 6 رسائل — الآن `/ask` على نفس النمط الموحد.


---

# 4. تطبيق الطالب — شجرة الملفات الجديدة

```
lib/
├── main.dart
├── app/  (app.dart, bootstrap.dart — يضاف Firebase.initializeApp + Crashlytics)
├── core/
│   ├── config/   (app_config.dart, app_constants.dart)
│   ├── network/  (api_client.dart ← يضاف interceptor للتوكن, api_endpoints.dart ← تضاف المسارات الجديدة)
│   ├── storage/  (chat_storage.dart, prefs_keys.dart, secure_storage.dart)
│   ├── sync/     (sync_service.dart ★ جديد — مزامنة Hive↔Firestore)
│   ├── remote/   (remote_config_service.dart ★ جديد — قراءة config/ بنظام version)
│   ├── services/ (auth_service.dart ★, notification_service.dart ★, analytics_service.dart ★,
│   │              tts_service.dart ★, stt_service.dart ★)
│   ├── theme/    (كما هو)
│   └── widgets/  (كما هو + robot_assistant.dart ★ — الروبوت العائم العام)
├── features/
│   ├── onboarding/      (welcome_screen.dart ← يُعاد بناؤها بالروبوت Rive)
│   ├── auth/ ★          (auth_screen.dart, widgets/)
│   ├── home/ ★          (home_screen.dart, widgets/{student_header, banner_carousel,
│   │                     section_cards, continue_card})
│   ├── chat/            (الموجود + إضافات: image attach, mic, save, share-as-image,
│   │                     suggested_chips)
│   ├── scholarships/ ★  (list_screen, details_screen, scholarship_chat_screen)
│   ├── quiz/ ★          (quiz_home, subject_quiz_screen, aptitude_screen, result_screen)
│   ├── services/ ★      (services_screen)
│   ├── settings/ ★      (settings_screen, profile_edit_screen)
│   └── saved/ ★         (saved_answers_screen)
```

---

# 5. الواجهات بالتفصيل الممل (التطبيق RTL — اليمين هو البداية)

## 5.1 Splash
- خلفية `bgLight`، شعار مسار وسط الشاشة بأنيميشن نبض (scale 0.95↔1.05).
- **ما يحدث خلف الكواليس بالترتيب:** `Firebase.initializeApp` → `ChatStorage.init` → قراءة `config/meta` (قراءة واحدة) ومقارنة version بالمحفوظ محلياً (قسم 12) → فحص `app_settings.maintenance_mode` (إن true: شاشة صيانة برسالة اللوحة وتقف هنا) → فحص حالة Auth:
  - لا مستخدم → Onboarding (إن أول تشغيل) أو Auth.
  - مستخدم → Home مباشرة + `SyncService.pullIfNeeded()` بالخلفية.

## 5.2 Onboarding (4 صفحات)
- الروبوت (Rive) وسط الشاشة بحجم ~45% من العرض، فقاعة كلام فوقه بخلفية `surfaceWhite` وزاوية 24، النص بـ TypewriterText الموجود.
- الصفحات: (1) "مرحباً بك في مسار 👋 رفيقك من أول ثانوي حتى المنحة" — الروبوت wave. (2) "اشرح، لخّص، اسأل، وتدرّب على الوزاري" — الروبوت يمسك كتاب/idle. (3) "منح دراسية واختبارات تكشف تخصصك المناسب" — الروبوت think. (4) "أنا معك في كل شاشة، اسألني متى شئت!" — الروبوت **point لأسفل** نحو زر "أنشئ حسابك 🚀".
- أسفل الشاشة: زر "التالي" يسار (تدرج رئيسي)، "رجوع" يمين، dots وسط (نفس نمط الشاشة الحالية). "تخطي" أعلى يسار بلون `textSecondary`.
- عند الإنهاء: `isFirstRun=false` → شاشة Auth.

## 5.3 التوثيق (شاشة واحدة بتبويبين)
- أعلى الشاشة: الروبوت مصغّر (80px) + فقاعة تتغير حسب الحقل النشط (نصوص ثابتة بالكود).
- تبويبان (سويتش منزلق): **تسجيل الدخول | حساب جديد**.
- حساب جديد: الاسم الكامل → البريد → كلمة السر (عين إظهار **يسار** الحقل) → تأكيدها → **اختيار الصف** (3 شرائح: أول/ثاني/ثالث ثانوي — إجباري) → زر "إنشاء الحساب" بعرض الشاشة بالتدرج.
- تسجيل الدخول: بريد + كلمة سر + "نسيت كلمة السر؟" (تحت الزر، تفتح Dialog تُرسل `sendPasswordResetEmail`).
- تحت الزرين: خط فاصل ثم زر ثانوي بإطار: **"جرّب كزائر 👀"** → `signInAnonymously` → حساب مؤقت grade=3 افتراضياً، بحد **5 أسئلة** (عداد محلي)، وعند نفادها Dialog: "أعجبك مسار؟ أنشئ حسابك المجاني واحتفظ بكل محادثاتك" → `linkWithCredential` (ترقية بدون فقدان بيانات).
- **بعد النجاح:** إنشاء/قراءة `users/{uid}` → حفظ `fcm_token` → Home.
- رسائل الأخطاء بالعربي: بريد مستخدم مسبقاً / كلمة سر ضعيفة / لا يوجد اتصال — بنفس نمط SnackBar الأحمر الحالي.

## 5.4 الواجهة الرئيسية (Home)
من الأعلى للأسفل داخل `SingleChildScrollView`:
1. **الهيدر:** يمين: صورة الطالب دائرية 48px (`cached_network_image`، placeholder أيقونة شخص) + عمود: "مساء الخير، {الاسم} 👋" (تحية حسب الوقت) وتحتها شارة الصف الصغيرة بخلفية `primary 8%`. يسار: أيقونة جرس 🔔 + أيقونة إعدادات ⚙️ (كل واحدة بحاوية `softSurface` دائرية زوايا 16 — نفس نمط أزرار الـ AppBar الحالي).
2. **البانر:** `carousel_slider` ارتفاع 140، زوايا 24، تقليب تلقائي كل 4 ثوانٍ، مؤشرات نقاط أسفله. البيانات من كاش `banners`. الضغط: حسب `target_type` (شاشة المنحة / متصفح خارجي / لا شيء). إن لا بانرات مفعّلة: القسم يختفي تماماً.
3. **كرت التعليم (البطل):** بعرض الشاشة، ارتفاع ~150، تدرج `mainGradient`، يمينه النصوص: "📚 قسم التعليم" + "اشرح، لخّص، وتدرّب على الوزاري"، يساره رسم الروبوت يمسك كتاباً. ضغطه → قسم التعليم.
4. **صف ثلاثة كروت** (ارتفاع ~120): 🎓 المنح (تدرج بنفسجي) | 🧠 اختبر نفسك (تدرج أزرق فاتح) | 🛠️ الخدمات (تدرج أخضر مزرق). أي قسم `sections_enabled` له false → يظهر الكرت باهتاً مع شارة "قريباً".
5. **"أكمل من حيث توقفت":** إن وُجدت محادثة سابقة (من Hive — صفر قراءات): كرت صغير فيه أيقونة المادة + عنوان آخر محادثة + "قبل ساعتين" → ضغطه يفتحها مباشرة.
6. **الروبوت العائم:** FAB دائري 60px **أسفل يمين** — **يظهر فقط إذا فعّل الطالب `settings.robot_enabled` من الإعدادات** (قسم 7.2). افتراضياً لا يظهر؛ الجولة التعريفية لمرة واحدة (قسم 7.1) هي الاستثناء الوحيد.

## 5.5 قسم التعليم
- عند الدخول: شريط علوي فيه شرائح الصفوف الثلاثة، **المحدد تلقائياً صف الطالب من حسابه**. تغيير الصف = يغيّر `grade` المرسل لكل الطلبات ويعيد تحميل الوحدات (نفس منطق `switchContext`).
- بعدها **شاشة الشات الحالية كما هي بالكامل** (Drawer المواد، لوحة الإعدادات، الأوضاع...) مع الإضافات التالية فقط:

### إضافات خانة الكتابة (`chat_input_area.dart`)
- داخل حقل النص، **يمين** (قبل النص): زر 📷 (يفتح BottomSheet: كاميرا | معرض → `image_picker` → ضغط الصورة → معاينة مصغرة فوق الحقل مع ✕ للحذف → تُرسل base64 مع الطلب التالي) وزر 🎤 (ضغطة تبدأ `stt_service` — الحقل يتوهج أحمر خفيف مع موجة، والكلام يتحول نصاً حياً داخل الحقل، ضغطة ثانية توقف. اللغة `ar`).
- زر الإرسال/الإيقاف يسار كما هو.

### الأسئلة المقترحة
- عند محادثة جديدة (messages فارغة): فوق خانة الكتابة صف شرائح أفقي قابل للتمرير من كاش `suggested_questions/{subject}` حسب الوضع الحالي. الضغط = يرسل النص فوراً كـ `processRequest(customText:)`. تختفي بعد أول رسالة.

### أزرار فقاعة الرد (بجانب "نسخ" الحالي)
- **⭐ حفظ:** يكتب المستند في `users/{uid}/saved_answers` + نسخة Hive. يتحول ⭐→✅ ثانيتين.
- **📤 مشاركة كصورة:** `screenshot` package يلف الفقاعة في قالب: شعار مسار أعلى + النص + "منصة مسار — رفيق الطالب اليمني 🇾🇪" أسفل → `share_plus`.
- **🔊 استماع:** يقرأ الرد بـ `tts_service` (أيقونة تتحول ⏸️ أثناء القراءة). إن كان `settings.auto_tts` مفعلاً من الإعدادات: يقرأ تلقائياً كل رد جديد.

## 5.6 قسم المنح
### شاشة القائمة
- AppBar بنفس النمط الزجاجي: "المنح الدراسية 🎓".
- بانر المنح أعلى (نفس مكوّن الكاروسيل).
- حقل بحث (فلترة محلية على الأسماء) + صف فلاتر شرائح: الكل | ممولة بالكامل | جزئية | مفتوحة الآن.
- كروت المنح (من كاش `scholarships`، مرتبة بـ order): يمين شعار الدولة/الجامعة 56px، وسط الاسم + `short_desc` سطر واحد، يسار **شارة الحالة** تُحسب محلياً من التواريخ: 🟢 "التقديم مفتوح" (اليوم بين open/close) / 🟡 "يفتح قريباً" / 🔴 "مغلق".
### شاشة التفاصيل
- صورة غلاف بعرض الشاشة 200px مع تدرج أسود سفلي يحمل اسم المنحة.
- شريط Tabs: **نبذة | المتطلبات | المواعيد | طريقة التقديم** (المتطلبات قائمة بعلامات ✅، المواعيد ببطاقات تاريخ).
- **زر ثابت أسفل الشاشة** بعرضها بالتدرج: "💬 اسأل مساعد المنحة" → شاشة شات (نفس مكونات فقاعات الشات الحالية معاد استخدامها) تتصل بـ `/scholarship/ask` مع آخر 6 رسائل. أول رسالة ترحيبية ثابتة من الروبوت: "أهلاً! أنا مساعد منحة {الاسم}، اسألني عن الشروط أو التقديم 😊". المحادثة **لا تُزامَن** (خفيفة ومؤقتة — Hive فقط).
- زر ثانوي بإطار: "🔔 ذكّرني قبل الإغلاق" → يسجل topic في FCM باسم `sch_{schId}` (الإشعار يُرسل من اللوحة يدوياً أو لاحقاً بـ Cloud Function مجدولة).

## 5.7 قسم اختبر نفسك
### الشاشة الرئيسية: كرتان كبيران
1. **"📝 اختبر مستواك في مادة"** → شاشة إعداد: اختيار الصف (افتراضي صفه) → المادة → الوحدة (من `/subjects/units`) → عدد الأسئلة (5/10/15 شرائح) → زر "ابدأ الاختبار 🚀" → طلب `/quiz/generate` (لودر بشخصية الروبوت think + "أجهّز أسئلتك...").
2. **"🧭 اكتشف تخصصك"** (اختبار الميول والقدرات) → تفاصيله أدناه.
### شاشة الاختبار (سؤال بسؤال)
- أعلى: شريط تقدم + "سؤال 3 من 10". السؤال في بطاقة `surfaceWhite` زوايا 24. الخيارات الأربعة بطاقات بعرض الشاشة، الضغط يحددها بإطار `primary`، زر "تأكيد" أسفل → البطاقة الصحيحة تتلون أخضر والخاطئة (إن اختيرت) أحمر مع اهتزاز خفيف + سطر توضيح `topic` → زر "التالي".
- **لا خروج بالسحب للخلف** بدون Dialog تأكيد "ستفقد تقدمك".
### شاشة النتيجة
- دائرة نسبة كبيرة متحركة (0→النسبة) بلون حسب الأداء (أخضر ≥80، برتقالي ≥50، أحمر أقل).
- **خريطة نقاط الضعف:** تجميع `topic` للأسئلة الخاطئة → "تحتاج تركيزاً في: {المواضيع}" مع زر لكل موضوع: "اشرح لي 📚" → يفتح شات المادة ويرسل تلقائياً "اشرح لي {الموضوع}". ★ هذه الحلقة الذهبية اختبار→شرح.
- حفظ النتيجة في `users/{uid}/results` (كتابة واحدة) + أزرار: مشاركة كصورة | إعادة الاختبار.
### اختبار الميول (15 سؤالاً)
- الأسئلة من كاش `config/aptitude_test` (تُحرَّر من اللوحة). نفس واجهة سؤال-بسؤال لكن **بدون صح/خطأ** — كل خيار يعكس ميلاً (`dimension`).
- عند الانتهاء: `/aptitude/analyze` → شاشة تقرير: "مجالك الأقرب: {top_fields}" بشارات كبيرة + `report_text` (فقرة الذكاء الاصطناعي: لماذا هذا المجال، تخصصات مقترحة، نصيحة) + "منح تناسب مجالك 🎓" (فلترة محلية بسيطة لو أضفنا حقل fields للمنح — اختياري v2) + حفظ في results + مشاركة كصورة.
- في شاشة تفاصيل أي منحة: إن لم يُجرِ الطالب اختبار الميول من قبل (فحص Hive): شريط لطيف "🧭 محتار في التخصص؟ جرّب اختبار الميول أولاً" يفتح الاختبار.

## 5.8 قسم الخدمات
- قائمة كروت من كاش `services` (مرتبة، المفعّلة فقط): أيقونة داخل دائرة ملونة بـ `color_hex` يمين + العنوان والوصف. الضغط → BottomSheet: العنوان + الوصف الكامل + زر واتساب أخضر عريض "تواصل معنا 💬" → `wa.me/{number}?text={whatsapp_message}` مضافاً لها اسم الطالب تلقائياً.
- أعلى القائمة بطاقة تعريفية: "خدمات مسار — فريقنا يساعدك في ملف تقديمك خطوة بخطوة 🤝".

## 5.9 الإعدادات
تفتح من ⚙️ الهيدر. قائمة أقسام:
- **الملف الشخصي:** صورة (ضغطها → image_picker → رفع Storage بمسار `avatars/{uid}.jpg` مضغوطة 300px → تحديث photo_url) + الاسم (قابل للتعديل) + البريد (للعرض) + **الصف** (3 شرائح — تغييره يحدّث المستند ويعاد تحميل قسم التعليم؛ مهم عند انتقال الطالب لصف جديد).
- **المظهر:** الوضع الداكن (السويتش الحالي) + **حجم خط الإجابات** (شريط 14–20، يُحفظ في settings ويُطبق على MarkdownStyleSheet).
- **الصوت:** "القراءة الصوتية التلقائية للردود" سويتش.
- **الروبوت المساعد 🤖:** سويتش "إظهار الروبوت في كل الشاشات" (`settings.robot_enabled` — راجع قسم 7.2) + زر ثانوي صغير "أعد الجولة التعريفية" (يصفّر `robot_intro_done` ويفتح Home).
- **الإشعارات:** إشعارات المنح / إشعارات عامة (اشتراك/إلغاء topics).
- **البيانات:** مسح المحادثات المحلية (Dialog تأكيد) | **حذف الحساب** (إلزامي لـ Google Play: Dialog تحذير قوي → حذف مستند المستخدم وفروعه ثم `user.delete()`).
- **عن مسار:** الإصدار، المطور (نافذة المطور الحالية)، سياسة الخصوصية (رابط)، تواصل معنا.
- **تسجيل الخروج** بالأحمر آخر عنصر (يمسح كاش Hive الشخصي).

---

# 6. المزامنة Hive ↔ Firestore (`sync_service.dart`)

**المبدأ: Hive هو المصدر الأول للعرض دائماً (سريع + أوفلاين). Firestore نسخة سحابية.**

- **الكتابة (بعد كل رد ناجح):** الحفظ في Hive فوراً (المنطق الحالي `saveCurrentConversation`) ثم `set(merge:true)` للمستند `conversations/{convId}` بالمحادثة كاملة (مصفوفة messages) **بدون انتظار** (fire-and-forget مع try/catch صامت). لا نت؟ يُضاف convId لقائمة `pending_sync` في Hive وتُرفع عند عودة الاتصال (`connectivity_plus` listener).
- **السحب:** فقط في حالتين: (1) تسجيل دخول على جهاز جديد/بعد إعادة تثبيت → قراءة كل conversations مرة واحدة وتعبئة Hive. (2) زر "🔄 استعادة محادثاتي" يدوي في الإعدادات. **لا مزامنة سحب دورية** — هذا ما يحمي الفاتورة.
- **التعارض:** last-write-wins بمقارنة `last_updated`.
- حد حجم المستند: عند تجاوز المحادثة ~400 رسالة تُقص أقدم الرسائل من النسخة السحابية فقط (النادرة جداً).

---

# 7. الروبوت المساعد (جولة تعريفية لمرة واحدة + وضع دائم اختياري)

مكوّن عام `RobotAssistant` قابل للحقن في Scaffold الشاشات الرئيسية عبر `screen_id` — لكنه **لا يظهر افتراضياً** إلا في حالتين أدناه.

## 7.1 السلوك الافتراضي: الجولة التعريفية (مرة واحدة فقط)
1. **متى؟** أول دخول للطالب إلى Home بعد إنشاء الحساب (مفتاح واحد `robot_intro_done` في SharedPreferences — يستبدل نظام `robot_shown_{screen_id}` المتعدد القديم).
2. **ماذا يحدث؟** الروبوت ينبثق (Rive: wave) وسط الشاشة بفقاعة أولى: *"أهلاً {الاسم}! أنا مساعدك في مسار 🤖"* ثم جولة قصيرة من 4 فقاعات متتالية بزر "التالي"، في كل واحدة يتحول لحالة point نحو القسم الذي يشرحه: (1) كرت التعليم *"من هنا تشرح وتلخّص وتتدرب على الوزاري 📚"* → (2) كرت المنح *"وهنا المنح الدراسية أولاً بأول 🎓"* → (3) اختبر نفسك *"اختبر مستواك واكتشف تخصصك 🧠"* → (4) الخدمات *"وفريقنا يساعدك في ملف تقديمك 🛠️"*.
3. **فقاعة الوداع (الأخيرة):** *"شفنا كل شيء! 👀 الآن بختفي عشان ما أزحمك... إذا احتجتني في أي وقت فعّلني من الإعدادات ⚙️ وبطلع لك في كل شاشة 😉"* → زر "فهمت 👍" → أنيميشن خروج لطيف (scale down + fade) → `robot_intro_done = true` → **الروبوت يختفي من التطبيق كلياً**.
4. النصوص ثابتة بالكود (fallback) مع override اختياري من مستند `config/robot_intros` (قابل للقراءة للطلاب — لا علاقة له بمجموعة `prompts/` السرية).
5. إن قاطع الطالب الجولة (خروج/back): تُعتبر منتهية (`robot_intro_done = true`) — لا نلاحقه بها.

## 7.2 الوضع الدائم (اختياري — يفعّله الطالب بنفسه)
- سويتش في الإعدادات: **"🤖 الروبوت المساعد — إظهاره في كل الشاشات"** (افتراضياً: مطفأ بعد الجولة). يُحفظ في `settings.robot_enabled`.
- عند تفعيله: FAB الروبوت (60px، أسفل يمين) يظهر في كل الشاشات الرئيسية عبر `screen_id`، وضغطه يفتح **الطبقة الذكية**: فقاعة شات شفافة (خلفية `surfaceWhite` بشفافية 0.93 — الشاشة خلفها مرئية) فيها آخر 4 تبادلات + حقل نص صغير. الإرسال → `/robot/ask` بـ `screen_id` → الباك يبني: `system = get_prompt("robot_screen_{screen_id}")` + سؤال الطالب → Flash-Lite (max_tokens 500) → الروبوت بحالة talk أثناء الكتابة + قراءة TTS إن مفعلة.
- عند إطفاء السويتش: يختفي الـ FAB من كل الشاشات فوراً.
- برومبتات الشاشات تُكتب من اللوحة (مجموعة `prompts/` — يقرؤها الباك اند فقط)، مثال `robot_screen_education`: *"أنت مساعد منصة مسار. الطالب الآن في شاشة الشات التعليمي وفيها: قائمة جانبية للمواد، زر إعدادات الجلسة أسفل يمين لاختيار الوضع والوحدة والدرس... أجب عن سؤاله عن استخدام الشاشة بإيجاز وود بالعربية."*

> 💡 **مكسب جانبي لهذا التغيير:** تكلفة `/robot/ask` تصبح شبه معدومة (لن يستخدمه إلا من فعّله قصداً)، والشاشات أنظف لبقية الطلاب، وجهد ضبط أنيميشن Rive على الأجهزة الضعيفة ينحصر في الجولة التعريفية والـ FAB فقط.

---

# 8. لوحة التحكم (مشروع Flutter Web منفصل: `masar_admin`)

- الدخول: Firebase Auth عادي ثم فحص `role == admin` من مستند المستخدم (وإلا رسالة رفض). القواعد الأمنية (2.1) هي الحماية الحقيقية.
- التخطيط: قائمة جانبية **يمين** ثابتة + محتوى يسار. الأقسام:

| القسم | المحتوى والوظائف |
|---|---|
| 📊 الرئيسية | بطاقات: طلاب اليوم الجدد، طلبات اليوم، إجمالي الطلاب. رسم أعمدة لآخر 30 يوم (قراءة 30 مستند `stats/daily`) + توزيع المواد والصفوف. زر "تصدير CSV" للتقارير للمؤسسة. |
| 🎓 المنح | جدول (الاسم/الدولة/الحالة/مفعلة) + زر إضافة → نموذج بكل حقول 2 (رفع الصور لـ Storage، محرر متطلبات كقائمة، منتقيا تاريخ open/close) + **حقل assistant_prompt متعدد الأسطر (يُحفظ في `scholarship_prompts/{schId}` 🔒 وليس في مستند المنحة العام) + زر "🧪 جرّب البرومبت"** يفتح شات تجريبي داخل اللوحة يستدعي `/scholarship/ask` قبل النشر. مفتاح تفعيل/إخفاء فوري. |
| 💬 البرومبتات | قائمة كل مجموعة `prompts/` 🔒 مجمعة بالنطاق (شاشات/مواد/أخرى) → محرر نص كبير + "آخر تعديل: {تاريخ} بواسطة {اسم}" + زر تجربة + حفظ. **الحفظ هنا لا يزيد `meta.version`** (الطلاب لا يقرؤون البرومبتات) — التعديل يصل للباك اند خلال ≤ 5 دقائق عبر كاشه الخاص. |
| ❓ الأسئلة المقترحة | لكل مادة/وضع: قائمة نصوص قابلة للإضافة/الحذف/الترتيب. |
| 🧭 اختبار الميول | محرر الـ 15 سؤالاً: نص السؤال + 4 خيارات وكل خيار له dimension من قائمة منسدلة. |
| 🛠️ الخدمات | جدول + إضافة/تعديل (عنوان، وصف، أيقونة من مكتبة أيقونات معروضة شبكياً، لون، رقم واتساب، رسالة جاهزة) + سحب لإعادة الترتيب + تفعيل. |
| 🖼️ البانرات | شبكة صور + رفع جديد + رابط الهدف (منحة من قائمة / URL) + ترتيب + تفعيل. |
| 📢 الإشعارات | نموذج: العنوان + النص + الجمهور (الكل / صف معين / مشتركي منحة) → إرسال عبر FCM HTTP v1 (استدعاء endpoint صغير في الباك `/admin/notify` محمي بفحص role admin من التوكن). سجل آخر 20 إشعاراً. |
| ⚙️ إعدادات التطبيق | maintenance_mode + الرسالة، min_version، مفاتيح تفعيل الأقسام الأربعة، **حقلا الحصة اليومية quota_ask / quota_light** (يصلان للباك خلال ≤ 5 دقائق). |

**قاعدة مهمة:** أي كتابة من اللوحة في مجموعات المحتوى المرئي للطلاب (`config/` أو `scholarships/` أو `services/` أو `banners/` أو `suggested_questions/`) تنتهي بـ `config/meta.version += 1` — هذا ما يجعل التطبيقات تعرف أن هناك جديداً (قسم 12). تعديلات `prompts/` و`scholarship_prompts/` **لا تزيد version** (الطلاب لا يكيّشونها — الباك اند يلتقطها بكاشه الخاص).

---

# 9. الصوت والإشعارات

- **TTS (`tts_service.dart`):** `flutter_tts`، لغة `ar`، سرعة 0.5. دوال speak/stop + ValueNotifier للحالة (لربط أيقونة ⏸️ وحركة فم الروبوت). قبل القراءة: تنظيف النص من رموز Markdown والإيموجي.
- **STT (`stt_service.dart`):** `speech_to_text`، `localeId: 'ar'`، بث جزئي حي للحقل. صلاحية المايكروفون تُطلب عند أول استخدام مع شرح.
- **FCM (`notification_service.dart`):** طلب الإذن عند أول دخول Home (ليس قبلها)، حفظ التوكن في مستند المستخدم وتحديثه عند `onTokenRefresh`، اشتراك تلقائي في topics: `all` و`grade_{n}`. النقر على إشعار منحة → deep link لشاشة تفاصيلها.

---

# 10. Rive — مواصفات ملف الروبوت

- ملف `.riv` واحد في assets، State Machine باسم `robot` بمدخلات: `state` (رقم: 0 idle / 1 talk / 2 point / 3 wave / 4 think) و trigger `tap` (قفزة مرحة عند لمسه).
- مبدئياً: روبوت جاهز من مجتمع Rive (community files — رخصة CC) يُعدَّل تلوينه لهوية مسار (أزرق `#3B82F6` → بنفسجي `#8B5CF6`). لاحقاً تصميم مخصص.
- أحجام الاستخدام: onboarding كبير (45% عرض) / Auth مصغر 80px / FAB 60px / لودر الاختبارات 100px.

---

# 11. مراحل التنفيذ (بالترتيب الإلزامي)

| المرحلة | المحتوى | مخرجات القبول |
|---|---|---|
| **1 — الأساس** (4-6 أسابيع) | Firebase (Auth/Firestore/Rules) + شاشة Auth + الزائر + حذف نظام الأكواد واعتماد التوكن في الباك + **نظام Quota (3.6) + إرسال chat_history من الفرونت (3.7)** + هيكلة الصفوف grade في الباك والفرونت + Home الجديدة (بدون بانر إن لم تجهز البيانات) + SyncService + RemoteConfigService + Crashlytics/Analytics | طالب يسجل، يستخدم التعليم بصفه مع سياق متابعة، يغيّر جهازه ويجد محادثاته، ويتوقف بلطف عند حده اليومي |
| **2 — التجربة** (3-4 أسابيع) | الروبوت (Rive + الجولة التعريفية 7.1 + سويتش الوضع الدائم و`/robot/ask` 7.2) + Onboarding الجديد + رفع الصور في الشات + الأسئلة المقترحة + حفظ/مشاركة كصورة + الإعدادات كاملة | الجولة تظهر مرة واحدة وتختفي، والسويتش يعيد الروبوت لكل الشاشات ويطفئه |
| **3 — المنح + اللوحة** (4 أسابيع) | مشروع اللوحة (المنح/البرومبتات/الخدمات/البانرات/الإعدادات أولاً) + شاشات المنح + `/scholarship/ask` + البانر في Home + قسم الخدمات | الأدمن يضيف منحة ببرومبتها وتظهر للطلاب فوراً |
| **4 — الاختبارات** (3 أسابيع) | `/quiz/generate` + `/aptitude/analyze` + شاشات الاختبارات والنتائج ونقاط الضعف + محرر الميول باللوحة + الإحصائيات والإشعارات باللوحة | اختبار مادة كامل بخريطة ضعف + تقرير ميول |
| **5 — الصوت** (1-2 أسبوع) | STT + TTS + ربط الروبوت + auto_tts | الطالب يتكلم ويسمع |

---

# 12. ⭐ استراتيجية فاتورة Firestore (شبه صفرية — اقرأها جيداً)

الطبقة المجانية **يومياً**: 50,000 قراءة / 20,000 كتابة / 1GB تخزين. التصميم أعلاه مبني عليها:

1. **نظام رقم النسخة (الحيلة الأساسية):** التطبيق عند الإقلاع يقرأ مستند `config/meta` فقط (**قراءة واحدة**). إن كان `version` مساوياً للمحفوظ في Hive → يستخدم الكاش المحلي بالكامل (**صفر قراءات إضافية**). إن تغيّر → يقرأ **فقط ما يخص الطالب**: مستندات `config/` (app_settings, aptitude_test, robot_intros) + مجموعات `scholarships/` و`services/` و`banners/` و`suggested_questions/` مرة واحدة ويحدّث الكاش والرقم. ★ مجموعتا `prompts/` و`scholarship_prompts/` **خارج كاش الطالب نهائياً** (سرية + توفير قراءات وبيانات). أي تعديل محتوى من اللوحة يزيد version. **النتيجة: طالب يفتح التطبيق 10 مرات يومياً = 10 قراءات فقط غالباً.**
2. **المحادثة = مستند واحد** (مصفوفة رسائل): استعادة 30 محادثة = 30 قراءة، وليس آلاف قراءات الرسائل.
3. **لا استعلامات دورية ولا Streams** في تطبيق الطالب إطلاقاً (snapshots/listeners ممنوعة إلا في اللوحة).
4. **الباك اند يقرأ config بكاش 5 دقائق** → ~288 قراءة/يوم مهما بلغ عدد الطلبات.
5. **الإحصائيات بعداد مجمّع**: كتابة merge واحدة لكل طلب على مستند اليوم (وليس مستنداً لكل حدث).
6. **الحساب التقديري عند 1000 طالب نشط و1000 طلب/يوم:** قراءات ≈ 1000 (meta) + 1000 (كتابة رسائل تُحتسب كتابة) + 288 (باك) ≈ بعيد جداً عن السقف → **$0 شهرياً**. وحتى عند 10,000 طالب نشط يومياً تبقى ضمن أو قرب المجاني (دولارات معدودة على خطة Blaze).
7. صور المنح/البانرات تُرفع مضغوطة (≤ 200KB) و`cached_network_image` يمنع إعادة تنزيلها.

# 12.1 تكلفة الذكاء الاصطناعي (مرجع)
عند 1000 طلب/يوم (≈4000 توكن إدخال + 800 إخراج للطلب): Flash-Lite ≈ **$22/شهر**، GPT-4o-mini ودييب سيك للمواد الحسابية حسب حصتها ≈ $20-40/شهر إضافية. طلبات الروبوت وشات المنح قصيرة وتكلفتها هامشية. **الإجمالي التشغيلي المتوقع للمنصة كاملة: $40-70 شهرياً عند ألف طلب يومياً.**

---

# 13. ملاحظات إلزامية للمنفذ

1. **لا تعِد بناء ما يعمل:** شاشة الشات ومنطق `ChatController` وواجهات المواد الحالية تبقى — فقط أضف عليها.
2. كل النصوص عربية RTL، خط Cairo، نظام الألوان الحالي (`AppColors`) هو المرجع لكل الشاشات الجديدة.
3. كل استدعاء شبكي: مهلة + معالجة أخطاء بنفس نمط `ErrorMessages` الحالي.
4. كل شاشة جديدة تسجل حدث Analytics باسمها (`screen_view`).
5. أي حقل جديد في Firestore يُضاف هنا في هذه الوثيقة أولاً (هي مصدر الحقيقة).
6. اختبار كل مرحلة على أجهزة أندرويد ضعيفة (2GB RAM) — جمهورنا أجهزته متواضعة: أنيميشن Rive يتعطل تلقائياً إن انخفض الأداء (fallback لصورة ثابتة للروبوت).
7. الالتزام بترتيب المراحل — لا ميزة من مرحلة لاحقة قبل قبول السابقة.
