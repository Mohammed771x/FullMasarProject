import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

// ==========================================
// 🧰 مفردات شاشات التوثيق — مقاسات Figma حرفياً
// ==========================================
// 🎨 **المصدر:** قسم «واجهات الدخول» (9 شاشات). كل رقمٍ هنا مقروءٌ من الملف
//    لا مُقدَّرٌ من صورة.
//
// ⭐ **لماذا ملفٌ واحد؟** المفردة نفسها تتكرر في تسع شاشات: الحقل بعنوانه
//    فوقه، والزرّ الممتلئ، والزرّ المحدَّد، وزرّ الرجوع. ونسخُها في كل شاشة
//    يعني تسع نسخٍ تتفرّق قيَمُها عند أول تعديل — وهو ما يُفقد «التطابق
//    الحرفي» المطلوب.

/// 📐 ثوابت التخطيط المشتركة.
class AuthMetrics {
  AuthMetrics._();

  /// عرض المحتوى 342 من لوح 390 ⇒ هامشٌ جانبي 24.
  static const double gutter = 24;

  /// ارتفاع الزرّ الأساسي.
  static const double buttonHeight = 47;

  /// ارتفاع الزرّ الثانوي (جوجل · زائر).
  static const double secondaryHeight = 39;

  static const double buttonRadius = 16;
  static const double fieldRadius = 12;
}

// ══════════════════════════════════════════════════
// 🔙 زرّ الرجوع — «Button - Back» 40×40 r16
// ══════════════════════════════════════════════════
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({super.key, this.onTap});

  /// `null` ⇒ يرجع بالـNavigator.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap ?? () => Navigator.maybePop(context),
          borderRadius: BorderRadius.circular(AuthMetrics.buttonRadius),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(AuthMetrics.buttonRadius),
              border: Border.all(color: AppColors.border),
            ),
            // ↩️ **لا يُعكس مع الاتجاه** — في التصميم يشير السهم يميناً،
            //    وفلاتر تعكس أيقونات `arrow_*_ios` تلقائياً في RTL.
            child: Icon(Icons.arrow_back_ios_new_rounded,
                size: 15,
                color: AppColors.headingInk,
                textDirection: TextDirection.rtl),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🏷️ عنوان الشاشة + وصفها
// ══════════════════════════════════════════════════
class AuthHeading extends StatelessWidget {
  /// ⛔ **ليس `const` عمداً.** ألوانه تُقرأ من [AppColors] وقت البناء،
  /// و`const AuthHeading(...)` تجعل فلاتر **تتخطّى إعادة بنائه** لأن
  /// الودجت الثابتة موحَّدة الهوية — فيبقى العنوان بحبر الوضع السابق.
  ///
  /// 🔴 **وقع فعلاً في المحاكي:** عنوان شاشة التأكيد ظلّ `#2C2C2C` على
  ///    خلفيةٍ سوداء بعد تبديل الوضع — أغمقَ من الوصف الذي تحته.
  ///    منعُ `const` في المُنشئ ضمانٌ وقت الترجمة لا تذكّرٌ من المطوّر،
  ///    وهي القاعدة نفسها المطبَّقة في [MasarBrand].
  // ignore: prefer_const_constructors_in_immutables  ← مقصود، انظر أعلاه
  AuthHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.titleSize = 24,
    this.align = TextAlign.center,
  });

  final String title;
  final String? subtitle;
  final double titleSize;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    final cross = switch (align) {
      TextAlign.center => CrossAxisAlignment.center,
      TextAlign.left => CrossAxisAlignment.start,
      _ => CrossAxisAlignment.start,
    };
    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(title,
            textAlign: align,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w700,
              height: 1.35,
              color: AppColors.headingTitle,
            )),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!,
              textAlign: align,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.6,
                color: AppColors.textSecondary,
              )),
        ],
      ],
    );
  }
}

// ══════════════════════════════════════════════════
// ✍️ حقل إدخال — عنوانٌ فوقه ثم صندوقٌ غائر
// ══════════════════════════════════════════════════
// 📐 العنوان 10/w700 · الصندوق 42 ارتفاعاً · r12 · تعبئة `#FAFBFB` ·
//    حدّ `#EBEDF0` · النصّ النائب 10/w400.
//
// ⚠️ **العنوان فوق الحقل لا داخله**: التصميم لا يستعمل `label` عائماً،
//    والعنوانُ الثابت يبقى مقروءاً أثناء الكتابة.
class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.ltr = false,
    this.helper,
    this.textInputAction,
    this.onSubmitted,
    this.enabled = true,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;

  /// البريد وكلمة المرور يُكتبان من اليسار داخل واجهةٍ عربية.
  final bool ltr;

  /// سطرُ إرشادٍ تحت الحقل (مثل شروط كلمة المرور).
  final String? helper;

  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool enabled;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.fieldLabel,
            )),
        const SizedBox(height: 5),
        TextField(
          controller: widget.controller,
          obscureText: _hidden,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          onSubmitted: widget.onSubmitted,
          textDirection: widget.ltr ? TextDirection.ltr : null,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            hintText: widget.hint,
            hintStyle: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.fieldHint),
            filled: true,
            fillColor: AppColors.fieldFill,
            // 👁️ زرّ الإظهار — في **بداية** السطر كما في التصميم (يمين RTL).
            prefixIcon: widget.obscure
                ? IconButton(
                    splashRadius: 18,
                    icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 19,
                        color: AppColors.n650),
                    onPressed: () => setState(() => _hidden = !_hidden),
                  )
                : null,
            prefixIconConstraints:
                const BoxConstraints(minWidth: 42, minHeight: 42),
            border: _border(AppColors.fieldBorder),
            enabledBorder: _border(AppColors.fieldBorder),
            disabledBorder: _border(AppColors.fieldBorder),
            focusedBorder: _border(AppColors.primary, width: 1.4),
          ),
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 5),
          Text(widget.helper!,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w400,
                  color: AppColors.primary900)),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color c, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AuthMetrics.fieldRadius),
        borderSide: BorderSide(color: c, width: width),
      );
}

