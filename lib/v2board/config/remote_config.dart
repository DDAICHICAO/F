import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/v2board/config/remote_config_model.dart';
import 'package:flutter/foundation.dart';

const _kTimeout = Duration(seconds: 5);

const kBuiltinOssUrls = [
  'https://bust-sh.oss-cn-shanghai.aliyuncs.com/sntp.yaml',
  'https://bust-gz-1251301437.cos.ap-guangzhou.myqcloud.com/sntp.yaml',
  'https://raw.githubusercontent.com/sntpPro/rule_list/refs/heads/main/sntp.yaml',
];

class RemoteConfigFetcher {
  late final Dio _dio;

  RemoteConfigFetcher() {
    final httpClient = HttpClient();
    httpClient.findProxy = (uri) => HttpClient.findProxyFromEnvironment(
          uri,
          environment: {'http_proxy': '', 'https_proxy': ''},
        );
    httpClient.badCertificateCallback = (_, _, _) => true;

    _dio = Dio(BaseOptions(
      connectTimeout: _kTimeout,
      receiveTimeout: _kTimeout,
    ));
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () => httpClient,
    );
  }

  Future<RemoteConfig?> fetchFromUrls(List<String> urls) async {
    for (final url in urls) {
      try {
        final config = await _fetchSingle(url);
        if (config != null) return config;
      } catch (e) {
        debugPrint('RemoteConfigFetcher: failed $url => $e');
        continue;
      }
    }
    return null;
  }

  Future<RemoteConfig?> _fetchSingle(String url) async {
    final response = await _dio.get<String>(
      url,
      options: Options(responseType: ResponseType.plain),
    );

    if (response.statusCode != 200 || response.data == null) {
      return null;
    }

    final body = response.data!.trim();
    final jsonMap = json.decode(body) as Map<String, Object?>;
    final config = RemoteConfig.fromJson(jsonMap);

    final decodedApi = config.decodedApi;
    if (decodedApi.isEmpty) return null;

    debugPrint('RemoteConfigFetcher: success from $url');
    return config;
  }
}

final remoteConfigFetcher = RemoteConfigFetcher();
