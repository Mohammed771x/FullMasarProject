import 'package:flutter/material.dart';

// ==========================================
// 🧪 بيانات الديمو (محاكاة كاملة لمحتوى Firestore/config — بلا أي شبكة)
// ==========================================

// ═══════════════ المنح ═══════════════
enum SchStatus { open, soon, closed }

class Scholarship {
  final String id;
  final String name;
  final String country;
  final String flag;
  final String shortDesc;
  final String about;
  final String fundingType; // full | partial
  final List<String> requirements;
  final List<String> howToApply;
  final DateTime openDate;
  final DateTime closeDate;
  final List<Color> gradient;

  const Scholarship({
    required this.id,
    required this.name,
    required this.country,
    required this.flag,
    required this.shortDesc,
    required this.about,
    required this.fundingType,
    required this.requirements,
    required this.howToApply,
    required this.openDate,
    required this.closeDate,
    required this.gradient,
  });

  SchStatus get status {
    final now = DateTime.now();
    if (now.isBefore(openDate)) return SchStatus.soon;
    if (now.isAfter(closeDate)) return SchStatus.closed;
    return SchStatus.open;
  }
}

final List<Scholarship> demoScholarships = [
  Scholarship(
    id: "turkey",
    name: "المنحة التركية",
    country: "تركيا",
    flag: "🇹🇷",
    shortDesc: "Türkiye Bursları — تمويل كامل مع راتب شهري",
    about: "منحة حكومية تركية ممولة بالكامل، تشمل الرسوم الدراسية والسكن والتأمين الصحي ومخصصاً شهرياً وتذاكر الطيران، إضافة إلى سنة مجانية لتعلّم اللغة التركية قبل بدء التخصص.",
    fundingType: "full",
    requirements: ["معدل 70% فأعلى للبكالوريوس", "العمر أقل من 21 سنة للبكالوريوس", "شهادة الثانوية العامة", "جواز سفر ساري المفعول", "خطاب دافع مقنع"],
    howToApply: ["أنشئ حساباً في موقع turkiyeburslari.gov.tr", "املأ البيانات الشخصية والأكاديمية", "ارفع الوثائق المطلوبة مترجمة", "اكتب خطاب الدافع بعناية", "تابع بريدك لموعد المقابلة"],
    openDate: DateTime(DateTime.now().year, 1, 10),
    closeDate: DateTime(DateTime.now().year, 12, 20),
    gradient: const [Color(0xFFEF4444), Color(0xFFB91C1C)],
  ),
  Scholarship(
    id: "saudi",
    name: "منحة الجامعات السعودية",
    country: "السعودية",
    flag: "🇸🇦",
    shortDesc: "مقاعد مجانية بمكافأة شهرية وسكن جامعي",
    about: "منح مقدّمة من الجامعات السعودية للطلاب الدوليين تشمل الإعفاء الكامل من الرسوم ومكافأة شهرية وسكناً جامعياً ورعاية صحية وتذكرة سفر سنوية، في بيئة دراسية متطورة.",
    fundingType: "full",
    requirements: ["شهادة الثانوية بمعدل جيد جداً", "حسن السيرة والسلوك", "لائق طبياً", "ألا يكون حاصلاً على منحة أخرى بالمملكة"],
    howToApply: ["قدّم عبر بوابة ادرس في السعودية studyinsaudi.moe.gov.sa", "اختر الجامعات والتخصصات بالترتيب", "ارفع الوثائق وصدّقها", "انتظر الترشيح النهائي"],
    openDate: DateTime(DateTime.now().year, 1, 1),
    closeDate: DateTime(DateTime.now().year, 12, 28),
    gradient: const [Color(0xFF16A34A), Color(0xFF065F46)],
  ),
  Scholarship(
    id: "india",
    name: "المنحة الهندية ICCR",
    country: "الهند",
    flag: "🇮🇳",
    shortDesc: "تخصصات الهندسة والعلوم بتكاليف معيشة منخفضة",
    about: "برنامج المجلس الهندي للعلاقات الثقافية (ICCR) يقدّم منحاً في الهندسة والعلوم والإدارة، مع بدل معيشة شهري وبدل سكن وكتب ورعاية صحية، وجودة تعليم معترف بها عالمياً.",
    fundingType: "full",
    requirements: ["شهادة الثانوية العامة", "إجادة اللغة الإنجليزية", "اجتياز اختبار اللغة إن طُلب", "العمر بين 18 و30 سنة"],
    howToApply: ["سجّل في بوابة a2ascholarships.iccr.gov.in", "اختر 3 جامعات مفضلة", "ارفع كشف الدرجات والشهادات", "قدّم قبل إغلاق البوابة"],
    openDate: DateTime(DateTime.now().year + 1, 2, 1),
    closeDate: DateTime(DateTime.now().year + 1, 4, 30),
    gradient: const [Color(0xFFF59E0B), Color(0xFFB45309)],
  ),
  Scholarship(
    id: "malaysia",
    name: "منحة ماليزيا الدولية MIS",
    country: "ماليزيا",
    flag: "🇲🇾",
    shortDesc: "بيئة متعددة الثقافات وجودة تعليم مرموقة",
    about: "منحة ماليزيا الدولية موجّهة للطلاب المتميزين في بلد يجمع بين جودة التعليم وتكلفة المعيشة المناسبة وبيئة إسلامية متعددة الثقافات، مع بدل شهري وتأمين صحي.",
    fundingType: "partial",
    requirements: ["معدل أكاديمي مرتفع", "IELTS 6.0 أو ما يعادلها", "خطة دراسية واضحة", "خطابا توصية"],
    howToApply: ["قدّم عبر بوابة biasiswa.mohe.gov.my", "أرفق شهادة اللغة", "اكتب مقترح الدراسة", "تابع الإيميل للمقابلة"],
    openDate: DateTime(DateTime.now().year, 1, 5),
    closeDate: DateTime(DateTime.now().year, 12, 15),
    gradient: const [Color(0xFF0EA5E9), Color(0xFF0369A1)],
  ),
  Scholarship(
    id: "usa",
    name: "منح الجامعات الأمريكية",
    country: "أمريكا",
    flag: "🇺🇸",
    shortDesc: "Fulbright ومساعدات جامعية لأعرق الجامعات",
    about: "منح فولبرايت والمساعدات المالية للجامعات الأمريكية تفتح أبواب أعرق الجامعات عالمياً، مع تركيز على التميّز الأكاديمي والقيادة والبحث العلمي وإرشاد أكاديمي كامل.",
    fundingType: "full",
    requirements: ["تفوق أكاديمي واضح", "TOEFL iBT 80+ أو IELTS 6.5+", "أنشطة لا صفية وقيادية", "مقالات شخصية قوية"],
    howToApply: ["ابدأ التحضير قبل سنة كاملة", "قدّم عبر Common App للجامعات", "اطلب المساعدة المالية Need-based", "جهّز مقالاتك بعناية فائقة"],
    openDate: DateTime(DateTime.now().year, 8, 1),
    closeDate: DateTime(DateTime.now().year, 11, 1),
    gradient: const [Color(0xFF6366F1), Color(0xFF3730A3)],
  ),
  Scholarship(
    id: "qatar",
    name: "منحة جامعة قطر",
    country: "قطر",
    flag: "🇶🇦",
    shortDesc: "إعفاء رسوم وسكن وتذاكر سنوية للمتفوقين",
    about: "منح جامعة قطر للطلاب الدوليين المتفوقين تشمل الإعفاء من الرسوم الدراسية والسكن الجامعي وتذاكر سفر سنوية، في واحدة من أفضل جامعات المنطقة.",
    fundingType: "full",
    requirements: ["معدل 85% فأعلى", "اجتياز متطلبات القسم", "شهادة لغة حسب التخصص"],
    howToApply: ["قدّم طلب القبول أولاً في qu.edu.qa", "بعد القبول قدّم على المنحة", "أرفق الوثائق المصدّقة"],
    openDate: DateTime(DateTime.now().year - 1, 9, 1),
    closeDate: DateTime(DateTime.now().year, 3, 1),
    gradient: const [Color(0xFF8B1538), Color(0xFF5B0E26)],
  ),
];

