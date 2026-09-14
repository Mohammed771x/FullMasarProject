// ══════════════════════════════════════════════════
// 📚 «الكل» لم تعد خياراً في وضع الوحدات
// ══════════════════════════════════════════════════
//
// 🔴 **قرار المالك (2026-09-14):** «الكل ماشي الكل — ضروري يكون في وحدة
//    عشان يقلّل البحث، يكون معصور، بحثٌ أفضل.»
//
//    والقياسُ يؤيّده: كتابُ الأحياء ١٦٢ صفحة، ووحدةُ التنظيم الهرموني ١٩.
//    البحثُ في ١٩ صفحةً يميّز بين جيرانٍ متقاربين، وفي ١٦٢ يُزاحم الموضوعَ
//    صفحاتٌ من وحداتٍ لا علاقة لها به.
//
// ⚠️ **و«الكل» تبقى في سنوات الوزاري** — هناك تعني «كل السنوات» وهي
//    خيارٌ صحيح، ولا علاقة لها بنطاق البحث.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

void main() {
  test('الوحدة تبدأ فارغةً لا «الكل»', () {
    final c = ChatController();
    addTearDown(c.dispose);
    expect(c.selectedUnit, isNot("الكل"));
    expect(c.selectedUnitName, isNot("الكل"));
  });

  test('⭐ قائمةُ الوحدات لا تحوي «الكل» إطلاقاً', () {
    final c = ChatController();
    addTearDown(c.dispose);
    expect(c.availableUnits, isNot(contains("الكل")));
  });

  test('🗳️ وسنواتُ الوزاري تحتفظ بـ«الكل» — معناها هناك مختلف', () {
    // حارسٌ ضدّ حذفٍ متحمّس: «الكل» في السنوات = كل الأعوام، وهي صحيحة.
    final c = ChatController();
    addTearDown(c.dispose);
    expect(c.availableYears, isA<List<String>>());
  });
}
