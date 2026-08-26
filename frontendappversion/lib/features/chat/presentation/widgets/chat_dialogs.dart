import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/models/chat_model.dart';
import '../controllers/chat_controller.dart';

// ==========================================
// 🪟 نوافذ شاشة المحادثة (موارد / مطور / إعادة تسمية / حذف)
// ==========================================
class ChatDialogs {
  ChatDialogs._();

  // ===== مركز الموارد =====
  static void showResources(BuildContext context) {
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
          Text("مركز الموارد", style: TextStyle(fontWeight: FontWeight.w800)),
        ]),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _resourceCard(context, "📐 الرياضيات", [
                  {"name": "ملخص التفاضل", "url": "https://drive.google.com/drive/folders/1hIojvkK09LT7IcqaK5aGoEV_vrrVZjLs"},
                  {"name": "ملخص الجبر", "url": "https://drive.google.com/drive/folders/1m8QVLyM6tbG5buQNDdGwNCRbV_28bsxA"},
                  {"name": "ملخص التكامل", "url": "https://drive.google.com/drive/u/1/folders/1ao83kRRVKk40VOAsgnLcjDeOodIyHNri"},
                  {"name": "ملخص الهندسة", "url": "https://drive.google.com/drive/u/1/folders/1TWxdgszrwzxCQW2uRSXkv7VZrIKIGvGV"},
                  {"name": "ملخص الاحتمالات", "url": "https://drive.google.com/drive/u/1/folders/1Sx-ZJqwjORzFwQR5EDVrVd32mkjkI_lh"},
                  {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"},
                ]),
                _resourceCard(context, "🧬 الأحياء", [
                  {"name": "ملخصات الأحياء", "url": "https://drive.google.com/drive/u/1/folders/1LLzIsWFKiZOkrr6DUaagm9RVmBdKKDQn"},
                  {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"},
                ]),
                _resourceCard(context, "⚛️ الكيمياء", [
                  {"name": "ملخصات الكيمياء", "url": "https://drive.google.com/drive/u/1/folders/1_9YpbhSvG4-qcVihLU10o8muFFPh0Gqt"},
                  {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"},
                ]),
                _resourceCard(context, "🔬 الفيزياء", [
                  {"name": "ملخص الفيزياء", "url": "https://drive.google.com/drive/folders/1ATQPwJNXYf-yidgXjhkW7E7AaqYev2vc"},
                  {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"},
                ]),
                _resourceCard(context, "📜 اللغة العربية", [
                  {"name": "ملخص النحو", "url": "https://drive.google.com/drive/u/1/folders/13Ec4BtxzxvJTOrR9_BriUGfr1HszU3M1"},
                  {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"},
                ]),
                _resourceCard(context, "🔤 اللغة الإنجليزية", [
                  {"name": "ملخصات الانجليزي", "url": "https://drive.google.com/drive/u/1/folders/1hEE0h4iBkgNRDsoy9OOVfL1eNFzYeiHU"},
                  {"name": "الأسئلة الوزارية", "url": "https://drive.google.com/drive/u/1/folders/1xaM6g_dtYTsKvomLK7uQcBbhKwaS0a6b"},
                ]),
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

  static Widget _resourceCard(BuildContext context, String title, List<Map<String, String>> items) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(20)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          children: items
              .map((item) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    leading: Icon(Icons.picture_as_pdf_rounded, color: Colors.redAccent, size: 20),
                    title: Text(item['name']!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                    trailing: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.download_rounded, color: AppColors.primary, size: 16),
                    ),
                    onTap: () async {
                      if (await canLaunchUrl(Uri.parse(item['url']!))) {
                        await launchUrl(Uri.parse(item['url']!), mode: LaunchMode.externalApplication);
                      }
                    },
                  ))
              .toList(),
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
