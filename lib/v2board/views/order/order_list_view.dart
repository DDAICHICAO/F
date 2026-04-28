import 'package:fl_clash/v2board/api/order_api.dart';
import 'package:fl_clash/v2board/models/plan.dart';
import 'package:fl_clash/v2board/providers/plan_order_provider.dart';
import 'package:fl_clash/v2board/widgets/currency_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OrderListView extends ConsumerStatefulWidget {
  const OrderListView({super.key});

  @override
  ConsumerState<OrderListView> createState() => _OrderListViewState();
}

class _OrderListViewState extends ConsumerState<OrderListView> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(planOrderProvider.notifier).fetchOrders());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = ref.watch(planOrderProvider);

    if (state.loading && state.orders.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text('暂无订单', style: theme.textTheme.bodyLarge),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => ref.read(planOrderProvider.notifier).fetchOrders(),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: state.orders.length,
        itemBuilder: (context, index) => _OrderCard(order: state.orders[index]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(
          order.tradeNo,
          style: theme.textTheme.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _StatusChip(status: order.status),
                const SizedBox(width: 8),
                Expanded(
                  child: CurrencyText(
                    amountInCents: (order.totalAmount * 100).round(),
                  ),
                ),
              ],
            ),
            if (order.createdAt != null)
              Text(
                '${order.createdAt!.year}-${order.createdAt!.month.toString().padLeft(2, '0')}-${order.createdAt!.day.toString().padLeft(2, '0')}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
        trailing: order.status == 0
            ? TextButton(
                onPressed: () => _cancelOrder(context),
                child: const Text('取消'),
              )
            : null,
      ),
    );
  }

  Future<void> _cancelOrder(BuildContext context) async {
    try {
      await orderApi.cancel(order.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已取消')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('取消失败: $e')),
        );
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  final int status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      0 => ('待支付', Colors.orange),
      1 => ('开通中', Colors.blue),
      2 => ('已取消', Colors.grey),
      3 => ('已完成', Colors.green),
      4 => ('已折抵', Colors.purple),
      _ => ('未知', Colors.grey),
    };
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 11, color: color)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: color),
    );
  }
}
