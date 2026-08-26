// ==========================================
// 🚀 نقطة دخول مستقلة لديمو "مسار المستقبل" (Front-End فقط)
// ==========================================
// لا تلمس main.dart ولا التطبيق الأصلي إطلاقاً.
//
// للتشغيل في كروم لعرض الديمو:
//   flutter run -d chrome -t lib/future_masar_demo.dart
//
// لبناء نسخة ويب للديمو:
//   flutter build web -t lib/future_masar_demo.dart

import 'package:flutter/material.dart';

import 'features/future_masar/presentation/future_masar_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const FutureMasarApp());
}
