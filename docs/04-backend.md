# 04 — الباك اند (FastAPI)

## النشر
`https://mohammed771-my-tutor-backend.hf.space` · محلياً `127.0.0.1:8000` · Docker
⚠️ Space مجاني ينام ويُعاد ([R-11](10-risks.md))

## البنية
راجع [01§1](01-current-state.md) للتفصيل. القلب: `subjects/common.py` (947 سطراً).

## الموديلات (تبقى كما هي)
| المادة | الموديل |
|---|---|
| احياء · عربي · انجليزي | Gemini Flash-Lite |
| فيزياء · كيمياء | GPT-4o-mini |
| رياضيات | DeepSeek |

## RAG
`SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")` + `faiss.IndexFlatIP`
🔴 **يُبنى عند الطلب، لا يُحفظ** → [ADR-012](08-decisions.md)

## المسارات المستهدفة
| المسار | التعديل |
|---|---|
| `/verify-access` | 🗑️ يُحذف |
| `/ask` | توكن + `grade` + صورة + quota |
| `/subjects/units` `/subjects/lessons` | `+ grade` |
| `/exams/*` `/math/*` | `+ grade` |
| `/robot/ask` `/scholarship/ask` `/quiz/generate` `/aptitude/analyze` | جديدة |
| `/admin/notify` `/admin/content/publish` | جديدة (أدمن) |

## حمولة `/ask` المستهدفة
```jsonc
{ "grade": 3, "subject": "احياء", "mode": "شرح|تلخيص|سؤال|وزاري",
  "input_type": "برومت|صفحة", "summary_level": 3,
  "lesson_name": "...", "unit_name": "...", "content": "...",
  "chat_history": [{"role":"...","content":"..."}],   // 6، ≤1500 حرف
  "image_base64": null }
// Header: Authorization: Bearer <firebase_id_token>
// حُذف: user_id · code · device_id
```

## أدوات جديدة (خارج الـ API)
```
tools/
├── build_indexes.py        بناء فهارس FAISS مسبقاً       [ADR-012]
├── tag_exam_questions.py   وسم الأسئلة الوزارية بالدرس   [ADR-007]
├── migrate_schema.py       توحيد صيغ الكتب               [ADR-011]
└── split_biology_lessons.py توليد دروس الأحياء من الصفحات
```
