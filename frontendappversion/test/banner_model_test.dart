// 🧪 نموذج البانر: الألوان والأيقونات تصل من الخادم كنصوص — والنصّ التالف
//    يجب أن يعطي بانراً باهتاً لا شاشةً منهارة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/features/banners/data/banner_model.dart';

void main() {
  AppBanner parse(Map<String, dynamic> j) => AppBanner.fromJson(j);

  group('التحويل من JSON', () {
    test('الحقول الكاملة', () {
      final b = parse({
        'id': 'bn_1',
        'title': 'عنوان',
        'subtitle': 'وصف',
        'icon': 'flight',
        'colors': ['#FF0000', '#00FF00'],
        'action': 'scholarship',
        'action_value': 'india',
        'order': 3,
        'auto': true,
      });
      expect(b.title, 'عنوان');
      expect(b.actionValue, 'india');
      expect(b.auto, isTrue);
      expect(b.iconData, Icons.flight_takeoff_rounded);
      expect(b.gradient, [const Color(0xFFFF0000), const Color(0xFF00FF00)]);
    });

    test('🛡️ رد ناقص لا يُسقط الشاشة', () {
      final b = parse({'id': 'x'});
      expect(b.title, '');
      expect(b.action, 'none');
      expect(b.gradient, hasLength(2));
      expect(b.iconData, Icons.star_rounded);
    });
  });

  group('الألوان', () {
    test('لونٌ تالف يُتجاهل ويبقى الصالح', () {
      expect(parse({'colors': ['أزرق', '#112233']}).gradient,
          [const Color(0xFF112233), const Color(0xFF112233)]);
    });

    test('لا لون صالح ⇒ لون الهوية لا شفافية', () {
      final g = parse({'colors': ['zzz']}).gradient;
      expect(g, hasLength(2));
      expect(g.first.a, 1.0);
    });

    test('لونٌ واحد يُكرَّر فيصير تدرّجاً مستوياً', () {
      expect(parse({'colors': ['#123456']}).gradient,
          [const Color(0xFF123456), const Color(0xFF123456)]);
    });
  });

  test('اسم أيقونة مجهول ⇒ نجمة لا فراغ', () {
    expect(parse({'icon': 'لا-يوجد'}).iconData, Icons.star_rounded);
  });

  test('كل أسماء الخادم لها أيقونة فعلية', () {
    // ⚠️ هذه القائمة **نسخة من `ICONS` في core/banners.py**. اختلافُهما يعني
    //    أيقونة مفقودة على شاشة الطالب لا يكتشفها أحد من اللوحة.
    const serverIcons = [
      'flight', 'school', 'explore', 'handshake', 'book', 'quiz',
      'chart', 'teacher', 'star', 'fire', 'gift', 'clock', 'bell',
      'rocket', 'target', 'trophy',
    ];
    final fallback = parse({'icon': 'لا-يوجد'}).iconData;
    for (final name in serverIcons) {
      final icon = parse({'icon': name}).iconData;
      if (name != 'star') {
        expect(icon, isNot(fallback), reason: 'الأيقونة «$name» غير معرّفة');
      }
    }
  });
  // ══════════════ 🎯 الفئة المستهدفة ══════════════
  // ⚠️ **التصفية المحلية هي الشبكة الثانية لا الأولى:** الخادم يصفّي حين
  //    يصله الصف. وجودها هنا يحمي حالةً واحدة — كاشٌ حُفظ لصفٍّ ثم غيّر
  //    الطالب صفّه، فيرى بانرات صفٍّ تركه حتى الإقلاع التالي.
  group('🎯 الاستهداف', () {
    AppBanner withSegment(String s) => AppBanner(id: 'b', title: 'ت', segment: s);

    test('الافتراضي للجميع', () {
      expect(parse({'title': 'ت'}).segment, 'all');
      expect(parse({'title': 'ت'}).targets(1, 'عام'), isTrue);
    });

    test('ثالث علمي يصل صاحبه وحده', () {
      final b = withSegment('g3_sci');
      expect(b.targets(3, 'علمي'), isTrue);
      expect(b.targets(3, 'أدبي'), isFalse);
      expect(b.targets(2, 'علمي'), isFalse);
      expect(b.targets(1, 'عام'), isFalse);
    });

    test('الصف كله بلا تمييز مسار', () {
      final b = withSegment('g3');
      expect(b.targets(3, 'علمي'), isTrue);
      expect(b.targets(3, 'أدبي'), isTrue);
      expect(b.targets(2, 'علمي'), isFalse);
    });

    test('ثاني أدبي', () {
      final b = withSegment('g2_lit');
      expect(b.targets(2, 'أدبي'), isTrue);
      expect(b.targets(2, 'علمي'), isFalse);
    });

    test('🛟 فئة لا يعرفها التطبيق ⇒ تُعرض للجميع', () {
      // نسخةٌ قديمة لا تُخفي بانراً لأنها لم تفهم كلمةً جديدة —
      // وإخفاؤه كان سيحرم طالباً من إعلانٍ قُصد به.
      expect(withSegment('g4_future').targets(3, 'علمي'), isTrue);
      expect(withSegment('').targets(1, 'عام'), isTrue);
    });

    test('الفئة تنجو من دورة JSON — الكاش يحفظها ويقرؤها', () {
      final b = withSegment('g3_lit');
      expect(AppBanner.fromJson(b.toJson()).segment, 'g3_lit');
    });
  });
}
