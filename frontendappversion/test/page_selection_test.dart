// ==========================================
// 📄 اختيار الصفحات — بديل «اكتب 13، 14، 15» بيدك
// ==========================================
// 🔴 **ما شكا منه المالك (2026-09-09):** الطالب يكتب أرقام الصفحات داخل
//    سؤاله. فإن أخطأ رقماً لم يعرف، وإن سأل سؤالاً تبعياً ضاعت صفحاته.
//
// ⭐ **وما صار:** الأرقام تصل مع القدرات، ويُنتقى منها بشريطٍ أفقيّ،
//    وتبقى الشرائح فوق حقل الكتابة تُرسل مع كل رسالة.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';

SubjectCapabilities _caps(Map<String, dynamic> pages) =>
    SubjectCapabilities.fromJson({
      "subject": "احياء",
      "lessons": {"available": false, "units": []},
      "pages": pages,
    });

void main() {
  group('📋 قراءة الصفحات من القدرات', () {
    test('تصل أرقام كل وحدة مع النداء نفسه', () {
      final c = _caps({
        "available": true,
        "units": ["الجهاز العصبي", "التكاثر"],
        "unit_pages": {
          "الجهاز العصبي": [9, 10, 11],
          "التكاثر": [62, 63],
        },
        "max_selectable": 3,
      });
      expect(c.pagesAvailable, isTrue);
      expect(c.pagesIn("التكاثر"), [62, 63]);
      expect(c.maxSelectablePages, 3);
    });

    test('«الكل» تجمع المنهج مرتّباً وبلا تكرار', () {
      // ⚠️ صفحةٌ قد ترد في وحدتين متجاورتين؛ وتكرارُها في المُنتقي يجعل
      //    الطالب يظن أنه أضاف اثنتين وهو أضاف واحدة.
      final c = _caps({
        "available": true,
        "units": ["أ", "ب"],
        "unit_pages": {
          "أ": [12, 11, 10],
          "ب": [12, 20],
        },
      });
      expect(c.pagesIn("الكل"), [10, 11, 12, 20]);
    });

    test('وحدةٌ بلا صفحات تعطي قائمةً فارغة لا خطأً', () {
      final c = _caps({"available": true, "units": ["أ"], "unit_pages": {}});
      expect(c.pagesIn("أ"), isEmpty);
      expect(c.pagesIn("الكل"), isEmpty);
    });
  });

  group('🛡️ خادمٌ أقدم', () {
    test('غياب unit_pages لا يُسقط المادة', () {
      // ⚠️ الغياب ليس «لا صفحات»: تطبيقٌ محدَّث أمام خادمٍ قديم يجب أن
      //    يبقى عاملاً بوضع الصفحات القديم لا أن يعرض شاشةً فارغة.
      final c = _caps({"available": true, "units": ["أ"]});
      expect(c.pagesAvailable, isTrue);
      expect(c.unitPages, isEmpty);
      expect(c.maxSelectablePages, 3);   // حدٌّ افتراضيّ معقول
    });

    test('مادةٌ بلا وضع صفحات أصلاً', () {
      final c = _caps({"available": false});
      expect(c.pagesAvailable, isFalse);
      expect(c.pagesIn("الكل"), isEmpty);
    });
  });
}
