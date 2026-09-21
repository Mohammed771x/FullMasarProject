// 🌊 بثّ الإجابة + 📌 قاعدة الالتصاق بالأسفل.
//
// كلا الملفين منطقٌ خالص عمداً — يُختبران بلا شاشة ولا شبكة.
import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ye_student_tutor/features/chat/data/repositories/ask_stream.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/stick_to_bottom.dart';

/// عميل يسلّم بايتات SSE على دفعاتٍ نتحكّم بها — لمحاكاة تقطيع الشبكة.
class _SseClient extends http.BaseClient {
  _SseClient(this.chunks, {this.status = 200, this.body});

  final List<String> chunks;
  final int status;
  final String? body;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final stream = status == 200
        ? Stream.fromIterable(chunks.map(utf8.encode))
        : Stream.value(utf8.encode(body ?? ""));
    return http.StreamedResponse(stream, status, request: request);
  }
}

Future<List<AskEvent>> _collect(_SseClient client) => AskStream(client)
    .open(url: Uri.parse("http://x/ask/stream"), headers: const {}, body: const {})
    .toList();

void main() {
  group('🌊 فكّ أحداث SSE', () {
    test('أجزاءٌ متتابعة ثم نهاية', () async {
      final events = await _collect(_SseClient([
        'data: {"t":"delta","v":"الأكسدة "}\n\n',
        'data: {"t":"delta","v":"هي فقدان الإلكترونات."}\n\n',
        'data: {"t":"done","answer":"الأكسدة هي فقدان الإلكترونات.","references":["الوحدة الأولى"]}\n\n',
      ]));

      expect(events.whereType<AskDelta>().map((e) => e.text).toList(),
          ["الأكسدة ", "هي فقدان الإلكترونات."]);
      final done = events.last as AskDone;
      expect(done.payload["answer"], "الأكسدة هي فقدان الإلكترونات.");
      expect(done.payload["references"], ["الوحدة الأولى"]);
    });

    test('🔴 حدثٌ مقطوع بين حزمتين يُجمَّع ولا يضيع', () async {
      // ⚠️ هذا **العطل الحقيقي** الذي يظهر على الشبكات البطيئة وحدها:
      //    الشبكة تسلّم بايتاتٍ لا رسائل، فيصل نصف سطر `data:` في حزمة
      //    والنصف الآخر في التالية. وقراءةُ كل حزمة كحدثٍ كامل كانت
      //    ستُسقط أجزاءً عشوائية من الشرح — عند طلابنا لا عندنا.
      final events = await _collect(_SseClient([
        'data: {"t":"del',
        'ta","v":"نصٌّ مقسوم"}\n\n',
        'data: {"t":"done","answer":"نصٌّ مقسوم"}\n\n',
      ]));

      expect(events.whereType<AskDelta>().single.text, "نصٌّ مقسوم");
    });

    test('عدة أحداث في حزمةٍ واحدة تُفكّ كلها', () async {
      final events = await _collect(_SseClient([
        'data: {"t":"delta","v":"أ"}\n\ndata: {"t":"delta","v":"ب"}\n\n'
            'data: {"t":"done","answer":"أب"}\n\n',
      ]));
      expect(events.whereType<AskDelta>().length, 2);
      expect(events.last, isA<AskDone>());
    });

    test('💓 النبضة تُتجاهَل ولا تُحسب حدثاً', () async {
      // بروكسيات كثيرة تقطع اتصالاً صامتاً، فالنبضة تُبقيه حيّاً — وعلى
      // العميل أن يتجاهلها كما ينصّ بروتوكول SSE.
      final events = await _collect(_SseClient([
        ': keep-alive\n\n',
        'data: {"t":"delta","v":"نص"}\n\n',
        ': keep-alive\n\n',
        'data: {"t":"done","answer":"نص"}\n\n',
      ]));
      expect(events.length, 2);
    });

    test('🛟 حدثٌ مشوّه يُتجاهل ولا يُسقط بقية البثّ', () async {
      final events = await _collect(_SseClient([
        'data: {{{ليس JSON\n\n',
        'data: {"t":"delta","v":"وصل رغم ذلك"}\n\n',
        'data: {"t":"done","answer":"وصل رغم ذلك"}\n\n',
      ]));
      expect(events.whereType<AskDelta>().single.text, "وصل رغم ذلك");
      expect(events.last, isA<AskDone>());
    });

    test('حدث الخطأ يصل برسالته العربية', () async {
      final events = await _collect(_SseClient([
        'data: {"t":"delta","v":"بداية"}\n\n',
        'data: {"t":"error","v":"⚠️ انقطع الاتصال أثناء الإجابة."}\n\n',
      ]));
      expect((events.last as AskFailure).message, contains("انقطع"));
    });
  });

  group('🛂 الرفض يصل كردٍّ عادي لا كتدفّق', () {
    test('429 برسالة الحصة ⇒ يُعامل كنهايةٍ عادية', () async {
      // الخادم يفرض الحرّاس **قبل** بدء البثّ كي يصل رمز الحالة الصحيح.
      // ورسالةُ الحصة يجب أن تُعرض للطالب كما هي لا كعطل شبكة.
      final events = await _collect(_SseClient(const [],
          status: 429,
          body: '{"answer":"🎟️ وصلت حدّك اليومي","quota_exceeded":true}'));

      final done = events.single as AskDone;
      expect(done.payload["answer"], contains("حدّك اليومي"));
      expect(done.payload["quota_exceeded"], isTrue);
    });

    test('خطأ خادمٍ بلا رسالة ⇒ فشلٌ مفهوم', () async {
      final events =
          await _collect(_SseClient(const [], status: 503, body: "boom"));
      expect(events.single, isA<AskFailure>());
    });
  });

  // ══════════════════════════════════════════════════
  // 📌 قاعدة الالتصاق — قلب سلوك التمرير
  // ══════════════════════════════════════════════════
  group('📌 الالتصاق بالأسفل', () {
    test('يبدأ ملتصقاً — أول رسالة يجب أن تُرى', () {
      expect(StickToBottom().isStuck, isTrue);
    });

    test('🔴 الطالب صعد ليقرأ ⇒ ينفكّ الالتصاق', () {
      final s = StickToBottom(threshold: 80);
      s.update(pixels: 200, maxExtent: 1000);   // بعيدٌ عن القاع
      expect(s.isStuck, isFalse);
    });

    test('🧲 عاد إلى القاع بنفسه ⇒ يستأنف تلقائياً بلا زر', () {
      final s = StickToBottom(threshold: 80);
      s.update(pixels: 200, maxExtent: 1000);
      s.update(pixels: 990, maxExtent: 1000);   // ضمن العتبة
      expect(s.isStuck, isTrue);
    });

    test('📏 العتبة تسامح الوصول «قريباً» من القاع', () {
      // `maxScrollExtent` يتغيّر مع كل حرفٍ يُضاف، والتمرير السلس يقف قريباً
      // من القاع لا عليه. فمساواةٌ تامة تعني التصاقاً لا يبدأ أبداً.
      final s = StickToBottom(threshold: 80);
      s.update(pixels: 940, maxExtent: 1000);   // ٦٠ بكسل
      expect(s.isStuck, isTrue);

      s.update(pixels: 900, maxExtent: 1000);   // ١٠٠ بكسل
      expect(s.isStuck, isFalse);
    });

    test('🔴 **الإرسال لا يُعيد الالتصاق** (قرار المالك 2026-09-09)', () {
      // كان الإرسال يستدعي `stick()` بحجّة «من كتب سؤالاً يريد جوابه».
      // وهو خطأ: الطالب يقرأ فقرةً في الأعلى، يخطر له سؤال فيرسله — فتقفز
      // به الشاشة للأسفل **وتضيع منه الفقرة**. أي أن الإرسال يعاقبه.
      final s = StickToBottom(threshold: 80);
      s.update(pixels: 100, maxExtent: 1000);
      expect(s.isStuck, isFalse);
      expect(s.isStuck, isFalse, reason: "الإرسال سحب الشاشة من تحت القارئ");
    });

    test('🔽 زرّ «انزل للأسفل» وحده يُعيد الالتصاق — بطلبٍ صريح', () {
      final s = StickToBottom()..release();
      expect(s.isStuck, isFalse);
      s.stick();
      expect(s.isStuck, isTrue);
    });

    // ══════════════════════════════════════════════════
    // 👆 السحب أثناء البثّ — العطل الذي حبس المالك في الأسفل
    // ══════════════════════════════════════════════════
    test('🔴 لمسُ الشاشة يفكّ الالتصاق **فوراً** بلا انتظار عتبة', () {
      // 🔴 **العطل:** الطالب يحاول الصعود أثناء البثّ فيسحب عشرين بكسلاً —
      //    أقلّ من العتبة (٨٠) — فيبقى الالتصاق، ثم تصل الدفعة بعد ٥٠ملّي
      //    فيقفز `jumpTo` ويعيده. فلا يبلغ العتبة أبداً ولا يهرب أبداً.
      final s = StickToBottom(threshold: 80);
      expect(s.isStuck, isTrue);

      s.beginUserDrag();          // الإصبع نزل ولم يتحرّك بعد
      expect(s.isStuck, isFalse, reason: "بقي ملتصقاً فسيُعاد للقاع");
      expect(s.isDragging, isTrue);
    });

    test('🔴 لا قفزَ إلى القاع والإصبع على الشاشة', () {
      // هذا هو الشرط الذي يمنع «الشدّ» فعلياً: `followBottom` تمتنع.
      final s = StickToBottom()..beginUserDrag();
      expect(s.isDragging, isTrue);
      expect(s.isStuck, isFalse);
    });

    test('✋ رفعُ الإصبع في الأعلى ⇒ يبقى حيث هو', () {
      final s = StickToBottom(threshold: 80)..beginUserDrag();
      s.endUserDrag(const _Metrics(pixels: 200, max: 1000));
      expect(s.isDragging, isFalse);
      expect(s.isStuck, isFalse);
    });

    test('🧲 رفعُ الإصبع عند القاع ⇒ يستأنف الالتصاق تلقائياً', () {
      final s = StickToBottom(threshold: 80)..beginUserDrag();
      s.endUserDrag(const _Metrics(pixels: 990, max: 1000));
      expect(s.isDragging, isFalse);
      expect(s.isStuck, isTrue);
    });

    test('🔴 نموّ النصّ وحده لا يفكّ الالتصاق', () {
      // ⚠️ **جوهر الميزة:** البثّ يزيد `maxScrollExtent` فتكبر المسافة إلى
      //    القاع بلا أن يلمس الطالب شيئاً. ولو حسبناه «صعوداً» لانفكّ
      //    الالتصاق في أول جزء — أي تتعطّل الميزة حين تلزم بالضبط.
      //    ولذلك `onUserScroll` تُنادى من إشعار السحب وحده لا من كل تغيّر.
      final s = StickToBottom(threshold: 80);
      expect(s.isStuck, isTrue);

      // نمَت الصفحة والطالب لم يتحرك ⇒ لا أحد ينادي `onUserScroll`.
      expect(StickToBottom.distanceToBottom(940, 2000), 1060);
      expect(s.isStuck, isTrue, reason: "انفكّ الالتصاق بلا تدخّل الطالب");
    });

    test('المسافة لا تصير سالبة عند التمرير الزائد (overscroll)', () {
      expect(StickToBottom.distanceToBottom(1100, 1000), 0);
    });

    // 🔴 **الشرحُ المخزون كان يستثني نفسَه من القاعدة كلِّها**
    //    (أمرُ المالك 2026-09-19): «لو جات رسالة من المخزون تو على طول
    //    ينزل بآخر شيء… أبغاه نفس لو أرسلت رسالة للمودل ويجيبها».
    //
    // ⚖️ والمخزونُ وحده هو ما يُكتب بـ[TypewriterText] (`animating`)، وكان
    //    `onTyping` فيه `jumpTo(maxScrollExtent)` **بلا شرط** مع كل حرف —
    //    فيتجاوز [StickToBottom] ولا يُفلت القارئ ولو وضع إصبعه. والحارسُ
    //    بالكود لا بالتعليق، لأن التعليقَ هو ما جعل استثناءَ البثّ يبدو
    //    مقصوداً فلا يُراجَع ([[streaming-design]]).
    test('📌 الطابعةُ تتبع قاعدةَ التمرير كالبثّ — لا قفزَ مطلق', () {
      final src = File('lib/features/chat/presentation/widgets/'
              'chat_list_view.dart')
          .readAsStringSync();
      final typing = src.substring(src.indexOf('onTyping:'),
          src.indexOf('onStopped:'));
      expect(typing.contains('followBottom'), isTrue,
          reason: 'الطابعةُ لا تمرّ بقاعدة الالتصاق');
      expect(typing.contains('jumpTo'), isFalse,
          reason: 'قفزٌ مطلقٌ يسحب الشاشة من تحت القارئ');
    });
  });
}

/// مقاييس تمريرٍ بسيطة — `endUserDrag` تحتاج `ScrollMetrics` وحدها.
class _Metrics implements ScrollMetrics {
  const _Metrics({required this.pixels, required double max}) : maxScrollExtent = max;

  @override
  final double pixels;
  @override
  final double maxScrollExtent;
  @override
  double get minScrollExtent => 0;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}
