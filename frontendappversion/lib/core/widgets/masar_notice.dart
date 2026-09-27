import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'masar_dialog.dart';
import 'phosphor.dart';

// ==========================================
// 🔔 رسالةُ وسط الشاشة — بديلُ الشريط السفليّ في التطبيق كلِّه
// ==========================================
// 🎯 **أمرُ المالك (٢٠٢٦-٠٩-٢٤):** «الـexception اللي يطلع من تحت أهبل…
//    في المحفوظات يطلع أسود… خلّه يطلع في نص الشاشة رسالة حلوة وجميلة:
//    إذا نحفظ شي يطلع صح، انحفظ… ولما أضغط الصور يطلع وصلت الحد الأقصى،
//    يقول فهمت، تروح ويكمل استخدامه — أي مكان عدّلها».
//
// 📐 **نوعان لا غير:**
//   • [MasarNotice.toast] — **تأكيدُ فعلٍ تمّ** («حُفظت» · «حُذفت»): بطاقةٌ
//     في الوسط بأيقونةٍ ملوّنة، تختفي وحدها بعد لحظة أو بلمسة، **ولا تحجز**
//     الشاشة — فالطالبُ يكمل ما كان فيه.
//   • [MasarNotice.info] — **شيءٌ يلزمه أن يعرفه** («وصلت الحدّ الأقصى» ·
//     «اختر الصفحات أولاً»): نافذةٌ بقالب [MasarDialog] نفسِه وزرُّ «فهمت».
//
// 🎨 وكلاهما من لغة التصميم نفسِها: لوحٌ أبيض r26 · مربّعُ أيقونةٍ ثنائيّةِ
//    اللون · عنوان w900 — لا أسودُ ولا برتقاليُّ Material.
enum NoticeKind { success, info, warning, error }

class MasarNotice {
  MasarNotice._();

  static OverlayEntry? _current;
  static Timer? _timer;

  /// 🎨 (تعبئةُ مربّع الأيقونة، حبرُها، الأيقونة) لكلّ نوع.
  static (Color, Color, PDIcon) _style(NoticeKind k) => switch (k) {
    NoticeKind.success => (
      AppColors.quizRightFill,
      AppColors.copiedInk,
      PD.checkCircle,
    ),
    NoticeKind.info => (
      AppColors.primaryTintSurface,
      AppColors.primary,
      PD.info,
    ),
    NoticeKind.warning => (
      AppColors.savedSurface,
      AppColors.savedInk,
      PD.warning,
    ),
    NoticeKind.error => (AppColors.errorTint, AppColors.error600, PD.warning),
  };

  /// ✅ تأكيدٌ قصيرٌ في وسط الشاشة — يختفي وحده.
  ///
  /// ⚠️ **واحدٌ في كل لحظة**: الجديدُ يُزيح القديمَ فوراً، فلا تتكدّس
  ///    البطاقاتُ حين يحفظ الطالبُ ثلاثَ رسائلَ متتالية.
  static void toast(
    BuildContext context,
    String message, {
    NoticeKind kind = NoticeKind.success,
    PDIcon? icon,
    Duration? duration,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    dismiss();
    final (tint, ink, fallback) = _style(kind);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _NoticeCard(
        message: message,
        tint: tint,
        ink: ink,
        icon: icon ?? fallback,
        onTap: () {
          if (identical(_current, entry)) dismiss();
        },
      ),
    );
    _current = entry;
    overlay.insert(entry);
    // ⏱️ **مدّةٌ على قدر الجملة**: «حُفظت» تُقرأ في لحظة، و«تتابع «المنحة
    //    التركية» — سننبّهك قبل إغلاقها» لا — ثانيةٌ ونصفٌ ثابتةٌ كانت تُطفئها
    //    قبل أن تُقرأ (رُئي في المحاكي). ١٫٦ث + ٤٠م.ث لكل حرف، وسقفُها ٣٫٥ث.
    final ms = (1600 + 40 * message.length).clamp(1600, 3500);
    _timer = Timer(duration ?? Duration(milliseconds: ms), () {
      if (identical(_current, entry)) dismiss();
    });
  }

