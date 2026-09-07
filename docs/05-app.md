# 05 — تطبيق الطالب

**الأساس المعتمد: `frontendappversion/`** ([ADR-004](08-decisions.md))

## البنية الحالية (نظيفة ✅)
```
lib/
├── main.dart (14)
├── app/     bootstrap.dart · app.dart
├── core/    config · network · storage · theme · error · widgets
└── features/
    ├── chat/          ✅ الميزة الحقيقية
    │   ├── data/models · data/repositories
    │   └── presentation/controllers · screens · widgets
    ├── future_masar/  🎨 ديمو 22 شاشة — يُفصل عن الإنتاج
    ├── instructions/  ✅
    └── onboarding/    ✅
```

## المطلوب إضافته
```
core/
├── sync/     sync_service.dart          Hive ↔ Firestore
├── remote/   remote_config_service.dart نظام meta.version
└── services/ auth · notification · analytics · tts · stt
features/
└── auth/  home/  scholarships/  quiz/  services/  settings/  saved/
```

## إضافات قسم التعليم (المرحلة 3)
- شريط الصفوف (افتراضي: صف الطالب)
- 📷 صورة (ضغط ≤800px، jpeg 70) · 🎤 صوت (`ar`)
- شرائح أسئلة مقترحة
- أزرار الفقاعة: ⭐ حفظ · 📤 مشاركة كصورة · 🔊 استماع

## الحزم المطلوبة
```
firebase_core auth firestore storage messaging crashlytics analytics
rive speech_to_text flutter_tts image_picker
carousel_slider screenshot share_plus connectivity_plus
```
إصلاحات: نقل `build_runner`/`hive_generator` لـ dev · هجرة `flutter_markdown` · تقليل مكتبات المعادلات

## قواعد ثابتة
1. RTL · Cairo · `AppColors` الحالي هو المرجع
2. **لا إعادة بناء لما يعمل** — `ChatController` و`ChatRepository` يبقيان
3. Hive أولاً للعرض
4. كل استدعاء: مهلة + معالجة أخطاء موحّدة (**بما فيها 429**)
5. الاختبار على أجهزة 2GB — Rive له fallback صورة ثابتة
6. **الديمو لا يُشحن للطلاب**