// ═══════════════ البانرات (محاكاة config/banners) ═══════════════
class DemoBanner {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final String? targetScholarshipId;
  const DemoBanner(this.title, this.subtitle, this.icon, this.gradient, {this.targetScholarshipId});
}

const List<DemoBanner> demoBanners = [
  DemoBanner("المنحة التركية فتحت أبوابها! 🎉", "تمويل كامل + راتب شهري — قدّم الآن", Icons.flight_takeoff_rounded, [Color(0xFFEF4444), Color(0xFF991B1B)], targetScholarshipId: "turkey"),
  DemoBanner("جرّب اختبار الميول الجديد 🧭", "15 سؤالاً تكشف تخصصك المناسب", Icons.explore_rounded, [Color(0xFF8B5CF6), Color(0xFF6D28D9)]),
  DemoBanner("خدمة تجهيز ملف التقديم 📋", "فريقنا يجهّز ملفك خطوة بخطوة", Icons.handshake_rounded, [Color(0xFF059669), Color(0xFF065F46)]),
];

// ═══════════════ الخدمات (محاكاة config/services) ═══════════════
class ServiceItem {
  final String title;
  final String desc;
  final String fullDesc;
  final IconData icon;
  final Color color;
  final String whatsappMessage;
  const ServiceItem(this.title, this.desc, this.fullDesc, this.icon, this.color, this.whatsappMessage);
}

