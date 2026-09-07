# 07 — نموذج البيانات

> ⚠️ **مصدر الحقيقة للحقول.** أي حقل جديد يُضاف هنا أولاً.

## 1. Firestore
```
config/
├── meta          { version, content_version, updated_at }
├── app_settings  { min_version, maintenance_mode, sections_enabled{}, quota_ask, quota_light }
├── aptitude_test { questions[15] }
└── robot_intros  { ... }

prompts/{id}                🔒 { scope, text, updated_at, updated_by }
suggested_questions/{id}       { subject, mode, questions[] }
services/{id} · banners/{id}

⭐ المنح — منفَّذة ([32](32-scholarships.md)):
scholarships/{id}              { name, country, flag, short_desc, about,
                                 benefits[], requirements[], documents[],
                                 how_to_apply[], fields[], degree_levels[],
                                 open_date, close_date, funding_type,
                                 cover_url, logo_url, website, gradient[],
                                 enabled, order, created_at, updated_at }
    🔴 لا حقل `status` — يُحسب من التاريخين في الخادم وفي التطبيق معاً.
scholarship_prompts/{id}    🔒 { assistant_prompt, updated_at }
    🔒 مجموعة موازية لا حقل داخل المنحة — وإلا قرأه الطالب.

users/{uid}  { name, email, grade, photo_url, role, fcm_token,
               is_anonymous, settings{dark_mode,font_size,auto_tts,robot_enabled} }
├── conversations/{id} { title, subject, grade, mode, messages[], last_updated }
├── saved_answers/{id} { subject, text, source_conv }
├── results/{id}       { type, score, total, wrong_topics[], report_text }
└── scholarship_chats/{id} ⭐ { title, scholarship_id, scholarship_name,
                               messages[], created_at, last_updated, expires_at }
    محادثات مساعد المنح — مربوطة بالحساب وتعود معه على جهاز جديد ([32§5]).

stats/daily/{yyyy-mm-dd}  { requests_total, requests_by_subject{}, new_users }

lessons_draft/{id}  🔒  ⭐ ADR-001
    { grade, subject, unit, lesson_no, lesson_name, page_from, page_to,
      body, parts[], status:"draft|published", updated_at, updated_by }

exam_questions/{id} 🔒  ⭐ ADR-007
    { grade, subject, year, part, question_type, text, answer,
      lesson, unit, tag_source:"ai|human", reviewed:bool }
```
**قاعدة:** مسارات Firestore تتناوب collection→document→collection. **المحادثة = مستند واحد.**

## 2. قواعد الأمان — النقاط الحرجة

### ⚠️ فخ `{doc=**}`
في rules v2 يطابق **صفر مقاطع أو أكثر** — `match /users/{uid}/{doc=**}` يطابق `/users/{uid}` نفسه، والقواعد تعمل بـ **OR** → الطالب يرقّي نفسه أدمن.
**الحل:** فصل الأب عن الفروع بنمط `/{col}/{docId}`.

### اختبارات إلزامية
- [ ] طالب يكتب `role:"admin"` في مستنده → **يُرفض**
- [ ] طالب يقرأ `prompts/*` → **يُرفض**
- [ ] طالب يقرأ `scholarships/*` ويكتب في محادثاته → **يُسمح**
- [ ] زائر يقرأ `config/meta` → **يُسمح**
- [ ] طالب يقرأ `users/{other_uid}` → **يُرفض**

## 3. Hive
### الموجود
```dart
ChatMessage      typeId 0 : role, text, refs[], timestamp
ChatConversation typeId 1 : id, title, subject, mode, messages[], createdAt, lastUpdated
```
### المضاف
```dart
WrongAnswer      typeId 2 · QuizResult typeId 3
SchMessage       typeId 4 : role, text, timestamp                      ⭐ [32]
SchConversation  typeId 5 : id, title, scholarshipId, scholarshipName,
                            messages[], createdAt, lastUpdated,
                            ownerUid, synced
```
### المطلوب إضافته
`grade` (افتراضي 3) · `unit` · `lesson` · `synced` · `imagePath`
⚠️ **الإضافة في نهاية ترقيم `@HiveField` آمنة. لا تُعِد ترقيم حقل قائم أبداً.**

### SharedPreferences
`isFirstRun` `robot_intro_done` `content_version` `config_version`
🗑️ تُحذف: `user_code` `device_id` `isActivated`

## 4. ملفات المحتوى
```
data/subjects/{grade}/{subject}/{subject}.json   ← الصيغة الموحّدة [11§4]
data/subjects/{grade}/{subject}/exams/{year}.json ← موسومة بالدرس [12]
indexes/{grade}_{subject}_{unit}.faiss            ← مبنية مسبقاً [13§3]
```
