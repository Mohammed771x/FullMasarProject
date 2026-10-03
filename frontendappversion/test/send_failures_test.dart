// 🧯 أعطالُ إرسال السؤال، وما يبقى من المحادثة إن غادر الطالبُ أثناء البثّ.
//
// 🔴 **ما قيس في فحص ٢٠٢٦-١٠-٠٢ (بخادمٍ وسيطٍ يحقن الأعطال):**
//    ① انقطاعُ النت و٤٠١ و٤٠٣ و٥٠٠ كلُّها «حدث خطأ غير متوقع» بلا زرّ إعادة.
//    ② ردودُ الخادم المرفوضة (٤٠٣ · ٤٢٩ · ٥٠٠ بحقل `answer`) تُعرض جواباً
//       عادياً من الموديل، ويُخصم بها العدّاد.
//    ③ فقاعةُ العطل تدخل سجلَّ المحادثة المرسَل للموديل ردّاً منه.
//    ④ `done` بنصٍّ فارغ يُرسم فقاعةً فارغةً بزرّي «نسخ» و«حفظ».
//    ⑤ قتلُ التطبيق أثناء البثّ يمحو السؤالَ والجوابَ معاً من المخزن.
//    ⑥ الجوابُ المقطوع يُحفظ ويعود بلا أي علامةٍ أنه غير مكتمل.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:ye_student_tutor/core/error/error_messages.dart';
import 'package:ye_student_tutor/core/quota/quota_repository.dart';
import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/ask_stream.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

/// ردٌّ مُبرمَج واحد لكل طلب — حالةٌ وجسم، أو بثٌّ، أو انقطاعُ شبكة.
class _Reply {
  const _Reply.status(this.status, [this.body = const {}])
      : deltas = const [],
        done = null,
        offline = false,
        hang = false;
  const _Reply.stream(this.deltas, {this.done, this.hang = false})
      : status = 200,
        body = const {},
        offline = false;
  const _Reply.offline()
      : status = 0,
        body = const {},
        deltas = const [],
        done = null,
        offline = true,
        hang = false;

  final int status;
  final Map<String, dynamic> body;
  final List<String> deltas;
  final String? done;
  final bool offline;

  /// يبقى البثُّ مفتوحاً بعد الأجزاء — طلبٌ «جارٍ» يُقتل فيه التطبيق.
  final bool hang;
}

class _ScriptedClient extends http.BaseClient {
  _ScriptedClient(this.replies);

  final List<_Reply> replies;
  int sent = 0;
  final List<Map<String, dynamic>> bodies = [];
  final Completer<void> _release = Completer<void>();

  /// أوّلُ جزءٍ وصل التطبيق — لحظةُ «البثّ جارٍ».
  final Completer<void> firstDelta = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    bodies.add(
        jsonDecode((request as http.Request).body) as Map<String, dynamic>);
    final r = replies[sent < replies.length ? sent : replies.length - 1];
    sent++;
    if (r.offline) throw const SocketException("لا شبكة");
    if (r.status != 200) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(r.body))),
        r.status,
        request: request,
      );
    }
    Stream<List<int>> body() async* {
      for (final d in r.deltas) {
        yield utf8.encode('data: ${jsonEncode({"t": "delta", "v": d})}\n\n');
      }
      if (!firstDelta.isCompleted) firstDelta.complete();
      if (r.hang) await _release.future;
      if (r.done != null) {
        yield utf8.encode(
            'data: ${jsonEncode({"t": "done", "answer": r.done, "references": <String>[]})}\n\n');
      }
    }

    return http.StreamedResponse(body(), 200, request: request);
  }

  @override
  void close() {
    if (!_release.isCompleted) _release.complete();
  }
}

ChatController _controller(_ScriptedClient client) => ChatController(
      askStream: AskStream(client),
    )
      ..selectedSubject = "احياء"
      ..selectedMode = "سؤال"
      ..selectedUnit = "الجهاز العصبي";

