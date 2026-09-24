// ══════════════════════════════════════════════════
// 📷 تدفّق الصورة في المحادثة — من الإرفاق إلى الحفظ
// ══════════════════════════════════════════════════
//
// 🔴 **العطل الذي وصفه المالك (2026-09-13):**
//    «لما نضيف صورة والمحادثة فاضية تنضاف وترسل، لكن لما المحادثة يكون
//     فيها كلام وأضفت الصورة — ما نقدر نرسل، أضغط الزر ما يضبط وتختفي
//     الصورة».
//
//    وله سببان متداخلان، كلاهما محروسٌ هنا:
//
//    ① **بوّابة الإرسال لم تكن تسأل عن المرفق إطلاقاً**: كانت تسأل عن نصٍّ
//      مكتوب أو درسٍ مختار. فمحادثةٌ جديدة اختير درسُها ⇒ الزرّ حيّ فتُرسل
//      الصورة، ومحادثةٌ مستعادة من السجلّ **لا يُستعاد درسُها** ⇒ الزرّ ميت
//      وصورةُ المسألة أمام الطالب. من هنا جاء الفرق بين «فاضية» و«فيها كلام».
//
//    ② **البثّ يُطفئ `isLoading` عند أول جزء**: فالزرّ يعود سهماً والطلبُ
//      ما زال في الطريق. ضغطةٌ ثانية تمرّ فوق الأولى — و`processRequest`
//      كانت **تُفرّغ المرفق قبل حارس «مشغول»**، فتضيع الصورة بلا إرسال.
//      وهذا حرفياً «أضغط ما يضبط وتختفي الصورة».
//
// 🎯 وهذه الاختبارات تمشي في كل حالةٍ للصورة: صورة · صورتان · مع نصّ ·
//    بلا نصّ · أثناء التحميل · أثناء البثّ · في وضع الصفحات · عند فشل
//    الشبكة · عبر تبديل المحادثات · وفي الحفظ والاستعادة.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ye_student_tutor/core/services/image_service.dart';
import 'package:ye_student_tutor/core/storage/chat_storage.dart';
import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/chat/data/models/subject_capabilities.dart';
import 'package:ye_student_tutor/features/chat/data/repositories/ask_stream.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';
import 'package:ye_student_tutor/features/chat/presentation/widgets/chat_input_area.dart';

import 'package:ye_student_tutor/core/widgets/phosphor.dart';

// ══════════════ أدوات ══════════════

PickedImage _img(String name) =>
    PickedImage(path: "/tmp/masar_$name.jpg", base64Data: "BASE64_$name", sizeBytes: 1024);

/// عميلٌ يلتقط جسم الطلب ويردّ بثّاً مُصطنعاً — بلا شبكة.
class _CapturingClient extends http.BaseClient {
  _CapturingClient(
      {this.answer = "الجواب",
      this.imageText = "",
      this.fail = false,
      this.pendingFirst = false,
      this.omitDone = false,
      this.firstDelta = "جزء"});

  final String firstDelta;
  final String answer;
  final String imageText;
  final bool fail;
  final bool pendingFirst;
  final bool omitDone;

  final List<Map<String, dynamic>> bodies = [];
  /// بوّابة اختيارية: تُبقي الطلب معلّقاً حتى نفتحها (لمحاكاة «جارٍ الرد»).
  Completer<void>? gate;

  Map<String, dynamic> get lastBody => bodies.last;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    bodies.add(jsonDecode((request as http.Request).body) as Map<String, dynamic>);
    if (fail) throw const SocketException("لا شبكة");
    if (pendingFirst && bodies.length == 1) {
      return http.StreamedResponse(
        Stream.value(utf8.encode('{"answer":"قيد المعالجة","in_flight":true}')),
        202,
        request: request,
      );
    }
    final done = jsonEncode({
      "t": "done",
      "answer": answer,
      "references": <String>[],
      if (imageText.isNotEmpty) "extracted_text": imageText,
    });
    // 🌊 الجزءُ الأول يصل فوراً، ثم **يقف الردّ عند البوّابة** إن وُضعت —
    //    فنمسك الحالة التي كانت العلّة كلها فيها: بثٌّ جارٍ و`isLoading`
    //    مُطفأ. وبلا بوّابةٍ يمضي البثّ إلى نهايته بلا انتظار.
    Stream<List<int>> body() async* {
      yield utf8.encode('data: {"t":"delta","v":"$firstDelta"}\n\n');
      if (gate != null) await gate!.future;
      if (omitDone) return;
      yield utf8.encode('data: $done\n\n');
    }

