# ==================================================
# 🔔 core/notifications.py — الإشعارات: جمهورٌ محسوب وسجلٌّ حقيقي
# ==================================================
# 🔴 **ما لا يفعله هذا الملف، ولماذا:** لا يرسل عبر FCM. لا `firebase_messaging`
#    في `pubspec.yaml` ولا رمز تسجيل جهاز (`fcm_token`) في أي مستند — فلا
#    يوجد شيءٌ يُرسل إليه. وزرٌّ يقول «أُرسل» بلا مُرسَلٍ إليه أسوأ من غيابه:
#    يظن المالك أن آلاف الطلاب قرأوا إعلاناً لم يصل أحداً.
#
# ⭐ **وما يفعله بدلاً من ذلك حقيقيٌّ كاملٌ لا واجهةُ عرض:**
#      • يحسب الجمهور **فعلاً** من `users` و`usage` بنفس تعريف [audience]
#        الذي تستعمله التحليلات — فالعدد المعروض قبل الإرسال عددٌ لا تقدير.
#      • يثبّت **لقطة المستلمين** وقت الإنشاء: من يسجّل غداً ليس مقصوداً
#        بإعلان اليوم، ولو طابق الشريحة.
#      • يخزّن الرسالة في `notifications/{id}` بحالةٍ صريحة، ويقدّمها على
#        `/notifications/inbox` لصاحبها — فالبنية **تعمل من طرفها الخادم**
#        ولا ينقصها إلا ناقلٌ يُوصلها دفعاً (push).
#
# 📬 والحالة تُقال كما هي: `pending` = محفوظ ومستهدَف وينتظر ناقلاً.
#    ويوم يُضاف FCM، ما يتغيّر عاملٌ يقرأ هذه المستندات — لا هذا الملف ولا
#    اللوحة ولا الجمهور.

import uuid
from datetime import datetime, timedelta, timezone

from . import audience
from . import push
from . import quota

MAX_TITLE = 80
MAX_BODY = 300
MAX_KEEP = 200              # سقف السجل — الأقدم يُحذف يدوياً لا آلياً
MAX_RECIPIENTS_STORED = 5000
RETENTION_DAYS = 30         # ما يبقى في صندوق الطالب

# وجهةُ النقر: نفس مفاتيح أقسام الوصول + «بلا وجهة».
LINK_SECTIONS = ("none", "education", "quiz", "analysis",
                 "scholarships", "teacher", "services")


class NotificationError(Exception):
    """خطأ برسالة عربية جاهزة للعرض في اللوحة."""


def _db():
    db = quota._firestore()
    if db is None:
        raise NotificationError(
            "⚠️ Firestore غير متاح على الخادم — لا يمكن حفظ الإشعارات ولا "
            "حساب جمهورها. اضبط FIREBASE_SERVICE_ACCOUNT_JSON.")
    return db


def available() -> bool:
    return quota._firestore() is not None


def delivery_available() -> bool:
    """هل يوجد ناقل دفعٍ مضبوط؟

    ⭐ سؤالٌ يُجاب **وقت الطلب** لا وقت الاستيراد: الخادم قد يُهيَّأ بعد
       أول استيراد، واللوحة تلتقط الفرق من الرد لا من تحديثٍ لها.
    """
    return push.available()


# ══════════════ الجمهور ══════════════

def _load_people():
    """المستخدمون + سياق النشاط — القراءة الوحيدة التي يحتاجها الجمهور."""
    from . import analytics
    db = _db()
    users = analytics._read_users(db)
    daily, _ = analytics._read_usage(db)
    return users, audience.build_context(daily)


def _accepts(user: dict, link: str) -> bool:
    """مفتاحُ الطالب الموافق لهذا الإشعار — مفتاح المنح لإشعار المنح."""
    key = "notif_scholarships" if link == "scholarships" else "notif_general"
    return user.get(key, user.get("notifications", True)) is not False


