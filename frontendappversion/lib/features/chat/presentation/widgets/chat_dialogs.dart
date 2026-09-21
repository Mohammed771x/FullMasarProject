import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/curriculum.dart';
import '../../../../core/config/resources.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_dialog.dart';
import '../../../../core/widgets/phosphor.dart';
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
  // ══════════════════════════════════════════════════
  // 📁 مركز الموارد — بلغة التصميم الجديد
  // ══════════════════════════════════════════════════
  // 🎨 كان `AlertDialog` من عهدٍ سابق: r28 · أيقونات Material · بطاقاتٌ
  //    رمادية r20 · و`ExpansionTile` بسهمٍ افتراضيّ. صار على [MasarDialog]:
  //    صفوفٌ 46 بحدٍّ خفيف تُفتح فتصير زرقاءَ خفيفةً بحدٍّ أزرق — كصفوف
  //    المواد في القائمة الجانبية حرفياً.
  static void showResources(BuildContext context,
      {required int grade, required Track track}) {
    final t = Curriculum.normalizeTrack(grade, track);
    final subjects = Curriculum.subjectsFor(grade, t);
    final scopeLabel = Curriculum.hasTracks(grade)
        ? "${Curriculum.gradeLabel(grade)} · ${t.label}"
        : Curriculum.gradeLabel(grade);

    showDialog(
      context: context,
      builder: (ctx) => ThemeScope(
        builder: (ctx) => MasarDialog(
          icon: PD.folderOpen,
          title: "مركز الموارد",
          // 🏷️ شارةُ النطاق: يعرف الطالب أن هذه مواردُ صفّه هو.
          subtitle: scopeLabel,
          primaryLabel: "إغلاق",
          fullWidthAction: true,
          closable: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!Resources.hasAny(grade, t))
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.warningTintSurface,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: AppColors.warningTintBorder),
                    ),
                    child: Text(
                      "🚧 موارد $scopeLabel قيد التجهيز — المواد أدناه جاهزة "
                      "وستُضاف روابطها قريباً.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11.5,
                          height: 1.7,
                          fontWeight: FontWeight.w800,
                          color: AppColors.warning900),
                    ),
                  ),
                ),
              for (final sbj in subjects) ...[
                _ResourceRow(
                    subject: sbj,
                    items: Resources.forSubject(grade, t, sbj)),
                const SizedBox(height: 8),
              ],
            ],
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
              child: Icon(PI.code.bold, color: Colors.white, size: 40),
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
              icon: PI.phone.regular,
              title: "رقم الهاتف (واتساب / اتصال)",
              subtitle: "917736388574+",
              onTap: () => launchUrl(Uri.parse("https://wa.me/917736388574"), mode: LaunchMode.externalApplication),
            ),
            const SizedBox(height: 12),
            _contactRow(
              icon: PI.camera.regular,
              title: "انستقرام",
              subtitle: "@mo_37ui",
              onTap: () => launchUrl(Uri.parse("https://www.instagram.com/mo_37ui?igsh=MTJxZHB1cTQ5bmEwdg%3D%3D&utm_source=qr"), mode: LaunchMode.externalApplication),
            ),
            const SizedBox(height: 12),
            _contactRow(
              icon: PI.envelope.regular,
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
            Icon(PI.caretLeft.regular, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  // ===== إعادة تسمية المحادثة =====
  // ══════════════════════════════════════════════════
  // ✏️ تعديل اسم المحادثة — تصميم `design/03-home/19`
  // ══════════════════════════════════════════════════
  // 🎨 مربّعُ قلمٍ أزرقُ فاتحٌ 48 r14 · عنوانٌ 17/w900 · حقلٌ **رماديٌّ بلا
  //    حدّ** r14 بارتفاع 52 · وزرُّ «حفظ» أزرقُ ممتلئ و«إلغاء» نصّاً.
  //
  // 📏 **سطرٌ واحدٌ لا يكبر مع الكتابة** (ملاحظة المالك): كان الحقل بلا
  //    `maxLines` فاسمُ المحادثة الطويل يلتفّ سطراً بعد سطرٍ ويطول
  //    الحوارُ تحت الإصبع وهو يكتب.
  static void showRename(BuildContext context, ChatController controller,
      ChatConversation conversation) {
    final TextEditingController renameController =
        TextEditingController(text: conversation.title);
    showDialog(
      context: context,
      builder: (ctx) => ThemeScope(
        builder: (ctx) => MasarDialog(
          icon: PD.pencilSimple,
          title: "تعديل أسم المحادثة",
          primaryLabel: "حفظ",
          cancelLabel: "إلغاء",
          onPrimary: () async {
            final newTitle = renameController.text.trim();
            if (newTitle.isEmpty) return;
            await controller.renameConversation(conversation, newTitle);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("✅ تم تعديل الاسم",
                    style: TextStyle(fontWeight: FontWeight.w900)),
                backgroundColor: AppColors.success700,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: SizedBox(
            height: 52,
            child: TextField(
              controller: renameController,
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: "اسم جديد…",
                hintStyle: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.dropdownCaret),
                filled: true,
                fillColor: AppColors.fieldFill,
                // ⚠️ الأربعةُ صراحةً: سمةُ التطبيق ترسم `enabledBorder`
                //    فيظهر إطارٌ لا وجودَ له في التصميم.
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: AppColors.primary, width: 1.4)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════
  // 🗑️ حذف المحادثة — تصميم `design/03-home/18`
  // ══════════════════════════════════════════════════
  // 🎨 مربّعُ تحذيرٍ أحمرُ فاتحٌ 48 r14 في بداية الرأس · عنوانٌ 17/w900 ·
  //    نصٌّ كحليٌّ سطران · وزرُّ «حذف» **أحمرُ ممتلئ** في نهاية السطر
  //    و«إلغاء» نصّاً إلى يمينه.
  static void showDeleteConfirmation(
      BuildContext context, ChatController controller, String id) {
    showDialog(
      context: context,
      builder: (ctx) => ThemeScope(
        builder: (ctx) => MasarDialog(
          icon: PD.warning,
          iconTint: AppColors.errorTint,
          iconInk: AppColors.error500,
          title: "حذف المحادثة",
          primaryLabel: "حذف",
          primaryColor: AppColors.error500,
          cancelLabel: "إلغاء",
          onPrimary: () async {
            controller.deleteConversation(id);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text("🗑️ تم حذف المحادثة بنجاح",
                    style: TextStyle(fontWeight: FontWeight.w900)),
                backgroundColor: AppColors.error600,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Text(
            "هل أنت متأكد أنك تريد حذف هذه المحادثة نهائياً؟ "
            "لا يمكن التراجع عن هذا الإجراء.",
            style: TextStyle(
                fontSize: 13.5,
                height: 1.9,
                fontWeight: FontWeight.w800,
                color: AppColors.panelTitle),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════
// 📚 صفُّ مادةٍ في مركز الموارد — يُفتح فيُظهر ملفّاتها
// ══════════════════════════════════════════════════
// 🔄 **يُفتح بدل `ExpansionTile`**: ذاك يرسم سهمَه وحشوتَه وخطوطَه بمقاسات
//    Material، فلا يطابق صفوفَ القائمة الجانبية. وهذا صفٌّ 46 بحدٍّ خفيف
//    كسائر صفوف التطبيق، يصير عند الفتح أزرقَ خفيفاً بحدٍّ أزرق — وهي
//    الحالةُ المختارة نفسُها في قائمة المواد.
class _ResourceRow extends StatefulWidget {
  const _ResourceRow({required this.subject, required this.items});

  final String subject;
  final List<ResourceLink> items;

  @override
  State<_ResourceRow> createState() => _ResourceRowState();
}

class _ResourceRowState extends State<_ResourceRow> {
  bool _open = false;

  bool get _empty => widget.items.isEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MasarDialogRow(
          highlighted: _open,
          // ⛔ المادةُ بلا ملفّاتٍ لا تُفتح — وتقول «قريباً» بدل أن تُفتح
          //    على فراغ.
          onTap: _empty ? null : () => setState(() => _open = !_open),
          child: Row(
            children: [
              PDuo(PD.filePdf,
                  size: 20,
                  color: _empty ? AppColors.cardHint : AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(Resources.displayName(widget.subject),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: _empty
                            ? AppColors.cardHint
                            : AppColors.textPrimary)),
              ),
              if (_empty)
                Text("قريباً",
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        color: AppColors.warning900))
              else ...[
                Text("${widget.items.length}",
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary)),
                const SizedBox(width: 6),
                AnimatedRotation(
                  turns: _open ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(PI.caretDown.regular,
                      size: 15, color: AppColors.dropdownCaret),
                ),
              ],
            ],
          ),
        ),
        // 📂 الملفّات — تنزلق بحركةٍ يتابعها الطالب لا تظهر فجأةً.
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !_open
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: 8, right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final item in widget.items) ...[
                        MasarDialogRow(
                          height: 44,
                          onTap: () => _open_(item),
                          child: Row(
                            children: [
                              Icon(PI.filePdf.regular,
                                  size: 18, color: AppColors.error500),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(item.name,
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.textPrimary)),
                              ),
                              Icon(PI.downloadSimple.bold,
                                  size: 16, color: AppColors.primary),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _open_(ResourceLink item) async {
    final uri = Uri.parse(item.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
