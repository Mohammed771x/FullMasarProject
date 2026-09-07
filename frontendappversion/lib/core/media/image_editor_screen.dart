import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_cropper/image_cropper.dart';

import '../services/image_service.dart';
import '../theme/app_colors.dart';

// 📍 يعيش في `core/media` لأن **قسمين** يستعملانه: التعليم ومساعد المنح.
// ==========================================
// ✏️ محرّر الصورة — قص + تحديد بالرسم
// ==========================================
// يفتح قبل الإرسال ليتمكّن الطالب من:
//   ✂️ قص الصورة (عبر image_cropper الأصلي)
//   🖊️ الرسم عليها لتحديد السؤال المقصود
//   ↩️ تراجع / 🗑️ مسح الرسم
// النتيجة تُدمج في صورة جديدة (الرسم يُحرق داخلها) وتُحفظ محلياً.
class ImageEditorScreen extends StatefulWidget {
  final PickedImage image;
  const ImageEditorScreen({super.key, required this.image});

  @override
  State<ImageEditorScreen> createState() => _ImageEditorScreenState();
}

class _Stroke {
  final List<Offset> points;
  final Color color;
  final double width;
  _Stroke(this.points, this.color, this.width);
}

class _ImageEditorScreenState extends State<ImageEditorScreen> {
  final GlobalKey _canvasKey = GlobalKey();
  final List<_Stroke> _strokes = [];

  late String _path;
  bool _busy = false;

  static const List<Color> _palette = [
    Color(0xFFEF4444), // أحمر
    Color(0xFF3B82F6), // أزرق
    Color(0xFF22C55E), // أخضر
    Color(0xFFF59E0B), // برتقالي
  ];
  Color _color = _palette.first;
  double _width = 5;

  @override
  void initState() {
    super.initState();
    _path = widget.image.path;
  }

  // ───────── القص ─────────
  Future<void> _crop() async {
    setState(() => _busy = true);
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: _path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 90,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: "قص الصورة",
            toolbarColor: AppColors.primary,
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: AppColors.primary,
            lockAspectRatio: false,
          ),
          IOSUiSettings(title: "قص الصورة", aspectRatioLockEnabled: false),
        ],
      );
      if (cropped != null && mounted) {
        setState(() {
          _path = cropped.path;
          _strokes.clear(); // إحداثيات الرسم لم تعد صالحة بعد القص
        });
      }
    } catch (_) {
      _notify("✂️ تعذّر فتح أداة القص.");
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ───────── الحفظ (دمج الرسم داخل الصورة) ─────────
  Future<void> _confirm() async {
    if (_strokes.isEmpty) {
      // لا رسم — نكتفي بالصورة (المقصوصة إن قُصّت)
      final plain = await ImageService.I.fromPath(_path);
      if (!mounted) return;
      Navigator.pop(context, plain);
      return;
    }
    setState(() => _busy = true);
    try {
      final boundary = _canvasKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;
      final ui.Image rendered = await boundary.toImage(pixelRatio: 2.0);
      final ByteData? bytes =
          await rendered.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) throw Exception();

      final edited = await ImageService.I.saveEdited(
        bytes.buffer.asUint8List(),
      );
      if (mounted) Navigator.pop(context, edited);
    } catch (_) {
      _notify("✏️ تعذّر حفظ التعديل.");
      if (mounted) setState(() => _busy = false);
    }
  }

  void _notify(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
      backgroundColor: Colors.orange.shade700,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text("تعديل الصورة",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
        actions: [
          if (_strokes.isNotEmpty) ...[
            IconButton(
              tooltip: "تراجع",
              icon: const Icon(Icons.undo_rounded),
              onPressed: _busy ? null : () => setState(_strokes.removeLast),
            ),
            IconButton(
              tooltip: "مسح الرسم",
              icon: const Icon(Icons.layers_clear_rounded),
              onPressed: _busy ? null : () => setState(_strokes.clear),
            ),
          ],
          IconButton(
            tooltip: "قص",
            icon: const Icon(Icons.crop_rounded),
            onPressed: _busy ? null : _crop,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: RepaintBoundary(
                key: _canvasKey,
                child: Stack(
                  children: [
                    Image.file(File(_path), fit: BoxFit.contain),
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (d) => setState(() =>
                            _strokes.add(_Stroke([d.localPosition], _color, _width))),
                        onPanUpdate: (d) => setState(() =>
                            _strokes.last.points.add(d.localPosition)),
                        child: CustomPaint(
                          painter: _StrokePainter(_strokes),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _toolbar(),
        ],
      ),
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      color: const Color(0xFF111827),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Row(
              children: [
                ..._palette.map((c) => Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: GestureDetector(
                        onTap: () => setState(() => _color = c),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _color == c ? Colors.white : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                      ),
                    )),
                Expanded(
                  child: Slider(
                    value: _width,
                    min: 2,
                    max: 16,
                    activeColor: _color,
                    inactiveColor: Colors.white24,
                    onChanged: (v) => setState(() => _width = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: _busy ? null : _confirm,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor: AlwaysStoppedAnimation(Colors.white)))
                    : const Icon(Icons.check_rounded),
                label: const Text("تم",
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<_Stroke> strokes;
  _StrokePainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (final p in s.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) => true;
}
