// ==========================================
// 🔍 قدرات المادة — من GET /content/capabilities
// ==========================================
// استدعاء واحد يعطي: الأوضاع المتاحة + شجرة الوحدات والدروس.
class LessonsUnit {
  final String unit;
  final List<String> lessons;
  const LessonsUnit({required this.unit, required this.lessons});

  factory LessonsUnit.fromJson(Map<String, dynamic> j) => LessonsUnit(
        unit: (j['unit'] ?? '').toString(),
        lessons: List<String>.from(j['lessons'] ?? const []),
      );
}

class SubjectCapabilities {
  final String subject;
  final bool lessonsAvailable;
  final bool pagesAvailable;
  final List<LessonsUnit> lessonsUnits;
  final List<String> pagesUnits;

  /// 📝 بنك وزاري لهذا الصف/المسار — الوزاري امتحان وطني للثالث،
  ///    فشريحته لا تظهر للأول والثاني ([31§3]).
  final bool examsAvailable;

  /// 🧠 «اختبر نفسك» — يُبنى من الدروس حصراً، لكل المواد بنفس القاعدة.
  final bool quizAvailable;

  const SubjectCapabilities({
    required this.subject,
    required this.lessonsAvailable,
    required this.pagesAvailable,
    required this.lessonsUnits,
    required this.pagesUnits,
    this.examsAvailable = false,
    this.quizAvailable = false,
  });

  factory SubjectCapabilities.fromJson(Map<String, dynamic> j) {
    final lessons = (j['lessons'] ?? const {}) as Map<String, dynamic>;
    final pages = (j['pages'] ?? const {}) as Map<String, dynamic>;
    final lessonsOk = lessons['available'] == true;
    return SubjectCapabilities(
      subject: (j['subject'] ?? '').toString(),
      lessonsAvailable: lessonsOk,
      pagesAvailable: pages['available'] == true,
      lessonsUnits: List<Map<String, dynamic>>.from(lessons['units'] ?? const [])
          .map(LessonsUnit.fromJson)
          .toList(),
      pagesUnits: List<String>.from(pages['units'] ?? const []),
      // ⚠️ خادم أقدم لا يرسل هذين المفتاحين. الغياب ليس «غير متاح»:
      //    نستنتج الاختبارات من وجود الدروس، ونُبقي الوزاري ظاهراً كما كان.
      //    (بدون هذا الاحتياط ظهرت «لا توجد دروس» لمادة دروسها موجودة فعلاً.)
      examsAvailable: j.containsKey('exams')
          ? ((j['exams'] ?? const {}) as Map)['available'] == true
          : true,
      quizAvailable: j.containsKey('quiz')
          ? ((j['quiz'] ?? const {}) as Map)['available'] == true
          : lessonsOk,
    );
  }

  /// لا محتوى بعد لأي وضع (المالك سيضيفه لاحقاً).
  bool get isEmpty => !lessonsAvailable && !pagesAvailable;

  List<String> get unitsWithLessons => lessonsUnits.map((u) => u.unit).toList();

  List<String> lessonsIn(String unit) {
    for (final u in lessonsUnits) {
      if (u.unit == unit) return u.lessons;
    }
    return const [];
  }

  /// وحدة درسٍ بعينه — أو `null` إن لم يكن في هذه المادة.
  ///
  /// يحتاجها اختيار الدروس **عبر الوحدات**: الدرس المقترح من قسم التحليل
  /// يصل بلا وحدته، فنبحث عنها بدل إسقاطه.
  String? unitOfLesson(String lesson) {
    for (final u in lessonsUnits) {
      if (u.lessons.contains(lesson)) return u.unit;
    }
    return null;
  }
}
