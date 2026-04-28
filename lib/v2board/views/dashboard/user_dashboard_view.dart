import 'package:fl_clash/v2board/api/user_api.dart';
import 'package:fl_clash/v2board/providers/auth_provider.dart';
import 'package:fl_clash/v2board/providers/user_provider.dart';
import 'package:fl_clash/v2board/views/plan/plan_list_view.dart';
import 'package:fl_clash/v2board/views/order/order_list_view.dart';
import 'package:fl_clash/v2board/widgets/currency_text.dart';
import 'package:fl_clash/v2board/widgets/traffic_progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserDashboardView extends ConsumerWidget {
  const UserDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userState = ref.watch(userProvider);
    final sub = userState.subscribeInfo;
    final userInfo = userState.userInfo;

    if (sub == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 用户信息卡片
        _buildUserCard(context, sub, userInfo, theme),
        const SizedBox(height: 12),

        // 封禁/暂停警示
        if (sub.suspended) ...[
          _buildAlertCard(
            context,
            icon: Icons.pause_circle,
            color: Colors.orange,
            title: '服务已暂停',
            subtitle: sub.suspendReason ?? '请联系客服',
          ),
          const SizedBox(height: 12),
        ],
        if (sub.subscribeBan) ...[
          _buildAlertCard(
            context,
            icon: Icons.block,
            color: theme.colorScheme.error,
            title: '订阅已被风控封禁',
            subtitle: '请联系客服或申请解封',
          ),
          const SizedBox(height: 12),
        ],

        // 流量进度条
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TrafficProgress(
              usedGB: sub.usedGB,
              totalGB: sub.totalGB,
              expireDays: _calcExpireDays(sub.expiredAtDate),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 余额信息
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  context,
                  label: '余额',
                  child: CurrencyText(
                    amountInCents: sub.balance,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outlineVariant,
                ),
                _buildStatItem(
                  context,
                  label: '在线设备',
                  child: Text(
                    '${sub.aliveIp}${sub.deviceLimit != null ? '/${sub.deviceLimit}' : ''}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  width: 1,
                  height: 40,
                  color: theme.colorScheme.outlineVariant,
                ),
                _buildStatItem(
                  context,
                  label: '套餐',
                  child: Text(
                    sub.planName ?? '无',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 快捷入口
        Card(
          child: Column(
            children: [
              _buildListTile(context, icon: Icons.shopping_bag, title: '购买套餐', onTap: () => _navigate(context, const PlanListView())),
              _buildListTile(context, icon: Icons.receipt_long, title: '我的订单', onTap: () => _navigate(context, const OrderListView())),
              _buildListTile(context, icon: Icons.password, title: '修改密码', onTap: () => _changePassword(context, ref)),
              _buildListTile(context, icon: Icons.refresh, title: '重置订阅', onTap: () => _resetSecurity(context, ref)),
              _buildListTile(context, icon: Icons.devices, title: '设备管理', onTap: () => _manageSessions(context, ref)),
              _buildListTile(context, icon: Icons.exit_to_app, title: '退出登录', onTap: () => _logout(context, ref), color: theme.colorScheme.error),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(BuildContext context, dynamic sub, dynamic userInfo, ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person,
                size: 32,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sub.email,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sub.planName != null ? '套餐: ${sub.planName}' : '未订阅',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (sub.expiredAtDate != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      '到期: ${_formatDate(sub.expiredAtDate!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: sub.isExpired ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  Text(subtitle, style: TextStyle(color: color, fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, {required String label, required Widget child}) {
    return Column(
      children: [
        child,
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        )),
      ],
    );
  }

  Widget _buildListTile(BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  int? _calcExpireDays(DateTime? expiredAt) {
    if (expiredAt == null) return null;
    final diff = expiredAt.difference(DateTime.now()).inDays;
    return diff > 0 ? diff : 0;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  void _changePassword(BuildContext context, WidgetRef ref) {
    final oldCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('修改密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldCtrl,
              decoration: const InputDecoration(labelText: '旧密码', border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newCtrl,
              decoration: const InputDecoration(labelText: '新密码', border: OutlineInputBorder(), helperText: '至少8位'),
              obscureText: true,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              try {
                await userApi.changePassword(
                  oldPassword: oldCtrl.text,
                  newPassword: newCtrl.text,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                // 改密后服务端清所有 session，需重新登录
                await ref.read(authProvider.notifier).logout();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('修改失败: $e')),
                  );
                }
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _resetSecurity(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重置订阅'),
        content: const Text('重置后当前订阅链接将失效，需要重新获取。确定继续？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              try {
                await userApi.resetSecurity();
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('订阅已重置，请重新登录以获取新链接')),
                  );
                  await ref.read(authProvider.notifier).logout();
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('重置失败: $e')),
                  );
                }
              }
            },
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
  }

  void _manageSessions(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('设备管理'),
        content: const Text('此功能将在后续版本中完善。'),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('确定')),
        ],
      ),
    );
  }

  void _logout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }

  void _navigate(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }
}
