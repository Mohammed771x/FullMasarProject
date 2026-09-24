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

  // ══════════════════════════════════════════════════
  // 🧭 **سياقُ الدرس** — ما كان يضيع بين الحفظ والاستعادة
  // ══════════════════════════════════════════════════
  //
  // 🔴 كانت المحادثة تحفظ (صفاً · مساراً · مادةً · فرعاً · وضعاً) وتترك
  //    **الوحدةَ والدرسَ ووضعَ المحتوى**. فمحادثةٌ في «وضع الدروس» تعود
  //    بمادتها صحيحةً و`selectedV3Lesson` فارغاً — والبوصلة أعلى الشاشة
  //    تعرض «انجليزي • القواعد» بلا درس. ولو أرسل الطالبُ رسالةً لذهبت
  //    باسم درسٍ فارغ، فيردّ الخادم «قيد الإضافة» على مادةٍ محتواها
  //    موجود: كلُّ شيءٍ يبدو سليماً والجوابُ وحده خاطئ.
  //
  // 🗄️ **والترقيم يمضي في الذيل** كما فعل الصفُّ والمالكُ قبله:
  //    `defaultValue: ""` تجعل كلَّ محادثةٍ محفوظةٍ قبل اليوم تُقرأ
  //    **بلا سياق** بدل أن تنهار قراءتُها — وهو بالضبط سلوكُها الحالي،
  //    فالترقية لا تُغيّر شيئاً على القديم ولا تطلب ترحيلاً.

  /// وحدةُ الدرس (`selectedV3Unit` في وضع الدروس · `selectedUnit` في الصفحات).
  @HiveField(11, defaultValue: "")
  final String unit;

  /// اسمُ الدرس المفتوح — فارغٌ في المحادثات الحرّة وفي القديمة.
  @HiveField(12, defaultValue: "")
  final String lesson;

  /// `"lessons"` أو `"pages"` — فارغٌ يعني «لم تُحفظ» فيُترك القرار للقدرات.
  @HiveField(13, defaultValue: "")
  final String contentMode;

  /// 📄 **صفحاتُ المحادثة** في وضع الوحدات — تعود معها كما يعود درسُها.
  ///
  /// 🎯 **بلاغ المالك (٢٠٢٦-٠٩-٢٤):** «محادثةٌ قديمة، اخترتُ فيها ثلاث
  ///    صفحات… نزلتُ ورجعت فما وجدتُ ما كنّا نناقشه. لكل شاتٍ درسُه —
  ///    ولو رجعتُ بعد سنة». الوحدةُ كانت تُحفظ والصفحاتُ لا.
  ///    وهي أيضاً **حدُّ المحادثة**: لا تُضاف إليها صفحةٌ من خارجها
  ///    ([ChatController.addPage]).
  @HiveField(14, defaultValue: <int>[])
  final List<int> pages;

  /// 📏 **٣ صفحاتٍ لا أكثر** — `MAX_PAGES_EXPLAIN_SUMMARY` في الخادم، وسقفُ
  ///    `pages` في `firestore.rules`. الثلاثةُ تتغيّر معاً أو لا تتغيّر.
  static const int maxPages = 3;

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
    this.unit = "",
    this.lesson = "",
    this.contentMode = "",
    this.pages = const [],
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
    'unit': unit,
    'lesson': lesson,
    'contentMode': contentMode,
    'pages': pages,
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
    // 🗄️ محادثاتٌ سُحبت من السحابة قبل هذه الحقول تصل بلا سياق — تُقرأ
    //    فارغةً كما كانت تُقرأ تماماً، ولا تُسقط الاستعادة.
    unit: json['unit'] ?? "",
    lesson: json['lesson'] ?? "",
    contentMode: json['contentMode'] ?? "",
    pages: _pagesFrom(json['pages']),
  );

  /// أرقامٌ صحيحة موجبة وحدها — مستندٌ تالفٌ أو قديمٌ يُقرأ بلا صفحات.
  static List<int> _pagesFrom(Object? raw) => raw is List
      ? [for (final p in raw) if (p is int && p > 0) p].take(maxPages).toList()
      : const [];

  /// للمزامنة: نفسُ التطبيع لمستند Firestore.
  static List<int> pagesFrom(Object? raw) => _pagesFrom(raw);
}
