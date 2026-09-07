// كل نقاط المحتوى يجب أن تحمل الصف والمسار.
// الخلل المُصلَح: بدونهما يفترض الخادم (3، علمي) فيرى طالب الأول محتوى الثالث.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/core/network/api_endpoints.dart';

import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';

void main() {
  group('قدرات المادة — التوافق مع خادم أقدم', () {
    test('خادم لا يرسل quiz/exams: الاختبارات تُستنتج من الدروس', () {
      // العلّة التي وقعت: خادم قديم بلا هذين المفتاحين جعل التطبيق يقول
      // «لا توجد دروس» لمادة دروسها موجودة فعلاً.
      final caps = SubjectCapabilities.fromJson({
        "subject": "فيزياء",
        "lessons": {"available": true, "units": [
          {"unit": "الفيزياء الذرية", "lessons": ["نظرية بوهر"]}
        ]},
        "pages": {"available": false, "units": []},
      });

      expect(caps.lessonsAvailable, isTrue);
      expect(caps.quizAvailable, isTrue);    // مستنتَجة من الدروس
      expect(caps.examsAvailable, isTrue);   // الوزاري يبقى كما كان
      expect(caps.lessonsIn("الفيزياء الذرية"), ["نظرية بوهر"]);
    });

    test('خادم حديث: القيم المرسَلة تُحترم كما هي', () {
      final caps = SubjectCapabilities.fromJson({
        "subject": "احياء",
        "lessons": {"available": false, "units": []},
        "pages": {"available": true, "units": ["الجهاز العصبي"]},
        "exams": {"available": true},
        "quiz": {"available": false},
      });

      expect(caps.quizAvailable, isFalse);
      expect(caps.examsAvailable, isTrue);
      expect(caps.pagesAvailable, isTrue);
    });

    test('مادة بلا محتوى إطلاقاً', () {
      final caps = SubjectCapabilities.fromJson({
        "subject": "فيزياء",
        "lessons": {"available": false, "units": []},
        "pages": {"available": false, "units": []},
      });
      expect(caps.isEmpty, isTrue);
      expect(caps.quizAvailable, isFalse);
    });
  });

  final scoped = <String, String>{
    "units": ApiEndpoints.units("انجليزي", 1, "عام"),
    "lessons": ApiEndpoints.lessons("انجليزي", "الوحدة", 1, "عام"),
    "examYears": ApiEndpoints.examYears("انجليزي", 2, "أدبي"),
    "examSections": ApiEndpoints.examSections("انجليزي", "2024", 2, "أدبي"),
    "mathLessons": ApiEndpoints.mathLessons("تفاضل", 2, "علمي"),
    "mathExamYears": ApiEndpoints.mathExamYears("تفاضل", 2, "علمي"),
    "mathExamLessons": ApiEndpoints.mathExamLessons("تفاضل", "2024", 2, "علمي"),
    "capabilities": ApiEndpoints.capabilities("انجليزي", 1, "عام"),
  };

  scoped.forEach((name, url) {
    test('$name يحمل grade و track', () {
      expect(url, contains("grade="));
      expect(url, contains("track="));
    });
  });

  test('القيم المُمرَّرة هي التي تظهر في الرابط', () {
    expect(ApiEndpoints.units("انجليزي", 1, "عام"), contains("grade=1"));
    expect(ApiEndpoints.units("انجليزي", 1, "عام"), contains("track=عام"));
    expect(ApiEndpoints.examYears("عربي", 3, "أدبي"), contains("grade=3"));
    expect(ApiEndpoints.examYears("عربي", 3, "أدبي"), contains("track=أدبي"));
  });
}