const List<ServiceItem> demoServices = [
  ServiceItem("كتابة السيرة الذاتية CV", "سيرة ذاتية احترافية بالعربي والإنجليزي", "نكتب لك سيرة ذاتية احترافية مصممة خصيصاً للمنح والقبولات الجامعية، بالعربية والإنجليزية، مع مراجعة لغوية كاملة وتنسيق عصري يلفت انتباه لجان القبول.", Icons.description_rounded, Color(0xFF3B82F6), "أرغب بخدمة كتابة السيرة الذاتية"),
  ServiceItem("خطاب الدافع Motivation Letter", "خطاب يقنع لجنة القبول بك", "خطاب دافع مخصص لك ولمنحتك المستهدفة، يبرز قصتك وأهدافك بأسلوب مؤثر ومقنع، مكتوب من مختصين ساعدوا عشرات الطلاب في القبول.", Icons.edit_note_rounded, Color(0xFF8B5CF6), "أرغب بخدمة كتابة خطاب الدافع"),
  ServiceItem("ترجمة وتوثيق الوثائق", "ترجمة معتمدة جاهزة للتقديم", "ترجمة معتمدة لشهاداتك وكشوف درجاتك ووثائقك مع التصديق المطلوب، جاهزة للرفع في بوابات المنح والجامعات.", Icons.translate_rounded, Color(0xFF0EA5E9), "أرغب بخدمة ترجمة وتوثيق الوثائق"),
  ServiceItem("تجهيز ملف التقديم كاملاً", "باقة شاملة من الألف إلى الياء", "نرافقك في رحلة التقديم كاملة: اختيار المنح المناسبة، تجهيز كل الوثائق، تعبئة الطلبات، والتحضير للمقابلة الشخصية.", Icons.folder_zip_rounded, Color(0xFF10B981), "أرغب بباقة تجهيز ملف التقديم كاملاً"),
  ServiceItem("التحضير للمقابلة الشخصية", "تدريب مباشر مع محاكاة مقابلات", "جلسات تدريب فردية على المقابلات الشخصية للمنح، مع محاكاة أسئلة حقيقية وتقييم أدائك ونصائح لتحسين إجاباتك.", Icons.record_voice_over_rounded, Color(0xFFF59E0B), "أرغب بخدمة التحضير للمقابلة الشخصية"),
];

// ═══════════════ التعليم ═══════════════
const List<String> demoSubjects = ["احياء", "فيزياء", "كيمياء", "عربي", "انجليزي", "رياضيات"];
const List<String> demoModes = ["شرح", "تلخيص", "سؤال", "وزاري"];

// الأسئلة المقترحة (محاكاة config/suggested_questions)
const Map<String, List<String>> demoSuggestedQuestions = {
  "احياء": ["اشرح لي التنظيم الهرموني", "لخّص درس الغدة الدرقية", "أعطني سؤال وزاري عن الوراثة", "ما وظيفة البنكرياس؟"],
  "فيزياء": ["اشرح نظرية بوهر", "ما قانون نيوتن الثاني؟", "لخّص درس الكهرومغناطيسية", "أعطني مسألة وزارية"],
  "كيمياء": ["اشرح تفاعلات الحمض والقاعدة", "ما هو عدد الأكسدة؟", "لخّص الكيمياء العضوية", "سؤال وزاري عن الاتزان"],
  "عربي": ["اشرح المفعول لأجله", "أعرب: العلمُ نورٌ", "لخّص درس البلاغة", "سؤال وزاري نحو وصرف"],
  "انجليزي": ["اشرح قاعدة Passive Voice", "ما الفرق بين Past و Perfect؟", "أعطني سؤال Spot the Mistakes", "اشرح Reported Speech"],
  "رياضيات": ["اشرح درس الاشتقاق", "حل معادلة تفاضلية بسيطة", "أعطني مسألة تكامل وزارية", "ما قاعدة السلسلة؟"],
};

// ═══════════════ بنك أسئلة الاختبارات (محاكاة /quiz/generate) ═══════════════
class QuizQ {
  final String q;
  final List<String> options;
  final int correct;
  final String topic;
  const QuizQ(this.q, this.options, this.correct, this.topic);
}

