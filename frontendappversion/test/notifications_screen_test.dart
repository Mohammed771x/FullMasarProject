// 📬 شاشة الإشعارات — ما يراه الطالب فعلاً حين يفتح الجرس.
//
// 🔴 الاختبار الأول هنا هو العطل نفسه حرفياً: إشعارٌ حفظه الخادم **يُرى**.
//    فحصُ المستودع وحده كان سيمرّ حتى لو بقي الجرس يعرض نصّاً ثابتاً.
//
// ⚠️ والشاشة تُحدِّث عند الفتح (الطالب يفتح الجرس لأنه يتوقّع جديداً)، فكل
//    اختبارٍ هنا يمرّ بالشبكة الوهمية لا بالبذر وحده — وإلا اختبرنا حالةً
//    لا تقع في التطبيق أصلاً.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ye_student_tutor/core/notifications/notifications_repository.dart';
import 'package:ye_student_tutor/features/future_masar/presentation/screens/notifications_screen.dart';

class _FakeIdentity extends InboxIdentity {
  const _FakeIdentity();
  @override
  String get uid => 'u1';
  @override
  bool get isGuest => false;
  @override
  Future<String?> idToken() async => 'tok';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = NotificationsRepository.I;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo.reset();
    NotificationsRepository.overrideIdentity(const _FakeIdentity());
  });

  tearDown(() {
    NotificationsRepository.overrideClient(null);
    NotificationsRepository.overrideIdentity(null);
  });

  Map<String, dynamic> item(String id,
          {String title = 'إعلان', String link = 'none'}) =>
      {
        'id': id,
        'title': title,
        'body': 'تفاصيل الإعلان',
        'link': link,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      };

  /// يُشغّل الشاشة على صندوقٍ يعيده الخادم — الطريق الحقيقي في التطبيق.
  Future<void> pumpWith(WidgetTester tester, List<Map<String, dynamic>> items) async {
    NotificationsRepository.overrideClient(MockClient((_) async => http.Response.bytes(
          utf8.encode(jsonEncode({'items': items})),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        )));
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: NotificationsScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('🔴 إشعارٌ حفظه الخادم يُرى في الشاشة', (tester) async {
    await pumpWith(tester, [item('n1', title: 'نتائج الوزاري ظهرت')]);

    expect(find.text('نتائج الوزاري ظهرت'), findsOneWidget);
    expect(find.text('لا إشعارات بعد'), findsNothing);
  });

  testWidgets('صندوقٌ فارغ يقول ذلك بلطف لا برسالة عطل', (tester) async {
    await pumpWith(tester, const []);
    expect(find.text('لا إشعارات بعد'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_rounded), findsNothing);
  });

  testWidgets('اسم القسم الذي تفتحه الوجهة يُعرض للطالب', (tester) async {
    await pumpWith(tester, [item('n1', link: 'quiz')]);
    expect(find.text('اختبر نفسك'), findsOneWidget);
  });

  testWidgets('إشعارٌ بلا وجهة لا يَعِد بفتح شيء', (tester) async {
    await pumpWith(tester, [item('n1', link: 'none')]);
    for (final label in ['التعليم', 'اختبر نفسك', 'المنح', 'مساعد المعلم']) {
      expect(find.text(label), findsNothing, reason: label);
    }
  });

  testWidgets('النقر يُعلّم الإشعار مقروءاً', (tester) async {
    await pumpWith(tester, [item('n1'), item('n2')]);
    expect(repo.unreadCount, 2);

    await tester.tap(find.text('إعلان').first);
    await tester.pumpAndSettle();
    expect(repo.unreadCount, 1);
  });

  testWidgets('«تعليم الكل كمقروء» يظهر وقت الحاجة وحدها', (tester) async {
    await pumpWith(tester, [item('n1')]);
    expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.done_all_rounded));
    await tester.pumpAndSettle();
    expect(repo.unreadCount, 0);
    expect(find.byIcon(Icons.done_all_rounded), findsNothing,
        reason: 'زرٌّ بلا أثرٍ يبقى معروضاً يوحي بأن الضغطة لم تنجح');
  });

  testWidgets('🛟 تعذُّر التحديث يُقال فوق الصندوق ولا يمحوه', (tester) async {
    // إعلانٌ وصل أمس ومحفوظ في الكاش، ثم انقطعت الشبكة.
    await pumpWith(tester, [item('n1', title: 'إعلانٌ وصل أمس')]);
    NotificationsRepository.overrideClient(
        MockClient((_) async => throw const _Offline()));

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(find.text('إعلانٌ وصل أمس'), findsOneWidget,
        reason: 'إعلانٌ وصل فعلاً لا يختفي لانقطاع شبكة');
    expect(find.byIcon(Icons.wifi_off_rounded), findsOneWidget);
  });
}

class _Offline implements Exception {
  const _Offline();
  @override
  String toString() => 'SocketException: failed';
}
