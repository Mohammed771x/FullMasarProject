import 'package:flutter/material.dart';

// ==========================================
// ✨ ظهور النصّ المبثوث بالتلاشي
// ==========================================
// 🎯 **الهدف:** إحساس ChatGPT — النصّ **ينبثق** من حافةٍ ناعمة بدل أن يقفز
//    سطراً سطراً. الفارق ليس تجميلياً فقط: الحافة القاسية تجعل كل سطرٍ
//    جديد يخطف العين، فيتشتّت القارئ؛ والحافة المتلاشية تُبقي انتباهه على
//    ما يقرأ ويترك الجديد يصل بهدوء.
//
// 🧩 **لماذا قناع تدرّج لا تلاشي لكل كلمة؟** لأن المحتوى **Markdown**:
//    عناوين وقوائم ورياضيات وجداول. وتقطيعُه لتلوين آخر كلمة يعني تفكيك
//    الصياغة في منتصفها — `**غامق` بلا إغلاقه يُفسد بقية الفقرة. القناع
//    يعمل **فوق** المحتوى المرسوم مهما كان تعقيده، فلا يلمس بنيته إطلاقاً.
//
// ⚡ و`ShaderMask` طبقةُ رسمٍ واحدة على GPU — لا إعادة تخطيط ولا إعادة
//    تحليل للنصّ مع كل جزءٍ يصل.

class StreamingText extends StatelessWidget {
  const StreamingText({
    super.key,
    required this.child,
    required this.streaming,
    this.fadeHeight = 34,
  });

  /// المحتوى المرسوم (Markdown عادةً).
  final Widget child;

  /// هل ما زال البثّ جارياً؟ عند `false` يختفي القناع تماماً.
  ///
  /// ⚠️ **وإخفاؤه لازم لا تحسين:** قناعٌ باقٍ بعد النهاية يترك آخر سطرٍ
  ///    باهتاً إلى الأبد — فتبدو الإجابة ناقصة وهي مكتملة.
  final bool streaming;

  /// ارتفاع منطقة التلاشي أسفل الفقاعة.
  ///
  /// ⚠️ ٣٤ ≈ سطرٌ ونصف: أقلُّ منها لا يُرى، وأكثرُ منها يُخفي سطراً كاملاً
  ///    من نصٍّ **وصل فعلاً** — فيظنّ الطالب أن الشرح توقّف.
  final double fadeHeight;

  @override
  Widget build(BuildContext context) {
    if (!streaming) return child;

    return ShaderMask(
      // `dstIn` يُبقي البكسل بمقدار ألفا التدرّج — أي يجعل الأسفل شفافاً
      // تدريجياً بدل أن يُلوّنه.
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        // نصٌّ أقصر من منطقة التلاشي: نُخفّف التدرّج بدل أن نُخفيه كله،
        // وإلا اختفت أول كلمةٍ تصل تماماً.
        final double span =
            rect.height <= 0 ? 0 : (fadeHeight / rect.height).clamp(0.0, 0.55);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: const [Colors.white, Colors.white, Colors.transparent],
          stops: [0.0, (1.0 - span).clamp(0.0, 1.0), 1.0],
        ).createShader(rect);
      },
      child: child,
    );
  }
}

// ==========================================
// ▍مؤشّر الكتابة — «الردّ ما زال قادماً»
// ==========================================
// ⭐ يُجيب عن سؤالٍ واحدٍ يهمّ الطالب: **هل انتهى أم ما زال يكتب؟** بدونه
//    يبدو التوقّف المؤقّت بين جزأين نهايةً للإجابة، فيبدأ الطالب يكتب
//    سؤالاً جديداً على ردٍّ لم يكتمل.
class TypingCaret extends StatefulWidget {
  const TypingCaret({super.key, this.color});

  final Color? color;

  @override
  State<TypingCaret> createState() => _TypingCaretState();
}

class _TypingCaretState extends State<TypingCaret>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color ?? Theme.of(context).colorScheme.primary;
    return FadeTransition(
      // ⚠️ لا يهبط إلى صفر: وميضٌ كاملٌ يشدّ العين أكثر من النصّ نفسه.
      opacity: Tween<double>(begin: 0.25, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 8,
        height: 15,
        margin: const EdgeInsetsDirectional.only(start: 3, top: 2),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
