// ⬇️ «انزل للأسفل» وإعادةُ فتح المحادثة — إلى القاع الحقيقيّ.
//
// 🔴 **رُئي في المحاكي (فحص ٢٠٢٦-١٠-٠٢):** في محادثةٍ طويلة احتاج الزرُّ
//    ثلاثَ نقراتٍ ثم اختفى قبل القاع، والمحادثةُ المعادُ فتحُها تبدأ من
//    منتصفها. القائمةُ كسولة، و`maxScrollExtent` تقديرٌ يكبر أثناء النزول.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/chat/presentation/widgets/chat_list_view.dart';

/// محادثةٌ طويلةٌ متفاوتةُ الأطوال — كما يصنعها شرحٌ مخزونٌ ثم أسئلة.
List<Map<String, dynamic>> _longChat() => [
      for (var i = 0; i < 24; i++) ...[
        {"role": "user", "text": "سؤال رقم $i"},
        {
          "role": "ai",
          "text": "جواب رقم $i\n\n${"سطرٌ من شرحٍ طويل يملأ الفقاعة. " * (i.isEven ? 40 : 3)}",
          "refs": <String>[],
        },
      ],
      {"role": "user", "text": "آخر سؤال"},
      {"role": "ai", "text": "آخر جواب", "refs": <String>[]},
    ];

Future<ChatController> _pump(WidgetTester tester) async {
  final c = ChatController();
  addTearDown(c.dispose);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    // كما في الشاشة: القائمةُ تُعاد بناؤها مع كل إشعارٍ من المتحكّم.
    home: Scaffold(
      body: ListenableBuilder(
        listenable: c,
        builder: (_, _) => ChatListView(controller: c),
      ),
    ),
  ));
  return c;
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void _expectAtTrueBottom(WidgetTester tester, ChatController c) {
  final p = c.scrollController.position;
  expect(p.pixels, moreOrLessEquals(p.maxScrollExtent, epsilon: 1),
      reason: "وقف قبل القاع: ${p.pixels} من ${p.maxScrollExtent}");
  expect(find.text("آخر جواب"), findsOneWidget,
      reason: "آخرُ رسالةٍ ليست على الشاشة");
}

void main() {
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('scroll_bottom');
    await ChatStorage.initForTests(dir.path);
  });
  tearDownAll(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  testWidgets('🔽 نقرةٌ واحدة على «انزل للأسفل» تصل آخرَ رسالة', (tester) async {
    final c = await _pump(tester);
    c.messages = _longChat();
    c.refresh();
    await tester.pump();
    c.scrollController.jumpTo(0); // الطالبُ صعد إلى أوّل المحادثة
    await tester.pump();

    c.jumpToBottomAndStick();
    await _frames(tester);
    _expectAtTrueBottom(tester, c);
    expect(c.stick.isStuck, isTrue);
  });

  testWidgets('📂 إعادةُ فتح محادثةٍ طويلة تبدأ من آخرها لا من منتصفها',
      (tester) async {
    final c = await _pump(tester);
    final conv = ChatConversation(
      id: "long",
      title: "طويلة",
      subject: "احياء",
      mode: "سؤال",
      messages: [
        for (final m in _longChat())
          ChatMessage(role: m["role"], text: m["text"]),
      ],
      createdAt: DateTime.now(),
      lastUpdated: DateTime.now(),
    );
    await c.loadConversation(conv);
    await _frames(tester);
    _expectAtTrueBottom(tester, c);
  });
}
