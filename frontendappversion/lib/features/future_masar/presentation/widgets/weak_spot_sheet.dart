import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../quiz/data/quiz_analytics.dart';

// ==========================================
// 🔍 تفصيل نقطة الضعف — أين ضعفك بالضبط داخل الدرس
// ==========================================
// الصفّ في شاشة التحليل **درسٌ واحد** بمجموع أخطائه (فلا يتكرّر الدرس).
// وهذه الورقة هي المستوى الثاني: المفاهيم داخله مرتّبةً بالأكثر خطأً —
// ليعرف الطالب أنه ضعيف في «تغيّر الإنتروبي» لا في «الديناميكا» كلها.

Future<void> showWeakSpotSheet(
  BuildContext context,
  WeakSpot spot, {
  required VoidCallback onExplain,
  required VoidCallback onRetakeQuiz,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surfaceWhite,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) =>
        _WeakSpotSheet(spot: spot, onExplain: onExplain, onRetakeQuiz: onRetakeQuiz),
  );
}

class _WeakSpotSheet extends StatelessWidget {
  const _WeakSpotSheet(
      {required this.spot, required this.onExplain, required this.onRetakeQuiz});

  final WeakSpot spot;
  final VoidCallback onExplain;
  final VoidCallback onRetakeQuiz;

  @override
  Widget build(BuildContext context) {
    final maxMisses = spot.topics.isEmpty
        ? 1
        : spot.topics.map((t) => t.misses).reduce((a, b) => a > b ? a : b);

    return Padding(
      padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 18,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.softSurface,
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            Text(spot.lesson,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 5),
            Text(
                "${spot.subject}"
                "${spot.unit.isEmpty ? '' : ' · ${spot.unit}'}",
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            const SizedBox(height: 10),
            // النسبة أولاً لأنها أساس الترتيب، والعيّنة بجوارها كي لا تُقرأ مجرّدة
            Row(children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Text("${spot.errorRate}٪ نسبة الخطأ",
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Colors.redAccent)),
              ),
              const SizedBox(width: 10),
              Text(
                  spot.asked > 0
                      ? "${spot.misses} من ${spot.asked} سؤالاً"
                      : "${spot.misses} خطأ",
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ]),
            const SizedBox(height: 20),

            if (spot.topics.isEmpty)
              Text("لم تُسجَّل مفاهيم لهذا الدرس بعد.",
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary))
            else ...[
              Row(children: [
                Icon(Icons.my_location_rounded,
                    size: 16, color: AppColors.secondary),
                const SizedBox(width: 6),
                Text("أين ضعفك بالضبط:",
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                        fontSize: 12.5)),
              ]),
              const SizedBox(height: 12),
              // شريطٌ نسبيٌّ لكل مفهوم — يُرى الفرق بلمحة لا بقراءة أرقام
              ...spot.topics.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(t.topic,
                                style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary)),
                          ),
                          const SizedBox(width: 10),
                          Text("${t.misses} خطأ",
                              style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.redAccent)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: t.misses / maxMisses,
                            minHeight: 6,
                            backgroundColor: AppColors.softSurface,
                            valueColor: const AlwaysStoppedAnimation(
                                Colors.redAccent),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],

            const SizedBox(height: 12),
            // 🔁 فعلان لا فعلٌ واحد: الشرح يعالج الضعف، وإعادة الاختبار
            //    تقيس هل زال — وبدونها يبقى الدرس «ضعيفاً» في القائمة أبداً
            //    لأن نسبة الخطأ لا تنزل إلا بمحاولة جديدة.
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onExplain();
                },
                icon: const Icon(Icons.menu_book_rounded, size: 19),
                label: const Text("اشرح لي هذا الدرس",
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  onRetakeQuiz();
                },
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: const Text("إعادة الاختبار على هذا الدرس",
                    style:
                        TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(
                      color: AppColors.primary.withValues(alpha: 0.45), width: 1.4),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
