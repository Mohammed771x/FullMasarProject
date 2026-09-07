// 🎓 نموذج المنحة: الحالة والعدّاد والفلاتر والتحويل.
//
// الحالة **تُحسب على الجهاز** لا تُقرأ من الخادم: القائمة مكيَّشة، وطالب
// يفتح التطبيق بعد أسبوعين بلا إنترنت يجب أن يرى «مغلق» لا شارةً قديمة.
// لذلك هذا الملف يختبر الحساب لا النقل.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/scholarships/data/models/scholarship.dart';

String _d(int daysFromNow) => DateTime.now()
    .add(Duration(days: daysFromNow))
    .toIso8601String()
    .substring(0, 10);

Scholarship _s({
  String id = "turkey",
  String name = "المنحة التركية",
  String country = "تركيا",
  String funding = "full",
  String? open,
  String? close,
  List<String> fields = const [],
  List<String> gradient = const [],
}) =>
    Scholarship.fromJson({
      "id": id,
      "name": name,
      "country": country,
      "funding_type": funding,
      "open_date": open ?? "",
      "close_date": close ?? "",
      "fields": fields,
      "gradient": gradient,
    });

void main() {
  group('الحالة تُحسب من التاريخين', () {
    test('قبل الفتح ⇒ يفتح قريباً', () {
      expect(_s(open: _d(10), close: _d(60)).status, SchStatus.soon);
    });

    test('بين التاريخين ⇒ مفتوح', () {
      expect(_s(open: _d(-10), close: _d(20)).status, SchStatus.open);
    });

    test('بعد الإغلاق ⇒ مغلق', () {
      expect(_s(open: _d(-60), close: _d(-1)).status, SchStatus.closed);
    });

    test('بلا مواعيد ⇒ مفتوح لا مغلق', () {
      // منحة دائمة التقديم يجب ألا تظهر مغلقة لمجرد أن الأدمن ترك التاريخ.
      expect(_s().status, SchStatus.open);
    });

    test('يوم الإغلاق نفسه ما زال مفتوحاً', () {
      // ⚠️ فخّ الساعات: مقارنةٌ بالوقت الكامل تُغلق المنحة صباح آخر يوم.
      expect(_s(open: _d(-30), close: _d(0)).status, SchStatus.open);
    });

    test('يوم الفتح نفسه مفتوح لا «قريباً»', () {
      expect(_s(open: _d(0), close: _d(30)).status, SchStatus.open);
    });
  });

  group('عدّاد الأيام المتبقية', () {
    test('يحسب الفرق بالأيام', () {
      expect(_s(open: _d(-5), close: _d(12)).daysLeft, 12);
    });

    test('آخر يوم ⇒ صفر لا سالب', () {
      expect(_s(open: _d(-5), close: _d(0)).daysLeft, 0);
    });

    test('المغلقة بلا عدّاد', () {
      expect(_s(open: _d(-60), close: _d(-3)).daysLeft, isNull);
    });

    test('التي لم تفتح بعد بلا عدّاد', () {
      // «باقٍ ٤٠ يوماً» على منحة لم تفتح يضلّل الطالب.
      expect(_s(open: _d(10), close: _d(50)).daysLeft, isNull);
    });

    test('بلا تاريخ إغلاق ⇒ بلا عدّاد', () {
      expect(_s(open: _d(-5)).daysLeft, isNull);
    });
  });

  group('الفلاتر', () {
    test('ممولة بالكامل / جزئية', () {
      expect(SchFilter.full.test(_s(funding: "full")), isTrue);
      expect(SchFilter.full.test(_s(funding: "partial")), isFalse);
      expect(SchFilter.partial.test(_s(funding: "partial")), isTrue);
    });

    test('مفتوحة الآن', () {
      expect(SchFilter.openNow.test(_s(open: _d(-1), close: _d(9))), isTrue);
      expect(SchFilter.openNow.test(_s(open: _d(5), close: _d(40))), isFalse);
    });

    test('تُغلق قريباً = مفتوحة وباقٍ ≤ ٣٠ يوماً', () {
      expect(SchFilter.closingSoon.test(_s(open: _d(-1), close: _d(12))), isTrue);
      expect(SchFilter.closingSoon.test(_s(open: _d(-1), close: _d(90))), isFalse);
      // مغلقة ⇒ لا تُحسب «تُغلق قريباً» (لا عدّاد لها أصلاً).
      expect(SchFilter.closingSoon.test(_s(open: _d(-60), close: _d(-2))), isFalse);
    });

    test('الكل يمرّر كل شيء', () {
      expect(SchFilter.all.test(_s(open: _d(-60), close: _d(-2))), isTrue);
    });
  });

  group('البحث', () {
    test('يطابق الاسم والدولة', () {
      final s = _s();
      expect(s.matches("تركي"), isTrue);
      expect(s.matches("تركيا"), isTrue);
      expect(s.matches("ماليزيا"), isFalse);
    });

    test('بحث فارغ يمرّر الكل', () {
      expect(_s().matches("   "), isTrue);
    });
  });

  group('الألوان والشارة', () {
    test('تدرّج الأدمن يُحترم', () {
      final s = _s(gradient: const ["#EF4444", "#B91C1C"]);
      expect(s.colors.first, const Color(0xFFEF4444));
    });

    test('تدرّج ناقص ⇒ لوحة احتياطية لا انهيار', () {
      expect(_s(gradient: const ["#EF4444"]).colors.length, 2);
    });

    test('اللون الاحتياطي ثابت لنفس المنحة', () {
      // عشوائيةٌ هنا تعني منحةً تغيّر لونها في كل فتح — إزعاجٌ بلا فائدة.
      expect(_s(id: "qatar").colors, _s(id: "qatar").colors);
    });

    test('بلا علم ⇒ حرفان من اسم الدولة', () {
      expect(_s().badge, isNotEmpty);
    });
  });

  group('التحويل ذهاباً وإياباً', () {
    test('toJson ثم fromJson يحفظ الحقول', () {
      final original = Scholarship.fromJson({
        "id": "qatar",
        "name": "منحة قطر",
        "country": "قطر",
        "flag": "🇶🇦",
        "short_desc": "إعفاء رسوم",
        "funding_type": "partial",
        "requirements": ["معدل 85%"],
        "how_to_apply": ["قدّم أولاً"],
        "open_date": "2026-01-01",
        "close_date": "2026-03-01",
        "gradient": ["#8B1538", "#5B0E26"],
        "order": 3,
      });
      final round = Scholarship.fromJson(original.toJson());

      expect(round.id, "qatar");
      expect(round.name, "منحة قطر");
      expect(round.requirements, ["معدل 85%"]);
      expect(round.openDate, DateTime(2026, 1, 1));
      expect(round.closeDate, DateTime(2026, 3, 1));
      expect(round.colors, original.colors);
      expect(round.order, 3);
      expect(round.isFullyFunded, isFalse);
    });

    test('حقول ناقصة لا تُسقط التحويل', () {
      // مستند قديم أو ناقص من اللوحة يجب ألا يُسقط الشاشة كلها.
      final s = Scholarship.fromJson({"id": "x", "name": "منحة", "country": ""});
      expect(s.requirements, isEmpty);
      expect(s.openDate, isNull);
      expect(s.status, SchStatus.open);
    });

    test('تاريخ مشوّه يُعامل كغائب لا كخطأ', () {
      final s = Scholarship.fromJson(
          {"id": "x", "name": "م", "country": "ي", "close_date": "غداً"});
      expect(s.closeDate, isNull);
      expect(s.status, SchStatus.open);
    });
  });
}
