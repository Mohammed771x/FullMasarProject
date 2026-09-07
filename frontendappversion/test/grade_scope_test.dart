// 🎓 نطاق الصف — القاعدة التي يقوم عليها فصل السنوات الثلاث.
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/session/grade_scope.dart';

void main() {
  const g3sci = GradeScope(3, 'علمي');
  const g1 = GradeScope(1, 'عام');

  test('النطاق يشمل سجلّ صفّه ومساره', () {
    expect(g3sci.includes(3, 'علمي'), isTrue);
  });

  test('صفٌّ آخر لا يدخل النطاق', () {
    expect(g3sci.includes(1, 'عام'), isFalse);
    expect(g3sci.includes(2, 'علمي'), isFalse);
  });

  // 🔑 «ثاني علمي» و«ثاني أدبي» منهجان مختلفان بمواد مختلفة — خلطُهما
  //    يجعل التحليل يقول للطالب إن أضعف مادةٍ عنده مادةٌ لا يدرسها.
  test('المسار يفصل داخل الصف الواحد', () {
    const g2sci = GradeScope(2, 'علمي');
    expect(g2sci.includes(2, 'أدبي'), isFalse);
    expect(g2sci.includes(2, 'علمي'), isTrue);
  });

  // 🕰️ سجلّاتٌ حُفظت قبل وجود الحقل — تظهر في كل الصفوف حتى تُتبنّى،
  //    لأن اختفاءها بعد التحديث يُقرأ عطباً لا ميزة.
  test('سجلٌّ بصفٍّ صفر ينتمي لكل نطاق', () {
    expect(g3sci.includes(0, ''), isTrue);
    expect(g1.includes(0, 'علمي'), isTrue);
  });

  test('المفتاح والمساواة', () {
    expect(g3sci.key, '3|علمي');
    expect(const GradeScope(3, 'علمي'), g3sci);
    expect(const GradeScope(3, 'أدبي'), isNot(g3sci));
  });
}