    return http.StreamedResponse(body(), 200, request: request);
  }

  @override
  void close() {
    final waiting = gate;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
  }
}

/// طالبٌ في وضع الوحدات بلا درسٍ مختار — أي **بوّابةٌ مغلقة إلا بالصورة**.
/// (وهي حال أي محادثةٍ تُستعاد من السجلّ: الدرس لا يُحفظ فلا يُستعاد.)
ChatController _controller({_CapturingClient? client}) => ChatController(
      askStream: client == null ? null : AskStream(client),
    )
      ..selectedSubject = "احياء"
      ..selectedMode = "شرح"
      // 🚦 اختيارٌ مكتمل ([ChatController.sendBlocker]): هذه الاختباراتُ
      //    تفحص الصورَ والبثّ، لا بوّابةَ الاختيار — ولها ملفُّها.
      ..selectedUnit = "الجهاز العصبي";

SubjectCapabilities _caps() => SubjectCapabilities.fromJson({
      "subject": "احياء",
      "lessons": {
        "available": true,
        "units": [
          {"unit": "الجهاز العصبي", "lessons": ["الخلية العصبية"]}
        ],
      },
      "pages": {
        "available": true,
        "units": ["الجهاز العصبي"],
        "unit_pages": {"الجهاز العصبي": [9, 10, 11]},
        "max_selectable": 3,
      },
    });

/// يعرض خانة الكتابة ويعيد «هل نُبّه الطالب بأن يكتب سؤالاً؟».
Future<List<String>> _pumpInput(WidgetTester tester, ChatController c) async {
  final warnings = <String>[];
  await tester.pumpWidget(MaterialApp(
    builder: (ctx, child) =>
        Directionality(textDirection: TextDirection.rtl, child: child!),
    home: Scaffold(
      body: AnimatedBuilder(
        animation: c,
        builder: (_, _) => ChatInputArea(
          controller: c,
          onEmptyWarning: () => warnings.add("اكتب سؤالك أولاً"),
        ),
      ),
    ),
  ));
  await tester.pump();
  return warnings;
}

// 🎨 **بعد إعادة التصميم**: أيقونات الشريط صارت Phosphor لا Material —
//    سهمُ الإرسال `PaperPlaneRight` وزرُّ الإيقاف `StopCircle` والكاميرا
//    `Camera`. والاختباراتُ تسأل عن السلوك نفسه، لا عن اسم الأيقونة القديم.
final Finder _sendFinder = find.byIcon(PI.paperPlaneRight.fill);
final Finder _stopFinder = find.byIcon(PI.stopCircle.fill);
final Finder _cameraFinder = find.byIcon(PI.camera.regular);

/// 🚦 الزرُّ حيٌّ أم رمادي.
///
/// ⚠️ **لا يُقاس بلون السهم بعد اليوم**: السهمُ أبيضُ في الحالتين كما في
///    التصميم، والفرقُ في **تعبئة الدائرة** — كاملةٌ حين يمكن الإرسال،
///    و40% منها حين لا شيءَ لِيُرسَل.
bool _sendEnabled(WidgetTester tester) {
  if (_sendFinder.evaluate().isEmpty) return false;   // صار زرَّ إيقاف
  final box = tester.widget<AnimatedContainer>(
      find.ancestor(of: _sendFinder, matching: find.byType(AnimatedContainer))
          .first);
  return (box.decoration as BoxDecoration).color!.a == 1.0;
}

Future<void> _tapSend(WidgetTester tester) async {
  final send =
      _sendFinder.evaluate().isNotEmpty ? _sendFinder : _stopFinder;
  await tester.tap(send);
  await tester.pump();
}

