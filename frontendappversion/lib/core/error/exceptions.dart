// ==========================================
// ⚠️ استثناءات مخصّصة لطبقة الشبكة
// ==========================================

/// يُرمى عندما يرجع السيرفر رمز حالة غير 200 (خطأ من جهة الخادم).
class ServerException implements Exception {
  final int statusCode;
  final String message;
  const ServerException(this.statusCode, [this.message = "Server error"]);

  @override
  String toString() => "ServerException($statusCode): $message";
}
