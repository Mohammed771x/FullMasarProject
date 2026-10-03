// 🤖 ما وُجد على أندرويد الحقيقي (فحص ٢٠٢٦-١٠-٠٣) — كلُّ عيبٍ هنا رُئي في
//    المحاكي بخادمٍ حقيقيّ ووسيطٍ يحقن الأعطال، لا افتُرض.
//
//    ① رفضُ App Check (401 بـ`app_check_failed`) قُرئ «انتهت جلستك… سجّل
//       الدخول من جديد» بعد تجديد توكنٍ وإعادةٍ بلا فائدة.
//    ② ردُّ JSON بحالة 200 على مسار البثّ (صورةٌ رُفضت · جوابٌ محفوظ لنفس
//       `request_id`) قُرئ انقطاعاً، فأُعيدت الصورةُ تلقائياً وخُصمت مرّتين.
//    ③ النقرةُ المزدوجة على «إرسال» أوقفت الطلبَ فوراً: سؤالٌ بلا جواب.
//    ④ «لم يُخصم سؤالك» وعدٌ لا يملكه التطبيق.
//    ⑤ «اختبر نفسك» يقرأ الحظرَ ورفضَ App Check «تأكد من الإنترنت».
//    ⑥ رجوعُ أندرويد يُغلق التطبيق من الترحيب ومن تبويبات الهيكل، ويُخرج من
//       قسم التعليم وكيبوردُ الرياضيات مفتوح.
//    ⑦ رأسُ المحادثة يفيض عند أكبر خطّ.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ye_student_tutor/core/error/error_messages.dart';
import 'package:ye_student_tutor/core/quota/quota_repository.dart';
import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/core/widgets/text_scale_clamp.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/ask_stream.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/chat/presentation/widgets/chat_app_bar.dart';
import 'package:ye_student_tutor/features/future_masar/presentation/screens/onboarding_screen.dart';
import 'package:ye_student_tutor/features/quiz/data/quiz_repository.dart';

const _appCheckReject =
    "📱 تعذّر التحقق من نسخة التطبيق. حدّث «مسار» من المتجر ثم أعد فتحه — وإن تكرّر راسل الدعم.";

/// ردٌّ مُبرمَج — حالةٌ وجسمٌ ونوعُ محتوى، أو بثٌّ يبقى مفتوحاً.
class _Reply {
  const _Reply.json(this.status, this.body)
      : sse = false,
        hang = false;
  const _Reply.hanging()
      : status = 200,
        body = const {},
        sse = true,
        hang = true;

  final int status;
  final Map<String, dynamic> body;
  final bool sse;
  final bool hang;
}

class _Client extends http.BaseClient {
  _Client(this.replies);
  final List<_Reply> replies;
  int sent = 0;
  final Completer<void> _release = Completer<void>();
  final Completer<void> firstDelta = Completer<void>();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final r = replies[sent < replies.length ? sent : replies.length - 1];
    sent++;
    if (!r.sse) {
      return http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(r.body))),
        r.status,
        headers: {"content-type": "application/json"},
        request: request,
      );
    }
    Stream<List<int>> body() async* {
      yield utf8.encode('data: ${jsonEncode({"t": "delta", "v": "جزءٌ أول "})}\n\n');
      if (!firstDelta.isCompleted) firstDelta.complete();
      await _release.future;
    }

    return http.StreamedResponse(body(), 200,
        headers: {"content-type": "text/event-stream"}, request: request);
  }

  @override
  void close() {
    if (!_release.isCompleted) _release.complete();
  }
}

