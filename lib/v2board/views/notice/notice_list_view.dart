import 'package:fl_clash/v2board/models/notice.dart';
import 'package:fl_clash/v2board/providers/notice_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NoticeListView extends ConsumerStatefulWidget {
  const NoticeListView({super.key});

  @override
  ConsumerState<NoticeListView> createState() => _NoticeListViewState();
}

class _NoticeListViewState extends ConsumerState<NoticeListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(noticeProvider.notifier).fetchList();
      ref.read(noticeProvider.notifier).markAllRead();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(noticeProvider);

    if (state.loading && state.notices.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.notices.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_off, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('暂无公告', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(noticeProvider.notifier).fetchList(),
      child: ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: state.notices.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) => _NoticeCard(notice: state.notices[index]),
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final Notice notice;
  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              notice.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              notice.content,
              style: theme.textTheme.bodyMedium,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            if (notice.createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                _formatDate(notice.createdAt!),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
