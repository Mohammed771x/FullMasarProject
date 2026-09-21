import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_markdown.dart';
import '../../../../core/widgets/phosphor.dart';

// ==========================================
// 🧩 لغةُ «معلومات الطالب / تحليل مستواي» البصرية
// ==========================================
// 🎨 **المصدر:** `design/03-home/21-معلومات.png` و`22-معلومات.png` — الشاشةُ
//    التي **وضع المصمّم التحليلَ داخلها**، لا مجلّد `07-analysis` الفارغ.
//    (قرارُ المالك 2026-09-21: «التحليل حوّلناه إلى قسم الطالب… تظهر لما
//    نضغط على الطالب».)
//
// 📐 وكلُّ رقمٍ هنا **مقيسٌ من بكسلات التصدير** (@2x · إطار 390×844):
//
//      الهامش 24 · بطاقةٌ r20 · صفُّ التركيز 65 بحدٍّ r22
//      شارةُ النسبة 42×38 r8 — `#FCDFDF` بحبر `#ED2C2C`
//      زرُّ «التفاصيل» 39 r16 على `#F5F6F7` بحبر `#42526D`
//      بطاقةُ الملخّص `#3C65CA` · شريطُ التقدّم 9 · حلقةُ المادة 46 بسماكة 4
//      بطاقةُ المراجعة 83 بتدرّجٍ `#36259D → #5047E6`
//
// ⭐ **ولماذا هنا لا في كل شاشة؟** صفُّ «تحتاج تركيز» نفسُه يظهر في
//    الرئيسية وفي شاشة التحليل وفي شاشة المادة. نسخُه ثلاثاً يعني افتراقَه
//    عند أوّل تعديل — وقد كان منسوخاً في الرئيسية فعلاً.

/// 📏 ثوابتُ القياس — تُقرأ من الشاشات بدل أن تُكرَّر أرقاماً عارية.
class AnalysisMetrics {
  AnalysisMetrics._();

  static const double margin = 24;
  static const double gap = 12;
  static const double cardRadius = 20;

  /// صفُّ «الدروس التي تحتاج تركيز» — 65 بنصف قطر 22.
  static const double focusRow = 65;
  static const double focusRadius = 22;
  static const double badgeW = 42;
  static const double badgeH = 38;
  static const double badgeRadius = 8;
  static const double action = 39;
  static const double actionRadius = 16;

  /// حلقةُ بطاقة المادة — **دائرةٌ كاملة** 46 بسماكة 4، لا قوسُ تقدّم.
  static const double ring = 46;
  static const double ringStroke = 4;

  /// زرُّ الورقة السفلية — 53، كزرَّي شاشة نتيجة الاختبار.
  static const double sheetButton = 53;

  /// بطاقةُ المادة 78 · بطاقةُ المراجعة 83 · شريطُ التقدّم 9.
  static const double subjectCard = 78;
  static const double reviewCard = 83;
  static const double bar = 9;
}

// ══════════════════════════════════════════════════
// 🎨 لونُ المستوى — ثلاثُ درجاتٍ من التصدير
// ══════════════════════════════════════════════════
/// 🟢🔵🔴 قِستُ حلقتَي التصدير: «ممتاز 100» على `#20D958` و«جيد 79» على
///    `#0092FF` — وهما `success500` و`primary500` **حرفاً**، أي أن المصمّم
///    بنى الحلقة من سلالم المشروع نفسِها. والثالثةُ للضعيف `error500`.
///
/// ⚠️ ولا رابعةَ: المصمّم لم يرسم كهرماناً هنا، وخمسُ درجاتٍ في حلقةٍ قطرُها
///    46 لا تُميَّز بالعين أصلاً.
Color analysisBand(int percent) => percent >= 80
    ? AppColors.success500
    : (percent >= 50 ? AppColors.primary500 : AppColors.error500);