const Map<String, List<QuizQ>> demoQuizBank = {
  "احياء": [
    QuizQ("أي الغدد التالية تفرز هرمون الثايروكسين؟", ["النخامية", "الدرقية", "الكظرية", "البنكرياس"], 1, "التنظيم الهرموني"),
    QuizQ("العضية المسؤولة عن إنتاج الطاقة في الخلية هي:", ["النواة", "الرايبوسوم", "الميتوكندريا", "جهاز جولجي"], 2, "الخلية"),
    QuizQ("عدد الكروموسومات في الخلية الجسدية للإنسان:", ["23", "44", "46", "48"], 2, "الوراثة"),
    QuizQ("هرمون الأنسولين يُفرز من:", ["الكبد", "البنكرياس", "الطحال", "الكلية"], 1, "التنظيم الهرموني"),
    QuizQ("ناتج البناء الضوئي الرئيسي هو:", ["ثاني أكسيد الكربون", "الجلوكوز", "النيتروجين", "الماء فقط"], 1, "البناء الضوئي"),
    QuizQ("الحمض النووي DNA يوجد بشكل رئيسي في:", ["السيتوبلازم", "النواة", "الغشاء الخلوي", "الفجوات"], 1, "الوراثة"),
    QuizQ("أي مما يلي وحدة بناء البروتين؟", ["الجلوكوز", "الحمض الأميني", "الحمض الدهني", "النيوكليوتيد"], 1, "الجزيئات الحيوية"),
    QuizQ("عملية انقسام الخلية الجسدية تسمى:", ["الانقسام المنصف", "الانقسام المتساوي", "الإخصاب", "التبرعم"], 1, "الخلية"),
    QuizQ("الجهاز المسؤول عن نقل الأكسجين في الدم:", ["الصفائح", "خلايا الدم الحمراء", "خلايا الدم البيضاء", "البلازما"], 1, "جسم الإنسان"),
    QuizQ("النبات يمتص الماء عن طريق:", ["الأوراق", "الساق", "الجذور", "الأزهار"], 2, "النبات"),
  ],
  "فيزياء": [
    QuizQ("وحدة قياس القوة في النظام الدولي:", ["الجول", "النيوتن", "الواط", "الباسكال"], 1, "الميكانيكا"),
    QuizQ("قانون نيوتن الثاني يربط بين القوة و:", ["السرعة فقط", "الكتلة والتسارع", "الزمن", "المسافة"], 1, "قوانين نيوتن"),
    QuizQ("سرعة الضوء في الفراغ تقارب:", ["300 كم/ث", "3×10⁸ م/ث", "340 م/ث", "1000 م/ث"], 1, "الموجات"),
    QuizQ("الطاقة الحركية تعتمد على:", ["الكتلة والسرعة", "الوزن فقط", "الزمن", "الحجم"], 0, "الطاقة"),
    QuizQ("وحدة المقاومة الكهربائية هي:", ["الأمبير", "الفولت", "الأوم", "الواط"], 2, "الكهرباء"),
    QuizQ("نظرية بوهر تتحدث عن نموذج:", ["الجاذبية", "الذرة", "الموجة", "المجال"], 1, "الفيزياء الحديثة"),
    QuizQ("العلاقة V = IR تُعرف بقانون:", ["نيوتن", "أوم", "كولوم", "أوهم الحراري"], 1, "الكهرباء"),
    QuizQ("تردد الموجة يقاس بوحدة:", ["المتر", "الثانية", "الهرتز", "الجول"], 2, "الموجات"),
  ],
  "كيمياء": [
    QuizQ("الرمز الكيميائي للصوديوم هو:", ["S", "So", "Na", "N"], 2, "الجدول الدوري"),
    QuizQ("درجة حموضة المحلول المتعادل pH تساوي:", ["0", "7", "14", "1"], 1, "الأحماض والقواعد"),
    QuizQ("عدد الأكسدة للأكسجين في الماء H₂O:", ["+1", "-2", "0", "+2"], 1, "التفاعلات"),
    QuizQ("الرابطة بين ذرتي هيدروجين رابطة:", ["أيونية", "تساهمية", "فلزية", "هيدروجينية"], 1, "الروابط"),
    QuizQ("العنصر الأكثر وفرة في القشرة الأرضية:", ["الحديد", "الأكسجين", "الكربون", "الذهب"], 1, "العناصر"),
    QuizQ("المادة التي تمنح المحلول لوناً أحمر مع تباع الشمس:", ["القاعدة", "الحمض", "المتعادل", "الملح"], 1, "الأحماض والقواعد"),
    QuizQ("عدد ذرات الهيدروجين في جزيء الميثان CH₄:", ["1", "2", "3", "4"], 3, "الكيمياء العضوية"),
    QuizQ("الجسيم موجب الشحنة في الذرة هو:", ["الإلكترون", "البروتون", "النيوترون", "الفوتون"], 1, "بنية الذرة"),
  ],
  "عربي": [
    QuizQ("إعراب كلمة (نورٌ) في: العلمُ نورٌ:", ["فاعل", "خبر مرفوع", "مبتدأ", "مفعول به"], 1, "النحو"),
    QuizQ("(كتبتُ الدرسَ) نوع (الدرسَ):", ["فاعل", "مفعول به", "حال", "تمييز"], 1, "النحو"),
    QuizQ("جمع كلمة (كتاب) هو:", ["كتّاب", "كُتُب", "مكتبة", "كاتب"], 1, "الصرف"),
    QuizQ("التشبيه من علوم:", ["النحو", "البلاغة", "الصرف", "العروض"], 1, "البلاغة"),
    QuizQ("(المفعول لأجله) يبيّن:", ["زمن الفعل", "سبب الفعل", "مكان الفعل", "أداة الفعل"], 1, "النحو"),
    QuizQ("علامة رفع جمع المذكر السالم:", ["الضمة", "الواو", "الألف", "الياء"], 1, "النحو"),
    QuizQ("(اقرأ) فعل:", ["ماضٍ", "مضارع", "أمر", "مصدر"], 2, "الصرف"),
    QuizQ("الطباق هو الجمع بين:", ["كلمتين متشابهتين", "الشيء وضده", "كلمتين مترادفتين", "كلمتين مسجوعتين"], 1, "البلاغة"),
  ],
  "انجليزي": [
    QuizQ("Choose the correct passive: The book ___ by Ali.", ["wrote", "was written", "writes", "is write"], 1, "Passive Voice"),
    QuizQ("Past simple of 'go':", ["goed", "gone", "went", "going"], 2, "Tenses"),
    QuizQ("Spot the mistake: 'She don't like tea.'", ["She", "don't", "like", "tea"], 1, "Grammar"),
    QuizQ("Plural of 'child':", ["childs", "children", "childes", "child"], 1, "Nouns"),
    QuizQ("Reported: He said, 'I am tired' → He said he ___ tired.", ["is", "was", "were", "be"], 1, "Reported Speech"),
    QuizQ("Choose synonym of 'happy':", ["sad", "glad", "angry", "tired"], 1, "Vocabulary"),
    QuizQ("'If it rains, I ___ stay home.' Choose:", ["will", "would", "am", "did"], 0, "Conditionals"),
    QuizQ("Comparative of 'good':", ["gooder", "better", "best", "more good"], 1, "Adjectives"),
  ],
  "رياضيات": [
    QuizQ("مشتقة الدالة f(x)=x² هي:", ["x", "2x", "x²", "2"], 1, "التفاضل"),
    QuizQ("تكامل الدالة f(x)=2x هو:", ["x²+c", "2+c", "x+c", "2x²+c"], 0, "التكامل"),
    QuizQ("حل المعادلة: 2x + 4 = 10 هو:", ["2", "3", "4", "5"], 1, "الجبر"),
    QuizQ("مجموع زوايا المثلث:", ["90°", "180°", "270°", "360°"], 1, "الهندسة"),
    QuizQ("نهاية الدالة x→0 للدالة sin(x)/x تساوي:", ["0", "1", "∞", "غير معرّفة"], 1, "النهايات"),
    QuizQ("مشتقة sin(x) هي:", ["cos(x)", "-cos(x)", "-sin(x)", "tan(x)"], 0, "التفاضل"),
    QuizQ("احتمال ظهور وجه في رمي عملة عادلة:", ["1", "0.5", "0.25", "0"], 1, "الاحتمالات"),
    QuizQ("قيمة log₁₀(100):", ["1", "2", "10", "100"], 1, "اللوغاريتمات"),
  ],
};

