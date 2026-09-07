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

  /// 📷 مسار صورة واحدة (حقل قديم — يبقى للتوافق مع الرسائل المحفوظة).
  @HiveField(4, defaultValue: "")
  final String imagePath;

  /// 📷 مسارات الصور المرفقة على جهاز الطالب (حتى صورتين).
  /// ⚠️ defaultValue إلزامي: بدونه تنهار قراءة الرسائل المحفوظة قبل هذا الحقل.
  @HiveField(5, defaultValue: <String>[])
  final List<String> imagePaths;

  /// 📄 **نصّ الصورة كما قرأه الخادم** — لا يُعرض، لكنه يُرسل في السياق.
  /// ⭐ بدونه تُنسى الصورة في السؤال التالي (التاريخ نصٌّ لا صور)، وتصير
  ///   المحادثة المستعادة على جهاز جديد بلا معنى.
  @HiveField(6, defaultValue: "")
  final String imageText;

  /// كل الصور موحّدةً من الحقلين (الجديد أولاً ثم القديم).
  List<String> get allImages =>
      imagePaths.isNotEmpty ? imagePaths : (imagePath.isEmpty ? const [] : [imagePath]);

  /// ما يُرسل في سياق المحادثة: كلام الطالب ومعه نصّ صورته.
  String get contextText =>
      imageText.isEmpty ? text : (text.isEmpty ? imageText : "$text\n$imageText");

  ChatMessage({
    required this.role,
    required this.text,
    this.refs = const [],
    DateTime? timestamp,
    this.imagePath = "",
    this.imagePaths = const [],
    this.imageText = "",
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    'refs': refs,
    'timestamp': timestamp.toIso8601String(),
    'imagePath': imagePath,
    'imagePaths': imagePaths,
    'imageText': imageText,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    role: json['role'],
    text: json['text'],
    refs: List<String>.from(json['refs'] ?? []),
    timestamp: DateTime.parse(json['timestamp']),
    imagePath: json['imagePath'] ?? "",
    imagePaths: List<String>.from(json['imagePaths'] ?? const []),
    imageText: json['imageText'] ?? "",
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

  // ── حقول جديدة (أُضيفت في نهاية الترقيم فلا تكسر البيانات القديمة) ──

  /// الصف الدراسي 1|2|3. المحادثات القديمة تُعتبر الصف الثالث.
  /// ⚠️ defaultValue إلزامي: بدونه تنهار قراءة المحادثات المحفوظة قبل هذا الحقل.
  @HiveField(7, defaultValue: 3)
  final int grade;

  /// المسار: "عام" | "علمي" | "أدبي".
  @HiveField(8, defaultValue: "علمي")
  final String track;

  /// فرع الرياضيات (تفاضل/تكامل/...) — فارغ لبقية المواد.
  @HiveField(9, defaultValue: "")
  final String branch;

  /// 👤 **مالك المحادثة** = `uid` الحساب الذي أنشأها.
  /// جوّال واحد قد يستعمله أكثر من حساب (وزائر): كل حساب يرى محادثاته وحدها.
  /// ⚠️ `defaultValue: ""` إلزامي — المحادثات المحفوظة قبل هذا الحقل تُعتبر
  ///    «بلا مالك» ويتبنّاها أول حساب يسجّل الدخول (ترحيل مرة واحدة).
  @HiveField(10, defaultValue: "")
  String ownerUid;

  ChatConversation({
    required this.id,
    required this.title,
    required this.subject,
    required this.mode,
    this.messages = const [],
    DateTime? createdAt,
    DateTime? lastUpdated,
    this.grade = 3,
    this.track = "علمي",
    this.branch = "",
    this.ownerUid = "",
  }) : createdAt = createdAt ?? DateTime.now(),
       lastUpdated = lastUpdated ?? DateTime.now();

  /// مفتاح النطاق: المحادثات تُفلتر به في القائمة الجانبية.
  /// كل (صف + مسار + مادة + فرع + وضع) له سجلّ محادثات مستقل.
  String get scopeKey => buildScopeKey(
        grade: grade,
        track: track,
        subject: subject,
        branch: branch,
        mode: mode,
      );

  static String buildScopeKey({
    required int grade,
    required String track,
    required String subject,
    required String branch,
    required String mode,
  }) =>
      "g$grade|$track|$subject|$branch|$mode";

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'mode': mode,
    'messages': messages.map((m) => m.toJson()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'lastUpdated': lastUpdated.toIso8601String(),
    'grade': grade,
    'track': track,
    'branch': branch,
    'ownerUid': ownerUid,
  };

  factory ChatConversation.fromJson(Map<String, dynamic> json) => ChatConversation(
    id: json['id'],
    title: json['title'],
    subject: json['subject'],
    mode: json['mode'],
    messages: (json['messages'] as List).map((m) => ChatMessage.fromJson(m)).toList(),
    createdAt: DateTime.parse(json['createdAt']),
    lastUpdated: DateTime.parse(json['lastUpdated']),
    grade: json['grade'] ?? 3,
    track: json['track'] ?? "علمي",
    branch: json['branch'] ?? "",
    ownerUid: json['ownerUid'] ?? "",
  );
}