// ══════════════════════════════════════════════════
// 🏷️ عنوانُ قسمٍ داخل الصفحة
// ══════════════════════════════════════════════════
/// 📐 16/w900 بحبر العناوين — نفسُ «الدروس التي تحتاج تركيز» في الرئيسية،
///    وهي من هذا التصدير نفسِه.
class AnalysisSectionTitle extends StatelessWidget {
  const AnalysisSectionTitle(this.text, {super.key, this.trailing});

  final String text;

  /// «عرض الكل» ونحوُه — في **يسار** السطر كما في التصميم.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final label = Text(text,
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: AppColors.headingInk));
    if (trailing == null) {
      return Align(alignment: Alignment.centerRight, child: label);
    }
    return Row(children: [label, const Spacer(), trailing!]);
  }
}

// ══════════════════════════════════════════════════
// 🎯 صفُّ «الدروس التي تحتاج تركيز»
// ══════════════════════════════════════════════════
/// 📐 مقيسٌ من التصدير: 65 ارتفاعاً · r22 · حشوةٌ أفقيّة 13 ·
///    شارةٌ 42×38 r8 (`#FCDFDF` / `#ED2C2C`) · عنوانٌ 12.5/w900 ·
///    وصفٌ 10/w400 (`#667085`) · زرٌّ 39 r16 (`#F5F6F7` / `#42526D`).
///
/// ⭐ **وهو الصفُّ نفسُه في الرئيسية** — كان منسوخاً هناك، فصار واحداً.
class AnalysisFocusRow extends StatelessWidget {
  const AnalysisFocusRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.percent,
    required this.onTap,
    this.actionLabel = "التفاصيل",
  });

  final String title;
  final String subtitle;
  final int percent;
  final VoidCallback onTap;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AnalysisMetrics.focusRadius),
        child: Container(
          height: AnalysisMetrics.focusRow,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: AppColors.surfaceWhite,
            borderRadius:
                BorderRadius.circular(AnalysisMetrics.focusRadius),
            border: Border.all(color: AppColors.rowBorder),
          ),
          child: Row(
            children: [
              // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — وهناك الشارةُ في التصميم.
              Container(
                width: AnalysisMetrics.badgeW,
                height: AnalysisMetrics.badgeH,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.errorTint,
                  borderRadius:
                      BorderRadius.circular(AnalysisMetrics.badgeRadius),
                ),
                child: Text("$percent%",
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.error500)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 🖌️ بالرسّام: اسمُ الدرس قد يكون صيغةً لا كلمة.
                    MathOrText(title,
                        maxLines: 1,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                            color: AppColors.headingInk)),
                    if (subtitle.isNotEmpty)
                      MathOrText(subtitle,
                          maxLines: 1,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w400,
                              color: AppColors.rowHint)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              AnalysisRowAction(label: actionLabel, onTap: onTap),
            ],
          ),
        ),
      );
}

/// زرُّ الصفّ الصغير — 39 r16 على `#F5F6F7` بحبر `#42526D` وسهمٍ يساراً.
class AnalysisRowAction extends StatelessWidget {
  const AnalysisRowAction({
    super.key,
    required this.label,
    required this.onTap,
    this.icon = PI.caretLeft,
  });

  final String label;
  final VoidCallback onTap;
  final PIcon icon;

  @override
  Widget build(BuildContext context) => Material(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(AnalysisMetrics.actionRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AnalysisMetrics.actionRadius),
          child: Container(
            height: AnalysisMetrics.action,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.rowAction)),
                const SizedBox(width: 6),
                Icon(icon.bold, size: 12, color: AppColors.rowAction),
              ],
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🔵 السطحُ الكحليّ — بطاقةُ الملخّص وبطاقةُ النصيحة
// ══════════════════════════════════════════════════
/// 📐 `#3C65CA` (`secondary500` حرفاً) بنصف قطر 20 وحشوة 18.
///
/// 🌙 **وحبرُه يتبع الوضع لا يثبت**: نصٌّ أبيضُ على كحليٍّ في الفاتح يبقى
///    أبيضَ في الداكن، لكنّ السطحَ نفسَه يُعمَّق كي لا يشعّ في ليل.
class AnalysisNavyCard extends StatelessWidget {
  const AnalysisNavyCard({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.analysisNavy,
          borderRadius: BorderRadius.circular(AnalysisMetrics.cardRadius),
        ),
        child: child,
      );
}

