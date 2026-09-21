import 'package:flutter/material.dart';

import '../../../../app/bootstrap.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_brand.dart';
import 'auth_screen.dart';

// ==========================================
// 🚀 شاشة الترحيب (Onboarding)
// ==========================================
// 🎨 **تصميم Figma** — «الشاشة الافتتاحية 4 · 5 · 6» (24:18572 · 33:29665 · 747:1622):
//
//    صفحةٌ بيضاء · هامش جانبي 24 · عمودٌ متمركز رأسياً:
//    روبوت 137×152 ← فجوة 18 ← عنوان 24/w700 `#21302A` ←
//    وصف 14/w700 `#626262` (سطر 26) ← زرّ 342×47 r16 `#0092FF`.
//    وزرّ رجوع 40×40 r16 مثبّت أعلى **بداية** السطر (يمين في RTL)،
//    يغيب في الصفحة الأولى.
//
// ⛔ **ما حُذف:** `RobotWidget` المرسوم بالكود · فقاعة الكلام ·
//    `TypewriterText` · `SoftWaveBackground` · `FadeInSlide` — لا شيء منها
//    في التصميم الجديد.
//
// ✅ **ما أُبقي رغم غيابه عن التصميم** (عقد التسليم: لا تختفي ميزة):
//    · زرّ «تخطي» — صُمّم بلغة المصمّم في الطرف المقابل لزرّ الرجوع.
//    · مؤشّر الصفحات — نقاطٌ بلون الهوية فوق الزرّ مباشرة.
//    · التمرير الأفقي بالإصبع (`PageView`).
//
// 📝 **النصوص من التطبيق لا من التصميم** (قرار المالك): المصمّم كتب ثلاث
//    صفحات بنصوصٍ من عنده، والتطبيق فيه أربع تعرّف الطالبَ بأقسامه الفعلية
//    — ومنها **قسم المنح** الذي لا تذكره صفحات المصمّم إطلاقاً.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _page = 0;

  static const _pages = [
    _Ob("مرحباً بك في مسار 👋",
        "رفيقك من أول ثانوي حتى المنحة الجامعية.\nكل ما تحتاجه في مكان واحد."),
    _Ob("اشرح، لخّص، اسأل، وتدرّب",
        "شروحات وتلخيصات وأسئلة وزارية ذكية لكل المواد وكل الصفوف."),
    _Ob("منح واختبارات تكشف تخصصك",
        "منح دراسية حول العالم، واختبار ميول يرشدك لتخصصك الأنسب."),
    _Ob("أنا معك في كل شاشة!", "اسألني متى شئت، وابدأ رحلتك الآن 🚀"),
  ];

  bool get _isLast => _page == _pages.length - 1;

  Future<void> _next() async {
    if (!_isLast) {
      _pc.nextPage(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic);
      return;
    }
    await AppBootstrap.markOnboardingDone();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => const AuthScreen(),
        transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
      ),
    );
  }

  void _back() => _pc.previousPage(
      duration: const Duration(milliseconds: 380), curve: Curves.easeOut);

  void _skip() => _pc.animateToPage(_pages.length - 1,
      duration: const Duration(milliseconds: 460), curve: Curves.easeOutCubic);

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ThemeScope(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.bgLight,
        body: SafeArea(
          child: Padding(
            // 📐 هامش التصميم: 24 جانبياً · 32 رأسياً.
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              children: [
                _topBar(),
                // 📐 **الكتلة كلّها متمركزة رأسياً** — روبوت ← عنوان ← وصف ←
                //    نقاط ← زرّ، والفراغ يتوزّع فوقها وتحتها.
                //
                // ⚠️ **ليس زرّاً مثبّتاً في أسفل الشاشة**: في التصميم يجلس
                //    الزرّ ملاصقاً للنصّ والفراغُ كلّه تحته. وتثبيتُه أسفلَ
                //    الشاشة يباعد بينه وبين ما يشرحه بمئتي بكسل.
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // ارتفاعٌ ثابت للصفحة: روبوت 152 + فجوتان 18 + عنوان
                      // وسطران وصف. وثباتُه يمنع اهتزاز الزرّ بين صفحةٍ
                      // عنوانُها سطر وأخرى عنوانها سطران.
                      SizedBox(
                        height: 340,
                        child: PageView.builder(
                          controller: _pc,
                          onPageChanged: (i) => setState(() => _page = i),
                          itemCount: _pages.length,
                          itemBuilder: (_, i) => _Page(ob: _pages[i]),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _dots(),
                      const SizedBox(height: 18),
                      _cta(),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// شريطٌ علويّ بارتفاع ثابت: الرجوع في البداية، والتخطّي في النهاية.
  ///
  /// ⚠️ **الارتفاع ثابت 40 دائماً** حتى في الصفحة الأولى التي لا زرّ رجوع
  ///    فيها — وإلا قفز المحتوى كلّه 40 بكسل عند أول تمرير.
  Widget _topBar() => SizedBox(
        height: 40,
        child: Row(
          children: [
            if (_page > 0)
              _CircleButton(onTap: _back, icon: Icons.arrow_back_ios_new_rounded),
            const Spacer(),
            // ⏭️ «تخطي» — غير موجود في التصميم، وأُبقي لأنه ميزةٌ قائمة.
            //    يختفي في الصفحة الأخيرة: لا شيء بعدها يُتخطّى.
            if (!_isLast)
              TextButton(
                onPressed: _skip,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text("تخطي",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              ),
          ],
        ),
      );

  Widget _dots() => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          _pages.length,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: _page == i ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: _page == i ? AppColors.primaryFill : AppColors.primaryMuted,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );

  /// الزرّ الأساسي — مقاس التصميم بالضبط: ارتفاع 47 · نصف قطر 16 · لون مصمت.
  Widget _cta() => SizedBox(
        width: double.infinity,
        height: 47,
        child: ElevatedButton(
          onPressed: _next,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryFill,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
          ),
          child: Text(_isLast ? "أنشئ حسابك 🚀" : "متابعة",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      );
}

// ══════════════════════════════════════════════════
// صفحةٌ واحدة — روبوت + عنوان + وصف، متمركزةٌ رأسياً
// ══════════════════════════════════════════════════
class _Page extends StatelessWidget {
  const _Page({required this.ob});
  final _Ob ob;

  @override
  Widget build(BuildContext context) => Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const MasarRobot(size: 137),
          const SizedBox(height: 18),
          Text(ob.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.4,
                color: AppColors.headingInk,
              )),
          const SizedBox(height: 18),
          Text(ob.desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 26 / 14, // ارتفاع السطر من التصميم
                color: AppColors.textSecondary,
              )),
        ],
      );
}

// ══════════════════════════════════════════════════
// زرّ دائريّ مربّع الأطراف — مواصفات «Button - Back»
// ══════════════════════════════════════════════════
class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.onTap, required this.icon});
  final VoidCallback onTap;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceWhite.withValues(alpha: 0.49),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            // ↩️ **لا يُعكس مع الاتجاه.** في التصميم يشير السهم **يميناً**
            //    (نحو ما جاء منه القارئ العربي)، وفلاتر تعكس أيقونات
            //    `arrow_*_ios` تلقائياً في RTL فتصير تشير يساراً.
            child: Icon(icon,
                size: 15,
                color: AppColors.headingInk,
                textDirection: TextDirection.rtl),
          ),
        ),
      );
}

class _Ob {
  final String title;
  final String desc;
  const _Ob(this.title, this.desc);
}
