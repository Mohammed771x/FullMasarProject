// ==========================================
// 👤 core/media/avatar_service.dart — صورة الحساب
// ==========================================
// ⭐ **لماذا تُرفع للسحابة** بينما صور المحادثة تبقى على الجهاز؟
//    صور المحادثة سياقُ سؤالٍ عابر يُقرأ نصّه ويُرمى. أما صورة الحساب فهويّة
//    الطالب: يجب أن تتبعه إلى جهازٍ جديد وبعد إعادة التثبيت، وإلا فقدها.
//
// ✂️ القصّ **مربّع إجباري** (1:1): الصورة تُعرض في دائرة، والمستطيلة تُقصّ
//    عشوائياً فيخرج نصف وجهٍ — يُحسم القصّ بيد الطالب لا بيد التخطيط.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:http/http.dart' as http;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../network/api_client.dart';
import '../network/api_endpoints.dart';
import '../session/user_session.dart';
import '../theme/app_colors.dart';

class AvatarException implements Exception {
  const AvatarException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AvatarService {
  AvatarService._();
  static final AvatarService I = AvatarService._();

  /// 512 يكفي لدائرةٍ قطرها 60 بكسل منطقي على أعلى كثافة شاشة، ويبقى الملف
  /// تحت ~60 كيلوبايت — فلا ينتظر الطالب على شبكة بطيئة.
  static const int _side = 512;
  static const int _quality = 85;

  final ImagePicker _picker = ImagePicker();

  /// يلتقط صورة ويقصّها مربّعةً ويضغطها. `null` إن ألغى الطالب.
  Future<Uint8List?> pickAndCrop({
    required bool fromCamera,
    required BuildContext context,
  }) async {
    final XFile? shot = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (shot == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: shot.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 95,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: "قصّ الصورة",
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          title: "قصّ الصورة",
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          rotateButtonsHidden: true,
        ),
      ],
    );
    if (cropped == null) return null;

    final Uint8List? out = await FlutterImageCompress.compressWithFile(
      cropped.path,
      minWidth: _side,
      minHeight: _side,
      quality: _quality,
      format: CompressFormat.jpeg,
    );
    if (out == null || out.isEmpty) {
      throw const AvatarException("⚠️ تعذّر تجهيز الصورة. جرّب صورة أخرى.");
    }
    return out;
  }

  /// يرفع الصورة ويعيد رابطها. `bytes == null` ⇒ حذف الصورة الحالية.
  ///
  /// ⚠️ الترتيب مقصود: نرفع أولاً ثم نكتب الرابط في الحساب. العكس يترك
  ///    مستنداً يشير إلى ملفٍ لم يُرفع، فتظهر صورة مكسورة لا صورة قديمة.
  Future<String> upload(Uint8List? bytes) async {
    final token = await UserSession.I.idToken();
    final body = <String, dynamic>{
      "image_base64": bytes == null ? "" : base64Encode(bytes),
      // المسار القديم (كود التفعيل) — يتجاهلها الخادم مع التوكن.
      "user_id": UserSession.I.name,
      "code": "",
    };

    final http.Response res;
    try {
      res = await http
          .post(Uri.parse(ApiEndpoints.avatar()),
              headers: ApiClient.authHeaders(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 40));
    } on Exception {
      throw const AvatarException("📡 لا يوجد اتصال. تحقّق من الإنترنت.");
    }

    final Map<String, dynamic> data = res.body.isEmpty
        ? const {}
        : (jsonDecode(res.body) as Map).cast<String, dynamic>();
    if (res.statusCode != 200) {
      throw AvatarException(
          (data["error"] ?? data["answer"] ?? "⚠️ تعذّر رفع الصورة.").toString());
    }
    return (data["url"] ?? "").toString();
  }

  /// ينظّف ملفات القصّ المؤقتة — لا يُنتظر ولا يُبلَّغ عن فشله.
  Future<void> cleanTemp(String path) async {
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
