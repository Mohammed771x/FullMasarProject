// ==========================================
// 👤 core/widgets/user_avatar.dart — صورة الحساب في كل مكان
// ==========================================
// ويدجت واحد يُستعمل في الترويسة والإعدادات، فلا تتفرّق أشكال الصورة.
// يستمع لـ`UserSession` فيتحدّث فوراً بعد الرفع بلا `setState` في كل شاشة.
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../media/avatar_service.dart';
import '../session/user_session.dart';
import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.radius = 26,
    this.editable = false,
    this.onChanged,
  });

  final double radius;

  /// يُظهر قلم التحرير ويفتح ورقة الاختيار عند النقر.
  final bool editable;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: UserSession.I,
      builder: (context, _) {
        final s = UserSession.I;
        final circle = Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            gradient: AppColors.mainGradient,
            shape: BoxShape.circle,
            boxShadow: AppColors.softShadow,
          ),
          child: CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.surfaceWhite,
            child: ClipOval(child: _inner(s)),
          ),
        );

        if (!editable) return circle;
        return GestureDetector(
          onTap: () => AvatarSheet.show(context, onChanged: onChanged),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              circle,
              Positioned(
                bottom: -1,
                left: -1,
                child: Container(
                  padding: EdgeInsets.all(radius * 0.13),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.surfaceWhite, width: 2),
                  ),
                  child: Icon(Icons.camera_alt_rounded,
                      size: radius * 0.42, color: Colors.white),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _inner(UserSession s) {
    if (s.photoUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: s.photoUrl,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        // ⚠️ لا مؤشّر تحميل دوّار: الصورة مكيَّشة، والدوران في كل بناء
        //    يجعل الترويسة ترتجف. الحرف الأول جسرٌ هادئ حتى تصل.
        placeholder: (_, _) => _fallback(s),
        errorWidget: (_, _, _) => _fallback(s),
      );
    }
    return _fallback(s);
  }

  Widget _fallback(UserSession s) => SizedBox(
        width: radius * 2,
        height: radius * 2,
        child: Center(
          child: s.isGuest
              ? Icon(Icons.person_outline_rounded,
                  size: radius * 1.08, color: AppColors.primary)
              : Text(
                  s.initial,
                  style: TextStyle(
                    fontSize: radius * 0.85,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
        ),
      );
}

// ══════════════════════════════════════════
// 📷 ورقة اختيار الصورة
// ══════════════════════════════════════════
class AvatarSheet {
  /// يفتح الخيارات ويتولّى الرفع كاملاً — الشاشة المستدعية لا تعرف شيئاً
  /// عن base64 ولا عن الشبكة.
  static Future<void> show(BuildContext context, {VoidCallback? onChanged}) async {
    final s = UserSession.I;
    if (s.isGuest) {
      _snack(context, "👤 أنشئ حساباً أولاً لتضع صورتك.");
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            _tile(ctx, Icons.photo_library_rounded, "اختر من المعرض", "gallery"),
            _tile(ctx, Icons.photo_camera_rounded, "التقط صورة", "camera"),
            if (s.photoUrl.isNotEmpty)
              _tile(ctx, Icons.delete_outline_rounded, "احذف الصورة", "delete",
                  danger: true),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;

    await _apply(context, choice, onChanged);
  }

  static Future<void> _apply(
      BuildContext context, String choice, VoidCallback? onChanged) async {
    try {
      if (choice == "delete") {
        await AvatarService.I.upload(null);
        await UserSession.I.setPhoto("");
        if (context.mounted) _snack(context, "🗑️ حُذفت الصورة");
        onChanged?.call();
        return;
      }

      final bytes = await AvatarService.I
          .pickAndCrop(fromCamera: choice == "camera", context: context);
      if (bytes == null) return; // ألغى الطالب — ليس خطأً

      if (context.mounted) _snack(context, "⏳ جارٍ رفع الصورة…");
      final url = await AvatarService.I.upload(bytes);
      await UserSession.I.setPhoto(url);
      if (context.mounted) _snack(context, "✅ تم تحديث صورتك");
      onChanged?.call();
    } on AvatarException catch (e) {
      if (context.mounted) _snack(context, e.message);
    } catch (_) {
      if (context.mounted) _snack(context, "⚠️ تعذّر تحديث الصورة. حاول ثانيةً.");
    }
  }

  static Widget _tile(BuildContext ctx, IconData icon, String label, String value,
      {bool danger = false}) {
    final color = danger ? Colors.redAccent : AppColors.textPrimary;
    return ListTile(
      leading: Icon(icon, color: danger ? Colors.redAccent : AppColors.primary),
      title: Text(label,
          style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      onTap: () => Navigator.pop(ctx, value),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }

  static void _snack(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
      ));
  }
}
