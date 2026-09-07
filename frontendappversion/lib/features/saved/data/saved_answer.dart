import 'package:hive/hive.dart';

part 'saved_answer.g.dart';

// ==========================================
// ⭐ إجابة محفوظة
// ==========================================
// **لماذا صندوق مستقل لا علامة داخل الرسالة؟**
//   المحادثات تُحذف — يدوياً ومن التشذيب التلقائي (سقف لكل مادة/منحة).
//   لو كانت العلامة داخل الرسالة لضاع المحفوظ مع محادثته، وهذا نقيض معنى
//   «محفوظ». فننسخ النصّ هنا نسخاً كاملاً ونقبل التكرار عن قصد.
@HiveType(typeId: 6)
class SavedAnswer extends HiveObject {
  /// بصمة النصّ — المفتاح نفسه. تمنع حفظ الإجابة مرّتين وتجعل فحص
  /// «هل هذه محفوظة؟» فوريّاً بلا مسحٍ للصندوق كلّه.
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String ownerUid;

  /// education | teacher | scholarship
  @HiveField(2)
  final String section;

  /// المادة (في التعليم) أو اسم المنحة — لتصفية القائمة.
  @HiveField(3)
  final String subject;

  @HiveField(4)
  final String text;

  @HiveField(5)
  final DateTime savedAt;

  /// 🎓 صف الطالب ومساره ساعةَ الحفظ — عليهما يُفصل سجلُّ كل سنة عن أختها.
  ///
  /// ⚠️ **صفرٌ يعني «محفوظٌ قبل الفصل»** لا «الصف صفر»: هذه سجلّاتُ نسخةٍ
  ///    سابقة لم يكن فيها للمحفوظ صفٌّ أصلاً. تظهر في كل الصفوف كي لا يفتح
  ///    الطالبُ التطبيقَ بعد التحديث فيجد محفوظاتِه اختفت، و
  ///    [SavedStorage.adoptScopeless] تنسبها لصفّه عند أول دخول.
  @HiveField(6, defaultValue: 0)
  int grade;

  @HiveField(7, defaultValue: "")
  String track;

  SavedAnswer({
    required this.id,
    required this.ownerUid,
    required this.section,
    required this.subject,
    required this.text,
    this.grade = 0,
    this.track = "",
    DateTime? savedAt,
  }) : savedAt = savedAt ?? DateTime.now();

  /// عنوان مختصر: أول سطر ذي معنى بعد تنظيف علامات الماركداون.
  String get title {
    for (final raw in text.split('\n')) {
      final line = raw
          .replaceAll(RegExp(r'^[#>\-*•\s]+'), '')
          .replaceAll(RegExp(r'[*_`]'), '')
          .trim();
      if (line.length >= 4) {
        return line.length <= 60 ? line : '${line.substring(0, 60)}…';
      }
    }
    return 'إجابة محفوظة';
  }

  String get sectionLabel => switch (section) {
        'teacher' => 'مساعد المعلم',
        'scholarship' => 'المنح',
        _ => 'التعليم',
      };
}
