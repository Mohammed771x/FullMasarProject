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

  test('الإيقاف بلا طلب جارٍ لا يفعل شيئاً', () {
    final c = ScholarshipChatController(
        scholarship: _sch, repository: ScholarshipRepository(_SlowClient()))
      ..start();
    c.stop();
    expect(c.isSending, isFalse);
    c.dispose();
  });
}
