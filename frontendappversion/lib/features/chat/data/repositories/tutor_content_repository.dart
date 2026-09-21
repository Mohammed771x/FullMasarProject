import 'dart:convert';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/subject_capabilities.dart';

// ==========================================
// 📚 مستودع المحتوى التعليمي (الوحدات/الدروس/السنوات/الأقسام)
// ==========================================
// يوحّد كل نقاط GET التي كانت مكرّرة في الكود الأصلي. كل دالة ترمي عند الفشل
// ليتولّى المتحكّم (Controller) عرض رسالة الخطأ المناسبة، تماماً كالسلوك السابق.
class TutorContentRepository {
  TutorContentRepository([ApiClient? client]) : _client = client ?? ApiClient();

  final ApiClient _client;

  // ⚠️ كل دالة هنا تأخذ الصف والمسار: المحتوى مخزَّن لكل صف على حدة،
  //    ومن دونهما يرد الخادم محتوى الثالث العلمي لأي صف.

  // وحدات مادة
  Future<List<String>> getUnits(String subject, int grade, String track) =>
      _client.getStringList(ApiEndpoints.units(subject, grade, track));

  // دروس وحدة داخل مادة
  Future<List<String>> getLessons(String subject, String unit, int grade, String track) =>
      _client.getStringList(ApiEndpoints.lessons(subject, unit, grade, track));

  // سنوات الوزاري لمادة
  Future<List<String>> getExamYears(String subject, int grade, String track) =>
      _client.getStringList(ApiEndpoints.examYears(subject, grade, track));

  // أقسام/صيغ أسئلة الوزاري
  Future<List<String>> getExamSections(String subject, String year, int grade, String track) =>
      _client.getStringList(ApiEndpoints.examSections(subject, year, grade, track));

  // دروس الرياضيات لفرع
  Future<List<String>> getMathLessons(String branch, int grade, String track) =>
      _client.getStringList(ApiEndpoints.mathLessons(branch, grade, track));

  // سنوات وزاري الرياضيات لفرع
  Future<List<String>> getMathExamYears(String branch, int grade, String track) =>
      _client.getStringList(ApiEndpoints.mathExamYears(branch, grade, track));

  // دروس وزاري الرياضيات لفرع وسنة
  Future<List<String>> getMathExamLessons(String branch, String year, int grade, String track) =>
      _client.getStringList(ApiEndpoints.mathExamLessons(branch, year, grade, track));

  /// ⚡ **الشرحُ المخزون لدرسٍ — أو فراغ.** ([ApiEndpoints.lessonExplanation])
  ///
  /// 🔒 لا تنادي موديلاً ولا تخصم حصة، ولا ترمي عند الفشل: السحبُ المسبق
  ///    راحةٌ لا وظيفة. فإن تعذّر مضى الطالبُ في `/ask` كما كان بلا أن يشعر.
  Future<String> getStoredExplanation(
      String subject, String unit, String lesson, int grade, String track) async {
    try {
      final res = await _client.getRaw(ApiEndpoints.lessonExplanation(
          subject, unit, lesson, grade, track));
      if (res.statusCode != 200) return "";
      final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
      return data["found"] == true ? (data["answer"] ?? "").toString() : "";
    } catch (_) {
      return "";
    }
  }

  // 🆕 قدرات المادة (وضع الدروس / وضع الوحدات) — استدعاء واحد
  Future<SubjectCapabilities> getCapabilities(String subject, int grade, String track) async {
    final res = await _client.getRaw(ApiEndpoints.capabilities(subject, grade, track));
    if (res.statusCode != 200) {
      // 404 = مادة بلا محتوى بعد → قدرات فارغة (رسالة ودّية لاحقاً من /ask)
      return SubjectCapabilities(
          subject: subject, lessonsAvailable: false, pagesAvailable: false,
          lessonsUnits: const [], pagesUnits: const [],
          examsAvailable: false, quizAvailable: false);
    }
    final data = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    return SubjectCapabilities.fromJson(data);
  }
}
