import 'dart:io';

import 'package:flutter/material.dart';

// 📍 يعيش في `core/media` لأن **قسمين** يستعملانه: التعليم ومساعد المنح.
// ==========================================
// 🔍 عارض الصورة ملء الشاشة
// ==========================================
// يُفتح بالضغط على صورة داخل المحادثة. يدعم التكبير بالإصبعين والسحب،
// والتنقّل بين صورتي الرسالة الواحدة.
class ImageViewerScreen extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.paths,
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pc;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pc = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final multi = widget.paths.length > 1;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        elevation: 0,
        title: multi
            ? Text("${_index + 1} من ${widget.paths.length}",
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900))
            : null,
      ),
      body: PageView.builder(
        controller: _pc,
        itemCount: widget.paths.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (_, i) => InteractiveViewer(
          minScale: 1,
          maxScale: 5,
          child: Center(
            child: Image.file(
              File(widget.paths[i]),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_not_supported_rounded,
                      color: Colors.white54, size: 46),
                  const SizedBox(height: 10),
                  const Text("الصورة لم تعد متاحة",
                      style: TextStyle(color: Colors.white70,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
