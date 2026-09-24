// 🛑 إيقاف الطلب الجاري — الحارس الذي يمنع ردّاً «متأخراً» من الظهور.
//
// 🔴 **الخطر الذي يحرسه هذا الملف:** إغلاق الاتصال وحده لا يكفي. الرد قد
//    يكون في الطريق أصلاً لحظة الضغط على «إيقاف»، أو يعود بعد أن انتقل
//    الطالب لمحادثة أخرى — فيُلحق بالمحادثة الخطأ. حارس التسلسل يطرح كل
//    ردٍّ لا يطابق رقمه الحالي.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:ye_student_tutor/features/scholarships/data/models/scholarship.dart';
import 'package:ye_student_tutor/features/scholarships/data/scholarship_chat_storage.dart';
import 'package:ye_student_tutor/features/scholarships/data/scholarship_repository.dart';
import 'package:ye_student_tutor/features/scholarships/presentation/controllers/scholarship_chat_controller.dart';

/// عميل بطيء نتحكّم في لحظة ردّه — يحاكي خادماً يتأخر.
class _SlowClient extends http.BaseClient {
  final Completer<void> gate = Completer<void>();
  int calls = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    calls++;
    await gate.future;
    return http.StreamedResponse(
      // ⚠️ `utf8.encode` لا `codeUnits`: العربية في UTF-16 تُفسد فكّ الترميز.
      Stream.value(utf8.encode('{"answer":"رد متأخر","ok":true}')),
      200,
    );
  }
}

/// خادمٌ يردّ 202 «قيد المعالجة» أولاً ثم يُسلّم الجواب — تماماً كما يفعل
/// حارسُ التكرار حين تصل محاولةٌ ثانيةٌ بنفس `request_id`.
class _PendingThenAnswerClient extends http.BaseClient {
  final List<Map<String, dynamic>> bodies = [];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    bodies.add(
        jsonDecode((request as http.Request).body) as Map<String, dynamic>);
    if (bodies.length == 1) {
      return http.StreamedResponse(
        Stream.value(
            utf8.encode('{"answer":"طلبك قيد المعالجة","in_flight":true}')),
        202,
      );
    }
    // ⚠️ والمحاولةُ الثانية تُبَثّ بصيغة SSE لا جسماً عارياً: ذاك ما
    //    يرسله الخادم على 200، وبدونه يقرأ العميل «إغلاقاً بلا `done`».
    final done = jsonEncode(
        {"t": "done", "answer": "آخر موعد ٣٠ يونيو", "ok": true});
    return http.StreamedResponse(
      Stream.value(utf8.encode('data: $done\n\n')),
      200,
    );
  }
}

final _sch = Scholarship.fromJson(
    {"id": "turkey", "name": "المنحة التركية", "country": "تركيا"});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('masar_stop_test');
    await SchChatStorage.initForTests(dir.path);
  });
  setUp(() async => SchChatStorage.clearAll());
  tearDownAll(() async => dir.delete(recursive: true));

  test('🛑 الإيقاف يطرح الرد المتأخر ولا يُظهره', () async {
    final slow = _SlowClient();
    final c = ScholarshipChatController(
        scholarship: _sch, repository: ScholarshipRepository(slow))
      ..start();

    final pending = c.send("متى آخر موعد؟");
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(c.isSending, isTrue);
    expect(c.messages.length, 1);          // سؤال الطالب حُفظ فوراً

    c.stop();                              // 🛑 الطالب يوقف
    expect(c.isSending, isFalse);

    slow.gate.complete();                  // الرد يصل **بعد** الإيقاف
    await pending;

    // ⭐ لا يُضاف: سؤال الطالب وحده يبقى.
    expect(c.messages.length, 1);
    expect(c.messages.single.isUser, isTrue);
    c.dispose();
  });

  test('سؤال الطالب يبقى محفوظاً بعد الإيقاف', () async {
    final slow = _SlowClient();
    final c = ScholarshipChatController(
        scholarship: _sch, repository: ScholarshipRepository(slow))
      ..start();

    final pending = c.send("ما الشروط؟");
    await Future<void>.delayed(const Duration(milliseconds: 20));
    c.stop();
    slow.gate.complete();
    await pending;

    // ما كتبه الطالب لا يضيع — أُضيف قبل الشبكة عن قصد.
    expect(c.messages.single.text, "ما الشروط؟");
    c.dispose();
  });

  test('محادثة جديدة أثناء الانتظار ⇒ الرد القديم لا يلحق بها', () async {
    final slow = _SlowClient();
    final c = ScholarshipChatController(
        scholarship: _sch, repository: ScholarshipRepository(slow))
      ..start();

    final pending = c.send("سؤال قديم");
    await Future<void>.delayed(const Duration(milliseconds: 20));

    c.newChat();                           // ينتقل لمحادثة فارغة
    slow.gate.complete();
    await pending;

    expect(c.messages, isEmpty);           // ⭐ لم يُلحق شيء بالجديدة
    c.dispose();
  });

  // ══════════════════════════════════════════════════
  // 🔁 202 ليس جواباً — نفسُ قاعدة قسم التعليم حرفياً
  // ══════════════════════════════════════════════════
  //
  // 🔴 **ما كان يحدث:** حارسُ التكرار يردّ 202 بنصٍّ عربيّ («طلبك قيد
  //    المعالجة»)، وكان العميل يراه جواباً مكتملاً فيعرضه في الفقاعة —
  //    فيقرأ الطالب جملةً إداريةً مكان ردّ المساعد، والردُّ الحقيقي الذي
  //    يُولّده الخادم في تلك اللحظة يُلقى في القمامة.
  //
  // ⚖️ والصواب: نفسُ `request_id` ونفسُ الحمولة حتى يتحوّل إلى جواب —
  //    فلا حصةٌ ثانيةٌ تُخصم ولا نداءُ موديلٍ يتكرّر.
  test('202 قيد المعالجة يُعاد الاستعلام لا يُعرض جواباً', () async {
    final client = _PendingThenAnswerClient();
    final c = ScholarshipChatController(
        scholarship: _sch, repository: ScholarshipRepository(client))
      ..start();

    await c.send("متى آخر موعد؟");

    expect(client.bodies, hasLength(2), reason: 'لم يُعد الاستعلام أصلاً');
    expect(client.bodies[1]["request_id"], client.bodies[0]["request_id"],
        reason: 'معرّفٌ جديد ⇒ خصمُ حصةٍ ثانيةٍ ونداءٌ ثانٍ للموديل');
    expect(client.bodies[1], client.bodies[0], reason: 'الحمولة تغيّرت');

    final replies = c.messages.where((m) => !m.isUser).toList();
    expect(replies, hasLength(1));
    expect(replies.single.text, contains("٣٠ يونيو"));
    expect(replies.single.text, isNot(contains("قيد المعالجة")));
    c.dispose();
  });

  test('الإيقاف بلا طلب جارٍ لا يفعل شيئاً', () {
    final c = ScholarshipChatController(
        scholarship: _sch, repository: ScholarshipRepository(_SlowClient()))
      ..start();
    c.stop();
    expect(c.isSending, isFalse);
    c.dispose();
  });
}
