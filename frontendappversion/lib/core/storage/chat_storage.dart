import 'package:hive_flutter/hive_flutter.dart';
import '../../features/chat/data/models/chat_model.dart';

// ==========================================
// 💾 تخزين المحادثات محلياً عبر Hive
// ==========================================
class ChatStorage {
  static const String _boxName = 'conversations';
  static Box<ChatConversation>? _box;

  // تهيئة Hive
  static Future<void> init() async {
    await Hive.initFlutter();

    // تسجيل المحولات
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(ChatMessageAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(ChatConversationAdapter());
    }

    _box = await Hive.openBox<ChatConversation>(_boxName);
  }

  // حفظ محادثة
  static Future<void> saveConversation(ChatConversation conversation) async {
    await _box?.put(conversation.id, conversation);
  }

  // جلب محادثة
  static ChatConversation? getConversation(String id) {
    return _box?.get(id);
  }

  // جلب كل المحادثات
  static List<ChatConversation> getAllConversations() {
    return _box?.values.toList() ?? [];
  }

  // جلب محادثات مادة معينة
  static List<ChatConversation> getConversationsBySubject(String subject) {
    return _box?.values.where((c) => c.subject == subject).toList() ?? [];
  }

  // حذف محادثة
  static Future<void> deleteConversation(String id) async {
    await _box?.delete(id);
  }

  // حذف كل المحادثات
  static Future<void> clearAll() async {
    await _box?.clear();
  }

  // تحديث آخر استخدام
  static Future<void> updateLastUsed(String id) async {
    final conv = _box?.get(id);
    if (conv != null) {
      conv.lastUpdated = DateTime.now();
      await _box?.put(id, conv);
    }
  }
}
