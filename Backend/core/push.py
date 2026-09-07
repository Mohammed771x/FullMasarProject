# ==================================================
# 📲 core/push.py — ناقل الدفع (FCM) وحده، لا أكثر
# ==================================================
# ⭐ **لماذا ملفٌّ مستقلٌّ عن [notifications]؟** لأنهما يجيبان سؤالين
#    مختلفين: ذاك يقول **لمن**، وهذا يقول **كيف تصل**. وخلطهما يعني أن
#    تغيير الناقل (FCM اليوم، غيره غداً) يلمس منطق الجمهور — وهو أثمن
#    ما في القسم وأكثره اختباراً.
#
# 🔑 **رمز الجهاز يعيش في `users/{uid}.fcm_tokens`** (مصفوفة نصوص):
#    • القراءة مجانية عملياً — التحليلات والجمهور يقرآن مستند المستخدم
#      أصلاً، فلا رحلةَ شبكةٍ إضافية لجلب الرموز.
#    • ولو جعلناها فرعاً (`users/{uid}/devices`) لصار إرسالٌ لألف طالبٍ
#      ألفَ قراءةِ فرعٍ قبل أن تُرسل رسالةٌ واحدة.
#
# 🧹 **والرموز تُنظَّف بالفشل لا بالوقت**: جهازٌ حُذف منه التطبيق يبقى رمزُه
#    صالحاً في الظاهر حتى يرفضه FCM. فنحذف ما يرفضه صراحةً (`UNREGISTERED`)
#    ولا نحذف ما فشل لعطلٍ عابر — وإلا فقد الطالبُ إشعاراته لانقطاعِ شبكة.

from . import quota

# سقف الدفعة الواحدة في FCM.
BATCH = 500

# ⚰️ الأخطاء التي تعني «هذا الرمز مات» لا «تعذّر الآن».
#
# 🔴 **بالنوع أولاً لا بالنصّ.** المطابقة النصّية وحدها كانت تُخطئ خطأً
#    صامتاً: الـSDK يرمي `UnregisteredError` نصُّها **«NotRegistered»**،
#    و«notregistered» **لا تحوي** «unregistered» — فلا يُحذف رمزٌ ميت أبداً،
#    فتتراكم أجهزةٌ ميتة تُبطئ كل إرسالٍ وتُظهر «فشل» دائماً بلا معنى.
#    كُشف بفحصٍ حقيقي على FCM، لا بالقراءة.
_DEAD_TOKEN_TYPES = {
    "UnregisteredError",
    "SenderIdMismatchError",
    "InvalidArgumentError",
}
_DEAD_TOKEN_CODES = {
    "UNREGISTERED",
    "NOT_FOUND",
    "NOTREGISTERED",
    "INVALID_ARGUMENT",
    "SENDER_ID_MISMATCH",
    "registration-token-not-registered",
    "invalid-registration-token",
    "invalid-argument",
}

MAX_TOKENS_PER_USER = 10


class PushError(Exception):
    """خطأ برسالة عربية جاهزة للعرض في اللوحة."""


def _messaging():
    """وحدة `firebase_admin.messaging` — أو `None` إن لم تكن متاحة."""
    try:
        import firebase_admin
        from firebase_admin import messaging
    except Exception:
        return None
    # ⚠️ الوحدة وحدها لا تكفي: بلا تطبيقٍ مُهيّأ (أي بلا بيانات اعتماد)
    #    ينهار أول نداءٍ لا عند الاستيراد — فنفحص الاثنين معاً هنا.
    if not getattr(firebase_admin, "_apps", None):
        return None
    return messaging


def available() -> bool:
    """هل يوجد ناقل دفعٍ يعمل فعلاً؟

    ⭐ هذه الدالّة هي **كل** ما تغيّر يوم وصل FCM: اللوحة تقرأ القدرة من
       الرد لا من تحديثٍ لها، فما كان يقول «لن يرنّ» صار يقول «سيصل».
    """
    return _messaging() is not None and quota._firestore() is not None


def tokens_for(users: list) -> dict:
    """`{uid: [رموز]}` من مستندات المستخدمين المقروءة أصلاً — بلا قراءةٍ ثانية."""
    out = {}
    for u in users or []:
        raw = u.get("fcm_tokens")
        if not isinstance(raw, (list, tuple)):
            continue
        clean = [str(t).strip() for t in raw if str(t or "").strip()]
        if clean:
            out[u["uid"]] = clean[:MAX_TOKENS_PER_USER]
    return out


