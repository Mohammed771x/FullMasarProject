import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

// ==========================================
// 📷 خدمة الصور — التقاط · ضغط · تخزين محلي
// ==========================================
// قرار المالك: الصور تُخزَّن **على جوال الطالب فقط**. لا رفع للتخزين السحابي،
// ولا حفظ على الخادم (الباك اند يقرأها ويستخرج نصها ثم يتجاهلها فوراً).
//
// الضغط إلزامي: صورة كاميرا خام 3–5 ميجابايت، وبعد الضغط 80–250 كيلوبايت —
// فارق حاسم على شبكة يمنية بطيئة وبيانات غالية.
class PickedImage {
  /// الملف المحفوظ في مجلد التطبيق (يُعرض في سجل المحادثة).
  final String path;

  /// base64 للإرسال إلى /ask.
  final String base64Data;

  final int sizeBytes;

  const PickedImage({
    required this.path,
    required this.base64Data,
    required this.sizeBytes,
  });
}

class ImageService {
  ImageService._();
  static final ImageService I = ImageService._();

  final ImagePicker _picker = ImagePicker();

  /// أقصى بُعد بعد الضغط. 1024 كافٍ لقراءة نص الكتاب بوضوح.
  static const int _maxDimension = 1024;
  static const int _quality = 65;

  /// حد أمان في التطبيق نفسه — الخادم يفرض حده أيضاً.
  static const int _maxBytes = 1400 * 1024;

  /// يلتقط صورة ويضغطها ويحفظها محلياً. يرجع null إن ألغى الطالب.
  /// يرمي [ImageException] برسالة عربية عند الفشل.
  Future<PickedImage?> pick({required bool fromCamera}) async {
    final XFile? shot = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: _maxDimension.toDouble(),
      maxHeight: _maxDimension.toDouble(),
      imageQuality: 80, // ضغط أولي من المنتقي، ثم ضغطنا الدقيق أدناه
    );
    if (shot == null) return null; // ألغى الطالب — ليس خطأ

    try {
      final Uint8List? compressed = await FlutterImageCompress.compressWithFile(
        shot.path,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: _quality,
        format: CompressFormat.jpeg,
      );

      // إن فشل الضغط نستخدم الأصل (أفضل من تعطيل الميزة)
      final Uint8List bytes = compressed ?? await File(shot.path).readAsBytes();

      if (bytes.lengthInBytes > _maxBytes) {
        throw const ImageException(
          "📷 الصورة كبيرة جداً حتى بعد الضغط. صوّر جزءاً أصغر من الصفحة.",
        );
      }

      // حفظ نسخة دائمة في مجلد التطبيق (منتقي الصور يحفظ في مجلد مؤقت يُمسح)
      final dir = await getApplicationDocumentsDirectory();
      final imagesDir = Directory("${dir.path}/chat_images");
      if (!await imagesDir.exists()) await imagesDir.create(recursive: true);

      final file = File("${imagesDir.path}/${const Uuid().v4()}.jpg");
      await file.writeAsBytes(bytes, flush: true);

      return PickedImage(
        path: file.path,
        base64Data: base64Encode(bytes),
        sizeBytes: bytes.lengthInBytes,
      );
    } on ImageException {
      rethrow;
    } catch (_) {
      throw const ImageException("📷 تعذّرت معالجة الصورة. حاول مرة أخرى.");
    }
  }

  /// يبني PickedImage من ملف موجود (بعد القص مثلاً).
  Future<PickedImage> fromPath(String path) async {
    final bytes = await File(path).readAsBytes();
    return PickedImage(
      path: path,
      base64Data: base64Encode(bytes),
      sizeBytes: bytes.lengthInBytes,
    );
  }

  /// يحفظ صورة مُعدَّلة (رسم مدموج) بعد ضغطها، ويرجع PickedImage جاهزاً للإرسال.
  Future<PickedImage> saveEdited(Uint8List pngBytes) async {
    // الناتج PNG من اللوحة — نضغطه JPEG لتقليل الحجم كثيراً
    Uint8List out;
    try {
      out = await FlutterImageCompress.compressWithList(
        pngBytes,
        minWidth: _maxDimension,
        minHeight: _maxDimension,
        quality: _quality,
        format: CompressFormat.jpeg,
      );
    } catch (_) {
      out = pngBytes;
    }
    if (out.lengthInBytes > _maxBytes) {
      throw const ImageException("📷 الصورة كبيرة جداً بعد التعديل.");
    }

    final dir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory("${dir.path}/chat_images");
    if (!await imagesDir.exists()) await imagesDir.create(recursive: true);
    final file = File("${imagesDir.path}/${const Uuid().v4()}.jpg");
    await file.writeAsBytes(out, flush: true);

    return PickedImage(
      path: file.path,
      base64Data: base64Encode(out),
      sizeBytes: out.lengthInBytes,
    );
  }

  /// يحذف صورة من التخزين المحلي (عند حذف المحادثة أو إلغاء الإرفاق).
  Future<void> delete(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {
      // الحذف أفضل جهد — فشله لا يعني شيئاً للطالب
    }
  }
}

class ImageException implements Exception {
  final String message;
  const ImageException(this.message);
  @override
  String toString() => message;
}
