// سياسة سياق المحادثة: آخر 6 رسائل، **كلٌّ كاملةً بلا قصّ**.
// الباك يستخدم آخر 6 في كل مادة — إرسال 10 كان يهدر حجم الطلب بلا فائدة.
//
// 🔄 **انقلب القصّ (2026-09-14 — قرار المالك):** كان كلُّ رسالةٍ تُقصّ عند
//    ١٥٠٠ حرف. وردُّ شرحٍ كامل يبلغ ٨ آلاف، فكان الموديل يرى **مقدّمة
//    الشرح وحدها**: يسأل الطالب «وضّح الخطوة السابعة» وهو لم يرَ إلا
//    الأولى والثانية، فيخترعها أو يعتذر. والجدارُ الوحيد الباقي دفاعيٌّ
//    على الخادم (`HISTORY_MAX_CHARS = 32000`) لا يمسّ محتوىً حقيقياً.
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

  test('⭐ الرسالة الطويلة تُرسل كاملةً — لا بدايتها', () {
    final c = ChatController();
    addTearDown(c.dispose);
    final long = "أ" * 20000;      // رقم المالك نفسه: «حتى كانت ٢٠ ألف حرف»
    c.messages = [
      {"role": "assistant", "text": long},
    ];

    final only = c.buildChatHistory().single["content"]!;
    expect(only.length, 20000, reason: 'قُصّت رسالةٌ كان يجب أن تمرّ كاملة');
    expect(only.endsWith("…"), isFalse, reason: 'علامةُ قصٍّ لم يعد لها موضع');
  });

  test('ونصّ الصورة يبقى ملتصقاً بها كاملاً كذلك', () {
    final c = ChatController();
    addTearDown(c.dispose);
    c.messages = [
      {"role": "user", "text": "ما هذا؟", "imageText": "[محتوى صورة: ${"س" * 3000}]"},
    ];
    final only = c.buildChatHistory().single["content"]!;
    expect(only, startsWith("ما هذا؟"));
    expect(only.length, greaterThan(3000));
  });

  test('الدور يُحفظ كما هو', () {
    final c = _withMessages(2);
    addTearDown(c.dispose);
    final h = c.buildChatHistory();
    expect(h[0]["role"], "user");
    expect(h[1]["role"], "assistant");
  });

  test('⭐ ولا سقفَ على الحجم — ستُّ رسائلٍ كاملة مهما طالت', () {
    final c = ChatController();
    addTearDown(c.dispose);
    c.messages = List.generate(30, (i) => {"role": "assistant", "text": "ب" * 8000});
    final h = c.buildChatHistory();
    expect(h.length, ChatController.historyLastN);
    final total = h.fold<int>(0, (n, m) => n + m["content"]!.length);
    expect(total, ChatController.historyLastN * 8000,
        reason: 'العددُ وحده يحدّ السياق الآن، لا طولُ الرسالة');
  });

  // ══════════════════════════════════════════════════
  // 🚫 دورُ الرفض لا يدخل السجلَّ الذاهبَ للموديل
  // ══════════════════════════════════════════════════
  //
  // 🔴 **رُئي حرفياً في المحاكي (2026-09-14):** سؤالٌ عن قانون نيوتن رُفض
  //    («ليس في وحدتك»)، ثم سأل الطالب عن الغدة النخامية — فجاء الجواب
  //    صحيحاً **ثم اعتذر عن قانون نيوتن**. الموديل رأى في السجلّ سؤالاً
  //    بلا جواب فحاول إكماله.

  ChatController withTurns(List<Map<String, dynamic>> turns) {
    final c = ChatController();
    c.messages = turns;
    return c;
  }

  test('🚫 الرفضُ وسؤالُه يسقطان من السجلّ', () {
    final c = withTurns([
      {"role": "user", "text": "عرف الغدة النخامية"},
      {"role": "assistant", "text": "الغدة النخامية هي..."},
      {"role": "user", "text": "ما هو قانون نيوتن الثاني؟"},
      {"role": "ai", "text": "لم أجد في وحدتك...", "offTopic": true},
    ]);
    addTearDown(c.dispose);
    final h = c.buildChatHistory();

    expect(h.length, 2, reason: "بقي دورُ الرفض في السجلّ");
    expect(h.every((m) => !m["content"]!.contains("نيوتن")), isTrue,
        reason: "سؤالُ الرفض ما زال معلّقاً بلا جواب");
    expect(h.first["content"], "عرف الغدة النخامية");
  });

  test('والرفضُ يبقى معروضاً للطالب على الشاشة', () {
    final c = withTurns([
      {"role": "user", "text": "سؤال دخيل"},
      {"role": "ai", "text": "لم أجد في وحدتك...", "offTopic": true},
    ]);
    addTearDown(c.dispose);
    expect(c.buildChatHistory(), isEmpty);
    expect(c.messages.length, 2, reason: "حُذف من الشاشة لا من السجلّ فقط");
  });

  test('رسالةٌ عادية لا تُحذف بالخطأ', () {
    final c = withTurns([
      {"role": "user", "text": "سؤال"},
      {"role": "ai", "text": "جواب"},
    ]);
    addTearDown(c.dispose);
    expect(c.buildChatHistory().length, 2);
  });

  // ══════════════════════════════════════════════════
  // ☢️ الدور "ai" — العطبُ الذي أبطل السياق كلَّه
  // ══════════════════════════════════════════════════
  //
  // 🔴 التطبيق يخزّن ردَّ المساعد بـ`"role": "ai"` (ثلاثةُ مواضع في
  //    `chat_controller`)، والخادمُ يُصفّي في كل معالجٍ
  //    `role in ("user", "assistant")` — فكانت **ردودُ المساعد كلُّها
  //    تُحذف** قبل أن تصل الموديل. فيرى ستَّ رسائلَ من الطالب بلا جوابٍ
  //    بينها، فيحاول الإجابة عنها كلِّها ويبدأ الشرحَ من أوّله في كل ردّ.
  //
  // ⚠️ **ولماذا لم يكشفه اختبارٌ حتى اليوم؟** لأن مساعدَ الاختبار أعلاه
  //    يكتب `"role": "assistant"` بيده — وهو ما لا يفعله التطبيق أبداً.
  //    فكان الاختبارُ يقيس عالماً غير الذي يعيشه الطالب. والمساعدُ أدناه
  //    يكتب "ai" كما يكتبها التطبيق فعلاً.

  ChatController withAiRoles(int count) {
    final c = ChatController();
    c.messages = List.generate(count, (i) => {
          "role": i.isEven ? "user" : "ai",
          "text": "رسالة رقم $i",
        });
    return c;
  }

  test('☢️ الدور "ai" يُرسل "assistant" — وإلا حُذف جوابُ المساعد كلُّه', () {
    final c = withAiRoles(4);
    addTearDown(c.dispose);
    final h = c.buildChatHistory();

    expect(h.map((m) => m["role"]).toList(),
        ["user", "assistant", "user", "assistant"]);
    expect(h.any((m) => m["role"] == "ai"), isFalse);
  });

  test('دورُ الطالب لا يتغيّر', () {
    final c = withAiRoles(1);
    addTearDown(c.dispose);
    expect(c.buildChatHistory().single["role"], "user");
  });

  test('دورٌ مجهول يبقى كما هو — لا نرقّيه إلى جوابِ مساعد', () {
    final c = ChatController();
    addTearDown(c.dispose);
    c.messages = [
      {"role": "نظام", "text": "شيء"},
    ];
    expect(c.buildChatHistory().single["role"], "نظام");
  });

  test('والمحتوى يبقى كاملاً بعد تبديل الدور', () {
    final c = ChatController();
    addTearDown(c.dispose);
    c.messages = [
      {"role": "ai", "text": "ج" * 5000},
    ];
    final only = c.buildChatHistory().single;
    expect(only["role"], "assistant");
    expect(only["content"]!.length, 5000);
  });
}
