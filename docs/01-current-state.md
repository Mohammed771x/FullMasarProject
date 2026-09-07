# 01 — الوضع الحالي (تدقيق فعلي)

> قراءة مباشرة للكود بتاريخ 2026-08-26.

## 1. الباك اند — `Backend/` (4,951 سطر Python)

```
api.py            436   المسارات
auth.py            65   نظام الأكواد
config.py          45   مفاتيح ومسارات وحدود
models.py          40   AskRequest
models_config.py  178   ربط المواد بالموديلات
subjects/
├── common.py     947   ★ القلب: FAISS، البحث، الفلترة، البرومبتات
├── math.py       673
├── english.py    588
├── arabic.py     545
├── chemistry.py  488
├── physics.py    477
└── biology.py    469
```

### المسارات الموجودة
| المسار | الطريقة |
|---|---|
| `/` | GET/HEAD |
| `/verify-access` | POST — 🗑️ يُحذف في v3 |
| `/subjects/units` | GET |
| `/subjects/lessons` | GET |
| `/exams/years` · `/exams/sections` | GET |
| `/math/lessons` · `/math/exams/years` · `/math/exams/lessons` | GET |
| `/ask` | POST — النقطة الرئيسية |

### الموديلات
| المادة | الموديل |
|---|---|
| احياء · عربي · انجليزي | Gemini Flash-Lite |
| فيزياء · كيمياء | GPT-4o-mini |
| رياضيات | DeepSeek |

### RAG — تصحيح لفهم شائع
> ⚠️ **كل المواد تستخدم FAISS، ليست الأحياء وحدها.**

| المادة | دالة البحث |
|---|---|
| احياء · رياضيات | `enhanced_qa_search` |
| فيزياء · كيمياء · عربي | `enhanced_search_physics` |
| انجليزي | `faiss_search` مباشرة |

`enhanced_qa_search` تدمج **بحثاً مباشراً بالكلمات + بحثاً دلالياً**، المباشر أولاً.

🔴 **الفهرس يُبنى عند الطلب ولا يُحفظ أبداً** → [13-performance](13-performance.md).

### الوزاري
كل المواد تستخدم `filter_and_rank_exams` (مطابقة كلمات، عتبة=1) **عدا الرياضيات** التي تفلتر بحقل `الدرس` → [12-wazari-accuracy](12-wazari-accuracy.md).

### كود ميت
- `filter_exams_smart` (`common.py:525`) — لا تُستدعى، ومع ذلك هي الأقرب للصواب
- `filter_exams_by_keyword` (`common.py:446`) — لا تُستدعى
- `book.index` · `book_docs.json` · `book_meta.json` · `exam_embeddings.npz` — لا تُقرأ
- `normalize_arabic` **مُعرّفة مرتين** في `common.py` (سطر 301 و489) — الثانية تطغى

## 2. الفرونت — `frontendappversion/` ★ الأساس المعتمد

```
lib/
├── main.dart                14   نظيف
├── app/                          bootstrap.dart · app.dart
├── core/
│   ├── config/   network/   storage/   theme/   error/   widgets/
└── features/
    ├── chat/            ✅ الميزة الحقيقية الوحيدة
    │   ├── data/models · data/repositories/chat_repository.dart (79)
    │   └── presentation/
    │       ├── controllers/chat_controller.dart      677  ★
    │       ├── screens/main_chat_screen.dart         272
    │       └── widgets/session_settings_panel.dart   565
    ├── future_masar/    🎨 ديمو v3 كامل — 22 شاشة، بيانات ثابتة
    ├── instructions/    ✅
    └── onboarding/      ✅
```

**تصحيح جوهري:** هذا الفرونت **يطابق وصف v3 §0.1** — `core/`+`features/`، `ChatController`، `ChatRepository`، `ErrorMessages`، `ApiClient`. ✅
**`webversion/`** هو النسخة القديمة (ملف واحد 3,566 سطراً بنظام أكواد) — **مرجع فقط.**

### `future_masar/` — ما هو؟
ديمو واجهات كامل لـ v3 (22 شاشة: splash، auth، home، scholarships، quiz، aptitude، services، **teacher_feature**، **teacher_assistant**، analysis، settings…) ببيانات ثابتة من `data/demo_data.dart`.
**قيمته:** مرجع بصري ممتاز — التصاميم موجودة، ينقصها الوصل بالباك اند.
**⚠️ خطر:** ديمو + إنتاج في نفس التطبيق. يجب فصله أو حذفه عند البناء الحقيقي.

### الحزم
موجودة: `http` `uuid` `markdown` `flutter_markdown` `flutter_math_fork` `webview_flutter` `cached_network_image` `flutter_tex` `hive` `path_provider` `intl` `shared_preferences` `google_fonts` `url_launcher` `flutter_secure_storage`

**ناقص لـ v3:** كل حزم Firebase · `rive` · `speech_to_text` · `flutter_tts` · `image_picker` · `carousel_slider` · `screenshot` · `share_plus` · `connectivity_plus`

**مشاكل:** `flutter_markdown` مهجورة · `build_runner`/`hive_generator` في `dependencies` · ثلاث مكتبات معادلات

## 3. البيانات
راجع [11-content-schema](11-content-schema.md) — صيغتان للكتب، أربع للامتحانات، 2.5 MB إجمالاً.

## 4. ما لا يوجد
❌ Firebase · ❌ إدارة حالة حديثة · ❌ اختبارات · ❌ CI/CD · ❌ دعم الصفوف · ❌ i18n