def preview(segment: str, notifications_only: bool = True,
            uids: list | None = None, link: str = "none") -> dict:
    """👁️ **ملخّص الجمهور قبل الإرسال** — عددٌ محسوب لا موعود.

    ⭐ يعرض التفصيل بالصف أيضاً: «٣٠٠ مستلم» رقمٌ لا يُراجَع، أما «٢٠٠ ثالث
       علمي و١٠٠ ثالث أدبي» فيكشف الشريحة الخاطئة قبل أن تصل الرسالة.
    """
    segment = audience.validate(segment)
    users, ctx = _load_people()

    # 🔴 **`None` تعني «استعمل الشريحة»، و`[]` تعني «لم تختر أحداً».**
    #    وخلطُهما كارثة صامتة: أدمنٌ يختار وضع «طلاب محدّدون» ثم لا يختار
    #    أحداً فيُرسَل الإعلانُ **للشريحة كلها** بدل لا أحد. `if uids:`
    #    وحدها كانت تفعل ذلك بالضبط لأن القائمة الفارغة قيمةٌ كاذبة.
    if uids is not None:
        chosen = {str(u).strip() for u in uids if str(u).strip()}
        people = [u for u in users if u["uid"] in chosen]
        missing = sorted(chosen - {u["uid"] for u in people})
        segment_label = f"مجموعة محدّدة ({len(people)})"
    else:
        people = audience.filter_users(users, segment, ctx)
        missing = []
        segment_label = audience.label(segment)

    # ⛔ المحظور لا يُشعَر — إشعارُ من منعناه دخولَ المنصّة تناقض.
    banned = [u for u in people if u["banned"]]
    people = [u for u in people if not u["banned"]]

    muted = []
    if notifications_only:
        muted = [u for u in people if not _accepts(u, link)]
        people = [u for u in people if _accepts(u, link)]

    # 📲 من لا جهازَ مسجّلٌ له لا يصله دفعٌ — يُقال عدده ولا يُخصم من
    #    الجمهور: الرسالة تبقى في صندوقه ويقرؤها عند فتح التطبيق.
    without_device = sum(1 for u in people if not u.get("devices"))

    by_grade = {}
    for u in people:
        if (u.get("role") or "student") != "student":
            key = "مديرون"
        else:
            g = u["grade"] if isinstance(u["grade"], int) else "?"
            key = f"الصف {g}" + (f" — {u['track']}" if u["track"] and g != 1 else "")
        by_grade[key] = by_grade.get(key, 0) + 1

    return {
        "segment": segment,
        "segment_label": segment_label,
        "recipients": len(people),
        "devices": sum(int(u.get("devices") or 0) for u in people),
        "without_device": without_device,
        "excluded_banned": len(banned),
        "excluded_muted": len(muted),
        "unknown_uids": missing,
        "by_grade": sorted([{"label": k, "count": v} for k, v in by_grade.items()],
                           key=lambda r: -r["count"]),
        "sample": [{"uid": u["uid"], "name": u["name"] or "—", "email": u["email"]}
                   for u in people[:8]],
        "uids": [u["uid"] for u in people],
        "delivery": delivery_available(),
        # 🗣️ تُقال في اللوحة حرفياً — الأدمن يستحق أن يعرف قبل الضغط لا بعده.
        # ⚠️ نصٌّ مجرّد لا Markdown: اللوحة تعرضه كنصّاً، فنجماتُ التوكيد
        #    تظهر كما هي فتبدو كخطأ في الرسالة نفسها.
        "delivery_note": _delivery_note(len(people), without_device),
    }


def _delivery_note(recipients: int, without_device: int) -> str:
    if not delivery_available():
        return ("ℹ️ لا ناقل دفع (FCM) مضبوط على الخادم: الإشعار يُحفظ "
                "ويُستهدَف فعلياً ويظهر في صندوق الطالب عند فتح التطبيق، "
                "لكنه لن يرنّ على الجهاز.")
    reachable = recipients - without_device
    if not reachable:
        return ("⚠️ لا جهاز مسجَّلاً لأيٍّ من هؤلاء: الإشعار سيُحفظ في "
                "صناديقهم ويظهر عند فتح التطبيق، ولن يرنّ على جهاز.")
    if without_device:
        return (f"✅ سيرنّ على أجهزة {reachable} منهم، "
                f"و{without_device} بلا جهاز مسجَّل بعد — يصلهم في صندوق "
                "التطبيق عند فتحه.")
    return "✅ الإشعار سيُدفع لأجهزة كل المستلمين."


