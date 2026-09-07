import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/session/user_session.dart';
import '../../data/models/scholarship_chat.dart';
import '../controllers/scholarship_chat_controller.dart';

// ==========================================
// 📂 سجلّ محادثات المنحة (Drawer)
// ==========================================
// ⭐ **الميزة التي كانت غائبة تماماً من الديمو.** الشات بلا سجلّ يعني أن
//    الطالب يفقد كل ما سأل عنه في كل مرة يغلق فيه الشاشة.
//
// السجلّ **مقصور على هذه المنحة وعلى هذا الحساب**: زميلك على جوّالك لا يرى
// أسئلتك، ومحادثات المنحة التركية لا تختلط بالماليزية.
class ScholarshipChatDrawer extends StatelessWidget {
  final ScholarshipChatController controller;
  const ScholarshipChatDrawer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final list = controller.history;
    final current = controller.conversation?.id;

    return Container(
      width: MediaQuery.of(context).size.width * 0.84,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(left: BorderSide(color: AppColors.softSurface)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _header(),
            _newButton(context),
            const SizedBox(height: 8),
            Divider(height: 1, color: AppColors.softSurface),
            Expanded(
              child: list.isEmpty
                  ? _emptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (_, i) =>
                          _tile(context, list[i], list[i].id == current),
                    ),
            ),
            if (list.isNotEmpty) _clearAll(context, list.length),
            if (UserSession.I.isGuest) _guestNote(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    final s = controller.scholarship;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
                gradient: LinearGradient(colors: s.colors),
                borderRadius: BorderRadius.circular(14)),
            child: Center(child: Text(s.badge, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("محادثاتي",
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary)),
                Text(s.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _newButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          controller.newChat();
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
              gradient: AppColors.mainGradient,
              borderRadius: BorderRadius.circular(16)),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text("محادثة جديدة",
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined,
                size: 46, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 14),
            Text("لا محادثات بعد مع هذه المنحة.\nاسأل سؤالك الأول وسيُحفظ هنا.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.8,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, SchConversation c, bool active) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
      child: InkWell(
        onTap: () {
          controller.openConversation(c.id);
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: active
                ? AppColors.primary.withValues(alpha: 0.09)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: active
                    ? AppColors.primary.withValues(alpha: 0.3)
                    : Colors.transparent),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(c.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 5),
                    Text("${c.questionCount} سؤال · ${_ago(c.lastUpdated)}",
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary.withValues(alpha: 0.8))),
                  ],
                ),
              ),
              IconButton(
                tooltip: "حذف",
                icon: Icon(Icons.delete_outline_rounded,
                    size: 19, color: AppColors.textSecondary),
                onPressed: () => _confirmDelete(context, c),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, SchConversation c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surfaceWhite,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("حذف المحادثة؟",
            style: TextStyle(
                fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
        content: Text("«${c.title}» — لا يمكن التراجع.",
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("إلغاء")),
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text("حذف", style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true) await controller.deleteConversation(c.id);
  }

  Widget _clearAll(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: TextButton.icon(
        onPressed: () async {
          final ok = await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              backgroundColor: AppColors.surfaceWhite,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text("مسح كل المحادثات؟",
                  style: TextStyle(
                      fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              content: Text("ستُحذف $count محادثة مع هذه المنحة.",
                  style: TextStyle(color: AppColors.textSecondary)),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: const Text("إلغاء")),
                TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: const Text("مسح", style: TextStyle(color: Colors.redAccent))),
              ],
            ),
          );
          if (ok == true) {
            await controller.clearAll();
            if (context.mounted) Navigator.pop(context);
          }
        },
        icon: Icon(Icons.delete_sweep_rounded, size: 18, color: AppColors.textSecondary),
        label: Text("مسح كل المحادثات",
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
      ),
    );
  }

  /// ⚠️ صراحةٌ مع الزائر: محادثاته على الجهاز فقط ولا تُرفع — وحسابه مؤقت.
  Widget _guestNote() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: AppColors.secondary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14)),
      child: Text(
        "🧪 أنت تتصفح كزائر — محادثاتك محفوظة على هذا الجهاز فقط.\n"
        "سجّل حساباً مجانياً لتعود معك على أي جهاز.",
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 11.5,
            height: 1.7,
            fontWeight: FontWeight.w600,
            color: AppColors.secondary),
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return "الآن";
    if (d.inMinutes < 60) return "قبل ${d.inMinutes} د";
    if (d.inHours < 24) return "قبل ${d.inHours} س";
    if (d.inDays < 7) return "قبل ${d.inDays} يوم";
    return "${t.day}/${t.month}";
  }
}
