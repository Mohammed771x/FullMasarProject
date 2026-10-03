import 'package:flutter/material.dart';

import '../core/notifications/push_router.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/theme_controller.dart';
import '../core/widgets/text_scale_clamp.dart';

// ==========================================
// 🌟 جذر التطبيق (MaterialApp + الثيم + RTL + الوضع الداكن)
// ==========================================
class MasarApp extends StatelessWidget {
  final Widget home;
  const MasarApp({super.key, required this.home});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isDarkModeNotifier,
      builder: (context, isDark, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          // 🧭 لازمٌ لنقر الإشعار: الوجهة تُفتح بلا `context` شاشة، لأن
          //    النقرة قد تصل والتطبيق مغلقٌ تماماً أو على شاشةٍ عميقة.
          navigatorKey: masarNavigatorKey,
          title: 'منصة مسار',
          builder: (context, child) => _SystemBrightnessBridge(
            child: _RebuildOnThemeChange(
              child: Directionality(
                textDirection: TextDirection.rtl,
                // 🔠 خطُّ النظام يُكبَّر حتى ×١٫٣ لا أكثر ([TextScaleClamp]).
                child: TextScaleClamp(child: child!),
              ),
            ),
          ),
          theme: AppTheme.build(isDark: isDark),
          home: home,
        );
      },
    );
  }
}

/// يوصّل إضاءة النظام إلى `ThemeController` ليعمل خيار «حسب النظام».
///
/// ⚠️ داخل `builder` لا فوق `MaterialApp`: هنا وحده يوجد `MediaQuery` يعيد
///    البناء عند تبديل الجهاز إلى الليل، فيتبعه التطبيق فوراً بلا إعادة فتح.
class _SystemBrightnessBridge extends StatelessWidget {
  const _SystemBrightnessBridge({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = MediaQuery.platformBrightnessOf(context);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => ThemeController.I.setSystemBrightness(brightness),
    );
    return child;
  }
}

/// 🌗 **تبديلُ الوضع يُعيد بناءَ الشجرة كلِّها — مرّةً واحدة، بلا فقد حالة.**
///
/// 🔴 **ما رُئي في المحاكي (٢٠٢٦-٠٩-٢٧):** اختيارُ «داكن» من الإعدادات
///    أظلم جسمَ الشاشة وأبقى رأسَها أبيض — وأيقوناتُ شريط الحالة صارت
///    بيضاء فوق أبيض فاختفت الساعةُ والبطارية.
///
/// ⚙️ **السبب:** [AppColors] تقرأ متغيّراً عامّاً لا `InheritedWidget`،
///    والرأسُ `const GlassBar(...)`. وفلاتر لا يعيد بناءَ عنصرٍ **ثابتٍ
///    بعينه** حين يُبنى أبوه — فيبقى بألوانه القديمة. و[ThemeScope] لا
///    ينفع هنا: يعيد بناءَ أبيه، والابنُ الثابتُ يُتخطّى. والعلّةُ عامّةٌ
///    في كل ودجت `const` يقرأ [AppColors] — لا في الإعدادات وحدها.
///
/// ✅ فحين يتبدّل الوضع يُعلَّم كلُّ عنصرٍ «يحتاج بناءً» — الآليةُ نفسُها
///    التي يستعملها Hot Reload. **الحالةُ باقية** (المكدّسُ والمحادثاتُ
///    والحقول) لأن العناصر لا تُهدم، والكلفةُ بناءٌ واحدٌ عند كل تبديل.
class _RebuildOnThemeChange extends StatefulWidget {
  const _RebuildOnThemeChange({required this.child});
  final Widget child;

  @override
  State<_RebuildOnThemeChange> createState() => _RebuildOnThemeChangeState();
}

class _RebuildOnThemeChangeState extends State<_RebuildOnThemeChange> {
  @override
  void initState() {
    super.initState();
    isDarkModeNotifier.addListener(_rebuildAll);
  }

  @override
  void dispose() {
    isDarkModeNotifier.removeListener(_rebuildAll);
    super.dispose();
  }

  void _rebuildAll() {
    if (!mounted) return;
    void mark(Element e) {
      e.markNeedsBuild();
      e.visitChildren(mark);
    }

    (context as Element).visitChildren(mark);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
