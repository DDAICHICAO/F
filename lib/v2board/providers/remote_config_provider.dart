import 'package:fl_clash/v2board/config/remote_config.dart';
import 'package:fl_clash/v2board/config/remote_config_model.dart';
import 'package:fl_clash/v2board/config/v2board_local_storage.dart';
import 'package:fl_clash/v2board/api/v2board_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum RemoteConfigStatus { loading, ready, error }

class RemoteConfigState {
  final RemoteConfigStatus status;
  final RemoteConfig? config;

  const RemoteConfigState({required this.status, this.config});
}

final remoteConfigProvider =
    NotifierProvider<RemoteConfigNotifier, RemoteConfigState>(
  RemoteConfigNotifier.new,
);

class RemoteConfigNotifier extends Notifier<RemoteConfigState> {
  @override
  RemoteConfigState build() {
    return const RemoteConfigState(status: RemoteConfigStatus.loading);
  }

  Future<void> init() async {
    v2boardApi.init();
    await v2boardApi.loadConfig();

    final storage = await V2boardLocalStorage.getInstance();

    final manualUrl = storage.manualApiUrl;
    if (manualUrl != null && manualUrl.isNotEmpty) {
      final config = RemoteConfig(hosts: [manualUrl]);
      await v2boardApi.updateConfig(config);
      state = RemoteConfigState(status: RemoteConfigStatus.ready, config: config);
      return;
    }

    if (v2boardApi.config != null) {
      state = RemoteConfigState(status: RemoteConfigStatus.ready, config: v2boardApi.config);
      _backgroundRefresh();
      return;
    }

    await fetchRemoteConfig();
  }

  Future<void> fetchRemoteConfig() async {
    state = RemoteConfigState(status: RemoteConfigStatus.loading, config: state.config);

    final storage = await V2boardLocalStorage.getInstance();
    final customUrls = storage.ossUrls;
    final urls = customUrls.isNotEmpty ? customUrls : kBuiltinOssUrls;

    final config = await remoteConfigFetcher.fetchFromUrls(urls);

    if (config != null) {
      await v2boardApi.updateConfig(config);
      state = RemoteConfigState(status: RemoteConfigStatus.ready, config: config);
    } else {
      state = const RemoteConfigState(status: RemoteConfigStatus.error);
    }
  }

  Future<void> setManualApiUrl(String url) async {
    final storage = await V2boardLocalStorage.getInstance();
    await storage.setManualApiUrl(url);

    final config = RemoteConfig(hosts: [url]);
    await v2boardApi.updateConfig(config);
    state = RemoteConfigState(status: RemoteConfigStatus.ready, config: config);
  }

  void _backgroundRefresh() {
    Future.microtask(() async {
      try {
        final storage = await V2boardLocalStorage.getInstance();
        final urls = storage.ossUrls.isNotEmpty ? storage.ossUrls : kBuiltinOssUrls;
        final config = await remoteConfigFetcher.fetchFromUrls(urls);
        if (config != null) {
          await v2boardApi.updateConfig(config);
          state = RemoteConfigState(status: RemoteConfigStatus.ready, config: config);
        }
      } catch (e) {
        debugPrint('RemoteConfigNotifier: background refresh failed $e');
      }
    });
  }
}
