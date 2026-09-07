# ==================================================
# 🗄️ core/media_store.py — رفع الصور إلى Firebase Storage
# ==================================================
# صور المنح (الأغلفة) تُرفع هنا وتُقدَّم برابط عام، فلا تمرّ بـFirestore
# إطلاقاً ([27§3]: Storage يُستعمل لصور الأدمن وصورة الملف الشخصي فقط).
#
# ⭐ **لماذا هذا أفضل من تخزينها في Firestore:**
#   • قائمة المنح تحمل **رابطاً** (~100 بايت) بدل صورة (~50 كيلوبايت)
#   • `cached_network_image` في التطبيق يكيّشها ويعيد استعمالها بلا كود منّا
#   • لا سقف مستند 1 MiB ولا ضغط على قراءات Firestore
#
# ⚠️ الرفع من الأدمن وحده. والملف يُسمّى بمعرّف المنحة فيُستبدل عند الرفع
#    الثاني بدل أن تتراكم نسخ يتيمة.

import os
import uuid

BUCKET_NAME = os.getenv("FIREBASE_STORAGE_BUCKET", "").strip()

# مجلدات الصور داخل البَكِت — لكل نوع مجلده كي يسهل تصفّحها وتنظيفها.
FOLDERS = {
    "cover": "scholarship_covers",
    "logo": "scholarship_logos",
    # 👤 صورة الحساب — يرفعها الطالب نفسه لا الأدمن، واسم الملف معرّفه
    #    فلا يستطيع أحد الكتابة فوق صورة غيره (المعرّف يأتي من التوكن).
    "avatar": "avatars",
}
COVER_PREFIX = FOLDERS["cover"]      # للتوافق مع نداءات قائمة


class StorageUnavailable(Exception):
    """Storage غير مهيّأ — الرسالة عربية جاهزة للعرض في اللوحة."""


def _bucket():
    """البَكِت الافتراضي للمشروع.

    ⚠️ المشاريع الحديثة تستعمل `{project}.firebasestorage.app`، والقديمة
       `{project}.appspot.com` — نجرّب المضبوط بالبيئة ثم الاثنين بالترتيب.
    """
    try:
        import firebase_admin
        from firebase_admin import storage
    except ImportError:
        raise StorageUnavailable("⚠️ مكتبة Firebase غير مثبّتة على الخادم.")

    try:
        app = firebase_admin.get_app()
    except ValueError:
        raise StorageUnavailable(
            "⚠️ Firebase غير مهيّأ — يلزم FIREBASE_SERVICE_ACCOUNT_JSON.")

    project = app.project_id or os.getenv("FIREBASE_PROJECT_ID", "")
    candidates = [BUCKET_NAME] if BUCKET_NAME else []
    candidates += [f"{project}.firebasestorage.app", f"{project}.appspot.com"]

    last = ""
    for name in [c for c in candidates if c]:
        try:
            bucket = storage.bucket(name)
            if bucket.exists():
                return bucket
        except Exception as e:      # صلاحية أو شبكة — نجرّب التالي
            last = str(e)[:120]

    raise StorageUnavailable(
        "⚠️ لم أجد مساحة تخزين للمشروع. فعّل Storage من Firebase Console"
        + (f" ({last})" if last else "."))


def available() -> bool:
    try:
        _bucket()
        return True
    except StorageUnavailable:
        return False


_EXT = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}


def upload_image(kind: str, sch_id: str, raw: bytes, mime: str) -> str:
    """يرفع صورة (`cover` · `logo` · `avatar`) ويعيد رابطاً عاماً.

    ⭐ الرابط يحمل **رمزاً عشوائياً** (`?v=`) يتغيّر مع كل رفع — وبدونه يبقى
       القديم في كاش التطبيقات والـCDN بعد تبديله.
    ⭐ واسم الملف هو معرّف المنحة: الرفع الثاني **يستبدل** ولا يراكم نسخاً
       يتيمة يُدفع ثمنها بلا فائدة.
    """
    folder = FOLDERS.get(kind)
    if not folder:
        raise StorageUnavailable(f"⚠️ نوع صورة غير معروف: {kind}")

    blob = _bucket().blob(f"{folder}/{sch_id}.{_EXT.get(mime, 'jpg')}")
    blob.cache_control = "public, max-age=604800"       # أسبوع
    blob.upload_from_string(raw, content_type=mime)
    try:
        blob.make_public()
    except Exception as e:
        raise StorageUnavailable(
            "⚠️ تعذّر جعل الصورة عامة. راجع قواعد Storage في Firebase Console "
            f"({str(e)[:80]})")
    return f"{blob.public_url}?v={uuid.uuid4().hex[:8]}"


def delete_image(kind: str, sch_id: str) -> None:
    """يحذف صورة منحة بكل امتداداتها. الفشل صامت — الحذف ليس حرجاً."""
    folder = FOLDERS.get(kind)
    if not folder:
        return
    try:
        bucket = _bucket()
    except StorageUnavailable:
        return
    for ext in ("jpg", "png", "webp"):
        try:
            blob = bucket.blob(f"{folder}/{sch_id}.{ext}")
            if blob.exists():
                blob.delete()
        except Exception:
            pass


# ── أسماء مختصرة للاستعمال الشائع ──
def upload_cover(sch_id: str, raw: bytes, mime: str) -> str:
    return upload_image("cover", sch_id, raw, mime)


def delete_cover(sch_id: str) -> None:
    delete_image("cover", sch_id)
