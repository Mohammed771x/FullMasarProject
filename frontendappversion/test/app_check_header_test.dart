import 'package:flutter_test/flutter_test.dart';
import 'package:ye_student_tutor/core/network/api_client.dart';
import 'package:ye_student_tutor/core/security/app_check_service.dart';

// 📱 App Check (فحص الأمان 2026-10-01): الخادمُ يقرأ `X-Firebase-AppCheck`
//    قبل أي نداء موديل ([Backend/core/app_check.py]). وكلُّ نداءٍ في التطبيق
//    يمرّ بـ`ApiClient.authHeaders` — فهنا موضعٌ واحد يكفي لحراسته.
void main() {
  tearDown(() => AppCheckService.tokenForTest = null);

  test('يُرسل توكن App Check مع التوثيق متى وُجد', () {
    AppCheckService.tokenForTest = 'ac-token';
    final h = ApiClient.authHeaders('id-token');
    expect(h['Authorization'], 'Bearer id-token');
    expect(h['X-Firebase-AppCheck'], 'ac-token');
    expect(h['Content-Type'], 'application/json');
  });

  test('بلا توكنٍ بعد: لا ترويسة فارغة — الطلبُ يمضي كما كان', () {
    AppCheckService.tokenForTest = null;
    expect(ApiClient.authHeaders('id-token').containsKey('X-Firebase-AppCheck'), isFalse);
    AppCheckService.tokenForTest = '';
    expect(ApiClient.authHeaders('id-token').containsKey('X-Firebase-AppCheck'), isFalse);
  });
}
