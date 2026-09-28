import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_character.dart';
import '../../../../core/widgets/phosphor.dart';

// ==========================================
// 📱 «أنا معك في كل شاشة» — مشهدٌ حيّ لا صورة
// ==========================================
// ✏️ **طلب المالك (٢٠٢٦-٠٩-٢٦):** لا رسمُ المصمّم (كومةُ أجهزة) ولا روبوتٌ
//    يحمل جهازاً بصورةٍ لا علاقة لها — «صمّم شيئاً يحاكي الموضوع».
//
// 💡 **الفكرة:** جوّالٌ في المنتصف تتقلّب شاشتُه بين أقسام التطبيق الحقيقية
//    (الرئيسية · مسار · اختبر نفسك · المنح) والشريطُ السفليّ فيه يتبعها —
//    ومع كل شاشةٍ جديدة **يطلّ الروبوت المعمَّم من خلف الجوّال** من جهةٍ
//    أخرى: يختبئ، تتبدّل الشاشة، ثم يطلّ ويرمش. «معك في كل شاشة» حرفياً.
//
// 🧘 **هادئ:** انتقالٌ واحدٌ كل ٢٫٨ ثانية، ولا شيء يطير حوله.
//    ♿ «تقليل الحركة» ⇒ الشاشة الأولى والروبوت ظاهرٌ ساكن، بلا مؤقّت.
//    والمؤقّت لا يدور إلا والصفحة ظاهرة ([active]).
class EverywhereScene extends StatefulWidget {
  const EverywhereScene({super.key, this.active = true});

  /// الصفحة الظاهرة الآن — خارجها يتوقّف التقليب.
  final bool active;

  @override
  State<EverywhereScene> createState() => _EverywhereSceneState();
}

/// من أين يطلّ الروبوت: الحافّةُ التي يخرج منها ([side]: وحدةُ اتجاه)
/// وموضعُه على امتدادها ([along]: −١..١) وميلُه **نحو** الجوّال.
class _Peek {
  const _Peek(this.side, this.along, this.tilt);
  final Offset side;
  final double along;
  final double tilt; // بالدرجات — موجبٌ مع عقارب الساعة
}

const _peeks = [
  _Peek(Offset(1, 0), -0.30, -12), // يمين · يميل يساراً نحو الجوّال
  _Peek(Offset(-1, 0), 0.05, 12), // يسار · يميل يميناً
  _Peek(Offset(0, -1), 0.30, 8), // من الأعلى
  _Peek(Offset(1, 0), 0.30, -10), // يمين أسفل
];