// ═══════════════ اختبار الميول (محاكاة config/aptitude_test) ═══════════════
enum AptDim { scientific, literary, technical, medical, business }

class AptOption {
  final String text;
  final AptDim dim;
  const AptOption(this.text, this.dim);
}

class AptitudeQ {
  final String text;
  final List<AptOption> options;
  const AptitudeQ(this.text, this.options);
}

const Map<AptDim, String> aptDimNames = {
  AptDim.scientific: "المجال العلمي والهندسي",
  AptDim.literary: "المجال الأدبي والإنساني",
  AptDim.technical: "المجال التقني والحاسوبي",
  AptDim.medical: "المجال الطبي والصحي",
  AptDim.business: "مجال الأعمال والإدارة",
};

const Map<AptDim, List<String>> aptSuggestedMajors = {
  AptDim.scientific: ["هندسة مدنية", "هندسة كهربائية", "فيزياء تطبيقية", "هندسة ميكانيكية"],
  AptDim.literary: ["إعلام وصحافة", "قانون", "علاقات دولية", "لغات وترجمة"],
  AptDim.technical: ["هندسة حاسوب", "علوم بيانات", "أمن سيبراني", "ذكاء اصطناعي"],
  AptDim.medical: ["طب بشري", "صيدلة", "تمريض", "طب أسنان"],
  AptDim.business: ["إدارة أعمال", "تسويق رقمي", "محاسبة", "اقتصاد"],
};

