#!/usr/bin/env python3
# ==================================================
# 🧪 tools/dev_local_store.py — تشغيل الخادم بمخزن محلي بدل Firestore
# ==================================================
# ⛔ **للتطوير والفحص وحدهما — لا يُشغَّل في الإنتاج أبداً.**
#
# لماذا يوجد أصلاً؟
#   قسم المنح ولوحة التحكم والحصة اليومية كلها تقرأ Firestore عبر Admin SDK،
#   وهو يحتاج `FIREBASE_SERVICE_ACCOUNT_JSON`. وبدونه لا يمكن تجربة القسم
#   محلياً إطلاقاً — لا إضافة منحة ولا رؤيتها في التطبيق.
#
#   هذا السكربت يحقن **مخزناً وهمياً على القرص** (ملف JSON واحد) مكان
#   Firestore، فيعمل كل شيء بلا حساب خدمة: اللوحة تكتب، والتطبيق يقرأ،
#   وبروتوكول النسخة يعمل، والمساعد يجيب (بمفتاح Gemini الحقيقي من .env).
#
# ما الفرق عن Firestore الحقيقي؟
#   • البيانات في ملف محلي لا في السحابة — لا تُشارَك مع جهاز آخر.
#   • بلا قواعد أمان (هي طبقة العميل أصلاً، والباك يتجاوزها بـAdmin SDK).
#   • بلا معاملات ذرّية — كافٍ تماماً لمستخدم واحد يفحص.
#
# التشغيل:
#     cd Backend && .venv/bin/python tools/dev_local_store.py
#
# البيانات تُحفظ في `Backend/.dev_store.json` (مستبعَد من git).
# لمسح كل شيء والبدء من جديد: احذف الملف.

import json
import os
import sys
import types

HERE = os.path.dirname(os.path.abspath(__file__))
BACKEND = os.path.dirname(HERE)
STORE = os.path.join(BACKEND, ".dev_store.json")

sys.path.insert(0, BACKEND)
os.chdir(BACKEND)

_EMPTY = {"users": {}, "usage": {}, "config": {}, "notifications": {},
          "scholarships": {}, "scholarship_prompts": {}}

# الفروع في مفتاحٍ واحدٍ مسطّح: «users/{uid}/results» ⇒ {doc_id: data}.
_SUBS_KEY = "__subcollections__"


def _load():
    if os.path.isfile(STORE):
        try:
            with open(STORE, encoding="utf-8") as f:
                return {**_EMPTY, **json.load(f)}
        except (json.JSONDecodeError, OSError) as e:
            print(f"⚠️ تعذّرت قراءة {STORE} ({e}) — نبدأ بمخزن فارغ.")
    return dict(_EMPTY)


DATA = _load()
SUBS = DATA.pop(_SUBS_KEY, {})


def _save():
    with open(STORE, "w", encoding="utf-8") as f:
        json.dump({**DATA, _SUBS_KEY: SUBS}, f, ensure_ascii=False, indent=1)


# ══════════════ محاكاة واجهة Firestore ══════════════
# نغطي ما تستعمله الوحدات فعلاً لا أكثر:
#   collection · document · get · set(merge) · delete · stream · batch

class _Snap:
    def __init__(self, doc_id, data, reference=None):
        self.id = doc_id
        self._data = data
        self.exists = data is not None
        self.reference = reference

    def to_dict(self):
        return dict(self._data or {})


class _Doc:
    def __init__(self, col, doc_id):
        self._col, self.id = col, doc_id

    @property
    def parent(self):
        return self._col

    def collection(self, name):
        """فرعٌ تحت مستند — `users/{uid}/results` وأخواته.

        ⭐ أُضيف لأن التحليلات تقرأ النتائج والمحادثات من الفروع: مخزنٌ
           مسطّح يجعل تبويب التحليلات يبدو «بلا بيانات» محلياً دائماً،
           فلا يُفحص أصلاً.
        """
        return _Col(SUBS.setdefault(f"{self._col.name}/{self.id}/{name}", {}),
                    name, owner=(self._col.name, self.id))

    def get(self):
        return _Snap(self.id, self._col.data.get(self.id), self)

    def set(self, patch, merge=False):
        cur = dict(self._col.data.get(self.id) or {}) if merge else {}
        for key, value in patch.items():
            if isinstance(value, dict) and "__inc__" in value:
                cur[key] = int(cur.get(key, 0) or 0) + value["__inc__"]
            elif value == "__server_ts__":
                cur[key] = "server-time"
            else:
                cur[key] = value
        self._col.data[self.id] = cur
        _save()

    def delete(self):
        self._col.data.pop(self.id, None)
        _save()

    def __repr__(self):
        return f"<_Doc {self._col.name}/{self.id}>"