ChatController _controller(_Client client) => ChatController(
      askStream: AskStream(client),
    )
      ..selectedSubject = "احياء"
      ..selectedMode = "سؤال"
      ..selectedUnit = "الجهاز العصبي";

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
    dir = await Directory.systemTemp.createTemp('android_audit');
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
  // ① رفضُ App Check
  // ══════════════════════════════════════════════════
  group('📱 رفضُ App Check ليس جلسةً منتهية', () {
    test('التصنيف: 401 بـapp_check_failed ⇒ forbidden', () {
      expect(askKindForStatus(401, {"app_check_failed": true}),
          AskErrorKind.forbidden);
      // و401 العادية باقيةٌ كما هي.
      expect(askKindForStatus(401, {"answer": "⛔"}), AskErrorKind.unauthorized);
    });

    test('رسالةُ الخادم تُعرض، بلا تجديد توكنٍ ولا إعادة ولا «سجّل الدخول»',
        () async {
      final client = _Client(const [
        _Reply.json(401, {
          "answer": _appCheckReject,
          "session_active": false,
          "app_check_failed": true,
        })
      ]);
      final c = _controller(client);
      c.inputController.text = "ما الغدة النخامية؟";
      await c.processRequest();

      final last = c.messages.last;
      expect(last["isError"], isTrue);
      expect(last["text"], _appCheckReject);
      expect(last["text"], isNot(ErrorMessages.askUnauthorized));
      expect(last["canRetry"], isFalse,
          reason: "إعادةُ نفس النسخة لا تُصلح رفضَ App Check");
      expect(client.sent, 1, reason: "جُدِّد التوكن وأُعيد الطلب بلا فائدة");
      expect(QuotaRepository.I.status.remaining, 10);
    });
  });

  // ══════════════════════════════════════════════════
  // ② 200 بلا بثّ
  // ══════════════════════════════════════════════════
  group('📦 JSON بحالة 200 على مسار البثّ = جوابٌ كامل', () {
    test('AskStream يُنتج AskDone لا انقطاعاً', () async {
      final stream = AskStream(MockClient((_) async => http.Response(
            jsonEncode({"answer": "📷 الصورة غير واضحة.", "references": []}),
            200,
            headers: {"content-type": "application/json; charset=utf-8"},
          )));
      final events = await stream
          .open(
            url: Uri.parse("http://x/ask/stream"),
            headers: const {},
            body: const {},
          )
          .toList();
      expect(events, hasLength(1));
      expect(events.single, isA<AskDone>());
      expect((events.single as AskDone).payload["answer"],
          "📷 الصورة غير واضحة.");
    });

    test('صورةٌ مرفوضة: رسالةُ الخادم تظهر، بطلبٍ واحد لا اثنين', () async {
      final client = _Client(const [
        _Reply.json(200, {
          "answer": "📷 لم أجد سؤالاً دراسياً في الصورة.",
          "references": <String>[],
          "session_active": false,
        })
      ]);
      final c = _controller(client);
      c.inputController.text = "حلّ هذه";
      await c.processRequest();

      expect(client.sent, 1,
          reason: "قُرئ الردُّ انقطاعاً فأُعيدت الصورةُ تلقائياً (خصمٌ ثانٍ)");
      expect(c.messages.last["isError"], isNot(true));
      expect(c.messages.last["text"], "📷 لم أجد سؤالاً دراسياً في الصورة.");
    });

    test('JSON بلا `answer` يبقى انقطاعاً لا جواباً فارغاً', () async {
      final stream = AskStream(MockClient((_) async => http.Response(
            "{}",
            200,
            headers: {"content-type": "application/json"},
          )));
      final events = await stream
          .open(
            url: Uri.parse("http://x/ask/stream"),
            headers: const {},
            body: const {},
          )
          .toList();
      expect(events.single, isA<AskFailure>());
      expect((events.single as AskFailure).kind, AskErrorKind.interrupted);
    });
  });

  // ══════════════════════════════════════════════════
  // ③ النقرةُ المزدوجة على «إرسال»
  // ══════════════════════════════════════════════════
  test('👆 إيقافٌ في أول لحظةٍ بعد الإرسال ارتدادُ إصبع — يُهمل، وبعدها يعمل',
      () async {
    final client = _Client(const [_Reply.hanging()]);
    final c = _controller(client);
    c.inputController.text = "سؤال";
    final done = c.processRequest();
    await client.firstDelta.future;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    c.stopFromButton(); // النقرةُ الثانية من «النقرة المزدوجة»
    expect(c.isBusy, isTrue, reason: "النقرةُ المزدوجة أوقفت الطلب فوراً");

    await Future<void>.delayed(const Duration(milliseconds: 750));
    c.stopFromButton(); // قرارٌ حقيقيّ
    client.close();
    await done;
    expect(c.isBusy, isFalse);
    expect(c.messages.last["text"].toString(), contains("تم الإيقاف"));
  });

  // ══════════════════════════════════════════════════
  // ④ لا وعدَ بلا علم
  // ══════════════════════════════════════════════════
  test('🛠️ رسالةُ عطل الخادم لا تَعِد «لم يُخصم سؤالك»', () {
    expect(ErrorMessages.askServer.contains("يُخصم"), isFalse);
  });

  // ══════════════════════════════════════════════════
  // ⑤ «اختبر نفسك»
  // ══════════════════════════════════════════════════
  group('🧠 «اختبر نفسك»: الرفضُ برسالةٍ ليس عطلَ شبكة', () {
    Future<QuizGeneration> gen(int status, Map<String, dynamic> body) =>
        QuizRepository(MockClient((_) async => http.Response(
              jsonEncode(body),
              status,
              headers: {"content-type": "application/json"},
            ))).generate(
          subject: "احياء",
          grade: 3,
          track: "علمي",
          unit: "التنظيم العصبي",
          lessons: const ["السيال العصبي"],
          count: 5,
        );

    test('403 حظر ⇒ رسالةُ الخادم', () async {
      final g = await gen(403, {"answer": "⛔ حسابك موقوف مؤقتاً."});
      expect(g.isEmpty, isTrue);
      expect(g.message, "⛔ حسابك موقوف مؤقتاً.");
    });

    test('401 App Check ⇒ رسالةُ الخادم', () async {
      final g = await gen(401, {"answer": _appCheckReject, "app_check_failed": true});
      expect(g.message, _appCheckReject);
    });

    test('500 يبقى عطلاً يُرمى (فتظهر «تعذّر الاتصال» وزرُّ الإعادة)', () {
      expect(gen(500, {"detail": "boom"}), throwsA(isA<HttpException>()));
    });
  });

  // ══════════════════════════════════════════════════
  // ⑥ رجوعُ أندرويد
  // ══════════════════════════════════════════════════
  testWidgets('↩️ الترحيب: الرجوعُ من الصفحة الثانية يعود للأولى ولا يُغلق',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text("متابعة"));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(find.text("اشرح، لخّص، اسأل، وتدرّب"), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 30));
    }
    expect(handled, isTrue, reason: "الرجوعُ وصل النظامَ فأُغلق التطبيق");
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.text("مرحباً بك في مسار 👋"), findsOneWidget,
        reason: "لم يرجع للصفحة الأولى");
  });

  group('↩️ حرّاسٌ بنيويّة (الهيكل وشاشة المحادثة تحتاجان نصف التطبيق)', () {
    test('الهيكل: الرجوعُ من تبويبٍ غير الرئيسية يعود إليها', () {
      final src = File('lib/core/shell/masar_shell.dart').readAsStringSync();
      expect(src.contains('canPop: _tab == MasarTab.home'), isTrue);
      expect(src.contains('_onTap(MasarTab.home)'), isTrue);
    });

    test('المحادثة: الرجوعُ يُغلق كيبورد الرياضيات أولاً', () {
      final src = File(
              'lib/features/chat/presentation/screens/main_chat_screen.dart')
          .readAsStringSync();
      expect(src.contains('canPop: !mathKeyboard'), isTrue);
      expect(src.contains('_c.inputFocus.unfocus()'), isTrue);
    });
  });

  // ══════════════════════════════════════════════════
  // ⑦ رأسُ المحادثة عند أكبر خطّ
  // ══════════════════════════════════════════════════
  testWidgets('🔠 رأسُ المحادثة لا يفيض عند أكبر خطٍّ يسمح به السقف',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final c = ChatController();
    addTearDown(c.dispose);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(
          size: Size(360, 800),
          textScaler: TextScaler.linear(TextScaleClamp.maxScale),
        ),
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ChatGlassAppBar(controller: c, onMenu: () {}, onHelp: () {}),
          ),
        ),
      ),
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
