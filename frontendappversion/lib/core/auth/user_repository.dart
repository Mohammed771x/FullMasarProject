import 'package:cloud_firestore/cloud_firestore.dart';

// ==========================================
// 👤 مستودع مستند المستخدم — users/{uid}
// ==========================================
// المصدر السحابي لبيانات الحساب (الاسم، الصف، المسار، الإعدادات).
// التطبيق يعرض من الكاش المحلي دائماً، وهذا يزامنه — فلا شاشة تنتظر الشبكة.
//
// 🔒 `role` يكتبه التطبيق **من قائمةٍ مغلقة** (`student` أو `teacher`) لا غير.
//    و`admin` يبقى ممنوعاً منعاً باتاً — تفرضه قواعد الأمان أولاً، ويحرسه
//    [AppRole.sanitize] هنا ثانياً ([07§2]). فالدور شكلُ واجهةٍ يختاره صاحبه،
//    أما الامتياز الإداري فلا يُمنح إلا من خارج التطبيق.

/// أدوار الحساب — قائمة مغلقة، وما عداها يُقرأ «طالباً».
class AppRole {
  static const student = "student";
  static const teacher = "teacher";

  /// الأدوار التي يجوز للتطبيق كتابتها. **`admin` ليس منها أبداً.**
  static const writable = [student, teacher];

  /// يعيد دوراً صالحاً للكتابة — وأي شيء آخر (بما فيه `admin`) يصير طالباً.
  static String sanitize(Object? raw) {
    final v = (raw ?? "").toString().trim();
    return writable.contains(v) ? v : student;
  }

  /// يقرأ الدور للعرض: `admin` يُعامَل معاملة الطالب في الواجهة.
  static String read(Object? raw) => sanitize(raw);
}

class UserProfile {
  final String uid;
  final String name;
  final String email;
  final int grade;
  final String track;
  final String photoUrl;
  final bool isGuest;

  /// `student` أو `teacher` — يحكم أيّ واجهةٍ يرى صاحب الحساب.
  final String role;

  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.grade,
    required this.track,
    this.photoUrl = "",
    this.isGuest = false,
    this.role = AppRole.student,
  });

  bool get isTeacher => role == AppRole.teacher;

  factory UserProfile.fromMap(String uid, Map<String, dynamic> m) => UserProfile(
        uid: uid,
        name: (m["name"] ?? "").toString(),
        email: (m["email"] ?? "").toString(),
        grade: (m["grade"] is int) ? m["grade"] as int : 3,
        track: (m["track"] ?? "علمي").toString(),
        photoUrl: (m["photo_url"] ?? "").toString(),
        isGuest: m["is_anonymous"] == true,
        role: AppRole.read(m["role"]),
      );
}

class UserRepository {
  UserRepository([FirebaseFirestore? db]) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> _doc(String uid) => _db.collection("users").doc(uid);

  /// 👤 **أيُّ صورةٍ تبقى؟** يعيد ما يُكتب، أو `null` أي «لا تلمس الحقل».
  ///
  /// صورة الطالب المرفوعة **أولى** من صورة مزوّد الدخول: الأولى اختيارٌ صريح،
  /// والثانية افتراضٌ يصل مجاناً مع كل جلسة جوجل. وكتابتها بلا شرط كانت
  /// تمحو ما رفعه الطالب — يرفع صورته، يخرج، يدخل، فيجدها عادت صورة جوجل.
  static String? resolvePhotoUrl({
    required String existing,
    required String incoming,
  }) {
    if (existing.trim().isNotEmpty) return null;  // موجودة ⇒ لا تُمَس
    if (incoming.trim().isEmpty) return null;     // لا جديد ⇒ لا كتابة فارغة
    return incoming.trim();
  }

  /// ينشئ المستند عند أول دخول، ويحدّث الحقول المتغيّرة بعدها.
  ///
  /// ⚠️ [role] يُكتب **عند الإنشاء وحده** — تبديله بعدها يمرّ بـ[setRole].
  ///    سببه أن `upsert` تُنادى عند كل دخولٍ بجوجل بقيمها الافتراضية، فكتابةُ
  ///    الدور فيها بلا شرط كانت تُرجع معلّماً إلى «طالب» في كل مرة يدخل.
  ///
  /// يعيد `true` إن **أنشأ** المستند الآن، و`false` إن كان قائماً — والفرق
  /// يهمّ المُنادي: مستندٌ قائم يعني أن السحابة هي مرجع الدور لا ما في الجهاز.
  Future<bool> upsert({
    required String uid,
    required String name,
    required String email,
    required int grade,
    required String track,
    String photoUrl = "",
    bool isGuest = false,
    String role = AppRole.student,
  }) async {
    final ref = _doc(uid);
    final snap = await ref.get();
    final data = <String, dynamic>{
      "name": name,
      "email": email,
      "grade": grade,
      "track": track,
      "is_anonymous": isGuest,
      "updated_at": FieldValue.serverTimestamp(),
    };

    // 👤 **صورة الطالب المرفوعة أولى من صورة مزوّد الدخول.**
    //    `upsert` تُنادى عند **كل** دخول بجوجل ومعها `photoURL` من جوجل،
    //    فكتابتها بلا شرط كانت تمحو الصورة التي رفعها الطالب بنفسه: يرفع
    //    صورته، يخرج، يدخل، فيجدها عادت صورة جوجل. الأولى اختيارٌ صريح
    //    والثانية افتراضٌ يأتي مجاناً مع كل جلسة — فلا تُكتب إلا على فراغ.
    final keep = resolvePhotoUrl(
      existing: (snap.data()?["photo_url"] ?? "").toString(),
      incoming: photoUrl,
    );
    if (keep != null) data["photo_url"] = keep;
    final created = !snap.exists;
    if (created) {
      data["created_at"] = FieldValue.serverTimestamp();
      data["role"] = AppRole.sanitize(role); // يُكتب مرة واحدة عند الإنشاء فقط
      data["settings"] = {
        "dark_mode": false,
        "font_size": 16,
        "auto_tts": false,
        "robot_enabled": true,
      };
    }
    await ref.set(data, SetOptions(merge: true));
    return created;
  }