class _Col:
    def __init__(self, data, name="", owner=None):
        self.data, self.name, self.owner = data, name, owner

    @property
    def parent(self):
        """يُصعِّد من الفرع لمستند صاحبه — عليه يقوم فلتر الشريحة."""
        if not self.owner:
            return None
        return _Doc(_Col(DATA.setdefault(self.owner[0], {}), self.owner[0]),
                    self.owner[1])

    def document(self, doc_id):
        return _Doc(self, doc_id)

    def stream(self):
        return [_Snap(k, v, _Doc(self, k)) for k, v in self.data.items()]

    def where(self, *args, **kwargs):
        """استعلامٌ مبسّط — يكفي `array_contains` الذي يستعمله صندوق الإشعارات.

        ⚠️ يعيد الكل عند أي شكل لا نفهمه: **مسحٌ زائد لا نتيجةٌ ناقصة**.
           فراغٌ كاذب هنا كان سيجعل صندوق الإشعارات يبدو فارغاً في التطوير
           بينما هو ممتلئ — فيُطارَد عطلٌ لا وجود له.
        """
        field = op = value = None
        if len(args) == 3:
            field, op, value = args
        elif "filter" in kwargs:
            f = kwargs["filter"]
            field = getattr(f, "field_path", None)
            op = getattr(f, "op_string", None)
            value = getattr(f, "value", None)
        if op != "array_contains" or field is None:
            return self
        keep = {k: v for k, v in self.data.items()
                if value in ((v or {}).get(field) or [])}
        return _Col(keep, self.name, self.owner)

    def limit(self, n):
        return self


class _Group:
    """`collection_group` — كل الفروع المتشابهة الاسم عبر كل المستندات."""

    def __init__(self, name):
        self.name = name

    def select(self, fields):
        return self          # المشروع للحقول توفيرُ نقلٍ لا يعني شيئاً محلياً

    def limit(self, n):
        return self

    def stream(self):
        for path, store in list(SUBS.items()):
            parent_col, parent_id, sub = path.split("/", 2)
            if sub != self.name:
                continue
            col = _Col(store, sub, owner=(parent_col, parent_id))
            for k, v in list(store.items()):
                yield _Snap(k, v, _Doc(col, k))


class _Batch:
    def __init__(self):
        self._ops = []

    def set(self, ref, patch, merge=False):
        self._ops.append((ref, patch, merge))

    def commit(self):
        for ref, patch, merge in self._ops:
            ref.set(patch, merge=merge)
        self._ops.clear()


class _DB:
    # 🏷️ **المخزن يُعرّف نفسه** — واللوحة تعلنه في أعلى الصفحة.
    #    بلا هذه السمة تبدو أرقامُ المذاكرة أرقامَ إنتاج: مالكٌ بحث عن
    #    حسابه بين ٤٤ حساباً مبذوراً فلم يجده، فظنّ اللوحة معطوبة.
    masar_store_kind = "dev-local"

    def collection(self, name):
        return _Col(DATA.setdefault(name, {}), name)

    def collection_group(self, name):
        return _Group(name)

    def batch(self):
        return _Batch()


def install():
    """يحقن المخزن الوهمي مكان Firestore قبل استيراد `api`."""
    # ⚠️ `.env` أولاً: `core/admin.py` يقرأ ADMIN_KEY **وقت الاستيراد**،
    #    فاستيراده قبل تحميل البيئة يجعل اللوحة تبدو مغلقة بلا سبب.
    from dotenv import load_dotenv
    load_dotenv(os.path.join(BACKEND, ".env"), override=True)

    firestore_stub = types.ModuleType("firebase_admin.firestore")
    firestore_stub.SERVER_TIMESTAMP = "__server_ts__"
    firestore_stub.Increment = lambda n: {"__inc__": n}
    sys.modules["firebase_admin.firestore"] = firestore_stub

    from core import quota
    quota._firestore = lambda: _DB()
    quota._db_ready = True

    _enable_real_push()