const List<AptitudeQ> demoAptitude = [
  AptitudeQ("أي نشاط يجذبك أكثر في وقت فراغك؟", [
    AptOption("حل الألغاز والمسائل الرياضية", AptDim.scientific),
    AptOption("القراءة والكتابة والنقاش", AptDim.literary),
    AptOption("تجربة برامج وأجهزة جديدة", AptDim.technical),
    AptOption("متابعة برامج عن الصحة والجسم", AptDim.medical),
  ]),
  AptitudeQ("عند العمل في مشروع جماعي، تفضّل أن:", [
    AptOption("تدير الفريق وتوزّع المهام", AptDim.business),
    AptOption("تصمم الحل التقني وتبرمجه", AptDim.technical),
    AptOption("تحلل الأرقام والنتائج", AptDim.scientific),
    AptOption("تكتب التقرير وتعرضه بأسلوب مقنع", AptDim.literary),
  ]),
  AptitudeQ("أي مادة دراسية تستمتع بها أكثر؟", [
    AptOption("الفيزياء والرياضيات", AptDim.scientific),
    AptOption("الأحياء والكيمياء", AptDim.medical),
    AptOption("اللغة العربية والأدب", AptDim.literary),
    AptOption("الحاسوب والتقنية", AptDim.technical),
  ]),
  AptitudeQ("ما الذي يشعرك بالإنجاز؟", [
    AptOption("مساعدة مريض على التعافي", AptDim.medical),
    AptOption("بناء تطبيق يستخدمه الناس", AptDim.technical),
    AptOption("إنجاح مشروع تجاري", AptDim.business),
    AptOption("اختراع حل هندسي لمشكلة", AptDim.scientific),
  ]),
  AptitudeQ("كيف تحب أن تقضي يوم عمل مثالي؟", [
    AptOption("في مختبر أو ورشة", AptDim.scientific),
    AptOption("أمام الحاسوب أطوّر أنظمة", AptDim.technical),
    AptOption("في اجتماعات وصفقات", AptDim.business),
    AptOption("مع أشخاص أساعدهم وأعالجهم", AptDim.medical),
  ]),
  AptitudeQ("أي موضوع تحب القراءة عنه؟", [
    AptOption("التاريخ والسياسة والفلسفة", AptDim.literary),
    AptOption("الفضاء والطاقة والاختراعات", AptDim.scientific),
    AptOption("التكنولوجيا والذكاء الاصطناعي", AptDim.technical),
    AptOption("ريادة الأعمال والاستثمار", AptDim.business),
  ]),
  AptitudeQ("عند مواجهة مشكلة، أول ما تفعله:", [
    AptOption("تحللها منطقياً بالأرقام", AptDim.scientific),
    AptOption("تبحث عن حل تقني ذكي", AptDim.technical),
    AptOption("تفكر بتأثيرها على الناس", AptDim.medical),
    AptOption("تحسب تكلفتها وعائدها", AptDim.business),
  ]),
  AptitudeQ("أي مهارة تتمنى إتقانها؟", [
    AptOption("الخطابة والكتابة المؤثرة", AptDim.literary),
    AptOption("البرمجة وتحليل البيانات", AptDim.technical),
    AptOption("التشخيص الطبي", AptDim.medical),
    AptOption("القيادة وإدارة الفرق", AptDim.business),
  ]),
  AptitudeQ("ما نوع الأفلام/المحتوى المفضل لديك؟", [
    AptOption("وثائقيات علمية", AptDim.scientific),
    AptOption("قصص وروايات ودراما", AptDim.literary),
    AptOption("محتوى تقني ومراجعات", AptDim.technical),
    AptOption("برامج صحية وطبية", AptDim.medical),
  ]),
  AptitudeQ("أي بيئة عمل تناسبك؟", [
    AptOption("مستشفى أو عيادة", AptDim.medical),
    AptOption("شركة تقنية", AptDim.technical),
    AptOption("مؤسسة أو بنك", AptDim.business),
    AptOption("مركز أبحاث", AptDim.scientific),
  ]),
  AptitudeQ("ما الذي يميّزك بين أصدقائك؟", [
    AptOption("قوة الإقناع والتعبير", AptDim.literary),
    AptOption("الدقة والتفكير المنطقي", AptDim.scientific),
    AptOption("حب مساعدة الآخرين", AptDim.medical),
    AptOption("روح المبادرة والقيادة", AptDim.business),
  ]),
  AptitudeQ("لو أنشأت مشروعاً، سيكون:", [
    AptOption("تطبيقاً أو منصة رقمية", AptDim.technical),
    AptOption("عيادة أو مركزاً صحياً", AptDim.medical),
    AptOption("شركة تجارية", AptDim.business),
    AptOption("مركز أبحاث وتطوير", AptDim.scientific),
  ]),
  AptitudeQ("أي جائزة تتمنى الحصول عليها؟", [
    AptOption("جائزة في الأدب أو الإعلام", AptDim.literary),
    AptOption("براءة اختراع", AptDim.scientific),
    AptOption("جائزة أفضل تطبيق", AptDim.technical),
    AptOption("جائزة رائد أعمال", AptDim.business),
  ]),
  AptitudeQ("ما الذي تفكر فيه عند سماع كلمة (مستقبل)؟", [
    AptOption("تطور طبي ينقذ الأرواح", AptDim.medical),
    AptOption("مدن ذكية وتقنيات", AptDim.technical),
    AptOption("اكتشافات علمية", AptDim.scientific),
    AptOption("فرص عمل واستثمار", AptDim.business),
  ]),
  AptitudeQ("أكثر شيء يشعرك بالفضول:", [
    AptOption("كيف يعمل جسم الإنسان", AptDim.medical),
    AptOption("كيف تعمل الآلات والقوانين", AptDim.scientific),
    AptOption("كيف تُبنى البرامج", AptDim.technical),
    AptOption("كيف تنمو الأفكار والقصص", AptDim.literary),
  ]),
];

