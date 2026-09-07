import 'package:flutter/material.dart';

// ==========================================
// 👨‍🏫 أدوات مساعد المعلم
// ==========================================
// أربع أدوات تشترك في **كل شيء** مع قسم التعليم (نفس الشات، نفس الصور والصوت
// والسياق وسجلّ المحادثات) وتختلف في شيئين اثنين فقط (قرار المالك):
//   ① **صفحة الإعدادات** — لكل أداة حقولها الخاصة تحت المادة/الوحدة/الدرس.
//   ② **البرومبتات** — ولكل أداة برومبتان في الخادم: توليد ومحادثة.
//
// ⚠️ **المصدر: الدروس وحدها.** لا وضع صفحات ولا محتوى وحدات هنا إطلاقاً —
//    فمادةٌ بلا دروس تُقال صراحةً بدل أن تُنتج خطةً لدرسٍ لا وجود له.
//
// 🔑 `id` هو **العقد مع الخادم** (`core/teacher_prompts.TOOLS`) وهو أيضاً جزء
//    من مفتاح نطاق المحادثات — فتغييره يفصل المعلّم عن سجلّه القديم.
enum TeacherTool { lessonPlan, simplify, homework, ask }

extension TeacherToolX on TeacherTool {
  /// المعرّف المتفق عليه مع الباك اند — لا يُترجم ولا يُغيَّر.
  String get id => switch (this) {
        TeacherTool.lessonPlan => "plan",
        TeacherTool.simplify => "simplify",
        TeacherTool.homework => "homework",
        TeacherTool.ask => "ask",
      };

  String get emoji => switch (this) {
        TeacherTool.lessonPlan => "📖",
        TeacherTool.simplify => "💡",
        TeacherTool.homework => "📝",
        TeacherTool.ask => "🤖",
      };

  String get label => switch (this) {
        TeacherTool.lessonPlan => "إنشاء خطة درس",
        TeacherTool.simplify => "تبسيط مفهوم",
        TeacherTool.homework => "إنشاء واجب",
        TeacherTool.ask => "اسأل المساعد",
      };

  String get description => switch (this) {
        TeacherTool.lessonPlan =>
          "خطة تدريس من نصّ الدرس نفسه: الأهداف، خطوات الشرح بأزمنتها، النشاط، التقويم والواجب.",
        TeacherTool.simplify =>
          "طرق شرحٍ لمفهومٍ يتعثّر فيه الطلاب: تشبيهان بحدودهما، تمثيل بلا وسائل، وسؤال كاشف.",
        TeacherTool.homework =>
          "واجب من الدرس وحده، متدرّج الصعوبة، ومعه مفتاح تصحيح بالدرجات.",
        TeacherTool.ask =>
          "محادثة مفتوحة لأي سؤال تربوي أو تعليمي — مع درسك أو بدونه.",
      };

  /// ⭐ **زرّ التوليد**: «اسأل المساعد» محادثة مفتوحة بلا زر — وهذا الفرق
  ///    الوحيد بين الأدوات في بنية الشاشة.
  bool get hasGenerate => this != TeacherTool.ask;

  /// ⭐ هل تُلزم الأداةُ باختيار درس قبل العمل؟
  ///    «اسأل المساعد» لا تُلزم: سؤالٌ عن إدارة الحصة لا يحتاج درساً.
  bool get requiresLesson => this != TeacherTool.ask;

  /// عنوان زر التوليد داخل لوحة الإعدادات.
  String get generateLabel => switch (this) {
        TeacherTool.lessonPlan => "🚀 إنشاء خطة الدرس",
        TeacherTool.simplify => "✨ تبسيط المفهوم",
        TeacherTool.homework => "🚀 إنشاء الواجب",
        TeacherTool.ask => "",
      };

  /// عنوان بطاقة الإعدادات.
  String get settingsTitle => switch (this) {
        TeacherTool.lessonPlan => "إعدادات الخطة",
        TeacherTool.simplify => "إعدادات التبسيط",
        TeacherTool.homework => "إعدادات الواجب",
        TeacherTool.ask => "إعدادات المحادثة",
      };

  /// نصّ شاشة التحميل أثناء التوليد.
  String get loadingText => switch (this) {
        TeacherTool.lessonPlan => "يجهّز مسار خطة الدرس...",
        TeacherTool.simplify => "يجهّز مسار طرق التبسيط...",
        TeacherTool.homework => "يجهّز مسار الواجب...",
        TeacherTool.ask => "",
      };

  List<Color> get gradient => switch (this) {
        TeacherTool.lessonPlan => const [Color(0xFF3B82F6), Color(0xFF1D4ED8)],
        TeacherTool.simplify => const [Color(0xFFF59E0B), Color(0xFFEA580C)],
        TeacherTool.homework => const [Color(0xFF10B981), Color(0xFF059669)],
        TeacherTool.ask => const [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
      };

  /// ⭐ شرائح الاقتراحات — «أمثلة من الحياة» و«اجعل النشاط مناسباً للمجموعات»
  ///    نُقلت من الديمو بطلب المالك، وهي الآن **تُرسل فعلاً** إلى الخادم
  ///    كرسالة متابعة عادية بدل أن تُنتج نصاً ثابتاً.
  List<String> get suggestions => switch (this) {
        TeacherTool.lessonPlan => const [
            "أضف مثالاً من الحياة",
            "اجعل النشاط مناسباً للمجموعات",
            "أضف سؤال تقويم إضافي",
            "اختصر الخطة لحصة ٤٥ دقيقة",
          ],
        TeacherTool.simplify => const [
            "أعطني تشبيهاً آخر",
            "كيف أشرحه لطالب ضعيف؟",
            "أضف تمثيلاً على السبورة",
            "ما الخطأ الشائع هنا؟",
          ],
        TeacherTool.homework => const [
            "أضف سؤال مقال",
            "اجعله أصعب قليلاً",
            "أضف الحلول النموذجية",
            "حوّله إلى اختبار قصير",
          ],
        TeacherTool.ask => const [
            "كيف أدير وقت الحصة؟",
            "أفكار لتقييم سريع",
            "كيف أتعامل مع الطلاب الضعاف؟",
            "كيف أضبط صفاً مكتظاً؟",
          ],
      };

  static TeacherTool? fromId(String id) {
    for (final t in TeacherTool.values) {
      if (t.id == id) return t;
    }
    return null;
  }
}

/// مستويات صعوبة الواجب — نفس القائمة البيضاء في الخادم.
const List<String> kTeacherDifficulties = ["سهل", "متوسط", "صعب"];

/// أعداد أسئلة الواجب — نفس القائمة البيضاء في الخادم.
const List<int> kTeacherCounts = [5, 10, 15];
