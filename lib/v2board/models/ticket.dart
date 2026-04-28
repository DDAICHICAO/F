class TicketMessage {
  final int id;
  final String message;
  final bool isMe;
  final DateTime? createdAt;

  const TicketMessage({
    required this.id,
    required this.message,
    required this.isMe,
    this.createdAt,
  });

  /// 解析 [TICKET_IMAGES] 协议，拆出 text + images
  ({String text, List<String> images}) get parsed {
    final separator = '\n\n[TICKET_IMAGES]\n';
    if (!message.contains('[TICKET_IMAGES]')) {
      return (text: message, images: <String>[]);
    }
    final parts = message.split(separator);
    final text = parts[0].trim();
    final images = parts.length > 1
        ? parts[1].split('\n').where((s) => s.trim().isNotEmpty).toList()
        : <String>[];
    return (text: text, images: images);
  }

  factory TicketMessage.fromJson(Map<String, dynamic> json) => TicketMessage(
        id: json['id'] as int,
        message: json['message'] as String? ?? '',
        isMe: json['is_me'] as bool? ?? false,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
      );
}

class Ticket {
  final int id;
  final String subject;
  final int level;
  final int status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<TicketMessage>? message;

  const Ticket({
    required this.id,
    required this.subject,
    required this.level,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.message,
  });

  String get statusText => switch (status) {
        0 => '待处理',
        1 => '已回复',
        2 => '已关闭',
        _ => '未知',
      };

  String get levelText => switch (level) {
        0 => '低',
        1 => '中',
        2 => '高',
        _ => '未知',
      };

  factory Ticket.fromJson(Map<String, dynamic> json) => Ticket(
        id: json['id'] as int,
        subject: json['subject'] as String? ?? '',
        level: json['level'] as int? ?? 0,
        status: json['status'] as int? ?? 0,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
        message: json['message'] is List
            ? (json['message'] as List)
                .map((e) => TicketMessage.fromJson(e as Map<String, dynamic>))
                .toList()
            : null,
      );
}