// ═══════════════ نصوص الروبوت لكل شاشة (محاكاة config/prompts.intro_text) ═══════════════
const Map<String, String> robotIntro = {
  "home": "أهلاً بك في مسار! 👋 من هنا تصل لكل شيء: التعليم، المنح، الاختبارات، والخدمات. اضغط أي بطاقة لتبدأ، وأنا موجود في كل شاشة لمساعدتك.",
  "education": "هنا قسم التعليم 📚 اختر مادتك من القائمة، وحدد الوضع (شرح/تلخيص/سؤال/وزاري) من زر الإعدادات، ثم اكتب أو اسألني مباشرة. جرّب أيضاً المايك 🎤 والكاميرا 📷!",
  "scholarships": "قسم المنح 🎓 تصفّح المنح حول العالم، وافتح أي منحة لترى شروطها ومواعيدها وطريقة التقديم، وتقدر تسألني مساعد كل منحة عن أي تفصيل.",
  "quiz": "اختبر نفسك 🧠 اختر مادة ووحدة وعدد الأسئلة، وبعد الاختبار سأريك نتيجتك ونقاط ضعفك مع رابط مباشر لشرح كل نقطة. أو جرّب اختبار الميول لتكتشف تخصصك!",
  "services": "قسم الخدمات 🛠️ فريق مسار يساعدك في سيرتك الذاتية، خطاب الدافع، الترجمة، وتجهيز ملف التقديم كاملاً. اختر الخدمة وتواصل معنا مباشرة.",
};

const Map<String, String> robotHint = {
  "home": "محتار من وين تبدأ؟ 😊",
  "education": "اسألني عن أي درس!",
  "scholarships": "أي منحة تناسبك؟",
  "quiz": "جاهز للتحدي؟ 💪",
  "services": "كيف أساعدك؟",
  "analysis": "خلني أحلل مستواك 📊",
};

// ═══════════════ تحليل المستوى (محاكاة results) ═══════════════
class ReviewLesson {
  final String name;
  final int errors;
  const ReviewLesson(this.name, this.errors);
}

class SubjectStats {
  final String subject;
  final String emoji;
  final int stars; // 0..5
  final String level;
  final int avg;
  final int tests;
  final int best;
  final int last;
  final String recEmoji;
  final String recText;
  final List<ReviewLesson> lessons;
  const SubjectStats({
    required this.subject,
    required this.emoji,
    required this.stars,
    required this.level,
    required this.avg,
    required this.tests,
    required this.best,
    required this.last,
    required this.recEmoji,
    required this.recText,
    required this.lessons,
  });
}

// الملخص العام
class OverallStats {
  final int tests;
  final int avg;
  final String bestSubject;
  final int lastResult;
  const OverallStats(this.tests, this.avg, this.bestSubject, this.lastResult);
}

const OverallStats demoOverall = OverallStats(26, 84, "الأحياء", 92);

