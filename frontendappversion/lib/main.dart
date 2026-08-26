import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';

// ==========================================
// 🎯 نقطة الدخول
// ==========================================
// كل التهيئة في AppBootstrap، وكل جذر الواجهة في MasarApp.
// المشروع مقسّم إلى core/ و features/ — راجع الملفات هناك.
void main() async {
  final home = await AppBootstrap.initialize();
  runApp(MasarApp(home: home));
}
