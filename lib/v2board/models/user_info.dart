class SubscribeInfo {
  final int id;
  final String email;
  final int? planId;
  final String? planName;
  final String token;
  final String uuid;
  final int? expiredAt;
  final int u;
  final int d;
  final int transferEnable;
  final int? deviceLimit;
  final int aliveIp;
  final int? resetDay;
  final int autoRenewal;
  final int balance;
  final String subscribeUrl;
  final bool subscribeBan;
  final bool suspended;
  final String? suspendReason;

  const SubscribeInfo({
    required this.id,
    required this.email,
    this.planId,
    this.planName,
    required this.token,
    required this.uuid,
    this.expiredAt,
    required this.u,
    required this.d,
    required this.transferEnable,
    this.deviceLimit,
    required this.aliveIp,
    this.resetDay,
    required this.autoRenewal,
    required this.balance,
    required this.subscribeUrl,
    required this.subscribeBan,
    required this.suspended,
    this.suspendReason,
  });

  factory SubscribeInfo.fromJson(Map<String, dynamic> json) {
    final plan = json['plan'];
    return SubscribeInfo(
      id: json['id'] as int,
      email: json['email'] as String? ?? '',
      planId: json['plan_id'] as int?,
      planName: plan is Map<String, dynamic> ? plan['name'] as String? : null,
      token: json['token'] as String? ?? '',
      uuid: json['uuid'] as String? ?? '',
      expiredAt: json['expired_at'] as int?,
      u: json['u'] as int? ?? 0,
      d: json['d'] as int? ?? 0,
      transferEnable: json['transfer_enable'] as int? ?? 0,
      deviceLimit: json['device_limit'] as int?,
      aliveIp: json['alive_ip'] as int? ?? 0,
      resetDay: json['reset_day'] as int?,
      autoRenewal: json['auto_renewal'] as int? ?? 0,
      balance: json['balance'] as int? ?? 0,
      subscribeUrl: json['subscribe_url'] as String? ?? '',
      subscribeBan: json['subscribe_ban'] as bool? ?? false,
      suspended: json['suspended'] as bool? ?? false,
      suspendReason: json['suspend_reason'] as String?,
    );
  }

  double get usedGB => (u + d) / (1024 * 1024 * 1024);
  double get totalGB => transferEnable / (1024 * 1024 * 1024);
  double get usagePercent => totalGB > 0 ? (usedGB / totalGB).clamp(0, 1) : 0;
  DateTime? get expiredAtDate =>
      expiredAt != null ? DateTime.fromMillisecondsSinceEpoch(expiredAt! * 1000) : null;
  bool get isExpired =>
      expiredAt != null && expiredAt! * 1000 < DateTime.now().millisecondsSinceEpoch;
}

class UserInfo {
  final String email;
  final int? transferEnable;
  final int? deviceLimit;
  final DateTime? lastLoginAt;
  final DateTime? createdAt;
  final bool banned;
  final bool suspended;
  final int autoRenewal;
  final int? expiredAt;
  final int balance;
  final int commissionBalance;
  final int? planId;
  final int? discount;
  final int? commissionRate;
  final String uuid;
  final String? avatarUrl;

  const UserInfo({
    required this.email,
    this.transferEnable,
    this.deviceLimit,
    this.lastLoginAt,
    this.createdAt,
    required this.banned,
    required this.suspended,
    required this.autoRenewal,
    this.expiredAt,
    required this.balance,
    required this.commissionBalance,
    this.planId,
    this.discount,
    this.commissionRate,
    required this.uuid,
    this.avatarUrl,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) => UserInfo(
        email: json['email'] as String? ?? '',
        transferEnable: json['transfer_enable'] as int?,
        deviceLimit: json['device_limit'] as int?,
        lastLoginAt: json['last_login_at'] != null
            ? DateTime.tryParse(json['last_login_at'].toString())
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        banned: json['banned'] as bool? ?? false,
        suspended: json['suspended'] as bool? ?? false,
        autoRenewal: json['auto_renewal'] as int? ?? 0,
        expiredAt: json['expired_at'] as int?,
        balance: json['balance'] as int? ?? 0,
        commissionBalance: json['commission_balance'] as int? ?? 0,
        planId: json['plan_id'] as int?,
        discount: json['discount'] as int?,
        commissionRate: json['commission_rate'] as int?,
        uuid: json['uuid'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
      );
}
