import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/curriculum.dart';
import '../../../../core/config/resources.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/models/chat_model.dart';
import '../controllers/chat_controller.dart';

// ==========================================
// 🪟 نوافذ شاشة المحادثة (موارد / مطور / إعادة تسمية / حذف)
// ==========================================
class ChatDialogs {
  ChatDialogs._();

  // ===== مركز الموارد =====
  // 📚 يتبع الصف والمسار: مواده = مواد الصف نفسها، وروابطه من
  //    `core/config/resources.dart`. مادة بلا روابط → شارة «قريباً».
  static void showResources(BuildContext context, {required int grade, required Track track}) {
    final t = Curriculum.normalizeTrack(grade, track);
    final subjects = Curriculum.subjectsFor(grade, t);
    final scopeLabel = Curriculum.hasTracks(grade)
        ? "${Curriculum.gradeLabel(grade)} · ${t.label}"
        : Curriculum.gradeLabel(grade);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.folder_special_rounded, color: AppColors.primary),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("مركز الموارد", style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                // 🏷️ شارة النطاق: يعرف الطالب أن هذه موارد صفه هو
                Text(scopeLabel,
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary)),
              ],
            ),
          ),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!Resources.hasAny(grade, t))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      "🚧 موارد $scopeLabel قيد التجهيز — المواد أدناه جاهزة وستُضاف روابطها قريباً.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, height: 1.6, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                    ),
                  ),
                ...subjects.map((s) => _resourceCard(context, s, Resources.forSubject(grade, t, s))),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إغلاق", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget _resourceCard(BuildContext context, String subject, List<ResourceLink> items) {
    final empty = items.isEmpty;
    // 🐛 Material لا Container: ListTile يرسم خلفيته وتموّجه على أقرب Material،
    //    فلو لوّنّا Container فوقه لأخفى التموّج — وFlutter يرمي تأكيداً بذلك.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.softSurface,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            enabled: !empty,
            title: Row(
              children: [
                Expanded(
                  child: Text(Resources.displayName(subject),
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: empty ? AppColors.textSecondary : AppColors.textPrimary)),
                ),
                if (empty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(8)),
                    child: Text("قريباً",
                        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                  ),
              ],
            ),
            trailing: empty ? const SizedBox.shrink() : null,
            children: items
                .map((item) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                      leading: Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
                      title: Text(item.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      trailing: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(10)),
                        child: Icon(Icons.download_rounded, color: AppColors.primary, size: 16),
                      ),
                      onTap: () async {
                        final uri = Uri.parse(item.url);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  // ===== نافذة الدعم والمطور =====
  static void showDeveloperInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(gradient: AppColors.mainGradient, shape: BoxShape.circle, boxShadow: AppColors.softShadow),
              child: Icon(Icons.code_rounded, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 20),
            Text("م. محمد الديني", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Text(
              "تم تطوير هذا الذكاء الاصطناعي بكل حب لخدمة الطلاب وتسهيل العملية التعليمية.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.6, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 28),
            _contactRow(
              icon: Icons.phone_rounded,
              title: "رقم الهاتف (واتساب / اتصال)",
              subtitle: "917736388574+",
              onTap: () => launchUrl(Uri.parse("https://wa.me/917736388574"), mode: LaunchMode.externalApplication),
            ),
            const SizedBox(height: 12),
            _contactRow(
              icon: Icons.camera_alt_rounded,
              title: "انستقرام",
              subtitle: "@mo_37ui",
              onTap: () => launchUrl(Uri.parse("https://www.instagram.com/mo_37ui?igsh=MTJxZHB1cTQ5bmEwdg%3D%3D&utm_source=qr"), mode: LaunchMode.externalApplication),
            ),
            const SizedBox(height: 12),
            _contactRow(
              icon: Icons.email_rounded,
              title: "البريد الإلكتروني",
              subtitle: "bfsak530156@gmail.com",
              onTap: () => launchUrl(Uri.parse("mailto:bsak530156@gmail.com")),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("إغلاق", style: TextStyle(color: AppColors.primary, fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  static Widget _contactRow({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(16)),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.surfaceWhite, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)]),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  // ===== إعادة تسمية المحادثة =====
  static void showRename(BuildContext context, ChatController controller, ChatConversation conversation) {
    final TextEditingController renameController = TextEditingController(text: conversation.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text("تعديل اسم المحادثة", style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: renameController,
          style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: "اسم جديد...",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            filled: true,
            fillColor: AppColors.softSurface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: TextStyle(color: AppColors.textSecondary))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            onPressed: () async {
              final newTitle = renameController.text.trim();
              if (newTitle.isNotEmpty) {
                await controller.renameConversation(conversation, newTitle);
                if (!ctx.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text("✅ تم تعديل الاسم"), backgroundColor: Colors.green.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), behavior: SnackBarBehavior.floating),
                );
              }
            },
            child: Text("حفظ", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ===== تأكيد الحذف =====
  static void showDeleteConfirmation(BuildContext context, ChatController controller, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            ),
            const SizedBox(width: 12),
            Text("حذف المحادثة", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          "هل أنت متأكد أنك تريد حذف هذه المحادثة نهائياً؟ لا يمكن التراجع عن هذا الإجراء.",
          style: TextStyle(color: AppColors.textPrimary, fontSize: 15, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            onPressed: () {
              Navigator.pop(ctx);
              controller.deleteConversation(id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("🗑️ تم حذف المحادثة بنجاح"), backgroundColor: Colors.redAccent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), behavior: SnackBarBehavior.floating),
              );
            },
            child: Text("حذف", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