def _enable_real_push():
    """📲 يُهيّئ Firebase **للدفع وحده** مع إبقاء المخزن محلياً.

    ⭐ **لماذا هذا التركيب الغريب؟** لأن فحص الإشعارات مستحيلٌ بدونه:
       الدفع يحتاج اعتماداً حقيقياً (لا يُحاكى — آبل وجوجل هما من يوصلان)،
       بينما الكتابة على Firestore الحقيقي أثناء الفحص تعني إشعاراتٍ
       تجريبية في سجل الإنتاج ورموزَ أجهزةٍ في مستندات طلابٍ حقيقيين.
       فالرسالة تُدفع فعلاً، والأثر كلُّه يبقى في `.dev_store.json`.

    ⚠️ **والدفع حقيقيٌّ فعلاً**: ما يُرسَل من هنا يرنّ على أجهزةٍ حقيقية.
       فلا تُجرِّب على شريحةٍ واسعة — جرّب على جهازك وحده.
    """
    raw = os.getenv("FIREBASE_SERVICE_ACCOUNT_JSON", "").strip()
    path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "").strip()
    if not raw and not (path and os.path.isfile(path)):
        print("   📲 لا اعتماد ⇒ لا دفع (الإشعارات تُحفظ في الصناديق فقط)",
              flush=True)
        return
    try:
        import firebase_admin
        from firebase_admin import credentials
        if not firebase_admin._apps:
            cert = credentials.Certificate(json.loads(raw)) if raw \
                else credentials.Certificate(path)
            firebase_admin.initialize_app(cert)
        print("   📲 ناقل الدفع **حقيقي** — ما تُرسله يرنّ على أجهزة فعلية.",
              flush=True)
    except Exception as e:
        print(f"   📲 تعذّرت تهيئة الدفع ({e}) — الإشعارات بلا رنين.", flush=True)


# ══════════════ بذرة اختبار ══════════════
# ثلاث منح تغطّي الحالات الثلاث (مفتوحة · تُغلق بعد أيام · لم تفتح بعد)
# كي تُرى الشارات والعدّاد والترتيب من أول تشغيل. تُضاف بـ`--seed`.

def _seed():
    from datetime import date, timedelta
    from core import scholarships as store

    today = date.today()
    day = lambda n: (today + timedelta(days=n)).isoformat()

    samples = [
        ("turkey", {
            "name": "المنحة التركية", "country": "تركيا", "flag": "🇹🇷",
            "funding_type": "full",
            "short_desc": "Türkiye Bursları — تمويل كامل مع راتب شهري",
            "about": "منحة حكومية تركية ممولة بالكامل تشمل الرسوم والسكن "
                     "والتأمين الصحي ومخصصاً شهرياً وتذاكر الطيران، إضافة إلى "
                     "سنة مجانية لتعلّم اللغة التركية قبل بدء التخصص.",
            "benefits": ["إعفاء كامل من الرسوم", "راتب شهري", "سكن جامعي",
                         "تذاكر طيران", "سنة لغة مجانية"],
            "requirements": ["معدل 70% فأعلى للبكالوريوس",
                             "العمر أقل من 21 سنة للبكالوريوس",
                             "شهادة الثانوية العامة", "جواز سفر ساري"],
            "documents": ["صورة الجواز", "كشف الدرجات مترجماً", "خطاب دافع"],
            "how_to_apply": ["أنشئ حساباً في turkiyeburslari.gov.tr",
                             "املأ البيانات الشخصية والأكاديمية",
                             "ارفع الوثائق مترجمة",
                             "اكتب خطاب الدافع بعناية",
                             "تابع بريدك لموعد المقابلة"],
            "open_date": day(-60), "close_date": day(175),
            "website": "https://turkiyeburslari.gov.tr",
            "degree_levels": ["بكالوريوس", "ماجستير"],
            "fields": ["الطب", "الهندسة", "العلوم"],
            "gradient": ["#EF4444", "#B91C1C"], "order": 0,
            "assistant_prompt":
                "ركّز على الطالب اليمني: ذكّره أن معادلة الشهادة تتم من وزارة "
                "التربية والتعليم، وأن خطاب الدافع أهم من المعدل.",
        }),
        ("qatar", {
            "name": "منحة جامعة قطر", "country": "قطر", "flag": "🇶🇦",
            "funding_type": "full",
            "short_desc": "إعفاء رسوم وسكن وتذاكر سنوية للمتفوقين",
            "about": "منح جامعة قطر للطلاب الدوليين المتفوقين تشمل الإعفاء من "
                     "الرسوم والسكن الجامعي وتذاكر سفر سنوية.",
            "requirements": ["معدل 85% فأعلى", "اجتياز متطلبات القسم"],
            "how_to_apply": ["قدّم طلب القبول أولاً في qu.edu.qa",
                             "بعد القبول قدّم على المنحة"],
            "open_date": day(-30), "close_date": day(6),   # ⏳ يُظهر العدّاد الأحمر
            "website": "https://www.qu.edu.qa",
            "degree_levels": ["بكالوريوس"],
            "gradient": ["#8B1538", "#5B0E26"], "order": 1,
        }),
        ("india", {
            "name": "المنحة الهندية ICCR", "country": "الهند", "flag": "🇮🇳",
            "funding_type": "partial",
            "short_desc": "تخصصات الهندسة والعلوم بتكاليف معيشة منخفضة",
            "about": "برنامج المجلس الهندي للعلاقات الثقافية يقدّم منحاً في "
                     "الهندسة والعلوم والإدارة مع بدل معيشة شهري.",
            "requirements": ["شهادة الثانوية العامة", "إجادة الإنجليزية"],
            "how_to_apply": ["سجّل في بوابة ICCR", "اختر ثلاث جامعات مفضلة"],
            "open_date": day(90), "close_date": day(180),  # 🟡 لم تفتح بعد
            "gradient": ["#F59E0B", "#B45309"], "order": 2,
        }),
    ]

    _seed_people()

    added = 0
    for sch_id, payload in samples:
        try:
            store.create(sch_id, payload)
            added += 1
        except store.ScholarshipError:
            pass        # موجودة مسبقاً — لا نطمس تعديلاتك
    print(f"🌱 بذرة الاختبار: أُضيفت {added} منحة "
          f"(الموجودة مسبقاً تُترك كما هي).", flush=True)




