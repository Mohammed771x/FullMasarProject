import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../data/demo_state.dart';
import '../widgets/demo_widgets.dart';
import 'auth_screen.dart';

// ==========================================
// ⚙️ الإعدادات
// ==========================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final s = DemoState.I;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: Stack(
        children: [
          const GlowBackgroundStatic(),
          Column(
            children: [
              const GlassBar(title: "الإعدادات ⚙️"),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
                  children: [
                    // الملف الشخصي
                    SoftCard(
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(3), decoration: BoxDecoration(gradient: AppColors.mainGradient, shape: BoxShape.circle), child: CircleAvatar(radius: 28, backgroundColor: AppColors.surfaceWhite, child: Icon(Icons.person_rounded, size: 32, color: AppColors.primary))),
                        const SizedBox(width: 14),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                          const SizedBox(height: 2),
                          Text(s.email, style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                        ])),
                        IconButton(onPressed: () => _snack("تعديل الصورة (محاكاة)"), icon: Icon(Icons.camera_alt_rounded, color: AppColors.primary)),
                      ]),
                    ),
                    const SizedBox(height: 8),
                    _sectionTitle("الصف الدراسي"),
                    Row(children: List.generate(3, (i) {
                      final g = i + 1;
                      final sel = s.grade == g;
                      return Expanded(child: Padding(
                        padding: EdgeInsets.only(left: i < 2 ? 8 : 0),
                        child: InkWell(
                          onTap: () => setState(() => s.setGrade(g)),
                          borderRadius: BorderRadius.circular(14),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(color: sel ? AppColors.primary : AppColors.surfaceWhite, borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? Colors.transparent : AppColors.textSecondary.withValues(alpha: 0.1))),
                            child: Center(child: Text(switch (g) { 1 => "أول", 2 => "ثاني", _ => "ثالث" }, style: TextStyle(fontWeight: FontWeight.bold, color: sel ? Colors.white : AppColors.textSecondary))),
                          ),
                        ),
                      ));
                    })),

                    _sectionTitle("المظهر"),
                    ValueListenableBuilder<bool>(
                      valueListenable: isDarkModeNotifier,
                      builder: (context, isDark, _) => _switchTile(isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded, "الوضع الداكن", isDark, (v) => setState(() => isDarkModeNotifier.value = v)),
                    ),
                    SoftCard(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [Icon(Icons.format_size_rounded, color: AppColors.primary, size: 20), const SizedBox(width: 12), Text("حجم خط الإجابات", style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)), const Spacer(), Text("${s.answerFontSize.round()}", style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary))]),
                        Slider(min: 14, max: 20, divisions: 6, value: s.answerFontSize, activeColor: AppColors.primary, inactiveColor: AppColors.softSurface, onChanged: (v) => setState(() => s.answerFontSize = v)),
                      ]),
                    ),

                    _sectionTitle("الصوت والإشعارات"),
                    _switchTile(Icons.volume_up_rounded, "القراءة الصوتية التلقائية", s.autoTts, (v) => setState(() => s.autoTts = v)),
                    _switchTile(Icons.school_rounded, "إشعارات المنح", s.notifScholarships, (v) => setState(() => s.notifScholarships = v)),
                    _switchTile(Icons.campaign_rounded, "إشعارات عامة", s.notifGeneral, (v) => setState(() => s.notifGeneral = v)),

                    _sectionTitle("البيانات"),
                    _actionTile(Icons.delete_sweep_rounded, "مسح المحادثات المحلية", AppColors.textPrimary, () => _snack("تم مسح المحادثات (محاكاة)")),
                    _actionTile(Icons.person_off_rounded, "حذف الحساب", Colors.redAccent, () => _confirmDelete()),

                    _sectionTitle("عن مسار"),
                    _actionTile(Icons.info_outline_rounded, "الإصدار 2.0", AppColors.textPrimary, () {}),
                    _actionTile(Icons.support_agent_rounded, "المطور: م. محمد الديني", AppColors.textPrimary, () {}),
                    _actionTile(Icons.privacy_tip_rounded, "سياسة الخصوصية", AppColors.textPrimary, () {}),

                    const SizedBox(height: 12),
                    _actionTile(Icons.logout_rounded, "تسجيل الخروج", Colors.redAccent, () {
                      DemoState.I.signOut();
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const AuthScreen()), (r) => false);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 18, 6, 10),
        child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: AppColors.textSecondary)),
      );

  Widget _switchTile(IconData icon, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftCard(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 13.5))),
          Switch(value: value, onChanged: onChanged, activeThumbColor: AppColors.primary),
        ]),
      ),
    );
  }

  Widget _actionTile(IconData icon, String label, Color color, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SoftCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13.5))),
            Icon(Icons.chevron_left_rounded, color: AppColors.textSecondary, size: 22),
          ]),
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surfaceWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text("حذف الحساب؟", style: TextStyle(fontWeight: FontWeight.w900, color: Colors.redAccent)),
      content: Text("سيتم حذف حسابك وكل بياناتك نهائياً. لا يمكن التراجع.", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, height: 1.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text("إلغاء", style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.bold))),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("حذف", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
      ],
    ));
  }

  void _snack(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m, style: const TextStyle(fontFamily: 'Cairo', fontWeight: FontWeight.bold)), backgroundColor: AppColors.primary, behavior: SnackBarBehavior.floating, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
}