class _EverywhereSceneState extends State<EverywhereScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _peek; // 0 مختبئ خلف الجوّال · 1 يطلّ
  Timer? _timer;
  int _i = 0;
  bool _still = false;

  @override
  void initState() {
    super.initState();
    _peek = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
      reverseDuration: const Duration(milliseconds: 260),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(EverywhereScene old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _sync();
  }

  void _sync() {
    _timer?.cancel();
    if (_still) {
      _peek.value = 1;
      return;
    }
    if (!widget.active) return;
    _peek.forward();
    _timer = Timer.periodic(const Duration(milliseconds: 2800), (_) => _next());
  }

  Future<void> _next() async {
    if (!mounted) return;
    await _peek.reverse().orCancel.catchError((_) {});
    if (!mounted) return;
    setState(() => _i = (_i + 1) % _screens.length);
    _peek.forward(from: 0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _peek.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final maxH = box.hasBoundedHeight ? box.maxHeight : 360.0;
        final maxW = box.hasBoundedWidth ? box.maxWidth : 340.0;
        // 📐 الجوّال بنسبة ١:٢ ويترك حوله مجالاً لإطلالة الرأس.
        final ph = math.min(maxH * 0.86, maxW * 1.2).clamp(200.0, 330.0);
        final pw = ph * 0.5;
        final head = pw * 0.78;
        final peek = _peeks[_i % _peeks.length];

        return SizedBox(
          width: maxW,
          height: maxH,
          child: AnimatedBuilder(
            animation: _peek,
            builder: (context, _) {
              final v = _peek.status == AnimationStatus.reverse
                  ? Curves.easeIn.transform(_peek.value)
                  : Curves.easeOutBack.transform(_peek.value);
              // 📐 الحافّةُ التي يخرج منها ثم موضعُه على امتدادها.
              final edge = Offset(
                peek.side.dx != 0 ? peek.side.dx * pw / 2 : peek.along * pw / 2,
                peek.side.dy != 0 ? peek.side.dy * ph / 2 : peek.along * ph / 2,
              );
              // يطلّ: مركزُ الرأس خارج الحافّة بخُمسه فتظهر العينُ وطرفُ العمامة
              // ويبقى أكثرُه خلف الجوّال — «يتلصّص» لا يخرج (اختيار المالك). يختبئ: خلفها كلّه.
              final out = edge + peek.side * (head * 0.20);
              final hidden = edge - peek.side * (head * 0.55);
              final c = Offset.lerp(hidden, out, v)!;
              return Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // 🌀 هالةٌ خافتة خلف المشهد.
                  Container(
                    width: ph * 0.95,
                    height: ph * 0.95,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.primary.withValues(alpha: 0.10),
                          AppColors.primary.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                  // 🤖 الرأسُ **تحت** الجوّال في المكدّس — فيطلّ من خلفه.
                  Transform.translate(
                    offset: c,
                    child: Transform.rotate(
                      angle: peek.tilt * math.pi / 180 * v,
                      child: SizedBox(
                        width: head,
                        height: head,
                        child: const MasarCharacterView(
                          character: MasarCharacter.head,
                        ),
                      ),
                    ),
                  ),
                  _Phone(width: pw, height: ph, index: _i),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════
// الجوّال — إطارٌ أبيض وشاشةٌ تتقلّب وشريطٌ يتبعها
// ══════════════════════════════════════════════════
class _Phone extends StatelessWidget {
  const _Phone({
    required this.width,
    required this.height,
    required this.index,
  });
  final double width;
  final double height;
  final int index;

  @override
  Widget build(BuildContext context) {
    final r = width * 0.2;
    final s = _screens[index];
    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.all(width * 0.045),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(r),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(r * 0.78),
        child: ColoredBox(
          color: AppColors.bgLight,
          child: Column(
            children: [
              // الجزيرة الديناميكية — تفصيلةٌ تجعله جوّالاً لا بطاقة.
              Padding(
                padding: EdgeInsets.only(top: width * 0.04),
                child: Container(
                  width: width * 0.28,
                  height: width * 0.075,
                  decoration: BoxDecoration(
                    color: AppColors.headingInk,
                    borderRadius: BorderRadius.circular(width),
                  ),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(
                        begin: const Offset(0, 0.06),
                        end: Offset.zero,
                      ).animate(a),
                      child: child,
                    ),
                  ),
                  child: KeyedSubtree(
                    key: ValueKey(index),
                    child: _ScreenBody(screen: s, unit: width / 10),
                  ),
                ),
              ),
              _MiniNav(active: s.tab, unit: width / 10),
            ],
          ),
        ),
      ),
    );
  }
}

/// شاشةٌ مصغّرة: عنوانُ القسم بأيقونته ثم ما يميّزه — بلا نصوصٍ تُقرأ،
/// فهي تلمّح للقسم ولا تُدرّسه (المقاس ≈١٥٠ نقطة لا يحمل جُملاً).
class _ScreenBody extends StatelessWidget {
  const _ScreenBody({required this.screen, required this.unit});
  final _Screen screen;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final u = unit;
    return Padding(
      padding: EdgeInsets.fromLTRB(u * 0.7, u * 0.6, u * 0.7, u * 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: u * 2,
                height: u * 2,
                decoration: BoxDecoration(
                  color: AppColors.navSurface,
                  borderRadius: BorderRadius.circular(u * 0.6),
                ),
                child: Icon(
                  screen.icon(active: true),
                  size: u * 1.2,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: u * 0.6),
              Flexible(
                child: Text(
                  screen.title,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: TextStyle(
                    fontSize: u * 1.05,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                    color: AppColors.headingInk,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: u * 0.8),
          Expanded(child: screen.body(u)),
        ],
      ),
    );
  }
}

/// الشريطُ السفليّ مصغّراً — نفسُ الأقسام ونفسُ دائرة «مسار» الوسطى.
class _MiniNav extends StatelessWidget {
  const _MiniNav({required this.active, required this.unit});
  final MasarTabHint active;
  final double unit;

  @override
  Widget build(BuildContext context) {
    final u = unit;
    Widget item(MasarTabHint t, PIcon icon) {
      final on = t == active;
      return Expanded(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          margin: EdgeInsets.symmetric(horizontal: u * 0.15),
          padding: EdgeInsets.symmetric(vertical: u * 0.35),
          decoration: BoxDecoration(
            color: on ? AppColors.surfaceWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(u * 0.6),
          ),
          child: Icon(
            icon(active: on),
            size: u * 1.05,
            color: on ? AppColors.primary : AppColors.navInk,
          ),
        ),
      );
    }

    final tutorOn = active == MasarTabHint.tutor;
    return Container(
      padding: EdgeInsets.fromLTRB(u * 0.3, u * 0.35, u * 0.3, u * 0.55),
      decoration: BoxDecoration(
        color: AppColors.navSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(u * 0.9)),
      ),
      child: Row(
        children: [
          item(MasarTabHint.home, PI.house),
          item(MasarTabHint.quiz, PI.listChecks),
          // دائرةُ «مسار» — تكبر قليلاً حين تكون شاشتُها.
          AnimatedScale(
            scale: tutorOn ? 1.12 : 1,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            child: Container(
              width: u * 1.9,
              height: u * 1.9,
              margin: EdgeInsets.symmetric(horizontal: u * 0.2),
              decoration: BoxDecoration(
                color: AppColors.primaryFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                PI.chatCircleDots(active: true),
                size: u * 1.0,
                color: Colors.white,
              ),
            ),
          ),
          item(MasarTabHint.scholarships, PI.airplaneInFlight),
          item(MasarTabHint.services, PI.cloudCheck),
        ],
      ),
    );
  }
}

/// أقسامُ الشريط كما في [MasarTab] — نسخةٌ محلّية كي لا يستورد مشهدُ
/// الترحيب هيكلَ التطبيق كلَّه.
enum MasarTabHint { home, quiz, tutor, scholarships, services }

class _Screen {
  const _Screen(this.tab, this.icon, this.title, this.body);
  final MasarTabHint tab;
  final PIcon icon;
  final String title;
  final Widget Function(double u) body;
}

final _screens = <_Screen>[
  _Screen(MasarTabHint.home, PI.house, "الرئيسية", _homeBody),
  _Screen(MasarTabHint.tutor, PI.chatCircleDots, "مسار", _chatBody),
  _Screen(MasarTabHint.quiz, PI.listChecks, "اختبر نفسك", _quizBody),
  _Screen(MasarTabHint.scholarships, PI.airplaneInFlight, "المنح", _grantsBody),
];

// ── أجسامُ الشاشات: كتلٌ بألوان التصميم تلمّح لكل قسم ──

Widget _bar(double u, double w, {Color? color, double h = 0.5}) => Container(
  width: w,
  height: u * h,
  decoration: BoxDecoration(
    color: color ?? AppColors.border,
    borderRadius: BorderRadius.circular(u),
  ),
);

Widget _homeBody(double u) => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    // بطاقةُ الترحيب الزرقاء.
    Container(
      height: u * 3.6,
      padding: EdgeInsets.all(u * 0.7),
      decoration: BoxDecoration(
        color: AppColors.primaryFill,
        borderRadius: BorderRadius.circular(u * 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _bar(u, u * 4.5, color: Colors.white.withValues(alpha: 0.95)),
          SizedBox(height: u * 0.45),
          _bar(u, u * 3, color: Colors.white.withValues(alpha: 0.6)),
        ],
      ),
    ),
    SizedBox(height: u * 0.7),
    Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final ic in [PI.bookOpenText, PI.graduationCap]) ...[
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(u * 0.8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Icon(
                  ic(active: true),
                  size: u * 1.5,
                  color: AppColors.primary,
                ),
              ),
            ),
            if (ic == PI.bookOpenText) SizedBox(width: u * 0.6),
          ],
        ],
      ),
    ),
  ],
);

