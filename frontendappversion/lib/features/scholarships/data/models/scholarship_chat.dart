import 'package:hive/hive.dart';

part 'scholarship_chat.g.dart';

// ==========================================
// 💬 محادثات مساعد المنحة — نموذج التخزين
// ==========================================
// ⭐ **لماذا محادثات أصلاً؟** سؤال المنحة ليس سؤالاً عابراً: الطالب يسأل عن
//    الشروط اليوم، وعن خطاب الدافع بعد أسبوع، ويحتاج أن يرجع لما قيل له.
//    بلا سجلٍّ يعيد الشرح من الصفر في كل مرة.
//
// 👤 **مربوطة بالحساب (`ownerUid`)**: جوّال واحد قد يستعمله أكثر من حساب —
//    وزائر — فلا يرى حسابٌ محادثاتِ آخر ولو كانا على الجهاز نفسه. نفس
//    السياسة المطبَّقة في محادثات التعليم ونتائج الاختبارات ([28§10]).
//
// 🎓 **مقسومة على المنحة (`scholarshipId`)**: محادثات المنحة التركية لا تظهر
//    في قائمة المنحة الماليزية — تماماً كما ينفصل سجلّ كل مادة في التعليم.
//
// ⚠️ **الترقيم:** 0/1 لمحادثات التعليم، 2/3 لنتائج الاختبارات، و4/5 هنا.
//    أي حقل جديد يُضاف **في نهاية الترقيم مع `defaultValue`** — إعادة ترقيم
//    حقل قائم تُتلف بيانات الأجهزة القديمة.

@HiveType(typeId: 4)
class SchMessage {
  @HiveField(0)
  final String role; // "user" | "ai"

  @HiveField(1)
  final String text;

  @HiveField(2)
  final DateTime timestamp;

  /// 📷 مسارات الصور على **جهاز الطالب** (حتى صورتين).
  /// ⚠️ `defaultValue` إلزامي: بدونه تنهار قراءة الرسائل المحفوظة قبل الحقل.
  /// ⚠️ الصورة نفسها لا تُرفع للسحابة أبداً — يُرفع نصها المستخرج ([27§3]).
  @HiveField(3, defaultValue: <String>[])
  final List<String> imagePaths;

  /// 📄 **نصّ الصورة كما قرأه الخادم** — لا يُعرض في الفقاعة، لكنه يُرسل
  /// ضمن سياق المحادثة في كل سؤال تالٍ.
  ///
  /// ⭐ بدونه تُنسى الصورة فوراً: التاريخ نصٌّ لا صور، فيصير سؤال المتابعة
  ///   («وهل هذا يكفي؟») بلا مرجع. وهو أيضاً ما يُبقي المحادثة مفهومة على
  ///   جهاز جديد حيث لم يعد ملف الصورة موجوداً أصلاً.
  @HiveField(4, defaultValue: "")
  final String imageText;

  SchMessage({
    required this.role,
    required this.text,
    DateTime? timestamp,
    this.imagePaths = const [],
    this.imageText = "",
  }) : timestamp = timestamp ?? DateTime.now();

  bool get isUser => role == "user";
  bool get hasImages => imagePaths.isNotEmpty;

  Map<String, dynamic> toMap() => {
        "role": role,
        "text": text,
        "ts": timestamp.toIso8601String(),
        // نرفع **العدد** لا المسار: المسار بلا معنى على جهاز آخر،
        // ويسمح لنا بعرض «الصورة لم تعد متاحة» عند الاستعادة.
        if (imagePaths.isNotEmpty) "images_count": imagePaths.length,
        // ★ النصّ يُرفع (لا الصورة): به تبقى المحادثة مفهومة على جهاز جديد.
        if (imageText.isNotEmpty) "image_text": imageText,
      };

  factory SchMessage.fromMap(Map m) => SchMessage(
        role: (m["role"] ?? "user").toString(),
        text: (m["text"] ?? "").toString(),
        timestamp: DateTime.tryParse((m["ts"] ?? "").toString()) ?? DateTime.now(),
        imageText: (m["image_text"] ?? "").toString(),
      );

  /// ما يُرسل للخادم في سياق المحادثة: كلام الطالب **ومعه نصّ صورته**.
  String get contextText =>
      imageText.isEmpty ? text : (text.isEmpty ? imageText : "$text\n$imageText");
}

@HiveType(typeId: 5)
class SchConversation {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  /// معرّف المنحة — مفتاح فصل السجلات.
  @HiveField(2)
  final String scholarshipId;

  /// اسم المنحة وقت الإنشاء — تُعرض في القائمة بلا انتظار تحميل المنح.
  @HiveField(3)
  final String scholarshipName;

  @HiveField(4)
  final List<SchMessage> messages;

  @HiveField(5)
  final DateTime createdAt;

  @HiveField(6)
  DateTime lastUpdated;

  /// 👤 مالك المحادثة = `uid` الحساب الذي أنشأها.
  @HiveField(7, defaultValue: "")
  String ownerUid;

  /// هل رُفعت للسحابة؟ (لإعادة المحاولة عند عودة الاتصال)
  @HiveField(8, defaultValue: false)
  bool synced;

  SchConversation({
    required this.id,
    required this.title,
    required this.scholarshipId,
    required this.scholarshipName,
    List<SchMessage>? messages,
    DateTime? createdAt,
    DateTime? lastUpdated,
    this.ownerUid = "",
    this.synced = false,
  })  : messages = messages ?? <SchMessage>[],
        createdAt = createdAt ?? DateTime.now(),
        lastUpdated = lastUpdated ?? DateTime.now();

  /// أول سؤال حقيقي للطالب هو العنوان — لا «محادثة ١» بلا معنى.
  /// (رسالة الترحيب من المساعد لا تصلح عنواناً: هي نفسها في كل محادثة.)
  void retitleFromFirstQuestion() {
    final first = messages.where((m) => m.isUser).map((m) => m.text).firstOrNull;
    if (first == null || first.trim().isEmpty) return;
    final clean = first.trim().replaceAll(RegExp(r'\s+'), ' ');
    title = clean.length <= 38 ? clean : "${clean.substring(0, 38)}…";
  }

  /// آخر سطر يظهر تحت العنوان في القائمة الجانبية.
  String get preview {
    if (messages.isEmpty) return "محادثة جديدة";
    final last = messages.last.text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return last.length <= 60 ? last : "${last.substring(0, 60)}…";
  }

  int get questionCount => messages.where((m) => m.isUser).length;

  Map<String, dynamic> toDoc() => {
        "title": title,
        "scholarship_id": scholarshipId,
        "scholarship_name": scholarshipName,
        "messages": messages.map((m) => m.toMap()).toList(),
        "created_at": createdAt.toIso8601String(),
        "last_updated": lastUpdated.toIso8601String(),
      };

  static SchConversation fromDoc(String id, Map<String, dynamic> d) => SchConversation(
        id: id,
        title: (d["title"] ?? "محادثة").toString(),
        scholarshipId: (d["scholarship_id"] ?? "").toString(),
        scholarshipName: (d["scholarship_name"] ?? "").toString(),
        messages: ((d["messages"] as List?) ?? const [])
            .map((m) => SchMessage.fromMap(Map.from(m as Map)))
            .toList(),
        createdAt: DateTime.tryParse((d["created_at"] ?? "").toString()) ?? DateTime.now(),
        lastUpdated: DateTime.tryParse((d["last_updated"] ?? "").toString()) ?? DateTime.now(),
        synced: true,
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
