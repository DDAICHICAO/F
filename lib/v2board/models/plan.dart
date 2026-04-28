class Plan {
  final int id;
  final String name;
  final int? groupId;
  final int monthPrice;
  final int quarterPrice;
  final int halfYearPrice;
  final int yearPrice;
  final int twoYearPrice;
  final int threeYearPrice;
  final int onetimePrice;
  final int resetPrice;
  final int transferEnable;
  final int speedLimit;
  final int deviceLimit;
  final String? content;

  const Plan({
    required this.id,
    required this.name,
    this.groupId,
    required this.monthPrice,
    required this.quarterPrice,
    required this.halfYearPrice,
    required this.yearPrice,
    required this.twoYearPrice,
    required this.threeYearPrice,
    required this.onetimePrice,
    required this.resetPrice,
    this.transferEnable = 0,
    this.speedLimit = 0,
    this.deviceLimit = 0,
    this.content,
  });

  /// GB 流量
  double get transferGB => transferEnable / 1073741824;

  Map<String, int> get pricing => {
        '月付': monthPrice,
        '季付': quarterPrice,
        '半年': halfYearPrice,
        '年付': yearPrice,
        '两年': twoYearPrice,
        '三年': threeYearPrice,
        '一次性': onetimePrice,
        '重置': resetPrice,
      };

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        groupId: json['group_id'] as int?,
        monthPrice: (json['month_price'] as num?)?.toInt() ?? -1,
        quarterPrice: (json['quarter_price'] as num?)?.toInt() ?? -1,
        halfYearPrice: (json['half_year_price'] as num?)?.toInt() ?? -1,
        yearPrice: (json['year_price'] as num?)?.toInt() ?? -1,
        twoYearPrice: (json['two_year_price'] as num?)?.toInt() ?? -1,
        threeYearPrice: (json['three_year_price'] as num?)?.toInt() ?? -1,
        onetimePrice: (json['onetime_price'] as num?)?.toInt() ?? -1,
        resetPrice: (json['reset_price'] as num?)?.toInt() ?? -1,
        transferEnable: (json['transfer_enable'] as num?)?.toInt() ?? 0,
        speedLimit: (json['speed_limit'] as num?)?.toInt() ?? 0,
        deviceLimit: (json['device_limit'] as num?)?.toInt() ?? 0,
        content: json['content'] as String?,
      );
}

class Order {
  final int id;
  final String tradeNo;
  final int planId;
  final int userId;
  final int couponId;
  final double totalAmount;
  final double discountAmount;
  final String? discount;
  final int period;
  final String? periodName;
  final int status;
  final String? statusText;
  final DateTime? createdAt;

  const Order({
    required this.id,
    required this.tradeNo,
    required this.planId,
    required this.userId,
    this.couponId = 0,
    required this.totalAmount,
    required this.discountAmount,
    this.discount,
    required this.period,
    this.periodName,
    required this.status,
    this.statusText,
    this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as int,
        tradeNo: json['trade_no'] as String? ?? '',
        planId: json['plan_id'] as int? ?? 0,
        userId: json['user_id'] as int? ?? 0,
        couponId: json['coupon_id'] as int? ?? 0,
        totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
        discountAmount: (json['discount_amount'] as num?)?.toDouble() ?? 0,
        discount: json['discount'] as String?,
        period: json['period'] as int? ?? 0,
        periodName: json['period'] is String ? json['period'] as String : null,
        status: json['status'] as int? ?? 0,
        statusText: json['status'] is String ? json['status'] as String : null,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
}

class CheckoutResult {
  final String type;
  final String? data;

  const CheckoutResult({required this.type, this.data});

  factory CheckoutResult.fromJson(Map<String, dynamic> json) => CheckoutResult(
        type: json['type'] as String? ?? '',
        data: json['data']?.toString(),
      );
}