# ══════════════ الإنشاء ══════════════

def _clean_text(value, limit: int, field: str) -> str:
    text = str(value or "").strip()
    if not text:
        raise NotificationError(f"❌ «{field}» مطلوب.")
    return text[:limit]


def create(payload: dict) -> dict:
    """يُنشئ إشعاراً مستهدَفاً ويثبّت لقطة مستلميه."""
    from firebase_admin import firestore as fs

    title = _clean_text((payload or {}).get("title"), MAX_TITLE, "العنوان")
    body = _clean_text((payload or {}).get("body"), MAX_BODY, "النص")
    segment = audience.validate((payload or {}).get("segment") or "all")
    link = str((payload or {}).get("link") or "none")
    if link not in LINK_SECTIONS:
        raise NotificationError(f"❌ وجهة غير معروفة: «{link}».")
    only_enabled = (payload or {}).get("notifications_only") is not False
    # ⚠️ **لا `or []` هنا**: تُحوّل `None` (استعمل الشريحة) إلى `[]`
    #    (لم تختر أحداً) — فينقلب المعنى تماماً.
    uids = (payload or {}).get("uids")

    audit = preview(segment, notifications_only=only_enabled, uids=uids, link=link)
    if not audit["recipients"]:
        raise NotificationError(
            "❌ لا مستلم واحد يطابق هذا الجمهور — راجع الشريحة قبل الإرسال.")

    recipients = audit["uids"][:MAX_RECIPIENTS_STORED]
    now = datetime.now(timezone.utc)
    doc_id = uuid.uuid4().hex[:20]
    record = {
        "title": title,
        "body": body,
        "segment": segment,
        "segment_label": audit["segment_label"],
        "link": link,
        "notifications_only": only_enabled,
        "recipients": recipients,
        "recipient_count": audit["recipients"],
        "truncated": audit["recipients"] > len(recipients),
        "created_at": now.isoformat(),
        "expires_at": (now + timedelta(days=RETENTION_DAYS)).isoformat(),
        "created_ts": fs.SERVER_TIMESTAMP,
    }

    # ⭐ **يُحفظ قبل أن يُدفع، لا بعده.** لو انقلب الترتيب لوصل الإشعار
    #    أجهزةَ الطلاب ثم فشل الحفظ، فيبقى في جيوبهم بلا أثرٍ عند الأدمن:
    #    لا يعرف أنه أُرسل فيرسله ثانيةً. والحفظُ أولاً أسوأُ حالاته سجلٌّ
    #    بلا دفعٍ — وهو ما تقوله الحالة صراحةً.
    record["status"] = "pending"
    ref = _db().collection("notifications").document(doc_id)
    ref.set(record)

    delivery = _deliver(doc_id, ref, title, body, link, recipients)
    out = {k: v for k, v in record.items() if k not in ("recipients", "created_ts")}
    out.update(delivery)
    return {"id": doc_id, **out,
            "audience": {k: audit[k] for k in
                         ("by_grade", "excluded_banned", "excluded_muted",
                          "without_device", "delivery_note")}}


