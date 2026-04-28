import 'package:fl_clash/v2board/models/ticket.dart';
import 'package:fl_clash/v2board/providers/ticket_provider.dart';
import 'package:fl_clash/v2board/views/ticket/ticket_detail_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TicketListView extends ConsumerStatefulWidget {
  const TicketListView({super.key});

  @override
  ConsumerState<TicketListView> createState() => _TicketListViewState();
}

class _TicketListViewState extends ConsumerState<TicketListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(ticketProvider.notifier).fetchList());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ticketState = ref.watch(ticketProvider);

    if (ticketState.loading && ticketState.tickets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (ticketState.tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('暂无工单', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(ticketProvider.notifier).fetchList(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: ticketState.tickets.length,
        itemBuilder: (context, index) {
          final ticket = ticketState.tickets[index];
          return _TicketCard(ticket: ticket);
        },
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(ticket.subject, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Row(
          children: [
            _StatusChip(status: ticket.status),
            const SizedBox(width: 8),
            _LevelChip(level: ticket.level),
            if (ticket.updatedAt != null) ...[
              const SizedBox(width: 8),
              Text(
                _formatDate(ticket.updatedAt!),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TicketDetailView(ticketId: ticket.id),
            ),
          );
        },
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _StatusChip extends StatelessWidget {
  final int status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      0 => Colors.orange,
      1 => Colors.blue,
      2 => Colors.grey,
      _ => Colors.grey,
    };
    return Chip(
      label: Text(switch (status) {
        0 => '待处理',
        1 => '已回复',
        2 => '已关闭',
        _ => '未知',
      }, style: const TextStyle(fontSize: 11)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color),
      labelStyle: TextStyle(color: color),
    );
  }
}

class _LevelChip extends StatelessWidget {
  final int level;
  const _LevelChip({required this.level});

  @override
  Widget build(BuildContext context) {
    return Text(
      switch (level) { 0 => '低', 1 => '中', 2 => '高', _ => '' },
      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
    );
  }
}
