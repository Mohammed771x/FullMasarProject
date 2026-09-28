// ══════════════════════════════════════════════════
// 📝 وزاري الرياضيات — لكل محادثةٍ سنتُها ودرسُها وأسئلتُها
// ══════════════════════════════════════════════════
//
// 🎯 **أمرُ المالك (٢٠٢٦-٠٩-٢٧):** بعد وصول الأسئلة يسأل «السؤال رقم ثلاثة
//    ممكن توضّحه لي» ⇒ يذهب للموديل آخرُ ست رسائل والدرسُ والسؤال. «وما يقدر
//    الطالب بعد ما يجيب الأسئلة يغيّر الدرس… ولو رجع بعدين على المحادثة
//    يوجد نفس الدرس».
//
// ⚠️ `test` لا `testWidgets`: الحفظُ يكتب في Hive ([masar-testing-traps]).
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/ask_stream.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/tutor_content_repository.dart';
import 'package:ye_student_tutor/features/chat/data/wazari_context.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

const _year = "2024";
const _lessonA = "القيم القصوى (تزايد وتناقص الدالة والنقط الحرجة)";
const _lessonB = "مبرهنة رول";

/// ردُّ الخادم على الجلب كما يكتبه `handle_math_exams` حرفاً بحرف.
String _fetchReply(int from, int to) {
  final b = StringBuffer(
    from == 1
        ? "✅ وجدت 10 سؤالاً\n📋 عرض ${to - from + 1} سؤال:\n\n"
        : "📋 الأسئلة الإضافية:\n\n",
  );
  for (var i = from; i <= to; i++) {
    b.write("\n📌 السؤال $i:\nأوجد المشتقة\n💡 الإجابة:\nص = ٢س\n━━━\n");
  }
  return b.toString();
}

/// يلتقط جسمَ كل طلب، ويردّ على الجلب بأسئلةٍ مرقّمة وعلى غيره بجواب.
class _Server extends http.BaseClient {
  final List<Map<String, dynamic>> bodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body =
        jsonDecode((request as http.Request).body) as Map<String, dynamic>;
    bodies.add(body);
    final content = (body["content"] ?? "").toString();
    final parts = content.split('|');
    final answer = parts.length == 3
        ? _fetchReply(1, int.parse(parts[2]))
        : content == "كمل"
        ? _fetchReply((body["exam_shown"] as int) + 1, 10)
        : "شرحُ السؤال";
    final done = jsonEncode({
      "t": "done",
      "answer": answer,
      "references": <String>[],
    });
    return http.StreamedResponse(
      Stream.value(utf8.encode('data: $done\n\n')),
      200,
      request: request,
    );
  }
}

class _Content extends TutorContentRepository {
  @override
  Future<List<String>> getMathExamYears(String b, int g, String t) async => [
    _year,
    "2018",
  ];

  @override
  Future<List<String>> getMathExamLessons(
    String b,
    String y,
    int g,
    String t,
  ) async => [_lessonA, _lessonB];

  @override
  Future<List<String>> getMathLessons(String b, int g, String t) async => [
    _lessonA,
    _lessonB,
  ];
}

ChatController _wazari(_Server server) =>
    ChatController(askStream: AskStream(server), contentRepository: _Content())
      ..selectedSubject = "رياضيات"
      ..selectedMathBranch = "تفاضل"
      ..mathMode = "وزاري"
      ..selectedMode = "وزاري"
      ..selectedMathExamYear = _year
      ..selectedMathExamLesson = _lessonA
      ..currentConversationId = "conv-w";

Future<void> _fetch(ChatController c, {int count = 4}) => c.processRequest(
  customText: "${c.selectedMathExamYear}|${c.selectedMathExamLesson}|$count",
);

Future<void> _ask(ChatController c, String text) {
  c.inputController.text = text;
  return c.processRequest();
}

