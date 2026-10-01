# ==================================================
# 🔒 core/user_controls.py — قراراتُ الإدارة على حسابٍ بعينه
# ==================================================
# ☢️ **ثغرةٌ حقيقية (فحص 2026-10-01):** الحظرُ و`quota_override` كانا يُكتبان
#    في `users/{uid}` وحده — وقواعد Firestore تسمح لصاحب المستند **بحذفه**
#    (`allow delete: if isOwner(uid)` لزرّ «احذف حسابي»). فالمحظور يكفيه
#    نداءٌ واحد من SDK:
#
#        deleteDoc(doc(db, 'users', myUid))      // ثم يُعيد إنشاءه نظيفاً
#
#    فيسقط `banned` ويسقط معه أيُّ حدٍّ خاصٍّ وضعه الأدمن (الحدُّ صفرٌ حظرٌ ليّن).
#    وحراسةُ الحقلين في القواعد لا تنفع هنا: الحذفُ لا يُعدّل حقلاً، يُزيل المستند.
#
# ✅ والعلاج: القرارُ يُحفظ في `user_controls/{uid}` — مجموعةٌ **لا يقرؤها
#    العميل ولا يكتبها** (القواعد ترفض كلَّ شيء)، ويكتبها الخادم بـAdmin SDK.
#    و`users/{uid}` يبقى نسخةً للعرض فقط؛ وحين يوجد الحقل هنا فهو الحَكَم.
#
# ⚖️ ولماذا «الحَكَم» لا «أو»؟ رفعُ الحظر يكتب `banned: false` هنا، فلو
#    جُمِع بـ«أو» مع نسخةٍ قديمة في `users/{uid}` لبقي المرفوعُ حظرُه محظوراً.
#    والحساباتُ المحظورة قبل هذا الملف (بلا مستندٍ هنا) تبقى على `users/{uid}`
#    كما كانت — ولتثبيتها: `tools/backfill_user_controls.py`.

COLLECTION = "user_controls"
FIELDS = ("banned", "quota_override")


def read(db, uid: str):
    """قرارات حسابٍ واحد — أو `None` إن لم يُتَّخذ فيه قرار. يرمي عند العطل
    (المستدعي يقرّر: `user_state` يفشل مفتوحاً كما كان)."""
    if db is None or not uid:
        return None
    snap = db.collection(COLLECTION).document(uid).get()
    return (snap.to_dict() or {}) if snap.exists else None


def read_all(db) -> dict:
    """`{uid: قرارات}` لكل الحسابات — للوحة والتحليلات. المجموعةُ صغيرة
    (المحظورون وأصحاب الحدّ الخاص وحدهم)، ومسحُها قراءةٌ لكلٍّ منهم."""
    if db is None:
        return {}
    try:
        return {doc.id: (doc.to_dict() or {})
                for doc in db.collection(COLLECTION).stream()}
    except Exception as e:                      # noqa: BLE001
        print(f"⚠️ تعذّرت قراءة {COLLECTION} ({e}) — يُعرض ما في users/ وحده.")
        return {}


def apply(user_doc: dict | None, controls: dict | None) -> dict:
    """مستند المستخدم بعد تطبيق قرارات الإدارة عليه — نسخةٌ جديدة لا تعديل.

    الحقلُ الموجود في `controls` يحكم (حتى `None`/`False`)، والغائب يترك
    قيمة `users/{uid}` كما هي.
    """
    out = dict(user_doc or {})
    for key in FIELDS:
        if controls and key in controls:
            out[key] = controls[key]
    return out


def write(db, uid: str, **fields) -> None:
    """يكتب قراراً (دمجاً) — والحقول المسموحة هي [FIELDS] وحدها."""
    bad = set(fields) - set(FIELDS)
    if bad:
        raise ValueError(f"حقول غير مسموحة: {sorted(bad)}")
    db.collection(COLLECTION).document(uid).set(dict(fields), merge=True)
