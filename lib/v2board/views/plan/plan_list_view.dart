import 'package:fl_clash/v2board/api/order_api.dart';
import 'package:fl_clash/v2board/models/plan.dart';
import 'package:fl_clash/v2board/providers/plan_order_provider.dart';
import 'package:fl_clash/v2board/widgets/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlanListView extends ConsumerStatefulWidget {
  const PlanListView({super.key});

  @override
  ConsumerState<PlanListView> createState() => _PlanListViewState();
}

class _PlanListViewState extends ConsumerState<PlanListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(planOrderProvider.notifier).fetchPlans());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(planOrderProvider);

    if (state.loading && state.plans.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.plans.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('暂无可购套餐', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(planOrderProvider.notifier).fetchPlans(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: state.plans.length,
        itemBuilder: (context, index) => _PlanCard(plan: state.plans[index]),
      ),
    );
  }
}

class _PlanCard extends ConsumerWidget {
  final Plan plan;
  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final availablePrices = plan.pricing.entries.where((e) => e.value > 0).toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  plan.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (plan.transferGB > 0)
                  Chip(
                    label: Text('${plan.transferGB.toStringAsFixed(0)} GB'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (plan.deviceLimit > 0) _infoChip(Icons.devices, '${plan.deviceLimit} 设备'),
                if (plan.speedLimit > 0) _infoChip(Icons.speed, '${plan.speedLimit} Mbps'),
              ],
            ),
            if (plan.content != null && plan.content!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(plan.content!, style: theme.textTheme.bodySmall),
            ],
            const Divider(height: 24),
            Wrap(
              spacing: 8,
              children: availablePrices.map((e) {
                return ActionChip(
                  label: Text('${e.key}: ${(e.value / 100).toStringAsFixed(2)}'),
                  onPressed: () => _checkout(context, ref, e.key, e.value),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 4),
        Text(text),
      ],
    );
  }

  Future<void> _checkout(BuildContext context, WidgetRef ref, String periodName, int priceInCents) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认购买'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('套餐: ${plan.name}'),
            Text('周期: $periodName'),
            CurrencyText(
              amountInCents: priceInCents,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确认')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await orderApi.checkout(
        planId: plan.id,
        period: periodName,
        type: 1,
      );
      if (context.mounted) {
        if (result.type == '-1' || result.type == '0') {
          // 无需支付或余额支付成功
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('购买成功')),
          );
        } else {
          // 需要第三方支付，用 WebView 打开
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('请完成支付: ${result.type}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('购买失败: $e')),
        );
      }
    }
  }
}
