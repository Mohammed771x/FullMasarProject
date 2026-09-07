# ==================================================
# 🛡️ core/image_guard.py — التحقق من الصور الواردة
# ==================================================
# لا نثق بما يرسله العميل إطلاقاً:
#   1. سقف الحجم يُفحص **قبل** فك الترميز (صورة ضخمة تفجّر الذاكرة)
#   2. النوع يُحدَّد من **البصمة السحرية** لا من حقل mime الذي يرسله العميل
#   3. JPEG/PNG/WebP فقط — لا SVG (يحمل سكربتات) ولا GIF ولا أي شيء آخر
#   4. الصورة لا تُكتب على القرص ولا تُسجَّل في اللوجات إطلاقاً

import base64
import binascii

# سقف base64 ≈ 2 ميجابايت نصاً ≈ 1.5 ميجابايت صورة.
# التطبيق يضغط إلى ~1024px/جودة 65 فينتج عادةً 80–250 كيلوبايت.
MAX_B64_CHARS = 2_000_000
MAX_RAW_BYTES = 1_500_000

# البصمات السحرية المقبولة
_SIGNATURES = (
    (b"\xff\xd8\xff", "image/jpeg"),
    (b"\x89PNG\r\n\x1a\n", "image/png"),
)


class ImageRejected(Exception):
    """صورة مرفوضة — الرسالة عربية وصالحة للعرض للطالب مباشرة."""


def _detect_mime(raw: bytes) -> str:
    for sig, mime in _SIGNATURES:
        if raw.startswith(sig):
            return mime
    # WebP: "RIFF" ثم "WEBP" عند الإزاحة 8
    if len(raw) >= 12 and raw[:4] == b"RIFF" and raw[8:12] == b"WEBP":
        return "image/webp"
    raise ImageRejected("📷 صيغة الصورة غير مدعومة. استخدم JPG أو PNG.")


def validate(image_b64: str) -> tuple[str, str]:
    """يتحقق من الصورة ويرجع (base64 نظيف، mime حقيقي).
    يرمي ImageRejected برسالة عربية عند أي خلل."""
    if not image_b64:
        raise ImageRejected("📷 لم تصل الصورة.")

    # قد يرسل العميل data URL كاملاً — نقتطع الترويسة
    if image_b64.startswith("data:"):
        comma = image_b64.find(",")
        if comma == -1:
            raise ImageRejected("📷 صيغة الصورة غير صالحة.")
        image_b64 = image_b64[comma + 1:]

    image_b64 = image_b64.strip()

    # ① الحجم قبل فك الترميز
    if len(image_b64) > MAX_B64_CHARS:
        raise ImageRejected("📷 الصورة كبيرة جداً. صوّرها بجودة أقل وحاول مجدداً.")

    # ② فك الترميز
    try:
        raw = base64.b64decode(image_b64, validate=True)
    except (binascii.Error, ValueError):
        raise ImageRejected("📷 تعذّرت قراءة الصورة.")

    if not raw:
        raise ImageRejected("📷 الصورة فارغة.")
    if len(raw) > MAX_RAW_BYTES:
        raise ImageRejected("📷 الصورة كبيرة جداً. صوّرها بجودة أقل وحاول مجدداً.")

    # ③ النوع من البصمة لا من ادّعاء العميل
    mime = _detect_mime(raw)
    return image_b64, mime