  /// يُزيل البطاقةَ الحاليّة إن وُجدت.
  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }

  /// ℹ️ رسالةٌ تحتاج إقراراً — نافذةٌ في الوسط وزرُّ «فهمت».
  static Future<void> info(
    BuildContext context,
    String message, {
    String? title,
    NoticeKind kind = NoticeKind.info,
    PDIcon? icon,
    String action = "فهمت",
    Future<void> Function()? onAction,
    String? cancelLabel,
  }) {
    dismiss();
    final (tint, ink, fallback) = _style(kind);
    return showDialog<void>(
      context: context,
      builder: (_) => MasarDialog(
        icon: icon ?? fallback,
        iconTint: tint,
        iconInk: ink,
        title: title ?? _defaultTitle(kind),
        primaryLabel: action,
        onPrimary: onAction,
        // 🔘 فعلٌ واحدٌ ⇒ زرٌّ بعرض اللوح؛ ومع «لاحقاً» صفُّ زرَّين.
        cancelLabel: cancelLabel,
        fullWidthAction: cancelLabel == null,
        child: Text(
          message,
          style: TextStyle(
            fontSize: 14.5,
            height: 1.7,
            fontWeight: FontWeight.w700,
            color: AppColors.chipInk,
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // 🧭 [say] — لمواضعَ كانت تمرّر نصّاً واحداً إلى `_snack`
  // ══════════════════════════════════════════════════
  // الرسائلُ القديمة تحمل نوعَها في رمزها الأوّل («✅ تم…» · «⚠️ تعذّر…»)،
  // فيُقرأ منه: **فعلٌ تمّ** ⇒ بطاقةٌ تختفي · **خطأ** ⇒ نافذةٌ حمراء ·
  // **ما عداهما** ⇒ نافذةٌ بـ«فهمت». والرمزُ يُنزع — فالأيقونةُ الملوّنة
  // تقوم مقامه، ورمزٌ فوق أيقونةٍ تكرار.
  static const _done = {"✅", "📋", "⭐", "🗑️", "🧹", "📨", "📧", "💡"};
  static const _progress = {"⏳", "🔊", "📤", "💬"};
  static const _bad = {"⚠️", "❌", "✂️", "✏️"};
  static final _lead = RegExp(
    r"^\s*([\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}]\u{FE0F}?(\u{200D}[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]\u{FE0F}?)*)\s*",
    unicode: true,
  );
  static final _tail = RegExp(
    r"\s*[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]\u{FE0F}?\s*$",
    unicode: true,
  );

  /// يفصل الرمزَ الأوّل عن النصّ، وينزع رمزاً في الآخِر («… 📚»).
  static (String, String) split(String message) {
    final m = _lead.firstMatch(message);
    final lead = m?.group(1) ?? "";
    final text = message.substring(m?.end ?? 0).replaceFirst(_tail, "").trim();
    return (lead, text.isEmpty ? message.trim() : text);
  }

  static void say(BuildContext context, String message) {
    final (lead, text) = split(message);
    if (_done.contains(lead)) {
      toast(
        context,
        text,
        icon: switch (lead) {
          "🗑️" => PD.trashSimple,
          "⭐" => PD.star,
          _ => null,
        },
        kind: lead == "🗑️" ? NoticeKind.error : NoticeKind.success,
      );
    } else if (_progress.contains(lead)) {
      toast(context, text, kind: NoticeKind.info);
    } else if (_bad.contains(lead) || text.contains("تعذّر")) {
      info(context, text, kind: NoticeKind.error);
    } else {
      info(context, text);
    }
  }

  /// 📷 **حدُّ الصور** — واحدٌ للتعليم والمعلّم والمنح.
  ///
  /// 🎯 أمرُ المالك (٢٠٢٦-٠٩-٢٤): «بعد صورتين الزر حق الصور ينروح — لا،
  ///    خلّه يكون موجود، بس لما يضغطه يقول له وصلت الحدّ الأقصى».
  static Future<void> imageLimit(BuildContext context, int max) => info(
    context,
    "تستطيع إرفاق ${max == 2 ? "صورتين" : "$max صور"} فقط في الرسالة "
    "الواحدة. احذف صورةً إن أردت استبدالها.",
    title: "وصلت الحدّ الأقصى",
    icon: PD.images,
  );

  static String _defaultTitle(NoticeKind k) => switch (k) {
    NoticeKind.success => "تمّ",
    NoticeKind.info => "تنبيه",
    NoticeKind.warning => "انتبه",
    NoticeKind.error => "تعذّر ذلك",
  };
}

/// البطاقةُ نفسُها — تظهر بتكبيرٍ خفيفٍ وتلاشٍ، في وسط الشاشة.
class _NoticeCard extends StatefulWidget {
  const _NoticeCard({
    required this.message,
    required this.tint,
    required this.ink,
    required this.icon,
    required this.onTap,
  });

  final String message;
  final Color tint;
  final Color ink;
  final PDIcon icon;
  final VoidCallback onTap;

  @override
  State<_NoticeCard> createState() => _NoticeCardState();
}

class _NoticeCardState extends State<_NoticeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _a, curve: Curves.easeOutBack);
    // 🖐️ **لا تحجز الشاشة**: ما خارج البطاقة يمرّ لمسُه إلى ما تحتها.
    return Center(
      child: FadeTransition(
        opacity: _a,
        child: ScaleTransition(
          scale: Tween(begin: 0.86, end: 1.0).animate(curve),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Material(
              color: Colors.transparent,
              child: GestureDetector(
                onTap: widget.onTap,
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: AppColors.rowBorder),
                    boxShadow: AppColors.softShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: widget.tint,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: PDuo(widget.icon, size: 28, color: widget.ink),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          fontWeight: FontWeight.w900,
                          color: AppColors.panelTitle,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
