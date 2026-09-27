// 🧪 دفعةُ المالك (٢٠٢٦-٠٩-٢٤ — الثالثة): رسالةُ وسط الشاشة بدل الشريط
//    السفليّ، والاقتراحاتُ تغيب مع الصورة، ولا مادةَ في بطاقة المعلّم.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/widgets/masar_notice.dart';

Widget _app(void Function(BuildContext) onTap) => MaterialApp(
  home: Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      body: Builder(
        builder: (ctx) => Align(
          alignment: Alignment.topCenter,
          child: ElevatedButton(
            onPressed: () => onTap(ctx),
            child: const Text('go'),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  group('🔔 MasarNotice', () {
    test('يقرأ النوعَ من الرمز الأوّل ويُسقطه من النصّ', () {
      expect(MasarNotice.split('✅ تم تحديث صورتك'), ('✅', 'تم تحديث صورتك'));
      expect(MasarNotice.split('🗑️ حُذفت الصورة'), ('🗑️', 'حُذفت الصورة'));
      expect(MasarNotice.split('⚠️ تعذّر فتح الرابط'), (
        '⚠️',
        'تعذّر فتح الرابط',
      ));
      // رمزٌ في الآخِر يُنزع كذلك
      expect(
        MasarNotice.split('يمكنك اختيار 3 دروس كحد أقصى 📚').$2,
        'يمكنك اختيار 3 دروس كحد أقصى',
      );
      // وبلا رمزٍ يبقى النصُّ كما هو
      expect(MasarNotice.split('لا رمز هنا'), ('', 'لا رمز هنا'));
    });

    testWidgets('التأكيدُ في وسط الشاشة، بلا رمزٍ خام، ويختفي وحده', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app((c) => MasarNotice.say(c, '⭐ حُفظت في المحفوظات')),
      );
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 300));

      final msg = find.text('حُفظت في المحفوظات');
      expect(msg, findsOneWidget);
      expect(
        find.textContaining('⭐'),
        findsNothing,
        reason: 'الأيقونةُ تقوم مقامه',
      );
      // 🎯 في الوسط لا في الأسفل
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      final y = tester.getCenter(msg).dy;
      expect(y, greaterThan(screen.height * 0.3));
      expect(y, lessThan(screen.height * 0.7));
      expect(find.byType(SnackBar), findsNothing);

      // ⏱️ المدّةُ على قدر الجملة وسقفُها ٣٫٥ث
      await tester.pump(const Duration(seconds: 4));
      expect(msg, findsNothing, reason: 'تختفي وحدها');
    });

    testWidgets('ما يحتاج إقراراً نافذةٌ بـ«فهمت» تُغلق بلمسة', (tester) async {
      await tester.pumpWidget(_app((c) => MasarNotice.imageLimit(c, 2)));
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('وصلت الحدّ الأقصى'), findsOneWidget);
      expect(find.textContaining('صورتين فقط'), findsOneWidget);

      await tester.tap(find.text('فهمت'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('وصلت الحدّ الأقصى'), findsNothing);
    });

    testWidgets('تأكيدان متتاليان لا يتكدّسان', (tester) async {
      var n = 0;
      await tester.pumpWidget(
        _app((c) => MasarNotice.toast(c, 'حُفظت ${++n}')),
      );
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('go'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('حُفظت 1'), findsNothing);
      expect(find.text('حُفظت 2'), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
    });
  });

  test('🚫 لا شريطَ سفليّاً باقٍ في التطبيق', () {
    final offenders = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => f.readAsStringSync().contains('showSnackBar('))
        .map((f) => f.path)
        .toList();
    expect(offenders, isEmpty);
  });

  test('📷 الاقتراحاتُ العلويّة تغيب مع صورةٍ مرفقة (التعليم والمعلّم)', () {
    final src = File(
      'lib/features/chat/presentation/screens/main_chat_screen.dart',
    ).readAsStringSync();
    final gate = src.substring(
      src.indexOf('if (_c.messages.isEmpty &&'),
      src.indexOf('ModeSuggestions(controller: _c)'),
    );
    expect(gate, contains('!_c.hasAttachments'));
  });

  test('📚 بطاقةُ المعلّم بلا حقل مادة', () {
    final src = File(
      'lib/features/teacher/presentation/widgets/teacher_settings_panel.dart',
    ).readAsStringSync();
    expect(src, isNot(contains('_label("المادة الدراسية:")')));
    expect(src, isNot(contains('c.setSubject(')));
  });
}