Widget _chatBody(double u) {
  Widget bubble(bool me, double w) => Align(
    // الطالبُ يميناً بلون الهوية، ومسار يساراً أبيض — كتجربة المحادثة.
    alignment: me
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd,
    child: Container(
      width: w,
      padding: EdgeInsets.all(u * 0.55),
      margin: EdgeInsets.only(bottom: u * 0.55),
      decoration: BoxDecoration(
        color: me ? AppColors.primaryFill : AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(u * 0.7),
        border: me ? null : Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bar(
            u,
            w * 0.8,
            color: me ? Colors.white.withValues(alpha: 0.9) : null,
            h: 0.4,
          ),
          if (!me) ...[
            SizedBox(height: u * 0.35),
            _bar(u, w * 0.6, h: 0.4),
            SizedBox(height: u * 0.35),
            _bar(u, w * 0.7, h: 0.4),
          ],
        ],
      ),
    ),
  );
  return Column(
    children: [
      bubble(true, u * 5),
      bubble(false, u * 6.4),
      bubble(true, u * 3.6),
    ],
  );
}

Widget _quizBody(double u) {
  Widget option(bool right) => Container(
    height: u * 1.7,
    margin: EdgeInsets.only(bottom: u * 0.5),
    padding: EdgeInsets.symmetric(horizontal: u * 0.5),
    decoration: BoxDecoration(
      color: right ? AppColors.schGreenFill : AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(u * 0.6),
      border: Border.all(
        color: right ? AppColors.success500 : AppColors.border,
      ),
    ),
    child: Row(
      children: [
        Icon(
          right ? PI.checkCircle(active: true) : PI.checkCircle(),
          size: u * 0.95,
          color: right ? AppColors.success600 : AppColors.border,
        ),
        SizedBox(width: u * 0.45),
        _bar(u, u * 3.4, h: 0.4),
      ],
    ),
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _bar(u, double.infinity, h: 0.45),
      SizedBox(height: u * 0.35),
      _bar(u, u * 4.5, h: 0.45),
      SizedBox(height: u * 0.8),
      option(false),
      option(true),
      option(false),
    ],
  );
}

Widget _grantsBody(double u) {
  Widget card(Color flag) => Container(
    height: u * 2.4,
    margin: EdgeInsets.only(bottom: u * 0.55),
    padding: EdgeInsets.all(u * 0.5),
    decoration: BoxDecoration(
      color: AppColors.surfaceWhite,
      borderRadius: BorderRadius.circular(u * 0.7),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      children: [
        Container(
          width: u * 1.4,
          height: u * 1.4,
          decoration: BoxDecoration(color: flag, shape: BoxShape.circle),
        ),
        SizedBox(width: u * 0.5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _bar(u, u * 3.6, h: 0.4),
              SizedBox(height: u * 0.3),
              _bar(
                u,
                u * 2.2,
                h: 0.4,
                color: AppColors.primary.withValues(alpha: 0.35),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  return Column(
    children: [
      card(const Color(0xFFE63946)),
      card(const Color(0xFF2A9D8F)),
      card(const Color(0xFFF4A261)),
    ],
  );
}
