class ApiResponse<T> {
  final T? data;
  final String? message;

  const ApiResponse({this.data, this.message});

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic)? fromJsonT,
  ) =>
      ApiResponse(
        data: json['data'] != null && fromJsonT != null
            ? fromJsonT(json['data'])
            : null,
        message: json['message'] as String?,
      );
}
