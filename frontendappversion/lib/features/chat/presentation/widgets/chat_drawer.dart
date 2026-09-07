import 'package:flutter/material.dart';

import '../../../../core/config/curriculum.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../controllers/chat_controller.dart';
import '../../../teacher/data/teacher_tool.dart';
import 'chat_dialogs.dart';

// ==========================================
// 📂 القائمة الجانبية (Drawer)
// ==========================================
// الترتيب: الشعار → محادثة جديدة → الصف → المسار → المواد → المحادثات.
// 🔻 نُقل إلى الإعدادات: "المطور" و"الوضع الداكن".
// 🔻 حُذف: "تحديث الكود" (لم يعد هناك نظام أكواد).
class ChatDrawer extends StatelessWidget {
  final ChatController controller;

  const ChatDrawer({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Container(
      width: MediaQuery.of(context).size.width * 0.86,
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        border: Border(left: BorderSide(color: AppColors.softSurface)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            _header(),
            _newChatButton(context),
            const SizedBox(height: 10),
            // 📚 الموارد (ملخصات وأسئلة وزارية على Drive)
            _drawerItem(context, Icons.library_books_rounded, "الموارد", () {
              Navigator.pop(context);
              ChatDialogs.showResources(context, grade: c.grade, track: c.track);
            }),
            const SizedBox(height: 6),

            // القوائم القابلة للتمرير
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _sectionLabel("الصف الدراسي"),
                  _gradeSelector(context),

                  if (Curriculum.hasTracks(c.grade)) ...[
                    const SizedBox(height: 12),
                    _sectionLabel("المسار"),
                    _trackSelector(context),
                  ],

                  const SizedBox(height: 12),
                  _divider(),
                  _sectionLabel("المواد الدراسية"),
                  _subjectList(context),

                  _divider(),
                  _conversationsHeader(),
                  _conversationsList(context),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── الشعار ─────────────────────────
  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Row(
        children: [
          const MasarLogo(size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("مسار",
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.w900)),
                Text("سفير الطالب اليمني 🇾🇪",
                    style: TextStyle(color: AppColors.primary, fontSize: 10.5, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────── زر محادثة جديدة ────────────────────
  Widget _newChatButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: InkWell(
        onTap: () {
          controller.createNewConversation();
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            gradient: AppColors.mainGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 19),
              SizedBox(width: 8),
              Text("محادثة جديدة", style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────── الصف ────────────────────────
  Widget _gradeSelector(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: List.generate(3, (i) {
          final g = i + 1;
          final sel = g == controller.grade;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i < 2 ? 7 : 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                // ★ لا نغلق القائمة: الطالب يختار الصف ثم المسار ثم المادة
                //   على التوالي، والعودة للمحادثة تحدث عند اختيار المادة فقط.
                onTap: () => controller.setGrade(g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.softSurface,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(Curriculum.gradeShort(g),
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: sel ? Colors.white : AppColors.textSecondary)),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ──────────────────────── المسار ────────────────────────
  Widget _trackSelector(BuildContext context) {
    final tracks = Curriculum.tracksFor(controller.grade);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: List.generate(tracks.length, (i) {
          final t = tracks[i];
          final sel = t == controller.track;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i < tracks.length - 1 ? 7 : 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(13),
                // ★ يبقى داخل القائمة أيضاً — راجع تعليق شرائح الصف.
                onTap: () => controller.setTrack(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.secondary.withValues(alpha: 0.14) : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                        color: sel ? AppColors.secondary.withValues(alpha: 0.5) : AppColors.softSurface, width: 1.4),
                  ),
                  child: Center(
                    child: Text(t.label,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: sel ? AppColors.secondary : AppColors.textSecondary)),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ──────────────────────── المواد ────────────────────────
  Widget _subjectList(BuildContext context) {
    final c = controller;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: c.subjects.map((s) {
          final sel = c.selectedSubject == s;
          final available = Curriculum.isAvailable(c.grade, c.track, s);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                if (!available) {
                  _snack(context, "🚧 محتوى «$s» لهذا الصف قيد الإضافة");
                  return;
                }
                await c.setSubject(s);
                // ★ اختيار المادة = نهاية الاختيار → نعود للمحادثة.
                if (context.mounted) Navigator.pop(context);
              },
              child: Opacity(
                opacity: available ? 1 : 0.45,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary.withValues(alpha: 0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(available ? Icons.book_rounded : Icons.lock_outline_rounded,
                          size: 18, color: sel ? AppColors.primary : AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(s,
                            style: TextStyle(
                                fontSize: 13,
                                color: sel ? AppColors.primary : AppColors.textPrimary,
                                fontWeight: sel ? FontWeight.bold : FontWeight.w600)),
                      ),
                      if (!available)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.softSurface, borderRadius: BorderRadius.circular(8)),
                          child: Text("قريباً",
                              style: TextStyle(
                                  fontSize: 9, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ──────────────────────── المحادثات ────────────────────────
  Widget _conversationsHeader() {
    final c = controller;
    // 👨‍🏫 في قسم المعلم `selectedMode` معرّفٌ داخلي («معلم:plan») يدخل في
    //    مفتاح النطاق — فلا يُعرض للمعلّم كما هو، بل باسم الأداة.
    final mode = c.isTeacher
        ? c.teacherTool!.label
        : (c.selectedSubject == "رياضيات" ? c.mathMode : c.selectedMode);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text("المحادثات",
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
          ),
          const SizedBox(height: 6),
          // 🏷️ شارة النطاق: توضّح للطالب أن هذه محادثات هذا السياق تحديداً
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10)),
              child: Text(
                "${c.selectedSubject} · $mode · ${Curriculum.gradeShort(c.grade)}"
                "${Curriculum.hasTracks(c.grade) ? ' ${c.track.label}' : ''}",
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _conversationsList(BuildContext context) {
    final convs = controller.conversations;
    if (convs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        child: Column(
          children: [
            Icon(Icons.forum_outlined, size: 30, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text("لا توجد محادثات في هذا القسم بعد.",
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: convs.length,
      itemBuilder: (context, index) {
        final conv = convs[index];
        final isActive = conv.id == controller.currentConversationId;
        return InkWell(
          onTap: () {
            controller.loadConversation(conv);
            Navigator.pop(context);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            color: isActive ? AppColors.softSurface : Colors.transparent,
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline_rounded,
                    size: 17, color: isActive ? AppColors.primary : AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    conv.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                        color: isActive ? AppColors.primary : AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.edit_rounded, size: 17, color: AppColors.secondary),
                  onPressed: () => ChatDialogs.showRename(context, controller, conv),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
                const SizedBox(width: 10),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 17, color: Colors.redAccent),
                  onPressed: () => ChatDialogs.showDeleteConfirmation(context, controller, conv.id),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ──────────────────────── مساعدات ────────────────────────
  Widget _drawerItem(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: AppColors.softSurface, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: AppColors.textPrimary, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary, fontSize: 13)),
            ),
            Icon(Icons.chevron_left_rounded, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _divider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Divider(height: 1, color: AppColors.softSurface),
      );

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(t,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
        ),
      );

  void _snack(BuildContext context, String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
}
