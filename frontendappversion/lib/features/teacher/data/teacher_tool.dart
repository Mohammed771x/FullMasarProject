import 'package:flutter/widgets.dart';

import '../../../core/widgets/phosphor.dart';

// ==========================================
// 👨‍🏫 أدوات مساعد المعلم
// ==========================================
// أربع أدوات تشترك في **كل شيء** مع قسم التعليم (نفس الشات، نفس الصور والصوت
// والسياق وسجلّ المحادثات) وتختلف في شيئين اثنين فقط (قرار المالك):
//   ① **بطاقة الإعدادات** — لكل أداة حقولها الخاصة تحت المادة/الوحدة/الدرس.
//   ② **البرومبتات** — ولكل أداة برومبتان في الخادم: توليد ومحادثة.
//
// ⚠️ **المصدر: الدروس وحدها.** لا وضع صفحات ولا محتوى وحدات هنا إطلاقاً —
//    فمادةٌ بلا دروس تُقال صراحةً بدل أن تُنتج خطةً لدرسٍ لا وجود له.
//
// 🔑 `id` هو **العقد مع الخادم** (`core/teacher_prompts.TOOLS`) وهو أيضاً جزء
//    من مفتاح نطاق المحادثات — فتغييره يفصل المعلّم عن سجلّه القديم.
//
// 🎨 **والعناوينُ والتسمياتُ من `design/09-teacher` حرفاً** (الإطارات ١·٣·٤):
//    «إعداد خطة التحضير الوزاري» · «توليد واجب / اختبار مدرسي متدرج» ·
//    «تبسيط مفهوم صعب للطلاب». وهذه **ليست عيّناتٍ توضيحية** كنصوص المصمّم
//    في بقيّة الشاشات: كلٌّ منها يصف الأداةَ التي في التطبيق بعينها، وهي
//    أوضحُ من «إعدادات الخطة» التي كانت هنا.
enum TeacherTool { lessonPlan, simplify, homework, ask }

extension TeacherToolX on TeacherTool {
  /// المعرّف المتفق عليه مع الباك اند — لا يُترجم ولا يُغيَّر.
  String get id => switch (this) {
        TeacherTool.lessonPlan => "plan",
        TeacherTool.simplify => "simplify",
        TeacherTool.homework => "homework",
        TeacherTool.ask => "ask",
      };

  /// 🎨 **ترتيب شريط الأدوات كما في التصميم**: خطة درس ← واجب ← تبسيط.
  ///    (وRTL يضع الأولى في اليمين.) و«اسأل المساعد» رابعةً 🆕 — أداةٌ
  ///    قائمةٌ في الخادم لم يرسمها المصمّم، فبُنيت بلغته.
  static const List<TeacherTool> bar = [
    TeacherTool.lessonPlan,
    TeacherTool.homework,
    TeacherTool.simplify,
    TeacherTool.ask,
  ];

  /// 🎨 سلّمُ ألوان الأداة في [AppColors.toolPalette].
  int get slot => switch (this) {
        TeacherTool.lessonPlan => 0,
        TeacherTool.homework => 1,
        TeacherTool.simplify => 2,
        TeacherTool.ask => 3,
      };

  /// ✒️ أيقونةُ الشريحة وزرِّ التوليد — من مكتبة المصمّم نفسها.
  ///
  /// ⚠️ **و«واجب واختبار» ليست `PIcon`**: المصمّم رسم ورقةً بعلامةِ صحّ،
  ///    و`file-check` أُضيفت إلى نواة Phosphor **بعد** الإصدار الذي أُخذت
  ///    منه خطوطُنا. وهي مركّبةٌ أصلاً في [PFileCheck] لشرائح «وزاري»
  ///    و«اختبارات» عند الطالب — فتُستعمل هنا هي نفسُها لا بديلٌ يشبهها.
  ///    ولذلك الأيقونةُ **ودجةٌ** لا `IconData`.
  Widget iconWidget({required double size, required Color color}) =>
      this == TeacherTool.homework
          ? PFileCheck(size: size, color: color)
          : Icon(_icon.regular, size: size, color: color);

  PIcon get _icon => switch (this) {
        TeacherTool.lessonPlan => PI.bookOpen,
        TeacherTool.simplify => PI.lightbulb,
        TeacherTool.homework => PI.fileText,
        TeacherTool.ask => PI.chatCircleDots,
      };

  String get emoji => switch (this) {
        TeacherTool.lessonPlan => "📖",
        TeacherTool.simplify => "💡",
        TeacherTool.homework => "📝",
        TeacherTool.ask => "🤖",
      };

  /// اسمُ الشريحة في شريط الأدوات — قصيرٌ كما في التصميم.
  String get chipLabel => switch (this) {
        TeacherTool.lessonPlan => "خطة درس",
        TeacherTool.simplify => "تبسيط مفهوم",
        TeacherTool.homework => "واجب واختبار",
        TeacherTool.ask => "اسأل المساعد",
      };

  /// الاسمُ الكامل — شارةُ النطاق في القائمة الجانبية وبطاقاتُ الدليل.
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
  ///    الوحيد بين الأدوات في بنية البطاقة.
  bool get hasGenerate => this != TeacherTool.ask;

  /// ⭐ هل تُلزم الأداةُ باختيار درس قبل العمل؟
  ///    «اسأل المساعد» لا تُلزم: سؤالٌ عن إدارة الحصة لا يحتاج درساً.
  bool get requiresLesson => this != TeacherTool.ask;

  /// عنوان زرّ التوليد — من التصميم، وتُذيَّل بـ«✨» كما فيه.
  String get generateLabel => switch (this) {
        TeacherTool.lessonPlan => "توليد خطة الدرس النموذجية",
        TeacherTool.simplify => "تبسيط المفهوم وابتكار تشبيهات",
        TeacherTool.homework => "إنشاء الواجب مع سلم التصحيح",
        TeacherTool.ask => "",
      };

  /// عنوان بطاقة الإعدادات — من التصميم.
  String get cardTitle => switch (this) {
        TeacherTool.lessonPlan => "إعداد خطة التحضير الوزاري",
        TeacherTool.simplify => "تبسيط مفهوم صعب للطلاب",
        TeacherTool.homework => "توليد واجب / اختبار مدرسي متدرج",
        TeacherTool.ask => "اسأل المساعد التربوي",
      };

  /// تسميةُ حقل الدرس فوقه — من التصميم.
  String get lessonFieldLabel => switch (this) {
        TeacherTool.lessonPlan => "عنوان الدرس المستهدف:",
        TeacherTool.ask => "الدرس (اختياري):",
        _ => "الدرس المستهدف:",
      };

  /// نصّ شاشة التحميل أثناء التوليد.
  String get loadingText => switch (this) {
        TeacherTool.lessonPlan => "يجهّز مسار خطة الدرس...",
        TeacherTool.simplify => "يجهّز مسار طرق التبسيط...",
        TeacherTool.homework => "يجهّز مسار الواجب...",
        TeacherTool.ask => "",
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
