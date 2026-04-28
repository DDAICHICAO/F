import 'package:fl_clash/v2board/api/order_api.dart';
import 'package:fl_clash/v2board/models/plan.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlanOrderState {
  final List<Plan> plans;
  final List<Order> orders;
  final bool loading;

  const PlanOrderState({
    this.plans = const [],
    this.orders = const [],
    this.loading = false,
  });

  PlanOrderState copyWith({
    List<Plan>? plans,
    List<Order>? orders,
    bool? loading,
  }) =>
      PlanOrderState(
        plans: plans ?? this.plans,
        orders: orders ?? this.orders,
        loading: loading ?? this.loading,
      );
}

final planOrderProvider = NotifierProvider<PlanOrderNotifier, PlanOrderState>(
  PlanOrderNotifier.new,
);

class PlanOrderNotifier extends Notifier<PlanOrderState> {
  @override
  PlanOrderState build() => const PlanOrderState();

  Future<void> fetchPlans() async {
    state = state.copyWith(loading: true);
    try {
      final plans = await orderApi.fetchPlans();
      state = state.copyWith(plans: plans, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  Future<void> fetchOrders() async {
    state = state.copyWith(loading: true);
    try {
      final orders = await orderApi.fetchOrders();
      state = state.copyWith(orders: orders, loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }
}
