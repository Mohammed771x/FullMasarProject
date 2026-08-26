import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../theme/app_colors.dart';

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

    return MarkdownBody(
      data: textToRender,
      styleSheet: MarkdownStyleSheet(
        textAlign: widget.isCentered ? WrapAlignment.center : WrapAlignment.start,
        p: TextStyle(
          fontSize: 16,
          color: AppColors.textPrimary,
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
