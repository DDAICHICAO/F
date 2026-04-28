class InviteData {
  final List<Map<String, dynamic>> codes;
  final List<InviteUser> users;
  final int commissionPending;
  final int commissionWithdrawn;
  final int commissionTotal;

  const InviteData({
    this.codes = const [],
    this.users = const [],
    this.commissionPending = 0,
    this.commissionWithdrawn = 0,
    this.commissionTotal = 0,
  });

  factory InviteData.fromJson(Map<String, dynamic> json) => InviteData(
        codes: (json['codes'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(),
        users: (json['users'] as List? ?? [])
            .map((e) => InviteUser.fromJson(e as Map<String, dynamic>))
            .toList(),
        commissionPending: (json['commission_pending'] as num?)?.toInt() ?? 0,
        commissionWithdrawn: (json['commission_withdrawn'] as num?)?.toInt() ?? 0,
        commissionTotal: (json['commission_total'] as num?)?.toInt() ?? 0,
      );
}

class InviteUser {
  final int id;
  final String email;
  final int? commissionBalance;
  final int? commissionStatus;
  final DateTime? createdAt;

  const InviteUser({
    required this.id,
    required this.email,
    this.commissionBalance,
    this.commissionStatus,
    this.createdAt,
  });

  factory InviteUser.fromJson(Map<String, dynamic> json) => InviteUser(
        id: json['id'] as int,
        email: json['email'] as String? ?? '',
        commissionBalance: (json['commission_balance'] as num?)?.toInt(),
        commissionStatus: json['commission_status'] as int?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
}
