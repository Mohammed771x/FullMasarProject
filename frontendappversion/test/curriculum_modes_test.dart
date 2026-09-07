// الأوضاع تأتي من المنهج + قدرات الخادم، لا من قائمة مكتوبة في الشاشة.
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/config/curriculum.dart';

void main() {
  group('الأساس', () {
    test('الرياضيات بلا وضع تلخيص', () {
      final m = Curriculum.modesFor("رياضيات");
      expect(m, isNot(contains("تلخيص")));
      expect(m.first, "شرح");
    });

    test('بقية المواد لها تلخيص', () {
      for (final s in ["احياء", "فيزياء", "كيمياء", "عربي", "انجليزي", "تاريخ"]) {
        expect(Curriculum.modesFor(s), contains("تلخيص"), reason: s);
      }
    });
  });

  group('قرار المالك: الوزاري للثالث كما هو + اختبارات بجواره ([31§9])', () {
    test('الثالث العلمي: خمس شرائح', () {
      expect(Curriculum.modesFor("فيزياء", grade: 3, examsAvailable: true),
          ["شرح", "تلخيص", "سؤال", "وزاري", "اختبارات"]);
    });

    test('★ الثالث الأدبي: الوزاري يبقى ولو لم يُكتشف بنك أسئلة', () {
      // العلّة التي وقعت: ربط الوزاري ببنك الأسئلة أخفاه عن الثالث الأدبي.
      // قرار المالك: الثالث لا يُمَس — علمياً كان أو أدبياً.
      final m = Curriculum.modesFor("عربي", grade: 3, examsAvailable: false);
      expect(m, contains("وزاري"));
      expect(m, ["شرح", "تلخيص", "سؤال", "وزاري", "اختبارات"]);
    });

    test('كل الصفوف ترى شريحة الاختبارات', () {
      for (final g in [1, 2, 3]) {
        expect(Curriculum.modesFor("عربي", grade: g), contains("اختبارات"), reason: "صف $g");
      }
    });

    test('الأول والثاني: الوزاري يُحذف والاختبارات مكانه', () {
      for (final g in [1, 2]) {
        final m = Curriculum.modesFor("فيزياء", grade: g, examsAvailable: false);
        expect(m, ["شرح", "تلخيص", "سؤال", "اختبارات"], reason: "صف $g");
        expect(m, isNot(contains("وزاري")), reason: "صف $g");
      }
    });

    test('الأول/الثاني: لو أُضيف بنك أسئلة يوماً ظهر الوزاري تلقائياً', () {
      expect(Curriculum.modesFor("فيزياء", grade: 2, examsAvailable: true),
          contains("وزاري"));
    });

    test('★ الاختبارات تظهر دائماً — حتى لمادة لم تُضف دروسها بعد', () {
      // الطالب يرى الباب مفتوحاً، وشاشة الإعداد تشرح إن كان المحتوى قادماً.
      final m = Curriculum.modesFor("احياء", grade: 3);
      expect(m, contains("اختبارات"));
      expect(m, contains("وزاري"));
    });

    test('الرياضيات في الثالث: أربع شرائح (بلا تلخيص)', () {
      expect(Curriculum.modesFor("رياضيات", grade: 3, examsAvailable: true),
          ["شرح", "سؤال", "وزاري", "اختبارات"]);
    });
  });

  test('كل مواد كل الصفوف لها أوضاع صالحة', () {
    const valid = {"شرح", "تلخيص", "سؤال", "وزاري", "اختبارات"};
    for (var g = 1; g <= 3; g++) {
      for (final t in Curriculum.tracksFor(g)) {
        for (final s in Curriculum.subjectsFor(g, t)) {
          final modes = Curriculum.modesFor(s, grade: g, examsAvailable: false);
          expect(modes, isNotEmpty, reason: "$s ($g ${t.label})");
          expect(valid.containsAll(modes), isTrue, reason: "$s: $modes");
          if (g == 3) {
            expect(modes, contains("وزاري"), reason: "الثالث يحتفظ بالوزاري دائماً");
          } else {
            expect(modes, isNot(contains("وزاري")), reason: "الوزاري للثالث فقط");
          }
        }
      }
    }
  });
}
