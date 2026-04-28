import 'dart:convert';

class RemoteConfig {
  final List<String> api;
  final String path;
  final List<String> oss;

  const RemoteConfig({
    required this.api,
    required this.path,
    this.oss = const [],
  });

  List<String> get decodedApi =>
      api.map((e) => utf8.decode(base64Decode(e))).toList();

  Map<String, dynamic> toJson() => {
        'api': api,
        'path': path,
        if (oss.isNotEmpty) 'oss': oss,
      };

  factory RemoteConfig.fromJson(Map<String, dynamic> json) => RemoteConfig(
        api: List<String>.from(json['api'] as List),
        path: json['path'] as String,
        oss: json['oss'] != null ? List<String>.from(json['oss'] as List) : [],
      );

  static RemoteConfig? fromRawJson(String jsonStr) {
    try {
      return RemoteConfig.fromJson(
        json.decode(jsonStr) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }
}
