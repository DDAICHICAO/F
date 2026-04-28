import 'package:fl_clash/v2board/api/api_paths.dart';
import 'package:fl_clash/v2board/api/v2board_api.dart';
import 'package:fl_clash/v2board/models/plan.dart';

class OrderApi {
  Future<List<Plan>> fetchPlans() async {
    final data = await v2boardApi.get(ApiPaths.planFetch);
    final list = data['data'] as List? ?? [];
    return list.map((e) => Plan.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<Order>> fetchOrders() async {
    final data = await v2boardApi.get(ApiPaths.orderFetch);
    final list = data['data'] as List? ?? [];
    return list.map((e) => Order.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// checkout type: 1=新购, 2=续费, 3=变更
  Future<CheckoutResult> checkout({
    required int planId,
    required String period,
    int type = 1,
    String? coupon,
  }) async {
    final body = <String, dynamic>{
      'plan_id': planId,
      'period': period,
      'type': type,
    };
    if (coupon != null) body['coupon'] = coupon;
    final data = await v2boardApi.post(ApiPaths.orderCheckout, data: body);
    return CheckoutResult.fromJson(data['data'] as Map<String, dynamic>);
  }

  Future<void> cancel(int orderId) async {
    await v2boardApi.post(ApiPaths.orderCancel, data: {'trade_no': orderId});
  }

  Future<Map<String, dynamic>> checkCoupon({
    required int planId,
    required String code,
    required String period,
  }) async {
    final data = await v2boardApi.post(
      ApiPaths.couponCheck,
      data: {'plan_id': planId, 'code': code, 'period': period},
    );
    return data['data'] as Map<String, dynamic>? ?? {};
  }
}

final orderApi = OrderApi();
