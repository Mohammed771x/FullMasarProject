import 'package:flutter/material.dart';

import '../../../../app/bootstrap.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_character.dart';
import '../widgets/everywhere_scene.dart';
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
//
// 🤖 **الشخصيات (٢٠٢٦-٠٩-٢٦):** الروبوتُ المعمَّم — هويةُ مسار الواحدة —
//    بوضعيةٍ لكل صفحة: يرفع إصبعه ويقول «هلا!» · «تمام» ولوحُ مهامّ ·
//    قبّعةُ تخرّج — والأخيرة **مشهدٌ حيّ** ([EverywhereScene]): جوّالٌ
//    تتقلّب شاشاتُه بين أقسام التطبيق والروبوتُ يطلّ من خلفه مع كل شاشة.
//    ✏️ المالك: «خلّوه هادي، لا تخليها مربوشة» — فاستُبدل برسم «العقل
//    الاصطناعي» (دماغٌ مضيء وشرائح طائرة) وضعيةٌ من الملف بعنصرٍ واحد؛
//    و«أنا معك» لا كومةُ أجهزة ولا جهازٌ بصورةٍ عشوائية بل ما يحاكي المعنى.
//    تحوم وترمش وتقفز عند اللمس وتدخل بارتداد ([MasarCharacterView])،
//    وتنزلق بسرعةٍ غير سرعة النصّ عند السحب (عمقٌ بين طبقتين).
//    ولأنها أكبر بكثير من الوجه، صار **ارتفاع الصفحة مرناً** والنقاطُ
//    والزرّ في ذيل الشاشة — كما في لوحة المصمّم التي رُسمت فيها.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pc = PageController();
  int _page = 0;

  static const _pages = [
    _Ob(
      MasarCharacter.hello,
      "مرحباً بك في مسار 👋",
      "رفيقك من أول ثانوي حتى المنحة الجامعية.\nكل ما تحتاجه في مكان واحد.",
      say: "هلا!",
    ),
    _Ob(
      MasarCharacter.ask,
      "اشرح، لخّص، اسأل، وتدرّب",
      "شروحات وتلخيصات وأسئلة وزارية ذكية لكل المواد وكل الصفوف.",
    ),
    _Ob(
      MasarCharacter.guide,
      // ✏️ المالك ٢٠٢٦-٠٩-٢٤: «اختبار الميول/التخصص» ليس قسماً قائماً —
      //    الاختبارات هنا «اختبر نفسك» على الدروس، وهي تحدّد المستوى.
      "منح واختبارات تحدّد مستواك",
      "منح دراسية حول العالم، واختبارات على دروسك تكشف مستواك وتقوّي نقاط ضعفك.",
    ),
    _Ob(
      null,
      "أنا معك في كل شاشة!",
      "اسألني متى شئت، وابدأ رحلتك الآن 🚀",
      scene: _everywhere,
    ),
  ];

  static Widget _everywhere(bool active) => EverywhereScene(active: active);

  bool get _isLast => _page == _pages.length - 1;

  Future<void> _next() async {
    if (!_isLast) {
      _pc.nextPage(
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await AppBootstrap.markOnboardingDone();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 600),
        pageBuilder: (_, _, _) => const AuthScreen(openSignup: true),
        transitionsBuilder: (_, a, _, c) =>
            FadeTransition(opacity: a, child: c),
      ),
    );
  }

  void _back() => _pc.previousPage(
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOut,
  );

  void _skip() => _pc.animateToPage(
    _pages.length - 1,
    duration: const Duration(milliseconds: 460),
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ↩️ **رجوعُ أندرويد يرجع صفحةً لا يُغلق التطبيق** (فحص أندرويد
    //    ٢٠٢٦-١٠-٠٣): من الصفحة الثانية كان يُخرج الطالبَ من «مسار» كلّه.
    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: ThemeScope(
      builder: (context) => Scaffold(
        backgroundColor: AppColors.bgLight,
        body: SafeArea(
          child: Padding(
            // 📐 هامش التصميم: 24 جانبياً · 32 رأسياً.
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: PageView.builder(
                    controller: _pc,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _pages.length,
                    itemBuilder: (_, i) => AnimatedBuilder(
                      animation: _pc,
                      builder: (context, _) {
                        // موضعُ الصفحة من المنتصف: 0 ظاهرة، ±1 خارج الشاشة.
                        final pos =
                            _pc.hasClients && _pc.position.hasContentDimensions
                            ? (_pc.page ?? _page.toDouble()) - i
                            : (_page - i).toDouble();
                        return _Page(
                          ob: _pages[i],
                          active: i == _page,
                          offset: pos.clamp(-1.0, 1.0),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _dots(),
                const SizedBox(height: 20),
                _cta(),
              ],
            ),
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
            child: const Text(
              "تخطي",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        _isLast ? "أنشئ حسابك 🚀" : "متابعة",
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════
// صفحةٌ واحدة — شخصيةٌ حيّة + عنوان + وصف
// ══════════════════════════════════════════════════
class _Page extends StatelessWidget {
  const _Page({required this.ob, required this.active, required this.offset});
  final _Ob ob;
  final bool active;

  /// −1..1 — بُعدُ الصفحة عن المنتصف أثناء السحب.
  final double offset;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final away = offset.abs();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 🎞️ **عمقٌ بين طبقتين:** الشخصية تتأخّر عن الصفحة (تتحرّك 70٪ من
        //    مسافتها) وتصغر قليلاً، والنصّ يسبقها — فيبدو الروبوت أبعدَ من
        //    الكلام ويُقرأ السحب انتقالاً لا انزلاقَ ورقة.
        //
        // 📐 عرضُها ٨٦٪ من الشاشة وارتفاعُها لا يتجاوز 380 — فتتنفّس
        //    من الحوافّ، وتبقى الكتلة كلّها متمركزةً رأسياً على الشاشات
        //    الطويلة بدل أن يُفتح فراغٌ بين الروبوت والعنوان.
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: 380, maxWidth: width * 0.86),
            child: Transform.translate(
              offset: Offset(offset * width * 0.30, 0),
              child: Transform.scale(
                scale: 1 - 0.12 * away,
                child: Opacity(
                  opacity: (1 - 0.7 * away).clamp(0.0, 1.0),
                  child:
                      ob.scene?.call(active) ??
                      MasarCharacterView(
                        character: ob.character!,
                        active: active,
                        say: ob.say,
                      ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Transform.translate(
          offset: Offset(-offset * width * 0.12, 0),
          child: Opacity(
            opacity: (1 - away).clamp(0.0, 1.0),
            child: Column(
              children: [
                Text(
                  ob.title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                    color: AppColors.headingInk,
                  ),
                ),
                const SizedBox(height: 12),
                // ارتفاعٌ ثابتٌ لسطرين — كي لا يقفز العنوان بين صفحةٍ وصفُها
                // سطرٌ وأخرى سطران.
                SizedBox(
                  height: 52,
                  child: Text(
                    ob.desc,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      height: 26 / 14, // ارتفاع السطر من التصميم
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
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
        child: Icon(
          icon,
          size: 15,
          color: AppColors.headingInk,
          textDirection: TextDirection.rtl,
        ),
      ),
    ),
  );
}

class _Ob {
  /// الشخصية — أو `null` حين تحلّ محلّها [scene].
  final MasarCharacter? character;
  final String title;
  final String desc;

  /// فقاعةُ كلام الشخصية — إن وُجدت.
  final String? say;

  /// مشهدٌ حيّ بدل الشخصية (يُعطى «الصفحة ظاهرة؟»).
  final Widget Function(bool active)? scene;
  const _Ob(this.character, this.title, this.desc, {this.say, this.scene});
}
