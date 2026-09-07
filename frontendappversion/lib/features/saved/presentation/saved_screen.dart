import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/session/user_session.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/masar_markdown.dart';
import '../data/saved_answer.dart';
import '../data/saved_storage.dart';

// ==========================================
// ⭐ شاشة المحفوظات
// ==========================================
// كل ما ضغط الطالب نجمته في التعليم أو مساعد المعلم أو المنح، في مكان واحد.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  String _filter = 'all';

  List<SavedAnswer> get _items {
    // 🎓 محفوظات هذا الصف وحده — من بدّل صفّه بدّل قائمته معه.
    final all = SavedStorage.all(UserSession.I.uid, scope: UserSession.I.scope);
    if (_filter == 'all') return all;
    return all.where((a) => a.section == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final total = SavedStorage.count(UserSession.I.uid, scope: UserSession.I.scope);

    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        title: const Text("المحفوظات",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          if (total > 0)
            IconButton(
              tooltip: "مسح الكل",
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _confirmClear,
            ),
        ],
      ),
      body: Column(
        children: [
          if (total > 0) _filters(),
          Expanded(
            child: items.isEmpty ? _empty(total) : _list(items),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    const tabs = {
      'all': 'الكل',
      'education': 'التعليم',
      'teacher': 'مساعد المعلم',
      'scholarship': 'المنح',
    };
    return SizedBox(
      height: 54,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        children: tabs.entries.map((e) {
          final on = _filter == e.key;
          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: ChoiceChip(
              label: Text(e.value),
              selected: on,
              onSelected: (_) => setState(() => _filter = e.key),
              labelStyle: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
                color: on ? Colors.white : AppColors.textSecondary,
              ),
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surfaceWhite,
              side: BorderSide(
                  color: AppColors.primary.withValues(alpha: on ? 0 : 0.15)),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _empty(int total) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_outline_rounded,
                  size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text(
                total == 0
                    ? "لا محفوظات بعد"
                    : "لا محفوظات في هذا القسم",
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                "اضغط ⭐ أسفل أي إجابة لتحفظها هنا،\nوتبقى معك حتى لو حذفت المحادثة.",
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13,
                    height: 1.7,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );

  Widget _list(List<SavedAnswer> items) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        itemCount: items.length,
        itemBuilder: (_, i) => _card(items[i]),
      );

  Widget _card(SavedAnswer a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.bubbleShadow,
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          title: Text(
            a.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                height: 1.5,
                color: AppColors.textPrimary),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              _tag(a.sectionLabel, AppColors.primary),
              if (a.subject.isNotEmpty) ...[
                const SizedBox(width: 6),
                _tag(a.subject, AppColors.secondary),
              ],
            ]),
          ),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: MasarMarkdown(data: a.text, selectable: true),
            ),
            const SizedBox(height: 10),
            Row(children: [
              _action(Icons.content_copy_rounded, "نسخ", () async {
                await Clipboard.setData(ClipboardData(text: a.text));
                if (mounted) _snack("📋 نُسخت");
              }),
              const SizedBox(width: 8),
              _action(Icons.star_rounded, "إزالة", () async {
                await SavedStorage.remove(a.id);
                if (mounted) setState(() {});
              }, danger: true),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.bold, color: color)),
      );

  Widget _action(IconData icon, String label, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? Colors.redAccent : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: danger
              ? Colors.redAccent.withValues(alpha: 0.08)
              : AppColors.softSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.bold, color: color)),
        ]),
      ),
    );
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("مسح كل المحفوظات؟",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        content: const Text("لا يمكن التراجع عن هذا.",
            style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("إلغاء")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("مسح",
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // ⚠️ **الصف الحالي وحده**: الطالب يرى قائمة صفّه ويضغط «مسح الكل»، فمسحُ
    //    صفوفٍ أخرى لا يراها حذفٌ لم يطلبه ولا يستطيع التراجع عنه.
    final n = await SavedStorage.clear(UserSession.I.uid, scope: UserSession.I.scope);
    if (!mounted) return;
    setState(() {});
    _snack("🗑️ مُسحت $n محفوظة");
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.textPrimary,
    ));
}
