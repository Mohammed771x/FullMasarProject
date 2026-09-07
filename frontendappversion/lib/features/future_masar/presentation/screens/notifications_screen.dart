import 'package:flutter/material.dart';

import '../../../../core/notifications/notifications_repository.dart';
import '../../../../core/notifications/push_router.dart';
import '../../../../core/theme/app_colors.dart';

// ==========================================
// 📬 شاشة الإشعارات — صندوق الطالب
// ==========================================
// 🔴 **ما كان قبلها:** الجرس في الرئيسية يعرض `_snack("لا إشعارات جديدة")`
//    نصّاً ثابتاً، وشارةً حمراء لا تنطفئ لأنها ليست مربوطةً بعدد. فيرسل
//    المالك إعلاناً وتقول اللوحة بصدق «محفوظ في صناديقهم» — ويفتح الطالب
//    الجرس فيُقال له «لا إشعارات». الطرفان صادقان والحلقة مقطوعة بينهما.
//
// ⭐ **والوجهة تمرّ بـ[PushRouter] نفسه** لا بمنطقٍ ثانٍ هنا: نقرةُ الإشعار
//    على الجهاز ونقرتُه في هذه الشاشة تفتحان **الشيء نفسه** وتخضعان
//    **لحارس الأقسام نفسه**. ونسختان من جدول الوجهات تنحرفان يوم يُضاف
//    قسمٌ، فيفتح أحدُهما ما يرفضه الآخر.

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repo = NotificationsRepository.I;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onChange);
    // 🔄 نحدّث عند الفتح: الطالب يفتح الجرس **لأنه يتوقّع جديداً**، فعرضُ
    //    كاشٍ من إقلاعٍ صباحيّ يخالف سبب فتحه للشاشة أصلاً.
    _refresh();
  }

  @override
  void dispose() {
    _repo.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    await _repo.refresh();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _open(NotificationItem n) async {
    await _repo.markRead(n.id);
    // ⚠️ الوجهة تُفتح **بعد** التعليم كمقروء: لو انقلب الترتيب وفشلت
    //    الملاحة (قسمٌ مقفل) لبقي الإشعار غيرَ مقروءٍ وقد قرأه الطالب.
    if (n.link.isEmpty || n.link == 'none') return;
    await PushRouter.open(n.link, n.id);
  }

  @override
  Widget build(BuildContext context) {
    final items = _repo.items;
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceWhite,
        elevation: 0,
        title: const Text("الإشعارات",
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        actions: [
          if (_repo.hasUnread)
            IconButton(
              tooltip: "تعليم الكل كمقروء",
              icon: const Icon(Icons.done_all_rounded),
              onPressed: () => _repo.markAllRead(),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        child: items.isEmpty ? _empty() : _list(items),
      ),
    );
  }

  Widget _list(List<NotificationItem> items) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 24),
        itemCount: items.length + (_repo.lastRefreshFailed ? 1 : 0),
        itemBuilder: (_, i) {
          // 🛟 الكاش يبقى معروضاً والتعذُّر يُقال فوقه — لا شاشةَ خطأٍ تمحو
          //    إعلاناتٍ وصلت فعلاً لأن التحديث الأخير تعثّر.
          if (_repo.lastRefreshFailed && i == 0) return _staleNote();
          return _card(items[i - (_repo.lastRefreshFailed ? 1 : 0)]);
        },
      );

  Widget _staleNote() => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.09),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, size: 18, color: Colors.orange),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                "تعذّر التحديث — هذه آخر إشعارات وصلتك. اسحب للأسفل للمحاولة.",
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      );

  Widget _card(NotificationItem n) {
    final unread = !_repo.isRead(n.id);
    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(
        color: AppColors.surfaceWhite,
        borderRadius: BorderRadius.circular(18),
        boxShadow: AppColors.bubbleShadow,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: unread ? 0.28 : 0.0),
          width: 1.4,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _open(n),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔵 نقطةٌ لا لونُ خلفيةٍ كامل: الفرق يُرى بلا أن يصير غيرُ
              //    المقروء صارخاً وسطَ قائمةٍ طويلة.
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: unread ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: unread ? FontWeight.w900 : FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      n.body,
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.6,
                          color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          _when(n.createdAt),
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textSecondary
                                  .withValues(alpha: 0.7)),
                        ),
                        if (_destination(n.link) != null) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.arrow_back_rounded,
                              size: 12,
                              color: AppColors.primary.withValues(alpha: 0.8)),
                          const SizedBox(width: 3),
                          Text(
                            _destination(n.link)!,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _empty() => ListView(
        // ⚠️ `ListView` لا `Center`: بدون ابنٍ قابلٍ للتمرير لا يعمل السحب
        //    للتحديث — فيبدو الصندوق الفارغ عالقاً بلا طريقة لإعادة المحاولة.
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 90),
        children: [
          Icon(Icons.notifications_none_rounded,
              size: 64, color: AppColors.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            _busy ? "جارٍ التحديث…" : "لا إشعارات بعد",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            _repo.lastRefreshFailed
                ? "تعذّر الوصول إلى الخادم — اسحب للأسفل للمحاولة."
                : "ستظهر هنا إعلانات المنصّة والمنح وكل ما يهمّك،\nحتى لو كان جهازك مغلقاً وقت إرسالها.",
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, height: 1.8, color: AppColors.textSecondary),
          ),
        ],
      );

  /// اسمُ القسم الذي تفتحه هذه الوجهة — أو `null` لإشعارٍ بلا وجهة.
  ///
  /// ⭐ يُشتقّ من [PushRouter.sectionFor] فلا يبقى جدولٌ ثانٍ ينحرف.
  static String? _destination(String link) {
    const labels = {
      'education': 'التعليم',
      'quiz': 'اختبر نفسك',
      'analysis': 'تحليل مستواي',
      'scholarships': 'المنح',
      'teacher': 'مساعد المعلم',
      'services': 'الخدمات',
    };
    return labels[PushRouter.sectionFor(link) ?? ''];
  }

  /// «قبل ٣ ساعات» — أوضح للطالب من طابعٍ زمنيّ كامل.
  ///
  /// ⚠️ الخادم يكتب الوقت بـUTC، والمقارنة تتم بـUTC أيضاً: خلطُهما يعطي
  ///    «قبل ٣ ساعات» لإشعارٍ وصل قبل دقيقة (فارقُ توقيت اليمن +٣).
  static String _when(String iso) {
    final at = DateTime.tryParse(iso);
    if (at == null) return '';
    final diff = DateTime.now().toUtc().difference(at.toUtc());
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'قبل ${diff.inHours} ساعة';
    if (diff.inDays == 1) return 'أمس';
    return 'قبل ${diff.inDays} يوماً';
  }
}
