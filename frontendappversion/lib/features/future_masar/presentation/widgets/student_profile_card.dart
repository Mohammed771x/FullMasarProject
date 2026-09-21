import 'package:flutter/material.dart';

import '../../../../core/config/curriculum.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/phosphor.dart';
import '../../../../core/widgets/user_avatar.dart';
import 'analysis_ui.dart';

// ==========================================
// 👤 بطاقةُ الطالب — رأسُ «معلومات الطالب»
// ==========================================
// 🎨 **المصدر:** `design/03-home/22-معلومات.png`. مقيسٌ من التصدير (@2x):
//
//      البطاقة 342×252 · r20 · حشوة 18
//      تدرّجٌ قطريّ `#A5C0FC → #7B9CEE` وفوقه دوائرُ زينة
//      الصورة 75 دائرية · الاسم 22/w900 · الصف 12/w700
//      الشريط 9 مستديرٌ بالكامل · «عرض التفاصيل» 31 بعرض 121 r16
//
// ⚠️ **والشريطُ يمتلئ من اليمين.** رسمه المصمّم ممتلئاً من اليسار — وهو
//    رسمُ Figma الافتراضيّ (LTR) لا قرارٌ: كلُّ شريطِ تقدّمٍ في التطبيق
//    (الاختبار · أشرطةُ المفاهيم) ينمو من اليمين لأن الواجهة عربية،
//    وشريطٌ واحدٌ معكوسٌ يُقرأ خطأً. (انحرافٌ مقصود، مسجَّلٌ في `INVENTORY`.)

class StudentProfileCard extends StatelessWidget {
  /// مفتاحُ شريط التقدّم — يقيسه الاختبارُ لأنه سقط بعرضِ صفرٍ مرّتين.
  static const Key barKey = Key("student-progress-bar");

  /// والمقطوعُ منه — **هو** ما يُقاس: الصندوقُ الخارجيّ كان بمقاسه الصحيح
  /// بينما جزءاه بارتفاع صفر، فمرّ الحارسُ الأوّلُ على عيبٍ قائم.
  static const Key doneKey = Key("student-progress-done");

  const StudentProfileCard({
    super.key,
    required this.studied,
    required this.total,
    required this.onDetails,
    this.onAvatarChanged,
  });

  /// عددُ الموادّ التي درسها الطالب فعلاً، ومجموعُ موادّ صفّه.
  final int studied;
  final int total;

  /// «عرض التفاصيل» — يفتح الإعدادات (حيث تُعدَّل بيانات الحساب).
  final VoidCallback onDetails;

  /// تغييرُ الصورة من داخل البطاقة — فالضغطُ على الصورة في الرئيسية صار
  /// يفتح هذه الشاشة، ولو لم تُنقل هنا لضاع بابُ تغيير الصورة.
  final VoidCallback? onAvatarChanged;