def send(title: str, body: str, data: dict, token_map: dict) -> dict:
    """يدفع الرسالة لكل رموز هؤلاء المستخدمين.

    يعيد `{sent, failed, devices, users_reached, dead}` — أرقامٌ حقيقية من
    رد FCM لا تقدير. و`dead` رموزٌ رفضها الخادم نهائياً فتُحذف.
    """
    messaging = _messaging()
    if messaging is None:
        raise PushError("⚠️ ناقل الدفع غير متاح على الخادم.")

    # نحتفظ بخريطة الرمز ← صاحبه كي نعرف من وصلته الرسالة فعلاً.
    owner = {}
    for uid, tokens in (token_map or {}).items():
        for t in tokens:
            owner[t] = uid
    tokens = list(owner)
    if not tokens:
        return {"sent": 0, "failed": 0, "devices": 0, "users_reached": 0, "dead": []}

    notification = messaging.Notification(title=title, body=body)
    # 🔤 كل القيم نصوص: FCM يرفض `data` بقيمةٍ غير نصية، وأسهل ما يُنسى
    #    رقمٌ يمرّ من اللوحة فيُفشل الدفعة كلها بلا سببٍ ظاهر.
    payload = {str(k): str(v) for k, v in (data or {}).items()}

    sent = failed = 0
    dead, reached = [], set()

    for start in range(0, len(tokens), BATCH):
        chunk = tokens[start:start + BATCH]
        message = messaging.MulticastMessage(
            notification=notification, data=payload, tokens=chunk,
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    channel_id="masar_general", sound="default"),
            ),
            apns=messaging.APNSConfig(
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(sound="default", badge=1)),
            ),
        )
        try:
            # ⚠️ `send_each_for_multicast` لا `send_multicast`: الأخيرة
            #    أُزيلت في الإصدارات الحديثة من الـSDK، وبقاؤها يعني قسماً
            #    يعمل على جهاز المطوّر ويسقط على الخادم.
            fn = getattr(messaging, "send_each_for_multicast", None) \
                or getattr(messaging, "send_multicast")
            response = fn(message)
        except Exception as e:
            # دفعةٌ كاملة سقطت (شبكة أو اعتماد) — لا رمزَ يُتّهم بذلك.
            print(f"⚠️ تعذّر دفع دفعة إشعارات: {e}")
            failed += len(chunk)
            continue

        for token, result in zip(chunk, response.responses):
            if result.success:
                sent += 1
                reached.add(owner[token])
                continue
            failed += 1
            if _is_dead(result.exception):
                dead.append(token)

    return {"sent": sent, "failed": failed, "devices": len(tokens),
            "users_reached": len(reached), "dead": dead}


def _is_dead(exc) -> bool:
    """هل يعني هذا الخطأ أن الرمز مات نهائياً؟

    ⚠️ الفرق يُحسم هنا لا في مكانٍ آخر: حذفُ رمزٍ فشل لانقطاعِ شبكةٍ عابر
       يعني طالباً لن يصله إشعارٌ بعد اليوم بلا أن يعرف أحدٌ لماذا.
    """
    if exc is None:
        return False
    # ① النوع — الأوثق: أسماء الـSDK ثابتة، ونصوصُها ليست كذلك.
    if type(exc).__name__ in _DEAD_TOKEN_TYPES:
        return True
    # ② ثم الرمز والنصّ — لأجل الأخطاء الملفوفة والوهميّة في الاختبارات.
    code = str(getattr(exc, "code", "") or "")
    cause_code = str(getattr(getattr(exc, "cause", None), "code", "") or "")
    text = f"{code} {cause_code} {exc}".upper().replace("-", "_").replace(" ", "")
    return any(dead.upper().replace("-", "_") in text for dead in _DEAD_TOKEN_CODES)


def prune(dead_tokens: list) -> int:
    """يحذف الرموز الميتة من مستندات أصحابها. يعيد عدد ما حُذف.

    ⚠️ **قراءةٌ فكتابةُ القائمة كاملةً، لا `ArrayRemove`**: المرور يقرأ كل
       مستندٍ أصلاً فالقائمة في اليد، والتحويل (transform) يضيف اعتماداً
       على `firebase_admin` داخل دالّةٍ تعمل في التطوير بمخزنٍ محليّ لا
       يفهم التحويلات — فيبدو التنظيف ناجحاً وهو لم يحذف شيئاً.
    """
    if not dead_tokens:
        return 0
    db = quota._firestore()
    if db is None:
        return 0

    removed = 0
    dead = set(dead_tokens)
    try:
        for doc in db.collection("users").stream():
            current = (doc.to_dict() or {}).get("fcm_tokens") or []
            remaining = [t for t in current if t not in dead]
            if len(remaining) == len(current):
                continue
            db.collection("users").document(doc.id).set(
                {"fcm_tokens": remaining}, merge=True)
            removed += len(current) - len(remaining)
    except Exception as e:
        print(f"⚠️ تعذّر تنظيف رموز الأجهزة: {e}")
    return removed


