import 'package:hive/hive.dart';

part 'chat_model.g.dart';

@HiveType(typeId: 0)
class ChatMessage {
  @HiveField(0)
  final String role; // "user" or "ai"
  
  @HiveField(1)
  final String text;
  
  @HiveField(2)
  final List<String> refs;
  
  @HiveField(3)
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.text,
    this.refs = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    'refs': refs,
    'timestamp': timestamp.toIso8601String(),
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'],
    text: json['text'],
    refs: List<String>.from(json['refs'] ?? []),
    timestamp: DateTime.parse(json['timestamp']),
  );
}

@HiveType(typeId: 1)
class ChatConversation {
  @HiveField(0)
  final String id;
  
  @HiveField(1)
  String title;
  
  @HiveField(2)
  final String subject;
  
  @HiveField(3)
  final String mode;
  
  @HiveField(4)
  final List<ChatMessage> messages;
  
  @HiveField(5)
  final DateTime createdAt;
  
  @HiveField(6)
  DateTime lastUpdated;

  ChatConversation({
    required this.id,
    required this.title,
    required this.subject,
    required this.mode,
    this.messages = const [],
    DateTime? createdAt,
    DateTime? lastUpdated,
  }) : createdAt = createdAt ?? DateTime.now(),
       lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'mode': mode,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'lastUpdated': lastUpdated.toIso8601String(),
  };

  factory ChatConversation.fromJson(Map<String, dynamic> json) => ChatConversation(
    id: json['id'],
    title: json['title'],
    subject: json['subject'],
    mode: json['mode'],
    messages: (json['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList(),
    createdAt: DateTime.parse(json['createdAt']),
    lastUpdated: DateTime.parse(json['lastUpdated']),
  );
}