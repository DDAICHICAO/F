enum ApiErrorType {
  unauthorized,
  forbidden,
  validation,
  server,
  network,
  unknown,
}

class ApiError implements Exception {
  final ApiErrorType type;
  final String message;
  final Map<String, List<String>>? errors;
  final int? statusCode;

  const ApiError({
    required this.type,
    required this.message,
    this.errors,
    this.statusCode,
  });

  factory ApiError.unauthorized([String? msg]) => ApiError(
        type: ApiErrorType.unauthorized,
        message: msg ?? '认证已过期，请重新登录',
        statusCode: 401,
      );

  factory ApiError.forbidden([String? msg]) => ApiError(
        type: ApiErrorType.forbidden,
        message: msg ?? '账户已被封禁',
        statusCode: 403,
      );

  factory ApiError.validation(
    String message, {
    Map<String, List<String>>? errors,
  }) =>
      ApiError(
        type: ApiErrorType.validation,
        message: message,
        errors: errors,
        statusCode: 422,
      );

  factory ApiError.server([String? msg]) => ApiError(
        type: ApiErrorType.server,
        message: msg ?? '服务器错误，请稍后重试',
        statusCode: 500,
      );

  factory ApiError.network([String? msg]) => ApiError(
        type: ApiErrorType.network,
        message: msg ?? '网络连接失败，请检查网络设置',
      );

  @override
  String toString() => 'ApiError($type, $statusCode): $message';
}
