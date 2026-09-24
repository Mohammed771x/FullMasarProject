import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'masar_markdown.dart';
import '../theme/app_colors.dart';
import '../settings/app_settings.dart';

// ==========================================
// ⌨️ كلاس الكتابة المتسلسلة (Premium Typewriter)
// ==========================================
class TypewriterText extends StatefulWidget {
  final String text;
  final VoidCallback? onFinished;
  final bool isCentered;
  final ValueNotifier<bool>? stopNotifier;
  final Function(String)? onStopped;
  final VoidCallback? onTyping; // 👈 أضفنا هذي عشان النزول التلقائي

  const TypewriterText({
    super.key,
    required this.text,
    this.onFinished,
    this.isCentered = false,
    this.stopNotifier,
    this.onStopped,
    this.onTyping, // 👈
  });

  @override
  State<TypewriterText> createState() => _TypewriterTextState();
}

class _TypewriterTextState extends State<TypewriterText> {
  String _displayedText = "";
  bool _isStopped = false;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    if (widget.stopNotifier != null) {
      widget.stopNotifier!.addListener(_onStopRequested);
    }
    _startTyping();
  }

  void _onStopRequested() {
    if (widget.stopNotifier?.value == true && !_isStopped) {
      _isStopped = true;
      if (widget.onStopped != null) {
        widget.onStopped!(_displayedText);
      }
    }
  }

  @override
  void dispose() {
    if (widget.stopNotifier != null) {
      widget.stopNotifier!.removeListener(_onStopRequested);
    }
    super.dispose();
  }

  void _startTyping() async {
    final String fullText = widget.text;
    int currentIndex = 0;

    int step = 12;

    while (currentIndex < fullText.length) {
      if (!mounted || _isStopped) break;

      currentIndex += step;
      if (currentIndex > fullText.length) {
        currentIndex = fullText.length;
      }
      // ☢️ **لا يُقطع الرمزُ التعبيريّ نصفين** (رُئي في المحاكي ٢٠٢٦-٠٩-٢٣):
      //    الخطوةُ ١٢ وحدةَ UTF-16، والرمزُ مثل 📝 وحدتان (زوجٌ بديل). فإن
      //    وقع القطعُ بينهما مرّ نصفُ رمزٍ إلى محرّك النصّ فرمى «string is not
      //    well-formed UTF-16» — مربّعاً رمادياً في النسخة المنشورة.
      if (currentIndex < fullText.length &&
          _isHighSurrogate(fullText.codeUnitAt(currentIndex - 1))) {
        currentIndex++;
      }

      await Future.delayed(const Duration(milliseconds: 15));

      if (mounted && !_isStopped) {
        setState(() {
          _displayedText = fullText.substring(0, currentIndex);
        });

        // 👈 هذا اللي بيخلي الشاشة تسحب لتحت مع كل دفعة كلمات جديدة
        if (widget.onTyping != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.onTyping!();
          });
        }
      }
    }

    if (mounted && !_isStopped) {
      setState(() {
        _isFinished = true;
      });

      // نسحب الشاشة سحبة أخيرة للتأكيد بعد ما يخلص
      if (widget.onTyping != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          widget.onTyping!();
        });
      }

      if (widget.onFinished != null) {
        widget.onFinished!();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String textToRender = _displayedText;

    if (!_isFinished && !_isStopped) {
      textToRender += " ▌";
    }

    // 🧮 يرسم الكسور بسطاً فوق مقام، ويسلّم الباقي لـMarkdownBody كما كان.
    return MasarMarkdown(
      data: textToRender,
      styleSheet: MarkdownStyleSheet(
        textAlign: widget.isCentered ? WrapAlignment.center : WrapAlignment.start,
        p: TextStyle(
          // ⚙️ حجم خط الإجابة كما ضبطه الطالب — لا رقم ثابت.
          fontSize: AppSettings.I.answerFontSize,
          color: AppColors.textPrimary,
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// النصفُ الأوّلُ من زوجٍ بديل (U+D800–U+DBFF) — لا يُعرض وحده أبداً.
bool _isHighSurrogate(int unit) => unit >= 0xD800 && unit <= 0xDBFF;
