# 🔐 دليل البناء الآمن — منصة مسار

هذا الملف يشرح كيف تبني التطبيق بأعلى درجة حماية من ناحية الكود.

## 1) البناء مع التشويش (Obfuscation)

التشويش يصعّب فك الـ APK وقراءة منطقك أو التلاعب به.

```bash
# أندرويد (APK)
flutter build apk --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=API_BASE_URL=https://mohammed771-my-tutor-backend.hf.space \
  --dart-define=ACCESS_CODE=SUPER_USER

# أندرويد (App Bundle للنشر على Google Play)
flutter build appbundle --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=API_BASE_URL=https://mohammed771-my-tutor-backend.hf.space \
  --dart-define=ACCESS_CODE=SUPER_USER

# iOS
flutter build ipa --release \
  --obfuscate \
  --split-debug-info=build/symbols \
  --dart-define=API_BASE_URL=https://mohammed771-my-tutor-backend.hf.space \
  --dart-define=ACCESS_CODE=SUPER_USER
```

> ⚠️ احتفظ بمجلد `build/symbols` في مكان آمن — تحتاجه لفك رموز تقارير الأعطال (Crash) لاحقاً.

## 2) الإعدادات عبر `--dart-define`

بدل كتابة الرابط والكود صراحةً داخل الكود، صارت تُمرَّر وقت البناء:

| المفتاح | الوصف | الافتراضي (للتطوير) |
|---------|-------|----------------------|
| `API_BASE_URL` | رابط سيرفر الإنتاج | `https://mohammed771-my-tutor-backend.hf.space` |
| `API_BASE_URL_WEB` | رابط السيرفر المحلي للويب | `http://127.0.0.1:8000` |
| `ACCESS_CODE` | كود الوصول المرسل مع كل طلب | `SUPER_USER` |

القيم الافتراضية موجودة في [`lib/core/config/app_config.dart`](lib/core/config/app_config.dart) حتى يعمل التشغيل المحلي مباشرة.

## 3) طبقات الأمان المطبّقة من ناحية الكود

- ✅ **تخزين آمن**: `device_id` يُخزَّن في `flutter_secure_storage` (Keychain/Keystore المشفّر) بدل النص الصريح، مع ترحيل تلقائي للمستخدمين الحاليين، وخطة بديلة آمنة لو فشل التخزين على جهاز قديم.
- ✅ **لا أسرار صريحة**: الرابط والكود يُمرَّران وقت البناء عبر `--dart-define`.
- ✅ **التشويش** يصعّب الهندسة العكسية للـ APK.

## 4) ملاحظة مهمة عن حماية الـ APIs (تحتاج الباك)

منع شخص أخذ التطبيق من استخدام الـ APIs **نهائياً** يتطلب تعاون الباك إند:
توقيع/توكن للطلبات (مثل JWT قصير العمر) بدل الاعتماد على كود ثابت يُرسل مع كل طلب.
حالياً كل الطلبات ترسل `code = SUPER_USER` لمطابقة الباك ريثما يُعاد تصميم المصادقة.
