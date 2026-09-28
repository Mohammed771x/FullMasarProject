import 'package:flutter/widgets.dart';

// ==========================================
// 📍 مراسي جولة الشرح — «هنا» التي يشير إليها الروبوت
// ==========================================
// كلُّ عنصرٍ يُشرح يُلفّ بـ[TourAnchor] باسمٍ ثابت ('home.stats' …)، والجولةُ
// تسأل [TourAnchors.rectOf] عن مكانه على الشاشة لحظةَ الشرح.
//
// 🧭 **لماذا سجلٌّ باسمٍ لا مفاتيحُ تُمرَّر؟** العناصرُ موزّعةٌ بين ودجاتٍ لا
//    يعرف بعضُها بعضاً: الشريطُ السفليّ في [MasarShell] والبطاقاتُ في
//    [HomeTab]. والسجلُّ يجعل خطواتِ الجولة قائمةً نصّيةً في ملفٍّ واحد.
//
// ⚠️ **لكل نسخةٍ مفتاحُها، والأحدثُ يفوز.** شاشةٌ قد تُفتح مرّتين في المكدّس
//    («تحليل مستواي» ← اختبار مراجعة ← «تحليل مستواي» من جديد)، ومفتاحٌ عامٌّ
//    واحدٌ لاسمٍ واحد كان سيُسقط التطبيقَ بـ«Duplicate GlobalKey». فالسجلُّ
//    يحفظ آخرَ نسخةٍ رُكّبت — وهي التي في الشاشة الظاهرة.
class TourAnchors {
  TourAnchors._();

  static final Map<String, List<GlobalKey>> _live = {};

  static BuildContext? contextOf(String id) {
    final keys = _live[id];
    if (keys == null) return null;
    for (final k in keys.reversed) {
      final ctx = k.currentContext;
      if (ctx != null) return ctx;
    }
    return null;
  }

  /// مستطيلُ العنصر بإحداثيات الشاشة — أو `null` إن لم يكن مبنيّاً الآن.
  static Rect? rectOf(String id) {
    final box = contextOf(id)?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  static void _add(String id, GlobalKey k) => (_live[id] ??= []).add(k);

  static void _remove(String id, GlobalKey k) {
    _live[id]?.remove(k);
    if (_live[id]?.isEmpty ?? false) _live.remove(id);
  }
}

/// يعلّم عنصراً بمرساةٍ تستطيع الجولةُ أن تجده بها. لا يغيّر شيئاً في رسمه.
class TourAnchor extends StatefulWidget {
  const TourAnchor({super.key, required this.id, required this.child});

  final String id;
  final Widget child;

  @override
  State<TourAnchor> createState() => _TourAnchorState();
}

class _TourAnchorState extends State<TourAnchor> {
  late final GlobalKey _key = GlobalKey(debugLabel: 'tour:${widget.id}');

  @override
  void initState() {
    super.initState();
    TourAnchors._add(widget.id, _key);
  }

  @override
  void didUpdateWidget(TourAnchor old) {
    super.didUpdateWidget(old);
    if (old.id != widget.id) {
      TourAnchors._remove(old.id, _key);
      TourAnchors._add(widget.id, _key);
    }
  }

  @override
  void dispose() {
    TourAnchors._remove(widget.id, _key);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      KeyedSubtree(key: _key, child: widget.child);
}
