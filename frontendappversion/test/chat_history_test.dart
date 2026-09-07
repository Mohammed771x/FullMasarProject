// سياسة سياق المحادثة: آخر 6 رسائل، وكل رسالة مقصوصة عند 1500 حرف.
// الباك يستخدم آخر 6 في كل مادة — إرسال 10 كان يهدر حجم الطلب بلا فائدة.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

ChatController _withMessages(int count) {
  final c = ChatController();
  c.messages = List.generate(count, (i) => {
        "role": i.isEven ? "user" : "assistant",
        "text": "رسالة رقم $i",
      });
  return c;
}

void main() {
  test('يرسل آخر 6 رسائل فقط بالترتيب الصحيح', () {
    final c = _withMessages(20);
    addTearDown(c.dispose);
    final h = c.buildChatHistory();

    expect(h.length, ChatController.historyLastN);
    expect(h.first["content"], "رسالة رقم 14"); // الأقدم ضمن الستة
    expect(h.last["content"], "رسالة رقم 19");  // الأحدث في النهاية
  });

  test('محادثة أقصر من الحد ترسل كما هي', () {
    final c = _withMessages(3);
    addTearDown(c.dispose);
    expect(c.buildChatHistory().length, 3);
  });

  test('محادثة فارغة ترسل قائمة فارغة', () {
    final c = _withMessages(0);
    addTearDown(c.dispose);
    expect(c.buildChatHistory(), isEmpty);
  });

  test('الرسالة الطويلة تُقصّ مع الاحتفاظ ببدايتها', () {
    final c = ChatController();
    addTearDown(c.dispose);
    final long = "أ" * 5000;
    c.messages = [
      {"role": "assistant", "text": long},
    ];

    final only = c.buildChatHistory().single["content"]!;
    expect(only.length, ChatController.historyMaxCharsPerMessage + 1); // +1 لعلامة القصّ
    expect(only.endsWith("…"), isTrue);
    expect(only.startsWith("أأأ"), isTrue);
  });

  test('الدور يُحفظ كما هو', () {
    final c = _withMessages(2);
    addTearDown(c.dispose);
    final h = c.buildChatHistory();
    expect(h[0]["role"], "user");
    expect(h[1]["role"], "assistant");
  });

  test('السقف الأقصى للسياق: 6 × 1500 حرف', () {
    final c = ChatController();
    addTearDown(c.dispose);
    c.messages = List.generate(30, (i) => {"role": "assistant", "text": "ب" * 4000});
    final total = c.buildChatHistory().fold<int>(0, (n, m) => n + m["content"]!.length);
    expect(total, lessThanOrEqualTo(
        ChatController.historyLastN * (ChatController.historyMaxCharsPerMessage + 1)));
  });
}
