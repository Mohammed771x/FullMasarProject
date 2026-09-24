import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'phosphor.dart';

// ==========================================
// 📍 نتيجةُ بحثٍ واحدة — كما في ChatGPT
// ==========================================
// 🎯 **طلبُ المالك (٢٠٢٦-٠٩-٢٤):** «يطلع كم سطر من المكان الفعلي،
//    والكلمة مغطّاة، ويوديني على المحادثة المطلوبة».
//
// 📐 سطرُ رأسٍ (أيقونةٌ · اسمُ المحادثة · وسمُ مكانها) ثم **ثلاثةُ أسطرٍ**
//    من الرسالة التي وُجدت فيها الكلمة، تبدأ بـ«أنت:» أو «مسار:» كي يعرف
//    أهو سؤالُه أم الجواب، والكلمةُ نفسُها **مظلَّلةٌ بلون الهوية**.
//
// 🔁 **مشتركةٌ بين قسم التعليم وقسم المعلم والمنح** — بحثٌ واحدٌ بشكلٍ واحد.
class SearchHitTile extends StatelessWidget {
  const SearchHitTile({
    super.key,
    required this.title,
    required this.tag,
    required this.before,
    required this.match,
    required this.after,
    required this.isUser,
    required this.inTitleOnly,
    required this.onTap,
    this.assistantName = "مسار",
  });

  final String title;

  /// أين هي — «احياء · شرح» أو اسمُ المنحة.
  final String tag;

  final String before;
  final String match;
  final String after;
  final bool isUser;

  /// التطابقُ في اسم المحادثة وحده — فلا مقتطفَ رسالة.
  final bool inTitleOnly;

  final VoidCallback onTap;
  final String assistantName;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
        fontSize: 12,
        height: 1.65,
        fontWeight: FontWeight.w600,
        color: AppColors.chipInk);
    final hit = base.copyWith(
      fontWeight: FontWeight.w900,
      color: AppColors.primary,
      backgroundColor: AppColors.primary.withValues(alpha: 0.14),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.rowBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(PI.chatCircleDots.regular,
                        size: 17, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: inTitleOnly
                          ? Text.rich(
                              TextSpan(children: [
                                TextSpan(text: before),
                                TextSpan(text: match, style: hit.copyWith(fontSize: 12.5)),
                                TextSpan(text: after),
                              ]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _titleStyle,
                            )
                          : Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _titleStyle),
                    ),
                    const SizedBox(width: 8),
                    // 🏷️ الوسمُ لا يزاحم الاسم: سقفُه ثلثُ السطر تقريباً.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 110),
                      child: Text(tag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.cardHint)),
                    ),
                  ],
                ),
                if (!inTitleOnly) ...[
                  const SizedBox(height: 6),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: isUser ? "أنت: " : "$assistantName: ",
                        style: base.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.headingInk),
                      ),
                      TextSpan(text: before),
                      TextSpan(text: match, style: hit),
                      TextSpan(text: after),
                    ]),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: base,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle get _titleStyle => TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w800,
      color: AppColors.textPrimary);
}