void main() {
  late Directory dir;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('masar_0927');
    await ChatStorage.initForTests(dir.path);
  });

  // ══════════════════════════════════════════════════
  group('🔢 عدُّ المعروض من الرسائل', () {
    test('ردودُ الجلب وحدها تُعدّ — وأكبرُ رقمٍ لا عددُ العلامات', () {
      final msgs = <Map<String, dynamic>>[
        {"role": "user", "text": "جلب أسئلة وزاري: $_lessonA ($_year)"},
        {"role": "ai", "text": _fetchReply(1, 4)},
        {"role": "user", "text": "وضح السؤال ٣"},
        // شرحُ الموديل يذكر «📌 السؤال 9» — ليس جلباً فلا يُعدّ.
        {"role": "ai", "text": "📌 السؤال 9: شرح"},
      ];
      expect(wazariShownIn(msgs), 4);
      msgs.add({"role": "ai", "text": _fetchReply(5, 7)});
      expect(wazariShownIn(msgs), 7);
      msgs.add({"role": "ai", "text": _fetchReply(1, 2)}); // جلبٌ أقلّ
      expect(wazariShownIn(msgs), 7, reason: 'المعروضُ ما زال سبعة');
    });

    test('الأرقامُ العربية تُقرأ كالغربية', () {
      expect(
        wazariShownIn([
          {"role": "ai", "text": "✅ وجدت\n📌 السؤال ١٢:\nس"},
        ]),
        12,
      );
    });

    test('🕰️ السنةُ من فقاعة الجلب — ودرسٌ في اسمه أقواس', () {
      expect(
        wazariFetchIn([
          {"role": "user", "text": "جلب أسئلة وزاري: $_lessonA ($_year)"},
          {"role": "ai", "text": "…"},
        ]),
        (_year, _lessonA),
      );
      expect(
        wazariFetchIn([
          {"role": "user", "text": "مرحبا"},
        ]),
        isNull,
      );
    });
  });

  // ══════════════════════════════════════════════════
  group('📤 ما يُرسل', () {
    test('المتابعةُ تحمل سنةَ المحادثة ودرسَها وعددَ المعروض', () async {
      final server = _Server();
      final c = _wazari(server);
      addTearDown(c.dispose);

      expect(c.sendBlocker, contains("جلب الأسئلة"), reason: 'لا أسئلةَ بعد');
      await _fetch(c);
      expect(c.mathWazariShown, 4);
      expect(c.sendBlocker, isNull);

      await _ask(c, "السؤال رقم ٣ ممكن توضحه لي؟");
      final follow = server.bodies.last;
      expect(follow["content"], "السؤال رقم ٣ ممكن توضحه لي؟");
      expect(follow["mode"], "وزاري");
      expect(follow["unit_name"], "تفاضل");
      expect(follow["lesson_name"], _lessonA);
      expect(follow["exam_year"], _year);
      expect(follow["exam_shown"], 4);
      final history = (follow["chat_history"] as List).cast<Map>();
      expect(history.length, lessThanOrEqualTo(6));
      expect(
        history.any((m) => m["role"] == "assistant"),
        isTrue,
        reason: 'ردُّ الجلب في السجلّ بدوره الصحيح',
      );
    });

    test('«كمل» تحمل العددَ فيكمل الخادمُ من بعده', () async {
      final server = _Server();
      final c = _wazari(server);
      addTearDown(c.dispose);
      await _fetch(c);
      await c.processRequest(customText: "كمل");
      expect(server.bodies.last["exam_shown"], 4);
      expect(c.mathWazariShown, 10);
    });

    test(
      '☢️ محادثةٌ جديدة بلا جلب ⇒ لا كتابة (كان العلَمُ يبقى مضاءً)',
      () async {
        final c = _wazari(_Server());
        addTearDown(c.dispose);
        await _fetch(c);
        await c.createNewConversation();
        expect(c.wazariLesson, isEmpty);
        expect(c.sendBlocker, contains("جلب الأسئلة"));
      },
    );
  });

  // ══════════════════════════════════════════════════
  group('🔒 الدرسُ مقفلٌ بعد الجلب', () {
    test('درسٌ آخر ⇒ السؤال، و«ابقَ» لا يمسّ شيئاً', () async {
      final c = _wazari(_Server());
      addTearDown(c.dispose);
      await _fetch(c);
      final id = c.currentConversationId;
      var asked = 0;
      c.onConfirmNewConversation = (_) async {
        asked++;
        return false;
      };
      await c.pickMathExamLesson(_lessonB);
      await c.pickMathExamYear("2018");
      expect(asked, 2);
      expect(c.selectedMathExamLesson, _lessonA);
      expect(c.selectedMathExamYear, _year);
      expect(c.currentConversationId, id);
      expect(c.wazariLesson, _lessonA);
    });

    test('«محادثة جديدة» ⇒ الدرسُ الجديد في محادثةٍ فارغة', () async {
      final c = _wazari(_Server());
      addTearDown(c.dispose);
      await _fetch(c);
      final id = c.currentConversationId;
      c.onConfirmNewConversation = (_) async => true;
      await c.pickMathExamLesson(_lessonB);
      expect(c.currentConversationId, isNot(id));
      expect(c.messages, isEmpty);
      expect(c.selectedMathExamLesson, _lessonB);
      expect(c.sendBlocker, contains("جلب الأسئلة"));
    });

    test('نفسُ الدرس، أو قبل أيّ جلب ⇒ بلا سؤال', () async {
      final c = _wazari(_Server());
      addTearDown(c.dispose);
      c.onConfirmNewConversation = (_) async => fail('لا سؤال قبل الجلب');
      await c.pickMathExamLesson(_lessonB);
      expect(c.selectedMathExamLesson, _lessonB);
      await c.pickMathExamLesson(_lessonA);
      await _fetch(c);
      await c.pickMathExamLesson(_lessonA); // هو نفسُه
    });
  });

  // ══════════════════════════════════════════════════
  group('🧭 الرجوعُ إلى المحادثة', () {
    test('تعود بسنتها ودرسها — ولو كانت الشاشةُ على غيرهما', () async {
      final server = _Server();
      final c = _wazari(server);
      addTearDown(c.dispose);
      await _fetch(c);
      final saved = ChatStorage.getOwnedConversation(
        c.currentConversationId!,
        c.ownerUid,
      )!;
      expect(saved.unit, _year, reason: 'سنةُ الوزاري في `unit`');
      expect(saved.lesson, _lessonA);

      // انتقل إلى محادثةٍ أخرى بدرسٍ آخر ثم عاد.
      await c.createNewConversation();
      c
        ..selectedMathExamYear = "2018"
        ..selectedMathExamLesson = _lessonB;
      await c.loadConversation(saved);
      await Future<void>.delayed(Duration.zero);
      expect(c.wazariYear, _year);
      expect(c.wazariLesson, _lessonA);
      expect(c.selectedMathExamYear, _year);
      expect(c.selectedMathExamLesson, _lessonA);
      expect(c.sendBlocker, isNull, reason: 'أسئلتُها في رسائلها');

      await _ask(c, "وضح السؤال ٢");
      expect(server.bodies.last["lesson_name"], _lessonA);
      expect(server.bodies.last["exam_year"], _year);
      expect(server.bodies.last["exam_shown"], 4);
    });

    test('🕰️ محادثةٌ قديمة بلا سنةٍ محفوظة تعود من فقاعة جلبها', () async {
      final server = _Server();
      final c = _wazari(server);
      addTearDown(c.dispose);
      await c.loadConversation(
        ChatConversation(
          id: "legacy",
          title: "قديمة",
          subject: "رياضيات",
          mode: "وزاري",
          branch: "تفاضل",
          lesson: _lessonA,
          messages: [
            ChatMessage(
              role: "user",
              text: "جلب أسئلة وزاري: $_lessonA ($_year)",
              timestamp: DateTime(2026),
            ),
            ChatMessage(
              role: "ai",
              text: _fetchReply(1, 5),
              timestamp: DateTime(2026),
            ),
          ],
        ),
      );
      expect(c.wazariYear, _year);
      await _ask(c, "وضح السؤال ٥");
      expect(server.bodies.last["exam_year"], _year);
      expect(server.bodies.last["exam_shown"], 5);
    });
  });
}