# ══════════════ تسجيل الأجهزة ══════════════
# ⭐ **لماذا يمرّ الرمز بالخادم بدل أن يكتبه التطبيق مباشرةً؟**
#    لأن `arrayUnion` من العميل **لا يمكن تحديدها بسقف**: جهازٌ مصابٌ أو
#    حلقةٌ خاطئة تكتب آلاف الرموز في مستندٍ واحد فتُثقل كل قراءةٍ له بعدها.
#    والخادم يقرأ ويقصّ ويكتب، فالسقف مفروضٌ فعلاً لا مأمولاً.
#    ولذلك أيضاً `fcm_tokens` **محظورٌ على العميل** في قواعد Firestore.

def register(uid: str, token: str, platform: str = "") -> dict:
    """يربط رمز جهازٍ بحساب. يقصّ الأقدم عند بلوغ السقف."""
    token = str(token or "").strip()
    if not uid or not token:
        raise PushError("❌ الحساب ورمز الجهاز مطلوبان.")
    if len(token) > 4096:
        raise PushError("❌ رمز الجهاز غير صالح.")

    db = quota._firestore()
    if db is None:
        raise PushError("⚠️ Firestore غير متاح — تعذّر تسجيل الجهاز.")

    ref = db.collection("users").document(uid)
    snap = ref.get()

    # ⚠️ **لا نشترط وجود المستند** — والاشتراطُ كان يُسقط تسجيلاتٍ حقيقية:
    #    عند أول دخولٍ على جهازٍ جديد يتسابق `PushService.start()` مع
    #    `_ensureProfile()`، فيصل الرمزُ قبل أن يُنشأ مستند المستخدم فيُرفض
    #    بـ400 — ولا يُعاد إرساله إلا في الإقلاع التالي. وقد وقع فعلاً في
    #    أول فحصٍ على جهازٍ حقيقي.
    # 🔒 وإسقاطُ الشرط لا يفتح ثغرة: `uid` يأتي من **توكن Firebase موثَّق**
    #    في `_identity_or_401` لا من جسد الطلب، فهو مستخدمٌ حقيقي دائماً.
    #    والكتابة بالدمج تُنشئ المستند أو تُكمله، ثم يملؤه التطبيق بالباقي.
    current = [t for t in ((snap.to_dict() or {}).get("fcm_tokens") or [])
               if isinstance(t, str) and t.strip()]
    if token in current:
        # موجودٌ أصلاً — لا كتابةَ بلا تغيير (كل إقلاعٍ ينادي هذا المسار).
        return {"registered": True, "devices": len(current), "changed": False}

    # الأحدث آخراً، والأقدم هو من يسقط عند الامتلاء.
    updated = ([t for t in current if t != token] + [token])[-MAX_TOKENS_PER_USER:]
    payload = {"fcm_tokens": updated}
    if platform:
        payload["last_platform"] = str(platform)[:16]
    ref.set(payload, merge=True)
    return {"registered": True, "devices": len(updated), "changed": True}


def unregister(uid: str, token: str) -> dict:
    """يفصل رمز جهازٍ عن حساب — يُنادى عند الخروج.

    ⚠️ **لازمٌ لا تحسين:** جوّالٌ يخرج منه طالبٌ ويدخل غيره يبقى رمزُه
       مربوطاً بالأول، فتصل إشعاراتُ الأول إلى جهازٍ يستعمله الثاني.
    """
    token = str(token or "").strip()
    if not uid or not token:
        return {"unregistered": False}
    db = quota._firestore()
    if db is None:
        return {"unregistered": False}
    try:
        ref = db.collection("users").document(uid)
        snap = ref.get()
        if not snap.exists:
            return {"unregistered": False}
        current = (snap.to_dict() or {}).get("fcm_tokens") or []
        remaining = [t for t in current if t != token]
        if len(remaining) == len(current):
            return {"unregistered": False, "devices": len(current)}
        ref.set({"fcm_tokens": remaining}, merge=True)
        return {"unregistered": True, "devices": len(remaining)}
    except Exception as e:
        print(f"⚠️ تعذّر فصل رمز الجهاز: {e}")
        return {"unregistered": False}
