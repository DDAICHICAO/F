import 'package:fl_clash/v2board/providers/invite_provider.dart';
import 'package:fl_clash/v2board/widgets/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InviteView extends ConsumerStatefulWidget {
  const InviteView({super.key});

  @override
  ConsumerState<InviteView> createState() => _InviteViewState();
}

class _InviteViewState extends ConsumerState<InviteView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(inviteProvider.notifier).fetchData());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(inviteProvider);
    final data = state.data;

    if (state.loading || data == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('邀请返利')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 佣金概览
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _statColumn(context, '待确认佣金', data.commissionPending),
                  Container(width: 1, height: 40, color: theme.colorScheme.outlineVariant),
                  _statColumn(context, '已提现', data.commissionWithdrawn),
                  Container(width: 1, height: 40, color: theme.colorScheme.outlineVariant),
                  _statColumn(context, '累计佣金', data.commissionTotal),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 邀请码
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('邀请码', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (data.codes.isEmpty)
                    Text('暂无邀请码', style: theme.textTheme.bodySmall)
                  else
                    ...data.codes.map((code) {
                      final codeStr = (code['code'] as String?) ?? '';
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(codeStr),
                        subtitle: Text(
                          '状态: ${code['status'] == 0 ? '可用' : '已用'}',
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.copy),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: codeStr));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已复制')),
                            );
                          },
                        ),
                      );
                    }),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () => ref.read(inviteProvider.notifier).generateCode(),
                    child: const Text('生成新邀请码'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 邀请的用户
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('已邀请用户', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  if (data.users.isEmpty)
                    Text('暂无', style: theme.textTheme.bodySmall)
                  else
                    ...data.users.map((user) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(user.email),
                          subtitle: user.commissionBalance != null
                              ? Text('佣金: ${user.commissionBalance}')
                              : null,
                        )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statColumn(BuildContext context, String label, int amountInCents) {
    return Column(
      children: [
        CurrencyText(
          amountInCents: amountInCents,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
