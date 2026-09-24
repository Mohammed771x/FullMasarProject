// ══════════════════════════════════════════════════
// 💬 الخروجُ من محادثةٍ والعودةُ إليها لا يقفل زرّ الإرسال
// ══════════════════════════════════════════════════
//
// 🔴 **شكوى المالك (2026-09-14) — «باغ خطير»:** «لو كتبت وأرسلت، نزلت من
//    المحادثة ورجعت دخلت، وكتبت مرة ثانية — ما يرسل.»
//
// ⚖️ والسبب أن [ChatController] **كائنٌ واحدٌ يعيش بعد الشاشة**: فتحُ محادثةٍ
//    يستبدل `messages` ولا يمسّ حالةَ الطلب الجاري. فمن غادر أثناء بثٍّ
//    أو انتظار يعود و`isStreaming`/`isLoading` ما زالت `true` —
//    و[ChatController.isBusy] تُطفئ الزرّ **إلى الأبد**.
//
// ☢️ وأسوأُ منه: `_streamIndex` يبقى مشيراً إلى رسالةٍ في القائمة **القديمة**،
//    فأيُّ جزءٍ متأخّر من البثّ يُكتب في رسالةٍ من محادثةٍ أخرى.
import 'package:flutter_test/flutter_test.dart';

import 'package:ye_student_tutor/features/chat/data/models/chat_model.dart';
import 'package:ye_student_tutor/features/chat/presentation/controllers/chat_controller.dart';

ChatConversation _conversation(String id, List<String> texts) => ChatConversation(
      id: id,
      title: texts.isEmpty ? 'محادثة' : texts.first,
      subject: 'احياء',
      mode: 'سؤال',
      messages: [
        for (var i = 0; i < texts.length; i++)
          ChatMessage(role: i.isEven ? 'user' : 'ai', text: texts[i], refs: const []),
      ],
      grade: 3,
      track: 'علمي',
    );