  Future<UserProfile?> fetch(String uid) async {
    final snap = await _doc(uid).get();
    if (!snap.exists) return null;
    return UserProfile.fromMap(uid, snap.data() ?? {});
  }

  /// تعديل جزئي (الصف/المسار/الاسم) — أرخص كتابة ممكنة.
  ///
  /// ⛔ الدور **لا يمرّ من هنا**: [setRole] وحدها تكتبه، فتُنقّيه من قائمةٍ
  ///    مغلقة. وبلا هذا الحذف كان يكفي أن يمرّر أحدهم `role: "admin"` في
  ///    خريطةٍ عامة ليتجاوز الحارس كلَّه.
  Future<void> patch(String uid, Map<String, dynamic> fields) async {
    if (fields.isEmpty) return;
    fields.remove("role");
    await _doc(uid).set(
      {...fields, "updated_at": FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  /// 🎭 تبديل الدور — المنفذ **الوحيد** لكتابته، ومن قائمةٍ مغلقة.
  ///
  /// قواعد الأمان تقبل `student` و`teacher` وترفض ما عداهما، فمحاولةُ كتابة
  /// `admin` تُرفض من الخادم أيضاً لا من هنا وحده.
  Future<void> setRole(String uid, String role) async {
    if (uid.isEmpty) return;
    await _doc(uid).set(
      {"role": AppRole.sanitize(role), "updated_at": FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> updateSettings(String uid, Map<String, dynamic> settings) async {
    await _doc(uid).set({"settings": settings}, SetOptions(merge: true));
  }

  /// كل فروع مستند المستخدم — **مصدرٌ واحد** يُشتقّ منه الحذف والاختبار.
  ///
  /// 🔴 **العطل الذي أوجب هذه القائمة:** كان الحذف يعدّد ثلاث مجموعات
  ///    مكتوبةً في مكانها، وقد أُضيفت `scholarship_chats` بعدها في
  ///    `firestore.rules` ولم يعلم بها أحد هنا. فكان الطالب يحذف حسابه
  ///    و**تبقى محادثاته مع مساعد المنح في السحابة** — بياناتٌ شخصية لحسابٍ
  ///    لم يعد له مالك، ومخالفةٌ صريحة لإلزام Google Play وحماية البيانات.
  ///
  /// ⚠️ ومن يضيف فرعاً جديداً في القواعد يضيفه هنا — واختبار
  ///    `account_deletion_test.dart` يقارن الاثنين فيسقط إن نُسي.
  static const List<String> userSubcollections = [
    "conversations",
    "scholarship_chats",
    "results",
    "saved_answers",
  ];

  /// أقصى عدد عمليات في دفعة Firestore الواحدة (حدُّ المنصّة ٥٠٠).
  static const int _batchLimit = 450;

  /// حذف بيانات المستخدم قبل حذف حسابه (إلزام Google Play).
  ///
  /// ⚠️ Firestore **لا يحذف الفروع مع المستند** — تُحذف صراحةً أولاً.
  ///
  /// ⚡ **بدفعاتٍ لا واحدةً واحدة:** الصيغة السابقة كانت `await` داخل حلقة،
  ///    أي رحلةً شبكية لكل مستند. طالبٌ نشط عنده ٣٠ محادثة و١٠٠ نتيجة
  ///    ⇒ نحو ١٥٠ رحلة و٢٠–٣٠ ثانية بلا أي مؤشر تقدّم، وإن انقطع النت في
  ///    منتصفها بقيت بقايا بلا مالك. الدفعة تُنهيها في نداءاتٍ معدودة
  ///    **وذرّيةً**: إمّا أن تُحذف الدفعة كلها أو لا شيء منها.
  Future<void> deleteAllData(String uid) async {
    if (uid.isEmpty) return;
    for (final col in userSubcollections) {
      await _deleteCollection(_doc(uid).collection(col));
    }
    await _doc(uid).delete();
  }

  /// يحذف مجموعةً كاملة على دفعاتٍ متتالية حتى تفرغ.
  ///
  /// ⚠️ الحلقة `while` لا مرورٌ واحد: المجموعة قد تتجاوز حدّ الدفعة، ومرورٌ
  ///    واحد كان سيترك الباقي **صامتاً** — أسوأ من الفشل لأنه يبدو نجاحاً.
  Future<void> _deleteCollection(
      CollectionReference<Map<String, dynamic>> col) async {
    while (true) {
      final snap = await col.limit(_batchLimit).get();
      if (snap.docs.isEmpty) return;
      final batch = _db.batch();
      for (final d in snap.docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (snap.docs.length < _batchLimit) return;
    }
  }
}
