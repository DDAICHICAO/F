import 'package:fl_clash/v2board/api/ticket_api.dart';
import 'package:fl_clash/v2board/providers/ticket_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TicketCreateView extends ConsumerStatefulWidget {
  const TicketCreateView({super.key});

  @override
  ConsumerState<TicketCreateView> createState() => _TicketCreateViewState();
}

class _TicketCreateViewState extends ConsumerState<TicketCreateView> {
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  int _level = 1;
  bool _sending = false;

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('新建工单')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _subjectCtrl,
              decoration: const InputDecoration(
                labelText: '主题',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text('优先级', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('低')),
                ButtonSegment(value: 1, label: Text('中')),
                ButtonSegment(value: 2, label: Text('高')),
              ],
              selected: {_level},
              onSelectionChanged: (s) => setState(() => _level = s.first),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageCtrl,
              decoration: const InputDecoration(
                labelText: '描述',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 6,
              minLines: 4,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('提交'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final subject = _subjectCtrl.text.trim();
    final message = _messageCtrl.text.trim();
    if (subject.isEmpty || message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请填写主题和描述')),
      );
      return;
    }
    setState(() => _sending = true);
    try {
      await ticketApi.create(
        subject: subject,
        level: _level,
        message: message,
      );
      await ref.read(ticketProvider.notifier).fetchList();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
