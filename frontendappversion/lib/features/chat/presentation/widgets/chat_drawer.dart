import 'package:flutter/material.dart';

import '../../../../core/config/curriculum.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/masar_brand.dart';
import '../../../../core/session/user_session.dart';
import '../../../../core/storage/chat_storage.dart';
import '../../data/conversation_search.dart';
import '../../data/models/chat_model.dart';
import '../controllers/chat_controller.dart';
import '../../../teacher/data/teacher_tool.dart';
import 'chat_dialogs.dart';

// ==========================================
// 📂 القائمة الجانبية (Drawer)
// ==========================================
// الترتيب: الشعار → محادثة جديدة → الصف → المسار → المواد → المحادثات.
// 🔻 نُقل إلى الإعدادات: "المطور" و"الوضع الداكن".
// 🔻 حُذف: "تحديث الكود" (لم يعد هناك نظام أكواد).
class ChatDrawer extends StatefulWidget {
  final ChatController controller;

  const ChatDrawer({super.key, required this.controller});

  @override
  State<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  // 🔎 نصّ البحث الحالي — فارغٌ يعني «اعرض محادثات هذا القسم كالمعتاد».
  final TextEditingController _search = TextEditingController();
  String _query = "";

  ChatController get controller => widget.controller;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// 🌍 **البحث يتخطّى نطاق الشاشة عمداً.**
  ///
  /// القائمة العادية تعرض محادثات (الصف · المادة · الوضع) الحالي وحدها —
  /// وهذا صحيحٌ للتصفّح. لكن الطالب الباحث عن «الأكسدة» **لا يتذكّر في أي
  /// مادةٍ سألها**، وحصرُ البحث في القسم المفتوح كان سيُرجع «لا نتائج» عن
  /// محادثةٍ موجودةٍ عنده فعلاً. فالبحث على كل محادثات الحساب.
  List<ChatConversation> get _visibleConversations {
    if (_query.trim().isEmpty) return controller.conversations;
    final all = ChatStorage.getAllConversations(UserSession.I.uid);
    return ConversationSearch.filter(all, _query);
  }

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

            // ══════════════════════════════════════════════════
            // 🔎 البحث **ثابتٌ في الأعلى** لا داخل القائمة
            // ══════════════════════════════════════════════════
            // 🔴 **علّة رآها المالك:** كان أسفل القائمة، فيلزم تمريرٌ طويل
            //    للوصول إليه — ثم يفتح الكيبورد **فيغطّيه هو ونتائجه**،
            //    فيكتب الطالب في حقلٍ لا يراه ويقرأ نتائج لا تظهر.
            //
            // ✅ خارج `ListView` فلا يتحرّك، وفوق النتائج فيراهما معاً،
            //    والكيبورد يقضم من أسفل القائمة لا من الحقل.
            _searchField(),

            // القوائم القابلة للتمرير
            Expanded(
              child: ListView(
                padding: EdgeInsets.only(
                  // ⌨️ ارتفاع الكيبورد يُضاف كحشوة سفلية: بدونه تبقى آخر
                  //    نتيجتين خلفه ولا سبيل للوصول إليهما.
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                children: [
                  // ══════════════════════════════════════════════════
                  // 🎓 لا مُبدِّل صفٍّ ولا مسارٍ هنا (قرار المالك 2026-09-09)
                  // ══════════════════════════════════════════════════
                  // طالبُ الأول الثانوي لا يعنيه «الثاني» و«الثالث»، ولا
                  // «علمي/أدبي». والصفُّ يُختار مرةً في **الإعدادات** ويرافق
                  // الحساب، فتكرارُه هنا زحمةٌ في قائمةٍ تُفتح عشرات المرات
                  // يومياً — ويُغري بتبديلٍ عرَضيّ يقلب المحتوى كلَّه.
                  //
                  // 📚 وتُعرض **مواد صفّه وحدها** — وهي معروضة أصلاً، لأن
                  //    `_subjectList` تشتقّها من `c.grade` و`c.track`.
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

  // ──────────────────────── 🔎 البحث ────────────────────────
  Widget _searchField() {
    final searching = _query.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: TextField(
        controller: _search,
        onChanged: (v) => setState(() => _query = v),
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 13, color: AppColors.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: "ابحث في كل محادثاتك…",
          hintStyle: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
          prefixIcon: Icon(Icons.search_rounded, size: 18, color: AppColors.textSecondary),
          suffixIcon: searching
              ? IconButton(
                  icon: Icon(Icons.close_rounded, size: 17, color: AppColors.textSecondary),
                  splashRadius: 18,
                  onPressed: () {
                    _search.clear();
                    setState(() => _query = "");
                  },
                )
              : null,
          filled: true,
          fillColor: AppColors.softSurface,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _conversationsList(BuildContext context) {
    final searching = _query.trim().isNotEmpty;
    final convs = _visibleConversations;
    if (convs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        child: Column(
          children: [
            Icon(searching ? Icons.search_off_rounded : Icons.forum_outlined,
                size: 30, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            // ⚠️ رسالتان لا واحدة: «لا محادثات بعد» على نتيجةِ بحثٍ فارغة
            //    تُوهم الطالب أن محادثاته ضاعت — وهي موجودة ولا تطابق فقط.
            Text(
                searching
                    ? "لا توجد محادثة تطابق «${_query.trim()}»."
                    : "لا توجد محادثات في هذا القسم بعد.",
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
            // 🔎 نتيجةُ بحثٍ قد تكون من مادةٍ أو صفٍّ آخر ⇒ يُنقَل النطاق
            //    معها. أما التصفّح العادي فداخل النطاق أصلاً.
            if (searching) {
              controller.openFromSearch(conv);
            } else {
              controller.loadConversation(conv);
            }
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        conv.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                            color: isActive ? AppColors.primary : AppColors.textPrimary),
                      ),
                      // 📄 أثناء البحث: أين وُجدت الكلمة + من أي مادة —
                      //    فالنتائج تأتي من كل الأقسام وعناوينها متشابهة.
                      if (searching) ...[
                        const SizedBox(height: 3),
                        Text(
                          _resultSubtitle(conv),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5,
                              height: 1.35,
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ],
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

  /// سطر النتيجة: المادة ثم مقتطف الكلمة إن وُجدت في متن المحادثة.
  String _resultSubtitle(ChatConversation conv) {
    final snippet = ConversationSearch.snippet(conv, _query);
    final where = "${conv.subject} · ${Curriculum.gradeShort(conv.grade)}";
    return snippet.isEmpty ? where : "$where — $snippet";
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