  @override
  Widget build(BuildContext context) {
    final s = UserSession.I;
    final ratio = total <= 0 ? 0.0 : (studied / total).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(AnalysisMetrics.cardRadius),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppColors.analysisProfileGradient,
          borderRadius: BorderRadius.circular(AnalysisMetrics.cardRadius),
        ),
        // ⚠️ **`passthrough` لا `loose`.** بلا ذلك يمرّ القيدُ **رخواً** إلى
        //    العمود، فيتقلّص إلى عرض أعرضِ نصٍّ فيه — **ويختفي شريطُ
        //    التقدّم كلياً** لأنه `SizedBox` بلا عرضٍ ذاتيّ. رأيتُه في
        //    المحاكي: بطاقةٌ كاملةٌ وشريطٌ غائب.
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            // 🎨 دوائرُ الزينة — أربعٌ كما في التصدير، تُقصّ عند الحواف.
            Positioned(top: -34, right: 38, child: _blob(64)),
            Positioned(top: 22, left: -30, child: _blob(96)),
            Positioned(bottom: -26, right: -18, child: _blob(88)),
            Positioned(bottom: 26, left: 54, child: _blob(52)),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 👤 الصورة — وهي أيضاً بابُ تغييرها لمن ليس زائراً.
                  UserAvatar(
                    radius: 37.5,
                    editable: !s.isGuest,
                    onChanged: onAvatarChanged,
                  ),
                  const SizedBox(height: 14),
                  Text(s.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.analysisProfileInk)),
                  const SizedBox(height: 8),
                  Text("الصف ${s.gradeLabel}${Curriculum.hasTracks(s.grade) ? ' — ${s.track}' : ''}",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.analysisProfileButtonInk)),
                  const SizedBox(height: 12),
                  _bar(ratio),
                  const SizedBox(height: 8),
                  Text("مادة درستها $studied / $total",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.analysisProfileInk)),
                  const SizedBox(height: 12),
                  Center(child: _detailsButton()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _blob(double size) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
            color: AppColors.analysisProfileBlob, shape: BoxShape.circle),
      );

  /// شريطُ «مادة درستها» — المقطوعُ أخضرُ باهتٌ **من اليمين**، والباقي كحليّ.
  Widget _bar(double ratio) => ClipRRect(
        borderRadius: BorderRadius.circular(AnalysisMetrics.bar),
        // ⚠️ **`double.infinity` لا `null`.** العمودُ يمرّر لأبنائه قيداً
        //    **رخواً** في العرض (محاذاتُه `center`)، فصندوقٌ بلا عرضٍ
        //    مصرَّحٍ يتقلّص إلى عرض أبنائه — و`Expanded` عرضُه الطبيعي صفر.
        //    فكان الشريطُ يُبنى بعرض **صفر**: موجودٌ في الشجرة، غائبٌ عن
        //    العين. رأيتُه في المحاكي مرّتين قبل أن أفهمه.
        child: SizedBox(
          key: barKey,
          width: double.infinity,
          height: AnalysisMetrics.bar,
          child: Row(
            // ⚠️ **`stretch` لازمةٌ هنا.** الصفُّ يمرّر ارتفاعاً **رخواً**
            //    (0..9)، و`ColoredBox` **بلا ابنٍ** يأخذ `constraints
            //    .smallest` أي ارتفاع **صفر** — فيُرسم الشريطُ بعرضه
            //    الكامل وبلا ارتفاعٍ إطلاقاً. وهذا ما أخفاه، لا العرض.
            //    (والارتفاعُ هنا **محدود** فلا خطرَ من `stretch`.)
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ⚠️ RTL: أوّلُ ابنٍ هو الأيمن ⇒ المقطوعُ يبدأ من اليمين.
              Expanded(
                  flex: (ratio * 1000).round().clamp(1, 1000),
                  child: ColoredBox(
                      key: doneKey, color: AppColors.analysisBarDone)),
              Expanded(
                  flex: ((1 - ratio) * 1000).round().clamp(1, 1000),
                  child: ColoredBox(color: AppColors.analysisBarRest)),
            ],
          ),
        ),
      );

  Widget _detailsButton() => Material(
        color: AppColors.analysisProfileButton,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onDetails,
          borderRadius: BorderRadius.circular(16),
          // 📐 **عرضُه من محتواه لا 121 ثابتاً.** قِستُ التصدير 121، لكنّ
          //    «عرض التفاصيل» بخطّ Cairo عند 11/w900 يخرج أعرضَ في فلاتر
          //    منه في Figma — فكان الصفُّ يفيض 29 بكسلاً. الارتفاعُ 31
          //    والشكلُ كما هما، والعرضُ يتبع النصّ.
          // ⚠️ **بلا `alignment`**: مع قيدٍ رخوٍ يجعلها `Container` تتمدّد
          //    إلى أقصى العرض — فيصير الزرُّ شريطاً عابراً للبطاقة.
          child: Container(
            height: 31,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("عرض التفاصيل",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.analysisProfileButtonInk)),
                const SizedBox(width: 6),
                Icon(PI.caretLeft.bold,
                    size: 12, color: AppColors.analysisProfileButtonInk),
              ],
            ),
          ),
        ),
      );
}