/// عمودُ رقمٍ وتسميةٍ داخل البطاقة الكحليّة.
class AnalysisNavyStat extends StatelessWidget {
  const AnalysisNavyStat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 6),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.86))),
        ],
      );
}

/// فاصلٌ رأسيٌّ بين أعمدة البطاقة الكحليّة — `#4B71CE` في التصدير.
class AnalysisNavyDivider extends StatelessWidget {
  const AnalysisNavyDivider({super.key, this.height = 44});

  final double height;

  @override
  Widget build(BuildContext context) => Container(
        width: 1,
        height: height,
        color: Colors.white.withValues(alpha: 0.22),
      );
}

// ══════════════════════════════════════════════════
// ⭕ حلقةُ المادة — دائرةٌ كاملة لا قوسُ تقدّم
// ══════════════════════════════════════════════════
/// 📐 46 قطراً بسماكة 4، والرقمُ بداخلها **بلا علامة %** كما في التصدير.
///
/// ⚠️ **وليست `CircularProgressIndicator`**: في التصدير حلقةُ «79» مكتملةٌ
///    كحلقة «100» — فهي **شارةُ مستوى** لا مقياسَ تقدّم. ورسمُها قوساً
///    ناقصاً يقول شيئاً لم يقله المصمّم.
class AnalysisScoreRing extends StatelessWidget {
  const AnalysisScoreRing({super.key, required this.percent, this.size = AnalysisMetrics.ring});

  final int percent;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = analysisBand(percent);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: AnalysisMetrics.ringStroke),
      ),
      child: Text("$percent",
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: AppColors.headingInk)),
    );
  }
}

// ══════════════════════════════════════════════════
// 📚 صفُّ «تحليل المواد»
// ══════════════════════════════════════════════════
/// 📐 بطاقةٌ بيضاء 78 · r20 · حدٌّ `#E8EDF3` · الحلقةُ يميناً ثم الاسمُ
///    14/w900 وتحته «ممتاز • 3 اختبارات» بلون المستوى، والسهمُ يساراً.
class AnalysisSubjectRow extends StatelessWidget {
  const AnalysisSubjectRow({
    super.key,
    required this.subject,
    required this.percent,
    required this.label,
    required this.quizzes,
    required this.onTap,
  });

  final String subject;
  final int percent;
  final String label;
  final int quizzes;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = analysisBand(percent);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AnalysisMetrics.cardRadius),
      child: Container(
        height: AnalysisMetrics.subjectCard,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: BorderRadius.circular(AnalysisMetrics.cardRadius),
          border: Border.all(color: AppColors.quizCardBorder),
        ),
        child: Row(
          children: [
            AnalysisScoreRing(percent: percent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.headingInk)),
                  const SizedBox(height: 6),
                  Text("$label • ${arabicQuizzes(quizzes)}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: color)),
                ],
              ),
            ),
            Icon(PI.caretLeft.regular, size: 18, color: AppColors.rowAction),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 📅 بطاقةُ «اختبار مراجعة»
// ══════════════════════════════════════════════════
/// 📐 83 ارتفاعاً · r20 · تدرّجٌ أفقيّ `#36259D` (يمين) → `#5047E6` (يسار)
///    · أيقونةُ تقويمٍ بيضاء يميناً · دائرةٌ بيضاء 46 فيها سهمٌ يساراً.
class AnalysisReviewCard extends StatelessWidget {
  const AnalysisReviewCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AnalysisMetrics.cardRadius),
        child: Container(
          constraints: const BoxConstraints(minHeight: AnalysisMetrics.reviewCard),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.analysisReviewGradient,
            borderRadius: BorderRadius.circular(AnalysisMetrics.cardRadius),
          ),
          child: Row(
            children: [
              // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن — وهناك التقويمُ في التصميم.
              Icon(PI.calendar.regular, size: 34, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 10.5,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9))),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Icon(PI.arrowLeft.bold,
                    size: 20, color: AppColors.headingInk),
              ),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🔤 تمييزُ العدد بالعربية
