// محاذاة فقاعات المحادثة في تطبيق RTL:
// رسالة الطالب (وصورها) تلتصق باليمين، ورد المساعد باليسار.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/chat/presentation/widgets/chat_list_view.dart';

Future<void> _pumpChat(WidgetTester tester, List<Map<String, dynamic>> messages) async {
  final c = ChatController()..messages = messages;
  addTearDown(c.dispose);
  await tester.pumpWidget(MaterialApp(
    builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    home: Scaffold(body: ChatListView(controller: c)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('صورتان: الفقاعة تحتهما تُحاذي حافتهما اليمنى', (tester) async {
    await _pumpChat(tester, [
      {
        "role": "user",
        "text": "حل",
        "images": ["/tmp/masar_test_a.jpg", "/tmp/masar_test_b.jpg"],
      },
    ]);

    final images = tester.getRect(find.byKey(const ValueKey("attachedImages")));
    final bubble = tester.getRect(find.byKey(const ValueKey("bubble")));

    // نفس الحافة اليمنى — لا انزياح للجهة المقابلة.
    expect(bubble.right, moreOrLessEquals(images.right, epsilon: 0.5));
    // الفقاعة أضيق من الصورتين هنا، فالاختبار يكشف الانزياح فعلاً.
    expect(bubble.width, lessThan(images.width));
  });

  testWidgets('صورتان: مربّعان متساويان (لا تفاوت في الحواف السفلية)', (tester) async {
    await _pumpChat(tester, [
      {
        "role": "user",
        "text": "س",
        "images": ["/tmp/masar_test_a.jpg", "/tmp/masar_test_b.jpg"],
      },
    ]);

    final imgs = find.byType(Image);
    expect(imgs, findsNWidgets(2));
    final a = tester.getRect(imgs.at(0));
    final b = tester.getRect(imgs.at(1));
    expect(a.size, b.size);
    expect(a.bottom, moreOrLessEquals(b.bottom, epsilon: 0.5));
    // في RTL أول صورة هي اليمنى
    expect(a.right, greaterThan(b.right));
  });

  testWidgets('رسالة الطالب تلتصق باليمين ورد المساعد باليسار', (tester) async {
    await _pumpChat(tester, [
      {"role": "user", "text": "سؤال"},
      {"role": "assistant", "text": "جواب"},
    ]);

    final w = tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final bubbles = find.byKey(const ValueKey("bubble"));
    final user = tester.getRect(bubbles.at(0));
    final ai = tester.getRect(bubbles.at(1));

    expect(user.right, moreOrLessEquals(w - 16, epsilon: 0.5)); // 16 = حشوة القائمة
    expect(ai.left, lessThan(user.left));
  });
}
