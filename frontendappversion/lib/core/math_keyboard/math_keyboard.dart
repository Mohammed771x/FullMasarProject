import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../widgets/math_text.dart';
import 'math_editor.dart';

// ============================================================
// ⌨️ math_keyboard.dart — كيبورد الرياضيات (مادة الرياضيات وحدها)
// ============================================================
// 📚 **المفاتيحُ من المنهج لا من الذاكرة.** مسحتُ ٨١ ملفاً (٥٢٧ ألف حرف:
//    الأول والثاني والثالث علمي وأدبي والوزاري) وعددتُ كلَّ رمز:
//    ( ) ٧٨٨٩ · = ٧٣٨٨ · + ٣٠٣٤ · كسر ٢٣٩٩ · أُسّ ١٤٣٤ · قا ٩١٥ · لو ٩٧٦ ·
//    جا ٧١٤ · هـ ٥٧٢ · | ٥٦٩ · ∫ ٥٠٣ · جتا ٤١٣ · ← ٣٧٧ · نها ٣٦٠ · جذر ٣٣٦ ·
//    π ٢٦٢ · لط ٢٦٠ · ظا ٢٠٢ · ± ٢٠٠ · ≤ ١٥٠ · ∞ ١٢٢ · Δ ١٠٨ · ≈ ١٠٤ · …
//    فالأكثرُ استعمالاً في الصفحة الأولى، والنادرُ في «رموز».
//
// ⭐ **كلُّ مفتاحٍ يكتب ترميزَ الرسّام نفسَه** — فما يُكتب هو ما يُرسم في
//    الفقاعة وما يقرؤه الموديل حرفياً. راجع [MathEditor].

/// ماذا يفعل المفتاح.
enum MathAction { backspace, forward, backward, space, newline, system }

enum _Tone { digit, op, fn, action, accent }

class _Key {
  const _Key(
    this.label, {
    this.text,
    this.template,
    this.action,
    this.tone = _Tone.digit,
    this.markup = false,
    this.icon,
    this.alternates,
    this.flex = 1,
  });

  /// عرضُ المفتاح بالنسبة لجيرانه — مفتاحُ الحذف في صفّ الحروف أعرض.
  final int flex;

  /// حروفٌ تظهر بالضغط المطوّل (الهمزات).
  final List<String>? alternates;

  /// أيقونةٌ بدل النصّ (الأسهم والحذف) — محارفُ «◀» تُرسم رموزاً تعبيرية في iOS.
  final IconData? icon;

  /// ما يظهر على المفتاح — نصٌّ عاديّ أو ترميزٌ يُرسم ([markup]).
  final String label;
  final String? text;
  final String? template;
  final MathAction? action;
  final _Tone tone;
  final bool markup;
}

// ⬚ خانةٌ في رسم المفتاح — العلامةُ نفسُها التي يرسمها المحرّر.
const _s = kSlotMark;

_Key _t(String label, {_Tone tone = _Tone.fn}) =>
    _Key(label, text: label, tone: tone);
_Key _d(String label) => _Key(label, text: label);

/// حروفُ الضغط المطوّل — كما في كيبورد الجوال.
const Map<String, List<String>> _alternates = {
  'ا': ['أ', 'إ', 'آ'],
  'ي': ['ئ'],
  'ى': ['ئ'],
  'و': ['ؤ'],
  'ء': ['أ', 'إ', 'ؤ', 'ئ'],
  'ه': ['ـ'],
};
_Key _l(String c) => _Key(c, text: c, alternates: _alternates[c]);
_Key _op(String label, [String? text]) =>
    _Key(label, text: text ?? label, tone: _Tone.op);
_Key _fn(String name) => _Key(name, text: '$name ', tone: _Tone.fn);
_Key _tpl(String label, String template, {_Tone tone = _Tone.accent}) =>
    _Key(label, template: template, tone: tone, markup: true);

class _Page {
  const _Page(this.title, this.rows, {this.letters = false, this.phrases});
  final String title;
  final List<List<_Key>> rows;

  /// صفحةُ الحروف — مفاتيحُ أضيق وعلامتا «، ؟» بجانب المسافة.
  final bool letters;
  final List<String>? phrases;
}

