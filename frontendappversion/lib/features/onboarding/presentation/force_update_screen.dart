import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/version/version_gate.dart';

// ==========================================
// 📦 شاشة التحديث الإلزامي — آخر ما يراه إصدارٌ مكسور
// ==========================================
// 🚧 **بلا زرّ رجوع ولا تخطٍّ عمداً.** هذه الشاشة لا تظهر إلا حين يقرّر
//    المالك من اللوحة أن هذا البناء لم يعد يعمل مع الخادم أصلاً. وزرُّ
//    «لاحقاً» هنا يعني السماحَ للطالب بالدخول إلى تطبيقٍ **سيفشل** أمامه
//    برسائل غامضة — وهو أسوأ من حجبٍ صريحٍ يقول له ماذا يفعل بالضبط.
//
// 🛟 ولا تظهر إلا بقرارٍ صريح: كل مسارات الفشل في [VersionGate] تعيد
//    «لا تحديث مطلوب»، فعطلُ شبكةٍ لا يحجب أحداً.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key, required this.verdict});

  final VersionVerdict verdict;

  Future<void> _openStore(BuildContext context) async {
    final url = verdict.storeUrl.trim();
    if (url.isEmpty) {
      // ⚠️ رابطٌ غائب من اللوحة ليس سبباً لزرٍّ ميت بلا تفسير.
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("حدّث «مسار» من المتجر الذي حمّلته منه 🙏"),
      ));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 🚧 زرّ الرجوع في أندرويد لا يتخطّى الشاشة — راجع الشرح أعلاه.
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.system_update_rounded,
                        size: 56, color: AppColors.primary),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    "تحديثٌ مطلوب",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    verdict.message.isNotEmpty
                        ? verdict.message
                        : "صدر تحديثٌ مهم لمسار — حدّث التطبيق لتتابع بلا مشاكل.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.7,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _openStore(context),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text("حدّث الآن"),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