void main() {
  test('🔴 العودةُ لمحادثةٍ أثناء البثّ تُحرّر زرّ الإرسال', () {
    final c = ChatController();
    addTearDown(c.dispose);

    c.debugSetBusy(streaming: true, streamIndex: 3);
    expect(c.isBusy, isTrue, reason: 'التهيئة نفسها خاطئة');

    c.loadConversation(_conversation('a', ['سؤال', 'جواب']));

    expect(c.isBusy, isFalse,
        reason: 'الزرّ ما زال مقفولاً بعد فتح محادثةٍ أخرى — نفسُ عطل المالك');
  });

  test('🔴 والعودةُ أثناء الانتظار كذلك', () {
    final c = ChatController();
    addTearDown(c.dispose);

    c.debugSetBusy(loading: true);
    c.loadConversation(_conversation('b', ['سؤال']));

    expect(c.isBusy, isFalse);
  });

  test('☢️ ومؤشّرُ البثّ لا يبقى مصوّباً على رسالةٍ من محادثةٍ سابقة', () {
    final c = ChatController();
    addTearDown(c.dispose);

    c.debugSetBusy(streaming: true, streamIndex: 7);
    c.loadConversation(_conversation('c', ['سؤال', 'جواب']));

    expect(c.debugStreamIndex, isNull,
        reason: 'جزءٌ متأخّر من البثّ سيُكتب في رسالةٍ من محادثةٍ أخرى');
  });

  test('💬 محادثةٌ جديدة تُحرّر الزرّ أيضاً', () {
    final c = ChatController();
    addTearDown(c.dispose);

    c.debugSetBusy(streaming: true, streamIndex: 2);
    c.createNewConversation();

    expect(c.isBusy, isFalse);
    expect(c.debugStreamIndex, isNull);
  });

  test('✅ ولا تُكسر الحالةُ السليمة: فتحُ محادثةٍ ولا طلبَ جارٍ', () {
    final c = ChatController();
    addTearDown(c.dispose);

    c.loadConversation(_conversation('d', ['سؤال', 'جواب']));

    expect(c.isBusy, isFalse);
    expect(c.messages.length, 2);
    expect(c.currentConversationId, 'd');
  });

  // ══════════════════════════════════════════════════
  // ⏱️ وشبكةُ أمانٍ لكل طريقٍ آخر: حالةٌ مشغولة ميتة
  // ══════════════════════════════════════════════════
  //
  // 🔴 مهلةُ `ask_stream` مهلةُ **فتحِ** الاتصال (١٢٠ث) لا مهلةَ التدفّق
  //    بعده. فبثٌّ يتجمّد في منتصفه — خلفيةُ الجوال، سقوطُ واي-فاي —
  //    يُبقي `await for` معلّقاً إلى الأبد و`isBusy` معه.

  test('⏱️ طلبٌ تجمّد لا يقفل الزرّ إلى الأبد', () {
    final c = ChatController();
    addTearDown(c.dispose);

    c.debugSetBusy(streaming: true, streamIndex: 1);
    c.debugAgeBusyState();
    c.selectedUnit = 'الجهاز العصبي'; // 🚦 اختيارٌ مكتمل — البوّابةُ ليست موضوعَ الاختبار

    var warned = false;
    c.onShowBusyWarning = () => warned = true;
    c.processRequest(customText: 'سؤال جديد');

    expect(warned, isFalse,
        reason: 'حُذّر الطالبُ من طلبٍ ميت — ولا حيلةَ له');
    expect(c.messages.any((m) => m['text'] == 'سؤال جديد'), isTrue,
        reason: 'الرسالةُ لم تُرسَل رغم أن الطلب السابق ميت');
  });

  test('✅ وطلبٌ حيٌّ ما زال يُحذّر — لا نسمح بطلبين معاً', () {
    final c = ChatController();
    addTearDown(c.dispose);

    c.debugSetBusy(streaming: true, streamIndex: 1);   // حديثٌ لا ميت

    var warned = false;
    c.onShowBusyWarning = () => warned = true;
    c.processRequest(customText: 'سؤال ثانٍ');

    expect(warned, isTrue, reason: 'مرّ طلبان معاً');
  });

  // ══════════════════════════════════════════════════
  // ☢️ فخُّ التغاير: القائمةُ تُقفل نفسها فلا تقبل رسالةً جديدة
  // ══════════════════════════════════════════════════
  //
  // 🔴 **هذا هو عطلُ المالك الحقيقي.** `messages` معلَنة
  //    `List<Map<String, dynamic>>`، لكنّ حرفيّة `loadConversation` كانت
  //    تُستنتج `Map<String, Object>` (لا قيمةَ فيها فارغة)، فيصير النوعُ
  //    **الحقيقي** للقائمة `List<Map<String, Object>>`. والإسنادُ يمرّ،
  //    ثم أولُ `messages.add(<String, dynamic>{...})` يرمي في زمن التشغيل:
  //
  //      type '_Map<String, dynamic>' is not a subtype of
  //      type 'Map<String, Object>' of 'value'
  //
  //    والاستثناءُ يقع **قبل** ظهور فقاعة الطالب، داخل `async` بلا ممسك —
  //    فلا شيء يظهر ولا رسالةُ خطأ. الزرُّ يبدو سليماً ولا يرسل أبداً.
  //    ⚠️ ولا تحذّر منه أداةُ التحليل: النوعان متوافقان عند الترجمة.

  test('☢️ يمكن إضافةُ رسالةٍ بعد فتح محادثةٍ محفوظة', () {
    final c = ChatController();
    addTearDown(c.dispose);

    c.loadConversation(_conversation('a', ['سؤال', 'جواب']));

    // هذه بالضبط ما يفعله [processRequest] عند الإرسال.
    expect(
      () => c.messages.add(<String, dynamic>{'role': 'user', 'text': 'رسالة جديدة'}),
      returnsNormally,
      reason: 'القائمةُ أقفلت نوعَها — الإرسالُ يرمي بصمت ولا يحدث شيء',
    );
    expect(c.messages.length, 3);
  });

  test('☢️ وفقاعةُ البثّ بحقولها كلِّها تُقبل كذلك', () {
    final c = ChatController();
    addTearDown(c.dispose);

    c.loadConversation(_conversation('b', ['سؤال']));
    // هذه حرفيّةُ [_pushChunk] — فيها `bool` و`List` و`String` معاً.
    expect(
      () => c.messages.add(<String, dynamic>{
            'role': 'ai',
            'text': '',
            'refs': const <String>[],
            'streaming': true,
            'animating': false,
          }),
      returnsNormally,
    );
  });

  test('☢️ ومحادثةٌ جديدة كذلك', () {
    final c = ChatController();
    addTearDown(c.dispose);

    c.createNewConversation();
    expect(
      () => c.messages.add(<String, dynamic>{'role': 'user', 'text': 'أول رسالة'}),
      returnsNormally,
    );
  });
}
