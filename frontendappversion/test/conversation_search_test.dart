// 🔎 البحث في المحادثات — التطبيع العربي هو ما يجعله يعمل أو يفشل.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/data/conversation_search.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';

ChatConversation _conv({
  required String id,
  required String title,
  List<String> texts = const [],
  String subject = "كيمياء",
  int grade = 3,
}) =>
    ChatConversation(
      id: id,
      title: title,
      subject: subject,
      mode: "شرح",
      grade: grade,
      track: "علمي",
      messages: [
        for (final t in texts) ChatMessage(role: "user", text: t),
      ],
    );

void main() {
  group('🔤 التطبيع العربي', () {
    test('يوحّد الهمزات والتاء المربوطة والألف المقصورة', () {
      expect(ConversationSearch.normalize("الأكسدة"),
          ConversationSearch.normalize("الاكسده"));
      expect(ConversationSearch.normalize("إعادة"),
          ConversationSearch.normalize("اعاده"));
      expect(ConversationSearch.normalize("مصطفى"),
          ConversationSearch.normalize("مصطفي"));
    });

    test('يُسقط التشكيل والتطويل', () {
      expect(ConversationSearch.normalize("الكِيمياءُ"),
          ConversationSearch.normalize("الكيمياء"));
      expect(ConversationSearch.normalize("مـــسار"),
          ConversationSearch.normalize("مسار"));
    });

    test('يوحّد حالة الأحرف اللاتينية (المصطلحات مختلطة)', () {
      expect(ConversationSearch.normalize("Newton"),
          ConversationSearch.normalize("newton"));
    });
  });

  group('🔎 التصفية', () {
    final convs = [
      _conv(id: "a", title: "شرح درس: الأكسدة والاختزال"),
      _conv(id: "b", title: "محادثة جديدة", texts: ["ما قانون نيوتن الثاني؟"]),
      _conv(id: "c", title: "أسئلة وزاري", texts: ["اشرح لي التناضح"]),
    ];

    test('استعلامٌ فارغ يُرجع القائمة كما هي بلا نسخ ترتيب', () {
      expect(ConversationSearch.filter(convs, "   "), convs);
    });

    test('يطابق العنوان', () {
      final r = ConversationSearch.filter(convs, "الأكسدة");
      expect(r.map((c) => c.id), ["a"]);
    });

    test('🔴 يطابق بلا همزات — «الاكسده» تجد «الأكسدة»', () {
      // هذا هو الفرق بين بحثٍ يعمل وبحثٍ يبدو معطوباً: الطالب يكتب بلا
      // همزٍ ولا تشكيل، والعنوان محفوظٌ بهما.
      final r = ConversationSearch.filter(convs, "الاكسده");
      expect(r.map((c) => c.id), ["a"]);
    });

    test('⭐ يبحث في متن الرسائل لا العنوان وحده', () {
      // العنوان مقتطعٌ من أول سؤال عند ٥٠ حرفاً، والكلمة التي يتذكّرها
      // الطالب غالباً في المتن.
      final r = ConversationSearch.filter(convs, "نيوتن");
      expect(r.map((c) => c.id), ["b"]);
    });

    test('يحافظ على ترتيب القائمة الأصلي', () {
      final r = ConversationSearch.filter(convs, "ا");
      expect(r.map((c) => c.id).toList(), containsAllInOrder(["a", "b", "c"]));
    });

    test('لا نتائج ⇒ قائمة فارغة لا القائمة كاملة', () {
      expect(ConversationSearch.filter(convs, "زئبق"), isEmpty);
    });
  });

  group('📄 المقتطف', () {
    test('يُظهر السياق حول الكلمة', () {
      final c = _conv(
        id: "x",
        title: "محادثة",
        // نصٌّ أطول بكثير من نافذة المقتطف كي يُختبر القصّ فعلاً لا بالصدفة.
        texts: ["${"مقدمة طويلة " * 12}التناضح العكسي${" وكلام بعده" * 12}"],
      );
      final s = ConversationSearch.snippet(c, "التناضح");
      expect(s, contains("التناضح"));
      expect(s.length, lessThan(c.messages.first.text.length));
      expect(s, startsWith("…"));   // قُصَّ من اليسار
      expect(s, endsWith("…"));     // وقُصَّ من اليمين
    });

    test('التطابق في العنوان وحده ⇒ لا مقتطف (لا سطر فارغ في الواجهة)', () {
      final c = _conv(id: "y", title: "الأكسدة", texts: ["كلام لا صلة له"]);
      expect(ConversationSearch.snippet(c, "الأكسدة"), isEmpty);
    });

    test('استعلامٌ فارغ ⇒ لا مقتطف', () {
      final c = _conv(id: "z", title: "ت", texts: ["نص"]);
      expect(ConversationSearch.snippet(c, ""), isEmpty);
    });

    test('🛟 لا ينهار على كلمةٍ في أول النص أو آخره', () {
      final c = _conv(id: "w", title: "ت", texts: ["التناضح"]);
      expect(() => ConversationSearch.snippet(c, "التناضح"), returnsNormally);
    });
  });
}