# ══════════════ بذرة الطلاب والاستخدام والنتائج ══════════════
# ⭐ **بلا هذه البذرة لا يُفحص تبويب التحليلات محلياً إطلاقاً:** كل قسم فيه
#    يعرض «لا بيانات بعد» بصدق، فلا يُرى شكل الأرقام ولا يُكتشف خطأ في
#    حسابها إلا في الإنتاج. والأرقام هنا **مصطنعة معلنة للتطوير** — لا
#    تُخلط بأرقام الإنتاج لأن المخزن ملفٌّ محليٌّ مستقل.

def _seed_people():
    import random
    from datetime import date, timedelta

    if DATA.get("users"):
        print("👥 المستخدمون موجودون — لا نطمسهم.", flush=True)
        return

    random.seed(7)              # بذرةٌ ثابتة: نفس الأرقام في كل تشغيل
    today = date.today()
    day = lambda n: (today - timedelta(days=n)).isoformat()

    profiles = [
        (1, "عام", 8), (2, "علمي", 7), (2, "أدبي", 5),
        (3, "علمي", 14), (3, "أدبي", 9),
    ]
    subjects = {
        "علمي": ["احياء", "كيمياء", "فيزياء", "رياضيات"],
        "أدبي": ["تاريخ", "جغرافيا", "عربي"],
        "عام": ["احياء", "عربي", "رياضيات"],
    }
    lessons = ["الخلية", "الانقسام", "الوراثة", "التنفس", "المناعة"]

    uid_n = 0
    for grade, track, count in profiles:
        for _ in range(count):
            uid_n += 1
            uid = f"dev{uid_n:03d}"
            age = random.randint(0, 80)          # منذ متى سجّل
            DATA["users"][uid] = {
                "name": f"طالب {uid_n}", "email": f"{uid}@example.test",
                "grade": grade, "track": track, "role": "student",
                "banned": uid_n % 23 == 0,
                "created_at": day(age),
                # 🔔 المفتاحان بالاسمين اللذين يكتبهما التطبيق ويقرؤهما
                #    الخادم — بذرةٌ باسمٍ ثالث تجعل الفحص المحلي يكذب.
                "settings": {
                    "notif_general": uid_n % 11 != 0,
                    "notif_scholarships": uid_n % 7 != 0,
                    "notifications": uid_n % 11 != 0 or uid_n % 7 != 0,
                },
            }
            # نشاطٌ متفاوت: بعضهم يومي وبعضهم هجر التطبيق
            active_days = random.randint(0, min(age, 30))
            for _ in range(active_days):
                d = day(random.randint(0, 29))
                key = f"{uid}_{d}"
                DATA["usage"][key] = {"asks": DATA["usage"].get(key, {}).get("asks", 0)
                                      + random.randint(1, 6)}
            # نتائج اختبارات لبعضهم
            for k in range(random.randint(0, 4)):
                subject = random.choice(subjects[track])
                picked = random.sample(lessons, random.randint(1, 3))
                total = len(picked) * 5
                score = random.randint(int(total * 0.3), total)
                wrong = []
                for lesson in picked:
                    for _ in range(random.randint(0, 3)):
                        wrong.append({"topic": "", "lesson": lesson, "unit": "الوحدة الأولى"})
                SUBS.setdefault(f"users/{uid}/results", {})[f"q{k}"] = {
                    "type": "quiz", "subject": subject, "grade": grade,
                    "track": track, "unit": "الوحدة الأولى", "lessons": picked,
                    "score": score, "total": total,
                    "duration_sec": random.randint(120, 900),
                    "wrong": wrong[:total - score],
                    "asked_per_lesson": {l: 5 for l in picked},
                    "created_at": day(random.randint(0, 29)) + "T10:00:00",
                }
            # محادثات تعليم
            for k in range(random.randint(0, 3)):
                SUBS.setdefault(f"users/{uid}/conversations", {})[f"c{k}"] = {
                    "title": "محادثة", "subject": random.choice(subjects[track]),
                    "mode": random.choice(["شرح", "تلخيص", "أمثلة"]),
                    "grade": grade, "track": track,
                    "last_updated": day(random.randint(0, 29)) + "T12:00:00",
                }
            # محادثات منح — للثالث غالباً
            if grade == 3 and uid_n % 3 == 0:
                sid = random.choice(["turkey", "qatar", "india"])
                SUBS.setdefault(f"users/{uid}/scholarship_chats", {})["s0"] = {
                    "title": "استفسار", "scholarship_id": sid,
                    "scholarship_name": {"turkey": "المنحة التركية",
                                         "qatar": "منحة جامعة قطر",
                                         "india": "المنحة الهندية ICCR"}[sid],
                    "created_at": day(random.randint(0, 29)) + "T09:00:00",
                    "last_updated": day(random.randint(0, 29)) + "T09:30:00",
                }

    # 👨‍🏫 معلّمون — **بدونهم لا يمكن فحص عرض الدور في اللوحة إطلاقاً**:
    #    تبدو خانة «معلّم» صفراً دائماً فيُظنّ العرض معطوباً وهو سليم.
    #    ولهم صفٌّ ومسار كالطلاب لأن أدواتهم تُبنى من دروس صفٍّ بعينه —
    #    وهذا بالضبط ما يجب أن تعرضه اللوحة «يُدرّس» لا «الصف».
    for i, (tg, tt) in enumerate([(3, "علمي"), (2, "أدبي"), (1, "عام")], 1):
        DATA["users"][f"dev-teacher{i}"] = {
            "name": f"أستاذ {i}", "email": f"teacher{i}@example.test",
            "grade": tg, "track": tt, "role": "teacher",
            "banned": False, "created_at": day(30 + i * 5),
            "settings": {"notif_general": True, "notif_scholarships": False},
        }

    DATA["users"]["dev-admin"] = {
        "name": "المالك", "email": "owner@example.test", "grade": 3,
        "track": "علمي", "role": "admin", "created_at": day(120),
    }
    _save()
    print(f"👥 بذرة التطوير: {len(DATA['users'])} مستخدماً، "
          f"{len(DATA['usage'])} يوم استخدام، "
          f"{sum(len(v) for k, v in SUBS.items() if k.endswith('/results'))} نتيجة اختبار.",
          flush=True)


def main():
    install()
    from core import admin as core_admin   # بعد install كي تُقرأ البيئة أولاً

    print("=" * 62)
    print("🧪 وضع التطوير: مخزن محلي بدل Firestore — لا تستعمله في الإنتاج")
    print(f"   الملف: {STORE}")
    print(f"   المنح المحفوظة: {len(DATA.get('scholarships', {}))}")
    if not core_admin.gate_open():
        print("   ⛔ اللوحة مغلقة: اضبط ADMIN_KEY أو ADMIN_EMAILS في .env")
    else:
        print("   ✅ اللوحة مفتوحة على /admin")
    print("=" * 62, flush=True)

    if "--seed" in sys.argv:
        _seed()

    import api
    import uvicorn
    uvicorn.run(api.app, host="0.0.0.0",
                port=int(os.getenv("PORT", "8000")))


if __name__ == "__main__":
    main()
