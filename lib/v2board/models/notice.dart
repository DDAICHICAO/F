class Notice {
  final int id;
  final String title;
  final String content;
  final String? icon;
  final String? url;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Notice({
    required this.id,
    required this.title,
    required this.content,
    this.icon,
    this.url,
    this.createdAt,
    this.updatedAt,
  });

  factory Notice.fromJson(Map<String, dynamic> json) => Notice(
        id: json['id'] as int,
        title: json['title'] as String? ?? '',
        content: json['content'] as String? ?? '',
        icon: json['icon'] as String?,
        url: json['url'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
      );
}
