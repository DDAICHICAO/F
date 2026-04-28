import 'package:fl_clash/v2board/api/ticket_api.dart';
import 'package:fl_clash/v2board/models/ticket.dart';
import 'package:fl_clash/v2board/providers/ticket_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TicketDetailView extends ConsumerStatefulWidget {
  final int ticketId;
  const TicketDetailView({super.key, required this.ticketId});

  @override
  ConsumerState<TicketDetailView> createState() => _TicketDetailViewState();
}

class _TicketDetailViewState extends ConsumerState<TicketDetailView> {
  final _replyCtrl = TextEditingController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref.read(ticketProvider.notifier).fetchDetail(widget.ticketId),
    );
  }

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketState = ref.watch(ticketProvider);
    final ticket = ticketState.currentTicket;

    if (ticket == null || ticketState.loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('工单详情')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final messages = ticket.message ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(ticket.subject, overflow: TextOverflow.ellipsis),
        actions: [
          if (ticket.status != 2)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '关闭工单',
              onPressed: () => _closeTicket(ticket),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: messages.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final msg = messages[index];
                return _MessageBubble(message: msg);
              },
            ),
          ),
          if (ticket.status != 2) ...[
            const Divider(height: 1),
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom + 8,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _replyCtrl,
                      decoration: const InputDecoration(
                        hintText: '输入回复...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 3,
                      minLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _sendReply,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _sendReply() async {
    final text = _replyCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ticketApi.reply(id: widget.ticketId, message: text);
      _replyCtrl.clear();
      await ref.read(ticketProvider.notifier).fetchDetail(widget.ticketId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _closeTicket(Ticket ticket) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('关闭工单'),
        content: Text('确定关闭 "${ticket.subject}" 吗？关闭后不可再回复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ticketApi.close(widget.ticketId);
      await ref.read(ticketProvider.notifier).fetchDetail(widget.ticketId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('关闭失败: $e')),
        );
      }
    }
  }
}

class _MessageBubble extends StatelessWidget {
  final TicketMessage message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parsed = message.parsed;
    final isMe = message.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parsed.text,
              style: TextStyle(
                color: isMe ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
              ),
            ),
            if (parsed.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: parsed.images.map((url) => ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(
                    url,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 100,
                      height: 100,
                      color: theme.colorScheme.surfaceContainerHighest,
                      child: const Icon(Icons.broken_image),
                    ),
                  ),
                )).toList(),
              ),
            ],
            if (message.createdAt != null) ...[
              const SizedBox(height: 4),
              Text(
                _formatTime(message.createdAt!),
                style: TextStyle(
                  fontSize: 11,
                  color: isMe
                      ? theme.colorScheme.onPrimary.withValues(alpha: 0.7)
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