const Map<String, SubjectStats> demoAnalysis = {
  "رياضيات": SubjectStats(
    subject: "الرياضيات",
    emoji: "📘",
    stars: 4,
    level: "جيد جداً",
    avg: 82,
    tests: 14,
    best: 95,
    last: 85,
    recEmoji: "🎉",
    recText: "مستواك جيد جداً.\nلقد حققت نتائج جيدة في أغلب الاختبارات، ولكن ننصحك بمراجعة بعض الدروس للوصول إلى مستوى ممتاز.",
    lessons: [ReviewLesson("درس الاشتقاق", 8), ReviewLesson("قاعدة السلسلة", 6), ReviewLesson("تطبيقات الاشتقاق", 4)],
  ),
  "فيزياء": SubjectStats(
    subject: "الفيزياء",
    emoji: "📗",
    stars: 3,
    level: "جيد",
    avg: 74,
    tests: 5,
    best: 88,
    last: 79,
    recEmoji: "💪",
    recText: "مستواك جيد.\nأنت على الطريق الصحيح، وبمراجعة الدروس التالية ستنتقل إلى مستوى أعلى بإذن الله.",
    lessons: [ReviewLesson("قوانين نيوتن", 7), ReviewLesson("نظرية بوهر", 5), ReviewLesson("الكهرومغناطيسية", 3)],
  ),
  "احياء": SubjectStats(
    subject: "الأحياء",
    emoji: "📙",
    stars: 5,
    level: "ممتاز",
    avg: 93,
    tests: 4,
    best: 98,
    last: 92,
    recEmoji: "🌟",
    recText: "أداء ممتاز!\nمستواك في الأحياء رائع، حافظ على هذا التميز واستمر في المراجعة الدورية.",
    lessons: [ReviewLesson("الوراثة", 2), ReviewLesson("التنظيم الهرموني", 1)],
  ),
  "كيمياء": SubjectStats(
    subject: "الكيمياء",
    emoji: "⚗️",
    stars: 3,
    level: "جيد",
    avg: 71,
    tests: 1,
    best: 76,
    last: 76,
    recEmoji: "💪",
    recText: "مستواك جيد.\nركّز على مراجعة الدروس التالية لرفع نتيجتك في الاختبارات القادمة.",
    lessons: [ReviewLesson("الأحماض والقواعد", 6), ReviewLesson("الاتزان الكيميائي", 5), ReviewLesson("التفاعلات", 4)],
  ),
  "عربي": SubjectStats(
    subject: "اللغة العربية",
    emoji: "📕",
    stars: 4,
    level: "جيد جداً",
    avg: 86,
    tests: 1,
    best: 90,
    last: 90,
    recEmoji: "🎉",
    recText: "مستواك جيد جداً.\nأداؤك في العربية مميز، مع القليل من المراجعة ستصل للإتقان الكامل.",
    lessons: [ReviewLesson("النحو والصرف", 4), ReviewLesson("البلاغة", 3)],
  ),
  "انجليزي": SubjectStats(
    subject: "اللغة الإنجليزية",
    emoji: "📖",
    stars: 3,
    level: "جيد",
    avg: 78,
    tests: 1,
    best: 82,
    last: 82,
    recEmoji: "💪",
    recText: "مستواك جيد.\nراجع القواعد التالية وستلاحظ تحسناً واضحاً في نتائجك.",
    lessons: [ReviewLesson("Passive Voice", 5), ReviewLesson("Tenses", 4), ReviewLesson("Reported Speech", 3)],
  ),
};

// المنهج: مادة → وحدة → دروس (لإعداد الاختبار)
const Map<String, Map<String, List<String>>> demoCurriculum = {
  "رياضيات": {
    "التفاضل": ["الاشتقاق", "قاعدة السلسلة", "تطبيقات الاشتقاق", "المشتقات العليا"],
    "التكامل": ["التكامل المحدود", "التكامل بالتعويض", "تطبيقات التكامل"],
    "الجبر": ["المتباينات", "الدوال", "المصفوفات"],
  },
  "فيزياء": {
    "الميكانيكا": ["قوانين نيوتن", "الشغل والطاقة", "الزخم"],
    "الكهرباء": ["قانون أوم", "الدوائر الكهربائية", "الكهرومغناطيسية"],
    "الفيزياء الحديثة": ["نظرية بوهر", "الإشعاع", "الكم"],
  },
  "كيمياء": {
    "الكيمياء العامة": ["بنية الذرة", "الروابط", "الجدول الدوري"],
    "التفاعلات": ["الأحماض والقواعد", "الاتزان الكيميائي", "الأكسدة والاختزال"],
    "الكيمياء العضوية": ["الهيدروكربونات", "المجموعات الوظيفية"],
  },
  "احياء": {
    "الخلية": ["تركيب الخلية", "الانقسام", "الأغشية"],
    "الوراثة": ["قوانين مندل", "الحمض النووي", "الطفرات"],
    "جسم الإنسان": ["التنظيم الهرموني", "الجهاز العصبي", "الدوران"],
  },
  "عربي": {
    "النحو والصرف": ["المفعول لأجله", "الإعراب", "الجموع"],
    "البلاغة": ["التشبيه", "الطباق", "الاستعارة"],
    "الأدب": ["الشعر الحديث", "النثر"],
  },
  "انجليزي": {
    "Grammar": ["Passive Voice", "Tenses", "Reported Speech", "Conditionals"],
    "Vocabulary": ["Synonyms", "Antonyms", "Word Formation"],
    "Reading": ["Comprehension", "Spot the Mistakes"],
  },
};
