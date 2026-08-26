import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';

// ==========================================
// 📚 مستودع المحتوى التعليمي (الوحدات/الدروس/السنوات/الأقسام)
// ==========================================
// يوحّد كل نقاط GET التي كانت مكرّرة في الكود الأصلي. كل دالة ترمي عند الفشل
// ليتولّى المتحكّم (Controller) عرض رسالة الخطأ المناسبة، تماماً كالسلوك السابق.
class TutorContentRepository {
  TutorContentRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  // وحدات مادة
  Future<List<String>> getUnits(String subject) =>
      _client.getStringList(ApiEndpoints.units(subject));

  // دروس وحدة داخل مادة
  Future<List<String>> getLessons(String subject, String unit) =>
      _client.getStringList(ApiEndpoints.lessons(subject, unit));

  // سنوات الوزاري لمادة
  Future<List<String>> getExamYears(String subject) =>
      _client.getStringList(ApiEndpoints.examYears(subject));

  // أقسام/صيغ أسئلة الوزاري
  Future<List<String>> getExamSections(String subject, String year) =>
      _client.getStringList(ApiEndpoints.examSections(subject, year));

  // دروس الرياضيات لفرع
  Future<List<String>> getMathLessons(String branch) =>
      _client.getStringList(ApiEndpoints.mathLessons(branch));

  // سنوات وزاري الرياضيات لفرع
  Future<List<String>> getMathExamYears(String branch) =>
      _client.getStringList(ApiEndpoints.mathExamYears(branch));

  // دروس وزاري الرياضيات لفرع وسنة
  Future<List<String>> getMathExamLessons(String branch, String year) =>
      _client.getStringList(ApiEndpoints.mathExamLessons(branch, year));
}
