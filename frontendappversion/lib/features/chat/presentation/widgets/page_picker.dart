// ==========================================
// 📄 مُنتقي الصفحات — أفقيّ، والصفحات تظهر مباشرةً
// ==========================================
// 🔴 **ما كان (وشكا منه المالك 2026-09-09):** الطالب يكتب أرقام الصفحات
//    بيده داخل سؤاله — «13، 14، 15» — من ذاكرته أو من الكتاب الورقي.
//    فإن أخطأ رقماً لم يعرف أنه أخطأ، وإن سأل سؤالاً تبعياً ضاعت صفحاته.
//
// ⭐ **وما صار:** «تطلع الصفحات اللي موجودة في الوحدة… أختار صفحة، أسوي
//    لها إضافة». الأرقام تصل مع `/content/capabilities` نفسه، فالقائمة
//    جاهزةٌ لحظةَ فتح الإعدادات بلا انتظار.
//
// ↔️ **ولماذا أفقيّ؟** طلبُ المالك حرفياً: «نتحرك بين الصفحات أفقياً، من
//    اليمين لليسار… زي التاريخ لما تختار السنة». والقائمة قد تبلغ ٣٤ صفحة
//    في الوحدة الواحدة، فشريطٌ أفقيّ يريها كلها بلا أن يبتلع الشاشة كما
//    تفعل قائمةٌ رأسية.

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../controllers/chat_controller.dart';

class PagePicker extends StatefulWidget {
  final ChatController controller;
  const PagePicker(this.controller, {super.key});

  @override
  State<PagePicker> createState() => _PagePickerState();
}

class _PagePickerState extends State<PagePicker> {
  // 🔴 **الرسالة داخل المُنتقي لا في SnackBar.**
  //
  //    لوحةُ الإعدادات طبقةٌ فوق الشاشة (`AnimatedPositioned`)، والـSnackBar
  //    يظهر في قاع الـScaffold — أي **تحتها فلا يُرى**. جرّبتُه في المحاكي:
  //    الضغطة الرابعة تُرفض بصمت، وهو عين ما يشكو منه المالك.
  //
  // ⭐ وهنا أفضل موضعاً على كل حال: العين على الشريط حين تُرفض الضغطة.
  //
  // ⏱️ **ولا تختفي بمؤقّت**: ثلاث ثوانٍ تمرّ والطالب ينظر إلى الشريط لا
  //    إلى موضع الرسالة، فيفوته التفسير ويبقى الرفض بلا سبب في ذهنه.
  //    تزول حين يفعل شيئاً — يرفع صفحةً أو يضيف أخرى — فتكون قد أدّت عملها.
  String? _warning;

  ChatController get c => widget.controller;

  void _warn(String? message) {
    if (_warning == message) return;
    setState(() => _warning = message);
  }

  @override
  Widget build(BuildContext context) {
    final pages = c.availablePages;

    if (pages.isEmpty) {
      // ⚠️ رسالةٌ صريحة لا شريطٌ فارغ: الفراغ يبدو عطلاً في التطبيق،
      //    والحقيقة أن هذه الوحدة بلا صفحات مرقّمة بعد.
      return _hint("لا توجد صفحات مرقّمة في هذا النطاق بعد.");
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.menu_book_rounded,
                size: 18, color: AppColors.primary),
            const SizedBox(width: 6),
            Text("اختر الصفحات",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary)),
            const Spacer(),
            // ⚠️ **لا شرطة مائلة**: «0 / 3» تنقلب في العربية فتُقرأ «3 / 0»
            //    أي أن المختار ثلاثةٌ من صفر. و«من» تربط الطرفين فلا تنقلب.
            Text("${c.selectedPages.length} من ${c.maxPages}",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: c.selectedPages.length >= c.maxPages
                        ? AppColors.primary
                        : AppColors.textSecondary)),
          ],
        ),
        const SizedBox(height: 10),

        // ⚠️ **فوق الشريط لا تحته**: لوحةُ الإعدادات تقصّ ما تجاوز حافّتها
        //    السفلى، والشريط ملاصقٌ لها — فرسالةٌ تحته لا تُرى إطلاقاً.
        //    جُرّب في المحاكي: الضغطة الرابعة كانت تُرفض بصمتٍ تام.
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.bottomCenter,
          child: _warning == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(children: [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: Colors.orange.shade700),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(_warning!,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange.shade800)),
                    ),
                  ]),
                ),
        ),
        // ↔️ الشريط الأفقيّ. `reverse: true` كي يبدأ من **اليمين** —
        //    فالعربية تُقرأ من اليمين، وبدءُ الترقيم من اليسار يجعل الطالب
        //    يظن أن أول الصفحات في آخر الشريط.
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            reverse: true,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            itemCount: pages.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, i) => _pageChip(context, pages[i]),
          ),
        ),

      ],
    );
  }

  Widget _pageChip(BuildContext context, int page) {
    final picked = c.selectedPages.contains(page);
    final full = c.selectedPages.length >= c.maxPages && !picked;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      child: Material(
        color: picked ? AppColors.primary : AppColors.softSurface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          // ⚠️ **الممتلئ يُنقر ولا يُعطَّل**: الزرّ المعطّل لا يقول لماذا،
          //    فيبدو التطبيق مكسوراً. والنقر هنا يشرح الحدّ برسالة.
          onTap: () => _toggle(context, page, picked),
          child: Container(
            constraints: const BoxConstraints(minWidth: 56),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (picked) ...[
                  const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white),
                  const SizedBox(width: 4),
                ],
                Text(
                  "$page",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: picked
                        ? Colors.white
                        : (full
                            ? AppColors.textSecondary.withValues(alpha: 0.45)
                            : AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggle(BuildContext context, int page, bool picked) {
    if (picked) {
      c.removePage(page);
      _warn(null);          // أفسحَ مكاناً — فلا معنى لبقاء التحذير
      return;
    }
    _warn(c.addPage(page)); // `null` عند النجاح فتزول الرسالة من نفسها
  }

  Widget _hint(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.softSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          Icon(Icons.info_outline_rounded,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(color: AppColors.textSecondary))),
        ]),
      );


}
