// وحدةُ الدرس — أساس اختيار الدروس عبر وحدات مختلفة في «اختبر نفسك».
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';

void main() {
  const caps = SubjectCapabilities(
    subject: 'كيمياء',
    lessonsAvailable: true,
    pagesAvailable: false,
    lessonsUnits: [
      LessonsUnit(unit: 'الكيمياء الحرارية', lessons: ['الطاقة', 'الإنثالبي']),
      LessonsUnit(unit: 'الكيمياء الكهربائية', lessons: ['خلايا خزن الطاقة']),
    ],
    pagesUnits: [],
    examsAvailable: true,
    quizAvailable: true,
  );

  test('يجد وحدة الدرس أياً كانت وحدته', () {
    expect(caps.unitOfLesson('الإنثالبي'), 'الكيمياء الحرارية');
    expect(caps.unitOfLesson('خلايا خزن الطاقة'), 'الكيمياء الكهربائية');
  });

  test('درس غير موجود ⇒ null لا استثناء', () {
    expect(caps.unitOfLesson('درس وهمي'), isNull);
    expect(caps.unitOfLesson(''), isNull);
  });

  test('⭐ دروس من وحدتين تُعرف وحدتاهما — ولا يُسقَط أيٌّ منها', () {
    // هذا ما كان يكسر «اختبار المراجعة»: أضعف الدروس موزّعة على وحدات
    const suggested = ['الإنثالبي', 'خلايا خزن الطاقة'];
    final found = {for (final l in suggested) l: caps.unitOfLesson(l)};
    expect(found.values.whereType<String>().length, 2);
    expect(found.values.toSet().length, 2, reason: 'الوحدتان مختلفتان');
  });
}
