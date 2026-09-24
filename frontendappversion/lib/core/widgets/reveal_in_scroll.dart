import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

// ==========================================
// 📍 تمريرٌ إلى رسالةٍ بعينها — ومن داخلها إلى موضع الكلمة
// ==========================================
// 🔴 **لماذا لا `Scrollable.ensureVisible(alignment: 0.15)`:** المحاذاةُ نسبةٌ
//    من «الفراغ الباقي» (ارتفاعُ النافذة − ارتفاعُ العنصر). والجوابُ الطويلُ
//    أطولُ من الشاشة، فيصير الفراغُ سالباً وتنزلق المحاذاةُ **داخل** العنصر:
//    رُئي في المحاكي — نتيجةُ بحثٍ في جوابٍ طويل تفتح على وسطه، والإزاحةُ
//    قبل النداء وبعده واحدة (٢٣٦٫٨٥).
//
// ✅ فالحسابُ صريح: رأسُ الرسالة عند ١٢٪ من أعلى النافذة، ثم — إن كانت
//    الرسالةُ أطولَ من ثلث الشاشة — نزولٌ داخلها بنسبة موضع الكلمة
//    ([position] ٠…١) حتى تقع الكلمةُ قرب ربع الشاشة.
Future<void> revealInScroll(
  ScrollController controller,
  BuildContext target, {
  double position = 0,
}) async {
  if (!controller.hasClients || !target.mounted) return;
  final box = target.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return;
  final viewport = RenderAbstractViewport.maybeOf(box);
  if (viewport == null) return;
  final pos = controller.position;
  final view = pos.viewportDimension;
  var offset = viewport.getOffsetToReveal(box, 0).offset - view * 0.12;
  if (position > 0.05 && box.size.height > view / 3) {
    final inside = box.size.height * position - view * 0.25;
    if (inside > 0) offset += inside;
  }
  offset = offset.clamp(pos.minScrollExtent, pos.maxScrollExtent);
  await controller.animateTo(offset,
      duration: const Duration(milliseconds: 380), curve: Curves.easeOutCubic);
}
