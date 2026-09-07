// 📬 صندوق إشعارات الطالب — الحلقة التي كانت مقطوعة.
//
// 🔴 **العطل الذي كشفه المالك:** الخادم يحفظ الإشعار في صندوق كل مستلَم،
//    واللوحة تقول بصدق «محفوظ في صناديقهم» — ولم يكن في التطبيق سطرٌ واحد
//    ينادي `/notifications/inbox`. الجرس كان `_snack("لا إشعارات جديدة")`
//    نصّاً ثابتاً بشارةٍ حمراء لا تنطفئ. فالطرفان صادقان ولا شيء بينهما.
//
// ⭐ والأهم بعد الوصل: **لا يُمسح صندوقٌ وصل فعلاً لأن التحديث تعثّر.**
//    إعلانٌ ظهر ثم اختفى لانقطاع شبكةٍ أسوأ من إعلانٍ تأخّر.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ye_student_tutor/core/notifications/notifications_repository.dart';

/// هويةٌ وهمية — قواعد الصندوق هي **قواعدُ هويّة**، فلا تُختبر بلا تحكّمٍ بها.
class _FakeIdentity extends InboxIdentity {
  _FakeIdentity({this.uid = 'u1', this.isGuest = false});

  @override
  final String uid;
  @override
  final bool isGuest;
  @override
  Future<String?> idToken() async => 'tok';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final repo = NotificationsRepository.I;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repo.reset();
    NotificationsRepository.overrideIdentity(_FakeIdentity());
  });

  tearDown(() {
    NotificationsRepository.overrideClient(null);
    NotificationsRepository.overrideIdentity(null);
  });

  Map<String, dynamic> item(String id,
          {String title = 'عنوان', String link = 'none', String at = '2026-08-31T10:00:00+00:00'}) =>
      {'id': id, 'title': title, 'body': 'نص', 'link': link, 'created_at': at};

  http.Client jsonClient(Object body, {int status = 200}) =>
      MockClient((_) async => http.Response(
            jsonEncode(body),
            status,
            headers: {'content-type': 'application/json; charset=utf-8'},
          ));

  group('الوصل بالخادم', () {
    test('ما يحفظه الخادم في الصندوق يصل الشاشة', () async {
      NotificationsRepository.overrideClient(jsonClient({
        'items': [item('n1', title: 'نتائج الوزاري'), item('n2')],
      }));
      await repo.refresh();

      expect(repo.items.length, 2);
      expect(repo.items.first.title, 'نتائج الوزاري');
      expect(repo.unreadCount, 2);
      expect(repo.hasUnread, isTrue);
    });

    test('🔐 الطلب يحمل توكن الحساب — الصندوق يُحدَّد بالتوكن لا بمُعامل', () async {
      String? auth;
      NotificationsRepository.overrideClient(MockClient((req) async {
        auth = req.headers['Authorization'];
        return http.Response(jsonEncode({'items': []}), 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }));
      await repo.refresh();
      expect(auth, 'Bearer tok');
    });

    test('العربية تصل سليمة (فكّ UTF-8 لا الافتراضي)', () async {
      NotificationsRepository.overrideClient(MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({'items': [item('n1', title: 'مبروك النجاح')]})),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          )));
      await repo.refresh();
      expect(repo.items.first.title, 'مبروك النجاح');
    });

    test('عنصرٌ بلا معرّف يُسقَط — لا صفٌّ لا يمكن تعليمه كمقروء', () async {
      NotificationsRepository.overrideClient(jsonClient({
        'items': [item('n1'), {'title': 'بلا معرّف'}],
      }));
      await repo.refresh();
      expect(repo.items.map((n) => n.id), ['n1']);
    });
  });

  group('🛟 التعثّر لا يمحو ما وصل', () {
    test('انقطاع الشبكة يُبقي الصندوق ويرفع علم التعذُّر', () async {
      NotificationsRepository.overrideClient(jsonClient({'items': [item('n1')]}));
      await repo.refresh();

      NotificationsRepository.overrideClient(
          MockClient((_) async => throw const SocketExceptionLike()));
      await repo.refresh();

      expect(repo.items.length, 1, reason: 'إعلانٌ وصل فعلاً لا يختفي لانقطاع شبكة');
      expect(repo.lastRefreshFailed, isTrue);
    });

    test('خطأ ٥٠٠ لا يمسح الصندوق', () async {
      NotificationsRepository.overrideClient(jsonClient({'items': [item('n1')]}));
      await repo.refresh();
      NotificationsRepository.overrideClient(jsonClient({'error': 'x'}, status: 500));
      await repo.refresh();
      expect(repo.items.length, 1);
      expect(repo.lastRefreshFailed, isTrue);
    });

    test('ردٌّ مشوّه بلا `items` لا يمسح الصندوق', () async {
      NotificationsRepository.overrideClient(jsonClient({'items': [item('n1')]}));
      await repo.refresh();
      NotificationsRepository.overrideClient(jsonClient({'ok': true}));
      await repo.refresh();
      expect(repo.items.length, 1);
    });

    test('نجاحٌ بعد فشل يُنزل علم التعذُّر', () async {
      NotificationsRepository.overrideClient(jsonClient({'error': 'x'}, status: 500));
      await repo.refresh();
      expect(repo.lastRefreshFailed, isTrue);
      NotificationsRepository.overrideClient(jsonClient({'items': [item('n1')]}));
      await repo.refresh();
      expect(repo.lastRefreshFailed, isFalse);
    });

    test('صندوقٌ فارغ من الخادم يُفرّغ فعلاً — الحذف من اللوحة يسري', () async {
      NotificationsRepository.overrideClient(jsonClient({'items': [item('n1')]}));
      await repo.refresh();
      NotificationsRepository.overrideClient(jsonClient({'items': []}));
      await repo.refresh();
      expect(repo.items, isEmpty);
      expect(repo.lastRefreshFailed, isFalse, reason: 'فراغٌ صادق ليس عطلاً');
    });
  });

  group('👁️ المقروء وغير المقروء', () {
    setUp(() {
      NotificationsRepository.overrideClient(
          jsonClient({'items': [item('n1'), item('n2'), item('n3')]}));
    });

    test('الشارة تنطفئ حين يُقرأ كل شيء', () async {
      await repo.refresh();
      expect(repo.hasUnread, isTrue);
      await repo.markAllRead();
      expect(repo.unreadCount, 0);
      expect(repo.hasUnread, isFalse,
          reason: 'شارةٌ لا تنطفئ أبداً يتعلّم الطالب تجاهُلها');
    });

    test('قراءة واحدٍ لا تُطفئ البقية', () async {
      await repo.refresh();
      await repo.markRead('n2');
      expect(repo.isRead('n2'), isTrue);
      expect(repo.unreadCount, 2);
    });

    test('⭐ إشعارٌ جديد يوقظ الشارة بعد أن أُطفئت', () async {
      await repo.refresh();
      await repo.markAllRead();
      NotificationsRepository.overrideClient(
          jsonClient({'items': [item('n1'), item('n2'), item('n3'), item('n4')]}));
      await repo.refresh();
      expect(repo.unreadCount, 1);
    });

    test('🧹 معرّفات ما انتهت صلاحيته تُقلَّم فلا تتراكم بلا حدّ', () async {
      await repo.refresh();
      await repo.markAllRead();
      NotificationsRepository.overrideClient(jsonClient({'items': [item('n3')]}));
      await repo.refresh();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getStringList('notifications_read_v1'), ['n3']);
    });

    test('حالة القراءة تبقى بعد إعادة تشغيل التطبيق', () async {
      await repo.refresh();
      await repo.markRead('n1');

      repo.reset();
      await repo.load();
      expect(repo.isRead('n1'), isTrue);
      expect(repo.unreadCount, 2);
    });
  });

  group('🚪 الهوية — صندوقٌ لا يُعرض لغير صاحبه', () {
    test('الزائر لا صندوق له ولا نداءَ شبكة', () async {
      var called = false;
      NotificationsRepository.overrideIdentity(_FakeIdentity(isGuest: true));
      NotificationsRepository.overrideClient(MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }));
      await repo.refresh();
      expect(called, isFalse);
      expect(repo.items, isEmpty);
    });

    test('حسابٌ بلا uid لا يُنادي الخادم', () async {
      var called = false;
      NotificationsRepository.overrideIdentity(_FakeIdentity(uid: ''));
      NotificationsRepository.overrideClient(MockClient((_) async {
        called = true;
        return http.Response('{}', 200);
      }));
      await repo.refresh();
      expect(called, isFalse);
    });

    test('🔴 كاشُ حسابٍ آخر لا يُقرأ — جوّالٌ يتشاركه أخوان', () async {
      NotificationsRepository.overrideClient(jsonClient({'items': [item('n1')]}));
      await repo.refresh();                       // حُفظ باسم u1

      NotificationsRepository.overrideIdentity(_FakeIdentity(uid: 'u2'));
      NotificationsRepository.overrideClient(
          MockClient((_) async => throw const SocketExceptionLike()));
      repo.reset();
      await repo.load();                          // بلا شبكة ⇒ الكاش وحده

      expect(repo.items, isEmpty,
          reason: 'صندوق الأخ لا يُعرض لأخيه ولو للحظةٍ قبل تصحيح الخادم');
    });

    test('الخروج يُفرّغ الصندوق والذاكرةَ والقرص', () async {
      NotificationsRepository.overrideClient(jsonClient({'items': [item('n1')]}));
      await repo.refresh();
      await repo.clear();

      expect(repo.items, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('notifications_cache_v1'), isNull);
      expect(prefs.getString('notifications_owner_v1'), isNull);
    });
  });

  group('⚡ الكاش أولاً', () {
    test('الجرس يفتح على آخر ما وصل قبل أن تردّ الشبكة', () async {
      NotificationsRepository.overrideClient(jsonClient({'items': [item('n1')]}));
      await repo.refresh();

      repo.reset();
      NotificationsRepository.overrideClient(
          MockClient((_) async => throw const SocketExceptionLike()));
      await repo.load();

      expect(repo.items.length, 1, reason: 'بلا شبكةٍ يُعرض المحفوظ لا شاشةٌ فارغة');
    });

    test('الوجهة تبقى مع الإشعار في الكاش — نقرةٌ بلا شبكة تفتح قسمها', () async {
      NotificationsRepository.overrideClient(
          jsonClient({'items': [item('n1', link: 'quiz')]}));
      await repo.refresh();
      repo.reset();
      NotificationsRepository.overrideClient(
          MockClient((_) async => throw const SocketExceptionLike()));
      await repo.load();
      expect(repo.items.first.link, 'quiz');
    });
  });
}

/// عطلُ شبكةٍ بلا استيراد `dart:io` — الاختبارات تعمل على كل منصّة.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
  @override
  String toString() => 'SocketException: failed';
}
