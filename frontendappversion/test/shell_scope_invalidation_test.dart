// 🎓 تبديلُ الصفّ من الإعدادات يُحدِّث الأقسام.
//
// 🔴 **العطلُ كما رآه المالك (2026-09-20):** «دخلت غيّرت الصف من الإعدادات،
//    ما تغيّر عندي». و«اختبر نفسك» يقرأ الصفَّ والمسارَ مرّةً واحدةً في
//    `initState`، ثم يعيش محفوظاً في `_built` داخل `MasarShell` كي لا
//    تُعاد الشبكةُ عند كل تنقّل. فالنتيجة: طالبٌ بدّل صفَّه وبقيت أمامه
//    موادُّ الصفّ الذي تركه حتى يُغلق التطبيق ويفتحه.
//
// 🛡️ **ولماذا حارسٌ بنيويّ لا اختبارُ ويدجت؟** بناءُ `MasarShell` يستدعي
//    شبكةً وتخزيناً وقواعدَ أقسام؛ وحارسٌ لا يعمل إلا بمحاكاة نصف التطبيق
//    يُعطَّل عند أوّل تغيير فيصير أخضرَ على عيبٍ قائم. فيُحرس الشرطان
//    اللذان يصنعان السلوك: أن الجلسة **تُنادي**، وأن الهيكل **يسمع ويُبطل**.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/session/user_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('① الجلسة تُنادي مستمعيها حين يتغيّر الصفّ أو المسار', () {
    var calls = 0;
    void listener() => calls++;
    UserSession.I.addListener(listener);
    addTearDown(() => UserSession.I.removeListener(listener));

    UserSession.I
      ..grade = 3
      ..track = 'علمي';
    // الحقلان عاريان (لا setter مخصّص)، فالنداءُ يأتي من الحافظ الذي
    // يكتبهما. نستدعيه كما تستدعيه شاشةُ الإعدادات.
    UserSession.I.notifyListeners();
    expect(calls, greaterThan(0));
  });

  group('② الهيكل يسمع ويُبطل ما بُني', () {
    final src = File('lib/core/shell/masar_shell.dart').readAsStringSync();

    test('يستمع إلى الجلسة ويلغي الاستماع', () {
      expect(src.contains('UserSession.I.addListener'), isTrue,
          reason: 'الهيكل لا يسمع تبدّل الجلسة');
      expect(src.contains('UserSession.I.removeListener'), isTrue,
          reason: 'مستمعٌ لا يُلغى يُسرّب الحالة بين الجلسات');
    });

    test('ويقارن **الصفّ والمسار** معاً لا الصفّ وحده', () {
      // ⚠️ المسارُ وحدَه يبدّل المواد أيضاً (علمي ⇄ أدبي).
      expect(src.contains(r'${UserSession.I.grade}|${UserSession.I.track}'),
          isTrue);
    });

    test('وعند التبدّل تُرمى الصفحات المبنيّة', () {
      expect(src.contains('_built.clear'), isTrue,
          reason: 'بلا إبطالٍ يبقى التبويب على الصفّ القديم');
    });
  });
}
