// 🎭 دور الحساب: طالب أو معلّم — ولا شيء غيرهما يُكتب من التطبيق.
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/auth/user_repository.dart';

void main() {
  group('AppRole — القائمة المغلقة', () {
    test('الدوران المسموحان يمرّان كما هما', () {
      expect(AppRole.sanitize('student'), 'student');
      expect(AppRole.sanitize('teacher'), 'teacher');
    });

    // 🔴 **الاختبار الأهم في الملف.** `admin` يفتح مستندات كل الطلاب
    //    ([firestore.rules])، فلو مرّ من التطبيق لصار الامتياز الإداري
    //    خياراً في شاشة الإعدادات.
    test('admin لا يمرّ أبداً — يُقرأ طالباً', () {
      expect(AppRole.sanitize('admin'), 'student');
      expect(AppRole.read('admin'), 'student');
    });

    test('الفارغ والمجهول والفراغ الزائد كلها طالب', () {
      expect(AppRole.sanitize(null), 'student');
      expect(AppRole.sanitize(''), 'student');
      expect(AppRole.sanitize('  '), 'student');
      expect(AppRole.sanitize('Teacher'), 'student'); // حسّاسٌ لحالة الأحرف
      expect(AppRole.sanitize(42), 'student');
    });

    test('الفراغ حول القيمة الصحيحة يُقصّ', () {
      expect(AppRole.sanitize(' teacher '), 'teacher');
    });
  });

  group('UserProfile — قراءة الدور من المستند', () {
    UserProfile p(Map<String, dynamic> m) => UserProfile.fromMap('u1', m);

    test('مستندٌ فيه teacher ⇒ معلّم', () {
      expect(p({'role': 'teacher'}).isTeacher, isTrue);
    });

    // 🕰️ مستندات ما قبل هذه النسخة بلا حقل `role` إطلاقاً — ولا يجوز أن
    //    يُقفل عليها التطبيق ولا أن تُقرأ معلّمةً.
    test('مستندٌ قديم بلا حقل role ⇒ طالب', () {
      expect(p({'name': 'أحمد'}).role, 'student');
      expect(p({'name': 'أحمد'}).isTeacher, isFalse);
    });

    test('مستند أدمن يُعرض في التطبيق كطالب لا كدورٍ ثالث', () {
      expect(p({'role': 'admin'}).isTeacher, isFalse);
      expect(p({'role': 'admin'}).role, 'student');
    });
  });
}