// ══════════════════════════════════════════════════
/// ⚠️ «آخر 2 اختبارات» عربيّةٌ مكسورة، و«آخر اختباران» مكسورةٌ أيضاً:
///    ما بعد «آخر» مضافٌ إليه. والصيغةُ هنا صيغةُ الإضافة.
String arabicQuizzes(int n, {bool afterAkhir = false}) => switch (n) {
      <= 0 => "لا اختبارات",
      1 => afterAkhir ? "اختبار" : "اختبار واحد",
      2 => afterAkhir ? "اختبارين" : "اختباران",
      _ => "$n اختبارات",
    };

/// ❌ «خطأ» و«خطآن» و«3 أخطاء» و«11 خطأً» — تمييزُ العدد بابٌ في العربية.
String arabicMistakes(int n) => switch (n) {
      <= 0 => "بلا أخطاء",
      1 => "خطأ",
      2 => "خطآن",
      <= 10 => "$n أخطاء",
      _ => "$n خطأً",
    };

// ══════════════════════════════════════════════════
// 📄 هيكلُ الورقة السفلية
// ══════════════════════════════════════════════════
/// ⭐ الورقتان (نقطةُ الضعف · اختبارُ المراجعة) تتشاركان الهيكلَ نفسَه:
///    مقبضٌ 42×4، وحشوةٌ 20، وإزاحةٌ فوق الكيبورد.
Future<T?> showAnalysisSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceWhite,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.rowBorder,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════
// 📈 خطُّ التقدّم — 🆕 لم يرسمه المصمّم
// ══════════════════════════════════════════════════
/// ⚠️ **والمحورُ الرأسي ثابتٌ 0–100** لا مشدودٌ إلى أصغرِ نقطةٍ وأكبرها:
///    مقياسٌ متحرّك يجعل فرقَ نقطتين يبدو هاوية، فيقرأ الطالبُ تحسّناً
///    وهمياً أو انهياراً وهمياً.
class AnalysisSparkline extends StatelessWidget {
  const AnalysisSparkline({super.key, required this.points, this.height = 66});

  final List<int> points;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: CustomPaint(
          painter: _SparkPainter(points, AppColors.primary),
          child: const SizedBox.expand(),
        ),
      );
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.points, this.color);

  final List<int> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    double x(int i) => size.width * i / (points.length - 1);
    double y(int v) => size.height * (1 - v / 100);

    final line = Path()..moveTo(x(0), y(points.first));
    for (var i = 1; i < points.length; i++) {
      line.lineTo(x(i), y(points[i]));
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(fill, Paint()..color = color.withValues(alpha: 0.12));
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..strokeWidth = 2.4
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);

    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(Offset(x(i), y(points[i])), 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(_SparkPainter old) => old.points != points;
}

/// ⏳ «قبل …» بعربيّةٍ سليمة — مفردٌ ومثنّى وجمعٌ وتمييزُ عدد.
///
/// 🔴 **رُصد في فحص قسم التحليل (٢٠٢٦-٠٩-٢٢):** سجلُّ اختبارات الأحياء
///    كان يقول **«قبل 1 أسابيع»** لاختبارٍ عمرُه أسبوع، و«قبل 2 أيام»
///    مكانَ «قبل يومين». التمييزُ بابٌ في العربية لا تفصيلاً تجميلياً،
///    وهذه شاشةٌ يقرؤها طالبٌ في حصّة اللغة العربية نفسِها.
String arabicAgo(
  int n, {
  required String one,
  required String two,
  required String few,
  required String many,
}) =>
    switch (n) {
      <= 1 => "قبل $one",
      2 => "قبل $two",
      <= 10 => "قبل $n $few",
      _ => "قبل $n $many",
    };