// ══════════════════════════════════════════════════
// 🔘 الزرّ الأساسي — 47 · r16 · تعبئة مصمتة
// ══════════════════════════════════════════════════
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: AuthMetrics.buttonHeight,
        child: ElevatedButton(
          onPressed: busy ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryFill,
            foregroundColor: Colors.white,
            disabledBackgroundColor:
                AppColors.primaryFill.withValues(alpha: 0.55),
            disabledForegroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AuthMetrics.buttonRadius)),
          ),
          child: busy
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      valueColor: AlwaysStoppedAnimation(Colors.white)))
              : Text(label,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );
}

// ══════════════════════════════════════════════════
// ⬜ الزرّ الثانوي — 39 · r12 · `#E6F4FF` بحدّ `#006EBF`
// ══════════════════════════════════════════════════
class AuthOutlineButton extends StatelessWidget {
  const AuthOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;
  final Widget? leading;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AuthMetrics.fieldRadius),
          child: Container(
            width: double.infinity,
            height: AuthMetrics.secondaryHeight,
            decoration: BoxDecoration(
              color: AppColors.primaryTintSurface,
              borderRadius: BorderRadius.circular(AuthMetrics.fieldRadius),
              border: Border.all(color: AppColors.primary800),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 8)],
                Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary)),
              ],
            ),
          ),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🔗 رابطٌ نصّي بمساحة لمسٍ حقيقية
// ══════════════════════════════════════════════════
/// ⚠️ **لماذا عنصرٌ خاص؟** `GestureDetector` حول `Text` عارٍ يعطي مساحة
///    لمسٍ بحجم الحروف فقط — ولا يزيد على ٢٠pt ارتفاعاً. وقد **فشلت النقرة
///    فعلاً في المحاكي** على «إنشاء حساب» مرّتين قبل أن يُكتشف السبب،
///    والطالبُ على جهازٍ حقيقي بإصبعٍ لا مؤشّر سيفشل أكثر.
///
/// هنا: حشوةٌ رأسية تبلغ بالمساحة ٤٤pt (حدّ أبل الأدنى)، و`opaque` كي
/// تُلتقط النقرة في كامل المستطيل لا على الحروف وحدها.
class AuthLink extends StatelessWidget {
  const AuthLink({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.fontSize = 15,
  });

  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final double fontSize;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
          child: Text(label,
              style: TextStyle(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w700,
                  color: color ?? AppColors.primary)),
        ),
      );
}

// ══════════════════════════════════════════════════
// 🇬 شعار جوجل — مرسومٌ بالكود
// ══════════════════════════════════════════════════
// لا صورة شبكية ولا أصل خارجي: الشاشة تُفتح بلا إنترنت، والحجم صفر بايت.
class GoogleGlyph extends StatelessWidget {
  const GoogleGlyph({super.key, this.size = 16});
  final double size;

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _GooglePainter()));
}

class _GooglePainter extends CustomPainter {
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final stroke = w * 0.22;
    final rect = Rect.fromLTWH(stroke / 2, stroke / 2, w - stroke, w - stroke);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, -0.35, -1.25, false, p..color = _red);
    canvas.drawArc(rect, -1.60, -1.35, false, p..color = _yellow);
    canvas.drawArc(rect, -2.95, -1.30, false, p..color = _green);
    canvas.drawArc(rect, 0.62, -0.97, false, p..color = _blue);

    canvas.drawRect(
      Rect.fromLTWH(w * 0.50, w * 0.42, w * 0.42, stroke * 0.92),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ══════════════════════════════════════════════════
// 🧱 هيكل شاشة توثيق — رجوعٌ أعلى ومحتوىً يمرّر
// ══════════════════════════════════════════════════
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.children,
    this.showBack = true,
    this.onBack,
    this.footer,
    this.background,
  });

  final List<Widget> children;
  final bool showBack;
  final VoidCallback? onBack;

  /// يُلصق بأسفل الشاشة خارج التمرير (الزرّ الأساسي في شاشات الخطوات).
  final Widget? footer;

  /// خلفيةٌ مخالفة (شاشتا الاستعادة في التصميم بخلفيةٍ خضراء خافتة).
  final Color? background;

  @override
  Widget build(BuildContext context) => ThemeScope(
        builder: (context) => Scaffold(
          backgroundColor: background ?? AppColors.bgLight,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AuthMetrics.gutter, 16, AuthMetrics.gutter, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ارتفاعٌ ثابت حتى حين يغيب الزرّ — وإلا قفز المحتوى.
                  SizedBox(
                    height: 40,
                    child: showBack
                        ? Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: AuthBackButton(onTap: onBack))
                        : null,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      // 🎹 لوحة المفاتيح تُغلق بلمسة خارج الحقل — وإلا حجبت
                      //    الزرّ في شاشةٍ قصيرة ولم يجد الطالب مخرجاً.
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: children,
                      ),
                    ),
                  ),
                  if (footer != null) ...[
                    const SizedBox(height: 12),
                    footer!,
                  ],
                ],
              ),
            ),
          ),
        ),
      );
}
