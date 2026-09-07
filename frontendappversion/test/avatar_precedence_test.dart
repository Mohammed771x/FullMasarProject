// 🧪 أيُّ صورةٍ تبقى بعد الدخول بجوجل؟
//
// علّة حقيقية وقعت: الطالب يرفع صورته، يخرج، يدخل بجوجل — فتعود صورة جوجل.
// السبب أن `upsert` تُنادى عند **كل** دخول ومعها `photoURL` من المزوّد،
// فتكتبها فوق ما رفعه.
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/auth/user_repository.dart';

void main() {
  String? resolve(String existing, String incoming) =>
      UserRepository.resolvePhotoUrl(existing: existing, incoming: incoming);

  test('🔴 العلّة: صورة المزوّد لا تمحو صورة الطالب المرفوعة', () {
    expect(resolve('https://storage/avatars/uid.jpg', 'https://google/photo.jpg'),
        isNull);
  });

  test('حساب جديد بلا صورة ⇒ صورة المزوّد ترحيبٌ مقبول', () {
    expect(resolve('', 'https://google/photo.jpg'), 'https://google/photo.jpg');
  });

  test('لا صورة هنا ولا هناك ⇒ لا كتابة أصلاً', () {
    expect(resolve('', ''), isNull);
  });

  test('دخولٌ ببريد (بلا صورة مزوّد) لا يمحو الموجودة', () {
    expect(resolve('https://storage/avatars/uid.jpg', ''), isNull);
  });

  test('الفراغات لا تُحسب صورةً', () {
    expect(resolve('   ', 'https://google/photo.jpg'), 'https://google/photo.jpg');
    expect(resolve('', '   '), isNull);
  });
}
