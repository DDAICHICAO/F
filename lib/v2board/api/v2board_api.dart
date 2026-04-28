import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/v2board/config/remote_config_model.dart';
import 'package:fl_clash/v2board/config/v2board_local_storage.dart';
import 'package:fl_clash/v2board/models/api_error.dart';
import 'package:flutter/foundation.dart';

class V2boardApi {
  static V2boardApi? _instance;

  V2boardApi._();

  static V2boardApi get instance => _instance ??= V2boardApi._();

  late final Dio _dio;
  RemoteConfig? _config;
  int _activeHostIndex = 0;

  List<String> get _hosts => _config?.hosts ?? [];

  String? get _baseUrl {
    final hosts = _hosts;
    if (hosts.isEmpty || _activeHostIndex >= hosts.length) return null;
    return hosts[_activeHostIndex];
  }

  RemoteConfig? get config => _config;

  int get activeHostIndex => _activeHostIndex;

  void init() {
    final httpClient = HttpClient();
    httpClient.findProxy = (uri) => HttpClient.findProxyFromEnvironment(
          uri,
          environment: {'http_proxy': '', 'https_proxy': ''},
        );
    httpClient.badCertificateCallback = (_, _, _) => true;
    httpClient.connectionTimeout = const Duration(seconds: 10);

    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => httpClient,
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      _ErrorInterceptor(),
      _RetryOnFailInterceptor(this),
    ]);
  }

  Future<void> loadConfig() async {
    final storage = await V2boardLocalStorage.getInstance();
    final cached = storage.ossConfig;
    if (cached != null) {
      final config = RemoteConfig.fromRawJson(cached);
      if (config != null) {
        _config = config;
        _activeHostIndex = storage.activeApiIndex;
        if (_activeHostIndex >= config.hosts.length) {
          _activeHostIndex = 0;
        }
      }
    }
  }

  Future<void> updateConfig(RemoteConfig config) async {
    _config = config;
    _activeHostIndex = 0;
    final storage = await V2boardLocalStorage.getInstance();
    await storage.setOssConfig(json.encode(config.toJson()));
    await storage.setActiveApiIndex(0);
  }

  void setAuthData(String? authData) {
    _dio.options.headers['Authorization'] = authData;
  }

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final response = await _dio.get<Map<String, dynamic>>(
      path,
      queryParameters: queryParameters,
      options: options,
    );
    return response.data ?? {};
  }

  Future<Map<String, dynamic>> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      path,
      data: data,
      queryParameters: queryParameters,
      options: options,
    );
    return response.data ?? {};
  }

  Future<void> switchToNextHost() async {
    final hosts = _hosts;
    if (hosts.length <= 1) return;
    _activeHostIndex = (_activeHostIndex + 1) % hosts.length;
    final storage = await V2boardLocalStorage.getInstance();
    await storage.setActiveApiIndex(_activeHostIndex);
    debugPrint('V2boardApi: switched to host index $_activeHostIndex');
  }
}

class _AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final api = V2boardApi.instance;
    final baseUrl = api._baseUrl;
    if (baseUrl != null && !options.path.startsWith('http')) {
      options.baseUrl = baseUrl;
    }
    handler.next(options);
  }
}

class _ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final statusCode = err.response?.statusCode;
    final data = err.response?.data;

    String? message;
    Map<String, List<String>>? errors;

    if (data is Map<String, dynamic>) {
      message = data['message'] as String?;
      final rawErrors = data['errors'];
      if (rawErrors is Map<String, dynamic>) {
        errors = rawErrors.map(
          (k, v) => MapEntry(k, List<String>.from(v as Iterable)),
        );
      }
    }

    switch (statusCode) {
      case 401:
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: ApiError.unauthorized(message),
          ),
        );
        return;
      case 403:
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: ApiError.forbidden(message),
          ),
        );
        return;
      case 422:
        handler.reject(
          DioException(
            requestOptions: err.requestOptions,
            error: ApiError.validation(message ?? '表单验证失败', errors: errors),
          ),
        );
        return;
    }

    if (err.type == DioExceptionType.connectionTimeout ||
        err.type == DioExceptionType.receiveTimeout ||
        err.type == DioExceptionType.connectionError) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: ApiError.network(message),
        ),
      );
      return;
    }

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        error: ApiError(
          type: ApiErrorType.server,
          message: message ?? '服务器错误',
          statusCode: statusCode,
        ),
      ),
    );
  }
}

class _RetryOnFailInterceptor extends Interceptor {
  final V2boardApi _api;
  static const _maxRetry = 2;

  _RetryOnFailInterceptor(this._api);

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final error = err.error;
    if (error is ApiError && error.type == ApiErrorType.network) {
      final retryCount = err.requestOptions.extra['retryCount'] as int? ?? 0;
      if (retryCount < _maxRetry) {
        await _api.switchToNextHost();
        final newOptions = err.requestOptions.copyWith(
          extra: {...err.requestOptions.extra, 'retryCount': retryCount + 1},
        );
        try {
          final response = await _api._dio.fetch(newOptions);
          handler.resolve(response);
          return;
        } on DioException catch (i) {
          handler.next(i);
          return;
        }
      }
    }
    handler.next(err);
  }
}

final v2boardApi = V2boardApi.instance;