final List<_Page> _pages = [
  // ── ١ أساسي: الأرقام والعمليات والبُنى الأكثر تكراراً ──
  _Page('أساسي', [
    [
      _d('٧'),
      _d('٨'),
      _d('٩'),
      _op('÷'),
      _tpl('\\frac{$_s}{$_s}', r'\frac{‸}{}'),
      _tpl('\\sqrt{$_s}', r'\sqrt{‸}'),
    ],
    [
      _d('٤'),
      _d('٥'),
      _d('٦'),
      _op('×'),
      _tpl('$_s\\sup{٢}', r'\sup{٢}‸'),
      _tpl('$_s\\sup{$_s}', r'\sup{‸}'),
    ],
    [_d('١'), _d('٢'), _d('٣'), _op('−', '-'), _op('('), _op(')')],
    [_d('٠'), _op('٫'), _op('='), _op('+'), _t('س'), _t('ص')],
  ]),
  // ── ٢ الدوال: المثلثية واللوغاريتمية والأُسّية ──
  _Page('دوال', [
    [
      _fn('جا'),
      _fn('جتا'),
      _fn('ظا'),
      _tpl('$_s\\sup{٢}', r'\sup{٢}‸'),
      _tpl('$_s\\sup{$_s}', r'\sup{‸}'),
      _tpl('$_s\\sup{-١}', r'\sup{-١}‸'),
    ],
    [
      _fn('قا'),
      _fn('قتا'),
      _fn('ظتا'),
      _t('π'),
      _t('هـ'),
      _tpl('هـ\\sup{$_s}', r'هـ\sup{‸}'),
    ],
    [
      _fn('لو'),
      _tpl('لو\\sub{$_s}', r'لو\sub{‸} '),
      _fn('لط'),
      _Key('|$_s|', template: '|‸|', tone: _Tone.accent, markup: true),
      _tpl('\\sqrt[$_s]{$_s}', r'\sqrt[‸]{}'),
      _t('°', tone: _Tone.op),
    ],
    [_t('س'), _t('ص'), _t('ع'), _t('ن'), _t('ت'), _op('،', '، ')],
  ]),
  // ── ٣ التفاضل والتكامل والعدّ ──
  _Page('تفاضل وتكامل', [
    [
      _tpl('نها\\sub{س←$_s}', r'نها\sub{س←‸} '),
      _t('∫'),
      _tpl('∫\\sub{$_s}\\sup{$_s}', r'∫\sub{‸}\sup{} '),
      _t('د س'),
      _tpl('\\frac{دص}{دس}', r'\frac{دص}{دس}'),
      _t('∞', tone: _Tone.op),
    ],
    [
      _t('د(س)'),
      _t('′', tone: _Tone.op),
      _t('″', tone: _Tone.op),
      _t('←', tone: _Tone.op),
      _t('Δ', tone: _Tone.op),
      _t('±', tone: _Tone.op),
    ],
    [
      _tpl('\\fact{$_s}', r'\fact{‸}'),
      _tpl('\\perm{$_s}{$_s}', r'\perm{‸}{}'),
      _tpl('\\comb{$_s}{$_s}', r'\comb{‸}{}'),
      _tpl('\\ovl{$_s}', r'\ovl{‸}'),
      _t('مجـ'),
      _t('!', tone: _Tone.op),
    ],
    [
      _op('['),
      _op(']'),
      _op('⟨'),
      _op('⟩'),
      _tpl('$_s\\sub{$_s}', r'\sub{‸}'),
      _t('ر(س)'),
    ],
  ]),
  // ── ٤ رموز العلاقات والمجموعات والمنطق ──
  _Page('رموز', [
    [_op('<'), _op('>'), _op('≤'), _op('≥'), _op('≠'), _op('≈')],
    [_op('∈'), _op('∉'), _op('∪'), _op('∩'), _op('⊂'), _op('∅')],
    [_op('∴'), _op('∵'), _op('⇐'), _op('⟺'), _op('⊥'), _op('∥')],
    [_op('ℝ'), _op('%'), _op(':'), _op('؟'), _op('/'), _op('∀')],
  ]),
  // ── ٥ حروف: لكتابة الطلب نفسِه بلا خروجٍ من الكيبورد ──
  _Page(
    'حروف',
    [
      // ⌨️ **ترتيبُ كيبورد الآيفون العربي كما في لقطة المالك** (٢٠٢٦-٠٩-٣٠)
      //    — والصفوفُ تُقرأ **من اليسار**: «ض» أقصى اليسار و«ج» أقصى اليمين،
      //    و«ة» آخرُ الصفّ الثاني، والحذفُ آخرُ الثالث. كانت مقلوبةً (من
      //    اليمين) فتاه الإصبعُ الذي يعرف مكانَ كلّ حرف.
      //    والإضافيّةُ بالضغط المطوّل كالجوال: «ا» ⇐ أ إ آ ، «و» ⇐ ؤ ،
      //    «ى/ي/ء» ⇐ ئ ، «ه» ⇐ ـ.
      ['ض', 'ص', 'ث', 'ق', 'ف', 'غ', 'ع', 'ه', 'خ', 'ح', 'ج'].map(_l).toList(),
      ['ش', 'س', 'ي', 'ب', 'ل', 'ا', 'ت', 'ن', 'م', 'ك', 'ة'].map(_l).toList(),
      [
        ...['ء', 'ظ', 'ط', 'ذ', 'د', 'ز', 'ر', 'و', 'ى'].map(_l),
        const _Key(
          '',
          icon: Icons.backspace_outlined,
          action: MathAction.backspace,
          tone: _Tone.action,
          flex: 2,
        ),
      ],
    ],
    letters: true,
    phrases: [
      'أوجد ',
      'احسب ',
      'حل المعادلة: ',
      'أثبت أن ',
      'بسّط ',
      'اشتق ',
      'إذا كانت ',
      'فأوجد ',
      'ارسم ',
      'عندما ',
    ],
  ),
];

