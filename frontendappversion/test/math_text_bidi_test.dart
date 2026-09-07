// 🧪 ترتيب القراءة داخل MathText — العلّة الثالثة: القلب **بين** الكلمات.
//
// الاختبار يقرأ مواضع الويدجتات على المحور الأفقي ويرتّبها يساراً→يميناً،
// فيقيس ما تراه العين فعلاً لا ما في الشجرة.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/math_text.dart';

/// نصوص السطر مرتَّبةً كما تُقرأ من اليسار إلى اليمين على الشاشة.
Future<List<String>> visualOrder(WidgetTester tester, String source) async {
  await tester.pumpWidget(MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: SizedBox(width: 1200, child: MathText(source))),
    ),
  ));
  await tester.pump();

  final entries = <(double, String)>[];
  for (final w in tester.widgetList<Text>(find.byType(Text))) {
    final box = find.byWidget(w).evaluate().first.renderObject as RenderBox;
    entries.add((box.localToGlobal(Offset.zero).dx, w.data ?? ''));
  }
  entries.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final e in entries) e.$2];
}

void main() {
  group('السطر اللاتيني يُقرأ من اليسار', () {
    testWidgets('معادلة كيميائية: المتفاعلات قبل النواتج', (tester) async {
      final order = await visualOrder(
        tester,
        r'HI => H2 + I2 , dH = -25.9 KJ',
      );
      // الذرّة قد تنقسم عند الأرقام («H2» ⇒ «H» + «2»)، فالمقياس هو
      // ترتيب القراءة لا المسافات.
      expect(order.join(), 'HI=>H2+I2,dH=-25.9KJ');
    });

    testWidgets('معادلة فيزيائية فيها كسر', (tester) async {
      final order = await visualOrder(tester, r'E = \frac{1}{2} m v2');
      // الكسر ويدجت لا نصّ، فنتحقّق من ترتيب ما حوله.
      expect(order.join(), startsWith('E='));
      expect(order.indexOf('E'), lessThan(order.indexOf('m')));
      expect(order.indexOf('m'), lessThan(order.indexOf('v')));
    });

    testWidgets('مقطع لاتيني داخل جملة عربية يُقرأ LTR', (tester) async {
      final order = await visualOrder(tester, r'راجع كتاب Physics 101 هنا');
      expect(order.indexOf('Physics'), lessThan(order.indexOf('101')));
    });
  });

  group('🛡️ العربية لا تتأثّر إطلاقاً', () {
    testWidgets('جملة عربية بكسر وأرقام تبقى RTL', (tester) async {
      final order = await visualOrder(
        tester,
        r'السرعة = \frac{المسافة}{الزمن} تساوي 20 متر',
      );
      // الترتيب المرجعي مُلتقَط من السلوك قبل الإصلاح — يجب ألّا يتغيّر.
      expect(order, [
        'متر', '20', 'تساوي', 'المسافة', 'الزمن', '=', 'السرعة',
      ]);
    });

    testWidgets('السالب يبقى ملتصقاً بعدده', (tester) async {
      final order = await visualOrder(tester, r'قيمة د(-2) تساوي -1.17');
      expect(order.contains('-1.17'), isTrue);
      expect(order.contains('-2'), isTrue);
    });

    testWidgets('أرقام متتالية بلا لاتينية لا تُقلب', (tester) async {
      final order = await visualOrder(tester, r'المجموع 20 و 30 و 40');
      expect(order, ['40', 'و', '30', 'و', '20', 'المجموع']);
    });
  });
}