def _deliver(doc_id: str, ref, title: str, body: str, link: str,
             recipients: list) -> dict:
    """يدفع الإشعار ويكتب نتيجةً **حقيقية** في المستند.

    🛟 وفشلُ الدفع لا يرمي: الإشعار محفوظٌ ومستهدَفٌ وسيصل في صندوق
       التطبيق. رميُ الخطأ هنا يجعل اللوحة تقول «فشل» عن شيءٍ نجح نصفه —
       فالحالة تُكتب كما هي ويُقرأ سببها.
    """
    if not delivery_available():
        note = "لا ناقل دفع مضبوط — الإشعار في صناديق المستلمين."
        ref.set({"reason": note}, merge=True)
        return {"status": "pending", "sent": 0, "failed": 0, "devices": 0,
                "delivered_note": note}

    try:
        from . import analytics
        users = analytics._read_users(_db())
        wanted = set(recipients)
        token_map = push.tokens_for([u for u in users if u["uid"] in wanted])
        result = push.send(title, body,
                           {"link": link, "notification_id": doc_id}, token_map)
    except Exception as e:
        print(f"⚠️ تعذّر دفع الإشعار {doc_id}: {e}")
        note = f"تعذّر الدفع ({e}) — الإشعار محفوظ في الصناديق."
        ref.set({"status": "pending", "push_error": str(e)[:300],
                 "reason": note}, merge=True)
        return {"status": "pending", "sent": 0, "failed": 0, "devices": 0,
                "delivered_note": note}

    # 🧹 الرموز التي رفضها FCM نهائياً تُحذف — وإلا تراكمت أجهزةٌ ميتة
    #    تُبطئ كل إرسالٍ قادم وتُظهر «فشل» دائماً لا معنى له.
    pruned = push.prune(result["dead"])

    # 🔴 **«بانتظار الإرسال» كانت تُقال لحالتين لا رابط بينهما**، فيقرأ
    #    الأدمن حالةً واحدة ويفهم ما ليس صحيحاً:
    #      ① لا ناقلَ دفعٍ مضبوطاً على الخادم ⇒ شيءٌ ينتظر فعلاً (إعداداً).
    #      ② الناقل يعمل، لكن **لا جهاز مسجَّلاً لأيٍّ من المستلمين** ⇒
    #         لا شيء ينتظر إطلاقاً: انتهى الأمر، والإشعار في الصناديق.
    #    وقع فعلاً: أُرسل إلى «ثالث علمي» فبقي «⏳ بانتظار الإرسال» إلى
    #    الأبد، فظُنّ أن الإرسال معطوب — ولم يكن فيه عطلٌ واحد، بل لم يكن
    #    في الشريحة كلها جهازٌ واحد يُدفع إليه.
    if result["sent"]:
        status = "sent"
    elif result["failed"]:
        status = "failed"
    elif not result["devices"]:
        status = "no_devices"
    else:
        status = "pending"

    note = {
        "sent": (f"وصل {result['users_reached']} مستلماً على "
                 f"{result['sent']} جهازاً."),
        "no_devices": ("لا جهاز مسجَّلاً لأيٍّ من المستلمين — الإشعار محفوظ "
                       "في صناديقهم ويظهر عند فتح التطبيق. لا شيء ينتظر."),
    }.get(status, "لم يصل أي جهاز — الإشعار في الصناديق ويظهر عند فتح التطبيق.")

    ref.set({"status": status,
             "sent": result["sent"], "failed": result["failed"],
             "devices": result["devices"],
             "users_reached": result["users_reached"],
             "reason": note,
             "pruned_tokens": pruned}, merge=True)
    return {"status": status, "sent": result["sent"], "failed": result["failed"],
            "devices": result["devices"],
            "users_reached": result["users_reached"], "pruned_tokens": pruned,
            "delivered_note": note}


