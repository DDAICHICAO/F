import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:fl_clash/v2board/config/remote_config_model.dart';
import 'package:flutter/foundation.dart';

const _kTimeout = Duration(seconds: 10);

const kBuiltinOssUrls = [
  'https://bucket-1388497120.cos.ap-shanghai.myqcloud.com/config/sntp-conifg.json',
  'https://bucket-n-1388497120.cos.ap-beijing.myqcloud.com/config/sntp-conifg.json',
  'https://8.210.218.228/config/sntp-conifg.json',
  'https://8.217.1.95/config/sntp-conifg.json',
  'https://47.107.67.134/config/sntp-conifg.json',
  'https://112.74.166.174/config/sntp-conifg.json',
  'https://raw.gitcode.com/toamsterron/oss/raw/main/config/sntp-conifg.json',
  'https://gitlab.com/toamsterron/oss/-/raw/main/config/sntp-conifg.json',
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
    if (urls.isEmpty) return null;
    final completer = Completer<RemoteConfig?>();
    int remaining = urls.length;

    for (final url in urls) {
      _fetchSingle(url).then((config) {
        if (!completer.isCompleted && config != null) {
          completer.complete(config);
        } else {
          remaining--;
          if (remaining == 0 && !completer.isCompleted) {
            completer.complete(null);
          }
        }
      }).catchError((e) {
        debugPrint('RemoteConfigFetcher: failed $url => $e');
        remaining--;
        if (remaining == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future;
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

    // 尝试先 Base64 解码，再 JSON 解析
    RemoteConfig? config;
    config = RemoteConfig.fromBase64(body);
    if (config != null && config.hosts.isNotEmpty) {
      debugPrint('RemoteConfigFetcher: success (base64) from $url');
      return config;
    }

    // 直接 JSON 解析
    config = RemoteConfig.fromRawJson(body);
    if (config != null && config.hosts.isNotEmpty) {
      debugPrint('RemoteConfigFetcher: success (json) from $url');
      return config;
    }

    return null;
  }
}

final remoteConfigFetcher = RemoteConfigFetcher();
