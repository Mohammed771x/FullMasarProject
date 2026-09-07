// 🧪 المحفوظات — البصمة، الملكية، التبديل، السقف.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/features/saved/data/saved_storage.dart';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('saved_test');
    await SavedStorage.initForTests(dir.path);
  });

  tearDown(() async => dir.delete(recursive: true));

  Future<bool> save(String uid, String text) => SavedStorage.toggle(
        ownerUid: uid,
        section: 'education',
        subject: 'احياء',
        text: text,
      );

  test('الحفظ ثم الإزالة — نفس الزر يبدّل الحالة', () async {
    expect(SavedStorage.isSaved('u1', 'جواب'), isFalse);
    expect(await save('u1', 'جواب'), isTrue);
    expect(SavedStorage.isSaved('u1', 'جواب'), isTrue);
    expect(await save('u1', 'جواب'), isFalse);
    expect(SavedStorage.isSaved('u1', 'جواب'), isFalse);
  });

  test('👤 محفوظات كل حساب لا يراها غيره', () async {
    await save('u1', 'جواب');
    expect(SavedStorage.isSaved('u2', 'جواب'), isFalse);
    expect(SavedStorage.all('u2'), isEmpty);
    expect(SavedStorage.all('u1'), hasLength(1));
  });

  test('النصّ نفسه لا يُحفظ مرّتين', () async {
    await save('u1', 'جواب');
    await SavedStorage.toggle(
        ownerUid: 'u1', section: 'teacher', subject: 'فيزياء', text: 'جواب');
    // التبديل الثاني أزالها — لا نسخة ثانية.
    expect(SavedStorage.count('u1'), 0);
  });

  test('البصمة ثابتة ولا تتأثّر بالمسافات الطرفية', () {
    expect(SavedStorage.fingerprint('u1', ' نص '),
        SavedStorage.fingerprint('u1', 'نص'));
    expect(SavedStorage.fingerprint('u1', 'نص'),
        isNot(SavedStorage.fingerprint('u2', 'نص')));
  });

  test('العنوان يتخطّى علامات الماركداون', () async {
    await save('u1', '### **عنوان الدرس**\nتفاصيل');
    expect(SavedStorage.all('u1').first.title, 'عنوان الدرس');
  });

  test('السقف يحذف الأقدم لا الأحدث', () async {
    for (var i = 0; i < SavedStorage.maxPerUser + 5; i++) {
      await save('u1', 'جواب رقم $i');
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    expect(SavedStorage.count('u1'), SavedStorage.maxPerUser);
    // الأحدث باقٍ، والأقدم ذهب.
    expect(SavedStorage.isSaved('u1', 'جواب رقم ${SavedStorage.maxPerUser + 4}'),
        isTrue);
    expect(SavedStorage.isSaved('u1', 'جواب رقم 0'), isFalse);
  });
}