def list_admin(limit: int = 50) -> dict:
    """سجل الإشعارات — الأحدث أولاً، بلا قائمة المستلمين (طويلةٌ بلا فائدة)."""
    db = _db()
    rows = []
    for doc in db.collection("notifications").stream():
        d = doc.to_dict() or {}
        rows.append({
            "id": doc.id,
            "title": d.get("title", ""),
            "body": d.get("body", ""),
            "segment": d.get("segment", ""),
            "segment_label": d.get("segment_label", ""),
            "link": d.get("link", "none"),
            "status": d.get("status", "pending"),
            "recipient_count": int(d.get("recipient_count") or 0),
            "sent": int(d.get("sent") or 0),
            "failed": int(d.get("failed") or 0),
            "users_reached": int(d.get("users_reached") or 0),
            "devices": int(d.get("devices") or 0),
            # 🗣️ السبب يُخزَّن مع الإشعار لا يُعاد استنتاجه: حالةُ اليوم
            #    تُقرأ بعد شهر، وقد تغيّر الناقل والأجهزة بينهما.
            "reason": str(d.get("reason") or ""),
            "created_at": str(d.get("created_at") or ""),
        })
    rows.sort(key=lambda r: r["created_at"], reverse=True)
    from . import admin as admin_store
    return {
        "items": rows[:max(1, min(int(limit or 50), MAX_KEEP))],
        "total": len(rows),
        # 🏷️ التبويب قد يُفتح مباشرةً من `#notif` بلا المرور بالأرقام —
        #    فلا يصله وسمُ المخزن من هناك. وإشعارٌ يُرسل إلى مخزنٍ محلي
        #    وهْمُه أثقل من أي رقمٍ خاطئ.
        "store": admin_store.store_info(),
        "delivery": delivery_available(),
        "links": list(LINK_SECTIONS),
        "segments": audience.describe_all(),
    }


def delete(notif_id: str) -> dict:
    """حذف إشعار — يزيله من صناديق من لم يقرأه بعد."""
    db = _db()
    ref = db.collection("notifications").document(str(notif_id or ""))
    if not ref.get().exists:
        raise NotificationError("❌ لا يوجد إشعار بهذا المعرّف.")
    ref.delete()
    return {"id": notif_id, "deleted": True}


# ══════════════ صندوق الطالب ══════════════

def inbox(uid: str, limit: int = 20) -> list:
    """📬 ما يخصّ هذا المستخدم — يقرأه التطبيق عند الإقلاع.

    ⚠️ اللقطة هي المرجع لا الشريحة: من طابق الشريحة بعد الإنشاء لا يصله
       إعلانٌ لم يكن مقصوداً به. ولو أُعيد الحساب هنا لتغيّر الجمهور بمرور
       الوقت — فيصل إعلانُ «مبروك نتائج الفصل» لمن سجّل بعده بشهر.
    """
    if not uid:
        return []
    try:
        db = quota._firestore()
        if db is None:
            return []
        today = datetime.now(timezone.utc).isoformat()

        # ⚠️ **استعلامٌ لا مسحٌ كامل**: هذا المسار يُنادى في كل إقلاعٍ لكل
        #    طالب. مسحُ مئتَي إشعارٍ لكلٍّ منهم يعني مئتَي قراءةٍ محاسَبة
        #    لأجل صندوقٍ فارغ غالباً. و`array_contains` يقرأ ما يخصّه وحده.
        #    والسقوط للمسح يبقى: مخزنُ التطوير لا يعرف `where`.
        try:
            col = db.collection("notifications")
            try:                       # الشكل الحديث — الموضعي مهجور بتحذير
                from google.cloud.firestore_v1.base_query import FieldFilter
                query = col.where(filter=FieldFilter(
                    "recipients", "array_contains", uid))
            except ImportError:
                query = col.where("recipients", "array_contains", uid)
            docs = list(query.limit(200).stream())
        except Exception:
            docs = list(db.collection("notifications").stream())

        out = []
        for doc in docs:
            d = doc.to_dict() or {}
            if uid not in (d.get("recipients") or []):
                continue
            if str(d.get("expires_at") or "") < today:
                continue
            out.append({
                "id": doc.id,
                "title": d.get("title", ""),
                "body": d.get("body", ""),
                "link": d.get("link", "none"),
                "created_at": str(d.get("created_at") or ""),
            })
        out.sort(key=lambda r: r["created_at"], reverse=True)
        return out[:max(1, min(int(limit or 20), 50))]
    except Exception as e:
        # 🛟 صندوقٌ فارغ لا شاشةٌ ساقطة: الإشعار ليس جوهر التطبيق.
        print(f"⚠️ تعذّرت قراءة صندوق الإشعارات: {e}")
        return []