void main() {
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('masar_images_test');
    await ChatStorage.initForTests(dir.path);
  });
  setUp(() async => ChatStorage.clearAll());
  tearDownAll(() async => dir.delete(recursive: true));

  // ══════════════════════════════════════════════════
  // 🚦 ① بوّابة الإرسال — الصورةُ وحدها طلبٌ كامل
  // ══════════════════════════════════════════════════
  group('🚦 بوّابة الإرسال', () {
    testWidgets('⭐ صورة بلا نصّ في محادثةٍ فيها كلام ⇒ الزرّ حيّ (عطل المالك)',
        (tester) async {
      final c = _controller()
        ..messages = [
          {"role": "user", "text": "سؤال سابق"},
          {"role": "ai", "text": "جواب سابق", "animating": false},
        ];
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);

      await _pumpInput(tester, c);

      expect(_sendEnabled(tester), isTrue,
          reason: 'الصورة طلبٌ كامل — لا يجوز أن يبقى الزرّ رمادياً');
      // ⚠️ والضغطةُ نفسها تُختبر في «حمولة الإرسال» أدناه: الإرسال الحقيقي
      //    يكتب في Hive، وكتابةُ القرص داخل `testWidgets` لا تنتهي أبداً
      //    (الزمنُ فيها وهميّ) — فخٌّ وقعنا فيه قبلاً.
    });

    testWidgets('صورة بلا نصّ في محادثةٍ فاضية ⇒ الزرّ حيّ كذلك', (tester) async {
      final c = _controller();
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);
      await _pumpInput(tester, c);
      expect(_sendEnabled(tester), isTrue);
    });

    testWidgets('صورتان بلا نصّ ⇒ الزرّ حيّ وزرّ الكاميرا يختفي', (tester) async {
      final c = _controller();
      c.attachedImages.addAll([_img("a"), _img("b")]);
      addTearDown(c.dispose);
      await _pumpInput(tester, c);

      expect(_sendEnabled(tester), isTrue);
      expect(_cameraFinder, findsNothing,
          reason: 'بلغ الحدّ الأقصى — فلا بابَ لثالثة');
      expect(find.byType(Image), findsNWidgets(2), reason: 'معاينتان');
    });

    testWidgets('صورة + نصّ ⇒ الزرّ حيّ', (tester) async {
      final c = _controller();
      c.inputController.text = "اشرح هذه المسألة";
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);
      await _pumpInput(tester, c);
      expect(_sendEnabled(tester), isTrue);
    });

    testWidgets('لا صورة ولا نصّ ولا درس ⇒ الزرّ رمادي وينبّه', (tester) async {
      final c = _controller();
      addTearDown(c.dispose);
      final warnings = await _pumpInput(tester, c);

      expect(_sendEnabled(tester), isFalse);
      await _tapSend(tester);
      expect(warnings, hasLength(1));
    });

    testWidgets('🌊 أثناء البثّ ⇒ زرُّ إيقافٍ لا سهم، ولا كاميرا', (tester) async {
      final c = _controller()
        ..isStreaming = true
        ..messages = [
          {"role": "user", "text": "اشرح"},
          {"role": "ai", "text": "ينمو", "streaming": true, "animating": false},
        ];
      c.inputController.text = "سؤال ثانٍ";
      addTearDown(c.dispose);
      await _pumpInput(tester, c);

      expect(_stopFinder, findsOneWidget,
          reason: '🔴 كان يظهر سهمَ إرسالٍ فيُطلق طلباً ثانياً فوق الأول');
      expect(_sendFinder, findsNothing);
      expect(_cameraFinder, findsNothing);
    });

    testWidgets('⏳ أثناء التحميل ⇒ زرُّ إيقاف', (tester) async {
      final c = _controller()..isLoading = true;
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);
      await _pumpInput(tester, c);
      expect(_stopFinder, findsOneWidget);
    });

    testWidgets('✕ على المعاينة يرفع الصورة وحدها', (tester) async {
      final c = _controller();
      c.attachedImages.addAll([_img("a"), _img("b")]);
      addTearDown(c.dispose);
      await _pumpInput(tester, c);

      // ✕ المعاينة صارت Phosphor كبقيّة أيقونات الشريط.
      await tester.tap(find.byIcon(PI.x.bold).first);
      await tester.pump();
      expect(c.attachedImages, hasLength(1));
      expect(c.attachedImages.single.path, contains("masar_b"));
    });
  });

  // ══════════════════════════════════════════════════
  // 🛡️ ② الرفض لا يبتلع الصورة
  // ══════════════════════════════════════════════════
  group('🛡️ الطلب المرفوض يُبقي المرفق', () {
    test('⭐ ضغطُ إرسالٍ أثناء التحميل ⇒ الصورة تبقى (عطل «تختفي الصورة»)',
        () async {
      final c = _controller()..isLoading = true;
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);

      var warned = false;
      c.onShowBusyWarning = () => warned = true;

      await c.processRequest();

      expect(warned, isTrue, reason: 'يُقال له لماذا لم يُرسل');
      expect(c.attachedImages, hasLength(1),
          reason: '🔴 كانت تُفرَّغ قبل الحارس فتضيع بلا إرسال');
      expect(c.messages, isEmpty);
    });

    test('🌊 ضغطُ إرسالٍ أثناء البثّ ⇒ لا طلب ثانٍ والصورة تبقى', () async {
      // بثٌّ حقيقيّ واقفٌ عند بوّابة — الحالة التي كان `isLoading` يكذب فيها.
      final client = _CapturingClient()..gate = Completer<void>();
      final c = _controller(client: client);
      c.inputController.text = "اشرح";
      addTearDown(c.dispose);

      final pending = c.processRequest();
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(c.isStreaming, isTrue);
      expect(c.isLoading, isFalse, reason: 'أوّلُ جزءٍ يُطفئ مؤشّر الانتظار');
      expect(c.isBusy, isTrue, reason: '⭐ والطلبُ ما زال في الطريق');

      // الطالب يُرفق صورةً ويضغط إرسال والردّ لم يكتمل بعد.
      c.attachedImages.add(_img("a"));
      c.inputController.text = "سؤال ثانٍ";
      var warned = false;
      c.onShowBusyWarning = () => warned = true;
      await c.processRequest();

      expect(warned, isTrue);
      expect(client.bodies, hasLength(1), reason: 'لا طلبَ ثانٍ فوق الأول');
      expect(c.attachedImages, hasLength(1),
          reason: '🔴 كانت تُفرَّغ هنا بلا إرسال — «أضغط ما يضبط وتختفي الصورة»');

      client.gate!.complete();
      await pending;
    });

    test('📄 وضع الصفحات بلا اختيار وبلا صورة ⇒ يُرفض ويُنبَّه', () async {
      final c = _controller()
        ..contentMode = "pages"
        ..selectedUnit = "الجهاز العصبي"
        ..caps = _caps();
      c.inputType = "صفحة";
      c.inputController.text = "اشرح";
      addTearDown(c.dispose);

      // 🚦 صار السببُ يصل من البوّابة الواحدة ([ChatController.sendBlocker])
      //    — بالكلمة نفسها — والشاشةُ تفتح البطاقةَ حيث تُختار الصفحات.
      //    وحارسُ الصفحات الأقدم (`onShowPagesRequired`) يسبقها — أيُّهما
      //    نطق فقد قال السببَ نفسَه.
      String? reason;
      c.onSendBlocked = (r) => reason = r;
      c.onShowPagesRequired = () => reason = 'اختر الصفحات أولاً';
      await c.processRequest();

      expect(reason, contains('الصفحات'));
      expect(c.messages, isEmpty);
    });

    test('📷 وضع الصفحات بلا اختيار **ومعه صورة** ⇒ يمضي', () async {
      final client = _CapturingClient();
      final c = _controller(client: client)
        ..contentMode = "pages"
        ..selectedUnit = "الجهاز العصبي"
        ..caps = _caps();
      c.inputType = "صفحة";
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);

      var asked = false;
      c.onShowPagesRequired = () => asked = true;
      await c.processRequest();

      expect(asked, isFalse,
          reason: 'من صوّر الصفحة لم ينسَ اختيارها — استغنى عنه');
      expect(client.bodies, hasLength(1));
      expect(client.lastBody["images_base64"], ["BASE64_a"]);
    });

    test('بلا نصّ وبلا صورة وبلا درس ⇒ لا شيء يُرسل', () async {
      final client = _CapturingClient();
      final c = _controller(client: client);
      addTearDown(c.dispose);
      await c.processRequest();
      expect(client.bodies, isEmpty);
      expect(c.messages, isEmpty);
    });
  });

  // ══════════════════════════════════════════════════
  // 🚀 ③ الإرسال الفعلي — ما الذي يصل الخادم؟
  // ══════════════════════════════════════════════════
  group('🚀 حمولة الإرسال', () {
    test('HTTP 202 يعيد نفس المحاولة بالنص والصورة والسياق نفسيهما', () async {
      final client = _CapturingClient(pendingFirst: true);
      final c = _controller(client: client);
      c.inputController.text = "اشرح الصورة";
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);

      await c.processRequest();

      expect(client.bodies, hasLength(2));
      expect(client.bodies[1], client.bodies[0]);
      expect(client.bodies[0]["request_id"], isNotEmpty);
      expect(c.messages.where((m) => m["role"] == "ai"), hasLength(1));
    });

    test('انقطاع البث بعد partial يثبت فقاعة واحدة ولا يكرر الإجابة', () async {
      final client = _CapturingClient(
          omitDone: true, firstDelta: "جزء وصل قبل الانقطاع");
      final c = _controller(client: client);
      c.inputController.text = "اشرح";
      addTearDown(c.dispose);

      await c.processRequest();

      final answers = c.messages.where((m) => m["role"] == "ai").toList();
      expect(answers, hasLength(1));
      expect(answers.single["text"], contains("جزء وصل قبل الانقطاع"));
      expect(answers.single["streaming"], isFalse);
    });

    // ══════════════════════════════════════════════
    // 🛟 وما قُرئ على الشاشة يُقرأ بعد العودة إليها
    // ══════════════════════════════════════════════
    // 🔴 **انحدارٌ دخل مع توحيد دورة الطلب:** بعد أن صار الانقطاعُ الجزئي
    //    يرمي `StreamInterrupted(hasPartial: true)` بدل أن يعود نجاحاً،
    //    سقط `saveCurrentConversation` من مساره. فالنصُّ يبقى على الشاشة
    //    ما دام الطالب فيها، فإذا خرج وعاد **لم يجد منه حرفاً** — ونداءُ
    //    الموديل قد دُفع ثمنُه كاملاً.
    //
    // ⚖️ واختبارُ الشاشة وحدها كان سيمرّ: الفقاعةُ هناك. فنقرأ من القرص.
    test('انقطاعٌ بعد partial يُحفظ على القرص لا على الشاشة وحدها', () async {
      final client = _CapturingClient(
        omitDone: true,
        firstDelta: "نصفُ الشرح وصل",
      );
      final c = _controller(client: client);
      c.inputController.text = "اشرح";
      addTearDown(c.dispose);

      await c.processRequest();

      final saved = ChatStorage.getConversation(c.currentConversationId!);
      expect(saved, isNotNull, reason: 'الانقطاعُ الجزئي لم يحفظ شيئاً');
      final stored = saved!.messages.where((m) => m.role == "ai").toList();
      expect(stored, hasLength(1));
      expect(stored.single.text, contains("نصفُ الشرح وصل"));
    });

    test('صورة واحدة بلا نصّ', () async {
      final client = _CapturingClient();
      final c = _controller(client: client);
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);

      await c.processRequest();

      expect(client.lastBody["images_base64"], ["BASE64_a"]);
      final userMsg = c.messages.first;
      expect(userMsg["text"], "📷 صورة");
      expect(userMsg["images"], ["/tmp/masar_a.jpg"]);
      expect(c.attachedImages, isEmpty, reason: 'الخانة تُفرَّغ بعد الإرسال');
    });

    test('صورتان بلا نصّ ⇒ «📷 صورتان» ومسارَان وحمولتان', () async {
      final client = _CapturingClient();
      final c = _controller(client: client);
      c.attachedImages.addAll([_img("a"), _img("b")]);
      addTearDown(c.dispose);

      await c.processRequest();

      expect(client.lastBody["images_base64"], ["BASE64_a", "BASE64_b"]);
      expect(c.messages.first["text"], "📷 صورتان");
      expect(c.messages.first["images"], hasLength(2));
    });

    test('صورة + نصّ ⇒ النصّ في المحتوى والصورة معه', () async {
      final client = _CapturingClient();
      final c = _controller(client: client);
      c.inputController.text = "احسب المطلوب في الصورة";
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);

      await c.processRequest();

      expect(client.lastBody["content"], "احسب المطلوب في الصورة");
      expect(client.lastBody["images_base64"], ["BASE64_a"]);
      expect(c.messages.first["text"], "احسب المطلوب في الصورة");
      expect(c.messages.first["images"], ["/tmp/masar_a.jpg"]);
      expect(c.inputController.text, isEmpty);
    });

    test('الرسالة التالية بلا مرفق ⇒ لا `images_base64` (لا تُرسل مرتين)',
        () async {
      final client = _CapturingClient();
      final c = _controller(client: client);
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);

      await c.processRequest();
      c.inputController.text = "وضّح أكثر";
      await c.processRequest();

      expect(client.bodies, hasLength(2));
      expect(client.bodies[0].containsKey("images_base64"), isTrue);
      expect(client.bodies[1].containsKey("images_base64"), isFalse);
    });

    test('★ نصُّ الصورة يُثبَّت على رسالة الطالب ويدخل سياق ما بعدها', () async {
      const ocr = "[محتوى صورة أرسلها الطالب: ما ناتج ٢س + ٣ = ٩ ؟]";
      final client = _CapturingClient(imageText: ocr);
      final c = _controller(client: client);
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);

      await c.processRequest();
      expect(c.messages.first["imageText"], ocr);

      c.inputController.text = "وضّح الخطوة الثانية";
      await c.processRequest();

      final history = (client.bodies[1]["chat_history"] as List)
          .map((e) => (e as Map)["content"].toString())
          .toList();
      expect(history.any((t) => t.contains(ocr)), isTrue,
          reason: 'التاريخ نصٌّ لا صور — بلا هذا تُنسى الصورة في السؤال التالي');
    });

    test('❌ فشل الشبكة ⇒ الصورة تعود لخانة الإرفاق ولا تبقى في فقاعةٍ فاشلة',
        () async {
      final client = _CapturingClient(fail: true);
      final c = _controller(client: client);
      c.inputController.text = "اشرح الصورة";
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);

      await c.processRequest();

      expect(c.attachedImages, hasLength(1),
          reason: 'شبكةُ الطالب تتقطّع — إعادةُ المحاولة ضغطةٌ لا رحلةٌ للمعرض');
      expect(c.attachedImages.single.base64Data, "BASE64_a");
      expect(c.messages.first.containsKey("images"), isFalse,
          reason: 'مالكٌ واحد للملف — وإلا عرضت الفقاعة ملفاً محذوفاً');
      expect(c.messages.last["isError"], isTrue);
    });
  });

  // ══════════════════════════════════════════════════
  // 🔒 ④ المرفق لا يعبر المحادثات
  // ══════════════════════════════════════════════════
  group('🔒 عزل المرفق', () {
    test('محادثةٌ جديدة تُفرغ المرفق المعلّق', () {
      final c = _controller();
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);

      c.createNewConversation();
      expect(c.attachedImages, isEmpty,
          reason: 'صورةُ محادثةٍ لا تُرسل في أخرى');
    });

    test('فتحُ محادثةٍ من السجلّ يُفرغ المرفق', () {
      final c = _controller();
      c.attachedImages.add(_img("a"));
      addTearDown(c.dispose);

      c.loadConversation(ChatConversation(
        id: "x",
        title: "قديمة",
        subject: "احياء",
        mode: "شرح",
        messages: [ChatMessage(role: "user", text: "سؤال")],
      ));
      expect(c.attachedImages, isEmpty);
    });
  });

  // ══════════════════════════════════════════════════
  // 💾 ⑤ الحفظ والاستعادة وحذف الملفات
  // ══════════════════════════════════════════════════
  group('💾 الحفظ والاستعادة', () {
    test('الصور تُحفظ مع المحادثة وتعود مع الاستعادة', () async {
      final client = _CapturingClient();
      final c = _controller(client: client);
      c.attachedImages.addAll([_img("a"), _img("b")]);
      addTearDown(c.dispose);

      await c.processRequest();

      final saved = ChatStorage.getConversation(c.currentConversationId!)!;
      expect(saved.messages.first.allImages,
          ["/tmp/masar_a.jpg", "/tmp/masar_b.jpg"]);

      final fresh = _controller()..loadConversation(saved);
      addTearDown(fresh.dispose);
      expect(fresh.messages.first["images"], hasLength(2));
    });

    test('🧹 حذفُ المحادثة يحذف ملفات صورها من الجوال', () async {
      final imagesDir = Directory("${dir.path}/chat_images")
        ..createSync(recursive: true);
      final file = File("${imagesDir.path}/one.jpg")..writeAsBytesSync([1, 2, 3]);

      final conv = ChatConversation(
        id: "with-image",
        title: "بصورة",
        subject: "احياء",
        mode: "شرح",
        messages: [
          ChatMessage(role: "user", text: "📷 صورة", imagePaths: [file.path])
        ],
      );
      await ChatStorage.saveConversation(conv);

      final c = _controller();
      addTearDown(c.dispose);
      await c.deleteConversation("with-image");
      // الحذف «أفضل جهد» غير منتظَر — نمنحه دورةً واحدة.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(file.existsSync(), isFalse,
          reason: 'وإلا تراكمت صورُ محادثاتٍ محذوفة حتى يمتلئ الجوال');
    });
  });

  // ══════════════════════════════════════════════════
  // 🛑 ⑥ الإيقاف أثناء البثّ
  // ══════════════════════════════════════════════════
  test('🛑 الإيقاف أثناء البثّ يوقفه فعلاً ويُبقي ما وصل', () async {
    final client = _CapturingClient(
        firstDelta: "نصفُ الشرح", answer: "الجواب الكامل بعد الإيقاف")
      ..gate = Completer<void>();
    final c = _controller(client: client);
    c.inputController.text = "اشرح";
    addTearDown(c.dispose);

    var confirmed = false;
    c.onShowStopConfirmation = () => confirmed = true;

    final pending = c.processRequest();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(c.isStreaming, isTrue);

    c.stopCurrentRequest();

    expect(confirmed, isTrue, reason: '🔴 كان يخرج فوراً بلا أن يوقف شيئاً');
    expect(c.isStreaming, isFalse);
    expect(c.isBusy, isTrue,
        reason: 'الإلغاء لم ينته بعد؛ لا يجوز إعلان idle مبكراً');
    expect(c.messages.last["streaming"], isFalse);
    expect(c.messages.last["text"], contains("نصفُ الشرح"),
        reason: 'الحصةُ دُفعت وما قرأه الطالب ملكُه');
    expect(c.messages.last["text"], contains("تم الإيقاف"));

    // والجواب الكامل يصل بعد الإيقاف ⇒ يُطرح ولا يُكتب فوق ما ثبّتناه.
    await pending;
    expect(c.isBusy, isFalse);
    expect(c.messages.last["text"], contains("تم الإيقاف"));
    expect(c.messages.last["text"], isNot(contains("الجواب الكامل")));
  });

  test('تبديل الوضع ينتظر إلغاء الطلب ولا يخلط السياقين', () async {
    final client = _CapturingClient()..gate = Completer<void>();
    final c = _controller(client: client);
    c.inputController.text = "اشرح";
    addTearDown(c.dispose);

    final pending = c.processRequest();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(c.isBusy, isTrue);

    final switching = c.switchContext(() => c.selectedMode = "تلخيص");
    // الإعداد لا يتغير قبل اكتمال إلغاء مالك الطلب القديم.
    expect(c.selectedMode, "شرح");
    await switching;
    await pending;

    expect(c.isBusy, isFalse);
    expect(c.selectedMode, "تلخيص");
    expect(c.messages.where((m) => m["text"] == "الجواب"), isEmpty);
  });
}
