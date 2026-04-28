class AuthResponse {
  final String token;
  final bool isAdmin;
  final String authData;

  const AuthResponse({
    required this.token,
    required this.isAdmin,
    required this.authData,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) => AuthResponse(
        token: json['token'] as String,
        isAdmin: json['is_admin'] as bool? ?? false,
        authData: json['auth_data'] as String,
      );
}
