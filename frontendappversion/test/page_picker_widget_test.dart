// 📄 المُنتقي على الشاشة — الرفض يجب أن **يُقال** لا أن يقع صامتاً.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/chat/presentation/widgets/page_picker.dart';

ChatController _controller() {
  final c = ChatController();
  c.inputType = "صفحة";
  c.selectedUnit = "الكل";
  c.caps = SubjectCapabilities.fromJson({
    "subject": "احياء",
    "lessons": {"available": false, "units": []},
    "pages": {
      "available": true,
      "units": ["أ"],
      "unit_pages": {"أ": [9, 10, 11, 12, 13]},
      "max_selectable": 3,
    },
  });
  return c;
}

Widget _wrap(ChatController c) => MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        // ⚠️ المُنتقي يقرأ حالة المتحكّم ويعتمد على إعادة بناء الأب —
        //    كما تفعل لوحة الإعدادات في التطبيق تماماً.
        child: Scaffold(
          body: ListenableBuilder(
            listenable: c,
            builder: (_, _) => PagePicker(c),
          ),
        ),
      ),
    );

void main() {
  testWidgets('يعرض صفحات النطاق ويضيف بالنقر', (t) async {
    final c = _controller();
    await t.pumpWidget(_wrap(c));

    expect(find.text('9'), findsOneWidget);
    expect(find.text('13'), findsOneWidget);

    await t.tap(find.text('9'));
    await t.pumpAndSettle();
    expect(c.selectedPages, [9]);
  });

  testWidgets('النقر ثانيةً يرفع الصفحة', (t) async {
    final c = _controller();
    await t.pumpWidget(_wrap(c));

    await t.tap(find.text('11'));
    await t.pumpAndSettle();
    expect(c.selectedPages, [11]);

    await t.tap(find.text('11'));
    await t.pumpAndSettle();
    expect(c.selectedPages, isEmpty);
  });

  testWidgets('⭐ تجاوزُ الحدّ يُقال للطالب ولا يقع صامتاً', (t) async {
    // 🔴 **العطل الذي كُشف في المحاكي:** الضغطة الرابعة تُرفض بلا أي أثر
    //    على الشاشة — فيبدو التطبيق مكسوراً لا محدوداً.
    final c = _controller();
    await t.pumpWidget(_wrap(c));

    for (final p in ['9', '11', '13']) {
      await t.tap(find.text(p));
      await t.pumpAndSettle();
    }
    expect(c.selectedPages, [9, 11, 13]);

    await t.tap(find.text('10'));
    await t.pumpAndSettle();

    expect(c.selectedPages, [9, 11, 13], reason: 'لم تُضف الرابعة');
    expect(find.textContaining('زائدة'), findsOneWidget,
        reason: 'ولم يُقل للطالب لماذا');
  });

  testWidgets('العدّاد يُقرأ «٠ من ٣» ولا ينقلب في العربية', (t) async {
    // ⚠️ «0 / 3» تنقلب في RTL فتُقرأ «3 / 0» — أي المختار ثلاثةٌ من صفر.
    final c = _controller();
    await t.pumpWidget(_wrap(c));
    expect(find.text('0 من 3'), findsOneWidget);
    expect(find.textContaining('/'), findsNothing);
  });

  testWidgets('نطاقٌ بلا صفحات يقول ذلك بدل شريطٍ فارغ', (t) async {
    final c = _controller();
    c.caps = SubjectCapabilities.fromJson({
      "subject": "احياء",
      "lessons": {"available": false, "units": []},
      "pages": {"available": true, "units": ["أ"], "unit_pages": {}},
    });
    await t.pumpWidget(_wrap(c));
    expect(find.textContaining('لا توجد صفحات'), findsOneWidget);
  });
}