/// يرسل [text] وينتظر نهاية الدورة كاملة.
Future<void> _send(ChatController c, String text) async {
  c.inputController.text = text;
  await c.processRequest();
}

const _known = QuotaStatus(
  limit: 10,
  used: 0,
  remaining: 10,
  isGuest: false,
  resetsDaily: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('send_failures');
    await ChatStorage.initForTests(dir.path);
  });
  setUp(() async {
    await ChatStorage.clearAll();
    QuotaRepository.I.status = _known;
  });
  tearDownAll(() async {
    try {
      await dir.delete(recursive: true);
    } catch (_) {}
  });

  // ══════════════════════════════════════════════════
  // 🏷️ التصنيف بالحالة لا بالنصّ
  // ══════════════════════════════════════════════════
  group('🏷️ askKindForStatus', () {
    test('كلُّ حالةٍ إلى نوعها', () {
      expect(askKindForStatus(401, null), AskErrorKind.unauthorized);
      expect(askKindForStatus(403, null), AskErrorKind.forbidden);
      expect(askKindForStatus(429, {"quota_exceeded": true}),
          AskErrorKind.quota);
      expect(askKindForStatus(429, {"answer": "⏳"}), AskErrorKind.rateLimited);
      expect(askKindForStatus(413, null), AskErrorKind.tooLarge);
      expect(askKindForStatus(422, null), AskErrorKind.tooLarge);
      expect(askKindForStatus(404, null), AskErrorKind.notFound);
      expect(askKindForStatus(500, null), AskErrorKind.server);
      expect(askKindForStatus(503, null), AskErrorKind.server);
      expect(askKindForStatus(400, null), AskErrorKind.badRequest);
    });

    test('🔤 نصُّ الخادم التقنيّ لا يُعرض («content» اللاتينية)', () {
      expect(
        ErrorMessages.forAskError(
            AskErrorKind.tooLarge, "❌ «content» أطول من المسموح"),
        ErrorMessages.askTooLarge,
      );
      // ورسالةُ الحظر العربية تُعرض كما هي — فيها سببٌ لا يعرفه التطبيق.
      expect(
        ErrorMessages.forAskError(AskErrorKind.forbidden, "⛔ حسابك موقوف."),
        "⛔ حسابك موقوف.",
      );
    });
  });

  // ══════════════════════════════════════════════════
  // ① ② كلُّ عطلٍ برسالته وزرّه — ولا جوابَ موديلٍ مزيّف ولا خصم
  // ══════════════════════════════════════════════════
  group('🧯 فقاعةُ العطل', () {
    // (الوصف · الردود · الرسالة المتوقّعة · إعادة؟ · عددُ الطلبات)
    final cases = <(String, List<_Reply>, String, bool, int)>[
      (
        '📡 انقطاعُ الإنترنت ⇒ «تعذّر الاتصال» + إعادة (ومحاولةٌ تلقائية واحدة)',
        const [_Reply.offline()],
        ErrorMessages.askNoConnection,
        true,
        2,
      ),
      (
        '🔐 401 ⇒ توكنٌ جديد ومحاولةٌ صامتة، ثم «انتهت جلستك»',
        const [
          _Reply.status(401, {"answer": "⛔ الرجاء تسجيل الدخول أولاً."})
        ],
        ErrorMessages.askUnauthorized,
        true,
        2,
      ),
      (
        '⛔ 403 ⇒ رسالةُ الخادم العربية، بلا إعادة ولا محاولةٍ ثانية',
        const [
          _Reply.status(403, {"answer": "⛔ هذا القسم مقفل حالياً."})
        ],
        "⛔ هذا القسم مقفل حالياً.",
        false,
        1,
      ),
      (
        '⏳ 429 إبطاء ⇒ رسالةُ الخادم + إعادة، بلا محاولةٍ تلقائية',
        const [
          _Reply.status(429, {"answer": "⏳ أرسلت كثيراً، انتظر دقيقة."})
        ],
        "⏳ أرسلت كثيراً، انتظر دقيقة.",
        true,
        1,
      ),
      (
        '🛠️ 500 بـ`answer` ⇒ عطلُ خادم لا جواب، ومحاولةٌ تلقائية واحدة',
        const [
          _Reply.status(500, {"answer": "⚠️ عذراً، حدث ضغط مفاجئ…"})
        ],
        ErrorMessages.askServer,
        true,
        2,
      ),
      (
        '🛠️ 404 (خادمٌ قديم) ⇒ «الخدمة غير متاحة»',
        const [_Reply.status(404, {"detail": "Not Found"})],
        ErrorMessages.askNotFound,
        true,
        1,
      ),
    ];

    for (final (name, replies, message, retry, requests) in cases) {
      test(name, () async {
        final client = _ScriptedClient(replies);
        final c = _controller(client);
        await _send(c, "ما الغدة النخامية؟");

        expect(c.messages, hasLength(2), reason: "سؤالٌ وفقاعةُ عطلٍ لا غير");
        final last = c.messages.last;
        expect(last["isError"], isTrue,
            reason: "ردُّ الخادم المرفوض عُرض جواباً عادياً");
        expect(last["text"], message);
        expect(last["canRetry"], retry);
        expect(client.sent, requests);
        expect(QuotaRepository.I.status.remaining, 10,
            reason: "خُصم من العدّاد لطلبٍ فشل");
        expect(c.isBusy, isFalse, reason: "زرّ الإرسال بقي مقفولاً");
      });
    }

    test('🎟️ 429 الحصة ⇒ يُبلَّغ بنفادها ولا يُخصم، والرسالةُ رسالةُ الخادم',
        () async {
      final client = _ScriptedClient(const [
        _Reply.status(429, {
          "answer": "🎟️ انتهت أسئلتك اليوم، تتجدّد غداً.",
          "quota_exceeded": true,
          "is_guest": true,
        })
      ]);
      final c = _controller(client);
      bool? guest;
      c.onQuotaExceeded = (g) => guest = g;
      await _send(c, "سؤال");

      expect(c.messages.last["isError"], isTrue);
      expect(c.messages.last["text"], "🎟️ انتهت أسئلتك اليوم، تتجدّد غداً.");
      expect(c.messages.last["canRetry"], isFalse);
      expect(guest, isTrue);
      expect(client.sent, 1);
      expect(QuotaRepository.I.status.remaining, 10);
    });

    test('✅ والنجاحُ وحده يُخصم — مرةً واحدة', () async {
      final c = _controller(
          _ScriptedClient(const [_Reply.stream(["جو"], done: "جواب")]));
      await _send(c, "سؤال");
      expect(c.messages.last["isError"], isNot(true));
      expect(c.messages.last["text"], "جواب");
      expect(QuotaRepository.I.status.remaining, 9);
    });
  });

  // ══════════════════════════════════════════════════
  // ③ رسائلُ العطل لا تصل الموديل
  // ══════════════════════════════════════════════════
  group('🚫 سجلُّ الموديل', () {
    test('العطلُ وسؤالُه خارج السجلّ — والسؤالُ التالي يصل بسياقٍ نظيف',
        () async {
      final client = _ScriptedClient(const [
        _Reply.status(500, {"answer": "⚠️ ضغط"}),
        _Reply.status(500, {"answer": "⚠️ ضغط"}),
        _Reply.stream(["ب"], done: "الجواب الثاني"),
      ]);
      final c = _controller(client);
      await _send(c, "السؤال الأول");
      expect(c.messages.last["isError"], isTrue);
      expect(c.buildChatHistory(), isEmpty);

      await _send(c, "السؤال الثاني");
      final sentHistory =
          (client.bodies.last["chat_history"] as List).cast<Map>();
      final contents = sentHistory.map((m) => m["content"]).toList();
      expect(contents.any((t) => t.toString().contains("ضغط")), isFalse,
          reason: "رسالةُ العطل وصلت الموديل ردّاً منه");
      expect(contents.contains("السؤال الأول"), isFalse,
          reason: "سؤالٌ بلا جواب يبقى معلّقاً فيجيب عنه الموديل من جديد");
    });

    test('💾 وبعد إعادة فتح المحادثة يبقى العطلُ عطلاً', () async {
      final c = _controller(_ScriptedClient(const [_Reply.offline()]));
      await _send(c, "سؤال");
      final saved = ChatStorage.getConversation(c.currentConversationId!)!;
      expect(saved.messages.last.status, ChatMessage.statusError);

      final reopened = _controller(_ScriptedClient(const [_Reply.offline()]));
      await reopened.loadConversation(saved);
      expect(reopened.messages.last["isError"], isTrue);
      expect(reopened.buildChatHistory(), isEmpty);
    });
  });

  // ══════════════════════════════════════════════════
  // 🔁 «أعد المحاولة»
  // ══════════════════════════════════════════════════
  test('🔁 «أعد المحاولة» يرسل السؤالَ نفسَه ويستبدل فقاعةَ العطل بالجواب',
      () async {
    final client = _ScriptedClient(const [
      _Reply.offline(),
      _Reply.offline(),
      _Reply.stream(["جـ"], done: "الجواب الصحيح"),
    ]);
    final c = _controller(client);
    await _send(c, "ما الغدة النخامية؟");
    expect(c.messages.last["isError"], isTrue);

    await c.retryFailed();
    expect(c.messages, hasLength(2));
    expect(c.messages.first["text"], "ما الغدة النخامية؟");
    expect(c.messages.last["text"], "الجواب الصحيح");
    expect(c.messages.any((m) => m["isError"] == true), isFalse);
    expect(client.bodies.last["content"], "ما الغدة النخامية؟");
    expect(QuotaRepository.I.status.remaining, 9);
  });

  // ══════════════════════════════════════════════════
  // ④ الجوابُ الفارغ
  // ══════════════════════════════════════════════════
  test('🤔 `done` فارغ ⇒ فقاعةُ عطلٍ بإعادة، لا فقاعةٌ فارغة ولا خصم', () async {
    final c = _controller(_ScriptedClient(const [_Reply.stream([], done: "")]));
    await _send(c, "سؤال");
    expect(c.messages, hasLength(2));
    expect(c.messages.last["isError"], isTrue);
    expect(c.messages.last["text"], ErrorMessages.askEmpty);
    expect(c.messages.last["canRetry"], isTrue);
    expect(QuotaRepository.I.status.remaining, 10);
  });

  test('⚖️ `done` فارغ بعد نصٍّ مبثوث ⇒ يُعتمد المبثوث', () async {
    final c = _controller(
        _ScriptedClient(const [_Reply.stream(["نصٌّ ", "وصل"], done: "")]));
    await _send(c, "سؤال");
    expect(c.messages.last["isError"], isNot(true));
    expect(c.messages.last["text"], "نصٌّ وصل");
  });

  // ══════════════════════════════════════════════════
  // ⑤ ⑥ إغلاقُ التطبيق أثناء البثّ
  // ══════════════════════════════════════════════════
  group('💾 مغادرةُ التطبيق أثناء البثّ', () {
    Future<(ChatController, _ScriptedClient, Future<void>)> streaming() async {
      final client = _ScriptedClient(const [
        _Reply.stream(["جزءٌ أوّل ", "وجزءٌ ثانٍ"], hang: true),
      ]);
      final c = _controller(client);
      c.inputController.text = "سؤال لا يجوز أن يضيع";
      final pending = c.processRequest();
      await client.firstDelta.future;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      return (c, client, pending);
    }

    test('📝 السؤالُ على القرص قبل وصول أي جواب', () async {
      final (c, client, pending) = await streaming();
      final saved = ChatStorage.getConversation(c.currentConversationId!)!;
      expect(saved.messages.first.text, "سؤال لا يجوز أن يضيع");
      client.close();
      await pending;
    });

    test('📱 الانتقالُ للخلفية ⇒ ما وصل يُحفظ «غير مكتمل» (ويُقتل بعدها)',
        () async {
      final (c, client, pending) = await streaming();
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // ☠️ قتلٌ بلا إنذار: لا `dispose` ولا نهايةَ للطلب — المخزنُ وحده باقٍ.
      final saved = ChatStorage.getConversation(c.currentConversationId!)!;
      expect(saved.messages, hasLength(2));
      expect(saved.messages.first.text, "سؤال لا يجوز أن يضيع");
      expect(saved.messages.last.text, "جزءٌ أوّل وجزءٌ ثانٍ");
      expect(saved.messages.last.status, ChatMessage.statusPartial);

      // وحين يعود الطالب: الجوابُ موسومٌ «غير مكتمل».
      final reopened = _controller(_ScriptedClient(const [_Reply.offline()]));
      await reopened.loadConversation(saved);
      expect(reopened.messages.last["partial"], isTrue);
      client.close();
      await pending;
    });

    test(
        '☠️ قتلٌ بلا إنذار (SIGKILL) والبثُّ متجمّد ⇒ لقطةٌ مؤجَّلة حفظت الجزء',
        () async {
      // 🔴 رُئي في المحاكي: جزءٌ ثم تجمّدٌ قبل مضيّ مدة اللقطة ثم قتل —
      //    فلا جزءَ لاحق ينادي اللقطة. لا حدثَ دورةِ حياة هنا عمداً.
      final (c, client, pending) = await streaming();
      await Future<void>.delayed(
          ChatController.snapshotEvery + const Duration(milliseconds: 400));
      final saved = ChatStorage.getConversation(c.currentConversationId!)!;
      expect(saved.messages, hasLength(2));
      expect(saved.messages.last.text, "جزءٌ أوّل وجزءٌ ثانٍ");
      expect(saved.messages.last.status, ChatMessage.statusPartial);
      client.close();
      await pending;
    });

    test('✅ وإن اكتمل البثُّ بعد العودة ⇒ يُكتب فوقه كاملاً بلا وسم',
        () async {
      final client = _ScriptedClient(const [
        _Reply.stream(["جزء"], done: "الجواب الكامل", hang: true),
      ]);
      final c = _controller(client);
      c.inputController.text = "سؤال";
      final pending = c.processRequest();
      await client.firstDelta.future;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      c.didChangeAppLifecycleState(AppLifecycleState.paused);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      client.close(); // يعود فيكتمل
      await pending;

      final saved = ChatStorage.getConversation(c.currentConversationId!)!;
      expect(saved.messages.last.text, "الجواب الكامل");
      expect(saved.messages.last.status, "");
    });

    test('↩️ الرجوعُ للخلف أثناء البثّ ⇒ الجزءُ يُحفظ موسوماً «غير مكتمل»',
        () async {
      final (c, client, pending) = await streaming();
      final id = c.currentConversationId!;
      c.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final saved = ChatStorage.getConversation(id)!;
      expect(saved.messages.last.text, "جزءٌ أوّل وجزءٌ ثانٍ");
      expect(saved.messages.last.status, ChatMessage.statusPartial);
      client.close();
      await pending;
    });

    test('📡 انقطاعٌ بعد جزءٍ ⇒ يبقى النصُّ موسوماً «غير مكتمل»', () async {
      final c =
          _controller(_ScriptedClient(const [_Reply.stream(["نصٌّ وصل"])]));
      await _send(c, "سؤال");
      expect(c.messages.last["partial"], isTrue);
      expect(c.messages.last["isError"], isNot(true));
      final saved = ChatStorage.getConversation(c.currentConversationId!)!;
      expect(saved.messages.last.status, ChatMessage.statusPartial);
    });
  });
}
