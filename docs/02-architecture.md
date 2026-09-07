# 02 — المعمارية

```
┌──────────────┐  ┌──────────────┐   ┌─────────────────┐
│ تطبيق الطالب  │  │ لوحة التحكم   │   │ Firebase        │
│ Flutter       │  │ Flutter Web   │   │ Auth·Firestore  │
└──────┬───────┘  └──────┬───────┘   │ Storage·FCM     │
       │ Bearer idToken  │            └────────┬────────┘
       └────────┬────────┘                     │ Admin SDK
                ▼                              │
      ┌─────────────────────────┐              │
      │ FastAPI (HF Spaces)     │◄─────────────┘
      │ /ask /robot /quiz ...   │──► Gemini · GPT-4o-mini · DeepSeek
      │ FAISS + JSON (محلي)     │
      └─────────────────────────┘
```

## المبادئ (غير قابلة للتفاوض)
1. **Hive أولاً للعرض** — لا شاشة تنتظر الشبكة
2. **صفر Streams في تطبيق الطالب** — اللوحة فقط
3. **نظام `meta.version`** — قراءة واحدة عند الإقلاع
4. **الباك stateless** — HF تُعاد تشغيلها كثيراً
5. **البرومبتات سرّية** — لا تصل للعميل
6. **كل وصول بيانات خلف Repository**
7. **الفهارس تُبنى عند النشر لا عند الطلب** ← [13](13-performance.md)
8. **صيغة محتوى واحدة لكل المواد** ← [11](11-content-schema.md)

## تدفّق `/ask` المستهدف
```
الطالب يكتب
  → الفرونت: chat_history من Hive
  → POST /ask + Bearer token
      1. verify_id_token          → uid
      2. check_quota(uid,"ask")   → 429 إن تجاوز
      3. get_prompt()  [كاش 5د]
      4. FAISS retrieve [فهرس محمّل مسبقاً]  ★
      5. استدعاء الموديل
      6. stats merge Increment(1)
  → حفظ Hive → مزامنة Firestore (fire-and-forget)
```
**قراءات Firestore لكل سؤال: صفر.**

## الطبقات
```
Presentation → Controller → Repository → ApiClient | Hive | Firestore
```
الويدجت لا يعرف مصدر البيانات.

## طبقات المحتوى
| الطبقة | المخزن | يكتب | يقرأ |
|---|---|---|---|
| Control Plane | Firestore | اللوحة | الباك عند النشر |
| Data Plane | JSON + FAISS | الباك عند النشر | الباك لكل طلب |
| Config Plane | Firestore | اللوحة | التطبيق (version) |