/// ⌨️ الكيبورد نفسُه — يُوضع مكانَ كيبورد الجوال أسفل الشاشة.
class MathKeyboard extends StatefulWidget {
  const MathKeyboard({
    super.key,
    required this.editor,
    required this.onChanged,
    required this.onSystemKeyboard,
  });

  final MathEditor editor;

  /// بعد كل ضغطة — كي يُعاد رسمُ الحقل ويُضاء زرُّ الإرسال.
  final VoidCallback onChanged;

  /// «أ ب ج» — العودةُ إلى كيبورد الجوال.
  final VoidCallback onSystemKeyboard;

  @override
  State<MathKeyboard> createState() => _MathKeyboardState();
}

class _MathKeyboardState extends State<MathKeyboard> {
  int _page = 0;

  void _press(_Key k) {
    HapticFeedback.selectionClick();
    final e = widget.editor;
    if (k.action != null) {
      switch (k.action!) {
        case MathAction.backspace:
          e.backspace();
        case MathAction.forward:
          e.forward();
        case MathAction.backward:
          e.backward();
        case MathAction.space:
          e.insert(' ');
        case MathAction.newline:
          e.insert('\n');
        case MathAction.system:
          widget.onSystemKeyboard();
          return;
      }
    } else if (k.template != null) {
      e.insertTemplate(k.template!);
    } else if (k.text != null) {
      e.insert(k.text!);
    }
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final page = _pages[_page];
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.softSurface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      padding: EdgeInsets.fromLTRB(5, 6, 5, bottomInset > 0 ? bottomInset : 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _tabs(),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: KeyedSubtree(
              key: ValueKey(_page),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (page.phrases != null) _phrases(page.phrases!),
                  // ⬅️ كلُّ الصفوف تُرصّ من اليسار — الأرقامُ كالآلة الحاسبة،
                  //    والحروفُ كالآيفون (لقطةُ المالك).
                  for (final row in page.rows)
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Row(
                        children: [
                          for (final k in row)
                            Expanded(
                              flex: k.flex,
                              child: _KeyButton(
                                data: k,
                                compact: page.letters,
                                repeat: k.action == MathAction.backspace,
                                onTap: () => _press(k),
                                onAlternate: (c) => _press(_Key(c, text: c)),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          _controlRow(letters: page.letters),
        ],
      ),
    );
  }

  /// شريطُ الصفحات — يُقرأ من اليمين كبقية التطبيق.
  Widget _tabs() => Directionality(
    textDirection: TextDirection.rtl,
    child: SizedBox(
      height: 32,
      child: Row(
        children: [
          for (var i = 0; i < _pages.length; i++)
            Expanded(
              flex: _pages[i].title.length > 6 ? 5 : 3,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _page = i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.primaryFill
                        : AppColors.surfaceWhite,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: i == _page
                          ? AppColors.primaryFill
                          : AppColors.border,
                    ),
                  ),
                  child: Text(
                    _pages[i].title,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: i == _page
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  /// كلماتُ الطلب الجاهزة — «أوجد» و«احسب» بضغطة.
  Widget _phrases(List<String> phrases) => Directionality(
    textDirection: TextDirection.rtl,
    child: SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 2),
        children: [
          for (final p in phrases)
            Padding(
              padding: const EdgeInsets.only(left: 6, bottom: 4),
              child: GestureDetector(
                onTap: () => _press(_Key(p, text: p)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primaryTintSurface,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    p.trim(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );

  /// الصفُّ الثابت أسفل كل صفحة: كيبورد الجوال · الأسهم · المسافة · الحذف.
  ///
  /// ↔️ **السهمان بصريّان لا منطقيّان**: «◀» يحرّك المؤشر يساراً على
  ///    الشاشة، وهو في العربية **إلى الأمام** — فيخرج من البسط إلى المقام
  ///    ومن الأُسّ إلى ما بعده كما يتوقّع الإصبع.
  Widget _controlRow({bool letters = false}) {
    Widget key(int flex, _Key k, {bool repeat = false}) => Expanded(
      flex: flex,
      child: _KeyButton(data: k, repeat: repeat, onTap: () => _press(k)),
    );
    // ⬅️ الصفُّ عربيّ الاتجاه: «أ ب ج» يميناً والحذفُ يساراً كما في iOS،
    //    والسهمان متجاوران كلٌّ يشير إلى حيث يمشي المؤشر على الشاشة.
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        children: [
          key(
            3,
            const _Key('أ ب ج', action: MathAction.system, tone: _Tone.action),
          ),
          key(
            2,
            const _Key(
              '',
              icon: Icons.keyboard_return_rounded,
              action: MathAction.newline,
              tone: _Tone.action,
            ),
          ),
          if (letters) key(1, const _Key('،', text: '، ', tone: _Tone.op)),
          key(letters ? 3 : 4, const _Key('مسافة', action: MathAction.space)),
          if (letters) key(1, const _Key('؟', text: '؟', tone: _Tone.op)),
          key(
            2,
            const _Key(
              '',
              icon: Icons.chevron_right_rounded,
              action: MathAction.backward,
              tone: _Tone.action,
            ),
            repeat: true,
          ),
          key(
            2,
            const _Key(
              '',
              icon: Icons.chevron_left_rounded,
              action: MathAction.forward,
              tone: _Tone.action,
            ),
            repeat: true,
          ),
          if (!letters)
            key(
              2,
              const _Key(
                '',
                icon: Icons.backspace_outlined,
                action: MathAction.backspace,
                tone: _Tone.action,
              ),
              repeat: true,
            ),
        ],
      ),
    );
  }
}

/// مفتاحٌ واحد — يغوص قليلاً عند اللمس، ويتكرّر مع الضغط المطوّل (الحذف
/// والأسهم) كما في كيبورد iOS.
class _KeyButton extends StatefulWidget {
  const _KeyButton({
    required this.data,
    required this.onTap,
    this.repeat = false,
    this.compact = false,
    this.onAlternate,
  });

  final ValueChanged<String>? onAlternate;

  final _Key data;
  final VoidCallback onTap;
  final bool repeat;
  final bool compact;

  @override
  State<_KeyButton> createState() => _KeyButtonState();
}

class _KeyButtonState extends State<_KeyButton> {
  bool _down = false;
  Timer? _hold;
  Timer? _tick;

  @override
  void dispose() {
    _hold?.cancel();
    _tick?.cancel();
    super.dispose();
  }

  OverlayEntry? _popup;
  bool _popped = false;

  bool get _hasAlternates =>
      (widget.data.alternates?.isNotEmpty ?? false) &&
      widget.onAlternate != null;

  /// 🔠 نافذةُ الهمزات فوق المفتاح — تُختار بلمسة، وتُغلق بلمسةٍ خارجها.
  void _showAlternates() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    HapticFeedback.mediumImpact();
    _popped = true;
    final at = box.localToGlobal(Offset.zero);
    final alts = widget.data.alternates!;
    const w = 44.0;
    final width = w * alts.length + 12;
    final screen = MediaQuery.sizeOf(context).width;
    final left = (at.dx + box.size.width / 2 - width / 2).clamp(
      6.0,
      screen - width - 6,
    );
    _popup = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closePopup,
            ),
          ),
          Positioned(
            left: left,
            top: at.dy - 58,
            child: Material(
              elevation: 6,
              color: AppColors.surfaceWhite,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: TextDirection.rtl,
                  children: [
                    for (final c in alts)
                      GestureDetector(
                        onTap: () {
                          widget.onAlternate!(c);
                          _closePopup();
                        },
                        child: Container(
                          width: w,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.primaryTintSurface,
                            borderRadius: BorderRadius.circular(9),
                          ),
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_popup!);
  }

  void _closePopup() {
    _popup?.remove();
    _popup = null;
  }

  void _start() {
    setState(() => _down = true);
    if (_hasAlternates) {
      // ⏳ الحرفُ يُكتب عند الرفع لا عند اللمس: الضغطُ المطوّل يفتح الهمزات.
      _popped = false;
      _hold = Timer(const Duration(milliseconds: 380), _showAlternates);
      return;
    }
    widget.onTap();
    if (widget.repeat) {
      _hold = Timer(const Duration(milliseconds: 420), () {
        _tick = Timer.periodic(
          const Duration(milliseconds: 75),
          (_) => widget.onTap(),
        );
      });
    }
  }

  void _release() {
    if (_hasAlternates && !_popped) widget.onTap();
    _stop();
  }

  void _stop() {
    _hold?.cancel();
    _tick?.cancel();
    if (mounted) setState(() => _down = false);
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.data;
    final (Color bg, Color ink) = switch (k.tone) {
      _Tone.digit => (AppColors.surfaceWhite, AppColors.textPrimary),
      _Tone.op => (AppColors.surfaceWhite, AppColors.primary),
      _Tone.fn => (AppColors.primaryTintSurface, AppColors.primary),
      _Tone.accent => (AppColors.primaryTintSurface, AppColors.textPrimary),
      _Tone.action => (AppColors.modeGroupSurface, AppColors.textPrimary),
    };
    final size = widget.compact ? 17.0 : 19.0;
    final style = TextStyle(
      fontSize: size,
      fontWeight: FontWeight.w700,
      color: ink,
      height: 1.2,
    );
    Widget label = k.icon != null
        // ↔️ أيقوناتُ Material تنقلب في الاتجاه العربيّ — والسهمُ هنا يشير
        //    إلى حيث يمشي المؤشرُ على الشاشة، فلا يُقلب.
        ? Directionality(
            textDirection: k.action == MathAction.backspace
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: Icon(k.icon, size: 24, color: ink),
          )
        : k.markup
        ? MathText(
            k.label,
            style: style.copyWith(fontSize: 16, height: 1.25),
            ruleColor: ink,
          )
        : Text(k.label, style: style, textAlign: TextAlign.center);

    return Listener(
      onPointerDown: (_) => _start(),
      onPointerUp: (_) => _release(),
      onPointerCancel: (_) => _stop(),
      child: AnimatedScale(
        scale: _down ? 0.92 : 1,
        duration: const Duration(milliseconds: 70),
        child: Container(
          height: 46,
          margin: EdgeInsets.symmetric(
            horizontal: widget.compact ? 1.5 : 2.5,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: _down ? AppColors.primaryMuted : bg,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.10),
                offset: const Offset(0, 1.2),
                blurRadius: 0.5,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: label,
            ),
          ),
        ),
      ),
    );
  }
}
