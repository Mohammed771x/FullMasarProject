import '../config/app_config.dart';

// ==========================================
// 🔗 مسارات الـ Backend (نفس عقد السيرفر الأصلي حرفياً)
// ==========================================
class ApiEndpoints {
  ApiEndpoints._();

  static String get _base => AppConfig.baseUrl;

  // المحادثة الرئيسية
  static String ask() => "$_base/ask";

  // المحتوى العام
  static String units(String subject) => "$_base/subjects/units?subject=$subject";

  static String lessons(String subject, String unit) =>
      "$_base/subjects/lessons?subject=$subject&unit=$unit";

  static String examYears(String subject) => "$_base/exams/years?subject=$subject";

  static String examSections(String subject, String year) =>
      "$_base/exams/sections?subject=$subject&year=$year";

  // الرياضيات
  static String mathLessons(String branch) => "$_base/math/lessons?branch=$branch";

  static String mathExamYears(String branch) => "$_base/math/exams/years?branch=$branch";

  static String mathExamLessons(String branch, String year) =>
      "$_base/math/exams/lessons?branch=$branch&year=$year";
}
